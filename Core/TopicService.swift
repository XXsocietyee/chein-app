import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct TopicQuery: Equatable, Hashable {
    public var keyword: String?
    public var categoryID: String?
    public var recommend: Bool
    public var pageSize: Int
    /// MP `sort_type` (首页 主题 stream sends 1). Nil is omitted.
    public var sortType: String?
    public init(keyword: String? = nil, categoryID: String? = nil, recommend: Bool = false, pageSize: Int = 10, sortType: String? = nil) {
        self.keyword = keyword; self.categoryID = categoryID
        self.recommend = recommend; self.pageSize = pageSize; self.sortType = sortType
    }
}
public struct TopicPage: Equatable {
    public let rows: [TopicSummary]
    public let pageNumber: Int
    public let pageSize: Int
    /// Source list API does not expose total. A full page permits probing the next page.
    public var hasMore: Bool { rows.count >= pageSize }
    public init(rows: [TopicSummary], pageNumber: Int, pageSize: Int) {
        self.rows = rows; self.pageNumber = pageNumber; self.pageSize = pageSize
    }
}
public enum TopicReadFailure: Error, Equatable { case unavailable }

/// Audited read routes only (list, detail, theme records). No generic endpoint escape hatch.
public struct TopicService {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    private let reads = InFlightReadCoalescer<InFlightHTTPBody>()
    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration; self.transport = transport
    }
    public func list(query: TopicQuery = TopicQuery(), pageNumber: Int = 1, token: String? = nil) async throws -> TopicPage {
        try await listDocument(query: query, pageNumber: pageNumber, token: token).page
    }
    /// Same `POST api/topic/list` as `list`. `TopicPage` has no payload; favorites resolve needs the body.
    public func listDocument(query: TopicQuery = TopicQuery(), pageNumber: Int = 1, token: String? = nil) async throws -> TopicListDocument {
        guard pageNumber > 0, query.pageSize > 0, query.pageSize <= 100 else { throw APIError.invalidRequest }
        var fields = ["is_my": "0", "pageNum": String(pageNumber), "pageSize": String(query.pageSize)]
        // Nil is omitted; an explicitly supplied empty string is retained, matching Flutter.
        if let keyword = query.keyword { fields["keyword"] = keyword }
        if let categoryID = query.categoryID { fields["category_id"] = categoryID }
        if query.recommend { fields["is_recommend"] = "1" }
        if let sortType = query.sortType { fields["sort_type"] = sortType }
        let data = try await post("api/topic/list", fields: fields, token: token)
        let envelope = try await PlayerFeedJSON.perform { () -> TopicRowsEnvelope in
            do { return try JSONDecoder().decode(TopicRowsEnvelope.self, from: data) }
            catch { throw APIError.malformedResponse }
        }
        return TopicListDocument(page: TopicPage(rows: envelope.rows, pageNumber: pageNumber, pageSize: query.pageSize), body: data)
    }
    public func detail(id: Int, token: String? = nil) async throws -> TopicDetail {
        try await detailDocument(id: id, token: token).detail
    }
    /// Same `POST api/topic/info-to-user` as `detail`. The decoded topic drops road geometry;
    /// the body is kept so a caller can verify it without a second read.
    public func detailDocument(id: Int, token: String? = nil) async throws -> TopicDetailDocument {
        guard id > 0 else { throw APIError.invalidRequest }
        let data = try await post("api/topic/info-to-user", fields: ["id": String(id)], token: token)
        let result = try decode(TopicDetailEnvelope.self, data).data
        guard let result, result.id == id, !result.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TopicReadFailure.unavailable
        }
        return TopicDetailDocument(detail: result, body: data)
    }
    public static let themeHistoryLimit = 20
    public func themeHistory(topicID: Int, beforeSessionID: Int? = nil, token: String) async throws -> TopicThemeHistoryPage {
        guard topicID > 0, beforeSessionID.map({ $0 > 0 }) ?? true else { throw APIError.invalidRequest }
        var query = [URLQueryItem(name: "topicId", value: String(topicID)), URLQueryItem(name: "limit", value: String(Self.themeHistoryLimit))]
        if let beforeSessionID { query.append(.init(name: "beforeSessionId", value: String(beforeSessionID))) }
        struct Envelope: Decodable { let data: [TopicThemeRecord]? }
        let rows = try decode(Envelope.self, try await get("api/play/theme/history", query: query, token: token)).data ?? []
        guard Set(rows.map(\.sessionID)).count == rows.count, rows.allSatisfy({ $0.topicID == nil || $0.topicID == topicID }) else { throw APIError.malformedResponse }
        return TopicThemeHistoryPage(rows: rows, hasMore: rows.count >= Self.themeHistoryLimit)
    }
    public func themeCard(sessionID: Int, token: String) async throws -> TopicThemeCard {
        guard sessionID > 0 else { throw APIError.invalidRequest }
        struct Envelope: Decodable { let data: TopicThemeCard? }
        guard let card = try decode(Envelope.self, try await get("api/play/theme/card", query: [.init(name: "sessionId", value: String(sessionID))], token: token)).data else { throw TopicReadFailure.unavailable }
        return card
    }
    private func get(_ path: String, query: [URLQueryItem], token: String) async throws -> Data {
        guard AuthRequestBuilder.isValidToken(token), var parts = URLComponents(url: configuration.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else { throw APIError.invalidRequest }
        parts.queryItems = query
        guard let url = parts.url else { throw APIError.invalidRequest }
        let key = InFlightReadKey.query(path: path, items: query, token: token)
        let response = try await reads.join(key) {
            var request = URLRequest(url: url); request.httpMethod = "GET"; request.httpShouldHandleCookies = false
            request.cachePolicy = .reloadIgnoringLocalCacheData; request.timeoutInterval = 20
            request.setValue("application/json", forHTTPHeaderField: "Accept"); request.setValue(token, forHTTPHeaderField: "Authorization")
            let (data, status) = try await self.transport.send(request)
            return InFlightHTTPBody(data: data, status: status)
        }
        return try check((response.data, response.status))
    }
    private func check(_ response: (Data, Int)) throws -> Data {
        let (data, status) = response
        if status == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(status) else { throw APIError.httpStatus(status) }
        let envelope = try decode(TopicStatusEnvelope.self, data)
        if envelope.code == 401 { throw APIError.unauthorized }
        guard envelope.code == 200 else { throw APIError.businessCode(envelope.code) }
        return data
    }
    private func post(_ path: String, fields: [String: String], token: String?) async throws -> Data {
        let key = InFlightReadKey.fields(method: "POST", path: path, fields: fields, token: token)
        let response = try await reads.join(key) {
            let request = try AuthRequestBuilder.makeFormRequest(url: self.configuration.baseURL.appendingPathComponent(path), fields: fields, token: token)
            let (data, status) = try await self.transport.send(request)
            return InFlightHTTPBody(data: data, status: status)
        }
        let (data, status) = (response.data, response.status)
        if status == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(status) else { throw APIError.httpStatus(status) }
        let envelope = try decode(TopicStatusEnvelope.self, data)
        if envelope.code == 401 { throw APIError.unauthorized }
        guard envelope.code == 200 else { throw APIError.businessCode(envelope.code) }
        return data
    }
    private func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        do { return try JSONDecoder().decode(type, from: data) }
        catch { throw APIError.malformedResponse }
    }
}
public struct TopicDetailDocument: Equatable {
    public let detail: TopicDetail
    public let body: Data
    public init(detail: TopicDetail, body: Data) {
        self.detail = detail
        self.body = body
    }
}
private struct TopicStatusEnvelope: Decodable { let code: Int }
private struct TopicDetailEnvelope: Decodable { let data: TopicDetail? }
private struct TopicRowsEnvelope: Decodable {
    let rows: [TopicSummary]
    enum CodingKeys: String, CodingKey { case data, rows }
    struct Page: Decodable { let rows: [TopicSummary]? }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Source precedence is data.rows, then root rows. A bare data array is not a topic page.
        let page = try c.decodeIfPresent(Page.self, forKey: .data)
        rows = try page?.rows ?? c.decodeIfPresent([TopicSummary].self, forKey: .rows) ?? []
    }
}
