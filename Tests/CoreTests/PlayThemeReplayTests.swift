import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private final class ReplayHTTP: HTTPTransport {
    var requests: [URLRequest] = []
    var script: [(Data, Int)] = []
    var thrown: Error?
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        if let thrown { throw thrown }
        return script.isEmpty ? (Data(#"{"code":200,"data":{}}"#.utf8), 200) : script.removeFirst()
    }
}

@MainActor final class PlayThemeReplayTests: XCTestCase {
    private func service(_ http: any HTTPTransport, base: String = "https://fixture.example/root/") throws -> PlayExperienceService {
        PlayExperienceService(configuration: try .init(baseURL: URL(string: base)!), transport: http, enabled: [.reads])
    }

    private func envelope(_ data: String, code: Int = 200) -> (Data, Int) {
        (Data(#"{"code":\#(code),"data":\#(data)}"#.utf8), code == 401 ? 401 : 200)
    }

    private func allowed(_ session: Int = 41) -> (Data, Int) {
        envelope(#"{"sessionId":\#(session),"topicId":7,"replayAllowed":true,"scope":"SOLO"}"#)
    }

    func testReplayAllowedIsStrictJSONTrue() throws {
        let yes = try JSONDecoder().decode(PlayWireValue.self, from: Data(#"{"sessionId":41,"replayAllowed":true,"playInstanceId":"replay:9"}"#.utf8))
        let facts = try XCTUnwrap(PlayThemeReplayFacts(yes))
        XCTAssertTrue(facts.replayAllowed)
        XCTAssertTrue(facts.confirmsReplay(of: 9))
        XCTAssertFalse(facts.confirmsReplay(of: 41))
        for raw in [#"{"sessionId":41,"replayAllowed":1}"#, #"{"sessionId":41,"replayAllowed":"true"}"#, #"{"sessionId":41}"#, #"{"sessionId":41,"scope":"TEAM","replayAllowed":true}"#] {
            let facts = try XCTUnwrap(PlayThemeReplayFacts(JSONDecoder().decode(PlayWireValue.self, from: Data(raw.utf8))))
            if raw.contains("TEAM") { XCTAssertTrue(facts.isTeam) } else { XCTAssertFalse(facts.replayAllowed) }
        }
        XCTAssertNil(PlayThemeReplayFacts(try JSONDecoder().decode(PlayWireValue.self, from: Data(#"{"sessionId":0,"replayAllowed":true}"#.utf8))))
    }

    func testPostsOnlySessionIdThenAcceptsReplayInstance() async throws {
        let http = ReplayHTTP()
        http.script = [allowed(), envelope(#"{"sessionId":88}"#), envelope(#"{"sessionId":88,"playInstanceId":"replay:41"}"#)]
        let api = try service(http, base: "https://www.chengyinhub.com/prod-api/")
        var minted = 0
        let done = await PlayThemeReplayExchange.submit(service: api, topicID: 7, sessionID: 41, token: "fixture-token",
            attempt: nil, makeRequestID: { minted += 1; return "req-1" })
        XCTAssertTrue(done.confirmed)
        XCTAssertNil(done.attempt)
        XCTAssertEqual(minted, 1)
        XCTAssertEqual(http.requests.count, 3)
        XCTAssertEqual(http.requests[0].httpMethod, "GET")
        XCTAssertEqual(http.requests[0].url?.host, "www.chengyinhub.com")
        XCTAssertEqual(http.requests[0].url?.query, "sessionId=41&topicId=7")
        XCTAssertEqual(http.requests[1].httpMethod, "POST")
        XCTAssertEqual(http.requests[1].url?.path, "/prod-api/api/play/theme/replay")
        XCTAssertNil(http.requests[1].url?.query)
        XCTAssertEqual(http.requests[1].httpBody, Data(#"{"sessionId":41}"#.utf8))
        XCTAssertEqual(http.requests[2].url?.query, "sessionId=88&topicId=7")
        let body = String(data: http.requests[1].httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertFalse(body.contains("amount"))
        XCTAssertFalse(body.contains("payChannel"))
        XCTAssertFalse(body.contains("requestId"))
    }

    func testRefusesUnlessAllowedAndSessionMatches() async throws {
        let cases = [
            #"{"sessionId":41,"replayAllowed":false}"#,
            #"{"sessionId":41,"replayAllowed":1}"#,
            #"{"sessionId":42,"replayAllowed":true}"#,
            #"{"sessionId":41,"replayAllowed":true,"scope":"TEAM"}"#
        ]
        for raw in cases {
            let http = ReplayHTTP()
            http.script = [envelope(raw)]
            let status = await PlayThemeReplayExchange.submit(service: try service(http), topicID: 7, sessionID: 41,
                token: "fixture-token", attempt: nil, makeRequestID: { "req" })
            XCTAssertFalse(status.confirmed)
            XCTAssertNil(status.attempt)
            XCTAssertEqual(http.requests.map(\.httpMethod), ["GET"], raw)
        }
    }

    func testUnknownKeepsTheRequestIDAndDoesNotPostAgain() async throws {
        let http = ReplayHTTP()
        http.script = [allowed(), (Data(#"{"code":500}"#.utf8), 500), allowed(), allowed()]
        let api = try service(http)
        let first = await PlayThemeReplayExchange.submit(service: api, topicID: 7, sessionID: 41, token: "fixture-token",
            attempt: nil, makeRequestID: { "req-kept" })
        XCTAssertFalse(first.confirmed)
        XCTAssertEqual(first.attempt?.requestID, "req-kept")
        let posts = http.requests.filter { $0.httpMethod == "POST" }
        XCTAssertEqual(posts.count, 1)
        let second = await PlayThemeReplayExchange.submit(service: api, topicID: 7, sessionID: 41, token: "fixture-token",
            attempt: first.attempt, makeRequestID: { XCTFail("minted a replacement"); return "req-new" })
        XCTAssertFalse(second.confirmed)
        XCTAssertEqual(second.attempt?.requestID, "req-kept")
        XCTAssertEqual(http.requests.filter { $0.httpMethod == "POST" }.count, 1)
    }

    func testTransportErrorStaysUnknown() async throws {
        let delayed = DelayedThrowHTTP(first: allowed().0)
        let api = try service(delayed)
        let status = await PlayThemeReplayExchange.submit(service: api, topicID: 7, sessionID: 41, token: "fixture-token",
            attempt: nil, makeRequestID: { "req-net" })
        XCTAssertFalse(status.confirmed)
        XCTAssertEqual(status.attempt?.requestID, "req-net")
        XCTAssertEqual(delayed.requests.filter { $0.httpMethod == "POST" }.count, 1)
    }

    func testBusinessRejectionDoesNotClaimSuccess() async throws {
        let http = ReplayHTTP()
        http.script = [allowed(), envelope(#"{}"#, code: 409)]
        let status = await PlayThemeReplayExchange.submit(service: try service(http), topicID: 7, sessionID: 41,
            token: "fixture-token", attempt: nil, makeRequestID: { "req-no" })
        XCTAssertFalse(status.confirmed)
        XCTAssertNil(status.attempt)
        XCTAssertFalse(status.showsButton)
    }

    func testReadBackMissKeepsTheSameRequest() async throws {
        let http = ReplayHTTP()
        http.script = [allowed(), envelope(#"{"sessionId":41}"#), envelope(#"{"sessionId":41,"playInstanceId":"other"}"#)]
        let status = await PlayThemeReplayExchange.submit(service: try service(http), topicID: 7, sessionID: 41,
            token: "fixture-token", attempt: nil, makeRequestID: { "req-wait" })
        XCTAssertFalse(status.confirmed)
        XCTAssertEqual(status.attempt?.requestID, "req-wait")
        XCTAssertTrue(status.showsButton)
    }
}

private final class DelayedThrowHTTP: HTTPTransport {
    var requests: [URLRequest] = []
    let first: Data
    init(first: Data) { self.first = first }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        if requests.count == 1 { return (first, 200) }
        if request.httpMethod == "POST" { throw URLError(.networkConnectionLost) }
        return (Data(#"{"code":200,"data":{"sessionId":41}}"#.utf8), 200)
    }
}
