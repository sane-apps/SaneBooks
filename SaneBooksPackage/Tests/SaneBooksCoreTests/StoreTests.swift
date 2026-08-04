import Foundation
@testable import SaneBooksCore
import Testing

@Suite("InMemoryStores")
struct StoreTests {
    @Test
    func viewingKeyStoreRoundTrip() throws {
        let store = InMemoryViewingKeyStore()
        let id = VaultID()
        try store.save("uview1qqq", for: id)
        #expect(try store.load(for: id) == "uview1qqq")
        try store.delete(for: id)
        #expect(try store.load(for: id) == nil)
    }

    @Test
    func upsertPreservesDistinctOutputsFromSameTransaction() throws {
        let store = InMemoryLedgerStore()
        let vaultID = VaultID()
        let txid = Data(repeating: 0xAA, count: 32)
        let first = NoteRow(
            id: .stable(vaultID: vaultID, txid: txid + Data([0])),
            vaultID: vaultID,
            txid: txid,
            blockHeight: 10,
            pool: .orchard,
            direction: .inbound,
            valueZatoshis: 1
        )
        let second = NoteRow(
            id: .stable(vaultID: vaultID, txid: txid + Data([1])),
            vaultID: vaultID,
            txid: txid,
            blockHeight: 10,
            pool: .orchard,
            direction: .inbound,
            valueZatoshis: 2
        )

        try store.upsertNotes([first, second])

        #expect(try store.notes(vaultID: vaultID).count == 2)
    }

    @Test
    func fileLedgerPersistsFingerprintOnly() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("SaneBooksTest-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let store = try FileLedgerStore(rootURL: tmp)
        let vault = Vault(
            displayName: "Test",
            network: .mainnet,
            keyKind: .ufvk,
            keyFingerprint: "uview:aabbccddeeff0011",
            mode: .bookkeeper
        )
        try store.upsertVault(vault)
        try store.upsertNotes([
            NoteRow(
                vaultID: vault.id,
                txid: Data(repeating: 1, count: 32),
                blockHeight: 10,
                pool: .sapling,
                direction: .inbound,
                valueZatoshis: 1
            ),
        ])

        let reloaded = try FileLedgerStore(rootURL: tmp)
        #expect(try reloaded.vault(id: vault.id)?.keyFingerprint == "uview:aabbccddeeff0011")
        let json = try String(contentsOf: store.ledgerFileURL, encoding: .utf8)
        #expect(!json.contains("uview1qqq"))
        #expect(json.contains("uview:aabbccddeeff0011"))
    }

    @Test
    func shareHistoryAppendAndList() throws {
        let store = InMemoryLedgerStore()
        #expect(try store.shareHistory().isEmpty)
        let entry = ShareHistoryEntry(
            recipientLabel: "Accountant",
            rangeStart: Date(timeIntervalSince1970: 1_700_000_000),
            rangeEnd: Date(timeIntervalSince1970: 1_800_000_000),
            integrityHash: "deadbeef",
            format: .pdf,
            rowCount: 3,
            vaultFingerprint: "uview:aabb"
        )
        try store.appendShareHistory(entry)
        let listed = try store.shareHistory()
        #expect(listed.count == 1)
        #expect(listed[0].recipientLabel == "Accountant")
        #expect(listed[0].format == .pdf)
        #expect(listed[0].rowCount == 3)
    }

    @Test
    func deletingVaultAlsoDeletesItsShareHistory() throws {
        let store = InMemoryLedgerStore()
        let removed = Vault(
            displayName: "Remove me",
            network: .mainnet,
            keyKind: .ufvk,
            keyFingerprint: "uview:remove",
            mode: .bookkeeper
        )
        let retained = Vault(
            displayName: "Keep me",
            network: .mainnet,
            keyKind: .ufvk,
            keyFingerprint: "uview:keep",
            mode: .bookkeeper
        )
        try store.upsertVault(removed)
        try store.upsertVault(retained)
        for fingerprint in [removed.keyFingerprint, retained.keyFingerprint] {
            try store.appendShareHistory(ShareHistoryEntry(
                rangeStart: Date(),
                rangeEnd: Date(),
                format: .csv,
                rowCount: 1,
                vaultFingerprint: fingerprint
            ))
        }

        try store.deleteVault(id: removed.id)

        let history = try store.shareHistory()
        #expect(history.count == 1)
        #expect(history.first?.vaultFingerprint == retained.keyFingerprint)
    }

    @Test
    func fileLedgerPersistsShareHistoryAndActiveVault() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("SaneBooksHist-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let store = try FileLedgerStore(rootURL: tmp)
        let v1 = Vault(displayName: "A", network: .mainnet, keyKind: .ufvk, keyFingerprint: "uview:aaaa", mode: .bookkeeper)
        let v2 = Vault(displayName: "B", network: .mainnet, keyKind: .ufvk, keyFingerprint: "uview:bbbb", mode: .bookkeeper)
        try store.upsertVault(v1)
        try store.upsertVault(v2)
        try store.setActiveVaultID(v2.id)
        try store.appendShareHistory(ShareHistoryEntry(
            rangeStart: Date(),
            rangeEnd: Date(),
            format: .csv,
            rowCount: 1
        ))

        let reloaded = try FileLedgerStore(rootURL: tmp)
        #expect(try reloaded.allVaults().count == 2)
        #expect(try reloaded.activeVaultID() == v2.id)
        #expect(try reloaded.shareHistory().count == 1)
    }

    @Test
    func fileLedgerEnforcesOwnerOnlyPermissions() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("SaneBooksPermissions-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let store = try FileLedgerStore(rootURL: tmp)
        let vault = Vault(
            displayName: "Permissions",
            network: .mainnet,
            keyKind: .ufvk,
            keyFingerprint: "uview:permissions",
            mode: .bookkeeper
        )
        try store.upsertVault(vault)

        let rootMode = try #require(
            FileManager.default.attributesOfItem(atPath: tmp.path)[.posixPermissions] as? NSNumber
        ).intValue & 0o777
        let ledgerMode = try #require(
            FileManager.default.attributesOfItem(atPath: store.ledgerFileURL.path)[.posixPermissions] as? NSNumber
        ).intValue & 0o777
        #expect(rootMode == 0o700)
        #expect(ledgerMode == 0o600)
    }

    @Test
    func fileLedgerRollsBackMemoryWhenPersistenceFails() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("SaneBooksPersistFailure-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let store = try FileLedgerStore(rootURL: tmp)
        try FileManager.default.createDirectory(
            at: store.ledgerFileURL,
            withIntermediateDirectories: false
        )
        let vault = Vault(
            displayName: "Must not survive",
            network: .mainnet,
            keyKind: .ufvk,
            keyFingerprint: "uview:failure",
            mode: .bookkeeper
        )

        do {
            try store.upsertVault(vault)
            Issue.record("Expected persistence to fail when ledger.json is a directory")
        } catch {
            #expect(try store.allVaults().isEmpty)
            #expect(try store.vault(id: vault.id) == nil)
        }
    }

    @Test
    func fileLedgerUsesOneEncodedSizeBudgetForPersistAndRelaunch() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("SaneBooksSizeBudget-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let initial = try FileLedgerStore(rootURL: tmp)
        let retained = Vault(
            displayName: "Fits exactly",
            network: .mainnet,
            keyKind: .ufvk,
            keyFingerprint: "uview:size-budget-retained",
            mode: .bookkeeper
        )
        try initial.upsertVault(retained)
        let exactEncodedSize = try Data(contentsOf: initial.ledgerFileURL).count

        let exactBoundaryStore = try FileLedgerStore(
            rootURL: tmp,
            encodedByteLimit: exactEncodedSize
        )
        try exactBoundaryStore.setActiveVaultID(retained.id)
        #expect(try Data(contentsOf: initial.ledgerFileURL).count == exactEncodedSize)

        let rejected = Vault(
            displayName: "This mutation must roll back before commit",
            network: .mainnet,
            keyKind: .ufvk,
            keyFingerprint: "uview:size-budget-rejected",
            mode: .bookkeeper
        )
        do {
            try exactBoundaryStore.upsertVault(rejected)
            Issue.record("Expected a snapshot above the encoded-size budget to fail")
        } catch {
            #expect(error as? SaneBooksError == .persistFailed(
                "Private ledger exceeds the encoded-size safety limit."
            ))
            #expect(try exactBoundaryStore.vault(id: retained.id) != nil)
            #expect(try exactBoundaryStore.vault(id: rejected.id) == nil)
            #expect(try Data(contentsOf: initial.ledgerFileURL).count == exactEncodedSize)
        }

        let relaunched = try FileLedgerStore(rootURL: tmp, encodedByteLimit: exactEncodedSize)
        #expect(try relaunched.vault(id: retained.id) != nil)
        #expect(try relaunched.vault(id: rejected.id) == nil)

        do {
            _ = try FileLedgerStore(rootURL: tmp, encodedByteLimit: exactEncodedSize - 1)
            Issue.record("Expected an existing snapshot one byte above the budget to fail closed")
        } catch {
            #expect(error as? SaneBooksError == .persistFailed(
                "Private ledger exceeds the encoded-size safety limit."
            ))
            #expect(try Data(contentsOf: initial.ledgerFileURL).count == exactEncodedSize)
        }
    }

    @Test
    func fileLedgerInitializationNeverFallsBackForInvalidRoot() throws {
        let rootFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("SaneBooksInvalidRoot-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: rootFile) }
        try Data("not a directory".utf8).write(to: rootFile)

        do {
            _ = try FileLedgerStore(rootURL: rootFile)
            Issue.record("Expected FileLedgerStore initialization to fail")
        } catch {
            #expect(FileManager.default.fileExists(atPath: rootFile.path))
        }
    }

    @Test
    func corruptedCurrentSnapshotDoesNotDowngradeToLegacyAndDiscardHistory() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("SaneBooksCorruptSnapshot-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let store = try FileLedgerStore(rootURL: tmp)
        try store.upsertVault(Vault(
            displayName: "Corruption test",
            network: .mainnet,
            keyKind: .ufvk,
            keyFingerprint: "uview:corrupt",
            mode: .bookkeeper
        ))
        try store.appendShareHistory(ShareHistoryEntry(
            rangeStart: Date(timeIntervalSince1970: 1_700_000_000),
            rangeEnd: Date(timeIntervalSince1970: 1_700_000_100),
            format: .csv,
            rowCount: 1
        ))

        let data = try Data(contentsOf: store.ledgerFileURL)
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["shareHistory"] = "damaged"
        try JSONSerialization.data(withJSONObject: object).write(to: store.ledgerFileURL, options: .atomic)

        do {
            _ = try FileLedgerStore(rootURL: tmp)
            Issue.record("Expected the corrupted current snapshot to fail closed")
        } catch {
            #expect(FileManager.default.fileExists(atPath: store.ledgerFileURL.path))
        }
    }

    @Test
    func fileLedgerPersistsAndReloadsTenThousandNotes() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("SaneBooksLargeLedger-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let store = try FileLedgerStore(rootURL: tmp)
        let vault = Vault(
            displayName: "Large ledger",
            network: .mainnet,
            keyKind: .ufvk,
            keyFingerprint: "uview:largeledger",
            mode: .bookkeeper
        )
        try store.upsertVault(vault)
        let rowCount = 10000
        let firstHeight = 3_400_000
        let notes = (0 ..< rowCount).map { index in
            var txid = Data(repeating: 0, count: 32)
            withUnsafeBytes(of: UInt64(index).bigEndian) { bytes in
                txid.replaceSubrange(24 ..< 32, with: bytes)
            }
            return NoteRow(
                id: .stableOutput(
                    vaultID: vault.id,
                    txid: txid,
                    pool: index.isMultiple(of: 2) ? .orchard : .ironwood,
                    outputIndex: 0
                ),
                vaultID: vault.id,
                txid: txid,
                blockHeight: UInt32(firstHeight + index),
                blockTime: Date(timeIntervalSince1970: 1_700_000_000 + Double(index)),
                pool: index.isMultiple(of: 2) ? .orchard : .ironwood,
                direction: .inbound,
                valueZatoshis: Int64(index + 1)
            )
        }

        try store.upsertNotes(notes)
        let reloaded = try FileLedgerStore(rootURL: tmp)
        let restored = try reloaded.notes(vaultID: vault.id)
        let expectedTotal = Int64(rowCount) * Int64(rowCount + 1) / 2
        #expect(restored.count == rowCount)
        #expect(restored.first?.blockHeight == UInt32(firstHeight))
        #expect(restored.last?.blockHeight == UInt32(firstHeight + rowCount - 1))
        #expect(restored.reduce(Int64(0)) { $0 + $1.valueZatoshis } == expectedTotal)
    }
}
