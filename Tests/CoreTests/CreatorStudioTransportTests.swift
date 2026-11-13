import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// U08-03 / U08-04 client against stubbed responses in the real TEST JSON shapes, one case per route, plus the U06
/// turn block. Each case checks the method, path, query and body the client sends.
@MainActor final class CreatorStudioTransportTests: XCTestCase {
    private final class Stub: HTTPTransport, @unchecked Sendable {
        var replies: [(String, Int)] = []
        var requests: [URLRequest] = []
        var fails = false
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            if fails { throw URLError(.networkConnectionLost) }
            let (body, status) = replies.isEmpty ? (#"{"code":200}"#, 200) : replies.removeFirst()
            return (Data(body.utf8), status)
        }
        var last: URLRequest { requests[requests.count - 1] }
        var lastPath: String { last.url?.path ?? "" }
        var lastQuery: [String: String] {
            Dictionary(uniqueKeysWithValues: (URLComponents(url: last.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        }
        var lastBody: [String: Any] { (try? JSONSerialization.jsonObject(with: last.httpBody ?? Data()) as? [String: Any]) ?? [:] }
    }

    private func service(_ stub: Stub, token: String? = "player-token") throws -> CreatorStudioService {
        CreatorStudioService(configuration: try APIConfiguration(baseURL: URL(string: "https://example.com/fixture/")!), transport: stub, token: { token })
    }

    // MARK: U08-03

    func testFeedbackReadIsScopedToOneTopicAndHidesTheReporter() async throws {
        let stub = Stub(); stub.replies = [(Fixture.feedbackPage, 200)]
        let page = try await service(stub).feedback(topicID: 992001)
        XCTAssertEqual(stub.last.httpMethod, "GET")
        XCTAssertNil(stub.last.httpBody)
        XCTAssertEqual(stub.lastPath, "/fixture/api/creator/feedback")
        XCTAssertEqual(stub.lastQuery, ["topicId": "992001"])
        XCTAssertEqual(stub.last.value(forHTTPHeaderField: "Authorization"), "player-token")
        XCTAssertEqual(page.items.map(\.feedbackId), [2, 1])
        XCTAssertEqual(page.items.first?.category, "PLACE")
        XCTAssertEqual(page.items.first?.configVersion, 1)
        XCTAssertNil(page.items.first?.nodeId)
        XCTAssertEqual(page.items.first?.ticketId, 2)
        XCTAssertFalse(page.hasMore)
        XCTAssertFalse(Fixture.feedbackPage.contains("memberId"))
    }

    func testTicketListDecodesServerDerivedStageAndEvidence() async throws {
        let stub = Stub(); stub.replies = [(Fixture.ticketPage, 200)]
        let page = try await service(stub).tickets(limit: 2)
        XCTAssertEqual(stub.lastPath, "/fixture/api/creator/maintenance/tickets")
        XCTAssertEqual(stub.lastQuery, ["limit": "2"])
        let ticket = try XCTUnwrap(page.items.first)
        XCTAssertEqual(ticket.ticketId, 2)
        XCTAssertEqual(ticket.knownStage, .closed)
        XCTAssertTrue(ticket.isClosed)
        XCTAssertEqual(ticket.baseline, .init(configVersion: 1, contentRevisionId: 1))
        XCTAssertEqual(ticket.current.publishedConfigVersion, 1)
        XCTAssertFalse(ticket.evidence.fixPublished)
        XCTAssertFalse(ticket.canCloseFixed)
        XCTAssertEqual(ticket.resolution, "NO_CHANGE")
        XCTAssertEqual(ticket.feedback.map(\.feedbackId), [2])
        XCTAssertNil(ticket.feedback.first?.topicName)
    }

    func testTicketDetailReadsOneTicketAndMapsMissingTicket() async throws {
        let stub = Stub(); stub.replies = [(Fixture.ticketClosed, 200), (#"{"msg":"不存在","code":404,"errorCode":"TICKET_NOT_FOUND"}"#, 404)]
        let ticket = try await service(stub).ticket(id: 2)
        XCTAssertEqual(stub.lastPath, "/fixture/api/creator/maintenance/tickets/2")
        XCTAssertEqual(ticket.closeReason, "r2 冒烟：已人工核实")
        do { _ = try await service(stub).ticket(id: 999999); XCTFail("expected not found") }
        catch { XCTAssertEqual(error as? CreatorStudioFailure, .notFound(code: "TICKET_NOT_FOUND")) }
    }

    func testOpenTicketSendsTheContractBodyAndDecodesTheReportedTicket() async throws {
        let stub = Stub(); stub.replies = [(Fixture.ticketOpened, 200)]
        let request = CreatorTicketOpenRequest(topicId: 992001, title: "入口标识", note: nil, feedbackIds: [2])
        let outcome = try await service(stub).openTicket(request)
        XCTAssertEqual(stub.last.httpMethod, "POST")
        XCTAssertEqual(stub.lastPath, "/fixture/api/creator/maintenance/tickets")
        XCTAssertNil(stub.last.url?.query)
        XCTAssertEqual(stub.last.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(Set(stub.lastBody.keys), ["requestId", "topicId", "title", "feedbackIds"])
        XCTAssertEqual(stub.lastBody["requestId"] as? String, request.requestId)
        XCTAssertEqual(request.requestId.count, 32)
        guard case .applied(let ticket) = outcome else { return XCTFail("\(outcome)") }
        XCTAssertEqual(ticket.knownStage, .reported)
        XCTAssertEqual(ticket.version, 1)
    }

    func testOpenWithLostResponseIsUnknownAndTheRequestReadRecoversIt() async throws {
        let stub = Stub(); stub.fails = true
        let request = CreatorTicketOpenRequest(topicId: 992001, title: "入口标识", note: "note", feedbackIds: [2])
        let lost = try await service(stub).openTicket(request)
        XCTAssertEqual(lost, .unknown)
        stub.fails = false; stub.replies = [(Fixture.requestApplied, 200), (Fixture.requestNotFound, 200)]
        let state = try await service(stub).openRequest(request.requestId)
        XCTAssertEqual(stub.lastPath, "/fixture/api/creator/maintenance/requests/" + request.requestId)
        guard case .applied(let ticket) = state else { return XCTFail("\(state)") }
        XCTAssertEqual(ticket.ticketId, 2)
        let missing = try await service(stub).openRequest("nonexistent-req-1")
        XCTAssertEqual(missing, .notFound)
    }

    func testCloseSendsVersionCASAndMapsFixNotPublished() async throws {
        let stub = Stub(); stub.replies = [(Fixture.fixNotPublished, 409), (Fixture.ticketClosed, 200)]
        let fixed = try await service(stub).closeTicket(id: 2, .init(expectedVersion: 1, resolution: .fixed, reason: nil))
        XCTAssertEqual(stub.lastPath, "/fixture/api/creator/maintenance/tickets/2/close")
        XCTAssertEqual(Set(stub.lastBody.keys), ["requestId", "expectedVersion", "resolution"])
        XCTAssertEqual(fixed, .rejected(.rejected(status: 409, code: "FIX_NOT_PUBLISHED", message: "修复还没有发布成新版本")))
        let noChange = try await service(stub).closeTicket(id: 2, .init(expectedVersion: 1, resolution: .noChange, reason: "r2 冒烟：已人工核实"))
        XCTAssertEqual(stub.lastBody["resolution"] as? String, "NO_CHANGE")
        XCTAssertEqual(stub.lastBody["expectedVersion"] as? Int, 1)
        guard case .applied(let ticket) = noChange else { return XCTFail("\(noChange)") }
        XCTAssertEqual(ticket.knownStage, .closed)
        let count = stub.requests.count
        let empty = try await service(stub).closeTicket(id: 2, .init(expectedVersion: 2, resolution: .noChange, reason: " "))
        XCTAssertEqual(stub.requests.count, count, "a NO_CHANGE without a reason is not sent")
        XCTAssertEqual(empty, .rejected(.rejected(status: 400, code: "CLOSE_REASON_REQUIRED", message: nil)))
    }

    func testSystemBusyBodyIsUnavailableNotEmpty() async throws {
        let stub = Stub(); stub.replies = [(Fixture.systemBusy, 200)]
        do { _ = try await service(stub).feedback(topicID: nil); XCTFail("expected unavailable") }
        catch { XCTAssertEqual(error as? CreatorStudioFailure, .unavailable(code: nil)) }
        XCTAssertNil(stub.last.url?.query)
    }

    // MARK: U08-04

    func testPostGameOutcomeSendsQueryAndKeepsNotMatureApartFromZero() async throws {
        let stub = Stub(); stub.replies = [(Fixture.outcome, 200)]
        let outcome = try await service(stub).postGameOutcome(cohortDate: "2026-11-13", windowDays: 30, topicID: 992001)
        XCTAssertEqual(stub.last.httpMethod, "GET")
        XCTAssertEqual(stub.lastPath, "/fixture/api/creator/analytics/post-game-outcome")
        XCTAssertEqual(stub.lastQuery, ["cohortDate": "2026-11-13", "windowDays": "30", "topicId": "992001"])
        XCTAssertEqual(outcome.scope.topicIds, [990013, 992001])
        let report = outcome.report
        XCTAssertFalse(report.mature)
        XCTAssertEqual(report.basisVersion, "POST_GAME_OUTCOME_V2_20261108")
        XCTAssertEqual(report.computedAt, "2026-11-13T23:12:31.558+08:00")
        XCTAssertEqual(report.historicalReplayable, false)
        XCTAssertEqual(report.testExclusionBasis, "NO_SERVER_MARKER")
        XCTAssertNil(report.cohort?.retentionRate)
        XCTAssertNil(report.cohort?.retainedMembers)
        XCTAssertEqual(CreatorOutcomePresentation.rate(report.cohort?.retentionRate, mature: report.mature), .notMature)
        XCTAssertEqual(CreatorOutcomePresentation.retained(report.cohort?.retainedMembers, mature: report.mature), .notMature)
        XCTAssertEqual(CreatorOutcomePresentation.rate(nil, mature: true), .dash)
        XCTAssertEqual(CreatorOutcomePresentation.count(nil), .dash)
        XCTAssertEqual(CreatorOutcomePresentation.shownMetrics(outcome).map(\.metricCode), ["OFFICIAL_COMPLETION", "SECOND_VALID_REGISTRATION"])
        XCTAssertEqual(CreatorOutcomePresentation.omittedMetrics(outcome),
                       ["REWARD_ISSUANCE", "PRIVATE_PHOTO", "PUBLIC_SHARE", "RECOMMENDATION_CLICK", "CLIENT_OBSERVED_EVENT", "ROAM_REVISIT"])
        let marks = CreatorOutcomePresentation.watermarks(report)
        XCTAssertEqual(marks.count, 5)
        XCTAssertEqual(marks.first?.source, "cms_registration.create_time")
        XCTAssertEqual(report.metrics["SECOND_VALID_REGISTRATION"]?.watermarkAt, nil)
        XCTAssertEqual(report.repeatSignupV1?.all?.notMatureMembers, 1)
    }

    func testCreatorWithoutTopicsIsABusinessNotFoundAndKeepsTheEntry() async throws {
        let stub = Stub(); stub.replies = [(Fixture.outcomeNoTopics, 404)]
        do { _ = try await service(stub).postGameOutcome(cohortDate: "2026-11-13"); XCTFail("expected not found") }
        catch {
            XCTAssertEqual(error as? CreatorStudioFailure, .notFound(code: "CREATOR_TOPICS_NOT_FOUND"))
            XCTAssertEqual(CreatorStudioAvailability.from(error), .available)
        }
        XCTAssertEqual(stub.lastQuery, ["cohortDate": "2026-11-13"])
    }

    // MARK: Availability

    func testRouteMissingOnTheBackendHidesBothEntries() async throws {
        let stub = Stub(); stub.replies = [(Fixture.routeAbsent, 404), (Fixture.routeAbsent, 404)]
        let service = try service(stub)
        let maintenance = await CreatorStudioAvailability.probeMaintenance(service)
        let outcome = await CreatorStudioAvailability.probeOutcome(service)
        XCTAssertEqual(maintenance, .hidden)
        XCTAssertEqual(outcome, .hidden)
        stub.replies = [(Fixture.ticketPage, 200), (Fixture.outcome, 200)]
        let liveMaintenance = await CreatorStudioAvailability.probeMaintenance(service)
        let liveOutcome = await CreatorStudioAvailability.probeOutcome(service)
        XCTAssertEqual(liveMaintenance, .available)
        XCTAssertEqual(liveOutcome, .available)
    }

    func testRefusedCompositionAndSignedOutHideTheEntry() async throws {
        final class Refusing: HTTPTransport { func send(_ request: URLRequest) async throws -> (Data, Int) { throw APIError.notConfigured } }
        let refused = CreatorStudioService(configuration: try APIConfiguration(baseURL: URL(string: "https://example.com/fixture/")!), transport: Refusing(), token: { "player-token" })
        let refusedProbe = await CreatorStudioAvailability.probeMaintenance(refused)
        XCTAssertEqual(refusedProbe, .hidden)
        let stub = Stub()
        let signedOut = await CreatorStudioAvailability.probeOutcome(try service(stub, token: nil))
        XCTAssertEqual(signedOut, .hidden)
        XCTAssertTrue(stub.requests.isEmpty)
    }

    // MARK: U06 turn block

    private func multiplayer(leader: Bool, turnsUntilMine: String, myTurn: Bool, finished: Bool = false, index: Int = 1) throws -> PlayWireValue {
        let current = leader ? #","currentRoleId":"finisher""# : ""
        let order = leader ? #","turnOrder":[{"position":0,"roleId":"starter","roleLabel":"Starter"},{"position":1,"roleId":"finisher","roleLabel":"Finisher"},{"position":2,"roleId":"scout","roleLabel":"Scout"}]"# : ""
        let raw = """
        {"members":[{"memberId":9001,"name":"A"}],"leaderMemberId":\(leader ? 9001 : 9002),"myRole":"scout","myRoleLabel":"Scout","turnIndex":\(index),"completedUnitIds":["u1"],"turn":{"index":\(index),"position":\(index % 3),"size":3,"round":\(index / 3 + 1),"completedTurns":1,"requiredTurns":\(finished ? 1 : 4),"finished":\(finished),"myTurn":\(myTurn),"turnsUntilMine":\(turnsUntilMine)\(current)}\(order)}
        """
        return try JSONDecoder().decode(PlayWireValue.self, from: Data(raw.utf8))
    }

    func testMemberTurnBlockShowsCurrentAndNextWithoutOtherRoles() throws {
        let turn = try XCTUnwrap(PlayAdvancedTurn(multiplayer: multiplayer(leader: false, turnsUntilMine: "1", myTurn: false), isLeader: false))
        XCTAssertEqual(turn.position, 1)
        XCTAssertEqual(turn.round, 1)
        XCTAssertFalse(turn.myTurn)
        XCTAssertEqual(turn.turnsUntilMine, 1)
        XCTAssertEqual(turn.nextPosition, 2)
        XCTAssertEqual(turn.nextIsMine, true)
        XCTAssertNil(turn.currentRoleID)
        XCTAssertTrue(turn.order.isEmpty)
        XCTAssertNil(turn.currentSlot)
    }

    func testNonLeaderDropsALeakedOrder() throws {
        let leaked = try multiplayer(leader: true, turnsUntilMine: "1", myTurn: false)
        let turn = try XCTUnwrap(PlayAdvancedTurn(multiplayer: leaked, isLeader: false))
        XCTAssertNil(turn.currentRoleID)
        XCTAssertTrue(turn.order.isEmpty)
    }

    func testLeaderSeesTheFullOrderWithCurrentAndNextRole() throws {
        let turn = try XCTUnwrap(PlayAdvancedTurn(multiplayer: multiplayer(leader: true, turnsUntilMine: "1", myTurn: false), isLeader: true))
        XCTAssertEqual(turn.currentRoleID, "finisher")
        XCTAssertEqual(turn.order.map(\.roleID), ["starter", "finisher", "scout"])
        XCTAssertEqual(turn.currentSlot?.display, "Finisher")
        XCTAssertEqual(turn.nextSlot?.display, "Scout")
    }

    func testFinishedAndInconsistentTurnBlocks() throws {
        let done = try XCTUnwrap(PlayAdvancedTurn(multiplayer: multiplayer(leader: true, turnsUntilMine: "null", myTurn: false, finished: true), isLeader: true))
        XCTAssertTrue(done.finished)
        XCTAssertNil(done.nextPosition)
        XCTAssertNil(done.currentSlot)
        XCTAssertNil(done.currentRoleID)
        XCTAssertNil(PlayAdvancedTurn(multiplayer: try multiplayer(leader: false, turnsUntilMine: "1", myTurn: true), isLeader: false), "myTurn must agree with turnsUntilMine")
        XCTAssertNil(PlayAdvancedTurn(multiplayer: try JSONDecoder().decode(PlayWireValue.self, from: Data(#"{"turnIndex":0}"#.utf8)), isLeader: false), "no turn block keeps the old row")
    }
}

private enum Fixture {
    // Real shapes from TEST https://8120-agqyfqxs5vwolymtoibzq3fhde.instabox.tech (hengyin integration/backend-app-r2,
    // 2026-11-13). ticketOpened/requestApplied reuse the ticket shape with the OPEN/REPORTED values the smoke run returned.
    static let feedbackPage = #"{"msg":"操作成功","code":200,"data":{"items":[{"feedbackId":2,"topicId":992001,"topicName":"E2E 城市定向·老城三章","nodeId":null,"nodeName":null,"category":"PLACE","content":"r2 smoke：入口标识不清楚","configVersion":1,"contentRevisionId":null,"createdAt":"2026-11-13T22:50:55.737+08:00","ticketId":2},{"feedbackId":1,"topicId":992001,"topicName":"E2E 城市定向·老城三章","nodeId":null,"nodeName":null,"category":"PLACE","content":"r2 smoke：入口标识不清楚","configVersion":1,"contentRevisionId":null,"createdAt":"2026-11-13T22:41:02.283+08:00","ticketId":1}],"hasMore":false,"nextCursor":null}}"#
    static let ticketPage = #"{"msg":"操作成功","code":200,"data":{"items":[{"ticketId":2,"topicId":992001,"topicName":"E2E 城市定向·老城三章","title":"入口标识","note":null,"status":"CLOSED","stage":"CLOSED","version":2,"baseline":{"configVersion":1,"contentRevisionId":1},"current":{"draftConfigVersion":1,"publishedConfigVersion":1},"evidence":{"fixDrafted":false,"fixPublished":false,"retestedByAuthor":false},"canCloseFixed":false,"resolution":"NO_CHANGE","fixedConfigVersion":null,"closeReason":"r2 冒烟：已人工核实","createdAt":"2026-11-13T22:50:55.944+08:00","closedAt":"2026-11-13T22:50:56.063+08:00","feedback":[{"feedbackId":2,"topicId":992001,"nodeId":null,"nodeName":null,"category":"PLACE","content":"r2 smoke：入口标识不清楚","configVersion":1,"contentRevisionId":null,"createdAt":"2026-11-13T22:50:55.737+08:00"}]},{"ticketId":1,"topicId":992001,"topicName":"E2E 城市定向·老城三章","title":"入口标识","note":null,"status":"CLOSED","stage":"CLOSED","version":2,"baseline":{"configVersion":1,"contentRevisionId":1},"current":{"draftConfigVersion":1,"publishedConfigVersion":1},"evidence":{"fixDrafted":false,"fixPublished":false,"retestedByAuthor":false},"canCloseFixed":false,"resolution":"NO_CHANGE","fixedConfigVersion":null,"closeReason":"r2 冒烟：已人工核实","createdAt":"2026-11-13T22:41:02.336+08:00","closedAt":"2026-11-13T22:41:02.380+08:00","feedback":[{"feedbackId":1,"topicId":992001,"nodeId":null,"nodeName":null,"category":"PLACE","content":"r2 smoke：入口标识不清楚","configVersion":1,"contentRevisionId":null,"createdAt":"2026-11-13T22:41:02.283+08:00"}]}],"hasMore":false,"nextCursor":null}}"#
    static let ticketClosed = #"{"msg":"操作成功","code":200,"data":{"ticketId":2,"topicId":992001,"topicName":"E2E 城市定向·老城三章","title":"入口标识","note":null,"status":"CLOSED","stage":"CLOSED","version":2,"baseline":{"configVersion":1,"contentRevisionId":1},"current":{"draftConfigVersion":1,"publishedConfigVersion":1},"evidence":{"fixDrafted":false,"fixPublished":false,"retestedByAuthor":false},"canCloseFixed":false,"resolution":"NO_CHANGE","fixedConfigVersion":null,"closeReason":"r2 冒烟：已人工核实","createdAt":"2026-11-13T22:50:55.944+08:00","closedAt":"2026-11-13T22:50:56.063+08:00","feedback":[{"feedbackId":2,"topicId":992001,"nodeId":null,"nodeName":null,"category":"PLACE","content":"r2 smoke：入口标识不清楚","configVersion":1,"contentRevisionId":null,"createdAt":"2026-11-13T22:50:55.737+08:00"}]}}"#
    static let ticketOpened = #"{"msg":"操作成功","code":200,"data":{"ticketId":2,"topicId":992001,"topicName":"E2E 城市定向·老城三章","title":"入口标识","note":null,"status":"OPEN","stage":"REPORTED","version":1,"baseline":{"configVersion":1,"contentRevisionId":1},"current":{"draftConfigVersion":1,"publishedConfigVersion":1},"evidence":{"fixDrafted":false,"fixPublished":false,"retestedByAuthor":false},"canCloseFixed":false,"resolution":null,"fixedConfigVersion":null,"closeReason":null,"createdAt":"2026-11-13T22:50:55.944+08:00","closedAt":null,"feedback":[{"feedbackId":2,"topicId":992001,"nodeId":null,"nodeName":null,"category":"PLACE","content":"r2 smoke：入口标识不清楚","configVersion":1,"contentRevisionId":null,"createdAt":"2026-11-13T22:50:55.737+08:00"}]}}"#
    static let requestApplied = #"{"msg":"操作成功","code":200,"data":{"requestId":"0123456789abcdef0123456789abcdef","state":"APPLIED","ticket":{"ticketId":2,"topicId":992001,"topicName":"E2E 城市定向·老城三章","title":"入口标识","note":null,"status":"OPEN","stage":"REPORTED","version":1,"baseline":{"configVersion":1,"contentRevisionId":1},"current":{"draftConfigVersion":1,"publishedConfigVersion":1},"evidence":{"fixDrafted":false,"fixPublished":false,"retestedByAuthor":false},"canCloseFixed":false,"resolution":null,"fixedConfigVersion":null,"closeReason":null,"createdAt":"2026-11-13T22:50:55.944+08:00","closedAt":null,"feedback":[{"feedbackId":2,"topicId":992001,"nodeId":null,"nodeName":null,"category":"PLACE","content":"r2 smoke：入口标识不清楚","configVersion":1,"contentRevisionId":null,"createdAt":"2026-11-13T22:50:55.737+08:00"}]}}}"#
    static let requestNotFound = #"{"msg":"操作成功","code":200,"data":{"requestId":"nonexistent-req-1","state":"NOT_FOUND"}}"#
    static let outcome = #"{"msg":"操作成功","code":200,"data":{"source":"creator-post-game-outcome-v1","scope":{"kind":"CREATOR_TOPICS","topicIds":[990013,992001],"cohortRule":"FIRST_VALID_REGISTRATION_ON_SCOPE_TOPICS","omittedMetrics":["REWARD_ISSUANCE","PRIVATE_PHOTO","PUBLIC_SHARE","RECOMMENDATION_CLICK","CLIENT_OBSERVED_EVENT"],"omittedReason":"NOT_ATTRIBUTABLE_TO_TOPIC"},"report":{"cohortDate":"2026-11-13","windowDays":30,"mature":false,"windowStart":"2026-11-13T00:00:00.000+08:00","windowEnd":"2026-12-14T00:00:00.000+08:00","computedAt":"2026-11-13T23:12:31.558+08:00","sourceWatermarks":{"cms_registration.payment_time":"2026-11-13T22:38:50.000+08:00","cms_registration.create_time":"2026-11-13T22:38:50.000+08:00","topic_route_session.completed_at":"2026-11-13T22:39:53.002+08:00","topic_route_session.update_time":"2026-11-13T22:39:53.002+08:00","community_post.published_at":"2026-11-13T22:38:49.000+08:00"},"cohort":{"eligibleMembers":0,"freeMembers":1,"fullRefundExcluded":0,"cancelledOrExpiredExcluded":0,"partialRefundMembers":0,"pendingRefundMembers":0,"duplicateOrdersCollapsed":0,"multiSeatCollapsed":0,"retainedMembers":null,"freeRetainedMembers":null,"partialRefundRetained":0,"pendingRefundRetained":0,"lateFactCount":0,"notMatureMembers":1,"retentionRate":null,"freeRetentionRate":null},"metrics":{"OFFICIAL_COMPLETION":{"metricCode":"OFFICIAL_COMPLETION","members":1,"memberDays":1,"facts":1,"firstOccurredAt":"2026-11-13T22:39:53.002+08:00","lastOccurredAt":"2026-11-13T22:39:53.002+08:00","sourceTables":"topic_route_session(status=1 已到终点，限创作者本人主题)","identityBasis":"创作者口径：只计本人主题的整局终局事实；member-day 去重","serverFinal":true,"publicVisible":true,"watermarkAt":"2026-11-13T22:39:53.002+08:00"},"SECOND_VALID_REGISTRATION":{"metricCode":"SECOND_VALID_REGISTRATION","members":0,"memberDays":0,"facts":0,"firstOccurredAt":null,"lastOccurredAt":null,"sourceTables":"cms_registration(payment_status=2) 另一笔不同 parent_order_no","identityBasis":"与主指标分子同源；未成熟时 members=0，须以 mature=false 区分而不是读成 0%","serverFinal":true,"publicVisible":true,"watermarkAt":null}},"roamRevisit":null,"repeatSignupV1":{"definitionVersion":"repeat_signup_v1","windowDays":30,"timeBasis":"首个有效报名 payment_time 为锚；第二笔时间 > 首笔且 < 首笔+30*24h；同时间不推断先后；逐人到窗末成熟，仅成熟会员计分子/比例，未成熟不算未复报","identityBasis":"member_id 报名账户去重；parent_order_no 区分独立订单，同单多席不重复；不推断代购实际参加人；现金/免费沿用 payable_amount 优先、total_amount 兜底、均空为0","recomputeBasis":"READ_ONLY_SQL：当前支付/报名状态与原到账退款事实重算，部分退/待审未到账不作全退；迟到仅按 create_time >= 个人窗末诊断；共享本响应 computedAt/sourceWatermarks，当前时刻之后支付不计，不可历史回放，与旧 V2 不可混比","available":true,"unknownReason":null,"paid":{"eligibilityBasis":"全历史首个现金实付>0且有效未全退报名；第二笔同样须现金实付>0且有效未全退","eligibleMembers":0,"matureMembers":0,"notMatureMembers":0,"retainedMembers":null,"retentionRate":null,"partialRefundMembers":0,"pendingRefundMembers":0,"partialRefundRetained":0,"pendingRefundRetained":0,"lateFactCount":0},"all":{"eligibilityBasis":"全历史首个有效未全退报名(含免费)；第二笔可付费或免费；与paid独立选首单和分母","eligibleMembers":1,"matureMembers":0,"notMatureMembers":1,"retainedMembers":null,"retentionRate":null,"partialRefundMembers":0,"pendingRefundMembers":0,"partialRefundRetained":0,"pendingRefundRetained":0,"lateFactCount":0}},"identityBasis":"服务端报名事实：全历史首笔有效报名(registration_status=2 & payment_status=2 & payment_time) + refund_application 到账退款；客户端观测单列，不参与分母分子","unavailableSources":{"GAME_SESSION_ACTIVITY_FINISHED":"game_session(活动级总局, status=FINISHED)：只有 finished_by 单个操作人，没有逐会员参与事实，无法把一次总局完成归属到具体会员，因此不计入 OFFICIAL_COMPLETION"},"basisVersion":"POST_GAME_OUTCOME_V2_20261108","deduplication":"MEMBER_LEVEL_FIRST_VALID_REGISTRATION","recomputeBasis":"READ_ONLY_SQL：分母=全历史首笔有效报名去重会员，分子=窗口内另一笔不同 parent_order_no 的有效报名会员","historicalReplayable":false,"snapshotNote":"即时只读计算；不落库、不可历史回放。需要对比请自行留存响应(含 computedAt 与各来源水位)","testExclusionBasis":"NO_SERVER_MARKER：现有表无服务端测试账号标记列，testExcluded 恒 0 且不可信；不得据此宣称已排除测试数据","metricCodes":["OFFICIAL_COMPLETION","SECOND_VALID_REGISTRATION"]}}}"#
    static let outcomeNoTopics = #"{"msg":"还没有自己的主题","code":404,"errorCode":"CREATOR_TOPICS_NOT_FOUND"}"#
    static let routeAbsent = #"{"msg":"请求路径不存在","code":404}"#
    static let fixNotPublished = #"{"msg":"修复还没有发布成新版本","code":409,"errorCode":"FIX_NOT_PUBLISHED"}"#
    static let systemBusy = #"{"msg":"系统繁忙，请稍后重试","code":500}"#
}
