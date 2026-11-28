#if DEBUG
import XCTest
@testable import QuestifyCore

/// Sweep 04:50 (mp-activity P1): the "Pay with" row offers the market's channels, default first.
final class RegistrationPayMethodTests: XCTestCase {
    func testChinaOffersWeChatPayFirstThenAlipay() {
        XCTAssertEqual(RegistrationPayMethod.options(market: .china, applePayAvailable: true), [.wechatPay, .alipay])
        XCTAssertEqual(RegistrationPayMethod.defaultMethod(market: nil, applePayAvailable: false), .wechatPay)
    }

    func testUnitedStatesOffersApplePayFirstWhenAvailable() {
        XCTAssertEqual(RegistrationPayMethod.options(market: .unitedStates, applePayAvailable: true), [.applePay, .card])
        XCTAssertEqual(RegistrationPayMethod.defaultMethod(market: .unitedStates, applePayAvailable: true), .applePay)
    }

    func testUnitedStatesWithoutApplePayOffersCardOnly() {
        XCTAssertEqual(RegistrationPayMethod.options(market: .unitedStates, applePayAvailable: false), [.card])
    }

    func testOfficialNames() {
        XCTAssertEqual(RegistrationPayMethod.wechatPay.names.zh, "微信支付")
        XCTAssertEqual(RegistrationPayMethod.alipay.names.en, "Alipay")
    }
}
#endif
