# Competitive positioning — SaneBooks

One page. Audience: coinholders reviewing a Retroactive Grant draft.

**SaneBooks lane:** local Mac, view-only, owner → CPA selective disclosure (classify + scoped proof pack).  
**Not:** checkout, spend wallet, or multi-chain tax SaaS.

Community gap: [forum Jun 2026](https://forum.zcashcommunity.com/t/is-anyone-actually-using-viewing-keys-for-business-accounting/56300).

| Product | What it is | Key / privilege | Where SaneBooks differs |
|---------|------------|-----------------|-------------------------|
| **CipherPay** | Non-custodial merchant payments: IVK trial decrypt, hosted/self-host checkout, CSV | **UIVK / IVK** receivables; hosted path can see amount/memo | CipherPay is **before/at** payment. SaneBooks is **after** money arrives: UFVK bookkeeper mode, change≠income, local-first packs, no spend, no hosted paste-your-key as primary path. |
| **Zodl** | Modern spend wallet (ZODL); UFVK export exists for view-only setups | Seed + spend; UFVK as a feature | Wallet. SaneBooks never holds spend power; Zodl remains where users spend and export the key. |
| **ZGo** | Historical merchant / order tooling; fiat price-at-order was a known differentiator | Merchant payment confirm | Order/checkout era product. SaneBooks is ledger + proof pack for accountants, with explicit fiat as-of methodology (no invented prices). |
| **Koinly** (and similar) | Multi-chain tax SaaS; historically weak on shielded ZEC | Exchange/CSV imports | Broad tax automation. SaneBooks is Zcash-native shielded classification + export a CPA can ingest — not automated filing. |
| **ZBooks** (ZecHub hackathon) | Team/DAO treasury accounting + structured batch payouts (SIWZ, M-of-N, ZIP 321) | UFVK for treasury read; payouts signed in treasurer wallet | Team/DAO ops + payout workflow. SaneBooks is **solo owner → CPA** on a Mac: offline `.sanebooks` packs, Reader mode, no payout URI / multisig product. |

## Positioning matrix

| Need | Best fit |
|------|----------|
| Accept ZEC at checkout | CipherPay (or similar) |
| Spend / seed custody | Zodl / YWallet / etc. |
| Team treasury + approved payouts | ZBooks-class tools |
| Multi-chain tax import | Koinly-class tools |
| Private Mac books + scoped CPA pack | **SaneBooks** |

## What we refuse to claim

- Not a CipherPay replacement
- Not a wallet
- Not “temporary viewing-key access” (keys are irrevocable — packs expire; keys do not)
- Not audited / tax-authority-certified without real attestation design
- No fake download counts or testimonials in grant materials
