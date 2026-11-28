import SwiftUI

@MainActor struct GlobalSearchView<Destination: View>: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.themeDomain) private var themeDomain
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
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
    /// P-021 / P-026: the host's search model when the host draws the system search field (首页 searches in place).
    /// Nil: this page owns the model and draws the field itself.
    var searchSession: GlobalSearchSession? = nil
    let destination: (SearchMapDestination) -> Destination
    @State private var initialQueryApplied = false
    @State private var ownSearchSession = GlobalSearchSession()
    /// The one search model: the host's, or this page's own.
    private var searchModel: GlobalSearchSession { searchSession ?? ownSearchSession }
    private var hostsField: Bool { searchSession == nil }
    /// PC-A-4-1: 主题模板 / 玩法模板 results for the same keyword (nil = not searched or not available).
    @State private var templateResults: GlobalTemplateSearchResults?
    @Environment(\.globalTemplateSearch) private var templateLanes
    @State private var filter = GlobalSearchQuery()
    /// R7-PC-A3-2: MP search2 `navigateToSearchList` toast (pages/search2/index.js:130, 250).
    @State private var emptySearchToast: LocalizedStringKey?
    /// PC-A-3-3: empty Search submit. Nil hides the prompt.
    @State private var emptySearchNotice: LocalizedStringKey?
    /// R7-PC-A4-1: unified rows are inline, so the topic/activity lanes step aside (pages/search2/result/index.js:95-100).
    @State private var unifiedReplacesLanes = false
    @State private var categoryRecovery = SearchMapCategoryRecovery()
    @State private var categoryPresentationID = UUID()
    @State private var filterPresentationID = UUID()
    @State private var filterSheetVisible = false
    @State private var retainedResults = GlobalSearchRetainedResults()
    @State private var isVisible = false
    /// Search lifecycle (docs/release/state-machines/views.md); results live in `retainedResults`.
    @State private var phase: CYPhase<Void, String> = .idle
    private var issue: String? { phase.failure }
    private var loading: Bool { phase.isLoading }
    /// Guard: only an in-flight search falls back to idle; a failure stays visible.
    private func settleLoading() { if phase.isLoading { phase = .idle } }
    /// Result scope, from the system scope bar (`.searchScopes`).
    private var selectedKind: GlobalSearchKind? { searchModel.scope }
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
    /// Design fixtures (`d2-search`, `d2-search-results`) render the real page: the 示例内容 note is hidden there,
    /// while `isOfflineExample` still keeps every write offline (same rule as Square).
    private var showsOfflineExampleNote: Bool {
        reader.isOfflineExample && (reader as? any SearchMapOfflineNoteHiding)?.hidesOfflineExampleNote != true
    }
    /// Mini-program `pages/search2`: search field with 筛选, then 搜索历史, 推荐搜索 and 类别, then the map entry.
    /// Results replace the suggestions in place (the mini-program pushes `search2/result`).
    var body: some View {
        List {
            Section {
                // P-022: the keyword lives in the system search field (`.searchable`, drawn by `globalSearchField`);
                // 筛选 is the first row, as Mail and Files put their filter under the field.
                Button { openFilters() } label: {
                    Label("searchMap.filters", systemImage: "line.3.horizontal.decrease.circle")
                }
                .pageTemplateControl(label: Text("searchMap.filters"), traits: .isButton)
                .accessibilityIdentifier("searchMap.filters")
                // PC-A-3-3: an empty Search submit shows the prompt inline, as form validation does; no request starts.
                if let emptySearchNotice {
                    Label(emptySearchNotice, systemImage: "info.circle")
                        .font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier("searchMap.emptySearchNotice")
                }
                if historyFailure { Text("searchMap.historyUnavailable").font(.footnote).foregroundStyle(.secondary) }
                if showsOfflineExampleNote { Label("searchMap.offline", systemImage: "wifi.slash").font(.footnote).foregroundStyle(.secondary) }
            }
            // The primary action appears once a keyword or category can search. An empty Search key
            // shows the prompt and does not start a request. MP `search2/result` has no search button:
            // once this query's results (or its request) are on screen, the button steps away.
            if filter.canSearch && !loading && retainedResults.snapshot(in: resultContext) == nil {
                Section {
                    Button { submitSearch() } label: {
                        Text("searchMap.search").frame(maxWidth: .infinity)
                    }
                        .buttonStyle(.borderedProminent).controlSize(.large).disabled(!reader.isConfigured)
                        .accessibilityIdentifier("searchMap.submit")
                }
                .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
            }
            if !reader.isConfigured {
                Section { SearchMapIssue(key: "searchMap.notConfigured").questifyCardListRow() }
            } else {
                if loading {
                    Section {
                        // P10: say what is happening, not a bare spinner.
                        ProgressView("search.r3.loading.results")
                            .frame(maxWidth: .infinity)
                            .accessibilityIdentifier("searchMap.loading")
                    }
                }
                // mp-states r3 (MP search2/result wxml:23 cy-error): a failed search reads 没能完成搜索 with 重试.
                if let issue { Section { SearchMapIssue(key: issue == "searchMap.failed" ? "globalSearch.failed" : issue) { Task { await search() } }.questifyCardListRow() } }
                if let snapshot = retainedResults.snapshot(in: resultContext) {
                    results(snapshot.results, retainedKinds: snapshot.retainedKinds)
                } else if !loading && issue == nil { suggestions }
            }
            // MP order: `search-actions__map` (在地图上找) is the last block of search2; `search2/result` has no map entry.
            if showsSuggestions { mapSection }
        }
        .listStyle(.insetGrouped)
        .globalSearchPageChrome(hostsField ? ownSearchSession : nil)
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
        .cySheet(isPresented: $showsFilters) {
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
                initialQueryApplied = true; filter = initialQuery; searchModel.keyword = initialQuery.keyword
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
        .onAppear {
            isVisible = true; categoryPresentationID = UUID(); updateCategoryPresentation()
            searchModel.kinds = searchKinds
            searchModel.suggestionPool = history + recommendedKeywords
        }
        // The system field drives the query: typing, a completion, the Search key.
        .onChange(of: searchModel.keyword) { _, value in setKeyword(value) }
        .onChange(of: searchModel.submitCount) { _, _ in submitSearch() }
        .onChange(of: history) { _, value in searchModel.suggestionPool = value + recommendedKeywords }
        .onDisappear {
            isVisible = false; retainedResults.cancelPending(); settleLoading()
            categoryRecovery.update(reader: reader, presentationID: nil, active: false)
        }
        .onChange(of: filter.keyword) { _, _ in emptySearchNotice = nil }
    }
    private var categoryOwner: SearchMapCategoryRecovery.Owner { .init(reader: reader) }
    /// The search2 page itself (no results, not loading, no failure): suggestions instead of results.
    private var showsSuggestions: Bool {
        reader.isConfigured && !loading && issue == nil && retainedResults.snapshot(in: resultContext) == nil
    }
    private func showsRow(_ row: GlobalSearchRow) -> Bool {
        if hidesMerchants && row.kind == .merchant { return false }
        if let kind = selectedKind { return row.kind == kind }
        return !(unifiedReplacesLanes && (row.kind == .topic || row.kind == .activity))
    }
    /// MP merges unified rows only for a bare keyword: no category, date or price narrowing.
    private var unifiedKeywordOnly: Bool {
        filter.categoryID == nil && filter.startDate == nil && filter.endDate == nil
            && filter.minimumPrice == nil && filter.maximumPrice == nil
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
        // Mini-program 搜索历史: recent keywords as system rows with 清空 on the header line (App Store "Recent" pattern).
        // Additive to MP: a trailing swipe removes one keyword, so one wrong search never forces Clear all.
        if !history.isEmpty {
            Section {
                ForEach(history, id: \.self) { keyword in
                    Button { setKeyword(keyword); Task { await search() } } label: {
                        Label { Text(verbatim: keyword).foregroundStyle(.primary) } icon: { Image(systemName: "clock.arrow.circlepath") }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .accessibilityAction(named: Text("search.r3.history.remove.a11y \(keyword)")) { removeHistory(keyword) }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { removeHistory(keyword) } label: {
                            Label("search.r3.history.remove", systemImage: "trash")
                        }
                    }
                }
            } header: {
                HStack {
                    sectionTitle("search.r3.recent")
                    Spacer()
                    Button("search.r3.history.clearAll") { if historyStore.clear(namespace: historyNamespace) { history = [] }; historyFailure = historyStore.failed }
                        .textCase(nil).buttonStyle(.borderless)
                        .accessibilityIdentifier("searchMap.clearHistory")
                        .accessibilityLabel(Text("searchMap.clearHistory.a11y"))
                }
            }
        }
        if !recommendedKeywords.isEmpty {
            Section {
                // MP `hot-keys .li` chips: one wrapping row of capsules (a column at accessibility sizes).
                capsuleLayout {
                    ForEach(Array(recommendedKeywords.enumerated()), id: \.offset) { index, keyword in
                        Button { setKeyword(keyword); Task { await search() } } label: {
                            Text(verbatim: keyword)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .disabled(!reader.isConfigured)
                        .accessibilityIdentifier("searchMap.recommended.\(index)")
                    }
                }
                .padding(.vertical, 4)
            } header: { sectionTitle("searchMap.recommended") }
        }
        // 类别 hides once the directory is known to be empty; loading and failure still show.
        if categoryLoading || categoryFailed || !categories.isEmpty {
            Section {
                if categoryLoading {
                    ProgressView("search.r3.loading.categories").frame(maxWidth: .infinity).accessibilityIdentifier("globalSearch.category.loading")
                } else if categoryFailed {
                    SearchMapIssue(key: "searchMap.categoryFailed") {
                        guard !showsFilters, let context else { return }
                        _ = categoryRecovery.retry(in: context)
                    }
                    .questifyCardListRow()
                }
                if !categories.isEmpty {
                    // P18: category shortcuts as system capsules in one wrapping row (no cover art or scrim).
                    capsuleLayout {
                        ForEach(categories) { category in
                            Button {
                                guard !showsFilters, let context, categoryRecovery.accepts(context) else { return }
                                var next = filter; next.categoryID = category.id; applyFilter(next)
                            } label: {
                                // MP 类别 tiles carry an icon beside the name (utils/category-icon.js).
                                Label {
                                    Text(verbatim: category.name)
                                } icon: {
                                    Image(systemName: SearchCategorySymbol.name(for: category.name)).accessibilityHidden(true)
                                }
                                // 16:37 sweep: the capsule rendered as one tall narrow icon pill. Always icon + name on
                                // one line at its natural width (the flow wraps whole capsules, never the name).
                                .labelStyle(.titleAndIcon)
                                .lineLimit(1)
                                .fixedSize()
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            .accessibilityAddTraits(filter.categoryID == category.id ? .isSelected : [])
                            .accessibilityIdentifier("searchMap.category.\(category.id)")
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: { sectionTitle("searchMap.categories") }
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
            }
            .pageTemplateControl(label: Text("searchMap.citySearch"), traits: .isButton)
            .accessibilityIdentifier("searchMap.citySearch")
            moreWaysMenu(includesNearby: true)
        }
    }
    private func moreWaysMenu(includesNearby: Bool) -> some View {
        Menu {
            if includesNearby {
                Button { mapRoute = .nearby } label: { Label("searchMap.nearby", systemImage: "location") }
            }
            if publicLayers != nil {
                Button { mapRoute = .layers } label: { Label("searchMap.publicLayers", systemImage: "square.3.layers.3d") }
                    .accessibilityIdentifier("mapPublic.entry")
            }
            if !hidesMerchants {
                Button { mapRoute = .shops } label: { Label("merchant.discover.title", systemImage: "storefront") }
                    .accessibilityIdentifier("merchant.discover.entry")
            }
        } label: {
            Label {
                Text(LocalizedStringResource("searchMap.moreWays", defaultValue: "More ways to find"))
            } icon: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .pageTemplateControl(
            label: Text(LocalizedStringResource("searchMap.moreWays", defaultValue: "More ways to find")),
            traits: .isButton
        )
        .accessibilityIdentifier("searchMap.more")
    }
    /// Wrapping capsule row; a plain column at accessibility sizes so no capsule is clipped (P12).
    private var capsuleLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.sm))
            : AnyLayout(TemplateChipFlow(spacing: CYSpacing.sm))
    }
    private func removeHistory(_ keyword: String) {
        history = historyStore.remove(keyword, namespace: historyNamespace, current: history)
        historyFailure = historyStore.failed
    }
    private func sectionTitle(_ key: LocalizedStringKey) -> some View {
        Text(key).accessibilityAddTraits(.isHeader)
    }
    @ViewBuilder private func results(_ value: GlobalSearchResults, retainedKinds: [GlobalSearchKind]) -> some View {
        // Mini-program `pages/search2/result` tabs are the system scope bar (`.searchScopes` in `globalSearchField`);
        // counts reach it through the search model once a search settles. The system scope bar only shows while the
        // field is active, and the MP result tabs are always on the page, so the same scopes sit above the results as
        // filter chips whenever the field is not presented (one selection, `searchModel.scope`).
        if !searchModel.isPresented, searchModel.kinds.count > 1 {
            Section { resultScopeChips }
                .listRowInsets(EdgeInsets(top: 0, leading: CYSpacing.md, bottom: 0, trailing: CYSpacing.md))
                .listRowBackground(Color.clear)
        }
        if (loading && !value.rows.isEmpty) || !retainedKinds.isEmpty || !value.gatedKinds.isEmpty || !value.failedKinds.isEmpty {
            Section {
                if loading && !value.rows.isEmpty {
                    Text("globalSearchRetention.refreshing").font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier("globalSearchRetention.refreshing")
                }
                if !retainedKinds.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("globalSearchRetention.stale")
                        ForEach(retainedKinds, id: \.self) { kind in Label(kind.titleKey, systemImage: "clock.arrow.circlepath") }
                    }.font(.footnote).foregroundStyle(.secondary).accessibilityIdentifier("globalSearchRetention.stale")
                }
                if !value.gatedKinds.isEmpty {
                    Label("searchMap.partialSignIn", systemImage: "lock").font(.footnote)
                        .accessibilityIdentifier("searchMap.guestGate")
                    if let onSignIn { Button("searchMap.signIn", action: onSignIn) }
                }
                if !value.failedKinds.isEmpty {
                    // Mini-program info banner: one line of copy with 重试本页 trailing, stacking vertically at >= .xxLarge.
                    Group {
                        if dynamicTypeSize >= .xxLarge {
                            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                                HStack(alignment: .top, spacing: CYSpacing.md) {
                                    Image(systemName: "info.circle").foregroundStyle(.secondary).accessibilityHidden(true)
                                    Text(LocalizedStringKey(value.allFailed ? "searchMap.allFailed" : "searchMap.partialFailure"))
                                        .foregroundStyle(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Button("searchMap.retryPage") { Task { await search() } }
                                    .buttonStyle(.borderless)
                            }
                        } else {
                            HStack(spacing: CYSpacing.md) {
                                Image(systemName: "info.circle").foregroundStyle(.secondary).accessibilityHidden(true)
                                Text(LocalizedStringKey(value.allFailed ? "searchMap.allFailed" : "searchMap.partialFailure"))
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: CYSpacing.sm)
                                Button("searchMap.retryPage") { Task { await search() } }
                                    .buttonStyle(.borderless)
                            }
                        }
                    }
                    .accessibilityIdentifier("searchMap.partialFailure")
                }
            }
        }
        let visible = value.rows.filter(showsRow)
        Section {
            // pages/search2/index readiness: a failed/gated player lane beside empty lanes is unknown, not "no results".
            if !loading, GlobalSearchEntryReadiness.phase(configured: reader.isConfigured, loading: loading, issueKey: nil,
                                                          results: value) == .unknown {
                Label("searchMap.unknownResults", systemImage: "questionmark.circle")
                    .font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("searchMap.unknown")
            }
            if value.showsEmptyState(for: selectedKind, isLoading: loading) {
                ContentUnavailableView {
                    Label {
                        Text("globalSearch.empty").accessibilityIdentifier("searchMap.empty")
                    } icon: {
                        Image(systemName: "magnifyingglass")
                    }
                } description: {
                    EmptyView()
                } actions: {
                    // mp-states r3: the MP footer 刷新 sits inside the empty state (one action), not as a separate row.
                    Button("searchMap.refreshResults") { Task { await search() } }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("searchMap.refreshResults")
                }
            }
            ForEach(visible) { row in
                NavigationLink { destination(row.destination) } label: { SearchMapCard(row: row, offline: reader.isOfflineExample) }
                    .accessibilityIdentifier("searchMap.result.\(row.id)")
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
                Text("searchMap.templates")
            }
        }
        if !loading, selectedKind == nil {
            UnifiedSearchEntry(keyword: filter.keyword, keywordOnly: unifiedKeywordOnly,
                               onRows: { unifiedReplacesLanes = $0 }, destination: destination)
        }
        // Mini-program result footer: "内容已加载完" under results; "刷新搜索结果" also stays on an empty or failed page.
        if !loading, !value.showsEmptyState(for: selectedKind, isLoading: loading) {
            Section {
                VStack(spacing: CYSpacing.xs) {
                    if !visible.isEmpty {
                        Text("searchMap.endOfResults").font(.footnote).foregroundStyle(.tertiary)
                    }
                    Button("searchMap.refreshResults") { Task { await search() } }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("searchMap.refreshResults")
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    /// Player lanes read the page model (em dash when failed or gated); merchant keeps its own count.
    /// MP `search2/result` `cy-tabs variant="chip"`: 全部 then each kind with its settled count.
    private var resultScopeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CYSpacing.sm) {
                CYFilterChip("searchMap.all", isSelected: searchModel.scope == nil) { searchModel.scope = nil }
                ForEach(searchModel.kinds, id: \.self) { kind in
                    CYFilterChip(kind.titleKey, count: Int(searchModel.scopeCounts[kind] ?? ""),
                                 isSelected: searchModel.scope == kind) { searchModel.scope = kind }
                }
            }
        }
        // Next round (motion): switching the result scope ticks like a segmented control.
        .sensoryFeedback(.selection, trigger: searchModel.scope)
        .accessibilityIdentifier("searchMap.resultScopes")
    }
    private func countText(_ value: GlobalSearchResults, _ kind: GlobalSearchKind) -> String {
        GlobalSearchEntryReadiness.countText(value, kind: kind) ?? String(value.count(kind))
    }
    private func applyFilter(_ next: GlobalSearchQuery) {
        // Invalidate synchronously, including category-only searches cleared to an empty query.
        filter = next; invalidate(); Task { await search() }
    }
    private func setKeyword(_ value: String) {
        if !searchModel.keyword.utf8.elementsEqual(value.utf8) { searchModel.keyword = value }
        guard !filter.keyword.utf8.elementsEqual(value.utf8) else { return }
        invalidate(); filter.keyword = value
    }
    private func invalidate() {
        retainedResults.invalidate(); phase = .idle
        searchModel.scope = nil; searchModel.scopeCounts = [:]
    }
    private func prepare() async {
        guard !Task.isCancelled else { return }
        if preparedOwner != readOwner {
            preparedOwner = readOwner; invalidate()
            history = historyStore.read(namespace: historyNamespace); historyFailure = historyStore.failed
        }
        updateCategoryPresentation()
    }
    /// Keyboard Search and the search button. No keyword and no category is a prompt, not a request.
    private func submitSearch() {
        guard filter.canSearch else {
            emptySearchNotice = LocalizedStringKey("searchMap.needKeywordOrCategory")
            return
        }
        emptySearchNotice = nil
        Task { await search() }
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
            searchModel.scopeCounts = Dictionary(uniqueKeysWithValues: searchKinds.map { ($0, countText(value, $0)) })
            // VoiceOver: results replace the suggestions in place, so say how many arrived.
            let found = value.rows.filter(showsRow).count
            AccessibilityNotification.Announcement(found == 0
                ? appLocalized("globalSearch.empty", locale: locale)
                : appLocalized("globalSearch.resultsAnnounced \(found)", locale: locale)).post()
            history = historyStore.add(query.keyword, namespace: historyNamespace, current: history); historyFailure = historyStore.failed
        } catch {
            guard isVisible, retainedResults.accepts(ticket, in: resultContext) else { return }
            retainedResults.fail(ticket, in: resultContext)
            phase = error is CancellationError ? .idle : .failed(SearchMapIssue.key(error), retry: nil)
        }
    }
}

private let globalSearchRecentRoutesKey = "globalSearch.recentRoutes.v1"

// MARK: - Page chrome (P-022)

extension View {
    /// A page that owns its search model draws the system field and its own inline title; a hosted page (首页) leaves
    /// the field, title and tab bar to the host.
    @MainActor @ViewBuilder fileprivate func globalSearchPageChrome(_ ownSession: GlobalSearchSession?) -> some View {
        if let ownSession {
            globalSearchField(ownSession)
                .appNavigationTitle("searchMap.title").navigationBarTitleDisplayMode(.inline)
                .cyHideTabBar()
        } else {
            self
        }
    }
}

/// mp-home r3 (00:10 sweep d2-search / d2-search-results): demo wording must not appear in a rendered fixture.
@MainActor protocol SearchMapOfflineNoteHiding { var hidesOfflineExampleNote: Bool { get } }
