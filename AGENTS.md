# SaneBooks Agent Instructions

Follow `~/AGENTS.md` first (cross-LLM policy source of truth). This file carries SaneBooks-specific facts.

Philosophy: `~/SaneApps/meta/Brand/NORTH_STAR.md`

## What Is This

Mac-native, local-first accountant layer for shielded Zcash: import a viewing key → classify income/change/expense → export a scoped, expiring proof pack. Not a wallet. Not CipherPay.

## Source Of Truth

- Product overview: `README.md`
- Development: `DEVELOPMENT.md`
- Architecture: `ARCHITECTURE.md`
- Privacy / security: `PRIVACY.md`, `SECURITY.md`
- Session resume: `SESSION_HANDOFF.md`
- Shared UI: `~/SaneApps/infra/SaneUI/`
- Tooling: `~/SaneApps/infra/SaneProcess/`

## Project Structure

| Path | Purpose |
|------|---------|
| `SaneBooks/` | Thin `@main` app shell, Info.plist, entitlements, assets |
| `SaneBooksPackage/Sources/SaneBooksCore` | Models, key validation, classification, ledger store |
| `SaneBooksPackage/Sources/SaneBooksSync` | SyncFacade, MockSyncFacade, capability gates |
| `SaneBooksPackage/Sources/SaneBooksExport` | Proof pack AEAD, CSV, PackBuilder/Reader |
| `SaneBooksPackage/Sources/SaneBooksFeature` | SwiftUI screens + AppModel |
| `project.yml` | XcodeGen thin app |

## Critical Notes

1. **Cannot spend** — no seed/spend key acceptance; Sync facade is view-only.
2. **UFVK preferred** — UIVK is degraded receivables mode with a permanent banner.
3. **No UVK in packs** — packs carry fingerprint + classified rows only.
4. **Ironwood** — live sync uses linked ZcashLightClientKit `2.7.0-rc.4` (UFVK view-only). Demo still available via `SANEBOOKS_FORCE_MOCK=1`.
5. **SaneUI** — accent `#0DA3C7`, settings text white ≥14pt, no gray `.secondary` in settings.
6. **Mini-first** — builds/tests/runtime on Mac Mini unless owner approves Air fallback.

## Build, Test, Release (Mini-first)

```bash
cd ~/SaneApps/apps/SaneBooks/SaneBooksPackage
SANEBOOKS_USE_LOCAL_SANEUI=1 swift build
SANEBOOKS_USE_LOCAL_SANEUI=1 swift test

cd ~/SaneApps/apps/SaneBooks
xcodegen generate
open SaneBooks.xcodeproj
```
