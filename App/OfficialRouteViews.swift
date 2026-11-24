import SwiftUI

// Mini-program subpackageRoam/official-routes + official-route, hosted inside the Roam start tab
// (an intro-card push, no new top-level page). Read-only: "start this route" stays unported, as in the source.

@MainActor struct OfficialRouteListView: View {
    @Environment(\.locale) private var locale
    private var officialRouteIsChinese: Bool { locale.language.languageCode?.identifier == "zh" }
    let reader: OfficialRouteReader
    @State private var state: LoadState = .loading
    @Namespace private var hero
    @State private var stagger = CYStaggerGate()
    private enum LoadState { case loading, ready([OfficialRoute]), empty, failed, offline }
    private var stateKey: Int {
        switch state { case .loading: return 0; case .ready: return 1; case .empty: return 2; case .failed: return 3; case .offline: return 4 }
    }
    var body: some View {
        Group {
            switch state {
            case .loading:
                ScrollView { CYLoadingStateView(rows: 3).padding(CYSpacing.lg) }
                    .accessibilityLabel(Text("officialRoute.loading"))
            case .failed:
                CYErrorStateView(title: "officialRoute.list.error", message: "officialRoute.error.message", retryTitle: "officialRoute.retry") { Task { await load() } }
            case .offline:
                CYStateLayout(kind: .offline, title: Text("officialRoute.list.error"), detail: Text("cy.kit.offline.body"), primary: ("officialRoute.retry", { _ = Task { await load() } }))
            case .empty:
                CYEmptyStateView(systemImage: "point.topleft.down.to.point.bottomright.curvepath", title: "officialRoute.list.empty")
            case .ready(let routes):
                ScrollView {
                    LazyVStack(spacing: CYSpacing.lg) {
                        ForEach(Array(routes.enumerated()), id: \.element.id) { index, route in
                            NavigationLink { OfficialRouteDetailView(reader: reader, routeID: route.id).cyHeroDestination(route.id, in: hero) } label: {
                                row(route).cyHeroSource(route.id, in: hero).cyStaggeredAppear(index: index, gate: stagger)
                            }
                                .buttonStyle(CYPressableStyle())
                                .accessibilityLabel(Text("officialRoute.list.open \(route.name)"))
                        }
                    }
                    .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.md)
                }
            }
        }
        .cyAnimation(.easeInOut(duration: CYMotion.Duration.standard), value: stateKey)
        .navigationTitle(Text("officialRoute.title"))
        .navigationBarTitleDisplayMode(.inline)
        .cyDomainScreen(.player)
        .task { await load() }
        .cyRefreshable { await load(refreshing: true) }
        .accessibilityIdentifier("officialRoute.list")
    }
    private func row(_ route: OfficialRoute) -> some View { OfficialRouteCard(route: route, chinese: officialRouteIsChinese) }
    private func load(refreshing: Bool = false) async {
        if !refreshing { state = .loading }
        do {
            let routes = try await reader.list()
            state = routes.isEmpty ? .empty : .ready(routes)
        } catch is CancellationError { return }
        catch let error as URLError where error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
            state = .offline
        } catch { state = .failed }
    }
}

@MainActor struct OfficialRouteDetailView: View {
    @Environment(\.locale) private var locale
    private var officialRouteIsChinese: Bool { locale.language.languageCode?.identifier == "zh" }
    let reader: OfficialRouteReader
    let routeID: String
    @State private var state: LoadState = .loading
    @State private var showShare = false
    private enum LoadState { case loading, ready(OfficialRouteDetail), notFound, failed }
    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(Text("officialRoute.loading"))
            case .failed:
                CYErrorStateView(title: "officialRoute.detail.error", message: "officialRoute.error.message", retryTitle: "officialRoute.retry") { Task { await load() } }
            case .notFound:
                CYEmptyStateView(systemImage: "questionmark.folder", title: "officialRoute.detail.notFound")
            case .ready(let detail):
                content(detail)
            }
        }
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .cyDomainScreen(.player)
        .toolbar {
            if case .ready = state {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showShare = true } label: { Label("officialRoute.share", systemImage: "square.and.arrow.up") }
                        .accessibilityIdentifier("officialRoute.share")
                }
            }
        }
        .sheet(isPresented: $showShare) {
            if case .ready(let detail) = state { CatalogShareCardView(content: shareContent(detail), tint: .ember) }
        }
        .task { await load() }
        .accessibilityIdentifier("officialRoute.detail")
    }
    /// Share card content: name, city (behind the composer's place toggle), duration / distance / stops and the
    /// relative shape of the stops. No coordinates, addresses or node names leave in the image.
    private func shareContent(_ detail: OfficialRouteDetail) -> CYShareCardContent {
        let route = detail.route
        let duration = OfficialRouteFormat.duration(route.totalMinutes, chinese: officialRouteIsChinese)
        let distance = OfficialRouteFormat.distance(route.distanceKm)
        let located = detail.nodes.filter { $0.latitude != nil && $0.longitude != nil }
        return CYShareCardContent(
            kind: .route,
            eyebrow: appLocalized("share.card.route.eyebrow", locale: locale),
            title: route.name,
            subtitle: nil,
            place: route.city.isEmpty ? nil : route.city,
            stats: [
                CYShareStat(appLocalized("share.card.stat.duration", locale: locale), duration.isEmpty ? nil : duration),
                CYShareStat(appLocalized("share.card.stat.distance", locale: locale), distance.isEmpty ? nil : distance),
                CYShareStat(appLocalized("share.card.stat.stops", locale: locale), detail.nodes.isEmpty ? nil : String(detail.nodes.count)),
            ],
            silhouette: CYShareCardContent.silhouette(latitudes: located.compactMap(\.latitude), longitudes: located.compactMap(\.longitude)),
            artSeed: route.name,
            artSymbol: "point.topleft.down.to.point.bottomright.curvepath",
            brand: appLocalized("share.card.brand", locale: locale),
            mpRouteArt: true) // MP share card: no cover → the route illustration
    }
    /// RROUTE-2: the route's own name is the inline title once loaded; 路线详情 only while loading / on errors.
    private var navTitle: Text {
        if case .ready(let detail) = state, !detail.route.name.isEmpty { return Text(verbatim: detail.route.name) }
        return Text("officialRoute.detail.title")
    }
    private func content(_ detail: OfficialRouteDetail) -> some View {
        OfficialRouteDetailContent(detail: detail, chinese: officialRouteIsChinese)
    }
    static func mapURL(lat: Double, lng: Double, name: String) -> URL? {
        var c = URLComponents(string: "https://maps.apple.com/")
        c?.queryItems = [URLQueryItem(name: "ll", value: "\(lat),\(lng)"), URLQueryItem(name: "q", value: name)]
        return c?.url
    }
    private func load() async {
        state = .loading
        do { state = .ready(try await reader.detail(routeID)) }
        catch is CancellationError { return }
        catch OfficialRouteReader.Failure.notFound { state = .notFound }
        catch { state = .failed }
    }
}

