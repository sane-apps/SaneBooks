# Target-user checklist — 2026-08-03

Persona: solo / small merchant who takes shielded ZEC and needs Mac CPA books.

Screenshots: this folder (`01`–`09` + settings).

## Wallet coverage (product answer)

| Priority | Wallets | How |
|----------|---------|-----|
| **Must (v1)** | Zashi, Zodl | UFVK paste **and** `data.db` import |
| **Should** | YWallet, Zingo CLI | UFVK paste only |
| **Later** | Vizor, zcashd legacy | UFVK / `zxviews` when UI stable |
| **Not sources** | CipherPay, ZGo, Pendrake, ZBooks | checkout / watch / treasury — different job |

**How many types?** Two *ingress* types for v1: (1) UFVK string, (2) ECC SDK `data.db`. Wallet *brands* to make easy: **2 must + 2 should ≈ 4**. Do not chase every wallet UI — document export paths in `WALLET_VIEWING_KEY_GUIDE.md`.

## Surface results

| # | Surface | Result | Target-user note |
|---|---------|--------|------------------|
| 01 | Welcome | OK | Clear value prop; no Settings on welcome (ok — not needed yet) |
| 02 | Import | **FAIL clip** | Bottom of “Or sync live” / live-probe CTAs cut off — owner can’t see full path |
| 03 | Ledger | OK | Demo books; income/expense/change/fee chips; New Proof Pack visible |
| 04 | Detail | OK | Classify party/subtag/memo; include-in-pack; Save |
| 05 | Pack | Soft | Range step works; lots of empty canvas; Continue far from card |
| 06 | Share | OK | Disclosure audit + passphrase + Save File; CPA recipient labeled |
| 07 | Sync | OK | Progress + demo banner; Cancel visible (bottom-right) |
| 08 | Reader | Soft | Unlock path clear; empty CPA-friendly chrome (expected locked) |
| 09 | Discreet | **FAIL** | Capture still shows amounts — toggle didn’t stick / AX miss |
| 10 | Settings menu | OK | Single **Settings…**; Vault tab opens |
| 11 | Dock menu | Untested live | Code present; right-click not AX-proven this pass |

## Jobs-to-be-done vs product

| Job (owner wants) | Status |
|-------------------|--------|
| Get history in (UFVK / data.db) | Partial — DB path exists; Import CTAs clipped; Zashi DB not on Mini this run |
| Classify income≠change≠expense | Demo OK |
| Fiat as-of with named source | Soft — USD* shown; source honesty needs Settings glance |
| Memo → line item | OK on detail; ledger truncates long memos (tooltip) |
| Expiring CPA pack | OK demo share |
| Honest coverage / partial history | OK on share ack |
| Tax-year range | OK pack quick selects |
| Safe share / discreet | Discreet unproven this pass |

## Gaps to fix next (priority)

1. Import scroll / safeAreaInset — “Or sync live” + probe buttons fully visible  
2. Prove Discreet hides ZEC/USD on ledger  
3. Dock right-click Settings/Import click-test  
4. Welcome: mention fastest path (Zashi/Zodl db) in one line  
5. Pack builder: less empty space / Continue nearer content  
6. Re-run Zashi `data.db` path when DB available on Mini  
7. Commit polish + checklist when owner asks  
