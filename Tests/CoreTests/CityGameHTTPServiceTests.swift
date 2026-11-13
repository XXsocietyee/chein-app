import XCTest
@testable import QuestifyCore

/// Stub-transport tests for the production CITY game service (gaps A routes). Synthetic numbers only.
@MainActor final class CityGameHTTPServiceTests: XCTestCase {
    private final class Stub: HTTPTransport {
        var requests: [URLRequest] = []
        /// Answers by "METHOD path"; a nil answer throws a lost connection.
        var answers: [String: (Int, Any)?] = [:]
        var fallback: (Int, Any)? = (404, ["code": 404, "msg": "x", "errorCode": "CITY_RECEIPT_NOT_FOUND"])
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            let key = (request.httpMethod ?? "") + " " + (request.url?.path ?? "")
            let answer = answers.keys.contains(key) ? answers[key]! : fallback
            guard let (status, body) = answer else { throw URLError(.networkConnectionLost) }
            return (try JSONSerialization.data(withJSONObject: body), status)
        }
    }

    private let base = URL(string: "https://city.example.test/prod-api/")!
    private var lease: CityGameProductionLease { CityGameProductionLease(host: "city.example.test", regionID: "r1")! }

    private func service(_ stub: Stub, current: @escaping () -> Bool = { true }, unauthorized: @escaping () -> Void = {}) throws -> CityGameHTTPService {
        try CityGameHTTPService(configuration: APIConfiguration(baseURL: base), token: "token-1", lease: lease, transport: stub,
                                isCurrent: current, onUnauthorized: unauthorized)
    }
    private func read(lifecycle: String = "OPEN") -> CityReadSnapshot {
        CityReadSnapshot(board: CityReadBoard(gameId: "g1", boardId: "b1", regionId: "r1", seasonId: "s1", rulesReleaseId: "rr1",
                                              rulesHash: String(repeating: "f", count: 64), lifecycle: lifecycle, title: "Synthetic board", revision: 4),
                         membership: .joined, participation: CityParticipation(participationId: "p1", membershipVersion: 2),
                         points: [CityReadPoint(pointId: "pt-a", title: "A", latitude: 1, longitude: 2, mine: false)])
    }
    private func ok(_ data: Any) -> (Int, Any) { (200, ["code": 200, "msg": "ok", "data": data]) }
    private func snapshotJSON(lifecycle: String = "OPEN", version: Int = 4, actions: Int = 3, landed: Any = NSNull()) -> [String: Any] {
        ["contract": "CITY_GAME_SNAPSHOT_V1", "scope": "CITY", "boardId": "b1", "seasonId": "s1", "boardVersion": version, "sequence": 9,
         "lifecycle": lifecycle, "roundSeq": 1,
         "rules": ["rulesReleaseId": "rr1", "ruleVersion": "synthetic-1", "validFromMillis": 1, "validUntilMillis": NSNull(),
                   "actionsRemaining": actions, "actionsPerRound": 3, "holdingLimit": 2],
         "properties": [["propertyId": "prop-a", "pointId": "pt-a", "role": "OPERABLE", "status": "AVAILABLE", "stateVersion": 7,
                         "heldByMyTeam": false, "protectedUntilMillis": NSNull(), "services": [], "challenge": NSNull(), "taskAttemptKept": true]],
         "memberPoints": 100, "neutralTasksAvailable": false,
         "team": ["trackPosition": 2, "landedPropertyId": landed, "score": 0]]
    }
    private func receiptJSON(_ requestId: String, action: String = "ROLL_ROUND", decision: String = "APPLIED", version: Int = 5,
                             reason: Any = NSNull(), charged: Int = 0, face: Any = NSNull()) -> [String: Any] {
        ["requestId": requestId, "boardId": "b1", "action": action, "decision": decision, "currentVersion": version,
         "reasonCode": reason, "taskAttemptKept": false, "pointsCharged": charged, "diceFace": face]
    }
    private func intent(_ kind: CityActionKind = .roll, target: String = "b1", expected: Int64 = 4, consent: CityPayerConsent? = nil) throws -> CityActionIntent {
        let r = read()
        return try CityActionIntent(kind: kind, board: r.board, lifecycle: .open, participation: r.participation, targetId: target,
                                    roundSeq: 1, expectedVersion: expected, consent: consent)
    }

    func testLeaseNeedsItsHostAndARegion() throws {
        XCTAssertNil(CityGameProductionLease(host: "city.example.test", regionID: ""))
        XCTAssertThrowsError(try CityGameHTTPService(configuration: APIConfiguration(baseURL: URL(string: "https://other.example.test/")!),
                                                     token: "token-1", lease: lease, transport: Stub(), isCurrent: { true }))
        XCTAssertTrue(CityGameProductionLease.paths.contains("/api/city-game/game/action/{}"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/city-game/game/action/" + UUID().uuidString))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/city-game/team-participation/request/" + UUID().uuidString.lowercased()))
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/city-game/acquisition"))
    }

    func testSnapshotRouteDecodesTheTeamBlock() async throws {
        let stub = Stub(); stub.answers["GET /prod-api/api/city-game/game/snapshot"] = ok(snapshotJSON(landed: "prop-a"))
        let value = try await service(stub).snapshot(for: read())
        let url = try XCTUnwrap(stub.requests.first?.url)
        XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems, [URLQueryItem(name: "boardId", value: "b1")])
        XCTAssertEqual(stub.requests.first?.value(forHTTPHeaderField: "Authorization"), "token-1")
        XCTAssertEqual(value.team, CityTeamProgress(trackPosition: 2, landedPropertyId: "prop-a", score: 0))
        try value.validate(against: read())
    }

    func testDeltasRouteSendsTheCursor() async throws {
        let stub = Stub()
        stub.answers["GET /prod-api/api/city-game/game/deltas"] = ok([["eventId": "evt-10", "boardId": "b1", "seasonId": "s1", "aggregate": "board",
                                                                      "type": "TEAM_MOVED", "sequence": 10, "boardVersion": 5]])
        let cursor = try CityStreamCursor(boardId: "b1", seasonId: "s1", rulesReleaseId: "rr1", boardVersion: 4, sequence: 9)
        let page = try await service(stub).deltas(after: cursor)
        XCTAssertEqual(page.map(\.eventId), ["evt-10"])
        let query = URLComponents(url: try XCTUnwrap(stub.requests.first?.url), resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(Set(query), [URLQueryItem(name: "after", value: "9"), URLQueryItem(name: "boardId", value: "b1"), URLQueryItem(name: "seasonId", value: "s1")])
    }

    func testQuoteRoutePostsIdsOnly() async throws {
        let stub = Stub()
        stub.answers["POST /prod-api/api/city-game/game/quote"] = ok(["quoteId": "8c1d1f1e-0000-4000-8000-000000000001", "quoteVersion": 4,
            "boardId": "b1", "action": "ACQUIRE_PROPERTY", "targetId": "prop-a", "payerMemberId": "12", "ruleVersion": "synthetic-1",
            "memberPointsCost": 30, "actionCost": 1, "beneficiaryMemberIds": ["12"], "expiresAtMillis": 9_999_999_999_999])
        let quote = try await service(stub).quote(.acquireProperty, targetId: "prop-a", read: read())
        XCTAssertEqual(quote.memberPointsCost, 30); XCTAssertEqual(quote.payerMemberId, "12")
        let body = try XCTUnwrap(stub.requests.first?.httpBody)
        XCTAssertEqual(String(decoding: body, as: UTF8.self), #"{"action":"ACQUIRE_PROPERTY","boardId":"b1","targetId":"prop-a"}"#)
        XCTAssertEqual(stub.requests.first?.value(forHTTPHeaderField: "Content-Type"), "application/json")
        // A free action is never quoted.
        await XCTAssertThrowsErrorAsync { _ = try await self.service(Stub()).quote(.roll, targetId: "b1", read: self.read()) }
    }

    func testActionRouteSendsTheCanonicalBodyAndDecodesTheServerFace() async throws {
        let stub = Stub(), roll = try intent()
        stub.answers["POST /prod-api/api/city-game/game/action"] = ok(receiptJSON(roll.requestId, face: 4))
        let receipt = try await service(stub).submit(roll)
        XCTAssertEqual(receipt.diceFace, 4); XCTAssertEqual(receipt.pointsCharged, 0)
        try receipt.validate(for: roll)
        XCTAssertEqual(stub.requests.first?.httpBody, try roll.body())
        let body = String(decoding: try XCTUnwrap(stub.requests.first?.httpBody), as: UTF8.self)
        XCTAssertFalse(body.contains("dice")); XCTAssertFalse(body.contains("Cost"))
    }

    func testReceiptRouteAndUnknownReceipt() async throws {
        let stub = Stub(), roll = try intent()
        // 404 CITY_RECEIPT_NOT_FOUND is the only "no receipt yet".
        let missing = try await service(stub).receipt(for: roll)
        XCTAssertNil(missing)
        XCTAssertEqual(stub.requests.first?.url?.path, "/prod-api/api/city-game/game/action/" + roll.requestId)
        XCTAssertEqual(stub.requests.first?.httpMethod, "GET")
        stub.answers["GET /prod-api/api/city-game/game/action/" + roll.requestId] = ok(receiptJSON(roll.requestId, face: 2))
        let found = try await service(stub).receipt(for: roll)
        XCTAssertEqual(found?.diceFace, 2)
        // Any other failure is not "missing": the outcome stays unknown.
        stub.answers["GET /prod-api/api/city-game/game/action/" + roll.requestId] = (503, ["code": 503, "msg": "x", "errorCode": "UNAVAILABLE"])
        await XCTAssertThrowsErrorAsync { _ = try await self.service(stub).receipt(for: roll) }
        stub.answers["GET /prod-api/api/city-game/game/action/" + roll.requestId] = .some(nil)
        await XCTAssertThrowsErrorAsync { _ = try await self.service(stub).receipt(for: roll) }
    }

    func testUnauthorizedStaleAndChangedAnswers() async throws {
        let stub = Stub(); var expired = 0
        stub.answers["GET /prod-api/api/city-game/game/snapshot"] = (401, ["code": 401, "msg": "x"])
        do { _ = try await service(stub, unauthorized: { expired += 1 }).snapshot(for: read()); XCTFail() }
        catch { XCTAssertEqual(error as? CityGameServiceError, .unauthorized) }
        XCTAssertEqual(expired, 1)
        stub.answers["GET /prod-api/api/city-game/game/deltas"] = (409, ["code": 409, "msg": "x", "errorCode": "CITY_SNAPSHOT_CHANGED"])
        let cursor = try CityStreamCursor(boardId: "b1", seasonId: "s1", rulesReleaseId: "rr1", boardVersion: 4, sequence: 9)
        do { _ = try await service(stub).deltas(after: cursor); XCTFail() }
        catch { XCTAssertEqual(error as? CityGameServiceError, .snapshotChanged) }
        // A lapsed lease sends nothing.
        let quiet = Stub()
        do { _ = try await service(quiet, current: { false }).snapshot(for: read()); XCTFail() }
        catch { XCTAssertEqual(error as? CityGameServiceError, .notCurrent) }
        XCTAssertTrue(quiet.requests.isEmpty)
    }

    /// Lost submit → unknown → readback by the saved requestId finds nothing → the exact same
    /// intent is re-sent → the server's stored receipt (with its face) settles it. Never re-rolled locally.
    func testCoordinatorRecoversALostRollThroughTheReceiptRoute() async throws {
        let stub = Stub()
        stub.answers["GET /prod-api/api/city-game/game/snapshot"] = ok(snapshotJSON())
        stub.answers["POST /prod-api/api/city-game/game/action"] = .some(nil)
        let game = CityGameCoordinator(read: read(), service: try service(stub), capabilities: .cityGame(lease), memberId: "12", isCurrent: { true })
        await game.load()
        XCTAssertTrue(game.canRoll)
        game.prepareRoll(); await game.confirm()
        XCTAssertEqual(game.phase, .unknown)
        let pending = try XCTUnwrap(game.pendingIntent)
        await game.readBack()
        XCTAssertEqual(game.notice, .noReceiptYet); XCTAssertEqual(game.phase, .unknown)
        stub.answers["POST /prod-api/api/city-game/game/action"] = ok(receiptJSON(pending.requestId, face: 5))
        await game.retryExact()
        let posts = stub.requests.filter { $0.httpMethod == "POST" }
        XCTAssertEqual(posts.count, 2)
        XCTAssertEqual(posts[0].httpBody, posts[1].httpBody)
        XCTAssertEqual(game.lastOutcome, .applied(version: 5)); XCTAssertEqual(game.lastReceipt?.diceFace, 5)
        XCTAssertNil(game.pendingIntent)
    }

    func testOneLifecycleActionsOnlyWhenOpenReadsWhenOpenOrFrozen() async throws {
        let stub = Stub(); stub.answers["GET /prod-api/api/city-game/game/snapshot"] = ok(snapshotJSON(lifecycle: "FROZEN"))
        let frozen = CityGameCoordinator(read: read(lifecycle: "FROZEN"), service: try service(stub), capabilities: .cityGame(lease),
                                         memberId: "12", isCurrent: { true })
        await frozen.load()
        XCTAssertEqual(frozen.phase, .ready); XCTAssertNotNil(frozen.snapshot)
        XCTAssertEqual(frozen.boardNotice, .boardNotOpen); XCTAssertFalse(frozen.canRoll)
        XCTAssertTrue(read(lifecycle: "FROZEN").board.servesBoundedReads); XCTAssertFalse(read(lifecycle: "FROZEN").board.acceptsNewActions)
        // One lifecycle: OPEN accepts actions and also serves the bounded reads; CLOSED serves neither.
        XCTAssertTrue(read().board.acceptsNewActions); XCTAssertTrue(read().board.servesBoundedReads)
        XCTAssertFalse(read(lifecycle: "CLOSED").board.servesBoundedReads); XCTAssertFalse(read(lifecycle: "CLOSED").board.acceptsNewActions)
        XCTAssertNoThrow(try CityPlayerRulesRoute(read: read()))
        XCTAssertThrowsError(try CityPlayerRulesRoute(read: read(lifecycle: "CLOSED")))
        XCTAssertNoThrow(try CityPlayerRulesRoute(read: read(lifecycle: "FROZEN")))
        XCTAssertThrowsError(try CityActionIntent(kind: .roll, board: read(lifecycle: "FROZEN").board, lifecycle: .open,
                                                  participation: read().participation, targetId: "b1", roundSeq: 1, expectedVersion: 4, consent: nil))
    }

    func testTeamBlockGatesOccupyOnLanding() async throws {
        let stub = Stub(); stub.answers["GET /prod-api/api/city-game/game/snapshot"] = ok(snapshotJSON())
        let game = CityGameCoordinator(read: read(), service: try service(stub), capabilities: .cityGame(lease), memberId: "12", isCurrent: { true })
        await game.load()
        let property = try XCTUnwrap(game.snapshot?.properties.first)
        XCTAssertEqual(game.actions(for: property), [])
        stub.answers["GET /prod-api/api/city-game/game/snapshot"] = ok(snapshotJSON(version: 5, landed: "prop-a"))
        await game.load()
        XCTAssertEqual(game.actions(for: try XCTUnwrap(game.snapshot?.properties.first)), [.acquireProperty])
    }

    func testReceiptRejectsChargesAndFacesThatDoNotFit() throws {
        let roll = try intent()
        var bad = CityActionReceipt(requestId: roll.requestId, boardId: "b1", action: "ROLL_ROUND", decision: .applied, currentVersion: 5,
                                    reasonCode: nil, taskAttemptKept: false)
        bad.pointsCharged = 3
        XCTAssertThrowsError(try bad.validate(for: roll))
        var rejected = CityActionReceipt(requestId: roll.requestId, boardId: "b1", action: "ROLL_ROUND", decision: .rejected, currentVersion: 4,
                                         reasonCode: "ROUND_CHANGED", taskAttemptKept: false)
        rejected.diceFace = 3
        XCTAssertThrowsError(try rejected.validate(for: roll))
    }
}

@MainActor private func XCTAssertThrowsErrorAsync(_ body: () async throws -> Void, file: StaticString = #filePath, line: UInt = #line) async {
    do { try await body(); XCTFail("expected an error", file: file, line: line) } catch {}
}
