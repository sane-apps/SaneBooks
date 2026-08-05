import CryptoKit
import Foundation
import Observation
import SaneBooksCore
import SaneBooksExport
import SaneBooksSync

public enum AppRoute: Equatable, Sendable {
    case onboarding
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
    public var route: AppRoute = .onboarding
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
    public var startupError: String?
    public internal(set) var isEphemeralTestSession = false
    public var importKeyText: String = ""
    public var importNetwork: ZcashNetwork = .mainnet
    public var importBirthdayText: String = ""
    public var filters = LedgerFilters()
    public var showWhatIsViewingKey = false
    public var showDegradedConfirm = false
    public var shareHistory: [ShareHistoryEntry] = []
    public var acknowledgePartialHistory = false
    public var capabilityReport: CapabilityReport?
    public var lwdURLString: String = "https://zec.rocks:443" {
        didSet { settingsDefaults.set(lwdURLString, forKey: SettingsKey.lwdURL) }
    }

    /// When true, import replaces the active receivables vault key (UFVK upgrade).
    public var importAsUpgrade = false
    public var showBirthdayHelp = false
    /// When true, next sync uses Mock path on LightClientSyncFacade (demo fixture).
    var pendingForceMock = false

    /// Settings
    public var defaultPackExpiryDays = 90 {
        didSet { settingsDefaults.set(defaultPackExpiryDays, forKey: SettingsKey.defaultPackExpiryDays) }
    }

    public var includeMemosByDefault = false {
        didSet { settingsDefaults.set(includeMemosByDefault, forKey: SettingsKey.includeMemosByDefault) }
    }

    public var truncateTxidsInUI = true {
        didSet { settingsDefaults.set(truncateTxidsInUI, forKey: SettingsKey.truncateTxidsInUI) }
    }

    /// Pendrake-style screen-share mode: hide ZEC/USD amounts in the ledger UI.
    public var discreetMode = false {
        didSet { settingsDefaults.set(discreetMode, forKey: SettingsKey.discreetMode) }
    }

    /// macOS does not apply SwiftUI Dynamic Type to text, so SaneBooks offers
    /// an explicit app-level text size that is honored across core journeys.
    public var textSize: SaneBooksTextSize = .standard {
        didSet { settingsDefaults.set(textSize.rawValue, forKey: SettingsKey.textSize) }
    }

    /// A versioned local disclosure gate. Completion is recorded only when the
    /// person deliberately starts the owner flow or opens the accountant Reader.
    public internal(set) var hasCompletedOnboarding = false {
        didSet { settingsDefaults.set(hasCompletedOnboarding, forKey: SettingsKey.hasCompletedOnboarding) }
    }

    /// Resumes an interrupted first-run explanation without recording analytics.
    public internal(set) var onboardingPage = 0 {
        didSet { settingsDefaults.set(onboardingPage, forKey: SettingsKey.onboardingPage) }
    }

    /// Prefill for proof-pack recipient label (CPA name).
    public var defaultRecipientLabel = "Accountant — Acme CPA" {
        didSet { settingsDefaults.set(defaultRecipientLabel, forKey: SettingsKey.defaultRecipientLabel) }
    }

    let store: any LedgerStore
    let keyStore: any ViewingKeyStore
    let sync: any SyncFacade
    private let validator = ViewingKeyValidator()
    var settingsDefaults: UserDefaults
    private var pendingImportAccept: ViewingKeyValidationOutcome?
    var syncTask: Task<Void, Never>?
    var activeSyncVaultID: VaultID?
    public internal(set) var isZashiDatabaseImportInProgress = false
    var zashiDatabaseImportTask: Task<Void, Never>?
    var zashiDatabaseImportID: UUID?
    var zashiDatabaseImportCancellation: ImportCancellation?
    var zashiDatabaseImportCompletion: (() -> Void)?

    /// Test / preview default: in-memory store + mock sync (no Keychain).
    public init(
        store: any LedgerStore = InMemoryLedgerStore(),
        keyStore: any ViewingKeyStore = InMemoryViewingKeyStore(),
        sync: any SyncFacade = MockSyncFacade(),
        settingsDefaults: UserDefaults = .standard
    ) {
        self.store = store
        self.keyStore = keyStore
        self.sync = sync
        self.settingsDefaults = settingsDefaults
        loadPersistedSettings()
    }

    // MARK: - Navigation

    public func advanceOnboarding() {
        onboardingPage = min(onboardingPage + 1, 2)
    }

    public func retreatOnboarding() {
        onboardingPage = max(onboardingPage - 1, 0)
    }

    public func restartOnboarding() {
        onboardingPage = 0
        route = .onboarding
    }

    public func completeOnboardingForOwner() {
        hasCompletedOnboarding = true
        onboardingPage = 0
        goImport()
    }

    public func completeOnboardingForReader() {
        hasCompletedOnboarding = true
        onboardingPage = 0
        goReader()
    }

    public func goWelcome() {
        clearPendingImport()
        route = .welcome
    }

    public func goImport(asUpgrade: Bool = false) {
        clearPendingImport()
        importAsUpgrade = asUpgrade
        route = .importKey
    }

    public func cancelImport() {
        let returnsToLedger = importAsUpgrade && vault != nil
        clearPendingImport()
        route = returnsToLedger ? .ledger : .welcome
    }

    private func clearPendingImport() {
        cancelZashiSDKDatabaseImport()
        importKeyText = ""
        importBirthdayText = ""
        importError = nil
        pendingImportAccept = nil
        showDegradedConfirm = false
        importAsUpgrade = false
        pendingForceMock = false
    }

    public func goReader() {
        readerResult = nil
        readerError = nil
        route = .reader
    }

    /// Offline fixture ledger (mock sync). Used by E2E scenes and the offline demo button.
    public func useDemoKey() {
        importKeyText = ViewingKeyValidator.fixtureMainnetUFVK
        importNetwork = .mainnet
        importBirthdayText = ""
        importError = nil
        pendingForceMock = true
    }

    /// Real ECC SDK mainnet UFVK → live lightwalletd sync (no mock).
    public func useLiveProbeKey() {
        importKeyText = ViewingKeyValidator.liveProbeMainnetUFVK
        importNetwork = .mainnet
        importBirthdayText = String(LiveProbeKey.defaultBirthday)
        importError = nil
        pendingForceMock = false
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
            let normalized = importKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
            let isFixture = normalized == ViewingKeyValidator.fixtureMainnetUFVK
                || normalized == ViewingKeyValidator.fixtureTestnetUFVK
            guard pendingForceMock || isFixture
                || LinkedZcashSDK.isValidViewingKey(normalized, kind: kind, network: network)
            else {
                importError = "That viewing key failed the Zcash SDK checksum or network check. Nothing was imported."
                return
            }
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
        importKeyText = ""
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
                try commitKeyAndVault(keyMaterial: keyMaterial, vault: existing)
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
            try commitKeyAndVault(keyMaterial: keyMaterial, vault: newVault)
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

    /// Replace legacy "Freelancer Vault" labels with clear names.
    func refreshVaultNamesIfNeeded() throws {
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
            importError = "Upgrade needs a full viewing key on the same network. Your books stay; only the key is replaced."
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
            try commitKeyAndVault(keyMaterial: keyMaterial, vault: upgraded)
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

    func commitKeyAndVault(
        keyMaterial: String,
        vault: Vault,
        replacingNotes: [NoteRow]? = nil
    ) throws {
        let previousKey = try keyStore.load(for: vault.id)
        try keyStore.save(keyMaterial, for: vault.id)
        do {
            try store.commitVault(vault, replacingNotes: replacingNotes)
        } catch {
            do {
                if let previousKey {
                    try keyStore.save(previousKey, for: vault.id)
                } else {
                    try keyStore.delete(for: vault.id)
                }
            } catch let rollbackError {
                throw SaneBooksError.persistFailed(
                    "Vault import failed, and ZecBooks could not restore the previous Keychain entry. "
                        + "A viewing-key entry may remain in this Mac's Keychain. Close ZecBooks and "
                        + "contact private support before retrying. (Cleanup error: "
                        + "\(rollbackError.localizedDescription))"
                )
            }
            throw error
        }
    }
}
