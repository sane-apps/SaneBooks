# Competitive positioning — SaneBooks

One page. Audience: coinholders reviewing a Retroactive Grant draft.

**SaneBooks lane:** local Mac, view-only, **owner → CPA selective disclosure** (classify + scoped, expiring proof pack).  
**Not:** checkout, spend wallet, team treasury payouts, or multi-chain tax SaaS.

Community gap: [forum Jun 2026](https://forum.zcashcommunity.com/t/is-anyone-actually-using-viewing-keys-for-business-accounting/56300).

## One-line wedge (use in grant / forum)

> CipherPay gets you paid privately. [ZBooks](https://github.com/AustinChris1/ZBooks-SIWZ) runs **team treasury + approved payouts**. **SaneBooks** is the Mac CPA layer: local books, change≠income, and an expiring `.sanebooks` pack your accountant opens in Reader — without a permanent raw UFVK.

## Adjacent products

| Product | What it is | Key / privilege | Where SaneBooks differs |
|---------|------------|-----------------|-------------------------|
| **CipherPay** | Non-custodial merchant payments: IVK trial decrypt, hosted/self-host checkout, CSV | **UIVK / IVK** receivables | CipherPay is **before/at** payment. SaneBooks is **after** money arrives. |
| **ZBooks** ([AustinChris1/ZBooks-SIWZ](https://github.com/AustinChris1/ZBooks-SIWZ)) | Team/DAO treasury accounting + SIWZ auth + M-of-N approvals + ZIP 321 batch payouts; web + Turso | UFVK for treasury read; payouts signed in treasurer wallet | **Different job.** ZBooks = multi-user treasury ops and money-out. SaneBooks = solo owner → CPA on a **local Mac**; offline packs + Reader; **no** payout URI, no SIWZ, no hosted ledger DB. |
| **Zodl** | Modern spend wallet; UFVK / `data.db` export | Seed + spend | Wallet. SaneBooks imports UFVK or Zashi/Zodl `data.db` only. |
| **ZGo** | Historical merchant / order tooling | Merchant confirm | Order/checkout era. SaneBooks is ledger + CPA pack. |
| **Koinly** (and similar) | Multi-chain tax SaaS; weak on shielded ZEC | Exchange/CSV | Broad tax automation. SaneBooks is Zcash-native shielded classification. |
| **Pendrake Watch** | UFVK watch-only desktop | UFVK watch | Watch wallet. We keep classification + CPA packs; borrowed discreet-mode UX only. |
| **ZecLedger** | Viewing-key accounting, cost basis, ZIP-321 checks | Viewing keys | Accounting cousin. Our moat is Mac-local `.sanebooks` / Reader + Ironwood honesty. |

## Positioning matrix

| Need | Best fit |
|------|----------|
| Accept ZEC at checkout | CipherPay (or similar) |
| Spend / seed custody | Zodl / YWallet / etc. |
| Team treasury + approved payouts | **ZBooks** |
| Multi-chain tax import | Koinly-class tools |
| Private Mac books + scoped CPA pack | **SaneBooks** |

## What we refuse to claim

- Not a ZBooks replacement (no team payouts / SIWZ / hosted treasury)
- Not a CipherPay replacement
- Not a wallet
- Not “temporary viewing-key access” (keys are irrevocable — packs expire; keys do not)
- Not audited / tax-authority-certified without real attestation design
- No fake download counts or testimonials in grant materials
