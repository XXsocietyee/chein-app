import XCTest
@testable import QuestifyCore

/// RM-02 (`OWN-25.1` & `OWN-READ-全队共享提示-跳过-计时-团队总分`):
/// Ports mini-program shared hints, skips, shared timer start/countdown, team total score
/// (`TEAM_FIRST_SOLVE_NODES`), and `/api/play/help/shared` cooperation semantics.
final class Rm02TeamSharedPoolTests: XCTestCase {
    private final class StubTransport: HTTPTransport, @unchecked Sendable {
        var responses: [Result<(Data, Int), Error>] = []
        var requests: [URLRequest] = []

        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            guard !responses.isEmpty else { throw URLError(.cannotConnectToHost) }
            switch responses.removeFirst() {
            case .success(let pair): return pair
            case .failure(let error): throw error
            }
        }
    }

    private func config() throws -> APIConfiguration {
        try APIConfiguration(baseURL: URL(string: "https://api.example.test/prod-api")!)
    }

    @MainActor
    func testOwn251SharedSkipAndIdempotentRecoverySyncTeamScore() async throws {
        let initialPool = #"{"teamId":5,"topicId":3,"activityId":0,"enabled":true,"hintsTotal":3,"hintsUsed":0,"hintsLeft":3,"skipsTotal":2,"skipsUsed":0,"skipsLeft":2,"timerLimitSec":600,"timerStartedAt":null,"timerDeadline":null,"timerExpired":false,"teamScore":10,"scoreBasis":"TEAM_FIRST_SOLVE_NODES","solvedNodeIds":[1],"version":1,"frozenAt":"2026-11-14T00:00:00"}"#
        let afterSkipPool = #"{"teamId":5,"topicId":3,"activityId":0,"enabled":true,"hintsTotal":3,"hintsUsed":0,"hintsLeft":3,"skipsTotal":2,"skipsUsed":1,"skipsLeft":1,"timerLimitSec":600,"timerStartedAt":"2026-11-14T00:01:00Z","timerDeadline":"2026-11-14T00:11:00Z","timerExpired":false,"teamScore":20,"scoreBasis":"TEAM_FIRST_SOLVE_NODES","solvedNodeIds":[1,9],"version":2,"frozenAt":"2026-11-14T00:00:00"}"#

        let transport = StubTransport()
        transport.responses = [.success((Data(#"{"code":200,"data":\#(initialPool)}"#.utf8), 200))]
        let service = TeamPoolService(configuration: try config(), transport: transport, token: { "token-1234" })
        var syncedPools: [TeamPoolSnapshot] = []
        let model = TeamPoolHintModel(service: service, nodeID: 9, resolveTeam: { 5 })
        model.onPoolUpdated = { syncedPools.append($0) }

        await model.load()
        XCTAssertTrue(model.canRequestSkip)
        XCTAssertTrue(model.canStartTimer)
        XCTAssertEqual(model.pool?.teamScore, 10)

        // Timeout/unknown on POST /api/team/pool/skip preserves requestId for receipt lookup
        transport.responses = [.failure(URLError(.timedOut))]
        await model.requestSkip()
        XCTAssertEqual(model.notice, .unknown)
        XCTAssertTrue(model.canRecover)

        let body = try XCTUnwrap(transport.requests.last?.httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as! [String: Any]
        let reqID = try XCTUnwrap(json["requestId"] as? String)
        XCTAssertEqual(transport.requests.last?.url?.path, "/prod-api/api/team/pool/skip")

        let receiptJSON = #"{"requestId":"\#(reqID)","kind":"SKIP","nodeId":9,"consumed":true,"byMemberId":7,"pool":\#(afterSkipPool)}"#
        transport.responses = [.success((Data(#"{"code":200,"data":{"requestId":"\#(reqID)","state":"APPLIED","result":\#(receiptJSON)}}"#.utf8), 200))]
        await model.recover()

        XCTAssertEqual(model.skipResult?.kind, .skip)
        XCTAssertFalse(model.skippedByTeam)
        XCTAssertTrue(model.isNodeSolvedByTeam)
        XCTAssertEqual(model.pool?.skipsLeft, 1)
        XCTAssertEqual(model.pool?.teamScore, 20)
        XCTAssertEqual(model.pool?.scoreBasis, "TEAM_FIRST_SOLVE_NODES")
        XCTAssertEqual(model.pool?.solvedNodeIds, [1, 9])
        XCTAssertEqual(syncedPools.last?.teamScore, 20)
    }

    @MainActor
    func testOwn251TimerStartAndDeadlineCountdown() async throws {
        let beforeTimer = #"{"teamId":5,"topicId":3,"activityId":0,"enabled":true,"hintsTotal":3,"hintsUsed":0,"hintsLeft":3,"skipsTotal":1,"skipsUsed":0,"skipsLeft":1,"timerLimitSec":300,"timerStartedAt":null,"timerDeadline":null,"timerExpired":false,"teamScore":0,"scoreBasis":"TEAM_FIRST_SOLVE_NODES","solvedNodeIds":[],"version":1,"frozenAt":"2026-11-14T00:00:00"}"#
        let startedTimer = #"{"teamId":5,"topicId":3,"activityId":0,"enabled":true,"hintsTotal":3,"hintsUsed":0,"hintsLeft":3,"skipsTotal":1,"skipsUsed":0,"skipsLeft":1,"timerLimitSec":300,"timerStartedAt":"2026-11-14T01:00:00Z","timerDeadline":"2026-11-14T01:05:00Z","timerExpired":false,"teamScore":0,"scoreBasis":"TEAM_FIRST_SOLVE_NODES","solvedNodeIds":[],"version":2,"frozenAt":"2026-11-14T00:00:00"}"#

        let transport = StubTransport()
        transport.responses = [
            .success((Data(#"{"code":200,"data":\#(beforeTimer)}"#.utf8), 200)),
            .success((Data(#"{"code":200,"data":\#(startedTimer)}"#.utf8), 200)),
        ]
        let service = TeamPoolService(configuration: try config(), transport: transport, token: { "token-1234" })
        let model = TeamPoolHintModel(service: service, nodeID: 0, resolveTeam: { 5 })

        await model.load()
        XCTAssertTrue(model.canStartTimer)
        await model.startTimer()

        XCTAssertEqual(transport.requests.last?.url?.path, "/prod-api/api/team/pool/timer/start")
        let pool = try XCTUnwrap(model.pool)
        let deadline = try XCTUnwrap(pool.timerDeadlineDate)
        XCTAssertEqual(pool.remainingTimerSeconds(at: deadline.addingTimeInterval(-95)), 95)
        XCTAssertEqual(pool.remainingTimerSeconds(at: deadline.addingTimeInterval(5)), 0)
        XCTAssertTrue(pool.isTimerExpired(at: deadline.addingTimeInterval(5)))
    }
}
