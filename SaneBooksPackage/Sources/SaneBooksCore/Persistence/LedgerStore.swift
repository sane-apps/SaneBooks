import Foundation

private struct LedgerSnapshotState {
    var vaults: [Vault]
    var notes: [NoteRow]
    var history: [ShareHistoryEntry]
    var activeVaultID: UUID?
}

public protocol LedgerStore: Sendable {
    func upsertVault(_ vault: Vault) throws
    func vault(id: VaultID) throws -> Vault?
    func allVaults() throws -> [Vault]
    func deleteVault(id: VaultID) throws
    func upsertNotes(_ notes: [NoteRow]) throws
    func replaceNotes(vaultID: VaultID, with notes: [NoteRow]) throws
    func notes(vaultID: VaultID) throws -> [NoteRow]
    func upsertClassification(noteID: NoteRowID, classification: Classification) throws
    func appendShareHistory(_ entry: ShareHistoryEntry) throws
    func shareHistory() throws -> [ShareHistoryEntry]
    func setActiveVaultID(_ id: VaultID?) throws
    func activeVaultID() throws -> VaultID?
    func commitVault(_ vault: Vault, replacingNotes notes: [NoteRow]?) throws
}

public final class InMemoryLedgerStore: LedgerStore, @unchecked Sendable {
    private let lock = NSLock()
    private var vaults: [UUID: Vault] = [:]
    private var notes: [UUID: NoteRow] = [:]
    private var history: [ShareHistoryEntry] = []
    private var activeID: UUID?

    public init() {}

    public func upsertVault(_ vault: Vault) throws {
        lock.lock()
        defer { lock.unlock() }
        vaults[vault.id.uuid] = vault
        if activeID == nil {
            activeID = vault.id.uuid
        }
    }

    public func vault(id: VaultID) throws -> Vault? {
        lock.lock()
        defer { lock.unlock() }
        return vaults[id.uuid]
    }

    public func allVaults() throws -> [Vault] {
        lock.lock()
        defer { lock.unlock() }
        return Array(vaults.values).sorted { $0.createdAt < $1.createdAt }
    }

    public func deleteVault(id: VaultID) throws {
        lock.lock()
        defer { lock.unlock() }
        let removedFingerprint = vaults[id.uuid]?.keyFingerprint
        vaults.removeValue(forKey: id.uuid)
        notes = notes.filter { $0.value.vaultID != id }
        if let removedFingerprint {
            history.removeAll { $0.vaultFingerprint == removedFingerprint }
        }
        if activeID == id.uuid {
            activeID = vaults.keys.first
        }
    }

    public func upsertNotes(_ notes: [NoteRow]) throws {
        lock.lock()
        defer { lock.unlock() }
        for note in notes {
            self.notes[note.id.uuid] = note
        }
    }

    public func replaceNotes(vaultID: VaultID, with notes: [NoteRow]) throws {
        lock.lock()
        defer { lock.unlock() }
        self.notes = self.notes.filter { $0.value.vaultID != vaultID }
        for note in notes {
            self.notes[note.id.uuid] = note
        }
    }

    public func notes(vaultID: VaultID) throws -> [NoteRow] {
        lock.lock()
        defer { lock.unlock() }
        return notes.values
            .filter { $0.vaultID == vaultID }
            .sorted {
                if $0.blockHeight != $1.blockHeight {
                    return $0.blockHeight < $1.blockHeight
                }
                return $0.txidHex < $1.txidHex
            }
    }

    public func upsertClassification(noteID: NoteRowID, classification: Classification) throws {
        lock.lock()
        defer { lock.unlock() }
        guard var note = notes[noteID.uuid] else {
            throw SaneBooksError.ledger("Unknown note \(noteID.uuid)")
        }
        note.classification = classification
        notes[noteID.uuid] = note
    }

    public func appendShareHistory(_ entry: ShareHistoryEntry) throws {
        lock.lock()
        defer { lock.unlock() }
        history.insert(entry, at: 0)
    }

    public func shareHistory() throws -> [ShareHistoryEntry] {
        lock.lock()
        defer { lock.unlock() }
        return history
    }

    public func setActiveVaultID(_ id: VaultID?) throws {
        lock.lock()
        defer { lock.unlock() }
        activeID = id?.uuid
    }

    public func activeVaultID() throws -> VaultID? {
        lock.lock()
        defer { lock.unlock() }
        return activeID.map { VaultID(uuid: $0) }
    }

    public func commitVault(_ vault: Vault, replacingNotes replacement: [NoteRow]?) throws {
        lock.lock()
        defer { lock.unlock() }
        if let replacement {
            guard replacement.allSatisfy({ $0.vaultID == vault.id }) else {
                throw SaneBooksError.persistFailed("Imported notes do not belong to the imported vault.")
            }
            guard Set(replacement.map(\.id.uuid)).count == replacement.count else {
                throw SaneBooksError.persistFailed("Imported notes contain duplicate identities.")
            }
            notes = notes.filter { $0.value.vaultID != vault.id }
            for note in replacement {
                notes[note.id.uuid] = note
            }
        }
        vaults[vault.id.uuid] = vault
        activeID = vault.id.uuid
    }

    func upsertVaultsAndNotes(_ vaults: [Vault], _ notes: [NoteRow]) throws {
        for vault in vaults {
            try upsertVault(vault)
        }
        try upsertNotes(notes)
    }

    func restoreSnapshot(
        vaults: [Vault],
        notes: [NoteRow],
        history: [ShareHistoryEntry],
        activeVaultID: UUID?
    ) throws {
        let vaultIDs = Set(vaults.map(\.id.uuid))
        guard vaultIDs.count == vaults.count else {
            throw SaneBooksError.persistFailed("Private ledger contains duplicate vault identities.")
        }
        guard Set(notes.map(\.id.uuid)).count == notes.count else {
            throw SaneBooksError.persistFailed("Private ledger contains duplicate note identities.")
        }
        guard notes.allSatisfy({ vaultIDs.contains($0.vaultID.uuid) }) else {
            throw SaneBooksError.persistFailed("Private ledger contains a note for an unknown vault.")
        }
        guard activeVaultID.map({ vaultIDs.contains($0) }) ?? true else {
            throw SaneBooksError.persistFailed("Private ledger has an invalid active vault.")
        }
        restoreTrustedSnapshot(
            vaults: vaults,
            notes: notes,
            history: history,
            activeVaultID: activeVaultID
        )
    }

    func restoreTrustedSnapshot(
        vaults: [Vault],
        notes: [NoteRow],
        history: [ShareHistoryEntry],
        activeVaultID: UUID?
    ) {
        lock.lock()
        defer { lock.unlock() }
        self.vaults = Dictionary(uniqueKeysWithValues: vaults.map { ($0.id.uuid, $0) })
        self.notes = Dictionary(uniqueKeysWithValues: notes.map { ($0.id.uuid, $0) })
        self.history = history
        activeID = activeVaultID
    }

    fileprivate func snapshot() -> LedgerSnapshotState {
        lock.lock()
        defer { lock.unlock() }
        return LedgerSnapshotState(
            vaults: Array(vaults.values),
            notes: Array(notes.values),
            history: history,
            activeVaultID: activeID
        )
    }
}

/// File-backed JSON under Application Support/SaneBooks/. UVK never written — fingerprint only.
public final class FileLedgerStore: LedgerStore, @unchecked Sendable {
    static let maximumEncodedByteCount = 100 * 1024 * 1024

    private let lock = NSLock()
    private let rootURL: URL
    private let encodedByteLimit: Int
    private var memory = InMemoryLedgerStore()

    private struct Snapshot: Codable {
        var vaults: [Vault]
        var notes: [NoteRow]
        var shareHistory: [ShareHistoryEntry]
        var activeVaultID: UUID?
    }

    public convenience init(rootURL: URL? = nil) throws {
        try self.init(rootURL: rootURL, encodedByteLimit: Self.maximumEncodedByteCount)
    }

    init(rootURL: URL?, encodedByteLimit: Int) throws {
        guard encodedByteLimit > 0 else {
            throw SaneBooksError.persistFailed("Private ledger encoded-size limit must be positive.")
        }
        self.encodedByteLimit = encodedByteLimit
        if let rootURL {
            self.rootURL = rootURL
        } else {
            guard let support = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first else {
                throw SaneBooksError.persistFailed(
                    "Application Support is unavailable; refusing nonpersistent ledger storage."
                )
            }
            self.rootURL = support.appendingPathComponent("SaneBooks", isDirectory: true)
        }
        try FileManager.default.createDirectory(at: self.rootURL, withIntermediateDirectories: true)
        try enforcePermissions(0o700, at: self.rootURL)
        try excludeFromBackup(self.rootURL)
        if FileManager.default.fileExists(atPath: ledgerFileURL.path) {
            let attributes = try FileManager.default.attributesOfItem(atPath: ledgerFileURL.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular else {
                throw SaneBooksError.persistFailed("Private ledger path is not a regular file.")
            }
            try enforcePermissions(0o600, at: ledgerFileURL)
        }
        try loadFromDisk()
    }

    public var ledgerFileURL: URL {
        rootURL.appendingPathComponent("ledger.json")
    }

    public func upsertVault(_ vault: Vault) throws {
        try mutateAndPersist { try memory.upsertVault(vault) }
    }

    public func vault(id: VaultID) throws -> Vault? {
        try withReadLock { try memory.vault(id: id) }
    }

    public func allVaults() throws -> [Vault] {
        try withReadLock { try memory.allVaults() }
    }

    public func deleteVault(id: VaultID) throws {
        try mutateAndPersist { try memory.deleteVault(id: id) }
    }

    public func upsertNotes(_ notes: [NoteRow]) throws {
        try mutateAndPersist { try memory.upsertNotes(notes) }
    }

    public func replaceNotes(vaultID: VaultID, with notes: [NoteRow]) throws {
        try mutateAndPersist { try memory.replaceNotes(vaultID: vaultID, with: notes) }
    }

    public func notes(vaultID: VaultID) throws -> [NoteRow] {
        try withReadLock { try memory.notes(vaultID: vaultID) }
    }

    public func upsertClassification(noteID: NoteRowID, classification: Classification) throws {
        try mutateAndPersist { try memory.upsertClassification(noteID: noteID, classification: classification) }
    }

    public func appendShareHistory(_ entry: ShareHistoryEntry) throws {
        try mutateAndPersist { try memory.appendShareHistory(entry) }
    }

    public func shareHistory() throws -> [ShareHistoryEntry] {
        try withReadLock { try memory.shareHistory() }
    }

    public func setActiveVaultID(_ id: VaultID?) throws {
        try mutateAndPersist { try memory.setActiveVaultID(id) }
    }

    public func activeVaultID() throws -> VaultID? {
        try withReadLock { try memory.activeVaultID() }
    }

    public func commitVault(_ vault: Vault, replacingNotes notes: [NoteRow]?) throws {
        try mutateAndPersist { try memory.commitVault(vault, replacingNotes: notes) }
    }

    private func loadFromDisk() throws {
        guard FileManager.default.fileExists(atPath: ledgerFileURL.path) else { return }
        let attributes = try FileManager.default.attributesOfItem(atPath: ledgerFileURL.path)
        let fileSize = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
        try validateEncodedByteCount(fileSize)
        let data = try Data(contentsOf: ledgerFileURL)
        try validateEncodedByteCount(UInt64(data.count))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // Backward-compatible decode: older snapshots lacked shareHistory / activeVaultID.
        let topLevel = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let hasCurrentFields = topLevel?["shareHistory"] != nil || topLevel?["activeVaultID"] != nil
        if hasCurrentFields {
            let snapshot = try decoder.decode(Snapshot.self, from: data)
            try memory.restoreSnapshot(
                vaults: snapshot.vaults,
                notes: snapshot.notes,
                history: snapshot.shareHistory,
                activeVaultID: snapshot.activeVaultID
            )
            return
        }
        struct LegacySnapshot: Codable {
            var vaults: [Vault]
            var notes: [NoteRow]
        }
        let legacy = try decoder.decode(LegacySnapshot.self, from: data)
        try memory.restoreSnapshot(
            vaults: legacy.vaults,
            notes: legacy.notes,
            history: [],
            activeVaultID: legacy.vaults.first?.id.uuid
        )
    }

    private func mutateAndPersist(_ mutation: () throws -> Void) throws {
        lock.lock()
        defer { lock.unlock() }
        let previous = memory.snapshot()
        do {
            try mutation()
            try persistLocked()
        } catch {
            memory.restoreTrustedSnapshot(
                vaults: previous.vaults,
                notes: previous.notes,
                history: previous.history,
                activeVaultID: previous.activeVaultID
            )
            throw error
        }
    }

    private func withReadLock<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    private func persistLocked() throws {
        let vaults = try memory.allVaults()
        var allNotes: [NoteRow] = []
        for vault in vaults {
            try allNotes.append(contentsOf: memory.notes(vaultID: vault.id))
        }
        let history = try memory.shareHistory()
        let active = try memory.activeVaultID()?.uuid
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let snapshot = Snapshot(
            vaults: vaults,
            notes: allNotes,
            shareHistory: history,
            activeVaultID: active
        )
        try writeSnapshotData(encoder.encode(snapshot))
    }

    private func writeSnapshotData(_ data: Data) throws {
        try validateEncodedByteCount(UInt64(data.count))

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: ledgerFileURL.path) {
            let attributes = try fileManager.attributesOfItem(atPath: ledgerFileURL.path)
            guard attributes[.type] as? FileAttributeType == .typeRegular else {
                throw SaneBooksError.persistFailed("Private ledger path is not a regular file.")
            }
        }

        let temporaryURL = rootURL.appendingPathComponent(".ledger-\(UUID().uuidString).tmp")
        defer { try? fileManager.removeItem(at: temporaryURL) }
        guard fileManager.createFile(
            atPath: temporaryURL.path,
            contents: data,
            attributes: [.posixPermissions: NSNumber(value: 0o600)]
        ) else {
            throw SaneBooksError.persistFailed("Could not create a private ledger update file.")
        }
        try enforcePermissions(0o600, at: temporaryURL)

        if fileManager.fileExists(atPath: ledgerFileURL.path) {
            _ = try fileManager.replaceItemAt(
                ledgerFileURL,
                withItemAt: temporaryURL,
                backupItemName: nil,
                options: .usingNewMetadataOnly
            )
        } else {
            try fileManager.moveItem(at: temporaryURL, to: ledgerFileURL)
        }
    }

    private func validateEncodedByteCount(_ byteCount: UInt64) throws {
        guard byteCount <= UInt64(encodedByteLimit) else {
            throw SaneBooksError.persistFailed("Private ledger exceeds the encoded-size safety limit.")
        }
    }

    private func enforcePermissions(_ permissions: Int, at url: URL) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: permissions)],
            ofItemAtPath: url.path
        )
    }

    private func excludeFromBackup(_ url: URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutable = url
        try mutable.setResourceValues(values)
    }
}
