import AppKit
import SaneBooksCore
import SaneBooksExport
import SaneUI
import SwiftUI
import UniformTypeIdentifiers

public struct ReaderView: View {
    @Bindable var model: AppModel
    @State private var passphrase = ""
    @State private var pendingURL: URL?

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if model.vault != nil {
                SaneBooksTopNav(
                    mode: .nested(title: "SaneBooks Reader"),
                    onVault: { model.route = .ledger },
                    onProofPacks: { model.beginProofPack() },
                    onBackToLedger: {
                        if model.vault == nil {
                            model.goWelcome()
                        } else {
                            model.route = .ledger
                        }
                    }
                )
            } else {
                HStack {
                    Text("SaneBooks Reader · Proof Pack")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Close") { model.goWelcome() }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .font(.system(size: 14, weight: .semibold))
                }
            }

            if let result = model.readerResult {
                packContents(result)
            } else {
                unlockForm
            }
        }
        .padding(28)
    }

    private var unlockForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Open a proof pack your accountant shared with you. No wallet key needed.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)

            ActionButton("Choose File…", style: .secondary) {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [UTType(filenameExtension: "sanebooks") ?? .data]
                panel.allowsMultipleSelection = false
                if panel.runModal() == .OK {
                    pendingURL = panel.url
                    model.readerError = nil
                }
            }

            if let pendingURL {
                SaneBooksStatusBanner(kind: .info, message: pendingURL.lastPathComponent)
            }

            SecureField("Passphrase", text: $passphrase)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(.white)

            if let err = model.readerError {
                SaneBooksStatusBanner(kind: .error, message: err)
            }

            ActionButton("Unlock") {
                guard let pendingURL else {
                    model.readerError = "Choose a proof pack file first."
                    return
                }
                model.openPack(url: pendingURL, passphrase: passphrase)
            }
            .disabled(pendingURL == nil || passphrase.isEmpty)
            .opacity(pendingURL == nil || passphrase.isEmpty ? 0.45 : 1)

            Spacer(minLength: 0)
        }
    }

    private func packContents(_ result: PackOpenResult) -> some View {
        let header = result.header
        let rows = result.payload.rows
        let rollups = result.payload.rollups

        return VStack(alignment: .leading, spacing: 16) {
            SaneBooksStatusBanner(
                kind: .success,
                message: "Pack unlocked · Read-only · No spend capability · No live chain sync"
            )

            Text(header.vaultDisplayName)
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text("Range \(header.rangeStart.formatted(date: .abbreviated, time: .omitted)) → \(header.rangeEnd.formatted(date: .abbreviated, time: .omitted)) · Expires \(header.expiresAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)

            HStack(spacing: 28) {
                Text("Income \(formatZEC(rollups.incomeZEC)) ZEC")
                Text("Expenses \(formatZEC(rollups.expenseZEC)) ZEC")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)

            Text("Category rollup")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
            ForEach(rollups.byCategory.sorted(by: { $0.key < $1.key }), id: \.key) { item in
                Text("\(item.key) …… \(formatZEC(item.value)) ZEC")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
            }

            List(rows) { row in
                HStack(spacing: 16) {
                    Text(row.date.formatted(date: .abbreviated, time: .omitted))
                        .frame(width: 72, alignment: .leading)
                    Text(row.kind.displayName)
                        .frame(width: 80, alignment: .leading)
                    Spacer()
                    Text("\(formatZEC(row.amountZEC)) ZEC")
                    Text(row.party ?? "—")
                        .frame(width: 120, alignment: .trailing)
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)

            HStack(spacing: 16) {
                ActionButton("Export CSV", style: .secondary) {
                    let panel = NSSavePanel()
                    panel.nameFieldStringValue = "pack.csv"
                    panel.allowedContentTypes = [.commaSeparatedText]
                    guard panel.runModal() == .OK, let url = panel.url else { return }
                    let csv = CSVExporter.export(rows: rows)
                    try? csv.write(to: url, atomically: true, encoding: .utf8)
                }
                ActionButton("Export PDF", style: .secondary) {
                    let panel = NSSavePanel()
                    panel.nameFieldStringValue = "pack.pdf"
                    panel.allowedContentTypes = [.pdf]
                    guard panel.runModal() == .OK, let url = panel.url else { return }
                    try? model.exportReaderPDF(to: url)
                }
                ActionButton("Check file", style: .secondary) {}
                Text("File ID \(String(result.payload.integrity.plaintextCanonicalHash.prefix(12)))…")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
    }
}
