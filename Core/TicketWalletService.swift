import Foundation
import CoreFoundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Only registration list/info reads. No issuance, verification, payment, refund or mutation path.
public struct TicketWalletService {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration; self.transport = transport
    }
    public static let pageSize = 10
    public static let maximumPages = 10

    /// `POST /api/registration/list` with `owner_type`, `pageNum`, and `pageSize` 10.
    /// Stops at 10 pages, when a page is shorter than `pageSize`, or when `total` names no further page.
    /// A bare array is one page.
    public func list(lane: TicketWalletLane, token: String) async throws -> [TicketWalletTicket] {
        var page = 1
        var collected: [TicketWalletTicket] = []
        while page <= Self.maximumPages {
            let data = try await post("api/registration/list", fields: [
                "owner_type": String(lane.rawValue),
                "pageNum": String(page),
                "pageSize": String(Self.pageSize)
            ], token: token)
            let envelope = try decode(RouteEnvelope.self, data)
            collected.append(contentsOf: envelope.rows)
            guard envelope.hasMore(after: page, pageSize: Self.pageSize, cap: Self.maximumPages) else { break }
            page += 1
        }
        return collected
    }
    public func wallet(token: String) async throws -> TicketWalletSnapshot {
        // Independent reads, stable merge order regardless of response timing.
        async let route = outcome(lane: .route, token: token)
        async let activity = outcome(lane: .activity, token: token)
        let results = await (route, activity)
        try Task.checkCancellation()
        // Cancellation of either lane retires the aggregate before any earlier
        // authorization response can invalidate a newer viewer.
        for result in [results.0, results.1] {
            if case .failure(let error) = result, error is CancellationError { throw error }
        }
        // A still-current authorization failure closes the private wallet.
        for result in [results.0, results.1] {
            if case .failure(let error) = result, error as? APIError == .unauthorized {
                throw APIError.unauthorized
            }
        }
        switch results {
        case (.success(let a), .success(let b)): return TicketWalletSnapshot(tickets: a + b)
        case (.failure(let error), .success(let b)):
            return TicketWalletSnapshot(tickets: b, partialFailure: TicketWalletLaneFailure(lane: .route, issue: TicketWalletIssue(error)))
        case (.success(let a), .failure(let error)):
            return TicketWalletSnapshot(tickets: a, partialFailure: TicketWalletLaneFailure(lane: .activity, issue: TicketWalletIssue(error)))
        case (.failure(let routeError), .failure): throw routeError
        }
    }
    public func detail(id: Int, token: String) async throws -> TicketWalletTicket {
        guard id > 0 else { throw APIError.invalidRequest }
        let data = try await post("api/registration/info", fields: ["id": String(id)], token: token)
        guard let result = try decode(DetailEnvelope.self, data).data, result.id == id else { throw TicketWalletReadFailure.unavailable }
        return result
    }
    private func outcome(lane: TicketWalletLane, token: String) async -> Result<[TicketWalletTicket], Error> {
        do { return .success(try await list(lane: lane, token: token)) }
        catch { return .failure(error) }
    }
    private func post(_ path: String, fields: [String: String], token: String) async throws -> Data {
        guard AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        try Task.checkCancellation()
        let request = try AuthRequestBuilder.makeFormRequest(url: configuration.baseURL.appendingPathComponent(path), fields: fields, token: token)
        let (data, status) = try await transport.send(request)
        try Task.checkCancellation()
        if status == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(status) else { throw APIError.httpStatus(status) }
        let envelope = try decode(StatusEnvelope.self, data)
        if envelope.code == 401 { throw APIError.unauthorized }
        guard envelope.code == 200 else { throw TicketWalletReadFailure.rejected(code: envelope.code, message: envelope.message) }
        return data
    }
    private func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        do { return try JSONDecoder().decode(type, from: data) }
        catch { throw APIError.malformedResponse }
    }
    private struct StatusEnvelope: Decodable {
        let code: Int
        let message: String?
        enum CodingKeys: String, CodingKey { case code, msg }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            code = try c.decode(Int.self, forKey: .code)
            // Malformed message prose must not obscure an authorization status.
            message = try? c.decode(String.self, forKey: .msg)
        }
    }
    private struct ActivityEnvelope: Decodable { let data: [TicketWalletTicket]? }
    private struct DetailEnvelope: Decodable { let data: TicketWalletTicket? }
    private struct RouteEnvelope: Decodable {
        let rows: [TicketWalletTicket]
        let total: Int?
        let paged: Bool
        enum CodingKeys: String, CodingKey { case data }
        struct Page: Decodable {
            let rows: [TicketWalletTicket]?
            let total: Int?
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            guard c.contains(.data), try !c.decodeNil(forKey: .data) else { rows = []; total = nil; paged = false; return }
            if let array = try? c.decode([TicketWalletTicket].self, forKey: .data) {
                rows = array
                total = nil
                paged = false
            } else {
                let page = try c.decode(Page.self, forKey: .data)
                rows = page.rows ?? []
                total = page.total
                paged = true
            }
        }
        func hasMore(after page: Int, pageSize: Int, cap: Int) -> Bool {
            guard paged, rows.count >= pageSize, page < cap, let total, total > 0, pageSize > 0 else { return false }
            let pages = (total + pageSize - 1) / pageSize
            return pages > page
        }
    }
}

/// Companion seats already claimed by the signed-in phone.
/// `POST /api/play/seat-invitations/claim-phone` with `{}`, then `GET /api/play/seat-invitations/mine`.
/// A failed claim still reads mine. A failed mine returns an empty list and does not throw.
public struct WalletSeatInvitation: Equatable, Sendable {
    public let invitationID: String
    public let ownerID: String
    public let ownerType: Int
    public let topicID: String?
    public let title: String
    public let coverURL: String
    public let usableUntil: String
    public init(invitationID: String, ownerID: String, ownerType: Int, topicID: String?, title: String, coverURL: String, usableUntil: String) {
        self.invitationID = invitationID
        self.ownerID = ownerID
        self.ownerType = ownerType
        self.topicID = topicID
        self.title = title
        self.coverURL = coverURL
        self.usableUntil = usableUntil
    }
}

public struct WalletSeatInvitationSource: Sendable {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration
        self.transport = transport
    }
    public func load(token: String) async -> [WalletSeatInvitation] {
        guard AuthRequestBuilder.isValidToken(token) else { return [] }
        _ = await postClaim(token: token)
        return await mine(token: token)
    }
    private func postClaim(token: String) async -> Bool {
        guard let request = request(path: ["api", "play", "seat-invitations", "claim-phone"], method: "POST", token: token, body: Data("{}".utf8)) else { return false }
        do {
            try ChinaReviewedRouteCapability.refuseUnwiredChinaProduction(request)
            _ = try await transport.send(request)
            return true
        } catch { return false }
    }
    private func mine(token: String) async -> [WalletSeatInvitation] {
        guard let request = request(path: ["api", "play", "seat-invitations", "mine"], method: "GET", token: token, body: nil) else { return [] }
        do {
            try ChinaReviewedRouteCapability.refuseUnwiredChinaProduction(request)
            let (data, status) = try await transport.send(request)
            guard (200..<300).contains(status),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  Self.codeOK(object["code"]),
                  let rows = object["data"] as? [[String: Any]] else { return [] }
            return rows.compactMap(Self.card)
        } catch { return [] }
    }
    private func request(path: [String], method: String, token: String, body: Data?) -> URLRequest? {
        let url = path.reduce(configuration.baseURL) { $0.appendingPathComponent($1) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.httpShouldHandleCookies = false
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        return request
    }
    private static func codeOK(_ value: Any?) -> Bool {
        if let text = value as? String { return text == "200" }
        if let number = value as? Int { return number == 200 }
        if let number = value as? NSNumber, CFGetTypeID(number as CFTypeRef) != CFBooleanGetTypeID() { return number.intValue == 200 }
        return false
    }
    private static func card(_ row: [String: Any]) -> WalletSeatInvitation? {
        guard let invitationID = text(row["invitationId"]), let ownerID = text(row["ownerId"]) else { return nil }
        let ownerType = int(row["ownerType"]) ?? 0
        return WalletSeatInvitation(
            invitationID: invitationID, ownerID: ownerID, ownerType: ownerType,
            topicID: text(row["topicId"]), title: text(row["topicName"]) ?? "",
            coverURL: text(row["topicCover"]) ?? "", usableUntil: text(row["usableUntil"]) ?? "")
    }
    private static func text(_ value: Any?) -> String? {
        if let text = value as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let number = value as? NSNumber, CFGetTypeID(number as CFTypeRef) != CFBooleanGetTypeID() { return number.stringValue }
        return nil
    }
    private static func int(_ value: Any?) -> Int? {
        if let number = value as? Int { return number }
        if let number = value as? NSNumber, CFGetTypeID(number as CFTypeRef) != CFBooleanGetTypeID() { return number.intValue }
        if let text = value as? String { return Int(text) }
        return nil
    }
}
