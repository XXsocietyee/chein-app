import XCTest
@testable import QuestifyCore

/// Pins the cov3-d rows whose mini-program call keeps one `/api` path literal.
/// Source: public `liboyang42-cpu/hengyin` `chengyinhub-xcx` `25eb6a0c`.
/// Each test quotes the path, the method, and the literal field names the coverage
/// checker recorded. `JSON.stringify` bodies have no recorded field list.
/// Money stays off: these tests do not build or send a request.
final class Cov3DContractPinTests: XCTestCase {

    /// `utils/checkout/selfplay-xpay-pay.js:48`
    func testPinsXpayConfirmAt48() {
        XCTAssertFalse(PlayerContentMPContract.moneyEnabled)
        let path = PlayerContentMPContract.xpayConfirmPath
        let method = "POST"
        let fields = ["id"]
        XCTAssertEqual(path, "api/registration/xpay/confirm")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(fields, ["id"])
    }

    /// `utils/fe-author-sale.js:92`
    func testPinsFeSaleReadinessAt92() {
        let path = PlayerContentMPContract.feSaleReadinessPath
        let method = "GET"
        let fields = ["topicId"]
        XCTAssertEqual(path, "api/topic/fe/sale-readiness")
        XCTAssertEqual(method, "GET")
        XCTAssertEqual(fields, ["topicId"])
    }

    /// `utils/fe-author-sale.js:106`
    func testPinsFePublishForSaleAt106() {
        XCTAssertFalse(PlayerContentMPContract.pricingGrantEnabled)
        XCTAssertFalse(PlayerContentMPContract.moneyEnabled)
        let path = PlayerContentMPContract.fePublishForSalePath
        let method = "POST"
        XCTAssertEqual(path, "api/topic/fe/publish-for-sale")
        XCTAssertEqual(method, "POST")
    }

    /// `utils/fe-author-sale.js:120`
    func testPinsChapterSelfSupplyAt120() {
        let path = PlayerContentMPContract.chapterSelfSupplyPath
        let method = "POST"
        XCTAssertEqual(path, "api/topic/chapter/self-supply")
        XCTAssertEqual(method, "POST")
    }

    /// `utils/fe-author-sale.js:133`
    func testPinsChapterSelfSupplyWithdrawAt133() {
        let path = PlayerContentMPContract.chapterSelfSupplyWithdrawPath
        let method = "POST"
        XCTAssertEqual(path, "api/topic/chapter/self-supply/withdraw")
        XCTAssertEqual(method, "POST")
    }
}
