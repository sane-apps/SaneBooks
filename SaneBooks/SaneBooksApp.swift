import AppKit
import SaneBooksFeature
import SwiftUI

@main
struct SaneBooksApp: App {
    @NSApplicationDelegateAdaptor(SaneBooksAppDelegate.self) private var appDelegate
    @State private var model = AppModel.makeProduction()

    var body: some Scene {
        mainWindow

        Settings {
            SettingsView(model: model)
                .frame(minWidth: 620, minHeight: 420)
                .saneBooksBrand()
        }
    }

    private var mainWindow: some Scene {
        WindowGroup("ZecBooks", id: "main") {
            ContentView(model: model)
                .onAppear {
                    appDelegate.model = model
                    #if DEBUG
                        model.applyE2ESceneIfNeeded()
                    #endif
                }
                .background(SaneBooksOpenSettingsBridge())
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

            // System Settings… (⌘,) comes from the Settings scene alone.
            // Do not add a second "SaneBooks Settings…" — it duplicated the menu and the
            // showSettingsWindow: selector was unreliable.

            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    UpdateService.shared.checkForUpdates()
                }
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
    }
}

/// Opens the SwiftUI Settings scene from AppKit (Dock menu / notifications).
private struct SaneBooksOpenSettingsBridge: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onReceive(NotificationCenter.default.publisher(for: .saneBooksOpenSettings)) { _ in
                openSettings()
            }
    }
}

// Notification.Name.saneBooksOpenSettings lives in SaneBooksFeature (Theme).

@MainActor
final class SaneBooksAppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel?

    func applicationDidFinishLaunching(_: Notification) {
        // Start Sparkle on the direct channel (zecbooks.app appcast).
        _ = UpdateService.shared
    }

    func applicationDockMenu(_: NSApplication) -> NSMenu? {
        let menu = NSMenu()

        let settings = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settings.keyEquivalentModifierMask = [.command]
        settings.target = self
        menu.addItem(settings)

        let updates = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        updates.target = self
        menu.addItem(updates)

        menu.addItem(.separator())

        let importKey = NSMenuItem(
            title: "Import Viewing Key…",
            action: #selector(importViewingKey),
            keyEquivalent: ""
        )
        importKey.target = self
        menu.addItem(importKey)

        let openPack = NSMenuItem(
            title: "Open Proof Pack…",
            action: #selector(openProofPack),
            keyEquivalent: ""
        )
        openPack.target = self
        menu.addItem(openPack)

        let newPack = NSMenuItem(
            title: "New Proof Pack",
            action: #selector(newProofPack),
            keyEquivalent: ""
        )
        newPack.target = self
        newPack.isEnabled = model?.vault != nil
        menu.addItem(newPack)

        return menu
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .saneBooksOpenSettings, object: nil)
    }

    @objc private func checkForUpdates() {
        UpdateService.shared.checkForUpdates()
    }

    @objc private func importViewingKey() {
        NSApp.activate(ignoringOtherApps: true)
        model?.goImport()
    }

    @objc private func openProofPack() {
        NSApp.activate(ignoringOtherApps: true)
        model?.goReader()
    }

    @objc private func newProofPack() {
        NSApp.activate(ignoringOtherApps: true)
        model?.beginProofPack()
    }
}
