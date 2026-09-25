import CryptoKit
import Foundation
@testable import SaneBooksCore
@testable import SaneBooksExport
import Testing

@Suite("Cross-implementation proof pack")
struct GoldenPackVectorTests {
    @Test
    func swiftWriterMatchesRustGoldenAndOpens() throws {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime]
        func day(_ text: String) -> Date {
            parser.date(from: text)!
        }

        let row = try ProofPackRow(
            id: #require(UUID(uuidString: "00112233-4455-6677-8899-AABBCCDDEEFF")),
            date: day("2025-06-15T12:00:00Z"),
            kind: .income,
            party: "Client",
            amountZEC: #require(Decimal(string: "1.5")),
            memoText: "Invoice",
            pool: .ironwood,
            txidTruncated: "aabbccdd11223344"
        )
        let attestation = SyncAttestation(
            syncedToHeight: 3_500_000,
            chainTipAtExport: 3_500_000,
            lwdEndpointFingerprint: "lwd.example",
            exportedAt: day("2026-01-15T00:00:00Z"),
            vaultMode: .bookkeeper,
            poolsPresent: [.ironwood],
            ironwoodCapable: true
        )
        let draft = try ProofPackDraft(
            vaultFingerprint: "uview:a1b2c3d4e5f60708",
            vaultDisplayName: "Treasury",
            network: .mainnet,
            rangeStart: day("2025-01-01T00:00:00Z"),
            rangeEnd: day("2025-12-31T23:59:59Z"),
            rows: [row],
            rollups: ProofPackRollups(
                incomeZEC: #require(Decimal(string: "1.5")),
                byCategory: ["Client": #require(Decimal(string: "1.5"))]
            ),
            syncAttestation: attestation,
            partialHistory: false,
            expiresAt: day("2026-04-15T23:59:59Z"),
            vaultMode: .bookkeeper
        )
        let encoded = try PackWriter.seal(
            draft: draft,
            passphrase: "correct horse battery",
            salt: Data(repeating: 0x42, count: 16),
            nonceData: Data(repeating: 0x11, count: 12),
            sealedAt: day("2026-01-15T00:00:00Z")
        )
        let goldenURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("rust/testdata/swift-golden.sanebooks")
        let committed = try Data(contentsOf: goldenURL)
        #expect(encoded.data == committed)
        let opened = try PackReader.open(
            encoded.data,
            passphrase: "correct horse battery",
            now: day("2026-01-15T00:00:00Z")
        )
        #expect(opened.payload.rows.count == 1)
        #expect(opened.payload.rows[0].party == "Client")
        #expect(opened.header.vaultDisplayName == "Treasury")
    }
}
