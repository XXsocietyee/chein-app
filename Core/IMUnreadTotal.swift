import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Mini-program pages/talent/list `loadImUnread`: POST /api/im/unread-total, no
/// fields, `data` is the server total (muted and group rows already excluded by
/// ImServiceImpl.unreadTotal). Failure is silent in the source: no badge.
public struct IMUnreadTotalService {
    public static let path = "api/im/unread-total"
    /// Call sites build a new service per badge read. The value is dropped when the flight finishes.
    private static let reads = InFlightReadCoalescer<InFlightHTTPBody>()
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    private let enabled: Bool
    public init(configuration: APIConfiguration, transport: any HTTPTransport, enabledPaths: Set<String>) {
        self.configuration = configuration; self.transport = transport; enabled = enabledPaths.contains(Self.path)
    }
    public var isConfigured: Bool { enabled }
    public func total(token: String) async throws -> Int {
        guard enabled else { throw APIError.notConfigured }
        guard AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        var request = try AuthRequestBuilder.makeFormRequest(url: configuration.baseURL.appendingPathComponent(Self.path), fields: [:], token: token)
        request.httpShouldHandleCookies = false
        try Task.checkCancellation()
        let response = try await Self.reads.join(InFlightReadKey.request(request)) {
            let (data, status) = try await self.transport.send(request)
            return InFlightHTTPBody(data: data, status: status)
        }
        try Task.checkCancellation()
        let (data, status) = (response.data, response.status)
        guard (200..<300).contains(status) else { throw MessagingReadFailure(httpStatus: status) }
        return try Self.decode(data)
    }
    public static func decode(_ data: Data) throws -> Int {
        struct Envelope: Decodable { let code: Int; let data: Int? }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else { throw APIError.malformedResponse }
        guard envelope.code == 200 else { throw MessagingReadFailure(code: envelope.code) }
        // Source falls back `res.data || 0`; a negative total is not a count.
        let total = envelope.data ?? 0
        guard total >= 0 else { throw APIError.malformedResponse }
        return total
    }
}

/// A response issued earlier than one already applied never rolls the badge back.
/// A genuine decrease from a later read is still applied; ordering is by issue ticket.
public struct IMUnreadTotalMonotonicGuard: Equatable {
    private var issued = 0
    private var appliedTicket = 0
    private var latest: Int?
    public init() {}
    public mutating func begin() -> Int { issued += 1; return issued }
    public mutating func accept(_ total: Int, ticket: Int, sessionIsCurrent: Bool) throws -> Int {
        guard sessionIsCurrent else { throw CancellationError() }
        guard total >= 0 else { throw APIError.malformedResponse }
        if ticket < appliedTicket, let latest { return latest }
        appliedTicket = ticket; latest = total
        return total
    }
    public mutating func reset() { self = .init() }
}

@MainActor public protocol IMUnreadTotalReading: AnyObject {
    var identity: MessagingReadIdentity? { get }
    var isConfigured: Bool { get }
    func unreadTotal() async throws -> Int
}

@MainActor public final class IMUnreadTotalReader: IMUnreadTotalReading {
    private let service: IMUnreadTotalService?
    private let session: () -> IMSafetySession?
    private var monotonic = IMUnreadTotalMonotonicGuard()
    private var guardedIdentity: MessagingReadIdentity?
    public init(service: IMUnreadTotalService?, session: @escaping () -> IMSafetySession?) {
        self.service = service; self.session = session
    }
    public var identity: MessagingReadIdentity? { session()?.identity }
    public var isConfigured: Bool { service?.isConfigured == true }
    public func unreadTotal() async throws -> Int {
        guard let service, service.isConfigured else { throw APIError.notConfigured }
        guard let snapshot = session() else { throw APIError.unauthorized }
        if guardedIdentity != snapshot.identity { monotonic.reset(); guardedIdentity = snapshot.identity }
        let ticket = monotonic.begin()
        let total = try await snapshot.withToken { try await service.total(token: $0) }
        guard !Task.isCancelled else { throw CancellationError() }
        return try monotonic.accept(total, ticket: ticket, sessionIsCurrent: session() == snapshot)
    }
}
