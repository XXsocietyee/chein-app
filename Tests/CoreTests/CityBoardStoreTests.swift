import XCTest
@testable import QuestifyCore

/// City board store + the live-server contract fixes (backend `ApiCityMonopolyController`,
/// integration/backend-app-r3): bbox query, claim / territory target keys, `mods` as a map,
/// `territories` on nearby, geohash fog, district slots and the merge of the two reads.
@MainActor final class CityBoardStoreTests: XCTestCase {
    private let base = URL(string: "https://city.example.test/prod-api/")!

    private func decode<T: Decodable>(_ type: T.Type, _ json: Any) throws -> T {
        try JSONDecoder().decode(type, from: JSONSerialization.data(withJSONObject: json))
    }

    private final class Stub: HTTPTransport {
        var requests: [URLRequest] = []
        var answers: [String: Any] = [:]
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            let key = (request.httpMethod ?? "") + " " + (request.url?.path ?? "")
            guard let body = answers[key] else {
                return (try JSONSerialization.data(withJSONObject: ["code": 404, "msg": "missing", "errorCode": "NOT_FOUND"]), 404)
            }
            return (try JSONSerialization.data(withJSONObject: ["code": 200, "data": body]), 200)
        }
    }

    func testLiveRoutesUseServerKeysAndAreLeased() throws {
        let bounds = CityMapBounds(minLat: 31.2, minLng: 121.4, maxLat: 31.3, maxLng: 121.5)
        let map = try CityMonopolyRoute.territoryMapBounds(bounds).request(baseURL: base, token: "tok-1")
        XCTAssertEqual(map.url?.path, "/prod-api/api/city-game/territory/map")
        XCTAssertEqual(map.url?.query, "maxLat=31.300000&maxLng=121.500000&minLat=31.200000&minLng=121.400000")
        let points = try CityMonopolyRoute.points.request(baseURL: base, token: "tok-1")
        XCTAssertEqual(points.url?.path, "/prod-api/api/city-game/territory/points")
        XCTAssertTrue(CityGameProductionLease.paths.contains("/api/city-game/territory/points"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/city-game/territory/points"))

        let wide = CityMapBounds(minLat: 30, minLng: 120, maxLat: 32, maxLng: 122)
        XCTAssertTrue(wide.isValid)
        XCTAssertLessThanOrEqual(wide.maxLat - wide.minLat, 0.5)

        let claim = CityTerritoryQuoteRequest(propertyId: "poi-7", poiId: 7, boardId: "b1", pointId: "pt-a")
        let claimBody = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(try CityMonopolyRoute.claimQuote(claim).request(baseURL: base, token: "tok-1").httpBody)) as? [String: Any])
        XCTAssertEqual(claimBody["poiId"] as? Int, 7)
        XCTAssertEqual(claimBody["boardId"] as? String, "b1")
        XCTAssertEqual(claimBody["pointId"] as? String, "pt-a")
        XCTAssertNil(claimBody["territoryId"])

        let shield = try CityMonopolyRoute.shield(CityPropertyActionRequest(propertyId: "t-1")).request(baseURL: base, token: "tok-1")
        let shieldBody = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(shield.httpBody)) as? [String: Any])
        XCTAssertEqual(shieldBody["territoryId"] as? String, "t-1")
    }

    func testPlaceQuoteRequestNamesTheRightTarget() throws {
        let coordinate = try XCTUnwrap(RoamCoordinate(latitude: 31.2, longitude: 121.4))
        let open = CityPlace(id: "poi-7", title: "人民广场", coordinate: coordinate, poiId: 7, boardId: "b1", pointId: "pt-a", ownership: .open)
        let claim = open.quoteRequest(.claim, fix: nil)
        XCTAssertEqual(claim.poiId, 7); XCTAssertEqual(claim.pointId, "pt-a"); XCTAssertNil(claim.territoryId)
        let held = CityPlace(id: "t-9", title: "书店", coordinate: coordinate, territoryId: "t-9", poiId: 7, ownership: .other)
        let challenge = held.quoteRequest(.challenge, fix: nil)
        XCTAssertEqual(challenge.territoryId, "t-9"); XCTAssertNil(challenge.poiId); XCTAssertNil(challenge.boardId)
    }

    func testCommandResultDecodesModsMapAndTaskFailure() throws {
        let win = try decode(CityTerritoryCommandResult.self, ["outcome": "WIN", "roll": 14, "nat": NSNull(), "mods": ["task": 2, "insight": 1, "warmup": 0],
                                                               "dc": 12, "total": 17, "feeSplit": ["fee": 90, "defenderComp": 36, "burned": 54, "refund": 0]])
        XCTAssertEqual(win.kind, .challengerWon)
        XCTAssertEqual(win.modifierTotal, 3)
        XCTAssertEqual(win.feeSplit?.toDefender, 36)
        let list = try decode(CityTerritoryCommandResult.self, ["outcome": "LOSS", "mods": [["source": "task", "value": 1]]])
        XCTAssertEqual(list.modifierTotal, 1)
        let failed = try decode(CityTerritoryCommandResult.self, ["outcome": "TASK_FAILED"])
        XCTAssertTrue(failed.taskFailed)
    }

    func testNearbyAcceptsTerritoriesKeyAndCardAcceptsLiveNames() throws {
        let item: [String: Any] = ["poiId": 1, "title": "人民广场", "latitude": 31.23, "longitude": 121.47, "radiusM": 80, "claimed": false,
                                   "status": "AVAILABLE", "isProtected": false, "checkinTollPoints": 5, "ownerRevenuePoints": 5,
                                   "checkinCount": 0, "revenueTotalPoints": 0]
        let nearby = try decode(RoamTerritoryNearbyResponse.self, ["revenueMode": "POINTS", "territories": [item]])
        XCTAssertEqual(nearby.items.count, 1)
        let card = try decode(CityTerritoryPropertyCard.self, ["propertyId": "t-1", "deedPhoto": "https://x.invalid/a.jpg", "visitsThisWeek": 4])
        XCTAssertEqual(card.photoURL, "https://x.invalid/a.jpg")
        XCTAssertEqual(card.visits, 4)
        let season = try decode(CitySeasonCurrent.self, ["seasonId": "s2026w46", "day": 8])
        XCTAssertEqual(season.seasonDay, 8)
        XCTAssertEqual(season.seasonPhase, .regular)
    }

    func testGeohashCentreAndDistrictSlots() throws {
        let centre = try XCTUnwrap(CityGeohash.center("ws0e96s"))
        XCTAssertEqual(centre.latitude, 23.129, accuracy: 0.002)
        XCTAssertEqual(centre.longitude, 113.264, accuracy: 0.002)
        XCTAssertNil(CityGeohash.center("ws0e9a!"))
        let slots = CityDistrictSlots.slots(for: ["d2", "d1", nil, "d2", "d7", "d3", "d4", "d5", "d6"])
        XCTAssertEqual(slots["d1"], 1); XCTAssertEqual(slots["d2"], 2); XCTAssertEqual(slots["d7"], 1)
    }

    func testMergeJoinsSpacesWithTheLayerAndKeepsFogAsSilhouettes() throws {
        let spaces = try decode(RoamTerritoryNearbyResponse.self, ["revenueMode": "POINTS", "territories": [
            ["poiId": 1, "title": "人民广场", "latitude": 31.23, "longitude": 121.47, "radiusM": 80, "claimed": false, "status": "AVAILABLE",
             "isProtected": false, "checkinTollPoints": 5, "ownerRevenuePoints": 5, "checkinCount": 0, "revenueTotalPoints": 0],
            ["territoryId": "t-2", "poiId": 2, "title": "江边步道", "latitude": 31.255, "longitude": 121.495, "radiusM": 80, "claimed": true,
             "ownerMemberId": 9004, "status": "CLAIMED", "isProtected": false, "checkinTollPoints": 5, "ownerRevenuePoints": 5,
             "checkinCount": 0, "revenueTotalPoints": 0]
        ]]).items
        let layer = try decode(CityTerritoryMapResponse.self, ["items": [
            ["propertyId": "t-2", "title": "江边步道", "tier": 2, "lvl": 1, "districtId": "d2", "holder": ["maskedName": "小*", "isMe": false],
             "lat": 31.255, "lng": 121.495, "invested": 180],
            ["propertyId": "t-3", "title": "骑楼口", "tier": 1, "lvl": 0, "districtId": "d1", "holder": ["maskedName": "我", "isMe": true],
             "lat": 31.24, "lng": 121.48, "protectedUntil": 4_102_444_800_000],
            ["districtId": "d1", "tier": 1, "geohash7": "wtw3sjq"]
        ]]).properties
        let centre = try XCTUnwrap(RoamCoordinate(latitude: 31.23, longitude: 121.47))
        let places = CityBoardStore.merge(spaces: spaces, layer: layer, memberID: 9009, center: centre)
        XCTAssertEqual(places.count, 4)
        XCTAssertEqual(places.first?.title, "人民广场")
        XCTAssertEqual(places.first?.ownership, .open)
        let river = try XCTUnwrap(places.first { $0.territoryId == "t-2" })
        XCTAssertEqual(river.ownership, .other); XCTAssertEqual(river.level, 1); XCTAssertEqual(river.districtIndex, 2)
        XCTAssertEqual(river.challengeFeePreview, 90)
        let mine = try XCTUnwrap(places.first { $0.territoryId == "t-3" })
        XCTAssertEqual(mine.ownership, .mine); XCTAssertTrue(mine.isProtected(now: Date()))
        XCTAssertEqual(places.filter { $0.ownership == .fogged }.count, 1)
    }

    /// Hook for fix/city-gaps-r3: a district name and deed serial on the layer reach the place; without them the
    /// place keeps nil (the deed band falls back to "街区 N" and shows no serial).
    func testDistrictNameAndDeedSerialHookPassesThroughTheMerge() throws {
        let layer = try decode(CityTerritoryMapResponse.self, ["items": [
            ["propertyId": "t-9", "title": "老麦咖啡馆", "tier": 1, "lvl": 0, "districtId": "d7", "districtName": "武康路街区",
             "deedSerial": 12, "holder": ["maskedName": "我", "isMe": true], "lat": 31.21, "lng": 121.44],
            ["propertyId": "t-8", "title": "转角花店", "tier": 1, "lvl": 0, "districtId": "d7", "districtName": "  ",
             "holder": ["maskedName": "我", "isMe": true], "lat": 31.22, "lng": 121.45]
        ]]).properties
        let places = CityBoardStore.merge(spaces: [], layer: layer, memberID: 9009, center: nil)
        let named = try XCTUnwrap(places.first { $0.territoryId == "t-9" })
        XCTAssertEqual(named.districtName, "武康路街区")
        XCTAssertEqual(named.deedSerial, 12)
        let blank = try XCTUnwrap(places.first { $0.territoryId == "t-8" })
        XCTAssertNil(blank.districtName, "a blank name is no name")
        XCTAssertNil(blank.deedSerial)
    }

    /// fix/city-gaps-r3 live fields: `districts[]` names and colour keys (placeholder seed = no name), item colour
    /// tokens, nearby `deedSerial`, and fogged items keep the public district name but never a serial.
    func testGapsR3DistrictsColourKeysAndDeedSerialReachThePlaces() throws {
        let nearby = try decode(RoamTerritoryNearbyResponse.self, ["revenueMode": "POINTS", "boardId": "gz", "territories": [
            ["boardId": "gz", "pointId": "p1", "title": "北京路口", "latitude": 23.12, "longitude": 113.26, "radiusM": 80, "claimed": false,
             "status": "AVAILABLE", "isProtected": false, "checkinTollPoints": 0, "ownerRevenuePoints": 0, "checkinCount": 0,
             "revenueTotalPoints": 0, "districtId": "d2", "deedSerial": 7],
            ["boardId": "gz", "pointId": "p2", "title": "上下九", "latitude": 23.121, "longitude": 113.261, "radiusM": 80, "claimed": false,
             "status": "AVAILABLE", "isProtected": false, "checkinTollPoints": 0, "ownerRevenuePoints": 0, "checkinCount": 0,
             "revenueTotalPoints": 0, "districtId": "d9", "districtColorToken": "district.c5"]
        ], "districts": [
            ["boardId": "gz", "districtId": "d2", "name": "北京路", "colorToken": "district.c4", "colorIndex": 4, "ownableCount": 6, "safetyBlocked": false],
            ["boardId": "gz", "districtId": "d9", "name": "d9", "colorToken": "brand.x", "ownableCount": 3, "safetyBlocked": false]
        ]])
        XCTAssertEqual(nearby.districts.count, 2)
        let map = try decode(CityTerritoryMapResponse.self, ["items": [
            ["districtId": "d2", "tier": 1, "geohash7": "ws0e9cb", "districtName": "北京路", "districtColorToken": "district.c4", "deedSerial": 3]
        ], "districts": []])
        let places = CityBoardStore.merge(spaces: nearby.items, layer: map.properties, memberID: nil, center: nil,
                                          districts: nearby.districts + map.districts)
        let named = try XCTUnwrap(places.first { $0.pointId == "p1" })
        XCTAssertEqual(named.districtName, "北京路"); XCTAssertEqual(named.districtIndex, 4); XCTAssertEqual(named.deedSerial, 7)
        let seeded = try XCTUnwrap(places.first { $0.pointId == "p2" })
        XCTAssertNil(seeded.districtName, "the placeholder seed (name == id) falls back to 街区 N")
        XCTAssertEqual(seeded.districtIndex, 5, "the item's own district.cN key wins")
        let fog = try XCTUnwrap(places.first { $0.ownership == .fogged })
        XCTAssertEqual(fog.districtName, "北京路"); XCTAssertNil(fog.deedSerial)
        XCTAssertEqual(CityDistrictInfo.slot(index: nil, token: "district.c8"), 2)
        XCTAssertNil(CityDistrictInfo.slot(index: nil, token: "district.cx"))
    }

    func testStoreLoadsQuotesAndReportsRejectionsAndLosses() async throws {
        let stub = Stub()
        let lease = try XCTUnwrap(CityGameProductionLease(host: "city.example.test", regionID: "r1"))
        let mapPath = "GET /prod-api/api/city-game/territory/map"
        stub.answers[mapPath] = ["items": [["propertyId": "t-3", "title": "骑楼口", "tier": 1, "lvl": 0, "districtId": "d1",
                                            "holder": ["maskedName": "我", "isMe": true], "lat": 31.231, "lng": 121.471]], "currency": "POINTS"]
        stub.answers["GET /prod-api/api/city-game/territory/points"] = ["currency": "POINTS", "balance": 469, "holdings": 1, "holdingLimit": 9]
        stub.answers["GET /prod-api/api/city-game/season/current"] = ["seasonId": "s2026w46", "phase": "REGULAR", "day": 8]
        stub.answers["GET /prod-api/api/city-game/territory/revenue"] = ["events": [], "todayPending": 12, "todayAvailable": 30]
        stub.answers["POST /prod-api/api/city-game/territory/claim/quote"] = ["quoteId": "q1", "quoteHash": "h", "cost": 60, "protectionHours": 24]
        stub.answers["POST /prod-api/api/city-game/territory/claim/command"] = ["outcome": "REJECTED", "reasons": ["APP_ATTEST_REQUIRED"], "balance": 469]
        let service = try CityMonopolyService(configuration: APIConfiguration(baseURL: base), token: "tok-1", lease: lease,
                                              transport: stub, isCurrent: { true })
        let nearby: CityNearbyRead = { _ in
            try JSONDecoder().decode(RoamTerritoryNearbyResponse.self, from: JSONSerialization.data(withJSONObject: ["revenueMode": "POINTS", "territories": [
                ["poiId": 1, "title": "人民广场", "latitude": 31.23, "longitude": 121.47, "radiusM": 80, "claimed": false, "status": "AVAILABLE",
                 "isProtected": false, "checkinTollPoints": 5, "ownerRevenuePoints": 5, "checkinCount": 0, "revenueTotalPoints": 0]]]))
        }
        let store = CityBoardStore(service: service, nearby: nearby, memberID: 9009)
        let centre = try XCTUnwrap(RoamCoordinate(latitude: 31.23, longitude: 121.47))
        await store.load(center: centre)
        XCTAssertEqual(store.phase, .loaded)
        XCTAssertEqual(store.mine.map(\.territoryId), ["t-3"])
        XCTAssertEqual(store.holdings?.count, 1); XCTAssertEqual(store.holdings?.limit, 9)
        XCTAssertEqual(store.todayRent, 42)
        XCTAssertTrue(stub.requests.contains { $0.url?.query?.contains("minLat=") == true })

        let open = try XCTUnwrap(store.places.first { $0.ownership == .open })
        await store.quote(.claim, place: open, fix: nil)
        XCTAssertEqual(store.pendingQuote?.quote.price, 60)
        let fixes = try (0..<4).map { step in
            try RoamDeviceFix(coordinate: centre, accuracyMeters: 8, measuredAt: Date().addingTimeInterval(Double(step - 3) * 20), datum: .gcj02)
        }
        let result = await store.confirm(fixes: fixes, photoAssetId: "https://example.invalid/p.jpg")
        XCTAssertEqual(result?.kind, .rejected)
        XCTAssertEqual(result?.reasons, ["APP_ATTEST_REQUIRED"])
        XCTAssertNotNil(store.pendingQuote, "a rejection keeps the quote so the player can fix the reason and retry")
        let sent = try XCTUnwrap(stub.requests.last { $0.url?.path.hasSuffix("claim/command") == true })
        let evidence = try XCTUnwrap((JSONSerialization.jsonObject(with: XCTUnwrap(sent.httpBody)) as? [String: Any])?["evidence"] as? [String: Any])
        XCTAssertEqual(evidence["inAppCamera"] as? Bool, true)

        stub.answers[mapPath] = ["items": [], "currency": "POINTS"]
        await store.load(center: centre)
        XCTAssertEqual(store.lost.map(\.territoryId), ["t-3"])
        XCTAssertEqual(store.haptic?.event, .propertyLost)
    }

    func testPointsChargeSurvivesPointsRead404() async throws {
        let stub = Stub()
        let lease = try XCTUnwrap(CityGameProductionLease(host: "city.example.test", regionID: "r1"))
        let pointsKey = "GET /prod-api/api/city-game/territory/points"
        let mapPath = "GET /prod-api/api/city-game/territory/map"
        stub.answers[mapPath] = ["items": [["propertyId": "t-3", "title": "骑楼口", "tier": 1, "lvl": 0, "districtId": "d1",
                                            "holder": ["maskedName": "我", "isMe": true], "lat": 31.231, "lng": 121.471]], "currency": "POINTS"]
        stub.answers[pointsKey] = ["currency": "POINTS", "balance": 500, "pending": 12, "holdings": 2, "holdingLimit": 9,
                                   "earnedSeason": 80, "spentSeason": 20]
        stub.answers["GET /prod-api/api/city-game/season/current"] = ["seasonId": "s2026w46", "phase": "REGULAR", "day": 8]
        stub.answers["GET /prod-api/api/city-game/territory/revenue"] = ["events": [], "todayPending": 0, "todayAvailable": 0]
        stub.answers["POST /prod-api/api/city-game/territory/claim/quote"] = ["quoteId": "q1", "quoteHash": "h", "cost": 60, "protectionHours": 24]
        stub.answers["POST /prod-api/api/city-game/territory/claim/command"] = ["outcome": "APPLIED", "balance": 440]
        stub.answers["POST /prod-api/api/city-game/territory/scout"] = ["propertyId": "t-3", "dc": 11, "cost": 10, "balance": 430]
        stub.answers["POST /prod-api/api/city-game/territory/shield"] = ["propertyId": "t-3", "cost": 60, "balance": 370,
                                                                        "protectedUntil": 1_795_900_800_000]
        let service = try CityMonopolyService(configuration: APIConfiguration(baseURL: base), token: "tok-1", lease: lease,
                                              transport: stub, isCurrent: { true })
        let nearby: CityNearbyRead = { _ in
            try JSONDecoder().decode(RoamTerritoryNearbyResponse.self, from: JSONSerialization.data(withJSONObject: ["revenueMode": "POINTS", "territories": [
                ["poiId": 1, "title": "人民广场", "latitude": 31.23, "longitude": 121.47, "radiusM": 80, "claimed": false, "status": "AVAILABLE",
                 "isProtected": false, "checkinTollPoints": 5, "ownerRevenuePoints": 5, "checkinCount": 0, "revenueTotalPoints": 0]]]))
        }
        let store = CityBoardStore(service: service, nearby: nearby, memberID: 9009)
        let centre = try XCTUnwrap(RoamCoordinate(latitude: 31.23, longitude: 121.47))
        await store.load(center: centre)
        XCTAssertEqual(store.points?.balance, 500)
        XCTAssertEqual(store.points?.holdings, 2)

        stub.answers.removeValue(forKey: pointsKey)
        let open = try XCTUnwrap(store.places.first { $0.ownership == .open })
        await store.quote(.claim, place: open, fix: nil)
        let fixes = try (0..<4).map { step in
            try RoamDeviceFix(coordinate: centre, accuracyMeters: 8, measuredAt: Date().addingTimeInterval(Double(step - 3) * 20), datum: .gcj02)
        }
        let claimed = await store.confirm(fixes: fixes, photoAssetId: "https://example.invalid/p.jpg")
        XCTAssertEqual(claimed?.kind, .applied)
        XCTAssertEqual(store.points?.balance, 440, "a 404 on the points read keeps the command balance")
        XCTAssertEqual(store.points?.pending, 12)
        XCTAssertEqual(store.points?.holdings, 2)
        XCTAssertEqual(store.points?.holdingLimit, 9)
        XCTAssertEqual(store.points?.earnedSeason, 80)
        XCTAssertEqual(store.points?.spentSeason, 20)

        stub.answers[pointsKey] = ["currency": "POINTS", "balance": 440, "pending": 0, "holdings": 3, "holdingLimit": 9]
        await store.load(center: centre)
        XCTAssertEqual(store.points?.balance, 440)
        XCTAssertEqual(store.points?.holdings, 3, "a successful points read replaces the whole summary")
        XCTAssertEqual(store.points?.pending, 0)

        stub.answers.removeValue(forKey: pointsKey)
        let mine = try XCTUnwrap(store.places.first { $0.territoryId == "t-3" })
        let dc = await store.scout(mine)
        XCTAssertEqual(dc, 11)
        XCTAssertEqual(store.points?.balance, 430)
        XCTAssertEqual(store.points?.holdings, 3)
        let protectedUntil = await store.shield(mine)
        XCTAssertNotNil(protectedUntil)
        XCTAssertEqual(store.points?.balance, 370)
        XCTAssertEqual(store.points?.holdings, 3)
    }

    func testUnavailableWithoutServices() {
        let store = CityBoardStore(service: nil, nearby: nil)
        XCTAssertEqual(store.phase, .unavailable)
        XCTAssertFalse(store.isAvailable)
        XCTAssertEqual(CityReasonCopy.text("APP_ATTEST_REQUIRED", chinese: true), "这台设备无法完成设备校验，换一台 iPhone 再试。")
    }
}
