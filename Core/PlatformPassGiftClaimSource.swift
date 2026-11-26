import Foundation

/// Thin mount hook for fix-r9 member MKT-3-1 (App lane). Cursor Core owns the final contract.
///
/// MP `subpackageMember/market/gift/index.js:101-123`: `POST /api/marketing/product/gifts/claim`
/// JSON `{token, requestId}`, `requestId` = `gift_<ms>_<8>` kept for the page's lifetime.
/// The claimer sends only the gift token: there is no amount, payment, refund or payout.
/// Production-host admission stays with `ChinaReviewedRouteCapability` (Cursor Core); a refused
/// route comes back as `.failed(reasonCode: nil)`, which shows 礼品当前不可领取 as the MP's default.
public enum PlatformPassGiftClaimOutcome: Equatable, Sendable {
    /// `isBizOk(res) && res.data` → 已领取; `registrationId` opens orderinfo, else the 礼品 tab.
    case claimed(registrationID: String?)
    /// `MISSING_LINK_CODES` (`TOKEN_REQUIRED`, `GIFT_TOKEN_INVALID`) → 链接已失效 · 返回.
    case missing
    /// Any other business refusal. `reasonCode` feeds `claimReasonText`.
    case failed(reasonCode: String?)
    /// `fail:` (network). The same request id is resent on the next tap.
    case unknown
}

public struct PlatformPassGiftClaimSource {
    /// MP `MISSING_LINK_CODES` (`market/gift/index.js:10`).
    public static let missingLinkCodes: Set<String> = ["TOKEN_REQUIRED", "GIFT_TOKEN_INVALID"]

    private let configuration: APIConfiguration
    private let transport: any HTTPTransport

    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    /// MP: `'gift_' + Date.now() + '_' + Math.random().toString(36).slice(2, 10)`.
    public static func requestID(nowMillis: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
                                 entropy: String = JourneyLoopSource.randomEntropy()) -> String {
        "gift_\(nowMillis)_\(entropy)"
    }

    public func claim(giftToken: String, requestID: String, token: String) async -> PlatformPassGiftClaimOutcome {
        let gift = giftToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !gift.isEmpty else { return .missing }
        guard AuthRequestBuilder.isValidToken(token) else { return .failed(reasonCode: nil) }
        let url = configuration.baseURL.appendingPathComponent(PlatformPass.claimPath)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.httpShouldHandleCookies = false
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let fields: [String: String] = ["token": gift, "requestId": requestID]
        guard let body = try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]) else {
            return .failed(reasonCode: nil)
        }
        request.httpBody = body
        do { try ChinaReviewedRouteCapability.refuseUnwiredChinaProduction(request) }
        catch { return .failed(reasonCode: nil) }
        let data: Data
        let status: Int
        do { (data, status) = try await transport.send(request) }
        catch { return .unknown }
        return Self.outcome(status: status, body: data)
    }

    /// Classifies a reply the way `market/gift/index.js:113-120` does.
    public static func outcome(status: Int, body: Data) -> PlatformPassGiftClaimOutcome {
        let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any]
        guard let object else { return (500...599).contains(status) ? .unknown : .failed(reasonCode: nil) }
        let reason = object["reasonCode"] as? String
        if (200..<300).contains(status), bizOK(object["code"]), let payload = object["data"], !(payload is NSNull) {
            let dict = payload as? [String: Any]
            return .claimed(registrationID: idText(dict?["registrationId"]))
        }
        if let reason, missingLinkCodes.contains(reason) { return .missing }
        return .failed(reasonCode: reason)
    }

    private static func bizOK(_ value: Any?) -> Bool {
        if let text = value as? String { return text == "200" }
        if let number = value as? NSNumber, CFGetTypeID(number as CFTypeRef) != CFBooleanGetTypeID() {
            return number.intValue == 200
        }
        return false
    }

    private static func idText(_ value: Any?) -> String? {
        if let text = value as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let number = value as? NSNumber, CFGetTypeID(number as CFTypeRef) != CFBooleanGetTypeID() {
            return number.stringValue
        }
        return nil
    }
}
