import Foundation

#if canImport(SQLite3)
    import SQLite3
#endif

/// Imports notes + UFVK metadata from a Zashi/Zodl/`ZcashLightClientKit` `data.db` export.
/// Does not spend; read-only SQLite access.
public enum ZashiSDKDatabaseImporter: Sendable {
    public struct Result: Sendable {
        public var birthdayHeight: UInt32
        public var ufvk: String
        public var accountName: String
        public var notes: [NoteRow]
    }

    public enum ImportError: Error, Sendable, LocalizedError {
        case openFailed(String)
        case noAccount
        case noUFVK
        case queryFailed(String)

        public var errorDescription: String? {
            switch self {
            case let .openFailed(m), let .queryFailed(m): m
            case .noAccount: "No account row in SDK database."
            case .noUFVK: "Account has no UFVK — cannot import into bookkeeper mode."
            }
        }
    }

    public static func importDatabase(at url: URL, vaultID: VaultID) throws -> Result {
        var db: OpaquePointer?
        let path = url.path
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            throw ImportError.openFailed("Could not open \(url.lastPathComponent)")
        }
        defer { sqlite3_close(db) }

        let (name, birthday, ufvk) = try readAccount(db: db)
        var drafts: [NoteRowDraft] = []
        try drafts.append(contentsOf: readOrchardNotes(db: db, vaultID: vaultID))
        try drafts.append(contentsOf: readSaplingNotes(db: db, vaultID: vaultID))
        try drafts.append(contentsOf: readIronwoodNotes(db: db, vaultID: vaultID))
        drafts.sort { lhs, rhs in
            if lhs.blockHeight != rhs.blockHeight {
                return lhs.blockHeight > rhs.blockHeight
            }
            return lhs.valueZatoshis > rhs.valueZatoshis
        }
        let notes = drafts.enumerated().map { index, draft in
            draft.asNoteRow(stableIndex: index)
        }
        return Result(
            birthdayHeight: birthday,
            ufvk: ufvk,
            accountName: name,
            notes: notes
        )
    }

    // MARK: - Private

    private static func readAccount(db: OpaquePointer) throws -> (String, UInt32, String) {
        let sql = """
        SELECT COALESCE(name,'(unnamed)'), birthday_height, ufvk
        FROM accounts LIMIT 1;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw ImportError.queryFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { throw ImportError.noAccount }
        let name = String(cString: sqlite3_column_text(stmt, 0))
        let birthday = UInt32(sqlite3_column_int64(stmt, 0 + 1))
        guard let ufvkC = sqlite3_column_text(stmt, 2) else { throw ImportError.noUFVK }
        let ufvk = String(cString: ufvkC)
        guard ufvk.hasPrefix("uview") else { throw ImportError.noUFVK }
        return (name, birthday, ufvk)
    }

    private static func readOrchardNotes(db: OpaquePointer, vaultID: VaultID) throws -> [NoteRowDraft] {
        try readPoolNotes(
            db: db,
            vaultID: vaultID,
            pool: .orchard,
            table: "orchard_received_notes",
            indexColumn: "action_index"
        )
    }

    private static func readSaplingNotes(db: OpaquePointer, vaultID: VaultID) throws -> [NoteRowDraft] {
        // Sapling uses output_index in some schema versions; try action-compatible query via shared shape.
        try readPoolNotes(
            db: db,
            vaultID: vaultID,
            pool: .sapling,
            table: "sapling_received_notes",
            indexColumn: "output_index"
        )
    }

    private static func readIronwoodNotes(db: OpaquePointer, vaultID: VaultID) throws -> [NoteRowDraft] {
        try readPoolNotes(
            db: db,
            vaultID: vaultID,
            pool: .ironwood,
            table: "ironwood_received_notes",
            indexColumn: "action_index"
        )
    }

    private static func readPoolNotes(
        db: OpaquePointer,
        vaultID: VaultID,
        pool: ShieldedPool,
        table: String,
        indexColumn: String
    ) throws -> [NoteRowDraft] {
        // Table may be empty or absent on older DBs.
        var existsStmt: OpaquePointer?
        let existsSQL = "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?1;"
        guard sqlite3_prepare_v2(db, existsSQL, -1, &existsStmt, nil) == SQLITE_OK, let existsStmt else {
            return []
        }
        defer { sqlite3_finalize(existsStmt) }
        table.withCString { sqlite3_bind_text(existsStmt, 1, $0, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
        guard sqlite3_step(existsStmt) == SQLITE_ROW else { return [] }

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
            // Column name mismatch — skip pool rather than fail whole import.
            return []
        }
        defer { sqlite3_finalize(stmt) }

        var out: [NoteRowDraft] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let value = sqlite3_column_int64(stmt, 0)
            let isChange = sqlite3_column_int(stmt, 1) != 0
            let index = Int(sqlite3_column_int(stmt, 2))
            let memo: MemoPayload = {
                if sqlite3_column_type(stmt, 3) == SQLITE_NULL {
                    return .empty
                }
                let len = Int(sqlite3_column_bytes(stmt, 3))
                guard len > 0, let ptr = sqlite3_column_blob(stmt, 3) else { return .empty }
                let data = Data(bytes: ptr, count: len)
                return ZIP302MemoDecoder.decode(data)
            }()
            let txLen = Int(sqlite3_column_bytes(stmt, 4))
            guard txLen > 0, let txPtr = sqlite3_column_blob(stmt, 4) else { continue }
            let txid = Data(bytes: txPtr, count: txLen)
            let height = UInt32(sqlite3_column_int64(stmt, 5))
            let blockTime: Date? = {
                if sqlite3_column_type(stmt, 6) == SQLITE_NULL {
                    return nil
                }
                return Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(stmt, 6)))
            }()

            var idMaterial = txid
            idMaterial.append(contentsOf: withUnsafeBytes(of: UInt32(index).bigEndian) { Array($0) })
            idMaterial.append(contentsOf: Array(pool.rawValue.utf8))

            out.append(
                NoteRowDraft(
                    vaultID: vaultID,
                    txid: txid,
                    blockHeight: height,
                    blockTime: blockTime,
                    pool: pool,
                    direction: isChange ? .changeCandidate : .inbound,
                    valueZatoshis: value,
                    memo: memo
                )
            )
        }
        return out
    }
}
