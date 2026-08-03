import Foundation
import SaneBooksCore

public enum PackBuilder {
    public static func buildDraft(
        vault: Vault,
        notes: [NoteRow],
        rangeStart: Date,
        rangeEnd: Date,
        includedKinds: Set<ClassificationKind>,
        includeMemos: Bool,
        includeChange: Bool,
        excludeTags: [String],
        cursor: SyncCursor?,
        recipientLabel: String?,
        expiresAt: Date
    ) -> ProofPackDraft {
        let filtered = notes.filter { note in
            guard let date = note.blockTime else { return false }
            guard date >= rangeStart, date <= rangeEnd else { return false }
            let kind = note.effectiveKind
            if kind == .change, !includeChange {
                return false
            }
            if kind == .untagged {
                return false
            }
            guard includedKinds.contains(kind) else { return false }
            if let party = note.classification?.party,
               excludeTags.contains(where: { $0.caseInsensitiveCompare(party) == .orderedSame }) {
                return false
            }
            if let sub = note.classification?.subtag,
               excludeTags.contains(where: { $0.caseInsensitiveCompare(sub) == .orderedSame }) {
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
                memoText: includeMemos ? note.memo.displayText : nil,
                pool: note.pool,
                txidTruncated: note.txidTruncated
            )
        }

        var byCategory: [String: Decimal] = [:]
        for row in rows where row.kind == .income || row.kind == .expense {
            let key = row.subtag ?? row.party ?? row.kind.displayName
            byCategory[key, default: 0] += row.amountZEC
        }

        let rollups = ProofPackRollups(
            incomeZEC: rows.filter { $0.kind == .income }.reduce(0) { $0 + $1.amountZEC },
            expenseZEC: rows.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amountZEC },
            feeZEC: rows.filter { $0.kind == .fee }.reduce(0) { $0 + $1.amountZEC },
            incomeFiat: rows.filter { $0.kind == .income }.compactMap(\.amountFiat).reduce(0, +),
            expenseFiat: rows.filter { $0.kind == .expense }.compactMap(\.amountFiat).reduce(0, +),
            fiatCurrency: "USD",
            byCategory: byCategory
        )

        let attestation = SyncAttestation(
            syncedToHeight: cursor?.scannedThroughHeight ?? 0,
            chainTipAtExport: cursor?.chainTipHeight,
            lwdEndpointFingerprint: cursor.map { String($0.lwdURL.host ?? "unknown") } ?? "demo",
            vaultMode: vault.mode,
            poolsPresent: Array(cursor?.poolsSynced ?? [.sapling, .orchard, .ironwood]),
            ironwoodCapable: cursor?.capabilityReport.supportsIronwood ?? false
        )

        let partial = Self.isPartialHistory(cursor: cursor)
        return ProofPackDraft(
            vaultFingerprint: vault.keyFingerprint,
            vaultDisplayName: vault.displayName,
            network: vault.network,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            includedKinds: includedKinds,
            excludeTags: excludeTags,
            includeMemos: includeMemos,
            includeChange: includeChange,
            rows: rows,
            rollups: rollups,
            syncAttestation: attestation,
            partialHistory: partial,
            acknowledgePartialHistory: false,
            recipientLabel: recipientLabel,
            expiresAt: expiresAt,
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

    /// Seal a draft into `.sanebooks` bytes (HKDF-SHA256 + ChaCha20-Poly1305).
    public static func build(
        draft: ProofPackDraft,
        passphrase: String,
        salt: Data? = nil,
        nonceData: Data? = nil
    ) throws -> Data {
        if let salt, let nonceData {
            return try PackWriter.seal(
                draft: draft,
                passphrase: passphrase,
                salt: salt,
                nonceData: nonceData
            ).data
        }
        let encoded = try PackWriter.seal(draft: draft, passphrase: passphrase)
        try PackBuilder.assertNoUVKMaterial(in: encoded.data)
        return encoded.data
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
