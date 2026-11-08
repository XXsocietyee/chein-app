import XCTest
@testable import QuestifyCore
import Foundation

// Core-visible half of IWP-1: the App-target canceler/transport tests are in Tests/AppUnitTests/BNDCancelTransportTests.swift.
// All values synthetic; no network.
private final class BNDScriptedCanceler: FreeExploreReservationCanceling {
    var quotes: [FreeExploreCancelQuoteOutcome] = []
    var cancelOutcome: FreeExploreCancelOutcome = .unconfirmed
    private(set) var quoteCalls = 0
    private(set) var cancelCalls: [(String, Bool, String)] = []
    func quote(reservationID: String, useWaiver: Bool) async -> FreeExploreCancelQuoteOutcome {
        quoteCalls += 1; return quotes.isEmpty ? .unavailable : quotes.removeFirst()
    }
    func cancel(reservationID: String, useWaiver: Bool, expectedOutcome: String) async -> FreeExploreCancelOutcome {
        cancelCalls.append((reservationID, useWaiver, expectedOutcome)); return cancelOutcome
    }
}

private final class BNDCancelBodyTransport: HTTPTransport {
    var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return (Data(#"{"code":200,"msg":"ok","data":{"id":31,"unitId":21,"registrationId":9001,"holderMemberId":5,"chapterId":11,"offerId":7,"merchantId":3,"startAt":"2026-12-01 10:00:00","status":"CANCELLED","idempotencyKey":"k-1","requestFingerprint":"fp"}}"#.utf8), 200)
    }
}

@MainActor final class BNDCancelCancelerTests: XCTestCase {
    func testQuoteUsesServerExpectedOutcomeVerbatim() async {
        let canceler = BNDScriptedCanceler()
        canceler.quotes = [.quote(FreeExploreCancelQuote(expectedOutcome: "WAIVED:2026-11", canCancel: true, message: "m"))]
        canceler.cancelOutcome = .cancelled(status: "CANCELLED")
        let model = FreeExploreCancelModel(canceler: canceler)
        await model.requestQuote(reservationID: "31", useWaiver: true)
        await model.confirm()
        XCTAssertEqual(canceler.cancelCalls.count, 1)
        XCTAssertEqual(canceler.cancelCalls.first?.2, "WAIVED:2026-11")
        XCTAssertEqual(canceler.cancelCalls.first?.1, true)
    }

    func testCancelBodyAlwaysContainsExpectedOutcome() async throws {
        let transport = BNDCancelBodyTransport()
        let session = try FreeExploreLaunchSession(baseURL: URL(string: "https://example.test")!, accountID: 5, market: "CN",
                                                   namespace: "test", role: "player", epoch: 1, token: "synthetic-test-credential")
        let client = try BundleAPIClient(session: session, authorization: "synthetic-test-credential", transport: transport,
                                         currentSession: { session }, writeAllowed: { true })
        _ = try await client.cancel(reservationID: FreeExploreLaunchID(31), useWaiver: false, expectedOutcome: "LATE_CANCELLED")
        let body = try XCTUnwrap(transport.requests.first?.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["useWaiver", "expectedOutcome"])
        XCTAssertEqual(object["expectedOutcome"] as? String, "LATE_CANCELLED")
        do {
            _ = try await client.cancel(reservationID: FreeExploreLaunchID(31), useWaiver: false, expectedOutcome: "")
            XCTFail("blank expectedOutcome must be refused")
        } catch { XCTAssertEqual(error as? FreeExploreLaunchFailure, .invalid) }
        XCTAssertEqual(transport.requests.count, 1)
    }

    func testUnknownPostOutcomeReadsBackWithoutResend() async {
        let canceler = BNDScriptedCanceler()
        canceler.quotes = [.quote(FreeExploreCancelQuote(expectedOutcome: "CANCELLED", canCancel: true, message: "m"))]
        canceler.cancelOutcome = .unconfirmed
        let model = FreeExploreCancelModel(canceler: canceler)
        await model.requestQuote(reservationID: "31", useWaiver: false)
        await model.confirm()
        XCTAssertEqual(model.state, .awaitingServerConfirmation)
        await model.confirm(); await model.requestQuote(reservationID: "31", useWaiver: false)
        XCTAssertEqual(canceler.cancelCalls.count, 1); XCTAssertEqual(canceler.quoteCalls, 1)
        model.resolveAfterReadback(reservationStatus: "BOOKED")
        XCTAssertEqual(model.state, .idle)
    }

    func testGatedCancelerStillUnavailable() async {
        let gated = GatedFreeExploreReservationCanceler()
        let quote = await gated.quote(reservationID: "31", useWaiver: false)
        let outcome = await gated.cancel(reservationID: "31", useWaiver: false, expectedOutcome: "CANCELLED")
        XCTAssertEqual(quote, .unavailable); XCTAssertEqual(outcome, .unavailable)
    }
}
