import SwiftUI

@MainActor struct GlobalSearchView<Destination: View>: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.themeDomain) private var themeDomain
    /// Player-first: shops/merchants are not a player search target (no chip, no wording, no rows).
    private var hidesMerchants: Bool { themeDomain == .player }
    private var searchKinds: [GlobalSearchKind] { GlobalSearchKind.allCases.filter { !(hidesMerchants && $0 == .merchant) } }
    let reader: any SearchMapReading
    var historyNamespace: String? = nil
    var publicMerchant = PublicMerchantHomeContext()
    var onSignIn: (() -> Void)? = nil
    var recommendedKeywords: [String] = []
    var publicLayers: MapPublicLayerCaller? = nil
    let destination: (SearchMapDestination) -> Destination
    @State private var filter = GlobalSearchQuery()
    @State private var categoryRecovery = SearchMapCategoryRecovery()
    @State private var categoryPresentationID = UUID()
    @State private var filterPresentationID = UUID()
    @State private var filterSheetVisible = false
    @State private var retainedResults = GlobalSearchRetainedResults()
    @State private var isVisible = false
    /// Search lifecycle (docs/release/state-machines/views.md); results live in `retainedResults`.
    @State private var phase: CYPhase<Void, String> = .idle
    /// Loading-to-content choreography (docs/release/motion-spec-loading.md): timed skeleton + first-screen stagger.
    @State private var skeletonShown = false
    @State private var stagger = CYStaggerGate()
    @QuestifyReduceMotion private var reduceMotion
    /// The skeleton is being held for its minimum time after the results arrived.
    private var holdingSkeleton: Bool { skeletonShown && !loading }
    private var issue: String? { phase.failure }
    private var loading: Bool { phase.isLoading }
    /// Guard: only an in-flight search falls back to idle; a failure stays visible.
    private func settleLoading() { if phase.isLoading { phase = .idle } }
    @State private var selectedKind: GlobalSearchKind?
    @State private var showsFilters = false
    @State private var history: [String] = []
    @State private var historyFailure = false
    @State private var preparedOwner: ReadOwner?
    @State private var mapRoute: MapRoute?
    private let historyStore = SearchMapLocalHistory()

    private struct ReadOwner: Equatable {
        let readerID: ObjectIdentifier
        let scope: UUID
        let authenticated: Bool
        let configured: Bool
    }
    private var readOwner: ReadOwner {
        .init(readerID: ObjectIdentifier(reader), scope: reader.scope,
              authenticated: reader.isAuthenticated, configured: reader.isConfigured)
    }
    private var resultContext: GlobalSearchResultContext {
        .init(readerID: ObjectIdentifier(reader), scope: reader.scope, isAuthenticated: reader.isAuthenticated,
              isConfigured: reader.isConfigured, query: filter)
    }
    /// Mini-program `pages/search2`: search field with 筛选, then 搜索历史, 推荐搜索 and 类别, then the map entry.
    /// Results replace the suggestions in place (the mini-program pushes `search2/result`).
    var body: some View {
        List {
            Section {
                // Mini-program `search2` head: one pill field with 筛选 trailing inside it.
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(CYColor.textTertiary).accessibilityHidden(true)
                    TextField(LocalizedStringKey(hidesMerchants ? "searchMap.placeholder.player" : "searchMap.placeholder"), text: Binding(get: { filter.keyword }, set: setKeyword)).textInputAutocapitalization(.never)
                        .submitLabel(.search).onSubmit { Task { await search() } }
                        .accessibilityIdentifier("searchMap.keyword")
                        .frame(minHeight: 44)
                }
                .padding(.horizontal, CYSpacing.md)
                .searchNightPill()
                // Mini-program `search2` head: the pill field, then a separate 筛选 tile (grid icon + label).
                .safeAreaInset(edge: .trailing, spacing: CYSpacing.sm) {
                    Button { openFilters() } label: {
                        Label("searchMap.filters", systemImage: "square.grid.2x2")
                            .font(CYTypography.label).foregroundStyle(CYColor.textPrimary)
                            .padding(.horizontal, CYSpacing.md)
                            .frame(minHeight: 44)
                            .background(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(CYNight.ink2))
                            .contentShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                    }
                    .buttonStyle(.plain).fixedSize()
                    .accessibilityIdentifier("searchMap.filters")
                }
                .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                if historyFailure { Text("searchMap.historyUnavailable").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary) }
                if reader.isOfflineExample { Label("searchMap.offline", systemImage: "wifi.slash").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary) }
            }
            .listRowBackground(Color.clear)
            // The single primary action appears once there is a keyword; the keyboard Search key always submits.
            if filter.canSearch {
                Section {
                    Button("searchMap.search") { Task { await search() } }
                        .buttonStyle(.questifyPrimary).frame(maxWidth: .infinity, minHeight: 44).disabled(!reader.isConfigured)
                        .accessibilityIdentifier("searchMap.submit")
                }
                .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }
            if !reader.isConfigured {
                Section { SearchMapIssue(key: "searchMap.notConfigured").questifyCardListRow() }
            } else {
                if skeletonShown {
                    Section {
                        CYLoadingStateView(rows: 3)
                            .accessibilityLabel(Text("searchMap.loading"))
                            .accessibilityIdentifier("searchMap.loading")
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .transition(.opacity)
                    }
                }
                if let issue, !holdingSkeleton { Section { SearchMapIssue(key: issue) { Task { await search() } }.questifyCardListRow() } }
                if holdingSkeleton {
                    EmptyView()
                } else if let snapshot = retainedResults.snapshot(in: resultContext) {
                    results(snapshot.results, retainedKinds: snapshot.retainedKinds)
                } else if !loading && issue == nil { suggestions }
            }
            mapSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(CYColor.bgPage)
        .cySkeletonTiming(isLoading: loading, visible: $skeletonShown)
        .cyAnimation(.easeInOut(duration: CYMotion.Duration.quick), value: skeletonShown)
        .appNavigationTitle("searchMap.title")
        .navigationDestination(item: $mapRoute) { route in
            let _ = recordRoute(route)
            switch route {
            case .city: SearchMapExplorerView(reader: reader, mode: .city, initialFilter: filter, onSignIn: onSignIn, destination: destination)
            case .nearby: SearchMapExplorerView(reader: reader, mode: .nearby, onSignIn: onSignIn, destination: destination)
            case .layers: if let publicLayers { MapPublicLayerCallerView(caller: publicLayers) }
            case .shops: MerchantDiscoverView(reader: reader, publicMerchant: publicMerchant)
            }
        }
        .sheet(isPresented: $showsFilters) {
            let presentationID = filterPresentationID
            let context = categoryRecovery.context(for: categoryOwner)
            let applyContext = categoryRecovery.presentationContext(for: categoryOwner)
            SearchMapFilterSheet(filter: filter, categories: categories, categoryFailed: categoryFailed,
                                 categoryLoading: categoryLoading, categoryLoaded: categoryLoaded,
                                 retryCategories: context.map { captured in {
                                     guard showsFilters, filterSheetVisible, presentationID == filterPresentationID else { return }
                                     _ = categoryRecovery.retry(in: captured)
                                 } }) { next in
                guard showsFilters, filterSheetVisible, presentationID == filterPresentationID,
                      let applyContext, categoryRecovery.acceptsPresentation(applyContext) else { return }
                applyFilter(next)
            }
            .onAppear {
                guard showsFilters, presentationID == filterPresentationID, categoryRecovery.owns(categoryOwner) else { return }
                filterSheetVisible = true; updateCategoryPresentation()
            }
            .onDisappear {
                guard presentationID == filterPresentationID, categoryRecovery.owns(categoryOwner) else { return }
                filterSheetVisible = false; updateCategoryPresentation()
            }
        }
        .task(id: readOwner) { await prepare() }
        #if DEBUG
        .task {
            // Design fixtures only: `--design-search-keyword <text>` runs one search so the results list can be shot.
            let args = ProcessInfo.processInfo.arguments
            guard let i = args.firstIndex(of: "--design-search-keyword"), args.indices.contains(i + 1) else { return }
            try? await Task.sleep(nanoseconds: 800_000_000)
            setKeyword(args[i + 1]); await search()
        }
        #endif
        .onChange(of: categoryOwner) { _, _ in updateCategoryPresentation() }
        .onChange(of: scenePhase) { _, _ in updateCategoryPresentation() }
        .onChange(of: showsFilters) { _, visible in
            if !visible { filterSheetVisible = false }
            updateCategoryPresentation()
        }
        .onAppear { isVisible = true; categoryPresentationID = UUID(); updateCategoryPresentation() }
        .onDisappear {
            isVisible = false; retainedResults.cancelPending(); settleLoading()
            categoryRecovery.update(reader: reader, presentationID: nil, active: false)
        }
    }
    private var categoryOwner: SearchMapCategoryRecovery.Owner { .init(reader: reader) }
    private var categories: [DiscoveryCategory] { categoryRecovery.owns(categoryOwner) ? categoryRecovery.categories : [] }
    private var categoryFailed: Bool { categoryRecovery.owns(categoryOwner) && categoryRecovery.phase == .failed }
    private var categoryLoading: Bool { categoryRecovery.owns(categoryOwner) && categoryRecovery.phase == .loading }
    private var categoryLoaded: Bool { categoryRecovery.owns(categoryOwner) && categoryRecovery.phase == .loaded }
    private func openFilters() {
        filterPresentationID = UUID(); filterSheetVisible = false; showsFilters = true
        updateCategoryPresentation()
    }
    private func updateCategoryPresentation() {
        // The page and sheet share the directory, never a draft or search request.
        // Switching surfaces retires callbacks; a settled directory survives reopening.
        let presentationID = showsFilters ? (filterSheetVisible ? filterPresentationID : nil) : categoryPresentationID
        categoryRecovery.update(reader: reader, presentationID: presentationID,
                                active: isVisible && scenePhase == .active)
        if let context = categoryRecovery.context(for: categoryOwner) {
            categoryRecovery.loadIfNeeded(in: context)
        }
    }
    @ViewBuilder private var suggestions: some View {
        let context = categoryRecovery.context(for: categoryOwner)
        // Mini-program 搜索历史: outlined keyword chips with 清空 on the header line (no recent-routes shelf).
        if !history.isEmpty {
            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88))], spacing: CYSpacing.sm) {
                    ForEach(history, id: \.self) { keyword in
                        Button { setKeyword(keyword); Task { await search() } } label: {
                            Text(verbatim: keyword).font(CYTypography.label).foregroundStyle(CYColor.textPrimary)
                                .lineLimit(1).minimumScaleFactor(0.85)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .searchNightPill()
                                .contentShape(Capsule())
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                HStack {
                    sectionTitle("searchMap.history")
                    Spacer()
                    Button("searchMap.clearHistory") { if historyStore.clear(namespace: historyNamespace) { history = [] }; historyFailure = historyStore.failed }
                        .font(CYTypography.meta).textCase(nil).buttonStyle(.borderless)
                        .frame(minHeight: 44).accessibilityIdentifier("searchMap.clearHistory")
                        .accessibilityLabel(Text("searchMap.clearHistory.a11y"))
                }
            }
            .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
        }
        if !recommendedKeywords.isEmpty {
            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88))], spacing: CYSpacing.sm) {
                    ForEach(Array(recommendedKeywords.enumerated()), id: \.offset) { index, keyword in
                        Button { setKeyword(keyword); Task { await search() } } label: {
                            Text(verbatim: keyword).font(CYTypography.label).foregroundStyle(CYColor.textPrimary)
                                .lineLimit(1).minimumScaleFactor(0.85)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .searchNightPill()
                                .contentShape(Capsule())
                        }.buttonStyle(.plain).disabled(!reader.isConfigured)
                            .accessibilityIdentifier("searchMap.recommended.\(index)")
                    }
                }
                .padding(.vertical, 4)
            } header: { sectionTitle("searchMap.recommended") }
            .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
        }
        // 类别 hides once the directory is known to be empty; loading and failure still show.
        if categoryLoading || categoryFailed || !categories.isEmpty {
            Section {
                if categoryLoading {
                    CYSkeleton().padding(.vertical, CYSpacing.sm).accessibilityIdentifier("globalSearch.category.loading")
                } else if categoryFailed {
                    SearchMapIssue(key: "searchMap.categoryFailed") {
                        guard !showsFilters, let context else { return }
                        _ = categoryRecovery.retry(in: context)
                    }
                    .questifyCardListRow()
                }
                if !categories.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 125))], spacing: CYSpacing.md) {
                        ForEach(categories) { category in
                            Button {
                                guard !showsFilters, let context, categoryRecovery.accepts(context) else { return }
                                var next = filter; next.categoryID = category.id; applyFilter(next)
                            } label: {
                                Text(verbatim: category.name).font(CYTypography.label).foregroundStyle(.white)
                                    .multilineTextAlignment(.leading).shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                                    .frame(maxWidth: .infinity, minHeight: 76, alignment: .bottomLeading).padding(CYSpacing.md)
                                    .background {
                                        ZStack(alignment: .bottom) {
                                            CYCoverArt(seed: category.name, showsDebugLabel: false)
                                            LinearGradient(colors: [.clear, .black.opacity(0.45)], startPoint: .center, endPoint: .bottom)
                                        }
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
                                    .contentShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
                            }.buttonStyle(CYPressScaleStyle()).accessibilityIdentifier("searchMap.category.\(category.id)")
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: { sectionTitle("searchMap.categories") }
            .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
        }
    }
    private enum MapRoute: String, Hashable, Identifiable { case city, nearby, layers, shops
        var id: Self { self }
    }
    private func recordRoute(_ route: MapRoute) {
        var list = (UserDefaults.standard.stringArray(forKey: globalSearchRecentRoutesKey) ?? []).filter { $0 != route.rawValue }
        list.insert(route.rawValue, at: 0)
        UserDefaults.standard.set(Array(list.prefix(4)), forKey: globalSearchRecentRoutesKey)
    }
    /// Mini-program `search-actions__map` (在地图上找活动与主题节点) as one pill; the native nearby, layers and
    /// shop entries are demoted into a single menu row and stay reachable.
    private var mapSection: some View {
        Section {
            Button { mapRoute = .city } label: {
                Label("searchMap.citySearch", systemImage: "location.north.line")
                    .font(CYTypography.label).foregroundStyle(CYColor.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .searchNightPill()
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("searchMap.citySearch")
            Menu {
                Button { mapRoute = .nearby } label: { Label("searchMap.nearby", systemImage: "location") }
                if publicLayers != nil {
                    Button { mapRoute = .layers } label: { Label("searchMap.publicLayers", systemImage: "square.3.layers.3d") }
                        .accessibilityIdentifier("mapPublic.entry")
                }
                if !hidesMerchants {
                    Button { mapRoute = .shops } label: { Label("merchant.discover.title", systemImage: "storefront") }
                        .accessibilityIdentifier("merchant.discover.entry")
                }
            } label: {
                HStack(spacing: 6) {
                    Text(LocalizedStringResource("searchMap.moreWays", defaultValue: "More ways to find"))
                    Image(systemName: "chevron.down").font(.caption2.weight(.bold))
                }
                .font(CYTypography.label).foregroundStyle(CYColor.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .accessibilityIdentifier("searchMap.more")
        }
        .listRowBackground(Color.clear)
    }
    private func sectionTitle(_ key: LocalizedStringKey) -> some View {
        Text(key).font(.title3.weight(.bold)).foregroundStyle(CYColor.textPrimary).textCase(nil)
            .padding(.horizontal, CYSpacing.xs).accessibilityAddTraits(.isHeader)
    }
    @ViewBuilder private func results(_ value: GlobalSearchResults, retainedKinds: [GlobalSearchKind]) -> some View {
        // Mini-program `pages/search2/result`: result tabs first. Segmented when the labels fit, a menu otherwise,
        // so counts never clip on small phones or at large text sizes.
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CYSpacing.sm) {
                    kindPill(nil, title: Text("searchMap.all") + Text(verbatim: " \(allCountText(value))"))
                    ForEach(searchKinds, id: \.self) { kind in
                        kindPill(kind, title: Text(kind.titleKey) + Text(verbatim: " \(countText(value, kind))"))
                    }
                }
                .padding(.horizontal, CYSpacing.pageHorizontal)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .accessibilityIdentifier("searchMap.resultKinds")
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        if (loading && !value.rows.isEmpty) || !retainedKinds.isEmpty || !value.gatedKinds.isEmpty || !value.failedKinds.isEmpty {
            Section {
                if loading && !value.rows.isEmpty {
                    Text("globalSearchRetention.refreshing").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("globalSearchRetention.refreshing")
                }
                if !retainedKinds.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("globalSearchRetention.stale")
                        ForEach(retainedKinds, id: \.self) { kind in Label(kind.titleKey, systemImage: "clock.arrow.circlepath") }
                    }.font(CYTypography.meta).foregroundStyle(CYColor.textSecondary).accessibilityIdentifier("globalSearchRetention.stale")
                }
                if !value.gatedKinds.isEmpty {
                    Label("searchMap.partialSignIn", systemImage: "lock").font(CYTypography.meta)
                        .accessibilityIdentifier("searchMap.guestGate")
                    if let onSignIn { Button("searchMap.signIn", action: onSignIn).frame(minHeight: 44) }
                }
                if !value.failedKinds.isEmpty {
                    VStack(alignment: .leading) {
                        Text(LocalizedStringKey(value.allFailed ? "searchMap.allFailed" : "searchMap.partialFailure"))
                        ForEach(value.failedKinds, id: \.self) { kind in Label(kind.titleKey, systemImage: "exclamationmark.circle") }
                        Button("searchMap.retry") { Task { await search() } }.buttonStyle(.borderless).frame(minHeight: 44)
                    }.font(CYTypography.meta).accessibilityIdentifier("searchMap.partialFailure")
                }
            }
        }
        let visible = value.rows.filter { !(hidesMerchants && $0.kind == .merchant) && (selectedKind == nil || $0.kind == selectedKind) }
        Section {
            // pages/search2/index readiness: a failed/gated player lane beside empty lanes is unknown, not "no results".
            if !loading, GlobalSearchEntryReadiness.phase(configured: reader.isConfigured, loading: loading, issueKey: nil,
                                                          results: value) == .unknown {
                Label("searchMap.unknownResults", systemImage: "questionmark.circle")
                    .font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                    .accessibilityIdentifier("searchMap.unknown")
            }
            if value.showsEmptyState(for: selectedKind, isLoading: loading) {
                CYEmptyState(systemImage: "magnifyingglass", "searchMap.empty", messageIdentifier: "searchMap.empty", kind: .search)
            }
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, row in
                NavigationLink { destination(row.destination) } label: { SearchMapCard(row: row, offline: reader.isOfflineExample) }
                    .buttonStyle(QuestifyCardButtonStyle()).accessibilityIdentifier("searchMap.result.\(row.id)")
                    .questifyHidesLinkIndicator()
                    .cyStaggeredAppear(index: index, gate: stagger)
                    .questifyCardListRow()
            }
        }
        // Mini-program result footer: "内容已加载完" and "刷新搜索结果".
        if !visible.isEmpty && !loading {
            Section {
                VStack(spacing: CYSpacing.xs) {
                    Text("searchMap.endOfResults").font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                    Button("searchMap.refreshResults") { Task { await search() } }
                        .font(CYTypography.label).buttonStyle(.borderless).frame(minHeight: 44)
                        .accessibilityIdentifier("searchMap.refreshResults")
                }
                .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)
        }
    }
    /// Player lanes read the page model (em dash when failed or gated); merchant keeps its own count.
    private func countText(_ value: GlobalSearchResults, _ kind: GlobalSearchKind) -> String {
        GlobalSearchEntryReadiness.countText(value, kind: kind) ?? String(value.count(kind))
    }
    private func allCountText(_ value: GlobalSearchResults) -> String {
        let player = GlobalSearchEntryReadiness.playerTotalText(value)
        return player == GlobalSearchEntryReadiness.unknownCount ? player : String(value.rows.count)
    }
    private func kindPill(_ kind: GlobalSearchKind?, title: Text) -> some View {
        let selected = selectedKind == kind
        return Button { withAnimation(CYMotion.resolve(.snappy, reduceMotion: reduceMotion)) { selectedKind = kind } } label: {
            title.font(CYTypography.bodyMedium).lineLimit(1)
                .foregroundStyle(selected ? Color.white : CYColor.textPrimary)
                .padding(.horizontal, CYSpacing.lg).frame(minHeight: 44)
                .searchNightPill(selected: selected)
        }
        .buttonStyle(.plain).cyHaptic(.selection, trigger: selectedKind)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
    private func kindPicker(_ value: GlobalSearchResults) -> some View {
        Picker("searchMap.resultKinds", selection: $selectedKind) {
            Text("searchMap.all").tag(GlobalSearchKind?.none)
            ForEach(searchKinds, id: \.self) { kind in
                (Text(kind.titleKey) + Text(verbatim: " \(countText(value, kind))"))
                    .tag(Optional(kind))
                    .accessibilityIdentifier("searchMap.kind.\(kind.rawValue)")
            }
        }
        .labelsHidden()
    }
    private func applyFilter(_ next: GlobalSearchQuery) {
        // Invalidate synchronously, including category-only searches cleared to an empty query.
        filter = next; invalidate(); Task { await search() }
    }
    private func setKeyword(_ value: String) {
        guard !filter.keyword.utf8.elementsEqual(value.utf8) else { return }
        invalidate(); filter.keyword = value
    }
    private func invalidate() { retainedResults.invalidate(); phase = .idle; selectedKind = nil }
    private func prepare() async {
        guard !Task.isCancelled else { return }
        if preparedOwner != readOwner {
            preparedOwner = readOwner; invalidate()
            history = historyStore.read(namespace: historyNamespace); historyFailure = historyStore.failed
        }
        updateCategoryPresentation()
    }
    private func search() async {
        let query = filter
        guard isVisible else { return }
        guard reader.isConfigured, query.canSearch else { return }
        let captured = resultContext
        let ticket = retainedResults.begin(in: captured)
        phase = .loading
        do {
            let value = try await reader.search(query)
            guard !Task.isCancelled, isVisible, filter == query, retainedResults.accepts(ticket, in: resultContext) else { return }
            phase = .loaded(())
            retainedResults.finish(value, ticket: ticket, in: resultContext)
            history = historyStore.add(query.keyword, namespace: historyNamespace, current: history); historyFailure = historyStore.failed
        } catch {
            guard isVisible, retainedResults.accepts(ticket, in: resultContext) else { return }
            retainedResults.fail(ticket, in: resultContext)
            phase = error is CancellationError ? .idle : .failed(SearchMapIssue.key(error), retry: nil)
        }
    }
}

private let globalSearchRecentRoutesKey = "globalSearch.recentRoutes.v1"
