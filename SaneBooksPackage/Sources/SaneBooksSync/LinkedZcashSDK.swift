import Foundation
import SaneBooksCore

/// Pinned ZcashLightClientKit identity for capability reporting and docs.
public enum LinkedZcashSDK: Sendable {
    /// Tag `2.7.0-rc.4` (commit `fb9f6cf…`) — first non-prerelease line with Ironwood receive/sync.
    public static let revision = "2.7.0-rc.4"
    public static let trackingIssue = "https://github.com/zcash/zcash-swift-wallet-sdk/issues/1806"
    public static let defaultMainnetLWD = URL(string: "https://zec.rocks:443")!
    /// Sapling activation — used only when the vault has no birthday.
    public static let mainnetDefaultBirthday: UInt32 = 419_200
    public static let testnetDefaultBirthday: UInt32 = 280_000

    public static var linkedCapabilityReport: CapabilityReport {
        CapabilityReport(
            sdkRevision: revision,
            supportsSapling: true,
            supportsOrchard: true,
            supportsIronwood: true,
            supportsTransparent: false,
            notes: [
                "ZcashLightClientKit \(revision) linked (Ironwood #1806 closed).",
                "View-only UFVK import via Synchronizer.importAccount(purpose: .viewOnly).",
                "UIVK import is not available in the public SDK — receivables mode stays degraded.",
                "Output pool raw value 4 is treated as Ironwood until the SDK names it."
            ]
        )
    }
}

/// Credentials required to open a live light-client session for one vault.
public struct SyncAccountCredentials: Sendable, Equatable {
    public var vaultID: VaultID
    public var viewingKey: String
    public var keyKind: ViewingKeyKind
    public var network: ZcashNetwork
    public var birthdayHeight: UInt32

    public init(
        vaultID: VaultID,
        viewingKey: String,
        keyKind: ViewingKeyKind,
        network: ZcashNetwork,
        birthdayHeight: UInt32
    ) {
        self.vaultID = vaultID
        self.viewingKey = viewingKey
        self.keyKind = keyKind
        self.network = network
        self.birthdayHeight = birthdayHeight
    }
}
