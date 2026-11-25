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
        wire.status = 200
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

private final class TeamCommandRecorder: HTTPTransport {
    var status = 200
    var payload = #"{"code":200}"#
    var requestIDs: [String] = []
    var paths: [String] = []
    var payloads: [[String: Any]] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let object = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any]
        requestIDs.append(object?["requestId"] as? String ?? "")
        paths.append(request.url?.path ?? "")
        payloads.append(object ?? [:])
        return (Data(payload.utf8), status)
    }
}
