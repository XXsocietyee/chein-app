import Foundation

/// fix/1128-cn-pay P0-2: the WeChat Open Platform APP-pay identity comes from build settings
/// (`Config/China.xcconfig` → `Config/Info.plist`), never from code. Owner values: the Open Platform AppID,
/// the Universal Link (`https://www.chengyinhub.com/app/`) and the WeChat Pay merchant ID (`mch_id`, the
/// `partnerId` the backend returns in `payParams`). Any empty, unexpanded or malformed value yields nil,
/// so the session keeps WeChat Pay off instead of guessing.
public enum WeChatPaymentBuildSettings {
    public static let appIDKey = "QuestifyWeChatAppID"
    public static let universalLinkKey = "QuestifyWeChatUniversalLink"
    public static let merchantIDKey = "QuestifyWeChatPayMerchantID"

    /// SDK return over the URL scheme: `wx<AppID>://pay/?returnKey=…&ret=…`.
    public static var urlCallback: WeChatSDKCallbackEndpoint { WeChatSDKCallbackEndpoint(host: "pay", path: "/") }

    /// SDK return over the Universal Link: `<universalLink><AppID>/pay/?…`.
    public static func universalLinkCallback(appID: String, universalLink: URL) -> WeChatSDKCallbackEndpoint? {
        guard let host = universalLink.host?.lowercased(), !host.isEmpty else { return nil }
        var base = URLComponents(url: universalLink, resolvingAgainstBaseURL: false)?.percentEncodedPath ?? ""
        if !base.hasSuffix("/") { base += "/" }
        return WeChatSDKCallbackEndpoint(host: host, path: base + appID + "/pay/")
    }

    /// Parses the three Info.plist values. Merchant IDs may be a comma-separated list of digits.
    public static func configuration(info: [String: Any]?) -> WeChatSDKPaymentConfiguration? {
        guard let info,
              let appID = text(info[appIDKey]),
              let linkText = text(info[universalLinkKey]), let link = URL(string: linkText),
              let merchantText = text(info[merchantIDKey]) else { return nil }
        let merchants = Set(merchantText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
        guard !merchants.isEmpty,
              let universal = universalLinkCallback(appID: appID, universalLink: link),
              let sdk = try? WeChatSDKConfiguration(appID: appID, universalLink: link,
                                                    urlCallbacks: [urlCallback],
                                                    universalLinkCallbacks: [universal]) else { return nil }
        return try? WeChatSDKPaymentConfiguration(sdk: sdk, merchantIDs: merchants)
    }

    /// The running app's values (nil until the owner fills `Config/China.xcconfig`).
    public static var current: WeChatSDKPaymentConfiguration? {
        configuration(info: Bundle.main.infoDictionary)
    }

    private static func text(_ raw: Any?) -> String? {
        guard let value = (raw as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty, !value.contains("$(") else { return nil }
        return value
    }
}
