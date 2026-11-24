import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Round-2 Core service methods for `play-roam` MP gaps:
/// `RHIST-1`, `ROAM-13`, `RTEAMS-3`, `JREPORT-3`, `SALBUM-6`.
@MainActor
public final class PlayRoamRound2Service {
    public static let paths: Set<String> = [
        "api/roam/history/list",
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

    /// `RHIST-1`: `GET /api/roam/history/list?pageNum=&pageSize=`
    public func fetchRoamHistory(pageNum: Int, pageSize: Int = 20) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/roam/history/list",
            method: "GET",
            query: ["pageNum": String(pageNum), "pageSize": String(pageSize)]
        ) else { return .unauthorized }
        return await send(req)
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

    /// `JREPORT-3`: `GET /api/rank/list` with `scope`, `topicId`, `activityId`, `teamId`, `cityCode`, `countryCode`, `clubId`
    public func fetchLeaderboard(_ queryModel: JourneyLeaderboardScopeQuery) async -> PlayerGapReply {
        var q: [String: String] = ["scope": queryModel.scope]
        if let v = queryModel.topicID { q["topicId"] = String(v) }
        if let v = queryModel.activityID { q["activityId"] = String(v) }
        if let v = queryModel.teamID { q["teamId"] = String(v) }
        if let v = queryModel.cityCode { q["cityCode"] = v }
        if let v = queryModel.countryCode { q["countryCode"] = v }
        if let v = queryModel.clubID { q["clubId"] = String(v) }
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
