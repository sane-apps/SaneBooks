import SwiftUI

public struct WelcomeView: View {
    @Bindable var model: AppModel

    public var body: some View {
        VStack(spacing: 28) {
            Spacer()
            SaneBooksBrandMark(size: 88)
                .padding(.bottom, 8)
            VStack(spacing: 12) {
                Text("SaneBooks")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                Text("Private books for shielded Zcash")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                Text("Import a viewing key. Build a ledger. Share a proof")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                Text("pack with your accountant — without spend keys.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
            }
            .multilineTextAlignment(.center)

            ActionButton("Import Viewing Key", icon: "key.fill") {
                model.goImport()
            }
            .frame(width: 280)

            Button("What is a viewing key?") {
                model.showWhatIsViewingKey = true
            }
            .buttonStyle(.plain)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.saneBooksAccent)

            Divider()
                .overlay(Color.white.opacity(0.2))
                .padding(.horizontal, 80)

            Text("This app cannot spend ZEC. Never paste a seed phrase.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)

            Button("Open Proof Pack Reader") {
                model.goReader()
            }
            .buttonStyle(.plain)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.saneBooksAccent)

            Spacer()
        }
        .padding(40)
        .sheet(isPresented: $model.showWhatIsViewingKey) {
            whatIsViewingKeySheet
        }
    }

    private var whatIsViewingKeySheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What is a viewing key?")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Text("A viewing key lets SaneBooks scan your shielded transaction history and build books. It cannot move funds.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
            Text("Use a Unified Full Viewing Key (uview…) for full bookkeeping. Incoming-only keys (uivk…) work for receivables but cannot detect change or expenses reliably.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
            Text("Never paste a seed phrase or spending key.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.saneBooksAccent)
            Spacer()
            ActionButton("Close", style: .secondary) {
                model.showWhatIsViewingKey = false
            }
        }
        .padding(28)
        .frame(minWidth: 440, minHeight: 320)
        .background(SaneBooksInkBackground())
    }
}
