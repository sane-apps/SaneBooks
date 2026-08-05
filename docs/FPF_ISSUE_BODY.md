### Terms and Conditions

- [x] I agree to the [Grant Agreement](https://9ba4718c-5c73-47c3-a024-4fc4e5278803.usrfiles.com/ugd/9ba471_6ff6db4095fd4c4ba21babec361e927e.pdf) terms if funded
- [x] I agree to [Provide KYC information](https://9ba4718c-5c73-47c3-a024-4fc4e5278803.usrfiles.com/ugd/9ba471_7d9e73d16b584a61bae92282b208efc4.pdf) if funded above $50,000 USD
- [x] I agree to disclose conflicts of interest
- [x] I understand that this grant program is only eligible for completed work, as it is a retroactive grant program. Applications for planned or partially completed work will not be considered. All completed work will be verified and accepted by its intended users or their representatives, who will confirm that the outputs meet the required quality, functionality, and usability before the work is listed as an option for Coinholder voting.
- [x] I agree that for any new open-source software, I will create a CONTRIBUTING.md file that reflects the high standards of Zcash development, using the [`librustzcash` style guides](https://github.com/zcash/librustzcash/blob/main/CONTRIBUTING.md#styleguides) as a primary reference.
- [x] I understand when contributing to existing Zcash code, I am required to adhere to the project specific contribution guidelines, paying close attention to any [merge](https://github.com/zcash/librustzcash/blob/main/CONTRIBUTING.md#merge-workflow), [branch](https://github.com/zcash/librustzcash/blob/main/CONTRIBUTING.md#branch-history), [pull request](https://github.com/zcash/librustzcash/blob/main/CONTRIBUTING.md#pull-request-review), and [commit](https://github.com/zcash/librustzcash/blob/main/CONTRIBUTING.md#commit-messages) guidelines as exemplified in the librustzcash repository.
- [x] I understand all grants are valued in USD but will be disbursed in Shielded ZEC. I acknowledge and accept that disbursement amounts may fluctuate based on the ZEC/USD exchange rate at the time of payment.

### Application Owners (@octocat, @octocat1)

@MrSaneApps

### Organization or Individual Name

SaneApps

### Additional Team Members

```team-members.yaml
- Name: Stephan Joseph
  Role: Founder / product + engineering
  Background: SaneApps Mac products (local-first, privacy-minded utilities)
  Responsibilities: Architecture, Mac app, classification/export, docs
```

### How did you learn about the Lockbox: Coinholder Retroactive Grants Program?

Zcash Community Forum (business viewing-key accounting thread) and ongoing Zcash ecosystem follow.

### Requested Grant Amount (USD)

$32,000

### Category

Non-Wallet Applications

### Project Summary

**ZecBooks** is a Mac-native, local-first bookkeeping layer for shielded Zcash: import a viewing key, classify income vs change vs expense, and export a scoped, expiring proof pack for an accountant. It cannot spend ZEC. It is not a merchant checkout product.

### Project Description

A lot of people assume privacy coins are about hiding from taxes. That is not why I built this, and it is not why most Zcash users care about shielded money. I believe people have a right to financial privacy and still want to keep clean books.

**Private money, kept with honest books.**

Shielded ZEC already supports ZIP 316 viewing keys. Merchant checkout and wallets exist. The missing product is **accounting semantics**:

- UFVK-class history so change notes are not booked as income
- Honest sync-gap / LWD-trust disclosure on every export
- Scoped proof packs (encrypted `.sanebooks` + CSV) instead of handing the accountant a permanent raw UFVK
- Ironwood-era sync via linked `ZcashLightClientKit` **2.7.0-rc.4** (view-only)

Community demand thread:  
https://forum.zcashcommunity.com/t/is-anyone-actually-using-viewing-keys-for-business-accounting/56300

**Wedge:** CipherPay gets you paid privately. [ZBooks](https://github.com/AustinChris1/ZBooks-SIWZ) runs team treasury + approved payouts. **ZecBooks** is the Mac bookkeeping layer after money arrives — local books, change≠income, expiring `.sanebooks` packs (Reader), not a permanent raw UFVK.

**Public product:** https://zecbooks.app  
**Download:** https://zecbooks.app/download → notarized [ZecBooks-0.1.1.zip](https://dist.zecbooks.app/updates/ZecBooks-0.1.1.zip)  
**Source:** https://github.com/sane-apps/SaneBooks (MIT; customer name ZecBooks; historical repo path SaneBooks)  
**Provenance:** https://github.com/sane-apps/SaneBooks/blob/main/docs/ZecBooks-0.1.1-PROVENANCE.md (SHA-256 `25578ef64874705f2f73ca9f23193a6ddd873a33a05339b284b0af1bec243308`)

**Deferred (not claimed as shipped):** hosted share links, QuickBooks OAuth, ZIP 311-only export path, published accounting field dictionary, independent CPA endorsement.

### Technical Approach (how you did it)

- Native **SwiftUI** Mac app (local-first)
- View-only: UFVK/UIVK only; refuse seeds/spend keys; **no** propose/send APIs
- Live path: `ZcashLightClientKit` 2.7.0-rc.4 (`importAccount(purpose: .viewOnly)`)
- Classification: Income / Expense / Change / Fee
- Export: `.sanebooks` v2 (PBKDF2-HMAC-SHA256 600k + ChaCha20-Poly1305) + CSV/PDF; packs never embed UVKs
- Support: Settings → About → Report Public Issue (in-app diagnostics → GitHub issue template; no secrets / no LWD credentials)

### Time Period of Work Completion

2026-08-03 – 2026-08-05 — product implementation, notarized public release ZecBooks 0.1.1, site/Sparkle distribution, MIT relicensing for grant eligibility.

### Total Budget (USD)

$32,000

### Budget Breakdown

```
- Compensation:
  - $(USD): 30000
  - Justification: Solo founder engineering for app, sync, export, tests, release, docs
- Technology/Software:
  - $(USD): 2000
  - Justification: Mini build/test, Apple Developer ID signing/notarization, site/dist hosting
- Infrastructure/Hosting:
  - $(USD): 0
  - Justification: N/A (included in technology line)
- Services/Contractors:
  - $(USD): 0
  - Justification: None
- Other:
  - $(USD): 0
  - Justification: N/A
- Total $(USD): 32000
```

### Previous Funding

No

### Previous Funding Details

None. No prior ZCG / coinholder / FPF grant for ZecBooks.

### Other Funding Sources

No

### Other Funding Sources Details

N/A (SaneApps self-funded product R&D to date).

### Success Metrics

No invented download counts or testimonials.

- Public notarized Mac build: ZecBooks 0.1.1 (provenance doc + Gatekeeper/stapler)
- SHA-256 of zip: `25578ef64874705f2f73ca9f23193a6ddd873a33a05339b284b0af1bec243308`
- Seed/spend rejection: unit tests in repo
- Pack contains no UVK: unit tests (byte scan)
- Change excluded from income: unit tests
- MIT LICENSE + CONTRIBUTING.md: published on GitHub
- Public bug reports: Settings → About → Report Public Issue

### Proof of completion

- Product: https://zecbooks.app
- Download: https://zecbooks.app/download → https://dist.zecbooks.app/updates/ZecBooks-0.1.1.zip
- Provenance (SHA-256 + notarization): https://github.com/sane-apps/SaneBooks/blob/main/docs/ZecBooks-0.1.1-PROVENANCE.md
- Source (MIT): https://github.com/sane-apps/SaneBooks
- GitHub release: https://github.com/sane-apps/SaneBooks/releases/tag/v0.1.1
- CONTRIBUTING.md: https://github.com/sane-apps/SaneBooks/blob/main/CONTRIBUTING.md
- Sparkle appcast: https://zecbooks.app/appcast.xml
- Bug report template: https://github.com/sane-apps/SaneBooks/blob/main/.github/ISSUE_TEMPLATE/bug_report.md

### Conflict of Interest Disclosure

None. Applicant builds SaneApps consumer Mac utilities; no conflict with ZCG committee roles, competing funded checkout processors, or wallet vendors disclosed. ZecBooks is adjacent to (not competing as) CipherPay checkout and Zodl spend UX.

### Community Forum Posting

- [x] I understand it is my responsibility to post a link to this issue on the [Zcash Community Forums](https://forum.zcashcommunity.com/t/about-the-retroactive-grants-category/52106) after this application has been submitted so the community can give input. I understand this is required in order for the community to discuss and vote on this grant application. Note: If you are unable to post on the forum (for example, due to new user restrictions), please leave a comment below, and we will adjust your posting permissions.
