import SwiftUI

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
                    return AnyView(DiscoveryTopicTemplatePreview(coordinator: session.publicTopicTemplateCoordinator(id: row.sourceID)))
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
