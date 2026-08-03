import AppKit
import SaneBooksExport
import SaneUI
import SwiftUI
import UniformTypeIdentifiers

public struct ShareProofPackView: View {
    @Bindable var model: AppModel
    @State private var format: ShareFormat = .sanebooks
    @State private var passphrase = ""
    @State private var recipient = "Accountant — Acme CPA"
    @State private var expiryDays = 90
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    enum ShareFormat: String, CaseIterable {
        case sanebooks = "Encrypted SaneBooks pack (.sanebooks)"
        case csv = "CSV (QuickBooks / spreadsheet)"
        case pdf = "PDF summary"
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SaneBooksTopNav(
                mode: .nested(title: "Share Proof Pack"),
                onVault: { model.route = .ledger },
                onProofPacks: { model.beginProofPack() },
                onBackToLedger: { model.route = .ledger }
            )

            if let draft = model.packDraft {
                Text("Pack: \(draft.vaultDisplayName) · \(draft.rangeStart.formatted(date: .abbreviated, time: .omitted)) → \(draft.rangeEnd.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                if let hash = model.lastIntegrityHash {
                    Text("Integrity: sha256:\(String(hash.prefix(8)))…\(String(hash.suffix(4)))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                }
                if draft.partialHistory {
                    SaneBooksStatusBanner(
                        kind: .error,
                        message: "History may be incomplete (sync not caught up, capability blocked, or demo ledger). Income totals could under-report. Acknowledge before export."
                    )
                    Toggle("I acknowledge partial history", isOn: $model.acknowledgePartialHistory)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .toggleStyle(.checkbox)
                }
            }

            Picker("Format", selection: $format) {
                ForEach(ShareFormat.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.radioGroup)
            .foregroundStyle(.white)
            .font(.system(size: 14, weight: .medium))

            if format == .sanebooks {
                VStack(alignment: .leading, spacing: 12) {
                    SecureField("Passphrase", text: $passphrase)
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

            Text("This pack reveals the selected history to anyone with the passphrase until it expires. It cannot spend funds.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            if let statusMessage {
                SaneBooksStatusBanner(kind: .success, message: statusMessage)
            }
            if let errorMessage {
                SaneBooksStatusBanner(kind: .error, message: errorMessage)
            }

            Spacer(minLength: 12)
            HStack(spacing: 16) {
                ActionButton("Save File…") { save() }
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(28)
        .onAppear { expiryDays = model.defaultPackExpiryDays }
    }

    private func save() {
        errorMessage = nil
        statusMessage = nil
        guard var draft = model.packDraft else { return }
        draft.recipientLabel = recipient.isEmpty ? nil : recipient
        draft.expiresAt = Calendar.current.date(byAdding: .day, value: expiryDays, to: Date())!
        draft.acknowledgePartialHistory = model.acknowledgePartialHistory
        model.packDraft = draft

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
            guard passphrase.count >= 8 else {
                errorMessage = "Use a passphrase of at least 8 characters."
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
