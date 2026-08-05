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
5. **Visual** — SaneBooks uses **ZEC gold** (`#F4B728`) + warm ink locally via `SaneBooksTheme` / `.saneBooksBrand()`. Global SaneUI teal `#0DA3C7` stays for other apps. Settings text white ≥14pt; no gray `.secondary` in settings. Do **not** put the trademarked Zcash Z in the app icon.
6. **Site / Sparkle / brand** — Customer name is **ZecBooks** (`PRODUCT_NAME` / display name). Repo/module/bundle id stay `SaneBooks` / `com.saneapps.SaneBooks` for continuity; public zip/dist artifact is `ZecBooks-X.Y.Z.zip` via `release.product_name`. Site: **https://zecbooks.app** (Pages `sanebooks-site`). Appcast: `https://zecbooks.app/appcast.xml`. Dist: `dist.zecbooks.app` (attach before first Sparkle `release.sh` ship).
7. **Mini-first** — builds/tests/runtime on Mac Mini unless owner approves Air fallback.

## Build, Test, Release (Mini-first)

```bash
cd ~/SaneApps/apps/SaneBooks
xcodegen generate
./scripts/SaneMaster.rb verify --timeout 1800
./scripts/SaneMaster.rb launch
```

Direct `swift test`, raw `xcodebuild`, and manual `.app` launch are diagnostics only and never final proof. The canonical Xcode action includes package, app-model, and UI-test targets; the wrapper must report a nonzero selected-test count. `scripts/prepare-zcash-framework.sh` repairs only the embedded destination framework after Xcode's copy phase; never mutate a package cache checkout.

Pack format v2 deliberately rejects legacy v1 because v1 exposed unauthenticated private metadata and used a fast passphrase derivation. CSV/PDF are plaintext and non-expiring. Do not weaken or blur those UI warnings.
