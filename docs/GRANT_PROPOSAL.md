# Retroactive Grant Application — ZecBooks

**Status:** **SUBMITTED** — FPF https://github.com/Financial-Privacy-Foundation/ZcashCoinholderGrantsProgram/issues/38 · Forum https://forum.zcashcommunity.com/t/call-for-proposals-coinholder-directed-retroactive-grants-program-q3/56885/8  
**Ask:** **$32,000** (owner-set). Soft risk: short completion window vs CipherPay-scale asks — defend with MIT + notarized provenance, not usage claims.  
**Public product:** [zecbooks.app](https://zecbooks.app) · [ZecBooks-0.1.1.zip](https://dist.zecbooks.app/updates/ZecBooks-0.1.1.zip)  
**Provenance:** [docs/ZecBooks-0.1.1-PROVENANCE.md](ZecBooks-0.1.1-PROVENANCE.md) (SHA-256 + Notarized Developer ID)

Program: [Financial Privacy Foundation — Zcash Coinholder Grants Program](https://github.com/Financial-Privacy-Foundation/ZcashCoinholderGrantsProgram)  
Forum gap cited: [Is anyone actually using viewing keys for business accounting?](https://forum.zcashcommunity.com/t/is-anyone-actually-using-viewing-keys-for-business-accounting/56300)

**License:** **MIT** ([LICENSE](../LICENSE)). `CONTRIBUTING.md` published. Relicensed from PolyForm Shield on 2026-08-05 to match CDRGP MIT disbursement guidance.

**Source note:** Customer product name is **ZecBooks**. Source publishes at https://github.com/sane-apps/SaneBooks (historical module/path name).

---

### Application Owners

`@MrSaneApps` (Stephan Joseph / SaneApps)

### Organization or Individual Name

SaneApps

### Additional Team Members

```yaml
- Name: Stephan Joseph
  Role: Founder / product + engineering
  Background: SaneApps Mac products (local-first, privacy-minded utilities)
  Responsibilities: Architecture, Mac app, classification/export, docs
```

### How did you learn about the Lockbox: Coinholder Retroactive Grants Program?

Zcash Community Forum (business viewing-key accounting thread) and ongoing Zcash ecosystem follow.

### Requested Grant Amount (USD)

**$32,000**

### Category

Non-Wallet Applications  
(view-only bookkeeping / selective-disclosure layer for owners and their accountants — explicitly **not** a spending wallet)

### Project Summary

**ZecBooks** is a Mac-native, local-first bookkeeping layer for shielded Zcash: import a viewing key, classify income vs change vs expense, and export a scoped, expiring proof pack for an accountant. It cannot spend ZEC. It is not a merchant checkout product.

### Project Description / Problem / Motivation

A lot of people assume privacy coins are about hiding from taxes. That is not why I built this, and it is not why most Zcash users care about shielded money. I believe people have a right to financial privacy and still want to keep clean books.

Shielded ZEC already supports ZIP 316 viewing keys. Merchant checkout and wallets exist. The missing product is **accounting semantics**:

- UFVK-class history so change notes are not booked as income
- Honest sync-gap / LWD-trust disclosure on every export
- Scoped proof packs (encrypted `.sanebooks` + CSV) instead of handing the accountant a permanent raw UFVK
- Ironwood-era sync via linked `ZcashLightClientKit` **2.7.0-rc.4** (view-only)

Community demand thread:  
https://forum.zcashcommunity.com/t/is-anyone-actually-using-viewing-keys-for-business-accounting/56300

**Wedge:** Private money, kept with honest books. CipherPay gets you paid privately. [ZBooks](https://github.com/AustinChris1/ZBooks-SIWZ) runs team treasury + approved payouts. **ZecBooks** is the Mac bookkeeping layer — local books, change≠income, expiring `.sanebooks` packs (Reader), not a permanent raw UFVK.

### What is implemented (publicly verifiable)

| Artifact | Evidence |
|----------|----------|
| Public site + download | https://zecbooks.app · https://zecbooks.app/download |
| Notarized Developer ID zip | https://dist.zecbooks.app/updates/ZecBooks-0.1.1.zip |
| SHA-256 + Gatekeeper/stapler | [ZecBooks-0.1.1-PROVENANCE.md](ZecBooks-0.1.1-PROVENANCE.md) — `25578ef64874705f2f73ca9f23193a6ddd873a33a05339b284b0af1bec243308` |
| Sparkle appcast | https://zecbooks.app/appcast.xml |
| Open-source source | https://github.com/sane-apps/SaneBooks (MIT) |
| Viewing-key validator (seed/spend reject) | unit tests in repo |
| Classification (change ≠ income) | unit tests in repo |
| Live SDK sync (`2.7.0-rc.4`, `zec.rocks`) | capability + catch-up path; see Sync sources |
| Encrypted `.sanebooks` v2 + CSV/PDF; no UVK in pack | unit tests (byte scan) |
| Reader mode | app UI |
| Public bug reports | Settings → About → **Report Public Issue** |
| License / contributing | MIT `LICENSE`, `CONTRIBUTING.md` |

**Deferred (not claimed as shipped):** hosted share links, QuickBooks OAuth, ZIP 311-only export path, published accounting field dictionary, independent CPA endorsement.

### Technical Approach

- Native **SwiftUI** Mac app (local-first)
- View-only: UFVK/UIVK only; refuse seeds/spend keys; **no** propose/send APIs
- Live path: `ZcashLightClientKit` 2.7.0-rc.4 (`importAccount(purpose: .viewOnly)`)
- Classification: Income / Expense / Change / Fee
- Export: `.sanebooks` v2 (PBKDF2-HMAC-SHA256 600k + ChaCha20-Poly1305) + CSV/PDF; packs never embed UVKs
- Support: in-app diagnostics → GitHub issue template (no secrets / no LWD credentials)

### Time Period of Work Completion

**2026-08-03 – 2026-08-05** — product implementation, notarized public release **ZecBooks 0.1.1**, site/Sparkle distribution, MIT relicensing for grant eligibility.

### Total Budget (USD)

**$32,000**

### Budget Breakdown

| Line | $(USD) | Justification |
|------|--------|---------------|
| Compensation | $30,000 | Solo founder engineering for app, sync, export, tests, release, docs |
| Technology | $2,000 | Mini build/test, Apple Developer ID signing/notarization, site/dist hosting |
| Services/Contractors | $0 | None |
| **Total** | **$32,000** | |

### Previous Funding

No

### Previous Funding Details

None. No prior ZCG / coinholder / FPF grant for ZecBooks.

### Other Funding Sources

No (SaneApps self-funded product R&D to date).

### Other Funding Sources Details

_N/A_

### Success Metrics

No invented download counts or testimonials.

| Metric | How verified | Current |
|--------|--------------|---------|
| Public notarized Mac build | provenance doc + `spctl` / stapler | **ZecBooks 0.1.1** |
| SHA-256 of zip | provenance doc | `25578ef6…243308` |
| Seed/spend rejection | unit tests | covered |
| Pack contains no UVK | unit tests | covered |
| Change excluded from income | unit tests | covered |
| MIT + CONTRIBUTING | public repo | published |
| Public bug reports | Settings → About | wired |

### Proof of completion checklist

- [x] Product: https://zecbooks.app
- [x] Source: https://github.com/sane-apps/SaneBooks
- [x] MIT `LICENSE` + `CONTRIBUTING.md`
- [x] Notarized artifact + SHA-256 provenance
- [x] In-app bug reporting + GitHub issue template
- [x] FPF GitHub issue: https://github.com/Financial-Privacy-Foundation/ZcashCoinholderGrantsProgram/issues/38
- [x] Forum notice: https://forum.zcashcommunity.com/t/call-for-proposals-coinholder-directed-retroactive-grants-program-q3/56885/8
- [x] Conflict disclosure: none

### Conflict of Interest Disclosure

None. Applicant builds SaneApps consumer Mac utilities; no conflict with ZCG committee roles, competing funded checkout processors, or wallet vendors disclosed. ZecBooks is adjacent to (not competing as) CipherPay checkout and Zodl spend UX.

### Community Forum Posting

- [x] Forum notice posted (CFP reply under TL0 constraints).

### Terms checklist (at submission)

Check the live FPF template boxes that are true, including:

- Completed-work attestation: **ZecBooks 0.1.1 is a public, notarized, MIT-licensed Mac app** intended for ZEC-receiving business owners and their accountants. Coinholders and community reviewers can verify it during the mandatory review period. **No paid CPA endorsement letter is claimed.**
- MIT + `CONTRIBUTING.md` for new open-source software.
- Forum post responsibility after the GitHub issue exists.

---

*Budget $32,000 (owner-set). MIT. No fake usage numbers.*
