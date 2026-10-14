import AppKit
import SwiftUI

enum AccountFilter: String, CaseIterable {
    case all, running
    var title: String { L10n.string(rawValue) }
}
enum AppPage: Hashable { case accounts, activity }

@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var accounts: [Account] = []
    @Published private(set) var activities: [Activity] = []
    @Published private(set) var runningIDs: Set<UUID> = []
    @Published private(set) var launchingIDs: Set<UUID> = []
    @Published private(set) var desktopApp: DesktopApp?
    @Published var page: AppPage = .accounts
    @Published var filter: AccountFilter = .all
    @Published var search = ""
    @Published var editorAccount: Account?
    @Published var showEditor = false
    @Published var showSettings = false
    @Published var accountToRemove: Account?
    @Published var errorMessage: String?
    @Published var toast: String?
    private(set) var storageReadOnly = false
    let isDemo: Bool
    let paths: ManagedPaths
    private let repository: AccountRepository
    private let launcher = AppLauncher()
    private var customAppPath: String?
    private var toastTask: Task<Void, Never>?
    private var monitorTask: Task<Void, Never>?

    init(isDemo: Bool = false, paths: ManagedPaths = .applicationSupport) {
        self.isDemo = isDemo
        self.paths = paths
        repository = AccountRepository(paths: paths)
        if isDemo {
            accounts = Account.examples
            runningIDs = [accounts[0].id]
            activities = [Activity(accountName: accounts[0].name, message: ActivityAction.opened.rawValue,
                                   date: Date().addingTimeInterval(-600))]
        } else {
            do {
                let state = try repository.load()
                accounts = state.accounts
                activities = state.activities
                customAppPath = state.customAppPath
                launcher.restore(state.sessions)
                runningIDs = Set(launcher.currentSessions.map(\.accountID))
            } catch {
                storageReadOnly = true
                errorMessage = L10n.format("error.storage.load", error.localizedDescription)
            }
        }
        refreshApp()
        if !isDemo {
            monitorTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(3))
                    guard !Task.isCancelled else { return }
                    self?.reconcileWindows()
                }
            }
        }
    }

    deinit { monitorTask?.cancel(); toastTask?.cancel() }

    var visibleAccounts: [Account] {
        accounts.filter {
            (filter == .all || runningIDs.contains($0.id))
                && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)
                    || $0.note.localizedCaseInsensitiveContains(search))
        }.sorted {
            if $0.isFavorite != $1.isFavorite { return $0.isFavorite }
            return $0.createdAt < $1.createdAt
        }
    }

    func addAccount() {
        editorAccount = nil
        showEditor = true
    }

    func edit(_ account: Account) {
        editorAccount = account
        showEditor = true
    }

    @discardableResult
    func save(_ account: Account) -> Bool {
        do {
            guard !storageReadOnly else { throw StorageError.unsupportedVersion }
            let validated = try account.validated()
            let oldAccounts = accounts
            let oldActivities = activities
            let existing = accounts.firstIndex(where: { $0.id == validated.id })
            if let existing { accounts[existing] = validated } else { accounts.append(validated) }
            record(validated.name, existing == nil ? .added : .updated, symbol: existing == nil ? "plus" : "pencil")
            do { try persist() } catch {
                accounts = oldAccounts
                activities = oldActivities
                throw error
            }
            showEditor = false
            if existing == nil {
                page = .accounts
                filter = .all
                search = ""
                // The account is already saved. A launch failure should leave it
                // available to retry instead of asking the user to add it again.
                if !open(validated) {
                    errorMessage = L10n.format("error.account.login", validated.name,
                                               errorMessage ?? LaunchError.exitedEarly.localizedDescription)
                    notify(L10n.string("toast.added"))
                }
            } else {
                notify(L10n.string("toast.updated"))
            }
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    func toggleFavorite(_ account: Account) {
        var updated = account
        updated.isFavorite.toggle()
        _ = save(updated)
    }

    func remove(_ account: Account) {
        let oldAccounts = accounts
        let oldActivities = activities
        accounts.removeAll { $0.id == account.id }
        record(account.name, .removed, symbol: "minus")
        do { try persist(); notify(L10n.string("toast.removed")) }
        catch { accounts = oldAccounts; activities = oldActivities; errorMessage = error.localizedDescription }
    }

    @discardableResult
    func open(_ account: Account) -> Bool {
        if isDemo {
            runningIDs.insert(account.id)
            record(account.name, .demoOpened)
            notify(L10n.format("toast.demo.opened", account.name))
            return true
        }
        if launcher.isRunning(account.id) { launcher.activate(account.id); return true }
        guard !launchingIDs.contains(account.id) else { return true }
        refreshApp()
        guard let app = desktopApp else { errorMessage = LaunchError.missingApp.localizedDescription; return false }
        launchingIDs.insert(account.id)
        do {
            try launcher.launch(account: account, app: app, paths: paths) { [weak self] status in
                guard let self else { return }
                self.runningIDs.remove(account.id)
                self.launchingIDs.remove(account.id)
                self.record(account.name, status == 0 ? .closed : .unexpectedExit, symbol: "xmark")
                self.persistReportingError()
                if status != 0 { self.errorMessage = L10n.format("error.app.exit", account.name) }
            }
            launchingIDs.remove(account.id)
            runningIDs.insert(account.id)
            if let index = accounts.firstIndex(where: { $0.id == account.id }) { accounts[index].lastOpenedAt = Date() }
            record(account.name, .opened)
            persistReportingError()
            notify(L10n.format("toast.opened", account.name))
            return true
        } catch {
            launchingIDs.remove(account.id)
            errorMessage = error.localizedDescription
            return false
        }
    }

    func refreshApp() { desktopApp = DesktopApp.detect(customPath: customAppPath) }

    func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = L10n.string("app.choose.message")
        panel.prompt = L10n.string("app.choose.prompt")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let selected = try DesktopApp(url: url)
            let oldPath = customAppPath
            customAppPath = url.path
            do { try persist() } catch { customAppPath = oldPath; throw error }
            desktopApp = selected
        } catch { errorMessage = error.localizedDescription }
    }

    func resetAppSelection() {
        let oldPath = customAppPath
        customAppPath = nil
        do { try persist(); refreshApp() }
        catch { customAppPath = oldPath; errorMessage = error.localizedDescription }
    }

    func revealData(for account: Account? = nil) {
        if isDemo { notify(L10n.string("toast.demo.data")); return }
        let url = account.map { paths.profile($0.id) } ?? paths.root
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.open(url)
        } else { notify(L10n.string("toast.data.unavailable")) }
    }

    private func record(_ name: String, _ action: ActivityAction, symbol: String = "arrow.up.right") {
        activities.insert(Activity(accountName: name, message: action.rawValue, symbol: symbol), at: 0)
        activities = Array(activities.prefix(100))
    }

    private func persist() throws {
        guard !isDemo else { return }
        guard !storageReadOnly else { throw StorageError.unsupportedVersion }
        try repository.save(StoredState(accounts: accounts, activities: activities, customAppPath: customAppPath,
                                        sessions: launcher.currentSessions))
    }

    private func reconcileWindows() {
        let current = Set(launcher.currentSessions.map(\.accountID))
        guard current != runningIDs else { return }
        for id in runningIDs.subtracting(current) {
            if let account = accounts.first(where: { $0.id == id }) {
                record(account.name, .closed, symbol: "xmark")
            }
        }
        runningIDs = current
        persistReportingError()
    }

    private func persistReportingError() {
        do { try persist() } catch { errorMessage = L10n.format("error.storage.save", error.localizedDescription) }
    }

    private func notify(_ message: String) {
        toastTask?.cancel()
        toast = message
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }
}
