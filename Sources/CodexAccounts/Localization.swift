import Foundation

enum L10n {
    static let supportedLanguages = ["en", "zh-Hans"]
    static let language = preferredLanguage(for: Locale.preferredLanguages)

    static var locale: Locale {
        // Use the selected UI language while retaining the Mac's regional format.
        Locale(identifier: language + "_" + (Locale.current.region?.identifier ?? "US"))
    }

    static let resourceBundle: Bundle = {
        // A distributed .app must use its packaged resources, not the build path
        // embedded in SwiftPM's generated Bundle.module accessor.
        if let url = Bundle.main.url(forResource: "CodexAccounts_CodexAccounts", withExtension: "bundle"),
           let bundle = Bundle(url: url) { return bundle }
        return .module
    }()

    static func preferredLanguage(for preferences: [String]) -> String {
        let selected = Bundle.preferredLocalizations(from: supportedLanguages, forPreferences: preferences).first ?? "en"
        return supportedLanguages.contains(selected) ? selected : "en"
    }

    static func stringsBundle(for language: String) -> Bundle {
        let selected = supportedLanguages.contains(language) ? language : "en"
        // SwiftPM normalizes localization directory names to lowercase.
        guard let url = resourceBundle.resourceURL?.appendingPathComponent(selected.lowercased() + ".lproj"),
              let bundle = Bundle(url: url) else { return resourceBundle }
        return bundle
    }

    static func string(_ key: String, language: String = L10n.language) -> String {
        let fallback = stringsBundle(for: "en").localizedString(forKey: key, value: key, table: "Localizable")
        return stringsBundle(for: language).localizedString(forKey: key, value: fallback, table: "Localizable")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: locale, arguments: arguments)
    }
}
