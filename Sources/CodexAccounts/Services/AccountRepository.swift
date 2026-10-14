import Foundation

struct ManagedPaths {
    let root: URL

    static var applicationSupport: ManagedPaths {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return ManagedPaths(root: support.appendingPathComponent("Codex Accounts", isDirectory: true))
    }

    var stateFile: URL { root.appendingPathComponent("accounts.json") }
    func profile(_ id: UUID) -> URL {
        root.appendingPathComponent("profiles", isDirectory: true)
            .appendingPathComponent(id.uuidString.lowercased(), isDirectory: true)
    }
    func codexHome(_ id: UUID) -> URL { profile(id).appendingPathComponent("codex", isDirectory: true) }
    func userData(_ id: UUID) -> URL { profile(id).appendingPathComponent("user-data", isDirectory: true) }

    func prepare(_ id: UUID) throws {
        let fm = FileManager.default
        // A profile's identity is a UUID, never a user-supplied name or path.
        for url in [root, root.appendingPathComponent("profiles"), profile(id), codexHome(id), userData(id)] {
            if fm.fileExists(atPath: url.path) {
                let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
                guard values.isSymbolicLink != true, values.isDirectory == true else {
                    throw StorageError.unsafeDirectory
                }
            } else {
                try fm.createDirectory(at: url, withIntermediateDirectories: true,
                                       attributes: [.posixPermissions: 0o700])
            }
            try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        }
        let config = codexHome(id).appendingPathComponent("config.toml")
        if !fm.fileExists(atPath: config.path) {
            // Each new profile starts clean. Existing user configuration is preserved.
            try Data("cli_auth_credentials_store = \"file\"\n".utf8).write(to: config, options: .atomic)
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: config.path)
        }
    }
}

struct AccountRepository {
    let paths: ManagedPaths

    func load() throws -> StoredState {
        guard FileManager.default.fileExists(atPath: paths.stateFile.path) else { return StoredState() }
        let state = try JSONDecoder().decode(StoredState.self, from: Data(contentsOf: paths.stateFile))
        guard state.version == 1 else { throw StorageError.unsupportedVersion }
        guard Set(state.accounts.map(\.id)).count == state.accounts.count else { throw StorageError.duplicateIdentity }
        for account in state.accounts { _ = try account.validated() }
        return state
    }

    func save(_ state: StoredState) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: paths.root.path) {
            let values = try paths.root.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
            guard values.isSymbolicLink != true, values.isDirectory == true else { throw StorageError.unsafeDirectory }
        }
        try fm.createDirectory(at: paths.root, withIntermediateDirectories: true,
                               attributes: [.posixPermissions: 0o700])
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: paths.root.path)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(state).write(to: paths.stateFile, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: paths.stateFile.path)
    }
}

enum StorageError: LocalizedError {
    case unsafeDirectory, unsupportedVersion, duplicateIdentity
    var errorDescription: String? {
        switch self {
        case .unsafeDirectory: L10n.string("error.storage.directory")
        case .unsupportedVersion: L10n.string("error.storage.version")
        case .duplicateIdentity: L10n.string("error.storage.duplicate")
        }
    }
}
