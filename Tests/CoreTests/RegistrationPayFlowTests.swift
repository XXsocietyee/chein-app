import XCTest
@testable import QuestifyCore

/// RM-02 (`API-/api/registration/pay`): payment is gated behind `ReviewedAreaSwitch.moneyPayments`
/// (`ReleaseMoneyWriteSwitch.paymentEnabled`), requires payment readiness + fresh quote + consent,
/// and never auto-retries on 410 or transport failures.
final class RegistrationPayFlowTests: XCTestCase {
    private actor CountingTransport: HTTPTransport {
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

    private func sampleQuote() throws -> RegistrationQuote {
        let json = #"{"payAmount":68,"pointsUsable":false,"pointsUsed":0,"quoteSign":"sig-rm02"}"#
        return try JSONDecoder().decode(RegistrationQuote.self, from: Data(json.utf8))
    }

    func testPaymentBlockedWhenReleaseSwitchClosed() async throws {
        defer { ReleaseMoneyWriteSwitch.testDerivation = nil }
        ReleaseMoneyWriteSwitch.testDerivation = nil

        let transport = CountingTransport { _ in (Data(), 200) }
        let config = try APIConfiguration(baseURL: URL(string: "https://test.example.com")!)
        let readiness = RegistrationPaymentReadiness(ready: true, message: "支付服务可用")

        let outcome = await RegistrationPayService.submit(
            configuration: config,
            transport: transport,
            token: "test-token-1234",
            registrationID: 901,
            readiness: readiness,
            quoteUsable: true,
            quoteFresh: true,
            consented: true
        )
        XCTAssertEqual(outcome, .blocked(.moneyPaymentsClosed))
        let count = await transport.requests.count
        XCTAssertEqual(count, 0)
    }

    func testPaymentBlockedWhenReadinessNotReady() async throws {
        defer { ReleaseMoneyWriteSwitch.testDerivation = nil }
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .payment }

        let transport = CountingTransport { _ in (Data(), 200) }
        let config = try APIConfiguration(baseURL: URL(string: "https://test.example.com")!)
        let readiness = RegistrationPaymentReadiness(ready: false, message: "支付服务暂不可用")

        let outcome = await RegistrationPayService.submit(
            configuration: config,
            transport: transport,
            token: "test-token-1234",
            registrationID: 901,
            readiness: readiness,
            quoteUsable: true,
            quoteFresh: true,
            consented: true
        )
        XCTAssertEqual(outcome, .blocked(.notReady, message: "支付服务暂不可用"))
        let count = await transport.requests.count
        XCTAssertEqual(count, 0)
    }

    func testPaymentDispatchesOnceOnTestHostAndNeverAutoRetries() async throws {
        defer { ReleaseMoneyWriteSwitch.testDerivation = nil }
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .payment }

        let payload = #"{"code":200,"msg":"支付参数已生成","data":{"registrationId":901,"paymentStatus":1,"registrationStatus":1,"payParams":{"timeStamp":"1700000000","nonceStr":"abc"}}}"#
        let transport = CountingTransport { _ in (Data(payload.utf8), 200) }
        let config = try APIConfiguration(baseURL: URL(string: "https://test.example.com")!)
        let readiness = RegistrationPaymentReadiness(ready: true, message: "支付服务可用")
        let quote = try sampleQuote()

        let model = await MainActor.run { RegistrationPayModel() }
        await model.pay(
            registrationID: 901,
            paymentsOpen: true,
            readiness: readiness,
            quote: quote,
            quoteReceivedAt: Date(),
            consented: true,
            executor: { id, channel, ready in
                await RegistrationPayService.submit(
                    configuration: config,
                    transport: transport,
                    token: "test-token-1234",
                    registrationID: id,
                    readiness: ready,
                    quoteUsable: true,
                    quoteFresh: true,
                    consented: true,
                    channel: channel
                )
            }
        )

        let outcome = await MainActor.run { model.outcome }
        guard case .paidOrParametersReceived(let response) = outcome else {
            return XCTFail("Expected paidOrParametersReceived, got \(outcome)")
        }
        XCTAssertEqual(response.registrationID, 901)
        XCTAssertEqual(response.payParams?["nonceStr"], "abc")

        // Second pay attempt on same registrationID is blocked immediately (never auto-retries).
        await model.pay(
            registrationID: 901,
            paymentsOpen: true,
            readiness: readiness,
            quote: quote,
            quoteReceivedAt: Date(),
            consented: true,
            executor: { _, _, _ in .outcomeUnknown(message: nil) }
        )
        let secondOutcome = await MainActor.run { model.outcome }
        XCTAssertEqual(secondOutcome, .blocked(.alreadyAttempted))
        let sentCount = await transport.requests.count
        XCTAssertEqual(sentCount, 1)
    }

    func testExpired410ReturnsRebuildWithoutRetry() async throws {
        defer { ReleaseMoneyWriteSwitch.testDerivation = nil }
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .payment }

        let payload = #"{"code":410,"msg":"订单已过期"}"#
        let transport = CountingTransport { _ in (Data(payload.utf8), 200) }
        let config = try APIConfiguration(baseURL: URL(string: "https://test.example.com")!)
        let readiness = RegistrationPaymentReadiness(ready: true, message: "ok")
        let quote = try sampleQuote()

        let model = await MainActor.run { RegistrationPayModel() }
        await model.pay(
            registrationID: 902,
            paymentsOpen: true,
            readiness: readiness,
            quote: quote,
            quoteReceivedAt: Date(),
            consented: true,
            executor: { id, channel, ready in
                await RegistrationPayService.submit(
                    configuration: config,
                    transport: transport,
                    token: "test-token-1234",
                    registrationID: id,
                    readiness: ready,
                    quoteUsable: true,
                    quoteFresh: true,
                    consented: true,
                    channel: channel
                )
            }
        )
        let outcome = await MainActor.run { model.outcome }
        XCTAssertEqual(outcome, .expiredNeedsRebuild(message: CheckoutOrderRebuildRule.orderExpiredUserMessage))
        let count = await transport.requests.count
        let dispatchCount = await MainActor.run { model.dispatchCount }
        XCTAssertEqual(count, 1)
        XCTAssertEqual(dispatchCount, 1)
    }

    func testTransportFailureTurnsOutcomeUnknownAndLocksRetry() async throws {
        defer { ReleaseMoneyWriteSwitch.testDerivation = nil }
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .payment }

        let transport = CountingTransport { _ in throw URLError(.timedOut) }
        let config = try APIConfiguration(baseURL: URL(string: "https://test.example.com")!)
        let readiness = RegistrationPaymentReadiness(ready: true, message: "ok")
        let quote = try sampleQuote()

        let model = await MainActor.run { RegistrationPayModel() }
        await model.pay(
            registrationID: 903,
            paymentsOpen: true,
            readiness: readiness,
            quote: quote,
            quoteReceivedAt: Date(),
            consented: true,
            executor: { id, channel, ready in
                await RegistrationPayService.submit(
                    configuration: config,
                    transport: transport,
                    token: "test-token-1234",
                    registrationID: id,
                    readiness: ready,
                    quoteUsable: true,
                    quoteFresh: true,
                    consented: true,
                    channel: channel
                )
            }
        )
        let outcome = await MainActor.run { model.outcome }
        XCTAssertEqual(outcome, .outcomeUnknown(message: nil))
        let count = await transport.requests.count
        XCTAssertEqual(count, 1)
    }
}
