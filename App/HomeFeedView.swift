import SwiftUI

/// Embed in the caller's NavigationStack. The caller owns existing detail destinations.
@MainActor struct HomeFeedView: View {
    let reader: any HomeFeedReading
    var unavailableMessageKey: String? = nil
    /// Supply only from verified backend configuration, never language/device locale.
    var sourceTimeZone: TimeZone? = nil
    var viewerNickname: String? = nil
    var viewerAvatar: String? = nil
    var selectedCity: String? = nil
    var showsHeroBanners: Bool = false
    var continuationCards: [HomeIndexParityPresentation.ContinuationCard] = []
    var continuationReadAvailability: HomeContinuationReadAvailability = .available
    var onActionBanner: ((HomeIndexParityPresentation.ActionBanner) -> Void)? = nil
    var onContinuation: ((HomeIndexParityPresentation.ContinuationCard) -> Void)? = nil
    var onRetryContinuation: (() -> Void)? = nil
    var onSelectCity: ((String?, Bool) -> Void)? = nil
    var onOpenUnifiedSearch: ((UnifiedSearchExperience.PresentationMode) -> Void)? = nil
    let onDestination: (HomeFeedDestination) -> Void
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var model = HomeFeedModel()
    @State private var kind: HomeFeedKind = .topics
    @State private var keyword = ""
    @State private var categoryID: Int?
    @State private var submittedKeyword = ""
    /// Loading-to-content choreography (docs/release/motion-spec-loading.md).
    @State private var streamSkeleton = false
    @State private var stagger = CYStaggerGate()
    @State private var localSelectedCity: String? = nil
    @State private var localIsNationwide: Bool = false
    private var hasHeroHeader: Bool { showsHeroBanners || viewerNickname != nil || selectedCity != nil || onActionBanner != nil }
    private var query: HomeFeedQuery { HomeFeedQuery(kind: kind, keyword: submittedKeyword, categoryID: categoryID) }
    var body: some View {
        let binding = model.bind(reader, available: unavailableMessageKey == nil)
        let permit = model.permit(reader)
        CYLoadSlot(isLoading: reader.isConfigured && unavailableMessageKey == nil && !model.matches(reader), skeletonRows: 4, label: "homeFeed.loading", announces: true) {
            if !reader.isConfigured || unavailableMessageKey != nil {
                ContentUnavailableView("homeFeed.unavailable", systemImage: "network.slash", description: Text(LocalizedStringKey(unavailableMessageKey ?? "auth.notConfigured")))
                    .accessibilityIdentifier("homeFeed.configurationUnavailable")
            } else if !model.matches(reader) {
                Color.clear
            } else {
                List {
                    if hasHeroHeader {
                        HomeHeroHeaderSectionView(
                            nickname: viewerNickname,
                            selectedCity: localSelectedCity ?? selectedCity,
                            isNationwide: localIsNationwide,
                            avatarSource: viewerAvatar,
                            onSelectCity: onSelectCity != nil ? { city, nationwide in
                                localSelectedCity = city
                                localIsNationwide = nationwide
                                onSelectCity?(city, nationwide)
                            } : nil,
                            onOpenUnifiedSearch: onOpenUnifiedSearch
                        ) { banner in
                            if banner.id == "activity_list" { kind = .activities }
                            onActionBanner?(banner)
                        }
                    }
                    bannerSection
                    feedSection(.recommended)
                    if !continuationCards.isEmpty || (continuationReadAvailability != .available && continuationReadAvailability != .unauthenticated) {
                        PlayContinuationBannerView(
                            cards: continuationCards,
                            readAvailability: continuationReadAvailability,
                            onSelectCard: { card in
                                guard model.canOpen(reader) else { return }
                                if let onContinuation {
                                    onContinuation(card)
                                } else {
                                    onDestination(card.destination)
                                }
                            },
                            onOpen: { destination in
                                if model.canOpen(reader) { onDestination(destination) }
                            },
                            onRetry: onRetryContinuation
                        )
                    }
                    feedSection(.nearby)
                    feedSection(.upcoming)
                    Section {
                        Picker("homeFeed.content", selection: $kind) {
                            Text("homeFeed.topics").tag(HomeFeedKind.topics)
                            Text("homeFeed.activities").tag(HomeFeedKind.activities)
                        }.pickerStyle(.segmented).accessibilityIdentifier("homeFeed.kind")
                        Picker("homeFeed.category", selection: $categoryID) {
                            Text("homeFeed.allCategories").tag(Int?.none)
                            ForEach(model.categories) { category in Text(verbatim: category.name).tag(Optional(category.id)) }
                        }.accessibilityIdentifier("homeFeed.category")
                        if model.categoryFailed { retry("homeFeed.categoriesError", id: "categories") { model.schedule(.categories, reader: reader, permit: permit) } }
                        ForEach(Array(model.pagination.items.enumerated()), id: \.element.id) { index, item in
                            row(item, section: "stream").cyStaggeredAppear(index: index, gate: stagger)
                        }
                        if model.pageFailed { retry("homeFeed.loadError", id: "page") { model.schedule(.page, reader: reader, permit: permit) } }
                        if model.loadingPage {
                            if model.pagination.items.isEmpty {
                                if streamSkeleton {
                                    CYLoadingStateView(rows: 3)
                                        .accessibilityLabel(Text("homeFeed.loading"))
                                        .listRowBackground(Color.clear).listRowSeparator(.hidden).listRowInsets(EdgeInsets())
                                        .transition(.opacity)
                                }
                            } else { ProgressView("homeFeed.loading") }
                        }
                        else if !model.pageFailed && model.pagination.items.isEmpty && !streamSkeleton {
                            CYEmptyStateView(systemImage: "magnifyingglass", title: "homeFeed.empty", description: "homeFeed.emptyHint")
                                .accessibilityIdentifier("homeFeed.empty")
                        }
                        if model.pagination.hasMore && !model.loadingPage && !model.pageFailed {
                            Button("homeFeed.loadMore") { model.schedule(.page, reader: reader, permit: permit) }
                                .frame(minHeight: 44)
                                .accessibilityIdentifier("homeFeed.loadMore")
                        } else if !model.pagination.hasMore && !model.loadingPage && !model.pageFailed && !model.pagination.items.isEmpty {
                            Text(verbatim: HomeIndexParityPresentation.noMoreFooterCopy(locale: locale))
                                .font(CYTypography.meta)
                                .foregroundStyle(CYColor.textTertiary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .accessibilityIdentifier("homeFeed.noMoreFooter")
                        }
                    } header: { sectionHeader(Text("homeFeed.explore")) }
                }
                .listStyle(.insetGrouped)
                .listSectionSpacing(CYSpacing.xxl)
                .scrollContentBackground(.hidden)
                .background(CYColor.bgPage)
                .searchable(text: $keyword, placement: onOpenUnifiedSearch == nil ? .automatic : .navigationBarDrawer(displayMode: .automatic), prompt: Text("homeFeed.search"))
                .onSubmit(of: .search) { submittedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines) }
                .onChange(of: keyword) { _, value in if value.isEmpty { submittedKeyword = "" } }
                .onChange(of: query) { _, value in model.schedule(.query(value), reader: reader, permit: permit) }
                .refreshable { await model.reload(reader: reader, query: query) }
                .cySkeletonTiming(isLoading: model.loadingPage && model.pagination.items.isEmpty, visible: $streamSkeleton)
                .cyAnimation(.easeInOut(duration: CYMotion.Duration.quick), value: streamSkeleton)
            }
        }
        .appNavigationTitle("homeFeed.title")
        // The greeting block is the title (mini-program home): no second large nav title above it.
        .toolbar(hasHeroHeader ? .hidden : .automatic, for: .navigationBar)
        .task(id: binding) { await model.resume(reader: reader, query: query, available: unavailableMessageKey == nil, expectedBinding: binding) }
        .onDisappear { model.suspend() }
    }
    @ViewBuilder private var bannerSection: some View {
        let permit = model.permit(reader)
        if model.bannerFailed { retry("homeFeed.bannersError", id: "banners") { model.schedule(.banners, reader: reader, permit: permit) } }
        if !model.banners.isEmpty {
            // Mirrors the mini-program hero swiper: full-width rounded covers, paged, dots, no captions.
            Section {
                CYHeroBanner(items: model.banners.map { banner in
                    CYHeroBannerItem(id: banner.id, imageURL: QuestifyCardArtwork.safeURL(banner.picUrl), accessibilityLabel: "homeFeed.openFeatured",
                                     title: banner.contents.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : Text(verbatim: $0) },
                                     action: banner.destination.map { destination in {
                        guard model.canOpen(reader) else { return }
                        switch destination { case .activity(let id): onDestination(.activity(id)); case .topic(let id): onDestination(.topic(id)) }
                    } })
                })
                .questifyCardListRow()
            }
        }
    }
    /// Mini-program `sec-reco` / `sec-nearby` / `sec-upcoming`: a titled horizontal rail each, with its own
    /// loading, failure and empty state. 即将上线 disappears once it has loaded with nothing in it.
    @ViewBuilder private func feedSection(_ section: HomeFeedSection) -> some View {
        let permit = model.permit(reader)
        let items = model.sections[section]
        let failed = model.failedSections.contains(section)
        let hidesEmptyUpcoming = section == .upcoming && !failed && (items?.isEmpty ?? !model.loading)
        if !hidesEmptyUpcoming {
            Section {
                if failed {
                    retry("homeFeed.loadError", id: section.rawValue) { model.schedule(.section(section), reader: reader, permit: permit) }
                } else if let items {
                    if items.isEmpty {
                        Text(section == .recommended ? LocalizedStringKey("homeFeed.editorsPicksEmpty") : LocalizedStringKey("homeFeed.activitiesEmpty"))
                            .font(CYTypography.bodyCompact)
                            .foregroundStyle(CYColor.textSecondary)
                    } else if dynamicTypeSize.isAccessibilitySize {
                        ForEach(items) { item in row(item, section: section.rawValue, style: .hero) }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: CYSpacing.md) {
                                ForEach(items) { item in
                                    row(item, section: section.rawValue, style: .shelf)
                                }
                            }
                            .scrollTargetLayout()
                            .padding(.horizontal, CYSpacing.lg)
                        }
                        .scrollClipDisabled()
                        .scrollTargetBehavior(.viewAligned)
                        .questifyCardListRow()
                    }
                } else if model.loading {
                    CYSkeleton().padding(.vertical, CYSpacing.md).frame(maxWidth: .infinity, minHeight: 88)
                }
            } header: {
                switch section {
                case .recommended: sectionHeader(Text("homeFeed.editorsPicks"))
                case .nearby: sectionHeader(Text("homeFeed.activityHighlights"))
                case .upcoming: sectionHeader(Text("homeFeed.upcoming"))
                }
            }
        }
    }
    /// Large, plain section title (mini-program `sec-title`): no small-caps grouped-list header.
    private func sectionHeader(_ title: Text) -> some View {
        title
            .font(.title2.weight(.bold))
            .foregroundStyle(CYColor.textPrimary)
            .textCase(nil)
            .padding(.leading, -CYSpacing.xs)
            .accessibilityAddTraits(.isHeader)
    }
    private func row(_ item: HomeFeedItem, section: String, style: CYImageCard.Style? = nil) -> some View {
        Button { if model.canOpen(reader) { onDestination(item.id) } } label: {
            if let style { HomeFeedShelfCard(item: item, sourceTimeZone: sourceTimeZone, style: style) } else { HomeFeedCard(item: item, sourceTimeZone: sourceTimeZone) }
        }
            .buttonStyle(QuestifyCardButtonStyle())
            .accessibilityIdentifier("homeFeed.\(section).\(item.accessibilityKey)")
            .questifyCardListRow()
    }
    private func retry(_ message: LocalizedStringKey, id: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Label { Text(message) } icon: { Image(systemName: "exclamationmark.triangle") }
                .font(CYTypography.bodyCompact)
                .foregroundStyle(CYColor.textSecondary)
            Button("homeFeed.retry", action: action)
                .buttonStyle(.cySecondary)
                .frame(minHeight: CYSpacing.minTouchTarget)
                .accessibilityIdentifier("homeFeed.retry.\(id)")
        }
    }
}

extension HomeFeedItem {
    var accessibilityKey: String {
        switch id { case .activity(let id): return "activity.\(id)"; case .topic(let id): return "topic.\(id)" }
    }
}

/// Kit image card for the rails: cover, title, then one meta line (date · place · price, em dash when unknown).
struct HomeFeedShelfCard: View {
    let item: HomeFeedItem
    var sourceTimeZone: TimeZone?
    var style: CYImageCard.Style
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone
    var body: some View {
        let date = QuestifyCardText.date(item.startDate, sourceTimeZone: sourceTimeZone, locale: locale, displayTimeZone: timeZone)
        // Currency + 起/From come from the shared price key; unknown price shows an em dash, never 0.
        let price = QuestifyCardText.amount(item.amount, locale: locale).map { appLocalized("playx.finishRoute.priceFrom \($0)", locale: locale) } ?? "—"
        let line = [QuestifyCardText.metaLine(date: date, place: item.place), price].compactMap { $0 }.joined(separator: " · ")
        CYImageCard(LocalizedStringKey(item.name), metaText: line,
                    imageURL: QuestifyCardArtwork.safeURL(item.imageURL), style: style)
    }
}

struct HomeFeedCard: View {
    let item: HomeFeedItem
    private let sourceTimeZone: TimeZone?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone
    init(item: HomeFeedItem, sourceTimeZone: TimeZone? = nil) {
        self.item = item
        self.sourceTimeZone = sourceTimeZone
    }
    private var typeSymbol: String {
        switch item { case .activity: return "figure.walk"; case .topic: return "map" }
    }
    /// Mini-program `v2-fcard` + `v2-status`: cover and title, one date · place line, then the starting price.
    var body: some View {
        QuestifyImageEntityCard(imageSource: safeImageSource, title: item.name, fallbackSymbol: typeSymbol,
                                minimumHeight: dynamicTypeSize.isAccessibilitySize ? 300 : 260) {
            QuestifyCardSummary(meta: QuestifyCardText.metaLine(date: QuestifyCardText.date(item.startDate, sourceTimeZone: sourceTimeZone, locale: locale, displayTimeZone: timeZone), place: item.place),
                                price: QuestifyCardText.amount(item.amount, locale: locale), onArtwork: true)
        }
    }
    /// Only a safe https cover reaches the card; anything else shows the clean placeholder.
    private var safeImageSource: String? {
        if let url = QuestifyCardArtwork.safeURL(item.imageURL) { return url.absoluteString }
        return nil
    }
}
