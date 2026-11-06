import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Credentials stay in memory. Epoch + viewerRevision fence ABA account/role/realm changes.
public struct ModSettlementReadSession: Equatable {
    let context: RuntimeDependencyContext
    let viewerRevision: UInt64
    public init(context: RuntimeDependencyContext, viewerRevision: UInt64) {
        self.context = context; self.viewerRevision = viewerRevision
    }
    public var ownerID: Int64 { Int64(context.session.accountID) }
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.viewerRevision == rhs.viewerRevision && lhs.context.market == rhs.context.market &&
        lhs.context.baseURL.absoluteString.utf8.elementsEqual(rhs.context.baseURL.absoluteString.utf8) &&
        lhs.context.role.utf8.elementsEqual(rhs.context.role.utf8) && lhs.context.session == rhs.context.session
    }
}
/// Authenticated own-member GET routes only. No administrator route or mutating method exists.
@MainActor public final class ModSettlementReader {
    public static let pageLimit = 100
    private let api: APIConfiguration?
    private let transport: any HTTPTransport
    private let current: () -> ModSettlementReadSession?
    private let onUnauthorized: (ModSettlementReadSession) -> Void
    private var observed: ModSettlementReadSession?
    private var identity = UUID()
    private var highestVersions: [String: Int64] = [:]
    private var highestIncomeRevisions: [String: Int64] = [:]
    public var isConfigured: Bool { api != nil }
    public var isAuthenticated: Bool { current() != nil }
    public var scope: UUID {
        if observed != current() { observed = current(); identity = UUID(); highestVersions = [:]; highestIncomeRevisions = [:] }
        return identity
    }
    public init(configuration: APIConfiguration?, transport: any HTTPTransport,
                current: @escaping () -> ModSettlementReadSession?, onUnauthorized: @escaping (ModSettlementReadSession) -> Void = { _ in }) {
        api = configuration; self.transport = transport; self.current = current; self.onUnauthorized = onUnauthorized; observed = current()
    }
    public func overview(expectedScope: UUID) async throws -> ModSettlementOverview {
        let session = try capture(expectedScope)
        let listData = try await read(suffix: nil, session: session, scope: expectedScope)
        let records: [ModSettlementRecord] = try decodeRequired(listData)
        guard records.count <= Self.pageLimit, Set(records.map(\.id)).count == records.count else { throw ModSettlementIssue.malformed }
        for row in records { try validate(row, session: session) }
        let qualificationData = try await read(suffix: "qualification", session: session, scope: expectedScope)
        let qualification: ModSettlementQualification? = try decodeOptional(qualificationData)
        try qualification?.validate(owner: session.ownerID)
        try check(session, scope: expectedScope)
        for row in records { try validate(row, session: session); highestVersions[row.id] = row.version }
        return ModSettlementOverview(records: records, qualification: qualification, readAt: Date())
    }
    /// Explicit next page of the same original creator ledger, never a total/revenue calculation.
    public func page(before: String, expectedScope: UUID) async throws -> [ModSettlementRecord] {
        guard ModSettlementWire.settlementID(before) else { throw ModSettlementIssue.malformed }
        let session = try capture(expectedScope)
        let data = try await read(suffix: nil, session: session, scope: expectedScope, before: before)
        let rows: [ModSettlementRecord] = try decodeRequired(data)
        guard rows.count <= Self.pageLimit, Set(rows.map(\.id)).count == rows.count,
              !rows.contains(where: { $0.id == before }) else { throw ModSettlementIssue.malformed }
        for row in rows { try validate(row, session: session) }
        try check(session, scope: expectedScope)
        for row in rows { highestVersions[row.id] = row.version }
        return rows
    }
    public func detail(id: String, expectedScope: UUID, minimumVersion: Int64 = 0) async throws -> ModSettlementRecord {
        guard ModSettlementWire.settlementID(id), minimumVersion >= 0 else { throw ModSettlementIssue.malformed }
        let session = try capture(expectedScope)
        let data = try await read(suffix: id, session: session, scope: expectedScope)
        let row: ModSettlementRecord = try decodeRequired(data)
        guard row.id == id, row.version >= minimumVersion else { throw ModSettlementIssue.malformed }
        try validate(row, session: session); try check(session, scope: expectedScope); highestVersions[id] = row.version
        return row
    }
    public func incomePage(before: String? = nil, expectedScope: UUID) async throws -> ModCreatorIncomePage {
        if let before { guard ModCreatorIncomeWire.orderKey(before) else { throw ModSettlementIssue.malformed } }
        let session = try capture(expectedScope)
        let data = try await read(suffix: nil, session: session, scope: expectedScope, income: .page(before))
        try ModCreatorIncomeWire.envelope(data, kind: "page")
        let page: ModCreatorIncomePage = try decodeRequired(data); try page.validate(owner: session.ownerID, before: before)
        for fact in page.facts { guard fact.revision >= (highestIncomeRevisions[fact.orderKey] ?? 0) else { throw ModSettlementIssue.malformed } }
        try check(session, scope: expectedScope)
        for fact in page.facts { highestIncomeRevisions[fact.orderKey] = fact.revision }
        return page
    }
    public func incomeDetail(orderKey: String, expectedScope: UUID, minimumRevision: Int64 = 0) async throws -> ModCreatorIncomeFact {
        guard ModCreatorIncomeWire.orderKey(orderKey), minimumRevision >= 0 else { throw ModSettlementIssue.malformed }
        let session = try capture(expectedScope)
        let data = try await read(suffix: nil, session: session, scope: expectedScope, income: .detail(orderKey))
        try ModCreatorIncomeWire.envelope(data, kind: "detail")
        let detail: ModCreatorIncomeDetail = try decodeRequired(data)
        try detail.validate(owner: session.ownerID, orderKey: orderKey,
                            minimumRevision: max(minimumRevision, highestIncomeRevisions[orderKey] ?? 0))
        try check(session, scope: expectedScope); highestIncomeRevisions[orderKey] = detail.current.revision
        return detail.current
    }
    public func incomeRevisions(anchor: ModCreatorIncomeFact, before: Int64? = nil, expectedScope: UUID) async throws -> ModCreatorIncomeRevisions {
        let session = try capture(expectedScope); try anchor.validate(owner: session.ownerID)
        if let before { guard before > 0, before <= anchor.revision else { throw ModSettlementIssue.malformed } }
        let data = try await read(suffix: nil, session: session, scope: expectedScope,
                                  income: .revisions(anchor.orderKey, anchor.revision, before))
        try ModCreatorIncomeWire.envelope(data, kind: "revisions")
        let page: ModCreatorIncomeRevisions = try decodeRequired(data)
        try page.validate(owner: session.ownerID, anchor: anchor, before: before); try check(session, scope: expectedScope)
        return page // Historical revisions never replace the separately read latest fact.
    }
    private func validate(_ row: ModSettlementRecord, session: ModSettlementReadSession) throws {
        try row.validate(owner: session.ownerID)
        guard row.version >= (highestVersions[row.id] ?? 0) else { throw ModSettlementIssue.malformed }
    }
    private func capture(_ captured: UUID) throws -> ModSettlementReadSession {
        guard api != nil else { throw ModSettlementIssue.notConfigured }
        guard let session = current() else { throw ModSettlementIssue.login }
        try check(session, scope: captured); return session
    }
    private func check(_ session: ModSettlementReadSession, scope captured: UUID) throws {
        try Task.checkCancellation()
        guard scope == captured, current() == session else { throw ModSettlementIssue.stale }
        guard let api, session.context.market == .china, api.baseURL.absoluteString.utf8.elementsEqual(session.context.baseURL.absoluteString.utf8),
              AuthRequestBuilder.isValidToken(session.context.session.token) else { throw ModSettlementIssue.notConfigured }
    }
    private enum IncomeRoute { case page(String?), detail(String), revisions(String, Int64, Int64?) }
    private func read(suffix: String?, session: ModSettlementReadSession, scope captured: UUID, before: String? = nil,
                      income: IncomeRoute? = nil) async throws -> Data {
        try check(session, scope: captured)
        guard let api else { throw ModSettlementIssue.notConfigured }
        if let suffix, suffix != "qualification", !ModSettlementWire.settlementID(suffix) { throw ModSettlementIssue.malformed }
        var path = "api/mod-settlement/mine" + (suffix.map { "/" + $0 } ?? "")
        var incomeQuery: [URLQueryItem] = []
        if let income {
            path = "api/mod-settlement/mine/income"
            switch income {
            case .page(let cursor):
                if let cursor { guard ModCreatorIncomeWire.orderKey(cursor) else { throw ModSettlementIssue.malformed }; incomeQuery.append(.init(name: "before", value: cursor)) }
            case .detail(let key):
                guard ModCreatorIncomeWire.orderKey(key) else { throw ModSettlementIssue.malformed }; path += "/" + key
            case .revisions(let key, let asOf, let cursor):
                guard ModCreatorIncomeWire.orderKey(key), asOf > 0 else { throw ModSettlementIssue.malformed }; path += "/" + key + "/revisions"
                incomeQuery.append(.init(name: "asOf", value: String(asOf)))
                if let cursor { guard cursor > 0, cursor <= asOf else { throw ModSettlementIssue.malformed }; incomeQuery.append(.init(name: "before", value: String(cursor))) }
            }
        }
        guard var components = URLComponents(url: api.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else { throw ModSettlementIssue.notConfigured }
        if income != nil { if !incomeQuery.isEmpty { components.queryItems = incomeQuery } }
        else if suffix == nil {
            components.queryItems = [.init(name: "limit", value: String(Self.pageLimit))]
            if let before { components.queryItems?.append(.init(name: "before", value: before)) }
        }
        guard let url = components.url else { throw ModSettlementIssue.notConfigured }
        var request = URLRequest(url: url); request.httpMethod = "GET"; request.timeoutInterval = 20
        request.httpShouldHandleCookies = false; request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(session.context.session.token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept"); request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        do {
            try check(session, scope: captured)
            let (data, status) = try await transport.send(request)
            try check(session, scope: captured)
            guard data.count <= 1_048_576 else { throw ModSettlementIssue.malformed }
            if status == 401 { throw ModSettlementIssue.login }
            if status == 404 { throw ModSettlementIssue.notFound }
            guard (200..<300).contains(status) else { throw ModSettlementIssue.unavailable }
            let envelope: Code
            do { envelope = try ModSettlementWire.decoder().decode(Code.self, from: data) } catch { throw ModSettlementIssue.malformed }
            if envelope.code == 401 { throw ModSettlementIssue.login }
            if envelope.code == 404 { throw ModSettlementIssue.notFound }
            guard envelope.code == 200 else { throw ModSettlementIssue.unavailable }
            return data
        } catch {
            try check(session, scope: captured) // Stale 401 must not expire a replacement login.
            if error as? ModSettlementIssue == .login { onUnauthorized(session) }
            throw (error as? ModSettlementIssue) ?? .unavailable
        }
    }
    private struct Code: Decodable { let code: Int }
    private struct Envelope<T: Decodable>: Decodable { let data: T? }
    private func decodeOptional<T: Decodable>(_ data: Data) throws -> T? {
        do { return try ModSettlementWire.decoder().decode(Envelope<T>.self, from: data).data }
        catch { throw ModSettlementIssue.malformed }
    }
    private func decodeRequired<T: Decodable>(_ data: Data) throws -> T {
        guard let value: T = try decodeOptional(data) else { throw ModSettlementIssue.malformed }; return value
    }
}

/// Exact normal-app own-record GET surface, shared with composition; no prefix-wide/admin/write approval.
public enum ModSettlementOwnReadRoute {
    public static func accepts(_ request: URLRequest, baseURL: URL) -> Bool {
        guard request.httpMethod == "GET", request.httpBody == nil, request.httpBodyStream == nil,
              let url = request.url, var parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == "https", parts.user == nil, parts.password == nil, parts.fragment == nil else { return false }
        let items = parts.queryItems ?? []
        guard Set(items.map(\.name)).count == items.count, items.allSatisfy({ $0.value != nil }) else { return false }
        let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value!) })
        parts.query = nil
        guard let plain = parts.url else { return false }
        let root = "api/mod-settlement/mine"
        var route: String?
        if plain == baseURL.appendingPathComponent(root) {
            guard Set(query.keys).isSubset(of: ["limit", "before"]),
                  let raw = query["limit"], let limit = Int(raw), (1...100).contains(limit), String(limit) == raw,
                  query["before"].map(ModSettlementWire.settlementID) ?? true else { return false }
            route = root
        } else if plain == baseURL.appendingPathComponent(root + "/qualification") {
            guard query.isEmpty else { return false }; route = root + "/qualification"
        } else if plain == baseURL.appendingPathComponent(root + "/income") {
            guard Set(query.keys).isSubset(of: ["before"]), query["before"].map(ModCreatorIncomeWire.orderKey) ?? true else { return false }
            route = root + "/income"
        } else {
            let prefix = baseURL.appendingPathComponent(root).absoluteString + "/"
            guard plain.absoluteString.hasPrefix(prefix) else { return false }
            let tail = String(plain.absoluteString.dropFirst(prefix.count)), components = tail.split(separator: "/", omittingEmptySubsequences: false)
            if components.count == 1, ModSettlementWire.settlementID(tail), query.isEmpty { route = root + "/" + tail }
            else if components.count == 2, components[0] == "income", ModCreatorIncomeWire.orderKey(String(components[1])), query.isEmpty {
                route = root + "/" + tail
            } else if components.count == 3, components[0] == "income", components[2] == "revisions",
                      ModCreatorIncomeWire.orderKey(String(components[1])), Set(query.keys).isSubset(of: ["asOf", "before"]),
                      let raw = query["asOf"], let asOf = Int64(raw), asOf > 0, String(asOf) == raw {
                if let cursor = query["before"] { guard let before = Int64(cursor), before > 0, before <= asOf, String(before) == cursor else { return false } }
                route = root + "/" + tail
            } else { return false }
        }
        guard let route, var canonical = URLComponents(url: baseURL.appendingPathComponent(route), resolvingAgainstBaseURL: false) else { return false }
        if !items.isEmpty { canonical.queryItems = items }
        return canonical.url?.absoluteString.utf8.elementsEqual(url.absoluteString.utf8) == true
    }
}
