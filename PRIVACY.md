# SaneBooks Privacy

SaneBooks is built for on-device books and selective disclosure.

## What stays on your Mac

- Viewing keys (Keychain, this device only — planned production path)
- Ledger classifications and vault metadata (Application Support; excluded from Time Machine backup when FileLedgerStore is used)
- Share history of packs you create (local)

## What leaves your Mac

- **Only when you export:** a `.sanebooks` proof pack or CSV you save/share. Packs do not include viewing keys.
- **Optional sync:** compact-block traffic to a lightwalletd endpoint you configure. Completeness assumes an honest server; packs carry that disclaimer.

## What we do not do

- No iCloud / CloudKit for vault or pack data
- No telemetry / analytics SDK in v1 design
- No acceptance of seeds or spending keys

## Reader mode

Opening a proof pack decrypts rows in memory for display/export. It does not write decrypted rows into an owner vault.

Contact: hi@saneapps.com
