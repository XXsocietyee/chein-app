import Foundation

/// Owner MP-first rule for club writes the mini-program already sends. The server checks the role.
/// Pay, refund execution, payout, withdrawal, paid orders, quote, registration create, and pricing
/// confirm are not built or sent. Settlement mine stays `POST {}` on its own route.
enum MPFirstClubApprovals {
    private static var rosterRevisions: [String: UUID] = [:]

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
        "api/publisher/identity/status", "api/club/roles/list"
    ]
    private static let moneyKeys: Set<String> = [
        "payAmount", "payChannel", "withdrawAmount", "refundId", "payoutAccount", "quoteId", "memberDiscountPrice"
    ]

    static func accepts(_ request: URLRequest, baseURL: URL, token: String?) -> Bool {
        guard let token, AuthRequestBuilder.isValidToken(token),
              request.httpMethod == "POST", request.httpBodyStream == nil,
              request.value(forHTTPHeaderField: "Content-Type") == "application/json",
              request.value(forHTTPHeaderField: "Authorization")?.utf8.elementsEqual(token.utf8) == true,
              let url = request.url, url.fragment == nil, url.user == nil, url.password == nil, url.query == nil,
              url.scheme == baseURL.scheme, url.host == baseURL.host, url.port == baseURL.port,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false), parts.query == nil,
              let relative = MPFirstMerchantWriteRoute.relativePath(parts.path, base: baseURL.path),
              !relative.contains("pay") && !relative.contains("refund") && !relative.contains("payout")
                && !relative.contains("withdraw") && !relative.contains("quote") && !relative.contains("registration")
                && !relative.contains("pricing") && !relative.contains("settlement"),
              governancePaths.contains(relative) || operationPaths.contains(relative),
              let body = request.httpBody, body.count < 65_536,
              let parsed = try? JSONSerialization.jsonObject(with: body),
              let object = parsed as? [String: Any],
              moneyKeys.isDisjoint(with: object.keys) else { return false }
        return true
    }
}
