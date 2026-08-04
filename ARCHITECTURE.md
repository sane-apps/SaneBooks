# SaneBooks Architecture (summary)

Thin Xcode app + SPM package with four libraries:

```
App (SaneBooks) → Feature → {Core, Sync, Export, SaneUI}
Sync → Core
Export → Core
```

## Modules

| Product | Responsibility |
|---------|----------------|
| **SaneBooksCore** | Vault, NoteRow, Classification, TagRule, ShareHistoryEntry, ViewingKeyValidator, LedgerStore (File + InMemory), ZIP302, VaultModeBanner |
| **SaneBooksSync** | `SyncFacade`, `MockSyncFacade`, `BlockedSyncFacade`, `LightClientSyncFacade`, `ZcashSDKEngine` (ZcashLightClientKit 2.7.0-rc.4 view-only), `CapabilityProbe` |
| **SaneBooksExport** | PackBuilder, PackCrypto/PackWriter, PackReader, CSVExporter, PDFSummaryExporter |
| **SaneBooksFeature** | SwiftUI E2E screens + `AppModel` (multi-vault, share history, tag rules, partial-history ack) |

The package graph is deterministic: SaneUI is always fetched at exact revision
`0894c053345a86b549ea1ee329a4ff3b20826061`. A sibling checkout is never selected
implicitly, so the same SaneBooks commit cannot compile different UI code merely
because of the host filesystem.

## Invariants

- No spend APIs on the public Sync surface
- Imported UVK source text is held in Keychain (`WhenUnlockedThisDeviceOnly`), never the JSON ledger. Live sync also requires the official SDK to persist viewing-account material in its local `data.db`; the per-vault SDK tree is backup-excluded and owner-only (`0700` directories / `0600` existing files).
- `.sanebooks` v2 = magic/version + minimal KDF parameters + ChaCha20-Poly1305 ciphertext; private vault/recipient/range/network/completeness metadata is inside authenticated ciphertext; no UVK
- Pack open recomputes rollups/category totals, row date membership, pool membership, and sync-height invariants; shared-passphrase authentication is not sender identity or independent chain proof
- Mainnet “complete books” gated on Sapling+Orchard+Ironwood capability
- Pack seal refused when `partialHistory && !acknowledgePartialHistory`
- Human passphrases are normalized and hardened with PBKDF2-HMAC-SHA256 at 600,000 iterations; v1 is rejected with re-export guidance
- Ledger directories/files are owner-only (`0700`/`0600`) and atomic writes roll in-memory state back on failure
- Zashi identities are stable `(txid, pool, output index)` keys; re-import merges user classifications/fiat marks/pack selections rather than replacing them
- Imports are bounded, transactional reads and do not infer a chain tip from the largest local note height
- SDK storage refuses symbolic links, is re-hardened after account import, and is purged with the vault
- The encoded ledger has one 100 MiB budget for both persistence and reload; a failed or oversize mutation restores the prior in-memory state and leaves the prior disk snapshot intact

## Defaults (app)

`AppModel.makeProduction()` → `FileLedgerStore` + `KeychainViewingKeyStore` + `LightClientSyncFacade` for normal production launches. Debug-only forced-mock or explicit no-keychain launches use an in-memory ledger and `InMemoryViewingKeyStore`; `SANEBOOKS_FORCE_MOCK=1` also selects `MockSyncFacade`, preventing test runners from touching production state. Release builds compile out launch-argument E2E routing and ignore those test-state switches.

macOS does not expose user-controlled SwiftUI Dynamic Type scaling, so SaneBooks
persists an app-level `Standard` (1.0), `Large` (1.16), or `Extra Large` (1.35)
text scale. Body copy grows more than headings so accessibility text remains
readable without overwhelming the window. Large ledger layouts use one vertical
page scroll plus a horizontal table pan instead of nested vertical scrollers.

## Demo mode

Fixture UFVK (`ViewingKeyValidator.fixtureMainnetUFVK`) forces mock sync on `LightClientSyncFacade` so demos never pretend chain completeness.

## 4. Current product and grant research

### Competition and grant evidence | Updated: 2026-08-04 | Status: verified | TTL: 30d

- The current [FPF Coinholder Grants template](https://github.com/Financial-Privacy-Foundation/ZcashCoinholderGrantsProgram/blob/main/.github/ISSUE_TEMPLATE/grant_application.yaml) emphasizes completed work, intended-user or representative acceptance, concrete cost/metrics, proof links, disclosures, and a forum post.
- [Maya Protocol issue #19](https://github.com/Financial-Privacy-Foundation/ZcashCoinholderGrantsProgram/issues/19) is the clearest current winner pattern: approved and disbursed after documenting production deployment, 28+ merged Zcash changes, nine months of work, a line-item budget, downstream use, public repositories, and security hardening.
- [ZChat issue #18](https://github.com/Financial-Privacy-Foundation/ZcashCoinholderGrantsProgram/issues/18) and [zec-pay issue #20](https://github.com/Financial-Privacy-Foundation/ZcashCoinholderGrantsProgram/issues/20) were rejected even though their applications cited working releases, demos, or usage. The public issue labels establish the outcome, not the voters' reasons; do not invent a rejection rationale.
- Current adjacent products include [ZecLedger](https://github.com/vancube2/zecledger), [ZBooks-SIWZ](https://github.com/AustinChris1/ZBooks-SIWZ), [CipherPay](https://github.com/atmospherelabs-dev/cipherpay-web), and [Pendrake Watch](https://github.com/auzum197/pendrake-watch). Public usage signals are too small to support a credible TAM or price estimate.
- Highest-value near-term evidence: notarized public artifact and provenance, representative Ironwood history, and a documented deterministic export schema. Those receipts are more valuable than adding speculative surface area.
- Useful adjacent patterns: cost-basis lots, expected-payment reconciliation, QuickBooks/Xero vocabulary, disclosure/privacy preflight, and release checksums. Defer payments, payouts, teams, SIWZ, hosted sharing, AI, and tax filing until intended-user evidence selects them.
- PolyForm Shield is source-available rather than OSI open source. Grant eligibility under this license is unknown; obtain written clarification before changing the license, adding contribution promises, or submitting.
