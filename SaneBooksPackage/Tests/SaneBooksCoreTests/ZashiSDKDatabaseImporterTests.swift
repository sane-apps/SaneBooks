import Foundation
@testable import SaneBooksCore
import SQLite3
import Testing

@Suite("ZashiSDKDatabaseImporter")
struct ZashiSDKDatabaseImporterTests {
    @Test func importsOrchardNotesFromFixtureDB() throws {
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
    }

    @Test func realZashiDBOptional() throws {
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

    private static func makeFixtureDatabase(noteCount: Int) throws -> URL {
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
              action_index INTEGER,
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
                (transaction_id, action_index, value, is_change, memo)
                VALUES (\(i + 1), 0, \(100_000_000 + i), 0, NULL);
                """
            )
        }
        return url
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
