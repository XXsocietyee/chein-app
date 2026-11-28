import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// One stub transport per G1 play-runtime route. Replies are queued; `fail` simulates a lost response.
private final class PlayRuntimeStubHTTP: HTTPTransport {
    var requests: [URLRequest] = []
    var replies: [(String, Int)] = []
    var fail = false
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        if fail { throw URLError(.networkConnectionLost) }
        guard !replies.isEmpty else { throw URLError(.badServerResponse) }
        let reply = replies.removeFirst(); return (Data(reply.0.utf8), reply.1)
    }
    var lastPath: String? { requests.last?.url?.path }
    var lastQuery: [String: String] {
        guard let url = requests.last?.url, let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return [:] }
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }
    var lastForm: [String: String] {
        let body = String(decoding: requests.last?.httpBody ?? Data(), as: UTF8.self)
        return Dictionary(uniqueKeysWithValues: body.split(separator: "&").map {
            let pair = $0.split(separator: "=", maxSplits: 1).map(String.init)
            return (pair[0], (pair.count > 1 ? pair[1] : "").removingPercentEncoding ?? "")
        })
    }
    var lastJSON: [String: Any] {
        (try? JSONSerialization.jsonObject(with: requests.last?.httpBody ?? Data()) as? [String: Any]) ?? [:]
    }
}

@MainActor final class PlayRuntimeGapTests: XCTestCase {
    private let base = URL(string: "https://fixture.example")!
    private func client(_ http: PlayRuntimeStubHTTP) throws -> PlayRuntimeClient {
        try PlayRuntimeClient(configuration: APIConfiguration(baseURL: base), transport: http, token: "fixture-token")
    }
    private func problem() throws -> JourneyCheckProblem {
        let raw = try JSONDecoder().decode(PlayWireValue.self, from: Data(#"{"allowedActions":["check"],"check":{"checkId":"c_1","skill":"Observe","tier":"hard"}}"#.utf8))
        return try XCTUnwrap(JourneyCheckProblem(encounter: raw))
    }
    private func original() throws -> PlayCheckOriginal {
        try XCTUnwrap(PlayCheckOriginal(owner: 7, sessionID: 41, nodeID: 34, checkID: "c_1", topicID: 12, activityID: nil))
    }
    private func receipt(_ action: String, settled: Bool = false, session: Int = 41) -> String {
        #"{"code":200,"data":{"sessionId":\#(session),"nodeId":34,"checkId":"c_1","actionId":"check:34:c_1:\#(action)","settled":\#(settled),"rerolled":false,"dice":[14],"kept":14,"total":16,"dc":15,"success":true,"luck":1,"text":"Server text"}}"#
    }

    // MARK: check

    func testCheckRollIsAFormWriteAndTheServerReceiptIsShown() async throws {
        let http = PlayRuntimeStubHTTP(); http.replies = [(receipt("roll"), 200)]
        let store = PlayCheckMemoryPendingStore(), client = try client(http)
        let runtime = PlayCheckRuntime(original: try original(), problem: try problem(), store: store, client: { client })
        XCTAssertTrue(runtime.canRoll)
        await runtime.perform(.roll)
        XCTAssertEqual(http.lastPath, "/api/play/check/roll")
        XCTAssertEqual(http.requests.last?.httpMethod, "POST")
        XCTAssertEqual(http.requests.last?.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
        XCTAssertEqual(http.lastForm, ["topicId": "12", "activityId": "0", "sessionId": "41", "nodeId": "34", "checkId": "c_1"])
        XCTAssertEqual(runtime.receipt?.total, 16)
        XCTAssertEqual(runtime.receipt?.text, "", "settle text never shows before settlement")
        XCTAssertFalse(runtime.unknown)
        XCTAssertTrue(store.values.isEmpty)
        XCTAssertTrue(runtime.canReroll)
        XCTAssertEqual(PlayCheckRuntime.marginText(runtime.receipt), "过线 1 点")
    }

    func testRerollAndSettleCarryTheirOwnActionIDs() async throws {
        let http = PlayRuntimeStubHTTP(); http.replies = [(receipt("roll"), 200), (receipt("reroll"), 200), (receipt("settle", settled: true), 200)]
        let client = try client(http)
        let runtime = PlayCheckRuntime(original: try original(), problem: try problem(), store: PlayCheckMemoryPendingStore(), client: { client })
        await runtime.perform(.roll); await runtime.perform(.reroll); await runtime.perform(.settle)
        XCTAssertEqual(http.requests.map(\.url?.path), ["/api/play/check/roll", "/api/play/check/reroll", "/api/play/check/settle"])
        XCTAssertEqual(runtime.receipt?.settled, true)
        XCTAssertEqual(runtime.receipt?.text, "Server text")
    }

    func testLostResponseIsUnknownAndOnlyTheReceiptReadClearsIt() async throws {
        let http = PlayRuntimeStubHTTP(); http.fail = true
        let store = PlayCheckMemoryPendingStore(), client = try client(http)
        let runtime = PlayCheckRuntime(original: try original(), problem: try problem(), store: store, client: { client })
        await runtime.perform(.roll)
        XCTAssertTrue(runtime.unknown); XCTAssertNil(runtime.receipt)
        XCTAssertEqual(store.values.values.first?.actionID, "check:34:c_1:roll")
        // A new roll is refused while the original is pending: no second POST.
        await runtime.perform(.roll)
        XCTAssertEqual(http.requests.count, 1)
        // A fresh runtime (relaunch) restores the unknown state from storage.
        let relaunched = PlayCheckRuntime(original: try original(), problem: try problem(), store: store, client: { client })
        XCTAssertTrue(relaunched.unknown); XCTAssertFalse(relaunched.canRoll)
        http.fail = false; http.replies = [(receipt("roll"), 200)]
        await relaunched.perform(.recover)
        XCTAssertEqual(http.requests.last?.httpMethod, "GET")
        XCTAssertEqual(http.lastPath, "/api/play/check/receipt")
        XCTAssertEqual(http.lastQuery, ["sessionId": "41", "nodeId": "34", "checkId": "c_1", "action": "roll"])
        XCTAssertFalse(relaunched.unknown); XCTAssertEqual(relaunched.receipt?.kept, 14)
        XCTAssertTrue(store.values.isEmpty)
    }

    func testMismatchedReceiptStaysUnknown() async throws {
        let http = PlayRuntimeStubHTTP(); http.replies = [(receipt("roll", session: 42), 200)]
        let store = PlayCheckMemoryPendingStore(), client = try client(http)
        let runtime = PlayCheckRuntime(original: try original(), problem: try problem(), store: store, client: { client })
        await runtime.perform(.roll)
        XCTAssertTrue(runtime.unknown); XCTAssertNil(runtime.receipt); XCTAssertFalse(store.values.isEmpty)
    }

    func testExplicitRejectionClearsThePendingWrite() async throws {
        let http = PlayRuntimeStubHTTP()
        http.replies = [(#"{"code":409,"msg":"这次检定已结算过了","errorCode":"CHECK_REJECTED"}"#, 200)]
        let store = PlayCheckMemoryPendingStore(), client = try client(http)
        let runtime = PlayCheckRuntime(original: try original(), problem: try problem(), store: store, client: { client })
        await runtime.perform(.roll)
        XCTAssertFalse(runtime.unknown); XCTAssertEqual(runtime.disabledReason, "这次检定已结算过了")
        XCTAssertTrue(store.values.isEmpty)
        // Any other failure code is not a rejection.
        http.replies = [(#"{"code":500,"msg":"busy"}"#, 200)]
        await runtime.perform(.roll)
        XCTAssertTrue(runtime.unknown); XCTAssertFalse(store.values.isEmpty)
        XCTAssertEqual(runtime.disabledReason, "busy")
    }

    func testUnreadableStoreNeverSends() async throws {
        let http = PlayRuntimeStubHTTP(); let store = PlayCheckMemoryPendingStore(); store.failing = true
        let client = try client(http)
        let runtime = PlayCheckRuntime(original: try original(), problem: try problem(), store: store, client: { client })
        await runtime.perform(.roll)
        XCTAssertTrue(runtime.unknown); XCTAssertTrue(http.requests.isEmpty)
    }

    func testOriginalRequiresRouteSessionAndSafeCheckID() {
        XCTAssertNil(PlayCheckOriginal(owner: 7, sessionID: nil, nodeID: 34, checkID: "c_1", topicID: 12, activityID: nil))
        XCTAssertNil(PlayCheckOriginal(owner: 7, sessionID: 41, nodeID: 34, checkID: "c&1", topicID: 12, activityID: nil))
        XCTAssertEqual(PlayCheckOriginal(owner: 7, sessionID: 41, nodeID: 34, checkID: "c_1", topicID: 12, activityID: 5)?.storageKey,
                       "journey-original:7:41:34:c_1")
    }

    // MARK: advanced receipt

    func testAdvancedReceiptProvesOnlyTheSameSessionAndKey() async throws {
        let http = PlayRuntimeStubHTTP()
        http.replies = [(#"{"code":200,"data":{"sessionId":9,"idempotencyKey":"k-1","view":{"version":3}}}"#, 200),
                        (#"{"code":200,"data":{"sessionId":9,"idempotencyKey":"k-2","view":{"version":3}}}"#, 200)]
        let client = try client(http)
        let view = try await PlayAdvancedReceipt.read(client: client, sessionID: 9, idempotencyKey: "k-1")
        XCTAssertEqual(view["version"].integer, 3)
        XCTAssertEqual(http.lastPath, "/api/play/advanced/receipt")
        XCTAssertEqual(http.lastQuery, ["sessionId": "9", "idempotencyKey": "k-1"])
        do { _ = try await PlayAdvancedReceipt.read(client: client, sessionID: 9, idempotencyKey: "k-1"); XCTFail() }
        catch { XCTAssertEqual(error as? PlayRuntimeError, .unknown) }
    }

    // MARK: shared help

    func testSharedHelpBodyRowsAndOutcomes() async throws {
        let cooperation = try JSONDecoder().decode(PlayWireValue.self, from: Data(#"{"gameSessionId":3,"authorityEpoch":2,"questions":[{"questKey":"q1","runtimeInstance":"r-9","nodeId":34}]}"#.utf8))
        XCTAssertTrue(PlayCoopHelp.canHelp(cooperation, questKey: "q1"))
        XCTAssertNil(PlayCoopHelp.body(activityID: 5, cooperation: cooperation, questKey: "q1", operation: .use, level: nil, requestID: "coop-1"))
        let body = try XCTUnwrap(PlayCoopHelp.body(activityID: 5, cooperation: cooperation, questKey: "q1", operation: .use, level: 2, requestID: "coop-1"))
        let http = PlayRuntimeStubHTTP()
        http.replies = [(#"{"code":200,"data":{"content":"Look up","chargedPoints":5,"levels":[{"level":1,"type":"TEXT","unlocked":true},{"level":2,"type":"ANSWER","usable":true,"costPoints":5},{"level":3,"type":"SKIP","usable":false,"reason":"REAL_OPERATION_REQUIRED"}]}}"#, 200),
                        (#"{"code":500,"msg":"积分不足"}"#, 200)]
        let client = try client(http)
        guard case .ok(let data) = await PlayCoopHelp.send(client: client, body: body) else { return XCTFail() }
        XCTAssertEqual(http.lastPath, "/api/play/help/shared")
        XCTAssertEqual(http.requests.last?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(http.lastJSON["operation"] as? String, "USE")
        XCTAssertEqual(http.lastJSON["requestId"] as? String, "coop-1")
        XCTAssertEqual(http.lastJSON["capabilities"] as? String, "game.teamCooperation@1")
        let rows = PlayCoopHelp.rows(data["levels"])
        XCTAssertEqual(rows.rows.map(\.actionText), ["重看", "消耗 5 积分"])
        XCTAssertEqual(rows.skip, PlayCoopHelp.Skip(level: 3, usable: false, reason: "需要现场完成，不能跳过"))
        let rejected = await PlayCoopHelp.send(client: client, body: body)
        XCTAssertEqual(rejected, .rejected("积分不足"))
        http.replies = [(#"{"code":503,"msg":"线路忙"}"#, 503)]
        let noted = await PlayCoopHelp.send(client: client, body: body)
        XCTAssertEqual(noted, .notedUnknown("线路忙"))
        http.fail = true
        let unknown = await PlayCoopHelp.send(client: client, body: body)
        XCTAssertEqual(unknown, .unknown)
    }

    // MARK: history

    func testHistoryReadIsScopedAndAllOrNothing() async throws {
        let scope = try XCTUnwrap(PlayHistoryScope(owner: 7, activityID: nil, topicID: 12, routeSessionID: 41))
        let good = #"{"code":200,"data":{"readOnly":true,"routeSessionId":41,"activityId":0,"topicId":12,"configVersion":3,"narrativeAvailable":true,"nodes":[{"nodeId":34,"done":true,"history":true,"results":[],"storyText":"Found it"}],"chapters":[{"chapterId":2,"complete":true,"blocks":[{"type":"node","nodeId":34},{"type":"text","who":"Guide","content":"Onward"}]}]}}"#
        let bad = #"{"code":200,"data":{"readOnly":true,"routeSessionId":41,"activityId":0,"topicId":12,"configVersion":3,"nodes":[{"nodeId":34,"done":false,"history":true,"results":[]}],"chapters":[]}}"#
        let http = PlayRuntimeStubHTTP(); http.replies = [(good, 200), (bad, 200)]
        let client = try client(http)
        let history = await PlayHistoryProjection.read(client: client, scope: scope, configVersion: nil)
        XCTAssertEqual(http.lastPath, "/api/play/history")
        XCTAssertEqual(http.lastQuery, ["activityId": "0", "topicId": "12", "routeSessionId": "41"])
        XCTAssertEqual(history?.chapters.first?.lines, ["Found it", "Guide：Onward"])
        let broken = await PlayHistoryProjection.read(client: client, scope: scope, configVersion: nil)
        XCTAssertNil(broken)
    }

    // MARK: setup

    func testSetupRowFollowsTheServerWindowAndPrepItems() async throws {
        let http = PlayRuntimeStubHTTP()
        http.replies = [(#"{"code":200,"data":{"prepItems":[" Water ","","Torch"],"playWindow":{"mode":"night"},"openNow":false}}"#, 200),
                        (#"{"code":200,"data":{"prepItems":[],"playWindow":{"mode":"any"}}}"#, 200),
                        (#"{"code":500,"msg":"x"}"#, 200)]
        let client = try client(http)
        guard case .loaded(let setup) = await PlayTopicSetup.read(client: client, topicID: 12) else { return XCTFail() }
        XCTAssertEqual(http.lastPath, "/api/play/setup"); XCTAssertEqual(http.lastQuery, ["topicId": "12"])
        XCTAssertEqual(setup.items.map(\.text), ["Water", "Torch"])
        XCTAssertEqual(setup.rowText(ticked: []), "开局前准备 · 夜间 20:00–06:00 开放")
        XCTAssertFalse(setup.ready(ticked: [0, 1]))
        let hidden = await PlayTopicSetup.read(client: client, topicID: 12)
        XCTAssertEqual(hidden, .hidden)
        let failed = await PlayTopicSetup.read(client: client, topicID: 12)
        XCTAssertEqual(failed, .failed)
    }

    // MARK: contact

    func testContactUsesActivityOrTopicAndNodeAndNeedsADialablePhone() async throws {
        let http = PlayRuntimeStubHTTP()
        http.replies = [(#"{"code":200,"data":{"kind":"merchant","name":"Tea House","phone":"021-5555 0101"}}"#, 200),
                        (#"{"code":200,"data":{"kind":"HOST","phone":"call me"}}"#, 200)]
        let client = try client(http)
        let contact = await PlayContact.read(client: client, scope: .activity(5), currentNodeID: 34)
        XCTAssertEqual(http.lastQuery, ["activityId": "5"])
        XCTAssertEqual(contact?.label, "联系商家"); XCTAssertEqual(contact?.phone, "021-5555 0101")
        let none = await PlayContact.read(client: client, scope: .topic(12), currentNodeID: 34)
        XCTAssertEqual(http.lastPath, "/api/play/contact")
        XCTAssertEqual(http.lastQuery, ["topicId": "12", "nodeId": "34"])
        XCTAssertNil(none)
    }

    // MARK: theme gameplay

    func testGameplayActionPreviewAndSharedPreview() async throws {
        let view = try JSONDecoder().decode(PlayWireValue.self, from: Data(#"{"sessionId":41,"version":6}"#.utf8))
        let command = try XCTUnwrap(PlayThemeGameplayExchange.command(view: view, operation: "QUEST_START", contentID: "q1",
            actionID: "theme_1", selections: ["costOption": .integer(1), "price": .integer(9)]))
        XCTAssertNil(command["price"], "only the mini-program selections travel")
        let http = PlayRuntimeStubHTTP()
        http.replies = [(#"{"code":200,"data":{"sessionId":41,"version":7}}"#, 200),
                        (#"{"code":200,"data":{"sessionId":41}}"#, 200),
                        (#"{"code":409,"msg":"版本已变化"}"#, 200),
                        (#"{"code":200,"data":{"sessionId":41,"version":6,"previewVersion":"pv-1","overflow":false,"grants":{"key":1}}}"#, 200),
                        (#"{"code":200,"data":{"previewOnly":true,"expectedRevision":4,"authorityEpoch":2,"result":{"preview":true}}}"#, 200)]
        let client = try client(http)
        let applied = await PlayThemeGameplayExchange.action(client: client, command: command)
        XCTAssertEqual(http.lastPath, "/api/play/theme/gameplay-action")
        XCTAssertEqual(http.lastJSON["actionId"] as? String, "theme_1"); XCTAssertEqual(http.lastJSON["expectedVersion"] as? Int, 6)
        guard case .applied(let receipt) = applied else { return XCTFail() }
        XCTAssertEqual(receipt["version"].integer, 7)
        let unproven = await PlayThemeGameplayExchange.action(client: client, command: command)
        XCTAssertEqual(unproven, .unknown)
        let rejected = await PlayThemeGameplayExchange.action(client: client, command: command)
        XCTAssertEqual(rejected, .rejected("版本已变化"))
        let preview = await PlayThemeGameplayExchange.preview(client: client, view: view, operation: "QUEST_RESOLVE", contentID: "q1")
        XCTAssertEqual(http.lastPath, "/api/play/theme/gameplay-preview")
        XCTAssertEqual(preview.pack?.previewVersion, "pv-1")
        let shared = await PlayThemeGameplayExchange.sharedPreview(client: client, activityID: 5, action: "TRADE_OPEN", payload: ["tradeKey": .string("t1")])
        XCTAssertEqual(http.lastPath, "/api/game/session/shared/preview")
        XCTAssertEqual(http.lastJSON["action"] as? String, "TRADE_OPEN")
        XCTAssertEqual(shared.data?["expectedRevision"].integer, 4)
        XCTAssertNil(PlayThemeGameplayExchange.command(view: .object(["scope": .string("TEAM"), "sessionId": .integer(1), "version": .integer(1)]),
            operation: "QUEST_START", contentID: "q1", actionID: "a"), "TEAM commands are not the personal gameplay route")
        http.replies = [(#"{"code":503,"msg":"动作没写上"}"#, 503), (#"{"code":200,"data":{"sessionId":41}}"#, 200)]
        let noted = await PlayThemeGameplayExchange.action(client: client, command: command)
        XCTAssertEqual(noted, .notedUnknown("动作没写上"))
        let stillUnknown = await PlayThemeGameplayExchange.action(client: client, command: command)
        XCTAssertEqual(stillUnknown, .unknown)
    }

    // MARK: run session

    func testRunSessionClearIsTheEndTombstone() async throws {
        let http = PlayRuntimeStubHTTP(); http.replies = [(#"{"code":200,"data":null}"#, 200)]
        let ok = await PlayRunSessionClear.clear(client: try client(http), scope: .activity(5), savedAt: 1_700_000_000_000)
        XCTAssertTrue(ok)
        XCTAssertEqual(http.lastPath, "/api/play/run-session/clear")
        XCTAssertEqual(http.lastForm, ["savedAt": "1700000000000", "activityId": "5"])
    }

    func testUnauthorizedIsNotUnknown() async throws {
        let http = PlayRuntimeStubHTTP(); http.replies = [(#"{"code":401,"msg":"请先登录"}"#, 200)]
        do { _ = try await client(http).get("api/play/history", query: [:]); XCTFail() }
        catch { XCTAssertEqual(error as? PlayRuntimeError, .unauthorized) }
    }

    // MARK: China gate

    func testChinaGateAdmitsThePlayRuntimeAndKeepsMoneyClosed() {
        for path in ["/api/play/check/roll", "/api/play/check/reroll", "/api/play/check/settle", "/api/play/check/receipt",
                     "/api/play/advanced/receipt", "/api/play/help/use", "/api/play/help/skip", "/api/play/help/shared",
                     "/api/play/history", "/api/play/run-session/clear", "/api/play/setup", "/api/play/theme/gameplay-action",
                     "/api/play/theme/gameplay-preview", "/api/play/theme/replay", "/api/game/session/shared/preview",
                     "/api/play/contact", "/api/play/encounter", "/api/circle-theme/session/answer", "/api/circle-theme/session/record",
                     "/api/circle-theme/instance/12/offers", "/api/circle-theme/session/9/card"] {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall(path), path)
        }
        for path in ["/api/registration/pay", "/api/pay/create", "/api/withdrawal/create", "/api/wallet/withdraw", "/api/asset/withdraw",
                     "/api/club/settlement/withdraw"] {
            XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall(path), path)
        }
    }
}
