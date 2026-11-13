import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// g-partials: one stub transport per new request (TEAM backpack read, shared help, trade preview,
/// advanced receipt) plus the walked trail the team sync uploads.
@MainActor final class PlayGapPartialsTests: XCTestCase {
    private final class Stub: HTTPTransport, @unchecked Sendable {
        var requests: [URLRequest] = []
        var replies: [String: [(String, Int)]] = [:]
        var fail = false
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            if fail { throw URLError(.networkConnectionLost) }
            let path = request.url!.path
            guard let key = replies.keys.first(where: { path.hasSuffix($0) }), var queue = replies[key], !queue.isEmpty else {
                throw URLError(.notConnectedToInternet)
            }
            let reply = queue.count > 1 ? queue.removeFirst() : queue[0]
            replies[key] = queue
            return (Data(reply.0.utf8), reply.1)
        }
        var last: URLRequest { requests.last! }
        var lastJSON: [String: Any] { (try? JSONSerialization.jsonObject(with: last.httpBody ?? Data())) as? [String: Any] ?? [:] }
        var lastQuery: [String: String] {
            let items = URLComponents(url: last.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        }
    }
    private let base = URL(string: "https://fixture.example")!
    private func client(_ stub: Stub) throws -> PlayRuntimeClient {
        try PlayRuntimeClient(configuration: APIConfiguration(baseURL: base), transport: stub, token: "fixture-token")
    }
    private func ok(_ data: String) -> (String, Int) { (#"{"code":200,"msg":"ok","data":\#(data)}"#, 200) }

    // MARK: walked trail (play-trail.js)

    func testWalkedTrailDropsCoarseFixesAndJitter() {
        var trail = TeamWalkedTrail()
        XCTAssertTrue(trail.note(latitude: 31.2, longitude: 121.4, accuracy: 10))
        XCTAssertFalse(trail.note(latitude: 31.21, longitude: 121.4, accuracy: 61), "accuracy > 60 m is not drawn")
        XCTAssertFalse(trail.note(latitude: 31.20003, longitude: 121.4, accuracy: 5), "a 3 m step is jitter")
        XCTAssertTrue(trail.note(latitude: 31.2001, longitude: 121.4, accuracy: nil))
        XCTAssertFalse(trail.note(latitude: .nan, longitude: 121.4, accuracy: 5))
        XCTAssertEqual(trail.points.count, 2)
    }

    func testWalkedTrailSimplifiesPastFourThousandPoints() {
        var trail = TeamWalkedTrail()
        for i in 0...TeamWalkedTrail.maxPoints { trail.note(latitude: 31 + Double(i) * 0.0001, longitude: 121 + (i % 2 == 0 ? 0 : 0.0002), accuracy: 5) }
        XCTAssertLessThanOrEqual(trail.points.count, 1000)
        XCTAssertEqual(trail.points.first?.latitude, 31)
    }

    func testTeamSyncUploadsWalkedPointsOnlyOnce() async {
        let stub = Stub()
        let service = PlayerGapService(baseURL: base, accountID: 7, token: { "fixture-token" }, transport: stub)
        let model = TeamTrailModel(service: service, activityID: 9)
        stub.replies["api/team/trail/consent"] = [ok(#"{"available":true,"share":true}"#)]
        _ = await model.consent(true)
        var trail = TeamWalkedTrail()
        trail.note(latitude: 31.2, longitude: 121.4, accuracy: 5)
        trail.note(latitude: 31.201, longitude: 121.4, accuracy: 5)
        stub.replies["api/team/trail/sync"] = [ok(#"{"available":true,"share":true,"teams":[]}"#)]
        _ = await model.tick(points: trail.points, done: 1)
        XCTAssertEqual(stub.last.url?.path, "/api/team/trail/sync")
        XCTAssertEqual(stub.last.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(stub.lastJSON["activityId"] as? String, "9")
        XCTAssertEqual(stub.lastJSON["pts"] as? [[Double]], [[31.2, 121.4], [31.201, 121.4]])
        trail.note(latitude: 31.202, longitude: 121.4, accuracy: 5)
        _ = await model.tick(points: trail.points, done: 1)
        XCTAssertEqual(stub.lastJSON["pts"] as? [[Double]], [[31.202, 121.4]])
    }

    // MARK: TEAM backpack read

    private let teamProjection = #"{"activityId":5,"sessionId":61,"revision":7,"status":"RUNNING","availableActions":["TRADE_OPEN"],"perspective":"PLAYER","player":{"playMode":"ROUTE","scope":"TEAM","teamId":3,"authorityEpoch":2,"hp":8,"hpMax":10,"used":1,"capacity":6,"contents":[{"kind":"ITEM","id":"rope","name":"Rope","quantity":1}],"cooperation":{"gameSessionId":61,"authorityEpoch":2,"questions":[{"questKey":"q1","nodeId":34,"runtimeInstance":"r1"}]},"quests":[],"world":{"itemCatalog":[{"id":"rope","name":"Rope"}],"tradeTargets":[{"teamId":4,"disabled":false}]}}}"#

    func testTeamBackpackReadsThePlayerProjectionAndMergesTeamScope() async throws {
        let stub = Stub(); stub.replies["api/game/session/view"] = [ok(teamProjection)]
        let read = await PlayTeamBackpackRead.read(client: try client(stub), activityID: 5)
        XCTAssertEqual(stub.last.httpMethod, "GET")
        XCTAssertEqual(stub.last.url?.path, "/api/game/session/view")
        XCTAssertEqual(stub.lastQuery, ["activityId": "5", "perspective": "PLAYER"])
        guard case .loaded(let snapshot) = read else { return XCTFail("expected a TEAM backpack") }
        XCTAssertEqual(snapshot.view["scope"].text, "TEAM")
        XCTAssertEqual(snapshot.view["sessionId"].integer, 61)
        XCTAssertEqual(snapshot.view["hpEnabled"].bool, true)
        XCTAssertTrue(snapshot.backpack.isTeam)
        XCTAssertEqual(snapshot.backpack.items.map(\.id), ["rope"])
        XCTAssertEqual(snapshot.teamID, 3); XCTAssertEqual(snapshot.revision, 7); XCTAssertEqual(snapshot.authorityEpoch, 2)
        XCTAssertEqual(snapshot.trade.tradeTargets.map(\.teamId), [4])
        XCTAssertTrue(snapshot.trade.tradeTargets[0].enabled)
    }

    func testPersonalRunAbsentSessionAndForeignActivityAreNotATeamBackpack() async throws {
        let stub = Stub()
        stub.replies["api/game/session/view"] = [ok(teamProjection.replacingOccurrences(of: #""scope":"TEAM""#, with: #""scope":"PLAYER""#))]
        let personal = await PlayTeamBackpackRead.read(client: try client(stub), activityID: 5)
        XCTAssertEqual(personal, .hidden)
        stub.replies["api/game/session/view"] = [(#"{"code":404,"msg":"none","errorCode":"GAME_SESSION_NOT_FOUND"}"#, 200)]
        let absent = await PlayTeamBackpackRead.read(client: try client(stub), activityID: 5)
        XCTAssertEqual(absent, .hidden)
        stub.replies["api/game/session/view"] = [ok(teamProjection)]
        let foreign = await PlayTeamBackpackRead.read(client: try client(stub), activityID: 6)
        XCTAssertEqual(foreign, .failed(nil), "another activity's projection is never shown")
        stub.fail = true
        let lost = await PlayTeamBackpackRead.read(client: try client(stub), activityID: 5)
        XCTAssertEqual(lost, .failed(nil))
    }

    // MARK: shared help sheet

    func testCoopHelpViewUseAndRetryKeepsTheRequestID() async throws {
        let stub = Stub(), client = try client(stub)
        let cooperation = try PlayExperienceSyntheticFixtures.wire(#"{"gameSessionId":61,"authorityEpoch":2,"questions":[{"questKey":"q1","nodeId":34,"runtimeInstance":"r1"}]}"#)
        let flow = PlayCoopHelpFlow(activityID: 5, cooperation: cooperation, questKey: "q1", client: { client })
        stub.replies["api/play/help/shared"] = [ok(#"{"levels":[{"level":1,"type":"TEXT","usable":true,"free":true},{"level":2,"type":"ANSWER","usable":true,"costPoints":5},{"level":3,"type":"SKIP","usable":true}],"remainingFreeUses":2}"#)]
        await flow.open()
        XCTAssertEqual(stub.last.url?.path, "/api/play/help/shared")
        XCTAssertEqual(stub.lastJSON["operation"] as? String, "VIEW")
        XCTAssertNil(stub.lastJSON["requestId"])
        XCTAssertEqual(stub.lastJSON["capabilities"] as? String, "game.teamCooperation@1")
        XCTAssertEqual(flow.rows.map(\.state), [.free, .cost])
        XCTAssertEqual(flow.skip?.usable, true)
        XCTAssertFalse(flow.freeText.isEmpty)

        stub.fail = true
        await flow.use(level: 2)
        XCTAssertEqual(flow.issue, .writeUnknown)
        let first = try XCTUnwrap(stub.lastJSON["requestId"] as? String)
        XCTAssertEqual(stub.lastJSON["level"] as? Int, 2)
        stub.fail = false
        stub.replies["api/play/help/shared"] = [ok(#"{"content":"Look up","chargedPoints":5}"#)]
        await flow.use(level: 2)
        XCTAssertEqual(stub.lastJSON["requestId"] as? String, first, "an unconfirmed USE is only retried with its own id")
        XCTAssertEqual(flow.content, "Look up"); XCTAssertEqual(flow.chargedPoints, 5)
        XCTAssertEqual(flow.rows.first { $0.level == 2 }?.state, .unlocked)
        XCTAssertNil(flow.unknown)

        flow.askSkip(); XCTAssertTrue(flow.skipConfirm)
        stub.replies["api/play/help/shared"] = [ok(#"{}"#)]
        await flow.confirmSkip()
        XCTAssertEqual(stub.lastJSON["operation"] as? String, "SKIP")
        XCTAssertNotEqual(stub.lastJSON["requestId"] as? String, first)
        XCTAssertTrue(flow.finished)
    }

    func testCoopHelpRejectionShowsTheServerTextAndAStaleQuestSendsNothing() async throws {
        let stub = Stub(), client = try client(stub)
        let cooperation = try PlayExperienceSyntheticFixtures.wire(#"{"gameSessionId":61,"authorityEpoch":2,"questions":[{"questKey":"q1","nodeId":34,"runtimeInstance":"r1"}]}"#)
        let stale = PlayCoopHelpFlow(activityID: 5, cooperation: cooperation, questKey: "missing", client: { client })
        await stale.open()
        XCTAssertEqual(stale.issue, .stale); XCTAssertTrue(stub.requests.isEmpty)
        let flow = PlayCoopHelpFlow(activityID: 5, cooperation: cooperation, questKey: "q1", client: { client })
        stub.replies["api/play/help/shared"] = [(#"{"code":409,"msg":"Already solved"}"#, 200)]
        await flow.open()
        XCTAssertEqual(flow.issue, .rejected("Already solved"))
    }

    // MARK: trade preview

    func testTradePreviewIsAPreviewOnlyCallMatchedToThePayload() async throws {
        let stub = Stub(), client = try client(stub)
        stub.replies["api/game/session/view"] = [ok(teamProjection)]
        guard case .loaded(let snapshot) = await PlayTeamBackpackRead.read(client: client, activityID: 5) else { return XCTFail() }
        var form = try XCTUnwrap(PlayTeamTradePreview.form(target: snapshot.trade.tradeTargets[0], snapshot: snapshot))
        XCTAssertEqual(form.items.map(\.id), ["rope"])
        form.items[0].give = "1"
        let payload = try PlayThemeTradeRules.payload(form)
        let result = #"{"previewOnly":true,"expectedRevision":7,"authorityEpoch":2,"result":{"preview":true,"tradeKey":"\#(form.tradeKey)","toTeamId":4,"fromTeamId":3,"give":[{"itemId":"rope","quantity":1}],"take":[],"fromUsed":0,"toUsed":2,"capacity":6}}"#
        stub.replies["api/game/session/shared/preview"] = [ok(result)]
        let read = await PlayTeamTradePreview.read(client: client, snapshot: snapshot, payload: payload)
        XCTAssertEqual(stub.last.url?.path, "/api/game/session/shared/preview")
        XCTAssertEqual(stub.lastJSON["action"] as? String, "TRADE_OPEN")
        XCTAssertEqual(stub.lastJSON["activityId"] as? Int, 5)
        XCTAssertEqual((stub.lastJSON["payload"] as? [String: Any])?["toTeamId"] as? Int, 4)
        guard case .ready(let preview) = read else { return XCTFail("expected a ready preview") }
        XCTAssertEqual(preview.fromUsed, 0); XCTAssertEqual(preview.toUsed, 2); XCTAssertEqual(preview.capacity, 6)

        stub.replies["api/game/session/shared/preview"] = [ok(result.replacingOccurrences(of: #""expectedRevision":7"#, with: #""expectedRevision":8"#))]
        let ahead = await PlayTeamTradePreview.read(client: client, snapshot: snapshot, payload: payload)
        XCTAssertEqual(ahead, .stale)
        stub.replies["api/game/session/shared/preview"] = [ok(result.replacingOccurrences(of: #""toTeamId":4"#, with: #""toTeamId":9"#))]
        let foreign = await PlayTeamTradePreview.read(client: client, snapshot: snapshot, payload: payload)
        XCTAssertEqual(foreign, .unconfirmed(nil))
    }

    // MARK: advanced receipt

    @available(macOS 14.0, *)
    private func unknownAdvanced() async throws -> (PlayAdvancedCoordinator, PlayRecoveryRecordingTransport, PlayAdvancedPending) {
        let session = try PlayExperienceSession(accountID: 7, epoch: 1, namespace: "synthetic-gp", token: "synthetic-token")
        let wire = PlayRecoveryRecordingTransport()
        wire.responses["/api/play/advanced/start"] = .reply(PlayExperienceSyntheticFixtures.envelope(PlayExperienceSyntheticFixtures.advanced), 200)
        wire.responses["/api/play/advanced/action"] = .failure(.unknownResult)
        let player = PlayAdvancedCoordinator(activityID: 41, topicID: 71, nodeID: 701,
            service: .init(configuration: try .init(baseURL: URL(string: "https://example.test")!), transport: wire, enabled: [.reads, .advanced]),
            currentSession: { session })
        await player.start()
        await player.submit(kind: "coinFlip", action: "FLIP_COIN")
        XCTAssertEqual(player.phase, "unknown")
        return (player, wire, try XCTUnwrap(player.pending))
    }
    private var advancedV3: String { PlayExperienceSyntheticFixtures.advanced.replacingOccurrences(of: "\"version\":2", with: "\"version\":3") }

    @available(macOS 14.0, *)
    func testAdvancedUnknownIsSettledByItsOwnReceipt() async throws {
        let (player, wire, pending) = try await unknownAdvanced()
        wire.responses["/api/play/advanced/receipt"] = .reply(PlayExperienceSyntheticFixtures.envelope(
            #"{"sessionId":601,"idempotencyKey":"\#(pending.key)","view":\#(advancedV3)}"#), 200)
        await player.recover()
        XCTAssertNil(player.pending); XCTAssertEqual(player.phase, "ready"); XCTAssertEqual(player.state?.version, 3)
        let read = try XCTUnwrap(wire.requests.last)
        XCTAssertEqual(read.httpMethod, "GET"); XCTAssertEqual(read.url?.path, "/api/play/advanced/receipt")
        let query = URLComponents(url: read.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(query.first { $0.name == "sessionId" }?.value, "601")
        XCTAssertEqual(query.first { $0.name == "idempotencyKey" }?.value, pending.key)
        XCTAssertEqual(wire.requests.filter { $0.url?.path == "/api/play/advanced/action" }.count, 1, "no replay")
    }

    @available(macOS 14.0, *)
    func testAdvancedReceiptForAnotherKeyOrMissingLeavesOnlyTheExactReplay() async throws {
        for reply: PlayRecoveryRecordingTransport.Response in [
            .reply(PlayExperienceSyntheticFixtures.envelope(#"{"sessionId":601,"idempotencyKey":"other","view":\#(advancedV3)}"#), 200),
            .reply(Data(#"{"code":404,"msg":"none"}"#.utf8), 200), .failure(.unknownResult)] {
            let (player, wire, pending) = try await unknownAdvanced()
            wire.responses["/api/play/advanced/receipt"] = reply
            wire.responses["/api/play/advanced/state"] = .reply(PlayExperienceSyntheticFixtures.envelope(advancedV3), 200)
            await player.recover()
            XCTAssertEqual(player.phase, "retryable"); XCTAssertEqual(player.pending, pending)
            XCTAssertEqual(wire.requests.suffix(2).map { $0.url?.path }, ["/api/play/advanced/receipt", "/api/play/advanced/state"])
        }
    }
}
