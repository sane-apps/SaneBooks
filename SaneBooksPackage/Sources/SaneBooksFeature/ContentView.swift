import SaneBooksCore
import SwiftUI

public struct ContentView: View {
    @Bindable var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        ZStack {
            SaneBooksInkBackground()
            if let startupError = model.startupError {
                storageFailure(startupError)
            } else {
                routeContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(minWidth: 820, minHeight: 600)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .saneBooksBrand()
        .saneBooksTextScale(effectiveTextScale)
        .safeAreaInset(edge: .top, spacing: 0) {
            if model.isEphemeralTestSession, !launchArguments.contains("--e2e-marketing") {
                Label("Test data — not saved", systemImage: "testtube.2")
                    .saneBooksFont(size: 13, weight: .bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 24)
                    .background(Color.orange)
                    .accessibilityIdentifier("sanebooks.test-session-banner")
            }
        }
        .transformEnvironment(\.layoutDirection) { direction in
            if launchArguments.contains("--e2e-layout-rtl") {
                direction = .rightToLeft
            }
        }
    }

    private var launchArguments: [String] {
        ProcessInfo.processInfo.arguments
    }

    private var effectiveTextScale: CGFloat {
        #if DEBUG
            if launchArguments.contains("--e2e-accessibility-text") {
                return SaneBooksTextSize.extraLarge.scale
            }
        #endif
        return model.textSize.scale
    }

    private func storageFailure(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Private ledger unavailable", systemImage: "externaldrive.badge.exclamationmark")
                .saneBooksFont(size: SaneBooksType.display, weight: .bold)
                .foregroundStyle(.white)
            Text(message)
                .saneBooksFont(size: 15, weight: .medium)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text("ZecBooks will not fall back to temporary or in-memory bookkeeping storage.")
                .saneBooksFont(size: 14, weight: .semibold)
                .foregroundStyle(.white)
        }
        .padding(24)
        .frame(maxWidth: 560, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.red.opacity(0.8), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var routeContent: some View {
        switch model.route {
        case .onboarding:
            SaneBooksOnboardingView(model: model)
        case .welcome:
            WelcomeView(model: model)
        case .importKey:
            ImportViewingKeyView(model: model)
        case .syncing:
            SyncProgressView(model: model)
        case .ledger:
            LedgerView(model: model)
        case let .noteDetail(id):
            TransactionDetailView(model: model, noteID: id)
        case .proofPackBuilder:
            ProofPackBuilderView(model: model)
        case .sharePack:
            ShareProofPackView(model: model)
        case .reader:
            ReaderView(model: model)
        }
    }
}
