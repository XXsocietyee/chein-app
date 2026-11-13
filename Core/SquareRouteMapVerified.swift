import Foundation

/// Chapters and stops from one `POST api/topic/info-to-user` body, plus road geometry
/// only when that body says the provider verified it.
///
/// A chapter that has a stop and no complete verified road hides the whole map.
/// Node-to-node straight lines are not returned. A missing stop name is an em dash.
public enum SquareRouteMapVerified {
    public static let unknownTitle = "—"

    public struct Stop: Equatable {
        public let id: Int
        public let title: String
        public let latitude: Double
        public let longitude: Double
        public init(id: Int, title: String, latitude: Double, longitude: Double) {
            self.id = id
            self.title = title
            self.latitude = latitude
            self.longitude = longitude
        }
    }

    public struct Point: Equatable {
        public let latitude: Double
        public let longitude: Double
        public init(latitude: Double, longitude: Double) {
            self.latitude = latitude
            self.longitude = longitude
        }
    }

    public struct Route: Equatable {
        public let stops: [Stop]
        /// One polyline per chapter. Chapters are not joined.
        public let segments: [[Point]]
        public init(stops: [Stop], segments: [[Point]]) {
            self.stops = stops
            self.segments = segments
        }
    }

    /// Nil when verified road geometry is absent, incomplete, or would have to be invented.
    public static func project(detail: TopicDetail, body: Data) -> Route? {
        guard detail.id > 0, detail.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return nil }
        let rawChapters = bodyChapters(body)
        var seen: Set<Int> = []
        var stops: [Stop] = []
        var segments: [[Point]] = []
        for chapter in detail.chapters {
            let raw = rawChapters.first { $0.id == chapter.id }
            let chapterStops = stops(in: chapter, raw: raw, seen: &seen)
            if chapterStops.isEmpty { continue }
            guard let segment = raw?.verifiedSegment(), segment.count >= 2 else { return nil }
            stops.append(contentsOf: chapterStops)
            segments.append(segment)
        }
        guard !stops.isEmpty, !segments.isEmpty else { return nil }
        return Route(stops: stops, segments: segments)
    }

    public static func title(_ raw: String?) -> String {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? unknownTitle : trimmed
    }

    private static func stops(in chapter: TopicChapter, raw: RawChapter?, seen: inout Set<Int>) -> [Stop] {
        let rawByID = Dictionary((raw?.nodes ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var rows: [(index: Int, sort: Double, node: TopicNode)] = []
        for (index, node) in chapter.nodes.enumerated() {
            guard node.id > 0, seen.insert(node.id).inserted else { continue }
            rows.append((index, rawByID[node.id]?.sortID ?? 0, node))
        }
        rows.sort { lhs, rhs in
            if lhs.sort != rhs.sort { return lhs.sort < rhs.sort }
            return lhs.index < rhs.index
        }
        return rows.compactMap { row in
            let point: SquareRouteMap.Point?
            if let rawNode = rawByID[row.node.id] {
                point = SquareRouteMap.point(rawNode.mapNode)
            } else if let latitude = row.node.latitude, let longitude = row.node.longitude {
                point = SquareRouteMap.point(.init(latitude: .number(latitude), longitude: .number(longitude)))
            } else {
                point = nil
            }
            guard let point else { return nil }
            let name = rawByID[row.node.id]?.name ?? row.node.name
            return Stop(id: row.node.id, title: title(name), latitude: point.latitude, longitude: point.longitude)
        }
    }

    private static func bodyChapters(_ body: Data) -> [RawChapter] {
        guard let envelope = try? JSONDecoder().decode(BodyEnvelope.self, from: body) else { return [] }
        return envelope.data?.chaptersList?.compactMap(\.chapter) ?? []
    }
}

private struct BodyEnvelope: Decodable {
    let data: BodyTopic?
    struct BodyTopic: Decodable { let chaptersList: [ChapterBox]? }
}

private struct ChapterBox: Decodable {
    let chapter: RawChapter?
    init(from decoder: Decoder) throws { chapter = try? RawChapter(from: decoder) }
}

private struct RawChapter: Decodable {
    let id: Int
    let nodes: [RawNode]
    let routeGeometryAvailable: Bool
    let routeGeometryError: Bool
    let errorCodeBlocks: Bool
    let geometry: GeometryPayload

    func verifiedSegment() -> [SquareRouteMapVerified.Point]? {
        guard routeGeometryAvailable, !routeGeometryError, !errorCodeBlocks else { return nil }
        let rows: [Coord]
        switch geometry {
        case .rows(let value): rows = value
        case .text(let text):
            guard let parsed = try? JSONDecoder().decode([Coord].self, from: Data(text.utf8)) else { return nil }
            rows = parsed
        case .unsupported: return nil
        }
        guard rows.count >= 2 else { return nil }
        var points: [SquareRouteMapVerified.Point] = []
        for row in rows {
            guard let point = row.point() else { return nil }
            points.append(.init(latitude: point.latitude, longitude: point.longitude))
        }
        return points
    }

    enum CodingKeys: String, CodingKey {
        case id, nodes, routeGeometryAvailable, routeGeometryError, routeGeometryErrorCode, routeGeometry
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let intID = try? c.decode(Int.self, forKey: .id), intID > 0 {
            id = intID
        } else if let text = try? c.decode(String.self, forKey: .id), let intID = Int(text), intID > 0 {
            id = intID
        } else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "chapter id")
        }
        nodes = (try? c.decode([NodeBox].self, forKey: .nodes))?.compactMap(\.node) ?? []
        routeGeometryAvailable = (try? c.decode(Bool.self, forKey: .routeGeometryAvailable)) == true
        routeGeometryError = (try? c.decode(Bool.self, forKey: .routeGeometryError)) == true
        errorCodeBlocks = (try? c.decode(ErrorCode.self, forKey: .routeGeometryErrorCode))?.blocksRoad == true
        geometry = (try? c.decode(GeometryPayload.self, forKey: .routeGeometry)) ?? .unsupported
    }
}

private struct NodeBox: Decodable {
    let node: RawNode?
    init(from decoder: Decoder) throws { node = try? RawNode(from: decoder) }
}

private struct RawNode: Decodable {
    let id: Int
    let name: String?
    let sortID: Double
    let latitude: SquareRouteMap.Value?
    let longitude: SquareRouteMap.Value?
    let lat: SquareRouteMap.Value?
    let lng: SquareRouteMap.Value?
    var mapNode: SquareRouteMap.Node {
        .init(latitude: latitude, lat: lat, longitude: longitude, lng: lng, name: name, sortID: sortID)
    }

    enum CodingKeys: String, CodingKey { case id, name, nodeName, sortId, latitude, longitude, lat, lng }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let intID = try? c.decode(Int.self, forKey: .id), intID > 0 {
            id = intID
        } else if let text = try? c.decode(String.self, forKey: .id), let intID = Int(text), intID > 0 {
            id = intID
        } else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "node id")
        }
        let primary = try c.decodeIfPresent(String.self, forKey: .name)
        let secondary = try c.decodeIfPresent(String.self, forKey: .nodeName)
        let candidates = [primary, secondary].compactMap { $0 }
        name = candidates.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? candidates.first
        if let sort = try? c.decode(SortNumber.self, forKey: .sortId) {
            sortID = sort.value
        } else {
            sortID = 0
        }
        latitude = try c.decodeIfPresent(MapValue.self, forKey: .latitude)?.value
        longitude = try c.decodeIfPresent(MapValue.self, forKey: .longitude)?.value
        lat = try c.decodeIfPresent(MapValue.self, forKey: .lat)?.value
        lng = try c.decodeIfPresent(MapValue.self, forKey: .lng)?.value
    }
}

private struct MapValue: Decodable {
    let value: SquareRouteMap.Value
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { value = .other; return }
        if let number = try? c.decode(Double.self), number.isFinite { value = .number(number); return }
        if let text = try? c.decode(String.self) { value = .text(text); return }
        value = .other
    }
}

private struct SortNumber: Decodable {
    let value: Double
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let number = try? c.decode(Double.self), number.isFinite {
            value = number
            return
        }
        if let text = try? c.decode(String.self),
           let number = SquareRouteMap.coordinate(.text(text), limit: .greatestFiniteMagnitude) {
            value = number
            return
        }
        value = 0
    }
}

private struct ErrorCode: Decodable {
    let blocksRoad: Bool
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { blocksRoad = false; return }
        if let flag = try? c.decode(Bool.self) { blocksRoad = flag; return }
        if let number = try? c.decode(Double.self) { blocksRoad = number.isFinite && number != 0; return }
        if let text = try? c.decode(String.self) { blocksRoad = !text.isEmpty; return }
        blocksRoad = true
    }
}

private enum GeometryPayload: Decodable {
    case rows([Coord])
    case text(String)
    case unsupported

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .unsupported; return }
        if let text = try? c.decode(String.self) { self = .text(text); return }
        if let rows = try? c.decode([Coord].self) { self = .rows(rows); return }
        self = .unsupported
    }
}

private struct Coord: Decodable {
    let latitude: SquareRouteMap.Value?
    let longitude: SquareRouteMap.Value?
    let lat: SquareRouteMap.Value?
    let lng: SquareRouteMap.Value?

    enum CodingKeys: String, CodingKey { case latitude, longitude, lat, lng }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        latitude = try c.decodeIfPresent(MapValue.self, forKey: .latitude)?.value
        longitude = try c.decodeIfPresent(MapValue.self, forKey: .longitude)?.value
        lat = try c.decodeIfPresent(MapValue.self, forKey: .lat)?.value
        lng = try c.decodeIfPresent(MapValue.self, forKey: .lng)?.value
    }

    func point() -> SquareRouteMap.Point? {
        SquareRouteMap.point(.init(latitude: latitude, lat: lat, longitude: longitude, lng: lng))
    }
}
