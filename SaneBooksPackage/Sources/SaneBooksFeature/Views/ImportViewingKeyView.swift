import SaneBooksCore
import SwiftUI

public struct ImportViewingKeyView: View {
    @Bindable var model: AppModel

    public var body: some View {
        VStack(alignment: .leading, spacing: 24) {
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
                .frame(height: 88)
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
                        .foregroundStyle(Color.saneAccent)
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

            Spacer(minLength: 12)

            HStack {
                Spacer()
                ActionButton(model.importAsUpgrade ? "Upgrade Key" : "Continue") {
                    model.finishImport()
                }
                .disabled(model.importKeyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(model.importKeyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            }
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
            Text("Sync a real UFVK now")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
            Text(
                "Loads the ECC Swift SDK mainnet test UFVK and syncs live via lightwalletd. Birthday \(LiveProbeKey.defaultBirthday.formatted())."
            )
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white)
            .fixedSize(horizontal: false, vertical: true)
            Text("To get a real ledger row: send any tiny ZEC amount to the probe unified address (docs/LIVE_PROBE_FUNDING.md), then sync again.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(LiveProbeKey.unifiedAddress)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            ActionButton("Use Live Probe Key", icon: "antenna.radiowaves.left.and.right", style: .primary) {
                model.useLiveProbeKey()
            }
            .frame(maxWidth: 260)
            ActionButton("Offline demo ledger", icon: "sparkles", style: .secondary) {
                model.useDemoKey()
            }
            .frame(maxWidth: 260)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.saneAccent.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.saneAccent.opacity(0.4), lineWidth: 1.5)
        )
    }
}
