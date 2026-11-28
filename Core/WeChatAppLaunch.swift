import Foundation

/// P0-5 (audit 11-28): WeChat app sign-in in Release. The owner's WeChat Open Platform AppID and Universal Link are
/// build settings (`QUESTIFY_WECHAT_APP_ID`, `QUESTIFY_WECHAT_UNIVERSAL_LINK`, docs/release/owner-values.md) that
/// Config/Info.plist copies into the bundle. Nothing here is a secret: the AppSecret stays on the backend
/// (`app.wechat.app.appsecret`, ApiLoginController.loginWechatApp).
public enum WeChatAppLaunch {
    public static let appIDInfoKey = "QuestifyWeChatAppID"
    public static let universalLinkInfoKey = "QuestifyWeChatUniversalLink"
    /// The SDK's callback hosts. `wx<AppID>://oauth?code=…&state=…` (URL scheme) and
    /// `<Universal Link><AppID>/oauth?code=…&state=…` (Universal Link) both carry the SendAuth response.
    public static let authCallbackHosts = ["oauth"]

    /// A configuration only when the AppID and the Universal Link are real values. The xcconfig placeholder
    /// (`chein-wechat-unset`) and an empty value give nil, so the WeChat button never renders.
    public static func configuration(appID rawAppID: String?, universalLink rawLink: String?,
                                     callbackHosts: [String] = authCallbackHosts) -> WeChatSDKConfiguration? {
        let appID = (rawAppID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let linkText = (rawLink ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard appID.hasPrefix("wx"), !linkText.isEmpty, let link = URL(string: linkText),
              let components = URLComponents(url: link, resolvingAgainstBaseURL: false),
              let host = components.host?.lowercased(), !host.isEmpty, !callbackHosts.isEmpty else { return nil }
        let base = components.percentEncodedPath
        var schemeRoutes: [WeChatSDKCallbackEndpoint] = []
        var linkRoutes: [WeChatSDKCallbackEndpoint] = []
        for callback in callbackHosts {
            schemeRoutes.append(WeChatSDKCallbackEndpoint(host: callback, path: ""))
            schemeRoutes.append(WeChatSDKCallbackEndpoint(host: callback, path: "/"))
            linkRoutes.append(WeChatSDKCallbackEndpoint(host: host, path: base + appID + "/" + callback))
            linkRoutes.append(WeChatSDKCallbackEndpoint(host: host, path: base + appID + "/" + callback + "/"))
        }
        return try? WeChatSDKConfiguration(appID: appID, universalLink: link,
                                           urlCallbacks: schemeRoutes, universalLinkCallbacks: linkRoutes)
    }

    public static func bundleConfiguration(_ bundle: Bundle = .main) -> WeChatSDKConfiguration? {
        configuration(appID: bundle.object(forInfoDictionaryKey: appIDInfoKey) as? String,
                      universalLink: bundle.object(forInfoDictionaryKey: universalLinkInfoKey) as? String)
    }

    /// The release gate. Each flag is a fact the host checks at the moment of use, never a constant:
    /// the official SDK is linked, the owner configuration is valid, the reviewed China legal catalog and
    /// Sign in with Apple are live (App Store 4.8 alternative), and the exchange service is wired.
    public static func gate(sdkLinked: Bool, configured: Bool, legalCatalog: Bool,
                            appleAlternative: Bool, exchangeWired: Bool) -> WeChatAppAuthGate {
        var gate = WeChatAppAuthGate()
        gate.sdkVerified = sdkLinked
        gate.providerVerified = configured
        gate.legalVerified = legalCatalog
        gate.appleAlternativeVerified = appleAlternative
        gate.liveExchangeApproved = exchangeWired
        return gate
    }
}
