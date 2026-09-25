//! View-only scan through `zcash_client_backend` 0.24.0.
//! Compact blocks are trial-decrypted with a viewing key. Nothing here builds a transaction.

#![forbid(unsafe_code)]

use std::collections::HashMap;
use std::time::Duration;

use orchard::note_encryption::{IronwoodDomain, OrchardDomain};
use sapling::note_encryption::SaplingDomain;
use sapling::zip32::IncomingViewingKey as SaplingIncoming;
use zcash_client_backend::proto::service::compact_tx_streamer_client::CompactTxStreamerClient;
use zcash_client_backend::proto::service::{BlockId, BlockRange, ChainSpec};
use zcash_client_backend::scanning::{
    scan_block, Nullifiers, ScanningKey, ScanningKeyOps, ScanningKeys,
};
use zcash_keys::keys::{UnifiedFullViewingKey, UnifiedIncomingViewingKey};
use zcash_protocol::consensus::{BlockHeight, Network, NetworkUpgrade, Parameters};
use zecbooks_core::{BooksNetwork, CheckedKey, KeyKind, LedgerRow};
use zip32::Scope;

const CHUNK: u32 = 100;
const REQUEST_TIMEOUT: Duration = Duration::from_secs(120);

#[derive(Clone, Debug)]
pub struct ScanUpdate {
    pub rows: Vec<LedgerRow>,
    pub from_height: u32,
    pub synced_to_height: u32,
    pub chain_tip_height: u32,
    pub partial_history: bool,
    pub unlinked_spends: u32,
    pub endpoint_host: String,
}

pub fn history_is_partial(kind: KeyKind, synced: u32, tip: u32, gaps: bool, _unlinked: u32) -> bool {
    kind == KeyKind::Uivk || synced < tip || gaps
}

fn install_tls() {
    // rustls 0.23 does not pick a crypto provider unless exactly one is installed.
    let _ = rustls::crypto::ring::default_provider().install_default();
}

pub async fn sync_viewing_key(
    key: &CheckedKey,
    endpoint: &str,
    from_height: Option<u32>,
) -> Result<ScanUpdate, String> {
    install_tls();
    if !endpoint.starts_with("https://") && !endpoint.starts_with("http://") {
        return Err("Pass --endpoint as an http or https URL for your lightwalletd.".into());
    }
    let network = consensus(key.network);
    let start_default = activation_height(&network, NetworkUpgrade::Sapling)?;
    let from_height = from_height.unwrap_or(start_default);
    let mut client = tokio::time::timeout(REQUEST_TIMEOUT, CompactTxStreamerClient::connect(endpoint.to_string()))
        .await
        .map_err(|_| "lightwalletd connection timed out".to_string())?
        .map_err(|err| format!("lightwalletd connection failed: {err}"))?;

    let tip = tip_height(&mut client).await?;
    if from_height > tip {
        return Err(format!("--from-height {from_height} is past the server tip {tip}"));
    }

    let keys = scanning_keys(key, &network)?;
    let mut rows = Vec::new();
    let mut nullifier_index: HashMap<String, usize> = HashMap::new();
    // Carry nullifiers so a later spend can mark change. A note on the change address is change even before that link exists.
    let mut tracked = Nullifiers::<u32>::empty();
    let mut unlinked = 0u32;
    let mut gaps = false;
    let mut height = from_height;
    while height <= tip {
        let end = height.saturating_add(CHUNK - 1).min(tip);
        let blocks = fetch_range(&mut client, height, end).await?;
        let expected = end - height + 1;
        if blocks.len() as u32 != expected {
            gaps = true;
        }
        for block in blocks {
            let scanned = scan_block::<_, u32, (u32, Scope)>(
                &network,
                block,
                &keys,
                &tracked,
                None,
            )
            .map_err(|err| format!("scan failed: {err}"))?;
            tracked.update_with(&scanned);
            let block_height = height_of(scanned.height());
            let block_time = u64::from(scanned.block_time());
            absorb_block(
                scanned.transactions(),
                block_height,
                block_time,
                &mut rows,
                &mut nullifier_index,
                &mut unlinked,
            );
        }
        eprintln!("synced {end} / {tip}");
        height = end.saturating_add(1);
    }

    Ok(ScanUpdate {
        rows,
        from_height,
        synced_to_height: tip,
        chain_tip_height: tip,
        partial_history: history_is_partial(key.kind, tip, tip, gaps, unlinked),
        unlinked_spends: unlinked,
        endpoint_host: host_of(endpoint),
    })
}

fn consensus(network: BooksNetwork) -> Network {
    match network {
        BooksNetwork::Mainnet => Network::MainNetwork,
        BooksNetwork::Testnet => Network::TestNetwork,
    }
}

fn activation_height(network: &Network, upgrade: NetworkUpgrade) -> Result<u32, String> {
    network
        .activation_height(upgrade)
        .map(height_of)
        .ok_or_else(|| format!("{upgrade} has no activation height on this network"))
}

fn height_of(height: BlockHeight) -> u32 {
    u32::from(height)
}

fn scanning_keys(
    key: &CheckedKey,
    network: &Network,
) -> Result<ScanningKeys<u32, (u32, Scope)>, String> {
    match key.kind {
        KeyKind::Ufvk => {
            let ufvk = UnifiedFullViewingKey::decode(network, key.encoded())
                .map_err(|_| "viewing key was rejected".to_string())?;
            Ok(ScanningKeys::from_account_ufvks([(0u32, ufvk)]))
        }
        KeyKind::Uivk => {
            let uivk = UnifiedIncomingViewingKey::decode(network, key.encoded())
                .map_err(|_| "viewing key was rejected".to_string())?;
            incoming_keys(&uivk)
        }
    }
}

type SaplingScan = HashMap<
    (u32, Scope),
    Box<dyn ScanningKeyOps<SaplingDomain, u32, sapling::Nullifier> + Send + Sync>,
>;
type OrchardScan = HashMap<
    (u32, Scope),
    Box<dyn ScanningKeyOps<OrchardDomain, u32, orchard::note::Nullifier> + Send + Sync>,
>;
type IronwoodScan = HashMap<
    (u32, Scope),
    Box<dyn ScanningKeyOps<IronwoodDomain, u32, orchard::note::Nullifier> + Send + Sync>,
>;

fn incoming_keys(
    uivk: &UnifiedIncomingViewingKey,
) -> Result<ScanningKeys<u32, (u32, Scope)>, String> {
    let mut sapling_keys = SaplingScan::new();
    let mut orchard_keys = OrchardScan::new();
    let mut ironwood_keys = IronwoodScan::new();
    if let Some(ivk) = uivk.sapling().as_ref() {
        let external = sapling_external(ivk);
        let key: Box<dyn ScanningKeyOps<SaplingDomain, u32, sapling::Nullifier> + Send + Sync> =
            Box::new(ScanningKey::new(
                external,
                Option::<sapling::NullifierDerivingKey>::None,
                0u32,
                Some(Scope::External),
            ));
        sapling_keys.insert((0u32, Scope::External), key);
    }
    if let Some(ivk) = uivk.orchard().clone() {
        let key: Box<dyn ScanningKeyOps<OrchardDomain, u32, orchard::note::Nullifier> + Send + Sync> =
            Box::new(ScanningKey::new(
                ivk.clone(),
                Option::<orchard::keys::FullViewingKey>::None,
                0u32,
                Some(Scope::External),
            ));
        orchard_keys.insert((0u32, Scope::External), key);
        let key: Box<
            dyn ScanningKeyOps<IronwoodDomain, u32, orchard::note::Nullifier> + Send + Sync,
        > = Box::new(ScanningKey::new(
            ivk,
            Option::<orchard::keys::FullViewingKey>::None,
            0u32,
            Some(Scope::External),
        ));
        ironwood_keys.insert((0u32, Scope::External), key);
    }
    Ok(ScanningKeys::new(sapling_keys, orchard_keys, ironwood_keys))
}

fn sapling_external(ivk: &SaplingIncoming) -> sapling::SaplingIvk {
    // ZIP 32 incoming viewing keys keep the external Sapling IVK in the last 32 bytes.
    // The diversifier key is not a scanning key.
    let bytes = ivk.to_bytes();
    let mut fr_bytes = [0u8; 32];
    fr_bytes.copy_from_slice(&bytes[32..]);
    let scalar = jubjub::Fr::from_bytes(&fr_bytes).unwrap();
    sapling::SaplingIvk(scalar)
}

async fn tip_height(
    client: &mut CompactTxStreamerClient<tonic::transport::Channel>,
) -> Result<u32, String> {
    let reply = tokio::time::timeout(REQUEST_TIMEOUT, client.get_latest_block(ChainSpec::default()))
        .await
        .map_err(|_| "lightwalletd tip request timed out".to_string())?
        .map_err(|err| format!("lightwalletd tip request failed: {err}"))?;
    u32::try_from(reply.get_ref().height).map_err(|_| "lightwalletd returned a tip that does not fit".into())
}

async fn fetch_range(
    client: &mut CompactTxStreamerClient<tonic::transport::Channel>,
    start: u32,
    end: u32,
) -> Result<Vec<zcash_client_backend::proto::compact_formats::CompactBlock>, String> {
    let range = BlockRange {
        start: Some(BlockId {
            height: u64::from(start),
            hash: Vec::new(),
        }),
        end: Some(BlockId {
            height: u64::from(end),
            hash: Vec::new(),
        }),
        pool_types: vec![],
    };
    let response = tokio::time::timeout(REQUEST_TIMEOUT, client.get_block_range(range))
        .await
        .map_err(|_| format!("lightwalletd block request timed out at {start}"))?
        .map_err(|err| format!("lightwalletd block request failed: {err}"))?;
    let mut stream = response.into_inner();
    let mut blocks = Vec::new();
    loop {
        let next = tokio::time::timeout(REQUEST_TIMEOUT, stream.message())
            .await
            .map_err(|_| format!("lightwalletd stream timed out at {start}"))?
            .map_err(|err| format!("lightwalletd stream failed: {err}"))?;
        match next {
            Some(block) => blocks.push(block),
            None => break,
        }
    }
    Ok(blocks)
}


fn note_is_change(spent_in_transaction: bool, scope: Option<Scope>) -> bool {
    // The change address is the internal scope. Trial decryption knows that
    // before this scan has linked the spend that funded the note.
    spent_in_transaction || scope == Some(Scope::Internal)
}

fn absorb_block(
    transactions: &[zcash_client_backend::wallet::WalletTx<u32>],
    height: u32,
    block_time: u64,
    rows: &mut Vec<LedgerRow>,
    nullifiers: &mut HashMap<String, usize>,
    unlinked: &mut u32,
) {
    let time = Some(unix_to_rfc3339(block_time));
    for tx in transactions {
        let txid = format!("{}", tx.txid());
        for output in tx.sapling_outputs() {
            push_output(
                rows,
                nullifiers,
                &txid,
                "sapling",
                output.index(),
                height,
                time.clone(),
                zatoshis_sapling(output.note()),
                note_is_change(output.is_change(), output.recipient_key_scope()),
                output.nf().map(nullifier_hex),
            );
        }
        for output in tx.orchard_outputs() {
            push_output(
                rows,
                nullifiers,
                &txid,
                "orchard",
                output.index(),
                height,
                time.clone(),
                zatoshis_orchard(&output.note().0),
                note_is_change(output.is_change(), output.recipient_key_scope()),
                output.nf().map(nullifier_hex),
            );
        }
        for output in tx.ironwood_outputs() {
            push_output(
                rows,
                nullifiers,
                &txid,
                "ironwood",
                output.index(),
                height,
                time.clone(),
                zatoshis_orchard(&output.note().0),
                note_is_change(output.is_change(), output.recipient_key_scope()),
                output.nf().map(nullifier_hex),
            );
        }
        for spend in tx.sapling_spends() {
            note_spend(rows, nullifiers, spend.nf(), unlinked);
        }
        for spend in tx.orchard_spends() {
            note_spend(rows, nullifiers, spend.nf(), unlinked);
        }
        for spend in tx.ironwood_spends() {
            note_spend(rows, nullifiers, spend.nf(), unlinked);
        }
    }
}

fn push_output(
    rows: &mut Vec<LedgerRow>,
    nullifiers: &mut HashMap<String, usize>,
    txid: &str,
    pool: &str,
    index: usize,
    height: u32,
    time: Option<String>,
    zatoshis: i64,
    is_change: bool,
    nullifier: Option<String>,
) {
    let output_index = u32::try_from(index).unwrap_or(0);
    let id = zecbooks_core::row_id(txid, pool, output_index);
    let row = LedgerRow {
        id: id.clone(),
        txid: txid.into(),
        output_index,
        pool: pool.into(),
        height,
        time,
        direction: if is_change { "change" } else { "inbound" }.into(),
        zatoshis,
        memo: None,
        classification: if is_change {
            zecbooks_core::Classification::change()
        } else {
            zecbooks_core::Classification::untagged()
        },
    };
    if let Some(nullifier) = nullifier {
        nullifiers.insert(nullifier, rows.len());
    }
    rows.push(row);
    let _ = id;
}

fn note_spend<Nf>(
    rows: &mut [LedgerRow],
    nullifiers: &HashMap<String, usize>,
    nullifier: &Nf,
    unlinked: &mut u32,
) where
    Nf: NullifierBytes,
{
    let key = nullifier.nullifier_hex();
    if nullifiers.contains_key(&key) {
        return;
    }
    let _ = rows;
    *unlinked += 1;
}

fn zatoshis_sapling(note: &sapling::Note) -> i64 {
    i64::try_from(note.value().inner()).unwrap_or(0)
}

fn zatoshis_orchard(note: &orchard::note::Note) -> i64 {
    i64::try_from(note.value().inner()).unwrap_or(0)
}

fn nullifier_hex<Nf: NullifierBytes>(nf: &Nf) -> String {
    nf.nullifier_hex()
}

trait NullifierBytes {
    fn nullifier_hex(&self) -> String;
}

impl NullifierBytes for sapling::Nullifier {
    fn nullifier_hex(&self) -> String {
        hex::encode(self.0)
    }
}

impl NullifierBytes for orchard::note::Nullifier {
    fn nullifier_hex(&self) -> String {
        hex::encode((*self).to_bytes())
    }
}

fn unix_to_rfc3339(seconds: u64) -> String {
    zecbooks_core::format_unix(i64::try_from(seconds).unwrap_or(0))
        .unwrap_or_else(|_| "1970-01-01T00:00:00Z".into())
}

pub fn host_of(endpoint: &str) -> String {
    let rest = endpoint.split("://").nth(1).unwrap_or(endpoint);
    let hostport = rest.split('/').next().unwrap_or(rest);
    hostport.split(':').next().unwrap_or(hostport).to_string()
}

#[cfg(test)]
mod tests {
    use super::*;


    #[test]
    fn change_address_is_change_before_the_spend_is_linked() {
        assert!(note_is_change(false, Some(Scope::Internal)));
        assert!(note_is_change(true, Some(Scope::External)));
        assert!(!note_is_change(false, Some(Scope::External)));
        assert!(!note_is_change(false, None));
    }


    #[test]
    fn uivk_scan_is_partial_even_at_the_tip() {
        assert!(history_is_partial(KeyKind::Uivk, 10, 10, false, 0));
        assert!(!history_is_partial(KeyKind::Ufvk, 10, 10, false, 0));
        assert!(history_is_partial(KeyKind::Ufvk, 9, 10, false, 0));
    }

    #[test]
    fn host_drops_scheme_and_port() {
        assert_eq!(host_of("https://lwd.example:9067"), "lwd.example");
    }
}
