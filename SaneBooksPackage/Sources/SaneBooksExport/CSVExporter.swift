import Foundation
import SaneBooksCore

public enum CSVExporter {
    public static let columns = [
        "date", "kind", "party", "subtag", "amount_zec", "amount_fiat",
        "fiat_currency", "pool", "txid", "memo"
    ]

    public static func export(
        rows: [ProofPackRow],
        includeMemos: Bool = true,
        fiatCurrency: String = "USD"
    ) -> String {
        var lines: [String] = [columns.joined(separator: ",")]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        for row in rows {
            let memo = includeMemos ? (row.memoText ?? "") : ""
            let fiat = row.amountFiat.map { "\($0)" } ?? ""
            lines.append([
                formatter.string(from: row.date),
                row.kind.rawValue,
                csvEscape(row.party ?? ""),
                csvEscape(row.subtag ?? ""),
                "\(row.amountZEC)",
                fiat,
                row.fiatMark?.currency ?? fiatCurrency,
                row.pool.rawValue,
                row.txidTruncated,
                csvEscape(memo)
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}
