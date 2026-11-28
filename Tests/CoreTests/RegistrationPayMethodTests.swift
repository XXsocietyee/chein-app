#if DEBUG
import XCTest
@testable import QuestifyCore

/// Sweep 04:50 (mp-activity P1): the "Pay with" row offers the market's channels, default first.
final class RegistrationPayMethodTests: XCTestCase {
    func testChinaOffersWeChatPayFirstThenAlipay() {
        // Pin updated (owner check 11-28 05:35): Alipay is offered only once its pay route is ready.
        XCTAssertEqual(RegistrationPayMethod.options(market: .china, applePayAvailable: true, alipayReady: true), [.wechatPay, .alipay])
        XCTAssertEqual(RegistrationPayMethod.options(market: .china, applePayAvailable: true, alipayReady: false), [.wechatPay])
        XCTAssertTrue(RegistrationPayMethod.showsAlipayComingSoon(market: .china, alipayReady: false))
        XCTAssertFalse(RegistrationPayMethod.showsAlipayComingSoon(market: .china, alipayReady: true))
        XCTAssertFalse(RegistrationPayMethod.showsAlipayComingSoon(market: .unitedStates, alipayReady: false))
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

    func testPayTitleNamesMethodAndTotal() {
        let title = RegistrationPayMethod.wechatPay.payTitle(amount: "¥12.50")
        XCTAssertEqual(title.zh, "微信支付 ¥12.50")
        XCTAssertEqual(title.en, "Pay ¥12.50 with WeChat Pay")
        XCTAssertEqual(RegistrationPayMethod.card.payTitle(amount: "$5.00").en, "Pay $5.00 by card")
    }

    func testEffectiveFallsBackToMarketDefault() {
        XCTAssertEqual(RegistrationPayMethod.effective(nil, market: .china, applePayAvailable: true), .wechatPay)
        XCTAssertEqual(RegistrationPayMethod.effective(.alipay, market: .china, applePayAvailable: true), .wechatPay)
        XCTAssertEqual(RegistrationPayMethod.effective(.card, market: .unitedStates, applePayAvailable: true), .card)
    }
}
#endif
