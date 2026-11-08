import XCTest
#if canImport(QuestifyCore)
@testable import QuestifyCore

/// club/create pre-check: the mini-program counts owned clubs except rejected ones (status 2) against the limit of 2.
final class ClubCreateQuotaTests: XCTestCase {
    private final class Transport: HTTPTransport {
        var requests: [URLRequest] = []
        var replies: [String] = []
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return (Data((replies.isEmpty ? "{}" : replies.removeFirst()).utf8), 200)
        }
    }
    private func snapshot(owned: String) async throws -> ClubOperationsSnapshot {
        let transport = Transport()
        transport.replies = [#"{"code":200,"appUser":{"id":701,"role":"club"}}"#, #"{"code":200,"data":{"owned":"# + owned + #"}}"#]
        let service = ClubOperationsService(configuration: try APIConfiguration(baseURL: URL(string: "https://example.com/")!), transport: transport)
        return try await service.snapshot(target: .create, token: "synthetic-token", accountID: 701, checkSession: {})
    }
    func testRejectedClubDoesNotCountAgainstLimit() async throws {
        let value = try await snapshot(owned: #"[{"id":81,"isOwner":true,"status":1},{"id":82,"isOwner":true,"status":2}]"#)
        XCTAssertEqual(value.ownedClubIDs, [81])
        XCTAssertTrue(value.canCreate)
    }
    func testTwoLiveClubsStillHitTheLimitAndUnknownStatusCounts() async throws {
        let live = try await snapshot(owned: #"[{"id":81,"isOwner":true,"status":0},{"id":82,"isOwner":true,"status":1}]"#)
        XCTAssertFalse(live.canCreate)
        let unknown = try await snapshot(owned: #"[{"id":81,"isOwner":true},{"id":82,"isOwner":true,"status":"x"}]"#)
        XCTAssertEqual(unknown.ownedClubIDs, [81, 82])
        XCTAssertFalse(unknown.canCreate)
    }
}
#endif
