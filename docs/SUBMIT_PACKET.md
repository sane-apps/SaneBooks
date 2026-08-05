# Q3 submit packet — ZecBooks

**Do not post** until GitHub `main` shows MIT, CONTRIBUTING, bug template, provenance, and this grant draft.

## 1) FPF GitHub issue

https://github.com/Financial-Privacy-Foundation/ZcashCoinholderGrantsProgram/issues/new?template=grant_application.yaml

Title: `Retroactive Grant Application - ZecBooks`

Fill from `docs/GRANT_PROPOSAL.md`.

## 2) Forum thread (after GitHub issue exists)

Category: Community Grants → Retroactive Grants  
Title: `Retroactive Grant Application: ZecBooks`

```
## ZecBooks — Retroactive Grant Application (Q3 2026)

**Ask:** $32,000 USD  
**FPF issue:** <paste GitHub issue URL>  
**Product:** https://zecbooks.app  
**Download:** https://zecbooks.app/download  
**Provenance (SHA-256 + notarization):** https://github.com/sane-apps/SaneBooks/blob/main/docs/ZecBooks-0.1.1-PROVENANCE.md  
**Source:** https://github.com/sane-apps/SaneBooks  
**License:** MIT

### One line
CipherPay gets you paid privately. ZBooks runs team treasury. **ZecBooks** is the Mac bookkeeping layer: classify change so it is not income, then hand your accountant an expiring `.sanebooks` pack — not a permanent viewing key.

### What shipped
- Notarized **ZecBooks 0.1.1** (Developer ID) via https://dist.zecbooks.app/updates/ZecBooks-0.1.1.zip
- SHA-256: `25578ef64874705f2f73ca9f23193a6ddd873a33a05339b284b0af1bec243308`
- View-only UFVK/UIVK import; refuses seeds/spend keys
- Live lightwalletd sync (ZcashLightClientKit 2.7.0-rc.4)
- Classification + encrypted proof packs + Reader
- Settings → About → Report Public Issue

### Verify in five minutes
1. `curl -fsSL -o ZecBooks-0.1.1.zip https://dist.zecbooks.app/updates/ZecBooks-0.1.1.zip && shasum -a 256 ZecBooks-0.1.1.zip`
2. Unzip → `spctl -a -vv -t exec ZecBooks.app` (expect Notarized Developer ID)
3. Read MIT LICENSE + CONTRIBUTING.md on GitHub

Happy to answer questions in this thread during the review period.
```

## 3) Owner-gated next steps

1. Commit + push this tree to `sane-apps/SaneBooks` `main`
2. Deploy website Pages (MIT footer) if not auto-deployed
3. Optional: `gh release create v0.1.1` pointing at dist zip + provenance
4. Create FPF issue + forum thread (needs explicit public-post approval)
