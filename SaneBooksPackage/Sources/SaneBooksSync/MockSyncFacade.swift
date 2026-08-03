import Foundation
import SaneBooksCore

/// Deterministic mock sync for Week 1 + unit tests. Completes synchronously (no sleep).
public actor MockSyncFacade: SyncFacade {
    public static let tipHeight: UInt32 = 2_850_104
    public static let birthdayDefault: UInt32 = 2_100_000

    private var cursors: [UUID: SyncCursor] = [:]
    private var notes: [UUID: [NoteRow]] = [:]
    private var cancelled: Set<UUID> = []
    private let capability: CapabilityReport

    public init(capability: CapabilityReport = .demoMock) {
        self.capability = capability
    }

    public func capabilityReport() async -> CapabilityReport {
        capability
    }

    public func currentCursor(vaultID: VaultID) async -> SyncCursor? {
        cursors[vaultID.uuid]
    }

    public func latestNotes(vaultID: VaultID) async -> [NoteRow] {
        notes[vaultID.uuid] ?? []
    }

    public func start(vaultID: VaultID) async throws {
        cancelled.remove(vaultID.uuid)
        let fixtures = DemoLedgerFixtures.notes(for: vaultID)
        var cursor = SyncCursor(
            vaultID: vaultID,
            birthdayHeight: Self.birthdayDefault,
            scannedThroughHeight: Self.birthdayDefault,
            chainTipHeight: Self.tipHeight,
            status: .scanning,
            poolsSynced: [.sapling, .orchard, .ironwood],
            capabilityReport: capability,
            isDemo: true,
            progressFraction: 0,
            noteCount: 0
        )
        cursors[vaultID.uuid] = cursor

        if cancelled.contains(vaultID.uuid) {
            cursor.status = .idle
            cursor.lastError = .cancelled
            cursors[vaultID.uuid] = cursor
            return
        }

        notes[vaultID.uuid] = fixtures
        cursor.scannedThroughHeight = Self.tipHeight
        cursor.progressFraction = 1
        cursor.noteCount = fixtures.count
        cursor.status = .caughtUp
        cursor.lastSuccessAt = Date(timeIntervalSince1970: 1_775_000_000)
        cursors[vaultID.uuid] = cursor
    }

    public func cancel(vaultID: VaultID) async {
        cancelled.insert(vaultID.uuid)
        if var cursor = cursors[vaultID.uuid] {
            cursor.status = .idle
            cursor.lastError = .cancelled
            cursors[vaultID.uuid] = cursor
        }
    }

    public func rescan(vaultID: VaultID, from height: UInt32) async throws {
        if var cursor = cursors[vaultID.uuid] {
            cursor.birthdayHeight = height
            cursors[vaultID.uuid] = cursor
        }
        try await start(vaultID: vaultID)
    }
}
