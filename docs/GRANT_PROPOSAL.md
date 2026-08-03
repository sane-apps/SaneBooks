# Draft: Retroactive Grant Application — SaneBooks

**Status:** Draft packaging for Coinholder-Directed Retroactive Grants (FPF template fields).  
**Not submitted.** Do not paste to GitHub/forum until owner fills TBD fields and confirms the retroactive scope is complete enough to attest.

Program: [Financial Privacy Foundation — Zcash Coinholder Grants Program](https://github.com/Financial-Privacy-Foundation/ZcashCoinholderGrantsProgram)  
Forum gap cited: [Is anyone actually using viewing keys for business accounting?](https://forum.zcashcommunity.com/t/is-anyone-actually-using-viewing-keys-for-business-accounting/56300)

---

### Application Owners

TBD — `@github-handle` (Stephan Joseph / SaneApps)

### Organization or Individual Name

SaneApps

### Additional Team Members

```yaml
# TBD — fill before submission
- Name: Stephan Joseph
  Role: Founder / product + engineering
  Background: SaneApps Mac products (local-first, privacy-minded utilities)
  Responsibilities: Architecture, Mac app, classification/export, docs
```

### How did you learn about the Lockbox: Coinholder Retroactive Grants Program?

TBD (forum / community / prior Zcash ecosystem reading)

### Requested Grant Amount (USD)

**$X TBD** — do not invent hours or a dollar figure until owner sets scope and rates.

### Category

Non-Wallet Applications  
(view-only accountant / selective-disclosure layer — explicitly **not** a spending wallet)

### Project Summary

SaneBooks is a Mac-native, local-first accountant layer for shielded Zcash: import a viewing key, classify income vs change vs expense, and export a scoped, expiring proof pack for a CPA. It cannot spend ZEC. It is not a merchant checkout product.

### Project Description / Problem / Motivation

Shielded ZEC already supports ZIP 316 viewing keys. Merchant checkout and wallets exist. The missing product is **accounting semantics**:

- UFVK-class history so change notes are not booked as income
- Honest sync-gap / LWD-trust disclosure on every export
- Scoped proof packs (encrypted `.sanebooks` + CSV) instead of handing the accountant a permanent raw UFVK
- Ironwood-era honesty: post-NU6.3 receives are not Orchard-only

Motivation and community demand are documented in the Jun 2026 forum thread:  
https://forum.zcashcommunity.com/t/is-anyone-actually-using-viewing-keys-for-business-accounting/56300

Adjacent products cover other lanes (CipherPay = IVK checkout; Zodl/YWallet = spend wallets; Koinly = multi-chain tax SaaS weak on shielded ZEC; ZBooks hackathon = team/DAO treasury + payouts). SaneBooks targets **owner → CPA selective disclosure** on a local Mac.

### What shipped (verifiable artifacts)

Honest inventory as of **2026-08-03** (Week 0–1 MVP + v1.1 competition pack). Live lightwalletd / Ironwood compact sync is **not** claimed complete — mainnet completeness is capability-gated (`supportsIronwood=false` until SDK #1806-class work).

| Artifact | Path / evidence |
|----------|-----------------|
| Thin Mac app + XcodeGen project | `SaneBooks/`, `project.yml` |
| SPM libraries: Core / Sync / Export / Feature | `SaneBooksPackage/Sources/*` |
| Viewing-key validator (seed/spend reject; UFVK/UIVK accept) | `SaneBooksCore` + unit tests |
| Classification engine (change ≠ income) + memo auto-tag rules | `SaneBooksCore` + unit tests |
| ZIP 302 memo decode | unit tests |
| Mock sync + `LightClientSyncFacade` blocked path + capability probe | `SaneBooksSync` |
| Encrypted `.sanebooks` packs (AEAD) + CSV + **PDF summary**; no UVK in pack bytes | `SaneBooksExport` + unit tests |
| Partial-history export gate (ack required) | PackWriter + Proof Pack / Share UI |
| Share history log (local) | Settings → Proof Packs |
| Multi-vault + Keychain + file ledger persistence | `AppModel.makeProduction()` |
| IVK receivables banner + upgrade-to-UFVK path | Ledger + Import |
| Birthday / viewing-key help (Zodl + YWallet) | Import + `docs/WALLET_VIEWING_KEY_GUIDE.md` |
| Reader mode (pack without vault key) | `SaneBooksFeature` |
| Unit tests | `SANEBOOKS_USE_LOCAL_SANEUI=1 swift test` — **34/34 green** |
| Visual audit screenshots | `outputs/visual-audit-sanebooks/` (`e2e-*`, `v11-*`, `VERDICT.md`) |
| License / privacy / security docs | `LICENSE` (PolyForm Shield), `PRIVACY.md`, `SECURITY.md` |
| Competition packaging | `docs/GRANT_PROPOSAL.md`, `COMPETITIVE_POSITIONING.md`, `WALLET_VIEWING_KEY_GUIDE.md` |

**Explicitly not shipped yet (do not claim in a submitted application until done):**

- Live compact-block sync against mainnet lightwalletd with Ironwood actions
- Notarized public release / Sparkle updates / public GitHub remote
- Hosted share links / QuickBooks OAuth
- ZIP 311 payment-disclosure-only proofs as the sole export path
### Technical Approach

- Native **SwiftUI** Mac app; SaneHosts-style SPM split (`SaneBooksCore`, `SaneBooksSync`, `SaneBooksExport`, `SaneBooksFeature`)
- View-only facade over sync: import UFVK/UIVK only; refuse seeds/spend keys
- Demo path: `MockSyncFacade` for offline E2E while Ironwood-capable SDK pin is gated (`mainnetSafe = Sapling && Orchard && Ironwood`)
- Ledger classification: Income / Expense / Change / Fee; UFVK same-tx inbound+outbound → change candidate
- Export: versioned AEAD `.sanebooks` (HKDF-SHA256 + ChaCha20-Poly1305) + CSV; packs never embed UVKs
- Trust: local-first; Keychain ThisDeviceOnly for key material; no iCloud vault sync; LWD trust named in pack attestation metadata

Stack target for live sync (when capability gate passes): `ZcashLightClientKit` / librustzcash behind Sync only — Feature/Export must not import the SDK.

### Time Period of Work Completion

TBD — scaffold and mock MVP work dated **2026-08** (see `SESSION_HANDOFF.md`). Extend only with dates of verifiable completed work before submission.

### Total Budget (USD)

**$X TBD**

### Budget Breakdown

| Line | $(USD) | Justification |
|------|--------|---------------|
| Compensation | TBD | Owner engineering for Core/Sync/Export/Feature, Mac shell, tests, visual audit, docs — **hours not invented** |
| Technology | TBD | Build/test Mac Mini time, signing/notarization if in scope — leave blank until known |
| Services/Contractors | $0 (expected) | None unless owner adds |
| **Total** | **$X TBD** | |

### Previous Funding

No

### Previous Funding Details

None. No prior ZCG / coinholder / FPF grant for SaneBooks.

### Other Funding Sources

No (SaneApps self-funded product R&D to date). Update if that changes before submission.

### Other Funding Sources Details

_N/A_

### Success Metrics

Use only measurable, non-fake metrics. **Do not invent download counts or testimonials.**

Proposed metrics (fill with real numbers at submission time):

| Metric | How verified | Current (2026-08-03) |
|--------|--------------|----------------------|
| Unit tests green | `swift test` | 21/21 |
| Mock E2E visual audit | `outputs/visual-audit-sanebooks/VERDICT.md` | 7 scenes pass |
| Seed/spend rejection | unit tests | covered |
| Pack contains no UVK | unit tests (byte scan) | covered |
| Change excluded from income | unit tests + ledger YTD | covered |
| Live Ironwood sync | capability gate + mainnet receipt | **not yet** |
| External CPA pilot | written feedback (if any) | **none claimed** |

### Proof of completion checklist

- [ ] Repo paths: `~/SaneApps/apps/SaneBooks` (public GitHub URL TBD when remote exists)
- [x] `LICENSE` — PolyForm Shield
- [x] `README.md` — coinholder-facing problem/solution/non-goals
- [x] Core/Sync/Export/Feature sources under `SaneBooksPackage/`
- [x] Test command:  
  `cd SaneBooksPackage && SANEBOOKS_USE_LOCAL_SANEUI=1 swift test`
- [x] Visual audit: `outputs/visual-audit-sanebooks/` (`e2e-welcome.png` … `e2e-reader.png`, `VERDICT.md`)
- [ ] Live sync proof (when ready): named LWD endpoint, tip height, Ironwood receive visible — screenshot + log receipt
- [ ] Forum application thread + FPF GitHub issue (at submission)
- [ ] Conflict disclosure confirmed: none

### Conflict of Interest Disclosure

None. Applicant builds SaneApps consumer Mac utilities; no conflict with ZCG committee roles, competing funded checkout processors, or wallet vendors disclosed. SaneBooks is adjacent to (not competing as) CipherPay checkout and Zodl spend UX.

### Community Forum Posting

- [ ] I understand it is my responsibility to post a link to the FPF issue on the [Zcash Community Forums Retroactive Grants category](https://forum.zcashcommunity.com/c/grants/retroactive-grants/54) after submission.

### Terms checklist (complete at submission)

Copy from the current FPF issue template and check only what is true — especially the attestation that work is **fully completed and verifiable**. Do not submit a partially complete Ironwood sync claim.

---

*Draft only. Budget $X TBD. No fake usage numbers.*
