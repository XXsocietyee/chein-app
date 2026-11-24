import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Round-2 Core service methods for `play-roam` MP gaps:
/// `ROAM-13`, `RTEAMS-3`, `JREPORT-3`, `SALBUM-6`.
/// RHIST-r7-1: passport history is `RoamPassportHistoryReadRoute` (`GET /api/roam/passport/history`), not a list invented here.
@MainActor
public final class PlayRoamRound2Service {
    public static let paths: Set<String> = [
        "api/roam/city-strip",
        "api/team/applications",
        "api/rank/list",
        "api/roam/stamp/album"
    ]

    public let baseURL: URL
    private let token: () -> String?
    private let transport: any HTTPTransport

    public init(baseURL: URL, token: @escaping () -> String?, transport: any HTTPTransport) {
        self.baseURL = baseURL
        self.token = token
        self.transport = transport
    }

    func makeRequest(
        _ path: String,
        method: String,
        query: [String: String] = [:],
        requireAuth: Bool = true
    ) throws -> URLRequest {
        var url = baseURL.appendingPathComponent(path)
        if !query.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
            guard let built = components.url else { throw APIError.invalidRequest }
            url = built
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if requireAuth {
            guard let token = token(), AuthRequestBuilder.isValidToken(token) else {
                throw APIError.invalidRequest
            }
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func send(_ request: URLRequest) async -> PlayerGapReply {
        do {
            let (data, status) = try await transport.send(request)
            return PlayerGapReply.classify(data: data, status: status)
        } catch {
            return .unknown
        }
    }

    /// `ROAM-13`: `GET /api/roam/city-strip`
    public func fetchCityStrip() async -> PlayerGapReply {
        guard let req = try? makeRequest("api/roam/city-strip", method: "GET", requireAuth: false) else {
            return .unknown
        }
        return await send(req)
    }

    /// `RTEAMS-3`: `GET /api/team/applications?teamId=`
    public func fetchTeamApplications(teamID: Int) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/team/applications",
            method: "GET",
            query: ["teamId": String(teamID)]
        ) else { return .unauthorized }
        return await send(req)
    }

    /// `JREPORT-3`: `GET /api/rank/list` as `journey-api.js` `rank` (`scope`, `scopeId`, `period` via `idQuery`).
    /// Topic, city, country, club and team ids are the `scopeId` of one tab, not extra query keys.
    public func fetchLeaderboard(_ queryModel: JourneyLeaderboardScopeQuery) async -> PlayerGapReply {
        let items = JourneyRankBoardContract.query(scope: queryModel.scope, scopeID: queryModel.scopeID ?? "", period: queryModel.period)
        var q: [String: String] = [:]
        for item in items {
            if let value = item.value { q[item.name] = value }
        }
        guard let req = try? makeRequest("api/rank/list", method: "GET", query: q) else {
            return .unauthorized
        }
        return await send(req)
    }

    /// `SALBUM-6`: `GET /api/roam/stamp/album?pageNum=&pageSize=50`
    public func fetchStampAlbum(pageNum: Int, pageSize: Int = 50) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/roam/stamp/album",
            method: "GET",
            query: ["pageNum": String(pageNum), "pageSize": String(pageSize)]
        ) else { return .unauthorized }
        return await send(req)
    }
}
