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
        "api/club/join-requests", "api/club/join-request/approve", "api/club/join-request/reject"
    ]
    /// CLB-G13a: the club staff shared-run command (MP topic-detail director.js confirmGenericOps / plan-fallback.js →
    /// `executeAction`). Admitted only with the exact `PlaySharedRunOps.acceptsCommandBody` envelope and a 通用玩法 /
    /// PLAN_FALLBACK action; the server checks the staff role. Not money (`GameSharedRunControl.RUN_CONTROL_ACTIONS`).
    static let sharedRunCommandPath = "api/game/session/command"
    /// CLB-r10-badges-01: badge reads, create and grant (all `POST` JSON, ClubBadgeManagementRoute).
    static let badgePaths: Set<String> = ClubBadgeManagementRoute.paths
    /// MP topic-detail chapter recruit/finish post `multipart/form-data` (ClubGovernanceService form: true), and so
    /// does the issueGroupCode review read `api/topic/info-to-user` (ClubGovernanceRead.usesForm; CLB-r10-group-code-01).
    static let formPaths: Set<String> = ["api/topic/chapter/recruit", "api/topic/chapter/finish", "api/topic/info-to-user"]
    private static let moneyKeys: Set<String> = [
        "payAmount", "payChannel", "withdrawAmount", "refundId", "payoutAccount", "quoteId", "memberDiscountPrice"
    ]

    static func accepts(_ request: URLRequest, baseURL: URL, token: String?) -> Bool {
        guard let token, AuthRequestBuilder.isValidToken(token),
              request.httpMethod == "POST", request.httpBodyStream == nil,
              request.value(forHTTPHeaderField: "Authorization")?.utf8.elementsEqual(token.utf8) == true,
              let url = request.url, url.fragment == nil, url.user == nil, url.password == nil, url.query == nil,
              url.scheme == baseURL.scheme, url.host == baseURL.host, url.port == baseURL.port,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false), parts.query == nil,
              let relative = MPFirstMerchantWriteRoute.relativePath(parts.path, base: baseURL.path),
              !relative.contains("pay") && !relative.contains("refund") && !relative.contains("payout")
                && !relative.contains("withdraw") && !relative.contains("quote") && !relative.contains("registration")
                && !relative.contains("pricing") && !relative.contains("settlement"),
              let body = request.httpBody, body.count < 65_536 else { return false }
        let contentType = request.value(forHTTPHeaderField: "Content-Type") ?? ""
        if formPaths.contains(relative) {
            guard contentType.hasPrefix("multipart/form-data; boundary="), let text = String(data: body, encoding: .utf8) else { return false }
            return moneyKeys.allSatisfy { !text.contains("name=\"\($0)\"") }
        }
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
            return shape.admits(object)
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
        func admits(_ object: [String: Any]) -> Bool {
            let keys = Set(object.keys)
            guard ids.isSubset(of: keys), keys.isSubset(of: ids.union(optionalIDs).union(optional)) else { return false }
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
        "api/club/join-request/reject": .init(ids: ["clubId", "memberId"], optional: ["reviewReason"])
    ]
    static func positive(_ value: Any?) -> Bool {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return false }
        let double = number.doubleValue
        return double >= 1 && double.rounded() == double && double <= 9_007_199_254_740_991
    }
}
