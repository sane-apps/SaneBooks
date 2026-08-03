import Foundation

/// Demo fixture notes for MockSyncFacade offline E2E.
public enum DemoLedgerFixtures {
    public static let fixtureMainnetUFVK =
        "uview1qqqsyqcyq5rqwzqfpg9scrgwpugpzysnzs23v9ccrydpk8qarc0jqgfzyvjz2f389q5j52ev95hz7vp3xgengdfkxuurjw3m8s7nu06qg9pyx3z99c744z"
    public static let fixtureTestnetUFVK =
        "uviewtest1qqqsyqcyq5rqwzqfpg9scrgwpugpzysnzs23v9ccrydpk8qarc0jqgfzyvjz2f389q5j52ev95hz7vp3xgengdfkxuurjw3m8s7nu06qg9pyx3z96ex5f4"

    public static func notes(for vaultID: VaultID) -> [NoteRow] {
        let cal = Calendar.current
        func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 14, _ min: Int = 0) -> Date {
            var c = DateComponents()
            c.year = y; c.month = m; c.day = d; c.hour = h; c.minute = min
            return cal.date(from: c) ?? Date()
        }

        let rate = FiatMark(
            ratePerZEC: Decimal(string: "57.0")!,
            asOf: date(2026, 7, 12),
            source: .oracleSnapshot
        )

        return [
            NoteRow(
                id: .stable(vaultID: vaultID, txid: Data((0 ..< 32).map { UInt8($0) })),
                vaultID: vaultID,
                txid: Data((0 ..< 32).map { UInt8($0) }),
                blockHeight: 2_850_100,
                blockTime: date(2026, 8, 1, 10, 12),
                pool: .ironwood,
                direction: .inbound,
                valueZatoshis: 120_000_000,
                memo: .text("Invoice 441 — June retainer"),
                suggestedClassification: .income,
                classification: Classification(kind: .income, party: "Client X", subtag: "Consulting", source: .user),
                fiatMark: rate
            ),
            NoteRow(
                id: .stable(vaultID: vaultID, txid: Data((1 ..< 33).map { UInt8($0) })),
                vaultID: vaultID,
                txid: Data((1 ..< 33).map { UInt8($0) }),
                blockHeight: 2_849_800,
                blockTime: date(2026, 7, 28, 16, 40),
                pool: .orchard,
                direction: .changeCandidate,
                valueZatoshis: 5_000_000,
                memo: .empty,
                suggestedClassification: .change,
                classification: Classification(kind: .change, source: .autoChange),
                fiatMark: rate
            ),
            NoteRow(
                id: .stable(vaultID: vaultID, txid: Data((2 ..< 34).map { UInt8($0) })),
                vaultID: vaultID,
                txid: Data((2 ..< 34).map { UInt8($0) }),
                blockHeight: 2_849_800,
                blockTime: date(2026, 7, 28, 16, 40),
                pool: .orchard,
                direction: .outbound,
                valueZatoshis: -40_000_000,
                memo: .text("VPN"),
                suggestedClassification: .expense,
                classification: Classification(kind: .expense, party: "Tools", subtag: "VPN", source: .user),
                fiatMark: rate
            ),
            NoteRow(
                id: .stable(vaultID: vaultID, txid: Data((3 ..< 35).map { UInt8($0) })),
                vaultID: vaultID,
                txid: Data((3 ..< 35).map { UInt8($0) }),
                blockHeight: 2_840_000,
                blockTime: date(2026, 7, 12, 14, 2),
                pool: .orchard,
                direction: .inbound,
                valueZatoshis: 200_000_000,
                memo: .empty,
                suggestedClassification: .income,
                classification: nil,
                fiatMark: FiatMark(
                    ratePerZEC: Decimal(string: "55.06")!,
                    asOf: date(2026, 7, 12),
                    source: .oracleSnapshot
                )
            ),
            NoteRow(
                id: .stable(vaultID: vaultID, txid: Data((4 ..< 36).map { UInt8($0) })),
                vaultID: vaultID,
                txid: Data((4 ..< 36).map { UInt8($0) }),
                blockHeight: 2_849_800,
                blockTime: date(2026, 7, 28, 16, 40),
                pool: .orchard,
                direction: .outbound,
                valueZatoshis: -1_000_000,
                memo: .empty,
                suggestedClassification: .fee,
                classification: Classification(kind: .fee, source: .autoFee),
                fiatMark: rate
            ),
            NoteRow(
                id: .stable(vaultID: vaultID, txid: Data((5 ..< 37).map { UInt8($0) })),
                vaultID: vaultID,
                txid: Data((5 ..< 37).map { UInt8($0) }),
                blockHeight: 2_820_000,
                blockTime: date(2026, 6, 15, 9, 0),
                pool: .sapling,
                direction: .inbound,
                valueZatoshis: 980_000_000,
                memo: .text("Product sale"),
                suggestedClassification: .income,
                classification: Classification(kind: .income, party: "Shop", subtag: "Product", source: .user),
                fiatMark: FiatMark(
                    ratePerZEC: Decimal(string: "52.0")!,
                    asOf: date(2026, 6, 15),
                    source: .oracleSnapshot
                )
            )
        ]
    }
}
