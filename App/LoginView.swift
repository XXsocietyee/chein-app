import SwiftUI

struct LoginView: View {
    let intent: RegistrationIntent
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme
    @State private var username = ""
    @State private var password = ""
    @State private var consentGranted = UsageConsentEnvironment.policy.granted
    @FocusState private var focusedField: Field?
    private enum Field { case username, password }

#if DEBUG
    /// Design fixtures only: stub values injected into the real page (no network, no session mutation).
    struct DesignOverride {
        var showsPassword = true; var username = ""; var errorKey: String?; var working = false
        /// The `login-player` fixture has no reviewed composition; this coordinator shows the approved Apple button.
        var authChannels: AuthChannelCoordinator?
    }
    var designOverride: DesignOverride?
#endif
    private var showsPasswordForm: Bool {
#if DEBUG
        if let designOverride { return designOverride.showsPassword }
        return session.canUsePassword
#else
        return false // Release signs in by phone code (or Apple) only.
#endif
    }
    private var shownErrorKey: String? {
#if DEBUG
        if let designOverride { return designOverride.errorKey }
#endif
        return session.errorKey
    }
    private var working: Bool {
#if DEBUG
        if let designOverride { return designOverride.working }
#endif
        return session.isWorking
    }
    /// L1 P-005: one sheet. The phone page and the legal documents push inside this stack instead of stacking sheets.
    @State private var path: [LoginRoute] = []
    /// The phone page is on the stack (kept as a name so the integrated-login diagnostics read the same).
    private var showsOtherSignIn: Bool { path.contains(.phone) }

    var body: some View {
        // The sign-in sheet owns one `AuthChannelModel`: Sign in with Apple on the first screen and the pushed phone
        // page share it, so a push never restarts or cancels a running authorization.
        LoginAuthChannelHost(coordinator: channelCoordinator) { model in
            stack(model)
        }
    }

    private var channelCoordinator: AuthChannelCoordinator {
#if DEBUG
        if let fixture = designOverride?.authChannels { return fixture }
#endif
        return session.authChannels
    }

    /// Split out of `stack(_:)` so the login form type-checks in time.
    private var loginHeaderSection: some View {
        Section {
            // P27: one mark, then a left-aligned title that says what happens.
            VStack(alignment: .leading, spacing: 12) {
                brandMark
                Text("auth.login.headline").cyText(.pageTitle)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                Text("auth.login.subtitle").font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder private func appleSignInSection(_ model: AuthChannelModel) -> some View {
        // P27: no disabled Apple button when no sign-in service is behind it (sweep ffeef67c7 login-player).
        if consentGranted && model.coordinator.appleConfigurationVerified && model.coordinator.isConfigured {
            Section {
                appleButton(model)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } footer: {
                if let key = model.state.issue?.localizationKey, !showsOtherSignIn {
                    Label { Text(LocalizedStringKey(key)) } icon: {
                        Image(systemName: model.state.issue == .appleIncomplete ? "info.circle" : "exclamationmark.circle.fill")
                    }
                    .foregroundStyle(model.state.issue == .appleIncomplete ? Color.secondary : CYColor.dangerText)
                    .accessibilityIdentifier("auth.channels.error")
                }
            }
        }
    }

    /// Phone entry, split out of `loginForm(_:)` so the form type-checks in time. `prominent` only when phone is the
    /// first method on the screen (P33: one primary action).
    @ViewBuilder private func phoneEntrySection(prominent: Bool) -> some View {
        // Phone in both markets (+86 / +1, default from the market). The US page appears once the deployment
        // verified `.internationalPhone`, otherwise nothing renders.
        if session.supportsPhoneSignIn {
            Section {
                Button {
                    session.weChatAuth.cancel(); password=""; path.append(.phone)
#if DEBUG
                    recordIntegratedLoginPhase("other_action")
#endif
                } label: {
                    Label("auth.channels.phoneTitle", systemImage: "iphone")
                        .frame(maxWidth: .infinity)
                }
                .modifier(LoginOtherChannelsStyle(prominent: prominent && !showsPasswordForm))
                .disabled(working || !consentGranted)
                .accessibilityIdentifier("auth.otherChannels")
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
    }

    /// P33 (audit P0-5): China leads with WeChat (only when installed and configured), then phone +86, then Sign in with
    /// Apple; the US leads with Sign in with Apple, then phone +1. Equal-width 50 pt buttons, one primary action, terms in
    /// the footnote. No Alipay sign-in (Alipay is payment only). Gated channels render nothing (P27).
    @ViewBuilder private func signInChannelSections(_ model: AuthChannelModel) -> some View {
        if session.operationalMarket == .china {
            if consentGranted {
                WeChatAppAuthSection(coordinator: session.weChatAuth, context: session.authChannelSnapshot)
            }
            phoneEntrySection(prominent: !weChatLeads)
            appleSignInSection(model)
        } else {
            appleSignInSection(model)
            phoneEntrySection(prominent: !(consentGranted && model.coordinator.appleConfigurationVerified))
        }
    }

    /// The WeChat button is on screen (it is then the first method and the primary action).
    private var weChatLeads: Bool {
        consentGranted && (session.weChatAuth.isOffered || session.weChatAuth.isWorking)
    }

    /// The sign-in form, split out of `stack(_:)` so each part type-checks in time.
    private func loginForm(_ model: AuthChannelModel) -> some View {
        Form {
            loginHeaderSection
            if !consentGranted {
                // Asked here only when the launch agreement was declined (P-008: consent is asked once).
                UsageConsentSignInRequirement(market: session.operationalMarket, granted: $consentGranted)
            }
            signInChannelSections(model)
            if showsPasswordForm {
                Section {
                    TextField("auth.username",text:$username)
                        .textContentType(.username).textInputAutocapitalization(.never)
                        .autocorrectionDisabled().submitLabel(.next)
                        .focused($focusedField,equals:.username)
                        .onSubmit { focusedField = .password }
                    SecureField("auth.password",text:$password)
                        .textContentType(.password).submitLabel(.go)
                        .focused($focusedField,equals:.password)
                        .onSubmit { submit() }
                } footer: {
                    // Validation sits in the section footer (native r2 inputs rule).
                    if let key = shownErrorKey {
                        Label { Text(LocalizedStringKey(key)) } icon: { Image(systemName: "exclamationmark.circle.fill") }
                            .foregroundStyle(CYColor.dangerText).accessibilityIdentifier("auth.error")
                    }
                }
                Section {
                    Button { submit() } label: {
                        HStack(spacing: 8) {
                            if working { ProgressView() }
                            Text(working ? "auth.phone.verifying" : "auth.signIn")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!showsPasswordForm || working || username.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || password.isEmpty)
                    .accessibilityIdentifier("auth.signIn")
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            if !showsPasswordForm, let key = shownErrorKey {
                Section {
                    Label { Text(LocalizedStringKey(key)) } icon: { Image(systemName: "exclamationmark.circle.fill") }
                        .foregroundStyle(CYColor.dangerText).accessibilityIdentifier("auth.error")
                }
            }
            SessionRestorationRetrySection(session: session)
            // P-009: the legal note scrolls with the form (no pinned bar to overlap at accessibility sizes).
            // P-008: the "by signing in you agree" sentence only while the agreement is not yet on record.
            Section {} footer: { legalFooter }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder private func loginDestination(_ route: LoginRoute, model: AuthChannelModel) -> some View {
        switch route {
        case .phone:
            AuthChannelView(embeddedModel: model, sessionSnapshot: session.authChannelSnapshot,
                            domesticPhoneVisible: session.supportsPhoneSignIn)
#if DEBUG
                .onAppear { recordIntegratedLoginPhase("channels_appear") }
                .onDisappear { recordIntegratedLoginPhase("channels_disappear") }
#endif
        case .legal(let type):
            legalDocument(type)
        }
    
    }

    private static func signedIn<V: Equatable>(_ old: V?, _ new: V?) -> Bool { old == nil && new != nil }
    private static func errorAppeared(_ old: String?, _ new: String?) -> Bool { new != nil }

    private func stack(_ model: AuthChannelModel) -> some View {
        NavigationStack(path: $path) {
            // Native r2: a grouped Form (Settings / Apple ID sign-in style). The brand header is the first section.
            loginForm(model)
#if DEBUG
            .onAppear { if let o = designOverride, username.isEmpty, !o.username.isEmpty { username = o.username; password = "design-stub" } }
#endif
            .navigationDestination(for: LoginRoute.self) { route in loginDestination(route, model: model) }
            .themeDomain(.player)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.confirmationAction) { LanguageSwitcher() }
                ToolbarItem(placement:.cancellationAction) {
                    Button("action.close") {
                        session.cancelPendingLogin(); model.clear(); password=""; dismiss()
                    }
                    .accessibilityIdentifier("auth.close")
                }
            }
        }
#if DEBUG
        .onChange(of: showsOtherSignIn) { _, value in recordIntegratedLoginPhase(value ? "presentation_true" : "presentation_false") }
#endif
        .sensoryFeedback(.success, trigger: session.account?.id, condition: Self.signedIn)
        .sensoryFeedback(.warning, trigger: session.errorKey, condition: Self.errorAppeared)
        .interactiveDismissDisabled(session.isWorking)
        .onChange(of:session.account?.id) { _,newID in if newID != nil { password=""; model.clear(); dismiss() } }
        .onDisappear { password=""; model.clear(); session.weChatAuth.cancel() }
    }

    private func appleButton(_ model: AuthChannelModel) -> some View {
        VStack(spacing: 8) {
            AuthChannelAppleButton(model: model)
                .id(colorScheme)
                .frame(minHeight: 50)
                .accessibilityIdentifier("auth.channels.appleSignIn")
            if model.state.work == .appleAuthorization || model.state.work == .appleExchange {
                ProgressView("auth.channels.appleWorking")
            }
        }
    }

    @ViewBuilder private var legalFooter: some View {
        VStack(spacing: 4) {
            if !consentGranted {
                Text("auth.channels.legalConsent").multilineTextAlignment(.center)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { agreementLink; privacyLink }
                VStack(spacing: 4) { agreementLink; privacyLink }
            }
            .buttonStyle(.borderless)
            .font(.footnote.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
    }

    private var agreementLink: some View {
        Button("auth.channels.userAgreement") { path.append(.legal(.userAgreement)) }
            .frame(minHeight: 44)
            .accessibilityIdentifier("auth.legal.agreement")
    }

    private var privacyLink: some View {
        Button("auth.channels.privacyPolicy") { path.append(.legal(.privacyPolicy)) }
            .frame(minHeight: 44)
            .accessibilityIdentifier("auth.legal.privacy")
    }

#if DEBUG
    private func recordIntegratedLoginPhase(_ phase: String) {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("--uitesting-integrated-login-diagnostics"),
              let index = args.firstIndex(of: "--uitesting-integrated-native"),
              args.indices.contains(index + 1), args[index + 1] == "denied",
              ["other_action", "channels_appear", "channels_disappear", "presentation_true", "presentation_false"].contains(phase) else { return }
        print("INTEGRATED_LOGIN_FIXTURE phase=" + phase)
    }
#endif
    /// A legal document pushed inside the sign-in sheet (it used to be a third stacked sheet).
    @ViewBuilder private func legalDocument(_ type: SettingsLegalType) -> some View {
        if type == .privacyPolicy { PrivacyProtectionView(market: session.operationalMarket, legalReader: session.legalReader, signedIn: session.account != nil) }
        else { SettingsLegalDocumentView(type: type, market: session.operationalMarket, reader: session.legalReader) }
    }
    /// Brand mark, once. `images/d_logo.png` is the same mark at a smaller size (not a wordmark), so stacking it
    /// under `cy_logo_mark` drew the logo twice (sweep login-player). The title below carries the words.
    private var brandMark: some View {
        MPAsset.BrandLogo.cyLogoMark
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 56, height: 56)
            .foregroundStyle(.primary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: AppLanguage.interfaceIsChinese(locale) ? "城瘾" : "Chein"))
    }

    private func submit() {
        guard showsPasswordForm, session.canUsePassword, !session.isWorking,
              !username.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty, !password.isEmpty else { return }
        focusedField=nil
        let name=username, credential=password
        Task { await session.login(username:name,password:credential);password="" }
    }
}

/// The secondary sign-in channel button: the screen's one prominent action when no password form is shown.
private struct LoginOtherChannelsStyle: ViewModifier {
    let prominent: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if prominent {
            content.buttonStyle(.borderedProminent).controlSize(.large)
        } else {
            content.buttonStyle(.bordered).controlSize(.large)
        }
    }
}

/// Where the sign-in sheet's navigation stack can go.
private enum LoginRoute: Hashable {
    case phone
    case legal(SettingsLegalType)
}

/// Owns the sign-in sheet's one `AuthChannelModel` for the sheet's lifetime and redraws on its changes.
@MainActor
private struct LoginAuthChannelHost<Content: View>: View {
    @StateObject private var model: AuthChannelModel
    private let content: @MainActor (AuthChannelModel) -> Content

    init(coordinator: AuthChannelCoordinator, @ViewBuilder content: @escaping @MainActor (AuthChannelModel) -> Content) {
        _model = StateObject(wrappedValue: AuthChannelModel(coordinator: coordinator))
        self.content = content
    }

    var body: some View { content(model) }
}
