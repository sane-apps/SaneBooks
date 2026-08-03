import Foundation
import SaneBooksCore

/// Multi-page PDF summary for accountant-ready selective disclosure.
/// Uses an uncompressed PDF 1.4 writer so integrity strings and fingerprints
/// remain searchable in file bytes (and open in Preview / Acrobat).
public enum PDFSummaryExporter {
    private static let pageWidth = 612
    private static let pageHeight = 792
    private static let margin = 48
    private static let lineHeight = 14

    public static func export(draft: ProofPackDraft, integrityHash: String? = nil) -> Data {
        let hash = integrityHash ?? "pending"
        var pages: [[String]] = []
        var lines: [String] = []

        func flushIfNeeded(reserve: Int = 4) {
            let maxLines = (pageHeight - margin * 2) / lineHeight - 2
            if lines.count + reserve > maxLines {
                pages.append(lines)
                lines = ["SaneBooks — Proof Pack Summary (cont.)", ""]
            }
        }

        lines.append("SaneBooks — Proof Pack Summary")
        lines.append("")
        lines.append("CANNOT SPEND — This document cannot spend ZEC. No spending keys are included.")
        lines.append("")
        lines.append("Vault fingerprint: \(draft.vaultFingerprint)")
        lines.append("Vault: \(draft.vaultDisplayName)")
        lines.append("Network: \(draft.network.displayName) · Mode: \(draft.vaultMode.rawValue)")
        lines.append("Range: \(isoDate(draft.rangeStart)) → \(isoDate(draft.rangeEnd))")
        if draft.partialHistory {
            lines.append("PARTIAL HISTORY — sync was not caught up or history may be incomplete.")
        }
        lines.append("")
        lines.append("Rollups")
        lines.append(
            "Income: \(formatDecimal(draft.rollups.incomeZEC)) ZEC · Expenses: \(formatDecimal(draft.rollups.expenseZEC)) ZEC · Fees: \(formatDecimal(draft.rollups.feeZEC)) ZEC"
        )
        lines.append("")
        lines.append("Line items (\(draft.rows.count))")
        for row in draft.rows {
            flushIfNeeded()
            lines.append(
                "\(isoDate(row.date))  \(row.kind.displayName)  \(formatDecimal(row.amountZEC)) ZEC  \(row.party ?? "—")  \(row.txidTruncated)"
            )
        }
        lines.append("")
        flushIfNeeded(reserve: 8)
        lines.append("Integrity: sha256:\(hash)")
        lines.append(
            "Sync attestation: synced to \(draft.syncAttestation.syncedToHeight) via \(draft.syncAttestation.lwdEndpointFingerprint)."
        )
        lines.append(draft.syncAttestation.disclaimer)
        lines.append(
            "LWD honesty: completeness assumes an honest lightwalletd; omitted compact blocks understate income."
        )
        pages.append(lines)

        return buildPDF(pages: pages)
    }

    // MARK: - Minimal uncompressed PDF

    private static func buildPDF(pages: [[String]]) -> Data {
        var objects: [Data] = []
        // Object 1: Catalog
        objects.append(Data("<< /Type /Catalog /Pages 2 0 R >>".utf8))

        var pageObjectNumbers: [Int] = []
        var nextObj = 3 // 1=catalog, 2=pages, then page/content pairs

        var kids: [String] = []
        var contentObjects: [(pageObj: Int, contentObj: Int, stream: Data)] = []

        for pageLines in pages {
            let pageObj = nextObj
            let contentObj = nextObj + 1
            nextObj += 2
            pageObjectNumbers.append(pageObj)
            kids.append("\(pageObj) 0 R")
            let stream = contentStream(for: pageLines)
            contentObjects.append((pageObj, contentObj, stream))
        }

        // Object 2: Pages
        let pagesDict =
            "<< /Type /Pages /Kids [\(kids.joined(separator: " "))] /Count \(pages.count) >>"
        // Rebuild objects array properly
        var numbered: [(Int, Data)] = []
        numbered.append((1, Data("<< /Type /Catalog /Pages 2 0 R >>".utf8)))
        numbered.append((2, Data(pagesDict.utf8)))

        for item in contentObjects {
            let pageDict =
                "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 \(pageWidth) \(pageHeight)] /Contents \(item.contentObj) 0 R /Resources << /Font << /F1 \(nextObj) 0 R >> >> >>"
            numbered.append((item.pageObj, Data(pageDict.utf8)))
            var streamObj = Data()
            streamObj.append(Data("<< /Length \(item.stream.count) >>\nstream\n".utf8))
            streamObj.append(item.stream)
            streamObj.append(Data("\nendstream".utf8))
            numbered.append((item.contentObj, streamObj))
        }

        // Font object
        let fontObj = nextObj
        numbered.append((fontObj, Data("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>".utf8)))

        // Fix font refs in page dicts — rebuild pages with correct font obj
        numbered = [(1, Data("<< /Type /Catalog /Pages 2 0 R >>".utf8))]
        numbered.append((2, Data(pagesDict.utf8)))
        for item in contentObjects {
            let pageDict =
                "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 \(pageWidth) \(pageHeight)] /Contents \(item.contentObj) 0 R /Resources << /Font << /F1 \(fontObj) 0 R >> >> >>"
            numbered.append((item.pageObj, Data(pageDict.utf8)))
            var streamObj = Data()
            streamObj.append(Data("<< /Length \(item.stream.count) >>\nstream\n".utf8))
            streamObj.append(item.stream)
            streamObj.append(Data("\nendstream".utf8))
            numbered.append((item.contentObj, streamObj))
        }
        numbered.append((fontObj, Data("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>".utf8)))

        numbered.sort { $0.0 < $1.0 }

        var pdf = Data("%PDF-1.4\n".utf8)
        var offsets = [0]
        for (num, body) in numbered {
            offsets.append(pdf.count)
            pdf.append(Data("\(num) 0 obj\n".utf8))
            pdf.append(body)
            pdf.append(Data("\nendobj\n".utf8))
        }
        let xrefStart = pdf.count
        pdf.append(Data("xref\n0 \(numbered.count + 1)\n".utf8))
        pdf.append(Data("0000000000 65535 f \n".utf8))
        for i in 1 ... numbered.count {
            let off = offsets[i]
            pdf.append(Data(String(format: "%010d 00000 n \n", off).utf8))
        }
        pdf.append(Data("trailer\n<< /Size \(numbered.count + 1) /Root 1 0 R >>\nstartxref\n\(xrefStart)\n%%EOF\n".utf8))
        return pdf
    }

    private static func contentStream(for lines: [String]) -> Data {
        var s = "BT\n/F1 11 Tf\n"
        var y = pageHeight - margin
        for (idx, line) in lines.enumerated() {
            let fontSize = idx == 0 && line.hasPrefix("SaneBooks") ? 16 : (line.hasPrefix("CANNOT SPEND") ? 11 : 10)
            let escaped = escapePDF(line)
            if idx == 0 {
                s += "/F1 \(fontSize) Tf\n1 0 0 1 \(margin) \(y) Tm\n(\(escaped)) Tj\n"
            } else {
                y -= lineHeight
                s += "/F1 \(fontSize) Tf\n1 0 0 1 \(margin) \(y) Tm\n(\(escaped)) Tj\n"
            }
        }
        s += "ET\n"
        return Data(s.utf8)
    }

    private static func escapePDF(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "(", with: "\\(")
            .replacingOccurrences(of: ")", with: "\\)")
    }

    private static func isoDate(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.string(from: date)
    }

    private static func formatDecimal(_ value: Decimal) -> String {
        let n = NSDecimalNumber(decimal: value)
        return String(format: "%.8f", n.doubleValue)
    }
}
