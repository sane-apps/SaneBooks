import Foundation
import Observation
import SaneBooksCore
import SaneBooksExport
import SaneBooksSync

public enum AppRoute: Equatable, Sendable {
    case welcome
    case importKey
    case syncing
    case ledger
    case noteDetail(NoteRowID)
    case proofPackBuilder
    case sharePack
    case reader
}

public struct LedgerFilters: Equatable, Sendable {
    public var year: Int?
    public var kind: ClassificationKind?
    public var untaggedOnly: Bool
    public var searchText: String

    public init(
        year: Int? = nil,
        kind: ClassificationKind? = nil,
        untaggedOnly: Bool = false,
        searchText: String = ""
    ) {
        self.year = year
        self.kind = kind
        self.untaggedOnly = untaggedOnly
        self.searchText = searchText
    }
}

@MainActor
@Observable
public final class AppModel {
    public var route: AppRoute = .welcome
    public var vault: Vault?
    public var vaults: [Vault] = []
    public var notes: [NoteRow] = []
    public var cursor: SyncCursor?
    public var packDraft: ProofPackDraft?
    public var lastIntegrityHash: String?
    public var lastSavedPackURL: URL?
    public var readerResult: PackOpenResult?
    public var readerError: String?
    public var importError: String?
    public var importKeyText: String = ""
    public var importNetwork: ZcashNetwork = .mainnet
    public var importBirthdayText: String = ""
    public var filters = LedgerFilters()
    public var showWhatIsViewingKey = false
    public var showDegradedConfirm = false
    public var shareHistory: [ShareHistoryEntry] = []
    public var acknowledgePartialHistory = false
    public var capabilityReport: CapabilityReport?
    public var lwdURLString: String = "https://zec.rocks:443"
    /// When true, import replaces the active receivables vault key (UFVK upgrade).
    public var importAsUpgrade = false
    public var showBirthdayHelp = false
    /// When true, next sync uses Mock path on LightClientSyncFacade (demo fixture).
    private var pendingForceMock = false

    // Settings
    public var defaultPackExpiryDays = 90
    public var includeMemosByDefault = false
    public var truncateTxidsInUI = true
    public var requirePassphraseToOpenVault = true

    private let store: any LedgerStore
    private let keyStore: any ViewingKeyStore
    private let sync: any SyncFacade
    private let validator = ViewingKeyValidator()
    private var pendingImportAccept: ViewingKeyValidationOutcome?
    private var syncTask: Task<Void, Never>?

    /// Test / preview default: in-memory store + mock sync (no Keychain).
    public init(
        store: any LedgerStore = InMemoryLedgerStore(),
        keyStore: any ViewingKeyStore = InMemoryViewingKeyStore(),
        sync: any SyncFacade = MockSyncFacade()
    ) {
        self.store = store
        self.keyStore = keyStore
        self.sync = sync
    }

    /// App launch default: FileLedgerStore + KeychainViewingKeyStore + LightClientSyncFacade.
    /// Falls back to in-memory if Application Support cannot be created.
    public static func makeProduction() -> AppModel {
        let forceMock = ProcessInfo.processInfo.environment["SANEBOOKS_FORCE_MOCK"] == "1"
        let sync: any SyncFacade = forceMock
            ? MockSyncFacade()
            : LightClientSyncFacade.makeDefault()
        do {
            let store = try FileLedgerStore()
            let model = AppModel(
                store: store,
                keyStore: KeychainViewingKeyStore(),
                sync: sync
            )
            model.reloadFromStore()
            return model
        } catch {
            return AppModel(sync: sync)
        }
    }

    public func reloadFromStore() {
        do {
            try pruneDuplicateVaultsByFingerprint()
            try refreshVaultNamesIfNeeded()
            vaults = try store.allVaults()
            shareHistory = try store.shareHistory()
            if let active = try store.activeVaultID(), let v = try store.vault(id: active) {
                vault = v
                notes = try store.notes(vaultID: v.id)
            } else if let first = vaults.first {
                vault = first
                notes = try store.notes(vaultID: first.id)
                try store.setActiveVaultID(first.id)
            } else {
                vault = nil
                notes = []
            }
            if vault != nil {
                route = .ledger
            }
        } catch {
            importError = error.localizedDescription
        }
    }

    /// Launch-arg driven routes for Mini visual / E2E captures (`--e2e-scene=`).
    public func applyE2ESceneIfNeeded(_ arguments: [String] = ProcessInfo.processInfo.arguments) {
        let scene = arguments
            .first { $0.hasPrefix("--e2e-scene=") }
            .map { String($0.dropFirst("--e2e-scene=".count)) }
        switch scene {
        case "welcome":
            route = .welcome
        case "import":
            route = .importKey
        case "import-demo":
            useDemoKey()
            route = .importKey
        case "sync", "ledger", "detail", "pack", "share":
            bootstrapDemoVaultForE2E(then: scene ?? "ledger")
        case "reader":
            route = .reader
        default:
            break
        }
    }

    private func bootstrapDemoVaultForE2E(then scene: String) {
        useDemoKey()
        // Reuse the existing demo vault when present — never stack duplicates per launch.
        let demoFP = ViewingKeyValidator().validate(
            ViewingKeyValidator.fixtureMainnetUFVK,
            selectedNetwork: .mainnet
        )
        if case let .accept(_, _, _, fingerprint, _) = demoFP,
           let existing = (try? store.allVaults())?.first(where: { $0.keyFingerprint == fingerprint }) {
            switchVault(existing.id)
        } else {
            finishImport()
        }
        Task {
            for _ in 0 ..< 80 {
                if cursor?.status == .caughtUp
                    || cursor?.status == .capabilityBlocked
                    || cursor?.status == .idle {
                    break
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
            await refreshFromSync()
            switch scene {
            case "sync":
                route = .syncing
            case "detail":
                route = .ledger
                if let first = notes.first {
                    route = .noteDetail(first.id)
                }
            case "pack":
                beginProofPack()
            case "share":
                prepareDefaultPackDraft()
                acknowledgePartialHistory = true
                if var draft = packDraft {
                    draft.acknowledgePartialHistory = true
                    packDraft = draft
                }
                route = .sharePack
            default:
                route = .ledger
            }
        }
    }

    public func prepareDefaultPackDraft() {
        guard let vault else { return }
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        let start = cal.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
        let end = cal.date(from: DateComponents(year: year, month: 12, day: 31)) ?? Date()
        let expires = cal.date(byAdding: .day, value: defaultPackExpiryDays, to: Date()) ?? Date()
        var draft = PackBuilder.buildDraft(
            vault: vault,
            notes: notes,
            rangeStart: start,
            rangeEnd: end,
            includedKinds: [.income, .expense, .fee],
            includeMemos: includeMemosByDefault,
            includeChange: false,
            excludeTags: [],
            cursor: cursor,
            recipientLabel: "Accountant — Acme CPA",
            expiresAt: expires
        )
        draft.acknowledgePartialHistory = acknowledgePartialHistory
        packDraft = draft
    }

    // MARK: - Navigation

    public func goWelcome() {
        route = .welcome
        importAsUpgrade = false
    }

    public func goImport(asUpgrade: Bool = false) {
        importError = nil
        importAsUpgrade = asUpgrade
        route = .importKey
    }

    public func goReader() {
        readerResult = nil
        readerError = nil
        route = .reader
    }

    public func useDemoKey() {
        importKeyText = ViewingKeyValidator.fixtureMainnetUFVK
        importNetwork = .mainnet
        importError = nil
        pendingForceMock = true
    }

    public func finishImport() {
        importError = nil
        let outcome = validator.validate(importKeyText, selectedNetwork: importNetwork)
        switch outcome {
        case .empty:
            importError = "Paste a viewing key to continue."
        case .rejectSeed:
            importError = SaneBooksError.seedRejected.userFacingMessage
        case .rejectSpendingKey:
            importError = SaneBooksError.spendingKeyRejected.userFacingMessage
        case .rejectGarbage:
            importError = SaneBooksError.garbageKey.userFacingMessage
        case let .networkMismatch(detected):
            importError = SaneBooksError.networkMismatch(expected: importNetwork, detected: detected).userFacingMessage
        case .rejectUnsupported:
            importError = SaneBooksError.unsupportedKey.userFacingMessage
        case let .accept(kind, network, _, fingerprint, mode):
            if importAsUpgrade {
                completeUpgrade(kind: kind, network: network, fingerprint: fingerprint, mode: mode)
                return
            }
            if mode == .receivables {
                pendingImportAccept = outcome
                showDegradedConfirm = true
                return
            }
            completeImport(kind: kind, network: network, fingerprint: fingerprint, mode: mode)
        }
    }

    public func confirmDegradedImport() {
        showDegradedConfirm = false
        guard case let .accept(kind, network, _, fingerprint, mode) = pendingImportAccept else { return }
        pendingImportAccept = nil
        completeImport(kind: kind, network: network, fingerprint: fingerprint, mode: mode)
    }

    public func cancelDegradedImport() {
        showDegradedConfirm = false
        pendingImportAccept = nil
    }

    private func completeImport(kind: ViewingKeyKind, network: ZcashNetwork, fingerprint: String, mode: VaultMode) {
        let birthday = parseBirthday(importBirthdayText)
        let keyMaterial = importKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let isDemo = keyMaterial == ViewingKeyValidator.fixtureMainnetUFVK
            || keyMaterial == ViewingKeyValidator.fixtureTestnetUFVK
            || pendingForceMock
        do {
            // Same viewing key → same books. Reuse instead of stacking clones.
            if var existing = try store.allVaults().first(where: { $0.keyFingerprint == fingerprint }) {
                existing.displayName = Self.defaultVaultDisplayName(
                    mode: existing.mode,
                    network: existing.network,
                    fingerprint: existing.keyFingerprint,
                    isDemo: isDemo || existing.displayName.lowercased().contains("demo")
                )
                try keyStore.save(keyMaterial, for: existing.id)
                try store.upsertVault(existing)
                try store.setActiveVaultID(existing.id)
                vault = existing
                vaults = try store.allVaults()
                notes = try store.notes(vaultID: existing.id)
                cursor = nil
                importKeyText = ""
                importAsUpgrade = false
                route = .syncing
                startSync()
                return
            }

            let newVault = Vault(
                displayName: Self.defaultVaultDisplayName(
                    mode: mode,
                    network: network,
                    fingerprint: fingerprint,
                    isDemo: isDemo
                ),
                network: network,
                keyKind: kind,
                keyFingerprint: fingerprint,
                birthdayHeight: birthday,
                mode: mode,
                capabilitiesBanner: mode == .receivables
                    ? VaultModeBanner.upgradeBannerCopy
                    : nil
            )
            try keyStore.save(keyMaterial, for: newVault.id)
            try store.upsertVault(newVault)
            try store.setActiveVaultID(newVault.id)
            vault = newVault
            vaults = try store.allVaults()
            notes = []
            cursor = nil
            importKeyText = ""
            importAsUpgrade = false
            route = .syncing
            startSync()
        } catch {
            importError = error.localizedDescription
        }
    }

    /// Human label for a books set (vault = viewing-key books, not a wallet).
    public static func defaultVaultDisplayName(
        mode: VaultMode,
        network: ZcashNetwork,
        fingerprint: String,
        isDemo: Bool
    ) -> String {
        if isDemo {
            return "Demo books"
        }
        let short = fingerprint.split(separator: ":").last.map(String.init) ?? fingerprint
        let tip = String(short.prefix(6))
        switch mode {
        case .bookkeeper:
            return "My books · \(network.displayName) · \(tip)"
        case .receivables:
            return "Incoming only · \(network.displayName) · \(tip)"
        }
    }

    /// Collapse clones that share a fingerprint (e2e relaunches used to create one per run).
    private func pruneDuplicateVaultsByFingerprint() throws {
        let all = try store.allVaults()
        let grouped = Dictionary(grouping: all, by: \.keyFingerprint)
        let active = try store.activeVaultID()
        for (_, group) in grouped where group.count > 1 {
            let keeper = group.first(where: { $0.id == active })
                ?? group.max(by: { $0.createdAt < $1.createdAt })!
            for orphan in group where orphan.id != keeper.id {
                try? keyStore.delete(for: orphan.id)
                try store.deleteVault(id: orphan.id)
            }
        }
    }

    /// Replace legacy "Freelancer Vault" labels with clear names.
    private func refreshVaultNamesIfNeeded() throws {
        let demoFP: String? = {
            let outcome = ViewingKeyValidator().validate(
                ViewingKeyValidator.fixtureMainnetUFVK,
                selectedNetwork: .mainnet
            )
            if case let .accept(_, _, _, fingerprint, _) = outcome {
                return fingerprint
            }
            return nil
        }()
        for var v in try store.allVaults() {
            let legacy = v.displayName == "Freelancer Vault"
                || v.displayName == "Receivables Vault"
                || v.displayName.hasPrefix("Freelancer")
            guard legacy else { continue }
            let isDemo = demoFP == v.keyFingerprint
            v.displayName = Self.defaultVaultDisplayName(
                mode: v.mode,
                network: v.network,
                fingerprint: v.keyFingerprint,
                isDemo: isDemo
            )
            try store.upsertVault(v)
        }
    }

    /// Replace receivables vault key with UFVK. New fingerprint is expected (documented).
    private func completeUpgrade(kind: ViewingKeyKind, network: ZcashNetwork, fingerprint: String, mode: VaultMode) {
        guard let current = vault else {
            importError = "No vault to upgrade."
            importAsUpgrade = false
            return
        }
        guard VaultModeBanner.canUpgrade(current: current, newMode: mode, newNetwork: network) else {
            importError = "Upgrade requires a full viewing key (uview…) on the same network. New fingerprint is OK — this replaces the vault key."
            return
        }
        let keyMaterial = importKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
        var upgraded = current
        upgraded.keyKind = kind
        upgraded.keyFingerprint = fingerprint
        upgraded.mode = mode
        upgraded.capabilitiesBanner = nil
        if current.displayName.contains("Incoming") || current.displayName.contains("Receivables") {
            upgraded.displayName = Self.defaultVaultDisplayName(
                mode: .bookkeeper,
                network: network,
                fingerprint: fingerprint,
                isDemo: false
            )
        }
        do {
            try keyStore.save(keyMaterial, for: upgraded.id)
            try store.upsertVault(upgraded)
            vault = upgraded
            vaults = try store.allVaults()
            importKeyText = ""
            importAsUpgrade = false
            importError = nil
            route = .ledger
        } catch {
            importError = error.localizedDescription
        }
    }

    // MARK: - Multi-vault

    public func switchVault(_ id: VaultID) {
        do {
            guard let next = try store.vault(id: id) else { return }
            try store.setActiveVaultID(id)
            vault = next
            notes = try store.notes(vaultID: id)
            cursor = nil
            packDraft = nil
            route = .ledger
            startSync()
        } catch {
            importError = error.localizedDescription
        }
    }

    public func addAnotherVault() {
        importAsUpgrade = false
        goImport()
    }

    // MARK: - Sync

    public func startSync() {
        guard let vault else { return }
        syncTask?.cancel()
        syncTask = Task {
            do {
                if let light = sync as? LightClientSyncFacade {
                    if pendingForceMock || LightClientSyncFacade.envForceMock {
                        await light.setForceMock(true)
                        pendingForceMock = false
                    }
                    if let url = URL(string: lwdURLString) {
                        await light.setLWDURL(url)
                    }
                }
                capabilityReport = await sync.capabilityReport()
                try await sync.start(vaultID: vault.id)
                await pollUntilSettled(vaultID: vault.id)
            } catch {
                cursor = await sync.currentCursor(vaultID: vault.id)
                capabilityReport = await sync.capabilityReport()
                importError = error.localizedDescription
                route = .ledger
            }
        }
    }

    private func pollUntilSettled(vaultID: VaultID) async {
        for _ in 0 ..< 120 {
            guard !Task.isCancelled else { return }
            if let c = await sync.currentCursor(vaultID: vaultID) {
                cursor = c
                if c.status == .caughtUp || c.status == .idle || c.status == .capabilityBlocked {
                    await refreshFromSync()
                    // Do not clobber proof-pack / detail / share routes after E2E or user navigation.
                    if route == .syncing {
                        route = .ledger
                    }
                    return
                }
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        await refreshFromSync()
        if route == .syncing {
            route = .ledger
        }
    }

    public func cancelSync() {
        guard let vault else { return }
        syncTask?.cancel()
        syncTask = Task {
            await sync.cancel(vaultID: vault.id)
            cursor = await sync.currentCursor(vaultID: vault.id)
            await refreshFromSync()
            route = .ledger
        }
    }

    public func refreshFromSync() async {
        guard let vault else { return }
        cursor = await sync.currentCursor(vaultID: vault.id)
        capabilityReport = await sync.capabilityReport()
        var synced = await sync.latestNotes(vaultID: vault.id)
        synced = ClassificationEngine.suggest(
            notes: synced,
            vaultMode: vault.mode,
            keyKind: vault.keyKind
        )
        synced = ClassificationEngine.applyRules(vault.tagRules, to: synced)
        do {
            // Preserve user classifications already in store.
            let existing = try store.notes(vaultID: vault.id)
            var byID: [UUID: NoteRow] = [:]
            var byTxid: [Data: NoteRow] = [:]
            for note in existing {
                byID[note.id.uuid] = note
                byTxid[note.txid] = note
            }
            synced = synced.map { note in
                let prior = byID[note.id.uuid] ?? byTxid[note.txid]
                guard let prior, let c = prior.classification, c.source == .user else {
                    return note
                }
                var n = note
                n.classification = c
                return n
            }
            if cursor?.isDemo == true {
                // Never wipe a good ledger with an empty pre-sync snapshot.
                if !synced.isEmpty {
                    try store.replaceNotes(vaultID: vault.id, with: synced)
                }
            } else {
                try store.upsertNotes(synced)
            }
            notes = try store.notes(vaultID: vault.id)
        } catch {
            importError = error.localizedDescription
        }
    }

    public func syncNow() {
        startSync()
        if route != .syncing {
            route = .syncing
        }
    }

    public func refreshCapability() async {
        capabilityReport = await sync.capabilityReport()
    }

    // MARK: - Tag rules

    public func saveTagRules(_ rules: [TagRule]) {
        guard var vault else { return }
        vault.tagRules = rules
        do {
            try store.upsertVault(vault)
            self.vault = vault
            vaults = try store.allVaults()
            notes = ClassificationEngine.applyRules(rules, to: notes)
            try store.upsertNotes(notes)
            notes = try store.notes(vaultID: vault.id)
        } catch {
            importError = error.localizedDescription
        }
    }

    public func addTagRule(_ rule: TagRule) {
        guard let vault else { return }
        var rules = vault.tagRules
        rules.append(rule)
        saveTagRules(rules)
    }

    public func deleteTagRule(id: UUID) {
        guard let vault else { return }
        saveTagRules(vault.tagRules.filter { $0.id != id })
    }

    // MARK: - Ledger

    public var filteredNotes: [NoteRow] {
        notes.filter { note in
            if filters.untaggedOnly, note.effectiveKind != .untagged {
                return false
            }
            if let kind = filters.kind, note.effectiveKind != kind {
                return false
            }
            if let year = filters.year, let date = note.blockTime {
                if Calendar.current.component(.year, from: date) != year {
                    return false
                }
            }
            let q = filters.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !q.isEmpty {
                let hay = [
                    note.memo.displayText,
                    note.classification?.party,
                    note.classification?.subtag,
                    note.txidTruncated
                ]
                .compactMap { $0?.lowercased() }
                .joined(separator: " ")
                if !hay.contains(q) {
                    return false
                }
            }
            return true
        }
    }

    public var untaggedCount: Int {
        notes.filter { $0.effectiveKind == .untagged }.count
    }

    public var incomeYTD: Decimal {
        ClassificationEngine.incomeYTD(notes: notes, year: Calendar.current.component(.year, from: Date()))
    }

    public var expenseYTD: Decimal {
        ClassificationEngine.expenseYTD(notes: notes, year: Calendar.current.component(.year, from: Date()))
    }

    public var showsIVKUpgradeBanner: Bool {
        guard let vault else { return false }
        return VaultModeBanner.shouldShowUpgradeBanner(mode: vault.mode)
    }

    public func openNote(_ id: NoteRowID) {
        route = .noteDetail(id)
    }

    public func selectedNote(_ id: NoteRowID) -> NoteRow? {
        notes.first { $0.id == id }
    }

    public func saveNote(_ note: NoteRow) {
        guard let vault else { return }
        var updated = note
        if var classification = updated.classification {
            classification.updatedAt = Date()
            classification.source = .user
            updated.classification = classification
        }
        do {
            try store.upsertNotes([updated])
            notes = try store.notes(vaultID: vault.id)
            route = .ledger
        } catch {
            importError = error.localizedDescription
        }
    }

    // MARK: - Proof packs

    public func beginProofPack() {
        guard vault != nil else { return }
        packDraft = nil
        acknowledgePartialHistory = false
        route = .proofPackBuilder
    }

    public func setPackDraft(_ draft: ProofPackDraft) {
        packDraft = draft
    }

    public func proceedToSharePack() {
        route = .sharePack
    }

    public func recordShareHistory(
        format: ShareExportFormat,
        integrityHash: String?,
        rowCount: Int,
        expiresAt: Date?
    ) {
        guard let draft = packDraft else { return }
        let entry = ShareHistoryEntry(
            expiresAt: expiresAt,
            recipientLabel: draft.recipientLabel,
            rangeStart: draft.rangeStart,
            rangeEnd: draft.rangeEnd,
            integrityHash: integrityHash,
            format: format,
            rowCount: rowCount,
            vaultFingerprint: draft.vaultFingerprint
        )
        do {
            try store.appendShareHistory(entry)
            shareHistory = try store.shareHistory()
        } catch {
            importError = error.localizedDescription
        }
    }

    public func savePack(passphrase: String, to url: URL) throws {
        guard var draft = packDraft else { throw SaneBooksError.pack("No pack draft") }
        draft.acknowledgePartialHistory = acknowledgePartialHistory
        packDraft = draft
        let encoded = try PackWriter.seal(draft: draft, passphrase: passphrase)
        try encoded.data.write(to: url, options: .atomic)
        lastIntegrityHash = encoded.integrityHash
        lastSavedPackURL = url
        recordShareHistory(
            format: .sanebooks,
            integrityHash: encoded.integrityHash,
            rowCount: draft.rows.count,
            expiresAt: draft.expiresAt
        )
    }

    public func exportCSV(to url: URL) throws {
        guard let draft = packDraft else { throw SaneBooksError.pack("No pack draft") }
        let csv = CSVExporter.export(rows: draft.rows, includeMemos: draft.includeMemos)
        try csv.write(to: url, atomically: true, encoding: .utf8)
        lastSavedPackURL = url
        recordShareHistory(
            format: .csv,
            integrityHash: lastIntegrityHash,
            rowCount: draft.rows.count,
            expiresAt: draft.expiresAt
        )
    }

    public func exportPDF(to url: URL) throws {
        guard var draft = packDraft else { throw SaneBooksError.pack("No pack draft") }
        draft.acknowledgePartialHistory = acknowledgePartialHistory
        packDraft = draft
        if draft.partialHistory, !draft.acknowledgePartialHistory {
            throw SaneBooksError.pack(
                "Partial history not acknowledged. Sync is incomplete or history may be missing — acknowledge before exporting."
            )
        }
        let hash = lastIntegrityHash ?? "unsealed"
        let data = PDFSummaryExporter.export(draft: draft, integrityHash: hash)
        try data.write(to: url, options: .atomic)
        lastSavedPackURL = url
        recordShareHistory(
            format: .pdf,
            integrityHash: hash == "unsealed" ? nil : hash,
            rowCount: draft.rows.count,
            expiresAt: draft.expiresAt
        )
    }

    // MARK: - Reader

    public func openPack(url: URL, passphrase: String) {
        readerError = nil
        do {
            let data = try Data(contentsOf: url)
            readerResult = try PackReader.open(data, passphrase: passphrase)
        } catch let err as SaneBooksError {
            readerError = err.userFacingMessage
        } catch {
            readerError = error.localizedDescription
        }
    }

    public func exportReaderPDF(to url: URL) throws {
        guard let result = readerResult else { throw SaneBooksError.pack("No open pack") }
        let draft = ProofPackDraft(
            vaultFingerprint: result.header.vaultFingerprint,
            vaultDisplayName: result.header.vaultDisplayName,
            network: result.header.network,
            rangeStart: result.header.rangeStart,
            rangeEnd: result.header.rangeEnd,
            rows: result.payload.rows,
            rollups: result.payload.rollups,
            syncAttestation: result.payload.attestation,
            partialHistory: result.header.partialHistory,
            acknowledgePartialHistory: true,
            recipientLabel: result.header.recipientLabel,
            expiresAt: result.header.expiresAt,
            vaultMode: result.header.vaultMode
        )
        let data = PDFSummaryExporter.export(
            draft: draft,
            integrityHash: result.payload.integrity.plaintextCanonicalHash
        )
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Vault management

    public func removeVault() {
        guard let vault else { return }
        syncTask?.cancel()
        Task {
            await sync.cancel(vaultID: vault.id)
        }
        do {
            try keyStore.delete(for: vault.id)
            try store.deleteVault(id: vault.id)
            vaults = try store.allVaults()
            shareHistory = try store.shareHistory()
            if let next = vaults.first {
                try store.setActiveVaultID(next.id)
                self.vault = next
                notes = try store.notes(vaultID: next.id)
                route = .ledger
            } else {
                self.vault = nil
                notes = []
                cursor = nil
                packDraft = nil
                route = .welcome
            }
        } catch {
            importError = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func parseBirthday(_ text: String) -> UInt32? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let height = UInt32(trimmed) {
            return height
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        if formatter.date(from: trimmed) != nil {
            return MockSyncFacade.birthdayDefault
        }
        return nil
    }
}
