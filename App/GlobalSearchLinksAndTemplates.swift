import Foundation
import SwiftUI
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// Parity r1, player-content. Two additions to the one global search that live beside the reviewed (byte-pinned)
// search contracts instead of inside them:
//  - PC-A-4-1: the 主题模板 / 玩法模板 lanes (MP utils/discover-search.js:161-167,200-201).
//  - PC-A-3-2: MP search links (`search2?keyword=`, `search2/result?...`, `searchmap?params=`) run their query at once.

/// The two template lanes. Kept apart from `GlobalSearchKind` so the four content lanes' counts, gates and the
/// all-failed rule stay exactly as reviewed.
enum GlobalTemplateKind: String, CaseIterable, Hashable { case topicTemplate, playTemplate }

struct GlobalTemplateSearchRow: Identifiable, Equatable {
    let kind: GlobalTemplateKind
    let sourceID: Int
    let title: String
    let detail: String?
    let imageURL: String?
    /// MP shelf `previewOnly`: listed, not opened (暂未开放).
    let previewOnly: Bool
    var id: String { "\(kind.rawValue)-\(sourceID)" }
}

struct GlobalTemplateSearchResults: Equatable {
    let rows: [GlobalTemplateSearchRow]
    let failedKinds: [GlobalTemplateKind]

    /// MP `matchesTemplateKeyword`: topic templates have no keyword contract, so they are matched on the client by
    /// name or subtitle (case-insensitive). Play templates are already filtered by the server `keyword`. 12 per lane,
    /// the MP result page size.
    static func make(keyword: String, categoryID: Int?, topics: [DiscoveryTopicTemplate]?, plays: [DiscoveryPlayTemplate]?) -> Self {
        let needle = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let topicRows = (topics ?? []).filter { row in
            !needle.isEmpty && [row.name, row.subtitle].contains { $0.lowercased().contains(needle) } && row.matchesCategory(categoryID)
        }.prefix(12).map {
            GlobalTemplateSearchRow(kind: .topicTemplate, sourceID: $0.id, title: $0.name,
                                    detail: $0.subtitle.isEmpty ? nil : $0.subtitle, imageURL: $0.imgUrl, previewOnly: $0.previewOnly)
        }
        let playRows = (plays ?? []).prefix(12).map {
            GlobalTemplateSearchRow(kind: .playTemplate, sourceID: $0.id, title: $0.title, detail: $0.description,
                                    imageURL: $0.imgUrl, previewOnly: false)
        }
        var failed: [GlobalTemplateKind] = []
        if topics == nil { failed.append(.topicTemplate) }
        if plays == nil { failed.append(.playTemplate) }
        return GlobalTemplateSearchResults(rows: Array(topicRows) + Array(playRows), failedKinds: failed)
    }
}

/// Injected into `GlobalSearchView`. Nil (fixtures, previews) = no template lanes.
struct GlobalTemplateSearchLanes {
    let search: @MainActor (GlobalSearchQuery) async -> GlobalTemplateSearchResults?
    let destination: @MainActor (GlobalTemplateSearchRow) -> AnyView

    /// Same public template reads the template shelf already uses (`DiscoveryReading`).
    @MainActor static func session(_ session: AppSession) -> GlobalTemplateSearchLanes {
        GlobalTemplateSearchLanes(
            search: { [weak session] query in
                guard let session, session.isConfigured else { return nil }
                let keyword = query.keyword.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !keyword.isEmpty else { return nil }
                let topicRows = try? await session.discoveryTopicTemplates()
                let playRows = try? await session.discoveryPlayTemplates(keyword: keyword, packType: nil)
                guard !Task.isCancelled else { return nil }
                return .make(keyword: keyword, categoryID: query.categoryID, topics: topicRows, plays: playRows)
            },
            destination: { [weak session] row in
                guard let session else { return AnyView(EmptyView()) }
                switch row.kind {
                case .topicTemplate:
                    // R7-PC-A7-1: like the shelf, a 主题模板 result opens the topic-preview deck; 查看详情 pushes the detail.
                    let id = row.sourceID
                    return AnyView(DiscoveryTopicTemplateDeckHost(coordinator: session.publicTopicTemplateCoordinator(id: id), readonly: false,
                                                                  makeDetail: { session.publicTopicTemplateCoordinator(id: id) }))
                case .playTemplate:
                    return AnyView(DiscoveryTemplateDetailView(id: row.sourceID, reader: session, authoringFactory: { session.templateAuthoringEditor(adopting: $0) },
                                                       authoringRevision: session.sessionRevision, authoringCompletion: session.templateAuthoringCompletionContext)
                        .id(session.templateAuthoringViewIdentity))
                }
            })
    }
}

private struct GlobalTemplateSearchKey: EnvironmentKey { static let defaultValue: GlobalTemplateSearchLanes? = nil }
extension EnvironmentValues {
    var globalTemplateSearch: GlobalTemplateSearchLanes? {
        get { self[GlobalTemplateSearchKey.self] }
        set { self[GlobalTemplateSearchKey.self] = newValue }
    }
}

/// Deep-link host for the MP search pages. In-app search keeps `SessionGlobalSearchView`; this host adds the link's
/// query and, for `searchmap`, opens the map explorer. Destinations are the same session screens.
@MainActor struct SessionLinkedSearchView: View {
    @EnvironmentObject private var session: AppSession
    var initialQuery: GlobalSearchQuery?
    var startsOnMap = false
    var onSignIn: (() -> Void)? = nil
    var body: some View {
        Group {
            if startsOnMap {
                SearchMapExplorerView(reader: session.searchMapReader, mode: .city, initialFilter: initialQuery ?? .init(),
                                      onSignIn: onSignIn, destination: destination)
            } else {
                GlobalSearchView(reader: session.searchMapReader, historyNamespace: session.searchMapHistoryNamespace,
                                 publicMerchant: session.publicMerchantHomeContext, onSignIn: onSignIn,
                                 recommendedKeywords: GlobalSearchRecommendedKeywords.keywords(for: session.operationalMarket),
                                 initialQuery: initialQuery, destination: destination)
            }
        }
        // PC-A-5-6 / X2: pushed search and map pages use the inline title; the map explorer it pushes follows (automatic).
        // `SearchMapExplorerView` / `GlobalSearchView` are byte-pinned, so the mode is set on this host.
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.walkingNavigationFactory, session.walkingNavigationFactory)
        .environment(\.globalTemplateSearch, .session(session))
        .id(session.searchMapReader.scope)
    }
    @ViewBuilder private func destination(_ value: SearchMapDestination) -> some View {
        switch value {
        case .activity(let id): ActivityDetailView(id: id, reader: session, playReaderForActivity: { session.playReader(for: .activity($0)) }, registrationEnabled: true)
        case .topic(let id): SessionTopicDetailView(id: id, session: session)
        case .club(let id): ClubDetailView(id: id, reader: session, onSignIn: onSignIn, actionCoordinator: session.clubActionCoordinator, management: session.clubManagementContext, community: session.clubCommunityContext, publicRoster: session.clubPublicRosterReader)
        case .merchant(let id): SearchMapMerchantDetailView(id: id, reader: session.searchMapReader)
        case .cityNode(let id): SearchMapCityDetailView(id: id, reader: session.searchMapReader, destination: merchantOnly)
        }
    }
    /// City-node related links are merchant ids only (same boundary as `SessionGlobalSearchView`).
    @ViewBuilder private func merchantOnly(_ related: SearchMapDestination) -> some View {
        if case .merchant(let merchantID) = related {
            SearchMapMerchantDetailView(id: merchantID, reader: session.searchMapReader)
        }
    }
}

/// Parses the MP search link query into the one search query (PC-A-3-2). Values outside the filter rules are dropped,
/// never sent: a bad date or price falls back to the keyword and category alone.
enum MPSearchLinkQuery {
    static func query(_ query: [String: String]) -> GlobalSearchQuery? {
        let category = query["categoryId"].flatMap(Int.init).flatMap { $0 > 0 ? $0 : nil }
        let full = GlobalSearchQuery(keyword: query["keyword"] ?? "", categoryID: category,
                                     startDate: query["startDate"], endDate: query["endDate"],
                                     minimumPrice: query["minPrice"].flatMap(Double.init), maximumPrice: query["maxPrice"].flatMap(Double.init))
        let value = (try? full.validate()) != nil ? full : GlobalSearchQuery(keyword: query["keyword"] ?? "", categoryID: category)
        return value.canSearch ? value : nil
    }
    /// `searchmap?params=<JSON>` (MP search2/index.js:227-234): keyword, categoryId, startDate, endDate, minPrice, maxPrice.
    static func mapQuery(_ params: String?) -> GlobalSearchQuery? {
        guard let params, let data = params.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        var flat: [String: String] = [:]
        for key in ["keyword", "categoryId", "startDate", "endDate", "minPrice", "maxPrice"] {
            if let text = object[key] as? String { flat[key] = text }
            else if let number = object[key] as? NSNumber { flat[key] = number.stringValue }
        }
        return query(flat)
    }
}

/// Puts a `PlayerContentMPContract` request back on the session base URL.
/// `PlayerContentMPContract.make` replaces the URL path, which drops `/native` and `/prod-api`.
enum PlayerContentMPAppWire {
    static func rehome(_ drafted: URLRequest, onto base: URL, token: String?, stripContentType: Bool) throws -> URLRequest {
        guard let url = drafted.url, let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidRequest
        }
        let relative = parts.path.hasPrefix("/") ? String(parts.path.dropFirst()) : parts.path
        guard !relative.isEmpty else { throw APIError.invalidRequest }
        var finalURL = base.appendingPathComponent(relative)
        if let query = parts.percentEncodedQuery, !query.isEmpty {
            guard var dest = URLComponents(url: finalURL, resolvingAgainstBaseURL: false) else { throw APIError.invalidRequest }
            dest.percentEncodedQuery = query
            guard let rebuilt = dest.url else { throw APIError.invalidRequest }
            finalURL = rebuilt
        }
        var request = URLRequest(url: finalURL)
        request.httpMethod = drafted.httpMethod ?? "GET"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if stripContentType {
            request.httpBody = nil
        } else {
            if let type = drafted.value(forHTTPHeaderField: "Content-Type") {
                request.setValue(type, forHTTPHeaderField: "Content-Type")
            }
            request.httpBody = drafted.httpBody
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            guard AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        return request
    }
}

/// Global search lanes and the type-1 category directory.
/// City nodes, merchant categories, and nearby reads stay on the inner reader.
@MainActor final class PlayerContentSearchMapReader: SearchMapReading {
    private let inner: SearchMapSessionReader
    private let baseURL: () -> URL?
    private let transport: any HTTPTransport
    private let token: () -> String?
    private let stamp: () -> UInt64
    private let onUnauthorized: (String, UInt64) -> Void
    /// Same page size as `SearchMapService.search`. Map activity pages stay at 10 on the inner reader.
    private let globalPageSize = 12

    init(inner: SearchMapSessionReader, baseURL: @escaping () -> URL?, transport: any HTTPTransport,
         token: @escaping () -> String?, stamp: @escaping () -> UInt64,
         onUnauthorized: @escaping (String, UInt64) -> Void) {
        self.inner = inner
        self.baseURL = baseURL
        self.transport = transport
        self.token = token
        self.stamp = stamp
        self.onUnauthorized = onUnauthorized
    }

    var isConfigured: Bool { inner.isConfigured }
    var isAuthenticated: Bool { inner.isAuthenticated }
    var isOfflineExample: Bool { inner.isOfflineExample }
    var scope: UUID { inner.scope }
    var manualAreaRevision: UInt64 { inner.manualAreaRevision }
    var publicLayerCoordinator: MapPublicLayerCoordinator? { inner.publicLayerCoordinator }
    var topicReader: (any TopicReading)? { inner.topicReader }
    func selectManualArea(_ area: RoamSearchArea?) { inner.selectManualArea(area) }
    func merchantCategories() async throws -> [DiscoveryCategory] { try await inner.merchantCategories() }
    func merchantDiscovery(tag: MerchantDiscoveryTag) async throws -> [MerchantDiscoveryRow] { try await inner.merchantDiscovery(tag: tag) }
    func cityNodes(_ query: CityNodeSearchQuery) async throws -> [SearchMapCityNode] { try await inner.cityNodes(query) }
    func citySearch(_ query: CityNodeSearchQuery) async throws -> CityNodeSearchResults { try await inner.citySearch(query) }
    func cityActivityPage(_ query: CityNodeSearchQuery, page: Int) async throws -> SearchMapActivityPage { try await inner.cityActivityPage(query, page: page) }
    func nearby(area: RoamSearchArea) async throws -> SearchMapNearbyResults { try await inner.nearby(area: area) }
    func cityNode(id: Int) async throws -> SearchMapCityNode { try await inner.cityNode(id: id) }
    func merchant(id: Int) async throws -> RoamMerchantDetail { try await inner.merchant(id: id) }
    func publicLayers(area: RoamSearchArea, body: Data) async throws -> Data { try await inner.publicLayers(area: area, body: body) }

    func categories() async throws -> [DiscoveryCategory] {
        guard isConfigured, let base = baseURL() else { throw APIError.notConfigured }
        let captured = scope
        let credential = token()
        let capturedStamp = stamp()
        try Task.checkCancellation()
        do {
            let drafted = try PlayerContentMPContract.categoryList(baseURL: base, type: 1, parentID: 0)
            let data = try await post(drafted, token: credential)
            try Task.checkCancellation()
            guard scope == captured else { throw CancellationError() }
            try requireBusinessOK(data)
            return try JSONDecoder().decode(DataBox<[DiscoveryCategory]>.self, from: data).data
        } catch {
            guard !Task.isCancelled, scope == captured else { throw CancellationError() }
            if let credential, error as? APIError == .unauthorized { onUnauthorized(credential, capturedStamp) }
            throw error
        }
    }

    func search(_ query: GlobalSearchQuery) async throws -> GlobalSearchResults {
        guard isConfigured else { throw APIError.notConfigured }
        try query.validate()
        let credential = token()
        if let credential, !AuthRequestBuilder.isValidToken(credential) { throw APIError.invalidRequest }
        let query = GlobalSearchQuery(keyword: query.keyword, categoryID: query.categoryID, startDate: query.startDate,
                                       endDate: query.endDate, minimumPrice: query.minimumPrice, maximumPrice: query.maximumPrice)
        guard query.canSearch else { return GlobalSearchResults(rows: []) }
        let captured = scope
        let capturedStamp = stamp()
        try Task.checkCancellation()
        do {
            let topics = try await lane { try await self.topicRows(query, token: credential) }
            let activities = try await lane { try await self.activityRows(query, token: credential) }
            let clubs = try await lane { try await self.clubRows(query, token: credential) }
            let merchants = try await lane { try await self.merchantRows(query, token: credential) }
            try Task.checkCancellation()
            guard scope == captured else { throw CancellationError() }
            let failures: [(GlobalSearchKind, SearchMapFailure?)] = [
                (.topic, topics.failure), (.activity, activities.failure), (.club, clubs.failure), (.merchant, merchants.failure)
            ]
            let topicRows = topics.rows.filter { query.matches(kind: .topic, date: $0.startDate, price: nil) }.map {
                GlobalSearchRow(kind: .topic, sourceID: $0.id, title: $0.name, detail: $0.introduction, imageURL: $0.imageURL)
            }
            let activityRows = activities.rows.filter {
                query.matches(kind: .activity, date: $0.startDate, price: $0.minimumAmount.map { NSDecimalNumber(decimal: $0).doubleValue })
            }.map {
                GlobalSearchRow(kind: .activity, sourceID: $0.id, title: $0.name, detail: $0.addressName ?? $0.address, imageURL: $0.imageURL)
            }
            let clubRows = clubs.rows.map {
                GlobalSearchRow(kind: .club, sourceID: $0.id, title: $0.name, detail: $0.description, imageURL: $0.cover ?? $0.logo)
            }
            let merchantRows = merchants.rows.map {
                GlobalSearchRow(kind: .merchant, sourceID: $0.id, title: $0.name, detail: $0.detail, imageURL: $0.imageURL, tags: $0.tags)
            }
            let rows = topicRows + activityRows + clubRows + merchantRows
            var seen = Set<String>()
            let results = GlobalSearchResults(rows: rows.filter { seen.insert($0.id).inserted },
                failedKinds: failures.compactMap { $0.1 != nil && $0.1 != .unauthorized ? $0.0 : nil },
                gatedKinds: failures.compactMap { $0.1 == .unauthorized ? $0.0 : nil })
            if credential != nil, !results.gatedKinds.isEmpty { throw APIError.unauthorized }
            return results
        } catch {
            guard !Task.isCancelled, scope == captured else { throw CancellationError() }
            if let credential, error as? APIError == .unauthorized { onUnauthorized(credential, capturedStamp) }
            throw error
        }
    }

    private func topicRows(_ query: GlobalSearchQuery, token: String?) async throws -> [TopicSummary] {
        guard let base = baseURL() else { throw APIError.notConfigured }
        let drafted = try PlayerContentMPContract.searchTopicList(
            baseURL: base, keyword: query.keyword, pageNum: 1, pageSize: globalPageSize, categoryID: query.categoryID)
        let data = try await post(drafted, token: token)
        try requireBusinessOK(data)
        return try JSONDecoder().decode(PagedRows<TopicSummary>.self, from: data).rows
    }

    private func activityRows(_ query: GlobalSearchQuery, token: String?) async throws -> [ActivitySummary] {
        guard let base = baseURL() else { throw APIError.notConfigured }
        let drafted = try PlayerContentMPContract.searchActivityList(
            baseURL: base, keyword: query.keyword, pageNum: 1, pageSize: globalPageSize, categoryID: query.categoryID)
        let data = try await post(drafted, token: token)
        return try JSONDecoder().decode(ActivityListResponse.self, from: data).rows
    }

    private func clubRows(_ query: GlobalSearchQuery, token: String?) async throws -> [ClubRecord] {
        guard token != nil else { throw APIError.unauthorized }
        guard let base = baseURL() else { throw APIError.notConfigured }
        let drafted = try PlayerContentMPContract.searchClubList(baseURL: base, name: query.keyword, categoryID: query.categoryID)
        let data = try await post(drafted, token: token)
        try requireBusinessOK(data)
        return try JSONDecoder().decode(DataBox<[ClubRecord]>.self, from: data).data
    }

    private func merchantRows(_ query: GlobalSearchQuery, token: String?) async throws -> [SearchMapMerchant] {
        guard let base = baseURL() else { throw APIError.notConfigured }
        let drafted = try PlayerContentMPContract.searchMerchantList(baseURL: base, name: query.keyword, categoryID: query.categoryID)
        let data = try await post(drafted, token: token)
        try requireBusinessOK(data)
        return try JSONDecoder().decode(DataBox<[SearchMapMerchant]>.self, from: data).data
    }

    private func post(_ drafted: URLRequest, token: String?) async throws -> Data {
        guard let base = baseURL() else { throw APIError.notConfigured }
        let request = try PlayerContentMPAppWire.rehome(drafted, onto: base, token: token, stripContentType: false)
        let (data, status) = try await transport.send(request)
        if status == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(status) else { throw APIError.httpStatus(status) }
        return data
    }

    private func requireBusinessOK(_ data: Data) throws {
        struct Status: Decodable { let code: Int }
        let code = try JSONDecoder().decode(Status.self, from: data).code
        if code == 401 { throw APIError.unauthorized }
        if code == 403 { throw APIError.businessCode(403) }
        guard code == 200 else { throw APIError.businessCode(code) }
    }

    private func lane<T>(_ operation: () async throws -> [T]) async throws -> (rows: [T], failure: SearchMapFailure?) {
        do { return (try await operation(), nil) }
        catch is CancellationError { throw CancellationError() }
        catch {
            if let failure = error as? APIError {
                switch failure {
                case .unauthorized, .httpStatus(401), .businessCode(401): return ([], .unauthorized)
                case .httpStatus(403), .businessCode(403): throw failure
                default: break
                }
            }
            return ([], .unavailable)
        }
    }

    private struct DataBox<T: Decodable>: Decodable { let data: T }
    private struct PagedRows<T: Decodable>: Decodable {
        let rows: [T]
        enum CodingKeys: String, CodingKey { case data, rows }
        private struct Page: Decodable { let rows: [T] }
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if container.contains(.data), try !container.decodeNil(forKey: .data) {
                rows = try container.decode(Page.self, forKey: .data).rows
            } else {
                rows = try container.decode([T].self, forKey: .rows)
            }
        }
    }
}

/// Official list, mine, and can-publish. A city filter and every other read stay on the inner reader.
@MainActor final class PlayerContentOfficialReader: OfficialEventReading {
    private let inner: OfficialSessionReader
    private let baseURL: () -> URL?
    private let transport: any HTTPTransport
    private let token: () -> String?
    private let onUnauthorized: (String) -> Void

    init(inner: OfficialSessionReader, baseURL: @escaping () -> URL?, transport: any HTTPTransport,
         token: @escaping () -> String?, onUnauthorized: @escaping (String) -> Void) {
        self.inner = inner
        self.baseURL = baseURL
        self.transport = transport
        self.token = token
        self.onUnauthorized = onUnauthorized
    }

    var invalidationSignal: OfficialReadInvalidationSignal? { inner.invalidationSignal }
    var isConfigured: Bool { inner.isConfigured }
    var isAuthenticated: Bool { inner.isAuthenticated }
    var isOfflineExample: Bool { inner.isOfflineExample }
    var scope: UUID { inner.scope }
    func detail(id: Int) async throws -> OfficialEvent { try await inner.detail(id: id) }
    /// ROAM-r11-2: forwards the guest-readable roam list (MP scene-roam-task-list/index.js:62-66).
    func activeForRoam() async throws -> [OfficialEvent] { try await inner.activeForRoam() }
    func partyInbox() async throws -> [OfficialPartyInvite] { try await inner.partyInbox() }
    func myPublished() async throws -> OfficialPublished { try await inner.myPublished() }
    func broadcastStats(id: Int) async throws -> OfficialBroadcastStats { try await inner.broadcastStats(id: id) }
    /// R10-PC-C6-2: MP official-mine/index.js:181-197 `recoverBroadcast` — `POST /api/official/broadcast/{id}/recover`,
    /// no body. A non-200 carries the server `msg` so the card can say it.
    func recoverBroadcast(id: String) async throws {
        guard isAuthenticated else { throw APIError.unauthorized }
        guard isConfigured, let base = baseURL() else { throw APIError.notConfigured }
        guard let credential = token(), AuthRequestBuilder.isValidToken(credential) else { throw APIError.unauthorized }
        let drafted = try PlayerContentMPContract.broadcastRecover(baseURL: base, id: id)
        try await fenced {
            let (data, status) = try await self.load(drafted)
            struct Status: Decodable { let code: Int?; let msg: String? }
            let envelope = try? JSONDecoder().decode(Status.self, from: data)
            if status == 401 || envelope?.code == 401 { throw APIError.unauthorized }
            let note = envelope?.msg?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard (200..<300).contains(status), envelope?.code == 200 else {
                if !note.isEmpty { throw OfficialReadFailure.explained(envelope?.code ?? status, note) }
                throw OfficialReadFailure.rejected(envelope?.code ?? status)
            }
        }
    }

    func events(city: String?) async throws -> [OfficialEvent] {
        if city != nil { return try await inner.events(city: city) }
        guard isConfigured, let base = baseURL() else { throw APIError.notConfigured }
        let drafted = try PlayerContentMPContract.officialEvents(baseURL: base)
        return try await fenced {
            let (data, status) = try await self.load(drafted)
            return try self.decodeEvents(data, status: status)
        }
    }

    func myEvents() async throws -> [OfficialEvent] {
        guard isAuthenticated else { throw APIError.unauthorized }
        guard isConfigured, let base = baseURL() else { throw APIError.notConfigured }
        guard let credential = token() else { throw APIError.unauthorized }
        guard AuthRequestBuilder.isValidToken(credential) else { throw APIError.invalidRequest }
        let drafted = try PlayerContentMPContract.officialMyEvents(baseURL: base)
        return try await fenced {
            let (data, status) = try await self.load(drafted)
            return try self.decodeEvents(data, status: status)
        }
    }

    func canPublish() async throws -> Bool {
        guard isAuthenticated else { return false }
        guard isConfigured, let base = baseURL() else { throw APIError.notConfigured }
        guard let credential = token() else { throw APIError.unauthorized }
        guard AuthRequestBuilder.isValidToken(credential) else { throw APIError.invalidRequest }
        let drafted = try PlayerContentMPContract.officialCanPublish(baseURL: base)
        return try await fenced {
            let (data, status) = try await self.load(drafted)
            return try self.decodeCanPublish(data, status: status)
        }
    }

    private func load(_ drafted: URLRequest) async throws -> (Data, Int) {
        guard let base = baseURL() else { throw APIError.notConfigured }
        let request = try PlayerContentMPAppWire.rehome(drafted, onto: base, token: token(), stripContentType: true)
        return try await transport.send(request)
    }

    private func fenced<T>(_ operation: () async throws -> T) async throws -> T {
        let captured = scope
        let credential = token()
        try Task.checkCancellation()
        do {
            let value = try await operation()
            try Task.checkCancellation()
            guard scope == captured else { throw CancellationError() }
            return value
        } catch {
            guard !Task.isCancelled, scope == captured else { throw CancellationError() }
            if let credential, error as? APIError == .unauthorized { onUnauthorized(credential) }
            throw error
        }
    }

    private func decodeEvents(_ data: Data, status: Int) throws -> [OfficialEvent] {
        try rejectOfficialStatus(data, status: status)
        struct Box: Decodable { let data: [OfficialEvent] }
        let rows = try JSONDecoder().decode(Box.self, from: data).data
        var seen = Set<Int>()
        return rows.filter { $0.isCompleteRecord && seen.insert($0.id).inserted }
    }

    private func decodeCanPublish(_ data: Data, status: Int) throws -> Bool {
        try rejectOfficialStatus(data, status: status)
        struct Box: Decodable {
            let data: Payload
            struct Payload: Decodable { let canPublish: Bool? }
        }
        return try JSONDecoder().decode(Box.self, from: data).data.canPublish == true
    }

    private func rejectOfficialStatus(_ data: Data, status: Int) throws {
        struct Status: Decodable { let code: Int?; let msg: String? }
        let envelope = try? JSONDecoder().decode(Status.self, from: data)
        if status == 401 || envelope?.code == 401 { throw APIError.unauthorized }
        if envelope?.code != 200, envelope?.msg?.contains("无官方发布权限") == true {
            throw OfficialReadFailure.noPublisherPermission
        }
        if status == 403 || envelope?.code == 403 { throw OfficialReadFailure.forbidden }
        guard (200..<300).contains(status) else { throw APIError.httpStatus(status) }
        guard let code = envelope?.code else { throw APIError.malformedResponse }
        guard code == 200 else { throw OfficialReadFailure.rejected(code) }
    }
}

/// Topic self-play create (R8-PC-B1-1). Free orders always send; paid orders follow the payment switch.
/// Quote and activity signup stay on their existing services.
@MainActor final class PlayerContentSelfPlayClient: TopicSelfPlayServing {
    private let inner: TopicSelfPlayHTTPClient
    private let baseURL: URL

    init(inner: TopicSelfPlayHTTPClient, baseURL: URL) {
        self.inner = inner
        self.baseURL = baseURL
    }

    var session: PublishingSession? { inner.session }
    var configured: Bool { inner.configured }
    func document() async throws -> TopicSelfPlayDocument { try await inner.document() }
    func freshTopic(_ topic: SelfPlayTopicID) async throws -> TopicDetail { try await inner.freshTopic(topic) }
    func recordConsent(requestID: String, document: TopicSelfPlayDocument) async throws {
        try await inner.recordConsent(requestID: requestID, document: document)
    }
    func paymentParameters(registrationID: Int) async throws -> [String: String] {
        try await inner.paymentParameters(registrationID: registrationID)
    }
    func readOrder(registrationID: Int) async throws -> OrderLifecycleDetail {
        try await inner.readOrder(registrationID: registrationID)
    }
    /// R8-PC-B1-1: MP pages/topic/index/index.js:1469 posts `/api/registration/create`.
    /// A paid total follows `ReleaseMoneyWriteSwitch.paymentEnabled` (owner 11-26: money is on in Release).
    /// A free (¥0) self-play order is not money and is always sent.
    func create(_ intent: TopicSelfPlayIntent) async throws -> RegistrationCreateResult {
        if PlayerContentMPContract.moneyEnabled { return try await inner.create(intent) }
        let fresh = try await inner.freshTopic(intent.topic)
        guard PlayerContentMPContract.selfPlayCreateOpen(price: fresh.selfPlayPrice) else {
            throw TopicSelfPlayFailure.unavailable
        }
        return try await inner.create(intent)
    }
}
