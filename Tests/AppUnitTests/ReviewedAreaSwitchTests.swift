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

    /// External-game Ed25519 key: pinned per API host on first use; a different key for that host is refused.
    @MainActor func testExternalGameSigningKeyIsPinnedPerEnvironment() throws {
        let suite = "pin-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite)); defer { defaults.removePersistentDomain(forName: suite) }
        let first = Data(repeating: 1, count: 32), rotated = Data(repeating: 2, count: 32)
        XCTAssertEqual(ExternalGameReviewModel.pin(first, host: "8120.example.test", defaults: defaults), first)
        XCTAssertEqual(ExternalGameReviewModel.pin(first, host: "8120.EXAMPLE.test", defaults: defaults), first)
        XCTAssertNil(ExternalGameReviewModel.pin(rotated, host: "8120.example.test", defaults: defaults))
        XCTAssertEqual(ExternalGameReviewModel.pin(rotated, host: "other.example.test", defaults: defaults), rotated)
        XCTAssertNil(ExternalGameReviewModel.pin(first, host: nil, defaults: defaults))
        XCTAssertNil(ExternalGameReviewModel.pin(Data(count: 16), host: "x.example.test", defaults: defaults))
    }
}
