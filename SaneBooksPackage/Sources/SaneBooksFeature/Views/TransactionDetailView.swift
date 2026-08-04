import SaneBooksCore
import SwiftUI

public struct TransactionDetailView: View {
    static let editableKinds = ClassificationKind.allCases

    @Bindable var model: AppModel
    let noteID: NoteRowID

    @State private var kind: ClassificationKind = .untagged
    @State private var party = ""
    @State private var subtag = ""
    @State private var memo = ""
    @State private var includeInPacks = true

    public var body: some View {
        Group {
            if let note = model.selectedNote(noteID) {
                detailContent(note)
            } else {
                VStack(spacing: 20) {
                    SaneBooksTopNav(
                        mode: .nested(title: "Transaction"),
                        onVault: { model.route = .ledger },
                        onProofPacks: { model.beginProofPack() },
                        onBackToLedger: { model.route = .ledger }
                    )
                    SaneErrorState(message: "Transaction not found.", retryTitle: "Back") {
                        model.route = .ledger
                    }
                }
            }
        }
        .padding(28)
        .onAppear { load(from: model.selectedNote(noteID)) }
    }

    private func detailContent(_ note: NoteRow) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SaneBooksTopNav(
                mode: .nested(title: "Transaction"),
                onVault: { model.route = .ledger },
                onProofPacks: { model.beginProofPack() },
                onBackToLedger: { model.route = .ledger }
            ) {
                ActionButton("Save", icon: "checkmark") {
                    save(note)
                }
            }
            .padding(.bottom, 16)

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .firstTextBaseline) {
                        if model.discreetMode {
                            Text("•••• ZEC")
                                .saneBooksFont(size: 28, weight: .bold)
                                .foregroundStyle(.white)
                        } else {
                            Text("\(note.direction == .outbound ? "-" : "+")\(formatZEC(abs(note.amountZEC))) ZEC")
                                .saneBooksFont(size: 28, weight: .bold)
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        if let date = note.blockTime {
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                                .saneBooksFont(size: 14, weight: .medium)
                                .foregroundStyle(.white)
                        }
                    }

                    if !model.discreetMode, let fiat = note.fiatMark?.amount(forZEC: abs(note.amountZEC)) {
                        Text("≈ $\(formatFiat(fiat)) at confirmation")
                            .saneBooksFont(size: 14, weight: .medium)
                            .foregroundStyle(.white)
                    }

                    detailRow("Direction", note.direction.displayName)
                    detailRow("Pool", note.pool.displayName)

                    Picker("Category", selection: $kind) {
                        ForEach(Self.editableKinds, id: \.self) { k in
                            Text(k.displayName).tag(k)
                        }
                    }
                    .foregroundStyle(.white)
                    .saneBooksFont(size: 14, weight: .medium)

                    labeledField("Party", text: $party)
                    labeledField("Subtag", text: $subtag)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Memo")
                            .saneBooksFont(size: 14, weight: .semibold)
                            .foregroundStyle(.white)
                        TextEditor(text: $memo)
                            .saneBooksFont(size: 14)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .frame(height: 80)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(.white)
                            .accessibilityLabel("Memo")
                    }

                    Toggle("Include in proof packs by default", isOn: $includeInPacks)
                        .saneBooksFont(size: 14, weight: .medium)
                        .foregroundStyle(.white)

                    Text("Txid: \(model.truncateTxidsInUI ? note.txidTruncated : note.txidHex)")
                        .saneBooksFont(size: 14, design: .monospaced)
                        .foregroundStyle(.white)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .saneBooksFont(size: 14, weight: .semibold)
                .foregroundStyle(.white)
            Spacer()
            Text(value)
                .saneBooksFont(size: 14, weight: .medium)
                .foregroundStyle(.white)
        }
    }

    private func labeledField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .saneBooksFont(size: 14, weight: .semibold)
                .foregroundStyle(.white)
            TextField(label, text: text)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(.white)
        }
    }

    private func load(from note: NoteRow?) {
        guard let note else { return }
        kind = note.classification?.kind ?? note.suggestedClassification ?? .untagged
        party = note.classification?.party ?? ""
        subtag = note.classification?.subtag ?? ""
        memo = note.memo.displayText ?? ""
        includeInPacks = note.includeInPacksByDefault
    }

    private func save(_ note: NoteRow) {
        var updated = note
        updated.classification = Classification(
            kind: kind,
            party: party.isEmpty ? nil : party,
            subtag: subtag.isEmpty ? nil : subtag,
            notes: memo.isEmpty ? nil : memo,
            source: .user
        )
        if case .text = note.memo {
            updated.memo = .text(memo)
        } else if !memo.isEmpty {
            updated.memo = .text(memo)
        }
        updated.includeInPacksByDefault = includeInPacks
        model.saveNote(updated, advanceUntaggedQueue: model.filters.untaggedOnly)
    }
}
