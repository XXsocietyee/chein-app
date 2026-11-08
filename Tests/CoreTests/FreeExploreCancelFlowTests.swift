#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

@MainActor final class FreeExploreCancelFlowTests: XCTestCase {
    private final class FakeCanceler: FreeExploreReservationCanceling {
        var quoteCalls: [(String, Bool)] = []
        var cancelCalls: [(String, Bool, String)] = []
        var quoteOutcome: FreeExploreCancelQuoteOutcome
        var cancelOutcome: FreeExploreCancelOutcome
        init(quote: FreeExploreCancelQuoteOutcome, cancel: FreeExploreCancelOutcome) { quoteOutcome = quote; cancelOutcome = cancel }
        func quote(reservationID: String, useWaiver: Bool) async -> FreeExploreCancelQuoteOutcome {
            quoteCalls.append((reservationID, useWaiver)); return quoteOutcome
        }
        func cancel(reservationID: String, useWaiver: Bool, expectedOutcome: String) async -> FreeExploreCancelOutcome {
            cancelCalls.append((reservationID, useWaiver, expectedOutcome)); return cancelOutcome
        }
    }

    private let quote = FreeExploreCancelQuote(expectedOutcome: "WAIVED:2026-11", canCancel: true, message: "ok")

    func testCancelSendsServerQuoteOutcomeOnlyAfterConfirm() async {
        let fake = FakeCanceler(quote: .quote(quote), cancel: .cancelled(status: "CANCELLED"))
        let model = FreeExploreCancelModel(canceler: fake)
        await model.requestQuote(reservationID: "88", useWaiver: true)
        XCTAssertEqual(model.state, .awaitingConfirmation(reservationID: "88", useWaiver: true, quote: quote))
        XCTAssertTrue(fake.cancelCalls.isEmpty, "quote alone never cancels")
        await model.confirm()
        XCTAssertEqual(fake.cancelCalls.count, 1)
        XCTAssertEqual(fake.cancelCalls[0].0, "88")
        XCTAssertEqual(fake.cancelCalls[0].1, true)
        XCTAssertEqual(fake.cancelCalls[0].2, "WAIVED:2026-11")
        XCTAssertEqual(model.state, .cancelled(status: "CANCELLED"))
    }

    func testGatedCancelerNeverShowsCancelled() async {
        let model = FreeExploreCancelModel(canceler: GatedFreeExploreReservationCanceler())
        await model.requestQuote(reservationID: "88", useWaiver: false)
        XCTAssertEqual(model.state, .unavailable)
        await model.confirm()
        XCTAssertEqual(model.state, .unavailable)
    }

    func testQuoteThatCannotCancelNeverReachesConfirm() async {
        let blocked = FreeExploreCancelQuote(expectedOutcome: "NONE", canCancel: false, message: "")
        let fake = FakeCanceler(quote: .quote(blocked), cancel: .cancelled(status: "CANCELLED"))
        let model = FreeExploreCancelModel(canceler: fake)
        await model.requestQuote(reservationID: "88", useWaiver: false)
        if case .failed = model.state {} else { XCTFail("expected failure") }
        await model.confirm()
        XCTAssertTrue(fake.cancelCalls.isEmpty)
    }

    func testAmbiguousAnswerIsNotCancelledUntilReadbackAndBlocksRepeat() async {
        let fake = FakeCanceler(quote: .quote(quote), cancel: .unconfirmed)
        let model = FreeExploreCancelModel(canceler: fake)
        await model.requestQuote(reservationID: "88", useWaiver: false)
        await model.confirm()
        XCTAssertEqual(model.state, .awaitingServerConfirmation)
        await model.requestQuote(reservationID: "88", useWaiver: false)
        XCTAssertEqual(fake.quoteCalls.count, 1, "no new quote while the original is unresolved")
        model.resolveAfterReadback(reservationStatus: "BOOKED")
        XCTAssertEqual(model.state, .idle)
    }

    func testRejectionShowsServerMessage() async {
        let fake = FakeCanceler(quote: .quote(quote), cancel: .rejected(message: "waiver used"))
        let model = FreeExploreCancelModel(canceler: fake)
        await model.requestQuote(reservationID: "88", useWaiver: true)
        await model.confirm()
        XCTAssertEqual(model.state, .failed("waiver used"))
    }
}
#endif
