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
                     "api/club/event-ops/attendance/correct", "api/club/topic-setting/save",
                     "api/club/event-notification/preview", "api/club/event-notification/status",
                     "api/club/badge/list", "api/club/badge/create", "api/club/badge/grant", "api/club/detail"] {
            XCTAssertTrue(MPFirstClubWriteRoute.accepts(json(path), baseURL: base, token: token), path)
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
