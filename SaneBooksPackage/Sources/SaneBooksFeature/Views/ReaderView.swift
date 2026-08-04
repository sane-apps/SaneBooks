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
    @State private var statusMessage: String?

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
                        .saneBooksFont(size: SaneBooksType.display, weight: .bold)
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Close") { model.goWelcome() }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .saneBooksFont(size: 14, weight: .semibold)
                }
            }

            if let result = model.readerResult {
                ScrollView(.vertical) {
                    packContents(result)
                        .padding(.bottom, 8)
                }
            } else {
                unlockForm
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .padding(28)
    }

    private var unlockForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "lock.doc.fill")
                    .saneBooksFont(size: 26, weight: .semibold)
                    .foregroundStyle(Color.saneBooksAccent)
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(Color.saneBooksAccent.opacity(0.14)))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Open an encrypted proof pack")
                        .saneBooksFont(size: SaneBooksType.display, weight: .bold)
                        .foregroundStyle(.white)
                    Text("Open a proof pack your accountant shared with you. No wallet key needed.")
                        .saneBooksFont(size: SaneBooksType.body, weight: .medium)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()
                .overlay(Color.white.opacity(0.18))

            HStack(spacing: 12) {
                ActionButton("Choose File…", style: .secondary) {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [UTType(filenameExtension: "sanebooks") ?? .data]
                    panel.allowsMultipleSelection = false
                    if panel.runModal() == .OK {
                        pendingURL = panel.url
                        model.readerError = nil
                        statusMessage = nil
                    }
                }

                if let pendingURL {
                    Text(pendingURL.lastPathComponent)
                        .saneBooksFont(size: SaneBooksType.body, weight: .semibold)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("Select a .sanebooks file")
                        .saneBooksFont(size: SaneBooksType.body, weight: .medium)
                        .foregroundStyle(.white)
                }
            }

            if pendingURL == nil {
                Label("Passphrase entry unlocks after you choose a file", systemImage: "2.circle.fill")
                    .saneBooksFont(size: SaneBooksType.body, weight: .semibold)
                    .foregroundStyle(.white)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                SecureField("Passphrase", text: $passphrase)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.white)
            }

            if let err = model.readerError {
                SaneBooksStatusBanner(kind: .error, message: err)
            }

            HStack(spacing: 16) {
                ActionButton("Unlock") {
                    guard let pendingURL else {
                        model.readerError = "Choose a proof pack file first."
                        return
                    }
                    model.openPack(url: pendingURL, passphrase: passphrase)
                    if model.readerError == nil {
                        statusMessage = "File authentication, expiry, and internal accounting consistency verified. This does not verify who created it or prove chain completeness."
                    }
                }
                .disabled(pendingURL == nil || passphrase.isEmpty)

                Spacer(minLength: 8)

                Label("Read-only · cannot spend", systemImage: "eye.fill")
                    .saneBooksFont(size: SaneBooksType.body, weight: .semibold)
                    .foregroundStyle(Color.saneBooksAccentSoft)
            }
        }
        .padding(24)
        .frame(maxWidth: 620, alignment: .leading)
        .background(
            SaneGlassRoundedBackground(
                cornerRadius: 18,
                tint: SaneBooksTheme.panelTint,
                edgeTint: SaneBooksTheme.goldSoft,
                tintStrength: 0.22,
                glowOpacity: 0.08
            )
        )
    }

    private func packContents(_ result: PackOpenResult) -> some View {
        let header = result.header
        let rows = result.payload.rows
        let rollups = result.payload.rollups
        let sortedCategories = rollups.byCategory.sorted(by: { $0.key < $1.key })

        return VStack(alignment: .leading, spacing: 16) {
            SaneBooksStatusBanner(
                kind: .success,
                message: "Pack unlocked · Read-only · No spend capability · No live chain sync"
            )

            if let statusMessage {
                SaneBooksStatusBanner(kind: .success, message: statusMessage)
            }
            if let readerError = model.readerError {
                SaneBooksStatusBanner(kind: .error, message: readerError)
            }

            Text(header.vaultDisplayName)
                .saneBooksFont(size: 18, weight: .bold)
                .foregroundStyle(.white)
                .lineLimit(2)
                .truncationMode(.middle)
            Text("Range \(header.rangeStart.formatted(date: .abbreviated, time: .omitted)) → \(header.rangeEnd.formatted(date: .abbreviated, time: .omitted)) · Expires \(header.expiresAt.formatted(date: .abbreviated, time: .omitted))")
                .saneBooksFont(size: 14, weight: .medium)
                .foregroundStyle(.white)

            HStack(spacing: 28) {
                Text("Income \(formatZEC(rollups.incomeZEC)) ZEC")
                Text("Expenses \(formatZEC(rollups.expenseZEC)) ZEC")
            }
            .saneBooksFont(size: 14, weight: .semibold)
            .foregroundStyle(.white)

            Text("Category rollup")
                .saneBooksFont(size: 14, weight: .semibold)
                .foregroundStyle(.white)
            ForEach(sortedCategories.prefix(50), id: \.key) { item in
                Text("\(item.key) …… \(formatZEC(item.value)) ZEC")
                    .saneBooksFont(size: 14, weight: .medium)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if sortedCategories.count > 50 {
                Text("\(sortedCategories.count - 50) more categories are preserved in the export.")
                    .saneBooksFont(size: 14, weight: .semibold)
                    .foregroundStyle(.white)
            }

            ScrollView([.horizontal, .vertical]) {
                LazyVStack(spacing: 0) {
                    ForEach(rows) { row in
                        HStack(spacing: 16) {
                            Text(row.date.formatted(date: .abbreviated, time: .omitted))
                                .frame(width: 100, alignment: .leading)
                            Text(row.kind.displayName)
                                .frame(width: 100, alignment: .leading)
                            Text("\(formatZEC(row.amountZEC)) ZEC")
                                .frame(width: 150, alignment: .trailing)
                            Text(row.party ?? "—")
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(width: 180, alignment: .leading)
                            Text(row.txidTruncated)
                                .saneBooksFont(size: 13, weight: .medium, design: .monospaced)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(width: 180, alignment: .leading)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .frame(minWidth: 760, alignment: .leading)
                        .background(Color.white.opacity(0.04))
                        .overlay(alignment: .bottom) {
                            Divider().overlay(Color.white.opacity(0.16))
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(
                            "\(row.kind.displayName), \(formatZEC(row.amountZEC)) ZEC, \(row.date.formatted(date: .abbreviated, time: .omitted)), \(row.party ?? "no party")"
                        )
                    }
                }
                .saneBooksFont(size: 14, weight: .medium)
                .foregroundStyle(.white)
            }
            .frame(minHeight: 180, maxHeight: 360)

            HStack(spacing: 16) {
                ActionButton("Export CSV", style: .secondary) {
                    let panel = NSSavePanel()
                    panel.nameFieldStringValue = "pack.csv"
                    panel.allowedContentTypes = [.commaSeparatedText]
                    guard panel.runModal() == .OK, let url = panel.url else { return }
                    let csv = CSVExporter.export(rows: rows)
                    do {
                        try csv.write(to: url, atomically: true, encoding: .utf8)
                        model.readerError = nil
                        statusMessage = "Saved plaintext CSV to \(url.lastPathComponent). It does not expire."
                    } catch {
                        statusMessage = nil
                        model.readerError = "CSV could not be saved. \(error.localizedDescription)"
                    }
                }
                ActionButton("Export PDF", style: .secondary) {
                    let panel = NSSavePanel()
                    panel.nameFieldStringValue = "pack.pdf"
                    panel.allowedContentTypes = [.pdf]
                    guard panel.runModal() == .OK, let url = panel.url else { return }
                    do {
                        try model.exportReaderPDF(to: url)
                        model.readerError = nil
                        statusMessage = "Saved plaintext PDF to \(url.lastPathComponent). It does not expire."
                    } catch {
                        statusMessage = nil
                        model.readerError = "PDF could not be saved. \(error.localizedDescription)"
                    }
                }
                ActionButton("Check file", style: .secondary) {
                    guard let pendingURL else {
                        model.readerError = "The original encrypted file is no longer selected. Choose it again to verify."
                        statusMessage = nil
                        return
                    }
                    model.openPack(url: pendingURL, passphrase: passphrase)
                    if model.readerError == nil {
                        statusMessage = "Re-read and verified file integrity for \(pendingURL.lastPathComponent). Sender identity is not verified."
                    } else {
                        statusMessage = nil
                    }
                }
                Text("File ID \(String(result.payload.integrity.plaintextCanonicalHash.prefix(12)))…")
                    .saneBooksFont(size: 14, design: .monospaced)
                    .foregroundStyle(.white)
            }
        }
    }
}
