import SwiftUI

@MainActor struct GlobalSearchView<Destination: View>: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.themeDomain) private var themeDomain
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Continuity r1: set when 首页 hosts search as a state of the page instead of a sheet.
    @Environment(\.globalSearchInPageHost) private var inPageHost
    @FocusState private var keywordFocused: Bool
    /// The field's body size, so the 首页 placeholder (14 pt) scales into it rather than cross-fading.
    @ScaledMetric(relativeTo: .body) private var fieldTextSize: CGFloat = 17
    /// R7-PC-A3-1 MP-first: MP search2 searches 主题、活动、俱乐部、商家 for every viewer (pages/search2/index.wxml:13;
    /// utils/discover-search.js:199-210 always requests the merchant lane), so players keep the merchant lane and copy.
    private var hidesMerchants: Bool { false }
    private var searchKinds: [GlobalSearchKind] { GlobalSearchKind.allCases.filter { !(hidesMerchants && $0 == .merchant) } }
    let reader: any SearchMapReading
    var historyNamespace: String? = nil
    var publicMerchant = PublicMerchantHomeContext()
    var onSignIn: (() -> Void)? = nil
    var recommendedKeywords: [String] = []
    var publicLayers: MapPublicLayerCaller? = nil
    /// MP link keyword / filters (PC-A-3-2): applied and searched once.
    var initialQuery: GlobalSearchQuery? = nil
    let destination: (SearchMapDestination) -> Destination
    @State private var initialQueryApplied = false
    /// PC-A-4-1: 主题模板 / 玩法模板 results for the same keyword (nil = not searched or not available).
    @State private var templateResults: GlobalTemplateSearchResults?
    @Environment(\.globalTemplateSearch) private var templateLanes
    @State private var filter = GlobalSearchQuery()
    /// R7-PC-A3-2: MP search2 `navigateToSearchList` toast (pages/search2/index.js:130, 250).
    @State private var emptySearchToast: LocalizedStringKey?
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
                    // Mini-program field: 搜索中 spinner while a search runs, clear (x) once there is text.
                    if loading {
                        ProgressView().controlSize(.small).tint(CYColor.resultSpinner).accessibilityLabel(Text("searchMap.loading"))
                    }
                    if !filter.keyword.isEmpty {
                        Button { setKeyword("") } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(CYColor.textTertiary)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(Text("searchMap.clearKeyword"))
                        .accessibilityIdentifier("searchMap.clearKeyword")
                    }
                }
                .padding(.horizontal, CYSpacing.md)
                .searchNightPill()
                // Mini-program `search2` head: the pill field, then a separate 筛选 tile (grid icon + label).
                .safeAreaInset(edge: .trailing, spacing: CYSpacing.sm) {
                    Button { openFilters() } label: {
                        Label("searchMap.filters", systemImage: "square.grid.2x2")
                            .cyText(.label).foregroundStyle(CYColor.textPrimary)
                            .padding(.horizontal, CYSpacing.md)
                            .frame(minHeight: 44)
                            .background(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(CYNight.ink2))
                            .contentShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                    }
                    .buttonStyle(.plain).fixedSize()
                    .pageTemplateControl(label: Text("searchMap.filters"), traits: .isButton)
                    .accessibilityIdentifier("searchMap.filters")
                }
                .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                .globalSearchInlineField(hidden: inPageHost != nil)
                if historyFailure { Text("searchMap.historyUnavailable").cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                if reader.isOfflineExample { Label("searchMap.offline", systemImage: "wifi.slash").cyText(.meta).foregroundStyle(CYColor.textSecondary) }
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
        // Typing swaps suggestions and results; rows insert and remove on the product spring.
        .cyAnimation(CYMotion.standard, value: listMotionKey)
        .globalSearchInPage(inPageHost) { hostedFieldRow($0) }
        .cySkeletonTiming(isLoading: loading, visible: $skeletonShown)
        .cyAnimation(.easeInOut(duration: CYMotion.Duration.quick), value: skeletonShown)
        .appNavigationTitle("searchMap.title").navigationBarTitleDisplayMode(.inline)
        .cyHideTabBar()
        .navigationDestination(item: $mapRoute) { route in
            let _ = recordRoute(route)
            switch route {
            case .city: SearchMapExplorerView(reader: reader, mode: .city, initialFilter: filter, onSignIn: onSignIn, destination: destination)
            case .nearby: SearchMapExplorerView(reader: reader, mode: .nearby, onSignIn: onSignIn, destination: destination)
            case .layers: if let publicLayers { MapPublicLayerCallerView(caller: publicLayers) }
            case .shops: MerchantDiscoverView(reader: reader, publicMerchant: publicMerchant)
            }
        }
        .cyToast(message: $emptySearchToast)
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
            .cySheet()
        }
        // PC-A-4-1: every content search also runs the two template lanes; their failure never fails the page.
        .onChange(of: loading) { _, isLoading in
            guard isLoading, let templateLanes else { return }
            let query = filter, scope = reader.scope
            templateResults = nil
            Task { @MainActor in
                let templates = await templateLanes.search(query)
                guard isVisible, filter == query, reader.scope == scope else { return }
                templateResults = templates
            }
        }
        .task(id: readOwner) {
            await prepare()
            if let initialQuery, !initialQueryApplied, reader.isConfigured {
                initialQueryApplied = true; filter = initialQuery
                // The task can start before onAppear marks the page visible; search() refuses an invisible page.
                for _ in 0..<40 where !isVisible && !Task.isCancelled { try? await Task.sleep(nanoseconds: 50_000_000) }
                await search()
            }
        }
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
        // In-page search: the keyboard rises with the field and drops as 取消 starts the reverse.
        .onChange(of: inPageHost?.progress) { _, progress in keywordFocused = progress == 1 }
        .onDisappear {
            isVisible = false; retainedResults.cancelPending(); settleLoading()
            categoryRecovery.update(reader: reader, presentationID: nil, active: false)
        }
    }
    private var categoryOwner: SearchMapCategoryRecovery.Owner { .init(reader: reader) }
    /// Changes when the list swaps suggestions, loading, a failure or result rows.
    private var listMotionKey: [String] {
        guard let snapshot = retainedResults.snapshot(in: resultContext) else {
            return [loading ? "loading" : (issue ?? "suggestions")]
        }
        return snapshot.results.rows.filter { selectedKind == nil || $0.kind == selectedKind }.map { "\($0.id)" }
    }
    /// 首页's search state: the field it was tapped from, 筛选 and 取消 in one top row. Same field, spinner, clear and
    /// filters as the inline row; only its place changes.
    private func hostedFieldRow(_ host: GlobalSearchInPageHost) -> some View {
        HStack(spacing: CYSpacing.sm) {
            HStack(spacing: 8) {
                // Same ink as the 首页 field it starts on (magnifier and prompt in textSecondary), so the hand-over frame
                // matches the field at rest exactly.
                Image(systemName: "magnifyingglass").foregroundStyle(CYColor.textSecondary).accessibilityHidden(true)
                TextField(text: Binding(get: { filter.keyword }, set: setKeyword),
                          prompt: Text(LocalizedStringKey(hidesMerchants ? "searchMap.placeholder.player" : "searchMap.placeholder")).foregroundStyle(CYColor.textSecondary)) {
                    Text(LocalizedStringKey(hidesMerchants ? "searchMap.placeholder.player" : "searchMap.placeholder"))
                }
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search).onSubmit { Task { await search() } }
                    .focused($keywordFocused)
                    .accessibilityIdentifier("searchMap.keyword")
                    .frame(minHeight: 44)
                    .modifier(GlobalSearchTextSettle(progress: host.progress, moving: host.source != nil,
                                                     from: Theme.length("--cy-type-body") / max(fieldTextSize, 1)))
                // Contextual icons: spinner and clear trade places with scale, fade and blur.
                if loading {
                    ProgressView().controlSize(.small).tint(CYColor.resultSpinner).accessibilityLabel(Text("searchMap.loading"))
                        .transition(.globalSearchContextualIcon)
                }
                if !filter.keyword.isEmpty {
                    Button { setKeyword("") } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(CYColor.textTertiary)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("searchMap.clearKeyword"))
                    .accessibilityIdentifier("searchMap.clearKeyword")
                    .transition(.globalSearchContextualIcon)
                }
            }
            .cyAnimation(CYMotion.standard, value: [loading, filter.keyword.isEmpty])
            .padding(.horizontal, CYSpacing.md)
            .modifier(GlobalSearchFieldMorph(progress: host.progress, source: host.source, onPlaced: host.onFieldPlaced))
            // 筛选 exists only in the search state: it fades in after half the move and out in the first half back.
            Button { openFilters() } label: {
                Label("searchMap.filters", systemImage: "square.grid.2x2")
                    .cyText(.label).foregroundStyle(CYColor.textPrimary)
                    .padding(.horizontal, CYSpacing.md)
                    .frame(minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(CYNight.ink2))
                    .contentShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
            }
            .buttonStyle(.plain).fixedSize()
            .pageTemplateControl(label: Text("searchMap.filters"), traits: .isButton)
            .accessibilityIdentifier("searchMap.filters")
            .modifier(GlobalSearchProgressFade(progress: host.progress, start: 0.5, end: 1))
            Button("action.cancel") { keywordFocused = false; host.onCancel() }
                .cyText(.body).foregroundStyle(CYColor.textPrimary)
                .buttonStyle(.borderless).fixedSize()
                .frame(minHeight: 44)
                .accessibilityIdentifier("globalSearch.close")
                .modifier(GlobalSearchTrailingSlide(progress: host.progress, moving: host.source != nil))
        }
        .padding(.horizontal, CYSpacing.pageHorizontal)
        .padding(.vertical, CYSpacing.xs)
        .accessibilityAction(.escape) { keywordFocused = false; host.onCancel() }
    }
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
                            Text(verbatim: keyword).cyText(.label).foregroundStyle(CYColor.textPrimary)
                                .cyWrapText(alignment: .center)
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
                        .cyText(.meta).textCase(nil).buttonStyle(.borderless)
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
                            Text(verbatim: keyword).cyText(.label).foregroundStyle(CYColor.textPrimary)
                                .cyWrapText(alignment: .center)
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
                                Text(verbatim: category.name).cyText(.label).foregroundStyle(.white)
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
                    .cyText(.label).foregroundStyle(CYColor.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .searchNightPill()
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .pageTemplateControl(label: Text("searchMap.citySearch"), traits: .isButton)
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
                    Image(systemName: "chevron.down").font(.caption.weight(.bold))
                }
                .cyText(.label).foregroundStyle(CYColor.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .pageTemplateControl(
                label: Text(LocalizedStringResource("searchMap.moreWays", defaultValue: "More ways to find")),
                traits: .isButton
            )
            .accessibilityIdentifier("searchMap.more")
        }
        .listRowBackground(Color.clear)
    }
    private func sectionTitle(_ key: LocalizedStringKey) -> some View {
        Text(key).cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary).textCase(nil)
            .padding(.horizontal, CYSpacing.xs).accessibilityAddTraits(.isHeader)
    }
    @ViewBuilder private func results(_ value: GlobalSearchResults, retainedKinds: [GlobalSearchKind]) -> some View {
        // Mini-program `pages/search2/result`: result tabs first. Segmented when the labels fit, a menu otherwise,
        // so counts never clip on small phones or at large text sizes.
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CYSpacing.sm) {
                    // Mini-program result tabs: 全部 carries no count; each kind tab shows its own.
                    kindPill(nil, title: Text("searchMap.all"))
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
                    Text("globalSearchRetention.refreshing").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("globalSearchRetention.refreshing")
                }
                if !retainedKinds.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("globalSearchRetention.stale")
                        ForEach(retainedKinds, id: \.self) { kind in Label(kind.titleKey, systemImage: "clock.arrow.circlepath") }
                    }.cyText(.meta).foregroundStyle(CYColor.textSecondary).accessibilityIdentifier("globalSearchRetention.stale")
                }
                if !value.gatedKinds.isEmpty {
                    Label("searchMap.partialSignIn", systemImage: "lock").cyText(.meta)
                        .accessibilityIdentifier("searchMap.guestGate")
                    if let onSignIn { Button("searchMap.signIn", action: onSignIn).frame(minHeight: 44) }
                }
                if !value.failedKinds.isEmpty {
                    // Mini-program info banner: one line of copy with 重试本页 trailing, stacking vertically at >= .xxLarge.
                    Group {
                        if dynamicTypeSize >= .xxLarge {
                            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                                HStack(alignment: .top, spacing: CYSpacing.md) {
                                    Image(systemName: "info.circle").foregroundStyle(CYColor.textSecondary).accessibilityHidden(true)
                                    Text(LocalizedStringKey(value.allFailed ? "searchMap.allFailed" : "searchMap.partialFailure"))
                                        .cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Button("searchMap.retryPage") { Task { await search() } }
                                    .cyText(.label).buttonStyle(.borderless).frame(minHeight: 44)
                            }
                        } else {
                            HStack(spacing: CYSpacing.md) {
                                Image(systemName: "info.circle").foregroundStyle(CYColor.textSecondary).accessibilityHidden(true)
                                Text(LocalizedStringKey(value.allFailed ? "searchMap.allFailed" : "searchMap.partialFailure"))
                                    .cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: CYSpacing.sm)
                                Button("searchMap.retryPage") { Task { await search() } }
                                    .cyText(.label).buttonStyle(.borderless).frame(minHeight: 44)
                            }
                        }
                    }
                    .listRowBackground(CYColor.bgElevated)
                    .accessibilityIdentifier("searchMap.partialFailure")
                }
            }
        }
        let visible = value.rows.filter { !(hidesMerchants && $0.kind == .merchant) && (selectedKind == nil || $0.kind == selectedKind) }
        Section {
            // pages/search2/index readiness: a failed/gated player lane beside empty lanes is unknown, not "no results".
            if !loading, GlobalSearchEntryReadiness.phase(configured: reader.isConfigured, loading: loading, issueKey: nil,
                                                          results: value) == .unknown {
                Label("searchMap.unknownResults", systemImage: "questionmark.circle")
                    .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    .accessibilityIdentifier("searchMap.unknown")
            }
            if value.showsEmptyState(for: selectedKind, isLoading: loading) {
                CYEmptyState(systemImage: "magnifyingglass", "globalSearch.empty", messageIdentifier: "searchMap.empty", kind: .search)
            }
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, row in
                NavigationLink { destination(row.destination) } label: { SearchMapCard(row: row, offline: reader.isOfflineExample) }
                    .buttonStyle(QuestifyCardButtonStyle()).accessibilityIdentifier("searchMap.result.\(row.id)")
                    .questifyHidesLinkIndicator()
                    .cyStaggeredAppear(index: index, gate: stagger)
                    .questifyCardListRow()
            }
        }
        if selectedKind == nil, let templateResults, !templateResults.rows.isEmpty {
            Section {
                ForEach(templateResults.rows) { row in
                    NavigationLink { templateLanes?.destination(row) } label: { GlobalTemplateResultRow(row: row) }
                        .disabled(row.previewOnly)
                        .accessibilityIdentifier("searchMap.templateResult.\(row.id)")
                }
            } header: {
                Text("searchMap.templates").cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary).textCase(nil)
            }
        }
        if !loading { UnifiedSearchEntry(keyword: filter.keyword, destination: destination) }
        // Mini-program result footer: "内容已加载完" under results; "刷新搜索结果" also stays on an empty or failed page.
        if !loading {
            Section {
                VStack(spacing: CYSpacing.xs) {
                    if !visible.isEmpty {
                        Text("searchMap.endOfResults").cyText(.meta).foregroundStyle(CYColor.textTertiary)
                    }
                    Button("searchMap.refreshResults") { Task { await search() } }
                        .cyText(.label).buttonStyle(.borderless).frame(minHeight: 44)
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
    @ViewBuilder private func kindPill(_ kind: GlobalSearchKind?, title: Text) -> some View {
        let selected = selectedKind == kind
        let pill = Button { withAnimation(CYMotion.resolve(.snappy, reduceMotion: reduceMotion)) { selectedKind = kind } } label: {
            title.cyText(.bodyMedium).cyWrapText(alignment: .center).monospacedDigit()
                .foregroundStyle(selected ? CYColor.actionPrimaryFg : CYColor.textPrimary)
                .padding(.horizontal, CYSpacing.lg).frame(minHeight: 44)
                .searchNightPill(selected: selected)
        }
        .buttonStyle(.plain).cyHaptic(.selection, trigger: selectedKind)
        .accessibilityAddTraits(selected ? .isSelected : [])
        if let kind {
            pill.accessibilityIdentifier("searchMap.kind.\(kind.rawValue)")
        } else {
            pill
        }
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
        guard reader.isConfigured else { return }
        guard query.canSearch else {
            // MP: no keyword, category, date or narrowed price → toast('请输入关键词或选择类别').
            let narrowedPrice = (query.minimumPrice ?? 0) > 0 || (query.maximumPrice.map { $0 < 1000 } ?? false)
            if query.startDate == nil, query.endDate == nil, !narrowedPrice { emptySearchToast = "searchMap.emptySubmit" }
            return
        }
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

// MARK: - In-page host (continuity r1)

/// 首页 hosts search as a state of the page. The host owns one progress value (0 = the field sits on the 首页 field
/// the user tapped, 1 = search at rest) and animates it on `CYMotion.standard`; every piece below derives from it, so
/// the whole change reverses or retargets from wherever it is.
struct GlobalSearchInPageHost {
    /// Window frame of the tapped 首页 field. Nil (Reduce Motion, iOS 17, field scrolled away) = no travel, a cross-fade.
    var source: CGRect?
    var progress: CGFloat
    var onCancel: () -> Void
    /// The field reports its resting window frame once laid out; the host then starts the move.
    var onFieldPlaced: (CGRect) -> Void
}

private struct GlobalSearchInPageHostKey: EnvironmentKey { static let defaultValue: GlobalSearchInPageHost? = nil }

extension EnvironmentValues {
    var globalSearchInPageHost: GlobalSearchInPageHost? {
        get { self[GlobalSearchInPageHostKey.self] }
        set { self[GlobalSearchInPageHostKey.self] = newValue }
    }
}

extension View {
    /// Content that exists only in the search state (history, suggestions, results) fades in after half the move.
    @ViewBuilder func globalSearchInPage<Row: View>(_ host: GlobalSearchInPageHost?, @ViewBuilder row: (GlobalSearchInPageHost) -> Row) -> some View {
        if let host {
            modifier(GlobalSearchProgressFade(progress: host.progress, start: 0.5, end: 1))
                .safeAreaInset(edge: .top, spacing: 0) { row(host) }
                // The hosted root has no bar. Without these the layer's stack drew its large 搜索 title over 首页 on
                // the hand-over frame (integ-r3, iOS 27 sim); the title still names pushed results' back button.
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .navigationBar)
        } else {
            self
        }
    }

    /// Drops the inline field row when the host draws the field in its top row.
    @ViewBuilder fileprivate func globalSearchInlineField(hidden: Bool) -> some View {
        if hidden { EmptyView() } else { self }
    }
}

/// Opacity ramps 0 to 1 while `progress` runs from `start` to `end`; evaluated every frame.
struct GlobalSearchProgressFade: ViewModifier, Animatable {
    var progress: CGFloat
    let start: CGFloat
    let end: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    func body(content: Content) -> some View {
        let t = end > start ? (progress - start) / (end - start) : (progress >= end ? 1 : 0)
        content.opacity(Double(min(max(t, 0), 1)))
    }
}

/// The field's capsule travels between the two boxes: its top-leading corner and size interpolate from the 首页 field to
/// the top row (a background layer, so nothing reflows), and the icon and text ride along with a transform. The map
/// glyph that only the 首页 field has fades out in the first 30 %.
private struct GlobalSearchFieldMorph: ViewModifier, Animatable {
    var progress: CGFloat
    let source: CGRect?
    let onPlaced: (CGRect) -> Void
    @State private var rest: CGRect?
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    func body(content: Content) -> some View {
        let t = progress
        let moving = source != nil && rest != nil
        let s = source ?? .zero
        let r = rest ?? .zero
        let boxX = moving ? (s.minX - r.minX) * (1 - t) : 0
        let boxY = moving ? (s.minY - r.minY) * (1 - t) : 0
        let midY = moving ? (s.midY - r.midY) * (1 - t) : 0
        content
            .offset(x: boxX, y: midY)
            // Measured AFTER the travel offset: a modifier applied after `.offset` sees the field's layout frame, not
            // the moved one. Measured before it, the reading would include the offset that is derived from it, and
            // `rest` would flip between two frames on every update (integ-r3: an endless update loop, search stuck
            // invisible at progress 0 while its `.isModal` layer hid 首页 from VoiceOver).
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { place(proxy.frame(in: .global)) }
                        .onChange(of: proxy.frame(in: .global)) { _, frame in place(frame) }
                }
            }
            .background(alignment: .topLeading) {
                Capsule(style: .continuous).fill(CYColor.bgElevated)
                    .frame(width: moving ? max(r.width + (s.width - r.width) * (1 - t), 1) : nil,
                           height: moving ? max(r.height + (s.height - r.height) * (1 - t), 1) : nil)
                    .overlay(alignment: .trailing) {
                        if moving {
                            Image(systemName: "map")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(CYColor.textPrimary)
                                .frame(width: 52, height: 52)
                                .opacity(Double(min(max(1 - t / 0.3, 0), 1)))
                                .accessibilityHidden(true)
                        }
                    }
                    .offset(x: boxX, y: boxY)
            }
            .opacity(rest == nil ? 0 : 1)
    }
    private func place(_ frame: CGRect) {
        guard frame.width > 1, rest != frame else { return }
        // The first reading can come from a layout pass before the top inset is placed (seen on iOS 27: x −83,
        // y −22, 52 pt wide). Only a frame inside the window may start the move.
        if rest == nil, frame.minX < 0 || frame.minY < 0 { return }
        let first = rest == nil
        rest = frame
        if first { onPlaced(frame) }
    }
}

/// Text that changes size scales rather than cross-fading: the 14 pt 首页 placeholder grows into the field's body size.
private struct GlobalSearchTextSettle: ViewModifier, Animatable {
    var progress: CGFloat
    let moving: Bool
    let from: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    func body(content: Content) -> some View {
        let t = min(max(progress, 0), 1)
        content.scaleEffect(moving ? from + (1 - from) * t : 1, anchor: .leading)
    }
}

/// 取消 slides in from the trailing edge with the field and back out with it.
private struct GlobalSearchTrailingSlide: ViewModifier, Animatable {
    var progress: CGFloat
    /// False under Reduce Motion and the other no-travel cases: 取消 is simply there and fades with the layer.
    let moving: Bool
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    func body(content: Content) -> some View {
        let remaining = moving ? 1 - progress : 0
        content.visualEffect { view, proxy in
            view.offset(x: remaining * (proxy.size.width + CYSpacing.pageHorizontal))
        }
    }
}

private struct GlobalSearchBlur: ViewModifier {
    let radius: CGFloat
    func body(content: Content) -> some View { content.blur(radius: radius) }
}

extension AnyTransition {
    /// make-interfaces-feel-better §7: contextual icons enter from scale 0.25, opacity 0 and 4 pt blur.
    static var globalSearchContextualIcon: AnyTransition {
        .scale(scale: 0.25)
            .combined(with: .opacity)
            .combined(with: .modifier(active: GlobalSearchBlur(radius: 4), identity: GlobalSearchBlur(radius: 0)))
    }
}
