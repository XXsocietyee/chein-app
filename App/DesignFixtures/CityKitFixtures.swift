#if DEBUG
import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// City kit design fixtures (`--design-fixture city-*`). Synthetic data, DEBUG only, for the states
// the TEST backend cannot reach from a simulator (App Attest blocks real claims and challenges, and
// there is no camera). The cast follows skill-r2 SR2-25: 老麦咖啡馆 open, 转角花店 (小李, 前哨 Lv1,
// weathered), 梧桐书店 (阿兰, 据点 Lv2, protected), 武康大楼 and 安福路 12 号 mine.

@MainActor final class CityFixtureMonopoly: CityMonopolyReading {
    enum ClaimAnswer { case rejected([String]), applied }
    enum ChallengeAnswer { case win, loss }
    var claimAnswer: ClaimAnswer = .rejected(["APP_ATTEST_REQUIRED", "ACCOUNT_LEVEL_TOO_LOW"])
    var challengeAnswer: ChallengeAnswer = .win
    var balance: Int64 = 1_286
    var empty = false
    var claimed = false

    static let base = (lat: 31.2050, lng: 121.4385)

    private func decode<T: Decodable>(_ json: Any) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: json))
    }

    private var now: Int64 { Int64(Date().timeIntervalSince1970 * 1000) }

    var held: [[String: Any]] {
        if empty { return [] }
        var rows: [[String: Any]] = [
            ["propertyId": "t-wukang", "title": "武康大楼", "tier": 4, "lvl": 2, "districtId": "d1", "status": "ACTIVE",
             "holder": ["maskedName": "我", "isMe": true], "protectedUntil": now + 5 * 3_600_000, "decayState": "OK",
             "lat": Self.base.lat + 0.0018, "lng": Self.base.lng - 0.0012, "invested": 1_040],
            ["propertyId": "t-anfu12", "title": "安福路 12 号", "tier": 2, "lvl": 1, "districtId": "d2", "status": "ACTIVE",
             "holder": ["maskedName": "我", "isMe": true], "decayState": "WEATHERED",
             "lat": Self.base.lat + 0.0032, "lng": Self.base.lng + 0.0016, "invested": 180],
            ["propertyId": "t-flower", "title": "转角花店", "tier": 2, "lvl": 1, "districtId": "d1", "status": "ACTIVE",
             "holder": ["maskedName": "小李", "isMe": false], "decayState": "WEATHERED",
             "lat": Self.base.lat - 0.0016, "lng": Self.base.lng + 0.0022, "invested": 180],
            ["propertyId": "t-books", "title": "梧桐书店", "tier": 3, "lvl": 2, "districtId": "d3", "status": "ACTIVE",
             "holder": ["maskedName": "阿兰", "isMe": false], "protectedUntil": now + 3 * 3_600_000, "decayState": "OK",
             "lat": Self.base.lat - 0.0028, "lng": Self.base.lng - 0.0020, "invested": 624],
            ["districtId": "d2", "tier": 1, "geohash7": "wtw3e9k"]
        ]
        if claimed {
            rows.append(["propertyId": "t-cafe", "title": "老麦咖啡馆", "tier": 2, "lvl": 0, "districtId": "d1", "status": "ACTIVE",
                         "holder": ["maskedName": "我", "isMe": true], "protectedUntil": now + 24 * 3_600_000, "decayState": "OK",
                         "lat": Self.base.lat + 0.0002, "lng": Self.base.lng + 0.0001, "invested": 120])
        }
        return rows
    }

    func nearbyAnswer() throws -> RoamTerritoryNearbyResponse {
        var items: [[String: Any]] = []
        if !claimed {
            items.append(["poiId": 7001, "title": "老麦咖啡馆", "latitude": Self.base.lat + 0.0002, "longitude": Self.base.lng + 0.0001,
                          "radiusM": 80, "claimed": false, "status": "UNCLAIMED", "isProtected": false, "checkinTollPoints": 5,
                          "ownerRevenuePoints": 5, "checkinCount": 0, "revenueTotalPoints": 0, "distanceM": 28, "tier": 2, "districtId": "d1"])
        }
        items.append(["poiId": 7002, "title": "愚园路 1088 弄", "latitude": Self.base.lat + 0.0045, "longitude": Self.base.lng - 0.0035,
                      "radiusM": 80, "claimed": false, "status": "UNCLAIMED", "isProtected": false, "checkinTollPoints": 5,
                      "ownerRevenuePoints": 5, "checkinCount": 0, "revenueTotalPoints": 0, "tier": 1, "districtId": "d3"])
        return try decode(["revenueMode": "POINTS", "territories": empty ? [] : items])
    }

    func territoryMap(bbox: String?, zoom: Int?) async throws -> CityTerritoryMapResponse { try decode(["items": held]) }
    func territoryMap(bounds: CityMapBounds) async throws -> CityTerritoryMapResponse { try decode(["items": held]) }
    func pointsSummary() async throws -> CityPointsSummary {
        CityPointsSummary(balance: balance, pending: 186, holdings: empty ? 0 : (claimed ? 3 : 2), holdingLimit: 9)
    }
    func property(_ propertyId: String) async throws -> CityTerritoryPropertyCard {
        let row = held.first { ($0["propertyId"] as? String) == propertyId } ?? [:]
        var card = row; card["visitsThisWeek"] = 14
        card["propertyId"] = propertyId
        return try decode(card)
    }
    func claimQuote(_ payload: CityTerritoryQuoteRequest) async throws -> CityTerritoryQuote {
        try decode(["quoteId": "q-claim", "quoteHash": "h", "cost": 120, "protectionHours": 24, "currency": "POINTS", "expiresAt": now + 300_000])
    }
    func claim(_ payload: CityTerritoryCommandRequest) async throws -> CityTerritoryCommandResult {
        switch claimAnswer {
        case .rejected(let reasons): return CityTerritoryCommandResult(outcome: "REJECTED", reasons: reasons, balance: balance)
        case .applied: claimed = true; balance -= 120; return CityTerritoryCommandResult(outcome: "CLAIMED", balance: balance)
        }
    }
    func upgradeQuote(_ payload: CityTerritoryQuoteRequest) async throws -> CityTerritoryQuote {
        try decode(["quoteId": "q-up", "quoteHash": "h", "cost": 96, "toLevel": 3])
    }
    func upgrade(_ payload: CityTerritoryCommandRequest) async throws -> CityTerritoryCommandResult { CityTerritoryCommandResult(outcome: "UPGRADED") }
    func challengeQuote(_ payload: CityTerritoryQuoteRequest) async throws -> CityTerritoryQuote {
        try decode(["quoteId": "q-ch", "quoteHash": "h", "cost": 90, "fee": 90, "dc": 12, "currency": "POINTS"])
    }
    func challenge(_ payload: CityTerritoryCommandRequest) async throws -> CityTerritoryCommandResult {
        let json: [String: Any] = challengeAnswer == .win
            ? ["outcome": "WIN", "roll": 14, "mods": ["task": 2, "insight": 1], "dc": 12, "total": 17,
               "feeSplit": ["fee": 90, "defenderComp": 36, "burned": 54, "refund": 0]]
            : ["outcome": "LOSS", "roll": 5, "mods": ["task": 2, "insight": 1], "dc": 12, "total": 8,
               "feeSplit": ["fee": 90, "defenderComp": 27, "burned": 63, "refund": 0]]
        return try decode(json)
    }
    func scout(_ payload: CityPropertyActionRequest) async throws -> CityScoutResult { try decode(["dc": 12, "cost": 10]) }
    func shield(_ payload: CityPropertyActionRequest) async throws -> CityShieldResult { try decode(["protectedUntil": now + 17 * 3_600_000]) }
    func revenue(cursor: String?, day: String?) async throws -> CityRevenuePage {
        try decode(["events": empty ? [] : [
            ["id": 1, "visitorMasked": "阿*", "propertyId": "t-wukang", "granted": 31, "state": "PENDING"],
            ["id": 2, "visitorMasked": "林*", "propertyId": "t-wukang", "granted": 27, "state": "PENDING"],
            ["id": 3, "visitorMasked": "小*", "propertyId": "t-anfu12", "granted": 4, "state": "AVAILABLE"]
        ], "todayPending": empty ? 0 : 58, "todayAvailable": empty ? 0 : 128, "threshold": 202])
    }
    func seasonCurrent() async throws -> CitySeasonCurrent {
        try decode(["seasonId": "s2026w46", "phase": "REGULAR", "day": 16, "freezesAt": now + 12 * 86_400_000])
    }
    func seasonLeaderboard(scope: CitySeasonScope, seasonId: String?) async throws -> CitySeasonLeaderboard { throw RoamTerritoryError.malformed }
    func memberAttributes() async throws -> MemberAttributesResponse { throw RoamTerritoryError.malformed }
    func attributeLedger(key: MemberAttributeKey?, cursor: String?) async throws -> MemberAttributeLedgerPage { throw RoamTerritoryError.malformed }
    func equipTitle(_ payload: MemberTitleEquipRequest) async throws -> MemberTitleEquipReceipt { throw RoamTerritoryError.malformed }
}

enum CityKitFixtures {
    @MainActor static func make(_ name: String) -> AnyView {
        // `-ax3` renders the same fixture at accessibility size AX3 (SR2-35 proofs).
        if name.hasSuffix("-ax3") {
            return AnyView(CityKitFixtureHost(name: String(name.dropLast(4))).themeDomain(.player).environment(\.dynamicTypeSize, .accessibility3))
        }
        return AnyView(CityKitFixtureHost(name: name).themeDomain(.player))
    }

    /// The store is made once per host (the registry is called on every root render).
    @MainActor static func store(_ name: String) -> CityBoardStore {
        let fake = CityFixtureMonopoly()
        switch name {
        case "city-claim-ok", "city-moment-claimed": fake.claimAnswer = .applied
        case "city-board-empty": fake.empty = true
        case "city-claim-short": fake.balance = 40
        case "city-dice-lost": fake.challengeAnswer = .loss
        default: break
        }
        return CityBoardStore(service: fake, nearby: { _ in try fake.nearbyAnswer() }, memberID: 9009)
    }
}

@MainActor private struct CityKitFixtureHost: View {
    let name: String
    @StateObject private var store: CityBoardStore
    @State private var loaded = false

    init(name: String) {
        self.name = name
        _store = StateObject(wrappedValue: CityKitFixtures.store(name))
    }

    private var center: RoamCoordinate { RoamCoordinate(latitude: CityFixtureMonopoly.base.lat, longitude: CityFixtureMonopoly.base.lng)! }
    private func fix() throws -> RoamDeviceFix {
        try RoamDeviceFix(coordinate: center, accuracyMeters: 12, measuredAt: Date(), datum: .gcj02)
    }

    var body: some View {
        Group {
            if loaded { content } else { Color.black }
        }
        .task {
            await store.load(center: center)
            loaded = true
        }
    }

    @ViewBuilder private var content: some View {
        let claimFixture: CityClaimFixture? = ["city-claim-ok", "city-claim-rejected"].contains(name)
            ? CityClaimFixture(photoRef: "fixture-photo", autoSubmit: true) : (name == "city-claim-short" ? CityClaimFixture(photoRef: "fixture-photo", autoSubmit: false) : nil)
        let deps = CityRoamRootDependencies(captureFix: { try fix() }, fallbackCenter: center, photoUploader: nil,
                                            liveDestination: { AnyView(Text(verbatim: "live")) }, passportDestination: nil,
                                            fixtureClaim: claimFixture)
        switch name {
        case "city-kit": CityKitGallery(store: store)
        case "city-board", "city-board-empty": NavigationStack { CityBoardView(store: store, onOpen: { _ in }, onMine: {}, onLedger: {}) }
        case "city-mine": NavigationStack { CityMyPropertiesView(store: store, onOpen: { _ in }, onShield: { _ in }, onUpgrade: { _ in }) }
        case "city-ledger": NavigationStack { CityRentLedgerView(store: store) }
        case "city-home-rail": ScrollView { CityHomeRail(store: store, onOpenMap: {}).padding() }.background(Color.black)
        case "city-property-open": CityRoamRootView(store: store, dependencies: deps, initialRoute: .property(id("老麦咖啡馆")))
        case "city-property-protected": CityRoamRootView(store: store, dependencies: deps, initialRoute: .property("t-books"))
        case "city-property-challenge": CityRoamRootView(store: store, dependencies: deps, initialRoute: .property("t-flower"))
        case "city-property-mine": CityRoamRootView(store: store, dependencies: deps, initialRoute: .property("t-wukang"))
        case "city-property-unlit": CityRoamRootView(store: store, dependencies: deps, initialRoute: .property(fogID))
        case "city-claim", "city-claim-ok", "city-claim-rejected", "city-claim-short":
            CityRoamRootView(store: store, dependencies: deps, initialRoute: .claim(id("老麦咖啡馆")))
        case "city-challenge": CityRoamRootView(store: store, dependencies: deps, initialRoute: .challenge("t-flower"))
        case "city-shield": CityRoamRootView(store: store, dependencies: deps, initialRoute: .shield("t-wukang"))
        case "city-upgrade": CityRoamRootView(store: store, dependencies: deps, initialRoute: .upgrade("t-anfu12"))
        case "city-dice-ready", "city-dice-won", "city-dice-lost":
            CityDiceFixture(store: store, place: store.place(id: "t-flower")!, autoRoll: name != "city-dice-ready", fixes: [(try? fix())].compactMap { $0 })
        case "city-moment-claimed":
            CityClaimedMoment(place: claimedPlace, photo: nil, protectionHours: 24, price: 120, onMine: {}, onDone: {})
        case "city-place-lost":
            CityPlaceLostMoment(place: store.place(id: "t-wukang")!, compensation: 40, onDone: {})
        case "city-defended":
            CityDefendedMoment(place: store.place(id: "t-wukang")!, hours: 12, onDone: {})
        default:
            CityRoamRootView(store: store, dependencies: deps)
        }
    }

    private func id(_ title: String) -> String { store.places.first { $0.title == title }?.id ?? "" }
    private var fogID: String { store.places.first { $0.ownership == .fogged }?.id ?? "" }
    private var claimedPlace: CityPlace {
        let open = store.places.first { $0.title == "老麦咖啡馆" }!
        return CityPlace(id: "t-cafe", title: open.title, coordinate: open.coordinate, territoryId: "t-cafe", districtId: "d1",
                         districtIndex: open.districtIndex, tier: .t2, level: 0, ownership: .mine, protectedUntil: Date().addingTimeInterval(86_400))
    }
}

@MainActor private struct CityDiceFixture: View {
    @ObservedObject var store: CityBoardStore
    let place: CityPlace
    let autoRoll: Bool
    let fixes: [RoamDeviceFix]
    @State private var ready = false
    var body: some View {
        Group {
            if ready { CityDiceMoment(place: place, fixes: fixes, dc: 12, store: store, onMine: {}, onDone: {}, autoRoll: autoRoll) }
            else { Color.black }
        }
        .task { await store.quote(.challenge, place: place, fix: fixes.first); ready = true }
    }
}

/// The kit sheet: deed sizes and states, pips, odds bar, die faces, pins, legend, hold button.
@MainActor private struct CityKitGallery: View {
    @ObservedObject var store: CityBoardStore
    @Environment(\.cyPalette) private var palette
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: CYSpacing.md) {
                        ForEach(store.places.prefix(4)) { CityDeedCard(place: $0, size: .full).frame(width: 300) }
                    }
                }
                ForEach(store.places) { CityDeedCard(place: $0, size: .row, trailing: $0.ownership == .open ? .price : .status) }
                HStack { ForEach(store.mine) { CityDeedCard(place: $0, size: .mini) } }
                CityOddsBar(needFace: 9, modifiers: ["任务 +2", "洞察 +1"])
                HStack(spacing: CYSpacing.lg) { CityD20Art(face: 20, size: 88); CityD20Art(face: nil, size: 88); CityD20Art(face: 5, lost: true, size: 88) }
                HStack { ForEach(store.places) { CityPin(place: $0) } }
                CityMapLegend()
                CityHoldButton(title: "按住 0.8 秒开始漫游", holdingTitle: "松手取消", onCommit: {})
            }
            .padding()
        }
        .background(palette.bgPage)
    }
}
#endif
