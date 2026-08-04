import SwiftUI

struct SaneBooksOnboardingView: View {
    private struct Page {
        let eyebrow: String
        let title: String
        let summary: String
        let icon: String
        let bullets: [(icon: String, text: String)]
    }

    private static let pages = [
        Page(
            eyebrow: "SAFE, READ-ONLY ACCESS",
            title: "View activity without moving money",
            summary: "SaneBooks uses a viewing key to build your records. It cannot send or spend your ZEC.",
            icon: "key.horizontal.fill",
            bullets: [
                ("checkmark.shield.fill", "For complete records, use the full viewing key from your wallet. A receive-only key may miss spending and change."),
                ("exclamationmark.triangle.fill", "Never enter recovery words or a spending key. SaneBooks will refuse them."),
                ("person.2.slash.fill", "Give your accountant an export, not your viewing key. A viewing key can reveal past and future activity."),
            ]
        ),
        Page(
            eyebrow: "STORED ON THIS MAC",
            title: "Keep your books on your Mac",
            summary: "Your wallet access and accounting data stay local. SaneBooks does not upload your ledger or track how you use the app.",
            icon: "lock.laptopcomputer",
            bullets: [
                ("internaldrive.fill", "Your viewing key and books are stored only on this Mac and are not included in backups."),
                ("network", "SaneBooks asks a Zcash server for transaction data. That server can see your internet address and may return incomplete data. You can choose your own server in Settings."),
                ("dollarsign.circle.fill", "Enter the dollar value you want recorded. SaneBooks never guesses a past exchange rate."),
            ]
        ),
        Page(
            eyebrow: "READY FOR YOUR ACCOUNTANT",
            title: "Share only what is needed",
            summary: "Review and label transactions, then create a clear file for the period you choose.",
            icon: "doc.text.magnifyingglass",
            bullets: [
                ("tag.fill", "Mark each item as income, expense, change, or fee. SaneBooks shows that a payment happened, but only you can confirm who it came from."),
                ("lock.doc.fill", "The private SaneBooks file does not include your viewing key. Add a password and expiration date, and the app warns if the file was changed."),
                ("doc.plaintext.fill", "PDF and CSV files are easy to open, but SaneBooks cannot protect them after you save or send them."),
            ]
        ),
    ]

    @Bindable var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var page: Page {
        Self.pages[model.onboardingPage]
    }

    var body: some View {
        VStack(spacing: 0) {
            onboardingHeader

            GeometryReader { geometry in
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 18) {
                        pageCard
                        onboardingFooter
                    }
                    .frame(maxWidth: 700)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: geometry.size.height,
                        alignment: .center
                    )
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityIdentifier("sanebooks.onboarding")
    }

    private var onboardingHeader: some View {
        HStack(spacing: 14) {
            SaneBooksBrandMark(size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text("SaneBooks")
                    .saneBooksFont(size: SaneBooksType.display, weight: .bold)
                    .foregroundStyle(.white)
                Text("Private books for shielded Zcash")
                    .saneBooksFont(size: SaneBooksType.body, weight: .semibold)
                    .foregroundStyle(Color.saneBooksAccentSoft)
            }
            Spacer(minLength: 12)
            Text("A quick setup for private books")
                .saneBooksFont(size: SaneBooksType.body, weight: .semibold)
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }

    private var pageCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                Image(systemName: page.icon)
                    .saneBooksFont(size: 30, weight: .semibold)
                    .foregroundStyle(Color.saneBooksAccent)
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(Color.saneBooksAccent.opacity(0.12)))
                    .overlay(Circle().stroke(Color.saneBooksAccent.opacity(0.45), lineWidth: 1))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 8) {
                    Text(page.eyebrow)
                        .saneBooksFont(size: 12, weight: .bold)
                        .foregroundStyle(Color.saneBooksAccentSoft)
                    Text(page.title)
                        .saneBooksFont(size: SaneBooksType.display, weight: .bold)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(page.summary)
                        .saneBooksFont(size: SaneBooksType.body, weight: .medium)
                        .foregroundStyle(SaneBooksTheme.pageIvory)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(page.bullets.enumerated()), id: \.offset) { _, bullet in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: bullet.icon)
                            .saneBooksFont(size: 16, weight: .semibold)
                            .foregroundStyle(Color.saneBooksAccentSoft)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        Text(bullet.text)
                            .saneBooksFont(size: SaneBooksType.body, weight: .medium)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: 660, alignment: .leading)
        .background(
            SaneGlassRoundedBackground(
                cornerRadius: 20,
                tint: SaneBooksTheme.panelTint,
                edgeTint: SaneBooksTheme.goldSoft,
                tintStrength: 0.26,
                glowOpacity: 0.10
            )
        )
        .frame(maxWidth: .infinity)
        .id(model.onboardingPage)
        .transition(.opacity.combined(with: .scale(scale: 0.985)))
        .accessibilityIdentifier("sanebooks.onboarding.page.\(model.onboardingPage + 1)")
    }

    private var onboardingFooter: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                ForEach(Self.pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index <= model.onboardingPage ? Color.saneBooksAccent : Color.white.opacity(0.22))
                        .frame(maxWidth: 72, minHeight: 4, maxHeight: 4)
                }
            }
            .frame(maxWidth: 230)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Introduction progress")
            .accessibilityValue("Step \(model.onboardingPage + 1) of \(Self.pages.count)")

            HStack(spacing: 12) {
                if model.onboardingPage > 0 {
                    Button("Back") {
                        changePage(forward: false)
                    }
                    .buttonStyle(SaneActionButtonStyle())
                    .saneBooksFont(size: SaneBooksType.body, weight: .semibold)
                    .accessibilityIdentifier("sanebooks.onboarding.back")
                }

                Spacer(minLength: 12)

                if model.onboardingPage < Self.pages.count - 1 {
                    Button("Continue") {
                        changePage(forward: true)
                    }
                    .buttonStyle(SaneActionButtonStyle(prominent: true))
                    .saneBooksFont(size: SaneBooksType.body, weight: .bold)
                    .accessibilityIdentifier("sanebooks.onboarding.next")
                } else {
                    finalActions
                }
            }
            .frame(maxWidth: 700)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }

    private var finalActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                readerButton
                ownerButton
            }
            VStack(alignment: .trailing, spacing: 8) {
                ownerButton
                readerButton
            }
        }
    }

    private var readerButton: some View {
        Button("Open Accountant Reader") {
            model.completeOnboardingForReader()
        }
        .buttonStyle(SaneActionButtonStyle())
        .saneBooksFont(size: SaneBooksType.body, weight: .semibold)
        .accessibilityHint("Opens a proof pack without importing a wallet viewing key")
        .accessibilityIdentifier("sanebooks.onboarding.start-reader")
    }

    private var ownerButton: some View {
        Button("Import Viewing Key") {
            model.completeOnboardingForOwner()
        }
        .buttonStyle(SaneActionButtonStyle(prominent: true))
        .saneBooksFont(size: SaneBooksType.body, weight: .bold)
        .accessibilityHint("Starts the view-only owner bookkeeping setup")
        .accessibilityIdentifier("sanebooks.onboarding.start-owner")
    }

    private func changePage(forward: Bool) {
        if reduceMotion {
            forward ? model.advanceOnboarding() : model.retreatOnboarding()
        } else {
            withAnimation(.easeInOut(duration: 0.22)) {
                forward ? model.advanceOnboarding() : model.retreatOnboarding()
            }
        }
    }
}

public struct WelcomeView: View {
    @Bindable var model: AppModel

    public var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 24)
            SaneBooksBrandMark(size: 96)
                .padding(.bottom, 4)
            VStack(spacing: 8) {
                Text("SaneBooks")
                    .saneBooksFont(size: SaneBooksType.hero, weight: .bold)
                    .foregroundStyle(.white)
                Text("Private books for shielded Zcash")
                    .saneBooksFont(size: SaneBooksType.title, weight: .semibold)
                    .foregroundStyle(Color.saneBooksAccentSoft)
            }

            VStack(spacing: 6) {
                Text("Import a viewing key. Build a ledger. Share a proof")
                    .saneBooksFont(size: SaneBooksType.body, weight: .medium)
                    .foregroundStyle(SaneBooksTheme.pageIvory)
                Text("pack with your accountant — without spend keys.")
                    .saneBooksFont(size: SaneBooksType.body, weight: .medium)
                    .foregroundStyle(SaneBooksTheme.pageIvory)
                Text("Fastest: import from Zashi or Zodl — or paste a viewing key.")
                    .saneBooksFont(size: SaneBooksType.body, weight: .semibold)
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
            .saneBooksFont(size: SaneBooksType.body, weight: .semibold)
            .foregroundStyle(Color.saneBooksAccent)

            Divider()
                .overlay(Color.saneBooksAccent.opacity(0.35))
                .padding(.horizontal, 80)

            Text("This app cannot spend ZEC. Never paste a seed phrase.")
                .saneBooksFont(size: SaneBooksType.body, weight: .medium)
                .foregroundStyle(SaneBooksTheme.pageIvory)

            Button("Open Proof Pack Reader") {
                model.goReader()
            }
            .buttonStyle(.plain)
            .saneBooksFont(size: SaneBooksType.body, weight: .semibold)
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
                .saneBooksFont(size: SaneBooksType.display, weight: .bold)
                .foregroundStyle(.white)
            Text("A viewing key lets SaneBooks read your private payment history and build books. It cannot move funds.")
                .saneBooksFont(size: SaneBooksType.body, weight: .medium)
                .foregroundStyle(SaneBooksTheme.pageIvory)
            Text("Use a full viewing key for complete books (income, change, and expenses). An incoming-only key can see payments received, but may mis-count change as income.")
                .saneBooksFont(size: SaneBooksType.body, weight: .medium)
                .foregroundStyle(SaneBooksTheme.pageIvory)
            Text("Never paste a seed phrase or spending key.")
                .saneBooksFont(size: SaneBooksType.body, weight: .semibold)
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
