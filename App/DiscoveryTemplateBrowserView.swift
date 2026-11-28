import SwiftUI

/// Embed in the root's NavigationStack or present through DiscoveryHomeView.
@MainActor
struct DiscoveryTemplateBrowserView: View {
    /// R9-PC-A-N1: the MP bell icon follows Dynamic Type.
    let reader: any DiscoveryReading
    let authoringFactory: ((DiscoveryPlayTemplate) -> TemplateAuthoringCoordinator)?
    let authoringRevision: UInt64
    let authoringCompletion: TemplateAuthoringCompletionContext?
    let imageReader: (any RetainedPublicImageReading)?
    /// Mini-program merchant scope; staff without project management only browse.
    let templateTabScope: TemplateTabScope
    /// True when merchant access failed to load (show retry banner rather than asserting readonly).
    let merchantAccessError: Bool
    let onRetryMerchantAccess: (() -> Void)?
    /// Mini-program template tab: the "+" opens the publish menu. Hidden for staff who only browse.
    let publishDestination: (() -> AnyView)?
    /// Round 4 (MP template/index.wxml:16 `tpl-bell` → `subpackageB/pages/im/list/index`): the bell opens the IM inbox.
    let inboxDestination: (() -> AnyView)?
    /// mp-r3-publish: the shelf is the 发布 tab itself (MP `pages/template/index` is a tab page), so it takes the
    /// large root title instead of the pushed inline 模板 title.
    let isTabRoot: Bool
    @State private var tab = Shelf.topics
    @State private var topicTag: String?
    @State private var gameTag: String?
    @State private var showsAllTags = false
    @StateObject private var topics = PublicTemplateCatalogVisitOwner()
    @State private var topicSelection: PublicTemplateCatalogSelection?
    @StateObject private var shelfGames = DiscoveryLoader<[DiscoveryPlayTemplate]>()
    @State private var toastMessage: String?
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private enum Shelf: String, CaseIterable { case topics, games }

    /// MP shelf/index.js `shelfNoun` (1121 N6): players see 主题 / 玩法; the merchant creator view keeps 主题模板 / 玩法模板.
    private var isPlayerShelf: Bool { templateTabScope == .consumer }
    private var emptyTopicsKey: LocalizedStringKey { isPlayerShelf ? "discovery.player.emptyTopics" : "discovery.emptyTopics" }
    private var emptyGamesKey: LocalizedStringKey { isPlayerShelf ? "discovery.player.emptyGames" : "discovery.emptyGames" }
    private var topicsFailedKey: LocalizedStringKey { isPlayerShelf ? "discovery.player.topicsFailed" : "discovery.topicsFailed" }
    private var gamesFailedKey: LocalizedStringKey { isPlayerShelf ? "discovery.player.gamesFailed" : "discovery.gamesFailed" }

    /// `searchDestination` stays so existing callers still compile. MP `goSearch` has one entrance, so this shelf
    /// does not open that closure as a second screen.
    init(reader: any DiscoveryReading, authoringFactory: ((DiscoveryPlayTemplate) -> TemplateAuthoringCoordinator)? = nil, authoringRevision: UInt64 = 0, imageReader: (any RetainedPublicImageReading)? = nil, authoringCompletion: TemplateAuthoringCompletionContext? = nil, templateTabScope: TemplateTabScope = .consumer, merchantAccessError: Bool = false, onRetryMerchantAccess: (() -> Void)? = nil, publishDestination: (() -> AnyView)? = nil, startOnGames: Bool = false, searchDestination _: (() -> AnyView)? = nil, inboxDestination: (() -> AnyView)? = nil, isTabRoot: Bool = false) {
        self.isTabRoot = isTabRoot
        _tab = State(initialValue: startOnGames ? .games : .topics)
        self.inboxDestination = inboxDestination
        self.publishDestination = publishDestination
        self.reader = reader; self.authoringFactory = authoringFactory; self.authoringRevision = authoringRevision
        self.imageReader = imageReader; self.authoringCompletion = authoringCompletion
        self.templateTabScope = templateTabScope
        self.merchantAccessError = merchantAccessError
        self.onRetryMerchantAccess = onRetryMerchantAccess
    }

    var body: some View {
        Group {
            if !reader.isConfigured {
                ContentUnavailableView {
                    Label("discovery.unavailable", systemImage: "network.slash")
                        .accessibilityIdentifier("discovery.unavailable")
                } description: {
                    Text("auth.notConfigured")
                }
            } else {
                // mp-r3-publish: MP template/index.wxml order — merchant access note, then tpl-shelf (主题/玩法 tabs
                // and search, featured rail, tags, shelves). The shelf has no presets block, so none is shown here.
                List {
                    if merchantAccessError || (templateTabScope == .merchant(canManageProjects: nil) && onRetryMerchantAccess != nil) {
                        Section {
                            if let onRetryMerchantAccess {
                                Button(action: onRetryMerchantAccess) {
                                    Label {
                                        Text("discovery.templateTab.accessRetry")
                                    } icon: {
                                        Image(systemName: "arrow.clockwise").foregroundStyle(.orange)
                                    }
                                }
                                .accessibilityIdentifier("discovery.templateTab.retryAccess")
                            } else {
                                Label {
                                    Text("discovery.templateTab.accessRetry")
                                } icon: {
                                    Image(systemName: "exclamationmark.triangle").foregroundStyle(CYColor.warningText)
                                }
                                .accessibilityIdentifier("discovery.templateTab.retryAccess")
                            }
                        }
                    } else if templateTabScope == .merchant(canManageProjects: false) {
                        Section {
                            Label {
                                Text("discovery.templateTab.staffReadOnly")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .accessibilityIdentifier("discovery.templateTab.staffReadOnly")
                            } icon: {
                                Image(systemName: "lock.fill").foregroundStyle(.orange).accessibilityHidden(true)
                            }
                            .accessibilityAddTraits(.isStaticText)
                        }
                        .pageTemplateReadingOrder(40)
                    }
                    Section {
                        // MP shelf `sh-top`: the 主题 / 玩法 tabs first, the search pill after them.
                        Picker("discovery.shelf", selection: $tab) {
                            Text("discovery.topics").tag(Shelf.topics)
                            Text("discovery.games").tag(Shelf.games)
                        }.cyAdaptiveSegmented().accessibilityIdentifier("discovery.shelf")
                            .pageTemplateReadingOrder(30)
                        // MP pages/template/index.js goSearch → /pages/search2/index. One entrance, both shelves.
                        NavigationLink { templateShelfSearch.cyPushedChrome() } label: {
                            Label {
                                if isPlayerShelf { Text("discovery.player.searchAll") } else { Text("discovery.searchAll") }
                            } icon: {
                                Image(systemName: "magnifyingglass")
                            }
                        }
                        .accessibilityIdentifier("discovery.globalSearch")
                        .pageTemplateReadingOrder(35)
                    }
                    if tab == .topics { topicShelf }
                    else { gameShelf }
                }
                .listStyle(.insetGrouped)
                .refreshable { await reloadCurrent() }
            }
        }
        // K40 (P1-26 / H-10): a session shelf, including one hosted in a sheet, pushes the copied draft into the editor.
        .modifier(SessionShelfTopicEditor(reader: reader))
        // PC-A-2-3: pushed / sheet-hosted page, inline title; the 发布 tab root takes the large root title.
        .modifier(DiscoveryTemplateShelfTitle(isTabRoot: isTabRoot))
        .cyToast(verbatimMessage: $toastMessage)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // R7-PC-A2-8 MP-first: pages/template/index.wxml:39 shows the 发布 + only when
                // `isMerchant && canManageMerchantProjects`; players never see it.
                if let publishDestination, templateTabScope == .merchant(canManageProjects: true) {
                    NavigationLink { publishDestination().cyPushedChrome() } label: {
                        Label("discovery.templateTab.publish", systemImage: "plus")
                    }.pageTemplateControl(label: Text("discovery.templateTab.publish"), traits: .isButton)
                        .accessibilityIdentifier("discovery.templateTab.publish")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if let inboxDestination {
                    NavigationLink { inboxDestination().cyPushedChrome() } label: {
                        Label("discovery.templateTab.inbox", systemImage: "bell")
                    }
                    .accessibilityLabel(Text("discovery.templateTab.inbox"))
                    .accessibilityIdentifier("discovery.templateTab.inbox")
                }
            }
        }
        .task(id: tab) {
            guard reader.isConfigured, tab == .games, shelfGames.value == nil else { return }
            await loadShelfGames()
        }
        .cySheet(isPresented: $showsAllTags) { Group {
            DiscoveryShelfCategorySheet(groups: allTagGroups, selected: tab == .topics ? topicTag : gameTag) { key in
                if tab == .topics { topicTag = key } else { gameTag = key }
                showsAllTags = false
            }
        }.cySheet(detents: [.large]) }
        .onAppear {
            if let visit = topics.appear(reader: reader), tab == .topics, topicSelection == nil {
                Task { await topics.load(reader: reader, visit: visit) }
            }
        }
        .onDisappear { topics.disappear() }
        .onChange(of: tab) { _, next in
            if next == .topics { scheduleTopicReload() }
            else { topics.cancelPending() }
        }
        .onReceive(reader.discoveryPresentationChanges) { _ in
            // AppSession publishes before mutating its identity.
            Task { @MainActor in
                await Task.yield()
                if topics.synchronize(reader: reader) {
                    topicSelection = nil
                    if tab == .topics { scheduleTopicReload() }
                }
            }
        }
        .navigationDestination(isPresented: topicDetailBinding) {
            if let selected = topicSelection,
               selected.identity == reader.discoveryPresentationIdentity {
                // R7-PC-A7-1, MP shelf/index.js:421-430: a topic row opens topic-preview (the deck); 查看详情 pushes the detail.
                DiscoveryTopicTemplateDeckHost(coordinator: selected.coordinator, readonly: false,
                                               makeDetail: { reader.publicTopicTemplateCoordinator(id: selected.templateID) }).id(selected.id)
            } else { Text("social.changed") }
        }
    }

    private var topicDetailBinding: Binding<Bool> {
        let selectedID = topicSelection?.id
        return Binding(get: { topicSelection != nil }, set: { presented in
            guard !presented, let selectedID, topicSelection?.id == selectedID else { return }
            topicSelection = nil
            topics.uncover()
            // A retained parent may not receive another onAppear.
            if tab == .topics { scheduleTopicReload() }
        })
    }
    private func scheduleTopicReload() {
        let visit = topics.visit
        Task { await topics.load(reader: reader, visit: visit) }
    }

    /// Session readers attach the template lanes `GlobalSearchView` already reads. Anyone else still gets that page,
    /// with an unconfigured session so opening it does not post.
    @ViewBuilder private var templateShelfSearch: some View {
        if let session = reader as? AppSession {
            SessionGlobalSearchView()
                .environmentObject(session)
                .environment(\.globalTemplateSearch, .session(session))
        } else {
            TemplateShelfSearchWithoutSession()
        }
    }

    /// A plain list button for shelf filter actions (全部分类, 清除筛选).
    private func filterChip(_ title: Text, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            title
        }
        .pageTemplateControl(label: title, traits: selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityValue(title)
        .accessibilityHint(title)
    }

    /// MP shelf/index.wxml topic block: skeleton / error / empty replace the whole shelf; otherwise the 精选 rail,
    /// then the tag row, then what the tag picks (标签只换标签下方内容 — the rail stays when a tag is chosen).
    @ViewBuilder private var topicShelf: some View {
        if let error = topics.error {
            Section { shelfIssue(error, failedTitle: topicsFailedKey) { Task { await loadTopics() } } }
        }
        if topics.isLoading {
            Section { DiscoveryTemplateSyncingRow(hasLoadedRows: topics.value != nil) }
        }
        if let rows = topics.value {
            let catalog = SearchDiscoveryFilterParity.visibleTopics(rows)
            if catalog.isEmpty {
                Section { emptyTopics }
            } else {
                let tags = SearchDiscoveryFilterParity.topicTags(in: catalog, selected: topicTag)
                let shown = SearchDiscoveryFilterParity.topics(catalog, matching: tags.selection)
                // R7-PC-A2-3 topic half (MP shelf/index.js:309 `buildTopics`): 精选 rail in FEATURED_TOPICS order.
                let featured = TemplateShelfArt.featuredTopics(catalog)
                if !featured.isEmpty { featuredTopicRail(featured) }
                Section {
                    shelfChipRow(SearchDiscoveryFilterParity.topicTags(in: rows, selected: topicTag), field: "shelf.topic") { topicTag = $0 }
                }
                .pageTemplateReadingOrder(20)
                if shown.isEmpty {
                    Section { ContentUnavailableView("discovery.noResults", systemImage: "magnifyingglass") }
                } else if let selection = tags.selection, let tag = tags.row.first(where: { $0.key == selection }) ?? tags.groups.flatMap(\.tags).first(where: { $0.key == selection }) {
                    topicSection("discovery.topics", rows: shown, hero: true, verbatimTitle: locale.pick(tag.zh, tag.en))
                } else {
                    // Then 全部主题, then the TOPIC_SHELVES rows that have content.
                    topicSection("discovery.shelf.allTopics", rows: shown)
                    topicSection("discovery.shelf.withinTwoHours", rows: shown.filter { ($0.totalTime ?? 0) > 0 && ($0.totalTime ?? 0) <= 7200 }, shelfKey: "shelf2h")
                    topicSection("discovery.shelf.scifi", rows: SearchDiscoveryFilterParity.topics(shown, matching: "scifi"), shelfKey: "shelfScifi")
                    topicSection("discovery.shelf.cityMemory", rows: SearchDiscoveryFilterParity.topics(shown, matching: "nostalgia"), shelfKey: "shelfMemory")
                    topicSection("discovery.shelf.solo", rows: SearchDiscoveryFilterParity.topics(shown, matching: "solo"), shelfKey: "shelfSolo")
                }
            }
        }
    }

    private var emptyTopics: some View {
        ContentUnavailableView {
            Label(emptyTopicsKey, systemImage: "map")
        } description: {
            EmptyView()
        } actions: {
            DiscoveryTemplateEmptyRefresh { Task { await loadTopics() } }
        }
    }

    /// Every tag group of the current shelf, for the 全部分类 sheet (same source as the filter menu).
    private var allTagGroups: [DiscoveryShelfTagGroup] {
        tab == .topics
            ? SearchDiscoveryFilterParity.topicTags(in: topics.value ?? [], selected: topicTag).groups
            : SearchDiscoveryFilterParity.gameTags(in: shelfGames.value ?? [], selected: gameTag).groups
    }

    /// MP shelf/index.wxml game block: skeleton / error / empty, else the FEATURED_GAMES rail, the tag row, then
    /// one shelf per GROUPS entry (or the picked tag's games). All of it comes from the paged `api/template/list`.
    @ViewBuilder private var gameShelf: some View {
        if let error = shelfGames.error, shelfGames.value == nil {
            Section { shelfIssue(error, failedTitle: gamesFailedKey) { Task { await loadShelfGames() } } }
        } else if let rows = shelfGames.value {
            let shelf = SearchDiscoveryFilterParity.shelfGames(rows)
            if shelf.isEmpty {
                Section { emptyGames }
            } else {
                // R7-PC-A2-3 / A2-6 (MP shelf/index.js:340 `buildGames`).
                let featured = TemplateShelfArt.featuredGameTitles.compactMap { title in
                    shelf.first { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) == title }
                }
                if !featured.isEmpty { featuredGameRail(featured) }
                Section {
                    shelfChipRow(SearchDiscoveryFilterParity.gameTags(in: rows, selected: gameTag), field: "shelf.game") { gameTag = $0 }
                    if gameTag != nil {
                        Button("discovery.clearFilters") {
                            gameTag = nil
                        }
                        .accessibilityLabel(Text("discovery.clearFilters"))
                        .accessibilityValue(Text(verbatim: clearFilterSpoken))
                        .accessibilityHint(Text("discovery.clearFilters"))
                    }
                }
                .pageTemplateReadingOrder(20)
                if let selection = SearchDiscoveryFilterParity.gameTags(in: rows, selected: gameTag).selection {
                    let shown = SearchDiscoveryFilterParity.games(rows, matching: selection)
                    if shown.isEmpty { Section { ContentUnavailableView("discovery.noResults", systemImage: "magnifyingglass") } }
                    else if let tag = shelfTag(SearchDiscoveryFilterParity.gameTags(in: rows, selected: selection), key: selection) {
                        gameSection("discovery.searchResults", rows: shown, verbatimTitle: locale.pick(tag.zh, tag.en))
                    } else { gameSection("discovery.searchResults", rows: shown) }
                } else {
                    gameSection("discovery.shelf.group.shop", rows: SearchDiscoveryFilterParity.games(rows, matching: "shop"))
                    gameSection("discovery.shelf.group.team", rows: SearchDiscoveryFilterParity.games(rows, matching: "team"))
                    gameSection("discovery.shelf.group.city", rows: SearchDiscoveryFilterParity.games(rows, matching: "city"))
                }
            }
        } else {
            Section { loadingRow }
        }
    }

    private var emptyGames: some View {
        ContentUnavailableView {
            Label(emptyGamesKey, systemImage: "sparkles.rectangle.stack")
        } description: {
            EmptyView()
        } actions: {
            DiscoveryTemplateEmptyRefresh { Task { await loadShelfGames() } }
        }
    }

    private var loadingRow: some View {
        ProgressView { Text("discovery.loading") }
            .frame(maxWidth: .infinity)
    }

    /// R7-PC-A2-4: MP `openTopic` — a preview-only row says 暂未开放 instead of opening.
    private func openTopic(_ item: DiscoveryTopicTemplate) {
        if item.previewOnly {
            toastMessage = appLocalized("searchMap.template.previewOnly", locale: locale)
            return
        }
        guard topicSelection == nil, topics.canOpen(reader: reader),
              topics.value?.contains(where: { $0.id == item.id }) == true else { return }
        topicSelection = .init(identity: reader.discoveryPresentationIdentity,
            coordinator: reader.publicTopicTemplateCoordinator(id: item.id), templateID: item.id)
        topics.cover()
    }
    /// MP `featTopics` swiper (shelf/index.wxml:21-36): bundled covers in a system page view with page dots.
    @ViewBuilder private func featuredTopicRail(_ rows: [DiscoveryTopicTemplate]) -> some View {
        Section {
            TabView {
                ForEach(rows, id: \.id) { item in
                    Button { openTopic(item) } label: {
                        DiscoveryShelfFeatureTile(art: TemplateShelfArt.topicCover(item.name), imageSource: item.imgUrl,
                                                  title: item.name.isEmpty ? Text("discovery.untitledTopic") : Text(verbatim: item.name),
                                                  meta: item.subtitle)
                    }
                    .buttonStyle(.plain)
                    .allowsHitTesting(topics.canOpen(reader: reader))
                    .padding(.bottom, 28)
                    .pageTemplateGroupedCard(label: topicCardLabel(item), traits: .isButton)
                    .accessibilityIdentifier("discovery.topic.featured.\(item.id)")
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))
            // a11y-dt r3: taller pages at accessibility sizes so the two-line title and meta are not cut off.
            .aspectRatio(dynamicTypeSize.isAccessibilitySize ? 2.0 / 3.0 : 16.0 / 13.0, contentMode: .fit)
            .accessibilityIdentifier("discovery.featuredTopics")
        } header: {
            Text("discovery.featured")
        }
    }
    /// `shelfKey` names a secondary shelf: its rows get `discovery.topic.<shelfKey>.<id>` so the main row id stays unique.
    @ViewBuilder private func topicSection(_ title: LocalizedStringKey, rows: [DiscoveryTopicTemplate], hint: LocalizedStringKey? = nil, hero: Bool = false, verbatimTitle: String? = nil, shelfKey: String? = nil) -> some View {
        if !rows.isEmpty {
            Section {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, item in
                    Button {
                        openTopic(item)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            // MP asset (shelf/art.js THEMES): a known topic name always shows its bundled cover.
                            if hero && index == 0 {
                                DiscoveryShelfHeaderImage(art: TemplateShelfArt.topicCover(item.name), imageSource: item.imgUrl)
                            }
                            HStack(alignment: .top, spacing: 12) {
                                if !(hero && index == 0) {
                                    if let art = TemplateShelfArt.topicCover(item.name) { TemplateShelfArtThumb(art: art) }
                                    else { DiscoveryTopicCoverThumb(urlString: item.imgUrl, seed: item.name) }
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    DiscoveryTitle(text: item.name, fallback: "discovery.untitledTopic").font(.body)
                                        .foregroundStyle(.primary)
                                    if !item.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Text(item.subtitle).font(.subheadline).foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    DiscoveryTopicMetadata(item: item)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .allowsHitTesting(topics.canOpen(reader: reader))
                    .pageTemplateGroupedCard(label: topicCardLabel(item), traits: .isButton)
                    .accessibilityIdentifier(shelfKey.map { "discovery.topic.\($0).\(item.id)" } ?? "discovery.topic.\(item.id)")
                }
            } header: {
                if let shownTitle = verbatimTitle { Text(verbatim: shownTitle) } else { Text(title) }
            } footer: {
                if let hint { Text(hint) }
            }
        }
    }
    /// MP `featGames` swiper (shelf/index.wxml:49-78): one bundled cover per page in a system page view, with page dots.
    @ViewBuilder private func featuredGameRail(_ rows: [DiscoveryPlayTemplate]) -> some View {
        Section {
            TabView {
                ForEach(rows, id: \.id) { item in
                    NavigationLink {
                        DiscoveryTemplateDetailView(id: item.id, reader: reader, authoringFactory: TemplateTabPolicy.refusal(for: .configure, previewOnly: false, scope: templateTabScope) == nil ? authoringFactory : nil, authoringRevision: authoringRevision, imageReader: imageReader, authoringCompletion: authoringCompletion)
                    } label: {
                        DiscoveryShelfFeatureTile(art: TemplateShelfArt.gameCover(item.title), imageSource: item.imgUrl,
                                                  title: item.title.isEmpty ? Text("discovery.untitledPlay") : Text(verbatim: item.title),
                                                  meta: item.description)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 28)
                    .pageTemplateGroupedCard(label: gameCardLabel(item), traits: .isButton)
                    .accessibilityIdentifier("discovery.play.featured.\(item.id)")
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))
            .aspectRatio(16.0 / 13.0, contentMode: .fit)
            .accessibilityIdentifier("discovery.featuredGames")
        } header: {
            Text("discovery.featured")
        }
    }
    @ViewBuilder private func gameSection(_ title: LocalizedStringKey, rows: [DiscoveryPlayTemplate], hero: Bool = false, verbatimTitle: String? = nil) -> some View {
        if !rows.isEmpty {
            Section {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, item in
                    NavigationLink {
                        DiscoveryTemplateDetailView(id: item.id, reader: reader, authoringFactory: TemplateTabPolicy.refusal(for: .configure, previewOnly: false, scope: templateTabScope) == nil ? authoringFactory : nil, authoringRevision: authoringRevision, imageReader: imageReader, authoringCompletion: authoringCompletion)
                    } label: {
                        // MP asset (shelf/game-covers.js GAMES): a known play title always shows its bundled cover.
                        if hero && index == 0 {
                            VStack(alignment: .leading, spacing: 8) {
                                DiscoveryShelfHeaderImage(art: TemplateShelfArt.gameCover(item.title), imageSource: item.imgUrl)
                                DiscoveryPlayRow(item: item)
                            }
                        } else if let art = TemplateShelfArt.gameCover(item.title) {
                            HStack(alignment: .top, spacing: 12) {
                                TemplateShelfArtThumb(art: art)
                                DiscoveryPlayRow(item: item)
                            }
                        } else {
                            DiscoveryPlayRow(item: item)
                        }
                    }
                    .pageTemplateGroupedCard(label: gameCardLabel(item), traits: .isButton)
                    .accessibilityIdentifier("discovery.play.\(item.id)")
                }
            } header: {
                if let shownTitle = verbatimTitle { Text(verbatim: shownTitle) } else { Text(title) }
            }
        }
    }
    /// R7-PC-A2-5: the generic failure names the shelf (MP `主题模板加载失败` / `玩法模板加载失败`).
    private func shelfIssue(_ error: Error, failedTitle: LocalizedStringKey = "discovery.loadFailed", retry: @escaping () -> Void) -> some View {
        let reason = error as? DiscoveryTemplateUnavailable
        let unauthorized = (error as? APIError) == .unauthorized
        let offline = reason == .offline || (error as? URLError)?.code == .notConnectedToInternet
        let title: LocalizedStringKey
        let detail: LocalizedStringKey?
        if unauthorized {
            title = "discovery.signInRequired"
            detail = "discovery.signInHint"
        } else if reason == .notFound || reason == .deleted {
            title = "discovery.templateMissing"
            detail = "discovery.templateMissingHint"
        } else if reason == .underReview {
            title = "discovery.templateReview"
            detail = "discovery.templateReviewHint"
        } else if reason == .offline {
            title = "discovery.templateOffline"
            detail = "discovery.templateOfflineHint"
        } else {
            title = failedTitle
            detail = nil
        }
        let canRetry = !unauthorized && (reason?.retryable ?? true)
        return ContentUnavailableView {
            Label(title, systemImage: offline ? "wifi.slash" : "exclamationmark.triangle")
        } description: {
            if let detail { Text(detail) }
        } actions: {
            if canRetry {
                Button("action.retry", action: retry)
                    .accessibilityIdentifier("discovery.retry")
            }
        }
    }

    private func topicCardLabel(_ item: DiscoveryTopicTemplate) -> Text {
        let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = name.isEmpty ? Text("discovery.untitledTopic") : Text(verbatim: name)
        let subtitle = item.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if subtitle.isEmpty { return title }
        return title + Text(verbatim: ", ") + Text(verbatim: subtitle)
    }

    private func gameCardLabel(_ item: DiscoveryPlayTemplate) -> Text {
        let name = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = name.isEmpty ? Text("discovery.untitledPlay") : Text(verbatim: name)
        let detail = item.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if detail.isEmpty { return title }
        return title + Text(verbatim: ", ") + Text(verbatim: detail)
    }

    private func loadTopics() async {
        await topics.load(reader: reader, visit: topics.visit)
    }
    /// A chosen category chip is spoken by its shelf name. No chosen tag is unknown.
    private var clearFilterSpoken: String {
        guard let gameTag else { return "—" }
        let tags = SearchDiscoveryFilterParity.gameTags(in: shelfGames.value ?? [], selected: gameTag)
        if let tag = shelfTag(tags, key: gameTag) { return locale.pick(tag.zh, tag.en) }
        return "—"
    }

    private func shelfTag(_ tags: DiscoveryShelfTagSet, key: String) -> DiscoveryShelfTag? {
        tags.row.first { $0.key == key } ?? tags.groups.flatMap(\.tags).first { $0.key == key }
    }

    /// Shelf category filter as a system menu (current choice shown on the trailing side), plus the 全部分类 sheet.
    @ViewBuilder private func shelfChipRow(_ tags: DiscoveryShelfTagSet, field: String, select: @escaping (String?) -> Void) -> some View {
        let all = locale.pick("全部", "All")
        let current = tags.selection.flatMap { key in shelfTag(tags, key: key).map { locale.pick($0.zh, $0.en) } } ?? all
        Menu {
            Button { select(nil) } label: {
                if tags.selection == nil { Label(all, systemImage: "checkmark") } else { Text(verbatim: all) }
            }
            .accessibilityIdentifier("\(field).all")
            ForEach(tags.row) { tag in
                let name = locale.pick(tag.zh, tag.en)
                Button { select(tag.key) } label: {
                    if tags.selection == tag.key { Label(name, systemImage: "checkmark") } else { Text(verbatim: name) }
                }
                .accessibilityIdentifier("\(field).\(tag.key)")
            }
        } label: {
            LabeledContent {
                Text(verbatim: current)
            } label: {
                Label(locale.pick("分类", "Category"), systemImage: "line.3.horizontal.decrease.circle")
            }
        }
        .accessibilityIdentifier(field)
        filterChip(Text(verbatim: locale.pick("全部分类", "All categories")), selected: false) { showsAllTags = true }
            .accessibilityIdentifier("\(field).allCategories")
    }

    private func loadShelfGames() async {
        await shelfGames.load { try await reader.discoveryPlayTemplates(keyword: "", packType: .single) }
    }
    private func reloadCurrent() async {
        if tab == .topics { await loadTopics() } else { await loadShelfGames() }
    }
}

/// Session shelves adopt a topic template into the professional editor. Fixture readers are not sessions, so they stay as they are.
@MainActor private struct SessionShelfTopicEditor: ViewModifier {
    let reader: any DiscoveryReading
    func body(content: Content) -> some View {
        if let session = reader as? AppSession {
            content.environment(\.topicEditorDestination, PublishTabRootView.topicEditorDestination(session: session))
        } else {
            content
        }
    }
}

/// Inline 模板 title when pushed or sheet-hosted; the large 发布 root title when the shelf is the tab root.
private struct DiscoveryTemplateShelfTitle: ViewModifier {
    let isTabRoot: Bool
    func body(content: Content) -> some View {
        if isTabRoot {
            content.cyRootHeader(.publish)
        } else {
            content.cyPageTitle("discovery.templateTab.title")
        }
    }
}

/// Fixtures have no session reader. The same search page still opens, and an unconfigured session does not post.
@MainActor private struct TemplateShelfSearchWithoutSession: View {
    @StateObject private var session = AppSession(composition: AppCompositionRoot(deployment: .unconfigured))
    var body: some View {
        SessionGlobalSearchView().environmentObject(session)
    }
}

/// `全部分类` sheet from the template shelf. Tags with no matches are already omitted.
@MainActor private struct DiscoveryShelfCategorySheet: View {
    let groups: [DiscoveryShelfTagGroup]
    let selected: String?
    let choose: (String?) -> Void
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row(locale.pick("全部", "All"), isSelected: selected == nil, hint: locale.pick("全部分类", "All categories")) { choose(nil) }
                        .accessibilityIdentifier("discovery.allCategories.all")
                }
                ForEach(groups) { group in
                    Section {
                        ForEach(group.tags) { tag in
                            row(locale.pick(tag.zh, tag.en), isSelected: selected == tag.key, hint: locale.pick(group.zh, group.en)) { choose(tag.key) }
                                .accessibilityIdentifier("discovery.allCategories.\(tag.key)")
                        }
                    } header: {
                        Text(verbatim: locale.pick(group.zh, group.en))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text(verbatim: locale.pick("全部分类", "All categories")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Label("action.close", systemImage: "xmark")
                    }
                    .accessibilityIdentifier("discovery.allCategories.close")
                    .accessibilityLabel(Text("action.close"))
                    .accessibilityValue(Text(verbatim: locale.pick("全部分类", "All categories")))
                    .accessibilityHint(Text(verbatim: locale.pick("全部分类", "All categories")))
                }
            }
        }
    }

    /// Settings-style choice row: the chosen value carries a tinted checkmark.
    private func row(_ title: String, isSelected: Bool, hint: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(verbatim: title).foregroundStyle(.primary)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark").foregroundStyle(.tint).accessibilityHidden(true)
                }
            }
        }
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(Text(verbatim: title))
        .accessibilityHint(Text(verbatim: hint))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}


/// Featured-rail page: the MP bundled cover (or the server cover) as a plain image, then title and meta below it.
private struct DiscoveryShelfFeatureTile: View {
    let art: Image?
    let imageSource: String?
    let title: Text
    var meta: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            DiscoveryShelfHeaderImage(art: art, imageSource: imageSource)
            title.font(.headline).foregroundStyle(.primary).lineLimit(2)
            if let meta, !meta.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(verbatim: meta).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
    }
}

/// One plain header image: the MP asset when the name is known, else the screened server cover.
private struct DiscoveryShelfHeaderImage: View {
    let art: Image?
    let imageSource: String?
    @ScaledMetric(relativeTo: .body) private var scaledHeight: CGFloat = 180
    /// a11y-dt r3: the picture grows a little with Dynamic Type but stops at 240 pt, so the title under it stays on screen.
    private var height: CGFloat { min(scaledHeight, 240) }
    var body: some View {
        if let art {
            art.resizable().scaledToFill()
                .frame(height: height).frame(maxWidth: .infinity)
                .clipped()
                .accessibilityHidden(true)
        } else {
            DiscoveryArtwork(source: imageSource, height: height)
        }
    }
}

@MainActor private struct PublicTemplateCatalogSelection {
    let id = UUID()
    let identity: String
    let coordinator: PublicTopicTemplateCoordinator
    let templateID: Int
}

/// One visible catalog visit owns accepted rows and any deferred unauthorized effect.
/// Hiding cancels acceptance, not the rows that still anchor a navigation transition.
@MainActor final class PublicTemplateCatalogVisitOwner: ObservableObject {
    @Published private(set) var value: [DiscoveryTopicTemplate]?
    @Published private(set) var error: Error?
    @Published private(set) var isLoading = false
    private(set) var visit = UUID()
    private(set) var visible = false
    private var covered = false
    private var readerID: ObjectIdentifier?
    private var identity: String?
    private var operation: UUID?

    @discardableResult func synchronize(reader: any DiscoveryReading) -> Bool {
        let next = reader.discoveryPresentationIdentity
        guard readerID != ObjectIdentifier(reader) || identity != next else { return false }
        cancelPending(); visit = UUID(); value = nil; error = nil; covered = false
        readerID = ObjectIdentifier(reader); identity = next
        return true
    }
    func appear(reader: any DiscoveryReading) -> UUID? {
        let changed = synchronize(reader: reader)
        guard !visible || changed else { return nil }
        visible = true; visit = UUID(); return visit
    }
    func disappear() { visible = false; visit = UUID(); cancelPending() }
    func cover() { covered = true; visit = UUID(); cancelPending() }
    func uncover() { covered = false; visit = UUID(); cancelPending() }
    func cancelPending() { visit = UUID(); operation = nil; isLoading = false }
    func canOpen(reader: any DiscoveryReading) -> Bool {
        visible && !covered && !isLoading && error == nil && value != nil && matches(reader)
    }
    private func matches(_ reader: any DiscoveryReading) -> Bool {
        readerID == ObjectIdentifier(reader) && identity == reader.discoveryPresentationIdentity && reader.isConfigured
    }
    func load(reader: any DiscoveryReading, visit expectedVisit: UUID) async {
        guard visible, !covered, visit == expectedVisit, matches(reader), operation == nil else { return }
        let request = reader.publicTopicTemplateCatalogRequest(), run = UUID()
        operation = run; isLoading = true; error = nil
        func current() -> Bool {
            !Task.isCancelled && visible && !covered && visit == expectedVisit && operation == run && matches(reader)
        }
        defer { if operation == run { operation = nil; isLoading = false } }
        do {
            let rows = try await request.read()
            guard current() else { return }
            value = rows
        } catch is CancellationError { }
        catch {
            guard current() else { return }
            self.error = error
            if error as? APIError == .unauthorized { request.onUnauthorized() }
        }
    }
}
