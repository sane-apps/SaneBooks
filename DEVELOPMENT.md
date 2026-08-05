# SaneBooks Development

> SaneApps Operator Overlay: this document records the canonical internal Mini workflow and release evidence.

## Canonical Mini workflow

```bash
cd ~/SaneApps/apps/SaneBooks
xcodegen generate
./scripts/SaneMaster.rb verify --timeout 1800
./scripts/SaneMaster.rb launch
```

The project wrapper is the final source of build/test/launch evidence. It targets the Mini, verifies nonzero selected tests, repairs the copied `libzcashlc.framework`, enforces single-instance/stale-binary rules, and emits a workflow receipt. Raw `swift test` or `xcodebuild` is a focused diagnostic only.

`SaneBooksPackage/Package.swift` pins SaneUI to an exact remote revision. The build graph never changes merely because a sibling checkout exists. Update the revision deliberately and capture it in release receipts.

## Thin app (XcodeGen)

Regenerate `SaneBooks.xcodeproj` after `project.yml` changes. `scripts/prepare-zcash-framework.sh` repairs the embedded build destination in a post-build phase; it must never mutate a package cache checkout.

- Bundle ID: `com.saneapps.SaneBooks`
- Debug entitlements: App Sandbox **OFF** (`SaneBooks.debug.entitlements`)
- Release entitlements: sandbox ON + network client + user-selected files

## Demo E2E (offline, customer actions)

1. Run app → Welcome → Import Viewing Key
2. Choose **Offline demo ledger** (or paste `ViewingKeyValidator.fixtureMainnetUFVK`)
3. Watch mock sync → Ledger with fixture notes
4. Tag untagged rows → New Proof Pack → Save `.sanebooks`
5. Reader → choose the saved file → unlock with the matching passphrase → Check file → deliberately export if required

Never treat a pre-arranged scene screenshot as E2E proof. A retained receipt must name the source commit, exact app path/build, host, fixture, user actions, expected/actual result, and screenshot/log locations.

## Mini-first

Prefer Mac Mini for `xcodebuild`, GUI proof, and App Store work. Air is controller only unless owner approves local fallback.

### Password-free XCTest authorization

The Mini has the one-time Apple-supported Automation Mode setting enabled, so signed UI tests do not require an administrator password on every run:

```bash
sudo /usr/bin/automationmodetool enable-automationmode-without-authentication
/usr/bin/xcrun automationmodetool
```

Expected idle read-back is `Automation Mode is disabled` plus `This device DOES NOT REQUIRE user authentication to enable Automation Mode.` The first line is normal outside an active test. This setting affects XCTest authorization only; forced-mock UI runs separately use an ephemeral ledger/key store and never probe production Keychain material.

## Exhaustive release and acceptance matrix

Updated: 2026-08-04 ET. `PASS` means verified against the current source in this audit; `BLOCKED` or `OPEN` is not a release pass.

| Lane | Current result | Required completion evidence |
|---|---|---|
| Source/config/reproducibility | PASS project enrollment and deterministic dependency graph: SaneUI is pinned to revision `0894c053345a86b549ea1ee329a4ff3b20826061`; OPEN clean-clone proof | origin parity; clean clone; pinned tools/deps; no generated drift; AppModel owner refactor |
| Build and test topology | PASS current Mini source: 112 Swift tests in 14 suites + 10 executed macOS UI journeys green, 1 private-fixture journey skipped; 121-test combined receipt `c1db7bd167a12f2426de7c1fe9479f23`; repeated signed UI runs produced no password prompt | sandboxed Release, standalone checkout, and exact shipped-package E2E |
| Dependency/supply chain | PASS pinned SDK/SaneUI, destination-only framework repair, bundled privacy manifest, and SaneUI guard; OPEN SBOM/advisory/license scan | artifact provenance, architectures, privacy manifests for nested dependencies, licenses, update review |
| Secrets/privacy/local storage | PASS owner permissions, fail-closed storage, ThisDeviceOnly production Keychain, ephemeral test key store, no telemetry | lock/logout/multi-user/FileVault/uninstall/leftover-data and redaction verification |
| Viewing-key validation | PASS official SDK parsing and seed/spend rejection | valid keys across supported versions/networks/pools; whitespace/Unicode/huge/wrong-network matrix |
| Zashi import | PASS bounded/cancellable off-main transactional import, stable identities, merge preservation, honest height, security-scoped lifetime, atomic UI commit | private real fixtures for each supported wallet schema/version; live-written/corrupt/locked/huge DB |
| Live sync | PASS HTTPS/port validation and bounded local state; OPEN real funded history | TLS/DNS/offline/rate/reorg/resume; outgoing/fees/pools; cancellation/vault switch; no sensitive logs |
| Ledger correctness | PASS deterministic demo rollups/filter rows plus 10k persist/reload/totals; one authoritative 100 MiB encoded snapshot limit rolls memory/disk back on failure | funded known fixture; decimals/locale/DST; outgoing/fee/refund/reorg; 100k/paged-store decision |
| Classification/rules | PASS basic edit/merge coverage; OPEN conflict/undo/localization | precedence, deletion, retroactive/idempotent application, persistence and focus stability |
| Proof-pack builder | PASS range/kind/row/vault/partial gates and 10k encrypted-pack round trip | large-history UI progress/cancel; timezone/expiry boundaries; independent accounting reconciliation |
| Encrypted pack security | PASS v2 PBKDF2 600k, AAD, checked RNG, 100 MiB bound, semantic recomputation, unknown-pool rejection, tamper/expiry tests | benchmark on minimum Mini; fuzz corpus; independent review; documented v1 re-export migration |
| CSV/PDF | PASS formula neutralization, truthful digest labeling, throwing/atomic PDF output, Unicode/pagination, 10k CSV/pack round trips | Numbers/Excel/Preview/print live matrix; 10k PDF consumer proof; assistive PDF semantics |
| Reader | PASS bounded open, authentic/semantic re-check, visible save results, scalable table, truthful authorship/chain limits | wrong/tampered/expired/oversize live UI matrix; decrypted-state teardown; VoiceOver |
| Share history/disclosure | PASS live disclosure summary and per-artifact digest; plaintext expiry cleared | cancellation/failure/retry/relaunch, file moved/modified, durable audit semantics |
| Settings/app controls | PASS dead controls removed, persisted settings including Standard/Large/Extra Large text, truthful restart/about/remove confirmation | full Tab-order audit, invalid endpoint, multiple windows, relaunch and cross-vault scope |
| Destructive actions/recovery | PASS confirmation and ledger-before-key removal; no silent pruning | injected every-boundary UI failures; encrypted owner backup/restore; uninstall/reinstall |
| Accessibility/keyboard/inclusive UX | PASS bright-text scan, WCAG-AA token regression, AX labels/values/hints, Cmd-N/I/O, RTL, and real app-level large-text reachability; OPEN full assistive pass | VoiceOver/Voice Control, complete Tab order, Reduce Motion/Transparency, system Increase Contrast |
| Window/layout/visual polish | PASS clean 820×600 app-only captures for Welcome/Ledger/Reader/builder/share, matched LTR/RTL, matched Standard/Extra Large, and scrolled large ledger rows; OPEN remaining display matrix | 1280×720, 1440×900, 5K/fullscreen/Split View; empty/error/very-long localization |
| Performance/resources | PASS bounded parsing/import, optimized search/filter, 10k storage/export regression, and repeated short canonical runs; OPEN measured budgets | launch/RSS/CPU/leaks/FPS/search/import/export/quit; long resource soak; orphan checks |
| Error handling/resilience | PASS injected ledger+Keychain double failure, oversize rollback, corrupt ledger/pack/PDF, cancellation, and hostile DB tests; OPEN system fault matrix | disk full, permission denied, production Keychain locked, concurrent changes, corrupt migration, support codes |
| Release/signing/updates | PASS GitHub DMG lane A: `release.enabled` fail-closed in shared `release.sh`; Developer ID Release archive; notarized+stapled `ZecBooks-0.1.1.zip`; Gatekeeper Notarized Developer ID; public https://zecbooks.app/download (Sparkle/App Store remain off) | Sparkle wired to zecbooks.app/appcast.xml; attach dist.zecbooks.app before first Sparkle ship; Mac App Store; upgrade-from-prior-public when a second build exists |
| Website/privacy/support/ops | PASS site https://zecbooks.app live (Pages sanebooks-site); privacy + guides; download still GitHub v0.1.0 until Sparkle ship | overview.mp4; family cross-links polish; synthetic delivery/read-back |
| Competition/grant | OPEN for grant-only items; notarized public artifact shipped | exact `$X` budget/metrics; written FPF PolyForm Shield eligibility; funded Ironwood receive |
| License/contribution | OPEN | written grant eligibility for PolyForm Shield; explicit source-available language; contribution policy only after decision |
| Mini hygiene | PASS: unrelated apps and retired SaneBar fixtures moved to Trash; actual SaneApps and active engineering/test/admin tools retained; Little Snitch extension is waiting to finish removal on next reboot | Trash is recoverable and still consumes disk until deliberately emptied; `SaneRemoteCapture.app` is an unreferenced test helper and remains installed pending a deliberate utility-retention decision |
| Evidence hygiene | PASS source/runtime/public claims separated; final app-only captures retained in `outputs/e2e/2026-08-04/final-green/cropped/`; final unit/UI receipt retained in `outputs/verify/20260804T070020.331374Z-44796-ed27ef1e/` | no stale screenshots promoted; no private fixtures or secrets retained |

### Required E2E journeys

1. Fresh launch → welcome → seed/spending-key rejection → valid UFVK/UIVK import → sync/error/retry → relaunch.
2. Zashi/Zodl database choose → import summary/limitations → stable re-import → classification preservation.
3. Ledger empty/one/long/large → search/filter/year/kind/untagged/discreet → row detail → save/cancel/rule.
4. Proof Pack → invalid and valid date/kind/row combinations → partial-history acknowledgment → disclosure audit.
5. Encrypted save → wrong/matching passphrase → tamper/expiry/unsupported/oversize → Check file → Reader table.
6. Plaintext CSV/PDF → warning → cancel/save/failure → digest → spreadsheet/PDF consumer validation.
7. Settings tabs → endpoint/restart/appearance/about/support/privacy → vault removal cancel/confirm/failure.
8. Keyboard/VoiceOver/focus/contrast/reduced-motion/text-scale plus every permitted window/display size.
9. Quit/reopen, upgrade/migration, data corruption/permission/disk-full/Keychain/network failure, resource soak, and orphan cleanup.
10. Exact sandboxed Release → clean install/quarantine → real representative history → proof-pack round trip → provenance receipt. **PASS** (2026-08-04): notarized ZIP `v0.1.0`, quarantine/spctl/staple, offline-demo history, pack builder → Share disclosure → Reader; receipt `outputs/journey10/journey10-receipt-latest.json`.
