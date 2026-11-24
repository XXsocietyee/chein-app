import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// One gate per cast feature. All default off. P2 adds the route rows; until a row is
/// admitted, `ChinaReviewedRouteCapability.offersFeature` refuses the China production host.
/// The voice read stays reviewed (`newBackendOnly`), not `.liveInProduction`.
public enum CastCapability: Hashable, Sendable {
    /// `POST /api/play/run/profile`. Write. Default off.
    case castProfile
    /// `GET /api/topic/cast/voice`. Read. Own gate, not the shared `.reads` lease. Default off.
    case castVoice
    /// `POST /api/play/run/branch`. Write. Default off.
    case castBranch

    /// Owner 2026-11-24: production enables no cast capability. Fixtures opt in explicitly.
    public static let productionEnabled: Set<CastCapability> = []
}

/// Cast contract endpoints (hengyin docs/design/cast-contract-1119.md, follow-up feat/cast-1119).
/// Standalone so this package does not edit `PlayExperienceService` (P2).
public struct CastService {
    public let configuration: APIConfiguration
    public let transport: any HTTPTransport
    public let enabled: Set<CastCapability>
    public init(configuration: APIConfiguration, transport: any HTTPTransport, enabled: Set<CastCapability> = []) {
        self.configuration = configuration; self.transport = transport; self.enabled = enabled
    }

    /// `POST /api/play/run/profile {runId, name, identityKey}`. The server requires 1–12
    /// characters, so an empty answer is sent as 「你」, the same fallback the story uses.
    public func saveCastProfile(runID: Int, profile: CastPlayerProfile, token: String) async throws {
        guard runID > 0 else { throw PlayExperienceError.invalidAction }
        var body: [String: PlayWireValue] = ["runId": .int(runID), "name": .string(profile.name ?? CastStoryVariables.playerFallback)]
        if let key = profile.identityKey { body["identityKey"] = .string(key) }
        _ = try await send("api/play/run/profile", json: body, capability: .castProfile, token: token)
    }

    /// `GET /api/topic/cast/voice?topicId=&chapterId=&blockKey=` → `{url}`. A response without
    /// an https URL is "no voice", not an error to show. `runId` lets the server voice `{玩家}`.
    public func castVoice(topicID: Int, chapterID: Int, blockKey: String, runID: Int? = nil, token: String) async throws -> String? {
        let key = blockKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard topicID > 0, chapterID > 0, !key.isEmpty, key.count <= 64 else { throw PlayExperienceError.invalidAction }
        var query = ["topicId": String(topicID), "chapterId": String(chapterID), "blockKey": key]
        if let runID, runID > 0 { query["runId"] = String(runID) }
        let raw = try await send("api/topic/cast/voice", query: query, capability: .castVoice, token: token)
        guard let url = raw["url"].text, Self.validHTTPS(url) else { return nil }
        return url
    }

    /// `POST /api/play/run/branch {runId, chapterId, blockKey, optionIndex}`. The server settles
    /// trust. A repeat answer returns the run's original pick, which the caller adopts.
    public func recordCastBranch(runID: Int, chapterID: Int, blockKey: String, optionIndex: Int, token: String) async throws -> Int? {
        let key = blockKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard runID > 0, chapterID > 0, !key.isEmpty, key.count <= 64, (0..<3).contains(optionIndex) else { throw PlayExperienceError.invalidAction }
        let raw = try await send("api/play/run/branch", json: [
            "runId": .int(runID), "chapterId": .int(chapterID), "blockKey": .string(key), "optionIndex": .int(optionIndex)
        ], capability: .castBranch, token: token)
        return raw["optionIndex"].tolerantInteger.flatMap { (0..<3).contains($0) ? $0 : nil }
    }

    private func send(_ path: String, query: [String: String] = [:], json: [String: PlayWireValue]? = nil,
                      capability: CastCapability, token: String) async throws -> PlayWireValue {
        guard enabled.contains(capability) else { throw PlayExperienceError.disabled }
        // Fixture hosts are offered. The China production host is offered only for an admitted
        // live route. Cast rows are not live, so this refuses www.chengyinhub.com even if a gate is on.
        guard ChinaReviewedRouteCapability.offersFeature(path, baseURL: configuration.baseURL) else { throw PlayExperienceError.disabled }
        let request = try make(path, query: query, json: json, token: token)
        let data: Data
        let status: Int
        do { (data, status) = try await transport.send(request) } catch { throw error }
        let envelope = try? JSONDecoder().decode(PlayWireValue.self, from: data)
        let code = envelope?["code"].tolerantInteger
        if status == 401 || code == 401 { throw PlayExperienceError.unauthorized }
        guard (200..<300).contains(status) else { throw PlayExperienceError.unknownResult }
        guard let code else { throw PlayExperienceError.malformed }
        guard code == 200 else { throw PlayExperienceError.rejected(code, envelope?["msg"].text) }
        return envelope?["data"] ?? .null
    }

    private func make(_ path: String, query: [String: String], json: [String: PlayWireValue]?, token: String) throws -> URLRequest {
        let segments = path.split(separator: "/", omittingEmptySubsequences: false)
        guard segments.first == "api", segments.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95
        } }), AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent(path))
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if !query.isEmpty {
            var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
            request.url = components.url
        }
        if let json {
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            request.httpBody = try encoder.encode(json)
        } else {
            request.httpMethod = "GET"
        }
        return request
    }

    static func validHTTPS(_ value: String) -> Bool {
        guard let url = URLComponents(string: value), url.scheme == "https", url.host?.isEmpty == false, url.user == nil, url.password == nil else { return false }
        return true
    }
}
