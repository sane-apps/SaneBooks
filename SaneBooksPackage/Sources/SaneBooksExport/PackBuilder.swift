import Foundation
import SaneBooksCore

public struct PackDraftOptions: Sendable {
    public var rangeStart: Date
    public var rangeEnd: Date
    public var includedKinds: Set<ClassificationKind>
    public var includeMemos: Bool
    public var includeChange: Bool
    public var excludeTags: [String]
    public var recipientLabel: String?
    public var expiresAt: Date

    public init(
        rangeStart: Date,
        rangeEnd: Date,
        includedKinds: Set<ClassificationKind>,
        includeMemos: Bool,
        includeChange: Bool,
        excludeTags: [String],
        recipientLabel: String?,
        expiresAt: Date
    ) {
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        self.includedKinds = includedKinds
        self.includeMemos = includeMemos
        self.includeChange = includeChange
        self.excludeTags = excludeTags
        self.recipientLabel = recipientLabel
        self.expiresAt = expiresAt
    }
}

public enum PackBuilder {
    public static func buildDraft(
        vault: Vault,
        notes: [NoteRow],
        options: PackDraftOptions,
        cursor: SyncCursor?
    ) -> ProofPackDraft {
        let filtered = notes.filter { note in
            guard let date = note.blockTime else { return false }
            guard date >= options.rangeStart, date <= options.rangeEnd else { return false }
            let kind = note.effectiveKind
            if kind == .change, !options.includeChange {
                return false
            }
            if kind == .untagged {
                return false
            }
            guard options.includedKinds.contains(kind) else { return false }
            if let party = note.classification?.party,
               options.excludeTags.contains(where: { $0.caseInsensitiveCompare(party) == .orderedSame })
            {
                return false
            }
            if let sub = note.classification?.subtag,
               options.excludeTags.contains(where: { $0.caseInsensitiveCompare(sub) == .orderedSame })
            {
                return false
            }
            return note.includeInPacksByDefault
        }

        let rows: [ProofPackRow] = filtered.map { note in
            let zec = abs(note.amountZEC)
            return ProofPackRow(
                date: note.blockTime ?? Date(),
                kind: note.effectiveKind,
                party: note.classification?.party,
                subtag: note.classification?.subtag,
                amountZEC: zec,
                amountFiat: note.fiatMark?.amount(forZEC: zec),
                fiatMark: note.fiatMark,
                memoText: options.includeMemos ? note.memo.displayText : nil,
                pool: note.pool,
                txidTruncated: note.txidTruncated
            )
        }

        let rollups = PackSemanticValidator.rollups(for: rows, fiatCurrency: "USD")

        let attestation = SyncAttestation(
            syncedToHeight: cursor?.scannedThroughHeight ?? 0,
            chainTipAtExport: cursor?.chainTipHeight,
            lwdEndpointFingerprint: cursor.map { String($0.lwdURL.host ?? "unknown") } ?? "demo",
            vaultMode: vault.mode,
            poolsPresent: Array(Set(rows.map(\.pool))).sorted { $0.rawValue < $1.rawValue },
            ironwoodCapable: cursor?.capabilityReport.supportsIronwood ?? false
        )

        let partial = Self.isPartialHistory(cursor: cursor)
        return ProofPackDraft(
            vaultFingerprint: vault.keyFingerprint,
            vaultDisplayName: vault.displayName,
            network: vault.network,
            rangeStart: options.rangeStart,
            rangeEnd: options.rangeEnd,
            includedKinds: options.includedKinds,
            excludeTags: options.excludeTags,
            includeMemos: options.includeMemos,
            includeChange: options.includeChange,
            rows: rows,
            rollups: rollups,
            syncAttestation: attestation,
            partialHistory: partial,
            acknowledgePartialHistory: false,
            recipientLabel: options.recipientLabel,
            expiresAt: options.expiresAt,
            vaultMode: vault.mode
        )
    }

    /// Honest incompleteness: not caught up, capability blocked, or demo ledger.
    public static func isPartialHistory(cursor: SyncCursor?) -> Bool {
        guard let cursor else { return true }
        if cursor.status != .caughtUp {
            return true
        }
        if cursor.status == .capabilityBlocked {
            return true
        }
        if cursor.isDemo {
            return true
        }
        if !cursor.capabilityReport.mainnetSafe, cursor.capabilityReport.supportsIronwood == false {
            return true
        }
        return false
    }

    /// Seal a draft into `.sanebooks` bytes (PBKDF2-HMAC-SHA256 + ChaCha20-Poly1305).
    public static func build(
        draft: ProofPackDraft,
        passphrase: String
    ) throws -> Data {
        let encoded = try PackWriter.seal(draft: draft, passphrase: passphrase)
        try PackBuilder.assertNoUVKMaterial(in: encoded.data)
        return encoded.data
    }

    /// Deterministic crypto inputs stay internal to the module test surface.
    static func build(
        draft: ProofPackDraft,
        passphrase: String,
        salt: Data,
        nonceData: Data
    ) throws -> Data {
        try PackWriter.seal(
            draft: draft,
            passphrase: passphrase,
            salt: salt,
            nonceData: nonceData
        ).data
    }

    public static func assertNoUVKMaterial(in pack: Data) throws {
        let needles = ["secret-extended-key", "secret-sharing-key", "uview1qqq", "uivk1qqq"].map { Array($0.utf8) }
        let bytes = [UInt8](pack)
        for needle in needles {
            guard bytes.count >= needle.count else { continue }
            outer: for i in 0 ... (bytes.count - needle.count) {
                for j in 0 ..< needle.count where bytes[i + j] != needle[j] {
                    continue outer
                }
                throw SaneBooksError.pack("UVK-like material leaked into pack bytes")
            }
        }
    }
}
