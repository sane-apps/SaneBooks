import SaneBooksCore
import SaneBooksExport
import SwiftUI

public struct ProofPackBuilderView: View {
    @Bindable var model: AppModel

    @State private var step = 0
    @State private var rangeStart = Calendar.current.date(
        from: DateComponents(year: Calendar.current.component(.year, from: Date()), month: 1, day: 1)
    ) ?? Date()
    @State private var rangeEnd = Date()
    @State private var includeIncome = true
    @State private var includeExpense = true
    @State private var includeFee = true
    @State private var includeChange = false
    @State private var includeMemos = false
    @State private var excludeTagText = ""
    @State private var validationMessage: String?

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SaneBooksTopNav(
                mode: .nested(title: "New Proof Pack"),
                onVault: { model.route = .ledger },
                onProofPacks: {},
                onBackToLedger: { model.route = .ledger }
            ) {
                Button("Cancel") { model.route = .ledger }
                    .buttonStyle(.plain)
                    .saneBooksFont(size: 14, weight: .semibold)
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 20)

            stepIndicator
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)

            GeometryReader { geometry in
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        Group {
                            switch step {
                            case 0: rangeStep
                            case 1: includeStep
                            default: reviewStep
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 12) {
                            if step > 0 {
                                ActionButton("Back", style: .secondary) { step -= 1 }
                            }
                            Spacer(minLength: 0)
                            if step < 2 {
                                ActionButton("Continue →") { continueToNextStep() }
                                    .disabled(!canContinue)
                            } else {
                                ActionButton("Build pack") { buildAndShare() }
                                    .disabled(!canBuild)
                            }
                        }
                        if let visibleValidationMessage {
                            Text(visibleValidationMessage)
                                .saneBooksFont(size: 14, weight: .semibold)
                                .foregroundStyle(.white)
                                .accessibilityLabel("Cannot continue: \(visibleValidationMessage)")
                        }
                    }
                    .frame(maxWidth: 640)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: geometry.size.height,
                        alignment: .center
                    )
                    .padding(.vertical, 12)
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)
        .padding(.bottom, 28)
        .saneBooksFont(size: 14, weight: .medium)
        .foregroundStyle(.white)
        .onAppear {
            includeMemos = model.includeMemosByDefault
            if let draft = model.packDraft {
                rangeStart = draft.rangeStart
                rangeEnd = draft.rangeEnd
                includeIncome = draft.includedKinds.contains(.income)
                includeExpense = draft.includedKinds.contains(.expense)
                includeFee = draft.includedKinds.contains(.fee)
                includeChange = draft.includeChange
                includeMemos = draft.includeMemos
            } else {
                // Prefer full synced history when notes predate calendar YTD.
                let dated = model.notes.compactMap(\.blockTime)
                if let minDate = dated.min(), let maxDate = dated.max() {
                    rangeStart = minDate
                    rangeEnd = maxDate
                }
            }
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            stepDot(0, label: "Range")
            connector(active: step > 0)
            stepDot(1, label: "Include")
            connector(active: step > 1)
            stepDot(2, label: "Review")
            Spacer(minLength: 0)
        }
    }

    private func stepDot(_ index: Int, label: String) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(step == index ? Color.saneBooksAccent : Color.white.opacity(step > index ? 0.22 : 0.10))
                    .frame(width: 22, height: 22)
                if step > index {
                    Image(systemName: "checkmark")
                        .saneBooksFont(size: 10, weight: .bold)
                        .foregroundStyle(.white)
                } else {
                    Text("\(index + 1)")
                        .saneBooksFont(size: 14, weight: .bold)
                        .foregroundStyle(step == index ? Color.black : Color.white)
                }
            }
            Text(label)
                .saneBooksFont(size: 14, weight: step == index ? .bold : .semibold)
                .foregroundStyle(step == index ? .white : Color.white)
        }
        .padding(.trailing, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(step > index ? "Completed" : (step == index ? "Current step" : "Not started"))
    }

    private func connector(active: Bool) -> some View {
        Rectangle()
            .fill(active ? Color.saneBooksAccent.opacity(0.55) : Color.white.opacity(0.14))
            .frame(width: 36, height: 2)
            .padding(.trailing, 12)
    }

    private var rangeStep: some View {
        panel {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Date range")
                        .saneBooksFont(size: 16, weight: .bold)
                        .foregroundStyle(.white)
                    Text("Only notes confirmed in this window go into the pack.")
                        .saneBooksFont(size: 14, weight: .medium)
                        .foregroundStyle(Color.white)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    presetButton("This year") { applyThisYear() }
                    presetButton("Last year") { applyLastYear() }
                    presetButton("All synced") { applyAllSynced() }
                }

                VStack(alignment: .leading, spacing: 14) {
                    dateField(title: "From", selection: $rangeStart)
                    dateField(title: "To", selection: $rangeEnd)
                }
            }
        }
    }

    private func dateField(title: String, selection: Binding<Date>) -> some View {
        DateRangeRow(title: title, date: selection)
    }

    private func presetButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .saneBooksFont(size: 14, weight: .semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var includeStep: some View {
        panel {
            VStack(alignment: .leading, spacing: 16) {
                Text("What to include")
                    .saneBooksFont(size: 16, weight: .bold)
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Income", isOn: $includeIncome)
                    Toggle("Expenses", isOn: $includeExpense)
                    Toggle("Network fees", isOn: $includeFee)
                    Toggle("Change notes (usually omit)", isOn: $includeChange)
                    Toggle("Memos", isOn: $includeMemos)
                        .onChange(of: includeMemos) { _, v in model.includeMemosByDefault = v }
                }
                .toggleStyle(.checkbox)
                .saneBooksFont(size: 14, weight: .medium)
                .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 8) {
                    Text("EXCLUDE TAGS")
                        .saneBooksFont(size: 14, weight: .bold)
                        .tracking(0.6)
                        .foregroundStyle(Color.white)
                    TextField("Comma-separated party or subtag names", text: $excludeTagText)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private var reviewStep: some View {
        panel {
            VStack(alignment: .leading, spacing: 14) {
                Text("Summary preview")
                    .saneBooksFont(size: 16, weight: .bold)
                    .foregroundStyle(.white)
                if let preview = buildDraft() {
                    Text("\(preview.rows.filter { $0.kind == .income }.count) income · \(preview.rows.filter { $0.kind == .expense }.count) expenses · \(preview.rows.filter { $0.kind == .fee }.count) fees")
                        .saneBooksFont(size: 14, weight: .medium)
                        .foregroundStyle(.white)
                    Text("Totals: \(formatZEC(preview.incomeZEC)) ZEC in · \(formatZEC(preview.expenseZEC)) ZEC out")
                        .saneBooksFont(size: 14, weight: .semibold)
                        .foregroundStyle(.white)
                    if preview.rows.isEmpty {
                        Text("No rows match this date range and selection. Go back and include at least one matching row.")
                            .saneBooksFont(size: 14, weight: .semibold)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if preview.partialHistory {
                        Text("History may be incomplete if sync is still catching up or this is a sample ledger. Income totals could under-report. Acknowledge before you export.")
                            .saneBooksFont(size: 14, weight: .semibold)
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Toggle("I acknowledge partial history", isOn: $model.acknowledgePartialHistory)
                            .saneBooksFont(size: 14, weight: .semibold)
                            .foregroundStyle(.white)
                            .toggleStyle(.checkbox)
                    }
                } else {
                    Text("The active vault is no longer available. Return to the ledger and start a new proof pack.")
                        .saneBooksFont(size: 14, weight: .semibold)
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func panel(@ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(22)
            .frame(maxWidth: 640, alignment: .leading)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }

    private func applyThisYear() {
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        rangeStart = cal.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
        rangeEnd = Date()
    }

    private func applyLastYear() {
        let cal = Calendar.current
        let year = cal.component(.year, from: Date()) - 1
        rangeStart = cal.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
        rangeEnd = cal.date(from: DateComponents(year: year, month: 12, day: 31)) ?? Date()
    }

    private func applyAllSynced() {
        let times = model.notes.compactMap(\.blockTime)
        rangeStart = times.min() ?? rangeStart
        rangeEnd = times.max() ?? Date()
    }

    private func buildDraft() -> ProofPackDraft? {
        guard let vault = model.vault, rangeStart <= rangeEnd else { return nil }
        var kinds = Set<ClassificationKind>()
        if includeIncome {
            kinds.insert(.income)
        }
        if includeExpense {
            kinds.insert(.expense)
        }
        if includeFee {
            kinds.insert(.fee)
        }
        let excludeTags = excludeTagText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let expires = Calendar.current.date(byAdding: .day, value: model.defaultPackExpiryDays, to: Date()) ?? Date()
        return PackBuilder.buildDraft(
            vault: vault,
            notes: model.notes,
            options: PackDraftOptions(
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
                includedKinds: kinds,
                includeMemos: includeMemos,
                includeChange: includeChange,
                excludeTags: excludeTags,
                recipientLabel: nil,
                expiresAt: expires
            ),
            cursor: model.cursor
        )
    }

    private func buildAndShare() {
        guard var draft = buildDraft() else {
            validationMessage = "The date range or active vault is no longer valid."
            return
        }
        guard !draft.rows.isEmpty else {
            validationMessage = "No rows match this pack. Adjust the date range or included kinds."
            return
        }
        draft.acknowledgePartialHistory = model.acknowledgePartialHistory
        if draft.partialHistory, !model.acknowledgePartialHistory {
            validationMessage = "Acknowledge incomplete history before building the pack."
            return
        }
        validationMessage = nil
        model.setPackDraft(draft)
        model.proceedToSharePack()
    }

    private var hasIncludedKind: Bool {
        includeIncome || includeExpense || includeFee || includeChange
    }

    private var canContinue: Bool {
        switch step {
        case 0: rangeStart <= rangeEnd
        case 1: hasIncludedKind
        default: true
        }
    }

    private var canBuild: Bool {
        guard let draft = buildDraft(), !draft.rows.isEmpty else { return false }
        return !draft.partialHistory || model.acknowledgePartialHistory
    }

    private var visibleValidationMessage: String? {
        switch step {
        case 0 where rangeStart > rangeEnd:
            "The From date must be on or before the To date."
        case 1 where !hasIncludedKind:
            "Include at least one row kind."
        case 2:
            if let draft = buildDraft() {
                if draft.rows.isEmpty {
                    "No rows match this pack. Adjust the date range or included kinds."
                } else if draft.partialHistory, !model.acknowledgePartialHistory {
                    "Acknowledge incomplete history before building the pack."
                } else {
                    validationMessage
                }
            } else {
                "The date range or active vault is no longer valid."
            }
        default:
            validationMessage
        }
    }

    private func continueToNextStep() {
        validationMessage = nil
        if step == 0, rangeStart > rangeEnd {
            validationMessage = "The From date must be on or before the To date."
            return
        }
        if step == 1, !hasIncludedKind {
            validationMessage = "Include at least one row kind."
            return
        }
        step += 1
    }
}

// MARK: - Date row (calendar popover — avoids broken macOS field DatePicker spacing)

private struct DateRangeRow: View {
    let title: String
    @Binding var date: Date
    @State private var showCalendar = false

    var body: some View {
        Button {
            showCalendar.toggle()
        } label: {
            HStack(spacing: 14) {
                Text(title)
                    .saneBooksFont(size: 14, weight: .semibold)
                    .foregroundStyle(Color.white)
                    .frame(width: 52, alignment: .leading)
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .saneBooksFont(size: 15, weight: .semibold)
                    .foregroundStyle(.white)
                    .frame(width: 130, alignment: .leading)
                Spacer(minLength: 0)
                Image(systemName: "calendar")
                    .saneBooksFont(size: 14, weight: .semibold)
                    .foregroundStyle(Color.saneBooksAccent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) date")
        .accessibilityValue(date.formatted(date: .abbreviated, time: .omitted))
        .accessibilityHint("Choose the \(title.lowercased()) date for this proof pack")
        .accessibilityIdentifier("sanebooks.pack.date.\(title.lowercased())")
        .popover(isPresented: $showCalendar, arrowEdge: .bottom) {
            DatePicker(
                title,
                selection: $date,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .accessibilityLabel("\(title) date")
            .padding(12)
            .frame(minWidth: 280)
            .colorScheme(.dark)
        }
    }
}
