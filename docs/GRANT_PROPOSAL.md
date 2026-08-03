# Draft: Retroactive Grant Application — SaneBooks

**Status:** Draft packaging for Coinholder-Directed Retroactive Grants (FPF template fields).  
**Not submitted.** Do not paste to GitHub/forum until owner sets **Requested Grant Amount** and confirms a **funded live receive** receipt exists (or explicitly scopes the attestation to catch-up-only).

Program: [Financial Privacy Foundation — Zcash Coinholder Grants Program](https://github.com/Financial-Privacy-Foundation/ZcashCoinholderGrantsProgram)  
Forum gap cited: [Is anyone actually using viewing keys for business accounting?](https://forum.zcashcommunity.com/t/is-anyone-actually-using-viewing-keys-for-business-accounting/56300)

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

**$X TBD — owner must set before submission.** Do not invent hours or a dollar figure.

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

Honest inventory as of **2026-08-03**.

| Artifact | Path / evidence |
|----------|-----------------|
| Thin Mac app + XcodeGen project | `SaneBooks/`, `project.yml` |
| SPM libraries: Core / Sync / Export / Feature | `SaneBooksPackage/Sources/*` |
| Viewing-key validator (seed/spend reject; UFVK/UIVK accept) | `SaneBooksCore` + unit tests |
| Classification engine (change ≠ income) + memo auto-tag rules | `SaneBooksCore` + unit tests |
| ZIP 302 memo decode | unit tests |
| Live `ZcashLightClientKit` **2.7.0-rc.4** view-only sync (`zec.rocks`) | `SaneBooksSync` + Mini catch-up receipt (tip **3435350**) |
| Offline `MockSyncFacade` demo path | `SANEBOOKS_FORCE_MOCK=1` / Offline demo ledger |
| Encrypted `.sanebooks` packs (AEAD) + CSV + **PDF summary**; no UVK in pack bytes | `SaneBooksExport` + unit tests |
| Partial-history export gate (ack required) | PackWriter + Proof Pack / Share UI |
| Share history log (local) | Settings → Proof Packs |
| Multi-vault + Keychain + file ledger persistence | `AppModel.makeProduction()` |
| IVK receivables banner + upgrade-to-UFVK path | Ledger + Import |
| Birthday / viewing-key help (Zodl + YWallet) | Import + `docs/WALLET_VIEWING_KEY_GUIDE.md` |
| Live probe funding guide | `docs/LIVE_PROBE_FUNDING.md` |
| Reader mode (pack without vault key) | `SaneBooksFeature` |
| Unit tests | `SANEBOOKS_USE_LOCAL_SANEUI=1 swift test` — **38/38 green** |
| Visual audit screenshots (mock E2E) | `outputs/visual-audit-sanebooks/` (`e2e-*`, `v11-*`, `VERDICT.md`) |
| License / privacy / security docs | `LICENSE` (PolyForm Shield), `PRIVACY.md`, `SECURITY.md` |
| Competition packaging | `docs/GRANT_PROPOSAL.md`, `COMPETITIVE_POSITIONING.md`, `WALLET_VIEWING_KEY_GUIDE.md` |

**Still open before a full “live books” attestation:**

- Non-empty live ledger (probe UFVK has **0** historical receives — needs a dust send to the probe UA, or import of an owner UFVK with history). See `docs/LIVE_PROBE_FUNDING.md`.
- Notarized public release / Sparkle updates
- Hosted share links / QuickBooks OAuth
- ZIP 311 payment-disclosure-only proofs as the sole export path

### Technical Approach

- Native **SwiftUI** Mac app; SPM split (`SaneBooksCore`, `SaneBooksSync`, `SaneBooksExport`, `SaneBooksFeature`)
- View-only facade: import UFVK/UIVK only; refuse seeds/spend keys; **no** propose/send APIs called
- Live path: `ZcashLightClientKit` 2.7.0-rc.4 behind Sync only (`importAccount(purpose: .viewOnly)`)
- Demo path: `MockSyncFacade` when `SANEBOOKS_FORCE_MOCK=1` or offline demo fixture
- Ledger classification: Income / Expense / Change / Fee; UFVK same-tx inbound+outbound → change candidate
- Export: versioned AEAD `.sanebooks` (HKDF-SHA256 + ChaCha20-Poly1305) + CSV; packs never embed UVKs
- Trust: local-first; Keychain ThisDeviceOnly for key material; no iCloud vault sync; LWD trust named in pack attestation metadata

### Time Period of Work Completion

**2026-08** — scaffold, mock MVP, v1.1 competition pack, live SDK wire-up and mainnet catch-up proof (see `SESSION_HANDOFF.md`).

### Total Budget (USD)

**$X TBD — owner must set before submission.**

### Budget Breakdown

| Line | $(USD) | Justification |
|------|--------|---------------|
| Compensation | TBD | Owner engineering for Core/Sync/Export/Feature, Mac shell, tests, visual audit, docs — **hours not invented** |
| Technology | TBD | Build/test Mac Mini time, signing/notarization if in scope |
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

| Metric | How verified | Current (2026-08-03) |
|--------|--------------|----------------------|
| Unit tests green | `swift test` | **38/38** |
| Mock E2E visual audit | `outputs/visual-audit-sanebooks/VERDICT.md` | 7 scenes pass |
| Seed/spend rejection | unit tests | covered |
| Pack contains no UVK | unit tests (byte scan) | covered |
| Change excluded from income | unit tests + ledger YTD | covered |
| Live LWD catch-up | Mini run: tip **3435350**, status caughtUp, LWD `zec.rocks` | **proven** |
| Live Ironwood **receive** visible | screenshot of ≥1 inbound note after fund/sync | **pending dust send** (`docs/LIVE_PROBE_FUNDING.md`) |
| External CPA pilot | written feedback (if any) | **none claimed** |

### Proof of completion checklist

- [ ] Public GitHub URL (fill after `sane-apps/SaneBooks` remote exists)
- [x] `LICENSE` — PolyForm Shield
- [x] `README.md` — coinholder-facing problem/solution/non-goals
- [x] Core/Sync/Export/Feature sources under `SaneBooksPackage/`
- [x] Test command:  
  `cd SaneBooksPackage && SANEBOOKS_USE_LOCAL_SANEUI=1 swift test`
- [x] Visual audit: `outputs/visual-audit-sanebooks/` (`e2e-welcome.png` … `e2e-reader.png`, `VERDICT.md`)
- [x] Live sync catch-up: LWD `zec.rocks`, tip **3435350**, `SESSION_HANDOFF.md`
- [ ] Live receive screenshot + log (after funding probe UA or importing funded UFVK)
- [ ] Forum application thread + FPF GitHub issue (at submission)
- [x] Conflict disclosure confirmed: none

### Conflict of Interest Disclosure

None. Applicant builds SaneApps consumer Mac utilities; no conflict with ZCG committee roles, competing funded checkout processors, or wallet vendors disclosed. SaneBooks is adjacent to (not competing as) CipherPay checkout and Zodl spend UX.

### Community Forum Posting

- [ ] I understand it is my responsibility to post a link to the FPF issue on the [Zcash Community Forums Retroactive Grants category](https://forum.zcashcommunity.com/c/grants/retroactive-grants/54) after submission.

### Terms checklist (complete at submission)

Copy from the current FPF issue template and check only what is true — especially the attestation that work is **fully completed and verifiable**. Do **not** claim a live Ironwood **receive** until the pending funded-note receipt exists.

---

*Draft only. Budget $X TBD. No fake usage numbers.*
