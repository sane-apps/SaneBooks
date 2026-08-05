# How to get a UFVK with history (ZecBooks live proof)

You do **not** need to invent a key. Use the built-in live probe account, then put **any** small ZEC amount on it.

## Fast path (recommended)

1. In ZecBooks: **Import Viewing Key → Use Live Probe Key → Import**.
2. From **any** wallet that already holds ZEC (Zodl, YWallet, exchange, etc.), send a tiny amount to this **unified address** (same account as the probe UFVK):

```
u1l9f0l4348negsncgr9pxd9d3qaxagmqv3lnexcplmufpq7muffvfaue6ksevfvd7wrz7xrvn95rc5zjtn7ugkmgh5rnxswmcj30y0pw52pn0zjvy38rn2esfgve64rj5pcmazxgpyuj
```

3. Wait for the tx to mine (~1–3 blocks).
4. In ZecBooks: sync again (or reopen the vault). You should see ≥1 inbound note.
5. Tag it Income → New Proof Pack → save `.sanebooks`.

That is a real mainnet receive on the Ironwood-era chain tip window (birthday `3430000`).

## If you have no ZEC at all

Buy the smallest amount your exchange allows, withdraw to the UA above (or to your own wallet first, then forward). There is no mainnet faucet.

## If you already have a funded wallet

Export that wallet’s **UFVK** (`uview…`) instead — see `WALLET_VIEWING_KEY_GUIDE.md` — and import it into ZecBooks with the wallet birthday. That is better for “your books”; the probe path is only for grant/dev proof.

## What we already proved without a receive

- Probe UFVK imports and **catches up** on `zec.rocks` (tip height recorded in `SESSION_HANDOFF.md`).
- Empty ledger on the probe key only means **no funds were ever sent to it**, not that sync is broken.
