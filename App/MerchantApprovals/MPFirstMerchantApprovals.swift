import Foundation

/// Owner 2026-11-25 MP-first rule ("check the mini-program first"): the merchant writes the MP sends are
/// sent by the app with the same endpoint, method and body, and the server's own permission checks decide.
/// None of these moves money; payment, refund, payout and withdrawal stay behind `ReviewedAreaSwitch`.
/// Evidence: pages/merchant/customer/detail/index.js:178-300, customer/index.js:716,
/// reviews/index.js:555-620, aftercare/detail/index.js:288, team/index.js:570,626,718,815.
enum MPFirstMerchantApprovals {
    /// Default ON per the MP-first rule.
    static let enabled = true

    static let businessPaths: Set<String> = [
        "api/merchant/crm/customers/tags/batch", "api/merchant/aftercare/respond",
        "api/merchant/reviews/reply", "api/merchant/reviews/reply/update", "api/merchant/reviews/reply/delete",
        "api/merchant/reviews/manage/report", "api/merchant/operators/invite", "api/merchant/operators/role",
        "api/merchant/operators/remove", "api/merchant/operators/invite/revoke"
    ]

    static func business(_ context: RuntimeDependencyContext) -> MerchantBusinessProductionApproval? {
        guard enabled, context.market == .china,
              let endpoints = try? OperationEndpointApproval(baseURL: context.baseURL, namespace: context.session.namespace,
                                                             accountID: context.session.accountID, paths: businessPaths) else { return nil }
        return try? MerchantBusinessProductionApproval(mpFirstMarket: .china, endpoints: endpoints)
    }

    static func engagement(_ context: RuntimeDependencyContext) -> MerchantEngagementProductionApproval? {
        guard enabled, context.market == .china,
              let endpoints = try? OperationEndpointApproval(baseURL: context.baseURL, namespace: context.session.namespace,
                                                             accountID: context.session.accountID,
                                                             paths: [MerchantEngagementProductionApproval.acceptInvitationPath]) else { return nil }
        return try? MerchantEngagementProductionApproval(market: .china, endpoints: endpoints, grants: [],
                                                         reviewedPolicyVersion: "mp-first-2026-11-25", mpFirstAcceptInvitation: true)
    }
}

/// Composition-firewall admission for the MP-first merchant writes (owner 2026-11-25). Exact POST paths the MP
/// merchant pages send, with the session token; the CRM customer paths carry one positive customer id, and only
/// aftercare respond carries a query (`refundId`, pages/merchant/aftercare/detail/index.js:288).
/// No money path is in this set (pay, refund execution, payout and withdrawal stay behind `ReviewedAreaSwitch`).
enum MPFirstMerchantWriteRoute {
    static let exactPaths: Set<String> = MPFirstMerchantApprovals.businessPaths
        .union([MerchantEngagementProductionApproval.acceptInvitationPath])
        .union(MerchantCityNPCParityGates.mpFirstChinaEndpoints)
        .subtracting(["api/compliance/consents"])
    static let customerSuffixes: Set<String> = ["notes", "notes/hide", "tags", "tags/remove"]

    static func accepts(_ request: URLRequest, baseURL: URL, token: String?) -> Bool {
        guard MPFirstMerchantApprovals.enabled, let token, AuthRequestBuilder.isValidToken(token),
              request.httpMethod == "POST", request.httpBodyStream == nil,
              request.value(forHTTPHeaderField: "Authorization")?.utf8.elementsEqual(token.utf8) == true,
              let url = request.url, url.fragment == nil, url.user == nil, url.password == nil,
              url.scheme == baseURL.scheme, url.host == baseURL.host, url.port == baseURL.port,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let relative = relativePath(parts.path, base: baseURL.path) else { return false }
        if relative == "api/merchant/aftercare/respond" {
            guard let items = parts.queryItems, items.count == 1, items[0].name == "refundId",
                  let raw = items[0].value, let id = Int(raw), id > 0, String(id) == raw else { return false }
            return true
        }
        guard parts.query == nil else { return false }
        if exactPaths.contains(relative) { return true }
        return isCustomerWrite(relative)
    }
    static func relativePath(_ path: String, base: String) -> String? {
        let prefix = base.hasSuffix("/") ? base : base + "/"
        guard path.hasPrefix(prefix), !path.contains("..") else { return nil }
        return String(path.dropFirst(prefix.count))
    }
    /// `api/merchant/crm/customers/{id}/notes|notes/hide|tags|tags/remove` (customer/detail/index.js:178-300).
    static func isCustomerWrite(_ relative: String) -> Bool {
        let head = "api/merchant/crm/customers/"
        guard relative.hasPrefix(head) else { return false }
        let rest = relative.dropFirst(head.count)
        guard let slash = rest.firstIndex(of: "/") else { return false }
        let raw = String(rest[..<slash])
        guard let id = Int(raw), id > 0, String(id) == raw else { return false }
        return customerSuffixes.contains(String(rest[rest.index(after: slash)...]))
    }
}
