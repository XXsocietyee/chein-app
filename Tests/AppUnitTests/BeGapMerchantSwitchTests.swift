import XCTest
#if canImport(QuestifyApp)
@testable import QuestifyApp
#if canImport(QuestifyCore)
import QuestifyCore
#elseif canImport(Core)
import Core
#endif
#else
@testable import Questify
#endif

final class BeGapMerchantSwitchTests: XCTestCase {
    func testDebugNonProductionHostOpensTheFourSwitches() {
        let open = ReviewedAreaSwitch.admits(debug: true, apiBaseURL: "http://127.0.0.1:8099/")
        XCTAssertTrue(open.moneyPayments)
        XCTAssertTrue(open.payout)
        XCTAssertTrue(open.merchantWrites)
        XCTAssertTrue(open.passwordLogin)
        let blank = ReviewedAreaSwitch.admits(debug: true, apiBaseURL: "")
        XCTAssertTrue(blank.merchantWrites)
    }

    func testReleaseAndProductionHostStayClosed() {
        let production = ReviewedAreaSwitch.admits(debug: true, apiBaseURL: "https://www.chengyinhub.com/prod-api/")
        XCTAssertTrue(production.moneyPayments)
        XCTAssertTrue(production.payout)
        XCTAssertFalse(production.merchantWrites)
        XCTAssertFalse(production.passwordLogin)
        let release = ReviewedAreaSwitch.admits(debug: false, apiBaseURL: "http://127.0.0.1:8099/")
        XCTAssertTrue(release.moneyPayments)
        XCTAssertTrue(release.payout)
        XCTAssertFalse(release.merchantWrites)
        XCTAssertFalse(release.passwordLogin)
        let missing = ReviewedAreaSwitch.admits(debug: false, apiBaseURL: "")
        XCTAssertFalse(missing.moneyPayments)
        XCTAssertFalse(missing.payout)
    }

    func testOwnerGrantAdmitsMerchantReadsAndStillRefusesMoney() {
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/merchant/insight"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/merchant/authoring/drafts/9"))
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/pay/create"))
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/asset/withdraw"))
        XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: "/api/pay/create"), .missing)
    }
}
