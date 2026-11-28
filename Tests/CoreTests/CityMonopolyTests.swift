import XCTest
@testable import QuestifyCore

/// CITY-MONOPOLY-SPEC numbers + attributes v2: points-only rule tables, wire decoding, routes,
/// service envelope handling, screen models and haptic sequences.
private func monopolyDecode<T: Decodable>(_ type: T.Type, _ json: Any) throws -> T {
    try JSONDecoder().decode(type, from: JSONSerialization.data(withJSONObject: json))
}

@MainActor final class CityMonopolyTests: XCTestCase {
    // MARK: Fixtures

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

    @MainActor private final class FakeMonopoly: CityMonopolyReading {
        var seasonValue: CitySeasonCurrent?
        var maps: [CityTerritoryMapResponse] = []
        var quoteValue: CityTerritoryQuote?
        var commandResult: CityTerritoryCommandResult?
        var commandError: Error?
        var scoutBalance: Int64?
        var shieldBalance: Int64?
        var revenueValue: CityRevenuePage?
        var attributeResponses: [MemberAttributesResponse] = []
        var commands: [CityTerritoryCommandRequest] = []
        var equipped: [String?] = []
        private var mapIndex = 0
        private var attributesIndex = 0

        func territoryMap(bbox: String?, zoom: Int?) async throws -> CityTerritoryMapResponse {
            guard !maps.isEmpty else { throw RoamTerritoryError.rejected(status: 404, code: "NOT_FOUND", message: nil) }
            defer { mapIndex = min(mapIndex + 1, maps.count - 1) }
            return maps[mapIndex]
        }
        func property(_ propertyId: String) async throws -> CityTerritoryPropertyCard {
            try monopolyDecode(CityTerritoryPropertyCard.self, ["propertyId": propertyId, "holder": ["isMe": true], "estimatedYield": 35])
        }
        func claimQuote(_ payload: CityTerritoryQuoteRequest) async throws -> CityTerritoryQuote { try quote() }
        func claim(_ payload: CityTerritoryCommandRequest) async throws -> CityTerritoryCommandResult { try command(payload) }
        func upgradeQuote(_ payload: CityTerritoryQuoteRequest) async throws -> CityTerritoryQuote { try quote() }
        func upgrade(_ payload: CityTerritoryCommandRequest) async throws -> CityTerritoryCommandResult { try command(payload) }
        func challengeQuote(_ payload: CityTerritoryQuoteRequest) async throws -> CityTerritoryQuote { try quote() }
        func challenge(_ payload: CityTerritoryCommandRequest) async throws -> CityTerritoryCommandResult { try command(payload) }
        func scout(_ payload: CityPropertyActionRequest) async throws -> CityScoutResult {
            var json: [String: Any] = ["propertyId": payload.propertyId, "dc": 14, "cost": 10]
            if let scoutBalance { json["balance"] = scoutBalance }
            return try monopolyDecode(CityScoutResult.self, json)
        }
        func shield(_ payload: CityPropertyActionRequest) async throws -> CityShieldResult {
            var json: [String: Any] = ["propertyId": payload.propertyId, "cost": 60]
            if let shieldBalance { json["balance"] = shieldBalance }
            return try monopolyDecode(CityShieldResult.self, json)
        }
        func revenue(cursor: String?, day: String?) async throws -> CityRevenuePage {
            guard let revenueValue else { throw RoamTerritoryError.malformed }
            return revenueValue
        }
        func seasonCurrent() async throws -> CitySeasonCurrent {
            guard let seasonValue else { throw RoamTerritoryError.rejected(status: 404, code: "NO_SEASON", message: nil) }
            return seasonValue
        }
        func seasonLeaderboard(scope: CitySeasonScope, seasonId: String?) async throws -> CitySeasonLeaderboard {
            try monopolyDecode(CitySeasonLeaderboard.self, ["top": [], "around": []])
        }
        func memberAttributes() async throws -> MemberAttributesResponse {
            guard !attributeResponses.isEmpty else { throw RoamTerritoryError.malformed }
            defer { attributesIndex = min(attributesIndex + 1, attributeResponses.count - 1) }
            return attributeResponses[attributesIndex]
        }
        func attributeLedger(key: MemberAttributeKey?, cursor: String?) async throws -> MemberAttributeLedgerPage {
            try monopolyDecode(MemberAttributeLedgerPage.self, ["items": []])
        }
        func equipTitle(_ payload: MemberTitleEquipRequest) async throws -> MemberTitleEquipReceipt {
            equipped.append(payload.titleCode)
            return try monopolyDecode(MemberTitleEquipReceipt.self, ["equippedTitle": payload.titleCode.map { $0 as Any } ?? NSNull()])
        }

        private func quote() throws -> CityTerritoryQuote {
            guard let quoteValue else { throw RoamTerritoryError.malformed }
            return quoteValue
        }
        private func command(_ payload: CityTerritoryCommandRequest) throws -> CityTerritoryCommandResult {
            commands.append(payload)
            if let commandError { throw commandError }
            guard let commandResult else { throw RoamTerritoryError.malformed }
            return commandResult
        }
    }

    private let base = URL(string: "https://city.example.test/prod-api/")!
    private var lease: CityGameProductionLease { CityGameProductionLease(host: "city.example.test", regionID: "r1")! }

    private func ok(_ data: Any) -> (Int, Any) { (200, ["code": 200, "msg": "ok", "data": data]) }


    private func fix(lat: Double, lng: Double, accuracy: Double, at seconds: TimeInterval) throws -> RoamDeviceFix {
        try RoamDeviceFix(coordinate: XCTUnwrap(RoamCoordinate(latitude: lat, longitude: lng)), accuracyMeters: accuracy,
                          measuredAt: Date(timeIntervalSince1970: 1_800_000_000 + seconds), datum: .gcj02)
    }

    private func mapJSON(mine: [String], others: [String] = [], district: String = "d1") -> [String: Any] {
        let rows: [[String: Any]] = mine.map { ["propertyId": $0, "tier": 2, "lvl": 1, "districtId": district, "status": "HELD", "holder": ["isMe": true]] }
            + others.map { ["propertyId": $0, "tier": "T1", "districtId": district, "status": "AVAILABLE"] }
        return ["boardId": "b1", "seasonId": "s2026w46", "currency": "POINTS", "properties": rows]
    }

    // MARK: Lease and routes

    func testEveryMonopolyRouteIsLeasedAndAdmitted() throws {
        for path in CityMonopolyRoute.leasePaths {
            XCTAssertTrue(CityGameProductionLease.paths.contains(path), "Missing lease path: \(path)")
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall(path), "Not admitted: \(path)")
        }
        let evidence = CityTerritoryEvidence(capturedAt: 1, lat: 31, lng: 121, hAcc: 10, samples: [])
        let command = CityTerritoryCommandRequest(propertyId: "p1", quoteId: "q1", quoteHash: "h", evidence: evidence)
        let quote = CityTerritoryQuoteRequest(propertyId: "p1")
        let action = CityPropertyActionRequest(propertyId: "p1")
        let routes: [CityMonopolyRoute] = [
            .territoryMap(regionId: "r1", bbox: nil, zoom: nil), .property(propertyId: "0f8fad5b-d9cb-469f-a165-70867728950e"),
            .claimQuote(quote), .claimCommand(command), .upgradeQuote(quote), .upgradeCommand(command),
            .challengeQuote(quote), .challengeCommand(command), .scout(action), .shield(action),
            .revenue(cursor: nil, day: nil), .seasonCurrent(regionId: nil),
            .seasonLeaderboard(scope: .solo, seasonId: nil, aroundMe: true), .memberAttributes,
            .attributeLedger(key: nil, cursor: nil), .equipTitle(MemberTitleEquipRequest(titleCode: "ATTR_EXPLORE_10"))
        ]
        for route in routes {
            let request = try route.request(baseURL: base, token: "tok-1")
            let relative = String(try XCTUnwrap(request.url?.path).dropFirst("/prod-api/".count))
            XCTAssertTrue(CityMonopolyRoute.leasePaths.contains(ChinaReviewedRouteCapability.normalized(relative)), relative)
        }
    }

    func testCommandRouteEncodesUpperCaseRequestAndRejectsBadInput() throws {
        let evidence = CityTerritoryEvidence(capturedAt: 1_800_000_000_000, lat: 31.2, lng: 121.4, hAcc: 12,
            samples: [CityTerritoryLocationSample(t: 1_800_000_000_000, lat: 31.2, lng: 121.4, hAcc: 12)])
        let command = CityTerritoryCommandRequest(propertyId: "prop-1", quoteId: "q-1", quoteHash: "abc", expectedVersion: 3, evidence: evidence)
        XCTAssertEqual(command.requestId, command.requestId.uppercased())
        let request = try CityMonopolyRoute.upgradeCommand(command).request(baseURL: base, token: "tok-1")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/prod-api/api/city-game/territory/upgrade/command")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(body["quoteHash"] as? String, "abc")
        XCTAssertEqual(body["expectedVersion"] as? Int, 3)
        XCTAssertEqual((body["evidence"] as? [String: Any])?["simulated"] as? Bool, false)
        XCTAssertNil((body["evidence"] as? [String: Any])?["photoAssetId"])

        let lower = CityTerritoryCommandRequest(requestId: UUID().uuidString.lowercased(), propertyId: "prop-1",
            quoteId: "q-1", quoteHash: "abc", evidence: evidence)
        XCTAssertThrowsError(try CityMonopolyRoute.claimCommand(lower).request(baseURL: base, token: "tok-1"))
        XCTAssertThrowsError(try CityMonopolyRoute.territoryMap(regionId: "r1", bbox: "1,2,3", zoom: nil).request(baseURL: base, token: "tok-1"))
        XCTAssertThrowsError(try CityMonopolyRoute.revenue(cursor: nil, day: "15/11/2026").request(baseURL: base, token: "tok-1"))

        let board = try CityMonopolyRoute.seasonLeaderboard(scope: .team, seasonId: "s2026w46", aroundMe: true).request(baseURL: base, token: "tok-1")
        XCTAssertEqual(board.url?.query, "around=me&scope=team&seasonId=s2026w46")
    }

    // MARK: Rule tables (all points)

    func testTierUpgradeAndInvestedTables() {
        XCTAssertEqual(CityMonopolyTier.allCases.map(\.claimCost), [60, 120, 240, 400])
        XCTAssertEqual(CityMonopolyTier.allCases.map(\.baseYield), [3, 5, 8, 12])
        XCTAssertEqual((0..<3).compactMap { CityMonopolyRules.upgradeCost(tier: .t1, fromLevel: $0) }, [30, 48, 72])
        XCTAssertEqual((0..<3).compactMap { CityMonopolyRules.upgradeCost(tier: .t4, fromLevel: $0) }, [200, 320, 480])
        XCTAssertNil(CityMonopolyRules.upgradeCost(tier: .t2, fromLevel: 3))
        XCTAssertEqual(CityMonopolyTier.allCases.map { CityMonopolyRules.invested(tier: $0, level: 3) }, [210, 420, 840, 1400])
    }

    func testRentTableCapAndModifiers() {
        let expected: [CityMonopolyTier: [Int64]] = [.t1: [3, 4, 5, 7], .t2: [5, 7, 9, 12], .t3: [8, 11, 14, 19], .t4: [12, 17, 22, 29]]
        for (tier, row) in expected {
            XCTAssertEqual((0...3).map { CityMonopolyRules.rent(tier: tier, level: $0) }, row, tier.code)
        }
        // Multiplier cap 4.0: T4 at Lv3 + monopoly + golden hour + rain + event is 48.
        XCTAssertEqual(CityMonopolyRules.rent(tier: .t4, level: 3, district: .monopoly, timeBand: 1.2, environment: 2.0, teamBonus: true), 48)
        XCTAssertEqual(CityMonopolyRules.rent(tier: .t1, level: 0, timeBand: CityMonopolyRules.timeBand(hour: 23)), 0)
        XCTAssertEqual(CityMonopolyRules.timeBand(hour: 7), 1.1)
        XCTAssertEqual(CityMonopolyRules.timeBand(hour: 18), 1.2)
        XCTAssertEqual(CityMonopolyRules.rent(tier: .t3, level: 2, weathered: true), 7)
        XCTAssertEqual(CityDistrictControl(ownedShare: 0.5), .majority)
        XCTAssertEqual(CityDistrictControl(ownedShare: 1), .monopoly)
    }

    func testOwnerDailyCapsHoldingLimitAndProtection() {
        XCTAssertEqual(CityMonopolyRules.ownerDailyThreshold(charmLevel: 0), 200)
        XCTAssertEqual(CityMonopolyRules.ownerDailyThreshold(charmLevel: 50), 300)
        XCTAssertEqual(CityMonopolyRules.ownerDailyMax(charmLevel: 50), 400)
        XCTAssertEqual(CityMonopolyRules.ownerGrant(raw: 20, alreadyGranted: 190, charmLevel: 0), 15)
        XCTAssertEqual(CityMonopolyRules.ownerGrant(raw: 40, alreadyGranted: 290, charmLevel: 0), 10)
        XCTAssertEqual(CityMonopolyRules.ownerGrant(raw: 40, alreadyGranted: 300, charmLevel: 0), 0)
        XCTAssertEqual([0, 15, 30, 45, 50].map { CityMonopolyRules.holdingLimit(exploreLevel: $0) }, [9, 10, 11, 12, 12])
        XCTAssertEqual(CityMonopolyRules.claimProtectionHours(phase: .regular), 24)
        XCTAssertEqual(CityMonopolyRules.claimProtectionHours(phase: .finale), 12)
        XCTAssertEqual(CityMonopolyRules.scoutCost(loreLevel: 9), 10)
        XCTAssertEqual(CityMonopolyRules.scoutCost(loreLevel: 10), 0)
        XCTAssertEqual(CitySeasonPhase(seasonDay: 2), .opening)
        XCTAssertEqual(CitySeasonPhase(seasonDay: 22), .finale)
        XCTAssertNil(CitySeasonPhase(seasonDay: 29))
    }

    func testChallengeFeeDCModAndWinChance() {
        XCTAssertEqual(CityMonopolyRules.challengeFee(invested: 60), 30)
        XCTAssertEqual(CityMonopolyRules.challengeFee(invested: CityMonopolyRules.invested(tier: .t2, level: 1)), 90)
        XCTAssertEqual(CityMonopolyRules.challengeFee(invested: 1400), 700)
        XCTAssertEqual(CityMonopolyRules.challengeFee(invested: 1400, finale: true), 525)
        XCTAssertEqual(CityMonopolyRules.challengeFee(invested: 1400, revenge: true), 350)
        XCTAssertEqual(CityMonopolyRules.challengeDC(level: 0, ownerVisitedRecently: false, district: .none, weathered: true), 8)
        XCTAssertEqual(CityMonopolyRules.challengeDC(level: 3, ownerVisitedRecently: true, district: .monopoly, weathered: false), 20)
        XCTAssertEqual(CityMonopolyRules.challengeMod(taskScore: 2, insightLevel: 35, assists: 5, warmup: true, staminaLevel: 20), 6)
        XCTAssertEqual(CityMonopolyRules.challengeMod(taskScore: 1, insightLevel: 15, assists: 0), 2)
        XCTAssertEqual(CityMonopolyRules.winChancePercent(dc: 10, mod: 0), 55)
        XCTAssertEqual(CityMonopolyRules.winChancePercent(dc: 14, mod: 3), 50)
        XCTAssertEqual(CityMonopolyRules.winChancePercent(dc: 20, mod: 0), 5)
        XCTAssertEqual(CityMonopolyRules.winChancePercent(dc: 20, mod: 6), 35)
        XCTAssertEqual(CityMonopolyRules.winChancePercent(dc: 8, mod: 3), 80)
        XCTAssertTrue(CityMonopolyRules.challengerWins(roll: 20, mod: 0, dc: 20))
        XCTAssertFalse(CityMonopolyRules.challengerWins(roll: 1, mod: 6, dc: 2))
        XCTAssertEqual(CityMonopolyRules.feeSplit(fee: 100, challengerWon: true).defender, 40)
        XCTAssertEqual(CityMonopolyRules.feeSplit(fee: 100, challengerWon: false).burned, 70)
    }

    func testDecayStatesWithLoreGrace() {
        XCTAssertEqual(CityMonopolyRules.decayState(daysSinceOwnerVisit: 6), .ok)
        XCTAssertEqual(CityMonopolyRules.decayState(daysSinceOwnerVisit: 7), .weathered)
        XCTAssertEqual(CityMonopolyRules.decayState(daysSinceOwnerVisit: 14), .decaying)
        XCTAssertEqual(CityMonopolyRules.decayState(daysSinceOwnerVisit: 21), .released)
        XCTAssertEqual(CityMonopolyRules.decayState(daysSinceOwnerVisit: 7, loreLevel: 20), .ok)
        XCTAssertEqual(CityMonopolyRules.decayState(daysSinceOwnerVisit: 22, loreLevel: 40), .decaying)
        XCTAssertEqual(CityMonopolyRules.decayLevelDrops(daysSinceOwnerVisit: 13), 0)
        XCTAssertEqual(CityMonopolyRules.decayLevelDrops(daysSinceOwnerVisit: 14), 1)
        XCTAssertEqual(CityMonopolyRules.decayLevelDrops(daysSinceOwnerVisit: 17), 2)
    }

    // MARK: Attributes v2 rules

    func testAttributeCurveTitlesAndArchetype() {
        XCTAssertEqual(MemberAttributeRules.need(level: 1), 10)
        XCTAssertEqual(MemberAttributeRules.need(level: 2), 30)
        XCTAssertEqual(MemberAttributeRules.need(level: 25), 670)
        XCTAssertEqual(MemberAttributeRules.need(level: 26), 755)
        XCTAssertEqual(MemberAttributeRules.need(level: 49), 8825)
        XCTAssertNil(MemberAttributeRules.need(level: 50))
        XCTAssertEqual(MemberAttributeRules.cumulative(level: 15), 2185)
        XCTAssertEqual(MemberAttributeRules.cumulative(level: 30), 11440)
        XCTAssertEqual(MemberAttributeRules.cumulative(level: 50), 91010)
        XCTAssertEqual(MemberAttributeRules.level(forAXP: 0), 1)
        XCTAssertEqual(MemberAttributeRules.level(forAXP: 2185), 15)
        XCTAssertEqual(MemberAttributeRules.level(forAXP: 2184), 14)
        XCTAssertEqual(MemberAttributeRules.level(forAXP: 1_000_000), 50)
        XCTAssertEqual(MemberAttributeRules.effectiveDailyAXP(raw: 300, softCap: 200), 225)
        XCTAssertEqual(MemberAttributeRules.effectiveDailyAXP(raw: 1000, softCap: 40), 50)
        XCTAssertEqual(MemberAttributeKey.allCases.map(\.dailySoftCap), [200, 150, 150, 120, 40, 150])
        XCTAssertEqual(MemberAttributeRules.titleCode(key: .explore, level: 10), "ATTR_EXPLORE_10")
        XCTAssertEqual(MemberAttributeRules.titleName(code: "ATTR_LORE_50", chinese: true), "活地图")
        XCTAssertEqual(MemberAttributeRules.unlockedTitles(key: .luck, level: 30), ["ATTR_LUCK_10", "ATTR_LUCK_20", "ATTR_LUCK_30"])
        XCTAssertEqual(MemberAttributeRules.archetype(levels: [.explore: 30, .stamina: 10, .insight: 5, .charm: 5, .luck: 5, .lore: 5]), .rover)
        XCTAssertEqual(MemberAttributeRules.archetype(levels: [.explore: 10, .stamina: 10, .insight: 9, .charm: 9, .luck: 8, .lore: 10]), .polymath)
    }

    // MARK: Decoding

    func testTerritoryMapDecodesObjectArrayAndFog() throws {
        let object = try monopolyDecode(CityTerritoryMapResponse.self, [
            "boardId": "b1", "currency": "POINTS",
            "properties": [
                ["propertyId": "p1", "pointId": "pt1", "geohash7": "wtw3sjq", "tier": "T3", "districtId": "d1", "colorToken": "district.c2",
                 "status": "HELD", "lvl": 2, "decayState": "WEATHERED", "protectedUntil": "2026-11-15T10:00:00Z",
                 "holder": ["maskedName": "A**", "archetype": "rover", "title": ["code": "ATTR_EXPLORE_10"], "isMe": false, "isMyTeam": true]],
                ["districtId": "d1", "tier": 1]
            ]
        ])
        XCTAssertEqual(object.properties.count, 2)
        let lit = object.properties[0]
        XCTAssertEqual(lit.tier, .t3)
        XCTAssertEqual(lit.decay, .weathered)
        XCTAssertEqual(lit.holder?.archetype?.display(chinese: true), "漫游者")
        XCTAssertEqual(lit.holder?.title?.display(chinese: false), "Fog Walker")
        XCTAssertEqual(lit.protectedUntil?.millis, 1_794_736_800_000)
        XCTAssertTrue(object.properties[1].isFogged)
        XCTAssertFalse(lit.isFogged)

        let array = try monopolyDecode(CityTerritoryMapResponse.self, [["propertyId": "p9", "tier": 4, "protectedUntil": 1_800_000_000_000]])
        XCTAssertEqual(array.properties.first?.tier, .t4)
        XCTAssertEqual(array.properties.first?.protectedUntil?.millis, 1_800_000_000_000)
    }

    func testDeedQuoteAndCommandResultDecode() throws {
        let card = try monopolyDecode(CityTerritoryPropertyCard.self, [
            "propertyId": "p1", "tier": 2, "lvl": 1, "invested": 180, "dc": 13, "weeklyVisits": 9,
            "multipliers": ["U": 1.4, "S_set": 1.2, "T_time": 1.0], "decayState": "OK", "version": 7
        ])
        XCTAssertEqual(card.multipliers?["S_set"], 1.2)
        XCTAssertEqual(card.decay, .ok)
        XCTAssertEqual(card.version, 7)

        let quote = try monopolyDecode(CityTerritoryQuote.self, [
            "quoteId": "q1", "quoteHash": "h1", "fee": 90, "dc": 12, "task": ["taskId": "t1", "kind": "QUIZ", "title": "老城题"],
            "expiresAt": 1_800_000_300_000
        ])
        XCTAssertEqual(quote.price, 90)
        XCTAssertEqual(quote.task?.kind, "QUIZ")

        let result = try monopolyDecode(CityTerritoryCommandResult.self, [
            "outcome": "CHALLENGER_WON", "roll": 14, "nat": 14, "dc": 16, "total": 17,
            "mods": [1, ["source": "INSIGHT", "value": 2]],
            "feeSplit": ["fee": 90, "defender": 36, "burned": 54], "balance": 410
        ])
        XCTAssertEqual(result.kind, .challengerWon)
        XCTAssertEqual(result.mods?.map(\.value), [1, 2])
        XCTAssertEqual(result.mods?.last?.source, "INSIGHT")
        XCTAssertEqual(result.feeSplit?.defender, 36)
        XCTAssertEqual(CityTerritoryOutcomeKind(wire: "rejected"), .rejected)
    }

    func testSeasonLeaderboardRevenueAndVisitDecode() throws {
        let season = try monopolyDecode(CitySeasonCurrent.self, ["seasonId": "s2026w46", "dayIndex": 23, "myScore": 412.5, "myRank": 8, "holdingCount": 4, "holdingLimit": 10])
        XCTAssertEqual(season.seasonPhase, .finale)
        let board = try monopolyDecode(CitySeasonLeaderboard.self, [
            "seasonId": "s2026w46",
            "entries": [["rank": 1, "name": "A", "score": 900], ["rank": 2, "name": "B", "score": 800]],
            "aroundMe": [["rank": 2, "name": "B", "score": 800], ["rank": 14, "name": "Me", "score": 300, "isMe": true]]
        ])
        XCTAssertEqual(board.rows.map(\.rank), [1, 2, 14])
        let revenue = try monopolyDecode(CityRevenuePage.self, [
            "events": [["visitorMasked": "V**", "propertyId": "p1", "base": 5, "multipliers": ["U": 1.4], "granted": 7, "state": "PENDING", "capReason": NSNull()]],
            "todayPending": 7, "todayAvailable": 120, "threshold": 210
        ])
        XCTAssertEqual(revenue.events.first?.yieldState, .pending)
        XCTAssertEqual(revenue.threshold, 210)

        let receipt = try monopolyDecode(RoamTerritoryCheckinReceipt.self, [
            "selfVisit": false, "cooldownActive": false, "visitorPointsSpent": 0, "ownerRevenuePoints": 7, "revenueMode": "POINTS",
            "territory": ["propertyId": "p1", "holderMasked": "A**", "yield": 7, "visitorCoins": 2]
        ])
        XCTAssertEqual(receipt.territory?.yieldPoints, 7)
        XCTAssertEqual(receipt.territory?.visitorPoints, 2)
        let item = try monopolyDecode(RoamTerritoryItem.self, [
            "latitude": 31.2, "longitude": 121.4, "radiusM": 50, "claimed": true, "status": "HELD", "isProtected": false,
            "checkinTollPoints": 0, "ownerRevenuePoints": 5, "checkinCount": 1, "revenueTotalPoints": 5,
            "tier": "T2", "upgradeLevel": 1, "decayState": "WEATHERED"
        ])
        XCTAssertEqual(item.tier, .t2)
        XCTAssertEqual(item.upgradeLevel, 1)
    }

    func testAttributesDecodeProgressAndTitles() throws {
        let response = try monopolyDecode(MemberAttributesResponse.self, [
            "attrs": [
                ["key": "lore", "level": 3, "axp": 60, "need": 45, "todayAxp": 12, "softCap": 150, "nextUnlock": ["level": 10, "effect": "免费侦察"]],
                ["key": "explore", "level": 15, "axp": 2300, "need": 355, "todayAxp": 40, "softCap": 200, "nextUnlock": "Lv30 地图剪影"]
            ],
            "archetype": ["code": "rover", "name": "远征漫游者"],
            "equippedTitle": "ATTR_EXPLORE_10",
            "seasonDelta": ["explore": 3],
            "titles": [["titleCode": "ATTR_EXPLORE_10", "category": "ATTR", "equipped": true]]
        ])
        XCTAssertEqual(response.orderedAttrs.map(\.key), ["explore", "lore"])
        XCTAssertEqual(response.level(of: .explore), 15)
        let explore = response.orderedAttrs[0]
        XCTAssertEqual(explore.levelProgress?.current, 115)
        XCTAssertEqual(explore.remainingToNextLevel, 240)
        XCTAssertEqual(explore.nextUnlock?.display(chinese: true), "Lv30 地图剪影")
        let lore = response.orderedAttrs[1]
        XCTAssertEqual(lore.levelProgress?.current, 20)
        XCTAssertEqual(lore.nextUnlock?.level, 10)
        XCTAssertEqual(response.archetype?.display(chinese: true), "远征漫游者")
        XCTAssertEqual(response.equippedTitle?.display(chinese: true), "迷雾行者")
        XCTAssertEqual(response.titles?.first?.display(chinese: false), "Fog Walker")
    }

    // MARK: Service envelope

    func testServiceDecodesEnvelopeAndMapsFailures() async throws {
        let stub = Stub()
        stub.answers["GET /prod-api/api/city-game/territory/revenue"] = ok(["events": [], "todayPending": 0, "todayAvailable": 300, "threshold": 200])
        stub.answers["GET /prod-api/api/member/attributes"] = (401, ["code": 401, "msg": "login"])
        stub.answers["POST /prod-api/api/city-game/territory/scout"] = (409, ["code": 409, "msg": "busy", "errorCode": "CITY_CHALLENGE_ACTIVE"])
        var unauthorized = 0
        let service = try CityMonopolyService(configuration: APIConfiguration(baseURL: base), token: "tok-1", lease: lease,
            transport: stub, isCurrent: { true }, onUnauthorized: { unauthorized += 1 })
        let revenue = try await service.revenue(cursor: nil, day: "2026-11-15")
        XCTAssertEqual(revenue.todayAvailable, 300)
        XCTAssertEqual(stub.requests.last?.url?.query, "day=2026-11-15")
        do {
            _ = try await service.memberAttributes()
            XCTFail("expected unauthorized")
        } catch {
            XCTAssertEqual(error as? RoamTerritoryError, .unauthorized)
        }
        XCTAssertEqual(unauthorized, 1)
        do {
            _ = try await service.scout(CityPropertyActionRequest(propertyId: "p1"))
            XCTFail("expected rejection")
        } catch {
            XCTAssertEqual(error as? RoamTerritoryError, .rejected(status: 409, code: "CITY_CHALLENGE_ACTIVE", message: "busy"))
        }
        let season = try? await service.seasonCurrent()
        XCTAssertNil(season)
        XCTAssertEqual(stub.requests.last?.url?.query, "regionId=r1")
    }

    // MARK: Screen models

    func testTerritoryModelReloadQuoteConfirmAndHaptics() async throws {
        let fake = FakeMonopoly()
        fake.maps = [try monopolyDecode(CityTerritoryMapResponse.self, mapJSON(mine: ["p1"], others: ["p2", "p3"]))]
        fake.seasonValue = try monopolyDecode(CitySeasonCurrent.self, ["seasonId": "s2026w46", "phase": "REGULAR"])
        var balance: Int64 = 500
        let model = CityMonopolyTerritoryModel(service: fake, pointsSource: { balance })
        await model.reload()
        XCTAssertEqual(model.pointsBalance, 500)
        XCTAssertEqual(model.mine.map(\.propertyId), ["p1"])
        XCTAssertEqual(model.holdings().count, 1)
        XCTAssertEqual(model.holdings(exploreLevel: 30).limit, 11)
        XCTAssertNil(model.haptic)

        fake.quoteValue = try monopolyDecode(CityTerritoryQuote.self, ["quoteId": "q1", "quoteHash": "h1", "cost": 60, "toLevel": 2, "version": 4])
        await model.requestQuote(.upgrade, propertyId: "p1", fix: nil)
        XCTAssertEqual(model.pendingQuote?.kind, .upgrade)
        XCTAssertEqual(model.pendingQuote?.quote.price, 60)

        let noFixes = await model.confirm(fixes: [])
        XCTAssertNil(noFixes)
        XCTAssertEqual(model.issueCode, "LOCATION_REQUIRED")
        XCTAssertEqual(model.haptic?.event, .presenceCheckFailed)

        fake.commandResult = try monopolyDecode(CityTerritoryCommandResult.self, ["outcome": "APPLIED", "balance": 440])
        let fixes = try [0.0, 30, 60].map { try fix(lat: 31.2, lng: 121.4, accuracy: 10, at: $0) }
        let result = await model.confirm(fixes: fixes)
        XCTAssertEqual(result?.kind, .applied)
        XCTAssertEqual(model.pointsBalance, 440, "command balance stands when GET /territory/points 404s and the wallet source is still 500")
        XCTAssertEqual(model.haptic?.event, .upgraded)
        XCTAssertNil(model.pendingQuote)
        XCTAssertEqual(fake.commands.first?.expectedVersion, 4)
        XCTAssertEqual(fake.commands.first?.evidence.samples.count, 3)
        XCTAssertEqual(fake.commands.first?.quoteHash, "h1")
        balance = 440
        await model.reload()
        XCTAssertEqual(model.pointsBalance, 440)

        fake.scoutBalance = 430
        await model.scout(propertyId: "p2")
        XCTAssertEqual(model.pointsBalance, 430, "scout balance stands when the points read 404s")
        fake.shieldBalance = 370
        await model.shield(propertyId: "p1")
        XCTAssertEqual(model.pointsBalance, 370, "shield balance stands when the points read 404s and the wallet source is still 440")
        XCTAssertEqual(balance, 440)
    }

    func testTerritoryModelChallengeLossPropertyLossDistrictAndRevenue() async throws {
        let fake = FakeMonopoly()
        fake.maps = [
            try monopolyDecode(CityTerritoryMapResponse.self, mapJSON(mine: ["p1"], others: ["p2", "p3"])),
            try monopolyDecode(CityTerritoryMapResponse.self, mapJSON(mine: ["p1", "p2"], others: ["p3"])),
            try monopolyDecode(CityTerritoryMapResponse.self, mapJSON(mine: ["p2"], others: ["p1", "p3"]))
        ]
        let model = CityMonopolyTerritoryModel(service: fake)
        await model.reload()
        XCTAssertNil(model.haptic)
        XCTAssertEqual(CityMonopolyTerritoryModel.districtControl(model.map?.properties ?? [])["d1"], CityDistrictControl.none)
        await model.reload()
        XCTAssertEqual(model.haptic?.event, .districtControl)
        await model.reload()
        XCTAssertEqual(model.haptic?.event, .propertyLost)

        fake.quoteValue = try monopolyDecode(CityTerritoryQuote.self, ["quoteId": "q2", "quoteHash": "h2", "fee": 30, "dc": 12])
        await model.requestQuote(.challenge, propertyId: "p3", fix: nil)
        XCTAssertEqual(model.scoutedDC["p3"], 12)
        fake.commandResult = try monopolyDecode(CityTerritoryCommandResult.self, ["outcome": "LOST", "roll": 5, "dc": 12, "total": 7])
        _ = await model.confirm(fixes: [try fix(lat: 31.2, lng: 121.4, accuracy: 8, at: 0)])
        XCTAssertEqual(model.haptic?.event, .takeoverLost)

        fake.revenueValue = try monopolyDecode(CityRevenuePage.self, ["events": [], "todayPending": 40, "todayAvailable": 200])
        await model.loadRevenue()
        XCTAssertEqual(model.haptic?.event, .rentCountUp(points: 240))

        await model.scout(propertyId: "p2")
        XCTAssertEqual(model.scoutedDC["p2"], 14)
        XCTAssertNil(model.pointsBalance, "a scout reply with no balance does not invent one")
        XCTAssertEqual(CityMonopolyTerritoryModel.hapticEvent(for: .claim, result: try monopolyDecode(CityTerritoryCommandResult.self, ["outcome": "APPLIED"])), .claimSucceeded)
        XCTAssertEqual(CityMonopolyTerritoryModel.hapticEvent(for: .claim, result: try monopolyDecode(CityTerritoryCommandResult.self, ["outcome": "REJECTED"])), .presenceCheckFailed)
    }

    func testAttributesModelLevelUpTitleUnlockAndEquip() async throws {
        let first: [String: Any] = ["attrs": [["key": "explore", "level": 9, "axp": 700, "need": 185]], "titles": []]
        let levelled: [String: Any] = ["attrs": [["key": "explore", "level": 10, "axp": 900, "need": 215]], "titles": []]
        let titled: [String: Any] = ["attrs": [["key": "explore", "level": 10, "axp": 950, "need": 215]],
                                     "titles": [["code": "ATTR_EXPLORE_10"]], "equippedTitle": "ATTR_EXPLORE_10"]
        let fake = FakeMonopoly()
        fake.attributeResponses = try [first, levelled, titled].map { try monopolyDecode(MemberAttributesResponse.self, $0) }
        let model = MemberAttributesModel(service: fake)
        await model.load()
        XCTAssertNil(model.haptic)
        XCTAssertEqual(model.attributes?.level(of: .explore), 9)
        await model.load()
        XCTAssertEqual(model.haptic?.event, .attributeLevelUp)
        await model.equip(titleCode: "ATTR_EXPLORE_10")
        XCTAssertEqual(fake.equipped, ["ATTR_EXPLORE_10"])
        XCTAssertEqual(model.haptic?.event, .titleUnlocked)
        XCTAssertEqual(model.titles.map(\.code), ["ATTR_EXPLORE_10"])
        XCTAssertNil(model.issueCode)
    }

    // MARK: Presence preflight and haptics

    func testPresencePreflightDetailsAndEvidence() throws {
        let anchor = try XCTUnwrap(RoamCoordinate(latitude: 31.2, longitude: 121.4))
        let poor = [try fix(lat: 31.2, lng: 121.4, accuracy: 41, at: 0)]
        let checks = CityPresencePreflight.evaluate(fixes: poor, anchor: anchor, requirePhoto: true, hasPhoto: false)
        XCTAssertEqual(checks.map(\.kind), [.distance, .accuracy, .dwell, .photo])
        XCTAssertEqual(checks.map(\.passed), [true, false, false, false])
        XCTAssertEqual(checks[1].detail(chinese: true), "定位精度 41 m，需要 ≤ 25 m，走到开阔处")

        let good = try [0.0, 30, 65].map { try fix(lat: 31.2001, lng: 121.4, accuracy: 9, at: $0) }
        XCTAssertTrue(CityPresencePreflight.evaluate(fixes: good, anchor: anchor, requirePhoto: false, hasPhoto: false).allSatisfy(\.passed))
        let far = try fix(lat: 31.21, lng: 121.4, accuracy: 9, at: 0)
        XCTAssertGreaterThan(CityPresencePreflight.distanceM(far.coordinate, anchor), 1000)

        let evidence = try XCTUnwrap(CityPresencePreflight.evidence(fixes: good))
        XCTAssertEqual(evidence.samples.count, 3)
        XCTAssertEqual(evidence.capturedAt, 1_800_000_065_000)
        XCTAssertEqual(evidence.hAcc, 9)
        XCTAssertNil(CityPresencePreflight.evidence(fixes: []))
    }

    func testHapticSequencesRespectCooldownAndSpec() {
        let events: [CityMonopolyHapticEvent] = [
            .claimSucceeded, .presenceChecks(passed: 3, failed: true), .presenceCheckFailed, .rentCountUp(points: 500),
            .takeoverWon, .takeoverLost, .propertyLost, .defenseHeld, .upgraded, .districtControl, .attributeLevelUp, .titleUnlocked
        ]
        for event in events {
            let steps = event.steps
            XCTAssertFalse(steps.isEmpty, "\(event)")
            XCTAssertEqual(steps.first?.delayMs, 0)
            XCTAssertTrue(steps.dropFirst().allSatisfy { $0.delayMs >= CityMonopolyHapticEvent.minimumIntervalMs }, "\(event)")
        }
        XCTAssertEqual(CityMonopolyHapticEvent.claimSucceeded.steps.map(\.cue), [.impactHeavy, .success])
        XCTAssertEqual(CityMonopolyHapticEvent.claimSucceeded.steps.last?.delayMs, 450)
        XCTAssertEqual(CityMonopolyHapticEvent.takeoverLost.steps.suffix(2).map(\.cue), [.impactHeavy, .error])
        XCTAssertEqual(CityMonopolyHapticEvent.defenseHeld.steps.map(\.cue), [.impactRigid, .impactRigid, .success])
        XCTAssertEqual(CityMonopolyHapticEvent.districtControl.steps.map(\.delayMs), [0, 300])
        XCTAssertEqual(CityMonopolyHapticEvent.rentCountUp(points: 500).steps.count, 13)
        XCTAssertEqual(CityMonopolyHapticEvent.rentCountUp(points: 30).steps.map(\.cue), [.selection, .selection, .selection, .impactLight])
        XCTAssertTrue(CityMonopolyHapticEvent.rentCountUp(points: 5).steps.isEmpty)
        XCTAssertEqual(CityMonopolyHapticEvent.presenceChecks(passed: 2, failed: false).steps.map(\.cue), [.selection, .selection])
        XCTAssertEqual(CityMonopolyHapticEvent.presenceChecks(passed: 0, failed: true).steps.map(\.cue), [.warning])
    }

    func testFormattingUsesPointsOnly() {
        XCTAssertEqual(CityMonopolyFormat.points(120, chinese: true), "120 积分")
        XCTAssertEqual(CityMonopolyFormat.points(120, chinese: false), "120 pts")
        XCTAssertEqual(CityMonopolyFormat.countdown(seconds: 90_000, chinese: true), "1天1小时")
        XCTAssertEqual(CityMonopolyFormat.countdown(seconds: 3_900, chinese: false), "1h 5m")
        XCTAssertEqual(CityMonopolyFormat.multiplier(1.4), "×1.40")
        XCTAssertEqual(CityMonopolyRules.currency, "POINTS")
        // One currency: no city-coin wallet route is leased.
        XCTAssertFalse(CityMonopolyRoute.leasePaths.contains { $0.contains("wallet") || $0.contains("purchase") })
    }
}
