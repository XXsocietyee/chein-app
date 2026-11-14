#if DEBUG
import Foundation

/// DEBUG-only App Store screenshot launch.
///
/// `--appstore-screenshot <id>` mounts an existing `--design-fixture` screen.
/// It does not create a fixture, a session, or a network client. An unknown id
/// resolves to a name `DesignFixtureRegistry` does not know, so the existing
/// unknown-fixture notice is shown and no request is sent.
enum AppStoreScreenshotHarness {
    static let flag = "--appstore-screenshot"
    static let languageFlag = "--appstore-screenshot-language"

    struct Screen: Equatable {
        let id: String
        let title: String
        let fixtureID: String
    }

    /// Eight player screens whose fixture ids already exist in `DesignFixtureRegistry`.
    static let screens: [Screen] = [
        .init(id: "home", title: "Home", fixtureID: "d2-home"),
        .init(id: "search", title: "Search", fixtureID: "d2-search"),
        .init(id: "square", title: "Square", fixtureID: "d2-square"),
        .init(id: "play", title: "Play", fixtureID: "d2-play"),
        .init(id: "roam", title: "Roam", fixtureID: "d2-roam"),
        .init(id: "inbox", title: "Messages", fixtureID: "d2-inbox"),
        .init(id: "me", title: "Account", fixtureID: "d2-me"),
        .init(id: "clubs", title: "Clubs", fixtureID: "d4-directory")
    ]

    enum Selection: Equatable {
        case absent
        case screen(Screen)
        case unknown(String)
    }

    static func selection(arguments: [String]) -> Selection {
        guard let index = arguments.firstIndex(of: Self.flag) else { return .absent }
        guard arguments.indices.contains(index + 1) else { return .unknown("") }
        let requested = arguments[index + 1]
        if requested.hasPrefix("--") { return .unknown("") }
        if let screen = Self.screens.first(where: { $0.id == requested }) {
            return .screen(screen)
        }
        return .unknown(requested)
    }

    /// Fixture id to mount, or nil when the screenshot flag is absent.
    /// A present but unknown id returns a name the registry does not define.
    static func mountedFixtureID(arguments: [String]) -> String? {
        let choice = Self.selection(arguments: arguments)
        switch choice {
        case .absent:
            return nil
        case .screen(let screen):
            return screen.fixtureID
        case .unknown(let raw):
            let suffix = raw.isEmpty ? "unknown" : raw
            return "appstore-screenshot-" + suffix
        }
    }

    /// Writes `preferences.language` before `QuestifyApp` reads `@AppStorage`.
    /// Call this from the session container initializer, which runs first.
    /// `en` and `zh-Hans` match `AppLanguage`. Any other value is ignored.
    static func applyStoredLanguage(arguments: [String]) {
        guard let index = arguments.firstIndex(of: Self.languageFlag) else { return }
        guard arguments.indices.contains(index + 1) else { return }
        let code = arguments[index + 1]
        guard code == "en" || code == "zh-Hans" else { return }
        UserDefaults.standard.set(code, forKey: AppLanguage.storageKey)
    }
}
#endif
