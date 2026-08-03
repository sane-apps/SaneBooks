import Foundation
import SaneBooksCore

/// Default capability probe for production.
/// Documents zcash-swift-wallet-sdk Ironwood tracking:
/// https://github.com/zcash/zcash-swift-wallet-sdk/issues/1806
///
/// Until Ironwood compact sync ships in a pinned SDK revision, `supportsIronwood` stays false
/// and `mainnetSafe` is false. Do not claim mainnet completeness.
public struct CapabilityProbe: SyncCapabilityProbing, Sendable {
    public init() {}

    public func probe() async -> CapabilityReport {
        CapabilityReport(
            sdkRevision: "not-linked",
            supportsSapling: true,
            supportsOrchard: true,
            supportsIronwood: false,
            supportsTransparent: false,
            notes: [
                "Ironwood compact sync unavailable (SDK #1806).",
                "Mainnet complete sync blocked until Ironwood support lands.",
                "Set SANEBOOKS_FORCE_MOCK=1 for demo ledger only."
            ]
        )
    }
}

/// Prefer this name in docs; `StaticCapabilityProbe` remains for tests with fixed reports.
public typealias DefaultCapabilityProbe = CapabilityProbe
