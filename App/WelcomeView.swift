import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var session: AppSession
    var onBrowse: (() -> Void)? = nil
    /// Launch is player-first (owner decision): the merchant choice is hidden here. Merchants still reach their
    /// flow through Settings / the Me tab; flip to `true` to restore the second role button.
    static let showsMerchantChoice = false
    private enum Destination: Identifiable {
        case settings, login(RegistrationIntent)
        var id: String {
            switch self {
            case .settings: return "settings"
            case .login(let intent): return "login-" + intent.rawValue
            }
        }
    }
    @State private var destination: Destination?
    /// Set once the player has finished (or left) the intro; later launches open on the last step.
    @AppStorage("onboarding.completed.v1") private var onboardingCompleted = false
    @Environment(\.locale) private var locale
    private var isChinese: Bool { locale.identifier.hasPrefix("zh") }

    var body: some View {
        // Launch (guest browse available) gets the onboarding pager; the signed-out Me tab keeps the compact page.
        Group {
            if onBrowse != nil { onboardingBody } else { classicBody }
        }
        .cyDomainScreen(.player)
    }

    private var onboardingBody: some View {
        NavigationStack {
            OnboardingFlow(
                initialStep: onboardingCompleted ? .consent : .welcome,
                topAccessory: AnyView(moreMenu),
                onRegister: { onboardingCompleted = true; destination = .login(.player) },
                onGuest: { onboardingCompleted = true; onBrowse?() })
                .toolbar(.hidden, for: .navigationBar)
                .sheet(item: $destination) { destination in
                    switch destination {
                    case .settings: SettingsView()
                    case .login(let intent): LoginView(intent: intent)
                    }
                }
        }
    }

    /// Language, saved drafts and settings live in one quiet menu.
    private var moreMenu: some View {
        Menu {
            NavigationLink { OwnerDraftGuestView() } label: { Label("ownerDraft.title", systemImage: "doc.on.doc") }
                .accessibilityIdentifier("ownerDraft.guestEntry")
            Button("settings.title", systemImage: "gearshape") { destination = .settings }
                .accessibilityIdentifier("welcome.settings")
            LanguageSwitcher(showsMenuTitle: true)
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(CYColor.textSecondary)
                .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                .accessibilityLabel(Text("settings.title"))
        }
        .accessibilityIdentifier("welcome.more")
    }

    /// r9 A1-08: MP pages/member/index/index.wxml:6 — signed out, 我的 is the in-page empty state
    /// `cy-empty kind="no-permission" title="登录后查看我的主页" cta="登录"`, not a welcome / onboarding page.
    /// The 登录 action keeps the `welcome.player` id and opens the same player sign-in sheet.
    private var classicBody: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("fixr9.ap.mine.signedOutTitle", systemImage: "person.crop.circle.badge.questionmark")
            } description: {
                if let key = WelcomeSessionPresentation.upgradeNoticeKey(errorKey: session.errorKey, accountID: session.account?.id) {
                    Text(LocalizedStringKey(key))
                        .accessibilityIdentifier("welcome.upgradeRequired")
                }
            } actions: {
                roleButton(.player, title: "fixr9.ap.mine.signIn", primary: true)
                    .frame(maxWidth: 320)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CYColor.bgPage)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Language, saved drafts and settings live in one quiet menu.
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        NavigationLink { OwnerDraftGuestView() } label: { Label("ownerDraft.title", systemImage: "doc.on.doc") }
                            .accessibilityIdentifier("ownerDraft.guestEntry")
                        Button("settings.title", systemImage: "gearshape") { destination = .settings }
                            .accessibilityIdentifier("welcome.settings")
                        LanguageSwitcher(showsMenuTitle: true)
                    } label: {
                        Image(systemName: "ellipsis.circle").accessibilityLabel(Text("settings.title"))
                    }
                    .accessibilityIdentifier("welcome.more")
                }
            }
            .sheet(item: $destination) { destination in
                switch destination {
                case .settings: SettingsView()
                case .login(let intent): LoginView(intent: intent)
                }
            }
        }
    }

    private func roleButton(_ role: RegistrationIntent, title: LocalizedStringKey, primary: Bool) -> some View {
        Button { destination = .login(role) } label: { Text(title) }
            .buttonStyle(RoleButtonStyle(primary: primary))
            .accessibilityIdentifier("welcome.\(role.rawValue)")
    }
}

/// Full-width pill: filled for the primary role, outlined for the secondary.
private struct RoleButtonStyle: ButtonStyle {
    let primary: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: CYRadius.pill, style: .continuous)
        configuration.label
            .cyText(.label)
            .foregroundStyle(primary ? CYColor.textOnAccent : CYColor.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(primary ? AnyShapeStyle(configuration.isPressed ? CYColor.brandStrong : CYColor.actionPrimaryBg) : AnyShapeStyle(Color.clear), in: shape)
            .overlay(shape.strokeBorder(primary ? Color.clear : CYColor.borderStrong, lineWidth: 1.5))
            .shadow(color: .black.opacity(primary ? 0.3 : 0), radius: 10, y: 4)
            .contentShape(shape)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
            .cyHaptic(.impactMedium, trigger: configuration.isPressed) { old, new in !old && new }
    }
}

#Preview("English") { WelcomeView().environmentObject(AppSession()).environment(\.locale, Locale(identifier: "en")) }
#Preview("简体中文 · Large type") {
    WelcomeView().environmentObject(AppSession()).environment(\.locale, Locale(identifier: "zh-Hans"))
        .environment(\.dynamicTypeSize, .accessibility3)
}
#Preview("Dark") { WelcomeView().environmentObject(AppSession()).preferredColorScheme(.dark) }


/// Animated layered cards: three generated place covers fan out of a stack, then drift gently; a stamp seal
/// lands on the top card. Decorative (hidden from VoiceOver). Reduce Motion shows the final arrangement, still.
struct WelcomeHero: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var fanned = false
    @State private var drifting = false

    private struct Card { let seed: String; let symbol: String; let angle: Double; let x: CGFloat; let y: CGFloat; let size: CGFloat }
    private let cards = [
        Card(seed: "welcome-night-market", symbol: "fork.knife", angle: -12, x: -92, y: 34, size: 138),
        Card(seed: "welcome-stamp-trail", symbol: "ticket", angle: 11, x: 96, y: 48, size: 126),
        Card(seed: "welcome-fog-map", symbol: "map", angle: -2, x: 0, y: -4, size: 172),
    ]

    var body: some View {
        ZStack {
            ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                tile(card, index: index)
            }
            Image(systemName: "checkmark.seal.fill")
                .cyText(.data2XL)
                .foregroundStyle(Color(red: 1.0, green: 0.80, blue: 0.30), .white)
                .background(Circle().fill(Color.black.opacity(0.35)).blur(radius: 8))
                .symbolEffect(.bounce, options: .nonRepeating, value: fanned)
                .rotationEffect(.degrees(fanned || reduceMotion ? 14 : -30))
                .scaleEffect(fanned || reduceMotion ? 1 : 0.2)
                .opacity(fanned || reduceMotion ? 1 : 0)
                .offset(x: 62, y: -70)
                .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.55).delay(0.75), value: fanned)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { fanned = true; return }
            fanned = true
            drifting = true
        }
    }

    private func tile(_ card: Card, index: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: CYRadius.xl, style: .continuous)
        let settled = fanned || reduceMotion
        return CYCoverArt(seed: card.seed, symbol: card.symbol, showsDebugLabel: false)
            .frame(width: card.size, height: card.size * 1.25)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
            .shadow(color: .black.opacity(0.55), radius: 16, y: 10)
            .rotationEffect(.degrees(settled ? card.angle : 0))
            .offset(x: settled ? card.x : 0, y: settled ? card.y : 24)
            .scaleEffect(settled ? 1 : 0.82)
            .opacity(settled ? 1 : 0)
            .animation(reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.72).delay(0.12 * Double(index)), value: fanned)
            .offset(y: drifting && !reduceMotion ? (index.isMultiple(of: 2) ? -5 : 5) : 0)
            .animation(reduceMotion ? nil : .easeInOut(duration: 2.8 + Double(index) * 0.5).repeatForever(autoreverses: true), value: drifting)
    }
}
