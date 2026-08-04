import SwiftUI

public struct WelcomeView: View {
    @Bindable var model: AppModel

    public var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 24)
            SaneBooksBrandMark(size: 96)
                .padding(.bottom, 4)
            VStack(spacing: 8) {
                Text("SaneBooks")
                    .font(.system(size: SaneBooksType.hero, weight: .bold))
                    .foregroundStyle(.white)
                Text("Private books for shielded Zcash")
                    .font(.system(size: SaneBooksType.title, weight: .semibold))
                    .foregroundStyle(Color.saneBooksAccentSoft)
            }

            VStack(spacing: 6) {
                Text("Import a viewing key. Build a ledger. Share a proof")
                    .font(.system(size: SaneBooksType.body, weight: .medium))
                    .foregroundStyle(SaneBooksTheme.pageIvory)
                Text("pack with your accountant — without spend keys.")
                    .font(.system(size: SaneBooksType.body, weight: .medium))
                    .foregroundStyle(SaneBooksTheme.pageIvory)
                Text("Fastest: import from Zashi or Zodl — or paste a viewing key.")
                    .font(.system(size: SaneBooksType.body, weight: .semibold))
                    .foregroundStyle(Color.saneBooksAccentSoft)
                    .padding(.top, 4)
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
            .font(.system(size: SaneBooksType.body, weight: .semibold))
            .foregroundStyle(Color.saneBooksAccent)

            Divider()
                .overlay(Color.saneBooksAccent.opacity(0.35))
                .padding(.horizontal, 80)

            Text("This app cannot spend ZEC. Never paste a seed phrase.")
                .font(.system(size: SaneBooksType.body, weight: .medium))
                .foregroundStyle(SaneBooksTheme.pageIvory)

            Button("Open Proof Pack Reader") {
                model.goReader()
            }
            .buttonStyle(.plain)
            .font(.system(size: SaneBooksType.body, weight: .semibold))
            .foregroundStyle(Color.saneBooksAccent)

            Spacer(minLength: 24)
        }
        .padding(40)
        .sheet(isPresented: $model.showWhatIsViewingKey) {
            whatIsViewingKeySheet
        }
    }

    private var whatIsViewingKeySheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What is a viewing key?")
                .font(.system(size: SaneBooksType.display, weight: .bold))
                .foregroundStyle(.white)
            Text("A viewing key lets SaneBooks read your private payment history and build books. It cannot move funds.")
                .font(.system(size: SaneBooksType.body, weight: .medium))
                .foregroundStyle(SaneBooksTheme.pageIvory)
            Text("Use a full viewing key for complete books (income, change, and expenses). An incoming-only key can see payments received, but may mis-count change as income.")
                .font(.system(size: SaneBooksType.body, weight: .medium))
                .foregroundStyle(SaneBooksTheme.pageIvory)
            Text("Never paste a seed phrase or spending key.")
                .font(.system(size: SaneBooksType.body, weight: .semibold))
                .foregroundStyle(Color.saneBooksAccent)
            Spacer(minLength: 12)
            ActionButton("Close", style: .secondary) {
                model.showWhatIsViewingKey = false
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(28)
        .frame(minWidth: 440, minHeight: 320)
        .background(SaneBooksInkBackground())
    }
}
