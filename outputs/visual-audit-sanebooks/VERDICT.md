# SaneBooks Visual Audit — Updated 2026-08-03 (v1.1)

**Host:** Mini  
**Build:** Debug succeeded after v1.1  
**Tests:** **34/34** green  

## Captures

### MVP E2E (`e2e-*.png`)
Welcome, Import, Ledger, Detail, Pack, Share, Reader — pass (earlier receipt).

### v1.1 (`v11-*.png`)
| Scene | File | Verdict |
|-------|------|---------|
| Welcome | `v11-welcome.png` | Pass |
| Import | `v11-import.png` | Pass — demo card + birthday help |
| Ledger | `v11-ledger.png` | Pass — multi-vault picker, sync banner, classification |
| Pack | `v11-pack.png` | Pass — stepper |
| Share | `v11-share.png` | **Pass — PDF option + partial-history ack banner** (competition-critical honesty) |
| Reader | `v11-reader.png` | Pass |
| Settings attempt | `v11-settings.png` | Contaminated / landed on ledger — SettingsLink works in-app; re-capture optional |

## Competition-facing visual story
Share screen shows the product wedge clearly: formats include **PDF summary**, encrypted pack, CSV; orange banner forces acknowledge of demo/partial sync before export. That matches footgun #5/#17 (never silent incomplete books).

## Remaining visual debt
- Dedicated Settings window shot (Vault / Sync capability / Share history / Tag rules)
- IVK receivables banner state (needs UIVK import fixture scene)
