import XCTest
@testable import CodexAccounts

final class IsolationTests: XCTestCase {
    private var root: URL!
    private var paths: ManagedPaths!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("CodexAccountsTests-" + UUID().uuidString)
        paths = ManagedPaths(root: root)
    }

    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
    }

    func testProfilesHaveIndependentCredentialAndDesktopDirectories() throws {
        let first = UUID(), second = UUID()
        try paths.prepare(first)
        try paths.prepare(second)
        let fakeAuth = paths.codexHome(first).appendingPathComponent("auth.json")
        try Data("test-only-placeholder".utf8).write(to: fakeAuth)
        XCTAssertNotEqual(paths.codexHome(first), paths.codexHome(second))
        XCTAssertNotEqual(paths.userData(first), paths.userData(second))
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.codexHome(second).appendingPathComponent("auth.json").path))
        let config = try String(contentsOf: paths.codexHome(second).appendingPathComponent("config.toml"))
        XCTAssertEqual(config, "cli_auth_credentials_store = \"file\"\n")
    }

    func testPreparePreservesExistingConfiguration() throws {
        let id = UUID()
        try paths.prepare(id)
        let config = paths.codexHome(id).appendingPathComponent("config.toml")
        let custom = "cli_auth_credentials_store = \"file\"\nmodel = \"custom-model\"\n"
        try custom.write(to: config, atomically: true, encoding: .utf8)
        try paths.prepare(id)
        XCTAssertEqual(try String(contentsOf: config), custom)
    }

    func testProfileNamesCannotChangeStoragePaths() throws {
        let account = Account(name: "../../Other Profile")
        _ = try account.validated()
        XCTAssertEqual(paths.profile(account.id).lastPathComponent, account.id.uuidString.lowercased())
        XCTAssertEqual(paths.profile(account.id).deletingLastPathComponent().lastPathComponent, "profiles")
    }

    func testManagedDirectoriesAndConfigurationUsePrivatePermissions() throws {
        let id = UUID()
        try paths.prepare(id)
        for url in [root!, paths.profile(id), paths.codexHome(id), paths.userData(id)] {
            XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int, 0o700)
        }
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: paths.codexHome(id).appendingPathComponent("config.toml").path)[.posixPermissions] as? Int, 0o600)
    }

    func testSymbolicLinkCannotRedirectAProfile() throws {
        let id = UUID()
        let outside = root.appendingPathComponent("outside")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let profiles = root.appendingPathComponent("profiles")
        try FileManager.default.createDirectory(at: profiles, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: paths.profile(id), withDestinationURL: outside)
        XCTAssertThrowsError(try paths.prepare(id))
        XCTAssertFalse(FileManager.default.fileExists(atPath: outside.appendingPathComponent("codex").path))
    }

    func testLaunchUsesIsolatedPathsAndDoesNotInheritCredentialsOrSessionIPC() {
        let id = UUID()
        let plan = LaunchPlan(executable: URL(fileURLWithPath: "/Applications/ChatGPT.app/Contents/MacOS/ChatGPT"),
                              accountID: id, paths: paths, inheritedEnvironment: [
                                "PATH": "/usr/bin", "HOME": "/Users/example", "LANG": "zh_CN.UTF-8",
                                "CODEX_HOME": "/Users/example/.codex",
                                "CODEX_ACCESS_TOKEN": "test-only-token",
                                "CODEX_SQLITE_HOME": "/Users/example/.codex/sqlite",
                                "CODEX_APP_TOOLS_PIPE_PATH": "/tmp/other-session",
                                "OPENAI_API_KEY": "test-only-api-key",
                                "NODE_OPTIONS": "--require=/tmp/injection.js",
                                "ELECTRON_RUN_AS_NODE": "1"
                              ])
        XCTAssertEqual(plan.arguments, ["--user-data-dir=" + paths.userData(id).path])
        XCTAssertEqual(plan.environment["CODEX_HOME"], paths.codexHome(id).path)
        XCTAssertEqual(plan.environment["CODEX_ELECTRON_USER_DATA_PATH"], paths.userData(id).path)
        for key in ["CODEX_ACCESS_TOKEN", "CODEX_SQLITE_HOME", "CODEX_APP_TOOLS_PIPE_PATH", "OPENAI_API_KEY", "NODE_OPTIONS", "ELECTRON_RUN_AS_NODE"] {
            XCTAssertNil(plan.environment[key])
        }
        XCTAssertEqual(plan.environment["PATH"], "/usr/bin")
        XCTAssertEqual(plan.environment["HOME"], "/Users/example")
        XCTAssertEqual(plan.environment["LANG"], "zh_CN.UTF-8")
    }
}
