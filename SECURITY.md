# SaneBooks Security

## Threat model (short)

| Risk | Mitigation |
|------|------------|
| Phishing for seeds | Native app; hard-reject seeds/spend keys |
| Malicious lightwalletd | Self-reported sync metadata + incompleteness honesty; configurable HTTPS endpoint. No independent attestation, Tor, or pinning claim |
| Accountant overshare | Live disclosure inventory; scoped pack instead of a raw key; explicit plaintext warnings |
| Backup/sync leak | No iCloud for vault; Keychain ThisDeviceOnly for the imported key; backup-excluded owner-only ledger and SDK data trees |
| Tampered pack | Canonical header as AEAD associated data plus ChaCha20-Poly1305 authentication |
| False accounting metadata | Reader recomputes rollups, categories, row date membership, pool list, and sync-height invariants |
| Offline passphrase guessing | PBKDF2-HMAC-SHA256, 600,000 iterations, minimum 12 characters, confirmation in export UI |
| Hostile files/databases | Strict byte/row/string bounds, alignment-safe parsing, read transactions, explicit unsupported-schema errors |
| Local data loss | Owner-only atomic ledger writes, fail-closed corruption handling, Keychain update-first ordering, UI-confirmed vault removal |
| Test controls in production | E2E launch routing and ephemeral-state switches are Debug-only; Release ignores test environment/arguments |

## Crypto

- Pack format: v2; v1 is intentionally rejected because its KDF and public metadata design are retired
- Pack KDF: PBKDF2-HMAC-SHA256, 600,000 iterations, random salt
- Pack AEAD: ChaCha20-Poly1305
- Minimal public header is authenticated as AAD; vault/recipient/range/network/completeness metadata is encrypted
- A shared-passphrase pack proves byte integrity and internal accounting consistency, not sender identity, non-repudiation, or independent chain completeness
- Expiry is enforced after authentication/decrypt; the error remains “wrong passphrase or altered file” to avoid an oracle
- CSV neutralizes spreadsheet-formula prefixes; CSV and PDF remain plaintext and non-expiring by design

## App hardening

| Build | Sandbox | Hardened Runtime |
|-------|---------|------------------|
| Debug | OFF (dev ease) | OFF |
| Release | ON + network client + user-selected files | ON |

## Non-goals

SaneBooks never implements send/propose spend paths on shipping configs.

## Validation level and known limits

- This repository has adversarial unit coverage for pack round trips, tampering, semantic inconsistency, unknown pools, limits, RNG failure, CSV formula prefixes, PDF renderer failure, storage failure/permissions/budget rollback, Keychain double-failure behavior, hostile evidence text, and Zashi identity/merge behavior.
- Forced-mock and explicit no-keychain launches substitute an ephemeral viewing-key store, preventing repeated test-runner Keychain prompts and test access to production key material.
- Live sync necessarily imports viewing-account material into the official Zcash SDK database. The SDK tree is sensitive local state: SaneBooks makes the per-vault directory owner-only, excludes it from backup, rejects symbolic links during hardening, and purges it with the vault. This is not an encrypted-at-rest claim; FileVault and a locked macOS account remain part of the local-device boundary.
- The 2026-08-04 audit was a manual multi-perspective adversarial review. The automated Codex Deep Security Scan server was unavailable, so there is no independent or automated-deep-scan claim.
- The current strict secret scan reports zero findings, and the Debug evidence bundle contains `PrivacyInfo.xcprivacy` declaring no collected data or tracking plus the required UserDefaults reason. The sandboxed Release artifact and nested-dependency privacy manifests remain unproven.
- Current source resolves the review's ledger-budget denial of service, ambiguous/empty PDF success, proof-pack semantic inconsistency, future-pool mislabeling, ambient SaneUI selection, false Keychain rollback copy, unbounded/spoofable evidence text, and deterministic production-crypto API findings. The shared SaneProcess release entrypoint remains the high-severity open finding: it does not yet enforce `.saneprocess` `release.enabled: false`.
- PBKDF2 is a platform-compatible fallback, not memory-hard Argon2id. Strong multi-word passphrases remain important.
- Existing v1 packs must be re-exported; backward decryption would preserve a weaker security boundary.
- A current private Zashi database fixture is still required to prove compatibility with each real wallet schema/version. Never retain or publish the fixture, viewing key, memos, txids, or paths.
- HTTPS protects transport to lightwalletd, but there is no Tor routing or certificate pinning and the server can omit history. A funded Ironwood receipt and independent security review remain release gates.
