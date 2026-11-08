import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable {
    case system, english = "en", simplifiedChinese = "zh-Hans"
    /// What `W8Text` must follow so Core copy matches the in-app language: `nil` follows the system.
    public var w8Override: String? { self == .system ? nil : rawValue }
    public var id: String { rawValue }
    public init(storedValue: String) { self = Self(rawValue: storedValue) ?? .system }
    public var locale: Locale {
        self == .system ? .autoupdatingCurrent : Locale(identifier: rawValue)
    }
}

/// An onboarding intention, never evidence of authorization or a server-owned role.
public enum RegistrationIntent: String, CaseIterable, Identifiable {
    case player, merchant
    public var id: String { rawValue }
}
