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
        HStack(spacing: 20) {
            switch mode {
            case let .main(selected):
                HStack(spacing: 10) {
                    SaneBooksBrandMark(size: 28)
                    Text("SaneBooks")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                tabLink("Vault", selected: selected == .vault, action: onVault)
                tabLink("Proof Packs", selected: selected == .proofPacks, action: onProofPacks)
            case let .nested(title):
                Button {
                    onBackToLedger?()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Ledger")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.saneAccent)
                }
                .buttonStyle(.plain)
                Spacer(minLength: 8)
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 12)
            trailing
            settingsControl
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
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
            Image(systemName: "gearshape")
            Text("Settings")
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.white)
        .contentShape(Rectangle())
    }

    private func tabLink(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: selected ? .bold : .semibold))
                .foregroundStyle(selected ? Color.saneAccent : .white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selected ? Color.saneAccent.opacity(0.16) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    private func openSettingsWindow() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
            Text(message)
                .font(.system(size: 14, weight: .medium))
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
        case .success, .info: Color.saneAccent
        case .error: Color.orange
        }
    }

    private var backgroundColor: Color {
        switch kind {
        case .success, .info: Color.saneAccent.opacity(0.12)
        case .error: Color.orange.opacity(0.14)
        }
    }

    private var borderColor: Color {
        switch kind {
        case .success, .info: Color.saneAccent.opacity(0.35)
        case .error: Color.orange.opacity(0.4)
        }
    }
}
