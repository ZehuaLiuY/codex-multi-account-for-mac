import AppKit
import Foundation

struct DesktopApp: Equatable {
    let url: URL
    let executable: URL
    let name: String
    let version: String

    init(url: URL) throws {
        guard url.pathExtension == "app", let bundle = Bundle(url: url),
              bundle.bundleIdentifier == "com.openai.codex",
              let executable = bundle.executableURL,
              FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw LaunchError.invalidApp
        }
        self.url = url
        self.executable = executable
        self.name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        self.version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    static func detect(customPath: String?) -> DesktopApp? {
        if let customPath { return try? DesktopApp(url: URL(fileURLWithPath: customPath)) }
        for path in ["/Applications/ChatGPT.app", "/Applications/Codex.app",
                     NSHomeDirectory() + "/Applications/ChatGPT.app", NSHomeDirectory() + "/Applications/Codex.app"] {
            if let app = try? DesktopApp(url: URL(fileURLWithPath: path)) { return app }
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex") {
            return try? DesktopApp(url: url)
        }
        return nil
    }
}

struct LaunchPlan {
    let executable: URL
    let arguments: [String]
    let environment: [String: String]

    init(executable: URL, accountID: UUID, paths: ManagedPaths, inheritedEnvironment: [String: String]) {
        self.executable = executable
        arguments = ["--user-data-dir=" + paths.userData(accountID).path]
        // Carry ordinary OS variables, but do not leak the current Codex session,
        // credentials, IPC endpoints, or Electron/Node injection variables.
        environment = inheritedEnvironment.filter { key, _ in
            !key.hasPrefix("CODEX_") && !key.hasPrefix("OPENAI_")
                && !key.hasPrefix("ELECTRON_") && !key.hasPrefix("NODE_")
        }.merging([
            "CODEX_HOME": paths.codexHome(accountID).path,
            "CODEX_ELECTRON_USER_DATA_PATH": paths.userData(accountID).path
        ], uniquingKeysWith: { _, new in new })
    }
}

@MainActor
final class AppLauncher {
    private var processes: [UUID: Process] = [:]
    private var sessions: [UUID: WindowSession] = [:]

    var currentSessions: [WindowSession] { sessions.values.filter { $0.process.isCurrent } }

    func restore(_ saved: [WindowSession]) {
        for session in saved where session.process.isCurrent { sessions[session.accountID] = session }
    }

    func isRunning(_ id: UUID) -> Bool { sessions[id]?.process.isCurrent == true }

    func activate(_ id: UUID) {
        guard let session = sessions[id], session.process.isCurrent else { return }
        NSRunningApplication(processIdentifier: session.process.pid)?.activate(options: [.activateAllWindows])
    }

    func launch(account: Account, app: DesktopApp, paths: ManagedPaths,
                onExit: @escaping @MainActor (Int32) -> Void) throws {
        if isRunning(account.id) { activate(account.id); return }
        try paths.prepare(account.id)
        let plan = LaunchPlan(executable: app.executable, accountID: account.id, paths: paths,
                              inheritedEnvironment: ProcessInfo.processInfo.environment)
        let process = Process()
        process.executableURL = plan.executable
        process.arguments = plan.arguments
        process.environment = plan.environment
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        // Never include child output in UI or logs; it may contain credentials.
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] process in
            let status = process.terminationStatus
            let pid = process.processIdentifier
            Task { @MainActor in
                // A delayed exit callback must not remove a newly opened window.
                guard self?.sessions[account.id]?.process.pid == pid else { return }
                self?.sessions.removeValue(forKey: account.id)
                self?.processes.removeValue(forKey: account.id)
                onExit(status)
            }
        }
        try process.run()
        guard let identity = ProcessIdentity.capture(pid: process.processIdentifier) else { throw LaunchError.exitedEarly }
        sessions[account.id] = WindowSession(accountID: account.id, process: identity)
        processes[account.id] = process
        // A directly spawned app may register with macOS after Process.run().
        // Wait until it is ready before bringing the new login window forward.
        Task { @MainActor [weak self] in
            for _ in 0..<100 {
                guard self?.sessions[account.id]?.process == identity, identity.isCurrent else { return }
                if let application = NSRunningApplication(processIdentifier: identity.pid), application.isFinishedLaunching {
                    application.activate(options: [.activateAllWindows])
                    return
                }
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
            }
        }
    }
}

enum LaunchError: LocalizedError {
    case invalidApp, missingApp, exitedEarly
    var errorDescription: String? {
        switch self {
        case .invalidApp: L10n.string("error.app.invalid")
        case .missingApp: L10n.string("error.app.missing")
        case .exitedEarly: L10n.string("error.app.start")
        }
    }
}
