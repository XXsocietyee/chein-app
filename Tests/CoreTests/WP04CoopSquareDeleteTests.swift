import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// WP-04 paths come from the client types. The capability table is not the source of the request.
final class WP04CoopSquareDeleteTests: XCTestCase {
    func testClientTypesBuildTheFivePaths() throws {
        XCTAssertEqual(CoopFlowMutation.markInviteRead(inviteID: 4).path, "api/coop/invite/read")
        XCTAssertEqual(try CoopFlowMutation.markInviteRead(inviteID: 4).body(), .object(["id": .id(4)]))
        XCTAssertEqual(CoopFlowRead.inviteRequest(requestID: "req_1").path, "api/coop/invite/request")
        XCTAssertEqual(CoopFlowRead.inviteRequests(before: "12", limit: 20).path, "api/coop/invite/requests")
        XCTAssertEqual(CoopFlowRead.supplyStations(topicID: 8, merchantMemberID: 3).path, "api/coop/supply-stations")
        let delete = try CreativeSquareAuthorDelete(postID: 7, authorMemberID: 2)
        XCTAssertEqual(delete.path, CreativeSquareAuthorDelete.path)
        XCTAssertEqual(CreativeSquareAuthorDelete.path, "api/creativesquare/delete")
        XCTAssertEqual(CreativeSquareAuthorDelete.listPath, "api/creativesquare/list")
        XCTAssertThrowsError(try CoopFlowRead.inviteRequest(requestID: "bad id").body())
        XCTAssertThrowsError(try CoopFlowRead.supplyStations(topicID: 0, merchantMemberID: 3).body())
    }

    func testReadsAreGetAndMarkReadIsPost() async throws {
        let transport = WP04MemoryTransport()
        let configuration = try APIConfiguration(baseURL: URL(string: "https://example.com")!)
        let service = CoopFlowService(configuration: configuration, transport: transport)
        let session = try CoopFlowSession(accountID: 2, epoch: 1, token: "synthetic-token")
        _ = try await service.read(.inviteRequest(requestID: "req_1"), session: session)
        _ = try await service.read(.inviteRequests(before: nil, limit: 20), session: session)
        _ = try await service.read(.supplyStations(topicID: 8, merchantMemberID: 3), session: session)
        _ = try await service.markInviteRead(inviteID: 4, session: session)
        let paths = transport.requests.map { ($0.httpMethod, $0.url?.path, $0.url?.query) }
        XCTAssertEqual(paths[0].0, "GET")
        XCTAssertTrue(paths[0].1?.hasSuffix(CoopFlowRead.inviteRequest(requestID: "req_1").path) == true)
        XCTAssertTrue(paths[0].2?.contains("requestId=req_1") == true)
        XCTAssertEqual(paths[1].0, "GET")
        XCTAssertTrue(paths[1].1?.hasSuffix(CoopFlowRead.inviteRequests(before: nil, limit: 20).path) == true)
        XCTAssertTrue(paths[1].2?.contains("limit=20") == true)
        XCTAssertEqual(paths[2].0, "GET")
        XCTAssertTrue(paths[2].1?.hasSuffix(CoopFlowRead.supplyStations(topicID: 8, merchantMemberID: 3).path) == true)
        XCTAssertTrue(paths[2].2?.contains("topicId=8") == true)
        XCTAssertTrue(paths[2].2?.contains("merchantMemberId=3") == true)
        XCTAssertEqual(paths[3].0, "POST")
        XCTAssertTrue(paths[3].1?.hasSuffix(CoopFlowMutation.markInviteRead(inviteID: 4).path) == true)
        XCTAssertNil(paths[3].2)
    }

    func testAuthorDeleteRereadsTheListWithoutThePost() async throws {
        let transport = WP04MemoryTransport()
        let configuration = try APIConfiguration(baseURL: URL(string: "https://example.com")!)
        let client = CreativeSquareAuthorDeleteClient(configuration: configuration, transport: transport)
        let command = try CreativeSquareAuthorDelete(postID: 7, authorMemberID: 2)
        let remaining = try await client.deleteOwnAndReread(command, viewerMemberID: 2, token: "synthetic-token")
        XCTAssertEqual(remaining, [9])
        XCTAssertEqual(transport.posts, [9])
        let delete = transport.requests[0]
        XCTAssertEqual(delete.httpMethod, "POST")
        XCTAssertTrue(delete.url?.path.hasSuffix(command.path) == true)
        let body = String(data: delete.httpBody ?? Data(), encoding: .utf8)
        XCTAssertTrue(body?.contains("name=\"id\"") == true)
        XCTAssertTrue(body?.contains("7") == true)
        XCTAssertEqual(transport.requests[1].httpMethod, "POST")
        XCTAssertTrue(transport.requests[1].url?.path.hasSuffix(CreativeSquareAuthorDelete.listPath) == true)
        let before = transport.requests.count
        do {
            _ = try await client.deleteOwnAndReread(command, viewerMemberID: 9, token: "synthetic-token")
            XCTFail("another member must not delete")
        } catch { XCTAssertEqual(error as? SocialActionBlock, .ownerRequired) }
        XCTAssertEqual(transport.requests.count, before)
    }
}

private final class WP04MemoryTransport: HTTPTransport {
    var posts = [7, 9]
    var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        let path = request.url?.path ?? ""
        if path.hasSuffix(CreativeSquareAuthorDelete.path) {
            let text = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
            if text.contains("\r\n7\r\n") { posts.removeAll { $0 == 7 } }
            return (Data("{\"code\":200,\"data\":null}".utf8), 200)
        }
        if path.hasSuffix(CreativeSquareAuthorDelete.listPath) {
            let rows = posts.map { "{\"id\":\($0)}" }.joined(separator: ",")
            return (Data("{\"code\":200,\"data\":{\"rows\":[\(rows)]}}".utf8), 200)
        }
        return (Data("{\"code\":200,\"data\":{\"rows\":[],\"nextCursor\":null,\"hasMore\":false,\"requiresSupplyStation\":true,\"stations\":[],\"state\":\"NOT_FOUND\",\"requestId\":\"req_1\"}}".utf8), 200)
    }
}
