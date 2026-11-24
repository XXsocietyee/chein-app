import SwiftUI

/// Embed in the root's NavigationStack or present through DiscoveryHomeView.
@MainActor
struct DiscoveryTemplateBrowserView: View {
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
    /// R7-PC-A2-2 (MP `goSearch`, owner ruling 2026-10-22): templates are a result type of the one global search. When
    /// the host supplies it, one read-only capsule pushes that search instead of the two local fields.
    let searchDestination: (() -> AnyView)?
    @State private var tab = Shelf.topics
    @State private var topicTag: String?
    @State private var gameTag: String?
    @State private var showsAllTags = false
    @State private var keyword = ""
    @State private var appliedKeyword = ""
    @State private var topicKeyword = ""
    @FocusState private var topicSearchFocused: Bool
    @State private var appliedTopicSearch = DiscoveryTopicTemplateNameSearch("")
    @StateObject private var topics = PublicTemplateCatalogVisitOwner()
    @State private var topicSelection: PublicTemplateCatalogSelection?
    @StateObject private var games = DiscoveryLoader<[DiscoveryPlayTemplate]>()
    @StateObject private var shelfGames = DiscoveryLoader<[DiscoveryPlayTemplate]>()
    @StateObject private var home = DiscoveryLoader<DiscoveryTemplateHome>()
    @State private var toastMessage: String?
    @Environment(\.cyPalette) private var palette
    @Environment(\.locale) private var locale

    private enum Shelf: String, CaseIterable { case topics, games }
    private struct Query: Equatable {
        let tab: Shelf
        let keyword: String
    }
    private var query: Query { Query(tab: tab, keyword: appliedKeyword) }
    private var hasGameKeyword: Bool { !appliedKeyword.isEmpty }

    init(reader: any DiscoveryReading, authoringFactory: ((DiscoveryPlayTemplate) -> TemplateAuthoringCoordinator)? = nil, authoringRevision: UInt64 = 0, imageReader: (any RetainedPublicImageReading)? = nil, authoringCompletion: TemplateAuthoringCompletionContext? = nil, templateTabScope: TemplateTabScope = .consumer, merchantAccessError: Bool = false, onRetryMerchantAccess: (() -> Void)? = nil, publishDestination: (() -> AnyView)? = nil, startOnGames: Bool = false, searchDestination: (() -> AnyView)? = nil) {
        _tab = State(initialValue: startOnGames ? .games : .topics)
        self.publishDestination = publishDestination
        self.searchDestination = searchDestination
        self.reader = reader; self.authoringFactory = authoringFactory; self.authoringRevision = authoringRevision
        self.imageReader = imageReader; self.authoringCompletion = authoringCompletion
        self.templateTabScope = templateTabScope
        self.merchantAccessError = merchantAccessError
        self.onRetryMerchantAccess = onRetryMerchantAccess
    }

    var body: some View {
        Group {
            if !reader.isConfigured {
                CYEmptyState(
                    systemImage: "network.slash",
                    "discovery.unavailable",
                    detail: "auth.notConfigured",
                    messageIdentifier: "discovery.unavailable",
                    kind: .offline
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: CYSpacing.xl) {
                        GameplayPresetSection(canDraft: !templateTabScope.isStaffReadOnly)
                            .pageTemplateReadingOrder(10)
                        if merchantAccessError || (templateTabScope == .merchant(canManageProjects: nil) && onRetryMerchantAccess != nil) {
                            if let onRetryMerchantAccess {
                                Button(action: onRetryMerchantAccess) {
                                    CYNoteBanner(text: Text("discovery.templateTab.accessRetry"), symbol: "arrow.clockwise", tone: .warning)
                                }
                                .cyPressable()
                                .accessibilityIdentifier("discovery.templateTab.retryAccess")
                            } else {
                                CYNoteBanner(text: Text("discovery.templateTab.accessRetry"), symbol: "exclamationmark.triangle", tone: .warning)
                                    .accessibilityIdentifier("discovery.templateTab.retryAccess")
                            }
                        } else if templateTabScope == .merchant(canManageProjects: false) {
                            HStack(alignment: .top, spacing: CYSpacing.sm) {
                                Image(systemName: "lock.fill").foregroundStyle(palette.warning).accessibilityHidden(true)
                                Text("discovery.templateTab.staffReadOnly").cyText(.meta)
                                    .foregroundStyle(palette.textSecondary)
                                    .accessibilityIdentifier("discovery.templateTab.staffReadOnly")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.lg)
                            .accessibilityAddTraits(.isStaticText)
                            .pageTemplateReadingOrder(40)
                        }
                        if let searchDestination {
                            NavigationLink { searchDestination() } label: {
                                HStack(spacing: CYSpacing.sm) {
                                    Image(systemName: "magnifyingglass").foregroundStyle(palette.textTertiary).accessibilityHidden(true)
                                    Text("discovery.searchAll").cyText(.bodyCompact).foregroundStyle(palette.textSecondary)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, CYSpacing.lg)
                                .frame(minHeight: CYSpacing.minTouchTarget)
                                .background(palette.bgElevated, in: Capsule(style: .continuous))
                                .contentShape(Capsule(style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(.isSearchField)
                            .accessibilityIdentifier("discovery.globalSearch")
                            .pageTemplateReadingOrder(35)
                        }
                        Picker("discovery.shelf", selection: $tab) {
                            Text("discovery.topics").tag(Shelf.topics)
                            Text("discovery.games").tag(Shelf.games)
                        }.pickerStyle(.segmented).accessibilityIdentifier("discovery.shelf")
                            .pageTemplateReadingOrder(30)
                        if tab == .topics { topicShelf.pageTemplateReadingOrder(20) }
                        else { gameShelf.pageTemplateReadingOrder(20) }
                    }
                    .padding(.horizontal, CYSpacing.pageHorizontal)
                    .padding(.vertical, CYSpacing.lg)
                }.cyDomainPageBackground().refreshable { await reloadCurrent() }
            }
        }
        .cyPageTitle("discovery.templateTab.title") // PC-A-2-3: pushed / sheet-hosted page, inline title
        .cyToast(verbatimMessage: $toastMessage)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let publishDestination, templateTabScope != .merchant(canManageProjects: false) {
                    NavigationLink { publishDestination() } label: {
                        Label("discovery.templateTab.publish", systemImage: "plus")
                    }.pageTemplateControl(label: Text("discovery.templateTab.publish"), traits: .isButton)
                        .accessibilityIdentifier("discovery.templateTab.publish")
                }
            }
        }
        .task {
            guard reader.isConfigured, home.value == nil else { return }
            await loadHome()
        }
        .task(id: query) {
            guard reader.isConfigured else { return }
            if tab == .games && hasGameKeyword { await loadGames() }
        }
        .task(id: tab) {
            guard reader.isConfigured, tab == .games, shelfGames.value == nil else { return }
            await loadShelfGames()
        }
        .sheet(isPresented: $showsAllTags) { Group {
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
                DiscoveryTopicTemplatePreview(coordinator: selected.coordinator).id(selected.id)
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

    private func searchPill(_ prompt: LocalizedStringKey, text: Binding<String>, field: String, submitID: String?, focus: FocusState<Bool>.Binding? = nil, submit: @escaping () -> Void) -> some View {
        HStack(spacing: CYSpacing.sm) {
            Image(systemName: "magnifyingglass").foregroundStyle(palette.textTertiary).accessibilityHidden(true)
            TextField(prompt, text: text)
                .submitLabel(.search)
                .onSubmit(submit)
                .accessibilityLabel(Text(prompt))
                .accessibilityIdentifier(field)
                .accessibilityLabel(Text(prompt))
                .accessibilityValue(Text(verbatim: text.wrappedValue.isEmpty ? "—" : text.wrappedValue))
                .accessibilityHint(Text("discovery.searchAction"))
            Button("discovery.searchAction", action: submit)
                .cyText(.meta, weight: .semibold).foregroundStyle(palette.textSecondary)
                .pageTemplateControl(label: Text("discovery.searchAction"), traits: .isButton)
                .accessibilityIdentifier(submitID ?? "\(field).submit")
                .accessibilityLabel(Text("discovery.searchAction"))
                .accessibilityValue(Text(verbatim: text.wrappedValue.isEmpty ? "—" : text.wrappedValue))
                .accessibilityHint(Text(prompt))
        }
        .padding(.horizontal, CYSpacing.lg)
        .frame(minHeight: CYSpacing.minTouchTarget)
        .background(palette.bgElevated, in: Capsule(style: .continuous))
    }

    private func filterChip(_ title: Text, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            title.cyText(.meta, weight: .semibold).cyWrapText(alignment: .center)
                .foregroundStyle(selected ? palette.actionPrimaryFg : palette.textSecondary)
                .padding(.horizontal, CYSpacing.lg).frame(minHeight: CYSpacing.minTouchTarget)
                .background(selected ? palette.actionPrimaryBg : Color.clear, in: Capsule(style: .continuous))
                .overlay { Capsule(style: .continuous).strokeBorder(selected ? Color.clear : palette.borderStrong, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .pageTemplateControl(label: title, traits: selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityValue(title)
        .accessibilityHint(title)
    }

    @ViewBuilder private var topicShelf: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            if searchDestination == nil {
            searchPill("discovery.topicNameSearch", text: $topicKeyword, field: "discovery.topicNameSearch", submitID: "discovery.topicNameSearch.submit", submit: applyTopicSearch)
            if appliedTopicSearch.isActive {
                HStack {
                    Text("discovery.searchingFor \(appliedTopicSearch.keyword)")
                        .cyText(.meta).foregroundStyle(palette.textSecondary)
                        .accessibilityIdentifier("discovery.topicNameSearch.applied")
                    Spacer(minLength: CYSpacing.sm)
                    Button("discovery.clearTopicNameSearch") {
                        topicKeyword = ""; appliedTopicSearch = DiscoveryTopicTemplateNameSearch("")
                        topicSearchFocused = false
                    }.cyText(.meta, weight: .semibold).foregroundStyle(palette.textPrimary)
                        .accessibilityIdentifier("discovery.topicNameSearch.clear")
                        .accessibilityLabel(Text("discovery.clearTopicNameSearch"))
                        .accessibilityValue(Text(verbatim: appliedTopicSearch.keyword.isEmpty ? "—" : appliedTopicSearch.keyword))
                        .accessibilityHint(Text("discovery.topicNameSearch"))
                }
            }
            }
        }
        shelfChipRow(SearchDiscoveryFilterParity.topicTags(in: topics.value ?? [], selected: topicTag), field: "shelf.topic") { topicTag = $0 }
        if let error = topics.error {
            shelfIssue(error, failedTitle: "discovery.topicsFailed") { Task { await loadTopics() } }
        }
        if topics.isLoading {
            if topics.value == nil { CYSkeleton() } else { DiscoveryTemplateSyncingRow(hasLoadedRows: true) }
        }
        if let rows = topics.value {
            if rows.isEmpty {
                CYEmptyState(systemImage: "map", "discovery.emptyTopics", actionTitle: "discovery.emptyRefresh") { Task { await loadTopics() } }
                    .accessibilityIdentifier("discovery.emptyRefresh")
            } else {
                let catalog = SearchDiscoveryFilterParity.visibleTopics(rows)
                let named = appliedTopicSearch.filter(catalog)
                let tags = SearchDiscoveryFilterParity.topicTags(in: catalog, selected: topicTag)
                let shown = SearchDiscoveryFilterParity.topics(named, matching: tags.selection)
                if catalog.isEmpty {
                    CYEmptyState(systemImage: "map", "discovery.emptyTopics", actionTitle: "discovery.emptyRefresh") { Task { await loadTopics() } }
                        .accessibilityIdentifier("discovery.emptyRefresh")
                } else if named.isEmpty || shown.isEmpty {
                    CYEmptyState(systemImage: "magnifyingglass", "discovery.noResults")
                        .accessibilityIdentifier("discovery.topicNameSearch.noResults")
                } else if let selection = tags.selection, let tag = tags.row.first(where: { $0.key == selection }) ?? tags.groups.flatMap(\.tags).first(where: { $0.key == selection }) {
                    topicSection("discovery.topics", rows: shown, hero: true, verbatimTitle: locale.pick(tag.zh, tag.en))
                } else {
                    topicSection("discovery.topics", rows: shown, hero: true)
                }
            }
        }
    }

    /// Every tag group of the current shelf, for the 全部分类 sheet (same source as the chip row).
    private var allTagGroups: [DiscoveryShelfTagGroup] {
        tab == .topics
            ? SearchDiscoveryFilterParity.topicTags(in: topics.value ?? [], selected: topicTag).groups
            : SearchDiscoveryFilterParity.gameTags(in: shelfGames.value ?? [], selected: gameTag).groups
    }

    @ViewBuilder private var gameShelf: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            if searchDestination == nil {
                searchPill("discovery.search", text: $keyword, field: "discovery.search", submitID: "discovery.search.submit", submit: applySearch)
            }
            shelfChipRow(SearchDiscoveryFilterParity.gameTags(in: shelfGames.value ?? [], selected: gameTag), field: "shelf.game") { gameTag = $0 }
            if hasGameKeyword || gameTag != nil {
                Button("discovery.clearFilters") {
                    keyword = ""; appliedKeyword = ""; gameTag = nil
                }.cyText(.meta, weight: .semibold).foregroundStyle(palette.textSecondary)
                    .accessibilityLabel(Text("discovery.clearFilters"))
                    .accessibilityValue(Text(verbatim: clearFilterSpoken))
                    .accessibilityHint(Text("discovery.clearFilters"))
            }
        }
        if let error = shelfGames.error, shelfGames.value == nil {
            DiscoveryErrorView(error: error) { Task { await loadShelfGames() } }
        }
        if hasGameKeyword {
            if games.isLoading { CYSkeleton() }
            if let error = games.error {
                shelfIssue(error, failedTitle: "discovery.gamesFailed") { Task { await loadGames() } }
            }
            if let rows = games.value {
                let matched = keywordGames(rows)
                if matched.rows.isEmpty { CYEmptyState(systemImage: "magnifyingglass", "discovery.noResults") }
                else { gameSection("discovery.searchResults", rows: matched.rows, verbatimTitle: matched.title) }
            }
        } else if let selection = SearchDiscoveryFilterParity.gameTags(in: shelfGames.value ?? [], selected: gameTag).selection {
            if shelfGames.isLoading, shelfGames.value == nil { CYSkeleton() }
            if let rows = shelfGames.value {
                let shown = SearchDiscoveryFilterParity.games(rows, matching: selection)
                if shown.isEmpty { CYEmptyState(systemImage: "magnifyingglass", "discovery.noResults") }
                else if let tag = shelfTag(SearchDiscoveryFilterParity.gameTags(in: rows, selected: selection), key: selection) {
                    gameSection("discovery.searchResults", rows: shown, verbatimTitle: locale.pick(tag.zh, tag.en))
                } else { gameSection("discovery.searchResults", rows: shown) }
            }
        } else {
            if home.isLoading { CYSkeleton() }
            if let error = home.error {
                shelfIssue(error, failedTitle: "discovery.gamesFailed") { Task { await loadHome() } }
            }
            if let value = home.value {
                if value.isEmpty { CYEmptyState(systemImage: "sparkles.rectangle.stack", "discovery.emptyGames") }
                gameSection("discovery.featured", rows: value.banner, hero: true)
                gameSection("discovery.latest", rows: value.latest)
                gameSection("discovery.recommended", rows: value.recommended)
                gameSection("discovery.mustPlay", rows: value.mustPlay)
                gameSection("discovery.hot", rows: value.hot)
            }
        }
    }
    @ViewBuilder private func topicSection(_ title: LocalizedStringKey, rows: [DiscoveryTopicTemplate], hint: LocalizedStringKey? = nil, hero: Bool = false, verbatimTitle: String? = nil) -> some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                if let shownTitle = verbatimTitle {
                    Text(verbatim: shownTitle).cyText(.cardTitle).foregroundStyle(palette.textPrimary)
                } else {
                    CYSectionHeader(title, subtitle: hint)
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { index, item in
                    Button {
                        // R7-PC-A2-4: MP `openTopic` — a preview-only row says 暂未开放 instead of opening.
                        if item.previewOnly {
                            toastMessage = appLocalized("searchMap.template.previewOnly", locale: locale)
                            return
                        }
                        guard topicSelection == nil, topics.canOpen(reader: reader),
                              topics.value?.contains(where: { $0.id == item.id }) == true else { return }
                        topicSelection = .init(identity: reader.discoveryPresentationIdentity,
                            coordinator: reader.publicTopicTemplateCoordinator(id: item.id))
                        topics.cover()
                    } label: {
                        if hero && index == 0 {
                            CYImageCard(verbatim: item.name, fallback: "discovery.untitledTopic", meta: item.subtitle, imageURL: TemplateBrowserPort.coverURL(item.imgUrl))
                        } else {
                            HStack(alignment: .top, spacing: CYSpacing.md) {
                                DiscoveryTopicCoverThumb(urlString: item.imgUrl, seed: item.name)
                                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                    DiscoveryTitle(text: item.name, fallback: "discovery.untitledTopic").cyText(.cardTitle)
                                        .foregroundStyle(palette.textPrimary)
                                    if !item.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        Text(item.subtitle).cyText(.bodyCompact).foregroundStyle(palette.textSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    DiscoveryTopicMetadata(item: item)
                                }
                                Spacer(minLength: 0)
                            }.cyDomainCard(radius: CYRadius.md, padding: CYSpacing.md)
                        }
                    }.buttonStyle(.plain).allowsHitTesting(topics.canOpen(reader: reader))
                        .pageTemplateGroupedCard(label: topicCardLabel(item), traits: .isButton)
                        .accessibilityIdentifier("discovery.topic.\(item.id)")
                }
            }
        }
    }
    @ViewBuilder private func gameSection(_ title: LocalizedStringKey, rows: [DiscoveryPlayTemplate], hero: Bool = false, verbatimTitle: String? = nil) -> some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                if let shownTitle = verbatimTitle {
                    Text(verbatim: shownTitle).cyText(.cardTitle).foregroundStyle(palette.textPrimary)
                } else {
                    CYSectionHeader(title)
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { index, item in
                    NavigationLink {
                        DiscoveryTemplateDetailView(id: item.id, reader: reader, authoringFactory: TemplateTabPolicy.refusal(for: .configure, previewOnly: false, scope: templateTabScope) == nil ? authoringFactory : nil, authoringRevision: authoringRevision, imageReader: imageReader, authoringCompletion: authoringCompletion)
                    } label: {
                        if hero && index == 0 {
                            CYImageCard(verbatim: item.title, fallback: "discovery.untitledPlay", meta: item.description, imageURL: TemplateBrowserPort.coverURL(item.imgUrl))
                        } else {
                            DiscoveryPlayRow(item: item).cyDomainCard(radius: CYRadius.md, padding: CYSpacing.md)
                        }
                    }.buttonStyle(.plain)
                    .pageTemplateGroupedCard(label: gameCardLabel(item), traits: .isButton)
                    .accessibilityIdentifier("discovery.play.\(item.id)")
                }
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
        return CYStateLayout(
            kind: offline ? .offline : .failure,
            title: Text(title),
            detail: detail.map { Text($0) },
            primary: canRetry ? (title: "action.retry", action: retry) : nil,
            primaryIdentifier: canRetry ? "discovery.retry" : nil
        )
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

    private func applyTopicSearch() {
        appliedTopicSearch = DiscoveryTopicTemplateNameSearch(topicKeyword)
        topicSearchFocused = false
    }
    private func applySearch() {
        appliedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private func loadHome() async { await home.load { try await reader.discoveryTemplateHome() } }
    private func loadTopics() async {
        await topics.load(reader: reader, visit: topics.visit)
    }
    /// A typed keyword stays as typed, including 0. No keyword and no chosen tag is unknown.
    private var clearFilterSpoken: String {
        if !appliedKeyword.isEmpty { return appliedKeyword }
        guard let gameTag else { return "—" }
        let tags = SearchDiscoveryFilterParity.gameTags(in: shelfGames.value ?? [], selected: gameTag)
        if let tag = shelfTag(tags, key: gameTag) { return locale.pick(tag.zh, tag.en) }
        return "—"
    }

    private func shelfTag(_ tags: DiscoveryShelfTagSet, key: String) -> DiscoveryShelfTag? {
        tags.row.first { $0.key == key } ?? tags.groups.flatMap(\.tags).first { $0.key == key }
    }

    private func keywordGames(_ rows: [DiscoveryPlayTemplate]) -> (rows: [DiscoveryPlayTemplate], title: String?) {
        let tags = SearchDiscoveryFilterParity.gameTags(in: shelfGames.value ?? rows, selected: gameTag)
        guard let selection = tags.selection else { return (rows, nil) }
        let matched = rows.filter { SearchDiscoveryFilterParity.gameMatches($0, key: selection) }
        let title = shelfTag(tags, key: selection).map { locale.pick($0.zh, $0.en) }
        return (matched, title)
    }

    private func shelfChipRow(_ tags: DiscoveryShelfTagSet, field: String, select: @escaping (String?) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CYSpacing.sm) {
                filterChip(Text(verbatim: locale.pick("全部", "All")), selected: tags.selection == nil) { select(nil) }
                    .accessibilityIdentifier("\(field).all")
                ForEach(tags.row) { tag in
                    filterChip(Text(verbatim: locale.pick(tag.zh, tag.en)), selected: tags.selection == tag.key) { select(tag.key) }
                        .accessibilityIdentifier("\(field).\(tag.key)")
                }
                filterChip(Text(verbatim: locale.pick("全部分类", "All categories")), selected: false) { showsAllTags = true }
                    .accessibilityIdentifier("\(field).allCategories")
            }
        }.accessibilityIdentifier(field)
    }

    private func loadGames() async {
        let requestedKeyword = appliedKeyword
        await games.load { try await reader.discoveryPlayTemplates(keyword: requestedKeyword, packType: nil) }
    }
    private func loadShelfGames() async {
        await shelfGames.load { try await reader.discoveryPlayTemplates(keyword: "", packType: .single) }
    }
    private func reloadCurrent() async {
        if tab == .topics {
            async let a: Void = loadTopics()
            async let b: Void = loadHome()
            _ = await (a, b)
        } else if hasGameKeyword {
            async let a: Void = loadGames()
            async let b: Void = loadShelfGames()
            _ = await (a, b)
        } else {
            async let a: Void = loadHome()
            async let b: Void = loadShelfGames()
            _ = await (a, b)
        }
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
            ScrollView {
                VStack(alignment: .leading, spacing: CYSpacing.lg) {
                    Button(action: { choose(nil) }) {
                        Text(verbatim: locale.pick("全部", "All"))
                            .cyText(.body, weight: selected == nil ? .semibold : .regular)
                            .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("discovery.allCategories.all")
                    .accessibilityLabel(Text(verbatim: locale.pick("全部", "All")))
                    .accessibilityValue(Text(verbatim: locale.pick("全部", "All")))
                    .accessibilityHint(Text(verbatim: locale.pick("全部分类", "All categories")))
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: CYSpacing.sm) {
                            Text(verbatim: locale.pick(group.zh, group.en))
                                .cyText(.cardTitle)
                            ForEach(group.tags) { tag in
                                Button(action: { choose(tag.key) }) {
                                    Text(verbatim: locale.pick(tag.zh, tag.en))
                                        .cyText(.body, weight: selected == tag.key ? .semibold : .regular)
                                        .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("discovery.allCategories.\(tag.key)")
                                .accessibilityLabel(Text(verbatim: locale.pick(tag.zh, tag.en)))
                                .accessibilityValue(Text(verbatim: locale.pick(tag.zh, tag.en)))
                                .accessibilityHint(Text(verbatim: locale.pick(group.zh, group.en)))
                            }
                        }
                    }
                }
                .padding(CYSpacing.lg)
            }
            .navigationTitle(Text(verbatim: locale.pick("全部分类", "All categories")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                    .accessibilityIdentifier("discovery.allCategories.close")
                    .accessibilityLabel(Text("action.close"))
                    .accessibilityValue(Text(verbatim: locale.pick("全部分类", "All categories")))
                    .accessibilityHint(Text(verbatim: locale.pick("全部分类", "All categories")))
                }
            }
        }
    }
}


@MainActor private struct PublicTemplateCatalogSelection {
    let id = UUID()
    let identity: String
    let coordinator: PublicTopicTemplateCoordinator
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
