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
| **SaneBooksSync** | `SyncFacade`, `MockSyncFacade`, `BlockedSyncFacade`, `LightClientSyncFacade`, `CapabilityProbe` (Ironwood/SDK #1806 honesty) |
| **SaneBooksExport** | PackBuilder, PackCrypto/PackWriter, PackReader, CSVExporter, PDFSummaryExporter |
| **SaneBooksFeature** | SwiftUI E2E screens + `AppModel` (multi-vault, share history, tag rules, partial-history ack) |

## Invariants

- No spend APIs on the public Sync surface
- UVK only in Keychain (`WhenUnlockedThisDeviceOnly`); JSON ledger holds fingerprint metadata only
- `.sanebooks` = magic `SANEBOOK` + public header + ChaCha20-Poly1305 ciphertext; no UVK
- Mainnet “complete books” gated on Sapling+Orchard+Ironwood capability
- Pack seal refused when `partialHistory && !acknowledgePartialHistory`

## Defaults (app)

`AppModel.makeProduction()` → `FileLedgerStore` + `KeychainViewingKeyStore` + `LightClientSyncFacade` (or `MockSyncFacade` if `SANEBOOKS_FORCE_MOCK=1`). Unit tests keep InMemory + Mock.

## Demo mode

Fixture UFVK (`ViewingKeyValidator.fixtureMainnetUFVK`) forces mock sync on `LightClientSyncFacade` so demos never pretend chain completeness.

Full blueprint: `/tmp/zcash-grant-research/architecture-blueprint.md` (promote durable bits here as they stabilize).
