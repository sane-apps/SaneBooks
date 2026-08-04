import SaneBooksCore
import SwiftUI

struct NoteRowView: View {
    @Environment(\.saneBooksTextScale) private var textScale

    let note: NoteRow
    let truncateTxid: Bool
    var discreetMode: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: LedgerColumns.spacing) {
                Text(dateLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .frame(width: LedgerColumns.date * textScale, alignment: .leading)

                kindChip
                    .frame(width: LedgerColumns.kind * textScale, alignment: .leading)

                Text(discreetMode ? "••••" : formatZEC(abs(note.amountZEC)))
                    .lineLimit(1)
                    .frame(width: LedgerColumns.zec * textScale, alignment: .trailing)
                    .saneBooksFont(size: SaneBooksType.body, weight: .semibold, design: .monospaced)
                    .foregroundStyle(note.effectiveKind == .income ? Color.saneBooksAccentSoft : .white)

                if discreetMode {
                    Text("••••")
                        .lineLimit(1)
                        .frame(width: LedgerColumns.usd * textScale, alignment: .trailing)
                        .saneBooksFont(size: SaneBooksType.body, weight: .medium, design: .monospaced)
                } else if let fiat = note.fiatMark?.amount(forZEC: abs(note.amountZEC)) {
                    Text("$\(formatFiat(fiat))")
                        .lineLimit(1)
                        .frame(width: LedgerColumns.usd * textScale, alignment: .trailing)
                        .saneBooksFont(size: SaneBooksType.body, weight: .medium, design: .monospaced)
                } else {
                    Text("—")
                        .frame(width: LedgerColumns.usd * textScale, alignment: .trailing)
                }

                Text(tagLabel)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: LedgerColumns.tag * textScale, alignment: .leading)
                    .help(tagLabel)

                Text(note.memo.displayText ?? "—")
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .help(note.memo.displayText ?? "")
            }
            .saneBooksFont(size: SaneBooksType.body, weight: .medium)
            .foregroundStyle(.white)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
            .overlay(alignment: .leading) {
                if note.effectiveKind == .untagged {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.saneBooksAccentSoft)
                        .frame(width: 3)
                        .padding(.vertical, 6)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Open transaction details")
        .accessibilityIdentifier("sanebooks.ledger.note-row")
    }

    private var dateLabel: String {
        guard let date = note.blockTime else { return "—" }
        return date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    private var kindChip: some View {
        Text(kindLabel)
            .saneBooksFont(size: 11, weight: .bold)
            .foregroundStyle(kindChipForeground)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(kindChipBackground)
            .clipShape(Capsule())
    }

    private var kindChipBackground: Color {
        switch note.effectiveKind {
        case .income: Color.saneBooksAccent.opacity(0.22)
        case .expense: Color.orange.opacity(0.22)
        case .change: Color.white.opacity(0.12)
        case .fee: Color.white.opacity(0.10)
        case .untagged: Color.saneBooksAccentSoft.opacity(0.28)
        case .excluded: Color.white.opacity(0.08)
        }
    }

    private var kindChipForeground: Color {
        switch note.effectiveKind {
        case .income: Color.saneBooksAccentSoft
        case .expense: Color.orange
        case .change, .fee, .excluded: Color.white
        case .untagged: Color.saneBooksAccentSoft
        }
    }

    private var kindLabel: String {
        switch note.direction {
        case .inbound: "↓ \(note.effectiveKind.displayName)"
        case .outbound: "↑ \(note.effectiveKind.displayName)"
        case .changeCandidate: "↕ \(note.effectiveKind.displayName)"
        }
    }

    private var tagLabel: String {
        if let party = note.classification?.party, let sub = note.classification?.subtag {
            return "\(party) · \(sub)"
        }
        return note.classification?.party ?? note.classification?.subtag ?? "—"
    }

    private var accessibilityLabel: String {
        if discreetMode {
            return "Transaction on \(dateLabel), \(note.effectiveKind.displayName). Private financial details are masked."
        }

        let amount = "\(formatZEC(abs(note.amountZEC))) ZEC"
        let fiat: String
        if let markedAmount = note.fiatMark?.amount(forZEC: abs(note.amountZEC)) {
            fiat = "$\(formatFiat(markedAmount))"
        } else {
            fiat = "no fiat mark"
        }
        let memo = note.memo.displayText ?? "no memo"
        return "\(dateLabel), \(note.effectiveKind.displayName), \(amount), \(fiat), tag \(tagLabel), memo \(memo)."
    }
}
