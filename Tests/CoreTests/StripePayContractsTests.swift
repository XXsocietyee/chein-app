import XCTest
@testable import QuestifyCore

/// US launch r1 (lane app-pay); fix 11-28 (audit P0-3 / P1-3). Stripe / Apple Pay contract for USD orders, pinned to
/// hengyin `us/r3-functional` `ApiStripePayController`:
///   intent(String id) · applePay(String id, String tokenId, String paymentData, String transactionIdentifier,
///   String paymentNetwork, String paymentMethodDisplayName) · checkout(String id)
/// No `@RequestBody`, so every call is a form-encoded POST. Backend `amount` is minor units (cents). No network.
final class StripePayContractsTests: XCTestCase {
    private final class Recorder: HTTPTransport, @unchecked Sendable {
        var requests: [URLRequest] = []
        let reply: (Data, Int)
        init(_ json: String, status: Int = 200) { reply = (Data(json.utf8), status) }
        func send(_ request: URLRequest) async throws -> (Data, Int) { requests.append(request); return reply }
    }

    private let api = try! APIConfiguration(baseURL: URL(string: "https://www.chengyinhub.com/prod-api/")!)

    override func tearDown() { ReleaseMoneyWriteSwitch.testDerivation = nil }

    /// Parses an `application/x-www-form-urlencoded` body back into fields.
    private func form(_ request: URLRequest?) throws -> [String: String] {
        let body = try XCTUnwrap(String(data: try XCTUnwrap(request?.httpBody), encoding: .utf8))
        var fields: [String: String] = [:]
        for pair in body.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            XCTAssertEqual(parts.count, 2, String(pair))
            let key = try XCTUnwrap(String(parts[0]).removingPercentEncoding)
            let value = try XCTUnwrap(String(parts[1]).removingPercentEncoding)
            XCTAssertNil(fields[key], "duplicate field \(key)")
            fields[key] = value
        }
        return fields
    }

    // MARK: Routes and switches

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

    func testRoutePathsMatchTheControllerMappings() {
        // @RequestMapping("/api/pay/stripe") + @PostMapping("/intent" | "/applepay" | "/checkout").
        XCTAssertEqual(StripePayRoute.allCases.map(\.routePath),
                       ["/api/pay/stripe/intent", "/api/pay/stripe/applepay", "/api/pay/stripe/checkout"])
    }

    func testClosedSwitchSendsNothing() async throws {
        let transport = Recorder(#"{"code":200,"data":{}}"#)
        let result = await StripePayService.createIntent(try StripeIntentRequest(registrationID: 1), configuration: api,
                                                         transport: transport, token: "tok")
        XCTAssertEqual(result.failureValue, .closed)
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testSignedOutSendsNothing() async throws {
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .payment }
        let transport = Recorder(#"{"code":200,"data":{}}"#)
        let result = await StripePayService.createIntent(try StripeIntentRequest(registrationID: 1), configuration: api,
                                                         transport: transport, token: "")
        XCTAssertEqual(result.failureValue, .signedOut)
        XCTAssertTrue(transport.requests.isEmpty)
    }

    // MARK: P1-3 routing by quote currency, not storefront

    func testEligibilityIsUSDWithAStripeChannelWhateverTheStorefront() {
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .payment }
        XCTAssertTrue(StripePayEligibility.applies(currency: "USD", paymentChannels: ["APPLE_PAY"]))
        XCTAssertTrue(StripePayEligibility.applies(currency: " usd ", paymentChannels: ["APPLE_PAY", "APP_STRIPE"]))
        XCTAssertTrue(StripePayEligibility.applies(currency: nil, paymentChannels: ["APP_STRIPE"]))
        XCTAssertFalse(StripePayEligibility.applies(currency: "CNY", paymentChannels: ["APPLE_PAY"]))
        XCTAssertFalse(StripePayEligibility.applies(currency: "USD", paymentChannels: ["APP"]))
        XCTAssertFalse(StripePayEligibility.applies(currency: "USD", paymentChannels: nil))
        XCTAssertFalse(StripePayEligibility.applies(currency: nil, paymentChannels: ["JSAPI", "APP", "APP_ALIPAY"]))
        ReleaseMoneyWriteSwitch.testDerivation = nil
        XCTAssertFalse(StripePayEligibility.applies(currency: "USD", paymentChannels: ["APPLE_PAY"]))
    }

    func testPayMarketFollowsTheQuoteNotTheStorefront() {
        // attachStripePaymentChannels: currency=USD + APPLE_PAY / APP_STRIPE. attachPaymentChannels: no currency, JSAPI / APP / APP_ALIPAY.
        XCTAssertEqual(StripePayEligibility.payMarket(currency: "USD", paymentChannels: ["APPLE_PAY"]), .unitedStates)
        XCTAssertEqual(StripePayEligibility.payMarket(currency: "USD", paymentChannels: []), .unitedStates)
        XCTAssertEqual(StripePayEligibility.payMarket(currency: nil, paymentChannels: ["APP", "APP_ALIPAY"]), .china)
        XCTAssertEqual(StripePayEligibility.payMarket(currency: "CNY", paymentChannels: nil), .china)
        XCTAssertNil(StripePayEligibility.payMarket(currency: nil, paymentChannels: nil))
        XCTAssertNil(StripePayEligibility.payMarket(currency: "  ", paymentChannels: nil))
    }

    func testMethodsPutApplePayFirstOnlyWhenTheDeviceCanPay() {
        let both = ["APPLE_PAY", "APP_STRIPE"]
        XCTAssertEqual(StripePayEligibility.methods(paymentChannels: both, applePayAvailable: true), [.applePay, .card])
        XCTAssertEqual(StripePayEligibility.methods(paymentChannels: both, applePayAvailable: false), [.card])
        XCTAssertEqual(StripePayEligibility.methods(paymentChannels: ["APPLE_PAY"], applePayAvailable: true), [.applePay])
        XCTAssertEqual(StripePayEligibility.methods(paymentChannels: ["APPLE_PAY"], applePayAvailable: false), [])
        XCTAssertEqual(RegistrationPayMethod.options(market: .unitedStates, applePayAvailable: true,
                                                     paymentChannels: ["APP_STRIPE"]), [.card])
        XCTAssertEqual(RegistrationPayMethod.options(market: .unitedStates, applePayAvailable: true,
                                                     paymentChannels: both), [.applePay, .card])
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

    // MARK: P0-3 wire format

    func testIntentIsAFormPostWithIdOnlyAndDecodesCents() async throws {
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .payment }
        // StripePaymentService.intentView: amount = frozen.amountMinor (cents).
        let transport = Recorder(#"{"code":200,"msg":"操作成功","data":{"registrationId":42,"registrationNo":"R42","paymentIntentId":"pi_1","clientSecret":"pi_1_secret_x","status":"requires_payment_method","amount":2500,"currency":"USD","publishableKey":"pk_test_x","checkoutAvailable":true}}"#)
        let result = await StripePayService.createIntent(try StripeIntentRequest(registrationID: 42),
                                                         configuration: api, transport: transport, token: "tok")
        let intent = try result.get()
        XCTAssertEqual(intent.amountMinor, 2500)
        XCTAssertEqual(intent.amount, Decimal(25), "2500 cents is $25.00, not $2,500")
        XCTAssertEqual(intent.currency, "USD")
        XCTAssertEqual(intent.paymentIntentID, "pi_1")
        XCTAssertEqual(intent.registrationID, 42)
        XCTAssertTrue(intent.checkoutAvailable)
        XCTAssertFalse(intent.alreadySettling)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/prod-api/api/pay/stripe/intent")
        XCTAssertNil(request.url?.query)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded; charset=utf-8")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "tok")
        XCTAssertEqual(String(data: try XCTUnwrap(request.httpBody), encoding: .utf8), "id=42")
        XCTAssertEqual(try form(request), ["id": "42"])
    }

    func testCheckoutIsAFormPostWithIdAndReadsCheckoutUrl() async throws {
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .payment }
        // StripePaymentService.createCheckout view.
        let transport = Recorder(#"{"code":200,"data":{"registrationId":9,"registrationNo":"R9","checkoutSessionId":"cs_1","checkoutUrl":"https://checkout.stripe.com/c/pay/cs_1","amount":1999,"currency":"USD"}}"#)
        let session = try await StripePayService.checkout(try StripeIntentRequest(registrationID: 9), configuration: api,
                                                          transport: transport, token: "tok").get()
        XCTAssertEqual(session.url.host, "checkout.stripe.com")
        XCTAssertEqual(session.amountMinor, 1999)
        XCTAssertEqual(transport.requests.first?.url?.path, "/prod-api/api/pay/stripe/checkout")
        XCTAssertEqual(try form(transport.requests.first), ["id": "9"])
    }

    func testApplePayConfirmSendsTheControllerFieldNames() async throws {
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .payment }
        let transport = Recorder(#"{"code":200,"data":{"registrationId":7,"paymentIntentId":"pi_7","status":"succeeded","amount":2500,"currency":"USD","paymentStatus":2,"registrationStatus":2}}"#)
        let paymentData = #"{"version":"EC_v1","data":"a+b/c==","signature":"s&t=1","header":{"ephemeralPublicKey":"k+/="}}"#
        let body = try StripeApplePayConfirmRequest(intent: try StripeIntentRequest(registrationID: 7),
                                                    paymentData: Data(paymentData.utf8), paymentMethodDisplayName: "Visa 1234",
                                                    paymentNetwork: "Visa", transactionIdentifier: "AB12")
        let result = try await StripePayService.confirmApplePay(body, configuration: api, transport: transport, token: "tok").get()
        XCTAssertTrue(result.authorizedOrProcessing)
        XCTAssertTrue(result.serverMarkedPaid)
        XCTAssertEqual(result.paymentStatus, 2)
        XCTAssertEqual(result.registrationStatus, 2)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url?.path, "/prod-api/api/pay/stripe/applepay")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), StripePayWire.contentType)
        let fields = try form(request)
        XCTAssertEqual(fields, [
            "id": "7",
            "paymentData": paymentData,
            "transactionIdentifier": "AB12",
            "paymentNetwork": "Visa",
            "paymentMethodDisplayName": "Visa 1234"
        ])
        // The backend wants exactly one of tokenId / paymentData; the app sends the raw PassKit token.
        XCTAssertNil(fields[StripePayWire.Field.tokenId])
        let raw = try XCTUnwrap(String(data: try XCTUnwrap(request.httpBody), encoding: .utf8))
        for reserved in ["+", "/", "{", "\"", " "] { XCTAssertFalse(raw.contains(reserved), reserved) }
        XCTAssertEqual(raw.components(separatedBy: "&").count, 5, "the JSON's own & and = must be escaped")
        XCTAssertFalse(raw.contains("pkToken"))
        XCTAssertFalse(raw.contains("registrationId"))
    }

    func testApplePayConfirmOmitsEmptyOptionalFieldsAndRefusesEmptyTokens() throws {
        let intent = try StripeIntentRequest(registrationID: 3)
        let body = try StripeApplePayConfirmRequest(intent: intent, paymentData: Data(#"{"v":1}"#.utf8),
                                                    paymentMethodDisplayName: "  ", paymentNetwork: nil, transactionIdentifier: "t")
        XCTAssertEqual(body.formFields, ["id": "3", "paymentData": #"{"v":1}"#, "transactionIdentifier": "t"])
        XCTAssertThrowsError(try StripeApplePayConfirmRequest(intent: intent, paymentData: Data(), paymentMethodDisplayName: nil,
                                                              paymentNetwork: nil, transactionIdentifier: "t"))
        XCTAssertThrowsError(try StripeApplePayConfirmRequest(intent: intent, paymentData: Data(#"{"v":1}"#.utf8),
                                                              paymentMethodDisplayName: nil, paymentNetwork: nil, transactionIdentifier: ""))
        XCTAssertThrowsError(try StripeIntentRequest(registrationID: 0))
    }

    func testFieldNamesMatchTheJavaSignature() {
        XCTAssertEqual([StripePayWire.Field.id, StripePayWire.Field.tokenId, StripePayWire.Field.paymentData,
                        StripePayWire.Field.transactionIdentifier, StripePayWire.Field.paymentNetwork,
                        StripePayWire.Field.paymentMethodDisplayName],
                       ["id", "tokenId", "paymentData", "transactionIdentifier", "paymentNetwork", "paymentMethodDisplayName"])
        XCTAssertEqual(StripePayForm.encode(["b": "x y", "a": "1&2=3"]), "a=1%262%3D3&b=x%20y")
        XCTAssertEqual(StripePayForm.encode(["k": "é"]), "k=%C3%A9")
    }

    // MARK: Cents

    func testAmountIsMinorUnitsEverywhere() {
        XCTAssertEqual(StripePayMoney.minorUnits(2500), 2500)
        XCTAssertEqual(StripePayMoney.minorUnits("1999"), 1999)
        XCTAssertNil(StripePayMoney.minorUnits(25.5), "cents are whole")
        XCTAssertNil(StripePayMoney.minorUnits(0))
        XCTAssertNil(StripePayMoney.minorUnits(-100))
        XCTAssertNil(StripePayMoney.minorUnits(nil))
        XCTAssertEqual(StripePayMoney.major(fromMinor: 2500), Decimal(25))
        XCTAssertEqual(StripePayMoney.major(fromMinor: 1999), Decimal(string: "19.99"))
        XCTAssertEqual(StripePayMoney.major(fromMinor: 1), Decimal(string: "0.01"))
        XCTAssertEqual(StripePayMoney.minor(fromMajor: Decimal(string: "19.99")!), 1999)
        XCTAssertNil(StripePayMoney.minor(fromMajor: Decimal(string: "19.999")!))
    }

    func testNonUSDIntentFractionalAmountAndForeignCheckoutHostAreRefused() async throws {
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .payment }
        let cny = Recorder(#"{"code":200,"data":{"amount":2500,"currency":"CNY"}}"#)
        let result = await StripePayService.createIntent(try StripeIntentRequest(registrationID: 1), configuration: api,
                                                         transport: cny, token: "tok")
        XCTAssertEqual(result.failureValue, .unknown)
        let fractional = Recorder(#"{"code":200,"data":{"amount":"25.00","currency":"USD"}}"#)
        let major = await StripePayService.createIntent(try StripeIntentRequest(registrationID: 1), configuration: api,
                                                        transport: fractional, token: "tok")
        XCTAssertEqual(try major.get().amountMinor, 25, "a bare amount is cents, never dollars")
        let evil = Recorder(#"{"code":200,"data":{"checkoutUrl":"https://example.com/pay","currency":"USD"}}"#)
        let url = await StripePayService.checkout(try StripeIntentRequest(registrationID: 1), configuration: api,
                                                  transport: evil, token: "tok")
        XCTAssertEqual(url.failureValue, .unknown)
    }

    // MARK: Errors (StripePayException code / errorCode / msg)

    func testBusinessRejectionKeepsServerMessage() async throws {
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .payment }
        let transport = Recorder(#"{"code":500,"msg":"Please accept the sign-up data sharing consent first"}"#)
        let result = await StripePayService.createIntent(try StripeIntentRequest(registrationID: 1), configuration: api,
                                                         transport: transport, token: "tok")
        XCTAssertEqual(result.failureValue, .rejected("Please accept the sign-up data sharing consent first"))
    }

    func testErrorCodesMapToStates() {
        XCTAssertEqual(StripePayService.mapFailure(code: 402, errorCode: "PAYMENT_DECLINED", message: "Payment was declined"),
                       .declined("Payment was declined"))
        XCTAssertEqual(StripePayService.mapFailure(code: 503, errorCode: "PAYMENT_OUTCOME_UNKNOWN", message: "x"), .outcomeUnknown)
        XCTAssertEqual(StripePayService.mapFailure(code: 409, errorCode: "ORDER_ALREADY_PAID", message: "x"), .alreadyPaid)
        XCTAssertEqual(StripePayService.mapFailure(code: 410, errorCode: "ORDER_EXPIRED", message: "gone"), .expired("gone"))
        XCTAssertEqual(StripePayService.mapFailure(code: 409, errorCode: "STRIPE_INTENT_CANCELED", message: nil), .expired(nil))
        XCTAssertEqual(StripePayService.mapFailure(code: 409, errorCode: "ORDER_AMOUNT_CHANGED", message: nil), .expired(nil))
        XCTAssertEqual(StripePayService.mapFailure(code: 500, errorCode: nil, message: "Please sign in"), .unauthorized)
        XCTAssertEqual(StripePayService.mapFailure(code: 401, errorCode: nil, message: nil), .unauthorized)
        XCTAssertEqual(StripePayService.mapFailure(code: 503, errorCode: "STRIPE_UNAVAILABLE", message: "busy"), .rejected("busy"))
    }

    func testDeclinedEnvelopeAndUnreadableConfirmAnswer() async throws {
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .payment }
        let body = try StripeApplePayConfirmRequest(intent: try StripeIntentRequest(registrationID: 7), paymentData: Data(#"{"v":1}"#.utf8),
                                                    paymentMethodDisplayName: nil, paymentNetwork: nil, transactionIdentifier: "t")
        let declined = Recorder(#"{"code":402,"msg":"Payment was declined","errorCode":"PAYMENT_DECLINED"}"#)
        let refused = await StripePayService.confirmApplePay(body, configuration: api, transport: declined, token: "tok")
        XCTAssertEqual(refused.failureValue, .declined("Payment was declined"))
        let garbled = Recorder("<html>", status: 502)
        let unknown = await StripePayService.confirmApplePay(body, configuration: api, transport: garbled, token: "tok")
        XCTAssertEqual(unknown.failureValue, .outcomeUnknown, "a token that left the device is never 'not charged'")
        let expired = Recorder("{}", status: 401)
        let signedOut = await StripePayService.confirmApplePay(body, configuration: api, transport: expired, token: "tok")
        XCTAssertEqual(signedOut.failureValue, .unauthorized)
    }

    // MARK: Server-confirmed result states

    func testStagesNeedTheServerToSayPaid() {
        let paidAnswer = StripeConfirmResult(status: "succeeded", paymentStatus: 2, registrationStatus: 2)
        let processing = StripeConfirmResult(status: "processing", paymentStatus: 1)
        XCTAssertEqual(StripePayStageResolver.afterApplePay(confirm: processing, paymentStatus: 2), .paid)
        XCTAssertEqual(StripePayStageResolver.afterApplePay(confirm: processing, paymentStatus: 1), .checking)
        XCTAssertEqual(StripePayStageResolver.afterApplePay(confirm: nil, paymentStatus: nil), .checking)
        XCTAssertEqual(StripePayStageResolver.afterApplePay(confirm: paidAnswer, paymentStatus: nil), .paid)
        XCTAssertEqual(StripePayStageResolver.afterApplePay(confirm: paidAnswer, paymentStatus: 1), .checking,
                       "the later status read wins over the confirm answer")
        XCTAssertEqual(StripePayStageResolver.afterCheckout(paymentStatus: 2), .paid)
        XCTAssertEqual(StripePayStageResolver.afterCheckout(paymentStatus: 1), .notCompleted)
        XCTAssertEqual(StripePayStageResolver.afterCheckout(paymentStatus: nil), .checking)
        XCTAssertEqual(StripePayStageResolver.refreshed(paymentStatus: 2), .paid)
        XCTAssertEqual(StripePayStageResolver.refreshed(paymentStatus: 0), .checking)
        XCTAssertFalse(StripeConfirmResult(status: "requires_payment_method").authorizedOrProcessing)
        XCTAssertTrue(StripeIntent(paymentIntentID: "pi", amountMinor: 1, currency: "USD", status: "processing").alreadySettling)
    }
}

private extension Result {
    var failureValue: Failure? { if case .failure(let value) = self { return value }; return nil }
}
