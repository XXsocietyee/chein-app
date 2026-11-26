import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// G6: one stub transport per route. Paths, queries, bodies, and the projections the screens draw.
@MainActor final class G6CapabilitySourceTests: XCTestCase {
    private let token = "session-token"

    // MARK: NPC

    func testNPCProfileReadsGlobalAndNodeScopes() async throws {
        let wire = Wire(body: Data(#"{"code":200,"data":{"npcs":[{"profileId":31,"name":"Ada","avatar":"https://cdn.test/a.png"}]}}"#.utf8))
        let source = try make(wire)
        let global = try await source.npcGlobalProfile(token: token)
        XCTAssertEqual(G6RoamNPCCoordinator.profileID(in: global), "31")
        _ = try await source.npcNodeProfiles(nodeID: 21, token: token)
        XCTAssertEqual(wire.requests.map { $0.httpMethod }, ["GET", "GET"])
        XCTAssertEqual(wire.requests.map { $0.url?.path }, ["/api/ai/npc/profile", "/api/ai/npc/profile"])
        XCTAssertEqual(query(wire.requests[0]), ["scope": "global"])
        XCTAssertEqual(query(wire.requests[1]), ["scope": "node", "nodeId": "21"])
        XCTAssertEqual(wire.requests[0].value(forHTTPHeaderField: "Authorization"), token)
        do { _ = try await source.npcNodeProfiles(nodeID: 0, token: token); XCTFail() } catch { XCTAssertEqual(error as? G6Refusal, .invalidRequest) }
    }

    func testNPCEventAlwaysSendsCacheOnlyAndDropsAnEmptyLine() async throws {
        let wire = Wire(bodies: [Data(#"{"code":200,"data":{"line":"Welcome back"}}"#.utf8), Data(#"{"code":200,"data":{"line":""}}"#.utf8)])
        let source = try make(wire)
        let first = try await source.npcEventLine(profileID: "31", eventType: "roam_start", token: token)
        XCTAssertEqual(G6RoamNPCCoordinator.line(in: first), "Welcome back")
        let second = try await source.npcEventLine(profileID: "31", eventType: "roam_end", token: token)
        XCTAssertNil(G6RoamNPCCoordinator.line(in: second))
        XCTAssertEqual(wire.requests[0].url?.path, "/api/ai/npc/event")
        XCTAssertEqual(query(wire.requests[0]), ["profileId": "31", "eventType": "roam_start", "cacheOnly": "true"])
        do { _ = try await source.npcEventLine(profileID: "31", eventType: "roam_greeting", token: token); XCTFail() }
        catch { XCTAssertEqual(error as? G6Refusal, .invalidRequest) }
        XCTAssertEqual(wire.requests.count, 2)
    }

    func testNPCChatShellBuildsTheRoamTrackAndReadsBackWithoutResending() async throws {
        let id = "0f8fad5b-d9cb-469f-a165-70867728950e"
        let wire = Wire(bodies: [
            Data(#"{"code":200,"data":{"requestId":"0f8fad5b-d9cb-469f-a165-70867728950e","outcomeStatus":"PROCESSING","safeText":"Checking"}}"#.utf8),
            Data(#"{"code":200,"data":{"requestId":"0f8fad5b-d9cb-469f-a165-70867728950e","outcomeStatus":"SUCCEEDED","safetyDecision":"PASS","safeText":"Hi"}}"#.utf8)
        ])
        let source = try make(wire)
        let sent = try await source.npcChat(requestID: id, bizID: 7, message: "  hello  ", token: token)
        XCTAssertEqual(G6NPCChat.reply(sent, requestID: id).state, .checking)
        let read = try await source.npcChatRequest(requestID: id, scope: "roam", bizID: 7, token: token)
        XCTAssertEqual(G6NPCChat.reply(read, requestID: id), .init(state: .delivering, safeText: "Hi"))
        XCTAssertEqual(wire.requests.map { $0.httpMethod }, ["POST", "GET"])
        XCTAssertEqual(json(wire.requests[0].httpBody)?["message"] as? String, "hello")
        XCTAssertEqual(json(wire.requests[0].httpBody)?["bizId"] as? Int, 7)
        XCTAssertEqual(query(wire.requests[1]), ["requestId": id, "scope": "roam", "bizId": "7"])
        XCTAssertEqual(G6NPCChat.reply(read, requestID: "11111111-1111-4111-8111-111111111111").state, .failed)
        let long = String(repeating: "字", count: 301)
        do { _ = try await source.npcChat(requestID: id, bizID: 7, message: long, token: token); XCTFail() }
        catch { XCTAssertEqual(error as? G6Refusal, .invalidRequest) }
    }

    func testStoryCharactersAskFourMerchantStopsAndKeepEightUniqueNames() throws {
        let chapters = try JSONDecoder().decode([TopicChapter].self, from: Data(#"""
        [{"id":1,"title":"A","nodes":[
          {"id":11,"name":" Gate ","registrationMerchantList":[{"memberId":1}]},
          {"id":12,"name":"Plain"},
          {"id":13,"name":"Cafe","registrationMerchantList":[{"memberId":2}]}]},
         {"id":2,"title":"B","nodes":[
          {"id":21,"name":"Shop","registrationMerchantList":[{"memberId":3}]},
          {"id":22,"name":"Bar","registrationMerchantList":[{"memberId":4}]},
          {"id":23,"name":"Late","registrationMerchantList":[{"memberId":5}]}]}]
        """#.utf8))
        XCTAssertEqual(G6StoryCharacters.asks(chapters).map(\.nodeID), [11, 13, 21, 22])
        XCTAssertEqual(G6StoryCharacters.asks(chapters).first?.place, "Gate")
        let rows: [(npc: [String: Any], place: String)] = (0..<10).map { (npc: ["name": "N\($0 % 9)", "profileId": $0], place: "P") }
            + [(npc: ["name": ""], place: "P")]
        let built = G6StoryCharacters.build(rows)
        XCTAssertEqual(built.count, 8)
        XCTAssertEqual(built.first, .init(id: "c-0", name: "N0", avatar: nil, place: "P"))
    }

    // MARK: Roam NPC coordinator

    func testRoamGateQuotasAndGaps() {
        var gate = G6RoamNPCGate()
        XCTAssertNil(gate.tryAcquire("roam_start", now: 0))
        XCTAssertEqual(gate.tryAcquire("roam_start", now: 0), .inFlight)
        gate.confirmShown("roam_start", now: 0)
        XCTAssertEqual(gate.tryAcquire("roam_start", now: 100_000), .quota)
        XCTAssertEqual(gate.tryAcquire("roam_milestone_25", now: 10_000), .globalGap)
        XCTAssertNil(gate.tryAcquire("roam_end", now: 10_000))
        gate.releaseUnshown("roam_end")
        XCTAssertNil(gate.tryAcquire("roam_end", now: 10_000))
        gate.releaseUnshown("roam_end")
        XCTAssertEqual(gate.tryAcquire("roam_end", now: 10_000), .failCapped)
        XCTAssertNil(gate.tryAcquire("roam_poi_first_light", now: 50_000))
        gate.confirmShown("roam_poi_first_light", now: 50_000)
        XCTAssertEqual(gate.tryAcquire("roam_poi_first_light", now: 100_000), .poiGap)
        XCTAssertEqual(gate.tryAcquire("roam_greeting", now: 999_999), .unknownEvent)
    }

    func testCoordinatorQueuesUntilTheProfileArrivesAndShowsOnlyReviewedLines() async {
        var clock = 0.0
        var shown: [String?] = []
        var finish: [String] = []
        var asked: [String] = []
        let coordinator = G6RoamNPCCoordinator(ports: .init(
            now: { clock }, sleep: { _ in }, featureOn: { true },
            fetchProfile: { "31" },
            fetchLine: { _, type in asked.append(type); return type == "roam_milestone_25" ? nil : "line:" + type },
            showBubble: { shown.append($0); return true },
            showFinishLine: { finish.append($0) }))
        coordinator.dispatch(.sessionStarted)
        await coordinator.settle()
        XCTAssertEqual(asked, ["roam_start"])
        XCTAssertEqual(shown.first ?? nil, "line:roam_start")
        clock = 60_000
        coordinator.dispatch(.uniqueTileCountChanged(30))
        await coordinator.settle()
        clock = 61_000
        coordinator.dispatch(.uniqueTileCountChanged(31))
        await coordinator.settle()
        coordinator.dispatch(.uniqueTileCountChanged(32))
        await coordinator.settle()
        XCTAssertEqual(asked.filter { $0 == "roam_milestone_25" }.count, 2, "a missing line is retried once, then capped")
        coordinator.dispatch(.poiVisitRecorded(firstVisit: false, poiKey: "k"))
        coordinator.dispatch(.poiVisitRecorded(firstVisit: true, poiKey: nil))
        await coordinator.settle()
        XCTAssertFalse(asked.contains("roam_poi_first_light"))
        coordinator.dispatch(.sessionFinished)
        await coordinator.settle()
        XCTAssertEqual(finish, ["line:roam_end"])
    }

    func testCoordinatorStaysSilentWhenTheFlagIsOffAndGivesUpAfterTwoProfileMisses() async {
        var flag = false
        var profileReads = 0
        let coordinator = G6RoamNPCCoordinator(ports: .init(
            now: { 0 }, sleep: { _ in }, featureOn: { flag },
            fetchProfile: { profileReads += 1; return nil },
            fetchLine: { _, _ in "never" }, showBubble: { _ in true }, showFinishLine: { _ in }))
        coordinator.start()
        coordinator.dispatch(.sessionStarted)
        await coordinator.settle()
        XCTAssertEqual(profileReads, 0)
        flag = true
        coordinator.dispatch(.sessionStarted)
        await coordinator.settle()
        XCTAssertEqual(profileReads, 2)
        XCTAssertTrue(coordinator.isSilenced)
    }

    // MARK: AI theme draft V2

    func testAIDraftRequestShapes() async throws {
        let wire = Wire(body: Data(#"{"code":200,"data":null}"#.utf8))
        let source = try make(wire)
        let key = "0f8fad5b-d9cb-469f-a165-70867728950e"
        let server = "td2_" + String(repeating: "a", count: 32)
        _ = try await source.aiDraftPrepare(prepareKey: key, idea: " Old town coffee ", productType: 2, token: token)
        _ = try await source.aiDraftExecute(requestID: server, token: token)
        _ = try await source.aiDraftRequest(requestID: server, prepareKey: nil, token: token)
        _ = try await source.aiDraftRequest(requestID: nil, prepareKey: key, token: token)
        _ = try await source.aiDraftRecovery(beforeID: nil, token: token)
        _ = try await source.aiDraftRecovery(beforeID: "41", token: token)
        XCTAssertEqual(wire.requests.map { $0.httpMethod }, ["POST", "POST", "GET", "GET", "GET", "GET"])
        XCTAssertEqual(wire.requests.map { $0.url?.path }, [
            "/api/ai/theme/draft/prepare", "/api/ai/theme/draft/execute", "/api/ai/theme/draft/request",
            "/api/ai/theme/draft/request", "/api/ai/theme/draft/recovery", "/api/ai/theme/draft/recovery"
        ])
        let prepare = try XCTUnwrap(json(wire.requests[0].httpBody))
        XCTAssertEqual(Set(prepare.keys), ["prepareKey", "idea", "productType"])
        XCTAssertEqual(prepare["idea"] as? String, "Old town coffee")
        XCTAssertEqual(prepare["productType"] as? Int, 2)
        XCTAssertEqual(json(wire.requests[1].httpBody) as NSDictionary?, ["requestId": server])
        XCTAssertEqual(query(wire.requests[2]), ["requestId": server])
        XCTAssertEqual(query(wire.requests[3]), ["prepareKey": key])
        XCTAssertNil(wire.requests[4].url?.query)
        XCTAssertEqual(query(wire.requests[5]), ["beforeId": "41"])
        do { _ = try await source.aiDraftExecute(requestID: key, token: token); XCTFail() } catch { XCTAssertEqual(error as? G6Refusal, .invalidRequest) }
        do { _ = try await source.aiDraftRecovery(beforeID: "0041", token: token); XCTFail() } catch { XCTAssertEqual(error as? G6Refusal, .invalidRequest) }
    }

    func testAIDraftViewRejectsAnyExtraOrMissingKey() {
        var view = viewBody(state: "PREPARED", request: "td2_" + String(repeating: "b", count: 32))
        XCTAssertNotNil(G6AIThemeDraftView(view))
        view["extra"] = 1
        XCTAssertNil(G6AIThemeDraftView(view))
        view.removeValue(forKey: "extra")
        view.removeValue(forKey: "replayed")
        XCTAssertNil(G6AIThemeDraftView(view))
        var succeeded = viewBody(state: "SUCCEEDED", request: "td2_" + String(repeating: "b", count: 32))
        succeeded["resultAvailable"] = true
        XCTAssertNil(G6AIThemeDraftView(succeeded), "an available result must be an object")
        succeeded["result"] = ["title": "T"]
        XCTAssertNotNil(G6AIThemeDraftView(succeeded))
        var badProduct = viewBody(state: "FAILED", request: nil)
        badProduct["productType"] = 3
        XCTAssertNil(G6AIThemeDraftView(badProduct))
    }

    func testAIDraftFlowPreparesExecutesAndReturnsTheResult() async throws {
        let server = "td2_" + String(repeating: "c", count: 32)
        let prepared = envelopeJSON(viewBody(state: "PREPARED", request: server, context: true))
        var done = viewBody(state: "SUCCEEDED", request: server, context: false)
        done["resultAvailable"] = true
        done["result"] = ["draft": ["title": "Old town"]]
        done["resultExpiresAt"] = "2030-01-02T00:00:00Z"
        let wire = Wire(bodies: [prepared, envelopeJSON(done)])
        let store = JourneyMemoryRequestStore()
        let flow = G6AIThemeDraftFlow(source: try make(wire), store: store, member: { "9" }, token: { "session-token" },
                                      now: { Date(timeIntervalSince1970: 1_800_000_000) }, makeUUID: { "0f8fad5b-d9cb-469f-a165-70867728950e" })
        let outcome = await flow.run(idea: "coffee", productType: 1)
        guard case .succeeded(let request, let result) = outcome else { return XCTFail("\(outcome)") }
        XCTAssertEqual(request, server)
        XCTAssertEqual((try JSONSerialization.jsonObject(with: result) as? [String: Any])?.keys.sorted(), ["draft"])
        XCTAssertEqual(wire.requests.map { $0.url?.path }, ["/api/ai/theme/draft/prepare", "/api/ai/theme/draft/execute"])
        guard case .ready(let record) = G6AIThemeDraftJournal(store: store).load(member: "9") else { return XCTFail() }
        XCTAssertEqual(record.state, "SUCCEEDED")
        XCTAssertEqual(record.stage, "KNOWN")
    }

    func testAIDraftUnknownIsReadBackNotRepreparedUntilConfirmed() async throws {
        let server = "td2_" + String(repeating: "d", count: 32)
        let unknown = envelopeJSON(viewBody(state: "UNKNOWN", request: server))
        let wire = Wire(bodies: [unknown, unknown, envelopeJSON(viewBody(state: "PROCESSING", request: "td2_" + String(repeating: "e", count: 32)))])
        let store = JourneyMemoryRequestStore()
        var keys = ["0f8fad5b-d9cb-469f-a165-70867728950e", "1f8fad5b-d9cb-469f-a165-70867728950e"]
        let flow = G6AIThemeDraftFlow(source: try make(wire), store: store, member: { "9" }, token: { "session-token" },
                                      now: { Date(timeIntervalSince1970: 1_800_000_000) }, makeUUID: { keys.removeFirst() })
        let first = await flow.run(idea: "coffee", productType: 2)
        XCTAssertEqual(first, .unknown)
        let second = await flow.run(idea: "something else", productType: 2)
        XCTAssertEqual(second, .unknown)
        XCTAssertEqual(wire.requests.map { $0.url?.path }, ["/api/ai/theme/draft/prepare", "/api/ai/theme/draft/request"])
        XCTAssertEqual(query(wire.requests[1]), ["requestId": server])
        XCTAssertTrue(flow.canConfirmNew)
        let third = await flow.run(idea: "something else", productType: 2, confirmedNew: true)
        XCTAssertEqual(third, .processing)
        XCTAssertEqual(wire.requests.last?.url?.path, "/api/ai/theme/draft/prepare")
        XCTAssertEqual(json(wire.requests.last?.httpBody)?["prepareKey"] as? String, "1f8fad5b-d9cb-469f-a165-70867728950e")
    }

    func testAIDraftNetworkFailureKeepsTheIdentity() async throws {
        let wire = Wire(failing: true)
        let store = JourneyMemoryRequestStore()
        let flow = G6AIThemeDraftFlow(source: try make(wire), store: store, member: { "9" }, token: { "session-token" },
                                      makeUUID: { "0f8fad5b-d9cb-469f-a165-70867728950e" })
        let outcome = await flow.run(idea: "coffee", productType: 1)
        XCTAssertEqual(outcome, .networkUnconfirmed)
        guard case .ready(let record) = G6AIThemeDraftJournal(store: store).load(member: "9") else { return XCTFail() }
        XCTAssertEqual(record.stage, "PREPARE_UNCONFIRMED")
        XCTAssertNil(record.requestId)
    }

    func testRecoveryPageOrderingAndPagingRules() {
        func item(_ cursor: String, _ hex: Character, key: String) -> [String: Any] {
            ["cursor": cursor, "prepareKey": key, "requestId": "td2_" + String(repeating: hex, count: 32), "state": "FAILED",
             "reasonCode": NSNull(), "productType": 1, "createdAt": "2030-01-01T08:00:00Z", "executeBefore": "2030-01-01T09:00:00Z",
             "resultExpiresAt": NSNull()]
        }
        let a = item("9", "a", key: "0f8fad5b-d9cb-469f-a165-70867728950e")
        let b = item("7", "b", key: "1f8fad5b-d9cb-469f-a165-70867728950e")
        let page = G6AIThemeDraftRecoveryPage(["items": [a, b], "nextCursor": NSNull()], before: nil)
        XCTAssertEqual(page?.items.map(\.cursor), ["9", "7"])
        XCTAssertEqual(page?.items.first?.createdAtText, "2030-01-01 08:00")
        XCTAssertNil(G6AIThemeDraftRecoveryPage(["items": [b, a], "nextCursor": NSNull()], before: nil), "cursors must descend")
        XCTAssertNil(G6AIThemeDraftRecoveryPage(["items": [a, b], "nextCursor": "7"], before: nil), "a next cursor needs a full page")
        XCTAssertNil(G6AIThemeDraftRecoveryPage(["items": [a], "nextCursor": NSNull()], before: "9"), "older than beforeId only")
        XCTAssertNil(G6AIThemeDraftRecoveryPage(["items": [a], "nextCursor": NSNull(), "total": 1], before: nil))
        XCTAssertNil(G6AIThemeDraftRecoveryPage(["items": [a, a], "nextCursor": NSNull()], before: nil))
    }

    func testJournalRefusesIllegalUpdates() {
        let journal = G6AIThemeDraftJournal(store: JourneyMemoryRequestStore())
        let start = G6AIThemeDraftRecord(memberId: "9", prepareKey: "0f8fad5b-d9cb-469f-a165-70867728950e", requestId: nil,
                                         stage: "PREPARE_UNCONFIRMED", state: nil, reasonCode: nil, createdAt: 1)
        XCTAssertTrue(journal.save(member: "9", start, expected: nil))
        var unknown = start
        unknown.requestId = "td2_" + String(repeating: "f", count: 32)
        unknown.state = "UNKNOWN"
        unknown.stage = "KNOWN"
        XCTAssertTrue(journal.save(member: "9", unknown, expected: start))
        var backToPrepared = unknown
        backToPrepared.state = "PREPARED"
        backToPrepared.stage = "PREPARED"
        XCTAssertFalse(journal.save(member: "9", backToPrepared, expected: unknown))
        XCTAssertFalse(journal.save(member: "8", unknown, expected: nil), "another member's record is invalid")
        XCTAssertNil(G6AIThemeDraftRecord.key(member: "0"))
    }

    // MARK: Creator

    func testAuthorWriteReceiptReadAndDecision() async throws {
        let wire = Wire(body: Data(#"{"code":200,"data":{"operation":"NPC_CHAT_DELETE","requestId":"aw-1","state":"UNKNOWN"}}"#.utf8))
        let source = try make(wire)
        let store = JourneyMemoryRequestStore()
        let intent = try XCTUnwrap(G6AuthorWrite.begin(store, owner: "9", bucket: "npc-delete", operation: "NPC_CHAT_DELETE",
                                                       endpoint: "/api/ai/npc/chat/data/delete", body: [:], requestID: "aw-1"))
        XCTAssertEqual(G6AuthorWrite.pending(store, owner: "9", bucket: "npc-delete"), intent)
        let envelope = try await source.authorWriteReceipt(operation: intent.operation, requestID: intent.requestId, token: token)
        XCTAssertEqual(wire.requests[0].url?.path, "/api/author-write/receipt")
        XCTAssertEqual(query(wire.requests[0]), ["operation": "NPC_CHAT_DELETE", "requestId": "aw-1"])
        XCTAssertEqual(G6AuthorWrite.decide(envelope, intent: intent), .replay)
        let other = G6Envelope(httpStatus: 200, code: "200", reasonCode: nil, message: nil,
                               dataJSON: Data(#"{"operation":"NPC_CHAT_DELETE","requestId":"aw-2","state":"FOUND"}"#.utf8), netFail: false)
        XCTAssertEqual(G6AuthorWrite.decide(other, intent: intent), .unknown)
        XCTAssertEqual(G6AuthorWrite.settle(status: 422, object: nil, intent: intent, valid: { _ in true }), .rejected)
        XCTAssertEqual(G6AuthorWrite.settle(status: 200, object: ["code": 200, "data": ["deleted": 2]], intent: intent,
                                            valid: { ($0?["deleted"] as? Int) != nil }), .succeeded)
        XCTAssertEqual(G6AuthorWrite.settle(status: 502, object: nil, intent: intent, valid: { _ in true }), .unknown)
        XCTAssertTrue(G6AuthorWrite.clear(store, intent: intent))
    }

    // MARK: Marketing reads

    func testPromotionCatalogShapeAndView() async throws {
        let wire = Wire(body: Data(#"""
        {"code":200,"data":{"serverNow":"2030-01-01 10:00:00",
          "offers":[{"offerCode":"BUNDLE","name":"Bundle","available":true,"differenceAmount":"12.5"},
                    {"name":"Locked","available":false,"reasonCode":"TRIGGER_FACT_MISSING"},
                    {"name":"","available":true}],
          "promotions":[{"promoCode":"P","name":"Flash","eligible":true,"windowEndsAt":"2030-01-04 10:00:00"},
                        {"name":"Soon","eligible":true,"windowEndsAt":"2030-01-01 10:20:30"},
                        {"name":"Past","eligible":true,"windowEndsAt":"2030-01-01 09:00:00"}],
          "tiers":[{"tierCode":"T1","minQuantity":2,"maxQuantity":4,"unitPrice":88},{"minQuantity":0,"maxQuantity":0,"unitPrice":1},
                   {"tierCode":"T3","minQuantity":5,"unitPrice":null}]}}
        """#.utf8))
        let envelope = try await make(wire).promotionCatalog(activityID: 42, token: token)
        XCTAssertEqual(wire.requests[0].url?.path, "/api/marketing/promotions/catalog")
        XCTAssertEqual(query(wire.requests[0]), ["ownerType": "2", "ownerId": "42"])
        let catalog = G6PromotionCatalog(envelope: envelope)
        XCTAssertEqual(catalog.offers.map(\.saveYuan), ["12.50", nil])
        XCTAssertEqual(catalog.offers.map(\.reasonCode), [nil, "TRIGGER_FACT_MISSING"])
        XCTAssertEqual(catalog.promotions.map(\.remain), [.days(3), .minutes(21), nil])
        XCTAssertEqual(catalog.tiers, [.init(id: "tier-T1", range: .span(2, 4), unitPrice: "88.00")])
        XCTAssertTrue(catalog.show)
        XCTAssertFalse(G6PromotionCatalog(envelope: .networkFailure).show)
    }

    func testRevenueAllocationsNeverShowUnknownAsZero() async throws {
        let wire = Wire(body: Data(#"""
        {"code":200,"data":[
          {"allocationId":5,"orderType":1,"statusText":"accrued","settleableAt":"2030-02-03 00:00:00","currency":"CNY","lines":[
            {"entryType":1,"role":"author","amountFen":1230},
            {"entryType":1,"role":"referrer","amount":null},
            {"entryType":2,"role":"author","sourceFact":"refund:1","amountFen":200},
            {"entryType":2,"role":"author","sourceFact":"refund:1","amount":"1.5"},
            {"entryType":2,"role":"x","sourceFact":"refund:2"}]},
          {"orderType":2,"statusText":"paid"},
          {"allocationId":"6","statusText":"weird","currency":"USD","lines":[{"entryType":1,"role":"author","amountFen":0}]}]}
        """#.utf8))
        let envelope = try await make(wire).authorRevenue(token: token)
        XCTAssertEqual(wire.requests[0].url?.path, "/api/marketing/revenue/author/mine")
        guard case .ready(let rows) = G6RevenueAllocations.state(envelope) else { return XCTFail() }
        XCTAssertEqual(rows.map(\.id), ["5", "6"])
        XCTAssertEqual(rows[0].settleableDay, "2030.02.03")
        XCTAssertEqual(rows[0].lines.map(\.amountText), ["¥12.30", nil, "\u{2212}¥3.50", nil])
        XCTAssertEqual(rows[0].lines.map(\.reversal), [false, false, true, true])
        XCTAssertEqual(rows[1].status, "unknown")
        XCTAssertNil(rows[1].orderType)
        XCTAssertEqual(rows[1].lines.map(\.amountText), ["USD 0.00"])
        let notParticipant = G6Envelope(httpStatus: 200, code: "500", reasonCode: "NOT_PARTICIPANT", message: nil, dataJSON: nil, netFail: false)
        XCTAssertEqual(G6RevenueAllocations.state(notParticipant), .hidden)
        XCTAssertEqual(G6RevenueAllocations.state(.networkFailure), .error)
        let empty = G6Envelope(httpStatus: 200, code: "200", reasonCode: nil, message: nil, dataJSON: Data("[]".utf8), netFail: false)
        XCTAssertEqual(G6RevenueAllocations.state(empty), .hidden)
        let object = G6Envelope(httpStatus: 200, code: "200", reasonCode: nil, message: nil, dataJSON: Data("{}".utf8), netFail: false)
        XCTAssertEqual(G6RevenueAllocations.state(object), .error)
    }

    func testMarketingProductDetailReadsOneProduct() async throws {
        let wire = Wire(bodies: [
            Data(#"{"code":200,"data":{"productId":"88","productName":"City pass","productKind":2,"cashPrice":19.9,"items":[{"topicId":"7","topicTitle":"Old town"}]}}"#.utf8),
            Data(#"{"code":500,"reasonCode":"PRODUCT_NOT_FOUND"}"#.utf8)
        ])
        let source = try make(wire)
        let ready = G6MarketingProduct.outcome(try await source.marketingProduct(id: "88", token: token))
        guard case .ready(let product) = ready else { return XCTFail() }
        XCTAssertEqual(product.name, "City pass")
        XCTAssertEqual(product.topics, ["Old town"])
        let missing = try await source.marketingProduct(id: "89", token: token)
        XCTAssertEqual(G6MarketingProduct.outcome(missing), .failed(reasonCode: "PRODUCT_NOT_FOUND"))
        XCTAssertEqual(wire.requests.map { $0.url?.path }, ["/api/marketing/product/88", "/api/marketing/product/89"])
        XCTAssertTrue(wire.requests.allSatisfy { $0.httpMethod == "GET" && $0.httpBody == nil })
        for id in ["list", "orders", "quote", "gifts", "../pay", ""] {
            do { _ = try await source.marketingProduct(id: id, token: token); XCTFail(id) }
            catch { XCTAssertEqual(error as? G6Refusal, .invalidRequest, id) }
        }
        XCTAssertEqual(wire.requests.count, 2)
    }

    // MARK: China gate

    func testChinaProductionAdmitsTheG6GrantAndRefusesHiddenAndMoneyRoutes() async throws {
        for path in ["/api/ai/npc/profile", "/api/ai/npc/event", "/api/ai/theme/draft/prepare", "/api/ai/theme/draft/execute",
                     "/api/ai/theme/draft/recovery", "/api/ai/theme/draft/request", "/api/marketing/promotions/catalog",
                     "/api/marketing/revenue/author/mine", "/api/marketing/product/88",
                     "/api/platform-pass/orders", "/api/platform-pass/orders/77"] {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall(path), path)
        }
        for path in ["/api/marketing/attribution/claim",
                     "/api/ai/npc/chat", "/api/ai/npc/chat/request", "/api/author-write/receipt",
                     "/api/marketing/product/quote", "/api/marketing/product/order",
                     "/api/marketing/product/orders/77/pay", "/api/registration/pay", "/api/pay/create", "/api/withdrawal/create"] {
            XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall(path), path)
        }
        XCTAssertEqual(ChinaReviewedRouteCapability.wiredPatternCount, 680) // 679 + orient scoring session recovery
        let wire = Wire(body: Data(#"{"code":200,"data":[]}"#.utf8))
        let china = G6CapabilitySource(configuration: try APIConfiguration(baseURL: URL(string: "https://www.chengyinhub.com/prod-api/")!), transport: wire)
        _ = try await china.authorRevenue(token: token)
        XCTAssertEqual(wire.requests.last?.url?.path, "/prod-api/api/marketing/revenue/author/mine")
        do { _ = try await china.npcChat(requestID: "0f8fad5b-d9cb-469f-a165-70867728950e", bizID: 1, message: "hi", token: token); XCTFail() }
        catch { XCTAssertEqual(error as? G6Refusal, .notAdmitted) }
        do { _ = try await china.authorWriteReceipt(operation: "NPC_CHAT_DELETE", requestID: "aw-1", token: token); XCTFail() }
        catch { XCTAssertEqual(error as? G6Refusal, .notAdmitted) }
        XCTAssertEqual(wire.requests.count, 1)
        XCTAssertFalse(G6CapabilitySource.paths.contains("/api/marketing/attribution/claim"))
        XCTAssertFalse(G6CapabilitySource.paths.contains("/api/platform-pass/orders/{}"))
    }

    // MARK: Helpers

    private func viewBody(state: String, request: String?, context: Bool = false) -> [String: Any] {
        ["contextAvailable": context, "executeBefore": request == nil ? NSNull() : "2030-01-01T00:00:00Z", "productType": NSNull(),
         "reasonCode": NSNull(), "replayed": false, "requestId": request.map { $0 as Any } ?? NSNull(), "result": NSNull(),
         "resultAvailable": false, "resultExpiresAt": NSNull(), "state": state]
    }

    private func envelopeJSON(_ view: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: ["code": 200, "data": view])) ?? Data()
    }

    private func make(_ wire: Wire) throws -> G6CapabilitySource {
        G6CapabilitySource(configuration: try APIConfiguration(baseURL: URL(string: "https://example.test")!), transport: wire)
    }

    private func query(_ request: URLRequest) -> [String: String] {
        guard let url = request.url, let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return [:] }
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    private func json(_ data: Data?) -> [String: Any]? {
        guard let data else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private final class Wire: HTTPTransport, @unchecked Sendable {
        var requests: [URLRequest] = []
        var bodies: [Data]
        var body: Data
        let failing: Bool
        init(body: Data = Data(#"{"code":200}"#.utf8), bodies: [Data] = [], failing: Bool = false) {
            self.body = body
            self.bodies = bodies
            self.failing = failing
        }
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            if failing { throw URLError(.notConnectedToInternet) }
            return (bodies.isEmpty ? body : bodies.removeFirst(), 200)
        }
    }
}
