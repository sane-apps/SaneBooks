import Foundation

public enum FiatSource: String, Codable, Sendable {
    case oracleSnapshot
    case userEntered
    case missing
}

public struct FiatMark: Codable, Sendable, Equatable {
    public var currency: String
    public var ratePerZEC: Decimal
    public var asOf: Date
    public var source: FiatSource

    public init(
        currency: String = "USD",
        ratePerZEC: Decimal,
        asOf: Date,
        source: FiatSource
    ) {
        self.currency = currency
        self.ratePerZEC = ratePerZEC
        self.asOf = asOf
        self.source = source
    }

    public func amount(forZEC zec: Decimal) -> Decimal? {
        guard source != .missing else { return nil }
        return zec * ratePerZEC
    }
}

public struct FiatOracleRecord: Codable, Sendable {
    public var sourceName: String
    public var fetchedAt: Date
    public var ratePerZEC: Decimal
    public var currency: String

    public init(
        sourceName: String,
        fetchedAt: Date,
        ratePerZEC: Decimal,
        currency: String = "USD"
    ) {
        self.sourceName = sourceName
        self.fetchedAt = fetchedAt
        self.ratePerZEC = ratePerZEC
        self.currency = currency
    }
}
