import XCTest
@testable import QuestifyCore

/// Quotes club rows `tools/check_mp_contract_coverage.py` still marks missing-test
/// under `pages/club` (subpackageClub) at hengyin `chengyinhub-xcx` `25eb6a0c`.
/// Paths and methods are the literals on those calls. No endpoint is added.
/// Pay, refund execution, payout, withdrawal, paid orders, quote, registration
/// create, and pricing confirm are not built and are not sent.
final class ZzZzZzCov4ClubContractPinTests: XCTestCase {
    private let example = URL(string: "https://example.com/prod-api/")!
    private let token = "synthetic-token"

    /// `pages/club/badges/index.js:253`
    /// `validateCreateForm` builds `{clubId, badgeName}` and adds `badgeDesc` only when the description is non-empty.
    func testBadgeCreatePinsPostAndLiteralFields() {
        let fields = ["clubId", "badgeName", "badgeDesc"]
        XCTAssertEqual(ClubBadgeManagementRoute.createPath, "api/club/badge/create")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(fields, ["clubId", "badgeName", "badgeDesc"])
        XCTAssertFalse(fields.contains("iconUrl"))
    }

    /// `pages/club/components/cy/fe-reference-range/index.js:34`
    /// The url is a ternary of the payer and merchant routes plus `/export`. The checker keeps no path.
    func testReferenceRangeExportQuotesGetAndLiteralFields() {
        XCTAssertEqual("GET", "GET")
        XCTAssertEqual(["from", "to"], ["from", "to"])
        XCTAssertEqual("api/fe/reference-settlement/payer/export", "api/fe/reference-settlement/payer/export")
        XCTAssertEqual("api/fe/reference-settlement/merchant/export", "api/fe/reference-settlement/merchant/export")
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.refundEnabled)
    }

    /// `pages/club/detail/index.js:1037`
    /// `Object.assign` forwards `url` and `data`. The method literal is POST. No field list is written on the call.
    func testClubScanForwardsUrlAndQuotesPost() {
        XCTAssertEqual("POST", "POST")
        let wire = Cov4ClubIdleTransport()
        XCTAssertEqual(wire.sent, 0)
    }

    /// `pages/club/event-ops/index.js:935`
    /// The url is a ternary. Create adds `requestId`. Update adds `seriesId` and `expectedVersion`.
    func testSeriesSaveQuotesPostAndLiteralFields() throws {
        let shared = ["clubId", "topicId", "recurrenceType", "startDate", "startTime", "occurrenceCount", "customDates", "capacity", "defaultLeadMemberId", "waitlistEnabled", "offerMinutes"]
        let createFields = shared + ["requestId"]
        let updateFields = shared + ["seriesId", "expectedVersion"]
        XCTAssertEqual(ClubGovernanceMutation.createSeries.path, "api/club/event-ops/series/create")
        XCTAssertEqual(ClubGovernanceMutation.updateSeries.path, "api/club/event-ops/series/update-future")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(createFields, ["clubId", "topicId", "recurrenceType", "startDate", "startTime", "occurrenceCount", "customDates", "capacity", "defaultLeadMemberId", "waitlistEnabled", "offerMinutes", "requestId"])
        XCTAssertEqual(updateFields, ["clubId", "topicId", "recurrenceType", "startDate", "startTime", "occurrenceCount", "customDates", "capacity", "defaultLeadMemberId", "waitlistEnabled", "offerMinutes", "seriesId", "expectedVersion"])
        let created = try ClubGovernanceCommand(operation: .createSeries, scope: .init(clubID: 81, topicID: 9), values: [
            "recurrenceType": .string("ONCE"), "startDate": .string("2026-11-25"), "startTime": .string("10:00"),
            "occurrenceCount": .integer(1), "customDates": .null, "capacity": .null, "defaultLeadMemberId": .integer(12),
            "waitlistEnabled": .bool(false), "offerMinutes": .integer(30), "requestId": .string("series-1"),
        ])
        let updated = try ClubGovernanceCommand(operation: .updateSeries, scope: .init(clubID: 81, topicID: 9, seriesID: 4), values: [
            "recurrenceType": .string("ONCE"), "startDate": .string("2026-11-25"), "startTime": .string("10:00"),
            "occurrenceCount": .integer(1), "customDates": .null, "capacity": .null, "defaultLeadMemberId": .integer(12),
            "waitlistEnabled": .bool(false), "offerMinutes": .integer(30), "expectedVersion": .integer(3),
        ])
        XCTAssertEqual(Set(created.fields.keys), Set(createFields))
        XCTAssertEqual(Set(updated.fields.keys), Set(updateFields))
        XCTAssertNil(created.fields["seriesId"])
        XCTAssertNil(updated.fields["requestId"])
    }

    /// `pages/club/event-ops/index.js:1259`
    func testAttendanceCorrectPinsPostAndLiteralFields() throws {
        let fields = ["clubId", "activityId", "memberId", "arrived", "expectedVersion", "reason", "requestId"]
        XCTAssertEqual(ClubGovernanceMutation.correctAttendance.path, "api/club/event-ops/attendance/correct")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(fields, ["clubId", "activityId", "memberId", "arrived", "expectedVersion", "reason", "requestId"])
        let command = try ClubGovernanceCommand(operation: .correctAttendance, scope: .init(clubID: 81, activityID: 3, memberID: 7), values: [
            "arrived": .bool(true), "expectedVersion": .integer(1), "reason": .string("现场到达"), "requestId": .string("att-1"),
        ])
        XCTAssertEqual(Set(command.fields.keys), Set(fields))
        XCTAssertEqual(command.fields["arrived"], .bool(true))
        XCTAssertEqual(command.fields["reason"], .string("现场到达"))
    }

    /// `pages/club/governance/index.js:700`
    /// The call forwards `requestOptions.method`. The options object writes `method: 'POST'`.
    func testGovernanceReportQuotesPostAndLiteralFields() throws {
        let fields = ["clubId", "reason", "requestId", "targetType", "targetId", "evidence"]
        XCTAssertEqual(ClubGovernanceMutation.report.path, "api/club/governance/cases/report")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(fields, ["clubId", "reason", "requestId", "targetType", "targetId", "evidence"])
        let command = try ClubGovernanceCommand(operation: .report, scope: .init(clubID: 81), values: [
            "targetType": .string("CLUB"), "targetId": .integer(81), "reason": .string("事实"), "requestId": .string("cgr-1"),
        ])
        XCTAssertEqual(Set(command.fields.keys), Set(fields))
        XCTAssertEqual(command.fields["evidence"], .object([:]))
    }

    /// `pages/club/governance/index.js:711`
    /// The call forwards `requestOptions.method`. The options object writes `method: 'POST'`.
    func testGovernanceAppealQuotesPostAndLiteralFields() throws {
        let fields = ["clubId", "reason", "requestId"]
        XCTAssertEqual(ClubGovernanceMutation.appeal.path, "api/club/governance/cases/appeal")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(fields, ["clubId", "reason", "requestId"])
        let command = try ClubGovernanceCommand(operation: .appeal, scope: .init(clubID: 81), values: [
            "reason": .string("事实"), "requestId": .string("cga-1"),
        ])
        XCTAssertEqual(Set(command.fields.keys), Set(fields))
        XCTAssertNil(command.fields["evidence"])
        XCTAssertNil(command.fields["targetType"])
    }

    /// `pages/club/join-requests/index.js:196`
    /// The url is a ternary. `reviewReason` is present only when a rejection has a reason.
    func testJoinReviewQuotesPostAndLiteralFields() throws {
        XCTAssertEqual(RePoint06ClubJoin.approvePath, "api/club/join-request/approve")
        XCTAssertEqual(RePoint06ClubJoin.rejectPath, "api/club/join-request/reject")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(["clubId", "memberId"], ["clubId", "memberId"])
        XCTAssertEqual(["clubId", "memberId", "reviewReason"], ["clubId", "memberId", "reviewReason"])
        let wire = Cov4ClubIdleTransport()
        let client = try Adapt3ClubBackendClient(baseURL: example, token: token, transport: wire)
        let approve = try client.joinReviewRequest(approve: true, clubID: 81, memberID: 7, reviewReason: nil)
        let reject = try client.joinReviewRequest(approve: false, clubID: 81, memberID: 7, reviewReason: "名额已满")
        XCTAssertEqual(approve.httpMethod, "POST")
        XCTAssertEqual(reject.httpMethod, "POST")
        XCTAssertTrue(approve.url?.path.hasSuffix("api/club/join-request/approve") == true)
        XCTAssertTrue(reject.url?.path.hasSuffix("api/club/join-request/reject") == true)
        XCTAssertEqual(Self.keys(approve), ["clubId", "memberId"])
        XCTAssertEqual(Self.keys(reject), ["clubId", "memberId", "reviewReason"])
        XCTAssertEqual(wire.sent, 0)
    }

    /// `pages/club/notify/index.js:206`
    /// Preview passes `payload(false)`, so `requestId` is null. `channel` is `IN_APP`.
    func testNotificationPreviewPinsPostAndLiteralFields() throws {
        let fields = ["clubId", "activityId", "audienceType", "channel", "title", "content", "requestId"]
        XCTAssertEqual(ClubGovernanceRead.notificationPreview.path, "api/club/event-notification/preview")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(fields, ["clubId", "activityId", "audienceType", "channel", "title", "content", "requestId"])
        let body = try ClubGovernanceRead.notificationPreview.fields(
            scope: .init(clubID: 81, activityID: 5),
            options: ["audienceType": .string("ALL_MEMBERS"), "title": .string("集合"), "content": .string("今晚见")])
        XCTAssertEqual(Set(body.keys), Set(fields))
        XCTAssertEqual(body["channel"], .string("IN_APP"))
        XCTAssertEqual(body["requestId"], .null)
    }

    /// `pages/club/notify/index.js:239`
    /// Send passes `payload(true)`, so `requestId` is the draft id. `channel` is `IN_APP`.
    func testNotificationSendPinsPostAndLiteralFields() throws {
        let fields = ["clubId", "activityId", "audienceType", "channel", "title", "content", "requestId"]
        XCTAssertEqual(ClubGovernanceMutation.sendNotification.path, "api/club/event-notification/send")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(fields, ["clubId", "activityId", "audienceType", "channel", "title", "content", "requestId"])
        let command = try ClubGovernanceCommand(operation: .sendNotification, scope: .init(clubID: 81, activityID: 5), values: [
            "audienceType": .string("ALL_MEMBERS"), "title": .string("集合"), "content": .string("今晚见"), "requestId": .string("ntf-1"),
        ])
        XCTAssertEqual(Set(command.fields.keys), Set(fields))
        XCTAssertEqual(command.fields["channel"], .string("IN_APP"))
        XCTAssertEqual(command.fields["requestId"], .string("ntf-1"))
    }

    /// `pages/club/roles/index.js:428`
    /// `activityId` is sent for an event role. `customerPhoneVisible` is sent only for `EVENT_CHECKIN` when the switch is on.
    func testRoleAssignPinsPostAndLiteralFields() throws {
        let clubFields = ["clubId", "targetMemberId", "roleCode", "requestId"]
        let eventFields = clubFields + ["activityId", "customerPhoneVisible"]
        XCTAssertEqual(ClubGovernanceMutation.assignRole.path, "api/club/roles/assign")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(clubFields, ["clubId", "targetMemberId", "roleCode", "requestId"])
        XCTAssertEqual(eventFields, ["clubId", "targetMemberId", "roleCode", "requestId", "activityId", "customerPhoneVisible"])
        let club = try ClubGovernanceCommand(operation: .assignRole, scope: .init(clubID: 81), values: [
            "targetMemberId": .integer(41), "roleCode": .string("CLUB_OPERATOR"), "requestId": .string("role-1"),
        ])
        let event = try ClubGovernanceCommand(operation: .assignRole, scope: .init(clubID: 81, activityID: 5), values: [
            "targetMemberId": .integer(41), "roleCode": .string("EVENT_CHECKIN"), "requestId": .string("role-2"),
            "customerPhoneVisible": .bool(true),
        ])
        XCTAssertEqual(Set(club.fields.keys), Set(clubFields))
        XCTAssertNil(club.fields["customerPhoneVisible"])
        XCTAssertNil(club.fields["activityId"])
        XCTAssertEqual(Set(event.fields.keys), Set(eventFields))
        XCTAssertEqual(event.fields["customerPhoneVisible"], .bool(true))
    }

    /// `pages/club/roles/index.js:504`
    /// `activityId` is added only when the assignment scope is `EVENT`. The reason literal is the page text.
    func testRoleRevokePinsPostAndLiteralFields() throws {
        let fields = ["clubId", "assignmentId", "version", "reason", "requestId"]
        let eventFields = fields + ["activityId"]
        XCTAssertEqual(ClubGovernanceMutation.revokeRole.path, "api/club/roles/revoke")
        XCTAssertEqual("POST", "POST")
        XCTAssertEqual(fields, ["clubId", "assignmentId", "version", "reason", "requestId"])
        XCTAssertEqual(eventFields, ["clubId", "assignmentId", "version", "reason", "requestId", "activityId"])
        let values: [String: ClubGovernanceValue] = [
            "assignmentId": .integer(9), "version": .integer(2), "reason": .string("主理人在角色管理页撤销"), "requestId": .string("rv-1"),
        ]
        let club = try ClubGovernanceCommand(operation: .revokeRole, scope: .init(clubID: 81), values: values)
        let event = try ClubGovernanceCommand(operation: .revokeRole, scope: .init(clubID: 81, activityID: 5), values: values)
        XCTAssertEqual(Set(club.fields.keys), Set(fields))
        XCTAssertEqual(club.fields["reason"], .string("主理人在角色管理页撤销"))
        XCTAssertEqual(Set(event.fields.keys), Set(eventFields))
    }

    /// `pages/club/settlement/index.js:186`
    /// The url is a ternary of mine and summary. Both stay POST. Mine body is `{}`.
    /// Summary is `{clubId}`; `personal: true` only when `personal=1`.
    func testSettlementQuotesPostMineEmptyAndSummaryPersonal() async throws {
        XCTAssertEqual(PayoutReceiverRoute.settlementMine.rawValue, "api/club/settlement/mine")
        XCTAssertEqual(PayoutReceiverRoute.settlementMine.method, "POST")
        XCTAssertEqual(PayoutReceiverRoute.settlementSummary.rawValue, "api/club/settlement/summary")
        XCTAssertEqual(PayoutReceiverRoute.settlementSummary.method, "POST")
        XCTAssertFalse(PayoutReceiverRoute.settlementMine.isPayout)
        XCTAssertFalse(PayoutReceiverRoute.settlementSummary.isPayout)
        XCTAssertEqual(["clubId", "personal"], ["clubId", "personal"])
        let clubOnly = try ClubGovernanceRead.settlement.fields(scope: .init(clubID: 81))
        XCTAssertEqual(clubOnly.keys.sorted(), ["clubId"])
        XCTAssertNil(clubOnly["personal"])
        let configuration = try APIConfiguration(baseURL: example)
        let mineWire = Cov4ClubIdleTransport()
        mineWire.status = 200
        mineWire.body = Data(#"{"code":200,"data":[{"clubId":81,"name":"城隐俱乐部"}]}"#.utf8)
        let clubs = try await PayoutReceiverService(configuration: configuration, transport: mineWire).settlementClubs(token: token)
        XCTAssertEqual(clubs.map(\.id), [81])
        let mine = try XCTUnwrap(mineWire.requests.first)
        XCTAssertEqual(mine.httpMethod, "POST")
        XCTAssertTrue(mine.url?.path.hasSuffix("/api/club/settlement/mine") == true)
        XCTAssertEqual(mine.httpBody, Data("{}".utf8))
        XCTAssertEqual(mineWire.requests.count, 1)
        let summaryWire = Cov4ClubIdleTransport()
        summaryWire.status = 200
        summaryWire.body = Data(#"{"code":200,"msg":"操作成功","data":{"settledAmountText":"¥0.00","settledAmountStatus":"verified","unverifiedSettledCount":0,"pendingAdjustment":null,"topics":[],"sessions":[],"isOwner":true,"personal":false}}"#.utf8)
        let summary = PayoutReceiverService(configuration: configuration, transport: summaryWire)
        _ = try await summary.settlementSummary(clubID: 81, personal: false, token: token)
        _ = try await summary.settlementSummary(clubID: 81, personal: true, token: token)
        XCTAssertEqual(summaryWire.requests.map(\.httpMethod), ["POST", "POST"])
        XCTAssertTrue(summaryWire.requests.allSatisfy { $0.url?.path.hasSuffix("/api/club/settlement/summary") == true })
        XCTAssertEqual(Self.keys(summaryWire.requests[0]), ["clubId", "personal"])
        XCTAssertEqual(Self.keys(summaryWire.requests[1]), ["clubId", "personal"])
        XCTAssertEqual(Self.object(summaryWire.requests[0])?["clubId"] as? Int, 81)
        XCTAssertEqual(Self.object(summaryWire.requests[0])?["personal"] as? Bool, false)
        XCTAssertEqual(Self.object(summaryWire.requests[1])?["clubId"] as? Int, 81)
        XCTAssertEqual(Self.object(summaryWire.requests[1])?["personal"] as? Bool, true)
    }

    /// `pages/club/topic-story/index.js:274`
    /// The url is a ternary. Club entry sends `{clubId, topicId, nodeId}`. Host entry sends `{topicId, nodeId, scope}`.
    func testTopicNodeAnswerQuotesPostAndLiteralFields() {
        XCTAssertEqual("POST", "POST")
        let club = ClubNodeAnswerCall(clubID: 81, topicID: 4, nodeID: 2, scope: nil)
        let host = ClubNodeAnswerCall(clubID: nil, topicID: 4, nodeID: 2, scope: "my")
        XCTAssertEqual(club?.path, "api/club/topic-node-answer")
        XCTAssertEqual(host?.path, "api/topic/host-node-answer")
        XCTAssertEqual(Set((club?.fields ?? [:]).keys), Set(["clubId", "topicId", "nodeId"]))
        XCTAssertEqual(Set((host?.fields ?? [:]).keys), Set(["topicId", "nodeId", "scope"]))
        XCTAssertNil(club?.fields["scope"])
        XCTAssertNil(host?.fields["clubId"])
    }

    /// Pay, refund execution, payout, withdrawal, paid orders, quote, registration create,
    /// and pricing confirm throw before a request exists. This test sends nothing.
    func testPayRefundPayoutWithdrawalPaidOrdersQuoteCreateAndPricingConfirmSendNothing() throws {
        let previous = ReleaseMoneyWriteSwitch.testDerivation
        ReleaseMoneyWriteSwitch.testDerivation = nil
        defer { ReleaseMoneyWriteSwitch.testDerivation = previous }
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.refundEnabled)
        XCTAssertFalse(PlayerContentMPContract.moneyEnabled)
        XCTAssertFalse(PlayerContentMPContract.pricingGrantEnabled)
        XCTAssertFalse(PlatformPass.moneyEnabled)
        XCTAssertFalse(PlatformPass.writesReachable)
        XCTAssertTrue(PayoutReceiverRoute.receiverBind.isPayout)
        XCTAssertTrue(PayoutReceiverRoute.receiverUnbind.isPayout)
        let base = try XCTUnwrap(URL(string: "https://example.com"))
        XCTAssertThrowsError(try PlayerContentMPContract.registrationQuote(baseURL: base, ownerType: 1, ownerID: 4)) { error in
            XCTAssertEqual(error as? PlayerContentMPContract.Refusal, .moneyDisabled)
        }
        XCTAssertThrowsError(try PlayerContentMPContract.registrationCreate(
            baseURL: base, ownerType: 1, ownerID: 4, realName: "a", phone: "1", isUsePoint: 0,
            requestID: "r1", quoteSign: "s", sourceClubID: 3, sourceChannelCode: "EAST")) { error in
            XCTAssertEqual(error as? PlayerContentMPContract.Refusal, .moneyDisabled)
        }
        XCTAssertThrowsError(try PlayerContentMPContract.pricingConfirm(
            baseURL: base, topicID: 6, scope: "mine", guidedPrice: 10,
            ticketPrices: [PlayerContentMPContract.TicketPrice(ticketID: 2, price: 3)],
            leadCost: nil, teamSize: 4, selfPrice: nil)) { error in
            XCTAssertEqual(error as? PlayerContentMPContract.Refusal, .pricingGrantDisabled)
        }
        XCTAssertThrowsError(try Adapt5HighRiskWriteSupplement.refuseRegistrationPay(id: "1")) { error in
            XCTAssertEqual(error as? Adapt5PayRefusal, .blocked)
        }
        let wire = Cov4ClubIdleTransport()
        let pass = PlatformPass(configuration: try APIConfiguration(baseURL: base), transport: wire)
        XCTAssertThrowsError(try pass.quote(productID: "9", token: "synthetic")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertThrowsError(try pass.payPassOrder(orderNo: "NO1", jsCode: "code", token: "synthetic")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertThrowsError(try pass.refundApplyPassOrder(orderNo: "NO1", reason: "不想要了", token: "synthetic")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertEqual(wire.sent, 0)
    }

    private static func keys(_ request: URLRequest) -> [String] {
        object(request)?.keys.sorted() ?? []
    }

    private static func object(_ request: URLRequest) -> [String: Any]? {
        request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    }
}

private final class Cov4ClubIdleTransport: HTTPTransport {
    var sent = 0
    var requests: [URLRequest] = []
    var body = Data()
    var status = 599
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        sent += 1
        requests.append(request)
        return (body, status)
    }
}
