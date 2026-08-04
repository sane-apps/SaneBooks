import Foundation
import SaneBooksCore

/// Human-readable disclosure audit for a proof pack (what the CPA will see).
public struct PackDisclosureSummary: Sendable, Equatable {
    public var rowCount: Int
    public var incomeZEC: Decimal
    public var expenseZEC: Decimal
    public var feeZEC: Decimal
    public var includesMemos: Bool
    public var includesChange: Bool
    public var pools: [String]
    public var untaggedExcludedCount: Int
    public var partialHistory: Bool
    public var recipientLabel: String?
    public var expiresAt: Date?

    public init(
        rowCount: Int,
        incomeZEC: Decimal,
        expenseZEC: Decimal,
        feeZEC: Decimal,
        includesMemos: Bool,
        includesChange: Bool,
        pools: [String],
        untaggedExcludedCount: Int,
        partialHistory: Bool,
        recipientLabel: String?,
        expiresAt: Date?
    ) {
        self.rowCount = rowCount
        self.incomeZEC = incomeZEC
        self.expenseZEC = expenseZEC
        self.feeZEC = feeZEC
        self.includesMemos = includesMemos
        self.includesChange = includesChange
        self.pools = pools
        self.untaggedExcludedCount = untaggedExcludedCount
        self.partialHistory = partialHistory
        self.recipientLabel = recipientLabel
        self.expiresAt = expiresAt
    }

    public static func from(draft: ProofPackDraft, allNotes: [NoteRow]) -> PackDisclosureSummary {
        let untaggedExcluded = allNotes.filter { note in
            guard let date = note.blockTime else { return false }
            guard date >= draft.rangeStart, date <= draft.rangeEnd else { return false }
            return note.effectiveKind == .untagged
        }.count
        let pools = Array(Set(draft.rows.map(\.pool.displayName))).sorted()
        return PackDisclosureSummary(
            rowCount: draft.rows.count,
            incomeZEC: draft.rollups.incomeZEC,
            expenseZEC: draft.rollups.expenseZEC,
            feeZEC: draft.rollups.feeZEC,
            includesMemos: draft.includeMemos,
            includesChange: draft.includeChange,
            pools: pools,
            untaggedExcludedCount: untaggedExcluded,
            partialHistory: draft.partialHistory,
            recipientLabel: draft.recipientLabel,
            expiresAt: draft.expiresAt
        )
    }

    /// Short, plain-language lines for the Share UI and PDF footer.
    public var auditLines: [String] {
        var lines: [String] = []
        lines.append("\(rowCount) labeled transactions in this date range")
        lines.append(
            String(
                format: "Income %.4f ZEC · Expenses %.4f ZEC · Fees %.4f ZEC",
                NSDecimalNumber(decimal: incomeZEC).doubleValue,
                NSDecimalNumber(decimal: expenseZEC).doubleValue,
                NSDecimalNumber(decimal: feeZEC).doubleValue
            )
        )
        if includesMemos {
            lines.append("Transaction memos included")
        } else {
            lines.append("Transaction memos left out")
        }
        lines.append(includesChange ? "Transfers and change included" : "Transfers and change left out")
        if untaggedExcludedCount > 0 {
            lines.append("\(untaggedExcludedCount) unlabeled transactions left out")
        }
        if partialHistory {
            lines.append("History may be incomplete")
        }
        if let recipientLabel, !recipientLabel.isEmpty {
            lines.append("Prepared for \(recipientLabel)")
        }
        if let expiresAt {
            lines.append("Expires \(expiresAt.formatted(date: .abbreviated, time: .omitted))")
        }
        lines.append("Read-only — cannot move funds")
        return lines
    }
}
