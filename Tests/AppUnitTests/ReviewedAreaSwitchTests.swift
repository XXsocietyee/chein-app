import XCTest
@testable import Questify

final class ReviewedAreaSwitchTests: XCTestCase {
    func testMoneySwitchesOpenOnlyForATestBuildOffTheProductionHost() {
        let testHost = "8120.example.test"
        XCTAssertTrue(ReviewedAreaSwitch.payout(apiHost: testHost, testOrDebug: true))
        XCTAssertTrue(ReviewedAreaSwitch.moneyPayments(apiHost: testHost, testOrDebug: true))
        XCTAssertTrue(ReviewedAreaSwitch.merchantWrites(apiHost: testHost, testOrDebug: true))
        XCTAssertTrue(ReviewedAreaSwitch.passwordLogin(apiHost: testHost, testOrDebug: true))
        XCTAssertFalse(ReviewedAreaSwitch.payout(apiHost: testHost, testOrDebug: false))
        XCTAssertFalse(ReviewedAreaSwitch.moneyPayments(apiHost: ReviewedAreaSwitch.productionAPIHost, testOrDebug: true))
        XCTAssertFalse(ReviewedAreaSwitch.merchantWrites(apiHost: "WWW.CHENGYINHUB.COM", testOrDebug: true))
        XCTAssertFalse(ReviewedAreaSwitch.passwordLogin(apiHost: nil, testOrDebug: true))
        XCTAssertFalse(ReviewedAreaSwitch.payout(apiHost: "  ", testOrDebug: true))
    }

    func testExternalGamesFollowTheHostOnly() {
        XCTAssertTrue(ReviewedAreaSwitch.externalGames(apiHost: "8120.example.test"))
        XCTAssertFalse(ReviewedAreaSwitch.externalGames(apiHost: ReviewedAreaSwitch.productionAPIHost))
        XCTAssertFalse(ReviewedAreaSwitch.externalGames(apiHost: nil))
        XCTAssertFalse(ReviewedAreaSwitch.externalGames(apiHost: ""))
    }

    /// Owner 2026-11-13: Core money writes follow the area switch in DEBUG/TEST builds. Production host and no host stay off;
    /// virtual goods stay off for every host. Release builds keep the Core constants false (compiled out, checked in source).
    func testDebugMoneyWriteSwitchFollowsTheHostAndRestoresClosed() {
        defer { ReleaseMoneyWriteSwitch.testDerivation = nil }
        ReviewedAreaSwitch.installReleaseMoneyDerivation(host: "8120.example.test")
        XCTAssertTrue(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertTrue(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertTrue(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.virtualGoodsEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.blocks("/api/pay/create"))
        ReviewedAreaSwitch.installReleaseMoneyDerivation(host: ReviewedAreaSwitch.productionAPIHost)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertTrue(ReleaseMoneyWriteSwitch.blocks("/api/pay/create"))
        ReviewedAreaSwitch.installReleaseMoneyDerivation(host: nil)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        ReleaseMoneyWriteSwitch.testDerivation = nil
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
    }
}
