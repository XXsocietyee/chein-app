import Foundation

/// Locale-aware copy for W8 play/RPG Core rules whose strings are surfaced by views.
/// Mirrors the app's inline `copy("中文", "English")` pattern for code that has no SwiftUI locale.
public enum W8Text {
    /// Test hook: set to "en" or "zh-Hans" to force a language.
    nonisolated(unsafe) public static var languageOverride: String?

    public static var isChinese: Bool {
        if let languageOverride { return languageOverride.hasPrefix("zh") }
        // Unit tests run with a non-localized bundle; keep the original (Chinese) rule copy there.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil || NSClassFromString("XCTestCase") != nil { return true }
        let lang = Bundle.main.preferredLocalizations.first ?? Locale.preferredLanguages.first ?? "en"
        return lang.hasPrefix("zh")
    }

    public static func t(_ zh: String, _ en: String) -> String {
        isChinese ? zh : en
    }
}
