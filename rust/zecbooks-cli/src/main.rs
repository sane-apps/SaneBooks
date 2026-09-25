//! `zecbooks` command. View-only. Recovery words and spending keys are refused.

#![forbid(unsafe_code)]

use std::fs;
use std::io::{self, Read, Write};
use std::path::PathBuf;
use std::process::ExitCode;
use std::time::{SystemTime, UNIX_EPOCH};

use clap::{Parser, Subcommand};
use zecbooks_core::{
    inspect, open, parse_date, seal, BooksNetwork, ClassKind, Json, Ledger, SealOptions,
};
use zecbooks_sync::sync_viewing_key;

#[derive(Parser)]
#[command(
    name = "zecbooks",
    version,
    about = "View-only books for shielded Zcash. Cannot spend."
)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Accept a unified full viewing key or incoming viewing key.
    Check {
        #[arg(long)]
        key_file: Option<PathBuf>,
        #[arg(long)]
        key: Option<String>,
    },
    /// Scan shielded history from a lightwalletd you choose.
    Sync {
        #[arg(long)]
        key_file: Option<PathBuf>,
        #[arg(long)]
        key: Option<String>,
        #[arg(long)]
        endpoint: String,
        #[arg(long)]
        out: PathBuf,
        #[arg(long, default_value = "mainnet")]
        network: String,
        #[arg(long)]
        from_height: Option<u32>,
        #[arg(long, default_value = "Books")]
        name: String,
    },
    /// Set income, expense, change, fee, untagged, or excluded on one row.
    Classify {
        #[arg(long)]
        ledger: PathBuf,
        #[arg(long)]
        id: String,
        #[arg(long = "as")]
        kind: String,
        #[arg(long)]
        party: Option<String>,
        #[arg(long)]
        subtag: Option<String>,
        #[arg(long)]
        notes: Option<String>,
    },
    /// Seal an expiring proof pack. The viewing key is not included.
    Pack {
        #[arg(long)]
        ledger: PathBuf,
        #[arg(long)]
        from: String,
        #[arg(long)]
        to: String,
        #[arg(long)]
        expire: String,
        #[arg(long)]
        passphrase_file: PathBuf,
        #[arg(long)]
        out: PathBuf,
        #[arg(long)]
        recipient: Option<String>,
        #[arg(long)]
        include_memos: bool,
        #[arg(long)]
        allow_untagged: bool,
        #[arg(long)]
        acknowledge_partial: bool,
    },
    /// Open a proof pack. No key import.
    Open {
        #[arg(long)]
        pack: PathBuf,
        #[arg(long)]
        passphrase_file: PathBuf,
    },
}

fn main() -> ExitCode {
    let cli = Cli::parse();
    let runtime = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build();
    let result = match runtime {
        Ok(runtime) => runtime.block_on(run(cli)),
        Err(err) => Err(err.to_string()),
    };
    match result {
        Ok(json) => {
            println!("{}", json.encode());
            ExitCode::SUCCESS
        }
        Err(err) => {
            let mut map = std::collections::BTreeMap::new();
            map.insert("ok".into(), Json::Bool(false));
            map.insert("error".into(), Json::String(err));
            println!("{}", Json::Object(map).encode());
            ExitCode::from(1)
        }
    }
}

async fn run(cli: Cli) -> Result<Json, String> {
    match cli.command {
        Command::Check { key_file, key } => {
            let text = read_key(key_file, key)?;
            let checked = inspect(&text).map_err(|err| err.to_string())?;
            Ok(object([
                ("ok", Json::Bool(true)),
                ("kind", Json::String(checked.kind.as_str().into())),
                ("network", Json::String(checked.network.as_str().into())),
                ("mode", Json::String(checked.mode.as_str().into())),
                ("fingerprint", Json::String(checked.fingerprint)),
                ("hasSapling", Json::Bool(checked.has_sapling)),
                ("hasOrchard", Json::Bool(checked.has_orchard)),
            ]))
        }
        Command::Sync {
            key_file,
            key,
            endpoint,
            out,
            network,
            from_height,
            name,
        } => {
            let text = read_key(key_file, key)?;
            let checked = inspect(&text).map_err(|err| err.to_string())?;
            let wanted = BooksNetwork::parse(&network).map_err(|_| "network must be mainnet or testnet".to_string())?;
            if checked.network != wanted {
                return Err(format!(
                    "This key is {} and --network is {}.",
                    checked.network.as_str(),
                    wanted.as_str()
                ));
            }
            let mut ledger = if out.exists() {
                Ledger::load(&out)?
            } else {
                Ledger::empty(&checked, &name)
            };
            if ledger.key_fingerprint != checked.fingerprint {
                return Err("This ledger belongs to a different viewing key.".into());
            }
            let resume = from_height.or_else(|| {
                if ledger.synced_to_height > 0 {
                    Some(ledger.synced_to_height.saturating_add(1))
                } else {
                    None
                }
            });
            let update = sync_viewing_key(&checked, &endpoint, resume).await?;
            ledger.endpoint = endpoint;
            ledger.endpoint_host = update.endpoint_host;
            if ledger.scanned_from_height == 0 {
                ledger.scanned_from_height = update.from_height;
            }
            ledger.synced_to_height = update.synced_to_height;
            ledger.chain_tip_height = Some(update.chain_tip_height);
            ledger.partial_history = update.partial_history || checked.kind == zecbooks_core::KeyKind::Uivk;
            ledger.unlinked_spends = update.unlinked_spends;
            ledger.ironwood_capable = checked.has_orchard;
            ledger.merge_scan(update.rows);
            ledger.save(&out)?;
            let mut summary = match ledger.summary() {
                Json::Object(map) => map,
                other => return Ok(other),
            };
            summary.insert("out".into(), Json::String(out.display().to_string()));
            Ok(Json::Object(summary))
        }
        Command::Classify {
            ledger,
            id,
            kind,
            party,
            subtag,
            notes,
        } => {
            let kind = ClassKind::parse(&kind).ok_or_else(|| {
                "kind must be income, expense, change, fee, untagged, or excluded".to_string()
            })?;
            let mut books = Ledger::load(&ledger)?;
            books.classify(&id, kind, party, subtag, notes)?;
            books.save(&ledger)?;
            Ok(books.summary())
        }
        Command::Pack {
            ledger,
            from,
            to,
            expire,
            passphrase_file,
            out,
            recipient,
            include_memos,
            allow_untagged,
            acknowledge_partial,
        } => {
            let books = Ledger::load(&ledger)?;
            let passphrase = fs::read_to_string(&passphrase_file)
                .map_err(|err| format!("cannot read passphrase file: {err}"))?;
            let passphrase = passphrase.trim_end_matches(['\n', '\r']);
            let now = now_unix()?;
            let bytes = seal(SealOptions {
                ledger: &books,
                from_unix: parse_date(&from, false)?,
                to_unix: parse_date(&to, true)?,
                expire_unix: parse_date(&expire, true)?,
                created_unix: now,
                passphrase,
                recipient: recipient.as_deref(),
                include_change: true,
                include_memos,
                allow_untagged,
                acknowledge_partial,
            })
            .map_err(|err| err.to_string())?;
            if let Some(parent) = out.parent() {
                if !parent.as_os_str().is_empty() {
                    fs::create_dir_all(parent).map_err(|err| err.to_string())?;
                }
            }
            fs::write(&out, &bytes).map_err(|err| format!("cannot write pack: {err}"))?;
            Ok(object([
                ("ok", Json::Bool(true)),
                ("out", Json::String(out.display().to_string())),
                ("bytes", Json::Number(bytes.len().to_string())),
            ]))
        }
        Command::Open {
            pack,
            passphrase_file,
        } => {
            let passphrase = fs::read_to_string(&passphrase_file)
                .map_err(|err| format!("cannot read passphrase file: {err}"))?;
            let passphrase = passphrase.trim_end_matches(['\n', '\r']);
            let bytes = fs::read(&pack).map_err(|err| format!("cannot read pack: {err}"))?;
            open(&bytes, passphrase, now_unix()?).map_err(|err| err.to_string())
        }
    }
}

fn read_key(key_file: Option<PathBuf>, key: Option<String>) -> Result<String, String> {
    match (key_file, key) {
        (Some(path), None) => {
            let mut file = fs::File::open(&path).map_err(|err| format!("cannot read key file: {err}"))?;
            let mut text = String::new();
            file.read_to_string(&mut text)
                .map_err(|err| format!("cannot read key file: {err}"))?;
            Ok(text)
        }
        (None, Some(text)) => {
            let _ = writeln!(
                io::stderr(),
                "warning: --key is stored in shell history. Prefer --key-file."
            );
            Ok(text)
        }
        (Some(_), Some(_)) => Err("Pass --key-file or --key, not both.".into()),
        (None, None) => Err("Pass --key-file. ZecBooks will not prompt for a seed.".into()),
    }
}

fn now_unix() -> Result<i64, String> {
    let duration = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|_| "system clock is before 1970".to_string())?;
    i64::try_from(duration.as_secs()).map_err(|_| "system clock is out of range".to_string())
}

fn object<const N: usize>(entries: [(&str, Json); N]) -> Json {
    let mut map = std::collections::BTreeMap::new();
    for (key, value) in entries {
        map.insert(key.to_string(), value);
    }
    Json::Object(map)
}
