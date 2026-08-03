import SaneBooksCore
import SwiftUI

public struct ContentView: View {
    @Bindable var model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        ZStack {
            SaneGradientBackground()
                .ignoresSafeArea()
            routeContent
        }
        .frame(minWidth: 980, minHeight: 640)
    }

    @ViewBuilder
    private var routeContent: some View {
        switch model.route {
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
