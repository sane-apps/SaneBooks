import SaneBooksCore
import SwiftUI

public enum SaneBooksSettingsTab: String, SaneSettingsTab {
    case vault = "Vault"
    case sync = "Sync"
    case proofPacks = "Proof Packs"
    case appearance = "Appearance"
    case privacy = "Privacy"
    case advanced = "Advanced"
    case license = "License"
    case about = "About"

    public var icon: String {
        switch self {
        case .vault: "key.fill"
        case .sync: "arrow.triangle.2.circlepath"
        case .proofPacks: "doc.badge.plus"
        case .appearance: "paintbrush.fill"
        case .privacy: "hand.raised.fill"
        case .advanced: "gearshape.2.fill"
        case .license: "checkmark.seal.fill"
        case .about: "info.circle.fill"
        }
    }

    public var iconColor: Color {
        switch self {
        case .vault: SaneSettingsIconSemantic.general.color
        case .sync: SaneSettingsIconSemantic.sync.color
        case .proofPacks: SaneSettingsIconSemantic.content.color
        case .appearance: SaneSettingsIconSemantic.appearance.color
        case .privacy: SaneSettingsIconSemantic.rules.color
        case .advanced: SaneSettingsIconSemantic.storage.color
        case .license: SaneSettingsIconSemantic.license.color
        case .about: SaneSettingsIconSemantic.about.color
        }
    }
}

public struct SettingsView: View {
    @Bindable var model: AppModel
    @State private var newRuleMemo = "INV-"
    @State private var newRuleParty = ""
    @State private var newRuleKind: ClassificationKind = .income

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        SaneSettingsContainer(defaultTab: SaneBooksSettingsTab.vault, windowSizing: .embedded) { tab in
            switch tab {
            case .vault: vaultTab
            case .sync: syncTab
            case .proofPacks: proofPacksTab
            case .appearance: appearanceTab
            case .privacy: privacyTab
            case .advanced: advancedTab
            case .license: licenseTab
            case .about: aboutTab
            }
        }
        .task {
            await model.refreshCapability()
        }
    }

    private var vaultTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CompactSection("Vaults", icon: "key.fill", iconColor: SaneSettingsIconSemantic.general.color) {
                    if model.vaults.isEmpty {
                        CompactRow("Status", icon: "info.circle", iconColor: SaneSettingsIconSemantic.general.color) {
                            Text("No vault imported")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                        }
                    } else {
                        ForEach(Array(model.vaults.enumerated()), id: \.element.id) { index, vault in
                            if index > 0 {
                                CompactDivider()
                            }
                            CompactRow(vault.displayName, icon: "tray.full", iconColor: SaneSettingsIconSemantic.general.color) {
                                HStack(spacing: 10) {
                                    Text(truncatedFingerprint(vault.keyFingerprint))
                                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.white)
                                    if model.vault?.id == vault.id {
                                        Text("Active")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(Color.saneAccent)
                                    } else {
                                        Button("Switch") { model.switchVault(vault.id) }
                                            .buttonStyle(.plain)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.saneAccent)
                                    }
                                }
                            }
                        }
                        CompactDivider()
                        CompactRow("Add vault", icon: "plus.circle", iconColor: SaneSettingsIconSemantic.general.color) {
                            Button("Import…") { model.addAnotherVault() }
                                .buttonStyle(.plain)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.saneAccent)
                        }
                    }
                }

                if let vault = model.vault {
                    CompactSection("Active vault", icon: "eye.fill", iconColor: SaneSettingsIconSemantic.general.color) {
                        CompactRow("Network", icon: "network", iconColor: SaneSettingsIconSemantic.general.color) {
                            Text(vault.network.displayName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        CompactDivider()
                        CompactRow("Mode", icon: "book.fill", iconColor: SaneSettingsIconSemantic.general.color) {
                            Text(vault.mode == .bookkeeper ? "Bookkeeper" : "Receivables")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        CompactDivider()
                        CompactRow("Remove vault", icon: "trash", iconColor: .red) {
                            Button("Remove…") { model.removeVault() }
                                .buttonStyle(.plain)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private var syncTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CompactSection("Sync", icon: "arrow.triangle.2.circlepath", iconColor: SaneSettingsIconSemantic.sync.color) {
                    CompactRow("Sync now", icon: "play.fill", iconColor: SaneSettingsIconSemantic.sync.color) {
                        Button("Sync Now") { model.syncNow() }
                            .buttonStyle(.plain)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.saneAccent)
                            .disabled(model.vault == nil)
                    }
                    CompactDivider()
                    CompactRow("Status", icon: "dot.radiowaves.left.and.right", iconColor: SaneSettingsIconSemantic.sync.color) {
                        Text(model.cursor?.status.displayName ?? "Idle")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    CompactDivider()
                    CompactRow("Lightwalletd URL", icon: "server.rack", iconColor: SaneSettingsIconSemantic.sync.color) {
                        TextField("https://…", text: $model.lwdURLString)
                            .textFieldStyle(.plain)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 220)
                    }
                    if let cursor = model.cursor {
                        CompactDivider()
                        CompactRow("Birthday", icon: "calendar", iconColor: SaneSettingsIconSemantic.sync.color) {
                            Text("block \(cursor.birthdayHeight.formatted())")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                        }
                    }
                }

                CompactSection("Capability", icon: "shield.lefthalf.filled", iconColor: SaneSettingsIconSemantic.sync.color) {
                    let report = model.capabilityReport ?? model.cursor?.capabilityReport
                    CompactRow("Ironwood", icon: "leaf", iconColor: SaneSettingsIconSemantic.sync.color) {
                        Text(report?.supportsIronwood == true ? "Supported" : "Unavailable (SDK #1806)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    CompactDivider()
                    CompactRow("Mainnet safe", icon: "checkmark.seal", iconColor: SaneSettingsIconSemantic.sync.color) {
                        Text(report?.mainnetSafe == true ? "Yes" : "No")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    if report?.mainnetSafe != true {
                        CompactDivider()
                        CompactRow("Notice", icon: "exclamationmark.triangle", iconColor: .orange) {
                            Text("Mainnet complete sync unavailable until Ironwood SDK")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if let notes = report?.notes, !notes.isEmpty {
                        CompactDivider()
                        CompactRow("Notes", icon: "text.alignleft", iconColor: SaneSettingsIconSemantic.sync.color) {
                            Text(notes.joined(separator: " "))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private var proofPacksTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CompactSection("Proof Packs", icon: "doc.badge.plus", iconColor: SaneSettingsIconSemantic.content.color) {
                    CompactRow("Default expiry", icon: "clock", iconColor: SaneSettingsIconSemantic.content.color) {
                        Picker("", selection: $model.defaultPackExpiryDays) {
                            Text("30 days").tag(30)
                            Text("90 days").tag(90)
                            Text("180 days").tag(180)
                        }
                        .labelsHidden()
                        .frame(width: 120)
                    }
                    CompactDivider()
                    CompactToggle(
                        label: "Include memos by default",
                        icon: "text.alignleft",
                        iconColor: SaneSettingsIconSemantic.content.color,
                        isOn: $model.includeMemosByDefault
                    )
                }

                CompactSection("Share history", icon: "clock.arrow.circlepath", iconColor: SaneSettingsIconSemantic.content.color) {
                    if model.shareHistory.isEmpty {
                        CompactRow("History", icon: "tray", iconColor: SaneSettingsIconSemantic.content.color) {
                            Text("No shares yet. Save a proof pack to record one.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                        }
                    } else {
                        ForEach(Array(model.shareHistory.enumerated()), id: \.element.id) { index, entry in
                            if index > 0 {
                                CompactDivider()
                            }
                            CompactRow(entry.recipientLabel ?? "Unlabeled", icon: "doc", iconColor: SaneSettingsIconSemantic.content.color) {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(entry.format.displayName) · \(entry.rowCount) rows")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white)
                                    Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white)
                                    if let exp = entry.expiresAt {
                                        Text("Expires \(exp.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                        }
                    }
                }

                CompactSection("Memo tag rules", icon: "tag.fill", iconColor: SaneSettingsIconSemantic.content.color) {
                    if let vault = model.vault {
                        ForEach(Array(vault.tagRules.enumerated()), id: \.element.id) { index, rule in
                            if index > 0 {
                                CompactDivider()
                            }
                            CompactRow("Contains \"\(rule.memoContains)\"", icon: "text.magnifyingglass", iconColor: SaneSettingsIconSemantic.content.color) {
                                HStack(spacing: 8) {
                                    Text("→ \(rule.kind.displayName)\(rule.party.map { " · \($0)" } ?? "")")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white)
                                    Button("Delete") { model.deleteTagRule(id: rule.id) }
                                        .buttonStyle(.plain)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        CompactDivider()
                        CompactRow("Add rule", icon: "plus", iconColor: SaneSettingsIconSemantic.content.color) {
                            VStack(alignment: .trailing, spacing: 8) {
                                TextField("Memo contains", text: $newRuleMemo)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white)
                                    .frame(width: 140)
                                TextField("Party (optional)", text: $newRuleParty)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white)
                                    .frame(width: 140)
                                Picker("Kind", selection: $newRuleKind) {
                                    Text("Income").tag(ClassificationKind.income)
                                    Text("Expense").tag(ClassificationKind.expense)
                                    Text("Excluded").tag(ClassificationKind.excluded)
                                }
                                .labelsHidden()
                                .frame(width: 120)
                                Button("Add") {
                                    let party = newRuleParty.trimmingCharacters(in: .whitespacesAndNewlines)
                                    model.addTagRule(TagRule(
                                        memoContains: newRuleMemo,
                                        kind: newRuleKind,
                                        party: party.isEmpty ? nil : party
                                    ))
                                    newRuleMemo = ""
                                    newRuleParty = ""
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.saneAccent)
                                .disabled(newRuleMemo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                    } else {
                        CompactRow("Rules", icon: "info.circle", iconColor: SaneSettingsIconSemantic.content.color) {
                            Text("Import a vault to add memo rules.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private var appearanceTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CompactSection("Appearance", icon: "paintbrush.fill", iconColor: SaneSettingsIconSemantic.appearance.color) {
                    CompactRow("Theme", icon: "circle.lefthalf.filled", iconColor: SaneSettingsIconSemantic.appearance.color) {
                        Text("System")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(16)
        }
    }

    private var privacyTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CompactSection("Privacy", icon: "hand.raised.fill", iconColor: SaneSettingsIconSemantic.rules.color) {
                    CompactToggle(
                        label: "Truncate txids in ledger",
                        icon: "scissors",
                        iconColor: SaneSettingsIconSemantic.rules.color,
                        isOn: $model.truncateTxidsInUI
                    )
                    CompactDivider()
                    CompactToggle(
                        label: "Require passphrase to open vault",
                        icon: "lock.fill",
                        iconColor: SaneSettingsIconSemantic.rules.color,
                        isOn: $model.requirePassphraseToOpenVault
                    )
                }
            }
            .padding(16)
        }
    }

    private var advancedTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CompactSection("Advanced", icon: "gearshape.2.fill", iconColor: SaneSettingsIconSemantic.storage.color) {
                    CompactRow("Reset sync state", icon: "arrow.counterclockwise", iconColor: SaneSettingsIconSemantic.storage.color) {
                        Button("Reset…") {
                            if model.vault != nil {
                                model.syncNow()
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.saneAccent)
                        .disabled(model.vault == nil)
                    }
                }
            }
            .padding(16)
        }
    }

    private var licenseTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CompactSection("License", icon: "checkmark.seal.fill", iconColor: SaneSettingsIconSemantic.license.color) {
                    CompactRow("Status", icon: "key.fill", iconColor: SaneSettingsIconSemantic.license.color) {
                        Text("Direct download — license stub")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(16)
        }
    }

    private var aboutTab: some View {
        SaneAboutView(
            appName: "SaneBooks",
            githubRepo: "SaneBooks",
            licenses: [SaneAboutLicenseCatalog.saneUI]
        )
    }

    private func truncatedFingerprint(_ fp: String) -> String {
        guard fp.count > 12 else { return fp }
        return String(fp.prefix(6)) + "…" + String(fp.suffix(4))
    }
}
