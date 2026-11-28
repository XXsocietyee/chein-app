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

    /// ADA t5-baoming: a missing consent does not become the button title. A paid quote stays a pay label.
    func testBlockedCheckoutKeepsThePayLabelAndPutsConsentInTheFootnote() {
        let amount = Decimal(string: "12.50")
        XCTAssertEqual(RegistrationCheckoutPayUX.submit(hasTicket: true, ticketPrice: amount, quoteEnabled: true,
                                                        quoteReceived: true, quotePayAmount: amount, paymentsOpen: true), .pay)
        XCTAssertEqual(RegistrationCheckoutPayUX.footnote(.missingConsent), .sharingConsent)
        XCTAssertEqual(RegistrationCheckoutPayUX.footnote(.invalidForm), .chooseParticipant)
        XCTAssertEqual(RegistrationCheckoutPayUX.footnote(.signupClosed), .signupClosed)
        XCTAssertEqual(RegistrationCheckoutPayUX.footnote(.paymentRequired), .blockReason)
        XCTAssertNil(RegistrationCheckoutPayUX.footnote(nil))
        XCTAssertTrue(RegistrationCheckoutPayUX.showsPayWithRow(ticketPrice: amount, quoteEnabled: true,
                                                                quoteReceived: true, quotePayAmount: amount))
    }

    /// A quote that brings the amount due to zero is a free confirmation. The Pay-with row hides.
    func testFreeQuoteHidesPayWithAndConfirmsSignup() {
        let listed = Decimal(string: "12.50")
        XCTAssertEqual(RegistrationCheckoutPayUX.submit(hasTicket: true, ticketPrice: listed, quoteEnabled: true,
                                                        quoteReceived: true, quotePayAmount: .zero, paymentsOpen: true), .confirmSignup)
        XCTAssertFalse(RegistrationCheckoutPayUX.showsPayWithRow(ticketPrice: listed, quoteEnabled: true,
                                                                 quoteReceived: true, quotePayAmount: .zero))
        XCTAssertEqual(RegistrationCheckoutPayUX.payWithRowPrice(ticketPrice: listed, quoteEnabled: true,
                                                                 quoteReceived: true, quotePayAmount: .zero), .zero)
    }

    func testPricedTicketBeforeAQuoteAsksToConfirmThePrice() {
        let listed = Decimal(string: "12.50")
        XCTAssertEqual(RegistrationCheckoutPayUX.submit(hasTicket: true, ticketPrice: listed, quoteEnabled: true,
                                                        quoteReceived: false, quotePayAmount: nil, paymentsOpen: true), .confirmPriceAndPay)
        XCTAssertEqual(RegistrationCheckoutPayUX.payWithRowPrice(ticketPrice: listed, quoteEnabled: true,
                                                                 quoteReceived: false, quotePayAmount: nil), listed)
    }

    func testFreeTicketAndMissingTicket() {
        XCTAssertEqual(RegistrationCheckoutPayUX.submit(hasTicket: true, ticketPrice: .zero, quoteEnabled: false,
                                                        quoteReceived: false, quotePayAmount: nil, paymentsOpen: true), .confirmSignup)
        XCTAssertNil(RegistrationCheckoutPayUX.submit(hasTicket: false, ticketPrice: nil, quoteEnabled: true,
                                                      quoteReceived: false, quotePayAmount: nil, paymentsOpen: true))
    }

    /// A USD quote's button follows the channels the server listed. Apple Pay is not offered when the list is card only.
    /// China still defaults to WeChat Pay. This does not turn the payment switch on.
    func testStripeButtonFollowsTheQuoteChannels() {
        XCTAssertEqual(RegistrationPayMethod.effective(selection: .applePay, market: .unitedStates, applePayAvailable: true,
                                                       alipayOffered: false, paymentChannels: ["APP_STRIPE"]), .card)
        XCTAssertEqual(RegistrationPayMethod.effective(selection: nil, market: .unitedStates, applePayAvailable: true,
                                                       alipayOffered: false, paymentChannels: ["APPLE_PAY", "APP_STRIPE"]), .applePay)
        XCTAssertEqual(RegistrationPayMethod.effective(selection: nil, market: .unitedStates, applePayAvailable: false,
                                                       alipayOffered: false, paymentChannels: ["APPLE_PAY", "APP_STRIPE"]), .card)
        XCTAssertEqual(RegistrationPayMethod.effective(selection: nil, market: .china, applePayAvailable: true,
                                                       alipayOffered: false, paymentChannels: ["APP"]), .wechatPay)
    }

    /// The payment switch stays off. The button does not pretend the player can pay.
    func testClosedPaymentSwitchDoesNotLabelTheButtonAsPay() {
        let amount = Decimal(string: "12.50")
        XCTAssertEqual(RegistrationCheckoutPayUX.submit(hasTicket: true, ticketPrice: amount, quoteEnabled: true,
                                                        quoteReceived: true, quotePayAmount: amount, paymentsOpen: false), .reviewKey)
    }

    /// Gap #9: a USD re-pay follows the offered Stripe method. A CNY order does not leave the China pay section.
    func testOrderRepayChoiceFollowsTheOrderCurrency() {
        XCTAssertEqual(OrderRepayChoice.method(currency: "USD", paymentChannels: ["APPLE_PAY", "APP_STRIPE"],
                                               selection: .card, applePayAvailable: true), .card)
        XCTAssertEqual(OrderRepayChoice.method(currency: "USD", paymentChannels: ["APPLE_PAY", "APP_STRIPE"],
                                               selection: .applePay, applePayAvailable: true), .applePay)
        XCTAssertNil(OrderRepayChoice.method(currency: "USD", paymentChannels: ["APPLE_PAY"],
                                             selection: .card, applePayAvailable: true))
        XCTAssertNil(OrderRepayChoice.method(currency: "USD", paymentChannels: ["APPLE_PAY"],
                                             selection: .applePay, applePayAvailable: false))
        XCTAssertNil(OrderRepayChoice.method(currency: "USD", paymentChannels: ["APPLE_PAY", "APP_STRIPE"],
                                             selection: nil, applePayAvailable: true))
        XCTAssertNil(OrderRepayChoice.method(currency: "CNY", paymentChannels: ["APP", "APP_ALIPAY"],
                                             selection: .alipay, applePayAvailable: false))
    }
}
#endif
