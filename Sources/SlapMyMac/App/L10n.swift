import Foundation

enum L10n {
    static var language: String {
        let stored = UserDefaults.standard.string(forKey: "appLanguage") ?? ""
        if !stored.isEmpty { return stored }
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.hasPrefix("fr") { return "fr" }
        return "en"
    }

    static var availableLanguages: [(code: String, name: String)] {
        [("", "System"), ("en", "English"), ("fr", "Fran\u{00E7}ais")]
    }

    static func tr(_ key: String) -> String {
        allStrings[language]?[key] ?? allStrings["en"]?[key] ?? key
    }

    static func tr(_ key: String, _ args: CVarArg...) -> String {
        let format = allStrings[language]?[key] ?? allStrings["en"]?[key] ?? key
        return args.isEmpty ? format : String(format: format, arguments: args)
    }

    internal static var allStrings: [String: [String: String]] = [
        "en": L10nEN.strings,
        "fr": L10nFR.strings,
    ]
}
