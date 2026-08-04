@preconcurrency import Combine
import Foundation
@testable import SaneBooksCore
@testable import SaneBooksSync
import Testing

private actor IntRecorder {
    private(set) var values: [Int] = []

    func append(_ value: Int) {
        values.append(value)
    }
}

@Suite("Sync facades")
struct SyncFacadeTests {
    @Test
    func sdkStorageIsOwnerOnlyBackupExcludedAndRejectsSymlinks() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("SaneBooksSDKStorage-\(UUID().uuidString)", isDirectory: true)
        let outside = fileManager.temporaryDirectory
            .appendingPathComponent("SaneBooksSDKOutside-\(UUID().uuidString)")
        defer {
            try? fileManager.removeItem(at: root)
            try? fileManager.removeItem(at: outside)
        }

        try ZcashSDKStoragePolicy.prepareRoot(at: root)
        let nested = root.appendingPathComponent("storage", isDirectory: true)
        try fileManager.createDirectory(at: nested, withIntermediateDirectories: true)
        let database = nested.appendingPathComponent("data.db")
        try Data("private viewing material".utf8).write(to: database)
        try ZcashSDKStoragePolicy.hardenExistingTree(at: root)

        let rootMode = try #require(
            fileManager.attributesOfItem(atPath: root.path)[.posixPermissions] as? NSNumber
        )
        let nestedMode = try #require(
            fileManager.attributesOfItem(atPath: nested.path)[.posixPermissions] as? NSNumber
        )
        let databaseMode = try #require(
            fileManager.attributesOfItem(atPath: database.path)[.posixPermissions] as? NSNumber
        )
        #expect(rootMode.intValue & 0o777 == 0o700)
        #expect(nestedMode.intValue & 0o777 == 0o700)
        #expect(databaseMode.intValue & 0o777 == 0o600)
        #expect(try root.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)

        try Data("do not chmod".utf8).write(to: outside)
        let link = root.appendingPathComponent("unexpected-link")
        try fileManager.createSymbolicLink(at: link, withDestinationURL: outside)
        #expect(throws: SaneBooksError.self) {
            try ZcashSDKStoragePolicy.hardenExistingTree(at: root)
        }
    }

    @Test
    func mockProgressesToCaughtUp() async throws {
        let sync = MockSyncFacade()
        let vaultID = VaultID()
        try await sync.start(vaultID: vaultID)
        let cursor = await sync.currentCursor(vaultID: vaultID)
        #expect(cursor?.status == .caughtUp)
        #expect(cursor?.scannedThroughHeight == MockSyncFacade.tipHeight)
        let notes = await sync.latestNotes(vaultID: vaultID)
        #expect(notes.count >= 3)
        #expect(notes.contains { $0.pool == .ironwood })
        let report = await sync.capabilityReport()
        #expect(report.supportsIronwood == true)
    }

    @Test
    func blockedReportsMainnetUnsafe() async throws {
        let sync = BlockedSyncFacade()
        let report = await sync.capabilityReport()
        #expect(report.supportsIronwood == false)
        #expect(report.mainnetSafe == false)

        let vaultID = VaultID()
        do {
            try await sync.start(vaultID: vaultID)
            Issue.record("Expected syncBlocked throw")
        } catch let error as SaneBooksError {
            guard case .syncBlocked = error else {
                Issue.record("Unexpected error \(error)")
                return
            }
        }
        let cursor = await sync.currentCursor(vaultID: vaultID)
        #expect(cursor?.status == .capabilityBlocked)
    }

    @Test
    func capabilityProbeReportsIronwoodLinked() async {
        let probe = CapabilityProbe()
        let report = await probe.probe()
        #expect(report.supportsIronwood == true)
        #expect(report.mainnetSafe == true)
        #expect(report.sdkRevision == LinkedZcashSDK.revision)
    }

    @Test
    func lightClientRequiresCredentialsWhenLive() async throws {
        let sync = LightClientSyncFacade(forceMock: false)
        let report = await sync.capabilityReport()
        #expect(report.mainnetSafe == true)
        let vaultID = VaultID()
        do {
            try await sync.start(vaultID: vaultID)
            Issue.record("Expected missing-credentials error")
        } catch let error as SaneBooksError {
            guard case .sync = error else {
                Issue.record("Unexpected \(error)")
                return
            }
        }
    }

    @Test
    func lightClientBlocksUIVK() async throws {
        let sync = LightClientSyncFacade(forceMock: false)
        let vaultID = VaultID()
        await sync.bindCredentials(
            SyncAccountCredentials(
                vaultID: vaultID,
                viewingKey: "uivk1placeholder",
                keyKind: .uivk,
                network: .mainnet,
                birthdayHeight: 3_400_000
            )
        )
        var blockedUIVK = false
        do {
            try await sync.start(vaultID: vaultID)
            Issue.record("Expected UIVK blocked")
        } catch let error as SaneBooksError {
            guard case .syncBlocked = error else {
                Issue.record("Unexpected \(error)")
                return
            }
            blockedUIVK = true
        }
        #expect(blockedUIVK)
    }

    @Test
    func lightClientUsesMockWhenForced() async throws {
        let sync = LightClientSyncFacade(forceMock: true)
        let vaultID = VaultID()
        try await sync.start(vaultID: vaultID)
        let cursor = await sync.currentCursor(vaultID: vaultID)
        #expect(cursor?.status == .caughtUp)
        let notes = await sync.latestNotes(vaultID: vaultID)
        #expect(!notes.isEmpty)
    }

    @Test
    func endpointParsesHostPort() throws {
        let standardHTTPSPort = 443
        let endpoint = try ZcashSDKEngine.endpoint(from: LinkedZcashSDK.defaultMainnetLWD)
        #expect(endpoint.host == "zec.rocks")
        #expect(endpoint.port == standardHTTPSPort)
        #expect(endpoint.secure == true)
    }

    @Test
    func endpointRejectsCleartextAndUnknownSchemes() throws {
        #expect(throws: SaneBooksError.self) {
            _ = try ZcashSDKEngine.endpoint(from: #require(URL(string: "http://zec.rocks:80")))
        }
        #expect(throws: SaneBooksError.self) {
            _ = try ZcashSDKEngine.endpoint(from: #require(URL(string: "ftp://zec.rocks")))
        }
    }

    @Test
    func onlySDKPoolFourMapsToIronwood() {
        #expect(ZcashSDKNoteMapper.pool(from: .other(4)) == .ironwood)
        #expect(ZcashSDKNoteMapper.pool(from: .other(5)) == nil)
        #expect(ZcashSDKNoteMapper.pool(from: .other(Int.max)) == nil)
    }

    @Test
    func liveMapperUsesCanonicalPoolAndOutputIdentity() {
        let vaultID = VaultID()
        let txid = Data(repeating: 0xAB, count: 32)

        let mapped = ZcashSDKNoteMapper.stableID(
            vaultID: vaultID,
            txid: txid,
            pool: .ironwood,
            outputIndex: 7
        )

        #expect(mapped == NoteRowID.stableOutput(
            vaultID: vaultID,
            txid: txid,
            pool: .ironwood,
            outputIndex: 7
        ))
        #expect(mapped != NoteRowID.stableOutput(
            vaultID: vaultID,
            txid: txid,
            pool: .orchard,
            outputIndex: 7
        ))
        #expect(mapped != NoteRowID.stableOutput(
            vaultID: vaultID,
            txid: txid,
            pool: .ironwood,
            outputIndex: 8
        ))
    }

    @Test
    func linkedSDKValidatesChecksumAndNetwork() {
        #expect(LinkedZcashSDK.isValidViewingKey(
            LiveProbeKey.mainnetUFVK,
            kind: .ufvk,
            network: .mainnet
        ))
        #expect(!LinkedZcashSDK.isValidViewingKey(
            ViewingKeyValidator.fixtureMainnetUFVK,
            kind: .ufvk,
            network: .mainnet
        ))
        #expect(!LinkedZcashSDK.isValidViewingKey(
            LiveProbeKey.mainnetUFVK,
            kind: .ufvk,
            network: .testnet
        ))
    }

    @Test
    func latestStateTaskCancelsSupersededWork() async {
        let coordinator = LatestTaskCoordinator()
        let recorder = IntRecorder()

        coordinator.replace {
            do {
                try await Task.sleep(for: .milliseconds(100))
            } catch {
                return
            }
            await recorder.append(1)
        }
        coordinator.replace {
            await recorder.append(2)
        }

        try? await Task.sleep(for: .milliseconds(180))
        #expect(await recorder.values == [2])
        coordinator.cancel()
    }

    @Test
    func publisherCompletionBridgeHonorsTaskCancellation() async {
        let subject = PassthroughSubject<Void, Error>()
        let task = Task {
            try await awaitPublisherCompletion(subject.eraseToAnyPublisher())
        }

        await Task.yield()
        task.cancel()
        try? await Task.sleep(for: .milliseconds(50))
        subject.send(completion: .finished)

        var observedCancellation = false
        do {
            try await task.value
            Issue.record("Cancelled publisher bridge completed successfully instead of throwing CancellationError")
        } catch is CancellationError {
            observedCancellation = true
        } catch {
            Issue.record("Unexpected cancellation error: \(error)")
        }
        #expect(observedCancellation)
    }
}
