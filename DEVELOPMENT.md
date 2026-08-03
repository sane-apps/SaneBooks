# SaneBooks Development

## Local package build

```bash
cd ~/SaneApps/apps/SaneBooks/SaneBooksPackage
SANEBOOKS_USE_LOCAL_SANEUI=1 swift build
SANEBOOKS_USE_LOCAL_SANEUI=1 swift test
```

`SANEBOOKS_USE_LOCAL_SANEUI=1` (or auto path detect) uses `~/SaneApps/infra/SaneUI`. Otherwise Package.swift pins SaneUI revision `9e90dbbc…`.

## Thin app (XcodeGen)

```bash
cd ~/SaneApps/apps/SaneBooks
xcodegen generate
open SaneBooks.xcodeproj
```

- Bundle ID: `com.saneapps.SaneBooks`
- Debug entitlements: App Sandbox **OFF** (`SaneBooks.debug.entitlements`)
- Release entitlements: sandbox ON + network client + user-selected files

## Demo E2E (offline)

1. Run app → Welcome → Import Viewing Key
2. **Use Demo Key** (or paste `ViewingKeyValidator.fixtureMainnetUFVK`)
3. Watch mock sync → Ledger with fixture notes
4. Tag untagged rows → New Proof Pack → Save `.sanebooks`
5. Welcome → Open Proof Pack (Reader) → unlock with passphrase

## Mini-first

Prefer Mac Mini for `xcodebuild`, GUI proof, and App Store work. Air is controller only unless owner approves local fallback.
