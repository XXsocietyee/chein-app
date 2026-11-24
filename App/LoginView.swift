import SwiftUI

struct LoginView: View {
    let intent: RegistrationIntent
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var password = ""
    @State private var showsOtherSignIn=false
    @State private var consentGranted = UsageConsentEnvironment.policy.granted
    @State private var legalDocument: AuthEntryLegalSheet?
    @FocusState private var focusedField: Field?
    private enum Field { case username, password }

#if DEBUG
    /// Design fixtures only: stub values injected into the real page (no network, no session mutation).
    struct DesignOverride { var showsPassword = true; var username = ""; var errorKey: String?; var working = false }
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
    @State private var rootLegal: AuthEntryLegalSheet?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CYSpacing.lg) {
                    WelcomeHero().scaleEffect(0.9).frame(height: 262).padding(.top, CYSpacing.lg)
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        Text("auth.login.headline").cyText(.dataXL).foregroundStyle(CYColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                        Text("auth.login.subtitle").cyText(.body).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                    if showsPasswordForm {
                        VStack(alignment: .leading, spacing: CYSpacing.md) {
                            VStack(spacing: 0) {
                                loginField(icon: "person.fill") {
                                    TextField("auth.username",text:$username)
                                        .textContentType(.username).textInputAutocapitalization(.never)
                                        .autocorrectionDisabled().submitLabel(.next)
                                        .focused($focusedField,equals:.username)
                                        .onSubmit { focusedField = .password }
                                }
                                Divider().overlay(CYColor.textPrimary.opacity(0.1)).padding(.leading, 56)
                                loginField(icon: "lock.fill") {
                                    SecureField("auth.password",text:$password)
                                        .textContentType(.password).submitLabel(.go)
                                        .focused($focusedField,equals:.password)
                                        .onSubmit { submit() }
                                }
                            }
                            .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous).strokeBorder(shownErrorKey != nil ? CYColor.dangerText.opacity(0.7) : CYColor.textPrimary.opacity(0.08), lineWidth: 1))
                            if let key = shownErrorKey {
                                Label { Text(LocalizedStringKey(key)) } icon: { Image(systemName: "exclamationmark.circle.fill") }
                                    .font(.footnote.weight(.medium)).foregroundStyle(CYColor.dangerText).accessibilityIdentifier("auth.error")
                            }
                            Button { submit() } label: {
                                HStack(spacing: CYSpacing.sm) {
                                    if working { ProgressView().tint(CYColor.textOnAccent) }
                                    Text(working ? "auth.phone.verifying" : "auth.signIn")
                                }
                            }
                            .buttonStyle(.cyPrimary)
                            .disabled(!showsPasswordForm || working || username.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || password.isEmpty)
                            .accessibilityIdentifier("auth.signIn")
                        }
                    } else if session.operationalMarket != .china {
                        Text("region.usLoginPending").foregroundStyle(CYColor.textSecondary).accessibilityIdentifier("region.auth.pending")
                    }
                    if !session.isConfigured {
                        Label("auth.notConfigured",systemImage:"info.circle").cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                    }
                    if !showsPasswordForm, let key = shownErrorKey {
                        Label { Text(LocalizedStringKey(key)) } icon: { Image(systemName: "exclamationmark.circle.fill") }.font(.footnote.weight(.medium)).foregroundStyle(CYColor.dangerText).accessibilityIdentifier("auth.error")
                    }
                    SessionRestorationRetrySection(session: session)
                    if !consentGranted {
                        UsageConsentSignInRequirement(market: session.operationalMarket, granted: $consentGranted)
                    }
                    if session.operationalMarket == .china && consentGranted {
                        WeChatAppAuthSection(coordinator: session.weChatAuth, context: session.authChannelSnapshot)
                    }
                }
                .padding(.horizontal, CYSpacing.pageHorizontal).padding(.bottom, CYSpacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(alignment: .top) { AuthArtBackdrop(height: 360) }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: CYSpacing.sm) {
                    Button { session.weChatAuth.cancel(); password="";showsOtherSignIn=true
#if DEBUG
                        recordIntegratedLoginPhase("other_action")
#endif
                    } label: {
                        Label(LocalizedStringKey(session.operationalMarket == .china ? "auth.channels.phoneTitle" : "auth.channels.title"), systemImage: "iphone")
                    }
                    .buttonStyle(CYPillButtonStyle(style: showsPasswordForm ? .secondary : .primary))
                    .disabled(working || !consentGranted)
                    .accessibilityIdentifier("auth.otherChannels")
                    VStack(spacing: 0) {
                        Text("auth.channels.legalConsent").cyText(.meta).foregroundStyle(CYColor.textSecondary).multilineTextAlignment(.center)
                        HStack(spacing: CYSpacing.lg) {
                            Button("auth.channels.userAgreement") { rootLegal = AuthEntryLegalSheet(type: .userAgreement) }
                            Button("auth.channels.privacyPolicy") { rootLegal = AuthEntryLegalSheet(type: .privacyPolicy) }
                        }
                        .cyText(.meta, weight: .semibold).frame(minHeight: 44)
                    }
                }
                .padding(.horizontal, CYSpacing.pageHorizontal).padding(.top, CYSpacing.md)
                .background(.bar)
            }
#if DEBUG
            .onAppear { if let o = designOverride, username.isEmpty, !o.username.isEmpty { username = o.username; password = "design-stub" } }
#endif
            .sheet(item: $rootLegal) { sheet in legalNavigation(sheet) { rootLegal = nil } }
            .scrollContentBackground(.hidden)
            .background(CYColor.bgPage)
            .themeDomain(.player)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.confirmationAction) { LanguageSwitcher() }
                ToolbarItem(placement:.cancellationAction) {
                    Button("action.close") {
                        session.cancelPendingLogin();password="";dismiss()
                    }
                    .accessibilityIdentifier("auth.close")
                }
            }
            .sheet(isPresented:$showsOtherSignIn) {
                AuthChannelView(coordinator:session.authChannels,sessionSnapshot:session.authChannelSnapshot,domesticPhoneVisible:session.supportsDomesticPhoneInput,
                                onOpenAgreement: { legalDocument = AuthEntryLegalSheet(type: .userAgreement) },
                                onOpenPrivacy: { legalDocument = AuthEntryLegalSheet(type: .privacyPolicy) })
                    .sheet(item: $legalDocument) { sheet in legalNavigation(sheet) { legalDocument = nil } }
                    .cySheet()
#if DEBUG
                    .onAppear { recordIntegratedLoginPhase("channels_appear") }
                    .onDisappear { recordIntegratedLoginPhase("channels_disappear") }
#endif
            }
#if DEBUG
            .onChange(of: showsOtherSignIn) { _, value in recordIntegratedLoginPhase(value ? "presentation_true" : "presentation_false") }
#endif
            .interactiveDismissDisabled(session.isWorking)
            .onChange(of:session.account?.id) { _,newID in if newID != nil { password="";dismiss() } }
            .onDisappear { password=""; session.weChatAuth.cancel() }
        }
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
    private func legalNavigation(_ sheet: AuthEntryLegalSheet, close: @escaping () -> Void) -> some View {
        NavigationStack {
            Group {
                if sheet.type == .privacyPolicy { PrivacyProtectionView(market: session.operationalMarket, legalReader: session.legalReader) }
                else { SettingsLegalDocumentView(type: sheet.type, market: session.operationalMarket, reader: session.legalReader) }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.close", action: close) } }
        }
        .cySheet(detents: [.large])
    }
    private func loginField<Field: View>(icon: String, @ViewBuilder _ field: () -> Field) -> some View {
        HStack(spacing: CYSpacing.md) {
            Image(systemName: icon).font(.system(.subheadline, weight: .semibold)).foregroundStyle(CYColor.textSecondary)
                .frame(width: 28).accessibilityHidden(true)
            field()
        }
        .padding(.horizontal, CYSpacing.lg).frame(minHeight: 60)
    }
    private func submit() {
        guard showsPasswordForm, session.canUsePassword, !session.isWorking,
              !username.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty, !password.isEmpty else { return }
        focusedField=nil
        let name=username, credential=password
        Task { await session.login(username:name,password:credential);password="" }
    }
}
