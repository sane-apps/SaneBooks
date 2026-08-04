# Draft: Retroactive Grant Application — SaneBooks

**Status:** Draft packaging for Coinholder-Directed Retroactive Grants (FPF template fields).  
**Not submitted.** Do not paste to GitHub/forum until the program confirms PolyForm Shield/source-available eligibility in writing, the owner sets **Requested Grant Amount**, and a notarized public artifact exists.

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

**Wedge:** CipherPay gets you paid privately. [ZBooks](https://github.com/AustinChris1/ZBooks-SIWZ) runs team treasury + approved payouts. SaneBooks is the Mac CPA layer — local books, change≠income, expiring `.sanebooks` packs (Reader), not a permanent raw UFVK.

Adjacent lanes stay adjacent (Zodl/YWallet = spend; Koinly = multi-chain tax SaaS). Full matrix: `docs/COMPETITIVE_POSITIONING.md`.

### What is implemented (verifiable source; not yet a public release)

Honest inventory as of **2026-08-04**.

| Artifact | Path / evidence |
|----------|-----------------|
| Thin Mac app + XcodeGen project | `SaneBooks/`, `project.yml` |
| SPM libraries: Core / Sync / Export / Feature | `SaneBooksPackage/Sources/*` |
| Viewing-key validator (seed/spend reject; UFVK/UIVK accept) | `SaneBooksCore` + unit tests |
| Classification engine (change ≠ income) + memo auto-tag rules | `SaneBooksCore` + unit tests |
| ZIP 302 memo decode | unit tests |
| Live `ZcashLightClientKit` **2.7.0-rc.4** view-only sync (`zec.rocks`) | `SaneBooksSync` + Mini catch-up receipt (tip **3435350**) |
| Offline `MockSyncFacade` demo path | `SANEBOOKS_FORCE_MOCK=1` / Offline demo ledger |
| Encrypted `.sanebooks` v2 packs (PBKDF2-HMAC-SHA256 600k + ChaCha20-Poly1305 with authenticated headers) + CSV + **PDF summary**; no UVK in pack bytes | `SaneBooksExport` + unit tests |
| Partial-history export gate (ack required) | PackWriter + Proof Pack / Share UI |
| Share history log (local) | Settings → Proof Packs |
| Multi-vault + Keychain + file ledger persistence | `AppModel.makeProduction()` |
| IVK receivables banner + upgrade-to-UFVK path | Ledger + Import |
| Birthday / viewing-key help (Zodl + YWallet) | Import + `docs/WALLET_VIEWING_KEY_GUIDE.md` |
| Live probe funding guide | `docs/LIVE_PROBE_FUNDING.md` |
| Reader mode (pack without vault key) | `SaneBooksFeature` |
| Canonical tests | Current Mini: **112 Swift Testing tests in 14 suites + 10 macOS UI journeys green**; combined receipt `c1db7bd167a12f2426de7c1fe9479f23` |
| Current minimum-size UX evidence | `outputs/e2e/2026-08-04/` — real 820×632 ledger/detail/builder/share journeys; Reader/import journeys also retained from the immediately preceding 820×600 pass |
| License / privacy / security docs | `LICENSE` (PolyForm Shield), `PRIVACY.md`, `SECURITY.md` |
| Competition packaging | `docs/GRANT_PROPOSAL.md`, `COMPETITIVE_POSITIONING.md`, `WALLET_VIEWING_KEY_GUIDE.md` |

**Still open before a completed-work application:**

- Non-empty live-sync receipt. The existing Zashi database receipt proves local import, not a live Ironwood receive or independently verified chain tip. See `docs/LIVE_PROBE_FUNDING.md`.
- Signed, notarized public release tied to source/dependency/binary hashes
- Published accounting export field dictionary and deterministic fixture
- Hosted share links / QuickBooks OAuth
- ZIP 311 payment-disclosure-only proofs as the sole export path

### Technical Approach

- Native **SwiftUI** Mac app; SPM split (`SaneBooksCore`, `SaneBooksSync`, `SaneBooksExport`, `SaneBooksFeature`)
- View-only facade: import UFVK/UIVK only; refuse seeds/spend keys; **no** propose/send APIs called
- Live path: `ZcashLightClientKit` 2.7.0-rc.4 behind Sync only (`importAccount(purpose: .viewOnly)`)
- Demo path: `MockSyncFacade` when `SANEBOOKS_FORCE_MOCK=1` or offline demo fixture
- Ledger classification: Income / Expense / Change / Fee; UFVK same-tx inbound+outbound → change candidate
- Export: versioned `.sanebooks` v2 (PBKDF2-HMAC-SHA256 600,000 iterations + ChaCha20-Poly1305 + authenticated canonical headers) + CSV/PDF; packs never embed UVKs
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

| Metric | How verified | Current (2026-08-04) |
|--------|--------------|----------------------|
| Canonical tests green | `./scripts/SaneMaster.rb verify --ui --timeout 1800` | **112 unit + 10 UI journeys passed**; receipt `c1db7bd167a12f2426de7c1fe9479f23` |
| Minimum-size user journeys | `outputs/e2e/2026-08-04/` | 820×632 ledger/detail/builder/share; prior 820×600 Reader/import proof retained |
| Seed/spend rejection | unit tests | covered |
| Pack contains no UVK | unit tests (byte scan) | covered |
| Change excluded from income | unit tests + ledger YTD | covered |
| Live LWD catch-up | Mini run: tip **3435350**, status caughtUp, LWD `zec.rocks` | **proven** |
| Live Ironwood **receive** visible | funded key + live-sync screenshot/log of ≥1 inbound Ironwood note | **not proven** — private Zashi import evidence is import proof only |

### Proof of completion checklist

- [x] Public GitHub: https://github.com/sane-apps/SaneBooks
- [x] `LICENSE` — PolyForm Shield
- [x] `README.md` — coinholder-facing problem/solution/non-goals
- [x] Core/Sync/Export/Feature sources under `SaneBooksPackage/`
- [x] Canonical test command: `./scripts/SaneMaster.rb verify --timeout 1800`
- [x] Current minimum-size UX evidence: `outputs/e2e/2026-08-04/`
- [x] Live sync catch-up: LWD `zec.rocks`, tip **3435350**, `SESSION_HANDOFF.md`
- [x] Zashi database import receipt — `outputs/visual-audit-sanebooks/gold-zashi-e2e/` + `LOG_RECEIPT.txt` (not live-receive proof)
- [ ] Funded live Ironwood receive and current live-sync receipt
- [x] Signed/notarized public artifact with source/dependency/binary provenance — https://github.com/sane-apps/SaneBooks/releases/tag/v0.1.0 (`SaneBooks-0.1.0.zip`, sha256 `54b922814f0269f94609b483d948b7cb2706a6b8cdc3254756a8e1142b964fe8`, notary `fcd6111b-0267-48f2-9797-866fac68ac06`, git `8583fbdc531f`)
- [ ] Forum application thread + FPF GitHub issue (at submission)
- [x] Conflict disclosure confirmed: none

### Conflict of Interest Disclosure

None. Applicant builds SaneApps consumer Mac utilities; no conflict with ZCG committee roles, competing funded checkout processors, or wallet vendors disclosed. SaneBooks is adjacent to (not competing as) CipherPay checkout and Zodl spend UX.

### Community Forum Posting

- [ ] I understand it is my responsibility to post a link to the FPF issue on the [Zcash Community Forums Retroactive Grants category](https://forum.zcashcommunity.com/c/grants/retroactive-grants/54) after submission.

### Terms checklist (complete at submission)

Copy from the current FPF issue template and check only what is true — especially the attestation that work is **fully completed and verifiable**. Under PolyForm Shield, describe SaneBooks as **source-available/Transparent Code**, not OSI open source. Obtain written program eligibility guidance before adding a contribution-policy claim or submitting.

---

*Draft only. Budget $X TBD. No fake usage numbers.*
