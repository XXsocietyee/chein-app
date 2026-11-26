import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Native r2 (owner 2026-11-26, "everything native"): an Apple-style welcome screen in the system background. App icon,
/// large title, three feature rows, the agreement checkbox with both documents, one prominent 创建账号 button and a plain
/// 先逛一逛 button. No orb, gradient, shader or pager (`OnboardingFlow` stays in the design kit, unused by the app).
///
/// Behaviour is unchanged: 创建账号 opens the existing `LoginView`, which still enforces the usage-consent gate;
/// 先逛一逛 starts guest browsing; the launch consent sheet (`usageConsentLaunchGate`) is untouched. The checkbox shows
/// and records the same stored agreement the gate writes (`UsageConsentPolicy.agree(agreementChecked: true)`).
struct WelcomeView: View {
    @EnvironmentObject private var session: AppSession
    var onBrowse: (() -> Void)? = nil
    /// Launch is player-first (owner decision): the merchant choice is hidden here. Merchants still reach their
    /// flow through Settings / the Me tab; flip to `true` to restore the second role button.
    static let showsMerchantChoice = false
    private enum Destination: Identifiable {
        case settings, login(RegistrationIntent), legal(SettingsLegalType)
        var id: String {
            switch self {
            case .settings: return "settings"
            case .login(let intent): return "login-" + intent.rawValue
            case .legal(let type): return "legal-" + type.rawValue
            }
        }
    }
    @State private var destination: Destination?
    /// Set once the player has registered or chosen to browse (kept from the onboarding pager for returning launches).
    @AppStorage("onboarding.completed.v1") private var onboardingCompleted = false
    /// Mirrors the stored usage agreement (MP pages/privacy/index.wxml:10 `我已阅读并同意《用户服务协议》《隐私保护指引》`).
    @State private var consentChecked = false
    @Environment(\.scenePhase) private var scenePhase

    private var consentPolicy: UsageConsentPolicy { UsageConsentEnvironment.policy }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 36) {
                    header
                    features
                    if let key = WelcomeSessionPresentation.upgradeNoticeKey(errorKey: session.errorKey, accountID: session.account?.id) {
                        Label(LocalizedStringKey(key), systemImage: "arrow.up.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("welcome.upgradeRequired")
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 40)
                .padding(.bottom, 24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) { footer }
            .background(Color(uiColor: .systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { moreMenu }
            }
            .sheet(item: $destination) { destination in
                switch destination {
                case .settings: SettingsView()
                case .login(let intent): LoginView(intent: intent)
                case .legal(let type): legalSheet(type)
                }
            }
        }
        .themeDomain(.player)
        .onAppear { refreshConsent() }
        .onChange(of: destination?.id) { _, _ in refreshConsent() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refreshConsent() } }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in refreshConsent() }
    }

    // MARK: Header and features

    private var header: some View {
        VStack(spacing: 20) {
            WelcomeAppIcon()
            Text("nativeR2.shell.welcome.title")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("welcome.title")
        }
        .frame(maxWidth: .infinity)
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 24) {
            WelcomeFeatureRow(systemImage: "map", title: "onboarding.roam.title", detail: "onboarding.roam.body")
            WelcomeFeatureRow(systemImage: "checkmark.seal", title: "onboarding.stamps.title", detail: "onboarding.stamps.body")
            WelcomeFeatureRow(systemImage: "person.2", title: "onboarding.clubs.title", detail: "onboarding.clubs.body")
        }
        .accessibilityIdentifier("welcome.features")
    }

    // MARK: Consent and actions

    private var consentRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: toggleConsent) {
                Label {
                    Text("fixr9.ap.consent.readAndAgree")
                        .font(.footnote)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: consentChecked ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(consentChecked ? Color.accentColor : Color.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("welcome.consent.checkbox")
            .accessibilityAddTraits(consentChecked ? [.isSelected] : [])
            .accessibilityValue(Text(consentChecked ? "fixr9.ap.consent.checked" : "fixr9.ap.consent.unchecked"))
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { agreementLink; privacyLink }
                VStack(alignment: .leading, spacing: 6) { agreementLink; privacyLink }
            }
            .font(.footnote)
            .buttonStyle(.borderless)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var agreementLink: some View {
        Button { destination = .legal(.userAgreement) } label: { Text("authEntry.gate.openAgreement", tableName: "AuthEntry") }
            .accessibilityIdentifier("welcome.consent.agreement")
    }

    private var privacyLink: some View {
        Button { destination = .legal(.privacyPolicy) } label: { Text("authEntry.gate.openPrivacyGuide", tableName: "AuthEntry") }
            .accessibilityIdentifier("welcome.consent.privacyGuide")
    }

    private var footer: some View {
        VStack(spacing: 12) {
            consentRow
            Button {
                onboardingCompleted = true
                destination = .login(.player)
            } label: {
                Text("onboarding.createAccount").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("welcome.player")
            if Self.showsMerchantChoice {
                Button { destination = .login(.merchant) } label: { Text("role.merchant").frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("welcome.merchant")
            }
            if let onBrowse {
                Button("welcome.browse") {
                    onboardingCompleted = true
                    onBrowse()
                }
                .buttonStyle(.borderless)
                .controlSize(.large)
                .accessibilityIdentifier("welcome.browse")
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

    /// Language, saved drafts and settings live in one toolbar menu.
    private var moreMenu: some View {
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

    private func legalSheet(_ type: SettingsLegalType) -> some View {
        NavigationStack {
            SettingsLegalDocumentView(type: type, market: session.operationalMarket, reader: session.legalReader)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("action.close") { destination = nil }
                            .accessibilityIdentifier("welcome.legal.close")
                    }
                }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func refreshConsent() {
        let granted = consentPolicy.granted
        if consentChecked != granted { consentChecked = granted }
    }

    /// Checking records the same agreement as the launch gate; unchecking withdraws it (MP declineUsageConsent).
    private func toggleConsent() {
        if consentChecked {
            consentPolicy.decline()
        } else {
            try? consentPolicy.agree(agreementChecked: true)
        }
        consentChecked = consentPolicy.granted
    }
}

/// One feature line in the Apple welcome style: a tinted SF Symbol, a headline and a secondary subheadline.
private struct WelcomeFeatureRow: View {
    let systemImage: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundStyle(Color.accentColor)
                .frame(width: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The installed app icon (from the bundle's primary icon), as Apple's welcome screens show it. Falls back to an SF Symbol.
private struct WelcomeAppIcon: View {
    var body: some View {
        #if canImport(UIKit)
        if let image = Self.primaryIcon() {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .accessibilityHidden(true)
        } else {
            fallback
        }
        #else
        fallback
        #endif
    }

    private var fallback: some View {
        Image(systemName: "building.2.crop.circle.fill")
            .font(.system(.largeTitle))
            .imageScale(.large)
            .foregroundStyle(Color.accentColor)
            .accessibilityHidden(true)
    }

    #if canImport(UIKit)
    private static func primaryIcon() -> UIImage? {
        guard let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primary["CFBundleIconFiles"] as? [String],
              let name = files.last else { return nil }
        return UIImage(named: name)
    }
    #endif
}

#Preview("English") { WelcomeView(onBrowse: {}).environmentObject(AppSession()).environment(\.locale, Locale(identifier: "en")) }
#Preview("简体中文 · Large type") {
    WelcomeView(onBrowse: {}).environmentObject(AppSession()).environment(\.locale, Locale(identifier: "zh-Hans"))
        .environment(\.dynamicTypeSize, .accessibility3)
}
#Preview("Dark") { WelcomeView(onBrowse: {}).environmentObject(AppSession()).preferredColorScheme(.dark) }
