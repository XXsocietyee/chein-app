import XCTest
@testable import Questify

/// CLB-r10-gate-05 / notify-01 / group-code-01 / badges-01: the club write firewall admits the
/// non-money club POSTs the MP sends (pages/club/notify, group-code:93-135, event-ops,
/// topic-detail, customer-detail, badges) and still refuses money keys.
@MainActor final class MPFirstClubWriteRouteR10Tests: XCTestCase {
    private let base = URL(string: "https://test.example.com")!
    private let token = "synthetic-token-123456"
    private func json(_ path: String, body: String = "{}") -> URLRequest {
        var request = URLRequest(url: base.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(body.utf8)
        return request
    }

    func testAdmitsTheR10ClubWrites() {
        for path in ["api/club/event-notification/send", "api/club/event-notification/retry", "api/verify/groupcode/issue",
                     "api/club/crm/customers/tag-remark", "api/club/event-ops/series/create", "api/club/event-ops/series/update-future",
                     "api/club/event-ops/attendance/correct", "api/club/topic-setting/save"] {
            XCTAssertTrue(MPFirstClubWriteRoute.accepts(json(path), baseURL: base, token: token), path)
        }
        let reads = [("api/club/event-notification/preview", #"{"clubId":3,"activityId":null,"audienceType":"ALL","title":"t","content":"c","channel":"IN_APP","requestId":null}"#),
                     ("api/club/event-notification/status", #"{"campaignId":9}"#), ("api/club/badge/list", #"{"id":3}"#),
                     ("api/club/detail", #"{"id":3}"#), ("api/club/members", #"{"clubId":3}"#), ("api/club/access/me", #"{"clubId":3,"activityId":4}"#),
                     ("api/publisher/identity/status", "{}"), ("api/club/event-ops/roster", #"{"clubId":3,"activityId":4}"#)]
        for (path, body) in reads { XCTAssertTrue(MPFirstClubWriteRoute.accepts(json(path, body: body), baseURL: base, token: token), path) }
    }

    /// Coordinator r10 round 2: the review reads pass only on their exact body (an extra `amount` key got through).
    func testReadsAdmitOnlyTheirExactBody() {
        for (path, body) in [("api/club/members", #"{"clubId":3,"amount":1}"#), ("api/club/members", #"{"clubId":0}"#),
                             ("api/club/members", #"{"clubId":"3"}"#), ("api/club/members", #"{"clubId":true}"#), ("api/club/members", "{}"),
                             ("api/club/detail", #"{"id":3,"amount":1}"#), ("api/club/detail", #"{"clubId":3}"#), ("api/club/detail", #"{"id":-1}"#),
                             ("api/club/badge/list", #"{"id":3,"amount":1}"#), ("api/club/event-notification/status", #"{"campaignId":9,"amount":1}"#),
                             ("api/club/crm/customers/detail", #"{"clubId":3}"#), ("api/club/topic-setting/detail", #"{"clubId":3,"topicId":1.5}"#),
                             ("api/club/access/me", #"{"clubId":3,"activityId":0}"#), ("api/publisher/identity/status", #"{"amount":1}"#),
                             ("api/club/event-notification/preview", #"{"clubId":3,"amount":1}"#)] {
            XCTAssertFalse(MPFirstClubWriteRoute.accepts(json(path, body: body), baseURL: base, token: token), "\(path) \(body)")
        }
    }

    func testAdmitsMultipartChapterWritesAndTopicReadOnly() throws {
        for path in ["api/topic/chapter/recruit", "api/topic/chapter/finish", "api/topic/info-to-user"] {
            let form = try AuthRequestBuilder.makeFormRequest(url: base.appendingPathComponent(path), fields: ["chapterId": "12", "scope": ""], token: token)
            XCTAssertTrue(MPFirstClubWriteRoute.accepts(form, baseURL: base, token: token), path)
        }
        let paid = try AuthRequestBuilder.makeFormRequest(url: base.appendingPathComponent("api/topic/chapter/finish"), fields: ["payAmount": "1"], token: token)
        XCTAssertFalse(MPFirstClubWriteRoute.accepts(paid, baseURL: base, token: token))
        XCTAssertFalse(MPFirstClubWriteRoute.accepts(json("api/topic/chapter/recruit"), baseURL: base, token: token))
        let form = try AuthRequestBuilder.makeFormRequest(url: base.appendingPathComponent("api/club/event-notification/send"), fields: [:], token: token)
        XCTAssertFalse(MPFirstClubWriteRoute.accepts(form, baseURL: base, token: token))
    }

    func testRefusesMoneyOpsAndKeys() {
        XCTAssertFalse(MPFirstClubWriteRoute.accepts(json("api/club/event-ops/cancel"), baseURL: base, token: token))
        XCTAssertFalse(MPFirstClubWriteRoute.accepts(json("api/club/topic-setting/end"), baseURL: base, token: token))
        XCTAssertFalse(MPFirstClubWriteRoute.accepts(json("api/club-compensation/hours/report"), baseURL: base, token: token))
        XCTAssertFalse(MPFirstClubWriteRoute.accepts(json("api/club/event-notification/send", body: #"{"payAmount":1}"#), baseURL: base, token: token))
    }
}
