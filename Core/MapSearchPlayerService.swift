import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// G5 map/search. Ports:
/// - `utils/open-address.js#geocode`: `POST api/map/geocode {address, region}` (form)
/// - `components/cy/map-address-search`: `POST api/map/place-search {keyword, longitude, latitude}` (form)
/// - `subpackageRoam/components/map-weather` + `weather-core.js`: `GET api/map/weather {lat, lng}` of the cell centre
/// - `pages/search2/result`: `GET api/search/unified {keyword, types, city_code, pageNum, pageSize: 12}`
public struct MapSearchPlayerService {
    public static let geocodePath = "api/map/geocode"
    public static let placeSearchPath = "api/map/place-search"
    public static let weatherPath = "api/map/weather"
    public static let unifiedSearchPath = "api/search/unified"
    /// V-06 fallback of `components/cy/map-address-search` `_searchNodes`: `GET api/city/nodes {lat, lng, radius: 20000, keyword}`.
    public static let cityNodesPath = "api/city/nodes"

    let client: PlayerCapabilityClient
    public init(client: PlayerCapabilityClient) { self.client = client }

    public struct Coordinate: Equatable {
        public let latitude: Double
        public let longitude: Double
    }

    /// `coords`: finite, not (0,0), within range; `lat`/`latitude`, `lng`/`longitude`/`lon`.
    public static func coordinate(_ raw: SquareGovernanceJSON) -> Coordinate? {
        let lat = PlayerCapabilityClient.number(raw["lat"] == .null ? raw["latitude"] : raw["lat"])
        let lngRaw = raw["lng"] != .null ? raw["lng"] : (raw["longitude"] != .null ? raw["longitude"] : raw["lon"])
        guard let lat, let lng = PlayerCapabilityClient.number(lngRaw), lat.isFinite, lng.isFinite,
              !(lat == 0 && lng == 0), abs(lat) <= 90, abs(lng) <= 180 else { return nil }
        return Coordinate(latitude: lat, longitude: lng)
    }

    // MARK: Geocode

    /// Text address → coordinate, or nil (「暂时无法定位」). `region` is the city text.
    public func geocode(address: String, region: String) async -> Coordinate? {
        let text = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let request = try? client.formRequest(Self.geocodePath,
                fields: [("address", text), ("region", region.trimmingCharacters(in: .whitespacesAndNewlines))]),
              let raw = try? await client.read(request) else { return nil }
        return Self.coordinate(raw)
    }

    // MARK: Place search

    public struct Place: Equatable, Identifiable {
        public let id: String
        public let name: String
        public let address: String
        public let coordinate: Coordinate?
    }

    /// Keyword ≥ 2 characters near a non-zero map centre. Rows already in `localNames` are dropped (同名去重).
    /// An empty list means the Tencent search is off; the caller then falls back to `api/city/nodes`.
    public func placeSearch(keyword: String, latitude: Double, longitude: Double, localNames: Set<String> = []) async throws -> [Place] {
        let text = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2, latitude != 0, longitude != 0 else { return [] }
        let raw = try await client.read(try client.formRequest(Self.placeSearchPath, fields: [
            ("keyword", text), ("longitude", String(longitude)), ("latitude", String(latitude))
        ]))
        return (raw.array ?? []).enumerated().compactMap { index, row in
            let name = row["name"].string ?? ""
            guard !name.isEmpty, !localNames.contains(name) else { return nil }
            return Place(id: "place-\(index)", name: name, address: row["address"].string ?? "", coordinate: Self.coordinate(row))
        }
    }

    /// MP `_searchNodes` + `utils/map-address-search.js#cityNodesToPlaces` (2026-10-29 V-06): when the Tencent place
    /// search is off (empty list) or fails, the merchant node library answers instead. Name = `name`, else `merchantName`;
    /// rows without a usable point or whose name is already listed (`localNames`, then earlier rows) are dropped.
    public func cityNodePlaces(keyword: String, latitude: Double, longitude: Double, localNames: Set<String> = []) async throws -> [Place] {
        let text = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2, latitude != 0, longitude != 0 else { return [] }
        let raw = try await client.read(try client.getRequest(Self.cityNodesPath, query: [
            ("lat", String(latitude)), ("lng", String(longitude)), ("radius", "20000"), ("keyword", text)
        ]))
        var taken = localNames
        var places: [Place] = []
        for row in raw.array ?? [] {
            let primary = row["name"].string ?? ""
            let name = primary.isEmpty ? (row["merchantName"].string ?? "") : primary
            guard !name.isEmpty, !taken.contains(name), let point = Self.coordinate(row) else { continue }
            taken.insert(name)
            let id = row["poiId"].int.map { "node-\($0)" } ?? "node-\(places.count)"
            places.append(Place(id: id, name: name, address: row["merchantAddress"].string ?? "", coordinate: point))
        }
        return places
    }

    // MARK: Weather

    public struct Weather: Equatable {
        /// rain | snow | fog
        public let kind: String
        /// Clamped to 0.15…1, default 0.5.
        public let intensity: Double
    }
    public static let cellsPerDegree = 20.0

    /// `cellOf`: 20 cells per degree (~5.5 km), same as `MapWeatherServiceImpl`.
    public static func cell(latitude: Double, longitude: Double) -> (Int, Int)? {
        guard latitude.isFinite, longitude.isFinite, abs(latitude) <= 90, abs(longitude) <= 180,
              !(latitude == 0 && longitude == 0) else { return nil }
        return (Int((latitude * cellsPerDegree).rounded(.down)), Int((longitude * cellsPerDegree).rounded(.down)))
    }

    /// `normalize`: clear, an unknown kind, or a bad shape draws nothing.
    public static func weather(_ raw: SquareGovernanceJSON) -> Weather? {
        guard let kind = raw["kind"].string, ["rain", "snow", "fog"].contains(kind) else { return nil }
        let value = PlayerCapabilityClient.number(raw["intensity"]).flatMap { $0.isFinite ? $0 : nil }
        return Weather(kind: kind, intensity: value.map { max(0.15, min(1, $0)) } ?? 0.5)
    }

    /// Only the cell centre is sent, never the player's exact position. Any failure: nil.
    public func weather(latitude: Double, longitude: Double) async -> Weather? {
        guard let cell = Self.cell(latitude: latitude, longitude: longitude) else { return nil }
        let lat = String(format: "%.3f", (Double(cell.0) + 0.5) / Self.cellsPerDegree)
        let lng = String(format: "%.3f", (Double(cell.1) + 0.5) / Self.cellsPerDegree)
        guard let request = try? client.getRequest(Self.weatherPath, query: [("lat", lat), ("lng", lng)]),
              let raw = try? await client.read(request) else { return nil }
        return Self.weather(raw)
    }

    // MARK: Unified search

    public struct SearchItem: Equatable, Identifiable {
        public let type: String
        public let itemID: Int
        public let title: String
        public let detail: String
        public var id: String { type + ":" + String(itemID) }
    }
    public struct SearchPage: Equatable {
        public let items: [SearchItem]
        public let total: Int
        public let count: Int
    }
    /// `TYPE_META` labels for the three unified types the result page asks for.
    public static let typeLabels = ["post": "帖文", "topic": "主题", "activity": "活动"]
    public static let pageSize = 12

    /// `unifiedPage`: one bad row or a type outside `types` invalidates the whole page.
    public static func searchPage(_ raw: SquareGovernanceJSON, types: [String]) -> SearchPage? {
        guard let rows = raw["rows"].array, let total = raw["total"].int ?? raw["total"].string.flatMap({ Int($0) }), total >= 0 else {
            return nil
        }
        var items: [SearchItem] = []
        for row in rows {
            guard let type = row["type"].string, types.contains(type), let id = PlayerCapabilityClient.positiveID(row["id"]) else { return nil }
            let label = typeLabels[type] ?? type
            let title = PlayerCapabilityClient.text(row["name"]).isEmpty ? PlayerCapabilityClient.text(row["title"]) : PlayerCapabilityClient.text(row["name"])
            let detail: String
            switch type {
            case "post": detail = "公开帖文"
            case "topic": detail = [row["addressName"], row["description"]].map(PlayerCapabilityClient.text).first { !$0.isEmpty } ?? "城市主题"
            default: detail = row["topicId"] != .null ? "关联主题节点"
                : ([row["addressName"], row["address"]].map(PlayerCapabilityClient.text).first { !$0.isEmpty } ?? "活动地点待公布")
            }
            items.append(SearchItem(type: type, itemID: id, title: title.isEmpty ? label : title, detail: detail))
        }
        return SearchPage(items: items, total: total, count: rows.count)
    }

    /// Search (`#842`: GET, works signed in or as guest). `types` is `topic,activity` plus `post` when community read is open.
    /// 503/404 mean unified search is not open: the caller falls back to the topic/activity lists.
    public func unifiedSearch(keyword: String, types: [String], cityCode: String, page: Int) async throws -> SearchPage {
        let text = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, page > 0, !types.isEmpty, types.allSatisfy({ Self.typeLabels[$0] != nil }) else {
            throw PlayerCapabilityFailure.invalid
        }
        let raw = try await client.read(try client.optionalAuthGetRequest(Self.unifiedSearchPath, query: [
            ("keyword", text), ("types", types.joined(separator: ",")), ("city_code", cityCode),
            ("pageNum", String(page)), ("pageSize", String(Self.pageSize))
        ]))
        guard let result = Self.searchPage(raw, types: types) else { throw PlayerCapabilityFailure.malformed }
        return result
    }

    /// `contentHasMore`: `count > 0 && page * 12 < total`.
    public static func hasMore(_ page: SearchPage, pageNumber: Int) -> Bool {
        page.count > 0 && pageNumber * pageSize < page.total
    }
}
