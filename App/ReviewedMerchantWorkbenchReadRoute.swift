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
