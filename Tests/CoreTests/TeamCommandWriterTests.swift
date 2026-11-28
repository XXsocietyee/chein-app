import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

final class TeamCommandWriterTests: XCTestCase {
    @MainActor func testUnknownKeepsTheRequestIDUntil2xxOr4xx() async throws {
        let base = try XCTUnwrap(URL(string: "https://example.test/prod-api/"))
        let approval = try OperationEndpointApproval(baseURL: base, namespace: "team", accountID: 7, paths: TeamCommandWriter.paths)
        let wire = TeamCommandRecorder()
        let writer = try TeamCommandWriter(approval: approval, configuration: try .init(baseURL: base), transport: wire)
        wire.status = 503
        let first = await writer.submit(key: "join-9", path: "api/team/command", fields: ["action": "join"])
        XCTAssertEqual(first, .unknown)
        let savedAwaited = await writer.savedRequestID(for: "join-9")
        let saved = try XCTUnwrap(savedAwaited)
        XCTAssertEqual(saved.count, 32)
        wire.status = 500
        _ = await writer.submit(key: "join-9", path: "api/team/command/query", fields: [:])
        let awaited = await writer.savedRequestID(for: "join-9")
        XCTAssertEqual(awaited, saved)
        XCTAssertEqual(wire.requestIDs, [saved, saved])
        wire.status = 409
        let rejected = await writer.submit(key: "join-9", path: "api/team/command/cancel", fields: [:])
        XCTAssertEqual(rejected, .rejected(409))
        let awaited1 = await writer.savedRequestID(for: "join-9")
        XCTAssertNil(awaited1)
        // Gap #7 (1128 plan): a 2xx alone is no longer success; only `data.state == APPLIED` is.
        wire.status = 200
        wire.payload = #"{"code":200,"data":{"requestId":"r","state":"APPLIED"}}"#
        let applied = await writer.submit(key: "join-9", path: "api/team/command", fields: ["action": "join"])
        XCTAssertEqual(applied, .applied(200))
        let awaited2 = await writer.savedRequestID(for: "join-9")
        XCTAssertNil(awaited2)
        XCTAssertNotEqual(wire.requestIDs.last, saved)
    }

    @MainActor func testQueryAndCancelUseTheSavedCommandAndClearOnlyOnTerminalState() async throws {
        XCTAssertEqual(TeamCommandRecoveryCopy.query, "查询原请求")
        XCTAssertEqual(TeamCommandRecoveryCopy.retry, "按原输入重试")
        XCTAssertEqual(TeamCommandRecoveryCopy.abort, "终止尚未执行的请求")
        XCTAssertEqual(TeamCommandRecoveryCopy.abortNote, "终止只针对未执行的原请求；已经提交的业务不会撤销。")
        let base = try XCTUnwrap(URL(string: "https://example.test/prod-api/"))
        let approval = try OperationEndpointApproval(baseURL: base, namespace: "team", accountID: 7, paths: TeamCommandWriter.paths)
        let wire = TeamCommandRecorder()
        let writer = try TeamCommandWriter(approval: approval, configuration: try .init(baseURL: base), transport: wire)
        let missing = await writer.query(key: "join-9")
        XCTAssertEqual(missing, .unknown)
        XCTAssertTrue(wire.payloads.isEmpty)
        wire.status = 503
        _ = await writer.submit(key: "join-9", path: "api/team/command", fields: ["action": "join", "targetId": "9"])
        let savedID = await writer.savedRequestID(for: "join-9")
        let saved = try XCTUnwrap(savedID)
        wire.status = 200
        wire.payload = #"{"code":200,"data":{"state":"UNKNOWN","requestId":"saved"}}"#
        let pending = await writer.query(key: "join-9")
        XCTAssertEqual(pending, .unknown)
        let pendingSaved = await writer.savedRequestID(for: "join-9")
        XCTAssertEqual(pendingSaved, saved)
        let query = try XCTUnwrap(wire.payloads.last)
        XCTAssertEqual(query["requestId"] as? String, saved)
        XCTAssertEqual(query.count, 1)
        XCTAssertTrue(wire.paths.last?.hasSuffix("api/team/command/query") == true)
        wire.status = 409
        let httpRejection = await writer.query(key: "join-9")
        XCTAssertEqual(httpRejection, .unknown)
        let rejectedSaved = await writer.savedRequestID(for: "join-9")
        XCTAssertEqual(rejectedSaved, saved)
        wire.status = 200
        wire.payload = #"{"code":200,"data":{"state":"CANCELLED"}}"#
        let cancelled = await writer.cancel(key: "join-9", fields: ["action": "join", "targetId": "9"])
        XCTAssertEqual(cancelled, .cancelled(200))
        let cleared = await writer.savedRequestID(for: "join-9")
        XCTAssertNil(cleared)
        let cancel = try XCTUnwrap(wire.payloads.last)
        XCTAssertEqual(cancel["requestId"] as? String, saved)
        XCTAssertEqual(cancel["action"] as? String, "join")
        XCTAssertEqual(cancel["targetId"] as? String, "9")
        XCTAssertTrue(wire.paths.last?.hasSuffix("api/team/command/cancel") == true)
    }
}

/// Gap #7: `/api/team/command` answers HTTP 200 `code:200` with `data.state` (TeamEventCommandService.execute).
final class TeamCommandReceiptTests: XCTestCase {
    @MainActor private func writer(_ wire: TeamCommandRecorder) throws -> TeamCommandWriter {
        let base = try XCTUnwrap(URL(string: "https://example.test/prod-api/"))
        let approval = try OperationEndpointApproval(baseURL: base, namespace: "team", accountID: 7, paths: TeamCommandWriter.paths)
        return try TeamCommandWriter(approval: approval, configuration: try .init(baseURL: base), transport: wire, token: { "player-token" })
    }

    @MainActor func testRejectedCarriesTheServerMessageAndUnknownKeepsTheID() async throws {
        let wire = TeamCommandRecorder()
        let writer = try writer(wire)
        wire.payload = #"{"code":200,"data":{"requestId":"r","state":"REJECTED","errorCode":"TEAM_FULL","message":"队伍已满"}}"#
        let rejected = await writer.submitReceipt(key: "team-9", path: "api/team/command", fields: ["action": "quit", "targetId": "9"])
        XCTAssertEqual(rejected, TeamCommandReceipt(terminal: .rejected(200), errorCode: "TEAM_FULL", message: "队伍已满"))
        let cleared = await writer.savedRequestID(for: "team-9")
        XCTAssertNil(cleared)
        XCTAssertEqual(wire.authorizations.last, "player-token")
        for payload in [#"{"code":200,"data":{"requestId":"r","state":"UNKNOWN"}}"#, #"{"code":200}"#, "not json"] {
            wire.payload = payload
            let seed = TeamCommandWriter.requestID(for: UUID())
            let pending = await writer.submitReceipt(key: "team-9", path: "api/team/command", fields: ["action": "quit", "targetId": "9"], requestID: seed)
            XCTAssertEqual(pending.terminal, .unknown, payload)
            let kept = await writer.savedRequestID(for: "team-9")
            XCTAssertNotNil(kept)
        }
        wire.payload = #"{"code":500,"msg":"原请求号与输入不一致"}"#
        let invalid = await writer.submitReceipt(key: "team-9", path: "api/team/command", fields: ["action": "quit", "targetId": "9"])
        XCTAssertEqual(invalid.terminal, .rejected(200))
        XCTAssertEqual(invalid.message, "原请求号与输入不一致")
    }

    @MainActor func testSeededRequestIDIsTheJournalOperationAndAdoptKeepsIt() async throws {
        let wire = TeamCommandRecorder()
        let writer = try writer(wire)
        let operation = UUID()
        let seed = TeamCommandWriter.requestID(for: operation)
        XCTAssertNotNil(seed.range(of: "^[a-f0-9]{32}$", options: .regularExpression))
        wire.payload = #"{"code":200,"data":{"requestId":"r","state":"APPLIED"}}"#
        _ = await writer.submitReceipt(key: "team-4", path: "api/team/command",
                                       fields: ["action": "kick", "targetId": "4", "memberId": "12"], requestID: seed)
        XCTAssertEqual(wire.requestIDs.last, seed)
        XCTAssertEqual(String(data: try XCTUnwrap(wire.bodies.last), encoding: .utf8),
                       #"{"memberId":"12","targetId":"4","action":"kick","requestId":""# + seed + #""}"#)
        writer.adopt(key: "team-4", requestID: seed)
        wire.payload = #"{"code":200,"data":{"requestId":"r","state":"APPLIED"}}"#
        _ = await writer.query(key: "team-4")
        XCTAssertEqual(wire.requestIDs.last, seed)
    }

    /// TeamHTTPService maps the receipt: APPLIED acknowledges (join-mode with the requested mode), REJECTED keeps the
    /// server text, CANCELLED never ran, UNKNOWN stays pending.
    @MainActor func testServiceMapsCommandReceipts() {
        let id = UUID()
        XCTAssertEqual(TeamHTTPService.decodeCommand(.init(terminal: .applied(200), errorCode: "", message: ""), action: .leave(teamID: 4), operationID: id),
                       .acknowledged(operationID: id, teamID: 4))
        XCTAssertEqual(TeamHTTPService.decodeCommand(.init(terminal: .applied(200), errorCode: "", message: ""), action: .changeJoinMode(teamID: 4, mode: .publicApplication), operationID: id),
                       .joinModeAcknowledged(operationID: id, teamID: 4, mode: .publicApplication))
        XCTAssertEqual(TeamHTTPService.decodeCommand(.init(terminal: .rejected(200), errorCode: "", message: "暂时无法加入该队伍"), action: .leave(teamID: 4), operationID: id),
                       .rejectedMessage(errorCode: "", message: "暂时无法加入该队伍"))
        XCTAssertEqual(TeamHTTPService.decodeCommand(.init(terminal: .rejected(409), errorCode: "", message: ""), action: .disband(teamID: 4), operationID: id), .rejected)
        XCTAssertEqual(TeamHTTPService.decodeCommand(.init(terminal: .cancelled(200), errorCode: "", message: ""), action: .disband(teamID: 4), operationID: id), .notSent)
        XCTAssertEqual(TeamHTTPService.decodeCommand(.unknown, action: .disband(teamID: 4), operationID: id), .unknown)
        XCTAssertEqual(TeamHTTPService.commandFields(.join(teamID: 4, inviteCode: " ABC123 ")), ["action": "join", "targetId": "4", "inviteCode": "ABC123"])
        XCTAssertEqual(TeamHTTPService.commandFields(.changeJoinMode(teamID: 4, mode: .invitation)), ["action": "join-mode", "targetId": "4", "joinMode": "1"])
        XCTAssertEqual(TeamHTTPService.commandFields(.remove(teamID: 4, memberID: 12)), ["action": "kick", "targetId": "4", "memberId": "12"])
        XCTAssertEqual(TeamHTTPService.commandFields(.leave(teamID: 4)), ["action": "quit", "targetId": "4"])
        XCTAssertEqual(TeamHTTPService.commandFields(.disband(teamID: 4)), ["action": "disband", "targetId": "4"])
    }
}

private final class TeamCommandRecorder: HTTPTransport {
    var status = 200
    var payload = #"{"code":200}"#
    var requestIDs: [String] = []
    var paths: [String] = []
    var payloads: [[String: Any]] = []
    var authorizations: [String] = []
    var bodies: [Data] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        authorizations.append(request.value(forHTTPHeaderField: "Authorization") ?? "")
        bodies.append(request.httpBody ?? Data())
        let object = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any]
        requestIDs.append(object?["requestId"] as? String ?? "")
        paths.append(request.url?.path ?? "")
        payloads.append(object ?? [:])
        return (Data(payload.utf8), status)
    }
}
