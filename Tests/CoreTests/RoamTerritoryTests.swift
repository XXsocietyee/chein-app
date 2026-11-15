import XCTest
@testable import QuestifyCore

@MainActor final class RoamTerritoryTests: XCTestCase {
    private final class Stub: HTTPTransport {
        var requests: [URLRequest] = []
        var answers: [String: (Int, Any)] = [:]
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            let key = (request.httpMethod ?? "") + " " + (request.url?.path ?? "")
            guard let (status, body) = answers[key] else {
                return (try JSONSerialization.data(withJSONObject: ["code": 404, "msg": "missing", "errorCode": "NOT_FOUND"]), 404)
            }
            return (try JSONSerialization.data(withJSONObject: body), status)
        }
    }

    private let base = URL(string: "https://city.example.test/prod-api/")!
    private var lease: CityGameProductionLease { CityGameProductionLease(host: "city.example.test", regionID: "r1")! }

    private func ok(_ data: Any) -> (Int, Any) { (200, ["code": 200, "msg": "ok", "data": data]) }

    func testCityGameLeaseIncludesUnifiedDiceAndTerritoryRoutes() {
        let expected = [
            "/api/city-game/dice/roll",
            "/api/city-game/dice/audit",
            "/api/roam/territory/nearby",
            "/api/roam/territory/claim",
            "/api/roam/territory/checkin",
            "/api/roam/territory/leaderboard",
            "/api/roam/territory/my"
        ]
        for path in expected {
            XCTAssertTrue(CityGameProductionLease.paths.contains(path), "Missing lease path: \(path)")
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall(path), "Not admitted: \(path)")
        }
    }

    func testUnifiedDiceRollAndAuditDecode() async throws {
        let stub = Stub()
        stub.answers["POST /prod-api/api/city-game/dice/roll"] = ok([
            "requestId": "req-roll-1",
            "boardId": "b1",
            "action": "ROLL_ROUND",
            "decision": "APPLIED",
            "currentVersion": 6,
            "pointsCharged": 0,
            "diceFace": 4,
            "idempotentReplay": false,
            "teamId": "team-1",
            "roundSeq": 1,
            "faceIndex": 3,
            "faceValue": 4,
            "previousPosition": 1,
            "newPosition": 5,
            "landedPropertyId": "prop-5"
        ])
        stub.answers["GET /prod-api/api/city-game/dice/audit"] = ok([
            "boardId": "b1",
            "regionId": "r1",
            "teamId": "team-1",
            "diceId": "dice-1",
            "rolls": [[
                "rollId": "roll-1",
                "requestId": "req-roll-1",
                "teamId": "team-1",
                "actorMemberId": 1001,
                "roundSeq": 1,
                "diceId": "dice-1",
                "faceIndex": 3,
                "faceValue": 4,
                "sourcePath": "UNIFIED_DICE_ROLL",
                "randomTicket": 7,
                "totalWeight": 12,
                "previousPosition": 1,
                "newPosition": 5,
                "landedPropertyId": "prop-5",
                "beforeUnits": 3,
                "afterUnits": 2,
                "boardVersion": 6,
                "rolledAtMillis": 1700000000000
            ]]
        ])

        let service = try CityGameHTTPService(configuration: APIConfiguration(baseURL: base), token: "tok-1", lease: lease, transport: stub, isCurrent: { true })
        let receipt = try await service.rollUnifiedDice(requestId: "req-roll-1", boardId: "b1", expectedVersion: 5)
        XCTAssertEqual(receipt.decision, "APPLIED")
        XCTAssertEqual(receipt.newPosition, 5)
        XCTAssertEqual(receipt.landedPropertyId, "prop-5")

        let audit = try await service.diceAudit(boardId: "b1", limit: 10)
        XCTAssertEqual(audit.rolls.count, 1)
        XCTAssertEqual(audit.rolls.first?.sourcePath, "UNIFIED_DICE_ROLL")
        XCTAssertEqual(audit.rolls.first?.newPosition, 5)
    }

    func testUnifiedActionBudgetAndRulesDecode() throws {
        let json: [String: Any] = [
            "contract": "CITY_ACTION_BUDGET_V2",
            "scope": "CITY",
            "status": "AVAILABLE",
            "writeApproved": true,
            "binding": [
                "boardId": "b1", "regionId": "r1", "seasonId": "s1",
                "rulesReleaseId": "rr1", "releaseId": 1,
                "contentHash": String(repeating: "a", count: 64),
                "revision": 1, "title": "Board 1",
                "rules": [
                    "mode": "COOP", "minMembers": 2, "maxMembers": 4,
                    "joinPolicy": "OPEN", "rosterPolicy": "FIXED",
                    "replacementPolicy": "NONE", "reentryPolicy": "DENY",
                    "roundPolicy": "FIXED", "roundId": "round-1"
                ]
            ],
            "teamId": "11111111-1111-1111-1111-111111111111",
            "sessionId": "22222222-2222-2222-2222-222222222222",
            "teamVersion": 3,
            "version": 1,
            "usedUnits": 1,
            "remainingUnits": 3,
            "rollCount": 1,
            "movementStatus": "AVAILABLE",
            "arrivalProof": "NOT_PROVIDED",
            "ownershipEffect": "NONE",
            "pointsEffect": "NONE",
            "effectsStatus": "APPLIED",
            "rules": [
                "scope": "TEAM_ROUND", "unit": "ACTION",
                "refillPolicy": "NONE_WITHIN_ROUND",
                "chargeTiming": "COMMITTED_ACTION_EFFECT",
                "actionKind": "DICE_ROLL_AND_ACQUIRE",
                "resultPolicy": "DICE_UNIFIED_TRACK_ACQUISITION_EXPLICIT_CONFIRM",
                "totalUnits": 4, "rollCost": 1, "acquisitionCost": 2
            ],
            "dice": ["diceId": "dice-1", "faces": [1, 2], "weights": [1, 1]],
            "recentResults": [[
                "resultId": "33333333-3333-3333-3333-333333333333",
                "requestId": "req-1",
                "diceId": "dice-1",
                "createdAt": "2026-11-14T12:00:00.000Z",
                "effectsStatus": "APPLIED",
                "verifier": "SERVER_WEIGHTED_SECURE_RANDOM_V1",
                "rollNumber": 1,
                "costUnits": 1,
                "beforeUnits": 4,
                "afterUnits": 3,
                "faceIndex": 1,
                "budgetVersion": 1,
                "faceValue": 2,
                "previousPosition": 0,
                "newPosition": 2,
                "landedPropertyId": "prop-2"
            ]]
        ]
        let decoded = try JSONDecoder().decode(CityActionBudgetState.self, from: JSONSerialization.data(withJSONObject: json))
        try decoded.validate(region: "r1")
        XCTAssertEqual(decoded.recentResults.first?.newPosition, 2)
    }

    func testTerritoryServiceNearbyClaimCheckinAndLeaderboard() async throws {
        let stub = Stub()
        stub.answers["GET /prod-api/api/roam/territory/nearby"] = ok([
            "boardId": "b1",
            "regionId": "r1",
            "seasonId": "s1",
            "revenueMode": "POINTS",
            "items": [[
                "territoryId": "terr-1",
                "poiId": 42,
                "boardId": "b1",
                "seasonId": "s1",
                "propertyId": "prop-1",
                "pointId": "pt-1",
                "trackIndex": 0,
                "title": "West Gate Plaza",
                "latitude": 31.23,
                "longitude": 121.47,
                "radiusM": 120,
                "ownerMemberId": 77,
                "ownerNickname": "Alice",
                "claimed": true,
                "status": "PROTECTED",
                "isProtected": true,
                "checkinTollPoints": 10,
                "ownerRevenuePoints": 8,
                "checkinCount": 4,
                "revenueTotalPoints": 32,
                "distanceM": 18.5
            ]]
        ])
        stub.answers["POST /prod-api/api/roam/territory/claim"] = ok([
            "idempotentReplay": false,
            "territoryId": "terr-1",
            "boardId": "b1",
            "seasonId": "s1",
            "propertyId": "prop-1",
            "poiId": 42,
            "ownerMemberId": 99,
            "plausibilityStatus": "PLAUSIBLE",
            "proofMethod": "PHOTO_GPS",
            "protectionSeconds": 1800
        ])
        stub.answers["POST /prod-api/api/roam/territory/checkin"] = ok([
            "idempotentReplay": false,
            "checkinId": "chk-1",
            "territoryId": "terr-1",
            "ownerMemberId": 77,
            "selfVisit": false,
            "cooldownActive": false,
            "visitorPointsSpent": 0,
            "ownerRevenuePoints": 8,
            "revenueMode": "POINTS",
            "plausibilityStatus": "PLAUSIBLE",
            "distanceM": 15.0
        ])
        stub.answers["GET /prod-api/api/roam/territory/leaderboard"] = ok([
            "boardId": "b1",
            "seasonId": "s1",
            "revenueMode": "POINTS",
            "leaders": [[
                "ownerMemberId": 77,
                "ownerNickname": "Alice",
                "territoryCount": 2,
                "totalCheckins": 10,
                "totalRevenuePoints": 80
            ]],
            "topTerritories": [[
                "territoryId": "terr-1",
                "title": "West Gate Plaza",
                "boardId": "b1",
                "seasonId": "s1",
                "propertyId": "prop-1",
                "poiId": 42,
                "ownerMemberId": 77,
                "ownerNickname": "Alice",
                "checkinCount": 10,
                "revenueTotalPoints": 80
            ]]
        ])
        stub.answers["GET /prod-api/api/roam/territory/my"] = ok([])

        let service = try RoamTerritoryService(configuration: APIConfiguration(baseURL: base), token: "tok-1", lease: lease, transport: stub, isCurrent: { true })
        let nearby = try await service.nearby(lat: 31.23, lng: 121.47, boardId: "b1")
        XCTAssertEqual(nearby.revenueMode, "POINTS")
        XCTAssertEqual(nearby.items.first?.propertyId, "prop-1")

        let claim = try await service.claim(RoamTerritoryClaimRequest(requestId: "req-c1", lat: 31.23, lng: 121.47, photoUrl: "https://cdn.example.test/proof.jpg", poiId: 42, boardId: "b1", propertyId: "prop-1"))
        XCTAssertEqual(claim.proofMethod, "PHOTO_GPS")

        let checkin = try await service.checkin(RoamTerritoryCheckinRequest(requestId: "req-k1", territoryId: "terr-1", lat: 31.23, lng: 121.47))
        XCTAssertEqual(checkin.revenueMode, "POINTS")
        XCTAssertEqual(checkin.ownerRevenuePoints, 8)

        let board = try await service.leaderboard(boardId: "b1")
        XCTAssertEqual(board.leaders.first?.totalRevenuePoints, 80)

        let mine = try await service.myTerritories()
        XCTAssertTrue(mine.isEmpty)
    }
}
