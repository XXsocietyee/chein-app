import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// RSESS-2: utils/roam-share-snapshot.js `publishShareSnapshot` — `POST api/roam/share/snapshot`
/// (form: clientTs, sessionId, snapshot JSON). The server quantizes coordinates and content-checks the text;
/// the 32-hex token is the only thing the link carries. The track sent is the same clipped route the card shows,
/// and only when the player turned the route on.
public enum RoamShareLinkReason: Equatable { case ready(String), failed, unavailable }

public struct RoamShareSnapshotPublisher {
    public static let path = "api/roam/share/snapshot"
    private static let tokenPattern = #"^[a-f0-9]{32}$"#
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    private let token: () -> String?
    public init(configuration: APIConfiguration, transport: any HTTPTransport, token: @escaping () -> String?) {
        self.configuration = configuration; self.transport = transport; self.token = token
    }

    /// MP `buildSharePayload`, from a saved local record.
    public static func payload(_ record: RoamHistoryRecord, includeRoute: Bool, routeName: String?) -> [String: Any] {
        let track = includeRoute ? Array(RoamShareRoutePrivacy.clippedTrack(record.track).prefix(500)) : []
        let pois: [[String: Any]] = record.pois.prefix(50).map { place in
            var row: [String: Any] = ["name": place.name, "cat": place.cat ?? "", "catLabel": ""]
            if includeRoute, abs(place.lat) <= 90, abs(place.lng) <= 180 { row["lat"] = place.lat; row["lng"] = place.lng }
            return row
        }
        var body: [String: Any] = [
            "routeName": routeName ?? "", "time": record.durationText ?? "",
            "medal": record.medal ?? "", "shopMedalName": record.shopMedalName ?? "",
            "track": track.map { ["lat": $0.lat, "lng": $0.lng] }, "pois": pois,
        ]
        body["distance"] = record.distance.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil } ?? NSNull()
        body["explorePct"] = record.explorePct.flatMap { $0 >= 0 ? $0 : nil } ?? NSNull()
        body["shops"] = record.shops.flatMap { $0 >= 0 ? $0 : nil } ?? NSNull()
        return body
    }

    public func publish(_ record: RoamHistoryRecord, includeRoute: Bool, routeName: String?) async -> RoamShareLinkReason {
        guard let sessionID = record.serverSessionID, sessionID > 0, record.ts > 0, let token = token(),
              let snapshot = try? JSONSerialization.data(withJSONObject: Self.payload(record, includeRoute: includeRoute, routeName: routeName), options: [.sortedKeys]),
              let text = String(data: snapshot, encoding: .utf8),
              let request = try? AuthRequestBuilder.makeFormRequest(url: configuration.baseURL.appendingPathComponent(Self.path),
                  fields: ["clientTs": String(record.ts), "sessionId": String(sessionID), "snapshot": text], token: token)
        else { return .failed }
        guard let response = try? await transport.send(request) else { return .failed }
        let (bytes, status) = response
        guard (200..<300).contains(status),
              let root = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              (root["code"] as? Int) == 200 || (root["code"] as? String) == "200",
              let data = root["data"] as? [String: Any], let value = data["token"] as? String,
              value.range(of: Self.tokenPattern, options: .regularExpression) != nil else { return .failed }
        return .ready(value)
    }

    /// The link a friend opens: `subpackageRoam/session?shareToken=` (parsed by MiniProgramPageLink).
    public static func link(token: String) -> URL? {
        var components = URLComponents()
        components.scheme = CheinDeepLink.scheme; components.host = "mp"; components.path = "/subpackageRoam/session/index"
        components.queryItems = [URLQueryItem(name: "shareToken", value: token)]
        return components.url
    }
}
