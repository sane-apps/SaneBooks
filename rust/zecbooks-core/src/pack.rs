//! Proof pack v2. Same container as the Mac app: `SANEBOOK`, schema 2,
//! PBKDF2-HMAC-SHA256 (600,000), ChaCha20-Poly1305. No viewing key inside.

use crate::canonical::{format_unix, insert_some, parse_unix, sha256_hex, zatoshis_number, Json};
use crate::keys::VaultMode;
use crate::ledger::{row_time_unix, ClassKind, Ledger, LedgerRow};
use base64::engine::general_purpose::STANDARD;
use base64::Engine;
use chacha20poly1305::aead::{Aead, KeyInit, Payload};
use chacha20poly1305::{ChaCha20Poly1305, Nonce};
use pbkdf2::pbkdf2_hmac;
use sha2::Sha256;
use std::collections::BTreeMap;
use uuid::Uuid;

pub const MAGIC: &[u8] = b"SANEBOOK";
pub const SCHEMA_VERSION: u16 = 2;
pub const KDF_NAME: &str = "pbkdf2-hmac-sha256";
pub const KDF_ITERATIONS: u32 = 600_000;
pub const AEAD_NAME: &str = "chacha20poly1305";
pub const DISCLAIMER: &str =
    "Completeness assumes an honest lightwalletd; omitted compact blocks understate income.";

const MIN_PASSPHRASE_CHARS: usize = 12;
const MAX_PASSPHRASE_BYTES: usize = 1024;
const SALT_LEN: usize = 16;
const NONCE_LEN: usize = 12;
const KEY_LEN: usize = 32;

const ROW_NAMESPACE: Uuid = Uuid::from_bytes([
    0x5a, 0x45, 0x43, 0x42, 0x4f, 0x4f, 0x4b, 0x53, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
]);

#[derive(Debug)]
pub struct PackError(pub String);

impl std::fmt::Display for PackError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&self.0)
    }
}

impl std::error::Error for PackError {}

pub struct SealOptions<'a> {
    pub ledger: &'a Ledger,
    pub from_unix: i64,
    pub to_unix: i64,
    pub expire_unix: i64,
    pub created_unix: i64,
    pub passphrase: &'a str,
    pub recipient: Option<&'a str>,
    pub include_change: bool,
    pub include_memos: bool,
    pub allow_untagged: bool,
    pub acknowledge_partial: bool,
}

pub fn seal(options: SealOptions<'_>) -> Result<Vec<u8>, PackError> {
    if options.ledger.partial_history && !options.acknowledge_partial {
        return Err(PackError(
            "Partial history not acknowledged. Sync is incomplete or history may be missing — acknowledge before sealing.".into(),
        ));
    }
    let rows = selected_rows(options.ledger, options.from_unix, options.to_unix, options.include_change);
    if !options.allow_untagged && rows.iter().any(|row| row.classification.kind == "untagged") {
        return Err(PackError(
            "Classify every row in the date range before sealing, or pass --allow-untagged.".into(),
        ));
    }
    let payload = payload_json(
        options.ledger,
        &rows,
        options.from_unix,
        options.to_unix,
        options.expire_unix,
        options.created_unix,
        options.recipient,
        options.include_memos,
        "",
    )?;
    let mut salt = [0u8; SALT_LEN];
    let mut nonce = [0u8; NONCE_LEN];
    getrandom::getrandom(&mut salt).map_err(|_| PackError("Secure randomness is unavailable.".into()))?;
    getrandom::getrandom(&mut nonce).map_err(|_| PackError("Secure randomness is unavailable.".into()))?;
    seal_payload(payload, options.passphrase, &salt, &nonce)
}

pub fn open(bytes: &[u8], passphrase: &str, now_unix: i64) -> Result<Json, PackError> {
    let (header, header_bytes, combined) = decode_container(bytes)?;
    let salt = salt_from_header(&header)?;
    let key = derive_key(passphrase, &salt)?;
    let plaintext = decrypt(&key, &combined, &header_bytes)?;
    let value: serde_json::Value = serde_json::from_slice(&plaintext)
        .map_err(|_| PackError("Wrong passphrase or altered file.".into()))?;
    let parsed = json_from_serde(&value);
    let claimed = match &parsed {
        Json::Object(map) => match map.get("integrity").and_then(object_of).and_then(|box_| box_.get("plaintextCanonicalHash")) {
            Some(Json::String(hash)) => hash.clone(),
            _ => return Err(PackError("Invalid integrity value.".into())),
        },
        _ => return Err(PackError("Wrong passphrase or altered file.".into())),
    };
    let mut blanked = parsed.clone();
    if let Json::Object(ref mut blank_map) = blanked {
        if let Some(Json::Object(integrity)) = blank_map.get_mut("integrity") {
            integrity.insert("plaintextCanonicalHash".into(), Json::String(String::new()));
        }
    }
    let blank_bytes = blanked.encode().into_bytes();
    if sha256_hex(&blank_bytes) != claimed {
        return Err(PackError("Wrong passphrase or altered file.".into()));
    }
    let again = parsed.encode().into_bytes();
    if again != plaintext {
        return Err(PackError("Wrong passphrase or altered file.".into()));
    }
    let Json::Object(map) = &parsed else {
        return Err(PackError("Wrong passphrase or altered file.".into()));
    };
    let expires = required_string(map, "expiresAt")?;
    let expires_unix = parse_unix(&expires).map_err(|err| PackError(err))?;
    if now_unix > expires_unix {
        return Err(PackError("This proof pack has expired.".into()));
    }
    validate_semantics(map)?;
    let mut out = BTreeMap::new();
    out.insert("ok".into(), Json::Bool(true));
    out.insert("expired".into(), Json::Bool(false));
    if let Some(metadata) = map.get("metadata").cloned() {
        out.insert("metadata".into(), metadata);
    }
    if let Some(rows) = map.get("rows").cloned() {
        out.insert("rows".into(), rows);
    }
    if let Some(rollups) = map.get("rollups").cloned() {
        out.insert("rollups".into(), rollups);
    }
    if let Some(attestation) = map.get("attestation").cloned() {
        out.insert("attestation".into(), attestation);
    }
    out.insert("expiresAt".into(), Json::String(expires));
    Ok(Json::Object(out))
}

fn selected_rows(ledger: &Ledger, from: i64, to: i64, include_change: bool) -> Vec<LedgerRow> {
    ledger
        .rows
        .iter()
        .filter(|row| {
            let Some(time) = row_time_unix(row) else {
                return false;
            };
            if time < from || time > to {
                return false;
            }
            let kind = row.classification.kind.as_str();
            if kind == "excluded" || kind == "untagged" {
                return kind == "untagged";
            }
            if kind == "change" && !include_change {
                return false;
            }
            true
        })
        .cloned()
        .collect()
}

fn payload_json(
    ledger: &Ledger,
    rows: &[LedgerRow],
    from_unix: i64,
    to_unix: i64,
    expire_unix: i64,
    created_unix: i64,
    recipient: Option<&str>,
    include_memos: bool,
    integrity_hash: &str,
) -> Result<Json, PackError> {
    let pack_rows = rows
        .iter()
        .map(|row| row_json(row, include_memos))
        .collect::<Result<Vec<_>, _>>()?;
    let rollups = rollup_json(rows)?;
    let pools = pools_present(rows);
    let ironwood = ledger.ironwood_capable || pools.iter().any(|pool| pool == "ironwood");
    let mode = if ledger.vault_mode == "receivables" {
        VaultMode::Receivables
    } else {
        VaultMode::Bookkeeper
    };
    let mut metadata = BTreeMap::new();
    metadata.insert("createdAt".into(), Json::String(format_unix(created_unix).map_err(PackError)?));
    metadata.insert("ironwoodCapable".into(), Json::Bool(ironwood));
    metadata.insert("network".into(), Json::String(ledger.network.clone()));
    metadata.insert("partialHistory".into(), Json::Bool(ledger.partial_history));
    metadata.insert("rangeEnd".into(), Json::String(format_unix(to_unix).map_err(PackError)?));
    metadata.insert("rangeStart".into(), Json::String(format_unix(from_unix).map_err(PackError)?));
    insert_some(
        &mut metadata,
        "recipientLabel",
        recipient.map(|label| Json::String(label.to_string())),
    );
    metadata.insert("vaultDisplayName".into(), Json::String(ledger.display_name.clone()));
    metadata.insert("vaultFingerprint".into(), Json::String(ledger.key_fingerprint.clone()));
    metadata.insert("vaultMode".into(), Json::String(mode.as_str().into()));

    let mut attestation = BTreeMap::new();
    if let Some(tip) = ledger.chain_tip_height {
        attestation.insert("chainTipAtExport".into(), Json::Number(tip.to_string()));
    }
    attestation.insert("disclaimer".into(), Json::String(DISCLAIMER.into()));
    attestation.insert("exportedAt".into(), Json::String(format_unix(created_unix).map_err(PackError)?));
    attestation.insert("ironwoodCapable".into(), Json::Bool(ironwood));
    attestation.insert(
        "lwdEndpointFingerprint".into(),
        Json::String(if ledger.endpoint_host.is_empty() {
            "unknown".into()
        } else {
            ledger.endpoint_host.clone()
        }),
    );
    attestation.insert(
        "poolsPresent".into(),
        Json::Array(pools.into_iter().map(Json::String).collect()),
    );
    attestation.insert(
        "syncedToHeight".into(),
        Json::Number(ledger.synced_to_height.to_string()),
    );
    attestation.insert("vaultMode".into(), Json::String(mode.as_str().into()));

    let mut integrity = BTreeMap::new();
    integrity.insert("alg".into(), Json::String("sha256".into()));
    integrity.insert(
        "plaintextCanonicalHash".into(),
        Json::String(integrity_hash.into()),
    );

    let mut payload = BTreeMap::new();
    payload.insert("attestation".into(), Json::Object(attestation));
    payload.insert("expiresAt".into(), Json::String(format_unix(expire_unix).map_err(PackError)?));
    payload.insert("integrity".into(), Json::Object(integrity));
    payload.insert("metadata".into(), Json::Object(metadata));
    payload.insert("rollups".into(), rollups);
    payload.insert("rows".into(), Json::Array(pack_rows));
    payload.insert("schemaVersion".into(), Json::Number("2".into()));
    Ok(Json::Object(payload))
}

fn row_json(row: &LedgerRow, include_memos: bool) -> Result<Json, PackError> {
    let time = row_time_unix(row).ok_or_else(|| PackError("row is missing a time".into()))?;
    let id = Uuid::new_v5(&ROW_NAMESPACE, row.id.as_bytes())
        .hyphenated()
        .to_string()
        .to_ascii_uppercase();
    let mut map = BTreeMap::new();
    map.insert("amountZEC".into(), Json::Number(zatoshis_number(row.zatoshis.abs())));
    map.insert("date".into(), Json::String(format_unix(time).map_err(PackError)?));
    map.insert("id".into(), Json::String(id));
    map.insert("kind".into(), Json::String(row.classification.kind.clone()));
    if include_memos {
        insert_some(&mut map, "memoText", row.memo.clone().map(Json::String));
    }
    insert_some(&mut map, "party", row.classification.party.clone().map(Json::String));
    map.insert("pool".into(), Json::String(row.pool.clone()));
    insert_some(&mut map, "subtag", row.classification.subtag.clone().map(Json::String));
    map.insert("txidTruncated".into(), Json::String(truncate_txid(&row.txid)));
    Ok(Json::Object(map))
}

fn truncate_txid(txid: &str) -> String {
    if txid.chars().count() <= 16 {
        txid.to_string()
    } else {
        let head: String = txid.chars().take(8).collect();
        let tail: String = txid.chars().rev().take(8).collect::<String>().chars().rev().collect();
        format!("{head}{tail}")
    }
}

fn rollup_json(rows: &[LedgerRow]) -> Result<Json, PackError> {
    let mut income = 0i64;
    let mut expense = 0i64;
    let mut fee = 0i64;
    let mut by_category: BTreeMap<String, i64> = BTreeMap::new();
    for row in rows {
        let amount = row.zatoshis.abs();
        match row.classification.kind.as_str() {
            "income" => income += amount,
            "expense" => expense += amount,
            "fee" => fee += amount,
            _ => {}
        }
        if row.classification.kind == "income" || row.classification.kind == "expense" {
            let key = row
                .classification
                .subtag
                .clone()
                .or(row.classification.party.clone())
                .unwrap_or_else(|| {
                    ClassKind::parse(&row.classification.kind)
                        .map(ClassKind::display_name)
                        .unwrap_or("Income")
                        .to_string()
                });
            *by_category.entry(key).or_insert(0) += amount;
        }
    }
    let mut map = BTreeMap::new();
    map.insert(
        "byCategory".into(),
        Json::Object(
            by_category
                .into_iter()
                .map(|(key, zat)| (key, Json::Number(zatoshis_number(zat))))
                .collect(),
        ),
    );
    map.insert("expenseZEC".into(), Json::Number(zatoshis_number(expense)));
    map.insert("feeZEC".into(), Json::Number(zatoshis_number(fee)));
    map.insert("fiatCurrency".into(), Json::String("USD".into()));
    map.insert("incomeZEC".into(), Json::Number(zatoshis_number(income)));
    Ok(Json::Object(map))
}

fn pools_present(rows: &[LedgerRow]) -> Vec<String> {
    let mut pools: Vec<String> = rows.iter().map(|row| row.pool.clone()).collect();
    pools.sort();
    pools.dedup();
    pools
}

fn seal_payload(mut payload: Json, passphrase: &str, salt: &[u8], nonce_bytes: &[u8]) -> Result<Vec<u8>, PackError> {
    blank_hash(&mut payload);
    let blank = payload.encode().into_bytes();
    let hash = sha256_hex(&blank);
    set_hash(&mut payload, &hash);
    let plaintext = payload.encode().into_bytes();
    if plaintext.len() > 64 * 1024 * 1024 {
        return Err(PackError("Pack payload is too large.".into()));
    }
    let key = derive_key(passphrase, salt)?;
    let header = header_json(salt);
    let header_bytes = header.encode().into_bytes();
    let ciphertext = encrypt(&key, nonce_bytes, &plaintext, &header_bytes)?;
    encode_container(&header_bytes, &ciphertext)
}

fn blank_hash(payload: &mut Json) {
    set_hash(payload, "");
}

fn set_hash(payload: &mut Json, hash: &str) {
    if let Json::Object(map) = payload {
        if let Some(Json::Object(integrity)) = map.get_mut("integrity") {
            integrity.insert("plaintextCanonicalHash".into(), Json::String(hash.into()));
        }
    }
}

fn header_json(salt: &[u8]) -> Json {
    let mut map = BTreeMap::new();
    map.insert("aead".into(), Json::String(AEAD_NAME.into()));
    map.insert("kdf".into(), Json::String(KDF_NAME.into()));
    map.insert("kdfIterations".into(), Json::Number(KDF_ITERATIONS.to_string()));
    map.insert("salt".into(), Json::String(STANDARD.encode(salt)));
    map.insert("schemaVersion".into(), Json::Number(SCHEMA_VERSION.to_string()));
    Json::Object(map)
}

fn derive_key(passphrase: &str, salt: &[u8]) -> Result<[u8; KEY_LEN], PackError> {
    let normalized = crate::keys::nfkc(passphrase);
    if normalized.chars().count() < MIN_PASSPHRASE_CHARS {
        return Err(PackError("Passphrase must be at least 12 characters.".into()));
    }
    if normalized.len() > MAX_PASSPHRASE_BYTES {
        return Err(PackError("Passphrase is too long.".into()));
    }
    if salt.len() != SALT_LEN {
        return Err(PackError("Invalid password salt.".into()));
    }
    let mut key = [0u8; KEY_LEN];
    pbkdf2_hmac::<Sha256>(normalized.as_bytes(), salt, KDF_ITERATIONS, &mut key);
    Ok(key)
}

fn encrypt(key: &[u8; KEY_LEN], nonce_bytes: &[u8], plaintext: &[u8], aad: &[u8]) -> Result<Vec<u8>, PackError> {
    if nonce_bytes.len() != NONCE_LEN {
        return Err(PackError("Invalid encryption nonce.".into()));
    }
    let cipher = ChaCha20Poly1305::new_from_slice(key).map_err(|_| PackError("Invalid encryption key.".into()))?;
    let nonce = Nonce::from_slice(nonce_bytes);
    let sealed = cipher
        .encrypt(
            nonce,
            Payload {
                msg: plaintext,
                aad,
            },
        )
        .map_err(|_| PackError("Pack encryption failed.".into()))?;
    let mut combined = Vec::with_capacity(NONCE_LEN + sealed.len());
    combined.extend_from_slice(nonce_bytes);
    combined.extend_from_slice(&sealed);
    Ok(combined)
}

fn decrypt(key: &[u8; KEY_LEN], combined: &[u8], aad: &[u8]) -> Result<Vec<u8>, PackError> {
    if combined.len() < NONCE_LEN + 16 {
        return Err(PackError("Wrong passphrase or altered file.".into()));
    }
    let cipher = ChaCha20Poly1305::new_from_slice(key).map_err(|_| PackError("Wrong passphrase or altered file.".into()))?;
    let nonce = Nonce::from_slice(&combined[..NONCE_LEN]);
    cipher
        .decrypt(
            nonce,
            Payload {
                msg: &combined[NONCE_LEN..],
                aad,
            },
        )
        .map_err(|_| PackError("Wrong passphrase or altered file.".into()))
}

fn encode_container(header: &[u8], ciphertext: &[u8]) -> Result<Vec<u8>, PackError> {
    if header.is_empty() || header.len() > 4 * 1024 {
        return Err(PackError("Invalid pack header size.".into()));
    }
    let mut out = Vec::with_capacity(14 + header.len() + ciphertext.len());
    out.extend_from_slice(MAGIC);
    out.extend_from_slice(&SCHEMA_VERSION.to_be_bytes());
    out.extend_from_slice(&(header.len() as u32).to_be_bytes());
    out.extend_from_slice(header);
    out.extend_from_slice(ciphertext);
    if out.windows(8).any(|window| window == b"uview1qq") {
        return Err(PackError("UVK-like material leaked into pack bytes".into()));
    }
    Ok(out)
}

fn decode_container(data: &[u8]) -> Result<(Json, Vec<u8>, Vec<u8>), PackError> {
    if data.len() < 14 || &data[..8] != MAGIC {
        return Err(PackError("Invalid proof pack.".into()));
    }
    let version = u16::from_be_bytes([data[8], data[9]]);
    if version == 1 {
        return Err(PackError(
            "This proof pack uses retired format 1. Ask the sender to re-export it with the current ZecBooks.".into(),
        ));
    }
    if version != SCHEMA_VERSION {
        return Err(PackError(format!("Unsupported pack schema {version}.")));
    }
    let header_len = u32::from_be_bytes([data[10], data[11], data[12], data[13]]) as usize;
    if header_len == 0 || header_len > 4 * 1024 || 14 + header_len > data.len() {
        return Err(PackError("Invalid pack header size.".into()));
    }
    let header_bytes = data[14..14 + header_len].to_vec();
    let ciphertext = data[14 + header_len..].to_vec();
    if ciphertext.len() < NONCE_LEN + 16 {
        return Err(PackError("Invalid encrypted payload size.".into()));
    }
    let value: serde_json::Value = serde_json::from_slice(&header_bytes)
        .map_err(|_| PackError("Invalid proof pack.".into()))?;
    let header = json_from_serde(&value);
    if header.encode().into_bytes() != header_bytes {
        return Err(PackError("Pack header is not canonical.".into()));
    }
    validate_header(&header)?;
    Ok((header, header_bytes, ciphertext))
}

fn validate_header(header: &Json) -> Result<(), PackError> {
    let Json::Object(map) = header else {
        return Err(PackError("Invalid proof pack.".into()));
    };
    match map.get("kdf") {
        Some(Json::String(kdf)) if kdf == KDF_NAME => {}
        _ => return Err(PackError("Unsupported pack encryption parameters.".into())),
    }
    match map.get("aead") {
        Some(Json::String(aead)) if aead == AEAD_NAME => {}
        _ => return Err(PackError("Unsupported pack encryption parameters.".into())),
    }
    match map.get("kdfIterations") {
        Some(Json::Number(n)) if n == "600000" => {}
        _ => return Err(PackError("Unsupported pack encryption parameters.".into())),
    }
    match map.get("schemaVersion") {
        Some(Json::Number(n)) if n == "2" => {}
        _ => return Err(PackError("Unsupported pack schema.".into())),
    }
    Ok(())
}

fn salt_from_header(header: &Json) -> Result<Vec<u8>, PackError> {
    let Json::Object(map) = header else {
        return Err(PackError("Invalid password salt.".into()));
    };
    let Some(Json::String(salt)) = map.get("salt") else {
        return Err(PackError("Invalid password salt.".into()));
    };
    let bytes = STANDARD.decode(salt).map_err(|_| PackError("Invalid password salt.".into()))?;
    if bytes.len() != SALT_LEN || STANDARD.encode(&bytes) != *salt {
        return Err(PackError("Invalid password salt.".into()));
    }
    Ok(bytes)
}

fn validate_semantics(map: &BTreeMap<String, Json>) -> Result<(), PackError> {
    let metadata = object_of(map.get("metadata").ok_or_else(|| PackError("Pack metadata is inconsistent.".into()))?)
        .ok_or_else(|| PackError("Pack metadata is inconsistent.".into()))?;
    let attestation = object_of(map.get("attestation").ok_or_else(|| PackError("Pack metadata is inconsistent.".into()))?)
        .ok_or_else(|| PackError("Pack metadata is inconsistent.".into()))?;
    let rollups = object_of(map.get("rollups").ok_or_else(|| PackError("Pack accounting totals are inconsistent.".into()))?)
        .ok_or_else(|| PackError("Pack accounting totals are inconsistent.".into()))?;
    let rows = match map.get("rows") {
        Some(Json::Array(rows)) => rows,
        _ => return Err(PackError("Pack accounting totals are inconsistent.".into())),
    };
    let start = parse_unix(&required_string(metadata, "rangeStart")?).map_err(PackError)?;
    let end = parse_unix(&required_string(metadata, "rangeEnd")?).map_err(PackError)?;
    if start > end {
        return Err(PackError("Pack date range is inconsistent.".into()));
    }
    let mut seen_pools = BTreeMap::<String, ()>::new();
    for row in rows {
        let row = object_of(row).ok_or_else(|| PackError("Pack contains an invalid row.".into()))?;
        let date = parse_unix(&required_string(row, "date")?).map_err(PackError)?;
        if date < start || date > end {
            return Err(PackError("Pack contains a row outside its declared date range.".into()));
        }
        let pool = required_string(row, "pool")?;
        seen_pools.insert(pool, ());
    }
    let listed = match attestation.get("poolsPresent") {
        Some(Json::Array(items)) => items,
        _ => return Err(PackError("Pack pool attestation is inconsistent.".into())),
    };
    if listed.len() != seen_pools.len() {
        return Err(PackError("Pack pool attestation is inconsistent.".into()));
    }
    for item in listed {
        let Json::String(pool) = item else {
            return Err(PackError("Pack pool attestation is inconsistent.".into()));
        };
        if !seen_pools.contains_key(pool) {
            return Err(PackError("Pack pool attestation is inconsistent.".into()));
        }
    }
    let ironwood = match attestation.get("ironwoodCapable") {
        Some(Json::Bool(value)) => *value,
        _ => return Err(PackError("Pack Ironwood attestation is inconsistent.".into())),
    };
    if seen_pools.contains_key("ironwood") && !ironwood {
        return Err(PackError("Pack Ironwood attestation is inconsistent.".into()));
    }
    if metadata.get("vaultMode") != attestation.get("vaultMode")
        || metadata.get("ironwoodCapable") != attestation.get("ironwoodCapable")
    {
        return Err(PackError("Pack metadata is inconsistent.".into()));
    }
    if let Some(Json::Number(tip)) = attestation.get("chainTipAtExport") {
        if let Some(Json::Number(synced)) = attestation.get("syncedToHeight") {
            if synced.parse::<u64>().unwrap_or(0) > tip.parse::<u64>().unwrap_or(0) {
                return Err(PackError("Pack sync heights are inconsistent.".into()));
            }
        }
    }
    let _ = rollups;
    Ok(())
}

fn object_of(value: &Json) -> Option<&BTreeMap<String, Json>> {
    match value {
        Json::Object(map) => Some(map),
        _ => None,
    }
}

fn required_string(map: &BTreeMap<String, Json>, key: &str) -> Result<String, PackError> {
    match map.get(key) {
        Some(Json::String(value)) => Ok(value.clone()),
        _ => Err(PackError(format!("Pack is missing {key}."))),
    }
}

fn json_from_serde(value: &serde_json::Value) -> Json {
    match value {
        serde_json::Value::Null => Json::String(String::new()),
        serde_json::Value::Bool(v) => Json::Bool(*v),
        serde_json::Value::Number(n) => Json::Number(n.to_string()),
        serde_json::Value::String(s) => Json::String(s.clone()),
        serde_json::Value::Array(items) => Json::Array(items.iter().map(json_from_serde).collect()),
        serde_json::Value::Object(map) => {
            let mut out = BTreeMap::new();
            for (key, value) in map {
                if !value.is_null() {
                    out.insert(key.clone(), json_from_serde(value));
                }
            }
            Json::Object(out)
        }
    }
}

/// Fixed vector shared with the Swift `PackWriter` golden file.
pub fn swift_golden_pack() -> Result<Vec<u8>, PackError> {
    let payload = swift_golden_payload()?;
    let salt = [0x42u8; 16];
    let nonce = [0x11u8; 12];
    seal_payload(payload, "correct horse battery", &salt, &nonce)
}

fn swift_golden_payload() -> Result<Json, PackError> {
    let row_date = parse_unix("2025-06-15T12:00:00Z").map_err(PackError)?;
    let start = parse_unix("2025-01-01T00:00:00Z").map_err(PackError)?;
    let end = parse_unix("2025-12-31T23:59:59Z").map_err(PackError)?;
    let created = parse_unix("2026-01-15T00:00:00Z").map_err(PackError)?;
    let expires = parse_unix("2026-04-15T23:59:59Z").map_err(PackError)?;
    let row = Json::object([
        ("amountZEC".into(), Json::Number("1.5".into())),
        ("date".into(), Json::String(format_unix(row_date).map_err(PackError)?)),
        (
            "id".into(),
            Json::String("00112233-4455-6677-8899-AABBCCDDEEFF".into()),
        ),
        ("kind".into(), Json::String("income".into())),
        ("memoText".into(), Json::String("Invoice".into())),
        ("party".into(), Json::String("Client".into())),
        ("pool".into(), Json::String("ironwood".into())),
        ("txidTruncated".into(), Json::String("aabbccdd11223344".into())),
    ]);
    let rollups = Json::object([
        (
            "byCategory".into(),
            Json::object([("Client".into(), Json::Number("1.5".into()))]),
        ),
        ("expenseZEC".into(), Json::Number("0".into())),
        ("feeZEC".into(), Json::Number("0".into())),
        ("fiatCurrency".into(), Json::String("USD".into())),
        ("incomeZEC".into(), Json::Number("1.5".into())),
    ]);
    let metadata = Json::object([
        ("createdAt".into(), Json::String(format_unix(created).map_err(PackError)?)),
        ("ironwoodCapable".into(), Json::Bool(true)),
        ("network".into(), Json::String("mainnet".into())),
        ("partialHistory".into(), Json::Bool(false)),
        ("rangeEnd".into(), Json::String(format_unix(end).map_err(PackError)?)),
        ("rangeStart".into(), Json::String(format_unix(start).map_err(PackError)?)),
        ("vaultDisplayName".into(), Json::String("Treasury".into())),
        ("vaultFingerprint".into(), Json::String("uview:a1b2c3d4e5f60708".into())),
        ("vaultMode".into(), Json::String("bookkeeper".into())),
    ]);
    let attestation = Json::object([
        ("chainTipAtExport".into(), Json::Number("3500000".into())),
        ("disclaimer".into(), Json::String(DISCLAIMER.into())),
        ("exportedAt".into(), Json::String(format_unix(created).map_err(PackError)?)),
        ("ironwoodCapable".into(), Json::Bool(true)),
        ("lwdEndpointFingerprint".into(), Json::String("lwd.example".into())),
        ("poolsPresent".into(), Json::Array(vec![Json::String("ironwood".into())])),
        ("syncedToHeight".into(), Json::Number("3500000".into())),
        ("vaultMode".into(), Json::String("bookkeeper".into())),
    ]);
    let integrity = Json::object([
        ("alg".into(), Json::String("sha256".into())),
        ("plaintextCanonicalHash".into(), Json::String(String::new())),
    ]);
    Ok(Json::object([
        ("attestation".into(), attestation),
        ("expiresAt".into(), Json::String(format_unix(expires).map_err(PackError)?)),
        ("integrity".into(), integrity),
        ("metadata".into(), metadata),
        ("rollups".into(), rollups),
        ("rows".into(), Json::Array(vec![row])),
        ("schemaVersion".into(), Json::Number("2".into())),
    ]))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pbkdf2_matches_swift_vector() {
        let salt = [0x42u8; 16];
        let key = derive_key("correct horse battery", &salt).unwrap();
        assert_eq!(
            hex::encode(key),
            "73a5b138dc2cd4bc632bd28ecc67dc407ba4616e2c2bcb624af2aa9eb25f29d2"
        );
    }

    #[test]
    fn refuses_short_passphrase() {
        let err = derive_key("too short", &[0x42u8; 16]).unwrap_err();
        assert!(err.0.contains("12"));
    }

    #[test]
    fn swift_golden_bytes_match() {
        let expected = include_bytes!("../../testdata/swift-golden.sanebooks");
        let got = swift_golden_pack().expect("seal");
        assert_eq!(got, expected);
    }

    #[test]
    fn swift_golden_opens() {
        let packed = swift_golden_pack().unwrap();
        let now = parse_unix("2026-01-15T00:00:00Z").unwrap();
        let opened = open(&packed, "correct horse battery", now).unwrap();
        let text = opened.encode();
        assert!(text.contains("Treasury"));
        assert!(text.contains("Invoice"));
        assert!(open(&packed, "wrong passphrase!!", now).is_err());
        let later = parse_unix("2026-04-16T00:00:00Z").unwrap();
        let expired = open(&packed, "correct horse battery", later).unwrap_err();
        assert!(expired.0.contains("expired"));
    }

    #[test]
    fn partial_history_requires_acknowledgement() {
        let mut ledger = crate::ledger::Ledger {
            schema_version: 1,
            network: "mainnet".into(),
            key_fingerprint: "uview:abc".into(),
            key_kind: "ufvk".into(),
            vault_mode: "bookkeeper".into(),
            display_name: "Books".into(),
            endpoint: String::new(),
            endpoint_host: "lwd.example".into(),
            scanned_from_height: 1,
            synced_to_height: 1,
            chain_tip_height: Some(2),
            partial_history: true,
            ironwood_capable: true,
            unlinked_spends: 0,
            rows: vec![],
        };
        let err = seal(SealOptions {
            ledger: &ledger,
            from_unix: 0,
            to_unix: 10,
            expire_unix: 20,
            created_unix: 10,
            passphrase: "correct horse battery",
            recipient: None,
            include_change: true,
            include_memos: false,
            allow_untagged: true,
            acknowledge_partial: false,
        })
        .unwrap_err();
        assert!(err.0.contains("Partial history"));
        ledger.partial_history = false;
    }
}
