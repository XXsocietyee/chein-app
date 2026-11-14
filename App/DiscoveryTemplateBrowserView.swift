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
    /// Mini-program template tab: the "+" opens the publish menu. Hidden for staff who only browse.
    let publishDestination: (() -> AnyView)?
    @State private var tab = Shelf.topics
    @State private var categoryID: Int?
    @State private var pack: DiscoveryPackType?
    @State private var keyword = ""
    @State private var appliedKeyword = ""
    @State private var topicKeyword = ""
    @FocusState private var topicSearchFocused: Bool
    @State private var appliedTopicSearch = DiscoveryTopicTemplateNameSearch("")
    @StateObject private var topics = PublicTemplateCatalogVisitOwner()
    @State private var topicSelection: PublicTemplateCatalogSelection?
    @StateObject private var games = DiscoveryLoader<[DiscoveryPlayTemplate]>()
    @StateObject private var home = DiscoveryLoader<DiscoveryTemplateHome>()
    @Environment(\.cyPalette) private var palette

    private enum Shelf: String, CaseIterable { case topics, games }
    private struct Query: Equatable {
        let tab: Shelf
        let pack: DiscoveryPackType?
        let keyword: String
    }
    private var query: Query { Query(tab: tab, pack: pack, keyword: appliedKeyword) }
    private var hasGameFilter: Bool { pack != nil || !appliedKeyword.isEmpty }

    init(reader: any DiscoveryReading, authoringFactory: ((DiscoveryPlayTemplate) -> TemplateAuthoringCoordinator)? = nil, authoringRevision: UInt64 = 0, imageReader: (any RetainedPublicImageReading)? = nil, authoringCompletion: TemplateAuthoringCompletionContext? = nil, templateTabScope: TemplateTabScope = .consumer, publishDestination: (() -> AnyView)? = nil, startOnGames: Bool = false) {
        _tab = State(initialValue: startOnGames ? .games : .topics)
        self.publishDestination = publishDestination
        self.reader = reader; self.authoringFactory = authoringFactory; self.authoringRevision = authoringRevision
        self.imageReader = imageReader; self.authoringCompletion = authoringCompletion; self.templateTabScope = templateTabScope
    }

    var body: some View {
        Group {
            if !reader.isConfigured {
                ContentUnavailableView("discovery.unavailable", systemImage: "network.slash", description: Text("auth.notConfigured"))
            } else if tab == .topics {
                topicPage
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: CYSpacing.xl) {
                        GameplayPresetSection(canDraft: !templateTabScope.isStaffReadOnly)
                        if templateTabScope == .merchant(canManageProjects: false) {
                            Text("discovery.templateTab.staffReadOnly").font(CYTypography.meta)
                                .foregroundStyle(palette.textSecondary)
                                .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.lg)
                                .accessibilityIdentifier("discovery.templateTab.staffReadOnly")
                        }
                        Picker("discovery.shelf", selection: $tab) {
                            Text("discovery.topics").tag(Shelf.topics)
                            Text("discovery.games").tag(Shelf.games)
                        }.pickerStyle(.segmented).accessibilityIdentifier("discovery.shelf")
                        if tab == .topics { topicShelf }
                        else { gameShelf }
                    }
                    .padding(.horizontal, CYSpacing.pageHorizontal)
                    .padding(.vertical, CYSpacing.lg)
                }.cyDomainPageBackground().refreshable { await reloadCurrent() }
            }
        }
        .appNavigationTitle("discovery.templateTab.title")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let publishDestination, templateTabScope != .merchant(canManageProjects: false) {
                    NavigationLink { publishDestination() } label: {
                        Label("discovery.templateTab.publish", systemImage: "plus")
                    }.accessibilityIdentifier("discovery.templateTab.publish")
                }
            }
        }
        .task {
            guard reader.isConfigured, home.value == nil else { return }
            await loadHome()
        }
        .task(id: query) {
            guard reader.isConfigured else { return }
            if tab == .games && hasGameFilter { await loadGames() }
        }
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
                .accessibilityIdentifier(field)
            Button("discovery.searchAction", action: submit)
                .font(CYTypography.meta.weight(.semibold)).foregroundStyle(palette.textSecondary)
                .accessibilityIdentifier(submitID ?? "\(field).submit")
        }
        .padding(.horizontal, CYSpacing.lg)
        .frame(minHeight: CYSpacing.minTouchTarget)
        .background(palette.bgElevated, in: Capsule(style: .continuous))
        .overlay { Capsule(style: .continuous).strokeBorder(palette.borderSubtle, lineWidth: 1).allowsHitTesting(false) }
    }

    private func filterChip(_ title: Text, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            title.font(CYTypography.meta.weight(.semibold)).lineLimit(1)
                .foregroundStyle(selected ? palette.actionPrimaryFg : palette.textSecondary)
                .padding(.horizontal, CYSpacing.lg).frame(minHeight: CYSpacing.minTouchTarget)
                .background(selected ? palette.actionPrimaryBg : Color.clear, in: Capsule(style: .continuous))
                .overlay { Capsule(style: .continuous).strokeBorder(selected ? Color.clear : palette.borderStrong, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var topicPage: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CYSpacing.xl) {
                shelfChrome
                topicShelf
                if let rows = topics.value {
                    if rows.isEmpty {
                        CYEmptyState(systemImage: "map", "discovery.emptyTopics", actionTitle: "discovery.emptyRefresh") { Task { await loadTopics() } }
                            .accessibilityIdentifier("discovery.emptyRefresh")
                    } else {
                        let filtered = appliedTopicSearch.filter(rows)
                        if filtered.isEmpty {
                            CYEmptyState(systemImage: "magnifyingglass", "discovery.noResults")
                                .accessibilityIdentifier("discovery.topicNameSearch.noResults")
                        } else {
                            let matching = filtered.filter { $0.matchesCategory(categoryID) }
                            let other = filtered.filter { !$0.matchesCategory(categoryID) }
                            if !matching.isEmpty {
                                CYSectionHeader(categoryID == nil ? "discovery.recommended" : "discovery.categoryMatches")
                                ForEach(Array(matching.enumerated()), id: \.offset) { index, item in
                                    topicCard(item, hero: index == 0)
                                }
                            }
                            if !other.isEmpty {
                                CYSectionHeader("discovery.otherTemplates", subtitle: "discovery.otherTemplatesHint")
                                ForEach(Array(other.enumerated()), id: \.offset) { _, item in
                                    topicCard(item, hero: false)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
        }.cyDomainPageBackground().refreshable { await reloadCurrent() }
    }

    private var gamePage: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CYSpacing.xl) {
                shelfChrome
                gameShelf
                if hasGameFilter {
                    if games.isLoading { CYSkeleton() }
                    if let error = games.error {
                        DiscoveryErrorView(error: error) { Task { await loadGames() } }
                    }
                    if let rows = games.value {
                        if rows.isEmpty { CYEmptyState(systemImage: "magnifyingglass", "discovery.noResults") }
                        else {
                            CYSectionHeader("discovery.searchResults")
                            ForEach(Array(rows.enumerated()), id: \.offset) { _, item in
                                gameCard(item, hero: false)
                            }
                        }
                    }
                } else {
                    if home.isLoading { CYSkeleton() }
                    if let error = home.error {
                        DiscoveryErrorView(error: error) { Task { await loadHome() } }
                    }
                    if let value = home.value {
                        if value.isEmpty { CYEmptyState(systemImage: "sparkles.rectangle.stack", "discovery.emptyGames") }
                        if !value.banner.isEmpty {
                            CYSectionHeader("discovery.featured")
                            ForEach(Array(value.banner.enumerated()), id: \.offset) { index, item in
                                gameCard(item, hero: index == 0)
                            }
                        }
                        if !value.latest.isEmpty {
                            CYSectionHeader("discovery.latest")
                            ForEach(Array(value.latest.enumerated()), id: \.offset) { _, item in
                                gameCard(item, hero: false)
                            }
                        }
                        if !value.recommended.isEmpty {
                            CYSectionHeader("discovery.recommended")
                            ForEach(Array(value.recommended.enumerated()), id: \.offset) { _, item in
                                gameCard(item, hero: false)
                            }
                        }
                        if !value.mustPlay.isEmpty {
                            CYSectionHeader("discovery.mustPlay")
                            ForEach(Array(value.mustPlay.enumerated()), id: \.offset) { _, item in
                                gameCard(item, hero: false)
                            }
                        }
                        if !value.hot.isEmpty {
                            CYSectionHeader("discovery.hot")
                            ForEach(Array(value.hot.enumerated()), id: \.offset) { _, item in
                                gameCard(item, hero: false)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
        }.cyDomainPageBackground().refreshable { await reloadCurrent() }
    }

    @ViewBuilder private var shelfChrome: some View {
        if templateTabScope == .merchant(canManageProjects: false) {
            Text("discovery.templateTab.staffReadOnly").font(CYTypography.meta)
                .foregroundStyle(palette.textSecondary)
                .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.lg)
                .accessibilityIdentifier("discovery.templateTab.staffReadOnly")
        }
        Picker("discovery.shelf", selection: $tab) {
            Text("discovery.topics").tag(Shelf.topics)
            Text("discovery.games").tag(Shelf.games)
        }.pickerStyle(.segmented).accessibilityIdentifier("discovery.shelf")
    }

    @ViewBuilder private var topicShelf: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            searchPill("discovery.topicNameSearch", text: $topicKeyword, field: "discovery.topicNameSearch", submitID: "discovery.topicNameSearch.submit", submit: applyTopicSearch)
            if appliedTopicSearch.isActive {
                HStack {
                    Text("discovery.searchingFor \(appliedTopicSearch.keyword)")
                        .font(CYTypography.meta).foregroundStyle(palette.textSecondary)
                        .accessibilityIdentifier("discovery.topicNameSearch.applied")
                    Spacer(minLength: CYSpacing.sm)
                    Button("discovery.clearTopicNameSearch") {
                        topicKeyword = ""; appliedTopicSearch = DiscoveryTopicTemplateNameSearch("")
                        topicSearchFocused = false
                    }.font(CYTypography.meta.weight(.semibold)).foregroundStyle(palette.textPrimary)
                        .accessibilityIdentifier("discovery.topicNameSearch.clear")
                }
            }
        }
        if let categories = home.value?.categories, !categories.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CYSpacing.sm) {
                    filterChip(Text("discovery.recommended"), selected: categoryID == nil) { categoryID = nil }
                    ForEach(categories) { category in
                        filterChip(Text(verbatim: category.name), selected: categoryID == category.id) { categoryID = category.id }
                    }
                }
            }.accessibilityIdentifier("discovery.topicCategory")
        }
        if let error = topics.error {
            DiscoveryErrorView(error: error) { Task { await loadTopics() } }
        }
        if topics.isLoading {
            if topics.value == nil { CYSkeleton() } else { DiscoveryTemplateSyncingRow(hasLoadedRows: true) }
        }
        // Optional category loading must never replace a successful topic shelf with an error screen.
        if home.error != nil {
            HStack {
                Text("discovery.categoriesUnavailable").font(CYTypography.meta).foregroundStyle(palette.textTertiary)
                Spacer(minLength: CYSpacing.sm)
                Button("action.retry") { Task { await loadHome() } }.font(CYTypography.meta.weight(.semibold))
            }
        }
    }

    @ViewBuilder private var gameShelf: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            searchPill("discovery.search", text: $keyword, field: "discovery.search", submitID: "discovery.search.submit", submit: applySearch)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CYSpacing.sm) {
                    filterChip(Text("discovery.allPacks"), selected: pack == nil) { pack = nil }
                    ForEach(DiscoveryPackType.allCases, id: \.rawValue) { item in
                        filterChip(Text(item.label), selected: pack == item) { pack = item }
                    }
                }
            }.accessibilityIdentifier("discovery.packFilter")
            if hasGameFilter {
                Button("discovery.clearFilters") {
                    keyword = ""; appliedKeyword = ""; pack = nil
                }.font(CYTypography.meta.weight(.semibold)).foregroundStyle(palette.textSecondary)
            }
        }
    }

    private func topicCard(_ item: DiscoveryTopicTemplate, hero: Bool) -> some View {
        Button {
            guard topicSelection == nil, topics.canOpen(reader: reader),
                  topics.value?.contains(where: { $0.id == item.id }) == true else { return }
            topicSelection = .init(identity: reader.discoveryPresentationIdentity,
                coordinator: reader.publicTopicTemplateCoordinator(id: item.id))
            topics.cover()
        } label: {
            if hero {
                CYImageCard(verbatim: item.name, fallback: "discovery.untitledTopic", meta: item.subtitle, imageURL: TemplateBrowserPort.coverURL(item.imgUrl))
                    .cachingFeedImage()
            } else {
                HStack(alignment: .top, spacing: CYSpacing.md) {
                    DiscoveryTopicCoverThumb(urlString: item.imgUrl)
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        DiscoveryTitle(text: item.name, fallback: "discovery.untitledTopic").font(CYTypography.cardTitle)
                            .foregroundStyle(palette.textPrimary)
                        if !item.subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(item.subtitle).font(CYTypography.bodyCompact).foregroundStyle(palette.textSecondary).lineLimit(2)
                        }
                        DiscoveryTopicMetadata(item: item)
                    }
                    Spacer(minLength: 0)
                }.cyDomainCard(radius: CYRadius.md, padding: CYSpacing.md)
            }
        }.buttonStyle(.plain).allowsHitTesting(topics.canOpen(reader: reader))
            .accessibilityIdentifier("discovery.topic.\(item.id)")
    }

    private func gameCard(_ item: DiscoveryPlayTemplate, hero: Bool) -> some View {
        NavigationLink {
            DiscoveryTemplateDetailView(id: item.id, reader: reader, authoringFactory: TemplateTabPolicy.refusal(for: .configure, previewOnly: false, scope: templateTabScope) == nil ? authoringFactory : nil, authoringRevision: authoringRevision, imageReader: imageReader, authoringCompletion: authoringCompletion)
        } label: {
            if hero {
                CYImageCard(verbatim: item.title, fallback: "discovery.untitledPlay", meta: item.description, imageURL: TemplateBrowserPort.coverURL(item.imgUrl))
                    .cachingFeedImage()
            } else {
                DiscoveryPlayRow(item: item).cyDomainCard(radius: CYRadius.md, padding: CYSpacing.md)
            }
        }.buttonStyle(.plain)
            .accessibilityIdentifier("discovery.play.\(item.id)")
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
    private func loadGames() async {
        let requestedKeyword = appliedKeyword
        let requestedPack = pack
        await games.load { try await reader.discoveryPlayTemplates(keyword: requestedKeyword, packType: requestedPack) }
    }
    private func reloadCurrent() async {
        if tab == .topics {
            async let a: Void = loadTopics()
            async let b: Void = loadHome()
            _ = await (a, b)
        } else if hasGameFilter { await loadGames() }
        else { await loadHome() }
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
