import Foundation
@testable import SaneBooksCore
@testable import SaneBooksExport
import Testing

@Suite("Pack round-trip")
struct PackExportTests {
    func sampleDraft(expiresAt: Date) -> ProofPackDraft {
        let row = ProofPackRow(
            date: Date(timeIntervalSince1970: 1_770_000_000),
            kind: .income,
            party: "Client",
            amountZEC: Decimal(string: "1.5")!,
            memoText: "Invoice",
            pool: .ironwood,
            txidTruncated: "aabbccdd…11223344"
        )
        let attestation = SyncAttestation(
            syncedToHeight: 3_500_000,
            chainTipAtExport: 3_500_000,
            lwdEndpointFingerprint: "sha256:deadbeef",
            vaultMode: .bookkeeper,
            poolsPresent: [.sapling, .orchard, .ironwood],
            ironwoodCapable: true
        )
        return ProofPackDraft(
            vaultFingerprint: "uview:a1b2c3d4e5f60708",
            vaultDisplayName: "Freelancer",
            network: .mainnet,
            rangeStart: Date(timeIntervalSince1970: 1_700_000_000),
            rangeEnd: Date(timeIntervalSince1970: 1_800_000_000),
            rows: [row],
            rollups: ProofPackRollups(incomeZEC: Decimal(string: "1.5")!),
            syncAttestation: attestation,
            partialHistory: false,
            expiresAt: expiresAt,
            vaultMode: .bookkeeper
        )
    }

    @Test func roundTripSucceeds() throws {
        let draft = sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400))
        let pack = try PackBuilder.build(
            draft: draft,
            passphrase: "correct horse battery",
            salt: Data(repeating: 0x42, count: 16),
            nonceData: Data(repeating: 0x11, count: 12)
        )
        #expect(pack.starts(with: Data("SANEBOOK".utf8)))

        let opened = try PackReader.open(pack, passphrase: "correct horse battery")
        #expect(opened.header.vaultFingerprint == "uview:a1b2c3d4e5f60708")
        #expect(opened.payload.rows.count == 1)
        #expect(opened.payload.rows[0].kind == .income)
        #expect(opened.header.kdf == "hkdf-sha256")
        #expect(opened.header.aead == "chacha20poly1305")
    }

    @Test func wrongPassphraseFails() throws {
        let pack = try PackBuilder.build(draft: sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400)), passphrase: "right")
        #expect(throws: SaneBooksError.wrongPassphrase) {
            _ = try PackReader.open(pack, passphrase: "wrong")
        }
    }

    @Test func expiredPackFails() throws {
        let pack = try PackBuilder.build(
            draft: sampleDraft(expiresAt: Date(timeIntervalSinceNow: -3600)),
            passphrase: "secret"
        )
        #expect(throws: SaneBooksError.expired) {
            _ = try PackReader.open(pack, passphrase: "secret", now: Date())
        }
    }

    @Test func noUviewKeyStringInPackBytes() throws {
        let fullUVK =
            "uview1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq"
        _ = fullUVK
        let pack = try PackBuilder.build(
            draft: sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400)),
            passphrase: "pass"
        )
        let packBytes = [UInt8](pack)
        let needle = Array(fullUVK.utf8)
        var found = false
        if packBytes.count >= needle.count {
            outer: for i in 0 ... (packBytes.count - needle.count) {
                for j in 0 ..< needle.count where packBytes[i + j] != needle[j] {
                    continue outer
                }
                found = true
                break
            }
        }
        #expect(!found)
        if let ascii = String(data: pack.prefix(500), encoding: .utf8) {
            #expect(!ascii.contains("uview1qqq"))
        }
    }

    @Test func csvExportsColumns() {
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

    @Test func partialPackRefusedWithoutAck() throws {
        var draft = sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400))
        draft.partialHistory = true
        draft.acknowledgePartialHistory = false
        #expect(throws: SaneBooksError.self) {
            _ = try PackWriter.seal(draft: draft, passphrase: "long-enough-pass")
        }
    }

    @Test func partialPackSealsWithAck() throws {
        var draft = sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400))
        draft.partialHistory = true
        draft.acknowledgePartialHistory = true
        let encoded = try PackWriter.seal(draft: draft, passphrase: "long-enough-pass")
        #expect(encoded.data.starts(with: Data("SANEBOOK".utf8)))
        #expect(encoded.integrityHash.count == 64)
    }

    @Test func pdfStartsWithMagicAndContainsFingerprint() {
        let draft = sampleDraft(expiresAt: Date(timeIntervalSinceNow: 86400))
        let pdf = PDFSummaryExporter.export(draft: draft, integrityHash: "abcdef0123456789")
        #expect(pdf.starts(with: Data("%PDF".utf8)))
        let ascii = String(decoding: pdf, as: UTF8.self)
        #expect(ascii.contains("uview:a1b2c3d4e5f60708"))
        #expect(ascii.contains("CANNOT SPEND"))
    }

    @Test func isPartialWhenNotCaughtUp() {
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

    @Test func disclosureSummaryListsRowsAndHonesty() {
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
        #expect(lines.contains(where: { $0.contains("tagged rows") }))
        #expect(lines.contains(where: { $0.contains("Memos included") }))
        #expect(lines.contains(where: { $0.contains("History may be incomplete") }))
        #expect(lines.contains(where: { $0.contains("View only") }))
        #expect(lines.contains(where: { $0.contains("Acme CPA") }))
    }
}
