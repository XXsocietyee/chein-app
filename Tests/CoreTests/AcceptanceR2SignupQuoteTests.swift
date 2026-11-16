#if DEBUG
import Foundation
import XCTest
@testable import QuestifyCore

/// Acceptance R2 F-01/F-02: a refused sign-up quote (`code 500 该主题尚未开售…`) left the footer on
/// "正在核对价格…" forever, and a `payment-readiness` `ready: false` answer was never named next to 立即报名.
@MainActor
private final class R2QuoteService: RegistrationCoordinatingService {
    enum Reply { case quote(String), fail(Error), hold }
    var reply: Reply = .quote(#"{"payAmount":12.5,"pointsUsable":true,"quoteSign":"fixture-sign"}"#)
    private(set) var quoteCount = 0
    private(set) var pending: CheckedContinuation<RegistrationQuote, Error>?
    func quote(_ selection: RegistrationQuoteRequest, token: String) async throws -> RegistrationQuote {
        quoteCount += 1
        switch reply {
        case .quote(let json): return try JSONDecoder().decode(RegistrationQuote.self, from: Data(json.utf8))
        case .fail(let error): throw error
        case .hold: return try await withCheckedThrowingContinuation { pending = $0 }
        }
    }
    func create(_ intent: RegistrationCreateIntent, token: String) async throws -> RegistrationCreateResult { throw APIError.notConfigured }
    func readStatus(registrationID: Int, token: String) async throws -> RegistrationStatusSnapshot { throw APIError.notConfigured }
}

@MainActor
final class AcceptanceR2SignupQuoteTests: XCTestCase {
    private let notOnSale = "该主题尚未开售，开售审核通过后才可报名"

    private func makeFlow(_ service: R2QuoteService, policy: RegistrationUICreationPolicy = .offlineFixture,
                          price: String = "12.5") throws -> RegistrationUIFlow {
        let activity = try JSONDecoder().decode(ActivityDetail.self, from: Data(
            "{\"id\":993031,\"name\":\"Fixture activity\",\"omsTicketList\":[{\"id\":11,\"name\":\"Paid\",\"price\":\(price),\"remainingInventory\":4}]}".utf8))
        let coordinator = RegistrationCoordinator(service: service, makeRequestID: { "fixture-r2-intent" })
        try coordinator.setAccount(id: 1, token: "fixture-only-token")
        let identity = ProfileReadIdentity(accountID: 1, epoch: 1)
        let flow = RegistrationUIFlow(activity: activity, coordinator: coordinator, currentIdentity: { identity },
                                      quoteEnabled: true, creationPolicy: policy)
        flow.open(); flow.setName("Fixture Person"); flow.setPhone("13800000000"); flow.setConsent(true)
        return flow
    }

    func testBusinessRefusalSettlesWithServerMessageAndRetryThenSucceeds() async throws {
        let service = R2QuoteService()
        service.reply = .fail(RegistrationResponseFailure(code: 500, message: notOnSale))
        let flow = try makeFlow(service)
        await flow.requestQuote()
        XCTAssertFalse(flow.isQuoting)
        XCTAssertEqual(flow.quotePhase, .refused(message: notOnSale))
        XCTAssertEqual(flow.confirmationBlock, .quoteUnavailable)
        let notice = flow.checkoutFooterNotice(paymentReadiness: nil)
        XCTAssertEqual(notice, .priceRefused(message: notOnSale))
        XCTAssertNotEqual(notice, .checkingPrice, "A refused quote must not read as still checking")
        XCTAssertEqual(notice?.offersQuoteRetry, true)
        XCTAssertFalse(flow.prepareConfirmation())

        service.reply = .quote(#"{"payAmount":12.5,"pointsUsable":true,"quoteSign":"fixture-sign"}"#)
        await flow.requestQuote()
        XCTAssertEqual(service.quoteCount, 2)
        guard case .priced(let quote) = flow.quotePhase else { return XCTFail("expected a priced quote") }
        XCTAssertEqual(quote.payAmount, Decimal(string: "12.5"))
        XCTAssertNil(flow.confirmationBlock)
        XCTAssertNil(flow.checkoutFooterNotice(paymentReadiness: .init(ready: true, message: "支付服务可用")))
        XCTAssertTrue(flow.prepareConfirmation(), "立即报名 is usable once priced")
    }

    func testHTTPRefusalKeepsEnvelopeMessageAndBareFailureStillSettles() async throws {
        let service = R2QuoteService()
        service.reply = .fail(RegistrationHTTPFailure(statusCode: 500, response: RegistrationResponseFailure(code: 500, message: "  \(notOnSale)  ")))
        let flow = try makeFlow(service)
        await flow.requestQuote()
        XCTAssertEqual(flow.quotePhase, .refused(message: notOnSale))

        service.reply = .fail(RegistrationHTTPFailure(statusCode: 502, response: nil))
        await flow.requestQuote()
        XCTAssertEqual(flow.quotePhase, .refused(message: nil))
        XCTAssertEqual(flow.checkoutFooterNotice(paymentReadiness: nil), .priceRefused(message: nil))

        service.reply = .fail(URLError(.timedOut))
        await flow.requestQuote()
        XCTAssertFalse(flow.isQuoting)
        XCTAssertEqual(flow.quotePhase, .refused(message: nil))
    }

    func testCheckingOnlyWhileTheRequestIsInFlight() async throws {
        let service = R2QuoteService()
        service.reply = .hold
        let flow = try makeFlow(service)
        let task = Task { await flow.requestQuote() }
        for _ in 0..<50 where service.pending == nil { await Task.yield() }
        let pending = try XCTUnwrap(service.pending)
        XCTAssertEqual(flow.quotePhase, .checking)
        XCTAssertEqual(flow.checkoutFooterNotice(paymentReadiness: nil), .checkingPrice)
        XCTAssertEqual(flow.checkoutFooterNotice(paymentReadiness: nil)?.offersQuoteRetry, false)
        pending.resume(throwing: RegistrationResponseFailure(code: 500, message: notOnSale))
        await task.value
        XCTAssertEqual(flow.quotePhase, .refused(message: notOnSale))
        XCTAssertEqual(flow.checkoutFooterNotice(paymentReadiness: nil), .priceRefused(message: notOnSale))
    }

    func testNeverRequestedQuoteOffersRetryInsteadOfSpinning() throws {
        let flow = try makeFlow(R2QuoteService())
        XCTAssertEqual(flow.quotePhase, .notRequested)
        XCTAssertEqual(flow.confirmationBlock, .quoteUnavailable)
        XCTAssertEqual(flow.checkoutFooterNotice(paymentReadiness: nil), .priceNeeded)
        XCTAssertEqual(flow.checkoutFooterNotice(paymentReadiness: nil)?.offersQuoteRetry, true)
    }

    func testPaymentReadinessFalseIsNamedWithItsMessage() async throws {
        let service = R2QuoteService()
        let flow = try makeFlow(service)
        await flow.requestQuote()
        XCTAssertNil(flow.confirmationBlock)
        XCTAssertEqual(flow.checkoutFooterNotice(paymentReadiness: .init(ready: false, message: "支付服务暂不可用")),
                       .paymentUnavailable(message: "支付服务暂不可用"))
        XCTAssertEqual(flow.checkoutFooterNotice(paymentReadiness: .init(ready: false, message: " ")), .paymentUnavailable(message: nil))
        XCTAssertNil(flow.checkoutFooterNotice(paymentReadiness: .init(ready: true, message: nil)))
        XCTAssertNil(flow.checkoutFooterNotice(paymentReadiness: nil), "Not read yet: nothing to claim")

        let free = try makeFlow(R2QuoteService(), price: "0")
        await free.requestQuote()
        XCTAssertNil(free.checkoutFooterNotice(paymentReadiness: .init(ready: false, message: "支付服务暂不可用")),
                     "A free ticket never needs the payment service")
    }

    func testQuoteRefusalOutranksPaymentReadinessAndConsentComesFirstWithoutServerMessage() {
        let notReady = RegistrationPaymentReadiness(ready: false, message: "支付服务暂不可用")
        XCTAssertEqual(RegistrationCheckoutFooterNotice.resolve(block: .quoteUnavailable, quotePhase: .refused(message: notOnSale),
            needsConsentFirst: false, paidTicket: true, paymentReadiness: notReady), .priceRefused(message: notOnSale))
        XCTAssertEqual(RegistrationCheckoutFooterNotice.resolve(block: .quoteUnavailable, quotePhase: .refused(message: nil),
            needsConsentFirst: true, paidTicket: true, paymentReadiness: nil), .consentBeforePrice)
        XCTAssertEqual(RegistrationCheckoutFooterNotice.resolve(block: .quoteUnavailable, quotePhase: .refused(message: notOnSale),
            needsConsentFirst: true, paidTicket: true, paymentReadiness: nil), .priceRefused(message: notOnSale))
        XCTAssertEqual(RegistrationCheckoutFooterNotice.resolve(block: .quoteUnavailable, quotePhase: .checking,
            needsConsentFirst: true, paidTicket: true, paymentReadiness: nil), .checkingPrice)
        XCTAssertNil(RegistrationCheckoutFooterNotice.resolve(block: .missingConsent, quotePhase: .notRequested,
            needsConsentFirst: true, paidTicket: true, paymentReadiness: notReady))
    }

    func testServerMessageIgnoresBlankAndNonServerIssues() {
        XCTAssertEqual(RegistrationCoordinatorIssue.business(.init(code: 500, message: " \(notOnSale)\n")).serverMessage, notOnSale)
        XCTAssertNil(RegistrationCoordinatorIssue.business(.init(code: 500, message: "   ")).serverMessage)
        XCTAssertNil(RegistrationCoordinatorIssue.http(.init(statusCode: 503, response: nil)).serverMessage)
        XCTAssertNil(RegistrationCoordinatorIssue.transport(code: -1001).serverMessage)
        XCTAssertNil(RegistrationCoordinatorIssue.api(.malformedResponse).serverMessage)
    }
}
#endif
