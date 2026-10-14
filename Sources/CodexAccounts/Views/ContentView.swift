import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AccountStore

    var body: some View {
        VStack(spacing: 0) {
            if store.page == .accounts { accountsPage }
            else { activityPage }
        }
        .background(Theme.canvas)
        .frame(minWidth: 640, idealWidth: 780, minHeight: 340, idealHeight: 460)
        .navigationTitle("Codex Accounts")
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Picker("", selection: $store.page) {
                        Text(L10n.string("accounts")).tag(AppPage.accounts)
                        Text(L10n.string("activity")).tag(AppPage.activity)
                    }.pickerStyle(.segmented).labelsHidden().frame(width: 160)
                    if store.isDemo { TinyLabel(text: L10n.string("demo")) }
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: store.addAccount) {
                    Label(L10n.string("addAccount"), systemImage: "plus")
                }.help(L10n.string("addAccount")).disabled(store.storageReadOnly)
                Button { store.showSettings = true } label: {
                    Label(L10n.string("settings"), systemImage: "gearshape")
                }.help(L10n.string("settings"))
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = store.toast {
                Label(toast, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12)).padding(.horizontal, 13).padding(.vertical, 9)
                    .background(.regularMaterial, in: Capsule()).padding(.bottom, 15)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: store.toast)
        .sheet(isPresented: $store.showEditor) {
            AccountEditor(account: store.editorAccount).environmentObject(store)
        }
        .sheet(isPresented: $store.showSettings) { SettingsSheet().environmentObject(store) }
        .alert(L10n.string("error.title"), isPresented: Binding(
            get: { store.errorMessage != nil && !store.showEditor && !store.showSettings },
            set: { if !$0 { store.errorMessage = nil } })) {
            Button(L10n.string("ok"), role: .cancel) { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
        .alert(L10n.format("remove.confirm", store.accountToRemove?.name ?? ""), isPresented: Binding(
            get: { store.accountToRemove != nil }, set: { if !$0 { store.accountToRemove = nil } })) {
            Button(L10n.string("cancel"), role: .cancel) { store.accountToRemove = nil }
            Button(L10n.string("remove"), role: .destructive) {
                if let account = store.accountToRemove { store.remove(account) }
                store.accountToRemove = nil
            }
        } message: { Text(L10n.string("remove.message")) }
    }

    private var accountsPage: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("", selection: $store.filter) {
                    ForEach(AccountFilter.allCases, id: \.self) { filter in
                        let count = filter == .all ? store.accounts.count : store.runningIDs.intersection(Set(store.accounts.map(\.id))).count
                        Text(L10n.format("filter.count", filter.title, Int32(count))).tag(filter)
                    }
                }.pickerStyle(.segmented).labelsHidden().controlSize(.small).fixedSize()
                Spacer(minLength: 20)
                AccountSearchField(text: $store.search).frame(width: 190, height: 24)
            }.padding(.horizontal, 20).padding(.vertical, 13)
            Divider()
            if store.visibleAccounts.isEmpty {
                emptyState(title: emptyTitle, symbol: store.search.isEmpty ? "person.crop.rectangle.stack" : "magnifyingglass") {
                    if store.accounts.isEmpty && !store.storageReadOnly {
                        Button(L10n.string("addAccount"), action: store.addAccount).buttonStyle(.borderedProminent)
                    }
                }
            } else {
                List {
                    ForEach(store.visibleAccounts) { account in AccountRow(account: account) }
                }.listStyle(.inset).scrollContentBackground(.hidden)
            }
        }
    }

    private var emptyTitle: String {
        L10n.string(store.storageReadOnly ? "empty.storage" : !store.search.isEmpty ? "empty.search" :
                    store.filter == .running ? "empty.running" : "empty.accounts")
    }

    private var activityPage: some View {
        Group {
            if store.activities.isEmpty {
                emptyState(title: L10n.string("empty.activity"), symbol: "clock") { EmptyView() }
            } else {
                List(store.activities) { activity in
                    HStack(spacing: 13) {
                        Image(systemName: activity.symbol).foregroundStyle(.secondary).frame(width: 25)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(activity.accountName).font(.system(size: 13, weight: .medium))
                            Text(activity.localizedMessage()).font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(activity.date, format: .relative(presentation: .named, unitsStyle: .abbreviated).locale(L10n.locale))
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }.padding(.vertical, 8)
                }.listStyle(.inset).scrollContentBackground(.hidden)
            }
        }
    }

    private func emptyState<Actions: View>(title: String, symbol: String, @ViewBuilder actions: () -> Actions) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } actions: { actions() }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AccountRow: View {
    @EnvironmentObject private var store: AccountStore
    let account: Account
    private var isRunning: Bool { store.runningIDs.contains(account.id) }
    private var isLaunching: Bool { store.launchingIDs.contains(account.id) }

    var body: some View {
        HStack(spacing: 13) {
            AccountAvatar(account: account, size: 36)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(account.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                    if account.isFavorite {
                        Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(.secondary)
                            .accessibilityLabel(L10n.string("favorite"))
                    }
                }
                if !account.note.isEmpty {
                    Text(account.note).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 5) {
                Circle().fill(isRunning ? Color.green : Color.secondary.opacity(0.4)).frame(width: 5, height: 5)
                Text(L10n.string(isRunning ? "running" : "stopped")).font(.system(size: 11))
            }.foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
            Button { store.open(account) } label: {
                HStack(spacing: 5) {
                    if isLaunching { ProgressView().controlSize(.mini) }
                    Text(L10n.string(isLaunching ? "opening" : isRunning ? "show" : "open"))
                }.frame(minWidth: 45)
            }.buttonStyle(.bordered).controlSize(.small).disabled(isLaunching)
                .accessibilityLabel(L10n.format(isRunning ? "show.account" : "open.account", account.name))
            Menu {
                Button(L10n.string("editAccount"), systemImage: "pencil") { store.edit(account) }
                Button(L10n.string(account.isFavorite ? "favorite.remove" : "favorite.add"), systemImage: "star") { store.toggleFavorite(account) }
                Button(L10n.string("data.open"), systemImage: "folder") { store.revealData(for: account) }
                Divider()
                Button(L10n.string("remove"), systemImage: "minus.circle", role: .destructive) { store.accountToRemove = account }
            } label: {
                Image(systemName: "ellipsis").frame(width: 18, height: 24)
            }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .accessibilityLabel(L10n.format("more.account", account.name))
        }.padding(.vertical, 10).padding(.horizontal, 3)
            .accessibilityElement(children: .contain)
    }
}
