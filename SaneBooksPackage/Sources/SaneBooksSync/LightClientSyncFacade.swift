import Foundation
import SaneBooksCore

/// View-only light-client facade scaffold.
///
/// Does **not** link ZcashLightClientKit by default (macOS/Ironwood incomplete — SDK #1806).
/// Behavior:
/// - `SANEBOOKS_FORCE_MOCK=1` or demo fixture key → `MockSyncFacade`
/// - `!mainnetSafe` from capability probe → capability-blocked cursor (honest incompleteness)
/// - Optional compile flag `SANEBOOKS_ENABLE_LIGHTCLIENT=1` reserves a stub path for future SDK wiring
///
/// Never pretends completeness when blocked.
public actor LightClientSyncFacade: SyncFacade {
    private let probe: any SyncCapabilityProbing
    private let mock: MockSyncFacade
    private let blocked: BlockedSyncFacade
    private var forceMock: Bool
    private var lwdURL: URL
    private var cursors: [UUID: SyncCursor] = [:]
    private var lastReport: CapabilityReport?

    public init(
        probe: any SyncCapabilityProbing = CapabilityProbe(),
        forceMock: Bool? = nil,
        lwdURL: URL = URL(string: "https://zec.rocks:443")!
    ) {
        self.probe = probe
        mock = MockSyncFacade()
        blocked = BlockedSyncFacade()
        self.forceMock = forceMock ?? Self.envForceMock
        self.lwdURL = lwdURL
    }

    /// Production default: blocked/honest unless mock forced.
    public static func makeDefault() -> LightClientSyncFacade {
        LightClientSyncFacade()
    }

    public static var envForceMock: Bool {
        ProcessInfo.processInfo.environment["SANEBOOKS_FORCE_MOCK"] == "1"
    }

    public func setForceMock(_ value: Bool) {
        forceMock = value
    }

    public func setLWDURL(_ url: URL) {
        lwdURL = url
    }

    public func lwdURLValue() -> URL {
        lwdURL
    }

    public func capabilityReport() async -> CapabilityReport {
        if forceMock {
            return .demoMock
        }
        let report = await probe.probe()
        lastReport = report
        return report
    }

    public func currentCursor(vaultID: VaultID) async -> SyncCursor? {
        if forceMock {
            return await mock.currentCursor(vaultID: vaultID)
        }
        if let cached = cursors[vaultID.uuid] {
            return cached
        }
        return await blocked.currentCursor(vaultID: vaultID)
    }

    public func latestNotes(vaultID: VaultID) async -> [NoteRow] {
        if forceMock {
            return await mock.latestNotes(vaultID: vaultID)
        }
        return []
    }

    public func start(vaultID: VaultID) async throws {
        if forceMock {
            try await mock.start(vaultID: vaultID)
            return
        }

        let report = await capabilityReport()
        #if SANEBOOKS_ENABLE_LIGHTCLIENT
            // Reserved: when Ironwood SDK lands and mainnetSafe, wire ZcashLightClientKit view-only here.
            if report.mainnetSafe {
                // Stub — fall through to blocked until real adapter exists.
            }
        #endif

        if !report.mainnetSafe {
            let cursor = SyncCursor(
                vaultID: vaultID,
                birthdayHeight: 419_200,
                scannedThroughHeight: 419_200,
                lastError: .capability,
                lwdURL: lwdURL,
                status: .capabilityBlocked,
                capabilityReport: report,
                isDemo: false
            )
            cursors[vaultID.uuid] = cursor
            throw SaneBooksError.syncBlocked(
                "Mainnet complete sync unavailable until Ironwood SDK (issue #1806). Ledger incomplete for post-NU6.3 receives."
            )
        }

        // Should not reach until SDK path is live.
        throw SaneBooksError.syncBlocked("Light client not linked — use mock or wait for Ironwood-capable SDK.")
    }

    public func cancel(vaultID: VaultID) async {
        if forceMock {
            await mock.cancel(vaultID: vaultID)
            return
        }
        if var cursor = cursors[vaultID.uuid] {
            cursor.status = .idle
            cursors[vaultID.uuid] = cursor
        }
        await blocked.cancel(vaultID: vaultID)
    }

    public func rescan(vaultID: VaultID, from height: UInt32) async throws {
        if forceMock {
            try await mock.rescan(vaultID: vaultID, from: height)
            return
        }
        _ = height
        try await start(vaultID: vaultID)
    }
}
