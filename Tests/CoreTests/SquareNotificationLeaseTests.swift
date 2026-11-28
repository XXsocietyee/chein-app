import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// K40 / plan M-11a. The shipped lease reads the community notification list and may mark one read
/// or file an appeal. Preference writes, comment approve and comment delete stay off.
private final class SquareNotificationLeaseHTTP: HTTPTransport {
    var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        let body = #"{"code":200,"data":{"items":[{"id":81,"read_at":null,"payload_json":"{\"action\":\"REPORT_STAGE_REVIEWING\"}"},{"id":82,"read_at":"2026-11-01T00:00:00Z","payload_json":"{\"action\":\"REPORT_RECEIVED\"}"},{"id":83,"read_at":null,"payload_json":"{\"action\":\"LIKE\"}"}]}}"#
        return (Data(body.utf8), 200)
    }
}

@MainActor final class SquareNotificationLeaseTests: XCTestCase {
    private let base = URL(string: "https://notify.example.test")!

    func testLeaseReadsReportNoticesAndBuildsMarkReadAndAppeal() async throws {
        XCTAssertTrue(SquareNotificationLease.routesLive)
        let fake = SquareNotificationLeaseHTTP()
        let service = SquareNotificationLease.service(baseURL: base, transport: fake)
        XCTAssertTrue(service.readsEnabled)
        XCTAssertEqual(service.allows(.markRead(notificationID: 81)), true)
        XCTAssertEqual(service.allows(.appeal(enforcementID: 91, reason: "facts")), true)
        XCTAssertFalse(service.allows(.preferences([.socialEnabled: true])))
        XCTAssertFalse(service.allows(.approveComment(postID: 71, commentID: 61)))
        XCTAssertFalse(service.allows(.deleteOwnComment(commentID: 62)))

        let dormant = SquareGovernanceService(dormantBaseURL: base, transport: fake)
        XCTAssertFalse(dormant.readsEnabled)
        XCTAssertFalse(dormant.allows(.markRead(notificationID: 81)))
        let hidden = await ReportProgressUnreadReader(service: dormant, token: { "synthetic-token" }, accountID: { 7 }).unreadCount()
        XCTAssertNil(hidden)
        XCTAssertTrue(fake.requests.isEmpty)

        let reader = ReportProgressUnreadReader(service: service, token: { "synthetic-token" }, accountID: { 7 })
        let unread = await reader.unreadCount()
        XCTAssertEqual(unread, 1)
        let sent = fake.requests.count
        let marked = await reader.markOpened()
        XCTAssertFalse(marked)
        XCTAssertEqual(fake.requests.count, sent)
        let list = try XCTUnwrap(fake.requests.first)
        XCTAssertEqual(list.httpMethod, "GET")
        XCTAssertEqual(list.url?.path, "/api/v1/community/notifications")
        XCTAssertEqual(URLComponents(url: try XCTUnwrap(list.url), resolvingAgainstBaseURL: false)?.queryItems, [URLQueryItem(name: "limit", value: "50")])
        XCTAssertEqual(list.value(forHTTPHeaderField: "Authorization"), "synthetic-token")
        XCTAssertNil(list.httpBody)

        let snapshot = SquareGovernanceSnapshot(identity: .init(accountID: 7, epoch: 1, namespace: "notify"),
                                                enforcements: [], notifications: [], preferences: .object([:]))
        let read = SquareGovernanceReview(snapshot: snapshot, action: .markRead(notificationID: 81), now: Date())
        let readRequest = try service.command(read, token: "synthetic-token")
        XCTAssertEqual(readRequest.httpMethod, "POST")
        XCTAssertEqual(readRequest.url?.path, "/api/v1/community/notifications/81/read")
        let readBody = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(readRequest.httpBody)) as? [String: Any])
        XCTAssertEqual(readBody["requestId"] as? String, read.requestID)
        XCTAssertTrue(read.requestID.hasPrefix("notification-read-"))

        let appeal = SquareGovernanceReview(snapshot: snapshot, action: .appeal(enforcementID: 91, reason: "facts"), now: Date())
        let appealRequest = try service.command(appeal, token: "synthetic-token")
        XCTAssertEqual(appealRequest.httpMethod, "POST")
        XCTAssertEqual(appealRequest.url?.path, "/api/v1/community/appeals")
        let appealBody = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(appealRequest.httpBody)) as? [String: Any])
        XCTAssertEqual(appealBody["enforcementId"] as? Int, 91)
        XCTAssertEqual(appealBody["reason"] as? String, "facts")
        XCTAssertEqual(appealBody["requestId"] as? String, appeal.requestID)
        XCTAssertEqual(appealBody["evidenceAssetIds"] as? [Any], [])
    }
}
