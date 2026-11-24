import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Only public read routes. No GPS acquisition, financial writes, or play-state reads.
public struct HomeFeedService {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    private let discovery: DiscoveryService
    private let topics: TopicService
    private let reads = InFlightReadCoalescer<InFlightHTTPBody>()
    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration; self.transport = transport
        discovery = DiscoveryService(configuration: configuration, transport: transport)
        topics = TopicService(configuration: configuration, transport: transport)
    }
    public func banners(token: String?) async throws -> [DiscoveryBanner] { try await discovery.banners(token: token) }
    public func categories(token: String?) async throws -> [DiscoveryCategory] { try await discovery.categories(token: token) }
    public func page(query: HomeFeedQuery, number: Int, token: String?) async throws -> HomeFeedPage {
        guard number > 0, (1...100).contains(query.pageSize), query.categoryID.map({ $0 > 0 }) ?? true else { throw APIError.invalidRequest }
        let keyword = query.keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = query.categoryID.map(String.init)
        let items: [HomeFeedItem]
        switch query.kind {
        case .topics:
            let page = try await topics.list(query: TopicQuery(keyword: keyword.isEmpty ? nil : keyword, categoryID: category, pageSize: query.pageSize, sortType: "1"), pageNumber: number, token: token)
            items = page.rows.map(HomeFeedItem.topic)
        case .activities:
            // MP index.js:1364-1377: 活动 stream lists open activities (`status:1`) in `sort_type:1` order.
            var fields = ["is_my": "0", "status": "1", "sort_type": "1", "pageNum": String(number), "pageSize": String(query.pageSize)]
            if !keyword.isEmpty { fields["keyword"] = keyword }
            if let category { fields["category_id"] = category }
            items = try await activities(fields: fields, token: token).map(HomeFeedItem.activity)
        }
        return HomeFeedPage(items: items, number: number, size: query.pageSize)
    }
    public func section(_ section: HomeFeedSection, token: String?) async throws -> [HomeFeedItem] {
        switch section {
        case .recommended:
            return try await topics.list(query: TopicQuery(recommend: true, pageSize: 5), token: token).rows.map(HomeFeedItem.topic)
        case .nearby:
            // Source's no-GPS fallback is time ordering; do not claim distance/proximity.
            return try await activities(fields: ["is_my": "0", "sort_type": "2", "pageNum": "1", "pageSize": "4"], token: token).map(HomeFeedItem.activity)
        case .upcoming:
            // MP index.js:773-779: 即将上线 = `is_my:2, status:2, sort_type:2`, four rows.
            return try await activities(fields: ["is_my": "2", "status": "2", "sort_type": "2", "pageNum": "1", "pageSize": "4"], token: token).map(HomeFeedItem.activity)
        }
    }
    private func activities(fields: [String: String], token: String?) async throws -> [ActivitySummary] {
        let key = InFlightReadKey.fields(method: "POST", path: "api/activity/list", fields: fields, token: token)
        let response = try await reads.join(key) {
            let request = try AuthRequestBuilder.makeFormRequest(url: self.configuration.baseURL.appendingPathComponent("api/activity/list"), fields: fields, token: token)
            let (data, status) = try await self.transport.send(request)
            return InFlightHTTPBody(data: data, status: status)
        }
        let (data, status) = (response.data, response.status)
        if status == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(status) else { throw APIError.httpStatus(status) }
        do { return try await PlayerFeedJSON.perform { try JSONDecoder().decode(ActivityListResponse.self, from: data) }.rows }
        catch let error as APIError { throw error }
        catch { throw APIError.malformedResponse }
    }
}
