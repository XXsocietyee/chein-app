import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Native r2 (owner 2026-11-26, "everything native"): an Apple-style welcome screen in the system background. A live
/// map with a sample route first (L1 P-007), large title, three feature rows, the agreement checkbox with both
/// documents (only while the agreement is not on record, P-008), one prominent 创建账号 button and a plain 先逛一逛
/// button. At accessibility text sizes the buttons scroll with the content instead of pinning (P-009).
/// No orb, gradient, shader or pager (`OnboardingFlow` stays in the design kit, unused by the app).
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
        case login(RegistrationIntent), legal(SettingsLegalType)
        var id: String {
            switch self {
            case .login(let intent): return "login-" + intent.rawValue
            case .legal(let type): return "legal-" + type.rawValue
            }
        }
    }
    @State private var destination: Destination?
    /// mp-nav r3: MP 设置 = navigateTo pages/shezhi/shezhi, a page: pushed on this stack (system back, no 完成).
    @State private var showsSettings = false
    /// Set once the player has registered or chosen to browse (kept from the onboarding pager for returning launches).
    @AppStorage("onboarding.completed.v1") private var onboardingCompleted = false
    /// Mirrors the stored usage agreement (MP pages/privacy/index.wxml:10 `我已阅读并同意《用户服务协议》《隐私保护指引》`).
    @State private var consentChecked = false
    /// P-008: the checkbox appears only once the agreement is found missing; checking it here keeps it visible
    /// (VoiceOver focus stays put), and an agreement already on record never asks again.
    @State private var asksConsent = false
    /// mp-nav r3 (Next round 2): counts the player's own taps, so the stored agreement syncing in does not tick.
    @State private var consentTaps = 0
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// P-009: a pinned footer covers most of the screen at accessibility sizes, so it scrolls with the content there.
    private var footerScrolls: Bool { dynamicTypeSize.isAccessibilitySize }

    private var consentPolicy: UsageConsentPolicy { UsageConsentEnvironment.policy }

    var body: some View {
        NavigationStack {
            Group {
                // Owner rule 2: signed out, this is still the 我的 tab root, so it keeps the large top-left title 我的.
                if onBrowse == nil {
                    signedOutMine.cyRootHeader(.mine)
                } else {
                    welcomeContent.navigationBarTitleDisplayMode(.inline)
                }
            }
            // mp-nav r3 (OWNER RULE 2): signed out, this is the 我的 tab root, so it carries the large 我的 title like the
            // signed-in root. The launch welcome (guest browse) is not a tab root and keeps an untitled inline bar.
            .modifier(WelcomeRootTitle(isTabRoot: onBrowse == nil))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { moreMenu }
            }
            .navigationDestination(isPresented: $showsSettings) {
                SettingsView(isPushed: true).themeDomain(.player).cyPushedChrome()
            }
            .cySheet(item: $destination) { destination in
                switch destination {
                case .login(let intent): LoginView(intent: intent)
                case .legal(let type): legalSheet(type)
                }
            }
        }
        .themeDomain(.player)
        .onAppear { refreshConsent() }
        .onChange(of: destination?.id) { _, _ in refreshConsent() }
        .onChange(of: showsSettings) { _, _ in refreshConsent() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refreshConsent() } }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in refreshConsent() }
    }

    /// r9 A1-08: MP pages/member/index/index.wxml:6 — signed out, the 我的 tab is the in-page empty state
    /// `cy-empty kind="no-permission" title="登录后查看我的主页" cta="登录"`, not the welcome page.
    /// 登录 keeps the `welcome.player` id and opens the same player sign-in sheet (LoginView keeps the consent gate).
    private var signedOutMine: some View {
        ContentUnavailableView {
            Label("fixr9.ap.mine.signedOutTitle", systemImage: "person.crop.circle.badge.questionmark")
        } description: {
            if let key = WelcomeSessionPresentation.upgradeNoticeKey(errorKey: session.errorKey, accountID: session.account?.id) {
                Text(LocalizedStringKey(key))
                    .accessibilityIdentifier("welcome.upgradeRequired")
            }
        } actions: {
            Button { destination = .login(.player) } label: { Text("fixr9.ap.mine.signIn") }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("welcome.player")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

    /// Launch welcome (guest browse available).
    private var welcomeContent: some View {
        ScrollView {
            VStack(spacing: 32) {
                WelcomeSampleRouteMap()
                header
                features
                // P-008: the launch sheet already asked; the checkbox shows only while nothing is on record.
                // P-009: it lives in the scrolling content, so 先逛一逛 can no longer sit on top of its footnote.
                if asksConsent { consentRow }
                if let key = WelcomeSessionPresentation.upgradeNoticeKey(errorKey: session.errorKey, accountID: session.account?.id) {
                    Label(LocalizedStringKey(key), systemImage: "arrow.up.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("welcome.upgradeRequired")
                }
                if footerScrolls { actions }
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            if !footerScrolls { footer }
        }
        .animation(reduceMotion ? nil : .default, value: asksConsent)
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: Header and features

    private var header: some View {
        VStack(spacing: 20) {
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
            .sensoryFeedback(.selection, trigger: consentTaps)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { agreementLink; privacyLink }
                VStack(alignment: .leading, spacing: 0) { agreementLink; privacyLink }
            }
            .font(.footnote)
            .buttonStyle(.borderless)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var agreementLink: some View {
        Button { destination = .legal(.userAgreement) } label: { Text("authEntry.gate.openAgreement", tableName: "AuthEntry").frame(minHeight: CYSpacing.minTouchTarget).contentShape(Rectangle()) }
            .accessibilityIdentifier("welcome.consent.agreement")
    }

    private var privacyLink: some View {
        Button { destination = .legal(.privacyPolicy) } label: { Text("authEntry.gate.openPrivacyGuide", tableName: "AuthEntry").frame(minHeight: CYSpacing.minTouchTarget).contentShape(Rectangle()) }
            .accessibilityIdentifier("welcome.consent.privacyGuide")
    }

    /// The pinned bottom bar (regular text sizes).
    private var footer: some View {
        actions
            .padding(.horizontal, 32)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemBackground))
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                onboardingCompleted = true
                destination = .login(.player)
            } label: {
                Text("onboarding.createAccount").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("welcome.player")
            if Self.showsMerchantChoice && PlayerLaunch.merchantCenterEnabled { // Lane G
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
    }

    /// Language, saved drafts and settings live in one toolbar menu.
    private var moreMenu: some View {
        Menu {
            NavigationLink { OwnerDraftGuestView() } label: { Label("ownerDraft.title", systemImage: "doc.on.doc") }
                .accessibilityIdentifier("ownerDraft.guestEntry")
            Button("settings.title", systemImage: "gearshape") { showsSettings = true }
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
        if !granted && !asksConsent { asksConsent = true }
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
        consentTaps += 1
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

#Preview("English") { WelcomeView(onBrowse: {}).environmentObject(AppSession()).environment(\.locale, Locale(identifier: "en")) }
#Preview("简体中文 · Large type") {
    WelcomeView(onBrowse: {}).environmentObject(AppSession()).environment(\.locale, Locale(identifier: "zh-Hans"))
        .environment(\.dynamicTypeSize, .accessibility3)
}
#Preview("Dark") { WelcomeView(onBrowse: {}).environmentObject(AppSession()).preferredColorScheme(.dark) }

/// The signed-out 我的 tab root takes the shared large root title; the launch welcome keeps an inline bar.
private struct WelcomeRootTitle: ViewModifier {
    let isTabRoot: Bool
    func body(content: Content) -> some View {
        if isTabRoot {
            content.cyRootHeader(.mine)
        } else {
            content.navigationBarTitleDisplayMode(.inline)
        }
    }
}
