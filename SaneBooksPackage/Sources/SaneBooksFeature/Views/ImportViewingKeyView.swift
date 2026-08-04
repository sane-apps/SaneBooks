import SaneBooksCore
import SwiftUI
import UniformTypeIdentifiers

public struct ImportViewingKeyView: View {
    @Bindable var model: AppModel
    @State private var showSDKDBImporter = false

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(model.importAsUpgrade ? "Upgrade to Full Viewing Key" : "Import Viewing Key")
                    .font(.system(size: SaneBooksType.display, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Button("Cancel") {
                    if model.importAsUpgrade, model.vault != nil {
                        model.importAsUpgrade = false
                        model.route = .ledger
                    } else {
                        model.goWelcome()
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: SaneBooksType.body, weight: .semibold))
                .foregroundStyle(.white)
            }
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if model.importAsUpgrade {
                        SaneBooksStatusBanner(
                            kind: .info,
                            message: "Paste a full viewing key for the same network. Your books stay on this Mac; only the key is replaced."
                        )
                    }

                    if !model.importAsUpgrade {
                        fastestPathCard
                    }

                    Text("Or paste a viewing key")
                        .font(.system(size: SaneBooksType.body, weight: .semibold))
                        .foregroundStyle(Color.saneBooksAccentSoft)

                    TextEditor(text: $model.importKeyText)
                        .font(.system(size: SaneBooksType.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .frame(minHeight: 52, maxHeight: 72)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.white)
                        .onChange(of: model.importKeyText) { _, _ in
                            if model.importError != nil {
                                model.importError = nil
                            }
                        }

                    HStack(spacing: 16) {
                        Text("Network")
                            .font(.system(size: SaneBooksType.body, weight: .semibold))
                            .foregroundStyle(.white)
                        Picker("Network", selection: $model.importNetwork) {
                            ForEach(ZcashNetwork.allCases, id: \.self) { net in
                                Text(net.displayName).tag(net)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .labelsHidden()
                        .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Wallet start date (optional)")
                            .font(.system(size: SaneBooksType.body, weight: .semibold))
                            .foregroundStyle(.white)
                        TextField("Date or start height (optional)", text: $model.importBirthdayText)
                            .textFieldStyle(.plain)
                            .padding(10)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(.white)
                        Text("Helps the first sync go faster. Never paste a seed phrase.")
                            .font(.system(size: SaneBooksType.body, weight: .medium))
                            .foregroundStyle(SaneBooksTheme.pageIvory.opacity(0.9))

                        DisclosureGroup(isExpanded: $model.showBirthdayHelp) {
                            birthdayWizardCopy
                        } label: {
                            Text("Where do I find this in my wallet?")
                                .font(.system(size: SaneBooksType.body, weight: .semibold))
                                .foregroundStyle(Color.saneBooksAccent)
                        }
                    }

                    if let err = model.importError {
                        SaneBooksStatusBanner(kind: .error, message: err)
                    }

                    if !model.importAsUpgrade {
                        liveAndDemoRow
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 20)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack {
                Spacer()
                ActionButton(model.importAsUpgrade ? "Upgrade Key" : "Continue") {
                    model.finishImport()
                }
                .disabled(model.importKeyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(model.importKeyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            }
            .padding(.horizontal, 28)
            .padding(.top, 10)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity)
            .background(SaneBooksTheme.ink.opacity(0.97))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.saneBooksAccent.opacity(0.28))
                    .frame(height: 1)
            }
        }
        .alert("Incoming-only viewing key", isPresented: $model.showDegradedConfirm) {
            Button("Continue anyway") { model.confirmDegradedImport() }
            Button("Cancel", role: .cancel) { model.cancelDegradedImport() }
        } message: {
            Text("An incoming-only key can miss change and expenses, so income may look too high. Prefer a full viewing key for complete books.")
        }
    }

    private var birthdayWizardCopy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Zodl: open More → export private data or sub-keys → copy the viewing key only (not the seed).")
                .font(.system(size: SaneBooksType.body, weight: .medium))
                .foregroundStyle(.white)
            Text("YWallet: open Backup / Show Viewing Key for the account → copy the viewing key.")
                .font(.system(size: SaneBooksType.body, weight: .medium))
                .foregroundStyle(.white)
            Text("Zashi: export private data, then use Import from Zashi / Zodl above.")
                .font(.system(size: SaneBooksType.body, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.top, 6)
    }

    /// Primary owner path — must be fully on-screen without hunting.
    private var fastestPathCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Fastest — import from your wallet")
                .font(.system(size: SaneBooksType.body, weight: .semibold))
                .foregroundStyle(.white)
            Text("Bring in a Zashi or Zodl wallet export to load your viewing key and history without a long re-scan.")
                .font(.system(size: SaneBooksType.body, weight: .medium))
                .foregroundStyle(SaneBooksTheme.pageIvory)
                .fixedSize(horizontal: false, vertical: true)
            ActionButton("Import from Zashi / Zodl…", icon: "externaldrive", style: .primary) {
                showSDKDBImporter = true
            }
            .frame(maxWidth: 320)
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
                .data
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else { return }
                let accessed = url.startAccessingSecurityScopedResource()
                defer {
                    if accessed {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                model.importZashiSDKDatabase(at: url)
            case let .failure(error):
                model.importError = error.localizedDescription
            }
        }
    }

    private var liveAndDemoRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Or try without your wallet")
                .font(.system(size: SaneBooksType.body, weight: .semibold))
                .foregroundStyle(Color.saneBooksAccentSoft)
            Text("Use a built-in sample key to sync live, or open an offline demo ledger.")
                .font(.system(size: SaneBooksType.body, weight: .medium))
                .foregroundStyle(SaneBooksTheme.pageIvory)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                ActionButton("Try live sample", icon: "antenna.radiowaves.left.and.right", style: .secondary) {
                    model.useLiveProbeKey()
                }
                .frame(maxWidth: 210)
                ActionButton("Offline demo ledger", icon: "sparkles", style: .secondary) {
                    model.useDemoKey()
                }
                .frame(maxWidth: 190)
            }
        }
        .padding(.top, 4)
    }
}
