import XCTest
@testable import Questify

/// 1128 gaps #12 / #13 / #14 / #18 (C-05, C-08, C-09, C-19, C-07a): the Release composition's club firewall
/// (`MPFirstClubWriteRoute`, reached only when the reviewed deployment has `playerWritesEnabled`) admits the owner
/// reads the club pages send, on the exact ClubGovernanceRead bodies, and still refuses settlement writes and
/// any other registration path.
@MainActor final class Fix1128bClubReadRouteTests: XCTestCase {
    private let base = URL(string: "https://test.example.com")!
    private let token = "synthetic-token-123456"

    private func json(_ path: String, body: String) -> URLRequest {
        var request = URLRequest(url: base.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(body.utf8)
        return request
    }

    private func encoded(_ read: ClubGovernanceRead, _ scope: ClubGovernanceScope, options: [String: ClubGovernanceValue] = [:]) throws -> URLRequest {
        let fields = try read.fields(scope: scope, options: options)
        return json(read.path, body: String(decoding: try JSONEncoder().encode(fields), as: UTF8.self))
    }

    func testReleaseDeploymentRoutesClubOwnerTrafficThroughThisFirewall() throws {
        let deployment = try RegionalLaunchConfiguration.reviewedDeployment(build: .init(
            market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL,
            bundleIdentifier: "invalid.example.questify.ios", realm: "cn-prod"))
        XCTAssertTrue(deployment.playerWritesEnabled)
        XCTAssertTrue(deployment.productionGatesEnabled)
    }

    /// Gap #12: settlement summary passes before the "settlement" guard; withdraw and mine stay refused.
    func testSettlementSummaryOnlyPasses() throws {
        XCTAssertTrue(MPFirstClubWriteRoute.accepts(try encoded(.settlement, .init(clubID: 3)), baseURL: base, token: token))
        for path in ["api/club/settlement/withdraw", "api/club/settlement/mine", "api/club/settlement/apply"] {
            XCTAssertFalse(MPFirstClubWriteRoute.accepts(json(path, body: #"{"clubId":3}"#), baseURL: base, token: token), path)
        }
    }

    /// Gap #13: the director console reads, with and without a session id.
    func testDirectorConsoleReadsPass() throws {
        let topic = ClubGovernanceScope(clubID: 3, topicID: 12)
        let session = ClubGovernanceScope(clubID: 3, topicID: 12, activityID: 55)
        for request in [try encoded(.topicStats, topic), try encoded(.topicStats, session), try encoded(.recruit, topic),
                        try encoded(.topicCustomers, topic), try encoded(.topicCustomers, topic, options: ClubTopicCustomerFilter.pending.options),
                        try encoded(.topicSettings, topic)] {
            XCTAssertTrue(MPFirstClubWriteRoute.accepts(request, baseURL: base, token: token), request.url?.path ?? "")
        }
        for (path, body) in [("api/club/crm/topic-manage-stats", #"{"clubId":3,"topicId":12}"#),
                             ("api/club/crm/topic-manage-stats", #"{"clubId":3,"topicId":12,"activityId":0}"#),
                             ("api/club/crm/topic-manage-stats", #"{"clubId":3,"topicId":12,"activityId":"5"}"#),
                             ("api/club/recruit/overview", #"{"clubId":3}"#),
                             ("api/club/recruit/overview", #"{"clubId":3,"topicId":12,"payAmount":1}"#),
                             ("api/club/crm/topic-customers", #"{"clubId":3,"topicId":12,"filter":1}"#),
                             ("api/club/crm/topic-customers", #"{"clubId":3,"topicId":12,"keyword":"x"}"#)] {
            XCTAssertFalse(MPFirstClubWriteRoute.accepts(json(path, body: body), baseURL: base, token: token), "\(path) \(body)")
        }
    }

    /// Gap #13: a role refusal hides the console quietly; a transport failure offers a retry.
    func testTopicStatsFailureIsRetryableExceptForRoleRefusal() {
        XCTAssertFalse(ClubTopicStatsLoad.retryable(ClubGovernanceFailure.forbidden))
        XCTAssertFalse(ClubTopicStatsLoad.retryable(ClubGovernanceFailure.signedOut))
        XCTAssertFalse(ClubTopicStatsLoad.retryable(CancellationError()))
        XCTAssertTrue(ClubTopicStatsLoad.retryable(ClubGovernanceFailure.malformed))
        XCTAssertTrue(ClubTopicStatsLoad.retryable(APIError.httpStatus(502)))
        XCTAssertTrue(ClubTopicStatsLoad.retryable(URLError(.timedOut)))
    }

    /// Gap #14: 报名名册 and 查看答案. topic-registrations passes only its exact body; other registration paths stay refused.
    func testRosterAndNodeAnswerPass() throws {
        XCTAssertTrue(MPFirstClubWriteRoute.accepts(try encoded(.registrations, .init(clubID: 3, topicID: 12)), baseURL: base, token: token))
        XCTAssertTrue(MPFirstClubWriteRoute.accepts(try encoded(.nodeAnswer, .init(clubID: 3, topicID: 12, nodeID: 40)), baseURL: base, token: token))
        for (path, body) in [("api/club/topic-registrations", #"{"clubId":3}"#),
                             ("api/club/topic-registrations", #"{"clubId":3,"topicId":12,"payAmount":1}"#),
                             ("api/club/topic-registrations", #"{"clubId":3,"topicId":0}"#),
                             ("api/registration/create", #"{"clubId":3,"topicId":12}"#),
                             ("api/club/topic-registrations/export", #"{"clubId":3,"topicId":12}"#),
                             ("api/club/topic-node-answer", #"{"clubId":3,"topicId":12}"#)] {
            XCTAssertFalse(MPFirstClubWriteRoute.accepts(json(path, body: body), baseURL: base, token: token), "\(path) \(body)")
        }
        var form = json("api/club/topic-registrations", body: #"{"clubId":3,"topicId":12}"#)
        form.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        XCTAssertFalse(MPFirstClubWriteRoute.accepts(form, baseURL: base, token: token))
    }

    /// Gap #18: event-ops series (list, detail, occurrences), roster and occurrence status reads, and the
    /// series create / update-future and attendance-correct writes.
    func testEventOpsSeriesPaths() throws {
        for request in [try encoded(.series, .init(clubID: 3)), try encoded(.seriesDetail, .init(clubID: 3, seriesID: 8)),
                        try encoded(.occurrences, .init(clubID: 3, seriesID: 8)), try encoded(.roster, .init(clubID: 3, activityID: 55)),
                        try encoded(.occurrenceStatus, .init(clubID: 3, activityID: 55))] {
            XCTAssertTrue(MPFirstClubWriteRoute.accepts(request, baseURL: base, token: token), request.url?.path ?? "")
        }
        for path in ["api/club/event-ops/series/create", "api/club/event-ops/series/update-future", "api/club/event-ops/attendance/correct"] {
            XCTAssertTrue(MPFirstClubWriteRoute.governancePaths.contains(path), path)
            XCTAssertTrue(MPFirstClubWriteRoute.accepts(json(path, body: #"{"clubId":3}"#), baseURL: base, token: token), path)
        }
        XCTAssertFalse(MPFirstClubWriteRoute.accepts(json("api/club/event-ops/series/occurrences", body: #"{"clubId":3}"#), baseURL: base, token: token))
    }
}
