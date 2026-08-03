import Foundation

/// Memo auto-tag rule: if memo contains `memoContains`, apply kind/party/subtag.
public struct TagRule: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var memoContains: String
    public var kind: ClassificationKind
    public var party: String?
    public var subtag: String?
    public var enabled: Bool

    public init(
        id: UUID = UUID(),
        memoContains: String,
        kind: ClassificationKind,
        party: String? = nil,
        subtag: String? = nil,
        enabled: Bool = true
    ) {
        self.id = id
        self.memoContains = memoContains
        self.kind = kind
        self.party = party
        self.subtag = subtag
        self.enabled = enabled
    }

    /// Optional seed: memo contains "INV-" → Income.
    public static var defaultInvoiceSeed: TagRule {
        TagRule(memoContains: "INV-", kind: .income, party: nil, subtag: "Invoice")
    }
}
