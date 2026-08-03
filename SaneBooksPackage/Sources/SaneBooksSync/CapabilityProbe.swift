import Foundation
import SaneBooksCore

/// Default capability probe for production.
/// Ironwood receive/sync landed in ZcashLightClientKit 2.7.0-rc.1+ (#1806 closed).
/// SaneBooks links `2.7.0-rc.4` via `LinkedZcashSDK`.
public struct CapabilityProbe: SyncCapabilityProbing, Sendable {
    public init() {}

    public func probe() async -> CapabilityReport {
        LinkedZcashSDK.linkedCapabilityReport
    }
}

/// Prefer this name in docs; `StaticCapabilityProbe` remains for tests with fixed reports.
public typealias DefaultCapabilityProbe = CapabilityProbe
