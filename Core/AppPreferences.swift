import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable {
    case system, english = "en", simplifiedChinese = "zh-Hans"
    /// What `W8Text` must follow so Core copy matches the in-app language: `nil` follows the system.
    public var w8Override: String? { self == .system ? nil : rawValue }
    public var id: String { rawValue }
    public init(storedValue: String) { self = Self(rawValue: storedValue) ?? .system }
    /// One-app (owner 2026-11-27): the language used when the user has stored no choice. It follows the
    /// phone (`Locale.preferredLanguages`): any zh* → Simplified Chinese, everything else → English.
    public static func deviceDefault(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        (preferredLanguages.first ?? "").lowercased().hasPrefix("zh") ? .simplifiedChinese : .english
    }
    public var locale: Locale {
        self == .system ? .autoupdatingCurrent : Locale(identifier: rawValue)
    }
    /// The one UserDefaults key shared by Settings, the language switcher and the app root.
    public static let storageKey = "preferences.language"
    /// Explicit choices decide directly; System defers to the device's preferred language code.
    public func isChinese(systemLanguageCode: String) -> Bool {
        self == .system ? systemLanguageCode.hasPrefix("zh") : self == .simplifiedChinese
    }

    /// UI language for bilingual copy. An explicit Settings choice wins. System follows the
    /// bundle's preferred localization (AppleLanguages), not the region locale: a zh-Hans UI
    /// with an en_US region must not keep English kit strings.
    public static func interfaceIsChinese(_ locale: Locale) -> Bool {
        if let active = AppLanguageRuntime.active {
            switch active {
            case .english: return false
            case .simplifiedChinese: return true
            case .system:
                let preferred = Bundle.main.preferredLocalizations.first ?? Locale.preferredLanguages.first ?? locale.identifier
                return preferred.lowercased().hasPrefix("zh")
            }
        }
        let identifier = locale.identifier.lowercased()
        if identifier.hasPrefix("zh") { return true }
        let language = locale.language.languageCode?.identifier.lowercased() ?? ""
        if language.hasPrefix("zh") { return true }
        let script = locale.language.script?.identifier.lowercased() ?? ""
        return script == "hans" || script == "hant"
    }
}

/// Persisted language choice. An explicit choice (including System) always wins. With no stored
/// choice the phone decides (`AppLanguage.deviceDefault`), for every market; the default is never stored.
public struct AppLanguagePreference {
    private let defaults: UserDefaults
    private let market: RegionalMarket?
    private let preferredLanguages: [String]
    public init(defaults: UserDefaults = .standard, market: RegionalMarket?,
                preferredLanguages: [String] = Locale.preferredLanguages) {
        self.defaults = defaults; self.market = market; self.preferredLanguages = preferredLanguages
    }
    public var language: AppLanguage {
        let stored = defaults.string(forKey: AppLanguage.storageKey)
        return market?.language(storedValue: stored, preferredLanguages: preferredLanguages)
            ?? stored.map(AppLanguage.init(storedValue:))
            ?? AppLanguage.deviceDefault(preferredLanguages: preferredLanguages)
    }
    public func select(_ language: AppLanguage) {
        defaults.set(language.rawValue, forKey: AppLanguage.storageKey)
    }
}

/// The language the UI is currently showing, published by the app root whenever the stored
/// choice changes so Core/bundle-built strings follow the switcher without a restart.
public enum AppLanguageRuntime {
    nonisolated(unsafe) public static var active: AppLanguage?
}

/// An onboarding intention, never evidence of authorization or a server-owned role.
public enum RegistrationIntent: String, CaseIterable, Identifiable {
    case player, merchant
    public var id: String { rawValue }
}
