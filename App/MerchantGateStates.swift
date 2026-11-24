import SwiftUI

// fix/r3-merchant-coop-a: the MP merchant pages share two full-page states (onDenyCta / onLoginCta):
// - not signed in → 登录后查看… + 登录;
// - denied → 当前身份不能查看… + 申请入驻 (no merchant identity) or 返回 (a member without the grant).
// Native form: ContentUnavailableView with one action.

/// Root-injected actions for the denied state. Without them the state offers 返回 only.
struct MerchantGateActions {
    /// True when the signed-in account already has an active merchant identity (access/me).
    var hasMerchantIdentity: @MainActor () async -> Bool
    /// The onboarding page (pages/merchant/apply).
    var applicationDestination: @MainActor () -> AnyView
}

private struct MerchantGateActionsKey: EnvironmentKey {
    static let defaultValue: MerchantGateActions? = nil
}

extension EnvironmentValues {
    var merchantGateActions: MerchantGateActions? {
        get { self[MerchantGateActionsKey.self] }
        set { self[MerchantGateActionsKey.self] = newValue }
    }
}

/// MP onDenyCta: 申请入驻 when there is no merchant identity, otherwise 返回.
struct MerchantDeniedState: View {
    let title: LocalizedStringKey
    var systemImage = "lock"
    var identifier = "merchant.gate.denied"
    @Environment(\.merchantGateActions) private var actions
    @Environment(\.dismiss) private var dismiss
    @State private var hasIdentity: Bool?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } actions: {
            if hasIdentity == false, let actions {
                NavigationLink {
                    actions.applicationDestination()
                } label: {
                    Text("merchant.gate.apply").frame(minHeight: CYSpacing.minTouchTarget)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(identifier + ".apply")
            } else if hasIdentity != nil || actions == nil {
                Button {
                    dismiss()
                } label: {
                    Text("merchant.gate.back").frame(minHeight: CYSpacing.minTouchTarget)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier(identifier + ".back")
            }
        }
        .accessibilityIdentifier(identifier)
        .task {
            guard hasIdentity == nil, let actions else { return }
            hasIdentity = await actions.hasMerchantIdentity()
        }
    }
}

/// MP onLoginCta: 登录后查看… with a 登录 button that opens the merchant sign-in sheet.
struct MerchantSignInState: View {
    let title: LocalizedStringKey
    var identifier = "merchant.gate.signIn"
    @State private var showsSignIn = false

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "person.crop.circle.badge.exclamationmark")
        } actions: {
            Button {
                showsSignIn = true
            } label: {
                Text("auth.signIn").frame(minHeight: CYSpacing.minTouchTarget)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier(identifier + ".action")
        }
        .accessibilityIdentifier(identifier)
        .sheet(isPresented: $showsSignIn) { LoginView(intent: .merchant) }
    }
}

/// MP full-page load error: a page-specific title, the server reason, and 重新加载.
struct MerchantLoadFailedState: View {
    let title: LocalizedStringKey
    var message: String? = nil
    var identifier = "merchant.gate.loadFailed"
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "exclamationmark.triangle")
        } description: {
            if let message, !message.isEmpty { Text(verbatim: message) }
        } actions: {
            Button(action: retry) {
                Text("merchant.gate.reload").frame(minHeight: CYSpacing.minTouchTarget)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier(identifier + ".retry")
        }
        .accessibilityIdentifier(identifier)
    }
}

/// MP kind="missing-param": a link without its record id — the title and 返回上一页.
struct MerchantMissingParamState: View {
    let title: LocalizedStringKey
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "link.badge.plus")
        } actions: {
            Button { dismiss() } label: {
                Text("merchant.gate.backToPrevious").frame(minHeight: CYSpacing.minTouchTarget)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("merchant.gate.missingParam.back")
        }
        .accessibilityIdentifier("merchant.gate.missingParam")
    }
}
