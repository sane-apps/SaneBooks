# Forum draft (copy into Retroactive Grants)

Title: `Retroactive Grant Application: ZecBooks`

## ZecBooks — Retroactive Grant Application (Q3 2026)

**Ask:** $32,000 USD  
**FPF issue:** https://github.com/Financial-Privacy-Foundation/ZcashCoinholderGrantsProgram/issues/38  
**Product:** https://zecbooks.app  
**Download:** https://zecbooks.app/download  
**Provenance (SHA-256 + notarization):** https://github.com/sane-apps/SaneBooks/blob/main/docs/ZecBooks-0.1.1-PROVENANCE.md  
**Source:** https://github.com/sane-apps/SaneBooks  
**License:** MIT

### Why this exists
A lot of people assume privacy coins are about hiding from taxes. That is not why I built this, and it is not why most Zcash users care about shielded money. I believe people have a right to financial privacy and still want to keep clean books. ZecBooks is the Mac layer for that: import a view-only key, classify income and change honestly, then send your accountant a locked package of the rows they need — without giving them lasting access to your wallet.

**Private money, kept with honest books.**

CipherPay gets you paid privately. ZBooks runs team treasury. ZecBooks is the Mac bookkeeping layer after money arrives.

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
