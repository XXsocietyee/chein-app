import Foundation

/// Mini-program subpackageRoam official routes (GET /api/preset/route/list and /route/info).
/// Port of subpackageRoam/utils/official-route.js: distance is km, durations are minutes.
public struct OfficialRoute: Equatable, Identifiable {
    public let id: String
    public let name: String
    public let city: String
    public let previewImage: String
    /// Mini-program `metaText` pieces: city, distance, duration (empty parts dropped).
    public let distanceKm: Double
    public let totalMinutes: Int
}

public struct OfficialRouteNode: Equatable, Identifiable {
    public var id: String { key }
    public let key: String
    public let order: Int
    public let name: String
    public let address: String
    public let imageURL: String
    public let stayMinutes: Int
    public let latitude: Double?
    public let longitude: Double?
}

public struct OfficialRouteDetail: Equatable {
    public let route: OfficialRoute
    public let nodes: [OfficialRouteNode]
}

public enum OfficialRouteFormat {
    /// `1.5 km` / `3 km`; empty when not positive.
    public static func distance(_ km: Double) -> String {
        guard km.isFinite, km > 0 else { return "" }
        return km == km.rounded() ? "\(Int(km)) km" : String(format: "%.1f km", km)
    }
    /// Locale-aware duration: `45 分钟`/`45 min`, `1 小时 20 分`/`1 h 20 min`.
    public static func duration(_ minutes: Int, chinese: Bool) -> String {
        guard minutes > 0 else { return "" }
        if minutes < 60 { return chinese ? "\(minutes) 分钟" : "\(minutes) min" }
        let h = minutes / 60, m = minutes % 60
        if chinese { return m > 0 ? "\(h) 小时 \(m) 分" : "\(h) 小时" }
        return m > 0 ? "\(h) h \(m) min" : "\(h) h"
    }
    public static func meta(_ route: OfficialRoute, chinese: Bool) -> String {
        [route.city, distance(route.distanceKm), duration(route.totalMinutes, chinese: chinese)]
            .filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

enum OfficialRouteDecoding {
    private struct Flex: Decodable {
        let text: String
        let number: Double?
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let s = try? c.decode(String.self) { text = s.trimmingCharacters(in: .whitespacesAndNewlines); number = Double(text) }
            else if let i = try? c.decode(Int64.self) { text = String(i); number = Double(i) }
            else if let d = try? c.decode(Double.self) { text = String(d); number = d }
            else { text = ""; number = nil }
        }
    }
    private struct RawNode: Decodable {
        let id: Flex?, name: Flex?, address: Flex?, imgUrl: Flex?, nodeTime: Flex?, latitude: Flex?, longitude: Flex?
    }
    private struct RawRoute: Decodable {
        let id: Flex?, name: Flex?, city: Flex?, previewImg: Flex?, totalDistance: Flex?, totalTime: Flex?
        let nodes: [RawNode]?
    }
    private struct ListEnvelope: Decodable { let data: [RawRoute]? }
    private struct DetailEnvelope: Decodable { let data: RawRoute? }

    private static func positive(_ f: Flex?) -> Double { (f?.number).flatMap { $0.isFinite && $0 > 0 ? $0 : nil } ?? 0 }
    private static func route(_ r: RawRoute) -> OfficialRoute? {
        let id = r.id?.text ?? "", name = r.name?.text ?? ""
        guard !id.isEmpty, !name.isEmpty else { return nil }
        return OfficialRoute(id: id, name: name, city: r.city?.text ?? "", previewImage: r.previewImg?.text ?? "",
                             distanceKm: positive(r.totalDistance), totalMinutes: Int(positive(r.totalTime).rounded()))
    }
    static func list(_ data: Data) throws -> [OfficialRoute] {
        guard let rows = (try? JSONDecoder().decode(ListEnvelope.self, from: data))?.data else { throw APIError.malformedResponse }
        return rows.compactMap(route)
    }
    static func detail(_ data: Data) throws -> OfficialRouteDetail {
        guard let raw = (try? JSONDecoder().decode(DetailEnvelope.self, from: data))?.data, let base = route(raw) else { throw APIError.malformedResponse }
        var order = 0
        let nodes: [OfficialRouteNode] = (raw.nodes ?? []).enumerated().compactMap { index, n in
            guard let name = n.name?.text, !name.isEmpty else { return nil }
            order += 1
            let lat = n.latitude, lng = n.longitude
            let hasPoint = !(lat?.text ?? "").isEmpty && !(lng?.text ?? "").isEmpty
                && lat?.number.map({ abs($0) <= 90 }) == true && lng?.number.map({ abs($0) <= 180 }) == true
            let nid = n.id?.text ?? ""
            return OfficialRouteNode(key: nid.isEmpty ? "n\(index)" : nid, order: order, name: name,
                address: n.address?.text ?? "", imageURL: n.imgUrl?.text ?? "", stayMinutes: Int(positive(n.nodeTime).rounded()),
                latitude: hasPoint ? lat?.number : nil, longitude: hasPoint ? lng?.number : nil)
        }
        return OfficialRouteDetail(route: base, nodes: nodes)
    }
}

/// Injected by the host; nil closures mean the read is not configured.
public struct OfficialRouteReader {
    public enum Failure: Error { case notFound }
    public var list: () async throws -> [OfficialRoute]
    public var detail: (String) async throws -> OfficialRouteDetail
    public init(list: @escaping () async throws -> [OfficialRoute], detail: @escaping (String) async throws -> OfficialRouteDetail) {
        self.list = list; self.detail = detail
    }
    /// Mini-program id rule: 1-18 ASCII digits.
    public static func isValidID(_ id: String) -> Bool { (1...18).contains(id.count) && id.allSatisfy { $0.isASCII && $0.isNumber } }
}

extension RoamService {
    public func officialRoutes(token: String) async throws -> [OfficialRoute] {
        try OfficialRouteDecoding.list(try await presetRead("api/preset/route/list", query: [:], token: token))
    }
    public func officialRoute(id: String, token: String) async throws -> OfficialRouteDetail {
        guard OfficialRouteReader.isValidID(id) else { throw OfficialRouteReader.Failure.notFound }
        do { return try OfficialRouteDecoding.detail(try await presetRead("api/preset/route/info", query: ["id": id], token: token)) }
        // Mini-program: backend business failure on info (missing / delisted) = not found.
        catch APIError.businessCode { throw OfficialRouteReader.Failure.notFound }
    }
}
