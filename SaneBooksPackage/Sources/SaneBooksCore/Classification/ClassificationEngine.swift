import Foundation

public enum ClassificationEngine {
    /// UFVK: inbound in a tx that also has outbound → suggest `.change`.
    /// UIVK: never auto-assign change.
    public static func suggest(
        notes: [NoteRow],
        vaultMode: VaultMode,
        keyKind: ViewingKeyKind
    ) -> [NoteRow] {
        let allowAutoChange = (vaultMode == .bookkeeper)
            && (keyKind == .ufvk || keyKind == .legacySaplingFVK)
        let outboundTxids = Set(notes.filter { $0.direction == .outbound }.map(\.txid))

        return notes.map { note in
            var updated = note
            if note.direction == .outbound, abs(note.valueZatoshis) < 10000 {
                updated.suggestedClassification = .fee
                if updated.classification == nil {
                    updated.classification = Classification(kind: .fee, source: .autoFee)
                }
                return updated
            }
            if note.direction == .inbound || note.direction == .changeCandidate {
                if allowAutoChange, outboundTxids.contains(note.txid) {
                    updated.suggestedClassification = .change
                    updated.direction = .changeCandidate
                    if updated.classification == nil {
                        updated.classification = Classification(kind: .change, source: .autoChange)
                    }
                } else if note.direction == .inbound {
                    updated.suggestedClassification = .income
                } else {
                    updated.suggestedClassification = .untagged
                }
            } else if note.direction == .outbound {
                updated.suggestedClassification = .expense
            }
            return updated
        }
    }

    public static func suggest(
        for note: NoteRow,
        siblingsInTx: [NoteRow],
        vaultMode: VaultMode
    ) -> ClassificationKind {
        let batch = suggest(
            notes: [note] + siblingsInTx,
            vaultMode: vaultMode,
            keyKind: vaultMode == .bookkeeper ? .ufvk : .uivk
        )
        return batch.first(where: { $0.id == note.id })?.suggestedClassification ?? .untagged
    }

    public static func incomeTotalZatoshis(notes: [NoteRow]) -> Int64 {
        notes.reduce(into: Int64(0)) { total, note in
            guard note.classification?.kind == .income else { return }
            total += abs(note.valueZatoshis)
        }
    }

    public static func incomeTotalZEC(notes: [NoteRow]) -> Decimal {
        Decimal(incomeTotalZatoshis(notes: notes)) / Decimal(100_000_000)
    }

    public static func incomeYTD(notes: [NoteRow], year: Int, calendar: Calendar = .current) -> Decimal {
        let filtered = notes.filter { note in
            guard note.effectiveKind == .income, let date = note.blockTime else { return false }
            return calendar.component(.year, from: date) == year
        }
        return filtered.reduce(Decimal(0)) { $0 + abs($1.amountZEC) }
    }

    public static func expenseYTD(notes: [NoteRow], year: Int, calendar: Calendar = .current) -> Decimal {
        let filtered = notes.filter { note in
            guard note.effectiveKind == .expense, let date = note.blockTime else { return false }
            return calendar.component(.year, from: date) == year
        }
        return filtered.reduce(Decimal(0)) { $0 + abs($1.amountZEC) }
    }

    /// Apply memo auto-tag rules after `suggest`. Skips notes already classified by the user.
    /// Does not override auto-change / auto-fee classifications.
    public static func applyRules(_ rules: [TagRule], to notes: [NoteRow]) -> [NoteRow] {
        let active = rules.filter(\.enabled).filter { !$0.memoContains.isEmpty }
        guard !active.isEmpty else { return notes }

        return notes.map { note in
            if let source = note.classification?.source, source == .user || source == .autoChange || source == .autoFee {
                return note
            }
            guard let memoText = note.memo.displayText, !memoText.isEmpty else { return note }
            guard let match = active.first(where: {
                memoText.localizedCaseInsensitiveContains($0.memoContains)
            }) else {
                return note
            }
            var updated = note
            updated.classification = Classification(
                kind: match.kind,
                party: match.party,
                subtag: match.subtag,
                source: .rule
            )
            updated.suggestedClassification = match.kind
            return updated
        }
    }
}
