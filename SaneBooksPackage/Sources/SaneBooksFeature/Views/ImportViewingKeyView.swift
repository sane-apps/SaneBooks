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
                    .font(.title2.bold())
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
            }
            .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if model.importAsUpgrade {
                        SaneBooksStatusBanner(
                            kind: .info,
                            message: "Paste a Unified Full Viewing Key (uview…) for the same network. A new fingerprint is expected — this replaces the vault key; notes stay on this vault."
                        )
                    }

                    Text("Viewing key")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)

                    TextEditor(text: $model.importKeyText)
                        .font(.system(size: 14, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .frame(height: 72)
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
                            .font(.system(size: 14, weight: .semibold))
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

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Wallet birthday (optional)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        TextField("Block height or YYYY-MM-DD", text: $model.importBirthdayText)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(.white)
                        Text("Speeds first sync")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)

                        DisclosureGroup(isExpanded: $model.showBirthdayHelp) {
                            birthdayWizardCopy
                        } label: {
                            Text("How to find birthday / viewing key")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.saneBooksAccent)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Accepted: Unified Full Viewing Key (uview…)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                        Text("Rejected: seeds, spending keys, transparent-only keys")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                    }

                    if let err = model.importError {
                        SaneBooksStatusBanner(kind: .error, message: err)
                    }

                    if !model.importAsUpgrade {
                        demoKeyCard
                    }
                }
            }

            HStack {
                Spacer()
                ActionButton(model.importAsUpgrade ? "Upgrade Key" : "Continue") {
                    model.finishImport()
                }
                .disabled(model.importKeyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(model.importKeyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            }
            .padding(.top, 16)
        }
        .padding(32)
        .alert("Incoming-only viewing key", isPresented: $model.showDegradedConfirm) {
            Button("Continue anyway") { model.confirmDegradedImport() }
            Button("Cancel", role: .cancel) { model.cancelDegradedImport() }
        } message: {
            Text("Incoming-only keys cannot detect change or expenses reliably. Income totals may be overstated. Prefer a Unified Full Viewing Key (uview…) for full bookkeeping.")
        }
    }

    private var birthdayWizardCopy: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Zodl")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
            Text("1. Open Zodl → Settings / Account.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
            Text("2. Export Unified Full Viewing Key (uview…) — never the seed.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
            Text("3. Copy wallet birthday (block height) from restore / account details if shown.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
            Text("Docs: https://zodl.app (link text only)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)

            Text("YWallet")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
            Text("1. Open YWallet → Account / Advanced.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
            Text("2. Export viewing key for this account (UFVK preferred).")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
            Text("3. Note birthday height used at wallet creation / restore.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
            Text("Docs: https://ywallet.app (link text only)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
        }
        .padding(.top, 8)
    }

    /// Live probe uses the ECC SDK DerivationTool mainnet UFVK against zec.rocks.
    private var demoKeyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fastest path — import scanned notes")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
            Text("Use a Zashi/Zodl SDK `data.db` export to load UFVK + history without a multi-hour rescan.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            ActionButton("Import Zashi / Zodl database…", icon: "externaldrive", style: .primary) {
                showSDKDBImporter = true
            }
            .frame(maxWidth: 300)

            Text("Or sync live")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.top, 4)
            Text(
                "ECC SDK mainnet test UFVK via lightwalletd (birthday \(LiveProbeKey.defaultBirthday.formatted())). Send dust to the probe UA in docs/LIVE_PROBE_FUNDING.md for a live receive row."
            )
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white)
            .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                ActionButton("Use Live Probe Key", icon: "antenna.radiowaves.left.and.right", style: .secondary) {
                    model.useLiveProbeKey()
                }
                .frame(maxWidth: 220)
                ActionButton("Offline demo ledger", icon: "sparkles", style: .secondary) {
                    model.useDemoKey()
                }
                .frame(maxWidth: 200)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.saneBooksAccent.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.saneBooksAccent.opacity(0.4), lineWidth: 1.5)
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
}
