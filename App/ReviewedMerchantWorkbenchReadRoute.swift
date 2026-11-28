import Foundation

/// Acceptance R2 F-16. The merchant workbench's own overview reads, sent by the session's `MerchantService`:
/// `api/merchant/dashboard` and `api/merchant/todo-summary` (POST, no body) and `api/merchant/events` (POST JSON `{}`).
/// They are live, wired, non-money reads in `ChinaReviewedRouteCapability`, but the ordinary composition transport had
/// no admission for them, so the revenue and to-do cards always answered 这项功能还没开通 (`auth.notConfigured`).
/// `api/merchant/access/me` is not here: it stays on the coupon-management read lease. The composition still requires
/// the reviewed production gates, China, and a signed-in merchant viewer; the server enforces `merchant:finance:read`.
enum ReviewedMerchantWorkbenchReadRoute {
    static let bodylessPaths = ["api/merchant/dashboard", "api/merchant/todo-summary"]
    static let eventsPath = "api/merchant/events"
    static let upcomingRunsPath = "api/merchant/upcoming-runs"

    static func accepts(_ request: URLRequest, baseURL: URL, token: String?) -> Bool {
        guard let token, AuthRequestBuilder.isValidToken(token),
              request.httpMethod == "POST", request.httpBodyStream == nil,
              request.value(forHTTPHeaderField: "Authorization")?.utf8.elementsEqual(token.utf8) == true,
              request.value(forHTTPHeaderField: "Cookie") == nil,
              request.value(forHTTPHeaderField: "Proxy-Authorization") == nil,
              let url = request.url, url.query == nil, url.fragment == nil, url.user == nil, url.password == nil,
              url.scheme == baseURL.scheme, url.host == baseURL.host, url.port == baseURL.port else { return false }
        let absolute = url.absoluteString
        if absolute == baseURL.appendingPathComponent(eventsPath).absoluteString {
            return MerchantEventsBodyAdmission.admits(request)
        }
        if absolute == baseURL.appendingPathComponent(upcomingRunsPath).absoluteString {
            return request.value(forHTTPHeaderField: "Content-Type") == "application/json"
                && request.httpBody == Data("{}".utf8)
        }
        guard request.httpBody == nil || request.httpBody?.isEmpty == true,
              request.value(forHTTPHeaderField: "Content-Type") == nil else { return false }
        return bodylessPaths.contains { absolute == baseURL.appendingPathComponent($0).absoluteString }
    }
}

/// `api/merchant/events` admits the existing JSON `{}` and Core's empty urlencoded POST. A POST with no content type stays out.
enum MerchantEventsBodyAdmission {
    static func admits(_ request: URLRequest) -> Bool {
        let type = request.value(forHTTPHeaderField: "Content-Type")
        if type == "application/json", request.httpBody == Data("{}".utf8) { return true }
        let empty = request.httpBody == nil || request.httpBody?.isEmpty == true
        return type == "application/x-www-form-urlencoded; charset=utf-8" && empty
    }
}

/// `MerchantOperationsService.save` sends `business_status=<int>` as one form field. JSON business-status stays unmatched.
enum MerchantBusinessStatusAdmission {
    static func kind(contentType: String?, body: Data?, matches: Bool) -> ReviewedMerchantOperationsRoute.Kind? {
        guard matches, contentType == "application/x-www-form-urlencoded; charset=utf-8",
              let body, let text = String(data: body, encoding: .utf8),
              text.hasPrefix("business_status=") else { return nil }
        let value = String(text.dropFirst("business_status=".count))
        guard !value.isEmpty, value.allSatisfy(\.isNumber), Int(value) != nil, text == "business_status=\(value)" else { return nil }
        return .write(path: "api/merchant/business-status/update")
    }
}

/// Merchant operations (`MerchantOperationsService`): the four baseline reads a save needs and the four reviewed saves
/// (decor, cooperation, NPC character, perk template). Bodies are checked against per-path key allowlists with scalar values
/// only (`params` may carry `{"clearCapacity":true}`). Profile, business-status and story saves are not leased.
enum ReviewedMerchantOperationsRoute {
    enum Kind: Equatable { case read, write(path: String) }
    static let writePaths: Set<String> = ["api/merchant/decor/save", "api/merchant/coop-profile/save", "api/merchant/npc/save", "api/merchant/city-node/template/submit"]
    private static let decor: Set<String> = ["coverImage", "slogan", "cityRole", "storyTitle", "gallery", "tags", "featuredType", "featuredId", "serviceTag",
        "serviceText", "locationLat", "locationLng", "locationVerified", "categoryIds", "address"]
    private static let coop: Set<String> = ["availableTime", "demand", "capacity", "params", "chargeType", "suitActivityTypes", "coopOpen"]
    private static let npc: Set<String> = ["name", "avatar", "greeting", "persona", "knowledge"]
    private static let template: Set<String> = ["id", "title", "validationMethod", "duration", "usageLocation", "ruleInstructions", "hint1", "hint2",
        "answerReveal", "storyText", "storyJson", "activityCategoryids", "categoryId", "imgUrl", "couponId", "description", "players", "requiredMaterials",
        "questionAnswer", "questionName", "questionA", "questionB", "questionC", "questionD", "correctAnswer", "feedbackText"]

    static func kind(_ request: URLRequest, baseURL: URL, token: String?) -> Kind? {
        guard let token, AuthRequestBuilder.isValidToken(token),
              request.httpMethod == "POST", request.httpBodyStream == nil,
              request.value(forHTTPHeaderField: "Authorization")?.utf8.elementsEqual(token.utf8) == true,
              request.value(forHTTPHeaderField: "Accept") == "application/json",
              request.value(forHTTPHeaderField: "Cookie") == nil,
              request.value(forHTTPHeaderField: "Proxy-Authorization") == nil,
              let url = request.url, url.fragment == nil,
              url.scheme == baseURL.scheme, url.host == baseURL.host, url.port == baseURL.port,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.user == nil, parts.password == nil, parts.query == nil else { return nil }
        let type = request.value(forHTTPHeaderField: "Content-Type")
        func exactPath(_ path: String) -> Bool { parts.path == baseURL.appendingPathComponent(path).path }
        if let form = MerchantBusinessStatusAdmission.kind(contentType: type, body: request.httpBody, matches: exactPath("api/merchant/business-status/update")) { return form }
        if exactPath("api/merchant/coop-profile") || exactPath("api/merchant/npc/profile") {
            return type == "application/json" && request.httpBody == Data("{}".utf8) ? .read : nil
        }
        // Reads sent as canonical multipart: empty (`merchant/info`) or a single positive `id` (`template/myinfo`).
        if exactPath("api/merchant/info") || exactPath("api/template/myinfo") {
            guard let type, type.hasPrefix("multipart/form-data; boundary="), let body = request.httpBody, body.count <= 512,
                  let text = String(data: body, encoding: .utf8) else { return nil }
            let boundary = String(type.dropFirst("multipart/form-data; boundary=".count))
            var fields: [String: String] = [:]
            if exactPath("api/template/myinfo") {
                let marker = "--\(boundary)\r\nContent-Disposition: form-data; name=\"id\"\r\n\r\n"
                guard let range = text.range(of: marker), let end = text[range.upperBound...].range(of: "\r\n"),
                      let id = Int(text[range.upperBound..<end.lowerBound]), id > 0 else { return nil }
                fields["id"] = String(id)
            }
            guard let canonical = try? AuthRequestBuilder.makeFormRequest(url: url, fields: fields, token: token, boundary: boundary),
                  canonical.httpBody == body else { return nil }
            return .read
        }
        guard type == "application/json", let body = request.httpBody, !body.isEmpty, body.count <= 16_384,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any], !object.isEmpty else { return nil }
        let allowed: Set<String>, required: Set<String>, path: String
        if exactPath("api/merchant/decor/save") { allowed = decor; required = []; path = "api/merchant/decor/save" }
        else if exactPath("api/merchant/coop-profile/save") { allowed = coop; required = ["availableTime", "demand"]; path = "api/merchant/coop-profile/save" }
        else if exactPath("api/merchant/npc/save") { allowed = npc; required = npc; path = "api/merchant/npc/save" }
        else if exactPath("api/merchant/city-node/template/submit") { allowed = template; required = ["title"]; path = "api/merchant/city-node/template/submit" }
        else { return nil }
        let keys = Set(object.keys)
        // An empty object, an array value, or a key outside the allowlist is not one of the four saves.
        guard !keys.isEmpty, keys.isSubset(of: allowed), required.isSubset(of: keys) else { return nil }
        for (key, value) in object {
            if key == "params" {
                guard let params = value as? [String: Any], params.count == 1, params["clearCapacity"] as? Bool == true else { return nil }
            } else if !(value is String || value is NSNumber || value is NSNull) { return nil }
            if path == "api/merchant/npc/save", !(value is String) { return nil }
        }
        return .write(path: path)
    }

    /// Decor and NPC saves are body-checked here. A path-only merchant write must not admit a body this route refused.
    static func refusedBodyCheckedSave(_ request: URLRequest, baseURL: URL, token: String?) -> Bool {
        guard request.httpMethod == "POST", let url = request.url, url.query == nil, url.fragment == nil else { return false }
        let checked = ["api/merchant/decor/save", "api/merchant/npc/save"]
        guard checked.contains(where: { url.path == baseURL.appendingPathComponent($0).path }) else { return false }
        return kind(request, baseURL: baseURL, token: token) == nil
    }
}
