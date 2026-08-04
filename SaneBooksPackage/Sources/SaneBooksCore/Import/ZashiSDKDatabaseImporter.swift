import Foundation

#if canImport(SQLite3)
    import SQLite3
#endif

/// Imports notes + UFVK metadata from a Zashi/Zodl/`ZcashLightClientKit` `data.db` export.
/// Does not spend; read-only SQLite access.
public enum ZashiSDKDatabaseImporter: Sendable {
    public struct Limits: Sendable, Equatable {
        public var maxDatabaseBytes: Int64
        public var maxRows: Int
        public var maxMemoBytes: Int
        public var maxAccountNameBytes: Int
        public var maxViewingKeyBytes: Int

        public init(
            maxDatabaseBytes: Int64 = 2 * 1024 * 1024 * 1024,
            maxRows: Int = 500_000,
            maxMemoBytes: Int = 512,
            maxAccountNameBytes: Int = 512,
            maxViewingKeyBytes: Int = 8192
        ) {
            self.maxDatabaseBytes = maxDatabaseBytes
            self.maxRows = maxRows
            self.maxMemoBytes = maxMemoBytes
            self.maxAccountNameBytes = maxAccountNameBytes
            self.maxViewingKeyBytes = maxViewingKeyBytes
        }

        public static let standard = Limits()
    }

    /// A local wallet database proves only what was imported through, not the network chain tip.
    public struct ImportAttestation: Sendable, Equatable {
        public var importedThroughHeight: UInt32?
        public let independentlyVerifiedChainTipHeight: UInt32? = nil
        public let isCaughtUp = false
    }

    public struct Result: Sendable {
        public var birthdayHeight: UInt32
        public var ufvk: String
        public var accountName: String
        public var notes: [NoteRow]
        public var attestation: ImportAttestation
    }

    /// The account metadata needed to select the correct local vault before a
    /// potentially large note scan begins.
    public struct AccountMetadata: Sendable, Equatable {
        public var birthdayHeight: UInt32
        public var ufvk: String
        public var accountName: String
    }

    public enum ImportError: Error, Sendable, LocalizedError {
        case openFailed(String)
        case notRegularFile
        case databaseTooLarge(actual: Int64, maximum: Int64)
        case noAccount
        case multipleAccounts(Int)
        case noUFVK
        case unsupportedSchema(String)
        case limitExceeded(String)
        case invalidData(String)
        case queryFailed(String)

        public var errorDescription: String? {
            switch self {
            case let .openFailed(message), let .queryFailed(message): message
            case .notRegularFile: "The selected Zashi database is not a regular file."
            case let .databaseTooLarge(actual, maximum):
                "The selected database is too large (\(actual) bytes; maximum \(maximum))."
            case .noAccount: "No account row in SDK database."
            case let .multipleAccounts(count):
                "This database contains \(count) accounts. Select or export a single-account database."
            case .noUFVK: "Account has no UFVK — cannot import into bookkeeper mode."
            case let .unsupportedSchema(detail): "Unsupported Zashi database schema: \(detail)"
            case let .limitExceeded(detail): "Zashi import limit exceeded: \(detail)"
            case let .invalidData(detail): "Invalid Zashi database data: \(detail)"
            }
        }
    }

    public static func importDatabase(
        at url: URL,
        vaultID: VaultID,
        limits: Limits = .standard,
        cancellation: ImportCancellation? = nil
    ) throws -> Result {
        try cancellation?.throwIfCancelled()
        try validateFile(at: url, limits: limits)

        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &db, flags, nil) == SQLITE_OK, let db else {
            if let db {
                sqlite3_close(db)
            }
            throw ImportError.openFailed("Could not open \(url.lastPathComponent)")
        }
        defer { sqlite3_close(db) }

        try execute(db: db, sql: "BEGIN DEFERRED TRANSACTION;")
        var committed = false
        defer {
            if !committed {
                sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            }
        }

        let account = try readAccount(db: db, limits: limits)
        var remainingRows = limits.maxRows
        var notes: [NoteRow] = []
        try notes.append(contentsOf: readPoolNotes(
            db: db,
            vaultID: vaultID,
            pool: .orchard,
            table: "orchard_received_notes",
            indexColumn: "action_index",
            limits: limits,
            remainingRows: &remainingRows,
            cancellation: cancellation
        ))
        try notes.append(contentsOf: readPoolNotes(
            db: db,
            vaultID: vaultID,
            pool: .sapling,
            table: "sapling_received_notes",
            indexColumn: "output_index",
            limits: limits,
            remainingRows: &remainingRows,
            cancellation: cancellation
        ))
        try notes.append(contentsOf: readPoolNotes(
            db: db,
            vaultID: vaultID,
            pool: .ironwood,
            table: "ironwood_received_notes",
            indexColumn: "action_index",
            limits: limits,
            remainingRows: &remainingRows,
            cancellation: cancellation
        ))
        try cancellation?.throwIfCancelled()
        notes.sort(by: noteSort)
        try cancellation?.throwIfCancelled()
        guard Set(notes.map(\.id)).count == notes.count else {
            throw ImportError.invalidData("duplicate transaction, pool, and output-index identity")
        }

        try execute(db: db, sql: "COMMIT;")
        committed = true
        return Result(
            birthdayHeight: account.birthdayHeight,
            ufvk: account.ufvk,
            accountName: account.accountName,
            notes: notes,
            attestation: ImportAttestation(importedThroughHeight: notes.map(\.blockHeight).max())
        )
    }

    /// Reads only bounded account metadata. Call this before the full scan so
    /// a re-import can select its vault without scanning the database twice.
    public static func inspectDatabase(
        at url: URL,
        limits: Limits = .standard,
        cancellation: ImportCancellation? = nil
    ) throws -> AccountMetadata {
        try cancellation?.throwIfCancelled()
        try validateFile(at: url, limits: limits)

        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &db, flags, nil) == SQLITE_OK, let db else {
            if let db {
                sqlite3_close(db)
            }
            throw ImportError.openFailed("Could not open \(url.lastPathComponent)")
        }
        defer { sqlite3_close(db) }

        try execute(db: db, sql: "BEGIN DEFERRED TRANSACTION;")
        var committed = false
        defer {
            if !committed {
                sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            }
        }

        let account = try readAccount(db: db, limits: limits)
        try cancellation?.throwIfCancelled()
        try execute(db: db, sql: "COMMIT;")
        committed = true
        return account
    }

    /// Preserves bookkeeping state when the same imported output is observed again.
    /// Exact stable IDs cover current imports; the unique semantic match migrates earlier index-based IDs.
    public static func mergeImportedNotesPreservingClassifications(
        existing: [NoteRow],
        imported: [NoteRow]
    ) -> [NoteRow] {
        let exact = Dictionary(grouping: existing, by: \.id)
            .compactMapValues { $0.count == 1 ? $0[0] : nil }
        let legacy = Dictionary(grouping: existing, by: LegacyIdentity.init(note:))
        let importedLegacyCounts = Dictionary(grouping: imported, by: LegacyIdentity.init(note:))
            .mapValues(\.count)

        return imported.map { importedNote in
            var merged = importedNote
            let key = LegacyIdentity(note: importedNote)
            let semanticMatches = legacy[key] ?? []
            // Require uniqueness on both sides so equal-value dual outputs in one
            // tx cannot copy one note's classification onto another.
            let uniqueSemanticRematch =
                semanticMatches.count == 1 && importedLegacyCounts[key] == 1
            guard let old = exact[importedNote.id] ?? (uniqueSemanticRematch ? semanticMatches[0] : nil) else {
                return merged
            }
            merged.classification = old.classification
            merged.suggestedClassification = old.suggestedClassification
            merged.includeInPacksByDefault = old.includeInPacksByDefault
            merged.fiatMark = old.fiatMark
            return merged
        }
    }

    private struct LegacyIdentity: Hashable {
        var txid: Data
        var blockHeight: UInt32
        var pool: ShieldedPool
        var direction: String
        var valueZatoshis: Int64

        init(note: NoteRow) {
            txid = note.txid
            blockHeight = note.blockHeight
            pool = note.pool
            direction = note.direction.rawValue
            valueZatoshis = note.valueZatoshis
        }
    }

    private static func validateFile(at url: URL, limits: Limits) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard attributes[.type] as? FileAttributeType == .typeRegular else {
            throw ImportError.notRegularFile
        }
        let sidecars = [url, URL(fileURLWithPath: url.path + "-wal"), URL(fileURLWithPath: url.path + "-shm")]
        let totalSize = try sidecars.reduce(Int64(0)) { total, candidate in
            guard FileManager.default.fileExists(atPath: candidate.path) else { return total }
            let item = try FileManager.default.attributesOfItem(atPath: candidate.path)
            let itemSize = (item[.size] as? NSNumber)?.int64Value ?? 0
            let (sum, overflow) = total.addingReportingOverflow(itemSize)
            return overflow ? Int64.max : sum
        }
        guard totalSize <= limits.maxDatabaseBytes else {
            throw ImportError.databaseTooLarge(actual: totalSize, maximum: limits.maxDatabaseBytes)
        }
    }

    private static func readAccount(db: OpaquePointer, limits: Limits) throws -> AccountMetadata {
        let accountCount = try scalarInt64(db: db, sql: "SELECT COUNT(*) FROM accounts;", schema: "accounts")
        guard accountCount > 0 else { throw ImportError.noAccount }
        guard accountCount == 1 else { throw ImportError.multipleAccounts(Int(accountCount)) }

        let sql = "SELECT COALESCE(name,'(unnamed)'), birthday_height, ufvk FROM accounts LIMIT 1;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw ImportError.unsupportedSchema("accounts: \(sqliteMessage(db))")
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { throw ImportError.noAccount }
        guard let nameBytes = sqlite3_column_text(stmt, 0) else {
            throw ImportError.invalidData("account name is unreadable")
        }
        let name = String(cString: nameBytes)
        guard name.utf8.count <= limits.maxAccountNameBytes else {
            throw ImportError.limitExceeded("account name exceeds \(limits.maxAccountNameBytes) bytes")
        }
        guard EvidenceTextPolicy.isValidIdentity(name, maximumBytes: limits.maxAccountNameBytes) else {
            throw ImportError.invalidData("account name contains unsafe control characters")
        }

        guard sqlite3_column_type(stmt, 1) != SQLITE_NULL else {
            throw ImportError.invalidData("birthday height is missing")
        }
        let birthdayValue = sqlite3_column_int64(stmt, 1)
        guard birthdayValue >= 0, birthdayValue <= Int64(UInt32.max) else {
            throw ImportError.invalidData("birthday height is outside the supported range")
        }
        guard let ufvkBytes = sqlite3_column_text(stmt, 2) else { throw ImportError.noUFVK }
        let ufvk = String(cString: ufvkBytes)
        guard ufvk.utf8.count <= limits.maxViewingKeyBytes else {
            throw ImportError.limitExceeded("viewing key exceeds \(limits.maxViewingKeyBytes) bytes")
        }
        guard ufvk.hasPrefix("uview") else { throw ImportError.noUFVK }
        return AccountMetadata(
            birthdayHeight: UInt32(birthdayValue),
            ufvk: ufvk,
            accountName: name
        )
    }

    private static func readPoolNotes(
        db: OpaquePointer,
        vaultID: VaultID,
        pool: ShieldedPool,
        table: String,
        indexColumn: String,
        limits: Limits,
        remainingRows: inout Int,
        cancellation: ImportCancellation?
    ) throws -> [NoteRow] {
        guard try tableExists(db: db, name: table) else { return [] }

        let sql = """
        SELECT o.value, o.is_change, o.\(indexColumn), o.memo,
               t.txid, t.mined_height, b.time
        FROM \(table) o
        JOIN transactions t ON t.id_tx = o.transaction_id
        LEFT JOIN blocks b ON b.height = t.mined_height
        WHERE t.mined_height IS NOT NULL;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw ImportError.unsupportedSchema("\(table): \(sqliteMessage(db))")
        }
        defer { sqlite3_finalize(stmt) }

        var output: [NoteRow] = []
        while true {
            if output.count.isMultiple(of: 64) {
                try cancellation?.throwIfCancelled()
            }
            let step = sqlite3_step(stmt)
            if step == SQLITE_DONE {
                break
            }
            guard step == SQLITE_ROW else {
                throw ImportError.queryFailed("Could not read \(table): \(sqliteMessage(db))")
            }
            guard remainingRows > 0 else {
                throw ImportError.limitExceeded("more than \(limits.maxRows) note rows")
            }
            remainingRows -= 1

            guard sqlite3_column_type(stmt, 0) != SQLITE_NULL else {
                throw ImportError.invalidData("\(table) contains a note with no value")
            }
            let value = sqlite3_column_int64(stmt, 0)
            guard value >= 0, value <= 2_100_000_000_000_000 else {
                throw ImportError.invalidData("\(table) contains an out-of-range note value")
            }
            guard sqlite3_column_type(stmt, 1) != SQLITE_NULL else {
                throw ImportError.invalidData("\(table) contains a note with no change flag")
            }
            let isChange = sqlite3_column_int(stmt, 1) != 0
            guard sqlite3_column_type(stmt, 2) != SQLITE_NULL else {
                throw ImportError.invalidData("\(table) contains a note with no output index")
            }
            let indexValue = sqlite3_column_int64(stmt, 2)
            guard indexValue >= 0, indexValue <= Int64(UInt32.max) else {
                throw ImportError.invalidData("\(table) contains an invalid output index")
            }
            let memo = try readMemo(stmt: stmt, column: 3, table: table, limits: limits)

            let txLength = Int(sqlite3_column_bytes(stmt, 4))
            guard txLength == 32, let txPointer = sqlite3_column_blob(stmt, 4) else {
                throw ImportError.invalidData("\(table) contains a malformed transaction ID")
            }
            let txid = Data(bytes: txPointer, count: txLength)
            let heightValue = sqlite3_column_int64(stmt, 5)
            guard heightValue >= 0, heightValue <= Int64(UInt32.max) else {
                throw ImportError.invalidData("\(table) contains an invalid mined height")
            }
            let blockTime: Date? = if sqlite3_column_type(stmt, 6) == SQLITE_NULL {
                nil
            } else {
                Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(stmt, 6)))
            }

            output.append(NoteRow(
                id: .stableOutput(
                    vaultID: vaultID,
                    txid: txid,
                    pool: pool,
                    outputIndex: UInt32(indexValue)
                ),
                vaultID: vaultID,
                txid: txid,
                blockHeight: UInt32(heightValue),
                blockTime: blockTime,
                pool: pool,
                direction: isChange ? .changeCandidate : .inbound,
                valueZatoshis: value,
                memo: memo
            ))
        }
        return output
    }

    private static func readMemo(
        stmt: OpaquePointer,
        column: Int32,
        table: String,
        limits: Limits
    ) throws -> MemoPayload {
        guard sqlite3_column_type(stmt, column) != SQLITE_NULL else { return .empty }
        let length = Int(sqlite3_column_bytes(stmt, column))
        guard length <= limits.maxMemoBytes else {
            throw ImportError.limitExceeded("\(table) memo exceeds \(limits.maxMemoBytes) bytes")
        }
        guard length > 0, let pointer = sqlite3_column_blob(stmt, column) else { return .empty }
        return ZIP302MemoDecoder.decode(Data(bytes: pointer, count: length))
    }

    private static func tableExists(db: OpaquePointer, name: String) throws -> Bool {
        var stmt: OpaquePointer?
        let sql = "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?1;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw ImportError.queryFailed("Could not inspect database schema: \(sqliteMessage(db))")
        }
        defer { sqlite3_finalize(stmt) }
        _ = name.withCString {
            sqlite3_bind_text(stmt, 1, $0, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    private static func scalarInt64(db: OpaquePointer, sql: String, schema: String) throws -> Int64 {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw ImportError.unsupportedSchema("\(schema): \(sqliteMessage(db))")
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw ImportError.queryFailed("Could not read \(schema)")
        }
        return sqlite3_column_int64(stmt, 0)
    }

    private static func execute(db: OpaquePointer, sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? sqliteMessage(db)
            sqlite3_free(error)
            throw ImportError.queryFailed(message)
        }
    }

    private static func sqliteMessage(_ db: OpaquePointer) -> String {
        String(cString: sqlite3_errmsg(db))
    }

    private static func noteSort(_ lhs: NoteRow, _ rhs: NoteRow) -> Bool {
        if lhs.blockHeight != rhs.blockHeight {
            return lhs.blockHeight > rhs.blockHeight
        }
        if lhs.txid != rhs.txid {
            return lhs.txid.lexicographicallyPrecedes(rhs.txid)
        }
        if lhs.pool != rhs.pool {
            return lhs.pool.rawValue < rhs.pool.rawValue
        }
        return lhs.id.uuid.uuidString < rhs.id.uuid.uuidString
    }
}
