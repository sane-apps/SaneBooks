import Foundation
@testable import SaneBooksCore
import Testing

@Suite("ViewingKeyValidator")
struct ViewingKeyValidatorTests {
    let validator = ViewingKeyValidator()

    @Test func rejectsBIP39Seed() {
        let seed = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        #expect(validator.validate(seed, selectedNetwork: .mainnet) == .rejectSeed)
    }

    @Test func rejectsSecretExtendedKey() {
        let result = validator.validate(
            "secret-extended-key-main1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq",
            selectedNetwork: .mainnet
        )
        #expect(result == .rejectSpendingKey)
    }

    @Test func rejectsSecretSharingKey() {
        #expect(validator.validate("secret-sharing-key-main1qqqq", selectedNetwork: .mainnet) == .rejectSpendingKey)
    }

    @Test func acceptsUFVKMainnet() {
        let key = "uview1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq"
        let result = validator.validate(key, selectedNetwork: .mainnet)
        guard case let .accept(kind, network, hrp, fingerprint, mode) = result else {
            Issue.record("Expected accept, got \(result)")
            return
        }
        #expect(kind == .ufvk)
        #expect(network == .mainnet)
        #expect(hrp == "uview")
        #expect(mode == .bookkeeper)
        #expect(fingerprint.hasPrefix("uview:"))
    }

    @Test func acceptsLiveProbeUFVK() {
        let result = validator.validate(LiveProbeKey.mainnetUFVK, selectedNetwork: .mainnet)
        guard case let .accept(kind, network, hrp, _, mode) = result else {
            Issue.record("Expected accept, got \(result)")
            return
        }
        #expect(kind == .ufvk)
        #expect(network == .mainnet)
        #expect(hrp == "uview")
        #expect(mode == .bookkeeper)
        #expect(LiveProbeKey.mainnetUFVK.hasPrefix("uview1"))
        #expect(LiveProbeKey.mainnetUFVK.count > 400)
    }

    @Test func networkMismatch() {
        let key = "uviewtest1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq"
        #expect(validator.validate(key, selectedNetwork: .mainnet) == .networkMismatch(detected: .testnet))
    }

    @Test func acceptsUIVK() {
        let key = "uivk1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq"
        let result = validator.validate(key, selectedNetwork: .mainnet)
        guard case let .accept(kind, _, _, _, mode) = result else {
            Issue.record("Expected accept, got \(result)")
            return
        }
        #expect(kind == .uivk)
        #expect(mode == .receivables)
    }
}

@Suite("ZIP302")
struct ZIP302Tests {
    @Test func emptyMemo() {
        var data = Data([0xF6])
        data.append(Data(repeating: 0, count: 10))
        #expect(ZIP302MemoDecoder.decode(data) == .empty)
    }

    @Test func utf8ZeroPadded() {
        var data = Data("hello".utf8)
        data.append(Data(repeating: 0, count: 20))
        #expect(ZIP302MemoDecoder.decode(data) == .text("hello"))
    }

    @Test func opaqueBinary() {
        #expect(ZIP302MemoDecoder.decode(Data([0xFF, 0x01, 0x02, 0x03])) == .opaque(Data([0x01, 0x02, 0x03])))
    }
}

@Suite("ClassificationEngine")
struct ClassificationEngineTests {
    let vaultID = VaultID()

    func note(txidByte: UInt8, direction: NoteDirection, value: Int64 = 1_000_000) -> NoteRow {
        NoteRow(
            vaultID: vaultID,
            txid: Data(repeating: txidByte, count: 32),
            blockHeight: 1,
            pool: .orchard,
            direction: direction,
            valueZatoshis: value
        )
    }

    @Test func ufvkSameTxInboundOutboundSuggestsChange() {
        let notes = [
            note(txidByte: 0x11, direction: .outbound, value: 50_000_000),
            note(txidByte: 0x11, direction: .inbound, value: 49_000_000)
        ]
        let result = ClassificationEngine.suggest(notes: notes, vaultMode: .bookkeeper, keyKind: .ufvk)
        let change = result.first { $0.suggestedClassification == .change }
        #expect(change != nil)
        #expect(change?.classification?.source == .autoChange)
    }

    @Test func uivkNeverAutoChange() throws {
        let notes = [
            note(txidByte: 0x22, direction: .outbound),
            note(txidByte: 0x22, direction: .inbound)
        ]
        let result = ClassificationEngine.suggest(notes: notes, vaultMode: .receivables, keyKind: .uivk)
        let inbound = try #require(result.first { $0.direction == .inbound })
        #expect(inbound.suggestedClassification != .change)
        #expect(inbound.classification?.kind != .change)
        #expect(inbound.suggestedClassification == .income)
    }

    @Test func incomeTotalsOnlyIncome() {
        var income = note(txidByte: 0x33, direction: .inbound, value: 100_000_000)
        income.classification = Classification(kind: .income, source: .user)
        var change = note(txidByte: 0x34, direction: .changeCandidate, value: 50_000_000)
        change.classification = Classification(kind: .change, source: .autoChange)
        #expect(ClassificationEngine.incomeTotalZatoshis(notes: [income, change]) == 100_000_000)
    }

    @Test func applyRulesTagsMemoContains() {
        var income = note(txidByte: 0x55, direction: .inbound, value: 10_000_000)
        income.memo = .text("INV-441 retainer")
        income.suggestedClassification = .income
        let rules = [TagRule.defaultInvoiceSeed]
        let result = ClassificationEngine.applyRules(rules, to: [income])
        #expect(result[0].classification?.kind == .income)
        #expect(result[0].classification?.source == .rule)
        #expect(result[0].classification?.subtag == "Invoice")
    }

    @Test func applyRulesSkipsUserClassification() {
        var income = note(txidByte: 0x56, direction: .inbound, value: 10_000_000)
        income.memo = .text("INV-999")
        income.classification = Classification(kind: .expense, party: "Manual", source: .user)
        let result = ClassificationEngine.applyRules([TagRule.defaultInvoiceSeed], to: [income])
        #expect(result[0].classification?.kind == .expense)
        #expect(result[0].classification?.source == .user)
    }
}

@Suite("VaultModeBanner")
struct VaultModeBannerTests {
    @Test func showsUpgradeForReceivables() {
        #expect(VaultModeBanner.shouldShowUpgradeBanner(mode: .receivables))
        #expect(!VaultModeBanner.shouldShowUpgradeBanner(mode: .bookkeeper))
    }

    @Test func canUpgradeSameNetwork() {
        let vault = Vault(
            displayName: "R",
            network: .mainnet,
            keyKind: .uivk,
            keyFingerprint: "uivk:aaaa",
            mode: .receivables
        )
        #expect(VaultModeBanner.canUpgrade(current: vault, newMode: .bookkeeper, newNetwork: .mainnet))
        #expect(!VaultModeBanner.canUpgrade(current: vault, newMode: .bookkeeper, newNetwork: .testnet))
        #expect(!VaultModeBanner.canUpgrade(current: vault, newMode: .receivables, newNetwork: .mainnet))
    }
}

@Suite("InMemoryStores")
struct StoreTests {
    @Test func viewingKeyStoreRoundTrip() throws {
        let store = InMemoryViewingKeyStore()
        let id = VaultID()
        try store.save("uview1qqq", for: id)
        #expect(try store.load(for: id) == "uview1qqq")
        try store.delete(for: id)
        #expect(try store.load(for: id) == nil)
    }

    @Test func fileLedgerPersistsFingerprintOnly() throws {
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
            )
        ])

        let reloaded = try FileLedgerStore(rootURL: tmp)
        #expect(try reloaded.vault(id: vault.id)?.keyFingerprint == "uview:aabbccddeeff0011")
        let json = try String(contentsOf: store.ledgerFileURL, encoding: .utf8)
        #expect(!json.contains("uview1qqq"))
        #expect(json.contains("uview:aabbccddeeff0011"))
    }

    @Test func shareHistoryAppendAndList() throws {
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

    @Test func fileLedgerPersistsShareHistoryAndActiveVault() throws {
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
}
