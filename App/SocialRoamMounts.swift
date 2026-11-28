import SwiftUI

// G4/G5 entries (receipt `mount-g45`). Each reads `\.socialRoamCapabilities` and draws nothing when it is nil,
// so hosts without the root injection (fixtures, previews, signed out) are unchanged.

/// 我的 → 我的帖文 / 我的收藏 (`pages/member`, `pages/mylike`).
@MainActor struct SquareMineAccountLinks: View {
    @Environment(\.socialRoamCapabilities) private var capabilities
    @Environment(\.locale) private var locale

    var body: some View {
        if let capabilities, let service = capabilities.squareMine {
            Section {
                ForEach(SquareMineList.allCases, id: \.self) { list in
                    NavigationLink { SquareMineListView(list: list, service: service, token: capabilities.token) } label: {
                        Label {
                            Text(verbatim: list == .posts ? PlayerCapabilityCopy.text("我的帖文", "My posts", locale)
                                                          : PlayerCapabilityCopy.text("我的收藏", "Bookmarks", locale))
                        } icon: {
                            Image(systemName: list == .posts ? "text.bubble" : "bookmark")
                        }
                    }
                    .accessibilityIdentifier("account.square.mine.\(list.rawValue)")
                }
            }
        }
    }
}

/// Public merchant home (`subpackageMember/components/cy/profile`): BL-66 safety summary and BL-67 「信息纠错」.
/// `merchantID` is the public-home row id (`mms_merchant.id`).
@MainActor struct PublicMerchantTrustSection: View {
    let merchantID: Int?
    @Environment(\.socialRoamCapabilities) private var capabilities
    @Environment(\.locale) private var locale
    @State private var correcting = false

    var body: some View {
        if let capabilities, let merchantID, merchantID > 0 {
            Section {
                // One row: the summary draws nothing until a sufficient sample is read, and an empty row would show.
                VStack(alignment: .leading, spacing: 8) {
                    MerchantSafetySummaryRow(merchantID: merchantID, client: capabilities.client)
                    Button { correcting = true } label: {
                        Label(PlayerCapabilityCopy.text("商家信息纠错", "Correct merchant info", locale), systemImage: "exclamationmark.bubble")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("merchant.publicHome.correction")
                    .cySheet(isPresented: $correcting) {
                        MerchantCorrectionSheet(merchantID: merchantID, client: capabilities.client)
                            .cyDomainSheet(detents: [.half, .full])
                    }
                }
            }
        }
    }
}

/// `pages/play/merchant` 「安全感受评价」. The node carries the owner member id; like the mini-program sheet, the tap
/// resolves it through public-home to `mms_merchant.id` before the sheet opens. No owner id or no bundle: no button.
@MainActor struct PlayStoreDaySafetyRatingEntry: View {
    let ownerMemberID: Int?
    @Environment(\.socialRoamCapabilities) private var capabilities
    @Environment(\.locale) private var locale
    @State private var rating: Rating?
    @State private var resolving = false
    @State private var missed = false

    private struct Rating: Identifiable { let merchantID: Int; var id: Int { merchantID } }

    var body: some View {
        if let capabilities, let owner = ownerMemberID.flatMap(PublicMerchantOwnerID.init) {
            VStack(alignment: .leading, spacing: 4) {
                Button { Task { await open(owner, reader: capabilities.merchantHome) } } label: {
                    Label(PlayerCapabilityCopy.text("安全感受评价", "Rate how safe it felt", locale), systemImage: "shield.lefthalf.filled")
                }
                .buttonStyle(.bordered)
                .disabled(resolving)
                .accessibilityIdentifier("storeDayPage.safetyRating")
                if missed {
                    Text(verbatim: PlayerCapabilityCopy.text("没有找到这家商家", "Merchant not found", locale))
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .cySheet(item: $rating) {
                MerchantSafetyRatingSheet(merchantID: $0.merchantID, client: capabilities.client)
                    .cyDomainSheet(detents: [.half, .full])
            }
        }
    }

    private func open(_ owner: PublicMerchantOwnerID, reader: any PublicMerchantHomeReading) async {
        guard !resolving else { return }
        resolving = true; missed = false
        if reader.isConfigured, !reader.isOfflineExample,
           let home = try? await reader.home(.ownerMemberID(owner)), let id = home.id, id > 0 {
            rating = Rating(merchantID: id)
        } else {
            missed = true
        }
        resolving = false
    }
}

/// `open-address.js`: a text-only address (no coordinates) is geocoded before it opens in Maps.
@MainActor struct PlayStoreDayGeocodeEntry: View {
    let name: String
    let address: String
    @Environment(\.socialRoamCapabilities) private var capabilities

    var body: some View {
        if let capabilities, !address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            GeocodedAddressButton(name: name, address: address, city: "", client: capabilities.client)
        }
    }
}

/// BL-70 visitor stack under a roam place row (`sourceType` 1 = roam point).
@MainActor struct RoamPlaceVisitorsLine: View {
    let item: RoamMapItem
    @ObservedObject var model: RoamShopVisitorsModel

    var body: some View {
        if case .place(let place) = item {
            let source = RoamPlayerExtrasService.VisitorSource(sourceType: 1, sourceID: place.id)
            RoamShopVisitorsStack(source: source, visitors: model.visitors[source])
        }
    }
}

/// Loads the visitor stacks for the visible place rows at once, like `_loadShopStripVisitors`.
struct RoamShopVisitorsLoad: ViewModifier {
    let items: [RoamMapItem]
    let model: RoamShopVisitorsModel
    @Environment(\.socialRoamCapabilities) private var capabilities

    private var sources: [RoamPlayerExtrasService.VisitorSource] {
        items.compactMap { item in
            guard case .place(let place) = item, place.id > 0 else { return nil }
            return RoamPlayerExtrasService.VisitorSource(sourceType: 1, sourceID: place.id)
        }
    }

    func body(content: Content) -> some View {
        content.task(id: SourcesKey(sources: sources, account: capabilities?.accountID)) {
            guard let capabilities, !sources.isEmpty else { return }
            await model.load(sources, client: capabilities.client)
        }
    }

    private struct SourcesKey: Hashable { let sources: [RoamPlayerExtrasService.VisitorSource]; let account: Int? }
}

/// Roam map weather ambience for the searched area (cell centre only). A modifier on the map, so the read runs
/// while the overlay still draws nothing. The browser map has its control row at the top corner, so no chip here.
struct RoamMapWeather: ViewModifier {
    let area: RoamSearchArea

    func body(content: Content) -> some View {
        content.modifier(OwnedMapSceneWeather(latitude: area.coordinate.latitude, longitude: area.coordinate.longitude,
                                              showsChip: false))
    }
}

/// mp-roam r3: MP `cy-map-weather` on the live map (pages/roam/index.wxml:251, active only on `screen == 'map'`).
/// Reads `/api/map/weather` for the ~5.5 km cell around the player (cell centre only, never the exact point) and
/// re-reads only when the cell changes. fix/1128c-ai-weather: real particles, day / night light and the chip.
struct RoamLiveMapWeather: ViewModifier {
    let latitude: Double?
    let longitude: Double?

    func body(content: Content) -> some View {
        content.modifier(OwnedMapSceneWeather(latitude: latitude, longitude: longitude))
    }
}

/// Roam share sheet: 「作废我发出的全部分享链接」 (`revokeShareSnapshots`).
@MainActor struct RoamShareRevokeEntry: View {
    @Environment(\.socialRoamCapabilities) private var capabilities

    var body: some View {
        if let capabilities {
            RoamShareRevokeRow(client: capabilities.client, accountID: capabilities.accountID)
                .id(capabilities.accountID)
        }
    }
}

/// Public template detail: 「采用为我的草稿」 (player scope '').
@MainActor struct TemplateAdoptEntry: View {
    let sourceTemplateID: Int
    @Environment(\.socialRoamCapabilities) private var capabilities

    var body: some View {
        if let capabilities, sourceTemplateID > 0 {
            TemplateAdoptButton(sourceTemplateID: sourceTemplateID, accountID: capabilities.accountID, scope: "", client: capabilities.client)
                .id(capabilities.accountID)
        }
    }
}

/// Topic editor: U02-03/OWN-U02-04 地点待办 for a saved topic. The read runs from `TemplateLocationTodosHost` on the editor form.
/// Source version and adoption updates are `SourceLineageSection` on the use row.
@MainActor struct TemplateLocationTodosEntry: View {
    let topicID: Int
    /// `ProjectEditOwner.rawValue`: '' (personal) or 'MERCHANT', the mini-program `operationScope`.
    let scope: String
    let nodes: [ProjectEditNode]
    @Environment(\.socialRoamCapabilities) private var capabilities
    @Environment(\.templateLocationTodosStore) private var store

    /// Saved nodes (server id) with a usable place: 「名称 · 地址」.
    private var bindable: [(id: Int, label: String)] {
        nodes.compactMap { node in
            guard let id = Int(node.id), id > 0, node.hasUsableCoordinates else { return nil }
            return (id, [node.name, node.address].filter { !$0.isEmpty }.joined(separator: " · "))
        }
    }

    var body: some View {
        if let capabilities, let store, topicID > 0 {
            TemplateLocationTodosSection(topicID: topicID, scope: scope, client: capabilities.client, bindableNodes: bindable, store: store)
        }
    }
}

/// Owns the to-do store on the always-present editor form and reads it when the saved topic, scope or account changes.
struct TemplateLocationTodosHost: ViewModifier {
    let topicID: Int?
    let scope: String
    @Environment(\.socialRoamCapabilities) private var capabilities
    @StateObject private var store = TemplateLocationTodosStore()

    private struct Key: Hashable { let topicID: Int?; let scope: String; let account: Int? }

    func body(content: Content) -> some View {
        content
            .environment(\.templateLocationTodosStore, store)
            .task(id: Key(topicID: topicID, scope: scope, account: capabilities?.accountID)) {
                guard let capabilities, let topicID, topicID > 0 else { return }
                await store.load(topicID: topicID, scope: scope, client: capabilities.client)
            }
    }
}

private struct TemplateLocationTodosStoreKey: EnvironmentKey {
    static var defaultValue: TemplateLocationTodosStore? { nil }
}

extension EnvironmentValues {
    var templateLocationTodosStore: TemplateLocationTodosStore? {
        get { self[TemplateLocationTodosStoreKey.self] }
        set { self[TemplateLocationTodosStoreKey.self] = newValue }
    }
}

/// My projects, topic rows: BL-120 「另存为模板」. Browse-only merchant lists offer nothing; merchant scope sends 'MERCHANT'.
@MainActor struct MyProjectSaveAsTemplateEntry: View {
    let project: CreatorContentProject
    var reload: () -> Void = {}
    @Environment(\.socialRoamCapabilities) private var capabilities
    @Environment(\.myProjectMerchantScopeAccess) private var access

    var body: some View {
        if let capabilities, !access.isBrowseOnly, project.bizType == MyProjectBiz.topic.rawValue, project.sourceID > 0 {
            TemplateProjectActions(id: project.sourceID, title: project.title, kind: .topic,
                                   scope: access.isMerchantScope ? "MERCHANT" : "", client: capabilities.client, reload: reload)
        }
    }
}

/// R7-PC-A4-1: `pages/search2/result` content leg (pages/search2/result/index.js:95-100). Signed in with a keyword and
/// no other filter, the MP merges `/api/search/unified` rows into the main results and drops its own topic/activity
/// lanes. Here the rows sit inline in the result list; `onRows` tells the host to hide its duplicate lanes.
@MainActor struct UnifiedSearchEntry<Destination: View>: View {
    let keyword: String
    var keywordOnly: Bool = true
    var onRows: (Bool) -> Void = { _ in }
    let destination: (SearchMapDestination) -> Destination
    @Environment(\.socialRoamCapabilities) private var capabilities
    @State private var items: [MapSearchPlayerService.SearchItem] = []
    @State private var page = 0
    @State private var hasMore = false
    @State private var loading = false
    @State private var failed = false

    private var text: String { keyword.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var key: String { text + "|" + String(keywordOnly) + "|" + String(capabilities?.accountID ?? 0) }

    var body: some View {
        Group {
            if capabilities != nil, keywordOnly, !text.isEmpty, !items.isEmpty || failed {
                Section {
                    ForEach(items) { item in
                        NavigationLink { target(item) } label: {
                            VStack(alignment: .leading) {
                                Text(verbatim: item.title).font(.body)
                                Text(verbatim: (MapSearchPlayerService.typeLabels[item.type] ?? item.type) + " · " + item.detail)
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("search.unified.\(item.id)")
                    }
                    if hasMore {
                        Button("context.picker.more") { Task { await load(page + 1) } }
                            .disabled(loading).accessibilityIdentifier("searchMap.unified.more")
                    }
                    if failed {
                        Button("searchMap.retryPage") { Task { await load(max(page, 0) + 1) } }
                            .accessibilityIdentifier("searchMap.unified.retry")
                    }
                } header: {
                    Text("searchMap.unified.header")
                }
                .accessibilityIdentifier("searchMap.unified.open")
            }
        }
        .task(id: key) {
            items = []; page = 0; hasMore = false; failed = false; onRows(false)
            guard capabilities != nil, keywordOnly, !text.isEmpty else { return }
            await load(1)
        }
    }

    @ViewBuilder private func target(_ item: MapSearchPlayerService.SearchItem) -> some View {
        switch item.type {
        case "topic": destination(.topic(item.itemID))
        case "activity": destination(.activity(item.itemID))
        // MP result post rows open pages/square/detail/index?id= (square detail).
        default: MPReviewedPageScreen(page: "pages/square/detail/index", query: ["id": String(item.itemID)])
        }
    }

    private func load(_ next: Int) async {
        guard let capabilities, !loading else { return }
        loading = true; defer { loading = false }
        let types = capabilities.communityOpen ? ["topic", "activity", "post"] : ["topic", "activity"]
        do {
            let result = try await MapSearchPlayerService(client: capabilities.client)
                .unifiedSearch(keyword: text, types: types, cityCode: "", page: next)
            guard !Task.isCancelled else { return }
            var seen = Set(items.map(\.id))
            items += result.items.filter { seen.insert($0.id).inserted }
            page = next; hasMore = MapSearchPlayerService.hasMore(result, pageNumber: next); failed = false
            onRows(!items.isEmpty)
        } catch PlayerCapabilityFailure.rejected(let code, _) where code == 503 || code == 404 {
            // Unified search not open: the MP falls back to its own topic/activity lanes.
            hasMore = false; onRows(false)
        } catch {
            failed = !Task.isCancelled && !items.isEmpty; onRows(!items.isEmpty)
        }
    }
}

/// `components/cy/map-address-search` remote leg under the city search field: ≤ 5 places near the map centre.
/// A row opens the place in Maps; the explorer's own area and reads are unchanged. A modifier on the field, so the
/// search runs while no row is drawn and adds no gap when there is nothing to show.
struct MapPlaceSuggestions: ViewModifier {
    let keyword: String
    let area: RoamSearchArea?
    @Environment(\.socialRoamCapabilities) private var capabilities
    @Environment(\.openURL) private var openURL
    @Environment(\.locale) private var locale
    @StateObject private var model = MapPlaceSearchModel()

    private struct Key: Hashable { let keyword: String; let area: RoamSearchArea?; let account: Int? }

    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            content
            if capabilities != nil {
                ForEach(model.places) { place in
                    Button { open(place) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: place.name)
                            if !place.address.isEmpty {
                                Text(verbatim: place.address).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(place.coordinate == nil)
                    .accessibilityIdentifier("searchMap.place.\(place.id)")
                }
                if model.remoteError {
                    Text(verbatim: PlayerCapabilityCopy.text("地点搜索暂不可用", "Place search is unavailable", locale))
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .task(id: Key(keyword: keyword, area: area, account: capabilities?.accountID)) {
            guard let capabilities, let area else { return }
            await model.search(keyword, latitude: area.coordinate.latitude, longitude: area.coordinate.longitude,
                               localNames: [], client: capabilities.client)
        }
    }

    private func open(_ place: MapSearchPlayerService.Place) {
        guard let point = place.coordinate,
              let url = URL(string: "maps://?ll=\(point.latitude),\(point.longitude)&q=\(place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        else { return }
        openURL(url)
    }
}
