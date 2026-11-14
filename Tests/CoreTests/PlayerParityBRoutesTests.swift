import XCTest
@testable import QuestifyCore

/// Parity package P-B: one stub reply per new request; method, path, and body match the mini-program call.
@MainActor final class PlayerParityBRoutesTests: XCTestCase {
    private final class Stub: HTTPTransport, @unchecked Sendable {
        var requests: [URLRequest] = []
        var replies: [String: (String, Int)] = [:]
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            let path = request.url!.path
            guard let reply = replies.first(where: { path.hasSuffix($0.key) })?.value else { throw URLError(.notConnectedToInternet) }
            return (Data(reply.0.utf8), reply.1)
        }
        var last: URLRequest { requests.last! }
        var lastJSON: [String: Any] { (try? JSONSerialization.jsonObject(with: last.httpBody ?? Data())) as? [String: Any] ?? [:] }
        var lastForm: String { String(data: last.httpBody ?? Data(), encoding: .utf8) ?? "" }
    }
    private let base = URL(string: "https://example.test/native")!
    private func make(_ stub: Stub) -> PlayerGapService {
        PlayerGapService(baseURL: base, accountID: 7, token: { "synthetic-token" }, transport: stub)
    }
    private func ok(_ data: String, msg: String = "done") -> (String, Int) { (#"{"code":200,"msg":"\#(msg)","data":\#(data)}"#, 200) }
    private let hashA = String(repeating: "a", count: 64), hashB = String(repeating: "b", count: 64)

    func testEveryParityBPathIsGrantedAndMoneyIsNot() {
        for path in PlayerGapService.parityBPaths {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path), path)
        }
        for money in ["/api/registration/pay", "/api/registration/payment-readiness", "/api/wallet/withdraw", "/api/club/settlement/withdraw"] {
            XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall(money), money)
        }
    }

    func testSharedControlReadValidatesTheStaffView() async throws {
        let stub = Stub()
        stub.replies["api/game/session/shared/control"] = ok(#"{"revision":3,"run":{"authorityEpoch":2,"operationStatus":"RUNNING","authorityMode":"ONLINE"},"teams":[{}],"stations":[{},{}],"availableActions":["OFFLINE_ANCHOR"],"offlineAnchorAvailable":true}"#)
        let read = await make(stub).sharedControl(activityID: 5)
        XCTAssertEqual(stub.last.httpMethod, "GET")
        XCTAssertEqual(stub.last.url?.query, "activityId=5")
        guard case .ready(let data) = read else { return XCTFail("\(read)") }
        let summary = try XCTUnwrap(SharedRunControlSummary(data))
        XCTAssertEqual(summary.teamCount, 1); XCTAssertEqual(summary.stationCount, 2); XCTAssertTrue(summary.offlineAnchorAvailable)
        XCTAssertNil(summary.anchoredAt)
        // An epoch below 1 or a non-string action is invalid data, not a ready panel.
        stub.replies["api/game/session/shared/control"] = ok(#"{"revision":3,"run":{"authorityEpoch":0},"teams":[],"stations":[]}"#)
        let awaited1 = await make(stub).sharedControl(activityID: 5)
        XCTAssertEqual(awaited1, .invalid)
        stub.replies["api/game/session/shared/control"] = (#"{"code":403,"msg":"仅活动所属俱乐部主理人可执行","data":{"reasonCode":"GAME_FORBIDDEN"}}"#, 200)
        let awaited2 = await make(stub).sharedControl(activityID: 5)
        XCTAssertEqual(awaited2, .businessError(message: "仅活动所属俱乐部主理人可执行", reasonCode: "GAME_FORBIDDEN"))
        stub.replies["api/game/session/shared/control"] = ("", 502)
        let awaited3 = await make(stub).sharedControl(activityID: 5)
        XCTAssertEqual(awaited3, .networkError)
    }

    func testSharedExportRead() async throws {
        let stub = Stub()
        stub.replies["api/game/session/shared/export"] = ok(#"{"revision":3,"authorityEpoch":2,"activityId":5,"sessionId":41,"configHash":"\#(hashA)","highWaterHash":"\#(hashB)","manual":{"needsReview":true,"nextSequence":4}}"#)
        guard case .ready(let data) = await make(stub).sharedExport(activityID: 5) else { return XCTFail() }
        XCTAssertEqual(stub.last.url?.path, "/native/api/game/session/shared/export")
        let summary = try XCTUnwrap(SharedRunExportSummary(data))
        XCTAssertEqual(summary.sessionID, 41); XCTAssertTrue(summary.manualNeedsReview); XCTAssertEqual(summary.manualNextSequence, 4)
        stub.replies["api/game/session/shared/export"] = ok(#"{"revision":3,"authorityEpoch":2,"activityId":6,"sessionId":41,"configHash":"\#(hashA)","highWaterHash":"\#(hashB)"}"#)
        let awaited4 = await make(stub).sharedExport(activityID: 5)
        XCTAssertEqual(awaited4, .invalid)
    }

    func testAnchorOnlyAGameReasonRefuses() async {
        let stub = Stub()
        stub.replies["api/game/session/shared/export/anchor"] = ok(#"{"activityId":5,"sessionId":41,"authorityEpoch":2,"configHash":"\#(hashA)","highWaterHash":"\#(hashB)","anchor":{"epoch":2,"at":1700000000000,"configHash":"\#(hashA)","highWaterHash":"\#(hashB)"}}"#)
        let anchored = await make(stub).anchorSharedRun(activityID: 5)
        XCTAssertEqual(stub.last.httpMethod, "POST")
        XCTAssertEqual(stub.lastJSON["activityId"] as? Int, 5)
        if case .anchored = anchored {} else { XCTFail("\(anchored)") }
        stub.replies["api/game/session/shared/export/anchor"] = (#"{"code":500,"msg":"离线记录未开始","data":{"reasonCode":"GAME_STATE_CONFLICT"}}"#, 200)
        let awaited5 = await make(stub).anchorSharedRun(activityID: 5)
        XCTAssertEqual(awaited5, .refused(message: "离线记录未开始"))
        stub.replies["api/game/session/shared/export/anchor"] = (#"{"code":500,"msg":"x"}"#, 200)
        let awaited6 = await make(stub).anchorSharedRun(activityID: 5)
        XCTAssertEqual(awaited6, .unknown)
        stub.replies["api/game/session/shared/export/anchor"] = ok(#"{"activityId":5,"sessionId":41,"authorityEpoch":2,"anchor":{"epoch":1}}"#)
        let awaited7 = await make(stub).anchorSharedRun(activityID: 5)
        XCTAssertEqual(awaited7, .unknown)
    }

    func testLeadTicketResolveAndSeatTarget() {
        XCTAssertEqual(LeadMemberTicket.resolve("  dyn.code "), .code("dyn.code"))
        XCTAssertEqual(LeadMemberTicket.resolve(#"{"code":"abc","type":"topic"}"#), .code("abc"))
        XCTAssertEqual(LeadMemberTicket.resolve(#"{"code":"abc","type":"activity"}"#), .notTopic)
        XCTAssertEqual(LeadMemberTicket.resolve("{bad"), .malformed)
        XCTAssertEqual(LeadMemberTicket.resolve(""), .malformed)
        let seat = RegistrationSeatTarget(code: "v1.88.topic_seat_2.x.y.z", activityID: 5)
        XCTAssertEqual(seat?.registrationID, "88"); XCTAssertEqual(seat?.seatNo, 2); XCTAssertEqual(seat?.activityID, "5")
        XCTAssertNil(RegistrationSeatTarget(code: "v1.88.topic_seat_0.x.y.z", activityID: 5))
        XCTAssertNil(RegistrationSeatTarget(code: "v1.88.group_v2_1_2.x.y", activityID: 5))
    }

    func testScanGroupMemberTicketFormAndClassification() async throws {
        let stub = Stub()
        stub.replies["api/registration/scan_group_member_ticket"] = ok("null", msg: "核销成功")
        let plain = await make(stub).scanGroupMemberTicket(code: "dyn+1", activityID: 5)
        XCTAssertEqual(stub.last.httpMethod, "POST")
        XCTAssertEqual(stub.lastForm, "activityId=5&code=dyn%2B1")
        XCTAssertEqual(LeadTicketScanOutcome.classify(plain, seat: nil), .verified(message: "核销成功"))
        XCTAssertEqual(LeadTicketScanOutcome.classify(nil, seat: nil), .failed(message: nil))
        let seat = try XCTUnwrap(RegistrationSeatTarget(code: "v1.88.topic_seat_2.x.y.z", activityID: 5))
        let receipt = #"{"seatId":3,"registrationId":88,"activityId":5,"verifierMemberId":7,"seatNo":2,"replayed":false,"verifiedAt":"2026-11-13 10:00:00"}"#
        stub.replies["api/registration/scan_group_member_ticket"] = ok(receipt)
        let awaited8 = await make(stub).scanGroupMemberTicket(code: "v1.88.topic_seat_2.x.y.z", activityID: 5)
        XCTAssertEqual(LeadTicketScanOutcome.classify(awaited8, seat: seat), .verified(message: "done"))
        // A 200 for another seat, a business 500, or no reply leaves the seat UNKNOWN.
        stub.replies["api/registration/scan_group_member_ticket"] = ok(#"{"seatId":3,"registrationId":89,"activityId":5,"verifierMemberId":7,"seatNo":2,"replayed":false,"verifiedAt":"x"}"#)
        let awaited9 = await make(stub).scanGroupMemberTicket(code: "c", activityID: 5)
        XCTAssertEqual(LeadTicketScanOutcome.classify(awaited9, seat: seat), .unknown)
        stub.replies["api/registration/scan_group_member_ticket"] = (#"{"code":500,"msg":"err"}"#, 200)
        let awaited10 = await make(stub).scanGroupMemberTicket(code: "c", activityID: 5)
        XCTAssertEqual(LeadTicketScanOutcome.classify(awaited10, seat: seat), .unknown)
        XCTAssertEqual(LeadTicketScanOutcome.classify(nil, seat: seat), .unknown)
        stub.replies["api/registration/scan_group_member_ticket"] = (#"{"code":409,"msg":"已在别处核销"}"#, 200)
        let awaited11 = await make(stub).scanGroupMemberTicket(code: "c", activityID: 5)
        XCTAssertEqual(LeadTicketScanOutcome.classify(awaited11, seat: seat), .review(message: "已在别处核销"))
        // The recovery read: form of the original seat; only a replayed receipt settles it.
        stub.replies["api/verify/seat/receipt"] = ok(receipt.replacingOccurrences(of: #""replayed":false"#, with: #""replayed":true"#))
        let recovered = await make(stub).seatReceipt(seat)
        XCTAssertEqual(stub.lastForm, "activityId=5&registrationId=88&seatNo=2")
        XCTAssertTrue(LeadTicketScanOutcome.recovered(recovered, seat: seat))
        stub.replies["api/verify/seat/receipt"] = ok(receipt)
        let awaited12 = await make(stub).seatReceipt(seat)
        XCTAssertFalse(LeadTicketScanOutcome.recovered(awaited12, seat: seat))
    }

    func testPendingSeatStoreHoldsUntilCleared() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "parityB.seat.\(UUID().uuidString)"))
        let store = LeadTicketPendingStore(defaults: defaults)
        let seat = try XCTUnwrap(RegistrationSeatTarget(code: "v1.88.activity_seat_1.x.y.z", activityID: 5))
        let key = LeadTicketPendingStore.key(accountID: 7, target: seat)
        XCTAssertFalse(store.isHeld(key))
        XCTAssertTrue(store.hold(key, target: seat)); XCTAssertTrue(store.isHeld(key))
        store.clear(key); XCTAssertFalse(store.isHeld(key))
    }

    func testOrientAlternativeSaveAndReadback() async throws {
        let stub = Stub()
        stub.replies["api/orient/task/alternative"] = ok("null")
        let row = OrientAlternativeRow(type: .quiz, on: true, prompt: "Which door?", answer: "red")
        let reply = await make(stub).saveOrientAlternative(topicID: 12, taskID: 34, row: row)
        if case .ok = reply {} else { XCTFail("\(reply)") }
        XCTAssertEqual(stub.last.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(stub.lastJSON["alternativeTaskType"] as? String, "QUIZ")
        XCTAssertEqual(stub.lastJSON["answer"] as? String, "red")
        XCTAssertEqual(stub.lastJSON["taskId"] as? Int, 34)
        _ = await make(stub).saveOrientAlternative(topicID: 12, taskID: 34, row: .init(type: .photo, on: false, prompt: "", answer: "x"))
        XCTAssertNil(stub.lastJSON["answer"])
        stub.replies["api/topic/author-saved-detail"] = ok(#"{"topic":{"id":12},"chapters":[{"cmsTopicNodeList":[{"id":34}]}],"nodeAlternativeConfigsLoaded":true,"nodeAlternativeConfigs":{"34":[{"type":"QUIZ","enabled":true,"promptText":"Which door?","answerConfigured":true},{"type":"PHOTO","enabled":false,"promptText":null,"answerConfigured":true}]}}"#)
        let read = await make(stub).orientAlternatives(topicID: 12, taskID: 34)
        let back = try XCTUnwrap(read)
        XCTAssertEqual(stub.lastForm, "id=12")
        XCTAssertEqual(back[.quiz]?.answerConfigured, true)
        XCTAssertEqual(back[.photo]?.answerConfigured, false)
        XCTAssertTrue(OrientAlternativeRow.confirms(back, dirty: [row]))
        XCTAssertEqual(OrientAlternativeRow.issue([.init(type: .quiz, on: true, prompt: "q")]), .quizNeedsPromptAndAnswer)
        XCTAssertEqual(OrientAlternativeRow.issue([.init(type: .scan, on: true)]), .scanNotConfigured)
        stub.replies["api/topic/author-saved-detail"] = ok(#"{"topic":{"id":12},"chapters":[],"nodeAlternativeConfigsLoaded":false}"#)
        let unloaded = await make(stub).orientAlternatives(topicID: 12, taskID: 34)
        XCTAssertNil(unloaded)
    }

    func testCircleHostReadAndConfigure() async throws {
        let stub = Stub()
        stub.replies["api/project/home"] = ok(#"{"host":{"recruit":{}},"topic":{"circleThemeCode":"FITNESS","circleReviewedAt":"2026-11-01 09:00:00"}}"#)
        let topic = await make(stub).circleHostTopic(topicID: 12)
        XCTAssertEqual(stub.lastJSON["scope"] as? String, "")
        XCTAssertEqual(topic?.themeCode, "FITNESS"); XCTAssertEqual(topic?.reviewedOn, "2026-11-01")
        stub.replies["api/project/home"] = ok(#"{"join":{},"topic":{"circleThemeCode":"FITNESS"}}"#)
        let notHost = await make(stub).circleHostTopic(topicID: 12)
        XCTAssertNil(notHost)
        XCTAssertNil(CircleThemeCatalog.validate(themeCode: "fitness", codes: ["F1", "F3", "F5"]))
        XCTAssertEqual(CircleThemeCatalog.validate(themeCode: "FITNESS", codes: ["F1", "F2"]), .count)
        XCTAssertEqual(CircleThemeCatalog.validate(themeCode: "FITNESS", codes: ["F1", "F2", "F4"]), .missing([.rest, .expression]))
        XCTAssertEqual(CircleThemeCatalog.validate(themeCode: "FITNESS", codes: ["F1", "F3", "M2"]), .foreign)
        XCTAssertEqual(CircleThemeCatalog.validate(themeCode: "NOPE", codes: ["F1"]), .unknownTheme)
        stub.replies["api/circle-theme/instance/configure"] = ok("null")
        let reply = await make(stub).configureCircleInstance(topicID: 12, candidateCodes: ["F1", "F3", "F5"])
        if case .ok = reply {} else { XCTFail("\(reply)") }
        XCTAssertEqual(stub.lastJSON["candidateCodes"] as? [String], ["F1", "F3", "F5"])
        XCTAssertEqual(stub.lastJSON["topicId"] as? Int, 12)
    }

    func testAnalyticsBatchQueueAndFlush() async throws {
        let stub = Stub()
        stub.replies["api/analytics/events/batch"] = ok(#"{"accepted":1}"#)
        let service = make(stub)
        final class Memory: AnalyticsQueueStoring {
            var queue: [AnalyticsQueuedEvent] = []
            func load(accountID: Int) -> [AnalyticsQueuedEvent]? { queue }
            func save(_ queue: [AnalyticsQueuedEvent], accountID: Int) -> Bool { self.queue = queue; return true }
        }
        let memory = Memory()
        let client = AnalyticsEventClient(accountID: 7, store: memory, isCurrent: { true }, post: { await service.postAnalyticsBatch($0) })
        XCTAssertFalse(client.track("not_allowed", pagePath: "/pages/play/index"))
        let source = FinishRouteAnalyticsSource(activityID: 5, topicID: 12, runID: nil)
        XCTAssertTrue(client.track("finish_route_recommendation_click", bizType: "activity", bizID: 9, pagePath: "/pages/play/index",
                                   properties: source.properties(mode: 1).merging(["phone": .string("13800138000")]) { $1 }, idempotencyKey: "k1"))
        XCTAssertFalse(client.track("finish_route_recommendation_click", pagePath: "/pages/play/index", idempotencyKey: "k1"))
        await client.flush()
        XCTAssertEqual(stub.last.url?.path, "/native/api/analytics/events/batch")
        let events = try XCTUnwrap(stub.lastJSON["events"] as? [[String: Any]])
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?["actorScope"] as? String, "member:7")
        XCTAssertEqual(events.first?["bizId"] as? Int, 9)
        let properties = try XCTUnwrap((events.first?["propertiesJson"] as? String).flatMap { try JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any] })
        XCTAssertNil(properties["phone"]); XCTAssertNil(properties["sourceRunId"])
        XCTAssertEqual(properties["placement"] as? String, "play_finish")
        XCTAssertTrue(memory.queue.isEmpty)
        // A short acknowledgement keeps the batch queued.
        stub.replies["api/analytics/events/batch"] = ok(#"{"accepted":0}"#)
        XCTAssertTrue(client.track("roam_start", pagePath: "/pages/roam/index"))
        await client.flush()
        XCTAssertEqual(memory.queue.count, 1)

        // Secrets/tokens are stripped from queued properties and generated idempotencyKeys use random UUIDs.
        XCTAssertTrue(client.track("content_view", pagePath: "/pages/topic/index", properties: [
            "secret": .string("s3cr3t"),
            "password": .string("hunter2"),
            "authorization": .string("Bearer abc"),
            "misc": .string("Bearer secret-value"),
            "safeFlag": .string("ok")
        ]))
        let queued = try XCTUnwrap(memory.queue.last)
        XCTAssertFalse(queued.propertiesJson.contains("s3cr3t"))
        XCTAssertFalse(queued.propertiesJson.contains("hunter2"))
        XCTAssertFalse(queued.propertiesJson.contains("Bearer"))
        XCTAssertTrue(queued.propertiesJson.contains("safeFlag"))
        XCTAssertEqual(queued.idempotencyKey.count, "content_view_".count + 32)
    }
}
