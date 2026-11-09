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
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: CYSpacing.xl) {
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
                    topicSection(categoryID == nil ? "discovery.recommended" : "discovery.categoryMatches", rows: matching, hero: true)
                    topicSection("discovery.otherTemplates", rows: other, hint: "discovery.otherTemplatesHint")
                }
            }
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
        if hasGameFilter {
            if games.isLoading { CYSkeleton() }
            if let error = games.error {
                DiscoveryErrorView(error: error) { Task { await loadGames() } }
            }
            if let rows = games.value {
                if rows.isEmpty { CYEmptyState(systemImage: "magnifyingglass", "discovery.noResults") }
                else { gameSection("discovery.searchResults", rows: rows) }
            }
        } else {
            if home.isLoading { CYSkeleton() }
            if let error = home.error {
                DiscoveryErrorView(error: error) { Task { await loadHome() } }
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
    @ViewBuilder private func topicSection(_ title: LocalizedStringKey, rows: [DiscoveryTopicTemplate], hint: LocalizedStringKey? = nil, hero: Bool = false) -> some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                CYSectionHeader(title, subtitle: hint)
                ForEach(Array(rows.enumerated()), id: \.offset) { index, item in
                    Button {
                        guard topicSelection == nil, topics.canOpen(reader: reader),
                              topics.value?.contains(where: { $0.id == item.id }) == true else { return }
                        topicSelection = .init(identity: reader.discoveryPresentationIdentity,
                            coordinator: reader.publicTopicTemplateCoordinator(id: item.id))
                        topics.cover()
                    } label: {
                        if hero && index == 0 {
                            TemplateHeroCard(title: item.name, fallback: "discovery.untitledTopic", meta: item.subtitle, imageURL: TemplateBrowserPort.coverURL(item.imgUrl))
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
            }
        }
    }
    @ViewBuilder private func gameSection(_ title: LocalizedStringKey, rows: [DiscoveryPlayTemplate], hero: Bool = false) -> some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                CYSectionHeader(title)
                ForEach(Array(rows.enumerated()), id: \.offset) { index, item in
                    NavigationLink {
                        DiscoveryTemplateDetailView(id: item.id, reader: reader, authoringFactory: TemplateTabPolicy.refusal(for: .configure, previewOnly: false, scope: templateTabScope) == nil ? authoringFactory : nil, authoringRevision: authoringRevision, imageReader: imageReader, authoringCompletion: authoringCompletion)
                    } label: {
                        if hero && index == 0 {
                            TemplateHeroCard(title: item.title, fallback: "discovery.untitledPlay", meta: item.description ?? "", imageURL: TemplateBrowserPort.coverURL(item.imgUrl))
                        } else {
                            DiscoveryPlayRow(item: item).cyDomainCard(radius: CYRadius.md, padding: CYSpacing.md)
                        }
                    }.buttonStyle(.plain)
                    .accessibilityIdentifier("discovery.play.\(item.id)")
                }
            }
        }
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

/// Hero cover card for server-authored titles (kept verbatim, so it cannot reuse `CYImageCard`'s LocalizedStringKey title).
private struct TemplateHeroCard: View {
    let title: String
    let fallback: LocalizedStringKey
    let meta: String
    let imageURL: URL?
    @Environment(\.cyPalette) private var palette
    var body: some View {
        Color.clear
            .aspectRatio(16.0 / 10.0, contentMode: .fit)
            .overlay {
                if let imageURL {
                    AsyncImage(url: imageURL) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() } else { placeholder }
                    }
                } else { placeholder }
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                    DiscoveryTitle(text: title, fallback: fallback).font(CYTypography.sectionTitle).lineLimit(2)
                    if !meta.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(verbatim: meta).font(CYTypography.meta).opacity(0.85).lineLimit(1)
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, CYSpacing.lg).padding(.bottom, CYSpacing.lg).padding(.top, CYSpacing.jumbo)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black.opacity(0.78), location: 0.7)], startPoint: .top, endPoint: .bottom))
            }
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
            .shadow(color: palette.cardShadowColor.opacity(0.4), radius: 8, x: 0, y: 3)
            .accessibilityElement(children: .combine)
    }
    private var placeholder: some View {
        LinearGradient(colors: [palette.bgStrong, palette.bgRaised], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(Image(systemName: "photo").font(.largeTitle).foregroundStyle(palette.textPlaceholder))
    }
}
