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
