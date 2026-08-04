import Combine
import Foundation
import SaneBooksCore
@preconcurrency import ZcashLightClientKit

/// Owns one SDKSynchronizer session for a vault. View-only: never calls propose/send APIs.
///
/// SDKSynchronizer is not Sendable; this type serializes access and is marked unchecked.
final class LatestTaskCoordinator: @unchecked Sendable {
    private var unfair = os_unfair_lock_s()
    private var task: Task<Void, Never>?

    func replace(with operation: @escaping @Sendable () async -> Void) {
        os_unfair_lock_lock(&unfair)
        task?.cancel()
        task = Task(operation: operation)
        os_unfair_lock_unlock(&unfair)
    }

    func cancel() {
        os_unfair_lock_lock(&unfair)
        task?.cancel()
        task = nil
        os_unfair_lock_unlock(&unfair)
    }
}

private final class PublisherCompletionState: @unchecked Sendable {
    private var unfair = os_unfair_lock_s()
    private var terminal: Result<Void, Error>?
    private var continuation: CheckedContinuation<Void, Error>?
    private var cancellable: AnyCancellable?

    func install(_ continuation: CheckedContinuation<Void, Error>) -> Bool {
        os_unfair_lock_lock(&unfair)
        if let terminal {
            os_unfair_lock_unlock(&unfair)
            continuation.resume(with: terminal)
            return false
        }
        self.continuation = continuation
        os_unfair_lock_unlock(&unfair)
        return true
    }

    func install(_ cancellable: AnyCancellable) {
        os_unfair_lock_lock(&unfair)
        let alreadyFinished = terminal != nil
        if !alreadyFinished {
            self.cancellable = cancellable
        }
        os_unfair_lock_unlock(&unfair)
        if alreadyFinished {
            cancellable.cancel()
        }
    }

    func finish(_ result: Result<Void, Error>) {
        os_unfair_lock_lock(&unfair)
        guard terminal == nil else {
            os_unfair_lock_unlock(&unfair)
            return
        }
        terminal = result
        let continuation = continuation
        let cancellable = cancellable
        self.continuation = nil
        self.cancellable = nil
        os_unfair_lock_unlock(&unfair)

        cancellable?.cancel()
        continuation?.resume(with: result)
    }

    func cancel() {
        finish(.failure(CancellationError()))
    }
}

func awaitPublisherCompletion(_ publisher: some Publisher) async throws {
    let state = PublisherCompletionState()
    try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            guard state.install(continuation) else { return }
            if Task.isCancelled {
                state.cancel()
                return
            }
            let cancellable = publisher.sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        state.finish(.success(()))
                    case let .failure(error):
                        state.finish(.failure(SaneBooksError.sync(String(describing: error))))
                    }
                },
                receiveValue: { _ in }
            )
            state.install(cancellable)
        }
    } onCancel: {
        state.cancel()
    }
}

final class ZcashSDKEngine: @unchecked Sendable {
    private var unfair = os_unfair_lock_s()
    private var synchronizer: SDKSynchronizer?
    private var stateCancellable: AnyCancellable?
    private let stateApplyTasks = LatestTaskCoordinator()
    private var cursor: SyncCursor?
    private var notes: [NoteRow] = []
    private var credentials: SyncAccountCredentials?
    private var lwdURL: URL = LinkedZcashSDK.defaultMainnetLWD
    private var sessionID: UUID?
    private let capability: CapabilityReport

    init(capability: CapabilityReport = LinkedZcashSDK.linkedCapabilityReport) {
        self.capability = capability
    }

    private func withLock<T>(_ body: () throws -> T) rethrows -> T {
        os_unfair_lock_lock(&unfair)
        defer { os_unfair_lock_unlock(&unfair) }
        return try body()
    }

    func currentCursor() -> SyncCursor? {
        withLock { cursor }
    }

    func latestNotes() -> [NoteRow] {
        withLock { notes }
    }

    func start(credentials: SyncAccountCredentials, lwdURL: URL) async throws {
        guard credentials.keyKind == .ufvk || credentials.keyKind == .legacySaplingFVK else {
            throw SaneBooksError.syncBlocked(
                "Live light-client sync requires a UFVK. UIVK/receivables mode cannot import via the public SDK yet."
            )
        }

        let session = UUID()
        stateApplyTasks.cancel()
        withLock {
            stateCancellable?.cancel()
            stateCancellable = nil
            synchronizer?.stop()
            synchronizer = nil
            sessionID = session
            self.credentials = credentials
            self.lwdURL = lwdURL
            notes = []
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
        guard install(sync: sync, session: session) else {
            sync.stop()
            throw CancellationError()
        }

        try await prepareAndImport(sync: sync, credentials: credentials)
        try ensureCurrent(session)
        try ZcashSDKStoragePolicy.hardenExistingTree(
            at: walletRootURL(for: credentials.vaultID)
        )

        observe(
            sync: sync,
            vaultID: credentials.vaultID,
            birthday: credentials.birthdayHeight,
            lwdURL: lwdURL,
            session: session
        )
        try await sync.start(retry: false)
        try ensureCurrent(session)

        await apply(
            state: sync.latestState,
            sync: sync,
            vaultID: credentials.vaultID,
            birthday: credentials.birthdayHeight,
            lwdURL: lwdURL,
            session: session
        )
    }

    func cancel(vaultID: VaultID) {
        stateApplyTasks.cancel()
        withLock {
            guard cursor?.vaultID == vaultID || credentials?.vaultID == vaultID else { return }
            sessionID = nil
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

    func purge(vaultID: VaultID) throws {
        cancel(vaultID: vaultID)
        withLock {
            if credentials?.vaultID == vaultID {
                credentials = nil
                cursor = nil
                notes = []
                synchronizer = nil
            }
        }
        let root = try walletRootURL(for: vaultID)
        if FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.removeItem(at: root)
        }
    }

    func rescan(
        credentials newCredentials: SyncAccountCredentials,
        lwdURL newLWDURL: URL,
        from height: UInt32
    ) async throws {
        var updatedCredentials = newCredentials
        updatedCredentials.birthdayHeight = height
        let state = withLock { () -> SDKSynchronizer? in
            guard credentials?.vaultID == updatedCredentials.vaultID else { return nil }
            credentials = updatedCredentials
            lwdURL = newLWDURL
            return synchronizer
        }

        guard let sync = state else {
            try await start(credentials: updatedCredentials, lwdURL: newLWDURL)
            return
        }

        try await awaitPublisherCompletion(
            sync.rewind(.height(blockheight: BlockHeight(height)))
        )
        try Task.checkCancellation()
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
        try await awaitPublisherCompletion(sync.wipe())
        try Task.checkCancellation()
    }

    private func install(sync: SDKSynchronizer, session: UUID) -> Bool {
        withLock {
            guard sessionID == session else { return false }
            synchronizer = sync
            return true
        }
    }

    private func ensureCurrent(_ session: UUID) throws {
        guard withLock({ sessionID == session }) else { throw CancellationError() }
    }

    private func observe(
        sync: SDKSynchronizer,
        vaultID: VaultID,
        birthday: UInt32,
        lwdURL: URL,
        session: UUID
    ) {
        withLock {
            guard sessionID == session else { return }
            stateCancellable?.cancel()
            stateCancellable = sync.stateStream
                .receive(on: DispatchQueue.global(qos: .utility))
                .sink { [weak self] state in
                    guard let self else { return }
                    stateApplyTasks.replace { [weak self] in
                        guard let self, !Task.isCancelled else { return }
                        await apply(
                            state: state,
                            sync: sync,
                            vaultID: vaultID,
                            birthday: birthday,
                            lwdURL: lwdURL,
                            session: session
                        )
                    }
                }
        }
    }

    private func apply(
        state: SynchronizerState,
        sync: SDKSynchronizer,
        vaultID: VaultID,
        birthday: UInt32,
        lwdURL: URL,
        session: UUID
    ) async {
        guard !Task.isCancelled else { return }
        let existing: SyncCursor? = withLock {
            guard sessionID == session else { return nil }
            return cursor
        }
        guard withLock({ sessionID == session }) else { return }

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
                  progress > 0
        {
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
                let mapped = await ZcashSDKNoteMapper.noteRows(vaultID: vaultID, synchronizer: sync)
                withLock {
                    if sessionID == session {
                        notes = mapped.rows
                    }
                }
                next.noteCount = mapped.rows.count
                if mapped.encounteredUnknownPool {
                    next.status = .degraded
                    next.lastError = .capability
                }
            }
        case .upToDate:
            next.status = .caughtUp
            next.progressFraction = 1
            next.lastSuccessAt = Date()
            next.lastError = nil
            guard !Task.isCancelled else { return }
            let mapped = await ZcashSDKNoteMapper.noteRows(vaultID: vaultID, synchronizer: sync)
            guard !Task.isCancelled else { return }
            withLock {
                if sessionID == session {
                    notes = mapped.rows
                }
            }
            next.noteCount = mapped.rows.count
            if mapped.encounteredUnknownPool {
                next.status = .degraded
                next.lastError = .capability
            }
        case .stopped, .unprepared:
            next.status = .idle
        case .error:
            next.status = .stalled
            next.lastError = .network
        }

        guard !Task.isCancelled else { return }
        withLock {
            if sessionID == session {
                cursor = next
            }
        }
    }

    private func walletRoot(for vaultID: VaultID) throws -> URL {
        let root = try walletRootURL(for: vaultID)
        try ZcashSDKStoragePolicy.prepareRoot(at: root)
        return root
    }

    private func walletRootURL(for vaultID: VaultID) throws -> URL {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw SaneBooksError.persistFailed("Application Support is unavailable; refusing temporary wallet storage")
        }
        return base
            .appendingPathComponent("SaneBooks", isDirectory: true)
            .appendingPathComponent("zcash-sdk", isDirectory: true)
            .appendingPathComponent(vaultID.uuid.uuidString, isDirectory: true)
    }
}
