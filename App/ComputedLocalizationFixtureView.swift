#if DEBUG
import SwiftUI

struct ComputedLocalizationFixtureView: View {
    @Environment(\.locale) private var locale
    @AppStorage("preferences.language") private var language = AppLanguage.system.rawValue
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxl) {
            // The computed catalog string is the only visible title. The bar stays blank.
            CYHeroHeader(verbatim: appLocalized("settings.title", locale: locale), titleIdentifier: "localization.fixture.computed")
            CYPillButton(verbatim: "简体中文", style: .secondary) { language = AppLanguage.simplifiedChinese.rawValue }
                .accessibilityLabel(Text(verbatim: "简体中文"))
                .accessibilityIdentifier("localization.fixture.chinese")
            CYPillButton(verbatim: "English", style: .secondary) { language = AppLanguage.english.rawValue }
                .accessibilityLabel(Text(verbatim: "English"))
                .accessibilityIdentifier("localization.fixture.english")
        }
        .padding(.horizontal, CYSpacing.pageHorizontal)
        .padding(.vertical, CYSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cyDomainPageBackground()
        .themeDomain(.player)
        .cyHeroScreen()
    }
}
#endif
