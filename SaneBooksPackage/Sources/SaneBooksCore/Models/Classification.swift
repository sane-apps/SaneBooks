import Foundation

public enum ClassificationKind: String, Codable, Sendable, CaseIterable, Hashable {
    case income
    case expense
    case change
    case fee
    case untagged
    case excluded

    public var displayName: String {
        switch self {
        case .income: "Income"
        case .expense: "Expense"
        case .change: "Change"
        case .fee: "Fee"
        case .untagged: "Untagged"
        case .excluded: "Excluded"
        }
    }
}

public enum ClassificationSource: String, Codable, Sendable {
    case user
    case autoChange
    case autoFee
    case rule
}

public struct Classification: Codable, Sendable, Equatable {
    public var kind: ClassificationKind
    public var party: String?
    public var subtag: String?
    public var notes: String?
    public var updatedAt: Date
    public var source: ClassificationSource

    public init(
        kind: ClassificationKind,
        party: String? = nil,
        subtag: String? = nil,
        notes: String? = nil,
        updatedAt: Date = Date(),
        source: ClassificationSource = .user
    ) {
        self.kind = kind
        self.party = party
        self.subtag = subtag
        self.notes = notes
        self.updatedAt = updatedAt
        self.source = source
    }
}
