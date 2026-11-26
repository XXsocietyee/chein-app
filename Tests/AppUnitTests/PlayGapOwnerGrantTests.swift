import XCTest
@testable import Questify

final class PlayGapOwnerGrantTests: XCTestCase {
    func testSwitchesStayClosedOnProduction() {
        XCTAssertFalse(ReviewedAreaSwitch.merchantWrites(host: "www.chengyinhub.com"))
        XCTAssertTrue(ReviewedAreaSwitch.moneyPayments(host: "WWW.CHENGYINHUB.COM"))
        XCTAssertFalse(ReviewedAreaSwitch.moneyPayments(host: nil))
        XCTAssertFalse(ReviewedAreaSwitch.merchantWritesBlocked(host: nil))
        XCTAssertTrue(ReviewedAreaSwitch.merchantWritesBlocked(host: "www.chengyinhub.com"))
        XCTAssertTrue(ReviewedAreaSwitch.moneyPayments(host: "api.example.test"))
    }

    func testGrantDoesNotRaiseTheContractBaseline() {
        XCTAssertEqual(ChinaReviewedRouteCapability.missingCount, 12)  // 2026-11-13 backend-final-gaps: only the 12 backend-closed workshop stubs stay missing (each row says why)
        XCTAssertEqual(ChinaReviewedRouteCapability.wiredPatternCount, 679)
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/native/home"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/native/home/return/restore"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/npc/chat/delete"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/city-game/action-budget/command"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/sms/send"))
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/city-game/merchant/operations/intent"))
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/marketing/product/order"))
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/marketing/product/pay"))
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/login"))
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/user/sms/send"))
        let base = URL(string: "https://www.chengyinhub.com/prod-api/")!
        var allowed = URLRequest(url: base.appendingPathComponent("api/native/device/status"))
        XCTAssertTrue(ReviewedPlayGapRoute.accepts(allowed, baseURL: base))
        allowed = URLRequest(url: base.appendingPathComponent("api/marketing/product/order"))
        XCTAssertFalse(ReviewedPlayGapRoute.accepts(allowed, baseURL: base))
    }

    func testProductNamesUseAnEmDashWhenMissing() {
        let payload = PlayWireValue.object(["data": .array([.object(["productId": .integer(4), "productName": .string("  ")])])])
        XCTAssertEqual(PlayGapProduct.parse(payload).first?.name, "—")
    }

    /// WP-02: the audit and guard appeal routes are on the play grant in both lists; the money-area routes are not.
    @MainActor func testCreatorTailRoutesAreGrantedInBothListsAndMoneyStaysOff() {
        for path in PlayerGapService.creatorTailPaths {
            XCTAssertTrue(ReviewedProductionGateLeases.playPaths.contains(path), path)
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path), path)
        }
        for gated in [PlayerGapService.editionEmptyReasonPath, "api/club/lead/release-station", "api/club/lead/unlock-chapter-receipt"] {
            XCTAssertFalse(ReviewedProductionGateLeases.playPaths.contains(gated), gated)
        }
        XCTAssertTrue(ReviewedAreaSwitch.moneyPayments(apiHost: "www.chengyinhub.com"))
        XCTAssertFalse(ReviewedAreaSwitch.passwordLogin(apiHost: "www.chengyinhub.com"))
    }
}
