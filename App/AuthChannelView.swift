import SwiftUI

/// Phone sign-in. Standalone it is its own sheet with a close button. L1 P-005: `LoginView` pushes the embedded
/// variant inside its one sheet and shares its `AuthChannelModel`, so Sign in with Apple (on the first screen) and
/// the phone form are one presentation; the embedded page shows no second Apple button and no second legal note.
/// Missing legal release content is visible, never a hidden code switch that disables all phone functionality.
/// No live endpoint is provided here.
@MainActor
struct AuthChannelView: View {
    @StateObject private var model: AuthChannelModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    private let sessionSnapshot: AuthChannelSessionSnapshot
    private let onOpenAgreement: (() -> Void)?
    private let onOpenPrivacy: (() -> Void)?
    private let legalReleaseContentVerified: Bool
    private let domesticPhoneVisible:Bool
    private let embedded: Bool

    init(coordinator: AuthChannelCoordinator, sessionSnapshot: AuthChannelSessionSnapshot,
         domesticPhoneVisible:Bool=true, legalReleaseContentVerified: Bool = false,
         onOpenAgreement: (() -> Void)? = nil, onOpenPrivacy: (() -> Void)? = nil) {
        _model = StateObject(wrappedValue: AuthChannelModel(coordinator: coordinator))
        self.sessionSnapshot = sessionSnapshot
        self.domesticPhoneVisible=domesticPhoneVisible
        self.legalReleaseContentVerified = legalReleaseContentVerified
        self.onOpenAgreement = onOpenAgreement; self.onOpenPrivacy = onOpenPrivacy
        embedded = false
    }

    /// Pushed inside the sign-in sheet's navigation stack; the sheet owns `model` and clears it when it closes.
    init(embeddedModel: AuthChannelModel, sessionSnapshot: AuthChannelSessionSnapshot, domesticPhoneVisible: Bool = true) {
        _model = StateObject(wrappedValue: embeddedModel)
        self.sessionSnapshot = sessionSnapshot
        self.domesticPhoneVisible = domesticPhoneVisible
        legalReleaseContentVerified = false
        onOpenAgreement = nil; onOpenPrivacy = nil
        embedded = true
    }

    var body: some View {
        if embedded {
            form
        } else {
            NavigationStack {
                form
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("action.close") { model.clear(); dismiss() }
                        }
                    }
                    .onDisappear { model.clear() }
            }
            .cyDomainScreen(.player)
        }
    }

    private var form: some View {
        PhoneSignInForm(
            phone: $model.phone, code: $model.code,
            phoneEnabled: domesticPhoneVisible, locked: model.state.isWorking,
            smsSent: model.state.smsSent,
            issueKey: model.state.issue?.localizationKey,
            issueIsSoft: model.state.issue == .appleIncomplete,
            requiresAppUpdate: model.state.requiresAppUpdate && model.state.issue != .upgradeRequired,
            cooldown: model.coordinator.smsCooldownRemaining,
            isSending: model.state.work == .sendingSMS, isSigningIn: model.state.work == .phoneLogin,
            canStart: model.canStart, hasSentBefore: model.state.nextSMSAllowedAt != nil,
            notConfigured: !model.coordinator.isConfigured, showsApple: !embedded && model.coordinator.appleConfigurationVerified,
            signedIn: model.state.signedIn,
            onSend: { model.sendCode() }, onSignIn: { model.signIn() },
            onAgreement: onOpenAgreement, onPrivacy: onOpenPrivacy,
            showsLegalFootnote: !embedded
        ) {
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
        .onChange(of: model.phone) { _, _ in model.phoneChanged() }
        .onChange(of: model.state.signedIn) { _, signedIn in
            guard signedIn else { return }
            model.clear()
            if !embedded { dismiss() }
        }
        .onChange(of: sessionSnapshot) { _, _ in
            model.clear()
            if !embedded { dismiss() }
        }
    }
}

/// The phone sign-in page, driven only by plain values so DEBUG design fixtures can mount the real
/// layout with stub state (idle, code sent, wrong code, signing in) without a live coordinator.
/// Pattern sources: Hinge and Lugg phone step (country chip + one field), BeReal code boxes, Cal AI legal footnote.
struct PhoneSignInForm<AppleContent: View>: View {
    @Binding var phone: String
    @Binding var code: String
    var phoneEnabled = true
    var locked = false
    var smsSent = false
    var issueKey: String? = nil
    var issueIsSoft = false
    var requiresAppUpdate = false
    var cooldown = 0
    var isSending = false
    var isSigningIn = false
    var canStart = true
    var hasSentBefore = false
    var notConfigured = false
    var showsApple = false
    var signedIn = false
    var onSend: () -> Void = {}
    var onSignIn: () -> Void = {}
    var onAgreement: (() -> Void)? = nil
    var onPrivacy: (() -> Void)? = nil
    /// False when the page is pushed inside the sign-in sheet, whose first screen already carries the legal note.
    var showsLegalFootnote = true
    @ViewBuilder var apple: () -> AppleContent
    @FocusState private var focus: Field?
    @State private var shakes = 0
    private enum Field { case phone, code }

    /// Native r2: a grouped Form. Phone and code are system text fields (`.telephoneNumber`, `.oneTimeCode`);
    /// validation and status sit in the section footer; the page title is the navigation bar's.
    var body: some View {
        Form {
            if phoneEnabled {
                Section {
                    HStack {
                        Text(verbatim: "+86")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(Text("auth.phone.country"))
                        phoneInput
                    }
                    sendButton
                } header: {
                    Text("auth.phone.subtitle").textCase(nil)
                } footer: {
                    if !(smsSent || !code.isEmpty || issueKey != nil) { status }
                }
                if smsSent || !code.isEmpty || issueKey != nil {
                    Section {
                        codeField
                    } header: {
                        Text("auth.phone.codeHint").textCase(nil)
                    } footer: {
                        status
                    }
                }
                Section {
                    primary
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                if showsApple {
                    Section {
                        apple()
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    } header: {
                        Text("auth.phone.or").textCase(nil)
                    }
                }
            } else {
                Section {
                    Text("region.usLoginPending").foregroundStyle(.secondary).accessibilityIdentifier("region.auth.pending")
                } footer: {
                    status
                }
            }
            if notConfigured {
                Section {
                    Label("auth.notConfigured", systemImage: "info.circle").foregroundStyle(.secondary)
                }
            }
            if showsLegalFootnote {
                Section {} footer: { legalFootnote }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(Text("auth.channels.phoneTitle"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: code) { _, value in
            let digits = String(value.filter { $0.isASCII && $0.isNumber }.prefix(6))
            if value != digits { code = digits }
        }
        .onChange(of: phone) { _, value in
            let digits = String(value.filter { $0.isASCII && $0.isNumber }.prefix(11))
            if value != digits { phone = digits }
        }
        .onChange(of: smsSent) { _, sent in if sent { focus = .code } }
        .onChange(of: issueKey) { _, key in if key != nil, !issueIsSoft { shakes += 1 } }
        .onChange(of: code) { _, value in if value.count == 6, validPhone, canStart, !isSigningIn { focus = nil; onSignIn() } }
        .sensoryFeedback(.success, trigger: signedIn) { _, new in new }
        .sensoryFeedback(.error, trigger: shakes)
    }

    private var phoneInput: some View {
        TextField("auth.channels.phone", text: $phone)
            .monospacedDigit()
            .keyboardType(.phonePad).textContentType(.telephoneNumber)
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .submitLabel(.next)
            .focused($focus, equals: .phone)
            .disabled(locked)
            .accessibilityIdentifier("auth.channels.phone")
    }

    private var sendButton: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            Button { focus = nil; onSend() } label: {
                HStack(spacing: 6) {
                    if isSending { ProgressView() }
                    if cooldown > 0 { Text("auth.phone.resendIn \(cooldown)").monospacedDigit() }
                    else { Text(hasSentBefore ? "auth.channels.resendCode" : "auth.channels.sendCode") }
                }
            }
            .disabled(!canSend)
            .accessibilityIdentifier("auth.channels.sendCode")
        }
    }

    private var hasError: Bool { issueKey != nil && !issueIsSoft }

    private var codeField: some View {
        TextField("auth.channels.code", text: $code)
            .monospacedDigit()
            .keyboardType(.numberPad).textContentType(.oneTimeCode)
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .submitLabel(.go)
            .focused($focus, equals: .code)
            .disabled(locked)
            .accessibilityIdentifier("auth.channels.code")
            .sensoryFeedback(.selection, trigger: code)
    }

    @ViewBuilder private var status: some View {
        if let issueKey {
            Label { Text(LocalizedStringKey(issueKey)) } icon: { Image(systemName: issueIsSoft ? "info.circle" : "exclamationmark.circle.fill") }
                .foregroundStyle(issueIsSoft ? Color.secondary : Color.red)
                .accessibilityIdentifier("auth.channels.error")
            if requiresAppUpdate {
                Text("auth.channels.upgradeRequired").foregroundStyle(.red)
                    .accessibilityIdentifier("auth.channels.upgradeRequired")
            }
        } else if smsSent {
            Label("auth.channels.smsSent", systemImage: "checkmark.circle.fill")
        }
    }

    private var primary: some View {
        Button { focus = nil; onSignIn() } label: {
            HStack(spacing: 8) {
                if isSigningIn { ProgressView() }
                Text(isSigningIn ? "auth.phone.verifying" : "auth.signIn")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!canStart || !validPhone || !validCode || isSigningIn)
        .accessibilityIdentifier("auth.channels.phoneSignIn")
    }

    private var legalFootnote: some View {
        VStack(spacing: 4) {
            Text("auth.channels.legalConsent").multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Button("auth.channels.userAgreement") { focus = nil; onAgreement?() }.disabled(onAgreement == nil)
                Button("auth.channels.privacyPolicy") { focus = nil; onPrivacy?() }.disabled(onPrivacy == nil)
            }
            .buttonStyle(.borderless)
            .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity)
    }

    private var validPhone: Bool { (try? AuthChannelInput.phone(phone)) != nil }
    private var validCode: Bool { (try? AuthChannelInput.code(code)) != nil }
    private var canSend: Bool { canStart && cooldown <= 0 && validPhone && !isSending && !locked }
}

extension PhoneSignInForm where AppleContent == EmptyView {
    init(phone: Binding<String>, code: Binding<String>) {
        self.init(phone: phone, code: code, apple: { EmptyView() })
    }
}
