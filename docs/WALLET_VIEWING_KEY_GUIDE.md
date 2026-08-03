# Wallet viewing-key export guide (UFVK)

**Purpose:** Help a business owner export a **Unified Full Viewing Key (UFVK)** for SaneBooks bookkeeper mode — or a **UIVK** for receivables-only (degraded) mode.

**Hard rules**

- Export a **viewing** key only. Never paste a seed phrase or spending key into SaneBooks.
- Viewing keys are **irrevocable**. Anyone who keeps a copy can keep reading that account’s history forever. Prefer sharing a SaneBooks **proof pack** with your accountant, not the raw UFVK.
- Prefer **UFVK** (`uview1…` / Rev2 `uvf…`) for real books. **UIVK** cannot correctly classify change as non-income.
- Confirm **mainnet vs testnet** before import.
- Never paste a viewing key into a public block explorer or random website.

Accuracy: **best-effort**. Wallet UIs change. Steps marked **[uncertain]** were not re-verified against the latest app build in this packaging pass — check the wallet’s current docs if a menu label differs.

---

## What string to look for

| Kind | Typical HRP (mainnet) | SaneBooks mode |
|------|------------------------|----------------|
| UFVK | `uview1…` (also Rev2 `uvf…`) | Bookkeeper (preferred) |
| UIVK | `uivk…` / `uvi…` | Receivables only + permanent banner |
| Legacy Sapling FVK | `zxviews…` | Supported for older merchants when possible; prefer unified |

---

## Zodl

Zodl is a modern Zcash wallet with viewing-key export for view-only / portfolio flows.

**Reported path (community / CipherScan learn pages):**

1. Open Zodl (device you trust).
2. Go to **More**.
3. Open **Export Private Data** — or **Seed & Keys → Show Sub Keys**  
   **[uncertain which submenu is current in your build; both appear in public write-ups.]**
4. Locate the **Unified Full Viewing Key** / UFVK (string beginning `uview…`).
5. Copy only the viewing key. Do **not** copy the seed into SaneBooks.
6. Paste into SaneBooks → Import.

**Notes**

- Zodl UFVK export UI was called out as completed in ZODL ecosystem updates (2026) for view-only setups.
- If you only see an incoming viewing key, SaneBooks will run receivables mode — fine for AR clerks, not complete P&L.

---

## YWallet

YWallet supports viewing-key features and UFVK display via backup.

**Reported path:**

1. Open the account in YWallet.
2. Use the **Backup** command / backup screen for that account.  
   Community reports: Backup displays the viewing key even when the account still has a spending key ([forum discussion](https://forum.zcashcommunity.com/t/export-and-import-of-incoming-viewing-keys-ivk-into-a-litewallet-mobile-app/45186)).
3. Copy the **unified viewing key** (`uview…`), not the seed.
4. Paste into SaneBooks.

**[uncertain]** Exact menu labels differ by YWallet version (desktop vs mobile). If Backup is not obvious, check YWallet’s current help for “viewing key” / “UFVK”.

**Notes**

- YWallet can also **import** a viewing-only account from a key — useful to test that your exported string is valid before trusting SaneBooks import.
- Prefer UFVK over Sapling-only `zxviews…` when your wallet offers unified export.

---

## zcashd

`zcashd` remains useful for operators with a full node, with limits after NU6.3 (Zebra is the long-term full-validation path; `zcashd` will not implement NU6.3 — see [ZIP 258](https://zips.z.cash/zip-0258)).

### Export (RPC)

```bash
zcash-cli z_exportviewingkey "YOUR_Z_ADDRESS"
```

Docs: [z_exportviewingkey](https://zcash.github.io/rpc/z_exportviewingkey.html)

- Returns the full viewing key for that `zaddr` in the legacy protocol encoding.
- Import of **unified** viewing keys into `zcashd` is historically **not** supported (`z_importviewingkey` notes unified UVK import as unsupported).
- **[uncertain for your node version]** whether a Unified Address yields a `uview…` string or a Sapling `zxviews…` string — inspect the HRP before import. Prefer exporting a UFVK from Zodl/YWallet when you need ZIP 316 unified keys covering modern pools.

### Practical recommendation

If you need a modern **UFVK** covering Sapling + Orchard (+ Ironwood-era receives as wallets migrate), prefer export from a **current unified wallet** (Zodl / YWallet / Zingo-class) rather than relying on `zcashd` alone.

---

## Zingo CLI (optional)

Public learn pages document:

```text
exportufvk
```

**[uncertain]** Confirm against your Zingo CLI version’s `--help`. Useful for power users who already operate Zingo.

---

## After export — SaneBooks import checklist

1. Confirm the string is a viewing key (HRP above), not 12/24 words and not `secret-extended-key`.
2. Prefer UFVK for bookkeeper mode.
3. Set birthday height conservatively if asked (too high = silent missing income).
4. Do not email the raw UFVK. Build a **proof pack** for the accountant when possible.
5. If you must share a key with a CPA who reconciles spends, treat that as permanent disclosure and use a dedicated account when you can.

---

## Sources (non-exhaustive)

- ZIP 316 — https://zips.z.cash/zip-0316
- ECC viewing keys explainer — https://electriccoin.co/blog/explaining-viewing-keys-2/
- zcashd `z_exportviewingkey` — https://zcash.github.io/rpc/z_exportviewingkey.html
- Forum: IVK/UFVK wallet export discussion — https://forum.zcashcommunity.com/t/export-and-import-of-incoming-viewing-keys-ivk-into-a-litewallet-mobile-app/45186
- Forum: business accounting gap — https://forum.zcashcommunity.com/t/is-anyone-actually-using-viewing-keys-for-business-accounting/56300
- CipherScan learn (Zodl / Zingo export pointers) — https://cipherscan.app/learn

*If a step is wrong for your wallet build, fix this doc with a dated note rather than guessing.*
