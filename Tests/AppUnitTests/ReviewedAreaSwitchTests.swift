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
}
