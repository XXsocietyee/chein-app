#if DEBUG
import SwiftUI

struct ComputedLocalizationFixtureView:View {
    @Environment(\.locale) private var locale
    @AppStorage("preferences.language") private var language=AppLanguage.system.rawValue
    var body:some View {
        VStack(spacing:24) {
            Text(verbatim:appLocalized("settings.title",locale:locale))
                .accessibilityIdentifier("localization.fixture.computed")
            CYPillButton(verbatim:"简体中文",style:.secondary) { language=AppLanguage.simplifiedChinese.rawValue }
                .accessibilityIdentifier("localization.fixture.chinese")
            CYPillButton(verbatim:"English",style:.secondary) { language=AppLanguage.english.rawValue }
                .accessibilityIdentifier("localization.fixture.english")
        }
        .padding(.horizontal, CYSpacing.lg)
    }
}
#endif
