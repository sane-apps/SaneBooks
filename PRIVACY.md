# SaneBooks Privacy

SaneBooks is built for on-device books and selective disclosure.

## What stays on your Mac

- The viewing key you import (Keychain, `WhenUnlockedThisDeviceOnly`)
- When live sync is enabled, the official Zcash SDK imports viewing-account material into its local `data.db`. SaneBooks keeps that SDK tree in backup-excluded, owner-only Application Support storage (`0700` directories / `0600` existing files). It cannot authorize spending, but it is sensitive and is removed with the vault.
- Forced-mock and explicit no-keychain test launches use ephemeral in-memory key storage and do not read or write the production Keychain.
- Ledger classifications and vault metadata (owner-only Application Support; excluded from Time Machine backup when FileLedgerStore is used)
- Share history of packs you create (local)

## What leaves your Mac

- **Only when you export:** a file you explicitly save/share. Encrypted `.sanebooks` packs do not include viewing keys and place private pack metadata inside ciphertext.
- `.sanebooks` authentication detects alteration and SaneBooks recomputes its internal accounting fields; it does not verify the sender's identity or independently prove that a lightwalletd returned complete history.
- **Plaintext boundary:** CSV and PDF are readable, copyable, editable, and non-expiring. SaneBooks warns before saving them; Reader-enforced expiry applies only to `.sanebooks`.
- **Optional sync:** compact-block traffic to a lightwalletd endpoint you configure. Completeness assumes an honest server; packs carry that disclaimer.

## What we do not do

- No iCloud / CloudKit for vault or pack data
- No telemetry / analytics SDK in v1 design
- No acceptance of seeds or spending keys

## Reader mode

Opening a proof pack decrypts rows in memory for display/export. It does not write decrypted rows into an owner vault. A Reader user can deliberately export plaintext CSV/PDF; those new files do not inherit encryption or expiry.

## Support boundary

Never attach viewing keys, seed phrases, spending keys, wallet databases, proof-pack passphrases, raw private memos, or full transaction history to a public issue. Use the private support route at hi@saneapps.com for sensitive context, and send only the minimum redacted information needed.

Contact: hi@saneapps.com
