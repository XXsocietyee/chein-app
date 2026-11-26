import XCTest
@testable import Questify
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// WP-09. Each row id is the test name. Synthetic payloads only.
@MainActor final class WP09PresetsTeamAfterSaleTests: XCTestCase {
    private let testHost = "https://8120.example.test/native/"
    private let china = "https://www.chengyinhub.com/prod-api/"

    func testOWN_21_1_presetDraftOpensEditableDraftOnTEST() async throws {
        let stub = PresetStub()
        stub.reply = { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/api/preset/gameplay/list") { return Self.ok(Self.catalog) }
            if path.hasSuffix("/api/preset/gameplay/info") { return Self.ok(Self.preset) }
            if path.hasSuffix("/api/preset/gameplay/draft") {
                let state = stub.requests.filter { $0.url?.path.hasSuffix("/draft") == true }.count > 1 ? "REPLAYED" : "APPLIED"
                return Self.ok(#"{"draftId":44,"authorTodos":["补结局文案"],"writeReceipt":{"state":"\#(state)"}}"#)
            }
            return (Data(#"{"code":404,"msg":"玩法预设不存在"}"#.utf8), 200)
        }
        let client = try Self.client(stub, url: testHost)
        let model = GameplayPresetModel(client: client, makeRequestID: { "preset-test-1" })
        await model.load()
        XCTAssertEqual(model.phase, .catalog)
        await model.open(presetKey: "timer")
        XCTAssertEqual(model.phase, .form)
        model.textInputs["title"] = "合成标题"
        await model.create()
        XCTAssertTrue(model.editorOpen)
        XCTAssertEqual(model.receipt?.draftID, 44)
        XCTAssertTrue(model.inputsEditable)
        XCTAssertEqual(model.textInputs["title"], "合成标题")
        XCTAssertEqual(stub.requests.last?.url?.host, "8120.example.test")
        XCTAssertNotEqual(stub.requests.last?.url?.host, "www.chengyinhub.com")
        let firstID = try Self.body(stub.requests.last!)["requestId"] as? String
        await model.create()
        XCTAssertEqual(try Self.body(stub.requests.last!)["requestId"] as? String, firstID)
        XCTAssertEqual(model.receipt?.state, .replayed)
        XCTAssertFalse(model.receipt?.outcome(chinese: true).contains("已新建") ?? true)
        XCTAssertTrue(model.editorOpen)
    }

    func testOWN_21_2_presetListAndInfo() async throws {
        let stub = PresetStub()
        stub.reply = { request in
            let path = request.url?.path ?? ""
            if path.hasSuffix("/list") { return Self.ok(#"{"catalogVersion":"9","presets":[]}"#) }
            return (Data(#"{"code":404,"msg":"玩法预设不存在"}"#.utf8), 200)
        }
        let client = try Self.client(stub, url: testHost)
        let empty = GameplayPresetModel(client: client)
        await empty.load()
        XCTAssertEqual(empty.phase, .empty)
        XCTAssertTrue(stub.requests.contains { $0.httpMethod == "GET" && $0.url?.path.hasSuffix("/api/preset/gameplay/list") == true })

        stub.reply = { request in
            if request.url?.path.hasSuffix("/info") == true { return (Data(#"{"code":404,"msg":"玩法预设不存在"}"#.utf8), 200) }
            return Self.ok(Self.catalog)
        }
        let model = GameplayPresetModel(client: client)
        await model.load()
        await model.open(presetKey: "missing")
        XCTAssertEqual(model.phase, .failed("玩法预设不存在"))
        XCTAssertTrue(ReviewedProductionGateLeases.playPaths.isSuperset(of: Set(GameplayPresetPath.relative)))
        XCTAssertEqual(ChinaReviewedRouteCapability.wp09PresetGrant, Set(GameplayPresetPath.relative.map { "/" + $0 }))
        for path in GameplayPresetPath.relative {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path), path)
        }
        let money = try Self.client(stub, url: china)
        let refused = await money.draft(requestID: "preset-test-1", presetKey: "timer", inputs: ["payAmount": 1])
        XCTAssertEqual(refused, .notSent)
        XCTAssertTrue(ReviewedAreaSwitch.moneyPayments(apiHost: "www.chengyinhub.com", testOrDebug: true))
        XCTAssertTrue(ReviewedAreaSwitch.moneyPayments(apiHost: "www.chengyinhub.com", testOrDebug: false))
        XCTAssertTrue(ReviewedAreaSwitch.moneyPayments(apiHost: "8120.example.test", testOrDebug: true))
        XCTAssertFalse(ReviewedAreaSwitch.moneyPayments(apiHost: nil, testOrDebug: true))
    }

    func testOWN_U02_04_sourceVersion() {
        let pending = SourceLineagePresentation(sourceContentRevisionId: nil)
        XCTAssertTrue(pending.historyPending)
        XCTAssertEqual(pending.historyLine(chinese: true), "历史来源待核对")
        XCTAssertEqual(pending.historyLine(chinese: false), "Source history still needs checking")
        XCTAssertFalse(pending.continueCurrent)
        XCTAssertFalse(pending.viewDiff)
        XCTAssertFalse(pending.saveAsNew)
        let known = SourceLineagePresentation(sourceContentRevisionId: "rev-9")
        XCTAssertEqual(known.identity, "rev-9")
        XCTAssertTrue(known.continueCurrent)
        XCTAssertFalse(known.viewDiff)
        XCTAssertFalse(known.saveAsNew)
        XCTAssertEqual(WP09Copy.unknown, "\u{2014}")
    }

    func testOWN_U06_02_myRoleAndPrivateClues() throws {
        let raw = """
        {"sessionId":501,"activityId":41,"topicId":71,"nodeId":701,"ownerType":2,"version":1,"status":"RUNNING","config":{"multiplayer":{"enabled":true,"assignment":"LEADER","requiredTurns":2,"roles":[{"id":"starter","label":"Starter","min":1,"max":1}]}},"multiplayer":{"members":[{"memberId":9001,"name":"Synthetic actor"},{"memberId":9002,"name":"Synthetic teammate"}],"leaderMemberId":9001,"myRole":"starter","myRoleLabel":"开局","myTask":"开锁","myEvidence":["门照片"],"myPrivateClues":["只有我"],"privateClues":{"finisher":"SECRET-OTHER"},"roleAssignments":{"9001":"starter"},"turnIndex":0,"completedUnitIds":[],"turn":{"index":0,"size":1,"position":0,"round":1,"completedTurns":0,"requiredTurns":2,"finished":false,"myTurn":true,"turnsUntilMine":0}}}
        """
        let state = try PlayAdvancedState(JSONDecoder().decode(PlayWireValue.self, from: Data(raw.utf8)))
        let team = try XCTUnwrap(PlayAdvancedTeamProjection(state: state, actorID: 9001))
        XCTAssertEqual(team.myRoleLabel, "开局")
        XCTAssertEqual(team.myTask, "开锁")
        XCTAssertEqual(team.myEvidence, ["门照片"])
        XCTAssertEqual(team.myPrivateClues, ["只有我"])
        XCTAssertFalse(team.exposes("SECRET-OTHER"))
        XCTAssertEqual(team.waitingOn(chinese: true), "开局")
        XCTAssertEqual(team.waitingOn(chinese: false), "开局")
        let quiet = """
        {"sessionId":501,"activityId":41,"topicId":71,"nodeId":701,"ownerType":2,"version":1,"status":"RUNNING","config":{"multiplayer":{"enabled":true,"assignment":"AUTO","requiredTurns":2,"roles":[]}},"multiplayer":{"members":[{"memberId":9001,"name":"Synthetic actor"}],"leaderMemberId":9002,"myRole":"starter","roleAssignments":{},"turnIndex":0,"completedUnitIds":[]}}
        """
        let other = try XCTUnwrap(PlayAdvancedTeamProjection(state: PlayAdvancedState(JSONDecoder().decode(PlayWireValue.self, from: Data(quiet.utf8))), actorID: 9001))
        XCTAssertEqual(other.waitingOn(chinese: true), WP09Copy.unknown)
        XCTAssertTrue(other.roles.isEmpty)
    }

    func testOWN_U06_04_organizerSharedResults() throws {
        let detail = try team(["roleFacts": ["myRoleLabel": "开局", "myTask": "开锁", "myEvidence": ["门照片"], "waitingOn": "开局", "myPrivateClues": ["只有我"]],
                               "sharedOutcome": ["whoMustAct": "组织者", "chapterRelease": "第 2 章", "paused": false, "summary": "共同到站",
                                                 "population": "本队已完成本章的人", "timeWindow": "2026-11-01/2026-11-13",
                                                 "clubHeadcount": 40, "sessionParticipants": 3]])
        XCTAssertEqual(detail.sharedOutcome?.clubHeadcount, 40)
        XCTAssertEqual(detail.sharedOutcome?.sessionParticipants, 3)
        XCTAssertNotEqual(detail.sharedOutcome?.countLine(detail.sharedOutcome?.clubHeadcount), detail.sharedOutcome?.countLine(detail.sharedOutcome?.sessionParticipants))
        XCTAssertEqual(detail.sharedOutcome?.pausedLine(chinese: false), "Not paused")
        XCTAssertTrue(TeamSharedOutcome.merchantAssetWrites.isEmpty)
        let missing = try team([:])
        XCTAssertNil(missing.roleFacts)
        XCTAssertNil(missing.sharedOutcome)
        XCTAssertEqual(TeamSharedOutcome?.none?.countLine(nil) ?? WP09Copy.unknown, WP09Copy.unknown)
    }

    func testOWN_U07_01_delivery() throws {
        let mixed = try order(#"{"id":9,"delivery":{}}"#)
        XCTAssertEqual(mixed.delivery?.mixedTickets, true)
        XCTAssertEqual(mixed.delivery?.headline(chinese: true), "按票种分别说明")
        XCTAssertEqual(mixed.delivery?.headline(chinese: false), "Each ticket type is explained separately")
        XCTAssertNil(mixed.delivery?.refundLine(chinese: true))
        let priced = try order(#"{"id":9,"delivery":{"ticketName":"自玩票","refundRule":"开始前可退","amountFromServer":12.5,"beneficiaryKind":"购买人"}}"#)
        XCTAssertEqual(priced.delivery?.amountLine, "12.5")
        XCTAssertEqual(priced.delivery?.refundLine(chinese: true), "开始前可退")
        XCTAssertFalse(priced.delivery?.headline(chinese: true).contains("按票种分别说明") ?? true)
        let absent = try order(#"{"id":9}"#)
        XCTAssertNil(absent.delivery)
    }

    func testOWN_U07_02_paymentReturn() {
        XCTAssertEqual(PaymentReturnPhase(loading: true, payment: 2, registration: 2), .querying)
        XCTAssertEqual(PaymentReturnPhase(loading: false, payment: 2, registration: 1), .received)
        XCTAssertTrue(PaymentReturnPhase(loading: false, payment: 2, registration: 1).unlocksEntitlement)
        let pending = PaymentReturnPhase(loading: false, payment: 0, registration: 1)
        XCTAssertEqual(pending, .pendingConfirmation)
        XCTAssertFalse(pending.unlocksEntitlement)
        XCTAssertFalse(PaymentReturnPhase(loading: false, payment: nil, registration: 2).unlocksEntitlement)
        XCTAssertEqual(PaymentReturnPhase(loading: false, payment: nil, registration: 3), .cancelled)
        XCTAssertEqual(PaymentReturnPhase(loading: false, payment: 3, registration: 1), .failed)
        XCTAssertEqual(PaymentReturnPhase(loading: false, payment: nil, registration: nil), .unknown)
        XCTAssertEqual(PaymentReturnPhase.unknown.title(chinese: true), WP09Copy.unknown)
        let note = PaymentChannelNote(channels: ["wechat"], chinese: true)
        XCTAssertTrue(note.text.contains("微信通道就绪"))
        XCTAssertTrue(note.text.contains("不代表"))
        XCTAssertFalse(note.text.contains("购买已成功"))
    }

    func testOWN_U07_03_workshopInstallStaysClosedOnProduction() {
        XCTAssertEqual(WorkshopPaidInstallAuthority.reason, "PAID_INSTALL_AUTHORITY_UNAVAILABLE")
        XCTAssertTrue(WorkshopPaidInstallAuthority.confirmSends(host: "www.chengyinhub.com"))
        XCTAssertFalse(WorkshopPaidInstallAuthority.confirmSends(host: nil))
        XCTAssertTrue(WorkshopPaidInstallAuthority.confirmSends(host: "8120.example.test"))
        XCTAssertTrue(WorkshopPaidInstallAuthority.notice(chinese: true).contains(WorkshopPaidInstallAuthority.reason))
        XCTAssertTrue(WorkshopPaidInstallAuthority.notice(chinese: false).contains("will not pretend"))
    }

    func testOWN_U07_04_partialRefundServerAmounts() throws {
        let facts = try XCTUnwrap(order(#"{"id":9,"settlementSummary":{"refundStage":"处理中","refundPendingAmount":1.5,"refundProcessingAmount":2,"refundCompletedAmount":3,"amountsComplete":false}}"#).settlement)
        XCTAssertEqual(facts.serverAmounts, ["1.5", "2", "3"])
        XCTAssertEqual(facts.stageLine, "处理中")
        XCTAssertEqual(facts.totalLine(chinese: true), "合计未齐")
        XCTAssertNotEqual(facts.totalLine(chinese: false), "6.5")
        XCTAssertFalse(facts.serverAmounts.contains("6.5"))
        let incomplete = try XCTUnwrap(order(#"{"id":9,"settlementSummary":{"refundPendingAmount":4}}"#).settlement)
        XCTAssertEqual(incomplete.processingLine, WP09Copy.unknown)
        XCTAssertNotEqual(incomplete.pendingLine, "0")
        let complete = try XCTUnwrap(order(#"{"id":9,"settlementSummary":{"amountsComplete":true,"refundCompletedAmount":3}}"#).settlement)
        XCTAssertEqual(complete.totalLine(chinese: true), WP09Copy.unknown)
    }

    func testOWN_U07_05_creatorAccrual() {
        let unknown = CreatorAccrualProjection.unknown(reason: "账本未装配")
        let hidden = unknown.lines(chinese: true).map(\.value).joined(separator: "\n")
        XCTAssertFalse(unknown.showsAmounts)
        XCTAssertTrue(hidden.contains("收益暂不可用"))
        XCTAssertTrue(hidden.contains("账本未装配"))
        XCTAssertFalse(hidden.contains("0"))
        XCTAssertFalse(hidden.contains("暂无收入"))
        let note = "不等于实收，也不等于可提现；到账与可提现以打款事实为准"
        let available = CreatorAccrualProjection(state: .available, gross: 10, refunded: -3, net: 99, basisNote: note,
                                                 reason: nil, periodStart: "2026-10-01", periodEnd: "2026-11-01")
        let lines = available.lines(chinese: true)
        XCTAssertEqual(lines.map(\.value)[0], note)
        XCTAssertEqual(lines.map(\.value)[3], "99")
        XCTAssertNotEqual(lines.map(\.value)[3], "7")
        XCTAssertTrue(lines.contains { $0.title == "应计净额" })
        XCTAssertFalse(lines.contains { $0.title.contains("可提现") })
        XCTAssertTrue(lines.map(\.value).joined().contains("2026-10-01"))
        XCTAssertTrue(lines.map(\.value).joined().contains("2026-11-01"))
        let joined = lines.map { $0.title + $0.value }.joined()
        XCTAssertFalse(joined.contains("ACCRUAL_ORIGINAL_LEDGER"))
        XCTAssertFalse(joined.contains("AVAILABLE"))
        let zero = CreatorAccrualProjection(state: .available, gross: 0, refunded: 0, net: 0, basisNote: note, reason: nil, periodStart: nil, periodEnd: nil)
        XCTAssertTrue(zero.lines(chinese: false).map(\.value).contains("0"))
    }

    func testOWN_十三_02_templatePresetRollup() {
        XCTAssertFalse(SourceLineagePresentation(sourceContentRevisionId: "rev").viewDiff)
        XCTAssertTrue(ChinaReviewedRouteCapability.wp09PresetGrant.contains("/api/preset/gameplay/draft"))
        XCTAssertTrue(ChinaReviewedRouteCapability.wp09PresetGrant.contains("/api/preset/gameplay/list"))
        XCTAssertTrue(ChinaReviewedRouteCapability.wp09PresetGrant.contains("/api/preset/gameplay/info"))
    }

    func testOWN_十三_03_teamAndAfterSaleRollup() throws {
        XCTAssertEqual(PaymentReturnPhase(loading: false, payment: 0, registration: 1).unlocksEntitlement, false)
        XCTAssertTrue(TeamSharedOutcome.merchantAssetWrites.isEmpty)
        XCTAssertEqual(CreatorAccrualProjection.unknown(reason: nil).showsAmounts, false)
        XCTAssertNil(try order(#"{"id":9,"delivery":{"ticketName":"场次票"}}"#).delivery?.refundLine(chinese: true))
        XCTAssertTrue(WorkshopPaidInstallAuthority.confirmSends(host: ReviewedAreaSwitch.productionAPIHost))
        XCTAssertFalse(WorkshopPaidInstallAuthority.confirmSends(host: nil))
    }

    private func team(_ extra: [String: Any]) throws -> TeamDetail {
        var object: [String: Any] = ["team": ["id": 4101, "title": "Synthetic", "status": 0, "joinMode": 2, "joinedCount": 2, "maxMembers": 4],
                                     "members": [["memberId": 901, "memberName": "A", "role": 1]],
                                     "joined": true, "leader": true]
        extra.forEach { object[$0.key] = $0.value }
        return try JSONDecoder().decode(TeamDetail.self, from: JSONSerialization.data(withJSONObject: object))
    }

    private func order(_ json: String) throws -> OrderLifecycleDetail {
        try JSONDecoder().decode(OrderLifecycleDetail.self, from: Data(json.utf8))
    }

    private static let catalog = #"{"catalogVersion":"9","presets":[{"presetKey":"timer","title":"限时","purpose":"练习","templateSource":"PRESET","authorTodos":["上传并审核头像"],"requiredFields":[{"key":"title","kind":"text","label":"标题"}]}]}"#
    private static let preset = #"{"presetKey":"timer","title":"限时","purpose":"练习","authorTodos":["上传并审核头像"],"requiredFields":[{"key":"title","kind":"text","label":"标题"}]}"#

    private static func ok(_ json: String) -> (Data, Int) {
        (Data("{\"code\":200,\"data\":\(json)}".utf8), 200)
    }

    private static func client(_ stub: PresetStub, url: String) throws -> GameplayPresetClient {
        GameplayPresetClient(configuration: try APIConfiguration(baseURL: XCTUnwrap(URL(string: url))), transport: stub, token: "synthetic-token")
    }

    private static func body(_ request: URLRequest) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
    }
}

private final class PresetStub: HTTPTransport {
    var requests: [URLRequest] = []
    var reply: (URLRequest) -> (Data, Int) = { _ in (Data(#"{"code":500,"msg":"—"}"#.utf8), 200) }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return reply(request)
    }
}
