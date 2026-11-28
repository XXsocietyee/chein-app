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
        "api/merchant/reviews/manage/report",
        "api/merchant/operators/invite", "api/merchant/operators/role",
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
                                                             paths: [
                                                                MerchantEngagementProductionApproval.acceptInvitationPath,
                                                                MerchantEngagementProductionApproval.customerCatalogPath,
                                                                "api/merchant/crm/segments", "api/merchant/crm/exports",
                                                                "api/common/uploadOSS"
                                                             ]) else { return nil }
        return try? MerchantEngagementProductionApproval(market: .china, endpoints: endpoints, grants: [],
                                                         reviewedPolicyVersion: MerchantCoopLiveWrites.policyVersion)
    }
}

/// Composition-firewall admission for the MP-first merchant writes (owner 2026-11-25). Exact POST paths the MP
/// merchant pages send, with the session token. CRM customer paths carry one positive customer id.
/// Queries: aftercare respond `refundId`, manual-case detail `manualCaseId`, game-session receipt `activityId`+`requestId`.
/// `uploadOSS` is admitted only as the aftercare evidence multipart. Station commands require a station action.
/// No money path is in this set (pay, refund execution, payout and withdrawal stay behind `ReviewedAreaSwitch`).
enum MPFirstMerchantWriteRoute {
    static let stationActions = ["STATION_ACCEPT", "STATION_DECLINE", "STATION_READY", "STATION_PAUSE", "STATION_RESUME", "VERIFY_SUBMISSION"]
    static let exactPaths: Set<String> = MPFirstMerchantApprovals.businessPaths
        .union([MerchantEngagementProductionApproval.acceptInvitationPath])
        .union(MerchantCityNPCParityGates.mpFirstChinaEndpoints)
        .union(["api/merchant/predict/settle", "api/merchant/crm/segments", "api/merchant/crm/exports"])
        .subtracting(["api/compliance/consents", "api/game/session/command", "api/game/session/receipt"])
    static let customerSuffixes: Set<String> = ["notes", "notes/hide", "tags", "tags/remove", "contact"]

    static func accepts(_ request: URLRequest, baseURL: URL, token: String?, merchantCenterEnabled: Bool = PlayerLaunch.merchantCenterEnabled) -> Bool {
        guard MPFirstMerchantApprovals.enabled, let token, AuthRequestBuilder.isValidToken(token),
              request.httpBodyStream == nil,
              request.value(forHTTPHeaderField: "Authorization")?.utf8.elementsEqual(token.utf8) == true,
              let url = request.url, url.fragment == nil, url.user == nil, url.password == nil,
              url.scheme == baseURL.scheme, url.host == baseURL.host, url.port == baseURL.port,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let relative = relativePath(parts.path, base: baseURL.path) else { return false }
        if request.httpMethod == "GET" {
            if relative == "api/game/session/receipt" { return admitsReceipt(parts) }
            return admitsExportDownload(relative, parts)
        }
        guard request.httpMethod == "POST" else { return false }
        if relative == "api/merchant/aftercare/respond" {
            guard let items = parts.queryItems, items.count == 1, items[0].name == "refundId",
                  let raw = items[0].value, let id = Int(raw), id > 0, String(id) == raw else { return false }
            return true
        }
        if relative == "api/merchant/aftercare/manual-case-detail" { return admitsManualCase(parts, request) }
        guard parts.query == nil else { return false }
        if relative == "api/game/session/command" { return admitsStationCommand(request) }
        if relative == "api/common/uploadOSS" { return admitsEvidenceUpload(request) }
        if isExportStatus(relative) { return admitsEmptyJSON(request) }
        if relative == "api/merchant/predict/settle", !merchantCenterEnabled { return false }
        if exactPaths.contains(relative) { return true }
        return isCustomerWrite(relative)
    }
    static func relativePath(_ path: String, base: String) -> String? {
        let prefix = base.hasSuffix("/") ? base : base + "/"
        guard path.hasPrefix(prefix), !path.contains("..") else { return nil }
        return String(path.dropFirst(prefix.count))
    }
    /// `api/merchant/crm/customers/{id}/notes|notes/hide|tags|tags/remove|contact`.
    static func isCustomerWrite(_ relative: String) -> Bool {
        let head = "api/merchant/crm/customers/"
        guard relative.hasPrefix(head) else { return false }
        let rest = relative.dropFirst(head.count)
        guard let slash = rest.firstIndex(of: "/") else { return false }
        let raw = String(rest[..<slash])
        guard let id = Int(raw), id > 0, String(id) == raw else { return false }
        return customerSuffixes.contains(String(rest[rest.index(after: slash)...]))
    }
    static func positiveID(_ raw: String?) -> Bool {
        guard let raw, let id = Int(raw), id > 0, String(id) == raw else { return false }
        return true
    }
    static func admitsReceipt(_ parts: URLComponents) -> Bool {
        guard MerchantCityNPCParityGates.mpFirstChinaEndpoints.contains("api/game/session/receipt"),
              let items = parts.queryItems, items.count == 2 else { return false }
        var fields: [String: String] = [:]
        for item in items { fields[item.name] = item.value ?? "" }
        guard positiveID(fields["activityId"]), let requestID = fields["requestId"],
              requestID.range(of: #"^[A-Za-z0-9_-]{8,64}$"#, options: .regularExpression) != nil else { return false }
        return fields.count == 2
    }
    static func admitsManualCase(_ parts: URLComponents, _ request: URLRequest) -> Bool {
        guard let items = parts.queryItems, items.count == 1, items[0].name == "manualCaseId",
              positiveID(items[0].value) else { return false }
        let body = request.httpBody
        return body == nil || body?.isEmpty == true
    }
    static func admitsStationCommand(_ request: URLRequest) -> Bool {
        guard let body = request.httpBody, let text = String(data: body, encoding: .utf8) else { return false }
        return stationActions.contains { text.contains("\"action\":\"\($0)\"") || text.contains("\"action\": \"\($0)\"") }
    }
    static func admitsEvidenceUpload(_ request: URLRequest) -> Bool {
        guard let type = request.value(forHTTPHeaderField: "Content-Type"), type.contains("boundary=MerchantEvidence-"),
              let body = request.httpBody, let text = String(data: body, encoding: .utf8) else { return false }
        return text.contains("merchant_aftercare_evidence") && text.contains("name=\"refundId\"")
    }
    static func isExportStatus(_ relative: String) -> Bool {
        exportChild(relative, suffix: "/status")
    }
    static func admitsExportDownload(_ relative: String, _ parts: URLComponents) -> Bool {
        guard parts.query == nil, exportChild(relative, suffix: "/download") else { return false }
        return true
    }
    static func exportChild(_ relative: String, suffix: String) -> Bool {
        let head = "api/merchant/crm/exports/"
        guard relative.hasPrefix(head), relative.hasSuffix(suffix) else { return false }
        let raw = String(relative.dropFirst(head.count).dropLast(suffix.count))
        return positiveID(raw) && !raw.contains("/")
    }
    static func admitsEmptyJSON(_ request: URLRequest) -> Bool {
        request.value(forHTTPHeaderField: "Content-Type") == "application/json" && request.httpBody == Data("{}".utf8)
    }
}
