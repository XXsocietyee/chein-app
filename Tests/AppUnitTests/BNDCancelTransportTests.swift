import XCTest
@testable import Questify

// All values synthetic. Nothing leaves the HTTP double.
private final class BNDCancelStub: HTTPTransport {
    var requests: [URLRequest] = []
    var handler: (URLRequest) async throws -> (Data, Int) = { _ in throw URLError(.timedOut) }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request); return try await handler(request)
    }
}

private let token = "synthetic-test-credential"
private let base = URL(string: "https://example.test")!

private func quoteJSON(outcome: String, expected: String, waiver: Bool, canCancel: Bool = true) -> Data {
    Data(#"{"code":200,"msg":"ok","data":{"reservationId":31,"registrationId":9001,"holderMemberId":5,"version":0,"status":"BOOKED","asOf":1767000000000,"useWaiver":\#(waiver),"outcome":"\#(outcome)","expectedOutcome":"\#(expected)","canCancel":\#(canCancel)}}"#.utf8)
}
private func reservationJSON(status: String) -> Data {
    Data(#"{"code":200,"msg":"ok","data":{"id":31,"unitId":21,"registrationId":9001,"holderMemberId":5,"chapterId":11,"offerId":7,"merchantId":3,"startAt":"2026-12-01 10:00:00","status":"\#(status)","idempotencyKey":"k-1","requestFingerprint":"fp"}}"#.utf8)
}

@MainActor final class BNDCancelTransportTests: XCTestCase {
    private func context() throws -> RuntimeDependencyContext {
        RuntimeDependencyContext(market: .china, baseURL: base, role: "player",
                                 session: try PlayExperienceSession(accountID: 5, epoch: 1, namespace: "test", token: token))
    }
    private func session() throws -> FreeExploreLaunchSession {
        try FreeExploreLaunchSession(baseURL: base, accountID: 5, market: "CN", namespace: "test", role: "player", epoch: 1, token: token)
    }
    private func rig(writeAllowed: @escaping () -> Bool = { true }) throws
        -> (stub: BNDCancelStub, transport: BundleCancelTransport, canceler: BundleCancelCanceler) {
        let stub = BNDCancelStub(); let ctx = try context(); let s = try session()
        let transport = try BundleCancelTransport(context: ctx, underlying: stub, current: { ctx }, writeAllowed: writeAllowed)
        let client = try BundleAPIClient(session: s, authorization: token, transport: transport,
                                         currentSession: { s }, writeAllowed: writeAllowed)
        return (stub, transport, BundleCancelCanceler(client: client))
    }
    private func request(_ method: String, _ path: String, query: String? = nil, body: String? = nil) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://example.test/api/free-explore/bundle/" + path + (query.map { "?" + $0 } ?? ""))!)
        request.httpMethod = method
        request.setValue(token, forHTTPHeaderField: "Authorization")
        if let body {
            let data = Data(body.utf8); request.httpBody = data
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.setValue(String(data.count), forHTTPHeaderField: "Content-Length")
        }
        return request
    }
    private func refused(_ transport: BundleCancelTransport, _ request: URLRequest, file: StaticString = #filePath, line: UInt = #line) async {
        do { _ = try await transport.send(request); XCTFail("expected refusal", file: file, line: line) } catch {}
    }

    func testTransportRejectsAnyOtherPathOrMethod() async throws {
        let r = try rig(); let good = #"{"useWaiver":false,"expectedOutcome":"CANCELLED"}"#
        r.stub.handler = { _ in (quoteJSON(outcome: "CANCELLED", expected: "CANCELLED", waiver: false), 200) }
        // Other routes, ids, queries, methods.
        await refused(r.transport, request("GET", "order", query: "registrationId=9001"))
        await refused(r.transport, request("GET", "reservation/31/cancel-quote"))
        await refused(r.transport, request("GET", "reservation/31/cancel-quote", query: "useWaiver=maybe"))
        await refused(r.transport, request("GET", "reservation/31/cancel-quote", query: "useWaiver=true&x=1"))
        await refused(r.transport, request("GET", "reservation/0/cancel-quote", query: "useWaiver=true"))
        await refused(r.transport, request("GET", "reservation/031/cancel-quote", query: "useWaiver=true"))
        await refused(r.transport, request("GET", "reservation/3a/cancel-quote", query: "useWaiver=true"))
        await refused(r.transport, request("GET", "reservation/31/cancel", query: "useWaiver=true"))
        await refused(r.transport, request("POST", "reservation/31/cancel-quote", body: good))
        await refused(r.transport, request("POST", "reservation", body: good))
        await refused(r.transport, request("POST", "order/refund-quote", body: good))
        await refused(r.transport, request("PUT", "reservation/31/cancel", body: good))
        await refused(r.transport, request("DELETE", "reservation/31/cancel"))
        // POST body shape: missing/extra/blank/ill-typed fields, query, content type, credential.
        await refused(r.transport, request("POST", "reservation/31/cancel", body: #"{"useWaiver":false}"#))
        await refused(r.transport, request("POST", "reservation/31/cancel", body: #"{"expectedOutcome":"CANCELLED"}"#))
        await refused(r.transport, request("POST", "reservation/31/cancel", body: #"{"useWaiver":false,"expectedOutcome":""}"#))
        await refused(r.transport, request("POST", "reservation/31/cancel", body: #"{"useWaiver":"no","expectedOutcome":"CANCELLED"}"#))
        await refused(r.transport, request("POST", "reservation/31/cancel", body: #"{"useWaiver":false,"expectedOutcome":"CANCELLED","x":1}"#))
        await refused(r.transport, request("POST", "reservation/31/cancel", query: "x=1", body: good))
        var wrongType = request("POST", "reservation/31/cancel", body: good)
        wrongType.setValue("text/plain", forHTTPHeaderField: "Content-Type"); await refused(r.transport, wrongType)
        var wrongToken = request("GET", "reservation/31/cancel-quote", query: "useWaiver=true")
        wrongToken.setValue("other-token", forHTTPHeaderField: "Authorization"); await refused(r.transport, wrongToken)
        var foreign = request("GET", "reservation/31/cancel-quote", query: "useWaiver=true")
        foreign.url = URL(string: "https://other.example/api/free-explore/bundle/reservation/31/cancel-quote?useWaiver=true"); await refused(r.transport, foreign)
        XCTAssertTrue(r.stub.requests.isEmpty, "no refused request may reach the network")
        // The two allowed shapes pass.
        _ = try await r.transport.send(request("GET", "reservation/31/cancel-quote", query: "useWaiver=true"))
        r.stub.handler = { _ in (reservationJSON(status: "CANCELLED"), 200) }
        _ = try await r.transport.send(request("POST", "reservation/31/cancel", body: good))
        XCTAssertEqual(r.stub.requests.map { $0.httpMethod }, ["GET", "POST"])
    }

    func testPostRefusedWhenWriteNotAllowed() async throws {
        let r = try rig(writeAllowed: { false })
        await refused(r.transport, request("POST", "reservation/31/cancel", body: #"{"useWaiver":false,"expectedOutcome":"CANCELLED"}"#))
        XCTAssertTrue(r.stub.requests.isEmpty)
    }

    func testQuoteUsesServerExpectedOutcomeVerbatim() async throws {
        let r = try rig()
        r.stub.handler = { _ in (quoteJSON(outcome: "WAIVED", expected: "WAIVED:2026-11", waiver: true), 200) }
        let model = FreeExploreCancelModel(canceler: r.canceler)
        await model.requestQuote(reservationID: "31", useWaiver: true)
        guard case .awaitingConfirmation(_, _, let quote) = model.state else { return XCTFail("\(model.state)") }
        XCTAssertEqual(quote.expectedOutcome, "WAIVED:2026-11")
        r.stub.handler = { _ in (reservationJSON(status: "CANCELLED"), 200) }
        await model.confirm()
        XCTAssertEqual(model.state, .cancelled(status: "CANCELLED"))
        let body = try XCTUnwrap(r.stub.requests.last?.httpBody)
        XCTAssertEqual(try JSONSerialization.jsonObject(with: body) as? NSDictionary,
                       ["useWaiver": true, "expectedOutcome": "WAIVED:2026-11"] as NSDictionary)
    }

    func testCancelBodyAlwaysContainsExpectedOutcome() async throws {
        let r = try rig()
        r.stub.handler = { _ in (reservationJSON(status: "CANCELLED"), 200) }
        _ = await r.canceler.cancel(reservationID: "31", useWaiver: false, expectedOutcome: "CANCELLED")
        let body = try XCTUnwrap(r.stub.requests.last?.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(object["expectedOutcome"] as? String, "CANCELLED"); XCTAssertEqual(object["useWaiver"] as? Bool, false)
        let before = r.stub.requests.count
        let blank = await r.canceler.cancel(reservationID: "31", useWaiver: false, expectedOutcome: "")
        XCTAssertEqual(blank, .rejected(message: "")); XCTAssertEqual(r.stub.requests.count, before)
    }

    func testQuoteChangedForcesReQuoteAndNeverAutoConfirms() async throws {
        let r = try rig(); var step = 0
        r.stub.handler = { request in
            if request.httpMethod == "GET" {
                step += 1
                return (quoteJSON(outcome: step == 1 ? "CANCELLED" : "LATE_CANCELLED",
                                  expected: step == 1 ? "CANCELLED" : "LATE_CANCELLED", waiver: false), 200)
            }
            return (Data(#"{"code":409,"msg":"changed","businessCode":"BUNDLE_CANCEL_QUOTE_CHANGED"}"#.utf8), 200)
        }
        let model = FreeExploreCancelModel(canceler: r.canceler)
        await model.requestQuote(reservationID: "31", useWaiver: false)
        await r.canceler.confirm(on: model)
        guard case .awaitingConfirmation(_, _, let quote) = model.state else { return XCTFail("\(model.state)") }
        XCTAssertEqual(quote.expectedOutcome, "LATE_CANCELLED")
        XCTAssertEqual(r.stub.requests.filter { $0.httpMethod == "POST" }.count, 1, "the new quote must wait for the user")
        XCTAssertEqual(r.stub.requests.filter { $0.httpMethod == "GET" }.count, 2)
    }

    func testLateCancelledOutcomeShownAsPenaltyNotFree() async throws {
        let r = try rig()
        r.stub.handler = { _ in (quoteJSON(outcome: "LATE_CANCELLED", expected: "LATE_CANCELLED", waiver: false), 200) }
        guard case .quote(let late) = await r.canceler.quote(reservationID: "31", useWaiver: false) else { return XCTFail("no quote") }
        XCTAssertEqual(late.expectedOutcome, "LATE_CANCELLED")
        XCTAssertTrue(late.message.contains("迟到") || late.message.lowercased().contains("late"))
        XCTAssertFalse(late.message.hasPrefix("可免费") || late.message.hasPrefix("Free"))
        // A waiver quote the user did not request is never offered.
        r.stub.handler = { _ in (quoteJSON(outcome: "WAIVED", expected: "WAIVED:2026-11", waiver: false), 200) }
        let unrequested = await r.canceler.quote(reservationID: "31", useWaiver: false)
        XCTAssertEqual(unrequested, .failed(message: ""))
    }

    func testUnknownPostOutcomeReadsBackWithoutResend() async throws {
        let r = try rig()
        r.stub.handler = { request in
            request.httpMethod == "GET" ? (quoteJSON(outcome: "CANCELLED", expected: "CANCELLED", waiver: false), 200) : (Data(), 503)
        }
        let model = FreeExploreCancelModel(canceler: r.canceler)
        await model.requestQuote(reservationID: "31", useWaiver: false)
        await r.canceler.confirm(on: model)
        XCTAssertEqual(model.state, .awaitingServerConfirmation)
        let posts = r.stub.requests.filter { $0.httpMethod == "POST" }.count
        XCTAssertEqual(posts, 1)
        await model.confirm()   // no-op outside awaitingConfirmation
        await model.requestQuote(reservationID: "31", useWaiver: false)   // ignored while awaiting
        XCTAssertEqual(r.stub.requests.filter { $0.httpMethod == "POST" }.count, 1)
        XCTAssertEqual(r.stub.requests.filter { $0.httpMethod == "GET" }.count, 1, "no new quote while awaiting")
        model.resolveAfterReadback(reservationStatus: "CANCELLED")
        XCTAssertEqual(model.state, .cancelled(status: "CANCELLED"))
    }

    func testGatedFactoryStillUnavailableByDefault() async throws {
        let canceler = FreeExploreCancelFactory.makeCanceler()
        XCTAssertTrue(canceler is GatedFreeExploreReservationCanceler)
        let quote = await canceler.quote(reservationID: "31", useWaiver: false)
        let outcome = await canceler.cancel(reservationID: "31", useWaiver: false, expectedOutcome: "CANCELLED")
        XCTAssertEqual(quote, .unavailable); XCTAssertEqual(outcome, .unavailable)
    }

    func testNoLocalTwelveHourCalculation() throws {
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("App")
        for name in ["BundleCancelTransport.swift", "BundleCancelCanceler.swift", "BundleCancelView.swift"] {
            let source = try String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
            for pattern in [#"\b12\b"#, #"43_?200"#, #"\b3_?600\b"#, #"timeIntervalSince"#, #"Calendar\."#, #"\bDate\("#] {
                XCTAssertNil(source.range(of: pattern, options: .regularExpression), "\(name) matches \(pattern)")
            }
        }
    }
}
