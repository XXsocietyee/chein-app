import XCTest
@testable import Questify

final class MerchantOpsWp03GateTests: XCTestCase {
    func testProductionHostKeepsMoneyAndMerchantWritesClosed() {
        let production = ReviewedAreaSwitch.productionAPIHost
        XCTAssertTrue(ReviewedAreaSwitch.moneyPayments(apiHost: production, testOrDebug: true))
        XCTAssertTrue(ReviewedAreaSwitch.moneyPayments(apiHost: production, testOrDebug: false))
        XCTAssertFalse(ReviewedAreaSwitch.merchantWrites(apiHost: "WWW.CHENGYINHUB.COM", testOrDebug: true))
        XCTAssertTrue(ReviewedAreaSwitch.payout(apiHost: production, testOrDebug: true))
        XCTAssertFalse(ReviewedAreaSwitch.passwordLogin(apiHost: production, testOrDebug: true))
        XCTAssertFalse(ReviewedAreaSwitch.moneyPayments(apiHost: nil, testOrDebug: true))
        XCTAssertTrue(ReviewedAreaSwitch.moneyPayments(apiHost: "8120.example.test", testOrDebug: true))
        XCTAssertTrue(ReviewedAreaSwitch.merchantWrites(apiHost: "8120.example.test", testOrDebug: true))
        XCTAssertTrue(MerchantOpsWp03Lease.admits(relative: MerchantOpsWp03Catalog.commerceOrder, method: "POST", host: production))
        XCTAssertFalse(MerchantOpsWp03Lease.admits(relative: MerchantOpsWp03Catalog.claimsSubmit, method: "POST", host: production))
        XCTAssertFalse(MerchantOpsWp03Lease.admits(relative: MerchantOpsWp03Catalog.shareCode, method: "POST", host: production))
        XCTAssertFalse(MerchantOpsWp03Lease.admits(relative: MerchantOpsWp03Catalog.inviteRevoke, method: "POST", host: production))
        XCTAssertTrue(MerchantOpsWp03Lease.admits(relative: MerchantOpsWp03Catalog.npcReview, method: "GET", host: production))
        XCTAssertTrue(MerchantOpsWp03Lease.admits(relative: MerchantOpsWp03Catalog.couponSummary, method: "POST", host: production))
        XCTAssertTrue(ReleaseMoneyWriteSwitch.blocks("/api/merchant/commerce/order"))
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/merchant/commerce/order"))
    }
}
