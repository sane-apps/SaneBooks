import Foundation
import SaneBooksCore

public enum CSVExporter {
    public static let columns = [
        "date", "kind", "party", "subtag", "amount_zec", "amount_fiat",
        "fiat_currency", "pool", "txid", "memo",
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
                safeStringCell(row.kind.rawValue),
                safeStringCell(row.party ?? ""),
                safeStringCell(row.subtag ?? ""),
                "\(row.amountZEC)",
                fiat,
                safeStringCell(row.fiatMark?.currency ?? fiatCurrency),
                safeStringCell(row.pool.rawValue),
                safeStringCell(row.txidTruncated),
                safeStringCell(memo),
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func safeStringCell(_ value: String) -> String {
        csvEscape(neutralizeSpreadsheetFormula(value))
    }

    private static func neutralizeSpreadsheetFormula(_ value: String) -> String {
        guard let first = value.unicodeScalars.first else { return value }
        let formulaPrefixes: Set<Unicode.Scalar> = ["=", "+", "-", "@"]
        if formulaPrefixes.contains(first) || isControlOrFormat(first) {
            return "'" + value
        }

        let firstVisible = value.unicodeScalars.drop {
            CharacterSet.whitespacesAndNewlines.contains($0)
                || isControlOrFormat($0)
        }.first
        if let firstVisible, formulaPrefixes.contains(firstVisible) {
            return "'" + value
        }
        return value
    }

    private static func isControlOrFormat(_ scalar: Unicode.Scalar) -> Bool {
        CharacterSet.controlCharacters.contains(scalar)
            || scalar.value == 0xFEFF
            || (0x200B ... 0x200F).contains(scalar.value)
            || (0x2060 ... 0x2064).contains(scalar.value)
    }

    private static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}
