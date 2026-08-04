import AppKit
import SaneBooksCore
import SaneBooksExport
import SaneUI
import SwiftUI
import UniformTypeIdentifiers

public struct ShareProofPackView: View {
    @Bindable var model: AppModel
    @State private var format: ShareFormat = .sanebooks
    @State private var passphrase = ""
    @State private var passphraseConfirmation = ""
    @State private var recipient = ""
    @State private var expiryDays = 90
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    enum ShareFormat: String, CaseIterable {
        case sanebooks = "Encrypted pack for your accountant"
        case csv = "Spreadsheet (CSV)"
        case pdf = "PDF summary"
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SaneBooksTopNav(
                mode: .nested(title: "Share Proof Pack"),
                onVault: { model.route = .ledger },
                onProofPacks: { model.beginProofPack() },
                onBackToLedger: { model.route = .ledger }
            )
            .padding(.bottom, 16)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    if let draft = model.packDraft {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Pack: \(draft.vaultDisplayName) · \(draft.rangeStart.formatted(date: .abbreviated, time: .omitted)) → \(draft.rangeEnd.formatted(date: .abbreviated, time: .omitted))")
                                .saneBooksFont(size: 14, weight: .semibold)
                                .foregroundStyle(.white)
                            if let hash = model.lastIntegrityHash {
                                Text("File check: \(String(hash.prefix(8)))…\(String(hash.suffix(4)))")
                                    .saneBooksFont(size: 14, weight: .medium)
                                    .foregroundStyle(.white)
                            }
                        }

                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .top, spacing: 18) {
                                disclosureColumn(for: draft)
                                    .frame(width: 350, alignment: .topLeading)
                                exportColumn
                                    .frame(width: 350, alignment: .topLeading)
                            }
                            .frame(maxWidth: .infinity, alignment: .top)

                            VStack(alignment: .leading, spacing: 18) {
                                disclosureColumn(for: draft)
                                exportColumn
                            }
                        }
                    } else {
                        SaneBooksStatusBanner(
                            kind: .error,
                            message: "This proof-pack draft is no longer available. Return to the ledger and build a new pack."
                        )
                    }
                }
                .padding(.bottom, 8)
            }

            HStack(spacing: 16) {
                ActionButton("Save File…") { save() }
                    .disabled(model.packDraft == nil)
                if let url = model.lastSavedPackURL {
                    ActionButton("Copy path", style: .secondary) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(url.path, forType: .string)
                        statusMessage = "Path copied to clipboard."
                        errorMessage = nil
                    }
                }
                Spacer()
                Button("Done") { model.route = .ledger }
                    .buttonStyle(.plain)
                    .saneBooksFont(size: 14, weight: .semibold)
                    .foregroundStyle(.white)
            }
            .padding(.top, 16)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 1)
            }
        }
        .padding(28)
        .onAppear {
            expiryDays = model.defaultPackExpiryDays
            if recipient.isEmpty {
                recipient = model.packDraft?.recipientLabel
                    ?? model.defaultRecipientLabel
            }
        }
        .onChange(of: format) { _, _ in
            model.clearLastExportReceipt()
            statusMessage = nil
            errorMessage = nil
        }
    }

    private func disclosureColumn(for draft: ProofPackDraft) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            disclosureAudit(for: draft)
            if draft.partialHistory {
                Toggle("I understand these totals may be incomplete", isOn: $model.acknowledgePartialHistory)
                    .saneBooksFont(size: 14, weight: .semibold)
                    .foregroundStyle(.white)
                    .toggleStyle(.checkbox)
            }
        }
    }

    private var exportColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Format", selection: $format) {
                ForEach(ShareFormat.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.radioGroup)
            .foregroundStyle(.white)
            .saneBooksFont(size: 14, weight: .medium)

            if format == .sanebooks {
                VStack(alignment: .leading, spacing: 12) {
                    SecureField("Passphrase", text: $passphrase)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.white)
                    SecureField("Confirm passphrase", text: $passphraseConfirmation)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.white)
                    Picker("Expires", selection: $expiryDays) {
                        Text("30 days").tag(30)
                        Text("90 days").tag(90)
                        Text("180 days").tag(180)
                    }
                    .foregroundStyle(.white)
                    TextField("Recipient label", text: $recipient)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.white)
                }
            }

            Text(formatWarning)
                .saneBooksFont(size: 14, weight: .medium)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            if let statusMessage {
                SaneBooksStatusBanner(kind: .success, message: statusMessage)
            }
            if let errorMessage {
                SaneBooksStatusBanner(kind: .error, message: errorMessage)
            }
        }
    }

    @ViewBuilder
    private func disclosureAudit(for draft: ProofPackDraft) -> some View {
        let summary = disclosureSummary(for: draft)
        VStack(alignment: .leading, spacing: 8) {
            Text("Disclosure audit")
                .saneBooksFont(size: 14, weight: .bold)
                .foregroundStyle(.white)
            ForEach(summary.auditLines, id: \.self) { line in
                Text("• \(line)")
                    .saneBooksFont(size: 13, weight: .medium)
                    .foregroundStyle(.white)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.saneBooksAccent.opacity(0.35), lineWidth: 1)
        )
    }

    private func disclosureSummary(for draft: ProofPackDraft) -> PackDisclosureSummary {
        var summary = PackDisclosureSummary.from(draft: draft, allNotes: model.notes)
        let trimmedRecipient = recipient.trimmingCharacters(in: .whitespacesAndNewlines)
        summary.recipientLabel = trimmedRecipient.isEmpty ? nil : trimmedRecipient
        summary.expiresAt = format == .sanebooks
            ? Calendar.current.date(byAdding: .day, value: expiryDays, to: Date()) ?? draft.expiresAt
            : nil
        return summary
    }

    private var formatWarning: String {
        switch format {
        case .sanebooks:
            "Password-protected SaneBooks file. It leaves out your viewing key, can expire, and warns if the file changes. Anyone with the file and password can read it until then."
        case .csv:
            "Spreadsheet with no password or expiration. Anyone with the file can read, copy, edit, or resend every included row."
        case .pdf:
            "PDF with no password or expiration. Anyone with the file can read, copy, print, or resend the summary."
        }
    }

    private func save() {
        errorMessage = nil
        statusMessage = nil
        guard var draft = model.packDraft else {
            errorMessage = "This proof-pack draft is no longer available. Build a new pack and try again."
            return
        }
        draft.recipientLabel = recipient.isEmpty ? nil : recipient
        draft.expiresAt = Calendar.current.date(byAdding: .day, value: expiryDays, to: Date()) ?? draft.expiresAt
        draft.acknowledgePartialHistory = model.acknowledgePartialHistory
        model.packDraft = draft
        if !recipient.isEmpty {
            model.defaultRecipientLabel = recipient
        }

        if draft.partialHistory, !model.acknowledgePartialHistory {
            errorMessage = "Acknowledge partial history before exporting."
            return
        }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        switch format {
        case .sanebooks:
            panel.nameFieldStringValue = "TaxYear.sanebooks"
            panel.allowedContentTypes = [UTType(filenameExtension: "sanebooks") ?? .data]
            guard passphrase.count >= PackCrypto.Limits.minimumPassphraseCharacters else {
                errorMessage = "Use a passphrase of at least \(PackCrypto.Limits.minimumPassphraseCharacters) characters. A few unrelated words are easier to remember and harder to guess."
                return
            }
            guard passphrase == passphraseConfirmation else {
                errorMessage = "The passphrases do not match."
                return
            }
        case .csv:
            panel.nameFieldStringValue = "TaxYear.csv"
            panel.allowedContentTypes = [.commaSeparatedText]
        case .pdf:
            panel.nameFieldStringValue = "TaxYear.pdf"
            panel.allowedContentTypes = [.pdf]
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            switch format {
            case .sanebooks:
                try model.savePack(passphrase: passphrase, to: url)
                statusMessage = "Saved \(url.lastPathComponent). Share the file and passphrase out of band."
            case .csv:
                try model.exportCSV(to: url)
                statusMessage = "CSV saved to \(url.lastPathComponent)."
            case .pdf:
                try model.exportPDF(to: url)
                statusMessage = "PDF saved to \(url.lastPathComponent)."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
