# SaneBooks Security

## Threat model (short)

| Risk | Mitigation |
|------|------------|
| Phishing for seeds | Native app; hard-reject seeds/spend keys |
| Malicious lightwalletd | Attestation + incompleteness honesty; configurable endpoint |
| Accountant overshare | Scoped pack > raw key; passphrase + expiry |
| Backup/sync leak | No iCloud for vault; Keychain ThisDeviceOnly |
| Tampered pack | AEAD + canonical hash verify |

## Crypto

- Pack KDF: HKDF-SHA256 (`sanebooks-pack-v1`)
- Pack AEAD: ChaCha20-Poly1305
- Expiry enforced after decrypt; wrong passphrase → auth fail

## App hardening

| Build | Sandbox | Hardened Runtime |
|-------|---------|------------------|
| Debug | OFF (dev ease) | OFF |
| Release | ON + network client + user-selected files | ON |

## Non-goals

SaneBooks never implements send/propose spend paths on shipping configs.
