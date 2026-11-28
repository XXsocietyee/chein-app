import Foundation

/// Owner MP-first rule for club writes the mini-program already sends. The server checks the role.
/// Pay, refund execution, payout, withdrawal, paid orders, quote, registration create, and pricing
/// confirm are not built or sent. Settlement mine stays `POST {}` on its own route.
enum MPFirstClubApprovals {
    private static var rosterRevisions: [String: UUID] = [:]
    private static var badgeApprovals: [String: ClubBadgeManagementApproval] = [:]

    static func governance(_ context: RuntimeDependencyContext) -> ClubGovernanceProductionApproval? {
        guard context.market == .china,
              let endpoints = try? OperationEndpointApproval(
                baseURL: context.baseURL, namespace: context.session.namespace,
                accountID: context.session.accountID, paths: ClubMPFirstGovernance.paths(for: ClubMPFirstGovernance.governance))
        else { return nil }
        return try? ClubGovernanceProductionApproval(mpFirstMarket: .china, endpoints: endpoints, operations: ClubMPFirstGovernance.governance)
    }

    /// CLB-r11-checkin-detail-01. MP pages/club/checkin-detail/index.js:143-200 (清退并退款, wxml:77-88) posts
    /// `/api/registration/cancel-by-owner` `{id}`. Owner 11-26: refund is money and is on in Release, so the approval
    /// is built for China only while `ReleaseMoneyWriteSwitch` has `.refund` on.
    static func ownerRefund(_ context: RuntimeDependencyContext) -> ClubOwnerRefundApproval? {
        guard context.market == .china, ReleaseMoneyWriteSwitch.isEnabled(.refund),
              let endpoints = endpoint(context, paths: MPFirstClubWriteRoute.ownerRefundPaths) else { return nil }
        return ClubOwnerRefundApproval(market: .china, endpoints: endpoints)
    }

    static func roleAssignment(_ context: RuntimeDependencyContext) -> ClubRoleAssignmentApproval? {
        guard context.market == .china, let endpoints = try? roleEndpoints(context, ClubRoleAssignmentRoute.paths) else { return nil }
        return try? ClubRoleAssignmentApproval(mpFirstEndpoints: endpoints)
    }

    static func roleRevocation(_ context: RuntimeDependencyContext) -> ClubRoleRevocationApproval? {
        guard context.market == .china, let endpoints = try? roleEndpoints(context, ClubRoleRevocationRoute.paths) else { return nil }
        return try? ClubRoleRevocationApproval(mpFirstEndpoints: endpoints)
    }

    static func roster(_ context: RuntimeDependencyContext) -> ClubPublicRosterApproval? {
        guard context.market == .china, context.session.accountID > 0 else { return nil }
        let key = "\(context.baseURL.absoluteString)|\(context.session.namespace)|\(context.session.accountID)|\(context.session.epoch)"
        let revision = rosterRevisions[key] ?? UUID()
        rosterRevisions[key] = revision
        return ClubPublicRosterApproval(
            identity: ClubReadIdentity(accountID: context.session.accountID, epoch: context.session.epoch),
            baseURL: context.baseURL, revision: revision)
    }

    /// CLB-r10-badges-01. MP pages/club/badges/index.js: list, create and grant (non-money).
    /// One approval per session identity so its revision stays stable for the host and transport checks.
    static func badges(_ context: RuntimeDependencyContext) -> ClubBadgeManagementApproval? {
        guard context.market == .china, context.session.accountID > 0 else { return nil }
        let key = "\(context.baseURL.absoluteString)|\(context.session.namespace)|\(context.session.accountID)|\(context.session.epoch)"
        if let cached = badgeApprovals[key] { return cached }
        guard let endpoints = endpoint(context, paths: ClubBadgeManagementRoute.paths),
              let approval = try? ClubBadgeManagementApproval(mpFirstEndpoints: endpoints) else { return nil }
        badgeApprovals[key] = approval
        return approval
    }

    static func welcomeWrite(_ context: RuntimeDependencyContext) -> OperationEndpointApproval? {
        endpoint(context, paths: [ClubWelcomeNoteService.path])
    }

    static func welcomeReceipt(_ context: RuntimeDependencyContext) -> OperationEndpointApproval? {
        endpoint(context, paths: [ClubWelcomeNoteService.receiptPath])
    }

    static var welcomeDirectory: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("club-welcome-note-original", isDirectory: true)
    }

    static func operations(_ context: RuntimeDependencyContext) -> OperationEndpointApproval? {
        endpoint(context, paths: MPFirstClubWriteRoute.operationPaths)
    }

    private static func roleEndpoints(_ context: RuntimeDependencyContext, _ paths: Set<String>) throws -> OperationEndpointApproval {
        try OperationEndpointApproval(baseURL: context.baseURL, namespace: context.session.namespace, accountID: context.session.accountID, paths: paths)
    }

    private static func endpoint(_ context: RuntimeDependencyContext, paths: Set<String>) -> OperationEndpointApproval? {
        guard context.market == .china else { return nil }
        return try? OperationEndpointApproval(baseURL: context.baseURL, namespace: context.session.namespace, accountID: context.session.accountID, paths: paths)
    }
}

/// Composition-firewall admission for the non-money club POSTs the enabled commands send.
/// Role assign/revoke stay on their exact body parser. Welcome-note stays on its own transport.
enum MPFirstClubWriteRoute {
    static let operationPaths: Set<String> = [
        "api/club/create", "api/club/update-mine", "api/club/set-member-role",
        "api/club/open-settings/public-visible", "api/club/open-settings/member-post", "api/club/open-settings/merchant-coop"
    ]
    static let governancePaths: Set<String> = [
        "api/club/governance/ban", "api/club/governance/unban", "api/club/governance/owner/transfer",
        "api/club/governance/cases/report", "api/club/governance/cases/appeal", "api/club/become-leader", "api/club/dissolve",
        "api/club/governance/list", "api/club/governance/cases/mine", "api/club/dissolution-blockers",
        "api/publisher/identity/status", "api/club/roles/list",
        // CLB-r10-gate-05 (MP pages/club/notify, group-code:93-135, event-ops, topic-detail, customer-detail):
        // the writes in `ClubMPFirstGovernance.clubOps` and their review reads.
        "api/club/event-notification/send", "api/club/event-notification/retry", "api/verify/groupcode/issue",
        "api/club/crm/customers/tag-remark", "api/club/event-ops/series/create", "api/club/event-ops/series/update-future",
        "api/club/event-ops/attendance/correct", "api/club/topic-setting/save",
        "api/club/event-notification/preview", "api/club/event-notification/status",
        "api/club/crm/customers/detail", "api/club/event-ops/topics", "api/club/event-ops/series/detail",
        "api/club/event-ops/roster", "api/club/topic-setting/detail", "api/club/access/me", "api/club/members",
        // CLB-r10-join-requests-01 (MP pages/club/join-requests/index.js:170): ClubManagementService's list read and
        // 通过 / 拒绝 (ClubJoinRequestsPageReady.routes). No other firewall branch admitted them in Release China.
        "api/club/join-requests", "api/club/join-request/approve", "api/club/join-request/reject",
        // P1-12: owner reads the club pages send through ClubGovernanceRead (MP stats/settlement/customers/event-ops/notify):
        // 统计概览, 结算 summary (read only; withdraw stays refused by the "withdraw" word), CRM list, series list, audience counts.
        "api/stats/club", settlementSummaryPath, "api/club/crm/customers/list", "api/club/event-ops/series/list",
        "api/club/event-notification/audience-counts",
        // 1128-plan C-13 (MP detail/index.js:3571): the 查看客户 gear count, `{clubId}` (ClubDetailR8Mounts).
        "api/club/crm/customers/count",
        // P1-11 (MP pages/club/detail/index.js:3430 removeMember): 移除成员, `{clubId, memberId}` (ClubManagementService.perform).
        "api/club/remove-member",
        // CLB-r11-money-01 (MP event-ops/index.js:1106-1115, topic-detail/index.js:1145-1148): host-cancel refund
        // writes and the cancel review read. The writes pass only while `.hostCancelRefund` is on (`accepts`).
        "api/club/event-ops/cancel", "api/club/topic-setting/end", "api/club/event-ops/occurrence/status",
        // CLB-r11-checkin-detail-01 (MP checkin-detail/index.js): the owner refund evidence read.
        "api/club/crm/checkin/detail",
        // CLB-r11-detail-05 (MP detail/index.js:3813-3847 applyCoopPool): 申请带队, intent only, not money.
        coopPoolApplyPath,
        // 1128 gap #13 (C-08; MP topic-detail/index.js:309,980,1048): the director console reads. Without
        // topic-manage-stats the console, 场次管理 and 核销 were hidden for every owner.
        "api/club/crm/topic-manage-stats", "api/club/recruit/overview", "api/club/crm/topic-customers",
        // 1128 gap #14 (C-09; MP topic-story/index.js:285): 查看答案. topic-registrations is admitted by
        // `acceptsTopicRegistrations` before the "registration" substring guard.
        "api/club/topic-node-answer",
        // 1128 gap #18 (C-07a; MP event-ops): the occurrence browser (locked / editable / cancelled).
        "api/club/event-ops/series/occurrences"
    ]
    /// 1128 gap #14 (C-19; MP pages/club/enroll/index.js:373): the 报名名册 read `{clubId, topicId}`. Its path contains
    /// "registration", so it is matched exactly before the substring guard; no other registration path passes here.
    static let topicRegistrationsPath = "api/club/topic-registrations"
    static let coopPoolApplyPath = "api/coop/pool/apply"
    /// P1-12: the one settlement path this firewall admits, an owner read `{clubId}` (ClubGovernanceRead.settlement).
    static let settlementSummaryPath = "api/club/settlement/summary"
    /// CLB-r11-money-01: the host-cancel refund writes. Gated on `ReleaseMoneyWriteSwitch` `.hostCancelRefund`.
    static let hostCancelRefundPaths: Set<String> = ["api/club/event-ops/cancel", "api/club/topic-setting/end"]
    /// CLB-G13a: the club staff shared-run command (MP topic-detail director.js confirmGenericOps / plan-fallback.js →
    /// `executeAction`). Admitted only with the exact `PlaySharedRunOps.acceptsCommandBody` envelope and a 通用玩法 /
    /// PLAN_FALLBACK action; the server checks the staff role. Not money (`GameSharedRunControl.RUN_CONTROL_ACTIONS`).
    static let sharedRunCommandPath = "api/game/session/command"
    /// CLB-r10-badges-01: badge reads, create and grant (all `POST` JSON, ClubBadgeManagementRoute).
    static let badgePaths: Set<String> = ClubBadgeManagementRoute.paths
    /// MP topic-detail chapter recruit/finish post `multipart/form-data` (ClubGovernanceService form: true), and so
    /// does the issueGroupCode review read `api/topic/info-to-user` (ClubGovernanceRead.usesForm; CLB-r10-group-code-01).
    static let formPaths: Set<String> = ["api/topic/chapter/recruit", "api/topic/chapter/finish", "api/topic/info-to-user"]
    /// CLB-r11-checkin-detail-01: the owner refund write and its two review reads (Core/ClubOwnerRefundApprovedAccess.swift:13).
    static let ownerRefundPath = "api/registration/cancel-by-owner"
    static let ownerRefundPaths: Set<String> = [ownerRefundPath, "api/club/access/me", "api/club/crm/checkin/detail"]
    private static let moneyKeys: Set<String> = [
        "payAmount", "payChannel", "withdrawAmount", "refundId", "payoutAccount", "quoteId", "memberDiscountPrice"
    ]

    static func accepts(_ request: URLRequest, baseURL: URL, token: String?) -> Bool {
        if acceptsOwnerRefund(request, baseURL: baseURL, token: token) { return true }
        if acceptsClubScan(request, baseURL: baseURL, token: token) { return true }
        if acceptsTopicRegistrations(request, baseURL: baseURL, token: token) { return true }
        guard let token, AuthRequestBuilder.isValidToken(token),
              request.httpMethod == "POST", request.httpBodyStream == nil,
              request.value(forHTTPHeaderField: "Authorization")?.utf8.elementsEqual(token.utf8) == true,
              let url = request.url, url.fragment == nil, url.user == nil, url.password == nil, url.query == nil,
              url.scheme == baseURL.scheme, url.host == baseURL.host, url.port == baseURL.port,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false), parts.query == nil,
              let relative = MPFirstMerchantWriteRoute.relativePath(parts.path, base: baseURL.path),
              !relative.contains("pay") && !relative.contains("refund") && !relative.contains("payout")
                && !relative.contains("withdraw") && !relative.contains("quote")
                && (!relative.contains("registration") || relative == topicRegistrationsPath)
                && !relative.contains("pricing") && (!relative.contains("settlement") || relative == settlementSummaryPath),
              let body = request.httpBody, body.count < 65_536 else { return false }
        let contentType = request.value(forHTTPHeaderField: "Content-Type") ?? ""
        if formPaths.contains(relative) {
            guard contentType.hasPrefix("multipart/form-data; boundary="), let text = String(data: body, encoding: .utf8) else { return false }
            return moneyKeys.allSatisfy { !text.contains("name=\"\($0)\"") }
        }
        if hostCancelRefundPaths.contains(relative), !ReleaseMoneyWriteSwitch.isEnabled(.hostCancelRefund) { return false }
        guard contentType == "application/json",
              governancePaths.contains(relative) || operationPaths.contains(relative) || badgePaths.contains(relative)
                || relative == sharedRunCommandPath,
              relative != sharedRunCommandPath || PlaySharedRunOps.acceptsCommandBody(body),
              let parsed = try? JSONSerialization.jsonObject(with: body),
              let object = parsed as? [String: Any],
              moneyKeys.isDisjoint(with: object.keys) else { return false }
        // Badge paths (incl. the api/club/detail + api/club/members review reads) only on the badge route's exact bodies.
        if badgePaths.contains(relative) { return ClubBadgeManagementRoute(request: request, baseURL: baseURL) != nil }
        if let shape = readShapes[relative] {
            if let reason = object["reviewReason"], !(reason is String) { return false }
            if relative == coopPoolApplyPath {
                guard let message = object["message"] as? String, message.count <= 500 else { return false }
            }
            if relative == "api/club/crm/topic-manage-stats", !admitsNullableActivity(object) { return false }
            if relative == "api/club/crm/topic-customers", let filter = object["filter"], !(filter is String) { return false }
            return shape.admits(object)
        }
        return true
    }

    /// CLB-r11-checkin-detail-01 (MP checkin-detail/index.js:163): `POST api/registration/cancel-by-owner` with the
    /// multipart form `{id}` (ClubOwnerRefundService), a positive registration id and nothing else, only while refund is on.
    static func acceptsOwnerRefund(_ request: URLRequest, baseURL: URL, token: String?) -> Bool {
        guard ReleaseMoneyWriteSwitch.isEnabled(.refund), let token, AuthRequestBuilder.isValidToken(token),
              request.httpMethod == "POST", request.httpBodyStream == nil,
              request.value(forHTTPHeaderField: "Authorization")?.utf8.elementsEqual(token.utf8) == true,
              let url = request.url, url.fragment == nil, url.user == nil, url.password == nil, url.query == nil,
              url.scheme == baseURL.scheme, url.host == baseURL.host, url.port == baseURL.port,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false), parts.query == nil,
              MPFirstMerchantWriteRoute.relativePath(parts.path, base: baseURL.path) == ownerRefundPath,
              let type = request.value(forHTTPHeaderField: "Content-Type"), type.hasPrefix("multipart/form-data; boundary="),
              let body = request.httpBody, body.count < 1024, let text = String(data: body, encoding: .utf8) else { return false }
        let boundary = String(type.dropFirst("multipart/form-data; boundary=".count))
        guard !boundary.isEmpty else { return false }
        let prefix = "--\(boundary)\r\nContent-Disposition: form-data; name=\"id\"\r\n\r\n"
        let suffix = "\r\n--\(boundary)--\r\n"
        guard text.hasPrefix(prefix), text.hasSuffix(suffix), text.count > prefix.count + suffix.count else { return false }
        let id = String(text.dropFirst(prefix.count).dropLast(suffix.count))
        guard id.count <= 16, id.allSatisfy(\.isASCII), id.allSatisfy(\.isNumber), let value = Int(id) else { return false }
        return value > 0
    }

    /// 1128 gap #14 (C-19): `POST api/club/topic-registrations` JSON `{clubId, topicId}` (ClubGovernanceRead.registrations,
    /// BE ApiClubController.java:1889), two positive ids and nothing else. Read only; registration create stays refused.
    static func acceptsTopicRegistrations(_ request: URLRequest, baseURL: URL, token: String?) -> Bool {
        guard let token, AuthRequestBuilder.isValidToken(token),
              request.httpMethod == "POST", request.httpBodyStream == nil,
              request.value(forHTTPHeaderField: "Authorization")?.utf8.elementsEqual(token.utf8) == true,
              request.value(forHTTPHeaderField: "Content-Type") == "application/json",
              let url = request.url, url.fragment == nil, url.user == nil, url.password == nil, url.query == nil,
              url.scheme == baseURL.scheme, url.host == baseURL.host, url.port == baseURL.port,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false), parts.query == nil,
              MPFirstMerchantWriteRoute.relativePath(parts.path, base: baseURL.path) == topicRegistrationsPath,
              let body = request.httpBody, body.count < 1024,
              let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] else { return false }
        return ReadShape(ids: ["clubId", "topicId"]).admits(object)
    }

    /// CLB-r11-detail-04: club 扫码核销. MP pages/club/detail/index.js:971-1010 (`onClubScan` → `resolveVerificationScan`
    /// → `submitClubScan`) posts these redemption bodies (ClubScanRoute.resolve). Not money: each redeems a code only.
    static let clubScanPaths: [String: Set<String>] = [
        "api/verify/groupcode/redeem": ["code"],
        "api/registration/scan_dynamic_code": ["code"],
        "api/coupon/verification": ["code"],
        "api/registration/scan_qr_code": ["type", "code"]
    ]
    static func acceptsClubScan(_ request: URLRequest, baseURL: URL, token: String?) -> Bool {
        guard let token, AuthRequestBuilder.isValidToken(token),
              request.httpMethod == "POST", request.httpBodyStream == nil,
              request.value(forHTTPHeaderField: "Authorization")?.utf8.elementsEqual(token.utf8) == true,
              request.value(forHTTPHeaderField: "Content-Type") == "application/json",
              let url = request.url, url.fragment == nil, url.user == nil, url.password == nil, url.query == nil,
              url.scheme == baseURL.scheme, url.host == baseURL.host, url.port == baseURL.port,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false), parts.query == nil,
              let relative = MPFirstMerchantWriteRoute.relativePath(parts.path, base: baseURL.path),
              let keys = clubScanPaths[relative],
              let body = request.httpBody, body.count < 20_000,
              let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any],
              Set(object.keys) == keys,
              (object["code"] as? String)?.isEmpty == false else { return false }
        if keys.contains("type") {
            guard let type = object["type"] as? String, ["activity", "topic"].contains(type) else { return false }
        }
        return true
    }

    /// Exact bodies for the review reads (ClubGovernanceRead.fields) and the join-request review writes
    /// (ClubManagementService.perform) on this firewall: every `ids` key is a
    /// positive integer, `optional` keys may be added, and no other key passes.
    struct ReadShape {
        let ids: Set<String>
        var optionalIDs: Set<String> = []
        var optional: Set<String> = []
        /// Non-id keys that must be present (CLB-r11-money-01 write bodies).
        var required: Set<String> = []
        func admits(_ object: [String: Any]) -> Bool {
            let keys = Set(object.keys)
            guard ids.union(required).isSubset(of: keys),
                  keys.isSubset(of: ids.union(optionalIDs).union(optional).union(required)) else { return false }
            return ids.union(optionalIDs.intersection(keys)).allSatisfy { MPFirstClubWriteRoute.positive(object[$0]) }
        }
    }
    static let readShapes: [String: ReadShape] = [
        "api/club/members": .init(ids: ["clubId"]),
        "api/club/governance/list": .init(ids: ["clubId"]),
        "api/club/governance/cases/mine": .init(ids: ["clubId"]),
        "api/club/dissolution-blockers": .init(ids: ["id"]),
        "api/publisher/identity/status": .init(ids: []),
        "api/club/roles/list": .init(ids: ["clubId"], optionalIDs: ["activityId"]),
        "api/club/access/me": .init(ids: ["clubId"], optionalIDs: ["activityId"]),
        "api/club/event-notification/preview": .init(ids: ["clubId"], optional: ["activityId", "audienceType", "title", "content", "channel", "requestId"]),
        "api/club/event-notification/status": .init(ids: ["campaignId"]),
        "api/club/crm/customers/detail": .init(ids: ["clubId", "memberId"]),
        "api/club/event-ops/topics": .init(ids: ["clubId"]),
        "api/club/event-ops/series/detail": .init(ids: ["clubId", "seriesId"]),
        "api/club/event-ops/roster": .init(ids: ["clubId", "activityId"]),
        "api/club/topic-setting/detail": .init(ids: ["clubId", "topicId"]),
        "api/club/join-requests": .init(ids: ["clubId"]),
        "api/club/join-request/approve": .init(ids: ["clubId", "memberId"]),
        "api/club/remove-member": .init(ids: ["clubId", "memberId"]),
        // P1-12: ClubGovernanceRead.fields bodies for the owner reads.
        "api/stats/club": .init(ids: ["clubId"]),
        "api/club/settlement/summary": .init(ids: ["clubId"]),
        "api/club/event-ops/series/list": .init(ids: ["clubId"]),
        "api/club/crm/customers/list": .init(ids: ["clubId", "pageNum", "pageSize"], optional: ["filter", "keyword"]),
        "api/club/crm/customers/count": .init(ids: ["clubId"]),
        "api/club/event-notification/audience-counts": .init(ids: ["clubId"], optional: ["activityId"]),
        "api/club/join-request/reject": .init(ids: ["clubId", "memberId"], optional: ["reviewReason"]),
        // CLB-r11-money-01: MP event-ops/index.js:1110-1115 and topic-detail/index.js:1147 bodies, exact keys.
        "api/club/event-ops/occurrence/status": .init(ids: ["clubId", "activityId"]),
        "api/club/event-ops/cancel": .init(ids: ["clubId", "activityId"], required: ["reason", "requestId"]),
        "api/club/topic-setting/end": .init(ids: ["clubId", "topicId"], required: ["cancellationEpoch"]),
        // CLB-r11-checkin-detail-01: the owner refund evidence read (ClubGovernanceRead.checkin keys).
        "api/club/crm/checkin/detail": .init(ids: ["clubId", "registrationId"]),
        // CLB-r11-detail-05: MP detail/index.js:3813-3847 body `{topicId, clubId, message}` (ClubCoopPoolApplyClient).
        "api/coop/pool/apply": .init(ids: ["topicId", "clubId"], required: ["message"]),
        // 1128 gaps #13 / #14 / #18: ClubGovernanceRead.fields bodies. topic-manage-stats always carries `activityId`
        // (a session id or JSON null), so it is checked by `admitsNullableActivity` below.
        "api/club/crm/topic-manage-stats": .init(ids: ["clubId", "topicId"], required: ["activityId"]),
        "api/club/recruit/overview": .init(ids: ["clubId", "topicId"]),
        "api/club/crm/topic-customers": .init(ids: ["clubId", "topicId"], optional: ["filter"]),
        "api/club/topic-node-answer": .init(ids: ["clubId", "topicId", "nodeId"]),
        "api/club/event-ops/series/occurrences": .init(ids: ["clubId", "seriesId"])
    ]
    /// `activityId` must be JSON null or a positive integer (ClubGovernanceRead.topicStats).
    static func admitsNullableActivity(_ object: [String: Any]) -> Bool {
        guard let value = object["activityId"] else { return false }
        return value is NSNull || positive(value)
    }
    static func positive(_ value: Any?) -> Bool {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return false }
        let double = number.doubleValue
        return double >= 1 && double.rounded() == double && double <= 9_007_199_254_740_991
    }
}
