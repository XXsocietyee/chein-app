import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// U08-03 creator maintenance workbench and U08-04 creator post-game outcome report (hengyin
/// integration/backend-app-r2 `a1974a9a2` / `955175611`). Author-only, non-money reads and writes on the
/// caller's own topics. Production does not serve these routes yet: a route-level 404 (no `errorCode`)
/// is `routeAbsent`, and the entries that call it stay hidden.
public enum CreatorStudioRoute {
    public static let feedback = "api/creator/feedback"
    public static let tickets = "api/creator/maintenance/tickets"
    public static let ticketRequests = "api/creator/maintenance/requests"
    public static let postGameOutcome = "api/creator/analytics/post-game-outcome"
    /// Every path the client sends, in the `{}` id form the reviewed leases use.
    public static let leasePaths: Set<String> = [
        feedback, tickets, tickets + "/{}", tickets + "/{}/close", ticketRequests + "/{}", postGameOutcome
    ]
}

public enum CreatorStudioFailure: Error, Equatable, Sendable {
    /// The backend has no such route (404 without `errorCode`); hide the entry.
    case routeAbsent
    case unauthorized
    case notConfigured
    /// 404 with a business code: TOPIC_NOT_FOUND, TICKET_NOT_FOUND, CREATOR_TOPICS_NOT_FOUND, FEEDBACK_NOT_FOUND.
    case notFound(code: String)
    /// 400/409 with the server's machine code (FIX_NOT_PUBLISHED, TICKET_VERSION_CONFLICT, ...).
    case rejected(status: Int, code: String?, message: String?)
    /// 5xx or REPORT_SOURCE_UNAVAILABLE: never shown as 0.
    case unavailable(code: String?)
    case malformed
}

// MARK: U08-03 wire

public struct CreatorFeedbackItem: Decodable, Equatable, Identifiable, Sendable {
    public let feedbackId: Int
    public let topicId: Int
    public let topicName: String?
    public let nodeId: Int?
    public let nodeName: String?
    /// PLACE, QUESTION or OTHER (U08-02).
    public let category: String?
    public let content: String?
    public let configVersion: Int?
    public let contentRevisionId: Int?
    public let createdAt: String?
    public let ticketId: Int?
    public var id: Int { feedbackId }
}

public struct CreatorStudioPage<Item: Decodable & Equatable & Sendable>: Decodable, Equatable, Sendable {
    public let items: [Item]
    public let hasMore: Bool
    public let nextCursor: String?
}

public struct CreatorMaintenanceTicket: Decodable, Equatable, Identifiable, Sendable {
    public enum Stage: String, Sendable { case reported = "REPORTED", fixDrafted = "FIX_DRAFTED", fixPublished = "FIX_PUBLISHED", retested = "RETESTED", closed = "CLOSED" }
    public struct Baseline: Decodable, Equatable, Sendable { public let configVersion: Int; public let contentRevisionId: Int? }
    public struct Current: Decodable, Equatable, Sendable { public let draftConfigVersion: Int?; public let publishedConfigVersion: Int? }
    public struct Evidence: Decodable, Equatable, Sendable { public let fixDrafted: Bool; public let fixPublished: Bool; public let retestedByAuthor: Bool }
    public let ticketId: Int
    public let topicId: Int
    public let topicName: String?
    public let title: String
    public let note: String?
    public let status: String
    /// Derived on the server from publish and retest facts; never stored or advanced by the client.
    public let stage: String
    public let version: Int
    public let baseline: Baseline
    public let current: Current
    public let evidence: Evidence
    public let canCloseFixed: Bool
    public let resolution: String?
    public let fixedConfigVersion: Int?
    public let closeReason: String?
    public let createdAt: String?
    public let closedAt: String?
    public let feedback: [CreatorFeedbackItem]
    public var id: Int { ticketId }
    public var isClosed: Bool { status == "CLOSED" }
    public var knownStage: Stage? { Stage(rawValue: stage) }
}

public struct CreatorTicketOpenRequest: Equatable, Sendable {
    public let requestId: String
    public let topicId: Int
    public let title: String
    public let note: String?
    public let feedbackIds: [Int]
    public init(requestId: String = CreatorStudioRequestID.make(), topicId: Int, title: String, note: String?, feedbackIds: [Int]) {
        self.requestId = requestId; self.topicId = topicId; self.title = title; self.note = note; self.feedbackIds = feedbackIds
    }
    var body: [String: Any] {
        var out: [String: Any] = ["requestId": requestId, "topicId": topicId, "title": title, "feedbackIds": feedbackIds]
        if let note, !note.isEmpty { out["note"] = note }
        return out
    }
}

public struct CreatorTicketCloseRequest: Equatable, Sendable {
    public enum Resolution: String, Sendable { case fixed = "FIXED", noChange = "NO_CHANGE" }
    public let requestId: String
    public let expectedVersion: Int
    public let resolution: Resolution
    public let reason: String?
    public init(requestId: String = CreatorStudioRequestID.make(), expectedVersion: Int, resolution: Resolution, reason: String?) {
        self.requestId = requestId; self.expectedVersion = expectedVersion; self.resolution = resolution; self.reason = reason
    }
    var body: [String: Any] {
        var out: [String: Any] = ["requestId": requestId, "expectedVersion": expectedVersion, "resolution": resolution.rawValue]
        if let reason, !reason.isEmpty { out["reason"] = reason }
        return out
    }
    /// NO_CHANGE needs a written reason of at least two characters (server rule CLOSE_REASON_REQUIRED).
    public var isComplete: Bool {
        resolution == .fixed || (reason?.trimmingCharacters(in: .whitespacesAndNewlines).count ?? 0) >= 2
    }
}

/// A write whose response was lost is `unknown`: re-ask with the same request id, never a new one.
public enum CreatorTicketWriteOutcome: Equatable, Sendable {
    case applied(CreatorMaintenanceTicket)
    case rejected(CreatorStudioFailure)
    case unknown
}

public enum CreatorTicketRequestState: Equatable, Sendable {
    case applied(CreatorMaintenanceTicket)
    case notFound
}

public enum CreatorStudioRequestID {
    /// 32 lowercase hex characters: inside the server pattern `[A-Za-z0-9._:-]{8,64}`, and an opaque id segment
    /// for the reviewed route key of `requests/{requestId}`.
    public static func make() -> String { UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "") }
}

// MARK: U08-04 wire

public struct CreatorPostGameOutcome: Decodable, Equatable, Sendable {
    public struct Scope: Decodable, Equatable, Sendable {
        public let kind: String?
        public let topicIds: [Int]
        public let cohortRule: String?
        public let omittedMetrics: [String]
        public let omittedReason: String?
    }
    public let source: String?
    public let scope: Scope
    public let report: CreatorPostGameOutcomeReport
}

public struct CreatorPostGameOutcomeReport: Decodable, Equatable, Sendable {
    public struct Cohort: Decodable, Equatable, Sendable {
        public let eligibleMembers: Int?
        public let freeMembers: Int?
        public let fullRefundExcluded: Int?
        public let cancelledOrExpiredExcluded: Int?
        public let partialRefundMembers: Int?
        public let pendingRefundMembers: Int?
        public let duplicateOrdersCollapsed: Int?
        public let multiSeatCollapsed: Int?
        public let retainedMembers: Int?
        public let freeRetainedMembers: Int?
        public let notMatureMembers: Int?
        public let lateFactCount: Int?
        /// Fraction (0...1, four decimals). Null when no member is mature.
        public let retentionRate: Double?
        public let freeRetentionRate: Double?
    }
    public struct Metric: Decodable, Equatable, Sendable {
        public let metricCode: String
        public let members: Int?
        public let memberDays: Int?
        public let facts: Int?
        public let firstOccurredAt: String?
        public let lastOccurredAt: String?
        public let sourceTables: String?
        public let identityBasis: String?
        public let serverFinal: Bool?
        public let watermarkAt: String?
    }
    public struct RepeatSignup: Decodable, Equatable, Sendable {
        public struct Segment: Decodable, Equatable, Sendable {
            public let eligibilityBasis: String?
            public let eligibleMembers: Int?
            public let matureMembers: Int?
            public let notMatureMembers: Int?
            public let retainedMembers: Int?
            public let retentionRate: Double?
            public let partialRefundMembers: Int?
            public let pendingRefundMembers: Int?
        }
        public let definitionVersion: String?
        public let windowDays: Int?
        public let available: Bool?
        public let unknownReason: String?
        public let paid: Segment?
        public let all: Segment?
    }
    public let cohortDate: String
    public let windowDays: Int
    public let mature: Bool
    public let windowStart: String?
    public let windowEnd: String?
    public let computedAt: String?
    /// Source table → watermark; a null watermark means that source has no fact yet.
    public let sourceWatermarks: [String: String?]
    public let cohort: Cohort?
    public let metrics: [String: Metric]
    public let repeatSignupV1: RepeatSignup?
    public let identityBasis: String?
    public let unavailableSources: [String: String]?
    public let basisVersion: String?
    public let historicalReplayable: Bool?
    public let snapshotNote: String?
    public let testExclusionBasis: String?
    public let metricCodes: [String]?

    private enum CodingKeys: String, CodingKey {
        case cohortDate, windowDays, mature, windowStart, windowEnd, computedAt, sourceWatermarks, cohort, metrics,
             repeatSignupV1, identityBasis, unavailableSources, basisVersion, historicalReplayable, snapshotNote,
             testExclusionBasis, metricCodes
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cohortDate = try c.decode(String.self, forKey: .cohortDate)
        windowDays = try c.decode(Int.self, forKey: .windowDays)
        mature = try c.decode(Bool.self, forKey: .mature)
        windowStart = try c.decodeIfPresent(String.self, forKey: .windowStart)
        windowEnd = try c.decodeIfPresent(String.self, forKey: .windowEnd)
        computedAt = try c.decodeIfPresent(String.self, forKey: .computedAt)
        sourceWatermarks = try c.decodeIfPresent([String: String?].self, forKey: .sourceWatermarks) ?? [:]
        cohort = try c.decodeIfPresent(Cohort.self, forKey: .cohort)
        metrics = try c.decodeIfPresent([String: Metric].self, forKey: .metrics) ?? [:]
        repeatSignupV1 = try c.decodeIfPresent(RepeatSignup.self, forKey: .repeatSignupV1)
        identityBasis = try c.decodeIfPresent(String.self, forKey: .identityBasis)
        unavailableSources = try c.decodeIfPresent([String: String].self, forKey: .unavailableSources)
        basisVersion = try c.decodeIfPresent(String.self, forKey: .basisVersion)
        historicalReplayable = try c.decodeIfPresent(Bool.self, forKey: .historicalReplayable)
        snapshotNote = try c.decodeIfPresent(String.self, forKey: .snapshotNote)
        // The server sends `CODE：explanation` (e.g. `NO_SERVER_MARKER：…`); the basis is the leading code.
        testExclusionBasis = try c.decodeIfPresent(String.self, forKey: .testExclusionBasis)
            .map { String($0.split(whereSeparator: { $0 == "：" || $0 == ":" }).first ?? Substring($0)).trimmingCharacters(in: .whitespaces) }
        metricCodes = try c.decodeIfPresent([String].self, forKey: .metricCodes)
    }
}

/// Owner hard rules for U08-04: `mature=false` reads "not mature", a null count reads "—", an omitted metric
/// reads "not available", and none of them is ever 0 or 0%.
public enum CreatorOutcomeValue: Equatable, Sendable {
    case notMature
    case dash
    case value(String)
}

public enum CreatorOutcomePresentation {
    /// Metrics a creator-scoped report cannot attribute to a topic: the server's `scope.omittedMetrics`,
    /// plus roam revisit, which the scoped report leaves out (`roamRevisit` null) without listing it.
    public static let roamRevisit = "ROAM_REVISIT"

    public static func omittedMetrics(_ outcome: CreatorPostGameOutcome) -> [String] {
        var out = outcome.scope.omittedMetrics
        if !out.contains(roamRevisit) { out.append(roamRevisit) }
        let shown = Set(shownMetrics(outcome).map(\.metricCode))
        return out.filter { !shown.contains($0) }
    }

    /// Metrics in the server's own order; codes without a metric object are dropped, never filled with 0.
    public static func shownMetrics(_ outcome: CreatorPostGameOutcome) -> [CreatorPostGameOutcomeReport.Metric] {
        let report = outcome.report
        let order = report.metricCodes ?? report.metrics.keys.sorted()
        return order.compactMap { report.metrics[$0] }
    }

    public static func rate(_ rate: Double?, mature: Bool, locale: Locale = .current) -> CreatorOutcomeValue {
        guard mature else { return .notMature }
        guard let rate, rate.isFinite else { return .dash }
        return .value(rate.formatted(.percent.precision(.fractionLength(0...1)).locale(locale)))
    }

    public static func count(_ value: Int?) -> CreatorOutcomeValue { value.map { .value(String($0)) } ?? .dash }

    /// A retained count before maturity is not "0 returned".
    public static func retained(_ value: Int?, mature: Bool) -> CreatorOutcomeValue {
        guard mature else { return .notMature }
        return count(value)
    }

    /// Watermarks sorted by source; a null watermark reads "—".
    public static func watermarks(_ report: CreatorPostGameOutcomeReport) -> [(source: String, value: CreatorOutcomeValue)] {
        report.sourceWatermarks.keys.sorted().map { key in
            let raw = report.sourceWatermarks[key] ?? nil
            return (key, raw.map { .value($0) } ?? .dash)
        }
    }

    public static func cohortDate(_ date: Date, calendar: Calendar = .shanghai) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
    }
}

public extension Calendar {
    /// The report's cohort day is a Shanghai calendar day.
    static var shanghai: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return calendar
    }
}

// MARK: Client

public struct CreatorStudioService {
    private let baseURL: URL
    private let transport: any HTTPTransport
    private let token: @MainActor @Sendable () -> String?

    public init(configuration: APIConfiguration, transport: any HTTPTransport, token: @escaping @MainActor @Sendable () -> String?) {
        self.baseURL = configuration.baseURL; self.transport = transport; self.token = token
    }

    // U08-03

    /// The creator's feedback. Send `topicID`: TEST `2e6f6651c` answers the unscoped read with 500.
    public func feedback(topicID: Int?, cursor: String? = nil, limit: Int? = nil) async throws -> CreatorStudioPage<CreatorFeedbackItem> {
        try await read(CreatorStudioRoute.feedback, query: query(topicID: topicID, status: nil, cursor: cursor, limit: limit))
    }

    public func tickets(topicID: Int? = nil, status: String? = nil, cursor: String? = nil, limit: Int? = nil) async throws -> CreatorStudioPage<CreatorMaintenanceTicket> {
        try await read(CreatorStudioRoute.tickets, query: query(topicID: topicID, status: status, cursor: cursor, limit: limit))
    }

    public func ticket(id: Int) async throws -> CreatorMaintenanceTicket {
        guard id > 0 else { throw CreatorStudioFailure.malformed }
        return try await read(CreatorStudioRoute.tickets + "/\(id)", query: [])
    }

    public func openTicket(_ request: CreatorTicketOpenRequest) async -> CreatorTicketWriteOutcome {
        await write(CreatorStudioRoute.tickets, body: request.body)
    }

    /// Recovery read for an open whose response was lost.
    public func openRequest(_ requestID: String) async throws -> CreatorTicketRequestState {
        struct Wire: Decodable { let state: String; let ticket: CreatorMaintenanceTicket? }
        let wire: Wire = try await read(CreatorStudioRoute.ticketRequests + "/" + requestID, query: [])
        if wire.state == "APPLIED", let ticket = wire.ticket { return .applied(ticket) }
        if wire.state == "NOT_FOUND" { return .notFound }
        throw CreatorStudioFailure.malformed
    }

    /// Close is replay-safe on the server: an unknown result is re-sent with the same request.
    public func closeTicket(id: Int, _ request: CreatorTicketCloseRequest) async -> CreatorTicketWriteOutcome {
        guard id > 0, request.isComplete else { return .rejected(.rejected(status: 400, code: "CLOSE_REASON_REQUIRED", message: nil)) }
        return await write(CreatorStudioRoute.tickets + "/\(id)/close", body: request.body)
    }

    // U08-04

    public func postGameOutcome(cohortDate: String, windowDays: Int? = nil, topicID: Int? = nil) async throws -> CreatorPostGameOutcome {
        var items = [URLQueryItem(name: "cohortDate", value: cohortDate)]
        if let windowDays { items.append(URLQueryItem(name: "windowDays", value: String(windowDays))) }
        if let topicID { items.append(URLQueryItem(name: "topicId", value: String(topicID))) }
        return try await read(CreatorStudioRoute.postGameOutcome, query: items)
    }

    // Transport

    private func query(topicID: Int?, status: String?, cursor: String?, limit: Int?) -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let topicID { items.append(URLQueryItem(name: "topicId", value: String(topicID))) }
        if let status, !status.isEmpty { items.append(URLQueryItem(name: "status", value: status)) }
        if let cursor, !cursor.isEmpty { items.append(URLQueryItem(name: "cursor", value: cursor)) }
        if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
        return items
    }

    private func request(_ path: String, query: [URLQueryItem], method: String) async throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else { throw CreatorStudioFailure.notConfigured }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw CreatorStudioFailure.notConfigured }
        guard let token = await token(), AuthRequestBuilder.isValidToken(token) else { throw CreatorStudioFailure.unauthorized }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        return request
    }

    private func read<T: Decodable>(_ path: String, query: [URLQueryItem]) async throws -> T {
        let request = try await request(path, query: query, method: "GET")
        let (data, status): (Data, Int)
        do { (data, status) = try await transport.send(request) }
        catch let error as APIError where error == .notConfigured || error == .invalidConfiguration { throw CreatorStudioFailure.notConfigured }
        return try CreatorStudioEnvelope.decode(T.self, data: data, status: status)
    }

    private func write(_ path: String, body: [String: Any]) async -> CreatorTicketWriteOutcome {
        guard var request = try? await request(path, query: [], method: "POST"),
              let payload = try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]) else {
            return .rejected(.unauthorized)
        }
        request.httpBody = payload
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, status): (Data, Int)
        do { (data, status) = try await transport.send(request) }
        catch let error as APIError where error == .notConfigured || error == .invalidConfiguration { return .rejected(.notConfigured) }
        catch { return .unknown }
        do { return .applied(try CreatorStudioEnvelope.decode(CreatorMaintenanceTicket.self, data: data, status: status)) }
        catch let failure as CreatorStudioFailure {
            switch failure {
            case .unavailable, .malformed: return .unknown
            default: return .rejected(failure)
            }
        } catch { return .unknown }
    }
}

/// `{code, msg, errorCode, data}`. The backend sends errors with a matching HTTP status, and some (500) as HTTP 200
/// with `code` in the body, so the effective status is the body code when present.
enum CreatorStudioEnvelope {
    private struct Head: Decodable { let code: Int?; let msg: String?; let errorCode: String? }
    private struct Body<T: Decodable>: Decodable { let data: T }

    static func decode<T: Decodable>(_ type: T.Type, data: Data, status: Int) throws -> T {
        let head = try? JSONDecoder().decode(Head.self, from: data)
        let code = (200..<300).contains(status) ? (head?.code ?? status) : status
        switch code {
        case 200:
            do { return try JSONDecoder().decode(Body<T>.self, from: data).data }
            catch { throw CreatorStudioFailure.malformed }
        case 401: throw CreatorStudioFailure.unauthorized
        case 404, 405:
            guard let errorCode = head?.errorCode, !errorCode.isEmpty else { throw CreatorStudioFailure.routeAbsent }
            throw CreatorStudioFailure.notFound(code: errorCode)
        case 500...599: throw CreatorStudioFailure.unavailable(code: head?.errorCode)
        default: throw CreatorStudioFailure.rejected(status: code, code: head?.errorCode, message: head?.msg)
        }
    }
}

/// Whether the backend serves a creator studio entry. Only a confirmed route keeps the entry visible.
public enum CreatorStudioAvailability: Equatable, Sendable {
    case available
    case hidden

    /// A route-level 404, a refused composition, or a signed-out viewer hides the entry. A business 404
    /// (e.g. CREATOR_TOPICS_NOT_FOUND), a rejection or a 5xx still proves the route exists.
    public static func from(_ error: Error) -> Self {
        switch error as? CreatorStudioFailure {
        case .routeAbsent?, .notConfigured?, .unauthorized?, nil: return .hidden
        case .notFound?, .rejected?, .unavailable?, .malformed?: return .available
        }
    }

    public static func probeMaintenance(_ service: CreatorStudioService) async -> Self {
        do { _ = try await service.tickets(limit: 1); return .available } catch { return from(error) }
    }

    public static func probeOutcome(_ service: CreatorStudioService, now: Date = Date()) async -> Self {
        do { _ = try await service.postGameOutcome(cohortDate: CreatorOutcomePresentation.cohortDate(now)); return .available }
        catch { return from(error) }
    }
}
