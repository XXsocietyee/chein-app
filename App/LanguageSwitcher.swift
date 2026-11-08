import SwiftUI

/// Applies the stored language choice to the subtree and publishes it for Core/bundle-built strings.
struct AppLanguageEnvironment: ViewModifier {
    let stored: String
    func body(content: Content) -> some View {
        content.environment(\.locale, Self.apply(stored: stored).locale)
    }
    /// Resolves the stored value and publishes it before any child body reads Core/bundle copy.
    @discardableResult static func apply(stored: String) -> AppLanguage {
        let language = RegionalLaunchConfiguration.language(stored)
        AppLanguageRuntime.active = language
        return language
    }
}

/// Compact language menu: Follow system / English / 简体中文. It reads and writes the same
/// `preferences.language` key as Settings, so both controls always agree and the choice persists.
struct LanguageSwitcher: View {
    static let storageKey = AppLanguage.storageKey
    @AppStorage(AppLanguage.storageKey) private var storedLanguage = RegionalLaunchConfiguration.language(nil).rawValue

    private var selection: Binding<AppLanguage> {
        Binding(get: { RegionalLaunchConfiguration.language(storedLanguage) },
                set: { storedLanguage = $0.rawValue })
    }

    var body: some View {
        Menu {
            Picker(selection: selection) {
                Text("language.system").tag(AppLanguage.system)
                Text(verbatim: "English").tag(AppLanguage.english)
                Text(verbatim: "简体中文").tag(AppLanguage.simplifiedChinese)
            } label: { Text("settings.language") }
        } label: {
            Image(systemName: "globe").frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel(Text("settings.language"))
        .accessibilityValue(current)
        .accessibilityIdentifier("language.switcher")
    }

    private var current: Text {
        switch selection.wrappedValue {
        case .system: return Text("language.system")
        case .english: return Text(verbatim: "English")
        case .simplifiedChinese: return Text(verbatim: "简体中文")
        }
    }
}
