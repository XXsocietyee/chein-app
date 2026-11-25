import SwiftUI

// fix/r3-merchant-coop-a round 3: MP deep links to half-a merchant pages that fell through to 该页面暂未开放
// (docs/mp-gap/flows-g2.md MISSING-ROUTE rows, merchant-coop). Every screen here is the existing native screen the
// workbench pushes; these hosts only bind it to the session. Nothing here writes; server permissions still apply.

/// `pages/merchant/marketing/index` and `pages/merchant/marketing/ai-insight/index` (initial surface `.insight`).
/// Same links as the merchant 营销 tab (HomeSearchTabParityViews). Recommendation targets need the workbench's
/// origin, so a deep-linked page opens suggestions only through the 营销 tab (origin nil keeps them stale-guarded).
@MainActor struct SessionMerchantMarketingLinkScreen: View {
    @ObservedObject var session: AppSession
    var initialSurface: MerchantMarketingCoordinator.Surface = .dashboard

    var body: some View {
        MerchantMarketingView(model: session.merchantMarketingCoordinator, initialSurface: initialSurface)
            .environment(\.merchantMarketingLinks, MerchantMarketingLinks(
                activityPublisher: { AnyView(SessionActivityPublishingDestination().environmentObject(session)) },
                projects: {
                    AnyView(MerchantProjectsView(reader: session, contentService: session.merchantContentService,
                                                 workspaceReadFactory: session.merchantProjectWorkspaceReadFactory))
                },
                coupons: { AnyView(SessionCouponManagementView()) },
                coopCenter: { session.merchantCoopCenterDestination(initialTab: .plaza) }))
            .environmentObject(session)
            .cyPushedChrome(domain: .merchant)
    }
}

/// `pages/merchant/predict/index`. No prediction reader (signed out / not configured) → the inbox's own sign-in state
/// is unreachable, so show the shared 登录后查看预测 page instead.
@MainActor struct SessionMerchantPredictionLinkScreen: View {
    @ObservedObject var session: AppSession

    var body: some View {
        Group {
            if let reader = session.merchantPredictionReader {
                MerchantPredictionInboxView(reader: reader.isolatedReader())
            } else {
                MerchantSignInState(title: "merchant.predict.signIn", identifier: "merchant.predict.link.signIn")
            }
        }
        .cyPushedChrome(domain: .merchant)
    }
}
