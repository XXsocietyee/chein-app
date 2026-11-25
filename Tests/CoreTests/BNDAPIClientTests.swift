import XCTest
@testable import QuestifyCore
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// All values synthetic. No request leaves the HTTP double.
final class BNDTransport: HTTPTransport {
    var requests: [URLRequest] = []
    var handler: (URLRequest) async throws -> (Data, Int) = { _ in throw URLError(.timedOut) }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request); return try await handler(request)
    }
}

@MainActor final class BNDAPIClientTests: XCTestCase {
    private let credential = "synthetic-test-credential"
    private func session(epoch: UInt64 = 1) throws -> FreeExploreLaunchSession {
        try FreeExploreLaunchSession(baseURL: URL(string: "https://example.test")!, accountID: 5, market: "CN",
                                     namespace: "test", role: "player", epoch: epoch, token: credential)
    }
    private func id(_ n: Int64) throws -> FreeExploreLaunchID { try FreeExploreLaunchID(n) }
    private func envelope(_ dataJSON: String) -> (Data, Int) { (Data(#"{"code":200,"msg":"ok","data":\#(dataJSON)}"#.utf8), 200) }
    private func makeClient(_ transport: BNDTransport, session: FreeExploreLaunchSession? = nil,
                            current: (() -> FreeExploreLaunchSession?)? = nil,
                            writeAllowed: @escaping () -> Bool = { false },
                            onUnauthorized: @escaping (FreeExploreLaunchSession) -> Void = { _ in }) throws -> BundleAPIClient {
        let s = try session ?? self.session()
        return try BundleAPIClient(session: s, authorization: credential, transport: transport,
                                   currentSession: current ?? { s }, writeAllowed: writeAllowed, onUnauthorized: onUnauthorized)
    }

    func testReadsUseGETWithExactPathQueryAndHeaders() async throws {
        let transport = BNDTransport()
        transport.handler = { [self] request in
            switch request.url?.path {
            case "/api/free-explore/bundle/reservation/31/cancel-quote": return envelope(BNDFixtures.cancelQuoteWaived)
            case "/api/free-explore/bundle/exit-options": return envelope(BNDFixtures.exitOptions)
            default: return envelope(BNDFixtures.receiptFound())
            }
        }
        let client = try makeClient(transport)
        _ = try await client.cancelQuote(reservationID: id(31), useWaiver: true)
        _ = try await client.exitOptions(registrationID: id(9001), unitID: id(21))
        let receipt = try await client.orderReceipt(requestId: " bundle-order:9001 ")
        XCTAssertEqual(receipt.receipt, .found)
        XCTAssertEqual(transport.requests.map { $0.httpMethod }, ["GET", "GET", "GET"])
        XCTAssertEqual(transport.requests[0].url?.query, "useWaiver=true")
        XCTAssertEqual(transport.requests[1].url?.query, "registrationId=9001&unitId=21")
        XCTAssertEqual(transport.requests[2].url?.path, "/api/free-explore/bundle/order/receipt")
        XCTAssertEqual(transport.requests[2].url?.query, "requestId=bundle-order:9001")
        for request in transport.requests {
            XCTAssertNil(request.httpBody)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), credential)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Cache-Control"), "no-store")
        }
    }

    func testBusiness409LoginRequiredIsNotUnauthorized401() async throws {
        let transport = BNDTransport(), session = try self.session()
        var unauthorizedCalls = 0
        transport.handler = { _ in (Data(#"{"code":409,"msg":"请先登录","businessCode":"LOGIN_REQUIRED"}"#.utf8), 200) }
        let client = try makeClient(transport, session: session, onUnauthorized: { _ in unauthorizedCalls += 1 })
        do {
            _ = try await client.cancelQuote(reservationID: id(31), useWaiver: false)
            XCTFail("expected a business failure")
        } catch {
            XCTAssertEqual(error as? FreeExploreLaunchFailure, .response(status: 200, code: 409, businessCode: "LOGIN_REQUIRED", message: nil))
            XCTAssertNil(error as? APIError)
        }
        XCTAssertEqual(unauthorizedCalls, 0)
        // Whereas a real HTTP 401 does retire the matching session exactly once.
        transport.handler = { _ in (Data(), 401) }
        do { _ = try await client.cancelQuote(reservationID: id(31), useWaiver: false); XCTFail("expected 401") }
        catch { XCTAssertEqual(error as? APIError, .unauthorized) }
        XCTAssertEqual(unauthorizedCalls, 1)
        // Write path: LOGIN_REQUIRED is a definite refusal (the pending command must be kept by the caller).
        transport.handler = { _ in (Data(#"{"code":409,"msg":"请先登录","businessCode":"LOGIN_REQUIRED"}"#.utf8), 200) }
        let writer = try makeClient(transport, session: session, writeAllowed: { true }, onUnauthorized: { _ in unauthorizedCalls += 1 })
        do { _ = try await writer.cancel(reservationID: id(31), useWaiver: false, expectedOutcome: "CANCELLED"); XCTFail("expected refusal") }
        catch { XCTAssertEqual(error as? FreeExploreLaunchFailure, .response(status: 200, code: 409, businessCode: "LOGIN_REQUIRED", message: nil)) }
        XCTAssertEqual(unauthorizedCalls, 1)
    }

    func testClientRefusesPostWhenWriteNotAllowed() async throws {
        let transport = BNDTransport()
        transport.handler = { _ in XCTFail("must not reach the network"); throw URLError(.badURL) }
        let client = try makeClient(transport) // default writeAllowed == false
        XCTAssertFalse(client.permitsWrites)
        do { _ = try await client.cancel(reservationID: id(31), useWaiver: false, expectedOutcome: "CANCELLED"); XCTFail("expected disabled") }
        catch { XCTAssertEqual(error as? FreeExploreLaunchFailure, .disabled) }
        let command = try BundleExitDecisionCommand(unitId: id(21), decision: .refundUnfulfilled, targetOfferId: nil, idempotencyKey: "xd-1")
        do { _ = try await client.exitDecision(command); XCTFail("expected disabled") }
        catch { XCTAssertEqual(error as? FreeExploreLaunchFailure, .disabled) }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testWriteSendsExactBodyWhenAllowedAndRequiresExpectedOutcome() async throws {
        let transport = BNDTransport()
        let reservation = #"{"id":31,"unitId":21,"registrationId":9001,"holderMemberId":5,"chapterId":11,"offerId":7,"merchantId":3,"startAt":"2026-12-01 12:00:00","status":"CANCELLED","idempotencyKey":"k-1","requestFingerprint":"fp"}"#
        transport.handler = { [self] _ in envelope(reservation) }
        let client = try makeClient(transport, writeAllowed: { true })
        let result = try await client.cancel(reservationID: id(31), useWaiver: true, expectedOutcome: "WAIVED:2026-11")
        XCTAssertEqual(result.status, "CANCELLED")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/free-explore/bundle/reservation/31/cancel")
        XCTAssertEqual(String(data: try XCTUnwrap(request.httpBody), encoding: .utf8), #"{"expectedOutcome":"WAIVED:2026-11","useWaiver":true}"#)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Length"), String(request.httpBody?.count ?? -1))
        do { _ = try await client.cancel(reservationID: id(31), useWaiver: false, expectedOutcome: ""); XCTFail("empty expectedOutcome") }
        catch { XCTAssertEqual(error as? FreeExploreLaunchFailure, .invalid) }
        XCTAssertEqual(transport.requests.count, 1)
    }

    func testWriteTransportErrorIsOutcomeUnknownNotFailure() async throws {
        let transport = BNDTransport()
        transport.handler = { _ in throw URLError(.networkConnectionLost) }
        let client = try makeClient(transport, writeAllowed: { true })
        do { _ = try await client.cancel(reservationID: id(31), useWaiver: false, expectedOutcome: "CANCELLED"); XCTFail("expected unknown") }
        catch { XCTAssertEqual(error as? FreeExploreLaunchFailure, .outcomeUnknown) }
    }

    func testClientNeverSendsWithoutAuthorizationMatch() async throws {
        // 1. A blank / non-header-safe credential cannot construct a client at all.
        let s = try session()
        for bad in ["", "   ", "tok\nen", "令牌"] {
            XCTAssertThrowsError(try BundleAPIClient(session: s, authorization: bad, transport: BNDTransport(), currentSession: { s }), bad)
        }
        // 2. A session that is no longer the current one never reaches the network (read or write).
        let transport = BNDTransport()
        transport.handler = { _ in XCTFail("must not reach the network"); throw URLError(.badURL) }
        let stale = try makeClient(transport, current: { try? self.session(epoch: 2) }, writeAllowed: { true })
        do { _ = try await stale.cancelQuote(reservationID: id(31), useWaiver: false); XCTFail("expected stale") }
        catch { XCTAssertEqual(error as? FreeExploreLaunchFailure, .staleSession) }
        do { _ = try await stale.cancel(reservationID: id(31), useWaiver: false, expectedOutcome: "CANCELLED"); XCTFail("expected stale") }
        catch { XCTAssertEqual(error as? FreeExploreLaunchFailure, .staleSession) }
        let loggedOut = try makeClient(transport, current: { nil })
        do { _ = try await loggedOut.exitOptions(registrationID: id(9001), unitID: id(21)); XCTFail("expected stale") }
        catch { XCTAssertEqual(error as? FreeExploreLaunchFailure, .staleSession) }
        XCTAssertTrue(transport.requests.isEmpty)
        // 3. Session switches while a read is in flight: the response is discarded.
        let flip = BNDTransport(); var current: FreeExploreLaunchSession? = s
        flip.handler = { [self] _ in current = nil; return envelope(BNDFixtures.exitOptions) }
        let racing = try makeClient(flip, session: s, current: { current })
        do { _ = try await racing.exitOptions(registrationID: id(9001), unitID: id(21)); XCTFail("expected stale") }
        catch { XCTAssertEqual(error as? FreeExploreLaunchFailure, .staleSession) }
        // 4. A write whose session/permission changes in flight is "unknown", never success.
        let wflip = BNDTransport(); var allowed = true
        wflip.handler = { _ in allowed = false; throw URLError(.timedOut) }
        let writer = try makeClient(wflip, session: s, writeAllowed: { allowed })
        do { _ = try await writer.cancel(reservationID: id(31), useWaiver: false, expectedOutcome: "CANCELLED"); XCTFail("expected unknown") }
        catch { XCTAssertEqual(error as? FreeExploreLaunchFailure, .outcomeUnknown) }
    }

    func testResponseForAnotherReservationOrHolderIsMalformed() async throws {
        let transport = BNDTransport()
        transport.handler = { [self] _ in envelope(BNDFixtures.cancelQuoteWaived) }
        let client = try makeClient(transport)
        do { _ = try await client.cancelQuote(reservationID: id(32), useWaiver: true); XCTFail("id mismatch") }
        catch { XCTAssertEqual(error as? FreeExploreLaunchFailure, .malformed) }
        do { _ = try await client.cancelQuote(reservationID: id(31), useWaiver: false); XCTFail("useWaiver echo mismatch") }
        catch { XCTAssertEqual(error as? FreeExploreLaunchFailure, .malformed) }
    }

    func testOversizeResponseMalformed() async throws {
        let transport = BNDTransport()
        let filler = String(repeating: "a", count: 1_048_577)
        transport.handler = { _ in (Data(#"{"code":200,"data":{"pad":"\#(filler)"}}"#.utf8), 200) }
        let client = try makeClient(transport)
        do { _ = try await client.exitOptions(registrationID: id(9001), unitID: id(21)); XCTFail("expected malformed") }
        catch { XCTAssertEqual(error as? FreeExploreLaunchFailure, .malformed) }
        // Same cap on a write: the answer is unusable, so the outcome is unknown rather than malformed.
        let writer = try makeClient(transport, writeAllowed: { true })
        do { _ = try await writer.cancel(reservationID: id(31), useWaiver: false, expectedOutcome: "CANCELLED"); XCTFail("expected unknown") }
        catch { XCTAssertEqual(error as? FreeExploreLaunchFailure, .outcomeUnknown) }
    }

    func testReceiptValidatesEchoAndOwner() async throws {
        let transport = BNDTransport()
        transport.handler = { [self] _ in envelope(BNDFixtures.receiptNotFound) }
        let client = try makeClient(transport)
        let notFound = try await client.orderReceipt(requestId: "bundle-order:9001")
        XCTAssertFalse(notFound.provesNoWrite)
        do { _ = try await client.orderReceipt(requestId: "other-key"); XCTFail("echo mismatch") }
        catch { XCTAssertEqual(error as? FreeExploreLaunchFailure, .malformed) }
        do { _ = try await client.orderReceipt(requestId: "  "); XCTFail("blank") }
        catch { XCTAssertEqual(error as? FreeExploreLaunchFailure, .invalid) }
        // FOUND for another holder (owner 6, not session account 5) is rejected.
        transport.handler = { [self] _ in envelope(BNDFixtures.receiptFound().replacingOccurrences(of: "\"holderMemberId\":5", with: "\"holderMemberId\":6")) }
        do { _ = try await client.orderReceipt(requestId: "bundle-order:9001"); XCTFail("foreign holder") }
        catch { XCTAssertEqual(error as? FreeExploreLaunchFailure, .malformed) }
    }
}
