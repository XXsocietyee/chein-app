import SwiftUI
import UIKit

/// Embed in the caller's NavigationStack. The caller owns existing detail destinations.
@MainActor struct HomeFeedView: View {
    let reader: any HomeFeedReading
    var unavailableMessageKey: String? = nil
    /// Supply only from verified backend configuration, never language/device locale.
    var sourceTimeZone: TimeZone? = nil
    var viewerNickname: String? = nil
    var viewerAvatar: String? = nil
    var viewerIsMerchant: Bool = false
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
    /// 我的地盘 rail (City Monopoly, round-1 Q1): sits 24 pt under 编辑精选. Nil hides it.
    var cityRail: AnyView? = nil
    let onDestination: (HomeFeedDestination) -> Void
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.timeZone) private var timeZone
    @Environment(\.cyHeroNamespace) private var heroNamespace
    @Environment(\.openURL) private var openURL
    @StateObject private var model = HomeFeedModel()
    @State private var kind: HomeFeedKind = .topics
    @State private var keyword = ""
    @State private var categoryID: Int?
    @State private var submittedKeyword = ""
    @State private var localSelectedCity: String? = nil
    @State private var localIsNationwide: Bool = false
    private var hasHeroHeader: Bool { showsHeroBanners || viewerNickname != nil || selectedCity != nil || onActionBanner != nil }
    private var query: HomeFeedQuery { HomeFeedQuery(kind: kind, keyword: submittedKeyword, categoryID: categoryID) }
    var body: some View {
        let binding = model.bind(reader, available: unavailableMessageKey == nil)
        let permit = model.permit(reader)
        Group {
            if !reader.isConfigured || unavailableMessageKey != nil {
                // Offline state. Lookup uses the interface language, not the region locale,
                // so zh-Hans does not keep the English kit sentences.
                let resource = CYKitCopy(locale: locale).resourceLocale
                ContentUnavailableView {
                    Label {
                        Text(verbatim: appLocalized("homeFeed.unavailable", locale: resource))
                    } icon: {
                        Image(systemName: "wifi.slash")
                    }
                } description: {
                    Text(verbatim: appLocalized(String.LocalizationValue(stringLiteral: unavailableMessageKey ?? "auth.notConfigured"), locale: resource))
                }
                    .accessibilityElement(children: .combine) // one static text, as the system placeholder was: UITests and VoiceOver read a single state
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("homeFeed.configurationUnavailable")
            } else if !model.matches(reader) {
                ProgressView("homeFeed.loading")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: CYSpacing.xxl) {
                    // Design hand-off r1 PL-22: what the player came for first — header and city context, 编辑精选,
                    // 附近活动 — then the promo swiper as one band, then 即将上线 and the tabbed feed.
                    // polish-d-r1: header, consent, offline notice and 编辑精选 are one group at `sm` rhythm. The 更多玩法
                    // menu already keeps a 44 pt target below its text, so the `xxl` section gap read as a hole.
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        if hasHeroHeader {
                            HomeHeroHeaderSectionView(
                                nickname: viewerNickname,
                                selectedCity: localSelectedCity ?? selectedCity,
                                isNationwide: localIsNationwide,
                                isMerchantViewer: viewerIsMerchant,
                                avatarSource: viewerAvatar,
                                onSelectCity: onSelectCity != nil ? { city, nationwide in
                                    localSelectedCity = city
                                    localIsNationwide = nationwide
                                    onSelectCity?(city, nationwide)
                                } : nil,
                                onOpenUnifiedSearch: onOpenUnifiedSearch
                            ) { banner in
                                // R7-PC-A1-2: a host that routes banners opens the activity list; without one, show the 活动 stream.
                                if let onActionBanner { onActionBanner(banner) } else if banner.id == "activity_list" { kind = .activities }
                            }
                            .pageTemplateReadingOrder(80)
                        }
                        if let consent = cityLocationConsent {
                            HomeCityLocationConsentCard(onAgree: consent.agree, onDecline: consent.decline)
                                .pageTemplateReadingOrder(70)
                        }
                        CYScreenOfflineWriteBanner(routes: ["/api/compliance/consents"])
                        if feedDown {
                            // R1 error state (166:3280): when every rail and the feed failed, one inline error under the
                            // header, with one retry for all of it; no section titles with nothing under them, no tabs.
                            retry(Text("homeFeed.feedFailed"), id: "feed") {
                                for section in HomeFeedSection.allCases { model.schedule(.section(section), reader: reader, permit: permit) }
                                model.schedule(.page, reader: reader, permit: permit)
                            }
                            .padding(.top, CYSpacing.sm)
                            .pageTemplateReadingOrder(60)
                        }
                        // Mini-program order: 编辑精选, 附近活动, 即将上线, then 主题 / 活动.
                        feedSection(.recommended, order: 2).pageTemplateReadingOrder(60)
                        if let cityRail { cityRail.pageTemplateReadingOrder(55) }
                    }
                    feedSection(.nearby, order: 3).pageTemplateReadingOrder(50)
                    if !feedDown, model.bannerFailed || !model.banners.isEmpty {
                        bannerSection
                            .pageTemplateReadingOrder(45)
                    }
                    feedSection(.upcoming, order: 4).pageTemplateReadingOrder(40)
                    if !feedDown {
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        // Source pages/index feed tabs are 主题 / 活动: a system segmented picker.
                        Picker(selection: $kind) {
                            Text("homeFeed.topics").tag(HomeFeedKind.topics)
                            Text("homeFeed.activities").tag(HomeFeedKind.activities)
                        } label: {
                            Text("homeFeed.content")
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("homeFeed.kind")
                        .accessibilityLabel(Text("homeFeed.content"))
                        ForEach(Array(model.pagination.items.enumerated()), id: \.element.id) { index, item in
                            row(item, section: "stream")
                        }
                        if model.pageFailed { retry(Text(LocalizedStringKey("mpfresh.home.streamFailed." + (kind == .topics ? "topics" : "activities") + (model.pagination.items.isEmpty ? ".first" : ".more")), tableName: "MpFresh"), id: "page") { model.schedule(.page, reader: reader, permit: permit) } }
                        if model.loadingPage {
                            ProgressView("homeFeed.loading")
                                .frame(maxWidth: .infinity)
                        }
                        else if !model.pageFailed && model.pagination.items.isEmpty {
                            // Source empty titles: 暂时没有主题 / 暂时没有活动. The keyword hint stays only after a search.
                            ContentUnavailableView {
                                Label {
                                    (kind == .topics ? Text("homeFeed.topicsEmpty") : Text("homeFeed.activitiesEmpty"))
                                        .accessibilityIdentifier("homeFeed.empty")
                                } icon: {
                                    Image(systemName: "magnifyingglass")
                                }
                            } description: {
                                if !submittedKeyword.isEmpty { Text("homeFeed.emptyHint") }
                            }
                        }
                        if model.pagination.hasMore && !model.loadingPage && !model.pageFailed {
                            // R7-PC-A1-6 (r1 PC-A-1-11): MP pages on reach-bottom. The sentinel loads the next page when it
                            // scrolls into view; a failed page keeps its retry row above.
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .onAppear { model.schedule(.page, reader: reader, permit: permit) }
                                .accessibilityLabel(Text("homeFeed.loading"))
                                .accessibilityIdentifier("homeFeed.loadMore")
                        } else if !model.pagination.hasMore && !model.loadingPage && !model.pageFailed && !model.pagination.items.isEmpty {
                            Text(verbatim: HomeIndexParityPresentation.noMoreFooterCopy(locale: locale))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .accessibilityIdentifier("homeFeed.noMoreFooter")
                        }
                    }
                    .pageTemplateReadingOrder(30)
                    }
                    todayCard.pageTemplateReadingOrder(20)
                    // Mini-program store card (city pass entry): one feed card, never a paywall.
                    MPPassExploreCard().pageTemplateReadingOrder(15)
                    if !continuationCards.isEmpty {
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
                        .pageTemplateReadingOrder(10)
                    }
                    }
                    .padding(.horizontal, CYSpacing.pageHorizontal)
                    .padding(.top, CYSpacing.lg)
                    .padding(.bottom, CYSpacing.jumbo)
                }
                .modifier(HomeFeedNavigationSearch(text: $keyword, enabled: !hasHeroHeader, usesDrawer: onOpenUnifiedSearch != nil))
                .onSubmit(of: .search) { submitFeedSearch() }
                .onChange(of: keyword) { _, value in if value.isEmpty { submittedKeyword = "" } }
                .onChange(of: query) { _, value in model.schedule(.query(value), reader: reader, permit: permit) }
                // System pull to refresh. Loaded rails stay on screen and change in place.
                .refreshable { await model.reload(reader: reader, query: query) }
            }
        }
        // Design hand-off r1 PL-11: one root header. The large title is the tab label (首页); the greeting is its
        // subtitle line, and the feed scrolls under the bar (the large title collapses on scroll).
        .appNavigationTitle("homeFeed.title")
        .navigationBarTitleDisplayMode(.large)
        .task(id: binding) { await model.resume(reader: reader, query: query, available: unavailableMessageKey == nil, expectedBinding: binding) }
        .onDisappear { model.suspend() }
        .cyDomainScreen(.player)
    }
    @ViewBuilder private var bannerSection: some View {
        let permit = model.permit(reader)
        if model.bannerFailed { retry(Text("homeFeed.bannersError"), id: "banners") { model.schedule(.banners, reader: reader, permit: permit) } }
        if !model.banners.isEmpty {
            // Mirrors the mini-program hero swiper: full-width covers, paged horizontally (system paging scroll view).
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: CYSpacing.md) {
                    ForEach(model.banners) { banner in
                        bannerSlide(banner).containerRelativeFrame(.horizontal)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
        }
    }
    /// One swiper slide: the cover, then the optional caption underneath in system type.
    @ViewBuilder private func bannerSlide(_ banner: DiscoveryBanner) -> some View {
        let caption = banner.contents.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        let slide = VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Color.clear
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .overlay {
                    if let url = QuestifyCardArtwork.safeURL(banner.picUrl) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image { image.resizable().scaledToFill() } else { Rectangle().fill(.fill.secondary) }
                        }
                    } else {
                        MPAsset.BannerCover.recoHero.resizable().scaledToFill()
                    }
                }
                .clipped()
            if let caption {
                Text(verbatim: caption).font(.headline).foregroundStyle(.primary).lineLimit(2)
            }
        }
        if let destination = banner.destination {
            Button {
                guard model.canOpen(reader) else { return }
                switch destination { case .activity(let id): onDestination(.activity(id)); case .topic(let id): onDestination(.topic(id)) }
            } label: { slide }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("homeFeed.openFeatured"))
        } else {
            slide.accessibilityHidden(true)
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
    /// loading and failure state. Source D5 (hengyin 8718d1e22): a rail that loaded with nothing in it disappears
    /// with its title (编辑精选, 附近活动 and 即将上线 alike); there is no in-section empty line any more.
    @ViewBuilder private func feedSection(_ section: HomeFeedSection, order: Int) -> some View {
        let permit = model.permit(reader)
        let items = model.sections[section]
        let failed = model.failedSections.contains(section)
        let hidesEmpty = !failed && (items?.isEmpty ?? !model.loading)
        if !hidesEmpty, !feedDown {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                switch section {
                case .recommended:
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        sectionHeader(Text("homeFeed.editorsPicks"))
                        // polish-d-r1: the footnote is the rail's subtitle, above the carousel, so it never sits under the tab bar.
                        if let items, !items.isEmpty {
                            Text("homeFeed.editorsPicksFootnote")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("homeFeed.editorsPicksFootnote")
                            if model.loading, !failed {
                                // Also above the carousel, so it never lands under the tab bar.
                                Text("homeFeed.updating.recommended")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .accessibilityIdentifier("homeFeed.updating.recommended")
                            }
                        }
                    }
                case .nearby: sectionHeader(Text("homeFeed.nearbyActivities"))
                case .upcoming: sectionHeader(Text("homeFeed.upcoming"))
                }
                if failed {
                    // Source names the failed rail: 编辑精选加载失败 / 附近活动加载失败 / 即将上线加载失败.
                    retry(Text(LocalizedStringKey("mpfresh.home.sectionFailed." + section.rawValue), tableName: "MpFresh"), id: section.rawValue) { model.schedule(.section(section), reader: reader, permit: permit) }
                } else if let items {
                    if dynamicTypeSize.isAccessibilitySize {
                        ForEach(items) { item in row(item, section: section.rawValue, style: .hero) }
                    } else if section != .nearby {
                        // Editor picks and upcoming: a system horizontal shelf (App Store style).
                        carouselRail(items, section: section)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(alignment: .top, spacing: CYSpacing.md) {
                                ForEach(items) { item in
                                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                        row(item, section: section.rawValue, style: .shelf)
                                        // R7-PC-A1-5: MP 附近活动 `进行中` badge, as a tinted label under the card.
                                        if item.isLive(at: Date(), sourceTimeZone: sourceTimeZone) { HomeFeedLiveChip() }
                                    }
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.viewAligned)
                    }
                } else if model.loading {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 88)
                }
                // Mini-program `正在更新…` line while a loaded rail refreshes, and the editor-picks footnote.
                if model.loading, let items, !items.isEmpty, !failed, section != .recommended {
                    Group {
                        switch section {
                        case .recommended: Text("homeFeed.updating.recommended")
                        case .nearby: Text("homeFeed.updating.nearby")
                        case .upcoming: Text("homeFeed.updating.upcoming")
                        }
                    }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("homeFeed.updating.\(section.rawValue)")
                }
            }
        }
    }
    /// Club label, first category and status in one secondary line; a repeated value shows once.
    static func recoCaption(_ item: HomeFeedItem) -> String {
        var parts: [String] = []
        for part in [item.clubLabel].compactMap({ $0 }) + recoChips(item) where !parts.contains(part) { parts.append(part) }
        return parts.joined(separator: " · ")
    }
    static func recoChips(_ item: HomeFeedItem) -> [String] {
        var chips: [String] = []
        if let first = item.categoryNames.first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) { chips.append(first) }
        if let status = item.statusLabel?.trimmingCharacters(in: .whitespaces), !status.isEmpty { chips.append(status) }
        return chips
    }
    /// Horizontal shelf over the already-loaded section items. Open goes through the same guarded destination as the
    /// nearby cards. 即将上线 keeps the source countdown (还剩N天 / 还剩N小时 / 已开始) under each card.
    private func carouselRail(_ items: [HomeFeedItem], section: HomeFeedSection) -> some View {
        let capped = Array(items.prefix(12))
        return ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: CYSpacing.md) {
                ForEach(capped) { item in
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        row(item, section: section.rawValue, style: .shelf)
                        // R7-PC-A1-3: MP index.wxml:107-120 — club label, first category and status on 编辑精选.
                        if section == .recommended {
                            let caption = Self.recoCaption(item)
                            if !caption.isEmpty {
                                Text(verbatim: caption)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .accessibilityIdentifier("homeFeed.reco.caption.\(item.accessibilityKey)")
                            }
                        }
                        if section == .upcoming, let countdown = upcomingCountdown(item) {
                            Text(verbatim: countdown)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("homeFeed.upcoming.countdown.\(item.accessibilityKey)")
                        }
                    }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(section == .recommended ? Text("carousel.editorsPicks") : Text("carousel.upcoming"))
        .accessibilityIdentifier("homeFeed.carousel.\(section.rawValue)")
    }
    /// Source 即将上线 countdown (hengyin 07608d68a, j1 F23): 还剩N天 / 还剩N小时 / 已开始. Unknown start shows nothing.
    private func upcomingCountdown(_ item: HomeFeedItem) -> String? {
        guard let start = HomeFeedDate.parse(item.startDate, sourceTimeZone: sourceTimeZone) else { return nil }
        let seconds = start.timeIntervalSinceNow
        if seconds <= 0 { return String(localized: LocalizedStringResource("mpfresh.home.countdown.started", table: "MpFresh", locale: locale)) }
        let days = Int(seconds / 86_400)
        if days >= 1 { return String(localized: LocalizedStringResource("mpfresh.home.countdown.days \(days)", table: "MpFresh", locale: locale)) }
        let hours = max(1, Int(seconds / 3_600))
        return String(localized: LocalizedStringResource("mpfresh.home.countdown.hours \(hours)", table: "MpFresh", locale: locale))
    }
    /// Plain section title (mini-program `sec-title`) in the system title style.
    private func sectionHeader(_ title: Text) -> some View {
        title
            .font(.title2.bold())
            .foregroundStyle(.primary)
            .accessibilityAddTraits(.isHeader)
    }
    /// MP index.wxml default covers: 编辑精选 reco-hero.jpg (:105), 附近活动 / 即将上线 route_city_cover.png (:151/:188),
    /// the stream home-route-city-placeholder.jpg (:216/:253).
    static func fallbackCover(_ section: String) -> CYCarouselFallback {
        switch section {
        case HomeFeedSection.recommended.rawValue: return .recoHero
        case HomeFeedSection.nearby.rawValue, HomeFeedSection.upcoming.rawValue: return .routeCityCover
        default: return .homeRouteCityPlaceholder
        }
    }
    private func row(_ item: HomeFeedItem, section: String, style: CYImageCard.Style? = nil) -> some View {
        // R7-PC-A1-4 (MP index.wxml:219-239 `onAddressTap`): on a stream card the 地点 row is its own visible tap target
        // below the card button (a button nested in the card label cannot take the tap). Long-press / VoiceOver stay.
        let placeURL = style == nil ? HomeFeedMapsLink.url(for: item.place) : nil
        return VStack(alignment: .leading, spacing: CYSpacing.xs) {
        Button { if model.canOpen(reader) { onDestination(item.id) } } label: {
            Group {
                if let style {
                    HomeFeedShelfCard(item: item, sourceTimeZone: sourceTimeZone, style: style, fallback: Self.fallbackCover(section), showsFeaturedFacts: section == HomeFeedSection.recommended.rawValue)
                } else {
                    HomeFeedCard(item: item, sourceTimeZone: sourceTimeZone, showsPlace: placeURL == nil)
                }
            }
            // The tapped card grows into the detail (iOS 18 zoom; iOS 17 keeps the push + entrance). Only the first copy of an item
            // on screen is the source, so duplicates across rails and the stream never fight over one id.
            .cyHeroSourceInherited(item.id, isEnabled: heroNamespace != nil && !heroOwned(by: section == "stream" ? nil : section).contains(item.id))
        }
            .buttonStyle(.plain)
            .pageTemplateGroupedCard(label: feedCardLabel(item, includeFeaturedFacts: section == HomeFeedSection.recommended.rawValue), traits: .isButton)
            .modifier(HomeFeedOpenPlaceInMaps(url: HomeFeedMapsLink.url(for: item.place), openURL: openURL))
            .accessibilityIdentifier("homeFeed.\(section).\(item.accessibilityKey)")
            if let placeURL, let place = item.place {
                HomeFeedPlaceLinkRow(place: place, url: placeURL, openURL: openURL)
                    .accessibilityIdentifier("homeFeed.\(section).\(item.accessibilityKey).place")
            }
        }
    }
    /// One label for the grouped feed card: name, then the price, time, and place lines already on the card.
    /// 编辑精选 also speaks Beta 试玩, the category tags, the status and the club when the list row has them.
    private func feedCardLabel(_ item: HomeFeedItem, includeFeaturedFacts: Bool = false) -> Text {
        let price: Text
        if let amount = HomeFeedMoney.plain(item.amount) {
            price = Text("playx.finishRoute.priceFrom \(amount)")
        } else {
            price = PageTemplateVoiceOver.spoken(HomeFeedSurfaceState.unknownText, locale: locale)
        }
        let time: Text
        if let date = QuestifyCardText.date(item.startDate, sourceTimeZone: sourceTimeZone, locale: locale, displayTimeZone: timeZone) {
            time = Text(verbatim: date)
        } else {
            time = Text("homeFeed.openEnded")
        }
        let place = item.place?.trimmingCharacters(in: .whitespacesAndNewlines)
        let placeText = PageTemplateVoiceOver.spoken((place?.isEmpty == false ? place! : HomeFeedSurfaceState.unknownText), locale: locale)
        var label = Text(verbatim: item.name) + Text(verbatim: ", ")
            + Text("homeFeed.status.price") + Text(verbatim: " ") + price + Text(verbatim: ", ")
            + Text("homeFeed.status.time") + Text(verbatim: " ") + time + Text(verbatim: ", ")
            + Text("homeFeed.place") + Text(verbatim: " ") + placeText
        if includeFeaturedFacts {
            if item.isBeta { label = label + Text(verbatim: ", ") + Text("topic.source.betaBadge") }
            for tag in item.featuredCategoryTags { label = label + Text(verbatim: ", ") + Text(verbatim: tag) }
            if let status = item.featuredStatusText { label = label + Text(verbatim: ", ") + Text(verbatim: status) }
            if let club = item.featuredClubText { label = label + Text(verbatim: ", ") + Text(verbatim: club) }
        }
        return label
    }
    /// Every rail and the first feed page failed and nothing is on screen: the page shows one inline error (166:3280).
    private var feedDown: Bool {
        HomeFeedSection.allCases.allSatisfy { model.failedSections.contains($0) && (model.sections[$0]?.isEmpty ?? true) }
            && model.pageFailed && model.pagination.items.isEmpty && !model.loading && !model.loadingPage
    }

    private func retry(_ message: Text, id: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Label { message } icon: { Image(systemName: "exclamationmark.triangle").accessibilityHidden(true) }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("homeFeed.retry", action: action)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("homeFeed.retry.\(id)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    private func submitFeedSearch() {
        submittedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Keeps the system search only when the navigation bar is showing. The hero top bar owns search
/// when the bar is hidden, so the feed does not draw a second field.
private struct HomeFeedNavigationSearch: ViewModifier {
    @Binding var text: String
    var enabled: Bool
    var usesDrawer: Bool
    func body(content: Content) -> some View {
        if enabled {
            content.searchable(
                text: $text,
                placement: usesDrawer ? .navigationBarDrawer(displayMode: .automatic) : .automatic,
                prompt: Text("homeFeed.search")
            )
        } else {
            content
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
    /// Round 4 image parity: the MP default differs per rail (stream / 附近活动 / 即将上线 / 编辑精选).
    var fallback: CYCarouselFallback = .homeRouteCityPlaceholder
    /// 编辑精选 only. Nearby and upcoming leave this off.
    var showsFeaturedFacts: Bool = false
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone
    var body: some View {
        let date = QuestifyCardText.date(item.startDate, sourceTimeZone: sourceTimeZone, locale: locale, displayTimeZone: timeZone)
        // Currency + 起/From come from the shared price key; unknown price shows an em dash, never 0.
        let price = HomeFeedMoney.plain(item.amount).map { appLocalized("playx.finishRoute.priceFrom \($0)", locale: locale) } ?? "—"
        let line = [QuestifyCardText.metaLine(date: date, place: item.place), price].compactMap { $0 }.joined(separator: " · ")
        let card = CYImageCard(LocalizedStringKey(item.name), metaText: line,
                    imageURL: QuestifyCardArtwork.safeURL(item.imageURL), style: style)
            // MP asset (index.wxml:216): a card without a cover shows `home-route-city-placeholder.jpg`.
            .fallbackArtwork(fallback.image)
            .cachingFeedImage()
        if showsFeaturedFacts, HomeFeedFeaturedFacts.hasAny(item) {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                card
                HomeFeedFeaturedFacts(item: item)
            }
        } else {
            card
        }
    }
}

/// Beta 试玩, category, status and club already present on an 编辑精选 topic-list row.
/// Each line is omitted when that field is missing. No zero and no placeholder.
struct HomeFeedFeaturedFacts: View {
    let item: HomeFeedItem
    static func hasAny(_ item: HomeFeedItem) -> Bool {
        item.isBeta || !item.featuredCategoryTags.isEmpty || item.featuredStatusText != nil || item.featuredClubText != nil
    }
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            if item.isBeta {
                Text("topic.source.betaBadge")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tint)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("homeFeed.featured.beta")
            }
            ForEach(Array(item.featuredCategoryTags.enumerated()), id: \.offset) { index, name in
                Text(verbatim: name)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("homeFeed.featured.category.\(index)")
            }
            if let status = item.featuredStatusText {
                Text(verbatim: status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("homeFeed.featured.status")
            }
            if let club = item.featuredClubText {
                Text(verbatim: club)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("homeFeed.featured.club")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("homeFeed.featured.facts")
    }
}

struct HomeFeedCard: View {
    let item: HomeFeedItem
    private let sourceTimeZone: TimeZone?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone
    /// False when the host draws the 地点 as its own tap target below the card (R7-PC-A1-4).
    private let showsPlace: Bool
    init(item: HomeFeedItem, sourceTimeZone: TimeZone? = nil, showsPlace: Bool = true) {
        self.item = item
        self.sourceTimeZone = sourceTimeZone
        self.showsPlace = showsPlace
    }
    private var typeSymbol: String {
        switch item { case .activity: return "figure.walk"; case .topic: return "map" }
    }
    private var eyebrow: LocalizedStringKey {
        switch item { case .activity: return "homeFeed.activities"; case .topic: return "homeFeed.topics" }
    }
    /// Mini-program `v2-fcard` + `v2-status`: cover and title, then 价格 / 时间 / 地点.
    /// A missing price or place is an em dash. A missing time is the source fallback 长期开放.
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            // R7-PC-A1-4: MP `feedTypeLabel` eyebrow above the card.
            Text(eyebrow)
                .font(.footnote)
                .foregroundStyle(.secondary)
            QuestifyImageEntityCard(imageSource: safeImageSource, title: item.name, fallbackSymbol: typeSymbol,
                                    minimumHeight: dynamicTypeSize.isAccessibilitySize ? 300 : 260) {
                EmptyView()
            }
            // Round 4 image parity: MP stream card default (index.wxml:216/253).
            .fallbackArtwork(MPAsset.BannerCover.homeRouteCityPlaceholder)
            .cachingFeedImage()
            // R7-PC-A1-3: MP stream card shows ≤2 category chips (`feedTags`, pages/index/index.wxml:216-253).
            if !item.feedTags.isEmpty {
                HStack(spacing: CYSpacing.xs) {
                    ForEach(Array(item.feedTags.enumerated()), id: \.offset) { _, tag in
                        Text(verbatim: tag)
                            .font(.footnote)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                priceRow
                timeRow
                if showsPlace { placeRow }
            }
            .accessibilityIdentifier("homeFeed.stream.status")
        }
    }
    private var priceRow: some View {
        statusRow("homeFeed.status.price", tabular: true) {
            if let amount = HomeFeedMoney.plain(item.amount) {
                Text("playx.finishRoute.priceFrom \(amount)")
            } else {
                Text(verbatim: HomeFeedSurfaceState.unknownText)
            }
        }
    }
    private var timeRow: some View {
        statusRow("homeFeed.status.time") {
            if let date = QuestifyCardText.date(item.startDate, sourceTimeZone: sourceTimeZone, locale: locale, displayTimeZone: timeZone) {
                Text(verbatim: date)
            } else {
                Text("homeFeed.openEnded")
            }
        }
    }
    private var placeRow: some View {
        statusRow("homeFeed.place") {
            if let place = item.place?.trimmingCharacters(in: .whitespacesAndNewlines), !place.isEmpty {
                Text(verbatim: place)
            } else {
                Text(verbatim: HomeFeedSurfaceState.unknownText)
            }
        }
    }
    private func statusRow<Value: View>(_ label: LocalizedStringKey, tabular: Bool = false, @ViewBuilder value: () -> Value) -> some View {
        // System label/value row; Dynamic Type stacks it on its own.
        LabeledContent {
            value()
                .monospacedDigit()
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        } label: {
            Text(label).foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
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
    /// Kept for DEBUG fixtures that still pass a model; the native card uses the system button press.
    var waveModel: CYPressWaveModel?

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

    var body: some View {
        let c = content
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            // Optional cover as one plain header image.
            if let url = c.imageURL, url.scheme?.lowercased() == "https" {
                Color.clear
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                    .overlay {
                        PlayerFeedRemoteImage(url: url, maxPixel: 1200, placeholder: { Color.clear }, failure: { Color.clear })
                    }
                    .clipped()
                    .accessibilityHidden(true)
            }
            Label(c.eyebrow, systemImage: c.symbol)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(verbatim: c.title)
                .font(.title2.bold())
                .foregroundStyle(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let meta = c.meta {
                Text(verbatim: meta).font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
            }
            if let action = c.action {
                Button(action: action) {
                    Text(verbatim: c.pill)
                }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, CYSpacing.xs)
                    .accessibilityIdentifier("homeFeed.today.action")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pageTemplateGroupedCard(label: todayLabel(c), traits: c.action == nil ? .isStaticText : .isButton)
        .accessibilityIdentifier("homeFeed.today.\(c.id)")
    }

    private func todayLabel(_ c: Content) -> Text {
        var label = Text(verbatim: c.eyebrow) + Text(verbatim: ", ") + Text(verbatim: c.title)
        if let meta = c.meta {
            label = label + Text(verbatim: ", ") + PageTemplateVoiceOver.spoken(meta, locale: locale)
        }
        label = label + Text(verbatim: ", ") + Text(verbatim: c.pill)
        return label
    }
}

#if DEBUG
#Preview("Today · ticket") {
    HomeTodayCard(choice: .ticket(HomeTodayFixtures.ticket), onTicket: {}).padding(CYSpacing.pageHorizontal).themeDomain(.player)
}
#Preview("Today · club event") {
    HomeTodayCard(choice: .clubEvent(HomeTodayFixtures.clubEvent), onClubEvent: {}).padding(CYSpacing.pageHorizontal).themeDomain(.player)
}
#Preview("Today · roam") {
    HomeTodayCard(choice: .roam, onStartRoam: {}).padding(CYSpacing.pageHorizontal).themeDomain(.player)
}
#Preview("Today · unknown time, roam") {
    HomeTodayCard(choice: HomeTodayChoice.resolve(ticket: HomeTodayFixtures.unknownTime, clubEvent: nil, now: HomeTodayFixtures.now, calendar: .current), onStartRoam: {})
        .padding(CYSpacing.pageHorizontal).themeDomain(.player)
}
#endif

/// MP 附近活动 `进行中` badge (R7-PC-A1-5).
struct HomeFeedLiveChip: View {
    var body: some View {
        Label("homeFeed.live", systemImage: "play.fill")
            .labelStyle(.titleAndIcon)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tint)
            .accessibilityIdentifier("homeFeed.liveChip")
    }
}

/// MP `onAddressTap` (open-address.js): the 地点 opens the place in Maps. The feed has no coordinates, so the address
/// is the query (R7-PC-A1-4).
enum HomeFeedMapsLink {
    static func url(for place: String?) -> URL? {
        guard let place = place?.trimmingCharacters(in: .whitespacesAndNewlines), !place.isEmpty,
              place != HomeFeedSurfaceState.unknownText else { return nil }
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [URLQueryItem(name: "q", value: place)]
        return components?.url
    }
}

/// R7-PC-A1-4: the stream card's 地点 line as a visible button (MP `onAddressTap`, open-address.js), laid out like the
/// card's other status rows, with the place in the brand tint and a pin.
struct HomeFeedPlaceLinkRow: View {
    let place: String
    let url: URL
    let openURL: OpenURLAction
    var body: some View {
        Button { openURL(url) } label: {
            LabeledContent {
                Label(place, systemImage: "mappin.and.ellipse")
                    .foregroundStyle(.tint)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            } label: {
                Text("homeFeed.place").foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("accountCollection.coupon.openInMaps"))
        .accessibilityValue(Text(verbatim: place))
    }
}

/// Long-press 在地图中打开 (and the matching VoiceOver action) on a feed card with an address.
struct HomeFeedOpenPlaceInMaps: ViewModifier {
    let url: URL?
    let openURL: OpenURLAction
    func body(content: Content) -> some View {
        if let url {
            content
                .contextMenu {
                    Button("accountCollection.coupon.openInMaps", systemImage: "map") { openURL(url) }
                }
                .accessibilityAction(named: Text("accountCollection.coupon.openInMaps")) { openURL(url) }
        } else {
            content
        }
    }
}

/// Owner decision 9 (11-24): money reads with two decimals through the shared `MoneyDisplay` (¥12.50). Unknown or
/// negative stays nil (the card says "—", never 0).
enum HomeFeedMoney {
    static func plain(_ value: Decimal?) -> String? {
        guard let value, value >= 0 else { return nil }
        return MoneyDisplay.plain(value)
    }
}
