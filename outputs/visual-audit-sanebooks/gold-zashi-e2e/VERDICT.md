# SaneBooks Visual Audit — Gold theme + Zashi DB E2E

**Host:** Mini  
**Date:** 2026-08-03  
**Build:** Debug `SaneBooks.app` (local SaneUI + ZEC gold theme)  
**Import:** Zashi SDK `data.db` via `--e2e-import-db=` (UFVK never logged)

## Evidence paths

`outputs/visual-audit-sanebooks/gold-zashi-e2e/`

| Scene | File | Verdict |
|-------|------|---------|
| Welcome | `welcome.png` | **Pass** — warm ink + gold CTA glow; brand mark readable |
| Import | `import.png` | **Pass after fix** — Zashi DB import is primary CTA; no long UA wall |
| Ledger (Zashi) | `zashi-ledger.png` | **Pass** — 10 notes, Sync Caught up · block 3,198,303, Client·E2E tags, gold chrome |
| Detail | `zashi-detail.png` | **Pass** — Orchard note tagged Income / Client / E2E |
| Pack builder | `zashi-pack.png` | **Pass** — range Oct 5, 2025 → Jan 8, 2026 (full imported history) |
| Share + disclosure | `zashi-share.png` | **Pass** — disclosure audit visible; Save File… sticky; 7 rows / 18.2458 ZEC income |

## Functional proof (ledger.json on Mini)

- notes = **10**
- kinds = income **7**, untagged **3**
- heights = **3088955–3198303**
- vault display = **Zashi (imported)**
- UFVK logged = **false**

## Theme

- Accent ZEC gold `#F4B728` (not SaneUI cyan)
- Warm ink background; gold panel edges on sync / disclosure / CTAs
- No trademarked Zcash Z in icon

## Issues found → fixed in-session

1. Import card clipped Offline/Zashi buttons → shortened card; Zashi import primary  
2. Share Save File… below fold → ScrollView + sticky footer  
3. Pack wizard defaulted to calendar YTD → seeds from imported note date span  

## Remaining (owner)

- Grant **$X** still TBD in `docs/GRANT_PROPOSAL.md` (not invented)
- Optional: clean Settings-window dedicated shot

## Log receipt

See `LOG_RECEIPT.txt` in this folder (no secrets).
