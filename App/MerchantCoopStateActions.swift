import SwiftUI

// fix/r3-merchant-coop-b: shared CTAs for the merchant / coop dead-end states (MP `登录` and `申请入驻`).
// The workbench root (`MerchantHomeView`) injects both hooks; a host that does not inject them keeps the
// plain message without a button (nil hides the action, never a dead button).

private struct MerchantOpenApplicationKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

private struct MerchantOpenSignInKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// MP `openApplication` (`/pages/merchant/apply/index`): opens 商家入驻.
    var merchantOpenApplication: (() -> Void)? {
        get { self[MerchantOpenApplicationKey.self] }
        set { self[MerchantOpenApplicationKey.self] = newValue }
    }
    /// MP `goLogin`: opens the app's sign-in home.
    var merchantOpenSignIn: (() -> Void)? {
        get { self[MerchantOpenSignInKey.self] }
        set { self[MerchantOpenSignInKey.self] = newValue }
    }
}

/// Native `ContentUnavailableView` for a merchant / coop page that needs an action to leave the state.
/// `action` nil renders the message only.
struct MerchantCoopActionState: View {
    let systemImage: String
    let title: LocalizedStringKey
    var message: LocalizedStringKey? = nil
    var actionTitle: LocalizedStringKey? = nil
    var action: (() -> Void)? = nil
    var identifier: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            if let message { Text(message) }
        } actions: {
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle).frame(minHeight: CYSpacing.minTouchTarget)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(identifier + ".action")
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier(identifier)
    }
}

/// Signed-out page: `<title>` + 登录 (via the injected sign-in hook, or the root tab switch to 我的).
struct MerchantCoopSignInState: View {
    let title: LocalizedStringKey
    var identifier: String
    var signIn: (() -> Void)? = nil
    @Environment(\.merchantOpenSignIn) private var environmentSignIn
    @Environment(\.rootTabSwitch) private var rootTabSwitch

    private var resolvedSignIn: (() -> Void)? {
        if let signIn { return signIn }
        if let environmentSignIn { return environmentSignIn }
        guard rootTabSwitch.isAvailable else { return nil }
        let tabSwitch = rootTabSwitch
        return { tabSwitch(.mine) }
    }

    var body: some View {
        MerchantCoopActionState(systemImage: "person.crop.circle.badge.exclamationmark", title: title,
                                actionTitle: "merchantCoop.state.signIn", action: resolvedSignIn, identifier: identifier)
    }
}

/// No merchant identity: `<title>` + 申请入驻 (via the injected application hook).
struct MerchantCoopApplyState: View {
    let title: LocalizedStringKey
    var message: LocalizedStringKey? = nil
    var actionTitle: LocalizedStringKey = "merchant.gate.apply"
    var identifier: String
    @Environment(\.merchantOpenApplication) private var openApplication

    var body: some View {
        MerchantCoopActionState(systemImage: "storefront", title: title, message: message,
                                actionTitle: actionTitle, action: openApplication, identifier: identifier)
    }
}

/// MP image-with-default for merchant-coop rows: an absolute https URL loads through `AsyncImage`; anything else
/// (nil, empty, site-relative) shows the MP default asset (`/images/d_profile.png` avatars, `/images/d_logo.png` logos).
struct MerchantCoopMPThumb: View {
    enum Fallback { case avatar, logo }
    let urlString: String?
    let fallback: Fallback
    var side: CGFloat = 40

    private var url: URL? {
        guard let raw = urlString?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: raw), url.scheme?.lowercased() == "https" else { return nil }
        return url
    }
    private var placeholder: Image {
        switch fallback {
        case .avatar: return MPAsset.AvatarDefault.dProfile
        case .logo: return MPAsset.BrandLogo.dLogo
        }
    }

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase { image.resizable().scaledToFill() }
                    else { placeholder.resizable().scaledToFill() }
                }
            } else {
                placeholder.resizable().scaledToFill()
            }
        }
        .frame(width: side, height: side)
        .clipShape(fallback == .avatar ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous)))
        .accessibilityHidden(true)
    }
}
