import Foundation

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
}

public final class InMemoryLedgerStore: LedgerStore, @unchecked Sendable {
    private let lock = NSLock()
    private var vaults: [UUID: Vault] = [:]
    private var notes: [UUID: NoteRow] = [:]
    private var history: [ShareHistoryEntry] = []
    private var activeID: UUID?

    public init() {}

    public func upsertVault(_ vault: Vault) throws {
        lock.lock(); defer { lock.unlock() }
        vaults[vault.id.uuid] = vault
        if activeID == nil {
            activeID = vault.id.uuid
        }
    }

    public func vault(id: VaultID) throws -> Vault? {
        lock.lock(); defer { lock.unlock() }
        return vaults[id.uuid]
    }

    public func allVaults() throws -> [Vault] {
        lock.lock(); defer { lock.unlock() }
        return Array(vaults.values).sorted { $0.createdAt < $1.createdAt }
    }

    public func deleteVault(id: VaultID) throws {
        lock.lock(); defer { lock.unlock() }
        vaults.removeValue(forKey: id.uuid)
        notes = notes.filter { $0.value.vaultID != id }
        if activeID == id.uuid {
            activeID = vaults.keys.first
        }
    }

    public func upsertNotes(_ notes: [NoteRow]) throws {
        lock.lock(); defer { lock.unlock() }
        for note in notes {
            // Drop older clones of the same vault+txid (mock sync used to mint new UUIDs).
            let stale = self.notes.filter {
                $0.value.vaultID == note.vaultID
                    && $0.value.txid == note.txid
                    && $0.key != note.id.uuid
            }
            for item in stale {
                self.notes.removeValue(forKey: item.key)
            }
            self.notes[note.id.uuid] = note
        }
    }

    public func replaceNotes(vaultID: VaultID, with notes: [NoteRow]) throws {
        lock.lock(); defer { lock.unlock() }
        self.notes = self.notes.filter { $0.value.vaultID != vaultID }
        for note in notes {
            self.notes[note.id.uuid] = note
        }
    }

    public func notes(vaultID: VaultID) throws -> [NoteRow] {
        lock.lock(); defer { lock.unlock() }
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
        lock.lock(); defer { lock.unlock() }
        guard var note = notes[noteID.uuid] else {
            throw SaneBooksError.ledger("Unknown note \(noteID.uuid)")
        }
        note.classification = classification
        notes[noteID.uuid] = note
    }

    public func appendShareHistory(_ entry: ShareHistoryEntry) throws {
        lock.lock(); defer { lock.unlock() }
        history.insert(entry, at: 0)
    }

    public func shareHistory() throws -> [ShareHistoryEntry] {
        lock.lock(); defer { lock.unlock() }
        return history
    }

    public func setActiveVaultID(_ id: VaultID?) throws {
        lock.lock(); defer { lock.unlock() }
        activeID = id?.uuid
    }

    public func activeVaultID() throws -> VaultID? {
        lock.lock(); defer { lock.unlock() }
        return activeID.map { VaultID(uuid: $0) }
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
        lock.lock()
        self.vaults = [:]
        self.notes = [:]
        self.history = history
        activeID = activeVaultID
        lock.unlock()
        for vault in vaults {
            try upsertVault(vault)
        }
        try upsertNotes(notes)
        if let activeVaultID {
            try setActiveVaultID(VaultID(uuid: activeVaultID))
        }
    }
}

/// File-backed JSON under Application Support/SaneBooks/. UVK never written — fingerprint only.
public final class FileLedgerStore: LedgerStore, @unchecked Sendable {
    private let lock = NSLock()
    private let rootURL: URL
    private var memory = InMemoryLedgerStore()

    private struct Snapshot: Codable {
        var vaults: [Vault]
        var notes: [NoteRow]
        var shareHistory: [ShareHistoryEntry]
        var activeVaultID: UUID?
    }

    public init(rootURL: URL? = nil) throws {
        if let rootURL {
            self.rootURL = rootURL
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.rootURL = support.appendingPathComponent("SaneBooks", isDirectory: true)
        }
        try FileManager.default.createDirectory(at: self.rootURL, withIntermediateDirectories: true)
        try excludeFromBackup(self.rootURL)
        try loadFromDisk()
    }

    public var ledgerFileURL: URL {
        rootURL.appendingPathComponent("ledger.json")
    }

    public func upsertVault(_ vault: Vault) throws {
        try memory.upsertVault(vault)
        try persist()
    }

    public func vault(id: VaultID) throws -> Vault? {
        try memory.vault(id: id)
    }

    public func allVaults() throws -> [Vault] {
        try memory.allVaults()
    }

    public func deleteVault(id: VaultID) throws {
        try memory.deleteVault(id: id)
        try persist()
    }

    public func upsertNotes(_ notes: [NoteRow]) throws {
        try memory.upsertNotes(notes)
        try persist()
    }

    public func replaceNotes(vaultID: VaultID, with notes: [NoteRow]) throws {
        try memory.replaceNotes(vaultID: vaultID, with: notes)
        try persist()
    }

    public func notes(vaultID: VaultID) throws -> [NoteRow] {
        try memory.notes(vaultID: vaultID)
    }

    public func upsertClassification(noteID: NoteRowID, classification: Classification) throws {
        try memory.upsertClassification(noteID: noteID, classification: classification)
        try persist()
    }

    public func appendShareHistory(_ entry: ShareHistoryEntry) throws {
        try memory.appendShareHistory(entry)
        try persist()
    }

    public func shareHistory() throws -> [ShareHistoryEntry] {
        try memory.shareHistory()
    }

    public func setActiveVaultID(_ id: VaultID?) throws {
        try memory.setActiveVaultID(id)
        try persist()
    }

    public func activeVaultID() throws -> VaultID? {
        try memory.activeVaultID()
    }

    private func loadFromDisk() throws {
        guard FileManager.default.fileExists(atPath: ledgerFileURL.path) else { return }
        let data = try Data(contentsOf: ledgerFileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // Backward-compatible decode: older snapshots lacked shareHistory / activeVaultID.
        if let snapshot = try? decoder.decode(Snapshot.self, from: data) {
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

    private func persist() throws {
        lock.lock(); defer { lock.unlock() }
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
        try encoder.encode(snapshot).write(to: ledgerFileURL, options: .atomic)
    }

    private func excludeFromBackup(_ url: URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutable = url
        try mutable.setResourceValues(values)
    }
}
