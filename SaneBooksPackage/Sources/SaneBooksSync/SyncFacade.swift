import Foundation
import SaneBooksCore

public protocol SyncCapabilityProbing: Sendable {
    func probe() async -> CapabilityReport
}

public protocol SyncFacade: Sendable {
    func start(vaultID: VaultID) async throws
    func cancel(vaultID: VaultID) async
    func purge(vaultID: VaultID) async throws
    func rescan(vaultID: VaultID, from height: UInt32) async throws
    func capabilityReport() async -> CapabilityReport
    func currentCursor(vaultID: VaultID) async -> SyncCursor?
    func latestNotes(vaultID: VaultID) async -> [NoteRow]
}
