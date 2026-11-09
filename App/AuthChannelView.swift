import SwiftUI

/// Standalone native sheet. The caller owns the coordinator/session bridge and legal
/// document navigation. Missing legal release content is visible, never a hidden code
/// switch that disables all phone functionality. No live endpoint is provided here.
@MainActor
struct AuthChannelView: View {
    @StateObject private var model: AuthChannelModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var focus: Field?
    private enum Field { case phone, code }
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
            ScrollView {
                VStack(alignment: .leading, spacing: CYSpacing.lg) {
                    if domesticPhoneVisible {
                        phoneField
                        codeBoxes
                        resendRow
                        statusMessages
                        Button { focus = nil; model.signIn() } label: {
                            HStack {
                                Text("auth.signIn")
                                if model.state.work == .phoneLogin { ProgressView() }
                            }
                        }
                        .buttonStyle(.cyPrimary)
                        .disabled(!model.canStart || !validPhone || !validCode)
                        .accessibilityIdentifier("auth.channels.phoneSignIn")
                        .sensoryFeedback(.success, trigger: model.state.signedIn)
                    } else {
                        Text("region.usLoginPending").foregroundStyle(CYColor.textSecondary).accessibilityIdentifier("region.auth.pending")
                        statusMessages
                    }
                    if model.coordinator.appleConfigurationVerified {
                        AuthChannelAppleButton(model: model)
                            .id(colorScheme)
                            .frame(minHeight: 50)
                            .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                            .accessibilityIdentifier("auth.channels.appleSignIn")
                        if model.state.work == .appleAuthorization || model.state.work == .appleExchange {
                            ProgressView("auth.channels.appleWorking")
                        }
                    }
                    if !model.coordinator.isConfigured {
                        Label("auth.notConfigured", systemImage: "info.circle").foregroundStyle(CYColor.textSecondary)
                    }
                    legalFootnote
                }
                .padding(.horizontal, CYSpacing.pageHorizontal).padding(.vertical, CYSpacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(CYColor.bgPage)
            .appNavigationTitle("auth.channels.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.close") { model.clear(); dismiss() }
                }
            }
            .onChange(of: model.phone) { _, value in
                let digits = String(value.filter { $0.isASCII && $0.isNumber }.prefix(11))
                if value != digits { model.phone = digits }
                model.phoneChanged()
            }
            .onChange(of: model.code) { _, value in
                let digits = String(value.filter { $0.isASCII && $0.isNumber }.prefix(6))
                if value != digits { model.code = digits }
            }
            .onChange(of: model.state.signedIn) { _, signedIn in
                if signedIn { model.clear(); dismiss() }
            }
            .onChange(of: sessionSnapshot) { _, _ in model.clear(); dismiss() }
            .onDisappear { model.clear() }
        }
    }
    private var phoneField: some View {
        HStack(spacing: CYSpacing.md) {
            Text(verbatim: "+86").font(.system(.body, weight: .semibold)).foregroundStyle(CYColor.textPrimary)
                .padding(.trailing, CYSpacing.md)
                .overlay(alignment: .trailing) { Rectangle().fill(CYColor.textPrimary.opacity(0.15)).frame(width: 1, height: 24) }
                .accessibilityLabel(Text("auth.channels.phone"))
            TextField("auth.channels.phone", text: $model.phone)
                .font(.system(.title3, design: .rounded).monospacedDigit())
                .keyboardType(.phonePad).textContentType(.telephoneNumber)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused($focus, equals: .phone)
                .disabled(model.state.isWorking)
                .accessibilityIdentifier("auth.channels.phone")
        }
        .padding(.horizontal, CYSpacing.lg).frame(minHeight: 56)
        .background(CYColor.bgRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(focus == .phone ? CYColor.textPrimary.opacity(0.5) : .clear, lineWidth: 1.5))
    }
    private var codeBoxes: some View {
        ZStack {
            TextField("auth.channels.code", text: $model.code)
                .keyboardType(.numberPad).textContentType(.oneTimeCode)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused($focus, equals: .code)
                .disabled(model.state.isWorking)
                .opacity(0.02)
                .accessibilityIdentifier("auth.channels.code")
            HStack(spacing: CYSpacing.sm) {
                ForEach(0..<6, id: \.self) { i in
                    let chars = Array(model.code)
                    Text(i < chars.count ? String(chars[i]) : "")
                        .font(.system(.title2, design: .rounded, weight: .semibold).monospacedDigit())
                        .foregroundStyle(CYColor.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(CYColor.bgRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(focus == .code && i == min(chars.count, 5) ? CYColor.textPrimary.opacity(0.6) : .clear, lineWidth: 1.5))
                }
            }
            .allowsHitTesting(false).accessibilityHidden(true)
        }
        .contentShape(Rectangle()).onTapGesture { focus = .code }
        .sensoryFeedback(.selection, trigger: model.code)
    }
    private var resendRow: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            Button { focus = nil; model.sendCode() } label: {
                HStack(spacing: CYSpacing.sm) {
                    Text(smsButtonKey)
                    if model.state.work == .sendingSMS { ProgressView() }
                    else if model.coordinator.smsCooldownRemaining > 0 {
                        Text(model.coordinator.smsCooldownRemaining, format: .number)
                            .monospacedDigit().accessibilityLabel(Text("auth.channels.cooldownSeconds"))
                    }
                }
                .font(.system(.subheadline, weight: .semibold)).frame(minHeight: 44)
            }
            .disabled(!model.canStart || model.coordinator.smsCooldownRemaining > 0 || !validPhone)
            .accessibilityIdentifier("auth.channels.sendCode")
        }
    }
    @ViewBuilder private var statusMessages: some View {
        if model.state.smsSent { Label("auth.channels.smsSent", systemImage: "checkmark.circle").font(.footnote).foregroundStyle(CYColor.textSecondary) }
        if let issue = model.state.issue {
            Text(LocalizedStringKey(issue.localizationKey)).font(.footnote)
                .foregroundStyle(issue == .appleIncomplete ? CYColor.textSecondary : CYColor.dangerText)
                .accessibilityIdentifier("auth.channels.error")
            if model.state.requiresAppUpdate && issue != .upgradeRequired {
                Text("auth.channels.upgradeRequired").font(.footnote).foregroundStyle(CYColor.dangerText)
                    .accessibilityIdentifier("auth.channels.upgradeRequired")
            }
        }
    }
    private var legalFootnote: some View {
        VStack(spacing: CYSpacing.xs) {
            Text("auth.channels.legalConsent").font(.footnote).foregroundStyle(CYColor.textSecondary).multilineTextAlignment(.center)
            HStack(spacing: CYSpacing.lg) {
                Button("auth.channels.userAgreement") { focus = nil; onOpenAgreement?() }.disabled(onOpenAgreement == nil)
                Button("auth.channels.privacyPolicy") { focus = nil; onOpenPrivacy?() }.disabled(onOpenPrivacy == nil)
            }
            .font(.footnote.weight(.semibold)).frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity)
    }
    private var validPhone: Bool { (try? AuthChannelInput.phone(model.phone)) != nil }
    private var validCode: Bool { (try? AuthChannelInput.code(model.code)) != nil }
    private var smsButtonKey: LocalizedStringKey {
        if model.state.work == .sendingSMS { return "auth.channels.sendingCode" }
        if model.state.nextSMSAllowedAt != nil { return "auth.channels.resendCode" }
        return "auth.channels.sendCode"
    }
}
