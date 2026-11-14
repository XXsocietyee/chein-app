import Foundation
import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class ClubPublicTopicsCurrentContractTests: XCTestCase {
    func testExactClubReadShapeRejectsExtraFieldsAndMutation() throws {
        let base = URL(string: "https://example.test")!
        var request = URLRequest(url: base.appendingPathComponent("api/club/topics"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(#"{"id":41}"#.utf8)
        XCTAssertEqual(ClubPublicTopicsRoute(request: request, baseURL: base)?.clubID, 41)
        request.httpBody = Data(#"{"id":41,"page":1}"#.utf8)
        XCTAssertNil(ClubPublicTopicsRoute(request: request, baseURL: base))
        request.httpBody = Data(#"{"id":41}"#.utf8)
        request.setValue("request", forHTTPHeaderField: "X-Club-Request-Id")
        XCTAssertNil(ClubPublicTopicsRoute(request: request, baseURL: base))
    }
    @MainActor
    func testPublicTopicsReadPostsClubTopicsAndCannotBeActivityList() async throws {
        let base = try XCTUnwrap(URL(string: "https://8120.example.test"))
        let configuration = try APIConfiguration(baseURL: base)
        let transport = ClubPublicTopicsRouteTransport()
        let context = ClubPublicTopicsContext(identity: .init(accountID: nil, epoch: 4),
            viewerRevision: 8, role: nil, baseURL: base, namespace: "public-topics")
        let session = try ClubPublicTopicsSession(context: context, membershipRevision: 0, token: nil)
        let clubID = 41
        let approval = ClubPublicTopicsApproval(context: context, clubID: clubID, revision: UUID())
        let reader = ClubPublicTopicsReader(configuration: configuration, transport: transport,
            currentSession: { session },
            approval: { candidate, requested in
                guard candidate == context, requested == clubID else { return nil }
                return approval
            })
        let snapshot = try await reader.read(clubID: clubID, isCurrent: { true })
        XCTAssertEqual(snapshot.rows.map(\.id), [9])
        let topics = try XCTUnwrap(transport.requests.first { $0.url?.path.hasSuffix("api/club/topics") == true })
        XCTAssertEqual(topics.httpMethod, "POST")
        XCTAssertEqual(topics.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(topics.httpBody, Data("{\"id\":41}".utf8))
        XCTAssertEqual(ClubPublicTopicsRoute(request: topics, baseURL: base)?.clubID, clubID)
        XCTAssertEqual(transport.requests.map { $0.url?.path }, [
            "/api/club/topics", "/api/club/detail"
        ])
        XCTAssertFalse(transport.requests.contains { $0.url?.path.hasSuffix("api/activity/list") == true })
        var activityList = URLRequest(url: base.appendingPathComponent("api/activity/list"))
        activityList.httpMethod = "POST"
        activityList.setValue("application/json", forHTTPHeaderField: "Content-Type")
        activityList.httpBody = Data("{\"id\":41}".utf8)
        XCTAssertNil(ClubPublicTopicsRoute(request: activityList, baseURL: base))
        let sent = transport.requests.count
        do {
            _ = try await reader.read(clubID: 0, isCurrent: { true })
            XCTFail("club id 0 stays unmatched")
        } catch {
            XCTAssertEqual(error as? APIError, .notConfigured)
        }
        XCTAssertEqual(transport.requests.count, sent)
    }

    func testGuestSessionCannotSmuggleCredentialOrRole() throws {
        let base = URL(string: "https://example.test")!
        let context = ClubPublicTopicsContext(identity: .init(accountID: nil, epoch: 4),
            viewerRevision: 8, role: nil, baseURL: base, namespace: "test")
        XCTAssertNoThrow(try ClubPublicTopicsSession(context: context, membershipRevision: 0, token: nil))
        XCTAssertThrowsError(try ClubPublicTopicsSession(context: context, membershipRevision: 0, token: "synthetic"))
        let invalid = ClubPublicTopicsContext(identity: context.identity, viewerRevision: 8,
            role: "player", baseURL: base, namespace: "test")
        XCTAssertThrowsError(try ClubPublicTopicsSession(context: invalid, membershipRevision: 0, token: nil))
    }
}

private final class ClubPublicTopicsRouteTransport: HTTPTransport {
    var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        let path = request.url?.path ?? ""
        if path.hasSuffix("api/activity/list") {
            return (Data("{\"code\":500}".utf8), 500)
        }
        if path.hasSuffix("api/club/topics") {
            return (Data("{\"code\":200,\"data\":[{\"id\":9,\"name\":\"Public\"}]}".utf8), 200)
        }
        if path.hasSuffix("api/club/detail") {
            return (Data("{\"code\":200,\"data\":{\"id\":41,\"name\":\"Club\"}}".utf8), 200)
        }
        return (Data("{\"code\":404}".utf8), 404)
    }
}
