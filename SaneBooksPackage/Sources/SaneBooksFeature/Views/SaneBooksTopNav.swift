import AppKit
import SwiftUI

/// Top chrome shared by Ledger, Detail, and Proof Pack flows.
/// Matches UX plan: SaneBooks │ Vault │ Proof Packs │ ⚙ Settings
public struct SaneBooksTopNav<Trailing: View>: View {
    public enum MainTab: Equatable, Sendable {
        case vault
        case proofPacks
    }

    public enum Mode: Equatable, Sendable {
        /// Ledger / home: brand + Vault | Proof Packs | Settings
        case main(selected: MainTab)
        /// Nested screens: back to ledger + title + Settings
        case nested(title: String)
    }

    private let mode: Mode
    private let onVault: () -> Void
    private let onProofPacks: () -> Void
    private let onBackToLedger: (() -> Void)?
    private let trailing: Trailing

    public init(
        mode: Mode,
        onVault: @escaping () -> Void,
        onProofPacks: @escaping () -> Void,
        onBackToLedger: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.mode = mode
        self.onVault = onVault
        self.onProofPacks = onProofPacks
        self.onBackToLedger = onBackToLedger
        self.trailing = trailing()
    }

    public var body: some View {
        Group {
            switch mode {
            case let .main(selected):
                mainNavigation(selected: selected)
            case let .nested(title):
                nestedNavigation(title: title)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        // The ledger table is intentionally flexible. Keep primary navigation from
        // being compressed out of sight when a short window needs that space.
        .fixedSize(horizontal: false, vertical: true)
        .layoutPriority(10)
    }

    private func mainNavigation(selected: MainTab) -> some View {
        HStack(spacing: 20) {
            HStack(spacing: 10) {
                SaneBooksBrandMark(size: 28)
                Text("ZecBooks")
                    .saneBooksFont(size: SaneBooksType.title, weight: .bold)
                    .foregroundStyle(.white)
            }
            tabLink("Vault", selected: selected == .vault, action: onVault)
                .accessibilityIdentifier("sanebooks.nav.vault")
            tabLink("Proof Packs", selected: selected == .proofPacks, action: onProofPacks)
                .accessibilityIdentifier("sanebooks.nav.proof-packs")
            Spacer(minLength: 12)
            trailing
            settingsControl
                .accessibilityLabel("Open settings")
                .accessibilityHint("Opens ZecBooks settings")
                .accessibilityIdentifier("sanebooks.nav.settings")
        }
    }

    private func nestedNavigation(title: String) -> some View {
        HStack(spacing: 12) {
            backToLedgerButton
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(title)
                .saneBooksFont(size: SaneBooksType.title, weight: .bold)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                trailing
                settingsControl
                    .accessibilityLabel("Open settings")
                    .accessibilityHint("Opens ZecBooks settings")
                    .accessibilityIdentifier("sanebooks.nav.settings")
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var backToLedgerButton: some View {
        Button {
            onBackToLedger?()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.backward")
                Text("Ledger")
            }
            .saneBooksFont(size: SaneBooksType.body, weight: .semibold)
            .foregroundStyle(Color.saneBooksAccent)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back to ledger")
        .accessibilityHint("Returns to the vault ledger")
        .accessibilityIdentifier("sanebooks.nav.back-to-ledger")
    }

    @ViewBuilder
    private var settingsControl: some View {
        if #available(macOS 14.0, *) {
            SettingsLink {
                settingsLabel
            }
            .buttonStyle(.plain)
        } else {
            Button(action: openSettingsWindow) {
                settingsLabel
            }
            .buttonStyle(.plain)
        }
    }

    private var settingsLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "gearshape.fill")
            Text("Settings")
        }
        .saneBooksFont(size: SaneBooksType.body, weight: .semibold)
        .foregroundStyle(Color.saneBooksAccentSoft)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.saneBooksAccent.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.saneBooksAccent.opacity(0.35), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    private func tabLink(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .saneBooksFont(size: SaneBooksType.body, weight: selected ? .bold : .semibold)
                .foregroundStyle(selected ? Color.saneBooksAccent : .white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selected ? Color.saneBooksAccent.opacity(0.16) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityHint(selected ? "Current section" : "Open \(title)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func openSettingsWindow() {
        NotificationCenter.default.post(name: .saneBooksOpenSettings, object: nil)
    }
}

public extension SaneBooksTopNav where Trailing == EmptyView {
    init(
        mode: Mode,
        onVault: @escaping () -> Void,
        onProofPacks: @escaping () -> Void,
        onBackToLedger: (() -> Void)? = nil
    ) {
        self.init(
            mode: mode,
            onVault: onVault,
            onProofPacks: onProofPacks,
            onBackToLedger: onBackToLedger,
            trailing: { EmptyView() }
        )
    }
}

/// Calm status banner for share / reader success and error surfaces.
struct SaneBooksStatusBanner: View {
    enum Kind {
        case success
        case error
        case info
    }

    let kind: Kind
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .saneBooksFont(size: 14, weight: .semibold)
                .foregroundStyle(iconColor)
            Text(message)
                .saneBooksFont(size: 14, weight: .medium)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityMessage)
    }

    private var accessibilityMessage: String {
        switch kind {
        case .success: "Success: \(message)"
        case .error: "Warning: \(message)"
        case .info: "Information: \(message)"
        }
    }

    private var iconName: String {
        switch kind {
        case .success: "checkmark.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        }
    }

    private var iconColor: Color {
        switch kind {
        case .success, .info: Color.saneBooksAccent
        case .error: Color.orange
        }
    }

    private var backgroundColor: Color {
        switch kind {
        case .success, .info: Color.saneBooksAccent.opacity(0.12)
        case .error: Color.orange.opacity(0.14)
        }
    }

    private var borderColor: Color {
        switch kind {
        case .success, .info: Color.saneBooksAccent.opacity(0.35)
        case .error: Color.orange.opacity(0.4)
        }
    }
}
