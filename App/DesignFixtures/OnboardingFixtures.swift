#if DEBUG
import SwiftUI

/// D1 onboarding fixtures (synthetic, debug only): `welcome`, `welcome-menu`, `consent`, `login-player`.
struct WelcomeFixture: View {
    var body: some View {
        WelcomeView(onBrowse: {}).environmentObject(AppSession())
    }
}

/// The Welcome `...` menu cannot be opened programmatically, so this shows its exact entries in a list.
struct WelcomeMenuFixture: View {
    var body: some View {
        ZStack {
            WelcomeView(onBrowse: {}).environmentObject(AppSession())
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 0) {
                row("doc.on.doc", "ownerDraft.title")
                Divider()
                row("gearshape", "settings.title")
                Divider()
                HStack { LanguageSwitcher(); Spacer() }.padding(CYSpacing.lg)
            }
            .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
            .padding(.horizontal, CYSpacing.xxl)
        }
    }
    private func row(_ symbol: String, _ key: LocalizedStringKey) -> some View {
        Label(key, systemImage: symbol).foregroundStyle(CYColor.textPrimary).padding(CYSpacing.lg).frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ConsentFixture: View {
    var body: some View {
        UsageConsentGateView(market: nil, onAgree: {}, onDecline: {})
    }
}

struct LoginFixture: View {
    var body: some View {
        LoginView(intent: .player).environmentObject(AppSession())
    }
}
#endif
