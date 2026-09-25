//! Local ledger. The viewing key is not stored here.

use crate::canonical::{parse_unix, Json};
use crate::keys::{CheckedKey, KeyKind};
use serde::{Deserialize, Serialize};
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};

pub const SCHEMA_VERSION: u32 = 1;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct Ledger {
    pub schema_version: u32,
    pub network: String,
    pub key_fingerprint: String,
    pub key_kind: String,
    pub vault_mode: String,
    pub display_name: String,
    pub endpoint: String,
    pub endpoint_host: String,
    pub scanned_from_height: u32,
    pub synced_to_height: u32,
    pub chain_tip_height: Option<u32>,
    pub partial_history: bool,
    pub ironwood_capable: bool,
    pub unlinked_spends: u32,
    pub rows: Vec<LedgerRow>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct LedgerRow {
    pub id: String,
    pub txid: String,
    pub output_index: u32,
    pub pool: String,
    pub height: u32,
    pub time: Option<String>,
    pub direction: String,
    pub zatoshis: i64,
    pub memo: Option<String>,
    pub classification: Classification,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct Classification {
    pub kind: String,
    pub party: Option<String>,
    pub subtag: Option<String>,
    pub notes: Option<String>,
}

impl Classification {
    pub fn untagged() -> Self {
        Self {
            kind: "untagged".into(),
            party: None,
            subtag: None,
            notes: None,
        }
    }

    pub fn change() -> Self {
        Self {
            kind: "change".into(),
            party: None,
            subtag: None,
            notes: None,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ClassKind {
    Income,
    Expense,
    Change,
    Fee,
    Untagged,
    Excluded,
}

impl ClassKind {
    pub fn parse(text: &str) -> Option<Self> {
        Some(match text {
            "income" => Self::Income,
            "expense" => Self::Expense,
            "change" => Self::Change,
            "fee" => Self::Fee,
            "untagged" => Self::Untagged,
            "excluded" => Self::Excluded,
            _ => return None,
        })
    }

    pub fn as_str(self) -> &'static str {
        match self {
            Self::Income => "income",
            Self::Expense => "expense",
            Self::Change => "change",
            Self::Fee => "fee",
            Self::Untagged => "untagged",
            Self::Excluded => "excluded",
        }
    }

    pub fn display_name(self) -> &'static str {
        match self {
            Self::Income => "Income",
            Self::Expense => "Expense",
            Self::Change => "Change",
            Self::Fee => "Fee",
            Self::Untagged => "Untagged",
            Self::Excluded => "Excluded",
        }
    }
}

impl Ledger {
    pub fn empty(key: &CheckedKey, display_name: &str) -> Self {
        Self {
            schema_version: SCHEMA_VERSION,
            network: key.network.as_str().into(),
            key_fingerprint: key.fingerprint.clone(),
            key_kind: key.kind.as_str().into(),
            vault_mode: key.mode.as_str().into(),
            display_name: display_name.into(),
            endpoint: String::new(),
            endpoint_host: String::new(),
            scanned_from_height: 0,
            synced_to_height: 0,
            chain_tip_height: None,
            partial_history: key.kind == KeyKind::Uivk,
            ironwood_capable: key.has_orchard,
            unlinked_spends: 0,
            rows: Vec::new(),
        }
    }

    pub fn load(path: &Path) -> Result<Self, String> {
        let bytes = fs::read(path).map_err(|err| format!("cannot read ledger: {err}"))?;
        let ledger: Ledger =
            serde_json::from_slice(&bytes).map_err(|err| format!("invalid ledger: {err}"))?;
        if ledger.schema_version != SCHEMA_VERSION {
            return Err("unsupported ledger schema".into());
        }
        Ok(ledger)
    }

    pub fn save(&self, path: &Path) -> Result<(), String> {
        if let Some(parent) = path.parent() {
            if !parent.as_os_str().is_empty() {
                fs::create_dir_all(parent).map_err(|err| format!("cannot create ledger dir: {err}"))?;
                restrict_dir(parent);
            }
        }
        let text = serde_json::to_vec_pretty(self).map_err(|err| format!("ledger encode: {err}"))?;
        let tmp = temp_path(path);
        {
            let mut file = fs::File::create(&tmp).map_err(|err| format!("cannot write ledger: {err}"))?;
            file.write_all(&text)
                .map_err(|err| format!("cannot write ledger: {err}"))?;
            let _ = file.write_all(b"\n");
            restrict_file(&tmp);
        }
        fs::rename(&tmp, path).map_err(|err| format!("cannot replace ledger: {err}"))?;
        restrict_file(path);
        Ok(())
    }

    pub fn classify(
        &mut self,
        id: &str,
        kind: ClassKind,
        party: Option<String>,
        subtag: Option<String>,
        notes: Option<String>,
    ) -> Result<(), String> {
        let row = self
            .rows
            .iter_mut()
            .find(|row| row.id == id)
            .ok_or_else(|| format!("no row {id}"))?;
        row.classification.kind = kind.as_str().into();
        if party.is_some() {
            row.classification.party = party;
        }
        if subtag.is_some() {
            row.classification.subtag = subtag;
        }
        if notes.is_some() {
            row.classification.notes = notes;
        }
        Ok(())
    }

    pub fn merge_scan(&mut self, scanned: Vec<LedgerRow>) {
        for row in scanned {
            if let Some(existing) = self.rows.iter_mut().find(|old| old.id == row.id) {
                existing.txid = row.txid;
                existing.output_index = row.output_index;
                existing.pool = row.pool;
                existing.height = row.height;
                existing.time = row.time;
                existing.direction = row.direction;
                existing.zatoshis = row.zatoshis;
                if existing.classification.kind == "untagged" {
                    existing.classification = row.classification;
                }
                existing.memo = row.memo.or(existing.memo.take());
            } else {
                self.rows.push(row);
            }
        }
        self.rows.sort_by(|a, b| {
            a.height
                .cmp(&b.height)
                .then(a.txid.cmp(&b.txid))
                .then(a.pool.cmp(&b.pool))
                .then(a.output_index.cmp(&b.output_index))
        });
    }

    pub fn income_zatoshis(&self) -> i64 {
        self.rows
            .iter()
            .filter(|row| row.classification.kind == "income")
            .map(|row| row.zatoshis)
            .sum()
    }

    pub fn summary(&self) -> Json {
        let mut map = std::collections::BTreeMap::new();
        map.insert("ok".into(), Json::Bool(true));
        map.insert("fingerprint".into(), Json::String(self.key_fingerprint.clone()));
        map.insert("network".into(), Json::String(self.network.clone()));
        map.insert("mode".into(), Json::String(self.vault_mode.clone()));
        map.insert("rows".into(), Json::Number(self.rows.len().to_string()));
        let change_rows = self
            .rows
            .iter()
            .filter(|row| row.classification.kind == "change")
            .count();
        map.insert("changeRows".into(), Json::Number(change_rows.to_string()));
        map.insert(
            "incomeZatoshis".into(),
            Json::Number(self.income_zatoshis().to_string()),
        );
        map.insert(
            "partialHistory".into(),
            Json::Bool(self.partial_history),
        );
        map.insert(
            "syncedToHeight".into(),
            Json::Number(self.synced_to_height.to_string()),
        );
        Json::Object(map)
    }
}

pub fn row_id(txid: &str, pool: &str, output_index: u32) -> String {
    format!("{txid}:{pool}:{output_index}")
}

pub fn row_time_unix(row: &LedgerRow) -> Option<i64> {
    row.time.as_deref().and_then(|text| parse_unix(text).ok())
}

fn temp_path(path: &Path) -> PathBuf {
    let mut tmp = path.as_os_str().to_owned();
    tmp.push(".tmp");
    PathBuf::from(tmp)
}

fn restrict_file(path: &Path) {
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let _ = fs::set_permissions(path, fs::Permissions::from_mode(0o600));
    }
    let _ = path;
}

fn restrict_dir(path: &Path) {
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let _ = fs::set_permissions(path, fs::Permissions::from_mode(0o700));
    }
    let _ = path;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn change_is_not_income() {
        let mut ledger = sample();
        ledger.rows[0].classification.kind = "change".into();
        ledger.rows[0].zatoshis = 5;
        assert_eq!(ledger.income_zatoshis(), 0);
        ledger.classify("row", ClassKind::Income, None, None, None).unwrap();
        assert_eq!(ledger.income_zatoshis(), 5);
    }

    #[test]
    fn rescan_marks_untagged_change_without_clobbering_income() {
        let mut ledger = sample();
        let mut scanned = ledger.rows[0].clone();
        scanned.classification = Classification::change();
        scanned.direction = "change".into();
        ledger.merge_scan(vec![scanned]);
        assert_eq!(ledger.rows[0].classification.kind, "change");
        ledger.classify("row", ClassKind::Income, None, None, None).unwrap();
        let mut again = ledger.rows[0].clone();
        again.classification = Classification::change();
        ledger.merge_scan(vec![again]);
        assert_eq!(ledger.rows[0].classification.kind, "income");
    }

    fn sample() -> Ledger {
        Ledger {
            schema_version: 1,
            network: "mainnet".into(),
            key_fingerprint: "uview:abc".into(),
            key_kind: "ufvk".into(),
            vault_mode: "bookkeeper".into(),
            display_name: "Books".into(),
            endpoint: "https://lwd.example:9067".into(),
            endpoint_host: "lwd.example".into(),
            scanned_from_height: 1,
            synced_to_height: 2,
            chain_tip_height: Some(2),
            partial_history: false,
            ironwood_capable: true,
            unlinked_spends: 0,
            rows: vec![LedgerRow {
                id: "row".into(),
                txid: "aa".into(),
                output_index: 0,
                pool: "ironwood".into(),
                height: 1,
                time: Some("2025-06-15T12:00:00Z".into()),
                direction: "inbound".into(),
                zatoshis: 5,
                memo: None,
                classification: Classification::untagged(),
            }],
        }
    }
}
