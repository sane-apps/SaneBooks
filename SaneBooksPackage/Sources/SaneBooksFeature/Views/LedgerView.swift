import SaneBooksCore
import SwiftUI

/// Shared by header + NoteRowView — keep widths identical.
private enum LedgerColumns {
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

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SaneBooksTopNav(
                mode: .main(selected: .vault),
                onVault: { model.route = .ledger },
                onProofPacks: { model.beginProofPack() }
            )
            .padding(.bottom, 16)

            VStack(alignment: .leading, spacing: 20) {
                vaultIdentityRow

                if model.showsIVKUpgradeBanner {
                    upgradeBanner
                } else if let vault = model.vault, let banner = vault.capabilitiesBanner {
                    degradedBanner(banner)
                }

                SyncBanner(cursor: model.cursor)

                summaryPanel

                ledgerPanel
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .safeAreaInset(edge: .bottom, spacing: 0) {
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
        }
    }

    // MARK: - Identity

    private var vaultIdentityRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if model.vaults.count > 1 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BOOKS")
                        .font(.system(size: SaneBooksType.body, weight: .bold))
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
                        .font(.system(size: SaneBooksType.body, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(Color.saneBooksAccentSoft)
                    Text(vault.displayName)
                        .font(.system(size: SaneBooksType.display, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Viewing-key books — cannot spend")
                        .font(.system(size: SaneBooksType.body, weight: .medium))
                        .foregroundStyle(SaneBooksTheme.pageIvory.opacity(0.85))
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
                .font(.system(size: SaneBooksType.body, weight: .semibold))
                .foregroundStyle(model.discreetMode ? Color.saneBooksAccentSoft : .white)
            }
            .buttonStyle(.plain)
            .help("Hide amounts for screen sharing")
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Button(VaultModeBanner.upgradeCTA) {
                    model.goImport(asUpgrade: true)
                }
                .buttonStyle(.plain)
                .font(.system(size: 14, weight: .bold))
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
            .font(.system(size: 14, weight: .semibold))
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
                .font(.system(size: SaneBooksType.body, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(accent)
            Text(model.discreetMode ? "•••• ZEC" : "\(formatZEC(zec)) ZEC")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(model.discreetMode ? "•••• USD*" : (usd.map { "$\(formatFiat($0)) USD*" } ?? "— USD*"))
                .font(.system(size: SaneBooksType.body, weight: .semibold))
                .foregroundStyle(SaneBooksTheme.pageIvory.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }

    private var untaggedStat: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("UNTAGGED")
                .font(.system(size: SaneBooksType.body, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(model.untaggedCount > 0 ? Color.saneBooksAccentSoft : Color.saneBooksAccent.opacity(0.7))
            Text("\(model.untaggedCount)")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(model.untaggedCount > 0 ? Color.saneBooksAccentSoft : .white)
            if model.untaggedCount > 0 {
                Button("Review") {
                    model.beginUntaggedReview()
                }
                .buttonStyle(.plain)
                .font(.system(size: SaneBooksType.body, weight: .bold))
                .foregroundStyle(Color.saneBooksAccentSoft)
            } else {
                Text("All tagged")
                    .font(.system(size: SaneBooksType.body, weight: .semibold))
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
        VStack(alignment: .leading, spacing: 16) {
            filterBar
            if model.filteredNotes.isEmpty {
                SaneEmptyState(
                    icon: "tray",
                    title: "No notes yet",
                    description: "When shielded payments arrive, rows appear here automatically."
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                ledgerHeaderRow
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(model.filteredNotes.enumerated()), id: \.element.id) { index, note in
                            NoteRowView(
                                note: note,
                                truncateTxid: model.truncateTxidsInUI,
                                discreetMode: model.discreetMode
                            ) {
                                model.openNote(note.id)
                            }
                            .padding(.horizontal, LedgerColumns.rowInset)
                            .padding(.vertical, 4)
                            .background(index % 2 == 0 ? Color.white.opacity(0.04) : Color.clear)
                        }
                    }
                }
                .frame(minHeight: 260, maxHeight: .infinity)
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

    private var filterBar: some View {
        HStack(spacing: 18) {
            labeledControl("Kind") {
                Picker("", selection: kindBinding) {
                    Text("All").tag(ClassificationKind?.none)
                    ForEach([ClassificationKind.income, .expense, .change, .fee, .untagged], id: \.self) { k in
                        Text(k.displayName).tag(Optional(k))
                    }
                }
                .labelsHidden()
                .frame(width: 128)
            }

            labeledControl("Year") {
                Picker("", selection: yearBinding) {
                    Text("All years").tag(Int?.none)
                    ForEach(availableYears, id: \.self) { y in
                        Text(String(y)).tag(Optional(y))
                    }
                }
                .labelsHidden()
                .frame(width: 110)
            }

            Toggle("Untagged only", isOn: $model.filters.untaggedOnly)
                .font(.system(size: SaneBooksType.body, weight: .semibold))
                .foregroundStyle(.white)
                .toggleStyle(.checkbox)
                .padding(.top, 16)

            Spacer(minLength: 12)

            TextField("Search memo or tag", text: $model.filters.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: SaneBooksType.body, weight: .medium))
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
        }
    }

    private func labeledControl(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: SaneBooksType.body, weight: .bold))
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
            Text("Date").frame(width: LedgerColumns.date, alignment: .leading)
            Text("Type").frame(width: LedgerColumns.kind, alignment: .leading)
            Text("ZEC").frame(width: LedgerColumns.zec, alignment: .trailing)
            Text("USD*").frame(width: LedgerColumns.usd, alignment: .trailing)
            Text("Tag").frame(width: LedgerColumns.tag, alignment: .leading)
            Text("Memo").frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: SaneBooksType.body, weight: .bold))
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
            .opacity(model.vault == nil ? 0.45 : 1)

            Text("* USD at confirmation time. Not advice.")
                .font(.system(size: SaneBooksType.body, weight: .medium))
                .foregroundStyle(SaneBooksTheme.pageIvory.opacity(0.85))

            Spacer(minLength: 0)
        }
    }
}

// MARK: - NoteRowView

struct NoteRowView: View {
    let note: NoteRow
    let truncateTxid: Bool
    var discreetMode: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: LedgerColumns.spacing) {
                Text(dateLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .frame(width: LedgerColumns.date, alignment: .leading)

                kindChip
                    .frame(width: LedgerColumns.kind, alignment: .leading)

                Text(discreetMode ? "••••" : formatZEC(abs(note.amountZEC)))
                    .lineLimit(1)
                    .frame(width: LedgerColumns.zec, alignment: .trailing)
                    .font(.system(size: SaneBooksType.body, weight: .semibold, design: .monospaced))
                    .foregroundStyle(note.effectiveKind == .income ? Color.saneBooksAccentSoft : .white)

                if discreetMode {
                    Text("••••")
                        .lineLimit(1)
                        .frame(width: LedgerColumns.usd, alignment: .trailing)
                        .font(.system(size: SaneBooksType.body, weight: .medium, design: .monospaced))
                } else if let fiat = note.fiatMark?.amount(forZEC: abs(note.amountZEC)) {
                    Text("$\(formatFiat(fiat))")
                        .lineLimit(1)
                        .frame(width: LedgerColumns.usd, alignment: .trailing)
                        .font(.system(size: SaneBooksType.body, weight: .medium, design: .monospaced))
                } else {
                    Text("—")
                        .frame(width: LedgerColumns.usd, alignment: .trailing)
                }

                Text(tagLabel)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: LedgerColumns.tag, alignment: .leading)
                    .help(tagLabel)

                Text(note.memo.displayText ?? "—")
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .help(note.memo.displayText ?? "")
            }
            .font(.system(size: SaneBooksType.body, weight: .medium))
            .foregroundStyle(.white)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
            .overlay(alignment: .leading) {
                if note.effectiveKind == .untagged {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.saneBooksAccentSoft)
                        .frame(width: 3)
                        .padding(.vertical, 6)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var dateLabel: String {
        guard let date = note.blockTime else { return "—" }
        // Fixed pattern so column width is predictable (abbreviated locale forms vary).
        return date.formatted(
            .dateTime.month(.abbreviated).day().year().locale(Locale(identifier: "en_US_POSIX"))
        )
    }

    private var kindChip: some View {
        Text(kindLabel)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(kindChipForeground)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(kindChipBackground)
            .clipShape(Capsule())
    }

    private var kindChipBackground: Color {
        switch note.effectiveKind {
        case .income: Color.saneBooksAccent.opacity(0.22)
        case .expense: Color.orange.opacity(0.22)
        case .change: Color.white.opacity(0.12)
        case .fee: Color.white.opacity(0.10)
        case .untagged: Color.saneBooksAccentSoft.opacity(0.28)
        case .excluded: Color.white.opacity(0.08)
        }
    }

    private var kindChipForeground: Color {
        switch note.effectiveKind {
        case .income: Color.saneBooksAccentSoft
        case .expense: Color.orange
        case .change, .fee, .excluded: Color.white
        case .untagged: Color.saneBooksAccentSoft
        }
    }

    private var kindLabel: String {
        switch note.direction {
        case .inbound: "↓ \(note.effectiveKind.displayName)"
        case .outbound: "↑ \(note.effectiveKind.displayName)"
        case .changeCandidate: "↕ \(note.effectiveKind.displayName)"
        }
    }

    private var tagLabel: String {
        if let party = note.classification?.party, let sub = note.classification?.subtag {
            return "\(party) · \(sub)"
        }
        return note.classification?.party ?? note.classification?.subtag ?? "—"
    }
}

// MARK: - SyncBanner

struct SyncBanner: View {
    let cursor: SyncCursor?

    var body: some View {
        if let cursor {
            HStack(spacing: 12) {
                Image(systemName: statusIcon(cursor.status))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.saneBooksAccentSoft)
                Text(bannerText(cursor))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.saneBooksAccent.opacity(0.35), lineWidth: 1)
            )
        }
    }

    private func bannerText(_ cursor: SyncCursor) -> String {
        var parts = ["Sync: \(cursor.status.displayName)"]
        parts.append("block \(cursor.scannedThroughHeight.formatted())")
        parts.append("\(cursor.noteCount) notes")
        if cursor.isDemo {
            parts.append("demo")
        }
        return parts.joined(separator: " · ")
    }

    private func statusIcon(_ status: SyncStatus) -> String {
        switch status {
        case .caughtUp: "checkmark.circle.fill"
        case .scanning: "arrow.triangle.2.circlepath"
        case .stalled, .degraded: "exclamationmark.triangle.fill"
        case .capabilityBlocked: "xmark.octagon.fill"
        case .idle: "pause.circle.fill"
        }
    }
}
