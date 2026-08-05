# SESSION_HANDOFF — SaneBooks / ZecBooks

**Updated:** 2026-08-04 ET (ZecBooks ship prep — dist attached, 0.1.1)
**Branch:** `main` · remote `sane-apps/SaneBooks`

## Current outcome

- Customer product name **ZecBooks**. Repo/modules/bundle id `com.saneapps.SaneBooks` and `.sanebooks` stay.
- Site https://zecbooks.app live. Appcast empty until 0.1.1 Sparkle ship.
- **dist.zecbooks.app** attached: DNS AAAA `100::` proxied + `sane-dist` Worker route deployed (Mini `/health` → 200).
- Version bumped to **0.1.1 (build 2)** for first Sparkle / ZecBooks-named binary ship.

## Still open

- Finish `release.sh` for 0.1.1 (notarize + R2 + appcast) if not completed this session
- Drop `website/demo/overview.mp4` when the overview cut is ready (poster only for now)

## Verification

- Mini unit verify 113 tests green; Package.resolved includes Sparkle
- Visual: five marketing PNGs with ZecBooks chrome + ledger TopNav/Discreet
- Dist worker route listed in wrangler deploy output for `dist.zecbooks.app/*`
