import XCTest
@testable import QuestifyCore

/// US launch r1 (lane app-pay): Stripe / Apple Pay contract for USD orders. No network.
final class StripePayContractsTests: XCTestCase {
    private final class Recorder: HTTPTransport, @unchecked Sendable {
        var requests: [URLRequest] = []
        let reply: (Data, Int)
        init(_ json: String, status: Int = 200) { reply = (Data(json.utf8), status) }
        func send(_ request: URLRequest) async throws -> (Data, Int) { requests.append(request); return reply }
    }

    private let api = try! APIConfiguration(baseURL: URL(string: "https://www.chengyinhub.com/prod-api/")!)

    override func tearDown() { ReleaseMoneyWriteSwitch.testDerivation = nil }

    func testStripeRoutesArePaymentKindAndFollowTheSwitch() {
        ReleaseMoneyWriteSwitch.testDerivation = nil
        for route in StripePayRoute.allCases {
            XCTAssertEqual(ReleaseMoneyWriteSwitch.kind(for: route.routePath), .payment, route.rawValue)
            XCTAssertTrue(ReleaseMoneyWriteSwitch.blocks(route.routePath))
            XCTAssertEqual(ChinaReviewedRouteCapability.moneyAreaOwnerGrant[route.routePath], .payment)
        }
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .payment }
        for route in StripePayRoute.allCases { XCTAssertTrue(ReleaseMoneyWriteSwitch.opens(route.routePath)) }
    }

    func testEligibilityIsUSMarketUSDWithAStripeChannelOnly() {
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .payment }
        XCTAssertTrue(StripePayEligibility.applies(market: .unitedStates, currency: "USD", paymentChannels: ["APPLE_PAY"]))
        XCTAssertTrue(StripePayEligibility.applies(market: .unitedStates, currency: nil, paymentChannels: ["APP_STRIPE"]))
        XCTAssertFalse(StripePayEligibility.applies(market: .china, currency: "USD", paymentChannels: ["APPLE_PAY"]))
        XCTAssertFalse(StripePayEligibility.applies(market: .unitedStates, currency: "CNY", paymentChannels: ["APPLE_PAY"]))
        XCTAssertFalse(StripePayEligibility.applies(market: .unitedStates, currency: "USD", paymentChannels: ["APP"]))
        XCTAssertFalse(StripePayEligibility.applies(market: .unitedStates, currency: "USD", paymentChannels: nil))
        ReleaseMoneyWriteSwitch.testDerivation = nil
        XCTAssertFalse(StripePayEligibility.applies(market: .unitedStates, currency: "USD", paymentChannels: ["APPLE_PAY"]))
    }

    func testUSDQuoteChannelsCountAsAppChannels() throws {
        let usd = try JSONDecoder().decode(RegistrationQuote.self, from: Data(
            #"{"payAmount":"25.00","quoteSign":"s","currency":"USD","paymentChannels":["APP_STRIPE","APPLE_PAY"]}"#.utf8))
        XCTAssertEqual(usd.currency, "USD")
        XCTAssertFalse(usd.paymentChannelUnavailable)
        let china = try JSONDecoder().decode(RegistrationQuote.self, from: Data(
            #"{"payAmount":"25.00","quoteSign":"s","paymentChannels":["MINI_PROGRAM"]}"#.utf8))
        XCTAssertNil(china.currency)
        XCTAssertTrue(china.paymentChannelUnavailable)
    }

    func testIntentSendsNoAmountAndDecodesMinorUnits() async throws {
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .payment }
        let transport = Recorder(#"{"code":200,"data":{"paymentIntentId":"pi_1","amountMinor":2500,"currency":"usd","checkoutUrl":"https://checkout.stripe.com/c/pay/cs_1"}}"#)
        let result = await StripePayService.createIntent(try StripeIntentRequest(registrationID: 42, orderNo: " R42 "),
                                                         configuration: api, transport: transport, token: "tok")
        let intent = try result.get()
        XCTAssertEqual(intent.amount, Decimal(25))
        XCTAssertEqual(intent.currency, "USD")
        XCTAssertEqual(intent.paymentIntentID, "pi_1")
        XCTAssertEqual(intent.checkoutURL?.host, "checkout.stripe.com")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url?.path, "/prod-api/api/pay/stripe/intent")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "tok")
        let body = try XCTUnwrap(String(data: try XCTUnwrap(request.httpBody), encoding: .utf8))
        XCTAssertEqual(body, #"{"bizType":"REGISTRATION","orderNo":"R42","registrationId":42}"#)
        XCTAssertFalse(body.contains("amount"))
    }

    func testNonUSDIntentAndForeignCheckoutHostAreRefused() async throws {
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .payment }
        let cny = Recorder(#"{"code":200,"data":{"amount":"25","currency":"CNY"}}"#)
        let result = await StripePayService.createIntent(try StripeIntentRequest(registrationID: 1), configuration: api,
                                                         transport: cny, token: "tok")
        XCTAssertEqual(result.failureValue, .unknown)
        let evil = Recorder(#"{"code":200,"data":{"url":"https://example.com/pay"}}"#)
        let url = await StripePayService.checkoutURL(try StripeIntentRequest(registrationID: 1), configuration: api,
                                                     transport: evil, token: "tok")
        XCTAssertEqual(url.failureValue, .unknown)
    }

    func testClosedSwitchSendsNothing() async throws {
        let transport = Recorder(#"{"code":200,"data":{}}"#)
        let result = await StripePayService.createIntent(try StripeIntentRequest(registrationID: 1), configuration: api,
                                                         transport: transport, token: "tok")
        XCTAssertEqual(result.failureValue, .closed)
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testApplePayConfirmCarriesTokenAndDecodesStatus() async throws {
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .payment }
        let transport = Recorder(#"{"code":200,"data":{"status":"succeeded"}}"#)
        let body = try StripeApplePayConfirmRequest(intent: try StripeIntentRequest(registrationID: 7), paymentIntentID: "pi_7",
                                                    paymentData: Data(#"{"version":"EC_v1"}"#.utf8), instrumentName: "Visa 1234",
                                                    paymentNetwork: "Visa", transactionIdentifier: "tx")
        let result = try await StripePayService.confirmApplePay(body, configuration: api, transport: transport, token: "tok").get()
        XCTAssertTrue(result.authorizedOrProcessing)
        let sent = try XCTUnwrap(String(data: try XCTUnwrap(transport.requests.first?.httpBody), encoding: .utf8))
        XCTAssertTrue(sent.contains(#""pkTokenTransactionId":"tx""#))
        XCTAssertTrue(sent.contains(#""paymentIntentId":"pi_7""#))
        XCTAssertEqual(transport.requests.first?.url?.path, "/prod-api/api/pay/stripe/applepay")
    }

    func testBusinessRejectionKeepsServerMessage() async throws {
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .payment }
        let transport = Recorder(#"{"code":500,"msg":"Order already paid"}"#)
        let result = await StripePayService.createIntent(try StripeIntentRequest(registrationID: 1), configuration: api,
                                                         transport: transport, token: "tok")
        XCTAssertEqual(result.failureValue, .rejected("Order already paid"))
    }
}

private extension Result {
    var failureValue: Failure? { if case .failure(let value) = self { return value }; return nil }
}
