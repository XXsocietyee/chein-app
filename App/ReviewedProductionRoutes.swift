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
        if acceptsContractHandle(request, baseURL: baseURL, token: token) { return true }
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
              let body = request.httpBody, body.count <= 1024,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let teamID = object["teamId"] as? Int, teamID > 0 else { return false }
        func exactPath(_ path: String) -> Bool { parts.path == baseURL.appendingPathComponent(path).path }
        func canonical(_ value: [String: Any]) -> Bool {
            (try? JSONSerialization.data(withJSONObject: value, options: .sortedKeys)) == body
        }
        if exactPath("api/team/apply") {
            if object.count == 1 { return body.count <= 96 && canonical(["teamId": teamID]) }
            guard object.count == 2, let rawMessage = object["message"] as? String else { return false }
            let trimmed = rawMessage.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed == rawMessage, trimmed.count <= NearbyTeamRequest.maxApplyMessageLength else { return false }
            return canonical(["teamId": teamID, "message": trimmed])
        }
        if exactPath("api/team/withdraw") {
            return body.count <= 96 && object.count == 1 && canonical(["teamId": teamID])
        }
        guard exactPath("api/team/handle"), object.count == 3,
              let memberID = object["memberId"] as? Int, memberID > 0,
              let approved = object["approved"] as? Bool else { return false }
        return canonical(["teamId": teamID, "memberId": memberID, "approved": approved])
    }

    /// `AccountPublishMPContract.teamHandleRequest`: `api/team/command` with string ids, `action` `handle`, and a 32-hex `requestId`.
    private static func acceptsContractHandle(_ request: URLRequest, baseURL: URL, token: String?) -> Bool {
        guard let token, AuthRequestBuilder.isValidToken(token),
              request.httpMethod == "POST", request.httpBodyStream == nil,
              request.value(forHTTPHeaderField: "Authorization")?.utf8.elementsEqual(token.utf8) == true,
              request.value(forHTTPHeaderField: "Accept") == "application/json",
              request.value(forHTTPHeaderField: "Content-Type") == AccountPublishMPContract.jsonContentType,
              request.value(forHTTPHeaderField: "Cookie") == nil,
              request.value(forHTTPHeaderField: "Proxy-Authorization") == nil,
              let url = request.url, url.fragment == nil, url.query == nil,
              url.scheme == baseURL.scheme, url.host == baseURL.host, url.port == baseURL.port,
              url.path == baseURL.appendingPathComponent(AccountPublishMPContract.teamCommandPath).path,
              let body = request.httpBody, body.count <= 1024,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              Set(object.keys) == ["memberId", "approved", "targetId", "action", "requestId"],
              object["action"] as? String == "handle",
              let memberID = object["memberId"] as? String,
              let targetID = object["targetId"] as? String,
              let approved = object["approved"] as? Bool,
              let requestID = object["requestId"] as? String,
              let contract = try? AccountPublishMPContract.teamHandleRequest(
                baseURL: baseURL, memberID: memberID, approved: approved, targetID: targetID, requestID: requestID, token: token),
              contract.httpBody == body else { return false }
        return true
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
            return acceptsMyProjectMutation(request, baseURL: baseURL, token: token)
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

/// Team lobby (`/api/orient/team/lobby`) and opening-lobby seat reads (`/api/play/player-journey/seats`,
/// `/api/play/seat-invitations*`) aligned with `integration/backend-app-r2`: signed-in `Authorization: <token>`
/// GET requests with positive integer query/path identifiers.
enum ReviewedTeamLobbyAndSeatsReadRoute {
    static func acceptsRead(url: URL, parts: URLComponents, baseURL: URL) -> Bool {
        guard url.scheme == baseURL.scheme, url.host == baseURL.host, url.port == baseURL.port else { return false }
        func exact(_ path: String) -> Bool { parts.path == baseURL.appendingPathComponent(path).path }
        func positive(_ raw: String?) -> Bool {
            guard let raw, !raw.isEmpty, raw.utf8.count <= 18,
                  raw.utf8.allSatisfy({ (48...57).contains($0) }),
                  let value = Int(raw), value > 0, String(value) == raw else { return false }
            return true
        }
        let items = parts.queryItems ?? []
        if exact("api/orient/team/lobby") {
            guard items.count == 2 else { return false }
            var values: [String: String] = [:]
            for item in items {
                guard let value = item.value, values[item.name] == nil else { return false }
                values[item.name] = value
            }
            return values.count == 2 && positive(values["ownerType"]) && positive(values["ownerId"])
        }
        if exact("api/play/player-journey/seats") || exact("api/play/seat-invitations") {
            return items.count == 1 && items[0].name == "registrationId" && positive(items[0].value)
        }
        let invitationPrefix = baseURL.appendingPathComponent("api/play/seat-invitations").path + "/"
        if items.isEmpty, parts.query == nil, parts.path.hasPrefix(invitationPrefix) {
            let suffix = String(parts.path.dropFirst(invitationPrefix.count))
            guard !suffix.isEmpty, suffix.utf8.count <= 64,
                  suffix != "invite", suffix != "claim",
                  suffix.utf8.allSatisfy({
                      (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 95 || $0 == 45
                  }) else { return false }
            return true
        }
        return false
    }
}


