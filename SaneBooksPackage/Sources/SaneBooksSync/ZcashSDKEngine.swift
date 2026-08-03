import Combine
import Foundation
import SaneBooksCore
@preconcurrency import ZcashLightClientKit

/// Owns one SDKSynchronizer session for a vault. View-only: never calls propose/send APIs.
///
/// SDKSynchronizer is not Sendable; this type serializes access and is marked unchecked.
final class ZcashSDKEngine: @unchecked Sendable {
    private var unfair = os_unfair_lock_s()
    private var synchronizer: SDKSynchronizer?
    private var stateCancellable: AnyCancellable?
    private var cursor: SyncCursor?
    private var notes: [NoteRow] = []
    private var credentials: SyncAccountCredentials?
    private var lwdURL: URL = LinkedZcashSDK.defaultMainnetLWD
    private let capability: CapabilityReport

    init(capability: CapabilityReport = LinkedZcashSDK.linkedCapabilityReport) {
        self.capability = capability
    }

    private func withLock<T>(_ body: () throws -> T) rethrows -> T {
        os_unfair_lock_lock(&unfair)
        defer { os_unfair_lock_unlock(&unfair) }
        return try body()
    }

    func bind(credentials: SyncAccountCredentials, lwdURL: URL) {
        withLock {
            self.credentials = credentials
            self.lwdURL = lwdURL
        }
    }

    func currentCursor() -> SyncCursor? {
        withLock { cursor }
    }

    func latestNotes() -> [NoteRow] {
        withLock { notes }
    }

    func start() async throws {
        let pair = withLock { () -> (SyncAccountCredentials, URL)? in
            guard let credentials else { return nil }
            return (credentials, lwdURL)
        }
        guard let (credentials, lwdURL) = pair else {
            throw SaneBooksError.sync("No viewing key bound for live sync.")
        }

        guard credentials.keyKind == .ufvk || credentials.keyKind == .legacySaplingFVK else {
            throw SaneBooksError.syncBlocked(
                "Live light-client sync requires a UFVK. UIVK/receivables mode cannot import via the public SDK yet."
            )
        }

        withLock {
            cursor = SyncCursor(
                vaultID: credentials.vaultID,
                birthdayHeight: credentials.birthdayHeight,
                scannedThroughHeight: credentials.birthdayHeight,
                lwdURL: lwdURL,
                status: .scanning,
                poolsSynced: [.sapling, .orchard, .ironwood],
                capabilityReport: capability,
                isDemo: false,
                progressFraction: 0
            )
        }

        let sync = try makeSynchronizer(for: credentials, lwdURL: lwdURL)
        withLock { synchronizer = sync }

        try await prepareAndImport(sync: sync, credentials: credentials)

        observe(sync: sync, vaultID: credentials.vaultID, birthday: credentials.birthdayHeight)
        try await sync.start(retry: false)

        await apply(state: sync.latestState, vaultID: credentials.vaultID, birthday: credentials.birthdayHeight)
    }

    func cancel() {
        withLock {
            stateCancellable?.cancel()
            stateCancellable = nil
            synchronizer?.stop()
            if var cursor {
                cursor.status = .idle
                cursor.lastError = .cancelled
                self.cursor = cursor
            }
        }
    }

    func rescan(from height: UInt32) async throws {
        let sync = withLock { () -> SDKSynchronizer? in
            if var creds = credentials {
                creds.birthdayHeight = height
                credentials = creds
            }
            return synchronizer
        }

        guard let sync else {
            try await start()
            return
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            var bag = Set<AnyCancellable>()
            sync.rewind(.height(blockheight: BlockHeight(height)))
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            cont.resume()
                        case let .failure(error):
                            cont.resume(throwing: SaneBooksError.sync(String(describing: error)))
                        }
                        bag.removeAll()
                    },
                    receiveValue: { _ in }
                )
                .store(in: &bag)
        }
        try await sync.start(retry: true)
    }

    // MARK: - Private

    private func makeSynchronizer(
        for credentials: SyncAccountCredentials,
        lwdURL: URL
    ) throws -> SDKSynchronizer {
        let root = try walletRoot(for: credentials.vaultID)
        let endpoint = try Self.endpoint(from: lwdURL)
        let network = ZcashNetworkBuilder.network(
            for: credentials.network == .mainnet ? .mainnet : .testnet
        )

        let initializer = Initializer(
            cacheDbURL: nil,
            fsBlockDbRoot: root.appendingPathComponent("blocks", isDirectory: true),
            generalStorageURL: root.appendingPathComponent("storage", isDirectory: true),
            dataDbURL: root.appendingPathComponent("data.db"),
            torDirURL: root.appendingPathComponent("tor", isDirectory: true),
            endpoint: endpoint,
            network: network,
            spendParamsURL: root.appendingPathComponent("sapling-spend.params"),
            outputParamsURL: root.appendingPathComponent("sapling-output.params"),
            saplingParamsSourceURL: .default,
            alias: .custom(credentials.vaultID.uuid.uuidString),
            loggingPolicy: .noLogging,
            isTorEnabled: false,
            isExchangeRateEnabled: false
        )
        return SDKSynchronizer(initializer: initializer)
    }

    private func prepareAndImport(
        sync: SDKSynchronizer,
        credentials: SyncAccountCredentials
    ) async throws {
        let birthday = BlockHeight(credentials.birthdayHeight)
        let result = try await sync.prepare(
            with: nil,
            walletBirthday: birthday,
            for: .existingWallet,
            name: "SaneBooks",
            keySource: "sanebooks"
        )

        if result == .seedRequired {
            try await wipe(sync)
            let retry = try await sync.prepare(
                with: nil,
                walletBirthday: birthday,
                for: .newWallet,
                name: "SaneBooks",
                keySource: "sanebooks"
            )
            if retry == .seedRequired {
                throw SaneBooksError.sync(
                    "SDK database requires a seed; wiped view-only DB and still blocked. Delete Application Support/SaneBooks/zcash-sdk and retry."
                )
            }
        }

        let accounts = try await sync.listAccounts()
        if accounts.isEmpty {
            _ = try await sync.importAccount(
                ufvk: credentials.viewingKey,
                seedFingerprint: nil,
                zip32AccountIndex: nil,
                purpose: .viewOnly,
                name: "Imported UFVK",
                keySource: "ufvk-import",
                birthday: birthday
            )
        }
    }

    private func wipe(_ sync: SDKSynchronizer) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            var bag = Set<AnyCancellable>()
            sync.wipe()
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            cont.resume()
                        case let .failure(error):
                            cont.resume(throwing: SaneBooksError.sync(String(describing: error)))
                        }
                        bag.removeAll()
                    },
                    receiveValue: { _ in }
                )
                .store(in: &bag)
        }
    }

    private func observe(sync: SDKSynchronizer, vaultID: VaultID, birthday: UInt32) {
        withLock {
            stateCancellable?.cancel()
            stateCancellable = sync.stateStream
                .receive(on: DispatchQueue.global(qos: .utility))
                .sink { [weak self] state in
                    guard let self else { return }
                    Task {
                        await self.apply(state: state, vaultID: vaultID, birthday: birthday)
                    }
                }
        }
    }

    private func apply(state: SynchronizerState, vaultID: VaultID, birthday: UInt32) async {
        let (lwdURL, existing, sync): (URL, SyncCursor?, SDKSynchronizer?) = withLock {
            (self.lwdURL, cursor, synchronizer)
        }

        var next = existing ?? SyncCursor(
            vaultID: vaultID,
            birthdayHeight: birthday,
            scannedThroughHeight: birthday,
            lwdURL: lwdURL,
            status: .scanning,
            poolsSynced: [.sapling, .orchard, .ironwood],
            capabilityReport: capability,
            isDemo: false
        )

        next.chainTipHeight = UInt32(state.latestBlockHeight)
        let fully = UInt32(state.fullyScannedHeight)
        if fully > birthday {
            next.scannedThroughHeight = fully
        } else if case let .syncing(progress, _) = state.syncStatus,
                  state.latestBlockHeight > BlockHeight(birthday),
                  progress > 0 {
            // Slipstream can advance progress before contiguous fullyScannedHeight moves.
            let span = Double(state.latestBlockHeight - BlockHeight(birthday))
            next.scannedThroughHeight = birthday + UInt32(span * Double(progress))
        } else {
            next.scannedThroughHeight = max(fully, birthday)
        }
        next.lwdURL = lwdURL
        next.capabilityReport = capability
        next.isDemo = false

        switch state.syncStatus {
        case let .syncing(progress, _):
            next.status = .scanning
            next.progressFraction = Double(progress)
            next.lastError = nil
            // Treat near-complete sync as caught up for ledger refresh; SDK may linger on enhance.
            if progress >= 0.999 {
                next.status = .caughtUp
                next.progressFraction = 1
                next.lastSuccessAt = Date()
                if let sync {
                    let mapped = await ZcashSDKNoteMapper.noteRows(vaultID: vaultID, synchronizer: sync)
                    withLock { notes = mapped }
                    next.noteCount = mapped.count
                }
            }
        case .upToDate:
            next.status = .caughtUp
            next.progressFraction = 1
            next.lastSuccessAt = Date()
            next.lastError = nil
            if let sync {
                let mapped = await ZcashSDKNoteMapper.noteRows(vaultID: vaultID, synchronizer: sync)
                withLock { notes = mapped }
                next.noteCount = mapped.count
            }
        case .stopped, .unprepared:
            next.status = .idle
        case .error:
            next.status = .stalled
            next.lastError = .network
        }

        withLock { cursor = next }
    }

    private func walletRoot(for vaultID: VaultID) throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let root = base
            .appendingPathComponent("SaneBooks", isDirectory: true)
            .appendingPathComponent("zcash-sdk", isDirectory: true)
            .appendingPathComponent(vaultID.uuid.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    nonisolated static func endpoint(from url: URL) throws -> LightWalletEndpoint {
        guard let host = url.host, !host.isEmpty else {
            throw SaneBooksError.sync("Invalid lightwalletd URL: \(url.absoluteString)")
        }
        let port = url.port ?? (url.scheme == "http" ? 80 : 443)
        let secure = (url.scheme ?? "https").lowercased() != "http"
        return LightWalletEndpoint(address: host, port: port, secure: secure)
    }
}
