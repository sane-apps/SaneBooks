import AppKit
import Foundation
@testable import SaneBooksCore
@testable import SaneBooksFeature
import Testing

@MainActor
@Suite("AppModel failure boundaries")
struct AppModelFailureTests {
    private var projectRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    @Test
    func doubleFailureReportsPossibleOrphanedKeychainEntryTruthfully() throws {
        let ledger = CommitFailingLedgerStore()
        let keys = RollbackFailingViewingKeyStore()
        let model = AppModel(store: ledger, keyStore: keys)
        let vault = Vault(
            displayName: "Failure fixture",
            network: .mainnet,
            keyKind: .ufvk,
            keyFingerprint: "uview:failure",
            mode: .bookkeeper
        )

        do {
            try model.commitKeyAndVault(keyMaterial: "uview-fixture", vault: vault)
            Issue.record("Expected the ledger commit and Keychain rollback to fail")
        } catch {
            let message = error.localizedDescription
            #expect(message.contains("viewing-key entry may remain"))
            #expect(message.contains("contact private support"))
            #expect(!message.contains("No key material was exposed"))
        }

        #expect(keys.savedValue == "uview-fixture")
        #expect(keys.deleteAttempted)
    }

    @Test
    func userEvidenceFieldsRejectDirectionalSpoofingBeforePersistence() throws {
        let store = InMemoryLedgerStore()
        let vault = Vault(
            displayName: "Evidence fixture",
            network: .mainnet,
            keyKind: .ufvk,
            keyFingerprint: "uview:evidence",
            mode: .bookkeeper
        )
        let note = NoteRow(
            vaultID: vault.id,
            txid: Data(repeating: 0x42, count: 32),
            blockHeight: 1,
            pool: .orchard,
            direction: .inbound,
            valueZatoshis: 1
        )
        try store.upsertVault(vault)
        try store.upsertNotes([note])
        let model = AppModel(store: store)
        model.reloadFromStore()
        var spoofed = note
        spoofed.classification = Classification(kind: .income, party: "Acme\u{202E}gpj")

        model.saveNote(spoofed)

        #expect(model.importError?.contains("unsafe controls") == true)
        #expect(try store.notes(vaultID: vault.id).first?.classification == nil)
    }

    @Test
    func dependencySelectionAndProductionCryptoInputsAreExplicit() throws {
        let manifest = try String(
            contentsOf: projectRootURL.appendingPathComponent("SaneBooksPackage/Package.swift"),
            encoding: .utf8
        )
        let project = try String(
            contentsOf: projectRootURL.appendingPathComponent("project.yml"),
            encoding: .utf8
        )
        let writer = try String(
            contentsOf: projectRootURL.appendingPathComponent(
                "SaneBooksPackage/Sources/SaneBooksExport/PackWriter.swift"
            ),
            encoding: .utf8
        )

        #expect(!manifest.contains("fileExists"))
        #expect(!manifest.contains("SANEBOOKS_USE_LOCAL_SANEUI"))
        #expect(manifest.contains("0894c053345a86b549ea1ee329a4ff3b20826061"))
        #expect(!project.contains("path: ../../infra/SaneUI"))
        let publicStart = try #require(writer.range(of: "public static func seal("))
        let publicTail = writer[publicStart.lowerBound...]
        let publicEnd = try #require(publicTail.range(of: ") throws -> EncodedPack"))
        let publicSignature = publicTail[..<publicEnd.upperBound]
        #expect(!publicSignature.contains("salt:"))
        #expect(!publicSignature.contains("nonceData:"))
        #expect(writer.contains("Deterministic crypto inputs are intentionally module-internal"))
    }
}

@MainActor
@Suite("Onboarding disclosure and persistence")
struct OnboardingDisclosureTests {
    private var projectRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    @Test
    func resumesAndCompletesOnlyThroughDeliberateUserRoutes() throws {
        let suite = "SaneBooksOnboardingTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = AppModel(settingsDefaults: defaults)
        #expect(first.route == .onboarding)
        #expect(!first.hasCompletedOnboarding)
        #expect(first.onboardingPage == 0)

        first.advanceOnboarding()
        #expect(first.onboardingPage == 1)
        #expect(!first.hasCompletedOnboarding)

        let resumed = AppModel(settingsDefaults: defaults)
        #expect(resumed.onboardingPage == 1)
        #expect(!resumed.hasCompletedOnboarding)
        resumed.completeOnboardingForReader()
        #expect(resumed.hasCompletedOnboarding)
        #expect(resumed.onboardingPage == 0)
        #expect(resumed.route == .reader)

        let relaunched = AppModel(settingsDefaults: defaults)
        relaunched.reloadFromStore()
        #expect(relaunched.hasCompletedOnboarding)
        #expect(relaunched.route == .welcome)

        relaunched.restartOnboarding()
        relaunched.advanceOnboarding()
        relaunched.advanceOnboarding()
        relaunched.completeOnboardingForOwner()
        #expect(relaunched.route == .importKey)
    }

    @Test
    func usesNoTrackingAndStatesEveryCriticalDisclosureInPlainLanguage() throws {
        let source = try String(
            contentsOf: projectRootURL.appendingPathComponent(
                "SaneBooksPackage/Sources/SaneBooksFeature/Views/WelcomeView.swift"
            ),
            encoding: .utf8
        )

        #expect(!source.contains("EventTracker"))
        for disclosure in [
            "It cannot send or spend your ZEC",
            "Never enter recovery words or a spending key",
            "That server can see your internet address and may return incomplete data",
            "choose your own server in Settings",
            "does not upload your ledger or track how you use the app",
            "never guesses a past exchange rate",
            "only you can confirm who it came from",
            "SaneBooks cannot protect them after you save or send them",
        ] {
            #expect(source.contains(disclosure))
        }
    }
}

private enum InjectedFailure: Error {
    case ledgerCommit
    case keychainDelete
}

private final class RollbackFailingViewingKeyStore: ViewingKeyStore, @unchecked Sendable {
    private(set) var savedValue: String?
    private(set) var deleteAttempted = false

    func save(_ key: String, for _: VaultID) throws {
        savedValue = key
    }

    func load(for _: VaultID) throws -> String? {
        nil
    }

    func delete(for _: VaultID) throws {
        deleteAttempted = true
        throw InjectedFailure.keychainDelete
    }
}

private final class CommitFailingLedgerStore: LedgerStore, @unchecked Sendable {
    private let backing = InMemoryLedgerStore()

    func upsertVault(_ vault: Vault) throws {
        try backing.upsertVault(vault)
    }

    func vault(id: VaultID) throws -> Vault? {
        try backing.vault(id: id)
    }

    func allVaults() throws -> [Vault] {
        try backing.allVaults()
    }

    func deleteVault(id: VaultID) throws {
        try backing.deleteVault(id: id)
    }

    func upsertNotes(_ notes: [NoteRow]) throws {
        try backing.upsertNotes(notes)
    }

    func replaceNotes(vaultID: VaultID, with notes: [NoteRow]) throws {
        try backing.replaceNotes(vaultID: vaultID, with: notes)
    }

    func notes(vaultID: VaultID) throws -> [NoteRow] {
        try backing.notes(vaultID: vaultID)
    }

    func upsertClassification(noteID: NoteRowID, classification: Classification) throws {
        try backing.upsertClassification(noteID: noteID, classification: classification)
    }

    func appendShareHistory(_ entry: ShareHistoryEntry) throws {
        try backing.appendShareHistory(entry)
    }

    func shareHistory() throws -> [ShareHistoryEntry] {
        try backing.shareHistory()
    }

    func setActiveVaultID(_ id: VaultID?) throws {
        try backing.setActiveVaultID(id)
    }

    func activeVaultID() throws -> VaultID? {
        try backing.activeVaultID()
    }

    func commitVault(_: Vault, replacingNotes _: [NoteRow]?) throws {
        throw InjectedFailure.ledgerCommit
    }
}

@Suite("Appearance accessibility")
struct AppearanceAccessibilityTests {
    @Test
    func allTextPalettePairsMeetWCAGAA() throws {
        let pairs: [(name: String, foreground: NSColor, background: NSColor)] = [
            ("white on ink", .white, NSColor(SaneBooksTheme.ink)),
            ("white on elevated ink", .white, NSColor(SaneBooksTheme.inkElevated)),
            ("gold on ink", NSColor(SaneBooksTheme.gold), NSColor(SaneBooksTheme.ink)),
            ("soft gold on elevated ink", NSColor(SaneBooksTheme.goldSoft), NSColor(SaneBooksTheme.inkElevated)),
            ("ivory on mid ink", NSColor(SaneBooksTheme.pageIvory.opacity(0.9)), NSColor(SaneBooksTheme.inkMid)),
            ("orange on ink", .systemOrange, NSColor(SaneBooksTheme.ink)),
            ("red on ink", .systemRed, NSColor(SaneBooksTheme.ink)),
        ]

        for pair in pairs {
            let ratio = try contrastRatio(foreground: pair.foreground, background: pair.background)
            #expect(ratio >= 4.5, "\(pair.name) contrast was only \(ratio):1")
        }
    }

    private func contrastRatio(foreground: NSColor, background: NSColor) throws -> Double {
        let foreground = try #require(foreground.usingColorSpace(.sRGB))
        let background = try #require(background.usingColorSpace(.sRGB))
        let alpha = foreground.alphaComponent
        let channels = [
            foreground.redComponent * alpha + background.redComponent * (1 - alpha),
            foreground.greenComponent * alpha + background.greenComponent * (1 - alpha),
            foreground.blueComponent * alpha + background.blueComponent * (1 - alpha),
        ]
        let backgroundChannels = [
            background.redComponent,
            background.greenComponent,
            background.blueComponent,
        ]
        let light = relativeLuminance(channels)
        let dark = relativeLuminance(backgroundChannels)
        return (max(light, dark) + 0.05) / (min(light, dark) + 0.05)
    }

    private func relativeLuminance(_ channels: [CGFloat]) -> Double {
        let linear = channels.map { channel -> Double in
            let component = Double(channel)
            return component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    }
}
