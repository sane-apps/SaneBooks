import Foundation
import SaneBooksCore
import SaneBooksSync

@MainActor
public extension AppModel {
    /// Starts a cancellable Zashi/Zodl database import. SQLite scanning and
    /// classification run off the main actor; only the final atomic commit
    /// updates the local ledger and visible model.
    func importZashiSDKDatabase(
        at url: URL,
        securityScoped: Bool = false,
        onSuccess: (() -> Void)? = nil
    ) {
        cancelZashiSDKDatabaseImport()
        importError = nil
        pendingForceMock = false

        let importID = UUID()
        let cancellation = ImportCancellation()
        zashiDatabaseImportID = importID
        zashiDatabaseImportCancellation = cancellation
        zashiDatabaseImportCompletion = onSuccess
        isZashiDatabaseImportInProgress = true

        zashiDatabaseImportTask = Task { [weak self] in
            guard let self else { return }
            let accessed = securityScoped && url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                try await self.completeZashiSDKDatabaseImport(
                    at: url,
                    importID: importID,
                    cancellation: cancellation
                )
            } catch is CancellationError {
                self.finishZashiSDKDatabaseImport(id: importID)
            } catch {
                guard self.isCurrentZashiSDKDatabaseImport(id: importID) else { return }
                self.importError = error.localizedDescription
                self.finishZashiSDKDatabaseImport(id: importID)
            }
        }
    }

    func cancelZashiSDKDatabaseImport() {
        zashiDatabaseImportID = nil
        zashiDatabaseImportCancellation?.cancel()
        zashiDatabaseImportCancellation = nil
        zashiDatabaseImportTask?.cancel()
        zashiDatabaseImportTask = nil
        zashiDatabaseImportCompletion = nil
        isZashiDatabaseImportInProgress = false
    }

    private func completeZashiSDKDatabaseImport(
        at url: URL,
        importID: UUID,
        cancellation: ImportCancellation
    ) async throws {
        // Read only the account row before picking a vault. This avoids the
        // former full-database "peek" scan and keeps all SQLite work off-main.
        let account = try await ZashiSDKDatabaseImporter.inspectDatabaseAsync(
            at: url,
            cancellation: cancellation
        )
        guard isCurrentZashiSDKDatabaseImport(id: importID) else { return }

        let outcome = ViewingKeyValidator().validate(account.ufvk, selectedNetwork: .mainnet)
        guard case let .accept(kind, network, _, fingerprint, mode) = outcome else {
            throw ZashiImportPresentationError.invalidWalletExport
        }
        guard LinkedZcashSDK.isValidViewingKey(account.ufvk, kind: kind, network: network) else {
            throw ZashiImportPresentationError.invalidSDKViewingKey
        }

        let existing = try store.allVaults().first(where: { $0.keyFingerprint == fingerprint })
        let vaultID = existing?.id ?? VaultID()
        let activeVault = makeImportedVault(
            existing: existing,
            vaultID: vaultID,
            account: account,
            keyKind: kind,
            network: network,
            fingerprint: fingerprint,
            mode: mode
        )
        let existingNotes = try store.notes(vaultID: activeVault.id)
        guard isCurrentZashiSDKDatabaseImport(id: importID) else { return }

        let imported = try await ZashiSDKDatabaseImporter.importDatabaseAsync(
            at: url,
            vaultID: activeVault.id,
            cancellation: cancellation
        )
        guard isCurrentZashiSDKDatabaseImport(id: importID) else { return }

        let classified = try await Task.detached(priority: .userInitiated) {
            try cancellation.throwIfCancelled()
            var notes = ClassificationEngine.suggest(
                notes: imported.notes,
                vaultMode: activeVault.mode,
                keyKind: activeVault.keyKind
            )
            notes = ClassificationEngine.applyRules(activeVault.tagRules, to: notes)
            try cancellation.throwIfCancelled()
            return ZashiSDKDatabaseImporter.mergeImportedNotesPreservingClassifications(
                existing: existingNotes,
                imported: notes
            )
        }.value
        guard isCurrentZashiSDKDatabaseImport(id: importID) else { return }

        // This is the sole model/store commit. A cancelled or superseded task
        // exits above with no key, vault, notes, route, or cursor mutation.
        try commitKeyAndVault(
            keyMaterial: imported.ufvk,
            vault: activeVault,
            replacingNotes: classified
        )
        vault = activeVault
        vaults = try store.allVaults()
        notes = classified
        let importedThrough = imported.attestation.importedThroughHeight ?? imported.birthdayHeight
        cursor = SyncCursor(
            vaultID: activeVault.id,
            birthdayHeight: imported.birthdayHeight,
            scannedThroughHeight: importedThrough,
            chainTipHeight: imported.attestation.independentlyVerifiedChainTipHeight,
            lastSuccessAt: nil,
            lwdURL: URL(string: lwdURLString) ?? LinkedZcashSDK.defaultMainnetLWD,
            status: .idle,
            poolsSynced: Set(classified.map(\.pool)),
            capabilityReport: LinkedZcashSDK.linkedCapabilityReport,
            isDemo: false,
            progressFraction: 0,
            noteCount: classified.count
        )
        importKeyText = ""
        filters = LedgerFilters()
        route = .ledger
        finishZashiSDKDatabaseImport(id: importID, succeeded: true)
    }

    private func makeImportedVault(
        existing: Vault?,
        vaultID: VaultID,
        account: ZashiSDKDatabaseImporter.AccountMetadata,
        keyKind: ViewingKeyKind,
        network: ZcashNetwork,
        fingerprint: String,
        mode: VaultMode
    ) -> Vault {
        if var kept = existing {
            if kept.displayName.hasPrefix("My books") || kept.displayName.hasPrefix("Incoming") {
                kept.displayName = account.accountName == "(unnamed)"
                    ? kept.displayName
                    : "\(account.accountName) (imported)"
            }
            kept.birthdayHeight = account.birthdayHeight
            return kept
        }
        return Vault(
            id: vaultID,
            displayName: account.accountName == "(unnamed)"
                ? Self.defaultVaultDisplayName(
                    mode: mode,
                    network: network,
                    fingerprint: fingerprint,
                    isDemo: false
                )
                : "\(account.accountName) (imported)",
            network: network,
            keyKind: keyKind,
            keyFingerprint: fingerprint,
            birthdayHeight: account.birthdayHeight,
            mode: mode
        )
    }

    private func isCurrentZashiSDKDatabaseImport(id: UUID) -> Bool {
        zashiDatabaseImportID == id && !Task.isCancelled
    }

    private func finishZashiSDKDatabaseImport(id: UUID, succeeded: Bool = false) {
        guard zashiDatabaseImportID == id else { return }
        let completion = succeeded ? zashiDatabaseImportCompletion : nil
        zashiDatabaseImportID = nil
        zashiDatabaseImportCancellation = nil
        zashiDatabaseImportTask = nil
        zashiDatabaseImportCompletion = nil
        isZashiDatabaseImportInProgress = false
        completion?()
    }
}

private enum ZashiImportPresentationError: LocalizedError {
    case invalidWalletExport
    case invalidSDKViewingKey

    var errorDescription: String? {
        switch self {
        case .invalidWalletExport:
            "That wallet export could not be read. Pick a Zashi or Zodl private-data file and try again."
        case .invalidSDKViewingKey:
            "The database viewing key failed the Zcash SDK checksum or network check. Nothing was imported."
        }
    }
}
