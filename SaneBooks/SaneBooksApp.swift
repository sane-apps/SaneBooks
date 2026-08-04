import AppKit
import SaneBooksFeature
import SwiftUI

@main
struct SaneBooksApp: App {
    @State private var model = AppModel.makeProduction()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .onAppear {
                    model.applyE2ESceneIfNeeded()
                }
        }
        .defaultSize(width: 1040, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Proof Pack") {
                    model.beginProofPack()
                }
                .keyboardShortcut("n", modifiers: [.command])
                .disabled(model.vault == nil)

                Button("Import Viewing Key…") {
                    model.goImport()
                }
                .keyboardShortcut("i", modifiers: [.command])

                Button("Open Proof Pack…") {
                    model.goReader()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }

            CommandGroup(after: .appSettings) {
                Button("SaneBooks Settings…") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .keyboardShortcut(",", modifiers: [.command, .option])
            }

            #if DEBUG
                CommandMenu("Debug") {
                    Button("Load Demo Vault") {
                        model.goImport()
                        model.useDemoKey()
                        model.finishImport()
                    }
                    Button("Go to Ledger") {
                        model.route = .ledger
                    }
                    .disabled(model.vault == nil)
                }
            #endif
        }

        Settings {
            SettingsView(model: model)
                .frame(minWidth: 620, minHeight: 420)
                .saneBooksBrand()
        }
    }
}
