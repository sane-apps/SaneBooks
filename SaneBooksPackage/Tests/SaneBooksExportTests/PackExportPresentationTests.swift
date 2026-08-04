import Foundation
import PDFKit
@testable import SaneBooksCore
@testable import SaneBooksExport
import Testing

extension PackExportTests {
    @Test
    func csvExportsColumns() {
        let row = ProofPackRow(
            date: Date(timeIntervalSince1970: 0),
            kind: .income,
            amountZEC: 1,
            pool: .sapling,
            txidTruncated: "abcd"
        )
        let csv = CSVExporter.export(rows: [row])
        #expect(csv.contains("date,kind,party"))
        #expect(csv.contains("income"))
    }

    @Test(arguments: [
        "=1+1", "+1", "-1", "@SUM(1,1)", "\t=1", "\r+1", "\n@1",
        " =1", "\u{00a0}@1", "\u{0000}-1", "\u{2003}+1", "\u{feff}=1", "\u{200b}@1"
    ])
    func csvNeutralizesSpreadsheetFormulaPrefixes(value: String) {
        let row = ProofPackRow(
            date: Date(timeIntervalSince1970: 0),
            kind: .income,
            party: value,
            subtag: value,
            amountZEC: 1,
            memoText: value,
            pool: .sapling,
            txidTruncated: value
        )
        let csv = CSVExporter.export(rows: [row], fiatCurrency: value)
        #expect(csv.contains("'" + value))
        #expect(!csv.contains("," + value + ","))
    }

    @Test
    func csvPreservesBenignTextAndNumericAmounts() {
        let row = ProofPackRow(
            date: Date(timeIntervalSince1970: 0),
            kind: .expense,
            party: "Invoice 42",
            amountZEC: -1.25,
            pool: .orchard,
            txidTruncated: "abc-123"
        )
        let csv = CSVExporter.export(rows: [row])
        #expect(csv.contains(",Invoice 42,"))
        #expect(csv.contains(",-1.25,"))
        #expect(!csv.contains("'-1.25"))
    }

    @Test
    func partialPackRefusedWithoutAck() throws {
        var draft = sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400))
        draft.partialHistory = true
        draft.acknowledgePartialHistory = false
        #expect(throws: SaneBooksError.self) {
            _ = try PackWriter.seal(draft: draft, passphrase: "correct horse battery")
        }
    }

    @Test
    func partialPackSealsWithAck() throws {
        var draft = sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400))
        draft.partialHistory = true
        draft.acknowledgePartialHistory = true
        let encoded = try PackWriter.seal(draft: draft, passphrase: "correct horse battery")
        #expect(encoded.data.starts(with: Data("SANEBOOK".utf8)))
        let expectedDigestHexLength = 32 * 2
        #expect(encoded.integrityHash.count == expectedDigestHexLength)
    }

    @Test
    func pdfIsPreviewCompatibleAndContainsDisclosureText() throws {
        let draft = sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400))
        let digest = String(repeating: "a", count: 64)
        let pdf = try PDFSummaryExporter.export(
            draft: draft,
            sourcePackPlaintextDigest: digest
        )
        #expect(pdf.starts(with: Data("%PDF".utf8)))
        let document = try #require(PDFDocument(data: pdf))
        #expect(document.pageCount == 1)
        let text = try #require(document.string)
        #expect(text.contains("uview:a1b2c3d4e5f60708"))
        #expect(text.contains("CANNOT SPEND"))
        #expect(text.contains("Source .sanebooks integrity"))
        #expect(text.contains("SHA-256 of canonical plaintext payload (digest field blanked):"))
        #expect(text.replacingOccurrences(of: "\n", with: "").contains(digest))
        #expect(!text.contains("sha256:pending"))
    }

    @Test
    func ownerPDFDoesNotClaimToEmbedItsOwnFileDigest() throws {
        let pdf = try PDFSummaryExporter.export(
            draft: sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400))
        )
        let document = try #require(PDFDocument(data: pdf))
        let text = try #require(document.string)
        #expect(!text.contains("Source .sanebooks integrity"))
        #expect(!text.contains("canonical plaintext payload"))
        #expect(!text.contains("sha256:pending"))
        #expect(text.contains("Sync verification"))
    }

    @Test
    func invalidPDFDataIsRejectedBeforeWrite() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SaneBooksInvalidPDF-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        let existing = Data("existing receipt".utf8)
        try existing.write(to: url)

        #expect(throws: SaneBooksError.pack("Could not create a valid PDF summary.")) {
            try PDFSummaryExporter.writeValidatedPDF(Data(), to: url)
        }
        #expect(try Data(contentsOf: url) == existing)

        #expect(throws: SaneBooksError.pack("Could not create a valid PDF summary.")) {
            try PDFSummaryExporter.writeValidatedPDF(Data("not a pdf".utf8), to: url)
        }
        #expect(try Data(contentsOf: url) == existing)
    }

    @Test
    func invalidSourcePayloadDigestIsRejected() {
        #expect(throws: SaneBooksError.pack("Invalid source proof-pack payload digest.")) {
            _ = try PDFSummaryExporter.export(
                draft: sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400)),
                sourcePackPlaintextDigest: "pending"
            )
        }
    }

    @Test
    func pdfWrapsUnicodeAndPaginatesWithoutBlankOrOversizedPages() throws {
        var draft = sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400))
        let expectedRowCount = 180
        let letterPageSize = CGSize(width: 612, height: 792)
        let longParty = "München 東京 Société-" + String(repeating: "帳", count: 180)
        draft.vaultDisplayName = "経理 — Café München"
        draft.rows = (0 ..< expectedRowCount).map { index in
            ProofPackRow(
                date: Date(timeIntervalSince1970: 1_770_000_000 + Double(index * 60)),
                kind: index.isMultiple(of: 2) ? .income : .expense,
                party: longParty,
                amountZEC: Decimal(index) / 100,
                memoText: "Facture numéro \(index)",
                pool: .ironwood,
                txidTruncated: String(repeating: "a", count: 160)
            )
        }

        let pdf = try PDFSummaryExporter.export(
            draft: draft,
            sourcePackPlaintextDigest: String(repeating: "f", count: 64)
        )
        let document = try #require(PDFDocument(data: pdf))
        #expect(document.pageCount > 2)

        let extracted = try #require(document.string)
        #expect(extracted.contains("経理 — Café München"))
        #expect(extracted.contains("München 東京 Société"))
        #expect(extracted.contains("Line items (\(expectedRowCount))"))
        #expect(extracted.contains("Page 1 of \(document.pageCount)"))
        #expect(extracted.contains("Page \(document.pageCount) of \(document.pageCount)"))

        for pageIndex in 0 ..< document.pageCount {
            let page = try #require(document.page(at: pageIndex))
            let bounds = page.bounds(for: .mediaBox)
            #expect(bounds.width == letterPageSize.width)
            #expect(bounds.height == letterPageSize.height)
            #expect(!(page.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    @Test
    func tenThousandRowLedgerExportsAndRoundTrips() throws {
        var draft = sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400))
        let baseRow = try #require(draft.rows.first)
        let rowCount = 10000
        draft.rows = (0 ..< rowCount).map { index in
            var row = baseRow
            row.id = UUID()
            row.date = Date(timeIntervalSince1970: 1_700_000_000 + Double(index))
            row.kind = index.isMultiple(of: 2) ? .income : .expense
            row.txidTruncated = String(format: "%08x…%08x", index, rowCount - index)
            return row
        }
        draft.rollups = PackSemanticValidator.rollups(
            for: draft.rows,
            fiatCurrency: draft.rollups.fiatCurrency
        )

        let csv = CSVExporter.export(rows: draft.rows)
        #expect(csv.split(separator: "\n").count == rowCount + 1)
        #expect(csv.contains("00000000…00002710"))
        #expect(csv.contains("0000270f…00000001"))

        let pack = try PackBuilder.build(
            draft: draft,
            passphrase: "correct horse battery",
            salt: Data(repeating: 0x42, count: 16),
            nonceData: Data(repeating: 0x11, count: 12)
        )
        #expect(pack.count < PackReader.maximumContainerBytes)
        let opened = try PackReader.open(pack, passphrase: "correct horse battery")
        #expect(opened.payload.rows.count == rowCount)
        #expect(opened.payload.rows.first?.txidTruncated == "00000000…00002710")
        #expect(opened.payload.rows.last?.txidTruncated == "0000270f…00000001")
    }

    @Test
    func isPartialWhenNotCaughtUp() {
        let cursor = SyncCursor(
            vaultID: VaultID(),
            birthdayHeight: 1,
            status: .scanning,
            capabilityReport: .demoMock
        )
        #expect(PackBuilder.isPartialHistory(cursor: cursor))
        var caught = cursor
        caught.status = .caughtUp
        caught.isDemo = false
        #expect(!PackBuilder.isPartialHistory(cursor: caught))
    }

    @Test
    func disclosureSummaryListsRowsAndHonesty() {
        let draft = sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400 * 30))
        var withPartial = draft
        withPartial.partialHistory = true
        withPartial.includeMemos = true
        withPartial.recipientLabel = "Acme CPA"
        let summary = PackDisclosureSummary.from(draft: withPartial, allNotes: [])
        #expect(summary.rowCount == 1)
        #expect(summary.incomeZEC == Decimal(string: "1.5"))
        #expect(summary.includesMemos)
        let lines = summary.auditLines
        #expect(lines.contains(where: { $0.contains("labeled transactions") }))
        #expect(lines.contains(where: { $0.contains("Transaction memos included") }))
        #expect(lines.contains(where: { $0.contains("History may be incomplete") }))
        #expect(lines.contains(where: { $0.contains("Read-only") }))
        #expect(lines.contains(where: { $0.contains("Acme CPA") }))
    }
}
