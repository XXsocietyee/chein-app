import XCTest
@testable import QuestifyCore

/// WP-02: one stub reply per new request. Method, path, query and body match the hengyin controller signatures
/// (ApiAuditController, ApiClubLeadController, ApiClubCompensationController at 067da9748) and the mini-program call.
@MainActor final class PlayCreatorTailRoutesTests: XCTestCase {
    private final class Stub: HTTPTransport, @unchecked Sendable {
        var requests: [URLRequest] = []
        var replies: [String: [(String, Int)]] = [:]
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            let path = request.url!.path
            guard let key = replies.keys.sorted(by: { $0.count > $1.count }).first(where: { path.hasSuffix($0) }),
                  var queue = replies[key], !queue.isEmpty else { throw URLError(.notConnectedToInternet) }
            let reply = queue.count > 1 ? queue.removeFirst() : queue[0]
            replies[key] = queue
            return (Data(reply.0.utf8), reply.1)
        }
        func json(_ request: URLRequest) -> [String: Any] { (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: Any] ?? [:] }
        func query(_ request: URLRequest) -> [String: String] {
            Dictionary(uniqueKeysWithValues: (URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        }
        func sent(_ suffix: String) -> [URLRequest] { requests.filter { $0.url!.path.hasSuffix(suffix) } }
    }
    private let base = URL(string: "https://example.test/native")!
    private func make(_ stub: Stub) -> PlayerGapService { PlayerGapService(baseURL: base, accountID: 9001, token: { "synthetic-token" }, transport: stub) }
    private func ok(_ data: String) -> (String, Int) { (#"{"code":200,"msg":"操作成功","data":\#(data)}"#, 200) }
    private func store() -> PlayCreatorTailDefaultsStore {
        let name = "wp02-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return PlayCreatorTailDefaultsStore(defaults: defaults)
    }

    func testCreatorTailPathsAreGrantedAndTheDeadReceiptIsGone() {
        for path in PlayerGapService.creatorTailPaths {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path), path)
        }
        XCTAssertNil(ChinaReviewedRouteCapability.mark(for: "/api/template/report-receipt"))
        XCTAssertFalse(TemplateContentReportTarget.readPaths.contains("api/template/report-receipt"))
    }

    // MARK: ApiAuditController /timeline, /appeal, /appeal/receipt

    func testAuditTimelineIsAGetWithBizTypeAndBizId() async throws {
        let stub = Stub()
        stub.replies["api/audit/timeline"] = [ok(#"{"bizType":"TOPIC","bizId":992001,"rounds":[{"kind":"SUBMIT","timeline":[{"id":5,"action":"REJECT","reasonLabels":["违规"," "],"reasonText":"图片不清晰","createTime":"2026-11-13 10:00:00"},{"action":"BOGUS"}],"problems":[{"id":2,"itemType":"NODE","itemId":34,"reasonText":"坐标缺失"}]}],"appeal":null,"canAppeal":true}"#)]
        let target = try XCTUnwrap(CreatorAuditTarget.project(id: 992001, bizType: "topic", state: "rejected"))
        guard case .ok(let data, _) = await make(stub).auditTimeline(target) else { return XCTFail() }
        let request = try XCTUnwrap(stub.requests.last)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(stub.query(request), ["bizType": "TOPIC", "bizId": "992001"])
        let timeline = CreatorAuditTimeline(data)
        XCTAssertTrue(timeline.canAppeal); XCTAssertNil(timeline.appealState)
        XCTAssertEqual(timeline.rows.map(\.id), ["0-5", "0-problem-2"])
        XCTAssertEqual(timeline.rows[0].detail, "违规 · 图片不清晰 · 2026-11-13 10:00:00")
        XCTAssertEqual(timeline.rows[1].problemItemType, "NODE"); XCTAssertEqual(timeline.rows[1].problemItemID, "34")
        // projectTarget: only rejected or offline topic/activity cards.
        XCTAssertNil(CreatorAuditTarget.project(id: 1, bizType: "topic", state: "running"))
        XCTAssertEqual(CreatorAuditTarget.project(id: 3, bizType: "activity", state: "offline")?.bizType, "ACTIVITY")
    }

    func testContentAppealFreezesTheCommandThenConfirmsByItsReceipt() async throws {
        let stub = Stub()
        stub.replies["api/audit/timeline"] = [ok(#"{"rounds":[],"appeal":null,"canAppeal":true}"#),
                                              ok(#"{"rounds":[],"appeal":{"state":"SUBMITTED"},"canAppeal":false}"#)]
        stub.replies["api/audit/appeal"] = [(#"{"code":200,"msg":"操作成功","appealId":"77","taskId":"88","state":"SUBMITTED"}"#, 200)]
        let target = try XCTUnwrap(CreatorAuditTarget(bizType: "TOPIC", bizID: "992001"))
        let flow = try XCTUnwrap(CreatorAuditAppealFlow(service: make(stub), store: store(), target: target))
        await flow.loadTimeline()
        XCTAssertTrue(flow.offersAppeal)
        // The receipt must echo the frozen intent; fill it in once the request id is known.
        stub.replies["api/audit/appeal/receipt"] = [ok("null")]
        await flow.submit(reason: "  图片是原创  ")
        let post = try XCTUnwrap(stub.sent("api/audit/appeal").last)
        XCTAssertEqual(post.httpMethod, "POST")
        XCTAssertEqual(post.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = stub.json(post)
        let requestID = try XCTUnwrap(body["requestId"] as? String)
        XCTAssertTrue(requestID.hasPrefix("appeal-") && requestID.count <= 64)
        XCTAssertEqual(body["bizType"] as? String, "TOPIC"); XCTAssertEqual(body["bizId"] as? String, "992001")
        XCTAssertEqual(body["reason"] as? String, "图片是原创"); XCTAssertEqual((body["attachments"] as? [Any])?.count, 0)
        XCTAssertNil(body["evidence"])
        let receipt = try XCTUnwrap(stub.sent("api/audit/appeal/receipt").last)
        XCTAssertEqual(receipt.httpMethod, "GET")
        XCTAssertEqual(stub.query(receipt), ["bizType": "TOPIC", "bizId": "992001", "requestId": requestID])
        // A null receipt is "not confirmed": the command stays pending with the same id.
        XCTAssertTrue(flow.draft.pending); XCTAssertEqual(flow.note, .unconfirmed); XCTAssertFalse(flow.offersAppeal)
        stub.replies["api/audit/appeal/receipt"] = [ok(#"{"state":"FOUND","appealId":"77","taskId":"88","appealState":"SUBMITTED","intent":{"version":1,"requestId":"\#(requestID)","bizType":"TOPIC","bizId":"992001","memberId":"9001","reason":"图片是原创","evidence":null,"attachments":[]}}"#)]
        await flow.recover()
        XCTAssertEqual(stub.query(try XCTUnwrap(stub.sent("api/audit/appeal/receipt").last))["requestId"], requestID)
        XCTAssertEqual(flow.note, .confirmed(appealID: "77")); XCTAssertTrue(flow.draft.confirmed); XCTAssertFalse(flow.draft.pending)
        XCTAssertEqual(flow.appealState, "SUBMITTED"); XCTAssertFalse(flow.offersAppeal)
        XCTAssertEqual(stub.sent("api/audit/appeal").count, 1)
    }

    func testContentAppealReceiptForAnotherOwnerDoesNotConfirm() throws {
        let target = try XCTUnwrap(CreatorAuditTarget(bizType: "ACTIVITY", bizID: "5"))
        let command = CreatorAuditAppealCommand(requestID: "appeal-1", target: target, reason: "r")
        let found = PlayWireValue.object(["state": .string("FOUND"), "appealId": .string("1"), "taskId": .string("2"), "appealState": .string("REVIEWING"),
            "intent": .object(["version": .integer(1), "requestId": .string("appeal-1"), "bizType": .string("ACTIVITY"), "bizId": .string("5"),
                               "memberId": .string("9001"), "reason": .string("r"), "evidence": .null, "attachments": .array([])])])
        XCTAssertEqual(command.confirmedAppealID(in: found, owner: 9001)?.appealID, "1")
        XCTAssertNil(command.confirmedAppealID(in: found, owner: 9002))
        XCTAssertNil(command.confirmedAppealID(in: .object(["state": .string("NOT_FOUND")]), owner: 9001))
    }

    // MARK: ApiAuditController /guard/reference, /guard/appeal, /guard/appeal/receipt

    func testGuardAppealRoundTripReadsEligibilitySubmitsOnceAndReadsByRequestID() async throws {
        let stub = Stub()
        stub.replies["api/audit/guard/reference"] = [ok(#"{"guardOrigin":{"guardLogId":"41","routeSessionId":"77","nodeId":"34"},"originalRunActive":true,"canSubmit":true}"#)]
        stub.replies["api/audit/guard/appeal"] = [(#"{"code":200,"msg":"操作成功","appealId":"5","taskId":"6","state":"SUBMITTED"}"#, 200)]
        stub.replies["api/audit/guard/appeal/receipt"] = [ok(#"{"state":"FOUND","appealId":"5","taskId":"6","appealState":"SUBMITTED","canReverify":false,"intent":{"version":1,"requestId":"req-1","bizType":"play_arrive_guard","bizId":"41","memberId":"9001","reason":"定位跳了","evidence":null,"attachments":[],"guardReference":{"guardLogId":"41","arrivalRequestId":"act-9"}}}"#)]
        let flow = try XCTUnwrap(PlayGuardAppealFlow(service: make(stub), store: store(), session: "activityId:3", keyFactory: { "req-1" }))
        let reference = try XCTUnwrap(PlayGuardAppealReference(guardLogID: "41", routeSessionID: "77", nodeID: 34, arrivalRequestID: "act-9"))
        flow.reference(reference)
        await flow.read()
        let read = try XCTUnwrap(stub.sent("api/audit/guard/reference").last)
        XCTAssertEqual(read.httpMethod, "GET")
        XCTAssertEqual(stub.query(read), ["guardLogId": "41", "arrivalRequestId": "act-9"])
        XCTAssertTrue(flow.canSubmit)
        await flow.submit(reason: "定位跳了")
        let post = try XCTUnwrap(stub.sent("api/audit/guard/appeal").last)
        XCTAssertEqual(post.httpMethod, "POST")
        let body = stub.json(post)
        XCTAssertEqual(body["guardLogId"] as? String, "41"); XCTAssertEqual(body["arrivalRequestId"] as? String, "act-9")
        XCTAssertEqual(body["requestId"] as? String, "req-1"); XCTAssertEqual(body["reason"] as? String, "定位跳了")
        XCTAssertTrue(body["evidence"] is NSNull); XCTAssertEqual((body["attachments"] as? [Any])?.count, 0)
        let receipt = try XCTUnwrap(stub.sent("api/audit/guard/appeal/receipt").last)
        XCTAssertEqual(stub.query(receipt), ["guardLogId": "41", "requestId": "req-1"])
        XCTAssertEqual(flow.entry?.state, .found); XCTAssertEqual(flow.entry?.result?.appealState, "SUBMITTED")
        XCTAssertFalse(flow.canSubmit)
        // A later refusal does not replace a settled, submitted appeal for a different run silently: FOUND may be replaced.
        XCTAssertEqual(stub.sent("api/audit/guard/appeal").count, 1)
    }

    func testGuardAppealTransportFailureKeepsTheCommandAndNeverResubmits() async throws {
        let stub = Stub()
        stub.replies["api/audit/guard/reference"] = [ok(#"{"guardOrigin":{"guardLogId":41,"routeSessionId":77},"canSubmit":true,"originalRunActive":true}"#)]
        let defaults = store()
        let flow = try XCTUnwrap(PlayGuardAppealFlow(service: make(stub), store: defaults, session: "activityId:3", keyFactory: { "req-2" }))
        flow.reference(try XCTUnwrap(PlayGuardAppealReference(guardLogID: "41", routeSessionID: "77", nodeID: 34, arrivalRequestID: "act-9")))
        await flow.read()
        await flow.submit(reason: "x") // appeal and receipt both have no stub: transport failure
        XCTAssertEqual(flow.entry?.state, .unknown); XCTAssertEqual(flow.entry?.command?.requestID, "req-2")
        // A new refusal cannot discard the unresolved intent, and a restored flow keeps it.
        flow.reference(try XCTUnwrap(PlayGuardAppealReference(guardLogID: "42", routeSessionID: "77", nodeID: 35, arrivalRequestID: "act-10")))
        XCTAssertEqual(flow.entry?.reference.guardLogID, "41")
        let restored = try XCTUnwrap(PlayGuardAppealFlow(service: make(stub), store: defaults, session: "activityId:3"))
        XCTAssertEqual(restored.entry?.command?.requestID, "req-2"); XCTAssertFalse(restored.canSubmit)
        XCTAssertEqual(stub.sent("api/audit/guard/appeal").count, 1)
    }

    func testArrivalRefusalCarriesTheGuardReference() throws {
        let envelope = try JSONDecoder().decode(PlayWireValue.self, from: Data(#"{"code":409,"msg":"移动过快","errorCode":"ARRIVE_GUARD_SPEED","appealable":true,"appealBizType":"play_arrive_guard","guardLogId":"41","routeSessionId":77}"#.utf8))
        let refusal = try XCTUnwrap(PlayCommandRefusal(envelope: envelope))
        XCTAssertEqual(refusal.guardLogID, "41"); XCTAssertEqual(refusal.routeSessionID, "77"); XCTAssertEqual(refusal.appealBizType, "play_arrive_guard")
        let failure = PlayArrivalFailure(nodeID: 34, refusal: refusal, snapshot: nil, arrivalRequestID: "act-9")
        XCTAssertEqual(failure.guardReference, PlayGuardAppealReference(guardLogID: "41", routeSessionID: "77", nodeID: 34, arrivalRequestID: "act-9"))
        XCTAssertNil(PlayArrivalFailure(nodeID: 34, refusal: refusal, snapshot: nil).guardReference)
    }

    // MARK: ApiClubCompensationController /editions/empty-reason

    func testEditionEmptyReasonPostsClubIdAndReadsOnlyThisClubsCode() async {
        let stub = Stub()
        stub.replies["api/club-compensation/editions/empty-reason"] = [ok(#"{"clubId":7001,"reasonCode":"NO_PERMISSION"}"#)]
        let reason = await make(stub).editionEmptyReason(clubID: 7001)
        XCTAssertEqual(reason, .noPermission)
        let request = stub.requests.last!
        XCTAssertEqual(request.httpMethod, "POST"); XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(String(data: request.httpBody!, encoding: .utf8), #"{"clubId":7001}"#)
        stub.replies["api/club-compensation/editions/empty-reason"] = [ok(#"{"clubId":7002,"reasonCode":"NO_PERMISSION"}"#)]
        let other = await make(stub).editionEmptyReason(clubID: 7001)
        XCTAssertNil(other)
        stub.replies["api/club-compensation/editions/empty-reason"] = [ok(#"{"clubId":"7001","reasonCode":"SOMETHING_NEW"}"#)]
        let unknown = await make(stub).editionEmptyReason(clubID: 7001)
        XCTAssertNil(unknown)
        XCTAssertTrue(ClubEditionEmptyReason.hasEditions.offersRetry); XCTAssertFalse(ClubEditionEmptyReason.notUndertaken.offersRetry)
    }
}

/// WP-02 leader tools on `PlayExperienceService` (`.leader` capability): the chapter command and its receipt, the station release.
final class PlayLeadTailServiceTests: XCTestCase {
    private final class Recorder: HTTPTransport, @unchecked Sendable {
        var requests: [URLRequest] = []
        var reply = #"{"code":200,"msg":"ok","data":null}"#
        func send(_ request: URLRequest) async throws -> (Data, Int) { requests.append(request); return (Data(reply.utf8), 200) }
    }
    private func service(_ recorder: Recorder) throws -> PlayExperienceService {
        PlayExperienceService(configuration: try APIConfiguration(baseURL: URL(string: "https://example.test/native/")!), transport: recorder, enabled: [.leader])
    }
    private func form(_ request: URLRequest) -> String { String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "" }

    func testUnlockChapterSendsTheFrozenCommandAndReadsItsReceipt() async throws {
        let recorder = Recorder()
        let command = try XCTUnwrap(PlayLeadUnlockCommand(commandID: "cmd-1", activityID: 992031, expectedChapterID: nil, targetChapterID: 51))
        recorder.reply = #"{"code":200,"msg":"已开启:第一章","data":{"commandId":"cmd-1","expectedChapterId":0,"targetChapterId":51}}"#
        let data = try await service(recorder).unlockChapter(command, token: "synthetic-token")
        XCTAssertTrue(command.confirms(data))
        let post = try XCTUnwrap(recorder.requests.last)
        XCTAssertEqual(post.httpMethod, "POST"); XCTAssertEqual(post.url?.path, "/native/api/club/lead/unlock-chapter")
        for field in ["activityId", "commandId", "expectedChapterId", "targetChapterId"] { XCTAssertTrue(form(post).contains("name=\"\(field)\""), field) }
        XCTAssertTrue(form(post).contains("cmd-1")); XCTAssertTrue(form(post).contains("992031"))
        _ = try await service(recorder).unlockChapterReceipt(command, token: "synthetic-token")
        let get = try XCTUnwrap(recorder.requests.last)
        XCTAssertEqual(get.httpMethod, "GET"); XCTAssertEqual(get.url?.path, "/native/api/club/lead/unlock-chapter-receipt")
        XCTAssertEqual(get.url?.query, "activityId=992031&commandId=cmd-1")
        // 409 with intentNotExecuted keeps that proof; a 520 receipt stays pending (a rejection the coordinator treats as unknown).
        recorder.reply = #"{"code":409,"msg":"期望章节已过期，请核对后重新确认","intentNotExecuted":true}"#
        do { _ = try await service(recorder).unlockChapter(command, token: "synthetic-token"); XCTFail() }
        catch let refusal as PlayCommandRefusal { XCTAssertTrue(refusal.intentNotExecuted) }
        recorder.reply = #"{"code":520,"msg":"章节命令结果待确认"}"#
        do { _ = try await service(recorder).unlockChapterReceipt(command, token: "synthetic-token"); XCTFail() }
        catch { XCTAssertEqual(error as? PlayExperienceError, .rejected(520, "章节命令结果待确认")) }
        // The bare legacy form is refused before the network.
        let before = recorder.requests.count
        do { try await service(recorder).lead(activityID: 992031, action: .unlockChapter, text: nil, token: "synthetic-token"); XCTFail() } catch {}
        XCTAssertEqual(recorder.requests.count, before)
    }

    func testReleaseStationPostsActivityMemberAndNode() async throws {
        let recorder = Recorder()
        recorder.reply = #"{"code":200,"msg":"已放行，成员可以跳过这一站"}"#
        try await service(recorder).releaseStation(activityID: 992031, memberID: 9004, nodeID: 34, token: "synthetic-token")
        let post = try XCTUnwrap(recorder.requests.last)
        XCTAssertEqual(post.httpMethod, "POST"); XCTAssertEqual(post.url?.path, "/native/api/club/lead/release-station")
        for (name, value) in [("activityId", "992031"), ("memberId", "9004"), ("nodeId", "34")] {
            XCTAssertTrue(form(post).contains("name=\"\(name)\"\r\n\r\n\(value)\r\n"), name)
        }
        // Without the leader capability nothing is sent.
        let closed = PlayExperienceService(configuration: try APIConfiguration(baseURL: URL(string: "https://example.test/native/")!), transport: recorder, enabled: [.reads])
        let before = recorder.requests.count
        do { try await closed.releaseStation(activityID: 992031, memberID: 9004, nodeID: 34, token: "synthetic-token"); XCTFail() }
        catch { XCTAssertEqual(error as? PlayExperienceError, .disabled) }
        XCTAssertEqual(recorder.requests.count, before)
    }

    func testTeamProgressCarriesChaptersAndSkipRequests() throws {
        let raw = try JSONDecoder().decode(PlayWireValue.self, from: Data(#"{"exists":true,"isLeader":true,"leaderMemberId":9003,"status":2,"currentChapterId":50,"nextChapterId":51,"members":[],"skipRequests":[{"memberId":9004,"nickname":"阿青","nodeId":34},{"memberId":0,"nodeId":1}]}"#.utf8))
        let progress = try PlayLeadProgress(raw)
        XCTAssertEqual(progress.currentChapterID, 50); XCTAssertEqual(progress.nextChapterID, 51)
        XCTAssertEqual(progress.skipRequests, [.init(memberID: 9004, nodeID: 34, nickname: "阿青")])
        XCTAssertNil(PlayLeadUnlockCommand(activityID: 3, expectedChapterID: 50, targetChapterID: nil))
    }
}
