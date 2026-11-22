import SwiftUI

/// Production destination routing reuses only compatible entity domains.
@MainActor struct SessionGlobalSearchView: View {
    @EnvironmentObject private var session: AppSession
    var onSignIn: (() -> Void)? = nil
    /// MP link query (search2 `keyword`, result filters, searchmap `params`): runs once when the view can search.
    var initialQuery: GlobalSearchQuery? = nil
    /// MP `pages/searchmap/index` opens the map explorer, not the list search.
    var startsOnMap = false
    @State private var publicLayers: MapPublicLayerCaller?
    var body: some View {
        content
            .environment(\.walkingNavigationFactory, session.walkingNavigationFactory)
            .id(session.searchMapReader.scope)
            .task(id: session.searchMapReader.scope) {
                if publicLayers == nil {
                    publicLayers = MapPublicLayerCaller(reader: session.searchMapReader) { id in
                        let access = try await session.activityDetail(id: id)
                        guard case .allowed(let detail) = access else { throw APIError.notConfigured }
                        return detail.summary.name
                    }
                }
                publicLayers?.noteAccount(session.account?.id)
            }
    }
    @ViewBuilder private var content: some View {
        if startsOnMap {
            SearchMapExplorerView(reader: session.searchMapReader, mode: .city, initialFilter: initialQuery ?? .init(),
                                  onSignIn: onSignIn, destination: destination)
        } else {
            GlobalSearchView(reader: session.searchMapReader, historyNamespace: session.searchMapHistoryNamespace, publicMerchant: session.publicMerchantHomeContext,
                             onSignIn: onSignIn, recommendedKeywords: GlobalSearchRecommendedKeywords.keywords(for: session.operationalMarket),
                             publicLayers: publicLayers, initialQuery: initialQuery, destination: destination)
        }
    }
    @ViewBuilder private func destination(_ value: SearchMapDestination) -> some View {
        switch value {
        case .activity(let id): ActivityDetailView(id: id, reader: session, playReaderForActivity: { session.playReader(for: .activity($0)) }, registrationEnabled: true)
        case .topic(let id): SessionTopicDetailView(id: id, session: session)
        case .club(let id): ClubDetailView(id: id, reader: session, onSignIn: onSignIn, actionCoordinator: session.clubActionCoordinator, management: session.clubManagementContext, community: session.clubCommunityContext, publicRoster: session.clubPublicRosterReader)
        case .merchant(let id): SearchMapMerchantDetailView(id: id, reader: session.searchMapReader)
        case .cityNode(let id): SearchMapCityDetailView(id: id, reader: session.searchMapReader, destination: cityNodeRelatedDestination)
        }
    }
    @ViewBuilder private func cityNodeRelatedDestination(_ related: SearchMapDestination) -> some View {
        // City-node related links are only merchant IDs, never template IDs masquerading as topics.
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
