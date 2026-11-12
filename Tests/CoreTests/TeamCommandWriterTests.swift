import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

final class TeamCommandWriterTests: XCTestCase {
    func testUnknownKeepsTheRequestIDUntil2xxOr4xx() async throws {
        let base = try XCTUnwrap(URL(string: "https://example.test/prod-api/"))
        let approval = try OperationEndpointApproval(baseURL: base, namespace: "team", accountID: 7, paths: TeamCommandWriter.paths)
        let wire = TeamCommandRecorder()
        let writer = try TeamCommandWriter(approval: approval, configuration: try .init(baseURL: base), transport: wire)
        wire.status = 503
        let first = await writer.submit(key: "join-9", path: "api/team/command", fields: ["action": "join"])
        XCTAssertEqual(first, .unknown)
        let saved = try XCTUnwrap(await writer.savedRequestID(for: "join-9"))
        XCTAssertEqual(saved.count, 32)
        wire.status = 500
        _ = await writer.submit(key: "join-9", path: "api/team/command/query", fields: [:])
        XCTAssertEqual(await writer.savedRequestID(for: "join-9"), saved)
        XCTAssertEqual(wire.requestIDs, [saved, saved])
        wire.status = 409
        let rejected = await writer.submit(key: "join-9", path: "api/team/command/cancel", fields: [:])
        XCTAssertEqual(rejected, .rejected(409))
        XCTAssertNil(await writer.savedRequestID(for: "join-9"))
        wire.status = 200
        let applied = await writer.submit(key: "join-9", path: "api/team/command", fields: ["action": "join"])
        XCTAssertEqual(applied, .applied(200))
        XCTAssertNil(await writer.savedRequestID(for: "join-9"))
        XCTAssertNotEqual(wire.requestIDs.last, saved)
    }
}

private final class TeamCommandRecorder: HTTPTransport {
    var status = 200
    var requestIDs: [String] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let object = try JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any]
        requestIDs.append(object?["requestId"] as? String ?? "")
        return (Data(#"{"code":200}"#.utf8), status)
    }
}
