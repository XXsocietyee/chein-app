import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum OfficialReadFailure: Error, Equatable {
    case noPublisherPermission, unavailable, forbidden, rejected(Int)
    /// Non-200 broadcast stats, with the server `msg`.
    case explained(Int, String)
}
/// Explicit GET allowlist. No generic public path, mutation, click tracking, purchase or signup.
public struct OfficialEventService {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    /// Event lists, roam tasks, and detail use one in-flight body. Status stays outside the join.
    private let reads = InFlightReadCoalescer<InFlightHTTPBody>()
    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration; self.transport = transport
    }
    public func events(city: String? = nil, token: String? = nil) async throws -> [OfficialEvent] {
        let rows: [OfficialEvent] = try await get("api/official/events", city: city, token: token)
        return complete(rows)
    }
    /// Bytes and status of `GET api/official/events`. `events()` only returns decoded rows, so a
    /// malformed success cannot be told apart from a transport failure. 401 still signs the caller out.
    public func eventsReceipt(city: String? = nil, token: String? = nil) async throws -> CloudB3RawBody {
        if let token { try requireToken(token) }
        guard var components = URLComponents(url: configuration.baseURL.appendingPathComponent("api/official/events"), resolvingAgainstBaseURL: false) else { throw APIError.invalidRequest }
        if let city { components.queryItems = [URLQueryItem(name: "city", value: city)] }
        guard let url = components.url else { throw APIError.invalidRequest }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"; request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue(token, forHTTPHeaderField: "Authorization") }
        let (data, status) = try await send(request)
        let envelope = try? JSONDecoder().decode(Status.self, from: data)
        if status == 401 || envelope?.code == 401 { throw APIError.unauthorized }
        return CloudB3RawBody(body: data, status: status)
    }
    /// ROAM-r11-2 (D-73): `GET api/official/active-for-roam` — the roam task list's 全部 source: 报名中 / 进行中 and
    /// roam-bound, filtered by the server, guests included. MP subpackageRoam/components/cy/scene-roam-task-list/index.js:62-66.
    public func activeForRoam(token: String? = nil) async throws -> [OfficialEvent] {
        let rows: [OfficialEvent] = try await get("api/official/active-for-roam", token: token)
        return complete(rows)
    }
    public func detail(id: Int, token: String? = nil) async throws -> OfficialEvent {
        guard id > 0 else { throw APIError.invalidRequest }
        let value: OfficialEvent = try await get("api/official/events/\(id)", token: token, missingEvent: true)
        guard value.isCompleteRecord, value.id == id else { throw OfficialReadFailure.unavailable }
        return value
    }
    public func myEvents(token: String) async throws -> [OfficialEvent] {
        try requireToken(token)
        let rows: [OfficialEvent] = try await get("api/official/my-events", token: token)
        return complete(rows)
    }
    public func partyInbox(token: String) async throws -> [OfficialPartyInvite] {
        try requireToken(token)
        let value: InboxPayload = try await get("api/official/v2/party-inbox", token: token)
        var seen = Set<Int>()
        return value.rows.filter { $0.id > 0 && seen.insert($0.id).inserted }
    }
    public func canPublish(token: String? = nil) async throws -> Bool {
        let value: PermissionPayload = try await get("api/official/can-publish", token: token)
        return value.canPublish == true
    }
    public func myPublished(token: String) async throws -> OfficialPublished {
        try requireToken(token)
        return try await get("api/official/my-published", token: token)
    }
    public func broadcastStats(id: Int, token: String) async throws -> OfficialBroadcastStats {
        guard id > 0 else { throw APIError.invalidRequest }
        try requireToken(token)
        return try await get("api/official/broadcast/\(id)/stats", token: token, missingBroadcast: true)
    }
    private func requireToken(_ token: String) throws {
        guard AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
    }
    private static func trimmedServerNote(_ raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
    private func complete(_ rows: [OfficialEvent]) -> [OfficialEvent] {
        var seen = Set<Int>()
        return rows.filter { $0.isCompleteRecord && seen.insert($0.id).inserted }
    }
    private func get<T: Decodable>(_ path: String, city: String? = nil, token: String?, missingEvent: Bool = false, missingBroadcast: Bool = false) async throws -> T {
        if let token { try requireToken(token) }
        guard var components = URLComponents(url: configuration.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else { throw APIError.invalidRequest }
        if let city { components.queryItems = [URLQueryItem(name: "city", value: city)] }
        guard let url = components.url else { throw APIError.invalidRequest }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"; request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue(token, forHTTPHeaderField: "Authorization") }
        let (data, status) = try await send(request)
        let envelope = try? JSONDecoder().decode(Status.self, from: data)
        if status == 401 || envelope?.code == 401 { throw APIError.unauthorized }
        // This exact source phrase is a normal permission state, not a retryable load error.
        if envelope?.code != 200, envelope?.msg?.contains("无官方发布权限") == true { throw OfficialReadFailure.noPublisherPermission }
        if status == 403 || envelope?.code == 403 { throw OfficialReadFailure.forbidden }
        // Source official-detail: only an explicit "content is gone" is unrecoverable.
        if missingEvent && (status == 404 || status == 410) { throw OfficialReadFailure.unavailable }
        guard (200..<300).contains(status) else {
            if missingBroadcast, let note = Self.trimmedServerNote(envelope?.msg) { throw OfficialReadFailure.explained(status, note) }
            throw APIError.httpStatus(status)
        }
        guard let code = envelope?.code else { throw APIError.malformedResponse }
        guard code == 200 else {
            if missingEvent && (code == 404 || code == 410
                || envelope?.msg?.trimmingCharacters(in: .whitespacesAndNewlines) == "活动不存在") { throw OfficialReadFailure.unavailable }
            // The stats source intentionally hides ownership behind “not found”. Do not infer deletion.
            if missingBroadcast && envelope?.msg == "通知不存在" { throw OfficialReadFailure.unavailable }
            if missingBroadcast, let note = Self.trimmedServerNote(envelope?.msg) { throw OfficialReadFailure.explained(code, note) }
            throw OfficialReadFailure.rejected(code)
        }
        do { return try JSONDecoder().decode(Envelope<T>.self, from: data).data }
        catch { throw APIError.malformedResponse }
    }
    /// Status stays outside the join, so a finished read is dropped and the next call sends again.
    private func send(_ request: URLRequest) async throws -> (Data, Int) {
        try Task.checkCancellation()
        let response = try await reads.join(InFlightReadKey.request(request)) {
            let (data, status) = try await self.transport.send(request)
            return InFlightHTTPBody(data: data, status: status)
        }
        try Task.checkCancellation()
        return (response.data, response.status)
    }
    private struct Status: Decodable { let code: Int?; let msg: String? }
    private struct Envelope<T: Decodable>: Decodable { let data: T }
    private struct PermissionPayload: Decodable { let canPublish: Bool? }
    private struct InboxPayload: Decodable {
        let rows: [OfficialPartyInvite]
        enum CodingKeys: String, CodingKey { case rows }
        init(from decoder: Decoder) throws {
            if let values = try? [OfficialPartyInvite](from: decoder) { rows = values; return }
            let c = try decoder.container(keyedBy: CodingKeys.self)
            rows = try c.decode([OfficialPartyInvite].self, forKey: .rows)
        }
    }
}
