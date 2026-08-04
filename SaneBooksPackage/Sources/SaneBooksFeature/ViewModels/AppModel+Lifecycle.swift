import Foundation
import SaneBooksCore
import SaneBooksSync

@MainActor
public extension AppModel {
    /// App launch default: FileLedgerStore + KeychainViewingKeyStore + LightClientSyncFacade.
    /// Forced-mock and explicit no-keychain launches isolate both ledger and key state in memory.
    /// A storage initialization failure is visible and blocks all bookkeeping work.
    static func makeProduction(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> AppModel {
        #if DEBUG
            let forceMock = environment["SANEBOOKS_FORCE_MOCK"] == "1"
            let useEphemeralTestState = shouldUseEphemeralKeyStore(
                environment: environment,
                arguments: arguments
            )
        #else
            let forceMock = false
            let useEphemeralTestState = false
        #endif
        let sync: any SyncFacade = forceMock
            ? MockSyncFacade()
            : LightClientSyncFacade.makeDefault()

        if useEphemeralTestState {
            let model = AppModel(
                store: InMemoryLedgerStore(),
                keyStore: InMemoryViewingKeyStore(),
                sync: sync
            )
            model.isEphemeralTestSession = true
            model.reloadFromStore()
            return model
        }

        do {
            let store = try FileLedgerStore()
            let model = AppModel(
                store: store,
                keyStore: KeychainViewingKeyStore(),
                sync: sync
            )
            model.reloadFromStore()
            return model
        } catch {
            let model = AppModel(sync: sync)
            model.startupError = "SaneBooks could not open its private ledger storage. No bookkeeping changes are allowed until this is fixed. Close the app, verify disk space and permissions, then reopen. (\(error.localizedDescription))"
            return model
        }
    }

    static func shouldUseEphemeralKeyStore(
        environment: [String: String],
        arguments: [String]
    ) -> Bool {
        environment["SANEBOOKS_FORCE_MOCK"] == "1"
            || environment["SANEAPPS_DISABLE_KEYCHAIN"] == "1"
            || arguments.contains("--sane-no-keychain")
    }

    func reloadFromStore() {
        do {
            try refreshVaultNamesIfNeeded()
            vaults = try store.allVaults()
            shareHistory = try store.shareHistory()
            if let active = try store.activeVaultID(), let v = try store.vault(id: active) {
                vault = v
                notes = try store.notes(vaultID: v.id)
            } else if let first = vaults.first {
                vault = first
                notes = try store.notes(vaultID: first.id)
                try store.setActiveVaultID(first.id)
            } else {
                vault = nil
                notes = []
            }
            if vault != nil {
                // Existing vault owners must never be interrupted by a newly
                // introduced first-run disclosure flow during an upgrade.
                hasCompletedOnboarding = true
                route = .ledger
            } else {
                route = hasCompletedOnboarding ? .welcome : .onboarding
            }
        } catch {
            importError = error.localizedDescription
        }
    }
}
