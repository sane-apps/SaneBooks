import Foundation
import SaneBooksCore
import SaneBooksSync

@MainActor
public extension AppModel {
    // MARK: - Multi-vault

    func switchVault(_ id: VaultID) {
        do {
            guard let next = try store.vault(id: id) else { return }
            try store.setActiveVaultID(id)
            vault = next
            notes = try store.notes(vaultID: id)
            cursor = nil
            packDraft = nil
            route = .ledger
            startSync()
        } catch {
            importError = error.localizedDescription
        }
    }

    func addAnotherVault() {
        importAsUpgrade = false
        goImport()
    }

    // MARK: - Sync

    func startSync() {
        guard let targetVault = vault else { return }
        let priorVaultID = activeSyncVaultID
        syncTask?.cancel()
        activeSyncVaultID = targetVault.id
        syncTask = Task {
            do {
                if let priorVaultID {
                    await sync.cancel(vaultID: priorVaultID)
                }
                try Task.checkCancellation()
                guard activeSyncVaultID == targetVault.id, vault?.id == targetVault.id else { return }
                if let light = sync as? LightClientSyncFacade {
                    if pendingForceMock || LightClientSyncFacade.envForceMock {
                        await light.setForceMock(true)
                        pendingForceMock = false
                    }
                    if let url = URL(string: lwdURLString) {
                        await light.setLWDURL(url)
                    }
                    if let key = try keyStore.load(for: targetVault.id) {
                        let birthday = targetVault.birthdayHeight
                            ?? (targetVault.network == .mainnet
                                ? LinkedZcashSDK.mainnetDefaultBirthday
                                : LinkedZcashSDK.testnetDefaultBirthday)
                        await light.bindCredentials(
                            SyncAccountCredentials(
                                vaultID: targetVault.id,
                                viewingKey: key,
                                keyKind: targetVault.keyKind,
                                network: targetVault.network,
                                birthdayHeight: birthday
                            )
                        )
                    }
                }
                try Task.checkCancellation()
                guard activeSyncVaultID == targetVault.id, vault?.id == targetVault.id else { return }
                capabilityReport = await sync.capabilityReport()
                try await sync.start(vaultID: targetVault.id)
                try Task.checkCancellation()
                await pollUntilSettled(vaultID: targetVault.id)
            } catch is CancellationError {
                return
            } catch {
                guard activeSyncVaultID == targetVault.id, vault?.id == targetVault.id else { return }
                cursor = await sync.currentCursor(vaultID: targetVault.id)
                capabilityReport = await sync.capabilityReport()
                importError = error.localizedDescription
                route = .ledger
            }
        }
    }

    private func pollUntilSettled(vaultID: VaultID) async {
        // Mock finishes in one tick; live LWD can run for hours from birthday.
        // Keep UI cursor fresh while scanning; settle on terminal states.
        for _ in 0 ..< 21600 {
            guard !Task.isCancelled,
                  activeSyncVaultID == vaultID,
                  vault?.id == vaultID
            else { return }
            if let c = await sync.currentCursor(vaultID: vaultID) {
                cursor = c
                if c.status == .caughtUp || c.status == .idle || c.status == .capabilityBlocked
                    || c.status == .stalled
                {
                    await refreshFromSync(vaultID: vaultID)
                    // Do not clobber proof-pack / detail / share routes after E2E or user navigation.
                    if route == .syncing {
                        route = .ledger
                    }
                    return
                }
            }
            try? await Task.sleep(for: .seconds(1))
        }
        await refreshFromSync(vaultID: vaultID)
        if route == .syncing {
            route = .ledger
        }
    }

    func cancelSync() {
        guard let targetVault = vault else { return }
        syncTask?.cancel()
        activeSyncVaultID = nil
        syncTask = Task {
            await sync.cancel(vaultID: targetVault.id)
            guard vault?.id == targetVault.id else { return }
            cursor = await sync.currentCursor(vaultID: targetVault.id)
            await refreshFromSync(vaultID: targetVault.id)
            route = .ledger
        }
    }

    func refreshFromSync(vaultID targetVaultID: VaultID? = nil) async {
        guard let targetVault = vault,
              targetVaultID == nil || targetVault.id == targetVaultID
        else { return }
        cursor = await sync.currentCursor(vaultID: targetVault.id)
        capabilityReport = await sync.capabilityReport()
        var synced = await sync.latestNotes(vaultID: targetVault.id)
        guard vault?.id == targetVault.id else { return }
        synced = ClassificationEngine.suggest(
            notes: synced,
            vaultMode: targetVault.mode,
            keyKind: targetVault.keyKind
        )
        synced = ClassificationEngine.applyRules(targetVault.tagRules, to: synced)
        do {
            // Preserve user classifications already in store.
            let existing = try store.notes(vaultID: targetVault.id)
            var byID: [UUID: NoteRow] = [:]
            var byTxid: [Data: [NoteRow]] = [:]
            for note in existing {
                byID[note.id.uuid] = note
                byTxid[note.txid, default: []].append(note)
            }
            let syncedCountsByTxid = Dictionary(grouping: synced, by: \.txid).mapValues(\.count)
            synced = synced.map { note in
                // The txid fallback is only safe for a one-output legacy identity.
                // Multi-output transactions must match the canonical pool/index ID.
                let legacyPrior = byTxid[note.txid].flatMap { candidates in
                    candidates.count == 1 && syncedCountsByTxid[note.txid] == 1
                        ? candidates[0]
                        : nil
                }
                guard let prior = byID[note.id.uuid] ?? legacyPrior else { return note }
                var n = note
                if let classification = prior.classification, classification.source == .user {
                    n.classification = classification
                }
                n.includeInPacksByDefault = prior.includeInPacksByDefault
                n.memo = prior.memo
                n.fiatMark = prior.fiatMark
                return n
            }
            if cursor?.isDemo == true {
                // Never wipe a good ledger with an empty pre-sync snapshot.
                if !synced.isEmpty {
                    try store.replaceNotes(vaultID: targetVault.id, with: synced)
                }
            } else if cursor?.status == .caughtUp, !synced.isEmpty {
                // A caught-up snapshot is authoritative for this vault. Replacing
                // removes retired pre-canonical IDs without retaining duplicates.
                try store.replaceNotes(vaultID: targetVault.id, with: synced)
            } else if !synced.isEmpty {
                try store.upsertNotes(synced)
            }
            guard vault?.id == targetVault.id else { return }
            notes = try store.notes(vaultID: targetVault.id)
        } catch {
            importError = error.localizedDescription
        }
    }

    func syncNow() {
        startSync()
        if route != .syncing {
            route = .syncing
        }
    }

    func refreshCapability() async {
        capabilityReport = await sync.capabilityReport()
    }
}
