import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Round-2 Core service methods for `play-roam` MP gaps:
/// `RTEAMS-3`, `JREPORT-3`, `SALBUM-6`.
/// RHIST-r7-1: passport history is `RoamPassportHistoryReadRoute` (`GET /api/roam/passport/history`), not a list invented here.
@MainActor
public final class PlayRoamRound2Service {
    public static let paths: Set<String> = [
        "api/team/applications",
        "api/rank/list",
        "api/roam/stamp/list"
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
        json: [String: PlayWireValue]? = nil,
        form: [String: String]? = nil,
        requireAuth: Bool = true
    ) throws -> URLRequest {
        var url = baseURL.appendingPathComponent(path)
        if !query.isEmpty {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw APIError.invalidRequest
            }
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
        if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            request.httpBody = try encoder.encode(json)
        } else if let form {
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            var components = URLComponents()
            components.queryItems = form.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
            let encoded = (components.percentEncodedQuery ?? "").replacingOccurrences(of: "+", with: "%2B")
            request.httpBody = Data(encoded.utf8)
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

    /// `RTEAMS-3`: `POST /api/team/applications {teamId}`
    public func fetchTeamApplications(teamID: Int) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/team/applications",
            method: "POST",
            json: ["teamId": .integer(Int64(teamID))]
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

    /// `SALBUM-6`: `POST /api/roam/stamp/list` (form `pageNum`, `pageSize=50`)
    public func fetchStampAlbum(pageNum: Int, pageSize: Int = 50) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/roam/stamp/list",
            method: "POST",
            form: ["pageNum": String(pageNum), "pageSize": String(pageSize)]
        ) else { return .unauthorized }
        return await send(req)
    }
}
