# SESSION_HANDOFF — SaneBooks

**Updated:** 2026-08-04 ET (overnight hardening committed)
**Branch:** `main` · remote `sane-apps/SaneBooks` · committed on main — release lane next

## Current outcome

Completed a broad technical, security, privacy, accounting-integrity, accessibility, scale, UX, competition, grant, dependency, and Mini-hygiene audit. The exhaustive release/acceptance matrix and required journeys are in `DEVELOPMENT.md`; durable competition research is in `ARCHITECTURE.md §4` (verified 2026-08-03, TTL 30d).

### Implemented this pass

- Canonical project enrollment: `.saneprocess`, project `scripts/SaneMaster.rb`, XcodeGen unit/UI test targets, and destination-only `libzcashlc.framework` repair.
- Security: official SDK key validation; HTTPS endpoint enforcement; owner-only atomic storage; Keychain compensation around ledger commits; bounded transactional wallet imports; canonical `(txid, pool, output index)` identities; vault-bound sync sessions; SDK/credential/share-history purge on vault removal.
- Pack/export: v2 PBKDF2-HMAC-SHA256 600k + ChaCha20-Poly1305 with authenticated headers and encrypted private metadata; v1 rejection/re-export guidance; CSV formula neutralization; real paginated PDF output; explicit plaintext/non-expiry warnings and disclosure preflight.
- UX/scale: bright text, truthful capability/loading states, screen-share Discreet mode, app-managed Standard/Large/Extra Large text, scrollable 820×600 ledger/detail/builder/Reader paths, RTL-aware navigation, Cmd-N/I/O, partial-history gate, masked viewing-key entry with explicit reveal, seed rejection, destructive confirmations, and reachable validation copy.
- Accounting integrity: live/import identity agreement; manual classification, memo, fiat mark, and pack-inclusion preservation across sync; caught-up snapshot replacement to remove retired duplicate identities; stale-vault task isolation.
- Regression coverage added for feature settings, canonical live identity, sync metadata preservation, import identities/limits/cancellation, exact 100 MiB storage rollback, vault/share cleanup, crypto abuse and semantic forgery, unknown pools, hostile evidence text, CSV/PDF failure semantics, WCAG-AA token contrast, large-text reachability, keyboard controls, RTL, and UI route reachability.
- Test privacy: forced-mock and explicit no-keychain launches now use an ephemeral viewing-key store. This removed the repeated Keychain password/“Always Allow” loop without changing production Keychain behavior.
- XCTest authorization: the Mini now allows Automation Mode without repeated authentication; fresh idle read-back confirms authentication is no longer required and repeated UI runs produced no password prompt.
- Mini installed-app cleanup: 22 unrelated apps plus 10 retired SaneBar fixtures (~1.73 GiB total) moved to Trash. Actual SaneApps products and active engineering/admin tools were retained. Little Snitch's system extension is `terminated waiting to uninstall on reboot`; no restart was performed. The small unreferenced `SaneRemoteCapture.app` test helper remains installed. Trash is recoverable and is not being emptied automatically.

## Verification receipts

- Current canonical Mini result: **112 Swift tests in 14 suites + 10 executed macOS UI journeys passed**, with one private-fixture journey explicitly skipped when unavailable. The combined wrapper reports 121 passing tests and receipt `c1db7bd167a12f2426de7c1fe9479f23`; logs: `outputs/verify/20260804T083734.854905Z-82969-d198f14a/`.
- A later UI-only proportion pass also completed all 10 executed journeys without a password prompt (receipt `d927ee6482e880c907a52edd62e33a29`).
- Live Debug E2E at the effective minimum **820×600** passed for Welcome, ledger, Discreet masking, search, transaction edit/save/restore, proof-pack review, disclosure inventory, Reader, keyboard navigation, RTL, and real Extra Large rendering/scroll reachability. Clean app-only and matched comparison captures: `outputs/e2e/2026-08-04/final-green/cropped/`.
- Final static receipts: docs `f6fc596a4431ae9b47629cba9716a248`, test scan `4e93a1c8cfd784488d260627758dfba2`, structural `f85a8dd753e0d874e5f48dff9ab594a7` (one informational AppModel owner aggregate), compliance `d54ad7446cf8e09550e9e090397b03c8`, SaneUI guard `31ee71ea8aca593a672c57de0d9c1b57`, strict secret scan `outputs/secret-scan/20260804-070007-secret-scan.json` with zero findings, and lint `f507e876d04ba3e9811f75341a461836`.

## Open blockers before release

1. Fix and regression-test the shared SaneProcess release entrypoint so `.saneprocess` `release.enabled: false` fails closed even when `release.sh` is invoked directly. The project-local wrapper already exits 78, but that is not the whole boundary.
2. Prove the exact sandboxed Release through signature, Gatekeeper, notarization, stapling, clean install/quarantine, upgrade/update, public download, support, privacy metadata, and provenance/SBOM. No release/deploy is authorized yet.
3. Complete the remaining human/system checks that can materially change the shipped app: VoiceOver and full Tab order, Reduce Motion/Transparency, Increase Contrast, injected production-Keychain/network/disk/corruption faults, and a bounded soak/orphan check.
4. Complete clean-clone dependency/SBOM/license/advisory proof. The optional Codex Security deep-scan service was unavailable in this runtime, so do not represent the manual adversarial review and regression suite as an independent audit.

Before a grant submission, separately obtain written FPF guidance on PolyForm Shield/source-available eligibility and set the exact completed-work budget. This is not an app-release blocker.

## Product opportunities, evidence-gated

- **Now:** release provenance/checksums and a stable documented export contract.
- **Next only if real user demand exposes the need:** expected-payment reconciliation and deterministic local privacy warnings.
- **Defer:** cost-basis methods until supported jurisdictional semantics can be defined and tested; payouts, SIWZ, teams, hosted sharing, AI, custody, and tax filing remain out of scope.

No open GitHub issues were returned by `gh issue list` on 2026-08-04. No separate customer feature-request queue was found in this repo; the export/reconciliation ideas above come from this audit, not claimed user demand.

## Canonical commands

```bash
cd ~/SaneApps/apps/SaneBooks
xcodegen generate
./scripts/SaneMaster.rb verify --timeout 1800
./scripts/SaneMaster.rb verify --ui --timeout 1800
./scripts/SaneMaster.rb launch
```

Do not substitute raw `xcodebuild`, do not launch/build on the Air, and do not submit, deploy, notarize, publish, or post the grant draft without owner authorization.
