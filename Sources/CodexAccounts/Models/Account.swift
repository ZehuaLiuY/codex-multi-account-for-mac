import Foundation

enum AccountTint: String, Codable, CaseIterable, Identifiable {
    case sage, blue, lavender, peach, graphite
    var id: String { rawValue }
    var title: String { L10n.string("color." + rawValue) }
}

struct Account: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var note: String = ""
    var symbol: String = "person"
    var tint: AccountTint = .sage
    var isFavorite = false
    var createdAt = Date()
    var lastOpenedAt: Date?

    static let symbols = ["person", "briefcase", "sparkles", "terminal", "flask"]

    func validated() throws -> Account {
        var result = self
        result.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        result.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.name.isEmpty else { throw AccountError.emptyName }
        guard result.name.count <= 40 else { throw AccountError.longName }
        guard result.note.count <= 100 else { throw AccountError.longNote }
        guard Self.symbols.contains(symbol) else { throw AccountError.invalidSymbol }
        return result
    }

    static var examples: [Account] { [
        Account(id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
                name: L10n.string("demo.personal"), symbol: "person", tint: .sage,
                isFavorite: true, lastOpenedAt: Date().addingTimeInterval(-600)),
        Account(id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
                name: L10n.string("demo.work"), symbol: "briefcase", tint: .blue,
                lastOpenedAt: Date().addingTimeInterval(-86400)),
        Account(id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
                name: L10n.string("demo.lab"), symbol: "flask", tint: .lavender)
    ] }
}

enum AccountError: LocalizedError {
    case emptyName, longName, longNote, invalidSymbol
    var errorDescription: String? {
        switch self {
        case .emptyName: L10n.string("error.name.empty")
        case .longName: L10n.string("error.name.long")
        case .longNote: L10n.string("error.note.long")
        case .invalidSymbol: L10n.string("error.symbol")
        }
    }
}

struct Activity: Codable, Identifiable {
    var id = UUID()
    var accountName: String
    var message: String
    var date = Date()
    var symbol = "arrow.up.right"

    func localizedMessage(language: String = L10n.language) -> String {
        // Older versions persisted Chinese sentences. Translate known actions at
        // display time, keeping the stored account names and original data intact.
        guard let action = ActivityAction(rawValue: message) ?? ActivityAction.legacyMessages[message] else { return message }
        return L10n.string(action.rawValue, language: language)
    }
}

enum ActivityAction: String, CaseIterable {
    case added = "activity.added", updated = "activity.updated", removed = "activity.removed"
    case opened = "activity.opened", demoOpened = "activity.demoOpened"
    case closed = "activity.closed", unexpectedExit = "activity.unexpectedExit"

    static let legacyMessages: [String: ActivityAction] = [
        "添加了账号": .added, "更新了账号": .updated, "从列表移除了账号": .removed,
        "打开了独立窗口": .opened, "打开了独立窗口（演示）": .demoOpened,
        "关闭了独立窗口": .closed, "窗口意外退出": .unexpectedExit
    ]
}

struct StoredState: Codable {
    var version = 1
    var accounts: [Account] = []
    var activities: [Activity] = []
    var customAppPath: String?
    var sessions: [WindowSession] = []

    enum CodingKeys: String, CodingKey { case version, accounts, activities, customAppPath, sessions }

    init(version: Int = 1, accounts: [Account] = [], activities: [Activity] = [],
         customAppPath: String? = nil, sessions: [WindowSession] = []) {
        self.version = version
        self.accounts = accounts
        self.activities = activities
        self.customAppPath = customAppPath
        self.sessions = sessions
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        accounts = try values.decode([Account].self, forKey: .accounts)
        activities = try values.decodeIfPresent([Activity].self, forKey: .activities) ?? []
        customAppPath = try values.decodeIfPresent(String.self, forKey: .customAppPath)
        sessions = try values.decodeIfPresent([WindowSession].self, forKey: .sessions) ?? []
    }
}
