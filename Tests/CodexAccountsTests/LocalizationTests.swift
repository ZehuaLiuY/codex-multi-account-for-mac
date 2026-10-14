import XCTest
@testable import CodexAccounts

final class LocalizationTests: XCTestCase {
    func testEnglishAndChineseHaveMatchingKeysAndFormatArguments() throws {
        let english = try table("en")
        let chinese = try table("zh-Hans")
        XCTAssertGreaterThan(english.count, 70)
        XCTAssertEqual(Set(english.keys), Set(chinese.keys))
        let arguments = try NSRegularExpression(pattern: "%([0-9]+\\$)?[@df]")
        for key in english.keys {
            func placeholders(_ value: String) -> [String] {
                let text = value as NSString
                return arguments.matches(in: value, range: NSRange(location: 0, length: text.length))
                    .map { text.substring(with: $0.range) }
            }
            XCTAssertEqual(placeholders(english[key]!), placeholders(chinese[key]!), key)
            XCTAssertEqual(L10n.string(key, language: "en"), english[key])
            XCTAssertEqual(L10n.string(key, language: "zh-Hans"), chinese[key])
        }
    }

    func testLanguageFollowsOrderedSystemPreferences() {
        XCTAssertEqual(L10n.preferredLanguage(for: ["en-AU", "zh-Hans-CN"]), "en")
        XCTAssertEqual(L10n.preferredLanguage(for: ["zh-Hans-CN", "en-AU"]), "zh-Hans")
        XCTAssertEqual(L10n.preferredLanguage(for: ["fr-FR", "zh-Hans-CN", "en"]), "zh-Hans")
        XCTAssertEqual(L10n.preferredLanguage(for: ["de-DE"]), "en")
    }

    func testBothLanguageBundlesContainTranslatedUIAndErrorMessages() {
        XCTAssertEqual(L10n.string("accounts", language: "en"), "Accounts")
        XCTAssertEqual(L10n.string("accounts", language: "zh-Hans"), "账号")
        XCTAssertEqual(L10n.string("error.name.empty", language: "en"), "Enter a name.")
        XCTAssertEqual(L10n.string("error.name.empty", language: "zh-Hans"), "请输入名称。")
        XCTAssertEqual(L10n.string("accounts", language: "unsupported"), "Accounts")
    }

    func testExistingActivitiesTranslateWithoutChangingUserData() throws {
        let account = Account(name: "Ray", note: "原始备注 / My note")
        let activity = Activity(accountName: account.name, message: "打开了独立窗口")
        let encoded = try JSONEncoder().encode(StoredState(accounts: [account], activities: [activity]))
        let decoded = try JSONDecoder().decode(StoredState.self, from: encoded)
        XCTAssertEqual(decoded.accounts, [account])
        XCTAssertEqual(decoded.activities[0].accountName, "Ray")
        XCTAssertEqual(decoded.activities[0].message, "打开了独立窗口")
        XCTAssertEqual(decoded.activities[0].localizedMessage(language: "en"), "Opened")
        XCTAssertEqual(decoded.activities[0].localizedMessage(language: "zh-Hans"), "已打开")
        let unknown = Activity(accountName: "Ray", message: "A custom legacy message")
        XCTAssertEqual(unknown.localizedMessage(language: "zh-Hans"), unknown.message)
    }

    func testNewActivitiesUseLanguageIndependentActionKeys() {
        for action in ActivityAction.allCases {
            let activity = Activity(accountName: "Ray", message: action.rawValue)
            XCTAssertNotEqual(activity.localizedMessage(language: "en"), action.rawValue)
            XCTAssertNotEqual(activity.localizedMessage(language: "zh-Hans"), action.rawValue)
        }
    }

    private func table(_ language: String) throws -> [String: String] {
        let path = try XCTUnwrap(L10n.resourceBundle.path(forResource: "Localizable", ofType: "strings", inDirectory: language + ".lproj"))
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try XCTUnwrap(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
    }
}
