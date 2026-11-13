import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Exact requests emitted by `NearbyTeamHTTPWriteAdapter` for apply, withdraw and handle (`NearbyTeamRequest.action`:
/// sorted-key JSON, `teamId` / `memberId` positive, `approved` a JSON boolean). `kick`, `quit`, `disband` and the
/// other team mutations are not matched.
enum ReviewedNearbyTeamWriteRoute {
    static let approvalPaths: Set<String> = ["api/team/apply", "api/team/withdraw", "api/team/handle"]

    static func accepts(_ request: URLRequest, baseURL: URL, token: String?) -> Bool {
        guard let token, AuthRequestBuilder.isValidToken(token),
              request.httpMethod == "POST", request.httpBodyStream == nil,
              request.value(forHTTPHeaderField: "Authorization")?.utf8.elementsEqual(token.utf8) == true,
              request.value(forHTTPHeaderField: "Accept") == "application/json",
              request.value(forHTTPHeaderField: "Content-Type") == "application/json",
              request.value(forHTTPHeaderField: "Cookie") == nil,
              request.value(forHTTPHeaderField: "Proxy-Authorization") == nil,
              let url = request.url, url.fragment == nil,
              url.scheme == baseURL.scheme, url.host == baseURL.host, url.port == baseURL.port,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.user == nil, parts.password == nil, parts.query == nil,
              let body = request.httpBody, body.count <= 96,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let teamID = object["teamId"] as? Int, teamID > 0 else { return false }
        func exactPath(_ path: String) -> Bool { parts.path == baseURL.appendingPathComponent(path).path }
        func canonical(_ value: [String: Any]) -> Bool {
            (try? JSONSerialization.data(withJSONObject: value, options: .sortedKeys)) == body
        }
        if exactPath("api/team/apply") || exactPath("api/team/withdraw") {
            return object.count == 1 && canonical(["teamId": teamID])
        }
        guard exactPath("api/team/handle"), object.count == 3,
              let memberID = object["memberId"] as? Int, memberID > 0,
              let approved = object["approved"] as? Bool else { return false }
        return canonical(["teamId": teamID, "memberId": memberID, "approved": approved])
    }
}

/// Anonymous receiver-side read of a shared footprint: exactly `RoamShareToken.request` (GET, one lowercase-hex `token`
/// query item, no Authorization, cookie or body).
enum ReviewedRoamShareSnapshotReadRoute {
    static func accepts(_ request: URLRequest, baseURL: URL) -> Bool {
        guard request.httpMethod == "GET", request.httpBody == nil, request.httpBodyStream == nil,
              request.value(forHTTPHeaderField: "Authorization") == nil,
              request.value(forHTTPHeaderField: "Cookie") == nil,
              request.value(forHTTPHeaderField: "Proxy-Authorization") == nil,
              request.value(forHTTPHeaderField: "Content-Type") == nil,
              request.value(forHTTPHeaderField: "Accept") == "application/json",
              let url = request.url, url.fragment == nil,
              url.scheme == baseURL.scheme, url.host == baseURL.host, url.port == baseURL.port,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.user == nil, parts.password == nil,
              parts.path == baseURL.appendingPathComponent(RoamShareSnapshot.path).path,
              let items = parts.queryItems, items.count == 1, items[0].name == "token",
              let value = items[0].value, RoamShareToken(value) != nil else { return false }
        return true
    }
}

/// Exact requests emitted by `MerchantMarketingService.home()` (with the fixed 30-day window) and `.insight()`.
/// `api/merchant/access/me` and the query-less `marketing-home` stay on the coupon-management read lease. Settlement,
/// subscription, commerce and prediction-inbox routes are not matched.
enum ReviewedMerchantMarketingReadRoute {
    static func accepts(_ request: URLRequest, baseURL: URL, token: String?) -> Bool {
        guard let token, AuthRequestBuilder.isValidToken(token),
              request.httpMethod == "POST", request.httpBody == nil, request.httpBodyStream == nil,
              request.value(forHTTPHeaderField: "Authorization")?.utf8.elementsEqual(token.utf8) == true,
              request.value(forHTTPHeaderField: "Accept") == "application/json",
              request.value(forHTTPHeaderField: "Content-Type") == nil,
              request.value(forHTTPHeaderField: "Cookie") == nil,
              request.value(forHTTPHeaderField: "Proxy-Authorization") == nil,
              let url = request.url, url.fragment == nil,
              url.scheme == baseURL.scheme, url.host == baseURL.host, url.port == baseURL.port,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.user == nil, parts.password == nil else { return false }
        func exactPath(_ path: String) -> Bool { parts.path == baseURL.appendingPathComponent(path).path }
        if exactPath("api/merchant/marketing-home") {
            guard let items = parts.queryItems, items.count == 1, items[0].name == "windowDays",
                  items[0].value == String(MerchantMarketingHome.windowDays) else { return false }
            return true
        }
        return exactPath("api/ai/merchant/insight") && parts.query == nil
    }
}

enum ReviewedProductionFormMutationRoute {
    static func accepts(_ request: URLRequest, baseURL: URL, token: String?) -> Bool {
        guard let token, AuthRequestBuilder.isValidToken(token),
              request.httpMethod == "POST", request.httpBodyStream == nil,
              request.value(forHTTPHeaderField: "Authorization")?.utf8.elementsEqual(token.utf8) == true,
              let url = request.url, url.query == nil, url.fragment == nil,
              let type = request.value(forHTTPHeaderField: "Content-Type"),
              type.hasPrefix("multipart/form-data; boundary="),
              let body = request.httpBody, body.count <= 1024,
              let text = String(data: body, encoding: .utf8) else { return false }
        let boundary = String(type.dropFirst("multipart/form-data; boundary=".count))
        let requiredKeys: Set<String>
        let positiveKey: String
        let requiredTypeField: String?
        switch url.absoluteString {
        case baseURL.appendingPathComponent("api/registration/cancel").absoluteString,
             baseURL.appendingPathComponent("api/registration/cancel-refund").absoluteString:
            requiredKeys = ["id"]; positiveKey = "id"; requiredTypeField = nil
        case baseURL.appendingPathComponent("api/coupon/qr-token").absoluteString,
             baseURL.appendingPathComponent("api/coupon/status").absoluteString:
            requiredKeys = ["couponHistoryId"]; positiveKey = "couponHistoryId"; requiredTypeField = nil
        case baseURL.appendingPathComponent("api/verify/citynode/issue").absoluteString:
            requiredKeys = ["poiId"]; positiveKey = "poiId"; requiredTypeField = nil
        case baseURL.appendingPathComponent("api/topic/like").absoluteString:
            requiredKeys = ["id", "type"]; positiveKey = "id"; requiredTypeField = "0"
        case baseURL.appendingPathComponent("api/im/delete").absoluteString,
             baseURL.appendingPathComponent("api/im/read").absoluteString:
            requiredKeys = ["conversation_id"]; positiveKey = "conversation_id"; requiredTypeField = nil
        case baseURL.appendingPathComponent("api/im/mute").absoluteString:
            requiredKeys = ["conversation_id", "muted"]; positiveKey = "conversation_id"; requiredTypeField = nil
        case baseURL.appendingPathComponent("api/im/report").absoluteString:
            requiredKeys = ["message_id", "reason"]; positiveKey = "message_id"; requiredTypeField = nil
        case baseURL.appendingPathComponent("api/im/block").absoluteString,
             baseURL.appendingPathComponent("api/im/unblock").absoluteString,
             baseURL.appendingPathComponent("api/im/start").absoluteString:
            requiredKeys = ["target_member_id"]; positiveKey = "target_member_id"; requiredTypeField = nil
        default:
            return false
        }
        var fields: [String: String] = [:]
        for key in requiredKeys {
            let marker = "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(key)\"\r\n\r\n"
            guard let range = text.range(of: marker),
                  let end = text[range.upperBound...].range(of: "\r\n") else { return false }
            fields[key] = String(text[range.upperBound..<end.lowerBound])
        }
        guard let rawID = fields[positiveKey], let id = Int(rawID), id > 0, String(id) == rawID else { return false }
        if let requiredTypeField, fields["type"] != requiredTypeField { return false }
        guard let canonical = try? AuthRequestBuilder.makeFormRequest(url: url, fields: fields, token: token, boundary: boundary) else { return false }
        return canonical.httpBody == body
    }

}

/// Handover 23 non-money paths. Merchant intent and marketing order/pay are not in this set.
enum ReviewedPlayGapRoute {
    static func accepts(_ request: URLRequest, baseURL: URL) -> Bool {
        guard let url = request.url, url.fragment == nil, url.user == nil, url.password == nil else { return false }
        let base = baseURL.path
        let path = url.path
        guard path == base || path.hasPrefix(base.hasSuffix("/") ? base : base + "/") else { return false }
        let relative = path.dropFirst(base.count)
        let key = ChinaReviewedRouteCapability.normalized(String(relative))
        return ChinaReviewedRouteCapability.playGapOwnerGrant.contains(key)
    }
}

