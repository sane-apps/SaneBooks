import Foundation
@testable import SaneBooksCore
import SQLite3
import Testing

@Suite("ZashiSDKDatabaseImporter")
struct ZashiSDKDatabaseImporterTests {
    @Test
    func importsOrchardNotesFromFixtureDB() throws {
        let url = try Self.makeFixtureDatabase(noteCount: 3)
        defer { try? FileManager.default.removeItem(at: url) }

        let vaultID = VaultID()
        let result = try ZashiSDKDatabaseImporter.importDatabase(at: url, vaultID: vaultID)
        #expect(result.notes.count == 3)
        #expect(result.birthdayHeight == 3_080_001)
        #expect(result.accountName == "Fixture")
        #expect(result.ufvk.hasPrefix("uview1"))
        #expect(result.notes.allSatisfy { $0.pool == .orchard })
        #expect(result.notes.allSatisfy { $0.vaultID == vaultID })
        // Highest height first.
        #expect(result.notes[0].blockHeight >= result.notes[1].blockHeight)
        #expect(result.attestation.importedThroughHeight == result.notes.map(\.blockHeight).max())
        #expect(result.attestation.independentlyVerifiedChainTipHeight == nil)
        #expect(!result.attestation.isCaughtUp)
    }

    @Test
    func stableIDsUseTransactionPoolAndRealOutputIndex() throws {
        let url = try Self.makeFixtureDatabase(noteCount: 2)
        defer { try? FileManager.default.removeItem(at: url) }
        let vaultID = VaultID()

        let first = try ZashiSDKDatabaseImporter.importDatabase(at: url, vaultID: vaultID)
        let firstIDs = Dictionary(uniqueKeysWithValues: first.notes.map { ($0.txidHex, $0.id) })

        // Add a higher note that would shift every global sort index in the former implementation.
        try Self.appendOrchardNote(
            to: url,
            transactionID: 99,
            txByte: 0x99,
            height: 3_200_000,
            outputIndex: 0
        )
        // Add another output from an existing transaction. Its output index must distinguish the ID.
        try Self.appendOrchardOutput(to: url, transactionID: 1, outputIndex: 1, value: 44)
        let second = try ZashiSDKDatabaseImporter.importDatabase(at: url, vaultID: vaultID)

        for note in first.notes {
            #expect(second.notes.first { $0.txidHex == note.txidHex && $0.valueZatoshis == note.valueZatoshis }?.id == firstIDs[note.txidHex])
        }
        let sameTransaction = second.notes.filter { $0.txid == Data(repeating: 1, count: 32) }
        #expect(sameTransaction.count == 2)
        #expect(Set(sameTransaction.map(\.id)).count == 2)
    }

    @Test
    func reimportMergePreservesManualClassificationAndPackChoice() throws {
        let url = try Self.makeFixtureDatabase(noteCount: 1)
        defer { try? FileManager.default.removeItem(at: url) }
        let vaultID = VaultID()
        let first = try ZashiSDKDatabaseImporter.importDatabase(at: url, vaultID: vaultID)
        var classified = try #require(first.notes.first)
        classified.classification = Classification(
            kind: .income,
            party: "Retained client",
            subtag: "Invoice",
            notes: "Manually reviewed",
            source: .user
        )
        classified.includeInPacksByDefault = false

        try Self.appendOrchardNote(
            to: url,
            transactionID: 2,
            txByte: 0x22,
            height: 3_200_000,
            outputIndex: 0
        )
        let reimported = try ZashiSDKDatabaseImporter.importDatabase(at: url, vaultID: vaultID)
        let merged = ZashiSDKDatabaseImporter.mergeImportedNotesPreservingClassifications(
            existing: [classified],
            imported: reimported.notes
        )
        let retained = try #require(merged.first { $0.txid == classified.txid })
        #expect(retained.classification?.party == "Retained client")
        #expect(retained.classification?.source == .user)
        #expect(!retained.includeInPacksByDefault)
        #expect(merged.first { $0.txid == Data(repeating: 0x22, count: 32) }?.classification == nil)
    }

    @Test
    func rejectsDuplicateTransactionPoolOutputIdentity() throws {
        let url = try Self.makeFixtureDatabase(noteCount: 1)
        defer { try? FileManager.default.removeItem(at: url) }
        try Self.appendOrchardOutput(to: url, transactionID: 1, outputIndex: 0, value: 99)

        do {
            _ = try ZashiSDKDatabaseImporter.importDatabase(at: url, vaultID: VaultID())
            Issue.record("Expected duplicate note identity to be rejected")
        } catch let error as ZashiSDKDatabaseImporter.ImportError {
            guard case let .invalidData(detail) = error else {
                Issue.record("Expected invalidData, got \(error)")
                return
            }
            #expect(detail.contains("duplicate"))
        }
    }

    @Test
    func reimportMergeMigratesUniqueLegacyIndexBasedID() throws {
        let url = try Self.makeFixtureDatabase(noteCount: 1)
        defer { try? FileManager.default.removeItem(at: url) }
        let imported = try ZashiSDKDatabaseImporter.importDatabase(at: url, vaultID: VaultID())
        var legacy = try #require(imported.notes.first)
        legacy.id = NoteRowID()
        legacy.classification = Classification(kind: .expense, party: "Legacy", source: .user)

        let merged = ZashiSDKDatabaseImporter.mergeImportedNotesPreservingClassifications(
            existing: [legacy],
            imported: imported.notes
        )

        #expect(merged.first?.id == imported.notes.first?.id)
        #expect(merged.first?.classification?.party == "Legacy")
    }

    @Test
    func equalValueDualOutputsDoNotCrossCopyClassificationOnLegacyRematch() {
        let vaultID = VaultID()
        let txid = Data(repeating: 0xAB, count: 32)
        let height: UInt32 = 3_100_000
        let value: Int64 = 50_000_000

        var existingA = NoteRow(
            id: NoteRowID(),
            vaultID: vaultID,
            txid: txid,
            blockHeight: height,
            pool: .orchard,
            direction: .inbound,
            valueZatoshis: value,
            classification: Classification(kind: .income, party: "Client A", source: .user)
        )
        var existingB = NoteRow(
            id: NoteRowID(),
            vaultID: vaultID,
            txid: txid,
            blockHeight: height,
            pool: .orchard,
            direction: .inbound,
            valueZatoshis: value,
            classification: Classification(kind: .expense, party: "Vendor B", source: .user)
        )
        // New stable IDs simulate identity migration; semantic keys collide.
        let importedA = NoteRow(
            id: NoteRowID(),
            vaultID: vaultID,
            txid: txid,
            blockHeight: height,
            pool: .orchard,
            direction: .inbound,
            valueZatoshis: value
        )
        let importedB = NoteRow(
            id: NoteRowID(),
            vaultID: vaultID,
            txid: txid,
            blockHeight: height,
            pool: .orchard,
            direction: .inbound,
            valueZatoshis: value
        )

        let merged = ZashiSDKDatabaseImporter.mergeImportedNotesPreservingClassifications(
            existing: [existingA, existingB],
            imported: [importedA, importedB]
        )

        #expect(merged.count == 2)
        #expect(merged.allSatisfy { $0.classification == nil })
        #expect(Set(merged.map(\.id)) == Set([importedA.id, importedB.id]))
    }

    @Test
    func rejectsMultipleAccountsInsteadOfChoosingFirst() throws {
        let url = try Self.makeFixtureDatabase(noteCount: 0)
        defer { try? FileManager.default.removeItem(at: url) }
        try Self.withDatabase(at: url) { db in
            try Self.exec(db, "INSERT INTO accounts VALUES ('Second', 3080002, '\(ViewingKeyValidator.fixtureMainnetUFVK)');")
        }

        var rejectedExpectedCount = false
        do {
            _ = try ZashiSDKDatabaseImporter.importDatabase(at: url, vaultID: VaultID())
            Issue.record("Expected a multi-account database to be rejected")
        } catch let error as ZashiSDKDatabaseImporter.ImportError {
            guard case .multipleAccounts(2) = error else {
                Issue.record("Expected multipleAccounts(2), got \(error)")
                return
            }
            rejectedExpectedCount = true
        }
        #expect(rejectedExpectedCount)
    }

    @Test
    func rejectsDirectionalControlsInImportedAccountName() throws {
        let url = try Self.makeFixtureDatabase(noteCount: 0)
        defer { try? FileManager.default.removeItem(at: url) }
        try Self.withDatabase(at: url) { db in
            try Self.exec(db, "UPDATE accounts SET name = 'Acme' || char(8238) || 'gpj';")
        }

        do {
            _ = try ZashiSDKDatabaseImporter.importDatabase(at: url, vaultID: VaultID())
            Issue.record("Expected unsafe directional controls to be rejected")
        } catch let error as ZashiSDKDatabaseImporter.ImportError {
            guard case let .invalidData(detail) = error else {
                Issue.record("Expected invalidData, got \(error)")
                return
            }
            let expectedDetail = "account name contains unsafe control characters"
            #expect(detail == expectedDetail)
        }
    }

    @Test
    func rejectsPresentPoolWithUnsupportedSchema() throws {
        let url = try Self.makeFixtureDatabase(noteCount: 0, orchardIndexColumn: "legacy_index")
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            _ = try ZashiSDKDatabaseImporter.importDatabase(at: url, vaultID: VaultID())
            Issue.record("Expected an incompatible present pool schema to be rejected")
        } catch let error as ZashiSDKDatabaseImporter.ImportError {
            guard case let .unsupportedSchema(detail) = error else {
                Issue.record("Expected unsupportedSchema, got \(error)")
                return
            }
            #expect(detail.contains("orchard_received_notes"))
        }
    }

    @Test
    func enforcesDatabaseRowAndMemoBounds() throws {
        let url = try Self.makeFixtureDatabase(noteCount: 3, memoHex: "01020304")
        defer { try? FileManager.default.removeItem(at: url) }

        var rejectedRowLimit = false
        do {
            _ = try ZashiSDKDatabaseImporter.importDatabase(
                at: url,
                vaultID: VaultID(),
                limits: .init(maxRows: 2)
            )
            Issue.record("Expected row limit failure")
        } catch let error as ZashiSDKDatabaseImporter.ImportError {
            guard case .limitExceeded = error else {
                Issue.record("Expected limitExceeded, got \(error)")
                return
            }
            rejectedRowLimit = true
        }

        var rejectedMemoLimit = false
        do {
            _ = try ZashiSDKDatabaseImporter.importDatabase(
                at: url,
                vaultID: VaultID(),
                limits: .init(maxMemoBytes: 3)
            )
            Issue.record("Expected memo limit failure")
        } catch let error as ZashiSDKDatabaseImporter.ImportError {
            guard case .limitExceeded = error else {
                Issue.record("Expected limitExceeded, got \(error)")
                return
            }
            rejectedMemoLimit = true
        }

        var rejectedDatabaseLimit = false
        do {
            _ = try ZashiSDKDatabaseImporter.importDatabase(
                at: url,
                vaultID: VaultID(),
                limits: .init(maxDatabaseBytes: 1)
            )
            Issue.record("Expected database size limit failure")
        } catch let error as ZashiSDKDatabaseImporter.ImportError {
            guard case .databaseTooLarge = error else {
                Issue.record("Expected databaseTooLarge, got \(error)")
                return
            }
            rejectedDatabaseLimit = true
        }
        #expect(rejectedRowLimit && rejectedMemoLimit && rejectedDatabaseLimit)
    }

    @Test
    func cancelledAsyncImportFailsBeforeReturningAnyPartialResult() async throws {
        let url = try Self.makeFixtureDatabase(noteCount: 128)
        defer { try? FileManager.default.removeItem(at: url) }
        let cancellation = ImportCancellation()
        cancellation.cancel()

        var cancelled = false
        do {
            _ = try await ZashiSDKDatabaseImporter.importDatabaseAsync(
                at: url,
                vaultID: VaultID(),
                cancellation: cancellation
            )
            Issue.record("Expected a cancelled import to throw")
        } catch is CancellationError {
            cancelled = true
        }
        #expect(cancelled)
    }

    @Test
    func realZashiDBOptional() throws {
        guard let path = ProcessInfo.processInfo.environment["SANEBOOKS_ZASHI_DB"], !path.isEmpty else {
            return
        }
        let url = URL(fileURLWithPath: path)
        let result = try ZashiSDKDatabaseImporter.importDatabase(at: url, vaultID: VaultID())
        #expect(result.notes.count >= 10)
        #expect(result.ufvk.hasPrefix("uview1"))
        #expect(result.ufvk.count > 100)
        #expect(result.birthdayHeight > 0)
        // Never assert on full UFVK contents.
    }

    private static func makeFixtureDatabase(
        noteCount: Int,
        orchardIndexColumn: String = "action_index",
        memoHex: String? = nil
    ) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sanebooks-fixture-\(UUID().uuidString).db")
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK, let db else {
            throw ImportOpenError()
        }
        defer { sqlite3_close(db) }

        let ufvk = ViewingKeyValidator.fixtureMainnetUFVK
        try exec(
            db,
            """
            CREATE TABLE accounts (
              name TEXT,
              birthday_height INTEGER,
              ufvk TEXT
            );
            CREATE TABLE blocks (height INTEGER PRIMARY KEY, time INTEGER);
            CREATE TABLE transactions (
              id_tx INTEGER PRIMARY KEY,
              txid BLOB,
              mined_height INTEGER
            );
            CREATE TABLE orchard_received_notes (
              id INTEGER PRIMARY KEY,
              transaction_id INTEGER,
              \(orchardIndexColumn) INTEGER,
              value INTEGER,
              is_change INTEGER,
              memo BLOB
            );
            """
        )
        try exec(db, "INSERT INTO accounts VALUES ('Fixture', 3080001, '\(ufvk)');")

        for i in 0 ..< noteCount {
            let height = 3_100_000 + UInt32(i)
            let txid = Data(repeating: UInt8(i + 1), count: 32)
            let txHex = txid.map { String(format: "%02x", $0) }.joined()
            try exec(db, "INSERT INTO blocks VALUES (\(height), \(1_700_000_000 + i));")
            try exec(
                db,
                """
                INSERT INTO transactions (id_tx, txid, mined_height)
                VALUES (\(i + 1), X'\(txHex)', \(height));
                """
            )
            try exec(
                db,
                """
                INSERT INTO orchard_received_notes
                (transaction_id, \(orchardIndexColumn), value, is_change, memo)
                VALUES (\(i + 1), 0, \(100_000_000 + i), 0, \(memoHex.map { "X'\($0)'" } ?? "NULL"));
                """
            )
        }
        return url
    }

    private static func appendOrchardNote(
        to url: URL,
        transactionID: Int,
        txByte: UInt8,
        height: UInt32,
        outputIndex: UInt32
    ) throws {
        try withDatabase(at: url) { db in
            let txHex = Data(repeating: txByte, count: 32).map { String(format: "%02x", $0) }.joined()
            try exec(db, "INSERT INTO blocks VALUES (\(height), 1700000999);")
            try exec(
                db,
                "INSERT INTO transactions (id_tx, txid, mined_height) VALUES (\(transactionID), X'\(txHex)', \(height));"
            )
            try exec(
                db,
                "INSERT INTO orchard_received_notes (transaction_id, action_index, value, is_change, memo) VALUES (\(transactionID), \(outputIndex), 55, 0, NULL);"
            )
        }
    }

    private static func appendOrchardOutput(
        to url: URL,
        transactionID: Int,
        outputIndex: UInt32,
        value: Int64
    ) throws {
        try withDatabase(at: url) { db in
            try exec(
                db,
                "INSERT INTO orchard_received_notes (transaction_id, action_index, value, is_change, memo) VALUES (\(transactionID), \(outputIndex), \(value), 0, NULL);"
            )
        }
    }

    private static func withDatabase(at url: URL, body: (OpaquePointer) throws -> Void) throws {
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK, let db else {
            throw ImportOpenError()
        }
        defer { sqlite3_close(db) }
        try body(db)
    }

    private static func exec(_ db: OpaquePointer, _ sql: String) throws {
        var err: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &err) == SQLITE_OK else {
            let message = err.map { String(cString: $0) } ?? "sqlite exec failed"
            sqlite3_free(err)
            throw ImportOpenError(message: message)
        }
    }

    private struct ImportOpenError: Error {
        var message: String = "open failed"
    }
}
