import SaneBooksCore
import SwiftUI
import UniformTypeIdentifiers

public struct ImportViewingKeyView: View {
    @Bindable var model: AppModel
    @State private var showSDKDBImporter = false
    @State private var showsViewingKey = false

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(model.importAsUpgrade ? "Replace Receive-Only Key" : "Set Up Your Books")
                    .saneBooksFont(size: SaneBooksType.display, weight: .bold)
                    .foregroundStyle(.white)
                Spacer()
                Button("Cancel") {
                    showsViewingKey = false
                    model.cancelImport()
                }
                .buttonStyle(.plain)
                .saneBooksFont(size: SaneBooksType.body, weight: .semibold)
                .foregroundStyle(.white)
            }
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if model.importAsUpgrade {
                        SaneBooksStatusBanner(
                            kind: .info,
                            message: "Paste a full viewing key that uses the same Zcash network. Your existing books stay on this Mac."
                        )
                    }

                    if !model.importAsUpgrade {
                        fastestPathCard
                    }

                    Text("Or enter a viewing key — never recovery words")
                        .saneBooksFont(size: SaneBooksType.body, weight: .semibold)
                        .foregroundStyle(Color.saneBooksAccentSoft)

                    HStack(spacing: 10) {
                        Group {
                            if showsViewingKey {
                                TextField("Viewing key", text: $model.importKeyText)
                            } else {
                                SecureField("Viewing key", text: $model.importKeyText)
                            }
                        }
                        .textFieldStyle(.plain)
                        .saneBooksFont(size: SaneBooksType.body, design: .monospaced)
                        .padding(12)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.white)
                        .accessibilityLabel("Viewing key")

                        Button(showsViewingKey ? "Hide" : "Reveal") {
                            showsViewingKey.toggle()
                        }
                        .buttonStyle(.plain)
                        .saneBooksFont(size: SaneBooksType.body, weight: .semibold)
                        .foregroundStyle(.white)
                        .accessibilityLabel(showsViewingKey ? "Hide viewing key" : "Reveal viewing key")
                    }
                    .onChange(of: model.importKeyText) { _, _ in
                        if model.importError != nil {
                            model.importError = nil
                        }
                    }

                    HStack(spacing: 16) {
                        Text("Zcash network")
                            .saneBooksFont(size: SaneBooksType.body, weight: .semibold)
                            .foregroundStyle(.white)
                        Picker("Network", selection: $model.importNetwork) {
                            ForEach(ZcashNetwork.allCases, id: \.self) { net in
                                Text(net == .mainnet ? "Mainnet (regular ZEC)" : "Testnet (testing only)")
                                    .tag(net)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                        .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Wallet start date (optional — speeds up first sync)")
                            .saneBooksFont(size: SaneBooksType.body, weight: .semibold)
                            .foregroundStyle(.white)
                        TextField("Date or starting block number", text: $model.importBirthdayText)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(.white)
                        DisclosureGroup(isExpanded: $model.showBirthdayHelp) {
                            birthdayWizardCopy
                        } label: {
                            Text("Where do I find this in my wallet?")
                                .saneBooksFont(size: SaneBooksType.body, weight: .semibold)
                                .foregroundStyle(Color.saneBooksAccent)
                        }
                    }

                    if let err = model.importError {
                        SaneBooksStatusBanner(kind: .error, message: err)
                    }

                    if model.isZashiDatabaseImportInProgress {
                        SaneBooksStatusBanner(
                            kind: .info,
                            message: "Reading your wallet history. You can cancel at any time; nothing is saved until it finishes."
                        )
                    }

                    if !model.importAsUpgrade {
                        liveAndDemoRow
                    }
                }
                .padding(.bottom, 8)
            }

            HStack {
                Spacer()
                ActionButton(model.importAsUpgrade ? "Replace Key" : "Continue") {
                    model.finishImport()
                }
                .disabled(model.importKeyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 10)
            .padding(.bottom, 14)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.saneBooksAccent.opacity(0.28))
                    .frame(height: 1)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 20)
        .alert("Incoming-only viewing key", isPresented: $model.showDegradedConfirm) {
            Button("Continue anyway") { model.confirmDegradedImport() }
            Button("Cancel", role: .cancel) { model.cancelDegradedImport() }
        } message: {
            Text("An incoming-only key can miss change and expenses, so income may look too high. Prefer a full viewing key for complete books.")
        }
        .onAppear {
            showsViewingKey = false
        }
        .onDisappear {
            showsViewingKey = false
        }
    }

    private var birthdayWizardCopy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Zodl: open More → Export Private Data or Sub-Keys → copy the viewing key only.")
                .saneBooksFont(size: SaneBooksType.body, weight: .medium)
                .foregroundStyle(.white)
            Text("YWallet: open Backup / Show Viewing Key for the account → copy the viewing key.")
                .saneBooksFont(size: SaneBooksType.body, weight: .medium)
                .foregroundStyle(.white)
            Text("Zashi: export private data, then use Import from Zashi / Zodl above.")
                .saneBooksFont(size: SaneBooksType.body, weight: .medium)
                .foregroundStyle(.white)
        }
        .padding(.top, 6)
    }

    /// Primary owner path — must be fully on-screen without hunting.
    private var fastestPathCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recommended — import from your wallet")
                .saneBooksFont(size: SaneBooksType.body, weight: .semibold)
                .foregroundStyle(.white)
            Text("Choose the file you exported from Zashi or Zodl. ZecBooks reads what it needs without changing your wallet.")
                .saneBooksFont(size: SaneBooksType.body, weight: .medium)
                .foregroundStyle(SaneBooksTheme.pageIvory)
                .fixedSize(horizontal: false, vertical: true)
            ActionButton("Import from Zashi / Zodl…", icon: "externaldrive", style: .primary) {
                showSDKDBImporter = true
            }
            .frame(maxWidth: 320)
            .disabled(model.isZashiDatabaseImportInProgress)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.saneBooksAccent.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.saneBooksAccent.opacity(0.45), lineWidth: 1.5)
        )
        .fileImporter(
            isPresented: $showSDKDBImporter,
            allowedContentTypes: [
                UTType(filenameExtension: "db") ?? .data,
                .data,
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                model.importZashiSDKDatabase(at: url, securityScoped: true)
            case let .failure(error):
                model.importError = error.localizedDescription
            }
        }
    }

    private var liveAndDemoRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Or try without your wallet")
                .saneBooksFont(size: SaneBooksType.body, weight: .semibold)
                .foregroundStyle(Color.saneBooksAccentSoft)
            Text("See a live sample or open a demo that works without the internet.")
                .saneBooksFont(size: SaneBooksType.body, weight: .medium)
                .foregroundStyle(SaneBooksTheme.pageIvory)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                ActionButton("See live sample", icon: "antenna.radiowaves.left.and.right", style: .secondary) {
                    model.useLiveProbeKey()
                }
                .frame(maxWidth: 210)
                ActionButton("Open offline demo", icon: "sparkles", style: .secondary) {
                    model.useDemoKey()
                }
                .frame(maxWidth: 190)
            }
        }
        .padding(.top, 4)
    }
}
