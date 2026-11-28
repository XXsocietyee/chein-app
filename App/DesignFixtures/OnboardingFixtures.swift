#if DEBUG
import SwiftUI

/// D1 onboarding fixtures (synthetic, debug only): `welcome`, `welcome-menu`, `consent`, `login-player`, `onboarding-1`...`onboarding-5`, `onboarding-zh-1`...`onboarding-zh-5`, `onboarding-ax`.
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

/// Onboarding pager at a fixed step (`onboarding-1`...`onboarding-5`); `ax` renders the last step at the largest
/// accessibility type size in Simplified Chinese (`onboarding-ax`).
/// Night-light wave 3 (B8): the fixtures play their own demo (hold-GO at 1.0 s, stamp at 1.0 s, clubs join at 1.0 s,
/// Create-account morph at 1.8 s) so a screen recording shows the whole beat sheet. `zhHans` swaps the locale only
/// (`onboarding-zh-1`...`onboarding-zh-5`); timing is identical. Pair with `--uitesting-fake-tilt` for parallax and
/// `--uitesting-reduce-motion` for the fallback video.
struct OnboardingFixture: View {
    let step: OnboardingStep
    var accessibility = false
    var zhHans = false
    var body: some View {
        let flow = OnboardingFlow(initialStep: step, autoDemo: !accessibility, onRegister: {}, onGuest: {}).cyScreenStyle().roleTheme(.player)
        if accessibility {
            flow.environment(\.dynamicTypeSize, .accessibility3).environment(\.locale, Locale(identifier: "zh-Hans"))
        } else if zhHans {
            flow.environment(\.locale, Locale(identifier: "zh-Hans"))
        } else {
            flow
        }
    }
}

struct ConsentFixture: View {
    var body: some View {
        UsageConsentGateView(market: nil, onAgree: {}, onDecline: {})
    }
}

struct LoginFixture: View {
    /// Sweep 04:50: render the shipped CN channel set (Apple approved), not the unreviewed bare session.
    @State private var channels = AuthChannelCoordinator(
        service: nil, appleSignInApproved: true,
        currentSession: { AuthChannelSessionSnapshot(epoch: 0, accountID: nil) },
        commitLogin: { (_: LoginResult, _: AuthChannelSessionSnapshot) -> Bool in false })
    @StateObject private var session = AppSession()
    var body: some View {
        var view = LoginView(intent: .player)
        view.designOverride = LoginView.DesignOverride(showsPassword: false, authChannels: channels)
        return view.environmentObject(session)
    }
}
#endif
