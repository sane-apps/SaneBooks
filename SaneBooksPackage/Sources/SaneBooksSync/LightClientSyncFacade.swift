import Foundation
import SaneBooksCore

/// View-only light-client facade over ZcashLightClientKit.
///
/// Behavior:
/// - `SANEBOOKS_FORCE_MOCK=1` or `setForceMock(true)` → `MockSyncFacade`
/// - Live path: bind UFVK credentials, then `start` drives SDKSynchronizer against LWD
/// - UIVK / missing credentials → honest `syncBlocked` (no fake completeness)
///
/// Never pretends chain completeness on the mock path without `isDemo`.
public actor LightClientSyncFacade: SyncFacade {
    private let probe: any SyncCapabilityProbing
    private let mock: MockSyncFacade
    private let engine: ZcashSDKEngine
    private var forceMock: Bool
    private var lwdURL: URL
    private var credentialsByVault: [UUID: SyncAccountCredentials] = [:]
    private var cursors: [UUID: SyncCursor] = [:]

    public init(
        probe: any SyncCapabilityProbing = CapabilityProbe(),
        forceMock: Bool? = nil,
        lwdURL: URL = LinkedZcashSDK.defaultMainnetLWD
    ) {
        self.probe = probe
        mock = MockSyncFacade()
        engine = ZcashSDKEngine()
        self.forceMock = forceMock ?? Self.envForceMock
        self.lwdURL = lwdURL
    }

    /// Production default: live SDK unless mock forced.
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

    /// Bind vault UFVK before `start`. Required for live sync.
    public func bindCredentials(_ credentials: SyncAccountCredentials) {
        credentialsByVault[credentials.vaultID.uuid] = credentials
    }

    public func capabilityReport() async -> CapabilityReport {
        if forceMock {
            return .demoMock
        }
        return await probe.probe()
    }

    public func currentCursor(vaultID: VaultID) async -> SyncCursor? {
        if forceMock {
            return await mock.currentCursor(vaultID: vaultID)
        }
        if let live = engine.currentCursor(), live.vaultID == vaultID {
            cursors[vaultID.uuid] = live
            return live
        }
        return cursors[vaultID.uuid]
    }

    public func latestNotes(vaultID: VaultID) async -> [NoteRow] {
        if forceMock {
            return await mock.latestNotes(vaultID: vaultID)
        }
        let live = engine.latestNotes()
        if !live.isEmpty {
            return live.filter { $0.vaultID == vaultID }
        }
        return []
    }

    public func start(vaultID: VaultID) async throws {
        if forceMock {
            try await mock.start(vaultID: vaultID)
            return
        }

        let report = await capabilityReport()
        guard report.mainnetSafe else {
            let cursor = SyncCursor(
                vaultID: vaultID,
                birthdayHeight: LinkedZcashSDK.mainnetDefaultBirthday,
                scannedThroughHeight: LinkedZcashSDK.mainnetDefaultBirthday,
                lastError: .capability,
                lwdURL: lwdURL,
                status: .capabilityBlocked,
                capabilityReport: report,
                isDemo: false
            )
            cursors[vaultID.uuid] = cursor
            throw SaneBooksError.syncBlocked(
                "Mainnet complete sync unavailable — capability gate failed (\(report.sdkRevision))."
            )
        }

        guard let credentials = credentialsByVault[vaultID.uuid] else {
            throw SaneBooksError.sync(
                "No viewing key loaded for this vault. Re-import the UFVK, then sync again."
            )
        }

        try await engine.start(credentials: credentials, lwdURL: lwdURL)
        if let cursor = engine.currentCursor(), cursor.vaultID == vaultID {
            cursors[vaultID.uuid] = cursor
        }
    }

    public func cancel(vaultID: VaultID) async {
        if forceMock {
            await mock.cancel(vaultID: vaultID)
            return
        }
        engine.cancel(vaultID: vaultID)
        if let cursor = engine.currentCursor(), cursor.vaultID == vaultID {
            cursors[vaultID.uuid] = cursor
        } else if var cursor = cursors[vaultID.uuid] {
            cursor.status = .idle
            cursors[vaultID.uuid] = cursor
        }
    }

    public func purge(vaultID: VaultID) async throws {
        try await mock.purge(vaultID: vaultID)
        try engine.purge(vaultID: vaultID)
        credentialsByVault.removeValue(forKey: vaultID.uuid)
        cursors.removeValue(forKey: vaultID.uuid)
    }

    public func rescan(vaultID: VaultID, from height: UInt32) async throws {
        if forceMock {
            try await mock.rescan(vaultID: vaultID, from: height)
            return
        }
        guard var credentials = credentialsByVault[vaultID.uuid] else {
            throw SaneBooksError.sync(
                "No viewing key loaded for this vault. Re-import the UFVK, then sync again."
            )
        }
        credentials.birthdayHeight = height
        credentialsByVault[vaultID.uuid] = credentials
        try await engine.rescan(credentials: credentials, lwdURL: lwdURL, from: height)
        if let cursor = engine.currentCursor(), cursor.vaultID == vaultID {
            cursors[vaultID.uuid] = cursor
        }
    }
}
