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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CYSpacing.lg) {
                    Image(systemName: "mappin.and.ellipse").font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(CYColor.textPrimary).padding(.top, CYSpacing.xl).accessibilityHidden(true)
                    Text("auth.title").font(.system(.largeTitle, weight: .semibold)).foregroundStyle(CYColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    if session.canUsePassword {
                        VStack(alignment: .leading, spacing: CYSpacing.md) {
                            Text("auth.existingAccount").font(.footnote.weight(.semibold)).foregroundStyle(CYColor.textSecondary)
                            VStack(spacing: 0) {
                                TextField("auth.username",text:$username)
                                    .textContentType(.username).textInputAutocapitalization(.never)
                                    .autocorrectionDisabled().submitLabel(.next)
                                    .focused($focusedField,equals:.username)
                                    .onSubmit { focusedField = .password }
                                    .frame(minHeight: 52)
                                Divider().overlay(CYColor.textPrimary.opacity(0.1))
                                SecureField("auth.password",text:$password)
                                    .textContentType(.password).submitLabel(.go)
                                    .focused($focusedField,equals:.password)
                                    .onSubmit { submit() }
                                    .frame(minHeight: 52)
                            }
                            .padding(.horizontal, CYSpacing.lg)
                            .background(CYColor.bgRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            Button { submit() } label: {
                                HStack {
                                    Text("auth.signIn")
                                    if session.isWorking { ProgressView() }
                                }
                            }
                            .buttonStyle(.cyPrimary)
                            .disabled(!session.canUsePassword || session.isWorking || username.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || password.isEmpty)
                            .accessibilityIdentifier("auth.signIn")
                        }
                    } else if session.operationalMarket != .china { Text("region.usLoginPending").foregroundStyle(CYColor.textSecondary).accessibilityIdentifier("region.auth.pending") }
                    if !session.isConfigured {
                        Label("auth.notConfigured",systemImage:"info.circle").font(.footnote).foregroundStyle(CYColor.textSecondary)
                    }
                    if let key=session.errorKey {
                        Label { Text(LocalizedStringKey(key)) } icon: { Image(systemName: "exclamationmark.circle") }.font(.footnote).foregroundStyle(CYColor.dangerText).accessibilityIdentifier("auth.error")
                    }
                    SessionRestorationRetrySection(session: session)
                    if !consentGranted {
                        UsageConsentSignInRequirement(market: session.operationalMarket, granted: $consentGranted)
                    }
                    if session.operationalMarket == .china && consentGranted {
                        WeChatAppAuthSection(coordinator: session.weChatAuth, context: session.authChannelSnapshot)
                    }
                    Button(LocalizedStringKey(session.operationalMarket == .china ? "auth.channels.phoneTitle" : "auth.channels.title")) { session.weChatAuth.cancel(); password="";showsOtherSignIn=true
#if DEBUG
                        recordIntegratedLoginPhase("other_action")
#endif
                    }
                    .buttonStyle(.cyPrimary)
                    .disabled(session.isWorking || !consentGranted)
                    .accessibilityIdentifier("auth.otherChannels")
                }
                .padding(.horizontal, CYSpacing.pageHorizontal).padding(.bottom, CYSpacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
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
                }
            }
            .sheet(isPresented:$showsOtherSignIn) {
                AuthChannelView(coordinator:session.authChannels,sessionSnapshot:session.authChannelSnapshot,domesticPhoneVisible:session.supportsDomesticPhoneInput,
                                onOpenAgreement: { legalDocument = AuthEntryLegalSheet(type: .userAgreement) },
                                onOpenPrivacy: { legalDocument = AuthEntryLegalSheet(type: .privacyPolicy) })
                    .sheet(item: $legalDocument) { sheet in
                        NavigationStack {
                            Group {
                                if sheet.type == .privacyPolicy { PrivacyProtectionView(market: session.operationalMarket, legalReader: session.legalReader) }
                                else { SettingsLegalDocumentView(type: sheet.type, market: session.operationalMarket, reader: session.legalReader) }
                            }
                            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.close") { legalDocument = nil } } }
                        }
                    }
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
    private func submit() {
        guard session.canUsePassword, !session.isWorking,
              !username.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty, !password.isEmpty else { return }
        focusedField=nil
        let name=username, credential=password
        Task { await session.login(username:name,password:credential);password="" }
    }
}
