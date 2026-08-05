import Foundation
import PDFKit
@testable import SaneBooksCore
@testable import SaneBooksExport
@testable import SaneBooksFeature
@testable import SaneBooksSync
import Testing

@MainActor
@Suite("AppModel safety and settings")
struct AppModelTests {
    private func isolatedDefaults() throws -> (defaults: UserDefaults, suite: String) {
        let suite = "SaneBooksTests.\(UUID().uuidString)"
        return try (#require(UserDefaults(suiteName: suite)), suite)
    }

    private var projectRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func runProjectCommand(_ arguments: [String]) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = projectRootURL.appendingPathComponent("scripts/SaneMaster.rb")
        process.arguments = arguments
        process.currentDirectoryURL = projectRootURL
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        try process.run()
        process.waitUntilExit()
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    private func proofPackDraft() -> ProofPackDraft {
        let row = ProofPackRow(
            date: Date(timeIntervalSince1970: 1_770_000_000),
            kind: .income,
            party: "Client",
            amountZEC: 1.5,
            pool: .ironwood,
            txidTruncated: "aabbccdd…11223344"
        )
        let attestation = SyncAttestation(
            syncedToHeight: 3_500_000,
            chainTipAtExport: 3_500_000,
            lwdEndpointFingerprint: "sha256:deadbeef",
            vaultMode: .bookkeeper,
            poolsPresent: [.ironwood],
            ironwoodCapable: true
        )
        return ProofPackDraft(
            vaultFingerprint: "uview:a1b2c3d4e5f60708",
            vaultDisplayName: "Freelancer",
            network: .mainnet,
            rangeStart: Date(timeIntervalSince1970: 1_700_000_000),
            rangeEnd: Date(timeIntervalSince1970: 1_800_000_000),
            rows: [row],
            rollups: ProofPackRollups(incomeZEC: 1.5, byCategory: ["Client": 1.5]),
            syncAttestation: attestation,
            partialHistory: false,
            expiresAt: Date(timeIntervalSinceNow: 86400),
            vaultMode: .bookkeeper
        )
    }

    @Test
    func transactionEditorSupportsEveryPersistedClassification() {
        #expect(TransactionDetailView.editableKinds == ClassificationKind.allCases)
    }

    @Test
    func directDownloadAboutUsesTheVerifiedGitHubSponsorsDestination() throws {
        let url = SaneBooksAboutView.donationURL
        #expect(url.scheme == "https")
        #expect(url.host == "github.com")
        #expect(url.path == "/sponsors/MrSaneApps")

        let manifest = try String(
            contentsOf: projectRootURL.appendingPathComponent(".saneprocess"),
            encoding: .utf8
        )
        #expect(manifest.contains("appstore:\n  enabled: false"))
    }

    @Test
    func mockAndNoKeychainLaunchesAlwaysUseEphemeralKeyStorage() {
        #expect(AppModel.shouldUseEphemeralKeyStore(
            environment: ["SANEBOOKS_FORCE_MOCK": "1"],
            arguments: []
        ))
        #expect(AppModel.shouldUseEphemeralKeyStore(
            environment: ["SANEAPPS_DISABLE_KEYCHAIN": "1"],
            arguments: []
        ))
        #expect(AppModel.shouldUseEphemeralKeyStore(
            environment: [:],
            arguments: ["SaneBooks", "--sane-no-keychain"]
        ))
        #expect(!AppModel.shouldUseEphemeralKeyStore(
            environment: [:],
            arguments: ["SaneBooks"]
        ))

        let forcedMock = AppModel.makeProduction(
            environment: ["SANEBOOKS_FORCE_MOCK": "1"],
            arguments: ["SaneBooks"]
        )
        #expect(forcedMock.store is InMemoryLedgerStore)
        #expect(forcedMock.keyStore is InMemoryViewingKeyStore)
        #expect(forcedMock.sync is MockSyncFacade)
        #expect(forcedMock.isEphemeralTestSession)

        let noKeychain = AppModel.makeProduction(
            environment: ["SANEAPPS_DISABLE_KEYCHAIN": "1"],
            arguments: ["SaneBooks", "--sane-no-keychain"]
        )
        #expect(noKeychain.store is InMemoryLedgerStore)
        #expect(noKeychain.keyStore is InMemoryViewingKeyStore)
        #expect(noKeychain.isEphemeralTestSession)
    }

    @Test
    func cancelingQueuedZashiImportLeavesLedgerUnchanged() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SaneBooksCancelledImport-\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data().write(to: url)

        let store = InMemoryLedgerStore()
        let model = AppModel(store: store)
        var completionCount = 0
        model.importZashiSDKDatabase(at: url) {
            completionCount += 1
        }
        #expect(model.isZashiDatabaseImportInProgress)

        model.cancelImport()
        await Task.yield()

        #expect(!model.isZashiDatabaseImportInProgress)
        #expect(try store.allVaults().isEmpty)
        #expect(model.vault == nil)
        #expect(model.notes.isEmpty)
        #expect(model.route == .welcome)
        #expect(completionCount == 0)
    }

    @Test
    func legacyEvidenceScriptsCannotDeleteProductionStateOrBypassCanonicalTests() throws {
        for name in ["mini-zashi-e2e-scenes.sh", "live-probe-after-fund.sh"] {
            let url = projectRootURL.appendingPathComponent("scripts/\(name)")
            let source = try String(contentsOf: url, encoding: .utf8)
            #expect(!source.contains("rm -rf"))
            #expect(!source.contains("open -a"))
            #expect(!source.contains("swift test"))
            #expect(source.contains("./scripts/SaneMaster.rb verify"))
            #expect(source.contains("SANEAPPS_DISABLE_KEYCHAIN=1") || name == "live-probe-after-fund.sh")
        }
    }

    @Test
    func releaseBuildCannotActivateTheE2EControlPlane() throws {
        let e2eSource = try String(
            contentsOf: projectRootURL.appendingPathComponent(
                "SaneBooksPackage/Sources/SaneBooksFeature/ViewModels/AppModel+E2E.swift"
            ),
            encoding: .utf8
        )
        let appSource = try String(
            contentsOf: projectRootURL.appendingPathComponent("SaneBooks/SaneBooksApp.swift"),
            encoding: .utf8
        )
        let lifecycleSource = try String(
            contentsOf: projectRootURL.appendingPathComponent(
                "SaneBooksPackage/Sources/SaneBooksFeature/ViewModels/AppModel+Lifecycle.swift"
            ),
            encoding: .utf8
        )

        let e2eDebug = try #require(e2eSource.range(of: "#if DEBUG"))
        let e2eExtension = try #require(e2eSource.range(of: "public extension AppModel"))
        let e2eEnd = try #require(e2eSource.range(of: "#endif", options: .backwards))
        #expect(e2eDebug.lowerBound < e2eExtension.lowerBound)
        #expect(e2eExtension.lowerBound < e2eEnd.lowerBound)

        let appDebug = try #require(appSource.range(of: "#if DEBUG"))
        let appControl = try #require(appSource.range(of: "model.applyE2ESceneIfNeeded()"))
        let appEnd = try #require(appSource.range(of: "#endif", range: appControl.lowerBound ..< appSource.endIndex))
        #expect(appDebug.lowerBound < appControl.lowerBound)
        #expect(appControl.lowerBound < appEnd.lowerBound)

        let releaseBranch = try #require(lifecycleSource.range(of: "#else"))
        let disabledMock = try #require(lifecycleSource.range(of: "let forceMock = false"))
        #expect(releaseBranch.lowerBound < disabledMock.lowerBound)
        #expect(lifecycleSource.contains("let useEphemeralTestState = false"))
    }

    @Test
    func githubReleaseLaneIsEnabledAndAppStoreStaysFailClosed() throws {
        let manifest = try String(
            contentsOf: projectRootURL.appendingPathComponent(".saneprocess"),
            encoding: .utf8
        )
        #expect(manifest.contains("github_repo: sane-apps/SaneBooks"))
        #expect(manifest.contains("use_sparkle: true"))
        #expect(manifest.contains("site_host: zecbooks.app"))
        #expect(manifest.contains("dist_host: dist.zecbooks.app"))
        #expect(manifest.contains("website_domain: zecbooks.app"))
        #expect(
            manifest.range(of: #"release:\s*\n(?:[ \t]+.+\n)*[ \t]+enabled: true"#, options: .regularExpression) != nil
        )
        #expect(
            manifest.range(of: #"appstore:\s*\n(?:[ \t]+.+\n)*[ \t]+enabled: false"#, options: .regularExpression) != nil
        )

        let wrapper = try String(
            contentsOf: projectRootURL.appendingPathComponent("scripts/SaneMaster.rb"),
            encoding: .utf8
        )
        #expect(wrapper.contains("appstore.enabled: false"))
        #expect(wrapper.contains("exit 78"))
    }

    @Test
    func debugAndUITestSigningStayAdHocAndDoNotConsultDeveloperKeychain() throws {
        let project = try String(
            contentsOf: projectRootURL.appendingPathComponent("project.yml"),
            encoding: .utf8
        )
        #expect(project.contains("CODE_SIGN_STYLE: Manual"))
        #expect(project.contains("CODE_SIGN_IDENTITY: \"-\""))
        #expect(project.contains("PROVISIONING_PROFILE_SPECIFIER: \"\""))
        #expect(project.contains("DEVELOPMENT_TEAM: \"\""))
    }

    @Test
    func settingsPersistAcrossModelRelaunch() throws {
        let isolated = try isolatedDefaults()
        let defaults = isolated.defaults
        defer { defaults.removePersistentDomain(forName: isolated.suite) }

        let chosenExpiryDays = 180
        let first = AppModel(settingsDefaults: defaults)
        first.defaultPackExpiryDays = chosenExpiryDays
        first.includeMemosByDefault = true
        first.truncateTxidsInUI = false
        first.discreetMode = true
        first.textSize = .extraLarge
        first.defaultRecipientLabel = "Example CPA"
        first.lwdURLString = "https://example.invalid:443"

        let relaunched = AppModel(settingsDefaults: defaults)
        #expect(relaunched.defaultPackExpiryDays == chosenExpiryDays)
        #expect(relaunched.includeMemosByDefault)
        #expect(!relaunched.truncateTxidsInUI)
        #expect(relaunched.discreetMode)
        #expect(relaunched.textSize == .extraLarge)
        #expect(relaunched.defaultRecipientLabel == "Example CPA")
        #expect(relaunched.lwdURLString == "https://example.invalid:443")
    }

    @Test
    func beginningNewPackClearsPriorArtifactReceipt() throws {
        let store = InMemoryLedgerStore()
        let vault = Vault(
            displayName: "Test",
            network: .mainnet,
            keyKind: .ufvk,
            keyFingerprint: "uview:test",
            mode: .bookkeeper
        )
        try store.upsertVault(vault)
        try store.setActiveVaultID(vault.id)
        let isolated = try isolatedDefaults()
        defer { isolated.defaults.removePersistentDomain(forName: isolated.suite) }
        let model = AppModel(store: store, settingsDefaults: isolated.defaults)
        model.reloadFromStore()
        model.lastIntegrityHash = "old-file-hash"
        model.lastSavedPackURL = URL(fileURLWithPath: "/tmp/old.csv")

        model.beginProofPack()

        #expect(model.lastIntegrityHash == nil)
        #expect(model.lastSavedPackURL == nil)
        #expect(model.route == .proofPackBuilder)
    }

    @Test
    func ownerPDFExportWritesValidFileThenRecordsItsFileDigest() throws {
        let store = InMemoryLedgerStore()
        let model = AppModel(store: store)
        model.setPackDraft(proofPackDraft())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SaneBooksOwner-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }

        try model.exportPDF(to: url)

        let data = try Data(contentsOf: url)
        #expect(data.starts(with: Data("%PDF".utf8)))
        let document = try #require(PDFDocument(data: data))
        let text = try #require(document.string)
        #expect(!text.contains("sha256:pending"))
        #expect(!text.contains("canonical plaintext payload"))
        #expect(model.lastSavedPackURL == url)
        let expectedDigestHexLength = 32 * 2
        #expect(model.lastIntegrityHash?.count == expectedDigestHexLength)
        let history = try store.shareHistory()
        #expect(history.count == 1)
        #expect(history.first?.format == .pdf)
        #expect(history.first?.integrityHash == model.lastIntegrityHash)
    }

    @Test
    func invalidOwnerPDFCannotOverwriteOrCreateHistoryReceipt() throws {
        let store = InMemoryLedgerStore()
        let model = AppModel(store: store)
        let draft = proofPackDraft()
        model.setPackDraft(draft)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SaneBooksOwnerInvalid-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        let existing = Data("existing file".utf8)
        try existing.write(to: url)

        #expect(throws: SaneBooksError.pack("Could not create a valid PDF summary.")) {
            try model.persistOwnerPDFExport(Data(), draft: draft, to: url)
        }

        #expect(try Data(contentsOf: url) == existing)
        #expect(model.lastIntegrityHash == nil)
        #expect(model.lastSavedPackURL == nil)
        #expect(try store.shareHistory().isEmpty)
    }

    @Test
    func readerPDFLabelsTheVerifiedSourcePayloadDigestPrecisely() throws {
        let model = AppModel(store: InMemoryLedgerStore())
        let encoded = try PackWriter.seal(
            draft: proofPackDraft(),
            passphrase: "correct horse battery"
        )
        let packURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SaneBooksSource-\(UUID().uuidString).sanebooks")
        let pdfURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SaneBooksReader-\(UUID().uuidString).pdf")
        defer {
            try? FileManager.default.removeItem(at: packURL)
            try? FileManager.default.removeItem(at: pdfURL)
        }
        try encoded.data.write(to: packURL)

        model.openPack(url: packURL, passphrase: "correct horse battery")
        try model.exportReaderPDF(to: pdfURL)

        let document = try #require(PDFDocument(url: pdfURL))
        let text = try #require(document.string)
        #expect(text.contains("Source .sanebooks integrity"))
        #expect(text.contains("SHA-256 of canonical plaintext payload (digest field blanked):"))
        #expect(text.replacingOccurrences(of: "\n", with: "").contains(encoded.integrityHash))
        #expect(!text.contains("sha256:pending"))
    }

    @Test
    func duplicateFingerprintsAreNotSilentlyDeletedOnReload() throws {
        let store = InMemoryLedgerStore()
        let first = Vault(
            displayName: "First books",
            network: .mainnet,
            keyKind: .ufvk,
            keyFingerprint: "uview:same",
            mode: .bookkeeper
        )
        let second = Vault(
            displayName: "Second books",
            network: .mainnet,
            keyKind: .ufvk,
            keyFingerprint: "uview:same",
            mode: .bookkeeper
        )
        try store.upsertVault(first)
        try store.upsertVault(second)
        let isolated = try isolatedDefaults()
        defer { isolated.defaults.removePersistentDomain(forName: isolated.suite) }
        let model = AppModel(store: store, settingsDefaults: isolated.defaults)

        model.reloadFromStore()

        #expect(model.vaults.count == 2)
        #expect(try store.allVaults().count == 2)
    }

    @Test
    func caughtUpRefreshPreservesUserBookkeepingMetadata() async throws {
        let refreshedHeight: UInt32 = 101
        let store = InMemoryLedgerStore()
        let vault = Vault(
            displayName: "Preservation",
            network: .mainnet,
            keyKind: .ufvk,
            keyFingerprint: "uview:preservation",
            mode: .bookkeeper
        )
        try store.upsertVault(vault)
        try store.setActiveVaultID(vault.id)
        let txid = Data(repeating: 0x44, count: 32)
        let noteID = NoteRowID.stableOutput(
            vaultID: vault.id,
            txid: txid,
            pool: .orchard,
            outputIndex: 2
        )
        let fiat = FiatMark(
            ratePerZEC: 42,
            asOf: Date(timeIntervalSince1970: 1_700_000_000),
            source: .userEntered
        )
        let existing = NoteRow(
            id: noteID,
            vaultID: vault.id,
            txid: txid,
            blockHeight: 100,
            pool: .orchard,
            direction: .inbound,
            valueZatoshis: 10,
            memo: .text("Edited memo"),
            classification: Classification(kind: .income, party: "Client", source: .user),
            includeInPacksByDefault: false,
            fiatMark: fiat
        )
        try store.upsertNotes([existing])

        let synced = NoteRow(
            id: noteID,
            vaultID: vault.id,
            txid: txid,
            blockHeight: refreshedHeight,
            pool: .orchard,
            direction: .inbound,
            valueZatoshis: 10,
            memo: .text("Wallet memo")
        )
        let facade = SnapshotSyncFacade(vaultID: vault.id, notes: [synced])
        let isolated = try isolatedDefaults()
        defer { isolated.defaults.removePersistentDomain(forName: isolated.suite) }
        let model = AppModel(store: store, sync: facade, settingsDefaults: isolated.defaults)
        model.reloadFromStore()

        await model.refreshFromSync(vaultID: vault.id)

        let refreshed = try #require(model.notes.first)
        #expect(refreshed.blockHeight == refreshedHeight)
        #expect(refreshed.classification?.party == "Client")
        #expect(refreshed.memo == .text("Edited memo"))
        #expect(!refreshed.includeInPacksByDefault)
        #expect(refreshed.fiatMark == fiat)
    }
}

private actor SnapshotSyncFacade: SyncFacade {
    let vaultID: VaultID
    let notes: [NoteRow]

    init(vaultID: VaultID, notes: [NoteRow]) {
        self.vaultID = vaultID
        self.notes = notes
    }

    func start(vaultID _: VaultID) async throws {}
    func cancel(vaultID _: VaultID) async {}
    func purge(vaultID _: VaultID) async throws {}
    func rescan(vaultID _: VaultID, from _: UInt32) async throws {}
    func capabilityReport() async -> CapabilityReport {
        .demoMock
    }

    func currentCursor(vaultID: VaultID) async -> SyncCursor? {
        guard vaultID == self.vaultID else { return nil }
        return SyncCursor(
            vaultID: vaultID,
            birthdayHeight: 1,
            scannedThroughHeight: 101,
            chainTipHeight: 101,
            status: .caughtUp,
            poolsSynced: [.orchard],
            capabilityReport: .demoMock,
            noteCount: notes.count
        )
    }

    func latestNotes(vaultID: VaultID) async -> [NoteRow] {
        vaultID == self.vaultID ? notes : []
    }
}
