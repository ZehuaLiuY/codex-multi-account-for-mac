import Darwin
import XCTest
@testable import CodexAccounts

final class AccountStoreTests: XCTestCase {
    private var root: URL!
    private var repository: AccountRepository!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("CodexAccountsStoreTests-" + UUID().uuidString)
        repository = AccountRepository(paths: ManagedPaths(root: root.appendingPathComponent("managed")))
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
    }

    @MainActor
    func testAddingAccountLaunchesItsOwnProfileAndPersistsWindow() async throws {
        let app = try makeFixture()
        try repository.save(StoredState(customAppPath: app.path))
        let store = AccountStore(paths: repository.paths)
        defer {
            for session in (try? repository.load())?.sessions ?? [] where session.process.isCurrent {
                kill(session.process.pid, SIGTERM)
            }
        }
        store.showEditor = true
        store.page = .activity
        store.filter = .running
        store.search = "unrelated account"
        let account = Account(name: "  New account  ")

        XCTAssertTrue(store.save(account))
        XCTAssertFalse(store.showEditor)
        XCTAssertEqual(store.page, .accounts)
        XCTAssertEqual(store.filter, .all)
        XCTAssertTrue(store.search.isEmpty)
        XCTAssertEqual(store.visibleAccounts.map(\.id), [account.id])
        XCTAssertEqual(store.runningIDs, [account.id])
        XCTAssertTrue(store.launchingIDs.isEmpty)
        XCTAssertNil(store.errorMessage)

        let state = try repository.load()
        XCTAssertEqual(state.accounts.count, 1)
        XCTAssertEqual(state.accounts[0].name, "New account")
        XCTAssertNotNil(state.accounts[0].lastOpenedAt)
        XCTAssertEqual(state.activities.map(\.message), [ActivityAction.opened.rawValue, ActivityAction.added.rawValue])
        XCTAssertEqual(state.sessions.map(\.accountID), [account.id])
        let session = try XCTUnwrap(state.sessions.first)
        XCTAssertTrue(session.process.isCurrent)

        let observed = repository.paths.codexHome(account.id).appendingPathComponent("launch-observed.txt")
        for _ in 0..<40 {
            if FileManager.default.fileExists(atPath: observed.path) { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        let environment = try String(contentsOf: observed).split(separator: "\n").map(String.init)
        XCTAssertEqual(environment, [repository.paths.codexHome(account.id).path,
                                     repository.paths.userData(account.id).path,
                                     "--user-data-dir=" + repository.paths.userData(account.id).path])
    }

    @MainActor
    func testEditingAndFavoritingDoNotOpenAWindow() throws {
        let app = try makeFixture()
        let account = Account(name: "Existing account")
        try repository.save(StoredState(accounts: [account], customAppPath: app.path))
        let store = AccountStore(paths: repository.paths)
        var edited = account
        edited.name = "Renamed account"
        edited.note = "Updated note"

        XCTAssertTrue(store.save(edited))
        store.toggleFavorite(edited)

        let state = try repository.load()
        XCTAssertEqual(state.accounts[0].name, edited.name)
        XCTAssertTrue(state.accounts[0].isFavorite)
        XCTAssertNil(state.accounts[0].lastOpenedAt)
        XCTAssertTrue(state.sessions.isEmpty)
        XCTAssertTrue(store.runningIDs.isEmpty)
        XCTAssertEqual(state.activities.map(\.message), [ActivityAction.updated.rawValue, ActivityAction.updated.rawValue])
        XCTAssertFalse(FileManager.default.fileExists(atPath: repository.paths.profile(account.id).path))
    }

    @MainActor
    func testLaunchFailureKeepsAccountAndExplainsHowToRetry() throws {
        try repository.save(StoredState(customAppPath: root.appendingPathComponent("Missing.app").path))
        let store = AccountStore(paths: repository.paths)
        store.showEditor = true
        let account = Account(name: "Retry sign-in")

        XCTAssertTrue(store.save(account))
        XCTAssertFalse(store.showEditor)
        XCTAssertEqual(store.errorMessage, L10n.format("error.account.login", account.name,
                                                     LaunchError.missingApp.localizedDescription))
        XCTAssertTrue(store.runningIDs.isEmpty)
        XCTAssertTrue(store.launchingIDs.isEmpty)
        let state = try repository.load()
        XCTAssertEqual(state.accounts, [account])
        XCTAssertTrue(state.sessions.isEmpty)
        XCTAssertEqual(state.activities.map(\.message), [ActivityAction.added.rawValue])
    }

    @MainActor
    func testFailedSaveDoesNotLaunchOrDismissEditor() throws {
        let app = try makeFixture()
        try repository.save(StoredState(customAppPath: app.path))
        let store = AccountStore(paths: repository.paths)
        store.showEditor = true
        try FileManager.default.removeItem(at: repository.paths.stateFile)
        try FileManager.default.createDirectory(at: repository.paths.stateFile, withIntermediateDirectories: false)
        let account = Account(name: "Unable to save")

        XCTAssertFalse(store.save(account))
        XCTAssertTrue(store.showEditor)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertTrue(store.accounts.isEmpty)
        XCTAssertTrue(store.activities.isEmpty)
        XCTAssertTrue(store.runningIDs.isEmpty)
        XCTAssertTrue(store.launchingIDs.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: repository.paths.profile(account.id).path))
    }

    private func makeFixture() throws -> URL {
        let bundle = root.appendingPathComponent("Fixture.app")
        let macOS = bundle.appendingPathComponent("Contents/MacOS")
        try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
        let info: [String: Any] = [
            "CFBundleIdentifier": "com.openai.codex", "CFBundleExecutable": "Fixture",
            "CFBundleName": "Sign-in Fixture", "CFBundlePackageType": "APPL"
        ]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: bundle.appendingPathComponent("Contents/Info.plist"))
        let executable = macOS.appendingPathComponent("Fixture")
        let script = """
        #!/bin/sh
        printf '%s\\n' "$CODEX_HOME" "$CODEX_ELECTRON_USER_DATA_PATH" "$1" > "$CODEX_HOME/launch-observed.txt"
        exec /bin/sleep 10
        """
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        return bundle
    }
}
