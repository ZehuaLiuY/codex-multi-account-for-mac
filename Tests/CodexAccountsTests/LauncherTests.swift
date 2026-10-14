import XCTest
@testable import CodexAccounts

final class LauncherTests: XCTestCase {
    @MainActor
    func testTwoProfilesLaunchConcurrentlyWithIndependentEnvironments() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("CodexAccountsLauncherTests-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let bundleURL = root.appendingPathComponent("Fixture.app")
        let macOS = bundleURL.appendingPathComponent("Contents/MacOS")
        try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
        let info: [String: Any] = [
            "CFBundleIdentifier": "com.openai.codex", "CFBundleExecutable": "Fixture",
            "CFBundleName": "Test Fixture", "CFBundlePackageType": "APPL"
        ]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: bundleURL.appendingPathComponent("Contents/Info.plist"))
        let executable = macOS.appendingPathComponent("Fixture")
        let script = """
        #!/bin/sh
        printf '%s\\n' "$CODEX_HOME" "$CODEX_ELECTRON_USER_DATA_PATH" "$1" "${CODEX_ACCESS_TOKEN-unset}" "${OPENAI_API_KEY-unset}" > "$CODEX_HOME/launch-observed.txt"
        /bin/sleep 1
        """
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let app = try DesktopApp(url: bundleURL)
        let paths = ManagedPaths(root: root.appendingPathComponent("managed"))
        let launcher = AppLauncher()
        let first = Account(name: "个人"), second = Account(name: "工作")
        let exited = expectation(description: "Both isolated child processes exit")
        exited.expectedFulfillmentCount = 2
        for account in [first, second] {
            try launcher.launch(account: account, app: app, paths: paths) { status in
                XCTAssertEqual(status, 0)
                exited.fulfill()
            }
        }
        XCTAssertTrue(launcher.isRunning(first.id))
        XCTAssertTrue(launcher.isRunning(second.id))
        XCTAssertEqual(launcher.currentSessions.count, 2)
        XCTAssertNotEqual(launcher.currentSessions[0].process.pid, launcher.currentSessions[1].process.pid)
        let restored = AppLauncher()
        restored.restore(launcher.currentSessions)
        XCTAssertTrue(restored.isRunning(first.id))
        XCTAssertTrue(restored.isRunning(second.id))
        try launcher.launch(account: first, app: app, paths: paths) { _ in XCTFail("A duplicate window was launched") }
        XCTAssertEqual(launcher.currentSessions.count, 2)
        await fulfillment(of: [exited], timeout: 5)
        for account in [first, second] {
            let observed = try String(contentsOf: paths.codexHome(account.id).appendingPathComponent("launch-observed.txt"))
                .split(separator: "\n").map(String.init)
            XCTAssertEqual(observed, [paths.codexHome(account.id).path, paths.userData(account.id).path,
                                       "--user-data-dir=" + paths.userData(account.id).path, "unset", "unset"])
        }
        XCTAssertTrue(launcher.currentSessions.isEmpty)
        XCTAssertTrue(restored.currentSessions.isEmpty)
    }

    func testUnrelatedDesktopApplicationIsRejected() {
        XCTAssertThrowsError(try DesktopApp(url: URL(fileURLWithPath: "/System/Applications/TextEdit.app")))
    }
}
