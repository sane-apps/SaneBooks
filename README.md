# SaneBooks

Private books for shielded Zcash — Mac-native, local-first.

Import a **viewing key**, classify income / change / expense, and share an expiring **proof pack** with your accountant. SaneBooks **cannot spend ZEC**.

**100% Transparent Code** under [PolyForm Shield](LICENSE). Not casual “open source.”

## The problem

Shielded Zcash already has viewing keys (ZIP 316). Merchants can take ZEC privately. What is missing is an **accountant layer**: classify change so it is not counted as income, attach fiat as-of with a named source, and hand a CPA a scoped pack — not a permanent UFVK and not a wallet CSV dump.

Community signal: [Is anyone actually using viewing keys for business accounting?](https://forum.zcashcommunity.com/t/is-anyone-actually-using-viewing-keys-for-business-accounting/56300) (Jun 2026).

## The solution

| Step | What happens |
|------|----------------|
| 1 | Import a **UFVK** (`uview…`) for bookkeeper mode (or **UIVK** for receivables-only, with a permanent degraded-mode banner) |
| 2 | Sync compact history via lightwalletd (`ZcashLightClientKit` 2.7.0-rc.4; demo via `SANEBOOKS_FORCE_MOCK=1`) |
| 3 | Tag rows: Income / Expense / Change / Fee — change is excluded from income totals |
| 4 | Build a time-scoped **proof pack** (encrypted `.sanebooks` + CSV) |
| 5 | Accountant opens **Reader** mode — read-only rows, no vault key, no chain sync |

## Non-goals

- **Not a wallet** — no seeds, no spending keys, no send UI
- **Not CipherPay** — CipherPay is merchant checkout / IVK payment detect; SaneBooks starts after money arrives
- **Not ZBooks** — [ZBooks](https://github.com/AustinChris1/ZBooks-SIWZ) is team/DAO treasury + SIWZ + approved ZIP 321 payouts (web). SaneBooks is solo owner → CPA on a local Mac with expiring proof packs
- **Not tax software** — we export accountant-ready rows; the CPA owns filing
- **Not “temporary UFVK access”** — viewing keys are irrevocable; share **packs**, not raw keys

## Security invariants

1. Reject seed phrases and spending-key strings at import
2. Prefer bookkeeper mode on **UFVK**; UIVK never claims complete books
3. Proof packs carry fingerprint + classified rows only — **never** embed UFVK/UIVK
4. Pack footer names lightwalletd endpoint + tip height + “assumes honest LWD”
5. No iCloud / CloudKit for vault data; Keychain ThisDeviceOnly for key material (production path)

## Ironwood honesty

NU6.3 / Ironwood activated on mainnet at height **3,428,143** ([ZIP 258](https://zips.z.cash/zip-0258)). New shielded receives land in Ironwood, not Orchard.

SaneBooks links **ZcashLightClientKit 2.7.0-rc.4** (Ironwood receive/sync; tracking issue [#1806](https://github.com/zcash/zcash-swift-wallet-sdk/issues/1806) closed). Live path imports a **UFVK** as view-only and syncs against a configurable lightwalletd (default `zec.rocks:443`). Demo/offline still uses `MockSyncFacade` when `SANEBOOKS_FORCE_MOCK=1` or the fixture demo key is used.

UIVK/receivables mode cannot import via the public SDK yet — that path stays degraded/honest.

## Demo path (offline)

1. Build and run (below)
2. **Import Viewing Key → Use Demo Key → Continue**
3. Wait for mock sync to catch up
4. Open a row → classify → **New Proof Pack** → export `.sanebooks` / CSV
5. **Reader** → unlock pack with passphrase

## Build and run

Requirements: macOS 14+, Xcode 16+.

```bash
cd ~/SaneApps/apps/SaneBooks/SaneBooksPackage
SANEBOOKS_USE_LOCAL_SANEUI=1 swift build
SANEBOOKS_USE_LOCAL_SANEUI=1 swift test

cd ~/SaneApps/apps/SaneBooks
xcodegen generate
open SaneBooks.xcodeproj
# Run the SaneBooks scheme (Debug sandbox off)
```

## Screenshots / visual audit

Clean Mini captures for the Week 0–1 mock MVP live under:

`outputs/visual-audit-sanebooks/`

See `VERDICT.md` in that folder for scene list and pass/fail notes.

## Docs

| Doc | Purpose |
|-----|---------|
| [docs/GRANT_PROPOSAL.md](docs/GRANT_PROPOSAL.md) | Draft Coinholder-Directed Retroactive Grant application |
| [docs/COMPETITIVE_POSITIONING.md](docs/COMPETITIVE_POSITIONING.md) | vs CipherPay, Zodl, ZGo, Koinly, ZBooks |
| [docs/WALLET_VIEWING_KEY_GUIDE.md](docs/WALLET_VIEWING_KEY_GUIDE.md) | How to export a UFVK from common wallets |
| [docs/LIVE_PROBE_FUNDING.md](docs/LIVE_PROBE_FUNDING.md) | How to fund the live probe UA for a real ledger row |
| [SECURITY.md](SECURITY.md) / [PRIVACY.md](PRIVACY.md) | Threat model and data boundaries |
| [AGENTS.md](AGENTS.md) | Agent / contributor project facts |

## License

[PolyForm Shield 1.0.0](LICENSE) — 100% Transparent Code. Contact: hi@saneapps.com
