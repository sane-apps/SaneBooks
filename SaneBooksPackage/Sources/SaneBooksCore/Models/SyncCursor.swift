import Foundation

public enum SyncStatus: String, Codable, Sendable {
    case idle
    case scanning
    case caughtUp
    case stalled
    case degraded
    case capabilityBlocked

    public var displayName: String {
        switch self {
        case .idle: "Idle"
        case .scanning: "Scanning"
        case .caughtUp: "Caught up"
        case .stalled: "Stalled"
        case .degraded: "Degraded"
        case .capabilityBlocked: "Capability blocked"
        }
    }
}

public enum SyncErrorCode: String, Codable, Sendable {
    case network
    case capability
    case cancelled
    case unknown
}

public struct CapabilityReport: Codable, Sendable, Equatable {
    public var sdkRevision: String
    public var supportsSapling: Bool
    public var supportsOrchard: Bool
    public var supportsIronwood: Bool
    public var supportsTransparent: Bool
    public var mainnetSafe: Bool
    public var evaluatedAt: Date
    public var notes: [String]

    public init(
        sdkRevision: String,
        supportsSapling: Bool,
        supportsOrchard: Bool,
        supportsIronwood: Bool,
        supportsTransparent: Bool = false,
        mainnetSafe: Bool? = nil,
        evaluatedAt: Date = Date(),
        notes: [String] = []
    ) {
        self.sdkRevision = sdkRevision
        self.supportsSapling = supportsSapling
        self.supportsOrchard = supportsOrchard
        self.supportsIronwood = supportsIronwood
        self.supportsTransparent = supportsTransparent
        self.mainnetSafe = mainnetSafe ?? (supportsSapling && supportsOrchard && supportsIronwood)
        self.evaluatedAt = evaluatedAt
        self.notes = notes
    }

    public static var ironwoodBlocked: CapabilityReport {
        CapabilityReport(
            sdkRevision: "mock-blocked",
            supportsSapling: true,
            supportsOrchard: true,
            supportsIronwood: false,
            notes: ["Ironwood compact sync unavailable — mainnet not safe"]
        )
    }

    public static var demoMock: CapabilityReport {
        CapabilityReport(
            sdkRevision: "mock-demo",
            supportsSapling: true,
            supportsOrchard: true,
            supportsIronwood: true,
            mainnetSafe: true,
            notes: ["Demo ledger — not chain data"]
        )
    }
}

public typealias SyncCapabilityReport = CapabilityReport

public struct SyncCursor: Codable, Sendable, Equatable {
    public var vaultID: VaultID
    public var birthdayHeight: UInt32
    public var scannedThroughHeight: UInt32
    public var chainTipHeight: UInt32?
    public var lastSuccessAt: Date?
    public var lastError: SyncErrorCode?
    public var lwdURL: URL
    public var status: SyncStatus
    public var poolsSynced: Set<ShieldedPool>
    public var capabilityReport: CapabilityReport
    public var isDemo: Bool
    public var progressFraction: Double
    public var etaSeconds: TimeInterval?
    public var noteCount: Int

    public init(
        vaultID: VaultID,
        birthdayHeight: UInt32,
        scannedThroughHeight: UInt32 = 0,
        chainTipHeight: UInt32? = nil,
        lastSuccessAt: Date? = nil,
        lastError: SyncErrorCode? = nil,
        lwdURL: URL = URL(string: "https://example.invalid/lwd")!,
        status: SyncStatus = .idle,
        poolsSynced: Set<ShieldedPool> = [],
        capabilityReport: CapabilityReport = .ironwoodBlocked,
        isDemo: Bool = false,
        progressFraction: Double = 0,
        etaSeconds: TimeInterval? = nil,
        noteCount: Int = 0
    ) {
        self.vaultID = vaultID
        self.birthdayHeight = birthdayHeight
        self.scannedThroughHeight = scannedThroughHeight
        self.chainTipHeight = chainTipHeight
        self.lastSuccessAt = lastSuccessAt
        self.lastError = lastError
        self.lwdURL = lwdURL
        self.status = status
        self.poolsSynced = poolsSynced
        self.capabilityReport = capabilityReport
        self.isDemo = isDemo
        self.progressFraction = progressFraction
        self.etaSeconds = etaSeconds
        self.noteCount = noteCount
    }
}

public struct SyncAttestation: Codable, Sendable, Equatable {
    public var syncedToHeight: UInt32
    public var chainTipAtExport: UInt32?
    public var lwdEndpointFingerprint: String
    public var exportedAt: Date
    public var vaultMode: VaultMode
    public var poolsPresent: [ShieldedPool]
    public var ironwoodCapable: Bool
    public var disclaimer: String

    public static let defaultDisclaimer =
        "Completeness assumes an honest lightwalletd; omitted compact blocks understate income."

    public init(
        syncedToHeight: UInt32,
        chainTipAtExport: UInt32? = nil,
        lwdEndpointFingerprint: String,
        exportedAt: Date = Date(),
        vaultMode: VaultMode,
        poolsPresent: [ShieldedPool],
        ironwoodCapable: Bool,
        disclaimer: String = SyncAttestation.defaultDisclaimer
    ) {
        self.syncedToHeight = syncedToHeight
        self.chainTipAtExport = chainTipAtExport
        self.lwdEndpointFingerprint = lwdEndpointFingerprint
        self.exportedAt = exportedAt
        self.vaultMode = vaultMode
        self.poolsPresent = poolsPresent
        self.ironwoodCapable = ironwoodCapable
        self.disclaimer = disclaimer
    }
}
