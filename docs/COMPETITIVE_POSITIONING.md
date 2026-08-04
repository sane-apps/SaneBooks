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

## What prior grant outcomes actually reward

The current program template and public approved applications support an evidence pattern, not a mechanical scorecard:

- completed, publicly usable work rather than a future roadmap;
- exact costs, technical receipts, and completion links;
- a simple, high-impact workflow already accepted by intended users or representatives;
- durable public utility, distribution, or downstream use;
- contribution and license language that matches the rights actually granted.

Rejected applications show that novelty, a low ask, research quality, a demo, or claimed user counts are not sufficient alone. Voter motives are not fully published, so SaneBooks must not claim to know why any one application lost.

**Competition-winning proof thesis:** ship a signed local-only accountant handoff, bind it to source/dependency/binary hashes, import representative shielded history, disclose exactly what leaves the vault, and prove the artifact opens cleanly on a fresh installation. That is higher value than adding payouts, SIWZ, teams, hosted sharing, or AI.

Primary precedents: [BitcoinVN](https://github.com/Financial-Privacy-Foundation/ZcashCoinholderGrantsProgram/issues/1), [ZcashCommunity](https://github.com/Financial-Privacy-Foundation/ZcashCoinholderGrantsProgram/issues/3), [Unstoppable Wallet](https://github.com/Financial-Privacy-Foundation/ZcashCoinholderGrantsProgram/issues/7), and [Maya Protocol](https://github.com/Financial-Privacy-Foundation/ZcashCoinholderGrantsProgram/issues/19). Current requirements: [FPF application template](https://github.com/Financial-Privacy-Foundation/ZcashCoinholderGrantsProgram/blob/main/.github/ISSUE_TEMPLATE/grant_application.yaml).

## Open-source patterns worth borrowing

- Adopt ZecLedger-style release hashes/provenance, privacy checks, and reconciliation vocabulary as patterns; do a file-level license/security review before reusing code.
- Keep official Zcash SDK parsing as the viewing-key trust boundary.
- Publish a stable export field dictionary and deterministic fixture before claiming QuickBooks/Xero compatibility.
- Defer cost-basis methods until the supported method and jurisdictional assumptions are defined and tested.
- Keep PolyForm Shield language precise: SaneBooks is source-available/Transparent Code, not OSI open source. Grant eligibility under that license remains unknown until confirmed in writing.

## What we refuse to claim

- Not a ZBooks replacement (no team payouts / SIWZ / hosted treasury)
- Not a CipherPay replacement
- Not a wallet
- Not “temporary viewing-key access” (keys are irrevocable — packs expire; keys do not)
- Not audited / tax-authority-certified without real attestation design
- No fake download counts or testimonials in grant materials
