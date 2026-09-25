//! Viewing-key check. Accepts a ZIP 316 unified full viewing key or incoming viewing key.
//! Recovery words and spending keys are refused. This crate cannot spend.

use sha2::{Digest, Sha256};
use unicode_normalization::UnicodeNormalization;
use zcash_keys::keys::{UnifiedFullViewingKey, UnifiedIncomingViewingKey};
use zcash_protocol::consensus::Network;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum KeyKind {
    Ufvk,
    Uivk,
}

impl KeyKind {
    pub fn as_str(self) -> &'static str {
        match self {
            KeyKind::Ufvk => "ufvk",
            KeyKind::Uivk => "uivk",
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum BooksNetwork {
    Mainnet,
    Testnet,
}

impl BooksNetwork {
    pub fn as_str(self) -> &'static str {
        match self {
            BooksNetwork::Mainnet => "mainnet",
            BooksNetwork::Testnet => "testnet",
        }
    }

    pub fn parse(text: &str) -> Result<Self, KeyError> {
        match text {
            "mainnet" => Ok(BooksNetwork::Mainnet),
            "testnet" => Ok(BooksNetwork::Testnet),
            _ => Err(KeyError::Rejected),
        }
    }

    fn consensus(self) -> Network {
        match self {
            BooksNetwork::Mainnet => Network::MainNetwork,
            BooksNetwork::Testnet => Network::TestNetwork,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum VaultMode {
    Bookkeeper,
    Receivables,
}

impl VaultMode {
    pub fn as_str(self) -> &'static str {
        match self {
            VaultMode::Bookkeeper => "bookkeeper",
            VaultMode::Receivables => "receivables",
        }
    }
}

#[derive(Debug)]
pub enum KeyError {
    Empty,
    Seed,
    SpendingKey,
    Rejected,
}

impl std::fmt::Display for KeyError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(match self {
            KeyError::Empty => "Paste a viewing key.",
            KeyError::Seed => "Recovery words are refused. ZecBooks cannot spend.",
            KeyError::SpendingKey => "Spending keys are refused. ZecBooks cannot spend.",
            KeyError::Rejected => {
                "Not a unified full viewing key or incoming viewing key."
            }
        })
    }
}

impl std::error::Error for KeyError {}

/// A checked viewing key. Debug output does not include the key text.
pub struct CheckedKey {
    encoded: String,
    pub kind: KeyKind,
    pub network: BooksNetwork,
    pub fingerprint: String,
    pub hrp: String,
    pub mode: VaultMode,
    pub has_sapling: bool,
    pub has_orchard: bool,
}

impl std::fmt::Debug for CheckedKey {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("CheckedKey")
            .field("kind", &self.kind)
            .field("network", &self.network)
            .field("fingerprint", &self.fingerprint)
            .finish()
    }
}

impl CheckedKey {
    pub fn encoded(&self) -> &str {
        &self.encoded
    }
}

pub fn inspect(raw: &str) -> Result<CheckedKey, KeyError> {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return Err(KeyError::Empty);
    }
    if looks_like_seed(trimmed) {
        return Err(KeyError::Seed);
    }
    let lower = trimmed.to_lowercase();
    if looks_like_spending_key(&lower) {
        return Err(KeyError::SpendingKey);
    }

    if let Some(key) = try_ufvk(&lower) {
        return Ok(key);
    }
    if let Some(key) = try_uivk(&lower) {
        return Ok(key);
    }
    Err(KeyError::Rejected)
}

fn try_ufvk(lower: &str) -> Option<CheckedKey> {
    for network in [BooksNetwork::Mainnet, BooksNetwork::Testnet] {
        let params = network.consensus();
        if let Ok(ufvk) = UnifiedFullViewingKey::decode(&params, lower) {
            let has_sapling = ufvk.sapling().is_some();
            let has_orchard = ufvk.orchard().is_some();
            return Some(checked(lower, KeyKind::Ufvk, network, has_sapling, has_orchard));
        }
    }
    None
}

fn try_uivk(lower: &str) -> Option<CheckedKey> {
    for network in [BooksNetwork::Mainnet, BooksNetwork::Testnet] {
        let params = network.consensus();
        if let Ok(uivk) = UnifiedIncomingViewingKey::decode(&params, lower) {
            let has_sapling = uivk.has_sapling();
            let has_orchard = uivk.has_orchard();
            return Some(checked(lower, KeyKind::Uivk, network, has_sapling, has_orchard));
        }
    }
    None
}

fn checked(
    lower: &str,
    kind: KeyKind,
    network: BooksNetwork,
    has_sapling: bool,
    has_orchard: bool,
) -> CheckedKey {
    let hrp = hrp_of(lower).unwrap_or("view");
    CheckedKey {
        encoded: lower.to_string(),
        kind,
        network,
        fingerprint: fingerprint(lower, hrp),
        hrp: hrp.to_string(),
        mode: match kind {
            KeyKind::Ufvk => VaultMode::Bookkeeper,
            KeyKind::Uivk => VaultMode::Receivables,
        },
        has_sapling,
        has_orchard,
    }
}

pub fn fingerprint(normalized_key: &str, hrp: &str) -> String {
    let digest = Sha256::digest(normalized_key.as_bytes());
    let prefix: String = digest
        .iter()
        .take(8)
        .map(|byte| format!("{byte:02x}"))
        .collect();
    format!("{hrp}:{prefix}")
}

fn hrp_of(lower: &str) -> Option<&str> {
    let idx = lower.rfind('1')?;
    if idx == 0 || idx + 1 >= lower.len() {
        return None;
    }
    Some(&lower[..idx])
}

fn looks_like_seed(input: &str) -> bool {
    let words: Vec<&str> = input.split_whitespace().collect();
    if ![12, 15, 18, 21, 24].contains(&words.len()) {
        return false;
    }
    words.iter().all(|word| {
        let count = word.chars().count();
        (3..=8).contains(&count) && word.chars().all(|ch| ch.is_ascii_alphabetic())
    })
}

fn looks_like_spending_key(lower: &str) -> bool {
    lower.contains("secret-extended-key")
        || lower.contains("secret-sharing-key")
        || lower.contains("secret-spending-key")
        || lower.starts_with("zsk")
}

pub fn nfkc(text: &str) -> String {
    text.nfkc().collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use zcash_keys::keys::UnifiedSpendingKey;
    use zip32::AccountId;

    const DEMO_FIXTURE: &str = "uview1qqqsyqcyq5rqwzqfpg9scrgwpugpzysnzs23v9ccrydpk8qarc0jqgfzyvjz2f389q5j52ev95hz7vp3xgengdfkxuurjw3m8s7nu06qg9pyx3z99c744z";

    #[test]
    fn refuses_recovery_words() {
        let phrase = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";
        assert!(matches!(inspect(phrase), Err(KeyError::Seed)));
    }

    #[test]
    fn refuses_spending_key_text() {
        let text = "secret-extended-key-main1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq";
        assert!(matches!(inspect(text), Err(KeyError::SpendingKey)));
    }

    #[test]
    fn fake_demo_fixture_is_not_a_real_viewing_key() {
        assert!(matches!(inspect(DEMO_FIXTURE), Err(KeyError::Rejected)));
    }

    #[test]
    fn accepts_testnet_viewing_key_derived_in_test() {
        let params = Network::TestNetwork;
        let seed = [0x11u8; 32];
        let account = AccountId::try_from(0).expect("account");
        let spending = UnifiedSpendingKey::from_seed(&params, &seed, account).expect("test key");
        let viewing = spending.to_unified_full_viewing_key();
        let encoded = viewing.encode(&params);
        let checked = inspect(&encoded).expect("ufvk");
        assert_eq!(checked.kind, KeyKind::Ufvk);
        assert_eq!(checked.network, BooksNetwork::Testnet);
        assert_eq!(checked.mode, VaultMode::Bookkeeper);
        assert!(!checked.fingerprint.contains("secret"));
        assert_ne!(checked.fingerprint, encoded);
        let incoming = viewing.to_unified_incoming_viewing_key();
        let incoming_text = incoming.encode(&params);
        let incoming_checked = inspect(&incoming_text).expect("uivk");
        assert_eq!(incoming_checked.kind, KeyKind::Uivk);
        assert_eq!(incoming_checked.mode, VaultMode::Receivables);
    }
}
