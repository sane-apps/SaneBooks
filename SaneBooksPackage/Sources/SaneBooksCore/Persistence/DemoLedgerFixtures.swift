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

/// Real mainnet UFVK from zcash-swift-wallet-sdk `DerivationToolMainnetTests`
/// (seed `9VDVOZZZ…`, Sapling `zs1vp7kvlqr4n9gpehztr76lcn6skkss9p8keqs3nv8avkdtjrcctrvmk9a7u494kluv756jeee5k0`).
/// Live lightwalletd sync — not mock.
public enum LiveProbeKey {
    public static let mainnetUFVK = """
    uview17fme6ux853km45g9ep07djpfzeydxxgm22xpmr7arzxyutlusalgpqlx7suga4ahzywfuwz4jclm00u7g8u65qvvdt45kttnfunvschssg3h3g06txs9ja32vx3xa8dej3unnat\
    gzjvd0vumk37t8es3ludldrtse3q6226ws7eq4q0ywz78nudwpepgdn7jmxz8yvp7k6gxkeynkam0f8aqf9qpeaej55zhkw39x7epayhndul0j4xjttdxxlnwcd09nr8svyx8j0zng0w6\
    scx3m5unpkaqxcm3hslhlfg4caz7r8d4xy9wm7klkg79w7j0uyzec5s3yje20eg946r6rmkf532nfydu26s8q9ua7mwxw2j2ag7hfcuu652gw6uta03vlm05zju3a9rwc4h367kqzfqrc\
    z35pdwdk2a7yqnk850un3ujxcvve45ueajgvtr6dj4ufszgqwdy0aedgmkalx2p7qed2suarwkr35dl0c8dnqp3
    """.replacingOccurrences(of: "\\\n", with: "").replacingOccurrences(of: "\n", with: "")

    /// Just after NU6.3 / Ironwood activation — short live scan window.
    public static let defaultBirthday: UInt32 = 3_430_000

    public static let saplingAddress =
        "zs1vp7kvlqr4n9gpehztr76lcn6skkss9p8keqs3nv8avkdtjrcctrvmk9a7u494kluv756jeee5k0"

    /// Unified address for the same account (DerivationToolMainnetTests).
    /// Send any small mainnet ZEC amount here, then live-sync to get a real ledger row.
    public static let unifiedAddress =
        "u1l9f0l4348negsncgr9pxd9d3qaxagmqv3lnexcplmufpq7muffvfaue6ksevfvd7wrz7xrvn95rc5zjtn7ugkmgh5rnxswmcj30y0pw52pn0zjvy38rn2esfgve64rj5pcmazxgpyuj"

    public static let transparentAddress = "t1dRJRY7GmyeykJnMH38mdQoaZtFhn1QmGz"

    public static let source =
        "zcash/zcash-swift-wallet-sdk DerivationToolMainnetTests (2.7.0-rc.4)"
}
