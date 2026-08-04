import SaneBooksCore
import SwiftUI

/// Shared by header + NoteRowView — keep widths identical.
enum LedgerColumns {
    static let spacing: CGFloat = 10
    /// Wide enough for "Sep 30, 2025" at 13pt medium — never wrap dates.
    static let date: CGFloat = 100
    static let kind: CGFloat = 92
    static let zec: CGFloat = 96
    static let usd: CGFloat = 72
    static let tag: CGFloat = 120
    static let rowInset: CGFloat = 12
}

public struct LedgerView: View {
    @Bindable var model: AppModel
    @Environment(\.saneBooksTextScale) private var textScale

    public var body: some View {
        if textScale > SaneBooksTextSize.standard.scale {
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: true) {
                    ledgerContent
                }
                .accessibilityIdentifier("sanebooks.ledger.large-text-scroll")
                footerChrome
            }
        } else {
            ledgerContent
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    footerChrome
                }
        }
    }

    private var footerChrome: some View {
        footerBar
            .padding(.horizontal, 28)
            .padding(.top, 10)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SaneBooksTheme.ink.opacity(0.96))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.saneBooksAccent.opacity(0.35))
                    .frame(height: 1)
            }
            .fixedSize(horizontal: false, vertical: true)
    }

    private var ledgerContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            SaneBooksTopNav(
                mode: .main(selected: .vault),
                onVault: { model.route = .ledger },
                onProofPacks: { model.beginProofPack() }
            )
            .padding(.bottom, 16)

            VStack(alignment: .leading, spacing: 20) {
                vaultIdentityRow
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(9)

                if model.showsIVKUpgradeBanner {
                    upgradeBanner
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(8)
                } else if let vault = model.vault, let banner = vault.capabilitiesBanner {
                    degradedBanner(banner)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(8)
                }

                SyncBanner(cursor: model.cursor)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(8)

                summaryPanel
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(7)

                ledgerPanel
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Identity

    private var vaultIdentityRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if model.vaults.count > 1 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BOOKS")
                        .saneBooksFont(size: SaneBooksType.body, weight: .bold)
                        .tracking(0.6)
                        .foregroundStyle(Color.saneBooksAccentSoft)
                    Picker("Books", selection: vaultPickerBinding) {
                        ForEach(model.vaults) { v in
                            Text(v.displayName).tag(Optional(v.id))
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 320, alignment: .leading)
                }
            } else if let vault = model.vault {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BOOKS")
                        .saneBooksFont(size: SaneBooksType.body, weight: .bold)
                        .tracking(0.6)
                        .foregroundStyle(Color.saneBooksAccentSoft)
                    Text(vault.displayName)
                        .saneBooksFont(size: SaneBooksType.display, weight: .bold)
                        .foregroundStyle(.white)
                        .accessibilityIdentifier("sanebooks.vault.name")
                    Text("Viewing-key books — cannot spend")
                        .saneBooksFont(size: SaneBooksType.body, weight: .medium)
                        .foregroundStyle(SaneBooksTheme.pageIvory.opacity(0.9))
                }
            }
            Spacer(minLength: 0)
            Button {
                model.discreetMode.toggle()
            } label: {
                Label(
                    model.discreetMode ? "Discreet on" : "Discreet",
                    systemImage: model.discreetMode ? "eye.slash.fill" : "eye.slash"
                )
                .saneBooksFont(size: SaneBooksType.body, weight: .semibold)
                .foregroundStyle(model.discreetMode ? Color.saneBooksAccentSoft : .white)
            }
            .buttonStyle(.plain)
            .help("Hide amounts for screen sharing")
            .accessibilityLabel("Discreet mode")
            .accessibilityValue(model.discreetMode ? "On; amounts are masked" : "Off; amounts are visible")
            .accessibilityHint("Masks financial amounts for screen sharing")
            .accessibilityIdentifier("sanebooks.privacy.discreet-mode")
        }
    }

    private var vaultPickerBinding: Binding<VaultID?> {
        Binding(
            get: { model.vault?.id },
            set: { newID in
                if let newID {
                    model.switchVault(newID)
                }
            }
        )
    }

    // MARK: - Banners

    private var upgradeBanner: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(VaultModeBanner.upgradeBannerCopy)
                    .saneBooksFont(size: 14, weight: .semibold)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Button(VaultModeBanner.upgradeCTA) {
                    model.goImport(asUpgrade: true)
                }
                .buttonStyle(.plain)
                .saneBooksFont(size: 14, weight: .bold)
                .foregroundStyle(Color.saneBooksAccentSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.orange.opacity(0.55), lineWidth: 1)
        )
    }

    private func degradedBanner(_ text: String) -> some View {
        Text(text)
            .saneBooksFont(size: 14, weight: .semibold)
            .foregroundStyle(.white)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.22))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.orange.opacity(0.55), lineWidth: 1)
            )
    }

    // MARK: - Summary

    private var summaryPanel: some View {
        HStack(alignment: .top, spacing: 0) {
            summaryStat(
                title: "Income YTD",
                zec: model.incomeYTD,
                usd: incomeUSD,
                accent: Color.saneBooksAccent
            )
            summaryDivider
            summaryStat(
                title: "Expenses YTD",
                zec: model.expenseYTD,
                usd: expenseUSD,
                accent: Color.orange
            )
            summaryDivider
            untaggedStat
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            SaneGlassRoundedBackground(
                cornerRadius: 12,
                tint: SaneBooksTheme.panelTint,
                tintStrength: 0.28,
                glowOpacity: 0.12
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.saneBooksAccent.opacity(0.22), lineWidth: 1)
        )
    }

    private var summaryDivider: some View {
        Rectangle()
            .fill(Color.saneBooksAccent.opacity(0.28))
            .frame(width: 1, height: 52)
            .padding(.horizontal, 22)
    }

    private func summaryStat(title: String, zec: Decimal, usd: Decimal?, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .saneBooksFont(size: SaneBooksType.body, weight: .bold)
                .tracking(0.6)
                .foregroundStyle(accent)
            Text(model.discreetMode ? "•••• ZEC" : "\(formatZEC(zec)) ZEC")
                .saneBooksFont(size: 17, weight: .bold, design: .rounded)
                .foregroundStyle(.white)
            Text(model.discreetMode ? "•••• USD*" : (usd.map { "$\(formatFiat($0)) USD*" } ?? "— USD*"))
                .saneBooksFont(size: SaneBooksType.body, weight: .semibold)
                .foregroundStyle(SaneBooksTheme.pageIvory.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }

    private var untaggedStat: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("UNTAGGED")
                .saneBooksFont(size: SaneBooksType.body, weight: .bold)
                .tracking(0.6)
                .foregroundStyle(model.untaggedCount > 0 ? Color.saneBooksAccentSoft : Color.saneBooksAccent)
            Text("\(model.untaggedCount)")
                .saneBooksFont(size: 17, weight: .bold, design: .rounded)
                .foregroundStyle(model.untaggedCount > 0 ? Color.saneBooksAccentSoft : .white)
            if model.untaggedCount > 0 {
                Button("Review") {
                    model.beginUntaggedReview()
                }
                .buttonStyle(.plain)
                .saneBooksFont(size: SaneBooksType.body, weight: .bold)
                .foregroundStyle(Color.saneBooksAccentSoft)
            } else {
                Text("All tagged")
                    .saneBooksFont(size: SaneBooksType.body, weight: .semibold)
                    .foregroundStyle(SaneBooksTheme.pageIvory.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }

    private var incomeUSD: Decimal? {
        usdTotal(for: .income)
    }

    private var expenseUSD: Decimal? {
        usdTotal(for: .expense)
    }

    private func usdTotal(for kind: ClassificationKind) -> Decimal? {
        let year = Calendar.current.component(.year, from: Date())
        var sum: Decimal = 0
        var any = false
        for note in model.notes {
            guard note.effectiveKind == kind else { continue }
            guard let date = note.blockTime,
                  Calendar.current.component(.year, from: date) == year
            else { continue }
            if let fiat = note.fiatMark?.amount(forZEC: abs(note.amountZEC)) {
                sum += fiat
                any = true
            }
        }
        return any ? sum : nil
    }

    // MARK: - Ledger table

    private var ledgerPanel: some View {
        let filtered = model.filteredNotes
        return VStack(alignment: .leading, spacing: 16) {
            filterBar
            if filtered.isEmpty {
                SaneEmptyState(
                    icon: "tray",
                    title: "No notes yet",
                    description: "When shielded payments arrive, rows appear here automatically."
                )
                .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                ScrollView(tableScrollAxes) {
                    VStack(alignment: .leading, spacing: 0) {
                        ledgerHeaderRow
                        LazyVStack(spacing: 0) {
                            ForEach(filtered) { note in
                                NoteRowView(
                                    note: note,
                                    truncateTxid: model.truncateTxidsInUI,
                                    discreetMode: model.discreetMode
                                ) {
                                    model.openNote(note.id)
                                }
                                .padding(.horizontal, LedgerColumns.rowInset)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.035))
                            }
                        }
                    }
                    .frame(
                        minWidth: 760 * textScale,
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .topLeading
                    )
                }
                .accessibilityIdentifier("sanebooks.ledger.rows-scroll")
                .frame(minHeight: 80, maxHeight: .infinity)
                .fixedSize(
                    horizontal: false,
                    vertical: textScale > SaneBooksTextSize.standard.scale
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            SaneGlassRoundedBackground(
                cornerRadius: 14,
                tint: SaneBooksTheme.panelTint,
                tintStrength: 0.18,
                glowOpacity: 0.08
            )
        )
    }

    private var tableScrollAxes: Axis.Set {
        textScale > SaneBooksTextSize.standard.scale ? .horizontal : [.horizontal, .vertical]
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: 18) {
                labeledControl("Kind") {
                    Picker("Kind filter", selection: kindBinding) {
                        Text("All").tag(ClassificationKind?.none)
                        ForEach([ClassificationKind.income, .expense, .change, .fee, .untagged], id: \.self) { k in
                            Text(k.displayName).tag(Optional(k))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 128)
                    .accessibilityIdentifier("sanebooks.filter.kind")
                }

                labeledControl("Year") {
                    Picker("Year filter", selection: yearBinding) {
                        Text("All years").tag(Int?.none)
                        ForEach(availableYears, id: \.self) { y in
                            Text(String(y)).tag(Optional(y))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 110)
                    .accessibilityIdentifier("sanebooks.filter.year")
                }

                Toggle("Untagged only", isOn: $model.filters.untaggedOnly)
                    .saneBooksFont(size: SaneBooksType.body, weight: .semibold)
                    .foregroundStyle(.white)
                    .toggleStyle(.checkbox)
                    .padding(.top, 16)
                    .accessibilityIdentifier("sanebooks.filter.untagged-only")

                Color.clear.frame(width: 12)

                TextField("Search memo or tag", text: $model.filters.searchText)
                    .textFieldStyle(.plain)
                    .saneBooksFont(size: SaneBooksType.body, weight: .medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(minWidth: 200, maxWidth: 280)
                    .background(Color.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.saneBooksAccent.opacity(0.35), lineWidth: 1)
                    )
                    .foregroundStyle(.white)
                    .padding(.top, 16)
                    .accessibilityLabel("Search notes by memo or tag")
                    .accessibilityHint("Filters the ledger as you type")
                    .accessibilityIdentifier("sanebooks.filter.search")
            }
            .padding(.bottom, 4)
        }
    }

    private func labeledControl(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .saneBooksFont(size: SaneBooksType.body, weight: .bold)
                .tracking(0.5)
                .foregroundStyle(Color.saneBooksAccentSoft)
            content()
        }
    }

    private var kindBinding: Binding<ClassificationKind?> {
        Binding(
            get: { model.filters.kind },
            set: { model.filters.kind = $0 }
        )
    }

    private var yearBinding: Binding<Int?> {
        Binding(
            get: { model.filters.year },
            set: { model.filters.year = $0 }
        )
    }

    private var availableYears: [Int] {
        let years = model.notes.compactMap { note -> Int? in
            guard let d = note.blockTime else { return nil }
            return Calendar.current.component(.year, from: d)
        }
        return Array(Set(years)).sorted(by: >)
    }

    private var ledgerHeaderRow: some View {
        HStack(spacing: LedgerColumns.spacing) {
            Text("Date").frame(width: LedgerColumns.date * textScale, alignment: .leading)
            Text("Type").frame(width: LedgerColumns.kind * textScale, alignment: .leading)
            Text("ZEC").frame(width: LedgerColumns.zec * textScale, alignment: .trailing)
            Text("USD*").frame(width: LedgerColumns.usd * textScale, alignment: .trailing)
            Text("Tag").frame(width: LedgerColumns.tag * textScale, alignment: .leading)
            Text("Memo").frame(maxWidth: .infinity, alignment: .leading)
        }
        .saneBooksFont(size: SaneBooksType.body, weight: .bold)
        .tracking(0.3)
        .foregroundStyle(Color.saneBooksAccentSoft)
        .padding(.horizontal, LedgerColumns.rowInset)
        .padding(.vertical, 8)
        .background(Color.saneBooksAccent.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack(alignment: .center, spacing: 16) {
            ActionButton("New Proof Pack", icon: "doc.badge.plus") {
                model.beginProofPack()
            }
            .disabled(model.vault == nil)

            Text("* USD at confirmation time. Not advice.")
                .saneBooksFont(size: SaneBooksType.body, weight: .medium)
                .foregroundStyle(SaneBooksTheme.pageIvory.opacity(0.9))

            Spacer(minLength: 0)
        }
    }
}
