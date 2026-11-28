#if DEBUG
import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// mp-roam r3: 地点详情 (`subpackageRoam/poi-detail` → `scene-roam-poi-detail`) on the shipping `RoamItemDetailView`,
/// one fixture per MP state: node card (`r3-roam-poi`), cy-error 节点无法打开 + 重试 (`-error`),
/// cy-empty 节点未开放或已下线 + 返回地图 (`-unavailable`), cy-empty 找不到这个节点 + 返回地图 (`-missing`).
/// Offline synthetic place, names in the UI language; no network.
enum RoamR3PoiFixture {
    enum Scenario { case content, failure, unavailable, missing }

    @MainActor static func make(_ scenario: Scenario) -> AnyView {
        AnyView(RoamR3PoiFixtureHost(scenario: scenario))
    }
}

@MainActor private struct RoamR3PoiFixtureHost: View {
    let scenario: RoamR3PoiFixture.Scenario
    @State private var reader: RoamR3PoiFixtureReader

    init(scenario: RoamR3PoiFixture.Scenario) {
        self.scenario = scenario
        _reader = State(initialValue: RoamR3PoiFixtureReader(scenario: scenario))
    }

    var body: some View {
        if let place = RoamR3PoiFixtureReader.place() {
            RoamItemDetailView(item: .place(place), reader: reader)
        } else {
            Text(verbatim: "fixture place did not decode")
        }
    }
}

@MainActor
final class RoamR3PoiFixtureReader: RoamReading {
    let scenario: RoamR3PoiFixture.Scenario
    var isConfigured: Bool { true }
    var identity: RoamReadIdentity? { RoamReadIdentity(accountID: 900, epoch: 1) }
    var searchArea: RoamSearchArea? {
        RoamSearchArea(coordinate: RoamCoordinate(latitude: 31.2400, longitude: 121.4900)!, label: "")
    }
    /// false: the rendered page shows what players see (no 示例内容 note); the data stays offline.
    var isOfflineExample: Bool { false }

    init(scenario: RoamR3PoiFixture.Scenario) { self.scenario = scenario }

    private static var prefersChinese: Bool { Locale.preferredLanguages.first?.hasPrefix("zh") == true }

    private static func name(_ en: String, _ zh: String) -> String { prefersChinese ? zh : en }

    private static func decode<T: Decodable>(_ type: T.Type, _ object: [String: Any]) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: object)
        return try JSONDecoder().decode(type, from: data)
    }

    static func place() -> RoamPlace? {
        let object: [String: Any] = [
            "id": 911,
            "name": name("Bund Origin courtyard", "外滩源庭院"),
            "lat": 31.2433,
            "lng": 121.4884,
            "type": 1,
            "address": name("33 Zhongshan East 1st Rd", "中山东一路33号"),
            "description": name("A quiet brick courtyard behind the riverfront.", "滨江背后一处安静的红砖庭院。"),
        ]
        return try? decode(RoamPlace.self, object)
    }

    func roamPlaces(radiusM: Int) async throws -> [RoamPlace] { [] }
    func roamRouteNodes(radiusM: Int) async throws -> [RoamRouteNode] { [] }
    func roamEvents(radiusM: Int) async throws -> RoamEvents { try Self.decode(RoamEvents.self, [:]) }
    func roamPlayers(radiusM: Int) async throws -> [RoamPlayer] { [] }
    func roamExploreDay() async throws -> RoamExploreDay? { nil }

    func roamNodeDetail(id: Int) async throws -> RoamNodeDetail {
        switch scenario {
        case .failure: throw APIError.httpStatus(503)
        case .unavailable: throw RoamReadFailure.nodeUnavailable
        case .missing: throw RoamReadFailure.nodeNotFound
        case .content: break
        }
        let object: [String: Any] = [
            "poiId": id,
            "name": Self.name("Bund Origin courtyard", "外滩源庭院"),
            "description": Self.name("A quiet brick courtyard behind the riverfront. Find the old bell over the gate.",
                                     "滨江背后一处安静的红砖庭院。找到门楼上的旧铜钟。"),
            "lat": 31.2433,
            "lng": 121.4884,
            "radiusM": 120,
            "status": 1,
            "tags": Self.name("History · Architecture", "历史 · 建筑"),
            "completed": false,
            "favorited": false,
            "averageRating": 4.6,
            "ratingCount": 38,
        ]
        return try Self.decode(RoamNodeDetail.self, object)
    }

    func roamMerchantDetail(id: Int) async throws -> RoamMerchantDetail {
        throw RoamReadFailure.nodeNotFound
    }
}
#endif
