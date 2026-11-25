import XCTest
@testable import Questify

/// WP-01 / WP-05. The app's area switch decides the Core money switch: the production host keeps every payout and
/// money write closed; a TEST/DEBUG host opens them (owner 2026-11-13). Virtual goods never open.
@MainActor final class PayoutReceiverAppTests: XCTestCase {
    override func tearDown() { ReleaseMoneyWriteSwitch.testDerivation = nil; super.tearDown() }

    /// Owner 2026-11-14: receiver status and the payout-account read are status reads, admitted on every host.
    private let statusReads = ["/api/club/personal-receiver/status", "/api/merchant/payout-account",
                               "/api/club/settlement/mine"]
    private let payoutPaths = ["/api/club/personal-receiver/bind", "/api/club/personal-receiver/unbind",
                               "/api/club-direct-merchant/club", "/api/club-direct-merchant/merchant"]
    private let moneyWrites = ["/api/registration/pay", "/api/registration/pay/app", "/api/pay/create", "/api/asset/withdraw",
                               "/api/withdrawal/create", "/api/fund/preflight/bank-withdrawal", "/api/fund/preflight/7/confirm"]

    func testProductionHostKeepsEveryMoneyRouteClosed() {
        ReviewedAreaSwitch.installReleaseMoneyDerivation(host: ReviewedAreaSwitch.productionAPIHost)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        for path in payoutPaths + moneyWrites + ["/api/registration/payment-readiness", "/api/cart/add"] {
            XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall(path), path)
        }
        ReviewedAreaSwitch.installReleaseMoneyDerivation(host: nil)
        for path in payoutPaths + moneyWrites { XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall(path), path) }
        for path in statusReads { XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall(path), path) }
    }

    func testTestHostOpensPayoutAndMoneyButNotVirtualGoods() {
        ReviewedAreaSwitch.installReleaseMoneyDerivation(host: "8120-agqyfqxs5vwolymtoibzq3fhde.instabox.tech")
        for path in payoutPaths + moneyWrites + ["/api/registration/payment-readiness"] {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall(path), path)
        }
        for path in ["/api/cart/add", "/api/cart/order/settlement", "/api/mod-commerce/orders", "/api/login"] {
            XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall(path), path)
        }
    }

    func testAppLeaseNamesEveryPayoutRouteOnce() {
        XCTAssertTrue(PayoutReceiverRouteGrant.readPaths.isDisjoint(with: PayoutReceiverRouteGrant.moneyPaths))
        for route in PayoutReceiverRoute.allCases {
            XCTAssertTrue(PayoutReceiverRouteGrant.admits(route), route.rawValue)
            XCTAssertEqual(PayoutReceiverRouteGrant.moneyPaths.contains(route.rawValue), route.isPayout, route.rawValue)
            if route == .receiverStatus || route == .merchantPayoutAccount || route == .settlementMine {
                // Status reads and the settlement mine list, granted unconditionally. Bind stays a payout write.
                XCTAssertTrue(ChinaReviewedRouteCapability.ownerDecisionGuardGrant.contains("/" + route.rawValue), route.rawValue)
                XCTAssertNil(ChinaReviewedRouteCapability.moneyAreaOwnerGrant["/" + route.rawValue], route.rawValue)
            } else if route != .settlementSummary {
                XCTAssertNotNil(ChinaReviewedRouteCapability.moneyAreaOwnerGrant["/" + route.rawValue], route.rawValue)
            }
        }
        XCTAssertEqual(ChinaReviewedRouteCapability.moneyAreaOwnerGrant["/api/registration/payment-readiness"], .payment)
    }

    func testMiniProgramPayoutPagesParseToRoutes() {
        XCTAssertEqual(MPParityRoute(miniProgramPath: "pages/club/payout-receiver/index", query: ["clubId": "7001"]),
                       .clubPayoutReceiver(clubID: 7001, mine: false))
        XCTAssertEqual(MPParityRoute(miniProgramPath: "/pages/club/payout-receiver/index", query: ["mine": "1"]),
                       .clubPayoutReceiver(clubID: nil, mine: true))
        XCTAssertNil(MPParityRoute(miniProgramPath: "pages/club/payout-receiver/index", query: [:]))
        XCTAssertEqual(MPParityRoute(miniProgramPath: "pages/merchant/payout-account/index", query: [:]), .merchantPayoutAccount)
        XCTAssertEqual(MPParityRoute(miniProgramPath: "pages/club/settlement/index", query: ["clubId": "7001", "personal": "1"]),
                       .clubSettlement(clubID: 7001, mine: false, personal: true))
        XCTAssertEqual(MPParityRoute(miniProgramPath: "pages/club/settlement/index", query: ["mine": "1"]),
                       .clubSettlement(clubID: nil, mine: true, personal: false))
        XCTAssertNil(MPParityRoute(miniProgramPath: "pages/club/settlement/index", query: ["clubId": "0"]))
    }
}
