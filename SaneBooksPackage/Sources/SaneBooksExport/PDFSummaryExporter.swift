import AppKit
import CoreText
import Foundation
import SaneBooksCore

/// Multi-page PDF summary for accountant-ready selective disclosure.
///
/// Core Text lays out the document into bounded page frames. This keeps long
/// names, identifiers, and Unicode text inside the printable area while the
/// system PDF context embeds the fonts Preview needs to render the result.
public enum PDFSummaryExporter {
    private static let pageSize = CGSize(width: 612, height: 792)
    private static let horizontalMargin: CGFloat = 48
    private static let headerBaseline: CGFloat = 744
    private static let bodyTop: CGFloat = 716
    private static let bodyBottom: CGFloat = 58
    private static let footerBaseline: CGFloat = 32

    public static func export(
        draft: ProofPackDraft,
        sourcePackPlaintextDigest: String? = nil
    ) throws -> Data {
        if let sourcePackPlaintextDigest {
            guard isSHA256HexDigest(sourcePackPlaintextDigest) else {
                throw SaneBooksError.pack("Invalid source proof-pack payload digest.")
            }
        }
        let document = documentText(
            draft: draft,
            sourcePackPlaintextDigest: sourcePackPlaintextDigest
        )
        let data = try renderPDF(document)
        try validatePDFData(data)
        return data
    }

    /// Refuses to persist an empty or non-PDF rendering result.
    public static func writeValidatedPDF(_ data: Data, to url: URL) throws {
        try validatePDFData(data)
        try data.write(to: url, options: .atomic)
    }

    public static func validatePDFData(_ data: Data) throws {
        let header = Data("%PDF".utf8)
        guard data.count > header.count, data.starts(with: header) else {
            throw SaneBooksError.pack("Could not create a valid PDF summary.")
        }
    }

    private static func documentText(
        draft: ProofPackDraft,
        sourcePackPlaintextDigest: String?
    ) -> NSAttributedString {
        let document = NSMutableAttributedString()

        document.appendParagraph(
            "CANNOT SPEND — This document cannot spend ZEC. No spending keys are included.",
            style: .warning
        )
        document.appendParagraph("Vault fingerprint: \(draft.vaultFingerprint)")
        document.appendParagraph("Vault: \(draft.vaultDisplayName)")
        document.appendParagraph(
            "Network: \(draft.network.displayName) · Mode: \(draft.vaultMode.rawValue)"
        )
        document.appendParagraph(
            "Range: \(isoDate(draft.rangeStart)) → \(isoDate(draft.rangeEnd))"
        )
        if draft.partialHistory {
            document.appendParagraph(
                "PARTIAL HISTORY — sync was not caught up or history may be incomplete.",
                style: .warning
            )
        }

        document.appendParagraph("Rollups", style: .section)
        document.appendParagraph(
            "Income: \(formatDecimal(draft.rollups.incomeZEC)) ZEC · "
                + "Expenses: \(formatDecimal(draft.rollups.expenseZEC)) ZEC · "
                + "Fees: \(formatDecimal(draft.rollups.feeZEC)) ZEC"
        )

        document.appendParagraph("Line items (\(draft.rows.count))", style: .section)
        for row in draft.rows {
            document.appendParagraph(
                "\(isoDate(row.date))  \(row.kind.displayName)  "
                    + "\(formatDecimal(row.amountZEC)) ZEC  \(row.party ?? "—")  "
                    + row.txidTruncated,
                style: .lineItem
            )
        }

        if let sourcePackPlaintextDigest {
            document.appendParagraph("Source .sanebooks integrity", style: .section)
            document.appendParagraph(
                "SHA-256 of canonical plaintext payload (digest field blanked): "
                    + sourcePackPlaintextDigest,
                style: .identifier
            )
        }

        document.appendParagraph("Sync verification", style: .section)
        document.appendParagraph(
            "Sync attestation: synced to \(draft.syncAttestation.syncedToHeight) via "
                + "\(draft.syncAttestation.lwdEndpointFingerprint)."
        )
        document.appendParagraph(draft.syncAttestation.disclaimer)
        document.appendParagraph(
            "LWD honesty: completeness assumes an honest lightwalletd; "
                + "omitted compact blocks understate income."
        )

        return document
    }

    private static func renderPDF(_ document: NSAttributedString) throws -> Data {
        let output = NSMutableData()
        guard let consumer = CGDataConsumer(data: output as CFMutableData) else {
            throw SaneBooksError.pack("Could not create the PDF output stream.")
        }

        var mediaBox = CGRect(origin: .zero, size: pageSize)
        let metadata = [kCGPDFContextTitle as String: "ZecBooks Proof Pack Summary"] as CFDictionary
        guard let context = CGContext(
            consumer: consumer,
            mediaBox: &mediaBox,
            metadata
        ) else {
            throw SaneBooksError.pack("Could not create the PDF rendering context.")
        }

        let framesetter = CTFramesetterCreateWithAttributedString(document)
        let bodyRect = CGRect(
            x: horizontalMargin,
            y: bodyBottom,
            width: pageSize.width - horizontalMargin * 2,
            height: bodyTop - bodyBottom
        )
        let bodyPath = CGPath(rect: bodyRect, transform: nil)
        let pageRanges = try pageRanges(
            for: document,
            framesetter: framesetter,
            bodyPath: bodyPath
        )

        for (index, range) in pageRanges.enumerated() {
            context.beginPDFPage(nil)
            context.textMatrix = .identity

            drawPageHeader(pageIndex: index, in: context)
            let frame = CTFramesetterCreateFrame(framesetter, range, bodyPath, nil)
            CTFrameDraw(frame, context)
            drawPageFooter(
                currentPage: index + 1,
                pageCount: pageRanges.count,
                in: context
            )

            context.endPDFPage()
        }

        context.closePDF()
        return output as Data
    }

    private static func pageRanges(
        for document: NSAttributedString,
        framesetter: CTFramesetter,
        bodyPath: CGPath
    ) throws -> [CFRange] {
        var ranges: [CFRange] = []
        var location = 0

        repeat {
            let requested = CFRange(location: location, length: 0)
            let frame = CTFramesetterCreateFrame(framesetter, requested, bodyPath, nil)
            let visible = CTFrameGetVisibleStringRange(frame)
            guard visible.length > 0 else { break }
            ranges.append(visible)
            location += visible.length
        } while location < document.length

        guard !ranges.isEmpty else {
            throw SaneBooksError.pack("Could not lay out the PDF summary.")
        }
        return ranges
    }

    private static func drawPageHeader(pageIndex: Int, in context: CGContext) {
        let text = pageIndex == 0
            ? "ZecBooks — Proof Pack Summary"
            : "ZecBooks — Proof Pack Summary (cont.)"
        let style: PDFTextStyle = pageIndex == 0 ? .title : .continuationTitle
        drawLine(text, style: style, at: CGPoint(x: horizontalMargin, y: headerBaseline), in: context)
    }

    private static func drawPageFooter(
        currentPage: Int,
        pageCount: Int,
        in context: CGContext
    ) {
        let text = "Page \(currentPage) of \(pageCount) · View-only proof summary"
        drawLine(text, style: .footer, at: CGPoint(x: horizontalMargin, y: footerBaseline), in: context)
    }

    private static func drawLine(
        _ text: String,
        style: PDFTextStyle,
        at point: CGPoint,
        in context: CGContext
    ) {
        let attributed = NSAttributedString(string: text, attributes: style.attributes)
        let line = CTLineCreateWithAttributedString(attributed)
        context.textPosition = point
        CTLineDraw(line, context)
    }

    private static func isoDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }

    private static func formatDecimal(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value)
        return String(format: "%.8f", number.doubleValue)
    }

    private static func isSHA256HexDigest(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy { byte in
            (48 ... 57).contains(byte) || (97 ... 102).contains(byte)
        }
    }
}

private enum PDFTextStyle {
    case body
    case continuationTitle
    case footer
    case identifier
    case lineItem
    case section
    case title
    case warning

    var attributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 2
        paragraph.paragraphSpacing = paragraphSpacing

        if self == .lineItem || self == .identifier {
            // Character wrapping guarantees that a long identifier or a party
            // name without spaces cannot cross the printable boundary.
            paragraph.lineBreakMode = .byCharWrapping
        }

        return [
            .font: font,
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraph,
        ]
    }

    private var font: NSFont {
        switch self {
        case .title:
            NSFont.systemFont(ofSize: 16, weight: .bold)
        case .continuationTitle, .section:
            NSFont.systemFont(ofSize: 12, weight: .semibold)
        case .warning:
            NSFont.systemFont(ofSize: 10, weight: .bold)
        case .footer:
            NSFont.systemFont(ofSize: 9, weight: .regular)
        case .identifier:
            NSFont.monospacedSystemFont(ofSize: 9, weight: .regular)
        case .body, .lineItem:
            NSFont.systemFont(ofSize: 10, weight: .regular)
        }
    }

    private var paragraphSpacing: CGFloat {
        switch self {
        case .section:
            6
        case .warning:
            8
        case .lineItem:
            3
        case .body, .identifier:
            5
        case .continuationTitle, .footer, .title:
            0
        }
    }
}

private extension NSMutableAttributedString {
    func appendParagraph(
        _ text: String,
        style: PDFTextStyle = .body
    ) {
        append(NSAttributedString(string: text + "\n", attributes: style.attributes))
    }
}
