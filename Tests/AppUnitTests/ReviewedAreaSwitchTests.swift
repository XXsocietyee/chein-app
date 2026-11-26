import XCTest
#if canImport(QuestifyCore)
import QuestifyCore
#endif
@testable import Questify

final class ReviewedAreaSwitchTests: XCTestCase {
    func testMoneySwitchesOpenOnlyForATestBuildOffTheProductionHost() {
        let testHost = "8120.example.test"
        let production = ReviewedAreaSwitch.productionAPIHost
        XCTAssertTrue(ReviewedAreaSwitch.payout(apiHost: testHost, testOrDebug: true))
        XCTAssertTrue(ReviewedAreaSwitch.moneyPayments(apiHost: testHost, testOrDebug: true))
        XCTAssertTrue(ReviewedAreaSwitch.merchantWrites(apiHost: testHost, testOrDebug: true))
        XCTAssertTrue(ReviewedAreaSwitch.passwordLogin(apiHost: testHost, testOrDebug: true))
        XCTAssertTrue(ReviewedAreaSwitch.payout(apiHost: testHost, testOrDebug: false))
        XCTAssertTrue(ReviewedAreaSwitch.moneyPayments(apiHost: production, testOrDebug: true))
        XCTAssertTrue(ReviewedAreaSwitch.moneyPayments(apiHost: production, testOrDebug: false))
        XCTAssertTrue(ReviewedAreaSwitch.payout(apiHost: "WWW.CHENGYINHUB.COM", testOrDebug: false))
        XCTAssertFalse(ReviewedAreaSwitch.merchantWrites(apiHost: "WWW.CHENGYINHUB.COM", testOrDebug: true))
        XCTAssertFalse(ReviewedAreaSwitch.passwordLogin(apiHost: production, testOrDebug: true))
        XCTAssertFalse(ReviewedAreaSwitch.passwordLogin(apiHost: nil, testOrDebug: true))
        XCTAssertFalse(ReviewedAreaSwitch.payout(apiHost: "  ", testOrDebug: true))
        XCTAssertFalse(ReviewedAreaSwitch.moneyPayments(apiHost: nil, testOrDebug: true))
    }

    func testExternalGamesFollowTheHostOnly() {
        XCTAssertTrue(ReviewedAreaSwitch.externalGames(apiHost: "8120.example.test"))
        XCTAssertFalse(ReviewedAreaSwitch.externalGames(apiHost: ReviewedAreaSwitch.productionAPIHost))
        XCTAssertFalse(ReviewedAreaSwitch.externalGames(apiHost: nil))
        XCTAssertFalse(ReviewedAreaSwitch.externalGames(apiHost: ""))
    }

    /// Owner 2026-11-25: a test host and www.chengyinhub.com open payment, refund, payout, and withdrawal.
    /// Virtual goods stay off. A missing host, and a cleared derivation, stay off.
    func testDebugMoneyWriteSwitchFollowsTheHostAndRestoresClosed() {
        defer { ReleaseMoneyWriteSwitch.testDerivation = nil }
        ReviewedAreaSwitch.installReleaseMoneyDerivation(host: "8120.example.test")
        XCTAssertTrue(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertTrue(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertTrue(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertTrue(ReleaseMoneyWriteSwitch.refundEnabled)
        XCTAssertTrue(ReleaseMoneyWriteSwitch.hostCancelRefundEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.virtualGoodsEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.blocks("/api/pay/create"))
        ReviewedAreaSwitch.installReleaseMoneyDerivation(host: ReviewedAreaSwitch.productionAPIHost)
        XCTAssertTrue(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertTrue(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertTrue(ReleaseMoneyWriteSwitch.refundEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.virtualGoodsEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.blocks("/api/pay/create"))
        XCTAssertTrue(ReleaseMoneyWriteSwitch.blocks("/api/cart/add"))
        ReviewedAreaSwitch.installReleaseMoneyDerivation(host: nil)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.refundEnabled)
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

    func testProductionHostDoesNotPresentAClosedFeatureAsPayment() {
        let host = ReviewedAreaSwitch.productionAPIHost
        let money = ReviewedAreaSwitch.moneyPayments(apiHost: host, testOrDebug: true)
        let payout = ReviewedAreaSwitch.payout(apiHost: host, testOrDebug: true)
        let writes = ReviewedAreaSwitch.merchantWrites(apiHost: host, testOrDebug: true)
        let password = ReviewedAreaSwitch.passwordLogin(apiHost: host, testOrDebug: true)
        XCTAssertTrue(money)
        XCTAssertTrue(payout)
        XCTAssertFalse(writes)
        XCTAssertFalse(password)
        XCTAssertFalse(BackendErrorCatalog.paymentSucceeded(
            code: "FEATURE_CLOSED", moneyPaymentsOpen: money, payoutOpen: payout, merchantWritesOpen: writes, passwordLoginOpen: password))
        XCTAssertFalse(BackendErrorCatalog.paymentSucceeded(
            code: "CASH_CLOSED", moneyPaymentsOpen: money, payoutOpen: payout, merchantWritesOpen: writes, passwordLoginOpen: password))
    }
}
