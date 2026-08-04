# SESSION_HANDOFF — SaneBooks

**Updated:** 2026-08-04 ET (GitHub DMG lane A shipped)
**Branch:** `main` · remote `sane-apps/SaneBooks` · HEAD `8583fbd` · tag `v0.1.0`

## Current outcome

Public notarized GitHub Release **v0.1.0** is live for lane A (Sparkle and Mac App Store still off).

- Release: https://github.com/sane-apps/SaneBooks/releases/tag/v0.1.0
- Asset: `SaneBooks-0.1.0.zip` (sha256 `54b922814f0269f94609b483d948b7cb2706a6b8cdc3254756a8e1142b964fe8`)
- Notary Accepted: `fcd6111b-0267-48f2-9797-866fac68ac06`
- Journey 10 receipt: `outputs/journey10/journey10-receipt-latest.json`
- SaneProcess supporting fixes: `83820359` (RELEASE_ENABLED), `df890b40` (notary fail-closed), `56aae852` (GitHub-only asset upload)

## Verification

- `release_preflight`: proceed with caution (no blockers; monetization/product_id + untracked noise warnings)
- Mini `verify --ui`: green before ship (122 tests)
- Sandboxed Release: archive + codesign + notarize + staple
- Clean install: quarantine → spctl Notarized Developer ID → offline demo → proof pack Share → Reader

## Still open (not lane-A blockers)

- Sparkle / `sanebooks.com` / Cloudflare Pages
- Mac App Store
- Full VoiceOver / Reduce Motion matrix
- Grant submit: `$X`, FPF PolyForm letter, funded Ironwood receive
- Encrypted Save File… disk write + Reader unlock of that exact file (Share UI proven; file dialog save not automated this pass)

## Product opportunities, evidence-gated

- **Now:** point customers/grant at the GitHub Release URL; keep Sparkle off until site lane is intentional.
- **Next:** second notarized build for upgrade-path public proof; website download page; grant `$X` + FPF letter.
