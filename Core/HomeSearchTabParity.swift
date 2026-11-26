import Foundation

// MARK: - Home Index Parity (`pages/index/index`)

/// Presentation rules for the mini-program Home screen (`pages/index/index`).
public enum HomeIndexParityPresentation {
    public static func isEnglish(_ locale: Locale) -> Bool {
        let code = (locale.language.languageCode?.identifier ?? locale.identifier).lowercased()
        return code.hasPrefix("en")
    }

    /// Shelf identifiers matching the mini-program home page sections.
    public enum ShelfKind: String, CaseIterable, Hashable, Sendable {
        case featuredRoutes
        case upcomingActivities
        case popularTopics
        case readyMadeTemplates

        /// Mini-program section header title.
        public var title: String {
            title(locale: Locale(identifier: "zh-Hans"))
        }

        public func title(locale: Locale) -> String {
            if HomeIndexParityPresentation.isEnglish(locale) {
                switch self {
                case .featuredRoutes: return "Featured Routes"
                case .upcomingActivities: return "Upcoming Activities"
                case .popularTopics: return "Popular Topics"
                case .readyMadeTemplates: return "Ready-Made Templates"
                }
            }
            switch self {
            case .featuredRoutes: return "精选路线"
            case .upcomingActivities: return "近期活动"
            case .popularTopics: return "热门主题"
            case .readyMadeTemplates: return "现成玩法"
            }
        }

        /// Optional subtitle or action hint shown alongside the shelf header.
        public var actionHint: String {
            actionHint(locale: Locale(identifier: "zh-Hans"))
        }

        public func actionHint(locale: Locale) -> String {
            if HomeIndexParityPresentation.isEnglish(locale) {
                switch self {
                case .featuredRoutes: return "View All"
                case .upcomingActivities: return "More"
                case .popularTopics: return "All Topics"
                case .readyMadeTemplates: return "Explore"
                }
            }
            switch self {
            case .featuredRoutes: return "查看全部"
            case .upcomingActivities: return "更多活动"
            case .popularTopics: return "全部主题"
            case .readyMadeTemplates: return "去挑选"
            }
        }
    }

    /// Fixed action banners shown in the mini-program hero carousel.
    public struct ActionBanner: Equatable, Hashable, Sendable, Identifiable {
        public let id: String
        public let title: String
        public let routePath: String

        public init(id: String, title: String, routePath: String) {
            self.id = id
            self.title = title
            self.routePath = routePath
        }

        public func title(locale: Locale) -> String {
            guard HomeIndexParityPresentation.isEnglish(locale) else { return title }
            switch id {
            case "club_apply": return "Become a Club"
            case "merchant_apply": return "Become a Merchant"
            case "activity_list": return "Join Activities with Friends"
            case "mini_games": return "Mini games"
            default: return title
            }
        }
    }

    public static let defaultCityFallback = "选择城市"
    public static let nationwideCityLabel = "全国"
    public static let defaultTravelerNickname = "旅人"

    public static let recommendedTopicsTitle = "推荐主题"
    public static let nearbyActivitiesTitle = "附近活动"
    public static let upcomingActivitiesTitle = "即将上线"
    public static let topicsFeedTabTitle = "主题"
    public static let activitiesFeedTabTitle = "活动"

    public static let emptyStateTitle = "暂无内容"
    public static let emptyStateHint = "切换城市或稍后再来看看"
    public static let loadingCopy = "加载中..."
    public static let errorCopy = "加载失败，请点击重试"
    public static let retryButtonTitle = "重试"
    public static let noMoreFooterCopy = "· 没有更多了 ·"

    public static func emptyStateTitle(locale: Locale) -> String {
        isEnglish(locale) ? "No content yet" : emptyStateTitle
    }

    public static func emptyStateHint(locale: Locale) -> String {
        isEnglish(locale) ? "Switch city or check back later" : emptyStateHint
    }

    public static func loadingCopy(locale: Locale) -> String {
        isEnglish(locale) ? "Loading..." : loadingCopy
    }

    public static func errorCopy(locale: Locale) -> String {
        isEnglish(locale) ? "Failed to load. Tap to retry" : errorCopy
    }

    public static func retryButtonTitle(locale: Locale) -> String {
        isEnglish(locale) ? "Retry" : retryButtonTitle
    }

    public static func noMoreFooterCopy(locale: Locale) -> String {
        isEnglish(locale) ? "· No more items ·" : noMoreFooterCopy
    }

    public static func continuationSectionTitle(locale: Locale = Locale(identifier: "zh-Hans")) -> String {
        isEnglish(locale) ? "Continue Game / Continue Exploration" : "继续游戏 / 继续探索"
    }

    public static let fixedActionBanners: [ActionBanner] = [
        ActionBanner(id: "club_apply", title: "成为俱乐部", routePath: "pages/club/apply"),
        ActionBanner(id: "merchant_apply", title: "成为商家", routePath: "pages/merchant/apply"),
        ActionBanner(id: "activity_list", title: "和朋友报名活动", routePath: "pages/activity/list")
    ]

    /// Lane G: the fixed banners the player build shows. `成为商家` (merchant onboarding) is hidden in Release.
    public static var playerActionBanners: [ActionBanner] {
        fixedActionBanners.filter { !PlayerLaunch.isHidden(page: $0.routePath) }
    }

    /// E2E-20261113b: the discoverable external HTML game entry. Shown only where the external-games switch is open.
    public static let miniGamesBanner = ActionBanner(id: "mini_games", title: "小游戏", routePath: "native/mini-games")

    /// Continuation card kind for Home (`play/run-session/list` vs `registration/my-joined`).
    public enum ContinuationKind: String, Equatable, Hashable, Sendable {
        case continueGame
        case continueExploration

        public var badgeTitle: String {
            badgeTitle(locale: Locale(identifier: "zh-Hans"))
        }

        public func badgeTitle(locale: Locale) -> String {
            if HomeIndexParityPresentation.isEnglish(locale) {
                switch self {
                case .continueGame: return "Continue Game"
                case .continueExploration: return "Continue Exploration"
                }
            }
            switch self {
            case .continueGame: return "继续游戏"
            case .continueExploration: return "继续探索"
            }
        }
    }

    /// Home continuation card model combining paused run sessions and joined registrations.
    public struct ContinuationCard: Equatable, Hashable, Identifiable {
        public let id: String
        public let kind: ContinuationKind
        public let destination: HomeFeedDestination
        public let title: String
        public let subtitle: String?
        public let elapsedMinutes: Int?
        public let isFallbackTitle: Bool

        public var playScope: PlaySessionScope {
            switch destination {
            case .activity(let id): return .activity(id)
            case .topic(let id): return .topic(id)
            }
        }

        public init(
            id: String,
            kind: ContinuationKind,
            destination: HomeFeedDestination,
            title: String,
            subtitle: String? = nil,
            elapsedMinutes: Int? = nil,
            isFallbackTitle: Bool = false
        ) {
            self.id = id
            self.kind = kind
            self.destination = destination
            self.title = title
            self.subtitle = subtitle
            self.elapsedMinutes = elapsedMinutes
            self.isFallbackTitle = isFallbackTitle
        }

        public func localizedTitle(locale: Locale) -> String {
            guard isFallbackTitle, HomeIndexParityPresentation.isEnglish(locale) else { return title }
            let scopeID = playScope.id
            switch kind {
            case .continueGame:
                return "Route in progress #\(scopeID)"
            case .continueExploration:
                return "Joined #\(scopeID)"
            }
        }

        public func localizedSubtitle(locale: Locale) -> String? {
            if let elapsedMinutes, elapsedMinutes > 0 {
                return HomeIndexParityPresentation.isEnglish(locale)
                    ? "\(elapsedMinutes) min elapsed"
                    : "已进行 \(elapsedMinutes) 分钟"
            }
            return subtitle
        }
    }

    /// Reconciles paused run sessions (`play/run-session/list`) and joined registrations (`registration/my-joined`)
    /// into deduplicated Home continuation cards (`继续游戏` prioritized ahead of `继续探索`).
    public static func continuationCards(
        pausedRuns: [PlayContinueRun] = [],
        participations: [ParticipationRecord] = [],
        locale: Locale = Locale(identifier: "zh-Hans")
    ) -> [ContinuationCard] {
        var cards: [ContinuationCard] = []
        var seenDestinations = Set<HomeFeedDestination>()
        let english = isEnglish(locale)

        for run in pausedRuns {
            let destination: HomeFeedDestination
            switch run.scope {
            case .activity(let id): destination = .activity(id)
            case .topic(let id): destination = .topic(id)
            }
            guard seenDestinations.insert(destination).inserted else { continue }
            let trimmedTitle = run.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let isFallback = trimmedTitle.isEmpty
            let resolvedTitle = isFallback
                ? (english ? "Route in progress #\(run.scope.id)" : "进行中的路线 #\(run.scope.id)")
                : trimmedTitle
            let elapsedMinutes: Int?
            let subtitle: String?
            if let elapsed = run.elapsedSeconds, elapsed > 0 {
                let minutes = max(1, elapsed / 60)
                elapsedMinutes = minutes
                subtitle = english ? "\(minutes) min elapsed" : "已进行 \(minutes) 分钟"
            } else {
                elapsedMinutes = nil
                subtitle = nil
            }
            cards.append(
                ContinuationCard(
                    id: "run_\(run.id)",
                    kind: .continueGame,
                    destination: destination,
                    title: resolvedTitle,
                    subtitle: subtitle,
                    elapsedMinutes: elapsedMinutes,
                    isFallbackTitle: isFallback
                )
            )
        }

        for record in participations {
            guard let scope = record.destination else { continue }
            let destination: HomeFeedDestination
            switch scope {
            case .activity(let id): destination = .activity(id)
            case .topic(let id): destination = .topic(id)
            }
            guard seenDestinations.insert(destination).inserted else { continue }
            let trimmedTitle = record.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let isFallback = trimmedTitle.isEmpty
            let resolvedTitle = isFallback
                ? (english ? "Joined #\(scope.id)" : "已报名 #\(scope.id)")
                : trimmedTitle
            let trimmedAddress = record.address?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            cards.append(
                ContinuationCard(
                    id: "joined_\(record.id)",
                    kind: .continueExploration,
                    destination: destination,
                    title: resolvedTitle,
                    subtitle: trimmedAddress.isEmpty ? nil : trimmedAddress,
                    elapsedMinutes: nil,
                    isFallbackTitle: isFallback
                )
            )
        }

        return cards
    }

    /// Formats a deterministic countdown label for an upcoming activity (`即将上线`) when `start > now`.
    public static func upcomingCountdownText(
        start: Date,
        now: Date,
        locale: Locale = Locale(identifier: "zh-Hans")
    ) -> String? {
        let interval = start.timeIntervalSince(now)
        guard interval > 0 else { return nil }
        let remaining = Int((interval + 1e-6).rounded(.down))
        let days = remaining / 86_400
        let hours = (remaining % 86_400) / 3_600
        let rawMinutes = (remaining % 3_600) / 60
        let minutes = (days == 0 && hours == 0) ? max(1, rawMinutes) : rawMinutes
        if isEnglish(locale) {
            if days > 0 {
                return "Starts in \(days)d \(hours)h"
            } else if hours > 0 {
                return "Starts in \(hours)h \(minutes)m"
            } else {
                return "Starts in \(minutes)m"
            }
        }
        if days > 0 {
            return "距上线 \(days)天\(hours)小时"
        } else if hours > 0 {
            return "距上线 \(hours)小时\(minutes)分"
        } else {
            return "距上线 \(minutes)分钟"
        }
    }

    /// Parses `startDate` via `HomeFeedDate.parse` and formats the `即将上线` countdown when `start > now`.
    public static func upcomingCountdownText(
        startDate: String?,
        now: Date,
        sourceTimeZone: TimeZone? = nil,
        locale: Locale = Locale(identifier: "zh-Hans")
    ) -> String? {
        guard let start = HomeFeedDate.parse(startDate, sourceTimeZone: sourceTimeZone) else { return nil }
        return upcomingCountdownText(start: start, now: now, locale: locale)
    }

    /// Maximum allowed schedule horizon (7 days = 604_800s, at most ~1_586 ticks) so even `.infinity`, `.nan`,
    /// or extreme caller values cannot allocate unbounded schedule arrays.
    public static let maxAllowedScheduleHorizon: TimeInterval = 7 * 86_400

    /// Generates display-granularity boundary dates (hour boundaries when >24h, minute boundaries when <=24h)
    /// from `date` up to `start` within a bounded horizon (default & hard ceiling 7 days = 1_586 ticks max) so countdown labels
    /// advance without a 1 Hz timer, without premature 256-entry truncation, and without unbounded far-future arrays.
    public static func countdownScheduleDates(
        from date: Date,
        start: Date,
        base: [Date] = [],
        maxScheduleHorizon: TimeInterval = maxAllowedScheduleHorizon
    ) -> [Date] {
        guard start > date else { return base.isEmpty ? [date] : base }
        let clampedHorizon: TimeInterval
        if maxScheduleHorizon.isFinite && maxScheduleHorizon > 0 {
            clampedHorizon = min(max(60, maxScheduleHorizon), maxAllowedScheduleHorizon)
        } else {
            clampedHorizon = maxAllowedScheduleHorizon
        }
        let horizonLimit = min(start, date.addingTimeInterval(clampedHorizon))
        var dates: [Date] = [date]
        var cursor = date
        while cursor < horizonLimit {
            let remaining = start.timeIntervalSince(cursor)
            guard remaining > 0 else { break }
            let step: TimeInterval = remaining > 86_400 ? 3_600 : 60
            let nextRemaining = floor((remaining - 1e-6) / step) * step
            if nextRemaining <= 0 {
                break
            }
            let tick = start.addingTimeInterval(-nextRemaining)
            if tick > cursor && tick <= horizonLimit && tick < start {
                dates.append(tick)
                cursor = tick
            } else {
                break
            }
        }
        let terminalDate = horizonLimit < start ? horizonLimit : start
        if dates.last != terminalDate {
            dates.append(terminalDate)
        }
        return dates
    }

    /// Resolves the city selector label: returns trimmed city name, `"全国"` / `"Nationwide"` when nationwide is selected,
    /// or `"选择城市"` / `"Select City"` when no city is resolved.
    public static func citySelectorLabel(
        selectedCity: String?,
        isNationwide: Bool = false,
        locale: Locale = Locale(identifier: "zh-Hans")
    ) -> String {
        if isNationwide {
            return isEnglish(locale) ? "Nationwide" : nationwideCityLabel
        }
        let trimmed = selectedCity?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            return trimmed
        }
        return isEnglish(locale) ? "Select City" : defaultCityFallback
    }

    /// Formats the mini-program hero greeting (`"Hi, {昵称‖旅人}!"` / `"Hi, {Nickname‖Traveler}!"`).
    public static func greetingText(
        nickname: String?,
        locale: Locale = Locale(identifier: "zh-Hans")
    ) -> String {
        let trimmed = nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let fallback = isEnglish(locale) ? "Traveler" : defaultTravelerNickname
        let resolved = trimmed.isEmpty ? fallback : trimmed
        // Design hand-off r1 PL-54: the greeting is the 首页 subtitle, not a title ("Hi, 玩家小城!" → "小城，今天去哪").
        return isEnglish(locale) ? "Where to today, \(resolved)?" : "\(resolved)，今天去哪"
    }

    /// Returns all shelf headers in display order.
    public static var shelfHeaders: [String] {
        ShelfKind.allCases.map(\.title)
    }

    public static func shelfHeaders(locale: Locale) -> [String] {
        ShelfKind.allCases.map { $0.title(locale: locale) }
    }
}

// MARK: - Global Search Parity (`pages/search2`)

/// Presentation rules for the mini-program global search page (`pages/search2`).
public enum GlobalSearchParityPresentation {
    public static let maxHistoryCount = 10
    public static let placeholderCopy = "搜索主题、活动、俱乐部、商家"
    public static let emptyQueryHint = "输入关键词搜索路线、活动、商家或俱乐部"
    public static let noResultsTitle = "未找到相关内容"
    public static let noResultsHint = "换个关键词或调整筛选条件试试"

    /// Result tab kinds matching `pages/search2` tabs.
    public enum ResultTabKind: String, CaseIterable, Hashable, Sendable {
        case all
        case routes
        case activities
        case merchants
        case clubs
        case moments

        public var title: String { title(chinese: true) }

        /// Result labels from `utils/discover-search.js` `TYPE_META` and the unified `post` row.
        public func title(chinese: Bool) -> String {
            switch self {
            case .all: return chinese ? "全部" : "All"
            case .routes: return chinese ? "主题" : "Topics"
            case .activities: return chinese ? "活动" : "Activities"
            case .merchants: return chinese ? "商家" : "Merchants"
            case .clubs: return chinese ? "俱乐部" : "Clubs"
            case .moments: return chinese ? "帖文" : "Posts"
            }
        }
    }

    /// Descriptor for a single search result tab with its count badge.
    public struct ResultTabDescriptor: Equatable, Hashable, Sendable, Identifiable {
        public let kind: ResultTabKind
        public let title: String
        public let count: Int

        public var id: String { kind.rawValue }

        public init(kind: ResultTabKind, count: Int) {
            self.kind = kind
            self.title = kind.title
            self.count = max(0, count)
        }

        /// Formatted badge text (nil when 0 for cleaner display, or string value when > 0).
        public var badgeText: String? {
            count > 0 ? "\(count)" : nil
        }

        /// Combined display label e.g. `"主题 3"` or `"主题"`.
        public var displayLabel: String {
            if let badge = badgeText {
                return "\(title) \(badge)"
            }
            return title
        }
    }

    /// Trims leading and trailing whitespace and newlines from a raw search input.
    public static func trimmedKeyword(_ raw: String?) -> String {
        (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Deduplicates search history preserving most-recent-first order, trimming whitespace,
    /// discarding empty entries, and capping at `maxHistoryCount` (10).
    public static func recordHistory(keyword: String, into existing: [String]) -> [String] {
        let cleaned = trimmedKeyword(keyword)
        var combined = existing
        if !cleaned.isEmpty {
            combined.insert(cleaned, at: 0)
        }
        return deduplicateHistory(combined)
    }

    /// Normalizes an array of history strings into at most 10 unique non-empty trimmed keywords.
    public static func deduplicateHistory(_ entries: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for entry in entries {
            let cleaned = trimmedKeyword(entry)
            guard !cleaned.isEmpty else { continue }
            if seen.insert(cleaned).inserted {
                result.append(cleaned)
                if result.count >= maxHistoryCount {
                    break
                }
            }
        }
        return result
    }

    /// Builds the 6 result tab descriptors (`全部`, `主题`, `活动`, `商家`, `俱乐部`, `帖文`) with count badges.
    public static func resultTabs(
        routesCount: Int = 0,
        activitiesCount: Int = 0,
        merchantsCount: Int = 0,
        clubsCount: Int = 0,
        momentsCount: Int = 0
    ) -> [ResultTabDescriptor] {
        let r = max(0, routesCount)
        let a = max(0, activitiesCount)
        let m = max(0, merchantsCount)
        let c = max(0, clubsCount)
        let d = max(0, momentsCount)
        let total = r + a + m + c + d
        return [
            ResultTabDescriptor(kind: .all, count: total),
            ResultTabDescriptor(kind: .routes, count: r),
            ResultTabDescriptor(kind: .activities, count: a),
            ResultTabDescriptor(kind: .merchants, count: m),
            ResultTabDescriptor(kind: .clubs, count: c),
            ResultTabDescriptor(kind: .moments, count: d)
        ]
    }

    /// Builds result tab descriptors from an existing `GlobalSearchResults` value.
    public static func resultTabs(from results: GlobalSearchResults, momentsCount: Int = 0) -> [ResultTabDescriptor] {
        resultTabs(
            routesCount: results.count(.topic),
            activitiesCount: results.count(.activity),
            merchantsCount: results.count(.merchant),
            clubsCount: results.count(.club),
            momentsCount: momentsCount
        )
    }
}

// MARK: - Root Tab Bar Parity (`components/tabBar`)

/// Role-aware 5-tab bar specification matching mini-program `components/tabBar`.
public enum RootTabBarParity {
    public enum RoleMode: String, CaseIterable, Hashable, Sendable {
        case consumer
        case merchant
    }

    public struct TabDescriptor: Equatable, Hashable, Sendable, Identifiable {
        public let index: Int
        public let rootTab: RootTab
        public let primaryTitle: String
        public let alternateTitle: String?
        public let titleKey: String
        public let systemImage: String

        public var id: Int { index }

        public init(
            index: Int,
            rootTab: RootTab,
            primaryTitle: String,
            alternateTitle: String? = nil,
            titleKey: String,
            systemImage: String
        ) {
            self.index = index
            self.rootTab = rootTab
            self.primaryTitle = primaryTitle
            self.alternateTitle = alternateTitle
            self.titleKey = titleKey
            self.systemImage = systemImage
        }

        /// Returns whether a candidate label matches either the primary or alternate title.
        public func matchesLabel(_ label: String) -> Bool {
            let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed == primaryTitle || (alternateTitle != nil && trimmed == alternateTitle)
        }
    }

    /// Root container destination resolved from `(RoleMode, RootTab)`.
    public enum RootContainerRoute: String, CaseIterable, Equatable, Hashable, Sendable {
        case consumerHome
        case consumerRoam
        case consumerTemplateLibrary
        case consumerClub
        case merchantWorkbench
        case merchantMarketing
        case merchantTemplates
        case merchantCooperation
        case mine
    }

    public struct TabBarState: Equatable, Hashable, Sendable {
        public let mode: RoleMode
        public let selectedTab: RootTab
        public let isAuthenticated: Bool
        public let tabs: [TabDescriptor]

        public init(mode: RoleMode = .consumer, selectedTab: RootTab = .home, isAuthenticated: Bool = false) {
            self.mode = mode
            self.selectedTab = selectedTab
            self.isAuthenticated = isAuthenticated
            self.tabs = RootTabBarParity.tabs(for: mode)
        }

        public func requiresAuthenticationPrompt(for tab: RootTab) -> Bool {
            false
        }

        /// Active root container route for the current `mode` and `selectedTab`.
        public var activeContainerRoute: RootContainerRoute {
            RootTabBarParity.containerRoute(for: selectedTab, mode: mode)
        }

        /// Returns a new state switched to `newMode`, resetting the selected tab to `defaultTab`.
        public func switchingMode(to newMode: RoleMode, resettingTabTo defaultTab: RootTab = .home) -> TabBarState {
            TabBarState(mode: newMode, selectedTab: defaultTab, isAuthenticated: isAuthenticated)
        }
    }

    public static let consumerModeTitle = "玩家视角"
    public static let merchantModeTitle = "商家工作台"

    /// Resolves the active root container mode. Fails closed to `.consumer` unless `prefersMerchantContainer`
    /// is true and `accountRole` is `"merchant"`.
    public static func resolvedMode(accountRole: String?, prefersMerchantContainer: Bool = false) -> RoleMode {
        guard prefersMerchantContainer else { return .consumer }
        let normalized = accountRole?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return normalized == "merchant" ? .merchant : .consumer
    }

    /// Which mode a signed-in account should request first. `role == merchant` or `userType == 2`
    /// asks for merchant mode. It does not admit merchant tabs; `merchantAccess()` still has to succeed.
    public static func initialRequestedMode(role: String, userType: Int?) -> RoleMode {
        let normalized = role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == "merchant" || userType == 2 { return .merchant }
        return .consumer
    }

    /// Maps a `(RootTab, RoleMode)` pair to its dedicated root container route.
    public static func containerRoute(for tab: RootTab, mode: RoleMode) -> RootContainerRoute {
        switch (mode, tab) {
        case (.consumer, .home): return .consumerHome
        case (.consumer, .roam): return .consumerRoam
        case (.consumer, .publish): return .consumerTemplateLibrary
        case (.consumer, .club): return .consumerClub
        case (.merchant, .home): return .merchantWorkbench
        case (.merchant, .roam): return .merchantMarketing
        case (.merchant, .publish): return .merchantTemplates
        case (.merchant, .club): return .merchantCooperation
        case (_, .mine): return .mine
        }
    }

    /// Standard 5 consumer tabs: `发现`/`首页`, `漫游`, `模板`/`玩法`, `俱乐部`, `我的`.
    public static let consumerTabs: [TabDescriptor] = [
        TabDescriptor(
            index: 0,
            rootTab: .home,
            primaryTitle: "首页",
            alternateTitle: "发现",
            titleKey: RootTab.home.titleKey,
            systemImage: RootTab.home.systemImage
        ),
        TabDescriptor(
            index: 1,
            rootTab: .roam,
            primaryTitle: "漫游",
            alternateTitle: nil,
            titleKey: RootTab.roam.titleKey,
            systemImage: RootTab.roam.systemImage
        ),
        TabDescriptor(
            index: 2,
            rootTab: .publish,
            primaryTitle: "模板",
            alternateTitle: "玩法",
            titleKey: RootTab.publish.titleKey,
            systemImage: RootTab.publish.systemImage
        ),
        TabDescriptor(
            index: 3,
            rootTab: .club,
            primaryTitle: "俱乐部",
            alternateTitle: nil,
            titleKey: RootTab.club.titleKey,
            systemImage: RootTab.club.systemImage
        ),
        TabDescriptor(
            index: 4,
            rootTab: .mine,
            primaryTitle: "我的",
            alternateTitle: nil,
            titleKey: RootTab.mine.titleKey,
            systemImage: RootTab.mine.systemImage
        )
    ]

    /// Merchant role 5-tab bar specification (`工作台`, `营销`, `模板`, `合作`, `我的`).
    public static let merchantTabs: [TabDescriptor] = [
        TabDescriptor(
            index: 0,
            rootTab: .home,
            primaryTitle: "工作台",
            alternateTitle: "首页",
            titleKey: "tabBar.merchant.workbench",
            systemImage: "square.grid.2x2"
        ),
        TabDescriptor(
            index: 1,
            rootTab: .roam,
            primaryTitle: "营销",
            alternateTitle: nil,
            titleKey: "tabBar.merchant.marketing",
            systemImage: "megaphone"
        ),
        TabDescriptor(
            index: 2,
            rootTab: .publish,
            primaryTitle: "模板",
            alternateTitle: "玩法",
            titleKey: "tabBar.merchant.templates",
            systemImage: "plus.square"
        ),
        TabDescriptor(
            index: 3,
            rootTab: .club,
            primaryTitle: "合作",
            alternateTitle: nil,
            titleKey: "tabBar.merchant.cooperation",
            systemImage: "person.2"
        ),
        TabDescriptor(
            index: 4,
            rootTab: .mine,
            primaryTitle: "我的",
            alternateTitle: nil,
            titleKey: RootTab.mine.titleKey,
            systemImage: RootTab.mine.systemImage
        )
    ]

    public static func tabs(for mode: RoleMode) -> [TabDescriptor] {
        switch mode {
        case .consumer: return consumerTabs
        case .merchant: return merchantTabs
        }
    }
}

// MARK: - Publish Tab Floating Sheet Parity (`pages/template` + `/api/publish/home`)

/// Presentation model for the floating publish button and action sheet on the Publish/Template tab (`pages/template`).
public enum PublishTabFloatingSheetParity {
    public enum ActionKind: String, CaseIterable, Hashable, Sendable {
        case quickTopic
        case proTopic
        case singleActivity

        public var title: String {
            switch self {
            case .quickTopic: return "快速发布主题"
            case .proTopic: return "专业版主题创编"
            case .singleActivity: return "发布单场活动"
            }
        }

        public var subtitle: String {
            switch self {
            case .quickTopic: return "3步轻量创建城市探索主题"
            case .proTopic: return "完整章节、节点与道具配置"
            case .singleActivity: return "面向俱乐部主理人发起定时活动"
            }
        }

        public var systemImage: String {
            switch self {
            case .quickTopic: return "bolt.fill"
            case .proTopic: return "slider.horizontal.3"
            case .singleActivity: return "calendar.badge.plus"
            }
        }
    }

    public struct ActionDescriptor: Equatable, Hashable, Sendable, Identifiable {
        public let kind: ActionKind
        public let title: String
        public let subtitle: String
        public let systemImage: String
        public let isEnabled: Bool
        public let disabledReason: String?

        public var id: String { kind.rawValue }

        public init(
            kind: ActionKind,
            isEnabled: Bool,
            disabledReason: String? = nil
        ) {
            self.kind = kind
            self.title = kind.title
            self.subtitle = kind.subtitle
            self.systemImage = kind.systemImage
            self.isEnabled = isEnabled
            self.disabledReason = disabledReason
        }
    }

    public struct SheetPresentation: Equatable, Hashable, Sendable {
        public let fabTitle: String
        public let sheetTitle: String
        public let quotaBadgeText: String?
        public let actions: [ActionDescriptor]

        public init(
            fabTitle: String = PublishTabFloatingSheetParity.fabButtonTitle,
            sheetTitle: String = PublishTabFloatingSheetParity.sheetHeaderTitle,
            quotaBadgeText: String?,
            actions: [ActionDescriptor]
        ) {
            self.fabTitle = fabTitle
            self.sheetTitle = sheetTitle
            self.quotaBadgeText = quotaBadgeText
            self.actions = actions
        }
    }

    public static let fabButtonTitle = "发布"
    public static let sheetHeaderTitle = "选择发布方式"
    public static let signInRequiredReason = "请先登录并获取发布权限"
    public static let quotaExhaustedReason = "主题发布额度已用完"
    public static let clubOnlyActivityReason = "仅认证俱乐部主理人可发布单场活动"

    /// Builds the floating publish sheet presentation from `/api/publish/home` capability.
    /// Fails closed when `capability` is nil.
    public static func presentation(capability: PublishingCapability?) -> SheetPresentation {
        guard let capability else {
            return SheetPresentation(
                quotaBadgeText: nil,
                actions: ActionKind.allCases.map {
                    ActionDescriptor(kind: $0, isEnabled: false, disabledReason: signInRequiredReason)
                }
            )
        }

        let quotaText: String?
        if capability.quotaExhausted {
            quotaText = "今日发布额度已用完"
        } else if let remaining = capability.remaining {
            quotaText = "剩余可发布 \(remaining) 个主题"
        } else {
            quotaText = nil
        }

        let quickEnabled = capability.simple && !capability.quotaExhausted
        let quickReason: String? = quickEnabled
            ? nil
            : (capability.quotaExhausted ? quotaExhaustedReason : "当前账号暂无快速发布权限")

        let proEnabled = capability.pro && !capability.quotaExhausted
        let proReason: String? = proEnabled
            ? nil
            : (capability.quotaExhausted ? quotaExhaustedReason : "当前账号暂无专业创编权限")

        let activityEnabled = capability.activity
        let activityReason: String? = activityEnabled ? nil : clubOnlyActivityReason

        return SheetPresentation(
            quotaBadgeText: quotaText,
            actions: [
                ActionDescriptor(kind: .quickTopic, isEnabled: quickEnabled, disabledReason: quickReason),
                ActionDescriptor(kind: .proTopic, isEnabled: proEnabled, disabledReason: proReason),
                ActionDescriptor(kind: .singleActivity, isEnabled: activityEnabled, disabledReason: activityReason)
            ]
        )
    }
}

// MARK: - Home Continuation Coordinator (P1 End-to-End Business Flow)

/// Account + session-revision + journey-scope identity binding for Home continuation cards.
public struct HomeContinuationOwnerScope: Equatable, Hashable, Sendable {
    public let accountID: Int
    public let sessionRevision: UInt64
    public let journeyScope: UUID

    public init(accountID: Int, sessionRevision: UInt64, journeyScope: UUID) {
        self.accountID = accountID
        self.sessionRevision = sessionRevision
        self.journeyScope = journeyScope
    }
}

/// Explicit read-availability state for Home continuation cards.
/// Keeps `PlayerJourneyService` default `readsEnabled = false` fail-closed while surfacing the approval gap.
public enum HomeContinuationReadAvailability: String, Equatable, Sendable {
    case available
    case journeyReadNotApproved
    case unauthenticated
    case failed

    public var messageKey: String? {
        switch self {
        case .available:
            return nil
        case .journeyReadNotApproved:
            return "homeContinuation.journeyReadNotApproved"
        case .unauthenticated:
            return "homeContinuation.signInRequired"
        case .failed:
            return "homeContinuation.loadFailed"
        }
    }
}

/// Result of pre-tap re-verification before entering a continuation card's runtime or detail destination.
public enum HomeContinuationNavigationDecision: Equatable {
    case enterRuntime(PlaySessionScope)
    case openDetail(HomeFeedDestination)
    case staleRejected
}

/// Coordinates Home continuation cards (`玩家“退出后继续玩”完整组`) with:
/// - `(accountID, sessionRevision, journeyScope)` binding,
/// - independent load leases (`activeLoadTicket`) and per-scope navigation leases (`scopeNavigationTickets`),
/// - explicit `journeyReadNotApproved` reporting when remote `PlayerJourneyService` reads remain default-off (`readsEnabled == false`),
/// - durable post-restart paused-run recovery and pre-tap re-verification before navigation.
@MainActor
public final class HomeContinuationCoordinator {
    public private(set) var ownerScope: HomeContinuationOwnerScope?
    public private(set) var cards: [HomeIndexParityPresentation.ContinuationCard] = []
    public private(set) var readAvailability: HomeContinuationReadAvailability = .unauthenticated
    public private(set) var activeGeneration: UInt64 = 0
    public private(set) var activeLoadTicket = UUID()
    private var scopeGenerations: [PlaySessionScope: UInt64] = [:]
    private var scopeNavigationTickets: [PlaySessionScope: UUID] = [:]

    public init() {}

    public func generation(for scope: PlaySessionScope) -> UInt64 {
        scopeGenerations[scope] ?? 0
    }

    public func navigationTicket(for scope: PlaySessionScope) -> UUID? {
        scopeNavigationTickets[scope]
    }

    /// Resets all continuation cards and invalidates both load and navigation leases so any in-flight work is discarded.
    public func reset(readAvailability: HomeContinuationReadAvailability = .unauthenticated) {
        activeGeneration &+= 1
        activeLoadTicket = UUID()
        ownerScope = nil
        cards = []
        self.readAvailability = readAvailability
        scopeGenerations.removeAll()
        scopeNavigationTickets.removeAll()
    }

    /// Reloads continuation cards for `ownerScope` with an independent load lease (`activeLoadTicket`) and monotonic generation isolation.
    /// Older completions, failures, or cancellations never overwrite newer state, and any in-flight navigation verification is invalidated.
    @discardableResult
    public func reload(
        ownerScope: HomeContinuationOwnerScope?,
        isAuthenticated: Bool,
        isJourneyReadConfigured: Bool,
        locale: Locale = Locale(identifier: "zh-Hans"),
        currentOwnerScope: () -> HomeContinuationOwnerScope?,
        loadParticipations: () async throws -> [ParticipationRecord],
        loadPausedRuns: ([ParticipationRecord]) async -> [PlayContinueRun]
    ) async -> [HomeIndexParityPresentation.ContinuationCard] {
        activeGeneration &+= 1
        let generation = activeGeneration
        let loadTicket = UUID()
        activeLoadTicket = loadTicket
        scopeNavigationTickets.removeAll()

        guard isAuthenticated, let ownerScope, ownerScope.accountID > 0 else {
            if generation == activeGeneration && activeLoadTicket == loadTicket {
                self.ownerScope = nil
                self.cards = []
                self.readAvailability = .unauthenticated
                self.scopeGenerations.removeAll()
                self.scopeNavigationTickets.removeAll()
            }
            return []
        }

        if self.ownerScope != ownerScope {
            self.ownerScope = ownerScope
            self.cards = []
            self.scopeGenerations.removeAll()
            self.scopeNavigationTickets.removeAll()
        }

        var remoteRecords: [ParticipationRecord] = []
        let resolvedAvailability: HomeContinuationReadAvailability

        if isJourneyReadConfigured {
            do {
                let fetched = try await loadParticipations()
                try Task.checkCancellation()
                guard generation == activeGeneration,
                      activeLoadTicket == loadTicket,
                      currentOwnerScope() == ownerScope else {
                    return self.cards
                }
                remoteRecords = fetched
                resolvedAvailability = .available
            } catch is CancellationError {
                return self.cards
            } catch {
                guard generation == activeGeneration,
                      activeLoadTicket == loadTicket,
                      currentOwnerScope() == ownerScope else {
                    return self.cards
                }
                remoteRecords = []
                resolvedAvailability = .failed
            }
        } else {
            // Remote PlayerJourneyService reads remain default-off (`readsEnabled == false`);
            // expose the approval gap explicitly while still recovering local durable paused runs.
            resolvedAvailability = .journeyReadNotApproved
        }

        let pausedRuns = await loadPausedRuns(remoteRecords)
        guard !Task.isCancelled,
              generation == activeGeneration,
              activeLoadTicket == loadTicket,
              currentOwnerScope() == ownerScope else {
            return self.cards
        }

        for run in pausedRuns {
            let previous = scopeGenerations[run.scope] ?? 0
            if generation >= previous {
                scopeGenerations[run.scope] = generation
            }
        }
        for record in remoteRecords {
            if let scope = record.destination {
                let previous = scopeGenerations[scope] ?? 0
                if generation >= previous {
                    scopeGenerations[scope] = generation
                }
            }
        }

        let nextCards = HomeIndexParityPresentation.continuationCards(
            pausedRuns: pausedRuns,
            participations: remoteRecords,
            locale: locale
        )
        self.ownerScope = ownerScope
        self.cards = nextCards
        self.readAvailability = resolvedAvailability
        return nextCards
    }

    /// Re-verifies owner scope, load lease (`activeLoadTicket`), per-scope navigation lease (`scopeNavigationTickets`),
    /// card freshness, and runtime/durable eligibility right before navigating on tap.
    /// Any concurrent reload, account/revision change, cancellation, or duplicate tap invalidates the prior lease.
    public func verifyNavigation(
        for card: HomeIndexParityPresentation.ContinuationCard,
        currentOwnerScope: () -> HomeContinuationOwnerScope?,
        canEnterRuntime: (PlaySessionScope) -> Bool,
        hasDurableOrLivePause: (PlaySessionScope) async -> Bool
    ) async -> HomeContinuationNavigationDecision {
        let capturedGeneration = activeGeneration
        let capturedLoadTicket = activeLoadTicket
        guard let expectedScope = ownerScope,
              currentOwnerScope() == expectedScope,
              cards.contains(card) else {
            if currentOwnerScope() != ownerScope {
                reset()
            }
            return .staleRejected
        }

        let playScope = card.playScope
        let navTicket = UUID()
        scopeNavigationTickets[playScope] = navTicket
        scopeGenerations[playScope] = (scopeGenerations[playScope] ?? capturedGeneration) &+ 1
        let capturedScopeGen = scopeGenerations[playScope]

        let hasPause = await hasDurableOrLivePause(playScope)
        guard !Task.isCancelled,
              activeGeneration == capturedGeneration,
              activeLoadTicket == capturedLoadTicket,
              currentOwnerScope() == expectedScope,
              ownerScope == expectedScope,
              scopeNavigationTickets[playScope] == navTicket,
              scopeGenerations[playScope] == capturedScopeGen,
              cards.contains(card) else {
            if currentOwnerScope() != ownerScope {
                reset()
            }
            return .staleRejected
        }
        scopeNavigationTickets[playScope] = nil

        switch card.kind {
        case .continueGame:
            guard hasPause, canEnterRuntime(playScope) else {
                cards.removeAll { $0.id == card.id }
                return .staleRejected
            }
            return .enterRuntime(playScope)
        case .continueExploration:
            if hasPause && canEnterRuntime(playScope) {
                return .enterRuntime(playScope)
            }
            return .openDetail(card.destination)
        }
    }
}

// MARK: - Unified Search Experience (Home + Search2 + SearchMap Merged; Map is a Mode)

/// Merges the 3 mini-program search entries (`pages/index` home search entry,
/// `pages/search2` global keyword/category/date/price search, and `pages/searchmap` map + nearby node search)
/// into a single Apple-native search experience where Map Search is an inline mode of the same screen,
/// never a separate pushed page.
public struct UnifiedSearchExperience: Equatable {
    /// The 3 mini-program search entry origins that converge into this single search screen.
    public enum EntryOrigin: String, CaseIterable, Equatable, Hashable, Sendable {
        case homeSearchBar = "pages/index"
        case globalSearch = "pages/search2"
        case mapSearch = "pages/searchmap"

        public var defaultMode: PresentationMode {
            switch self {
            case .homeSearchBar, .globalSearch: return .list
            case .mapSearch: return .map
            }
        }
    }

    /// Inline presentation mode of the unified search screen.
    /// Switching between `.list` and `.map` happens in place without pushing a new route,
    /// preserving keyword, category, date, price, and sort filters.
    public enum PresentationMode: String, CaseIterable, Equatable, Hashable, Sendable {
        case list
        case map

        public func title(locale: Locale = Locale(identifier: "zh-Hans")) -> String {
            let english = HomeIndexParityPresentation.isEnglish(locale)
            switch self {
            case .list: return english ? "List" : "列表"
            case .map: return english ? "Map" : "地图"
            }
        }

        public var systemImage: String {
            switch self {
            case .list: return "list.bullet"
            case .map: return "map"
            }
        }
    }

    /// Map sub-scope within `.map` mode (`城市节点与活动` vs `附近探索点`).
    public enum MapScope: String, CaseIterable, Equatable, Hashable, Sendable {
        case city
        case nearby

        public func title(locale: Locale = Locale(identifier: "zh-Hans")) -> String {
            let english = HomeIndexParityPresentation.isEnglish(locale)
            switch self {
            case .city: return english ? "City & Activities" : "城市与活动"
            case .nearby: return english ? "Nearby Nodes" : "附近节点"
            }
        }
    }

    public let origin: EntryOrigin
    public private(set) var mode: PresentationMode
    public private(set) var mapScope: MapScope
    public private(set) var query: GlobalSearchQuery
    public private(set) var selectedTab: GlobalSearchParityPresentation.ResultTabKind
    public private(set) var sortType: Int
    public private(set) var tag: String
    public private(set) var cityRole: String
    public private(set) var history: [String]

    public init(
        origin: EntryOrigin = .homeSearchBar,
        mode: PresentationMode? = nil,
        mapScope: MapScope = .city,
        query: GlobalSearchQuery = .init(),
        selectedTab: GlobalSearchParityPresentation.ResultTabKind = .all,
        sortType: Int = 1,
        tag: String = "",
        cityRole: String = "",
        history: [String] = []
    ) {
        self.origin = origin
        self.mode = mode ?? origin.defaultMode
        self.mapScope = mapScope
        self.query = query
        self.selectedTab = selectedTab
        self.sortType = (sortType == 2) ? 2 : 1
        self.tag = tag
        self.cityRole = cityRole
        self.history = GlobalSearchParityPresentation.deduplicateHistory(history)
    }

    /// Switches between `.list` and `.map` modes in place on the same screen, keeping all query and filter state intact.
    public mutating func switchMode(_ nextMode: PresentationMode) {
        mode = nextMode
    }

    public func switchingMode(to nextMode: PresentationMode) -> UnifiedSearchExperience {
        var copy = self
        copy.switchMode(nextMode)
        return copy
    }

    public mutating func switchMapScope(_ nextScope: MapScope) {
        mapScope = nextScope
    }

    public mutating func updateKeyword(_ rawKeyword: String) {
        query.keyword = rawKeyword
    }

    public mutating func submitSearch() {
        let trimmed = GlobalSearchParityPresentation.trimmedKeyword(query.keyword)
        query.keyword = trimmed
        if !trimmed.isEmpty {
            history = GlobalSearchParityPresentation.recordHistory(keyword: trimmed, into: history)
        }
    }

    public mutating func applyFilter(_ nextQuery: GlobalSearchQuery, sortType: Int? = nil, tag: String? = nil, cityRole: String? = nil) {
        query = nextQuery
        if let sortType { self.sortType = (sortType == 2) ? 2 : 1 }
        if let tag { self.tag = tag }
        if let cityRole { self.cityRole = cityRole }
    }

    public mutating func selectTab(_ tab: GlobalSearchParityPresentation.ResultTabKind) {
        selectedTab = tab
    }

    public mutating func clearHistory() {
        history = []
    }
}

/// Interactive city switch state for the Home tab (`pages/index`).
public struct HomeCitySwitchState: Equatable, Hashable, Sendable {
    public static let defaultSupportedCities: [String] = ["上海", "北京", "杭州", "成都", "深圳", "广州"]

    public private(set) var selectedCity: String?
    public private(set) var isNationwide: Bool
    public let availableCities: [String]

    public init(
        selectedCity: String? = nil,
        isNationwide: Bool = false,
        availableCities: [String] = HomeCitySwitchState.defaultSupportedCities
    ) {
        let trimmed = selectedCity?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.selectedCity = (trimmed?.isEmpty == false) ? trimmed : nil
        self.isNationwide = isNationwide
        self.availableCities = availableCities
    }

    public func displayLabel(locale: Locale = Locale(identifier: "zh-Hans")) -> String {
        HomeIndexParityPresentation.citySelectorLabel(
            selectedCity: selectedCity,
            isNationwide: isNationwide,
            locale: locale
        )
    }

    public mutating func selectCity(_ city: String?) {
        let trimmed = city?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty || trimmed == HomeIndexParityPresentation.nationwideCityLabel {
            selectedCity = nil
            isNationwide = true
        } else {
            selectedCity = trimmed
            isNationwide = false
        }
    }

    public mutating func selectNationwide() {
        selectedCity = nil
        isNationwide = true
    }
}
