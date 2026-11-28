import XCTest
@testable import QuestifyCore

/// fix-1128-alipay (audit P0-4): request shapes for `/api/pay/alipay/order|query` (hengyin `us/r3-functional`
/// `ApiAlipayPayController`: POST, form `id`, member token), answer decoding, and the pay-step state transitions.
final class AlipayAppPayTests: XCTestCase {
    private actor RecordingTransport: HTTPTransport {
        var requests: [URLRequest] = []
        let handler: @Sendable (URLRequest) throws -> (Data, Int)

        init(_ handler: @escaping @Sendable (URLRequest) throws -> (Data, Int)) {
            self.handler = handler
        }

        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return try handler(request)
        }
    }

    private func configuration() throws -> APIConfiguration {
        try APIConfiguration(baseURL: URL(string: "https://test.example.com/api-root/")!)
    }

    private func body(_ request: URLRequest) -> String {
        String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
    }

    override func tearDown() {
        ReleaseMoneyWriteSwitch.testDerivation = nil
        super.tearDown()
    }

    // MARK: request shape

    func testOrderRequestIsPostFormIDWithToken() throws {
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .payment }
        let request = try AlipayAppPayService.makeRequest(.order, configuration: configuration(),
                                                          token: "test-token-1234", registrationID: 701)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api-root/api/pay/alipay/order")
        XCTAssertNil(request.url?.query)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "test-token-1234")
        XCTAssertTrue(body(request).contains("name=\"id\"\r\n\r\n701\r\n"))
        XCTAssertEqual(RegistrationAlipayFormID.registrationID(inFormBody: body(request)), 701)
    }

    func testQueryRequestUsesTheQueryRoute() throws {
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .payment }
        let request = try AlipayAppPayService.makeRequest(.query, configuration: configuration(),
                                                          token: "test-token-1234", registrationID: 702)
        XCTAssertEqual(request.url?.path, "/api-root/api/pay/alipay/query")
        XCTAssertEqual(RegistrationAlipayFormID.registrationID(inFormBody: body(request)), 702)
    }

    func testOrderIsBlockedWhileThePaymentSwitchIsOff() async throws {
        ReleaseMoneyWriteSwitch.testDerivation = nil
        XCTAssertThrowsError(try AlipayAppPayService.makeRequest(.order, configuration: configuration(),
                                                                 token: "test-token-1234", registrationID: 701))
        let transport = RecordingTransport { _ in (Data(), 200) }
        let outcome = await AlipayAppPayService.createOrder(configuration: try configuration(), transport: transport,
                                                            token: "test-token-1234", registrationID: 701)
        XCTAssertEqual(outcome, .unavailable(message: nil))
        let count = await transport.requests.count
        XCTAssertEqual(count, 0)
    }

    func testRouteGrantsAndMoneyKind() {
        XCTAssertEqual(ReleaseMoneyWriteSwitch.kind(for: "/api/pay/alipay/order"), .payment)
        XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: "/api/pay/alipay/query"))
        XCTAssertEqual(ChinaReviewedRouteCapability.moneyAreaOwnerGrant["/api/pay/alipay/order"], .payment)
        XCTAssertEqual(ChinaReviewedRouteCapability.moneyAreaOwnerGrant["/api/pay/alipay/query"], .payment)
    }

    func testInvalidInputsNeverBuildARequest() throws {
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .payment }
        XCTAssertThrowsError(try AlipayAppPayService.makeRequest(.order, configuration: configuration(),
                                                                 token: "test-token-1234", registrationID: 0))
        XCTAssertThrowsError(try AlipayAppPayService.makeRequest(.order, configuration: configuration(),
                                                                 token: "", registrationID: 701))
    }

    // MARK: order answers

    func testOrderSuccessCarriesTheOrderString() async throws {
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .payment }
        let json = #"{"code":200,"msg":"操作成功","data":{"registrationId":701,"registrationNo":"R701","amountFen":1250,"amount":"12.50","currency":"CNY","payChannel":"ALIPAY","orderString":"app_id=synthetic&biz_content=%7B%7D&sign=synthetic"}}"#
        let transport = RecordingTransport { _ in (Data(json.utf8), 200) }
        let outcome = await AlipayAppPayService.createOrder(configuration: try configuration(), transport: transport,
                                                            token: "test-token-1234", registrationID: 701)
        let expected = AlipayAppPayOrder(registrationID: 701, registrationNo: "R701",
                                         orderString: "app_id=synthetic&biz_content=%7B%7D&sign=synthetic")
        XCTAssertEqual(outcome, .order(expected))
        XCTAssertEqual(expected.adapterParameters, ["orderString": "app_id=synthetic&biz_content=%7B%7D&sign=synthetic"])
        let count = await transport.requests.count
        XCTAssertEqual(count, 1)
    }

    func testOrderErrorCodesMapToStates() {
        func decode(_ code: Int, _ errorCode: String) -> AlipayAppPayOrderOutcome {
            let json = "{\"code\":\(code),\"msg\":\"m\",\"errorCode\":\"\(errorCode)\"}"
            return AlipayAppPayService.decodeOrder(Data(json.utf8), status: 200, registrationID: 701)
        }
        XCTAssertEqual(decode(409, "ORDER_ALREADY_PAID"), .alreadyPaid)
        XCTAssertEqual(decode(410, "ORDER_EXPIRED"), .expired(message: "m"))
        XCTAssertEqual(decode(503, "ALIPAY_NOT_CONFIGURED"), .unavailable(message: "m"))
        XCTAssertEqual(decode(503, "ALIPAY_UNAVAILABLE"), .unavailable(message: "m"))
        XCTAssertEqual(decode(409, "CURRENCY_NOT_SUPPORTED"), .rejected(errorCode: "CURRENCY_NOT_SUPPORTED", message: "m"))
        XCTAssertEqual(AlipayAppPayService.decodeOrder(Data(), status: 401, registrationID: 701), .unauthorized)
        XCTAssertEqual(AlipayAppPayService.decodeOrder(Data("x".utf8), status: 200, registrationID: 701), .unknown)
    }

    func testOrderForAnotherRegistrationIsRefused() {
        let json = #"{"code":200,"data":{"registrationId":999,"orderString":"a=b"}}"#
        XCTAssertEqual(AlipayAppPayService.decodeOrder(Data(json.utf8), status: 200, registrationID: 701), .unknown)
    }

    // MARK: query answers

    func testQueryDecodesPaidAndTradeStatus() {
        let paid = #"{"code":200,"data":{"registrationId":701,"paid":true,"paymentStatus":2,"registrationStatus":1}}"#
        let result = AlipayAppPayService.decodeQuery(Data(paid.utf8), status: 200, registrationID: 701)
        XCTAssertEqual(result, AlipayAppPayQueryResult(paid: true, paymentStatus: 2, registrationStatus: 1, tradeStatus: nil))
        XCTAssertEqual(result?.isPaid, true)

        let open = #"{"code":200,"data":{"registrationId":701,"paid":false,"paymentStatus":1,"tradeStatus":"TRADE_CLOSED"}}"#
        let unpaid = AlipayAppPayService.decodeQuery(Data(open.utf8), status: 200, registrationID: 701)
        XCTAssertEqual(unpaid?.isPaid, false)
        XCTAssertEqual(unpaid?.buyerDidNotPay, true)

        let refused = #"{"code":404,"msg":"该订单未发起支付宝支付","errorCode":"ALIPAY_ORDER_NOT_CREATED"}"#
        XCTAssertNil(AlipayAppPayService.decodeQuery(Data(refused.utf8), status: 200, registrationID: 701))
    }

    // MARK: state transitions (same result states as WeChat Pay)

    func testProviderReturnPlusOneQueryDecidesTheStage() {
        let paid = AlipayAppPayQueryResult(paid: true, paymentStatus: 2, registrationStatus: 1, tradeStatus: nil)
        let waiting = AlipayAppPayQueryResult(paid: false, paymentStatus: 1, registrationStatus: 1, tradeStatus: "WAIT_BUYER_PAY")
        let closed = AlipayAppPayQueryResult(paid: false, paymentStatus: 1, registrationStatus: 1, tradeStatus: "NOT_EXIST")
        XCTAssertEqual(RegistrationAlipayResolver.stage(providerReturn: .returned, query: paid), .paid)
        XCTAssertEqual(RegistrationAlipayResolver.stage(providerReturn: .cancelled, query: paid), .paid)
        XCTAssertEqual(RegistrationAlipayResolver.stage(providerReturn: .cancelled, query: waiting), .cancelled)
        XCTAssertEqual(RegistrationAlipayResolver.stage(providerReturn: .failed, query: nil), .cancelled)
        XCTAssertEqual(RegistrationAlipayResolver.stage(providerReturn: .returned, query: waiting), .checking)
        XCTAssertEqual(RegistrationAlipayResolver.stage(providerReturn: .returned, query: nil), .checking)
        XCTAssertEqual(RegistrationAlipayResolver.stage(providerReturn: .unknown, query: waiting), .checking)
        XCTAssertEqual(RegistrationAlipayResolver.stage(providerReturn: .unknown, query: closed), .cancelled)
        XCTAssertEqual(RegistrationAlipayResolver.refreshed(query: paid), .paid)
        XCTAssertEqual(RegistrationAlipayResolver.refreshed(query: nil), .checking)
    }

    func testOrderOutcomeStages() {
        let order = AlipayAppPayOrder(registrationID: 701, registrationNo: nil, orderString: "a=b")
        XCTAssertNil(RegistrationAlipayResolver.stage(orderOutcome: .order(order)))
        XCTAssertEqual(RegistrationAlipayResolver.stage(orderOutcome: .alreadyPaid), .checking)
        XCTAssertEqual(RegistrationAlipayResolver.stage(orderOutcome: .expired(message: nil)), .expired(message: nil))
        XCTAssertEqual(RegistrationAlipayResolver.stage(orderOutcome: .unavailable(message: "x")), .alipayUnavailable(message: "x"))
        XCTAssertEqual(RegistrationAlipayResolver.stage(orderOutcome: .unauthorized), .signedOut)
        XCTAssertEqual(RegistrationAlipayResolver.stage(orderOutcome: .unknown), .checking)
        XCTAssertTrue(RegistrationAlipayResolver.canPay(.ready))
        XCTAssertTrue(RegistrationAlipayResolver.canPay(.cancelled))
        XCTAssertFalse(RegistrationAlipayResolver.canPay(.launching))
        XCTAssertFalse(RegistrationAlipayResolver.canPay(.paid))
    }

    // MARK: channel choice (P32)

    func testAlipayOfferedOnlyWithBackendChannelAndProvider() {
        XCTAssertTrue(AlipayAppPayChannel.offered(paymentChannels: ["APP", "APP_ALIPAY"], providerReady: true))
        XCTAssertFalse(AlipayAppPayChannel.offered(paymentChannels: ["APP", "APP_ALIPAY"], providerReady: false))
        XCTAssertFalse(AlipayAppPayChannel.offered(paymentChannels: ["APP"], providerReady: true))
        XCTAssertFalse(AlipayAppPayChannel.offered(paymentChannels: nil, providerReady: true))
    }

    func testEffectiveMethodDefaultsToWeChatPay() {
        let both = ["APP", "APP_ALIPAY"]
        XCTAssertEqual(RegistrationPayMethod.effective(selection: nil, market: .china, applePayAvailable: false,
                                                       alipayOffered: true, paymentChannels: both), .wechatPay)
        XCTAssertEqual(RegistrationPayMethod.effective(selection: .alipay, market: .china, applePayAvailable: false,
                                                       alipayOffered: true, paymentChannels: both), .alipay)
        XCTAssertEqual(RegistrationPayMethod.effective(selection: .alipay, market: .china, applePayAvailable: false,
                                                       alipayOffered: false, paymentChannels: ["APP"]), .wechatPay)
        XCTAssertEqual(RegistrationPayMethod.effective(selection: nil, market: .china, applePayAvailable: false,
                                                       alipayOffered: true, paymentChannels: ["APP_ALIPAY"]), .alipay)
        XCTAssertEqual(RegistrationPayMethod.alipay.payButtonKey, "registration.payWith.alipay %@")
        XCTAssertEqual(RegistrationPayMethod.wechatPay.payButtonKey, "registration.payWith.wechatPay %@")
    }

    func testAlipayOnlyQuoteIsNotPaymentUnavailable() throws {
        let json = #"{"payAmount":12.5,"pointsUsable":false,"pointsUsed":0,"quoteSign":"s","paymentChannels":["APP_ALIPAY"]}"#
        let quote = try JSONDecoder().decode(RegistrationQuote.self, from: Data(json.utf8))
        XCTAssertFalse(quote.paymentChannelUnavailable)
    }

    // MARK: URL hand-off without the SDK binary

    func testLaunchURLCarriesTheOrderAndReturnScheme() throws {
        let url = try XCTUnwrap(AlipayURLPayment.launchURL(orderString: "app_id=1&sign=a+b", fromScheme: "chengyinpay"))
        XCTAssertEqual(url.scheme, "alipay")
        XCTAssertEqual(url.host, "alipayclient")
        let query = try XCTUnwrap(url.query?.removingPercentEncoding)
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(query.utf8)) as? [String: String])
        XCTAssertEqual(object, ["requestType": "SafePay", "fromAppUrlScheme": "chengyinpay", "dataString": "app_id=1&sign=a+b"])
        XCTAssertNil(AlipayURLPayment.launchURL(orderString: "", fromScheme: "chengyinpay"))
    }

    func testReturnURLResultStatus() throws {
        let json = #"{"memo":{"result":"","ResultStatus":"9000","memo":""},"requestType":"safepay"}"#
        let encoded = try XCTUnwrap(json.addingPercentEncoding(withAllowedCharacters: .alphanumerics))
        let url = try XCTUnwrap(URL(string: "chengyinpay://safepay/?" + encoded))
        XCTAssertEqual(AlipayURLPayment.resultStatus(from: url), "9000")
        XCTAssertNil(AlipayURLPayment.resultStatus(from: try XCTUnwrap(URL(string: "chengyinpay://other/?x"))))
    }

    func testFormIDParser() {
        XCTAssertEqual(RegistrationAlipayFormID.registrationID(inFormBody: "id=55"), 55)
        XCTAssertNil(RegistrationAlipayFormID.registrationID(inFormBody: "id=0"))
        XCTAssertNil(RegistrationAlipayFormID.registrationID(inFormBody: "name=x"))
    }
}
