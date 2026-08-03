import Foundation
@testable import SaneBooksCore
@testable import SaneBooksSync
import Testing

@Suite("Sync facades")
struct SyncFacadeTests {
    @Test func mockProgressesToCaughtUp() async throws {
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

    @Test func blockedReportsMainnetUnsafe() async throws {
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

    @Test func capabilityProbeDefaultsIronwoodFalse() async {
        let probe = CapabilityProbe()
        let report = await probe.probe()
        #expect(report.supportsIronwood == false)
        #expect(report.mainnetSafe == false)
        #expect(report.notes.contains { $0.contains("1806") })
    }

    @Test func lightClientBlocksWhenNotMainnetSafe() async throws {
        let sync = LightClientSyncFacade(forceMock: false)
        let report = await sync.capabilityReport()
        #expect(report.mainnetSafe == false)
        let vaultID = VaultID()
        do {
            try await sync.start(vaultID: vaultID)
            Issue.record("Expected blocked")
        } catch let error as SaneBooksError {
            guard case .syncBlocked = error else {
                Issue.record("Unexpected \(error)")
                return
            }
        }
        let cursor = await sync.currentCursor(vaultID: vaultID)
        #expect(cursor?.status == .capabilityBlocked)
    }

    @Test func lightClientUsesMockWhenForced() async throws {
        let sync = LightClientSyncFacade(forceMock: true)
        let vaultID = VaultID()
        try await sync.start(vaultID: vaultID)
        let cursor = await sync.currentCursor(vaultID: vaultID)
        #expect(cursor?.status == .caughtUp)
        let notes = await sync.latestNotes(vaultID: vaultID)
        #expect(!notes.isEmpty)
    }
}
