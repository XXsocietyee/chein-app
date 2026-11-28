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

    /// CLB-r10-join-requests-01: the join-request list read and 通过 / 拒绝 pass on ClubManagementService's exact bodies.
    func testAdmitsJoinRequestReviewOnItsExactBody() {
        for (path, body) in [("api/club/join-requests", #"{"clubId":3}"#), ("api/club/join-request/approve", #"{"clubId":3,"memberId":8}"#),
                             ("api/club/join-request/reject", #"{"clubId":3,"memberId":8}"#),
                             ("api/club/join-request/reject", #"{"clubId":3,"memberId":8,"reviewReason":"名额已满"}"#)] {
            XCTAssertTrue(MPFirstClubWriteRoute.accepts(json(path, body: body), baseURL: base, token: token), "\(path) \(body)")
        }
        for (path, body) in [("api/club/join-request/approve", #"{"clubId":3,"memberId":8,"reviewReason":"x"}"#),
                             ("api/club/join-request/approve", #"{"clubId":3}"#), ("api/club/join-request/reject", #"{"clubId":3,"memberId":8,"reviewReason":1}"#),
                             ("api/club/join-request/approve", #"{"clubId":3,"memberId":8,"amount":1}"#), ("api/club/join-requests", #"{"clubId":3,"page":1}"#)] {
            XCTAssertFalse(MPFirstClubWriteRoute.accepts(json(path, body: body), baseURL: base, token: token), "\(path) \(body)")
        }
    }

    /// P1-11 (MP pages/club/detail/index.js:3430): 移除成员 passes on ClubManagementService's exact `{clubId, memberId}` body only.
    func testAdmitsRemoveMemberOnItsExactBody() {
        XCTAssertTrue(MPFirstClubWriteRoute.accepts(json("api/club/remove-member", body: #"{"clubId":3,"memberId":8}"#), baseURL: base, token: token))
        for body in [#"{"clubId":3}"#, #"{"clubId":3,"memberId":0}"#, #"{"clubId":3,"memberId":8,"amount":1}"#,
                     #"{"clubId":3,"memberId":8,"reviewReason":"x"}"#, #"{"clubId":"3","memberId":8}"#] {
            XCTAssertFalse(MPFirstClubWriteRoute.accepts(json("api/club/remove-member", body: body), baseURL: base, token: token), body)
        }
    }

    /// P1-12: the club owner reads (统计概览, 结算, CRM, series, audience counts) pass on ClubGovernanceRead's exact bodies;
    /// settlement writes and extra keys stay refused.
    func testAdmitsOwnerReadsOnTheirExactBody() throws {
        let scope = ClubGovernanceScope(clubID: 3)
        for read in [ClubGovernanceRead.stats, .settlement, .series, .customers, .audienceCounts] {
            let fields = try read.fields(scope: scope)
            let body = String(decoding: try JSONEncoder().encode(fields), as: UTF8.self)
            XCTAssertTrue(MPFirstClubWriteRoute.accepts(json(read.path, body: body), baseURL: base, token: token), "\(read.path) \(body)")
        }
        for (path, body) in [("api/stats/club", #"{"clubId":3,"amount":1}"#), ("api/club/settlement/summary", #"{"clubId":0}"#),
                             ("api/club/settlement/summary", #"{"clubId":3,"personal":true}"#), ("api/club/settlement/withdraw", #"{"clubId":3}"#),
                             ("api/club/settlement/mine", #"{"clubId":3}"#), ("api/club/crm/customers/list", #"{"clubId":3}"#),
                             ("api/club/event-ops/series/list", #"{"clubId":3,"page":1}"#)] {
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
        let saved = ReleaseMoneyWriteSwitch.testDerivation
        defer { ReleaseMoneyWriteSwitch.testDerivation = saved }
        // CLB-r11-money-01: host-cancel refund passes only its exact MP body and only while the money switch is on.
        let cancel = json("api/club/event-ops/cancel", body: #"{"clubId":81,"activityId":55,"reason":"场地关闭","requestId":"event-cancel-1"}"#)
        let end = json("api/club/topic-setting/end", body: #"{"clubId":81,"topicId":3,"cancellationEpoch":"0"}"#)
        ReleaseMoneyWriteSwitch.testDerivation = nil
        XCTAssertFalse(MPFirstClubWriteRoute.accepts(cancel, baseURL: base, token: token))
        XCTAssertFalse(MPFirstClubWriteRoute.accepts(end, baseURL: base, token: token))
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .hostCancelRefund }
        XCTAssertTrue(MPFirstClubWriteRoute.accepts(cancel, baseURL: base, token: token))
        XCTAssertTrue(MPFirstClubWriteRoute.accepts(end, baseURL: base, token: token))
        XCTAssertTrue(MPFirstClubWriteRoute.accepts(json("api/club/event-ops/occurrence/status", body: #"{"clubId":81,"activityId":55}"#), baseURL: base, token: token))
        XCTAssertFalse(MPFirstClubWriteRoute.accepts(json("api/club/event-ops/cancel"), baseURL: base, token: token))
        XCTAssertFalse(MPFirstClubWriteRoute.accepts(json("api/club/topic-setting/end"), baseURL: base, token: token))
        XCTAssertFalse(MPFirstClubWriteRoute.accepts(json("api/club/event-ops/cancel", body: #"{"clubId":81,"activityId":55,"reason":"场地关闭","requestId":"r","refundId":1}"#), baseURL: base, token: token))
        XCTAssertFalse(MPFirstClubWriteRoute.accepts(json("api/club-compensation/hours/report"), baseURL: base, token: token))
        XCTAssertFalse(MPFirstClubWriteRoute.accepts(json("api/club/event-notification/send", body: #"{"payAmount":1}"#), baseURL: base, token: token))
    }
}
