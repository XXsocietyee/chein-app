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
            // Native r2: a grouped Form (Settings / Apple ID sign-in style). The brand header is the first section.
            Form {
                Section {
                    VStack(spacing: 12) {
                        brandMark
                        Text("auth.login.headline").font(.title.bold())
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                        Text("auth.login.subtitle").font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
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
                                .foregroundStyle(.red).accessibilityIdentifier("auth.error")
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
                } else if session.operationalMarket != .china {
                    Section {
                        Text("region.usLoginPending").foregroundStyle(.secondary).accessibilityIdentifier("region.auth.pending")
                    }
                }
                if !session.isConfigured {
                    Section {
                        Label("auth.notConfigured",systemImage:"info.circle").foregroundStyle(.secondary)
                    }
                }
                if !showsPasswordForm, let key = shownErrorKey {
                    Section {
                        Label { Text(LocalizedStringKey(key)) } icon: { Image(systemName: "exclamationmark.circle.fill") }
                            .foregroundStyle(.red).accessibilityIdentifier("auth.error")
                    }
                }
                SessionRestorationRetrySection(session: session)
                if !consentGranted {
                    UsageConsentSignInRequirement(market: session.operationalMarket, granted: $consentGranted)
                }
                if session.operationalMarket == .china && consentGranted {
                    WeChatAppAuthSection(coordinator: session.weChatAuth, context: session.authChannelSnapshot)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button { session.weChatAuth.cancel(); password="";showsOtherSignIn=true
#if DEBUG
                        recordIntegratedLoginPhase("other_action")
#endif
                    } label: {
                        Label(LocalizedStringKey(session.operationalMarket == .china ? "auth.channels.phoneTitle" : "auth.channels.title"), systemImage: "iphone")
                            .frame(maxWidth: .infinity)
                    }
                    .modifier(LoginOtherChannelsStyle(prominent: !showsPasswordForm))
                    .disabled(working || !consentGranted)
                    .accessibilityIdentifier("auth.otherChannels")
                    VStack(spacing: 0) {
                        Text("auth.channels.legalConsent").font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        HStack(spacing: 16) {
                            Button("auth.channels.userAgreement") { rootLegal = AuthEntryLegalSheet(type: .userAgreement) }
                            Button("auth.channels.privacyPolicy") { rootLegal = AuthEntryLegalSheet(type: .privacyPolicy) }
                        }
                        .buttonStyle(.borderless)
                        .font(.footnote.weight(.semibold)).frame(minHeight: 44)
                    }
                }
                .padding(.horizontal).padding(.top, 12)
                .background(.bar)
            }
#if DEBUG
            .onAppear { if let o = designOverride, username.isEmpty, !o.username.isEmpty { username = o.username; password = "design-stub" } }
#endif
            .sheet(item: $rootLegal) { sheet in legalNavigation(sheet) { rootLegal = nil } }
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
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    /// Brand mark and wordmark. Both source files are near-black, so they template to the primary text colour.
    private var brandMark: some View {
        VStack(spacing: 12) {
            MPAsset.BrandLogo.cyLogoMark
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
            MPAsset.BrandLogo.dLogo
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(height: 36)
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "城瘾"))
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
