import XCTest
@testable import CodexAccounts

final class RepositoryTests: XCTestCase {
    private var root: URL!
    private var repository: AccountRepository!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("CodexAccountsRepositoryTests-" + UUID().uuidString)
        repository = AccountRepository(paths: ManagedPaths(root: root))
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
    }

    func testRoundTripPreservesUnicodeProfileMetadata() throws {
        let account = Account(name: "工作 & personal", note: "我的独立空间", symbol: "briefcase", tint: .blue, isFavorite: true)
        try repository.save(StoredState(accounts: [account]))
        XCTAssertEqual(try repository.load().accounts, [account])
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: repository.paths.stateFile.path)[.posixPermissions] as? Int, 0o600)
    }

    func testMissingStateStartsEmpty() throws {
        XCTAssertTrue(try repository.load().accounts.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }

    func testOlderStateWithoutWindowSessionsLoads() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("{\"version\":1,\"accounts\":[]}".utf8).write(to: repository.paths.stateFile)
        XCTAssertTrue(try repository.load().sessions.isEmpty)
    }

    func testReusedProcessIDDoesNotMatchSavedWindow() throws {
        let identity = try XCTUnwrap(ProcessIdentity.capture(pid: getpid()))
        XCTAssertTrue(identity.isCurrent)
        let stale = ProcessIdentity(pid: identity.pid, startSeconds: identity.startSeconds + 1,
                                    startMicroseconds: identity.startMicroseconds)
        XCTAssertFalse(stale.isCurrent)
        XCTAssertNil(ProcessIdentity.capture(pid: -1))
    }

    @MainActor
    func testWindowRestorationIgnoresStaleProcesses() throws {
        let launcher = AppLauncher()
        let id = UUID()
        let identity = try XCTUnwrap(ProcessIdentity.capture(pid: getpid()))
        launcher.restore([WindowSession(accountID: id, process: identity)])
        XCTAssertTrue(launcher.isRunning(id))
        let staleID = UUID()
        launcher.restore([WindowSession(accountID: staleID,
                                        process: ProcessIdentity(pid: identity.pid, startSeconds: 0, startMicroseconds: 0))])
        XCTAssertFalse(launcher.isRunning(staleID))
        XCTAssertEqual(launcher.currentSessions.count, 1)
    }

    func testCorruptStateIsNeverSilentlyOverwritten() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let original = Data("not-valid-json".utf8)
        try original.write(to: repository.paths.stateFile)
        XCTAssertThrowsError(try repository.load())
        XCTAssertEqual(try Data(contentsOf: repository.paths.stateFile), original)
    }

    func testUnsupportedVersionAndDuplicateIdentitiesAreRejected() throws {
        var state = StoredState()
        state.version = 99
        try repository.save(state)
        XCTAssertThrowsError(try repository.load())
        let account = Account(name: "个人")
        try repository.save(StoredState(accounts: [account, account]))
        XCTAssertThrowsError(try repository.load())
    }

    func testAccountValidationTrimsWhitespaceAndRejectsInvalidInput() throws {
        XCTAssertEqual(try Account(name: "  工作 \n", note: "  备注 ").validated().name, "工作")
        XCTAssertEqual(try Account(name: "工作", note: "  备注 ").validated().note, "备注")
        XCTAssertThrowsError(try Account(name: " \n ").validated())
        XCTAssertThrowsError(try Account(name: String(repeating: "名", count: 41)).validated())
        XCTAssertThrowsError(try Account(name: "工作", symbol: "missing-symbol").validated())
    }

    @MainActor
    func testDemoChangesNeverCreatePersistentAccountData() {
        let store = AccountStore(isDemo: true, paths: repository.paths)
        XCTAssertEqual(store.accounts.count, 3)
        XCTAssertTrue(store.save(Account(name: "演示添加")))
        XCTAssertTrue(store.runningIDs.contains(store.accounts.last!.id))
        store.remove(store.accounts.last!)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }

    @MainActor
    func testStoreRefusesToOverwriteUnreadableState() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let original = Data("broken-data".utf8)
        try original.write(to: repository.paths.stateFile)
        let store = AccountStore(paths: repository.paths)
        XCTAssertTrue(store.storageReadOnly)
        XCTAssertFalse(store.save(Account(name: "不应该保存")))
        XCTAssertEqual(try Data(contentsOf: repository.paths.stateFile), original)
    }
}
