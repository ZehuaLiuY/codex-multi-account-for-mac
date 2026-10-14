import SwiftUI

struct SettingsSheet: View {
    @EnvironmentObject private var store: AccountStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.string("settings")).font(.system(size: 17, weight: .semibold))
                Spacer()
            }.padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 5)
            Form {
                Section(L10n.string("desktopApp")) {
                    HStack {
                        Label(store.desktopApp?.name ?? L10n.string("app.missing"), systemImage: "app")
                            .help(store.desktopApp?.url.path ?? L10n.string("app.missing"))
                        Spacer()
                        Button(action: store.resetAppSelection) {
                            Label(L10n.string("app.detect"), systemImage: "arrow.clockwise")
                        }.labelStyle(.iconOnly).help(L10n.string("app.detect"))
                        Button(L10n.string("app.choose"), action: store.chooseApp)
                    }
                }
                Section(L10n.string("localData")) {
                    HStack {
                        Text("Codex Accounts")
                        Spacer()
                        Button(L10n.string("folder.open")) { store.revealData() }
                    }
                }
            }.formStyle(.grouped).frame(height: 210)
            HStack {
                Text("Codex Accounts 0.2.0").font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button(L10n.string("done")) { dismiss() }.keyboardShortcut(.defaultAction)
            }.padding(.horizontal, 24).padding(.bottom, 20)
        }.frame(width: 460).fixedSize(horizontal: false, vertical: true)
            .background(Theme.canvas).onExitCommand { dismiss() }
            .alert(L10n.string("error.title"), isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                Button(L10n.string("ok"), role: .cancel) { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "") }
    }
}
