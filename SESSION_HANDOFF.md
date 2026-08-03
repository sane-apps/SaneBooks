# SESSION_HANDOFF — SaneBooks

**Updated:** 2026-08-03 (v1.1 competition pack)  
**Branch:** local `main` (no remote; uncommitted)

## Done

### MVP
- Mac app + SPM Core/Sync/Export/Feature
- Demo E2E UI + mock sync
- `.sanebooks` AEAD + CSV + Reader

### v1.1 (competition / market gaps)
- PDF summary export
- Share history (local)
- Memo auto-tag rules (+ default INV-)
- IVK upgrade banner/flow
- Partial-history export acknowledgment gate
- Multi-vault + Keychain + file ledger (`makeProduction`)
- Birthday / UFVK help copy
- `LightClientSyncFacade` + CapabilityProbe (Ironwood honestly blocked)
- Grant packaging: LICENSE, README, `docs/GRANT_PROPOSAL.md`, positioning, wallet guide
- Tests: **34/34**; Mini build green; visual `v11-*` shots

## Not done (honest)
- Live Ironwood mainnet LWD sync (SDK capability)
- Sparkle / notarized release
- Public GitHub remote + first commit (owner ask)
- Clean Settings-window screenshot

## Run
```bash
cd ~/SaneApps/apps/SaneBooks && xcodegen generate
# Demo:
SANEBOOKS_FORCE_MOCK=1 open …/SaneBooks.app --args --e2e-scene=ledger
```

## Next for grant submit
1. Owner sets budget `$X` + handles in `docs/GRANT_PROPOSAL.md`
2. Commit + public repo
3. Forum + FPF GitHub issue when retroactive scope is attested
4. Ironwood sync when Swift SDK ready — then re-audit

## Shown to owner
- 2026-08-03: App launched on Air with --e2e-scene=ledger (SANEBOOKS_FORCE_MOCK=1). Clean Mini shots in outputs/visual-audit-sanebooks/show-*.png
