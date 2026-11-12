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
    /// Today-card inputs. The host supplies what it already holds; nothing here is fetched by the feed.
    var todayTicket: HomeTodayCandidate? = nil
    var todayClubEvent: HomeTodayCandidate? = nil
    var onOpenTodayTicket: (() -> Void)? = nil
    var onOpenTodayClubEvent: (() -> Void)? = nil
    var onStartRoam: (() -> Void)? = nil
    var onSelectCity: ((String?, Bool) -> Void)? = nil
    /// Mini-program `locationPrompt`: set only while the host is asking for the home-city location consent. Nil hides the card.
    var cityLocationConsent: (agree: () -> Void, decline: () -> Void)? = nil
    var onOpenUnifiedSearch: ((UnifiedSearchExperience.PresentationMode) -> Void)? = nil
    let onDestination: (HomeFeedDestination) -> Void
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.timeZone) private var timeZone
    @Environment(\.cyHeroNamespace) private var heroNamespace
    @StateObject private var model = HomeFeedModel()
    @State private var kind: HomeFeedKind = .topics
    @State private var keyword = ""
    @State private var categoryID: Int?
    @State private var submittedKeyword = ""
    /// Loading-to-content choreography (docs/release/motion-spec-loading.md).
    @State private var streamSkeleton = false
    @State private var stagger = CYStaggerGate()
    /// First-fold section reveal (spring, 70 ms apart, once per screen).
    @State private var reveal = CYSectionRevealGate()
    @State private var localSelectedCity: String? = nil
    @State private var localIsNationwide: Bool = false
    private var hasHeroHeader: Bool { showsHeroBanners || viewerNickname != nil || selectedCity != nil || onActionBanner != nil }
    private var query: HomeFeedQuery { HomeFeedQuery(kind: kind, keyword: submittedKeyword, categoryID: categoryID) }
    var body: some View {
        let binding = model.bind(reader, available: unavailableMessageKey == nil)
        let permit = model.permit(reader)
        CYLoadSlot(isLoading: reader.isConfigured && unavailableMessageKey == nil && !model.matches(reader), skeletonRows: 4, label: "homeFeed.loading", announces: true) {
            if !reader.isConfigured || unavailableMessageKey != nil {
                // Night-city offline state: drawn art on the ink ground instead of the system placeholder.
                CYStateLayout(kind: .offline, title: Text("homeFeed.unavailable"),
                              detail: Text(LocalizedStringKey(unavailableMessageKey ?? "auth.notConfigured")))
                    .accessibilityElement(children: .combine) // one static text, as the system placeholder was: UITests and VoiceOver read a single state
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background { CYExploreGround() }
                    .accessibilityIdentifier("homeFeed.configurationUnavailable")
            } else if !model.matches(reader) {
                Color.clear
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: CYSpacing.xxl) {
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
                        .cySectionReveal(order: 0, gate: reveal)
                    }
                    if let consent = cityLocationConsent {
                        HomeCityLocationConsentCard(onAgree: consent.agree, onDecline: consent.decline)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    todayCard.cySectionReveal(order: 1, gate: reveal)
                    if model.bannerFailed || !model.banners.isEmpty { bannerSection.cySectionReveal(order: 2, gate: reveal) }
                    feedSection(.recommended, order: 3)
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
                        .cySectionReveal(order: 4, gate: reveal)
                    }
                    feedSection(.nearby, order: 5)
                    feedSection(.upcoming, order: 6)
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        sectionHeader(Text("homeFeed.explore"))
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
                    }
                    .cySectionReveal(order: 7, gate: reveal)
                    }
                    .padding(.horizontal, CYSpacing.pageHorizontal)
                    .padding(.top, CYSpacing.lg)
                    .padding(.bottom, CYSpacing.jumbo)
                }
                .background { CYExploreGround() }
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
            VStack {
                CYHeroBanner(items: model.banners.map { banner in
                    CYHeroBannerItem(id: banner.id, imageURL: QuestifyCardArtwork.safeURL(banner.picUrl), accessibilityLabel: "homeFeed.openFeatured",
                                     title: banner.contents.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : Text(verbatim: $0) },
                                     action: banner.destination.map { destination in {
                        guard model.canOpen(reader) else { return }
                        switch destination { case .activity(let id): onDestination(.activity(id)); case .topic(let id): onDestination(.topic(id)) }
                    } })
                })
            }
        }
    }
    /// One focal point on the first fold: ticket within 24 h > club event today > start a roam.
    @ViewBuilder private var todayCard: some View {
        let choice = HomeTodayChoice.resolve(ticket: todayTicket, clubEvent: todayClubEvent, now: Date(), calendar: .current)
        // A club event that is a real activity opens the activity detail: the card is the hero source and zooms into it.
        let activityID = choice.activityID
        HomeTodayCard(choice: choice,
                      onTicket: onOpenTodayTicket,
                      onClubEvent: activityID.map { id -> () -> Void in { if model.canOpen(reader) { onDestination(.activity(id)) } } } ?? onOpenTodayClubEvent,
                      onStartRoam: onStartRoam)
            .cyHeroSourceInherited(HomeFeedDestination.activity(activityID ?? 0), isEnabled: activityID != nil)
    }
    /// Items that already own a hero source higher on the screen (Today card, then each earlier rail), so a namespace
    /// never holds two sources for one destination id.
    private func heroOwned(by section: String?) -> Set<HomeFeedDestination> {
        var owned = Set<HomeFeedDestination>()
        if let id = HomeTodayChoice.resolve(ticket: todayTicket, clubEvent: todayClubEvent, now: Date(), calendar: .current).activityID { owned.insert(.activity(id)) }
        for rail in HomeFeedSection.allCases {
            if rail.rawValue == section { break }
            if let items = model.sections[rail] { owned.formUnion(items.map(\.id)) }
        }
        return owned
    }
    /// Mini-program `sec-reco` / `sec-nearby` / `sec-upcoming`: a titled horizontal rail each, with its own
    /// loading, failure and empty state. 即将上线 disappears once it has loaded with nothing in it.
    @ViewBuilder private func feedSection(_ section: HomeFeedSection, order: Int) -> some View {
        let permit = model.permit(reader)
        let items = model.sections[section]
        let failed = model.failedSections.contains(section)
        let hidesEmptyUpcoming = section == .upcoming && !failed && (items?.isEmpty ?? !model.loading)
        if !hidesEmptyUpcoming {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                switch section {
                case .recommended: sectionHeader(Text("homeFeed.editorsPicks"))
                case .nearby: sectionHeader(Text("homeFeed.activityHighlights"))
                case .upcoming: sectionHeader(Text("homeFeed.upcoming"))
                }
                if failed {
                    retry("homeFeed.loadError", id: section.rawValue) { model.schedule(.section(section), reader: reader, permit: permit) }
                } else if let items {
                    if items.isEmpty {
                        Text(section == .recommended ? LocalizedStringKey("homeFeed.editorsPicksEmpty") : LocalizedStringKey("homeFeed.activitiesEmpty"))
                            .font(CYTypography.bodyCompact)
                            .foregroundStyle(CYColor.textSecondary)
                    } else if dynamicTypeSize.isAccessibilitySize {
                        ForEach(items) { item in row(item, section: section.rawValue, style: .hero) }
                    } else if section != .nearby {
                        // Glass carousel for the editor picks and upcoming rails (nearby keeps the compact shelf).
                        carouselRail(items, section: section)
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
                        .padding(.horizontal, -CYSpacing.lg)
                    }
                } else if model.loading {
                    CYSkeleton().padding(.vertical, CYSpacing.md).frame(maxWidth: .infinity, minHeight: 88)
                }
            }
            // Skeleton, failure and content cross-fade in place; a rail never swaps instantly.
            .cyAnimation(CYMotion.standard, value: failed ? 2 : (items == nil ? 0 : 1))
            .cySectionReveal(order: order, gate: reveal)
        }
    }
    /// Glass carousel over the already-loaded section items. Open goes through the same guarded destination as the shelf cards.
    private func carouselRail(_ items: [HomeFeedItem], section: HomeFeedSection) -> some View {
        let capped = Array(items.prefix(12))
        let slides: [CYCarouselSlide] = capped.map { item in
            CYCarouselSlide(id: item.accessibilityKey, seed: item.name, title: item.name,
                            date: QuestifyCardText.date(item.startDate, sourceTimeZone: sourceTimeZone, locale: locale, displayTimeZone: timeZone),
                            place: item.place, imageURL: QuestifyCardArtwork.safeURL(item.imageURL))
        }
        return CYCarouselRail(phase: .loaded(slides),
                              railLabel: section == .recommended ? "carousel.editorsPicks" : "carousel.upcoming",
                              onOpen: { key in
                                  guard model.canOpen(reader), let item = capped.first(where: { $0.accessibilityKey == key }) else { return }
                                  onDestination(item.id)
                              }) {
            ForEach(items) { item in row(item, section: section.rawValue, style: .hero) }
        }
        .accessibilityIdentifier("homeFeed.carousel.\(section.rawValue)")
    }
    /// Large, plain section title (mini-program `sec-title`): no small-caps grouped-list header.
    private func sectionHeader(_ title: Text) -> some View {
        title
            .font(CYTypography.sectionTitle)
            .foregroundStyle(CYColor.textPrimary)
            .textCase(nil)
            .padding(.top, CYSpacing.xs)
            .accessibilityAddTraits(.isHeader)
    }
    private func row(_ item: HomeFeedItem, section: String, style: CYImageCard.Style? = nil) -> some View {
        Button { if model.canOpen(reader) { onDestination(item.id) } } label: {
            Group {
                if let style { HomeFeedShelfCard(item: item, sourceTimeZone: sourceTimeZone, style: style) } else { HomeFeedCard(item: item, sourceTimeZone: sourceTimeZone) }
            }
            // The tapped card grows into the detail (iOS 18 zoom; iOS 17 keeps the push + entrance). Only the first copy of an item
            // on screen is the source, so duplicates across rails and the stream never fight over one id.
            .cyHeroSourceInherited(item.id, isEnabled: heroNamespace != nil && !heroOwned(by: section == "stream" ? nil : section).contains(item.id))
        }
            .buttonStyle(QuestifyCardButtonStyle())
            .accessibilityIdentifier("homeFeed.\(section).\(item.accessibilityKey)")
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CYSpacing.lg)
        .background(CYColor.bgSurface, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        .cyNightCardDepth(radius: CYRadius.lg)
        .transition(.opacity)
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


/// One thing the "Today" card can point at. Supplied by the host from data it already holds; the feed view never fetches it.
struct HomeTodayCandidate: Equatable {
    var id: String
    var title: String
    var start: Date?
    var place: String?
    var imageURL: URL?
    /// Set when the candidate is a real activity: the Today card then opens the activity detail and zooms into it.
    var activityID: Int? = nil
}

extension HomeTodayCandidate {
    /// Earliest not-yet-used ticket from the wallet read whose start is a real instant. A wall-clock start with no
    /// verified source zone parses to nil and is skipped: an unknown time is never "today", never a guess.
    static func nextTicket(from tickets: [TicketWalletTicket], now: Date) -> HomeTodayCandidate? {
        tickets.compactMap { ticket -> HomeTodayCandidate? in
            guard ticket.status == .ready || ticket.status == .pending, ticket.action == .detail,
                  let start = HomeFeedDate.parse(ticket.startDate, sourceTimeZone: nil),
                  start.timeIntervalSince(now) >= -3 * 3600, start.timeIntervalSince(now) <= 24 * 3600,
                  let title = ticket.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else { return nil }
            let place = ticket.addressName?.trimmingCharacters(in: .whitespacesAndNewlines)
            return HomeTodayCandidate(id: "ticket-\(ticket.id)", title: title, start: start, place: place?.isEmpty == false ? place : nil, imageURL: nil)
        }.min { ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture) }
    }
}

/// Which single thing Explore's first fold shows (ux-strategy W1-6): ticket within 24 h > club event today > "start a roam".
enum HomeTodayChoice: Equatable {
    case ticket(HomeTodayCandidate)
    case clubEvent(HomeTodayCandidate)
    case roam

    /// The activity a club-event Today card opens, when it is one. Tickets and the roam prompt never have one.
    var activityID: Int? {
        if case .clubEvent(let candidate) = self { return candidate.activityID }
        return nil
    }

    /// A ticket counts from 3 h before it starts (already underway) to 24 h ahead. A club event counts on the current calendar day.
    /// Candidates without a start date never win: an unknown time is not "today".
    static func resolve(ticket: HomeTodayCandidate?, clubEvent: HomeTodayCandidate?, now: Date, calendar: Calendar) -> HomeTodayChoice {
        if let ticket, let start = ticket.start {
            let delta = start.timeIntervalSince(now)
            if delta >= -3 * 3600 && delta <= 24 * 3600 { return .ticket(ticket) }
        }
        if let clubEvent, let start = clubEvent.start, calendar.isDate(start, inSameDayAs: now) { return .clubEvent(clubEvent) }
        return .roam
    }
}

/// Full-bleed Today card: the single focal point of the Explore fold. One headline, one meta line, one pill.
struct HomeTodayCard: View {
    let choice: HomeTodayChoice
    var onTicket: (() -> Void)?
    var onClubEvent: (() -> Void)?
    var onStartRoam: (() -> Void)?
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone
    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion
    /// Wave 3 B2: dip 0.985, touch-origin wave, then the action (see `CYWave.swift`).
    @State private var ownWave = CYPressWaveModel()
    /// DEBUG fixtures inject a model so a synthetic finger can drive the card; live screens leave it nil.
    var waveModel: CYPressWaveModel?
    private var wave: CYPressWaveModel { waveModel ?? ownWave }

    private var copy: CYKitCopy { CYKitCopy(locale: locale) }

    private struct Content {
        var eyebrow: String
        var title: String
        var meta: String?
        var pill: String
        var symbol: String
        var imageURL: URL?
        var action: (() -> Void)?
        var id: String
    }

    private var content: Content {
        switch choice {
        case .ticket(let c):
            return Content(eyebrow: copy("Today · Your ticket", "今天 · 你的门票"), title: c.title, meta: meta(c),
                           pill: copy("Show ticket", "出示门票"), symbol: "ticket", imageURL: c.imageURL, action: onTicket, id: "ticket")
        case .clubEvent(let c):
            return Content(eyebrow: copy("Today · Club event", "今天 · 俱乐部活动"), title: c.title, meta: meta(c),
                           pill: copy("See event", "查看活动"), symbol: "person.3", imageURL: c.imageURL, action: onClubEvent, id: "clubEvent")
        case .roam:
            return Content(eyebrow: copy("Today", "今天"), title: copy("Start a roam", "开始一次漫游"),
                           meta: copy("Walk somewhere new and light up the map.", "走去一个新地方，点亮地图"),
                           pill: copy("Start a roam", "开始漫游"), symbol: "figure.walk", imageURL: nil, action: onStartRoam, id: "roam")
        }
    }

    /// time · place, em dash when the time is unknown (never a fake value).
    private func meta(_ c: HomeTodayCandidate) -> String {
        let time = c.start.map { $0.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, locale: locale, timeZone: timeZone)) }
        let place = c.place?.trimmingCharacters(in: .whitespacesAndNewlines)
        return [time ?? "—", (place?.isEmpty ?? true) ? nil : place].compactMap { $0 }.joined(separator: " · ")
    }

    private var isChinese: Bool { locale.identifier.lowercased().hasPrefix("zh") || locale.language.languageCode?.identifier == "zh" }

    var body: some View {
        let c = content
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            // The one light source sits top trailing, away from the text; lantern gold only on the discovery prompt.
            CYTodayMedallion(symbol: c.symbol, lit: c.id == "roam")
                .frame(maxWidth: .infinity, alignment: .trailing)
            Spacer(minLength: CYSpacing.lg)
            Text(verbatim: c.eyebrow)
                .cyEyebrow(isChinese: isChinese)
                .foregroundStyle(.white.opacity(0.78))
            Text(verbatim: c.title)
                .font(CYTypography.pageTitle)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let meta = c.meta {
                Text(verbatim: meta).font(CYTypography.bodyCompact).monospacedDigit().foregroundStyle(.white.opacity(0.82))
            }
            if let action = c.action {
                CYPillButton(verbatim: c.pill, style: .primary, fullWidth: false) {
                    wave.perform(action, waveOn: cyLightAllowed(reduceMotion: reduceMotion))
                }
                    .cyPressWaveExcluded()
                    .padding(.top, CYSpacing.sm)
                    .accessibilityIdentifier("homeFeed.today.action")
            }
        }
        .foregroundStyle(.white)
        .padding(CYSpacing.xl)
        .frame(maxWidth: .infinity, minHeight: 280, alignment: .bottomLeading)
        .background { backdrop(c).cyBackdropParallax() }
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.xl, style: .continuous))
        .cyNightCardDepth(radius: CYRadius.xl)
        .cyPressWave(wave, onTap: c.action)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("homeFeed.today.\(c.id)")
    }

    private func backdrop(_ c: Content) -> some View {
        ZStack {
            CYCoverArt(seed: c.title)
            if let url = c.imageURL, url.scheme?.lowercased() == "https" {
                AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: CYMotion.Duration.standard))) { phase in
                    if let image = phase.image { image.resizable().scaledToFill().transition(.opacity) } else { Color.clear }
                }
            }
            // Indigo dusk at the top, ink (never pure black) at the foot where the text sits.
            LinearGradient(stops: [.init(color: CYNight.indigo.opacity(0.45), location: 0),
                                   .init(color: CYNight.ink0.opacity(0.10), location: 0.35),
                                   .init(color: CYNight.ink0.opacity(0.90), location: 1)],
                           startPoint: .top, endPoint: .bottom)
        }
    }
}

#if DEBUG
#Preview("Today · ticket") {
    HomeTodayCard(choice: .ticket(HomeTodayFixtures.ticket), onTicket: {}).padding(CYSpacing.pageHorizontal).cyDomainPageBackground().themeDomain(.player)
}
#Preview("Today · club event") {
    HomeTodayCard(choice: .clubEvent(HomeTodayFixtures.clubEvent), onClubEvent: {}).padding(CYSpacing.pageHorizontal).cyDomainPageBackground().themeDomain(.player)
}
#Preview("Today · roam") {
    HomeTodayCard(choice: .roam, onStartRoam: {}).padding(CYSpacing.pageHorizontal).cyDomainPageBackground().themeDomain(.player)
}
#Preview("Today · unknown time, roam") {
    HomeTodayCard(choice: HomeTodayChoice.resolve(ticket: HomeTodayFixtures.unknownTime, clubEvent: nil, now: HomeTodayFixtures.now, calendar: .current), onStartRoam: {})
        .padding(CYSpacing.pageHorizontal).cyDomainPageBackground().themeDomain(.player)
}
#endif
