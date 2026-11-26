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
        "api/club/event-ops/roster", "api/club/topic-setting/detail", "api/club/access/me", "api/club/members"
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
        // `api/club/members` is a review read (ClubGovernanceRead.members), not a write: admit only its exact
        // `{"clubId": positive}` shape, as ClubPublicRosterRoute does, so an extra key (e.g. `amount`) stays closed.
        if relative == ClubGovernanceRead.members.path {
            guard Set(object.keys) == ["clubId"], let id = object["clubId"] as? Int, id > 0 else { return false }
        }
        return true
    }
}
