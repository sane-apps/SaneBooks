import Foundation

/// Shared boundary for text that becomes an accounting label or exported evidence.
/// Directional/zero-width controls are rejected instead of being allowed to spoof
/// names, rows, CSV cells, or PDF labels while leaving normal Unicode intact.
public enum EvidenceTextPolicy {
    public static let maximumIdentityBytes = 512
    public static let maximumMemoBytes = 4 * 1024

    public static func isValidIdentity(
        _ value: String,
        maximumBytes: Int = maximumIdentityBytes
    ) -> Bool {
        value.utf8.count <= maximumBytes
            && !value.unicodeScalars.contains(where: { isForbidden($0.value, allowMemoWhitespace: false) })
    }

    public static func isValidMemo(
        _ value: String,
        maximumBytes: Int = maximumMemoBytes
    ) -> Bool {
        value.utf8.count <= maximumBytes
            && !value.unicodeScalars.contains(where: { isForbidden($0.value, allowMemoWhitespace: true) })
    }

    private static func isForbidden(_ scalar: UInt32, allowMemoWhitespace: Bool) -> Bool {
        if allowMemoWhitespace, scalar == 0x09 || scalar == 0x0A || scalar == 0x0D {
            return false
        }
        if scalar < 0x20 || (0x7F ... 0x9F).contains(scalar) {
            return true
        }
        return scalar == 0x061C
            || (0x200B ... 0x200F).contains(scalar)
            || (0x202A ... 0x202E).contains(scalar)
            || (0x2060 ... 0x206F).contains(scalar)
            || scalar == 0xFEFF
    }
}

public struct NoteRowID: Hashable, Codable, Sendable {
    public let uuid: UUID

    public init(uuid: UUID = UUID()) {
        self.uuid = uuid
    }

    /// Stable id so mock/re-sync does not stack duplicate rows for the same tx.
    public static func stable(vaultID: VaultID, txid: Data) -> NoteRowID {
        var bytes: [UInt8] = []
        bytes.append(contentsOf: withUnsafeBytes(of: vaultID.uuid.uuid) { Array($0) })
        bytes.append(contentsOf: [UInt8](txid))
        // FNV-1a 128-bit style fold — distinct for nearby fixture txids.
        var h1: UInt64 = 0xCBF2_9CE4_8422_2325
        var h2: UInt64 = 0x100_0000_01B3
        for (i, b) in bytes.enumerated() {
            h1 ^= UInt64(b)
            h1 = h1 &* 0x100_0000_01B3
            h2 ^= UInt64(b) &+ UInt64(i)
            h2 = h2 &* 0xCBF2_9CE4_8422_2325
        }
        let uuid = UUID(uuid: (
            UInt8(truncatingIfNeeded: h1 >> 56),
            UInt8(truncatingIfNeeded: h1 >> 48),
            UInt8(truncatingIfNeeded: h1 >> 40),
            UInt8(truncatingIfNeeded: h1 >> 32),
            UInt8(truncatingIfNeeded: h1 >> 24),
            UInt8(truncatingIfNeeded: h1 >> 16),
            UInt8(truncatingIfNeeded: h1 >> 8),
            UInt8(truncatingIfNeeded: h1),
            UInt8(truncatingIfNeeded: h2 >> 56),
            UInt8(truncatingIfNeeded: h2 >> 48),
            UInt8(truncatingIfNeeded: h2 >> 40),
            UInt8(truncatingIfNeeded: h2 >> 32),
            UInt8(truncatingIfNeeded: h2 >> 24),
            UInt8(truncatingIfNeeded: h2 >> 16),
            UInt8(truncatingIfNeeded: h2 >> 8),
            UInt8(truncatingIfNeeded: h2)
        ))
        return NoteRowID(uuid: uuid)
    }

    /// Canonical identity for a shielded output across database import and live SDK sync.
    /// Pool is part of the identity because pool-specific output indexes can overlap.
    public static func stableOutput(
        vaultID: VaultID,
        txid: Data,
        pool: ShieldedPool,
        outputIndex: UInt32
    ) -> NoteRowID {
        var material = txid
        material.append(0)
        material.append(contentsOf: pool.rawValue.utf8)
        material.append(0)
        material.append(contentsOf: withUnsafeBytes(of: outputIndex.bigEndian) { Array($0) })
        return .stable(vaultID: vaultID, txid: material)
    }
}

public enum ShieldedPool: String, Codable, Sendable, Hashable, CaseIterable {
    case sapling
    case orchard
    case ironwood
    case transparent

    public var displayName: String {
        switch self {
        case .sapling: "Sapling"
        case .orchard: "Orchard"
        case .ironwood: "Ironwood"
        case .transparent: "Transparent"
        }
    }
}

public enum NoteDirection: String, Codable, Sendable {
    case inbound
    case outbound
    case changeCandidate

    public var displayName: String {
        switch self {
        case .inbound: "Received (shielded)"
        case .outbound: "Sent (shielded)"
        case .changeCandidate: "Change candidate"
        }
    }
}

public struct NoteRow: Identifiable, Codable, Sendable, Equatable {
    public var id: NoteRowID
    public var vaultID: VaultID
    public var txid: Data
    public var blockHeight: UInt32
    public var blockTime: Date?
    public var pool: ShieldedPool
    public var direction: NoteDirection
    public var valueZatoshis: Int64
    public var memo: MemoPayload
    public var nullifier: Data?
    public var noteCommitment: Data?
    public var suggestedClassification: ClassificationKind?
    public var classification: Classification?
    public var includeInPacksByDefault: Bool
    public var syncObservedAt: Date
    public var fiatMark: FiatMark?

    public init(
        id: NoteRowID = NoteRowID(),
        vaultID: VaultID,
        txid: Data,
        blockHeight: UInt32,
        blockTime: Date? = nil,
        pool: ShieldedPool,
        direction: NoteDirection,
        valueZatoshis: Int64,
        memo: MemoPayload = .empty,
        nullifier: Data? = nil,
        noteCommitment: Data? = nil,
        suggestedClassification: ClassificationKind? = nil,
        classification: Classification? = nil,
        includeInPacksByDefault: Bool = true,
        syncObservedAt: Date = Date(),
        fiatMark: FiatMark? = nil
    ) {
        self.id = id
        self.vaultID = vaultID
        self.txid = txid
        self.blockHeight = blockHeight
        self.blockTime = blockTime
        self.pool = pool
        self.direction = direction
        self.valueZatoshis = valueZatoshis
        self.memo = memo
        self.nullifier = nullifier
        self.noteCommitment = noteCommitment
        self.suggestedClassification = suggestedClassification
        self.classification = classification
        self.includeInPacksByDefault = includeInPacksByDefault
        self.syncObservedAt = syncObservedAt
        self.fiatMark = fiatMark
    }

    public var effectiveKind: ClassificationKind {
        classification?.kind ?? suggestedClassification ?? .untagged
    }

    public var amountZEC: Decimal {
        Decimal(valueZatoshis) / Decimal(100_000_000)
    }

    public var txidHex: String {
        txid.map { String(format: "%02x", $0) }.joined()
    }

    public var txidTruncated: String {
        let hex = txidHex
        guard hex.count > 16 else { return hex }
        return String(hex.prefix(8)) + "…" + String(hex.suffix(8))
    }
}

public struct NoteRowDraft: Codable, Sendable, Equatable {
    public var vaultID: VaultID
    public var txid: Data
    public var blockHeight: UInt32
    public var blockTime: Date?
    public var pool: ShieldedPool
    public var direction: NoteDirection
    public var valueZatoshis: Int64
    public var memo: MemoPayload
    public var nullifier: Data?
    public var noteCommitment: Data?

    public init(
        vaultID: VaultID,
        txid: Data,
        blockHeight: UInt32,
        blockTime: Date? = nil,
        pool: ShieldedPool,
        direction: NoteDirection,
        valueZatoshis: Int64,
        memo: MemoPayload = .empty,
        nullifier: Data? = nil,
        noteCommitment: Data? = nil
    ) {
        self.vaultID = vaultID
        self.txid = txid
        self.blockHeight = blockHeight
        self.blockTime = blockTime
        self.pool = pool
        self.direction = direction
        self.valueZatoshis = valueZatoshis
        self.memo = memo
        self.nullifier = nullifier
        self.noteCommitment = noteCommitment
    }

    public func asNoteRow(stableIndex: Int = 0) -> NoteRow {
        return NoteRow(
            id: .stableOutput(
                vaultID: vaultID,
                txid: txid,
                pool: pool,
                outputIndex: UInt32(clamping: stableIndex)
            ),
            vaultID: vaultID,
            txid: txid,
            blockHeight: blockHeight,
            blockTime: blockTime,
            pool: pool,
            direction: direction,
            valueZatoshis: valueZatoshis,
            memo: memo,
            nullifier: nullifier,
            noteCommitment: noteCommitment
        )
    }
}
