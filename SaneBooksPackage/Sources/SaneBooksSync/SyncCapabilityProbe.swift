import Foundation
import SaneBooksCore

public struct StaticCapabilityProbe: SyncCapabilityProbing, Sendable {
    public var report: CapabilityReport

    public init(report: CapabilityReport = .ironwoodBlocked) {
        self.report = report
    }

    public func probe() async -> CapabilityReport {
        report
    }
}
