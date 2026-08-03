import Foundation
import SaneBooksCore

public actor BlockedSyncFacade: SyncFacade {
    private let capability: CapabilityReport
    private var cursors: [UUID: SyncCursor] = [:]

    public init(capability: CapabilityReport = .ironwoodBlocked) {
        self.capability = capability
    }

    public func capabilityReport() async -> CapabilityReport {
        capability
    }

    public func currentCursor(vaultID: VaultID) async -> SyncCursor? {
        cursors[vaultID.uuid]
    }

    public func latestNotes(vaultID _: VaultID) async -> [NoteRow] {
        []
    }

    public func start(vaultID: VaultID) async throws {
        cursors[vaultID.uuid] = SyncCursor(
            vaultID: vaultID,
            birthdayHeight: 419_200,
            scannedThroughHeight: 419_200,
            lastError: .capability,
            status: .capabilityBlocked,
            capabilityReport: capability,
            isDemo: false
        )
        throw SaneBooksError.syncBlocked(
            "Ironwood sync unavailable — ledger incomplete for post-NU6.3 receives."
        )
    }

    public func cancel(vaultID: VaultID) async {
        if var cursor = cursors[vaultID.uuid] {
            cursor.status = .idle
            cursors[vaultID.uuid] = cursor
        }
    }

    public func rescan(vaultID: VaultID, from height: UInt32) async throws {
        _ = height
        try await start(vaultID: vaultID)
    }
}
