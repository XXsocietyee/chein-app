#if DEBUG
import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// mp-roam r3 (ADA 1128 `d2-roam` P0 "the core experience, roam, is not shown"; receipt continue 11 Not done):
/// `d2-roam` / `d6-roam` mount the shipping 漫游 tab root `RoamMapHomeView` (`NativeR2Flags.mapHome`, default on),
/// not the legacy roam browser that players only reach as the 漫游护照与工具 sheet. Synthetic readers only: no
/// session, location, network or write. Names follow the UI language (sweep rule 19:50).
@MainActor struct RoamMapHomeFixture: View {
    @State private var roam = RoamMapHomeFixtureReader()
    @State private var entry: RoamMapHomeFixtureEntryReader

    init(nearbyEmpty: Bool = false) {
        _entry = State(initialValue: RoamMapHomeFixtureEntryReader(empty: nearbyEmpty))
    }

    var body: some View {
        RoamMapHomeView(dependencies: RoamMapHomeDependencies(roamReader: roam, entryReader: entry))
            .themeDomain(.player)
    }
}

private func roamMapHomeFixtureText(_ en: String, _ zh: String) -> String {
    Locale.preferredLanguages.first?.hasPrefix("zh") == true ? zh : en
}

private func roamMapHomeFixtureJSON(_ object: Any) -> Data {
    (try? JSONSerialization.data(withJSONObject: object)) ?? Data("[]".utf8)
}

/// The fixture city centre (People's Square, Shanghai, GCJ-02), shared by both readers so pins sit around the camera.
private let roamMapHomeFixtureCentre = (latitude: 31.2304, longitude: 121.4737)

/// 附近 places for the map home list and pins.
@MainActor final class RoamMapHomeFixtureReader: RoamReading {
    var isConfigured: Bool { true }
    var identity: RoamReadIdentity? { RoamReadIdentity(accountID: 900, epoch: 1) }
    var searchArea: RoamSearchArea? {
        RoamCoordinate(latitude: roamMapHomeFixtureCentre.latitude, longitude: roamMapHomeFixtureCentre.longitude)
            .map { RoamSearchArea(coordinate: $0, label: roamMapHomeFixtureText("Shanghai", "上海")) }
    }
    /// The sweep shows what players see, so no offline-example footer.
    var isOfflineExample: Bool { false }

    func roamPlaces(radiusM: Int) async throws -> [RoamPlace] {
        let t = roamMapHomeFixtureText
        let rows: [[String: Any]] = [
            ["id": 911, "name": t("Lantern Gate", "灯笼门"), "lat": 31.2329, "lng": 121.4761, "type": 1,
             "address": t("Nanjing Road East", "南京东路"), "xp": 20],
            ["id": 912, "name": t("Old Street Neon", "老街霓虹"), "lat": 31.2281, "lng": 121.4795, "type": 1,
             "address": t("Fuzhou Road", "福州路"), "xp": 20],
            ["id": 913, "name": t("Corner Coffee", "转角咖啡"), "lat": 31.2296, "lng": 121.4702, "type": 2,
             "address": t("Huangpi Road North", "黄陂北路")]
        ]
        return try JSONDecoder().decode([RoamPlace].self, from: roamMapHomeFixtureJSON(rows))
    }
    func roamRouteNodes(radiusM: Int) async throws -> [RoamRouteNode] { [] }
    func roamEvents(radiusM: Int) async throws -> RoamEvents {
        try JSONDecoder().decode(RoamEvents.self, from: Data("{}".utf8))
    }
    func roamPlayers(radiusM: Int) async throws -> [RoamPlayer] { [] }
    func roamExploreDay() async throws -> RoamExploreDay? { nil }
    func roamNodeDetail(id: Int) async throws -> RoamNodeDetail { throw APIError.httpStatus(404) }
    func roamMerchantDetail(id: Int) async throws -> RoamMerchantDetail { throw APIError.httpStatus(404) }
}

/// MP entry-peek 附近活动 rows (`/api/roam/entry/nearby` shape); `empty` = the P-26 empty peek (`d6-roam`).
@MainActor final class RoamMapHomeFixtureEntryReader: RoamEntryNearbyReading {
    let empty: Bool
    init(empty: Bool) { self.empty = empty }
    var isConfigured: Bool { true }
    var isSignedIn: Bool { true }
    var allowsPublicEntry: Bool { true }
    var isOfflineExample: Bool { false }
    var searchArea: RoamSearchArea? {
        RoamCoordinate(latitude: roamMapHomeFixtureCentre.latitude, longitude: roamMapHomeFixtureCentre.longitude)
            .map { RoamSearchArea(coordinate: $0, label: roamMapHomeFixtureText("Shanghai", "上海")) }
    }
    var readKey: String { empty ? "fixture-empty" : "fixture-content" }

    func entryNearby() async throws -> [RoamEntryActivity] {
        if empty { return [] }
        let t = roamMapHomeFixtureText
        let items: [[String: Any]] = [
            ["kind": "activity", "id": 921, "topicId": 821, "productType": 1,
             "name": t("Bund Night Clues", "外滩夜色寻线"), "picUrl": "",
             "startDate": "2099-10-01 19:00:00", "endDate": "2099-10-01 22:00:00", "viewerHasTicket": 0,
             "latitude": 31.2352, "longitude": 121.4812, "addressName": t("The Bund", "外滩"), "distance": 1100],
            ["kind": "topic", "id": 822, "productType": 2,
             "name": t("Old Street Free Explore", "老街自由探索"), "viewerHasTicket": 1,
             "latitude": 31.2275, "longitude": 121.4744, "addressName": t("Fuzhou Road", "福州路"), "distance": 420]
        ]
        let envelope: [String: Any] = ["code": 200, "data": ["radius": 3000, "items": items]]
        return try RoamEntryNearbyRoute.decode(roamMapHomeFixtureJSON(envelope), status: 200)
    }
}
#endif
