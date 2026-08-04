import CryptoKit
import Foundation
import SaneBooksCore
import SaneBooksExport
import SaneBooksSync

@MainActor
public extension AppModel {
    // MARK: - Tag rules

    func saveTagRules(_ rules: [TagRule]) {
        guard var vault else { return }
        vault.tagRules = rules
        do {
            try store.upsertVault(vault)
            self.vault = vault
            vaults = try store.allVaults()
            notes = ClassificationEngine.applyRules(rules, to: notes)
            try store.upsertNotes(notes)
            notes = try store.notes(vaultID: vault.id)
        } catch {
            importError = error.localizedDescription
        }
    }

    func addTagRule(_ rule: TagRule) {
        guard let vault else { return }
        var rules = vault.tagRules
        rules.append(rule)
        saveTagRules(rules)
    }

    func deleteTagRule(id: UUID) {
        guard let vault else { return }
        saveTagRules(vault.tagRules.filter { $0.id != id })
    }

    // MARK: - Ledger

    var filteredNotes: [NoteRow] {
        let query = filters.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return notes.filter { note in
            if filters.untaggedOnly, note.effectiveKind != .untagged {
                return false
            }
            if let kind = filters.kind, note.effectiveKind != kind {
                return false
            }
            if let year = filters.year, let date = note.blockTime {
                if Calendar.current.component(.year, from: date) != year {
                    return false
                }
            }
            if !query.isEmpty {
                let searchable = [
                    note.memo.displayText,
                    note.classification?.party,
                    note.classification?.subtag,
                    note.txidTruncated,
                ]
                .compactMap(\.self)
                let matched = searchable.contains {
                    $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
                }
                if !matched {
                    return false
                }
            }
            return true
        }
    }

    var untaggedCount: Int {
        notes.reduce(into: 0) { count, note in
            if note.effectiveKind == .untagged {
                count += 1
            }
        }
    }

    /// Focus the untagged review queue (filter + open first untagged row).
    func beginUntaggedReview() {
        filters.untaggedOnly = true
        filters.kind = nil
        if let first = notes.first(where: { $0.effectiveKind == .untagged }) {
            openNote(first.id)
        }
    }

    /// After tagging a note, open the next untagged row (or return to filtered ledger).
    func advanceUntaggedReview(after savedID: NoteRowID? = nil) {
        filters.untaggedOnly = true
        if let next = notes.first(where: { note in
            note.effectiveKind == .untagged && note.id != savedID
        }) {
            openNote(next.id)
        } else {
            route = .ledger
        }
    }

    var incomeYTD: Decimal {
        ClassificationEngine.incomeYTD(notes: notes, year: Calendar.current.component(.year, from: Date()))
    }

    var expenseYTD: Decimal {
        ClassificationEngine.expenseYTD(notes: notes, year: Calendar.current.component(.year, from: Date()))
    }

    var showsIVKUpgradeBanner: Bool {
        guard let vault else { return false }
        return VaultModeBanner.shouldShowUpgradeBanner(mode: vault.mode)
    }

    func openNote(_ id: NoteRowID) {
        route = .noteDetail(id)
    }

    func selectedNote(_ id: NoteRowID) -> NoteRow? {
        notes.first { $0.id == id }
    }

    func saveNote(_ note: NoteRow, advanceUntaggedQueue: Bool = false) {
        guard let vault else { return }
        var updated = note
        if var classification = updated.classification {
            let identityFields = [classification.party, classification.subtag].compactMap(\.self)
            guard identityFields.allSatisfy({ EvidenceTextPolicy.isValidIdentity($0) }),
                  classification.notes.map({ EvidenceTextPolicy.isValidMemo($0) }) ?? true
            else {
                importError = "Party, subtag, or notes contain unsafe controls or exceed the evidence limit."
                return
            }
            classification.updatedAt = Date()
            classification.source = .user
            updated.classification = classification
        }
        if case let .text(memo) = updated.memo, !EvidenceTextPolicy.isValidMemo(memo) {
            importError = "Memo contains unsafe controls or exceeds the 4 KB evidence limit."
            return
        }
        do {
            try store.upsertNotes([updated])
            notes = try store.notes(vaultID: vault.id)
            if advanceUntaggedQueue, filters.untaggedOnly {
                advanceUntaggedReview(after: updated.id)
            } else {
                route = .ledger
            }
        } catch {
            importError = error.localizedDescription
        }
    }

    // MARK: - Proof packs

    func beginProofPack() {
        guard vault != nil else { return }
        packDraft = nil
        acknowledgePartialHistory = false
        clearLastExportReceipt()
        route = .proofPackBuilder
    }

    func clearLastExportReceipt() {
        lastIntegrityHash = nil
        lastSavedPackURL = nil
    }

    func setPackDraft(_ draft: ProofPackDraft) {
        packDraft = draft
    }

    func proceedToSharePack() {
        route = .sharePack
    }

    func recordShareHistory(
        format: ShareExportFormat,
        integrityHash: String?,
        rowCount: Int,
        expiresAt: Date?
    ) {
        guard let draft = packDraft else { return }
        let entry = ShareHistoryEntry(
            expiresAt: expiresAt,
            recipientLabel: draft.recipientLabel,
            rangeStart: draft.rangeStart,
            rangeEnd: draft.rangeEnd,
            integrityHash: integrityHash,
            format: format,
            rowCount: rowCount,
            vaultFingerprint: draft.vaultFingerprint
        )
        do {
            try store.appendShareHistory(entry)
            shareHistory = try store.shareHistory()
        } catch {
            importError = error.localizedDescription
        }
    }

    func savePack(passphrase: String, to url: URL) throws {
        guard var draft = packDraft else { throw SaneBooksError.pack("No pack draft") }
        draft.acknowledgePartialHistory = acknowledgePartialHistory
        packDraft = draft
        let encoded = try PackWriter.seal(draft: draft, passphrase: passphrase)
        try encoded.data.write(to: url, options: .atomic)
        let fileHash = Self.sha256Hex(encoded.data)
        lastIntegrityHash = fileHash
        lastSavedPackURL = url
        recordShareHistory(
            format: .sanebooks,
            integrityHash: fileHash,
            rowCount: draft.rows.count,
            expiresAt: draft.expiresAt
        )
    }

    func exportCSV(to url: URL) throws {
        guard var draft = packDraft else { throw SaneBooksError.pack("No pack draft") }
        draft.acknowledgePartialHistory = acknowledgePartialHistory
        packDraft = draft
        if draft.partialHistory, !draft.acknowledgePartialHistory {
            throw SaneBooksError.pack(
                "Partial history not acknowledged. Sync is incomplete or history may be missing — acknowledge before exporting."
            )
        }
        let csv = CSVExporter.export(rows: draft.rows, includeMemos: draft.includeMemos)
        try csv.write(to: url, atomically: true, encoding: .utf8)
        let fileHash = Self.sha256Hex(Data(csv.utf8))
        lastIntegrityHash = fileHash
        lastSavedPackURL = url
        recordShareHistory(
            format: .csv,
            integrityHash: fileHash,
            rowCount: draft.rows.count,
            expiresAt: nil
        )
    }

    func exportPDF(to url: URL) throws {
        guard var draft = packDraft else { throw SaneBooksError.pack("No pack draft") }
        draft.acknowledgePartialHistory = acknowledgePartialHistory
        packDraft = draft
        if draft.partialHistory, !draft.acknowledgePartialHistory {
            throw SaneBooksError.pack(
                "Partial history not acknowledged. Sync is incomplete or history may be missing — acknowledge before exporting."
            )
        }
        let data = try PDFSummaryExporter.export(draft: draft)
        try persistOwnerPDFExport(data, draft: draft, to: url)
    }

    internal func persistOwnerPDFExport(
        _ data: Data,
        draft: ProofPackDraft,
        to url: URL
    ) throws {
        try PDFSummaryExporter.writeValidatedPDF(data, to: url)
        let fileHash = Self.sha256Hex(data)
        lastIntegrityHash = fileHash
        lastSavedPackURL = url
        recordShareHistory(
            format: .pdf,
            integrityHash: fileHash,
            rowCount: draft.rows.count,
            expiresAt: nil
        )
    }

    // MARK: - Reader

    func openPack(url: URL, passphrase: String) {
        readerError = nil
        do {
            readerResult = try PackReader.open(url, passphrase: passphrase)
        } catch let err as SaneBooksError {
            readerError = err.userFacingMessage
        } catch {
            readerError = error.localizedDescription
        }
    }

    func exportReaderPDF(to url: URL) throws {
        guard let result = readerResult else { throw SaneBooksError.pack("No open pack") }
        let draft = ProofPackDraft(
            vaultFingerprint: result.header.vaultFingerprint,
            vaultDisplayName: result.header.vaultDisplayName,
            network: result.header.network,
            rangeStart: result.header.rangeStart,
            rangeEnd: result.header.rangeEnd,
            rows: result.payload.rows,
            rollups: result.payload.rollups,
            syncAttestation: result.payload.attestation,
            partialHistory: result.header.partialHistory,
            acknowledgePartialHistory: true,
            recipientLabel: result.header.recipientLabel,
            expiresAt: result.header.expiresAt,
            vaultMode: result.header.vaultMode
        )
        let data = try PDFSummaryExporter.export(
            draft: draft,
            sourcePackPlaintextDigest: result.payload.integrity.plaintextCanonicalHash
        )
        try PDFSummaryExporter.writeValidatedPDF(data, to: url)
    }

    // MARK: - Vault management

    func removeVault() {
        guard let vault else { return }
        syncTask?.cancel()
        activeSyncVaultID = nil
        Task {
            do {
                try await sync.purge(vaultID: vault.id)
                try store.deleteVault(id: vault.id)
                do {
                    try keyStore.delete(for: vault.id)
                } catch {
                    importError = "The vault and local ledger were removed, but its viewing-key entry could not be deleted from Keychain. (\(error.localizedDescription))"
                }
                vaults = try store.allVaults()
                shareHistory = try store.shareHistory()
                if let next = vaults.first {
                    try store.setActiveVaultID(next.id)
                    self.vault = next
                    notes = try store.notes(vaultID: next.id)
                    route = .ledger
                } else {
                    self.vault = nil
                    notes = []
                    cursor = nil
                    packDraft = nil
                    route = .welcome
                }
            } catch {
                importError = "Vault removal stopped before every local copy could be removed. Review the remaining vault and try again. (\(error.localizedDescription))"
            }
        }
    }

    // MARK: - Helpers

    internal func parseBirthday(_ text: String) -> UInt32? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let height = UInt32(trimmed) {
            return height
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        if formatter.date(from: trimmed) != nil {
            return MockSyncFacade.birthdayDefault
        }
        return nil
    }

    internal enum SettingsKey {
        static let defaultPackExpiryDays = "SaneBooks.defaultPackExpiryDays"
        static let includeMemosByDefault = "SaneBooks.includeMemosByDefault"
        static let truncateTxidsInUI = "SaneBooks.truncateTxidsInUI"
        static let discreetMode = "SaneBooks.discreetMode"
        static let textSize = "SaneBooks.textSize"
        static let hasCompletedOnboarding = "SaneBooks.onboarding.v1.completed"
        static let onboardingPage = "SaneBooks.onboarding.v1.page"
        static let defaultRecipientLabel = "SaneBooks.defaultRecipientLabel"
        static let lwdURL = "SaneBooks.lwdURL"
    }

    internal func loadPersistedSettings() {
        if settingsDefaults.object(forKey: SettingsKey.defaultPackExpiryDays) != nil {
            defaultPackExpiryDays = settingsDefaults.integer(forKey: SettingsKey.defaultPackExpiryDays)
        }
        if settingsDefaults.object(forKey: SettingsKey.includeMemosByDefault) != nil {
            includeMemosByDefault = settingsDefaults.bool(forKey: SettingsKey.includeMemosByDefault)
        }
        if settingsDefaults.object(forKey: SettingsKey.truncateTxidsInUI) != nil {
            truncateTxidsInUI = settingsDefaults.bool(forKey: SettingsKey.truncateTxidsInUI)
        }
        if settingsDefaults.object(forKey: SettingsKey.discreetMode) != nil {
            discreetMode = settingsDefaults.bool(forKey: SettingsKey.discreetMode)
        }
        if let rawTextSize = settingsDefaults.string(forKey: SettingsKey.textSize),
           let persistedTextSize = SaneBooksTextSize(rawValue: rawTextSize)
        {
            textSize = persistedTextSize
        }
        if settingsDefaults.object(forKey: SettingsKey.hasCompletedOnboarding) != nil {
            hasCompletedOnboarding = settingsDefaults.bool(forKey: SettingsKey.hasCompletedOnboarding)
        }
        if settingsDefaults.object(forKey: SettingsKey.onboardingPage) != nil {
            onboardingPage = max(0, min(settingsDefaults.integer(forKey: SettingsKey.onboardingPage), 2))
        }
        if let recipient = settingsDefaults.string(forKey: SettingsKey.defaultRecipientLabel) {
            defaultRecipientLabel = recipient
        }
        if let endpoint = settingsDefaults.string(forKey: SettingsKey.lwdURL) {
            lwdURLString = endpoint
        }
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
