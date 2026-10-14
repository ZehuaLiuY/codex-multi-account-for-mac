import AppKit
import SwiftUI

@main
struct CodexAccountsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var store = AccountStore(isDemo: CommandLine.arguments.contains("--demo")
                                                || CommandLine.arguments.contains("--snapshot"))

    var body: some Scene {
        Window("Codex Accounts", id: "main") {
            ContentView().environmentObject(store)
                .environment(\.locale, L10n.locale)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 780, height: 460)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(L10n.string("addAccount"), action: store.addAccount).keyboardShortcut("n", modifiers: .command)
                    .disabled(store.storageReadOnly)
            }
            CommandGroup(replacing: .appSettings) {
                Button(L10n.string("settings.menu")) { store.showSettings = true }.keyboardShortcut(",", modifiers: .command)
            }
            CommandMenu(L10n.string("accounts")) {
                Button(L10n.string("accounts")) { store.page = .accounts }.keyboardShortcut("1", modifiers: .command)
                Button(L10n.string("activity")) { store.page = .activity }.keyboardShortcut("2", modifiers: .command)
            }
        }
        MenuBarExtra("Codex Accounts", systemImage: "square.stack.3d.up") {
            MenuBarContent().environmentObject(store)
        }
    }
}

private struct MenuBarContent: View {
    @EnvironmentObject private var store: AccountStore
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button(L10n.string("app.open")) { showMain() }
        Divider()
        if store.accounts.isEmpty { Text(L10n.string("empty.accounts")) }
        ForEach(store.accounts) { account in
            Button {
                store.open(account)
                if store.errorMessage != nil { showMain() }
            } label: {
                Label(store.runningIDs.contains(account.id) ? L10n.format("menu.running", account.name) : account.name, systemImage: account.symbol)
            }
        }
        Divider()
        Button(L10n.string("addAccount.menu")) { showMain(); store.addAccount() }.disabled(store.storageReadOnly)
        Button(L10n.string("settings.menu")) { showMain(); store.showSettings = true }
        Divider()
        Button(L10n.string("app.quit")) { NSApplication.shared.terminate(nil) }.keyboardShortcut("q", modifiers: .command)
    }
    private func showMain() {
        openWindow(id: "main")
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        if CommandLine.arguments.contains("--snapshot") {
            NSApplication.shared.appearance = NSAppearance(named: CommandLine.arguments.contains("--dark") ? .darkAqua : .aqua)
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        guard let index = CommandLine.arguments.firstIndex(of: "--snapshot"),
              CommandLine.arguments.indices.contains(index + 1) else { return }
        let path = CommandLine.arguments[index + 1]
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "main" || $0.title == "Codex Accounts" }),
                  let frameView = window.contentView?.superview else {
                print("Preview failed: main window is unavailable.")
                exit(1)
            }
            window.setContentSize(NSSize(width: 780, height: 400))
            window.makeKeyAndOrderFront(nil)
            frameView.layoutSubtreeIfNeeded()
            guard let bitmap = frameView.bitmapImageRepForCachingDisplay(in: frameView.bounds) else {
                print("Preview failed: window bitmap is unavailable.")
                exit(1)
            }
            frameView.cacheDisplay(in: frameView.bounds, to: bitmap)
            guard let data = bitmap.representation(using: .png, properties: [:]) else {
                print("Preview failed: PNG encoding failed.")
                exit(1)
            }
            do {
                try data.write(to: URL(fileURLWithPath: path))
                print("Saved preview: \(path) [\(L10n.language)]")
                print("Localization bundle: \(L10n.resourceBundle.bundleURL.path)")
            }
            catch { print("Preview failed: \(error.localizedDescription)"); exit(1) }
            NSApplication.shared.terminate(nil)
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
