import SwiftUI

/// Standalone native sheet. The caller owns the coordinator/session bridge and legal
/// document navigation. Missing legal release content is visible, never a hidden code
/// switch that disables all phone functionality. No live endpoint is provided here.
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

    init(coordinator: AuthChannelCoordinator, sessionSnapshot: AuthChannelSessionSnapshot,
         domesticPhoneVisible:Bool=true, legalReleaseContentVerified: Bool = false,
         onOpenAgreement: (() -> Void)? = nil, onOpenPrivacy: (() -> Void)? = nil) {
        _model = StateObject(wrappedValue: AuthChannelModel(coordinator: coordinator))
        self.sessionSnapshot = sessionSnapshot
        self.domesticPhoneVisible=domesticPhoneVisible
        self.legalReleaseContentVerified = legalReleaseContentVerified
        self.onOpenAgreement = onOpenAgreement; self.onOpenPrivacy = onOpenPrivacy
    }
    var body: some View {
        NavigationStack {
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
                notConfigured: !model.coordinator.isConfigured, showsApple: model.coordinator.appleConfigurationVerified,
                signedIn: model.state.signedIn,
                onSend: { model.sendCode() }, onSignIn: { model.signIn() },
                onAgreement: onOpenAgreement, onPrivacy: onOpenPrivacy
            ) {
                VStack(spacing: CYSpacing.sm) {
                    AuthChannelAppleButton(model: model)
                        .id(colorScheme)
                        .frame(minHeight: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                        .accessibilityIdentifier("auth.channels.appleSignIn")
                    if model.state.work == .appleAuthorization || model.state.work == .appleExchange {
                        ProgressView("auth.channels.appleWorking")
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.close") { model.clear(); dismiss() }
                }
            }
            .onChange(of: model.phone) { _, _ in model.phoneChanged() }
            .onChange(of: model.state.signedIn) { _, signedIn in
                if signedIn { model.clear(); dismiss() }
            }
            .onChange(of: sessionSnapshot) { _, _ in model.clear(); dismiss() }
            .onDisappear { model.clear() }
        }
        .cyDomainScreen(.player)
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
    @ViewBuilder var apple: () -> AppleContent
    @FocusState private var focus: Field?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var shakes = 0
    private enum Field { case phone, code }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.xl) {
                header
                if phoneEnabled {
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        phoneField
                        if smsSent || !code.isEmpty || issueKey != nil { codeSection }
                    }
                    status
                    primary
                    if showsApple { appleBlock }
                } else {
                    Text("region.usLoginPending").foregroundStyle(CYColor.textSecondary).accessibilityIdentifier("region.auth.pending")
                    status
                }
                if notConfigured {
                    Label("auth.notConfigured", systemImage: "info.circle").cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                }
                legalFootnote
            }
            .padding(.horizontal, CYSpacing.pageHorizontal).padding(.bottom, CYSpacing.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollContentBackground(.hidden)
        .background(alignment: .top) { AuthArtBackdrop(height: 300) }
        .background(CYColor.bgPage)
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

    private var header: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Image(systemName: "message.badge.filled.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(CYColor.actionPrimaryFg, CYColor.actionPrimaryBg)
                .cyText(.display)
                .frame(width: 56, height: 56)
                .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous).strokeBorder(CYColor.textPrimary.opacity(0.12), lineWidth: 1))
                .padding(.top, CYSpacing.xl).accessibilityHidden(true)
            Text("auth.channels.phoneTitle")
                .cyText(.dataXL).foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
            Text("auth.phone.subtitle")
                .cyText(.body).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var countryChip: some View {
        HStack(spacing: CYSpacing.xs) {
            Text(verbatim: "🇨🇳").cyText(.sectionTitle)
            Text(verbatim: "+86").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary).fixedSize()
        }
        .padding(.horizontal, CYSpacing.md).frame(minHeight: 40)
        .background(CYColor.bgRaised, in: Capsule())
        .accessibilityElement(children: .ignore).accessibilityLabel(Text("auth.phone.country"))
    }

    private var phoneInput: some View {
        TextField("auth.channels.phone", text: $phone)
            .font(.system(.title3, design: .rounded).monospacedDigit())
            .keyboardType(.phonePad).textContentType(.telephoneNumber)
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .focused($focus, equals: .phone)
            .disabled(locked)
            .accessibilityIdentifier("auth.channels.phone")
    }

    /// Chip + number on one card; the code button sits under it (trailing) so the number never truncates.
    /// At accessibility sizes the chip stacks above the number.
    private var phoneField: some View {
        VStack(alignment: .trailing, spacing: CYSpacing.xs) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: CYSpacing.sm) { countryChip; phoneInput }
                } else {
                    HStack(spacing: CYSpacing.md) { countryChip; phoneInput }
                }
            }
            .padding(.horizontal, CYSpacing.md).padding(.vertical, CYSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous).strokeBorder(focus == .phone ? CYColor.brand : CYColor.textPrimary.opacity(0.08), lineWidth: focus == .phone ? 2 : 1))
            sendButton
        }
    }

    private var sendButton: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            Button { focus = nil; onSend() } label: {
                HStack(spacing: CYSpacing.xs) {
                    if isSending { ProgressView().controlSize(.small) }
                    if cooldown > 0 { Text("auth.phone.resendIn \(cooldown)").monospacedDigit() }
                    else { Text(hasSentBefore ? "auth.channels.resendCode" : "auth.channels.sendCode") }
                }
                .cyText(.bodyMedium).cyWrapText()
                .padding(.horizontal, CYSpacing.lg).frame(minHeight: 44)
                .background(canSend ? CYColor.brandSoft : CYColor.bgRaised, in: Capsule())
            }
            .foregroundStyle(canSend ? CYColor.brand : CYColor.textSecondary)
            .disabled(!canSend)
            .accessibilityIdentifier("auth.channels.sendCode")
        }
    }

    private var codeSection: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text("auth.phone.codeHint").cyText(.bodyMedium).foregroundStyle(CYColor.textSecondary)
            codeBoxes
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var hasError: Bool { issueKey != nil && !issueIsSoft }

    private var codeBoxes: some View {
        let reduced = reduceMotion
        return ZStack {
            TextField("auth.channels.code", text: $code)
                .keyboardType(.numberPad).textContentType(.oneTimeCode)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused($focus, equals: .code)
                .disabled(locked)
                .opacity(0.02)
                .accessibilityIdentifier("auth.channels.code")
            HStack(spacing: CYSpacing.sm) {
                ForEach(0..<6, id: \.self) { i in
                    let chars = Array(code)
                    let active = focus == .code && i == min(chars.count, 5)
                    Text(i < chars.count ? String(chars[i]) : (active ? "" : " "))
                        .cyText(.dataXL)
                        .foregroundStyle(CYColor.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous)
                            .strokeBorder(hasError ? CYColor.dangerText : (active ? CYColor.brand : (i < chars.count ? CYColor.textPrimary.opacity(0.3) : CYColor.textPrimary.opacity(0.08))), lineWidth: active || hasError ? 2 : 1))
                        .scaleEffect(i < chars.count && !reduceMotion ? 1 : 0.98)
                        .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.6), value: chars.count)
                }
            }
            .keyframeAnimator(initialValue: 0.0, trigger: shakes) { view, x in view.offset(x: reduced ? 0 : x) } keyframes: { _ in
                KeyframeTrack { CubicKeyframe(10, duration: 0.06); CubicKeyframe(-10, duration: 0.08); CubicKeyframe(6, duration: 0.07); CubicKeyframe(0, duration: 0.06) }
            }
            .allowsHitTesting(false).accessibilityHidden(true)
        }
        .contentShape(Rectangle()).onTapGesture { focus = .code }
        .sensoryFeedback(.selection, trigger: code)
    }

    @ViewBuilder private var status: some View {
        if let issueKey {
            Label { Text(LocalizedStringKey(issueKey)) } icon: { Image(systemName: issueIsSoft ? "info.circle" : "exclamationmark.circle.fill") }
                .font(.footnote.weight(.medium))
                .foregroundStyle(issueIsSoft ? CYColor.textSecondary : CYColor.dangerText)
                .accessibilityIdentifier("auth.channels.error")
            if requiresAppUpdate {
                Text("auth.channels.upgradeRequired").cyText(.bodyCompact).foregroundStyle(CYColor.dangerText)
                    .accessibilityIdentifier("auth.channels.upgradeRequired")
            }
        } else if smsSent {
            Label("auth.channels.smsSent", systemImage: "checkmark.circle.fill").cyText(.bodyMedium).foregroundStyle(CYColor.textSecondary)
        }
    }

    private var primary: some View {
        Button { focus = nil; onSignIn() } label: {
            HStack(spacing: CYSpacing.sm) {
                if isSigningIn { ProgressView().tint(CYColor.textOnAccent) }
                Text(isSigningIn ? "auth.phone.verifying" : "auth.signIn")
            }
        }
        .buttonStyle(.cyPrimary)
        .disabled(!canStart || !validPhone || !validCode || isSigningIn)
        .accessibilityIdentifier("auth.channels.phoneSignIn")
    }

    @ViewBuilder private var appleBlock: some View {
        HStack(spacing: CYSpacing.md) {
            Rectangle().fill(CYColor.textPrimary.opacity(0.12)).frame(height: 1)
            Text("auth.phone.or").cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
            Rectangle().fill(CYColor.textPrimary.opacity(0.12)).frame(height: 1)
        }
        .accessibilityHidden(true)
        apple()
    }

    private var legalFootnote: some View {
        VStack(spacing: CYSpacing.xs) {
            Text("auth.channels.legalConsent").cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary).multilineTextAlignment(.center)
            HStack(spacing: CYSpacing.lg) {
                Button("auth.channels.userAgreement") { focus = nil; onAgreement?() }.disabled(onAgreement == nil)
                Button("auth.channels.privacyPolicy") { focus = nil; onPrivacy?() }.disabled(onPrivacy == nil)
            }
            .cyText(.bodyMedium).frame(minHeight: 44)
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

/// Full-bleed art behind the first screens: the Welcome cover art, blurred and faded into the page,
/// so Login and phone sign-in read as the same place as Welcome. Decorative.
struct AuthArtBackdrop: View {
    var height: CGFloat = 320
    var body: some View {
        ZStack {
            CYCoverArt(seed: "welcome-fog-map", symbol: "map", showsDebugLabel: false, showsGlyph: false)
                .blur(radius: 36).saturation(1.2).opacity(0.5)
            LinearGradient(colors: [.clear, CYColor.bgPage], startPoint: .center, endPoint: .bottom)
        }
        .frame(height: height).frame(maxWidth: .infinity).clipped()
        .ignoresSafeArea(edges: .top)
        .accessibilityHidden(true)
    }
}
