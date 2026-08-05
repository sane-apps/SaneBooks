# ZecBooks 0.1.1 — public provenance

Verified on Mac Mini **2026-08-05**.

| Item | Value |
|------|-------|
| Product | ZecBooks 0.1.1 (build 2) |
| Download | https://dist.zecbooks.app/updates/ZecBooks-0.1.1.zip |
| Site download redirect | https://zecbooks.app/download → same zip |
| Appcast | https://zecbooks.app/appcast.xml |
| SHA-256 (zip) | `25578ef64874705f2f73ca9f23193a6ddd873a33a05339b284b0af1bec243308` |
| Zip size | 22,150,057 bytes |
| Bundle ID | `com.saneapps.SaneBooks` |
| Team ID | `M78L6FXD48` |
| Signing | Developer ID Application: Stephan Joseph (M78L6FXD48) |
| Gatekeeper | `spctl -a -vv -t exec ZecBooks.app` → **accepted** / Notarized Developer ID |
| Staple | `xcrun stapler validate ZecBooks.app` → **The validate action worked!** |
| Codesign timestamp | Aug 4, 2026 ~22:05 ET |
| License | MIT |

## Reproduce

```bash
curl -fsSL -o ZecBooks-0.1.1.zip https://dist.zecbooks.app/updates/ZecBooks-0.1.1.zip
shasum -a 256 ZecBooks-0.1.1.zip
# expect: 25578ef64874705f2f73ca9f23193a6ddd873a33a05339b284b0af1bec243308
unzip ZecBooks-0.1.1.zip
spctl -a -vv -t exec ZecBooks.app
xcrun stapler validate ZecBooks.app
```

## Source

Public source: https://github.com/sane-apps/SaneBooks  
Tag/release for this binary will match the commit published with this provenance file on `main`.
