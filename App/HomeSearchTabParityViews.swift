import SwiftUI

/// Hero greeting, city badge, and 3 fixed action banners (`成为俱乐部`, `成为商家`, `和朋友报名活动`) for Home (`pages/index/index`).
@MainActor
struct HomeHeroHeaderSectionView: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.locale) private var locale
    var nickname: String? = nil
    var selectedCity: String? = nil
    var isNationwide: Bool = false
    var isMerchantViewer: Bool = false
    var avatarSource: String? = nil
    var onSelectCity: ((String?, Bool) -> Void)? = nil
    var onOpenUnifiedSearch: ((UnifiedSearchExperience.PresentationMode) -> Void)? = nil
    var onSelectBanner: ((HomeIndexParityPresentation.ActionBanner) -> Void)? = nil
    @Environment(\.externalGameSession) private var externalGameSession
    @Environment(\.homeMoreMenuContent) private var moreMenuContent
    /// Continuity r1: the in-page search state borrows this field's box while it stands in for it.
    @Environment(\.homeSearchSource) private var searchSource
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    @AccessibilityFocusState private var searchEntryFocused: Bool
    /// The fixed banners, plus Mini games for a signed-in session where the external-games switch is open.
    private var actionBanners: [HomeIndexParityPresentation.ActionBanner] {
        guard let externalGameSession, ExternalGameSessionRead.externalGamesOpen(baseURL: externalGameSession.baseURL)
        else { return HomeIndexParityPresentation.playerActionBanners }
        return HomeIndexParityPresentation.playerActionBanners + [HomeIndexParityPresentation.miniGamesBanner]
    }

    private var hasCity: Bool {
        onSelectCity != nil || isNationwide || !(selectedCity?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                if let onOpenUnifiedSearch {
                    // One search entry, in the home top bar. It opens pages/search2 (list) or the map.
                    // The feed no longer draws a second field under 更多玩法.
                    HStack(spacing: CYSpacing.sm) {
                        Button {
                            onOpenUnifiedSearch(.list)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                Text(LocalizedStringResource("searchMap.placeholder.player", defaultValue: "Search topics, activities and clubs")) // player-first: no merchants
                                    .foregroundStyle(.secondary)
                                    .cyWrapText()
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        // System bordered capsule button: it opens the search screen, so it is a button, not a field.
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)
                        .accessibilityAddTraits(.isSearchField)
                        .pageTemplateControl(
                            label: Text("searchMap.placeholder.player"),
                            hint: Text("homeFeed.search"),
                            traits: .isButton
                        )
                        .accessibilityIdentifier("homeIndex.hero.searchEntry")
                        .accessibilityFocused($searchEntryFocused)

                        Button {
                            onOpenUnifiedSearch(.map)
                        } label: {
                            Image(systemName: "map")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.circle)
                        .controlSize(.large)
                        .pageTemplateControl(
                            label: Text(verbatim: UnifiedSearchExperience.PresentationMode.map.title(locale: locale)),
                            hint: Text("homeSearch.mapHint"),
                            traits: .isButton
                        )
                        .accessibilityIdentifier("homeIndex.hero.mapSearchEntry")
                    }
                    .modifier(HomeSearchSourceField(context: searchSource))
                    .onChange(of: searchSource?.returnFocus) { _, _ in searchEntryFocused = true }
                }
                // Mini-program `v3-hero-greet-row`: name on its own line, then `玩家 · 城市`, avatar trailing.
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        // PL-11 / PL-54: the 首页 large title is the header; the greeting is its one-line subtitle.
                        CYRootSubtitle(verbatim: HomeIndexParityPresentation.greetingText(nickname: nickname, locale: locale))
                            .accessibilityIdentifier("homeIndex.hero.greeting")
                        (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2)) : AnyLayout(HStackLayout(spacing: 6))) {
                            if nickname?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                                // MP asset (pages/index/index.wxml:46): the player badge is `index-figma/icon-member.png`.
                                Label {
                                    Text(LocalizedStringKey(isMerchantViewer ? "account.role.merchant" : "homeFeed.player"))
                                } icon: {
                                    if isMerchantViewer { Image(systemName: "storefront.fill") }
                                    else { MPAsset.FeatureIcon.iconMember.resizable().scaledToFit().frame(width: 16, height: 16).accessibilityHidden(true) }
                                }
                                    .foregroundStyle(.tint)
                            }
                            if hasCity {
                                if let onSelectCity {
                                    Menu {
                                        Button {
                                            onSelectCity(nil, true)
                                        } label: {
                                            Text(verbatim: CoreLoopCopy(locale: locale).tr(HomeIndexParityPresentation.citySelectorLabel(selectedCity: nil, isNationwide: true, locale: locale)))
                                        }
                                        ForEach(HomeCitySwitchState.defaultSupportedCities, id: \.self) { city in
                                            Button {
                                                onSelectCity(city, false)
                                            } label: {
                                                Text(verbatim: CoreLoopCopy(locale: locale).tr(city))
                                            }
                                        }
                                    } label: {
                                        Label {
                                            Text(verbatim: CoreLoopCopy(locale: locale).tr(HomeIndexParityPresentation.citySelectorLabel(selectedCity: selectedCity, isNationwide: isNationwide, locale: locale)))
                                        } icon: {
                                            Image(systemName: "location.fill")
                                        }
                                        .foregroundStyle(.secondary)
                                        .frame(minHeight: CYSpacing.minTouchTarget)
                                    }
                                    .accessibilityIdentifier("homeIndex.hero.city")
                                } else {
                                    Label {
                                        Text(verbatim: CoreLoopCopy(locale: locale).tr(HomeIndexParityPresentation.citySelectorLabel(selectedCity: selectedCity, isNationwide: isNationwide, locale: locale)))
                                    } icon: {
                                        Image(systemName: "location.fill")
                                    }
                                    .foregroundStyle(.secondary)
                                    .accessibilityIdentifier("homeIndex.hero.city")
                                }
                            }
                        }
                        .font(.subheadline)
                    }
                    Spacer(minLength: 0)
                    // PC-A-1-4: MP `goUser` — the avatar opens 我的 (a control, not decoration).
                    if rootTabSwitch.isAvailable {
                        Button { rootTabSwitch(.mine) } label: { HomeHeroAvatar(source: avatarSource) }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(LocalizedStringKey(RootTab.mine.titleKey)))
                            .accessibilityAddTraits(.isButton)
                            .accessibilityIdentifier("homeIndex.hero.avatar")
                    } else {
                        HomeHeroAvatar(source: avatarSource)
                    }
                }
                // The three fixed action banners are demoted into one quiet menu row; every banner stays reachable.
                Menu {
                    ForEach(actionBanners) { banner in
                        Button {
                            onSelectBanner?(banner)
                        } label: {
                            // MP assets (utils/index/home-action-banner.js:21-35): each action banner's poster.
                            Label { Text(verbatim: banner.title(locale: locale)) } icon: { HomeActionBannerPoster(id: banner.id) }
                        }
                        .accessibilityIdentifier("homeIndex.actionBanner.\(banner.id)")
                    }
                    // verify-r1 2.5 / N-12 (owner Q9): the header's former ⋯ items live here, so the 首页 bar keeps
                    // only 消息 and search.
                    if let moreMenuContent {
                        Divider()
                        moreMenuContent
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(LocalizedStringResource("homeFeed.moreWaysToPlay", defaultValue: "More ways to play"))
                            .cyWrapText()
                        Image(systemName: "chevron.down").font(.caption.weight(.bold))
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(minHeight: CYSpacing.minTouchTarget)
                }
                .accessibilityIdentifier("homeIndex.actionBanner.menu")
            }
            .padding(.vertical, 4)
            .listRowBackground(Color.clear)
        }
    }
}

// MARK: - 首页 search continuity (continuity r1)

/// Where the 首页 search field sits in window coordinates, kept by the host so the in-page search state can start its
/// field exactly on top of it. A plain box: the writes made while the feed scrolls never invalidate a view.
@MainActor final class HomeSearchSourceBox {
    var frame: CGRect = .zero
    init() {}
}

/// Published by `SessionHomeFeedView` into the feed. Nil (fixtures, other hosts) leaves the field as it always was.
struct HomeSearchSourceContext {
    let box: HomeSearchSourceBox
    /// True while the search state's field stands in for this one: one field on screen, never two.
    var isHidden: Bool
    /// Bumped when search closes so VoiceOver focus returns to the field that opened it.
    var returnFocus: Int
}

private struct HomeSearchSourceKey: EnvironmentKey { static let defaultValue: HomeSearchSourceContext? = nil }

extension EnvironmentValues {
    var homeSearchSource: HomeSearchSourceContext? {
        get { self[HomeSearchSourceKey.self] }
        set { self[HomeSearchSourceKey.self] = newValue }
    }
}

/// Records the field's window frame and hides it, with no fade, while search owns it.
private struct HomeSearchSourceField: ViewModifier {
    let context: HomeSearchSourceContext?
    func body(content: Content) -> some View {
        if let context {
            content
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { context.box.frame = proxy.frame(in: .global) }
                            .onChange(of: proxy.frame(in: .global)) { _, frame in context.box.frame = frame }
                    }
                }
                .opacity(context.isHidden ? 0 : 1)
                .accessibilityHidden(context.isHidden)
        } else {
            content
        }
    }
}

/// Round account avatar for the Home hero. Decorative: the greeting already names the viewer.
private struct HomeHeroAvatar: View {
    let source: String?
    var body: some View {
        Group {
            if let url = QuestifyCardArtwork.safeURL(source) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { fallback }
                }
            } else {
                fallback
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
    /// MP asset (pages/index/index.wxml:38): a missing avatar is `/images/d_profile.png`.
    private var fallback: some View {
        MPAsset.AvatarDefault.dProfile.resizable().scaledToFill()
    }
}

/// Poster for a home action banner (`home-action-banner.js` `poster`). Other banners keep the arrow glyph.
private struct HomeActionBannerPoster: View {
    let id: String
    var body: some View {
        switch id {
        case "activity_list": MPAsset.BannerCover.homeBannerFriends.resizable().scaledToFill()
        case "club_apply": MPAsset.BannerCover.homeBannerClub.resizable().scaledToFill()
        case "merchant_apply": MPAsset.BannerCover.homeBannerMerchant.resizable().scaledToFill()
        default: Image(systemName: "arrow.up.right").accessibilityHidden(true)
        }
    }
}

/// Home continuation banner (`继续游戏` / `继续探索`) backed by `HomeIndexParityPresentation.ContinuationCard`.
@MainActor
struct PlayContinuationBannerView: View {
    @Environment(\.locale) private var locale
    let cards: [HomeIndexParityPresentation.ContinuationCard]
    var readAvailability: HomeContinuationReadAvailability = .available
    var onSelectCard: ((HomeIndexParityPresentation.ContinuationCard) -> Void)? = nil
    var onOpen: ((HomeFeedDestination) -> Void)? = nil
    var onRetry: (() -> Void)? = nil

    var body: some View {
        Section {
            if let messageKey = readAvailability.messageKey, readAvailability != .unauthenticated {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: readAvailability == .failed ? "exclamationmark.triangle" : "info.circle")
                        .accessibilityHidden(true).font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(LocalizedStringKey(messageKey))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("homeIndex.continuation.availability.\(readAvailability.rawValue)")
                    Spacer()
                    if readAvailability == .failed, let onRetry {
                        Button("homeFeed.retry", action: onRetry)
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("homeIndex.continuation.retry")
                    }
                }
            }
            ForEach(cards) { card in
                Button {
                    if let onSelectCard {
                        onSelectCard(card)
                    } else {
                        onOpen?(card.destination)
                    }
                } label: {
                    // System row: badge, title and subtitle, with a tinted play symbol trailing.
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: card.kind.badgeTitle(locale: locale))
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(verbatim: card.localizedTitle(locale: locale))
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            if let subtitle = card.localizedSubtitle(locale: locale) {
                                Text(verbatim: subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "play.circle.fill")
                            .font(.title)
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pageTemplateGroupedCard(label: continuationLabel(card), traits: .isButton)
                .accessibilityIdentifier("homeIndex.continuation.\(card.id)")
            }
        } header: {
            Text(verbatim: HomeIndexParityPresentation.continuationSectionTitle(locale: locale))
                .accessibilityAddTraits(.isHeader)
        }
    }

    private func continuationLabel(_ card: HomeIndexParityPresentation.ContinuationCard) -> Text {
        var label = Text(verbatim: card.kind.badgeTitle(locale: locale)) + Text(verbatim: ", ") + Text(verbatim: card.localizedTitle(locale: locale))
        if let subtitle = card.localizedSubtitle(locale: locale) {
            label = label + Text(verbatim: ", ") + Text(verbatim: subtitle)
        }
        return label
    }
}

/// Shelf header view for Home (`pages/index`) sections (`精选路线`, `近期活动`, `热门主题`, `现成玩法`).
@MainActor
struct HomeIndexShelfHeaderView: View {
    @Environment(\.locale) private var locale
    let shelf: HomeIndexParityPresentation.ShelfKind
    var onAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: shelf.title(locale: locale))
                .font(.headline)
                .accessibilityIdentifier("homeIndex.shelfHeader.\(shelf.rawValue)")
            Spacer()
            if let onAction {
                Button(action: onAction) {
                    HStack(spacing: 4) {
                        Text(verbatim: shelf.actionHint(locale: locale))
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline)
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("homeIndex.shelfAction.\(shelf.rawValue)")
            }
        }
    }
}

/// Result tabs with counts for Global Search (`pages/search2`), as a native segmented control.
@MainActor
struct GlobalSearchResultTabsBar: View {
    let tabs: [GlobalSearchParityPresentation.ResultTabDescriptor]
    @Binding var selectedKind: GlobalSearchParityPresentation.ResultTabKind

    var body: some View {
        Picker("searchMap.resultKinds", selection: $selectedKind) {
            ForEach(tabs) { tab in
                segmentTitle(tab)
                    .tag(tab.kind)
                    .accessibilityIdentifier("globalSearch.tab.\(tab.kind.rawValue)")
            }
        }
        .pickerStyle(.segmented)
    }

    private func segmentTitle(_ tab: GlobalSearchParityPresentation.ResultTabDescriptor) -> Text {
        let title = Text(LocalizedStringKey(Self.titleKey(tab.kind)))
        guard let badge = tab.badgeText else { return title }
        return title + Text(verbatim: " \(badge)")
    }

    private static func titleKey(_ kind: GlobalSearchParityPresentation.ResultTabKind) -> String {
        switch kind {
        case .all: return "searchMap.all"
        case .routes: return "searchMap.kind.topic"
        case .activities: return "searchMap.kind.activity"
        case .merchants: return "searchMap.kind.merchant"
        case .clubs: return "searchMap.kind.club"
        case .moments: return "social.posts"
        }
    }
}

/// Empty, loading, or error state view for Home (`pages/index`).
@MainActor
struct HomeIndexEmptyStateView: View {
    enum Phase: Equatable {
        case loading
        case empty
        case error
    }

    @Environment(\.locale) private var locale
    let phase: Phase
    var onRetry: (() -> Void)? = nil

    var body: some View {
        switch phase {
        case .loading:
            VStack(spacing: 12) {
                ProgressView()
                    .accessibilityHidden(true)
                Text(verbatim: HomeIndexParityPresentation.loadingCopy(locale: locale))
                    .accessibilityAddTraits(.updatesFrequently)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("homeIndex.state.loading")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        case .empty:
            ContentUnavailableView {
                Label {
                    Text(verbatim: HomeIndexParityPresentation.emptyStateTitle(locale: locale))
                } icon: {
                    Image(systemName: "tray")
                }
            } description: {
                Text(verbatim: HomeIndexParityPresentation.emptyStateHint(locale: locale))
                    .accessibilityIdentifier("homeIndex.state.empty")
            }
        case .error:
            ContentUnavailableView {
                Label {
                    Text(verbatim: HomeIndexParityPresentation.errorCopy(locale: locale))
                        .accessibilityIdentifier("homeIndex.state.error")
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
            } description: {
                EmptyView()
            } actions: {
                if let onRetry {
                    Button(action: onRetry) {
                        Text(verbatim: HomeIndexParityPresentation.retryButtonTitle(locale: locale))
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("homeIndex.state.retry")
                }
            }
        }
    }
}

/// Role-aware consumer (`玩家视角`) ↔ merchant (`商家工作台`) root container switch banner (`components/tabBar`).
@MainActor
struct MerchantRootModeSwitchBannerView: View {
    let state: RootTabBarParity.TabBarState
    var canSwitchToMerchant: Bool = false
    var onSelectMode: ((RootTabBarParity.RoleMode) -> Void)? = nil
    var onSelectTab: ((RootTab) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    onSelectMode?(.consumer)
                } label: {
                    Text("rootMode.consumer")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(state.mode == .consumer ? Color.accentColor : .secondary)
                .accessibilityIdentifier("rootTabBar.mode.consumer")

                if canSwitchToMerchant || state.mode == .merchant {
                    Button {
                        onSelectMode?(.merchant)
                    } label: {
                        Text("rootMode.merchant")
                            .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(state.mode == .merchant ? Color.accentColor : .secondary)
                    .accessibilityIdentifier("rootTabBar.mode.merchant")
                }
                Spacer()
            }

            HStack(spacing: 6) {
                ForEach(state.tabs) { descriptor in
                    let isSelected = descriptor.rootTab == state.selectedTab
                    Button {
                        onSelectTab?(descriptor.rootTab)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: descriptor.systemImage)
                                .font(.subheadline)
                            Text(LocalizedStringKey(descriptor.titleKey))
                                .font(.caption.weight(isSelected ? .semibold : .regular))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .accessibilityIdentifier("rootTabBar.tab.\(state.mode.rawValue).\(descriptor.index)")
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("rootTabBar.containerSwitch")
    }
}

/// Merchant 5-tab business entries (`工作台`, `营销`, `模板`, `合作`, `我的`) mapped 1:1 with `RootTabBarParity.merchantTabs`.
enum MerchantRootBusinessTab: Int, CaseIterable, Hashable, Sendable, Identifiable {
    case workbench = 0
    case marketing = 1
    case templates = 2
    case cooperation = 3
    case mine = 4

    var id: Int { rawValue }

    init(rootTab: RootTab) {
        switch rootTab {
        case .home: self = .workbench
        case .roam: self = .marketing
        case .publish: self = .templates
        case .club: self = .cooperation
        case .mine: self = .mine
        }
    }

    var rootTab: RootTab {
        switch self {
        case .workbench: return .home
        case .marketing: return .roam
        case .templates: return .publish
        case .cooperation: return .club
        case .mine: return .mine
        }
    }

    var descriptor: RootTabBarParity.TabDescriptor {
        RootTabBarParity.merchantTabs[rawValue]
    }

    var containerRoute: RootTabBarParity.RootContainerRoute {
        RootTabBarParity.containerRoute(for: rootTab, mode: .merchant)
    }
}

/// Environment action for requesting a consumer ↔ merchant root container mode switch.
struct MerchantRootModeSwitch {
    let isAvailable: Bool
    let activeMode: RootTabBarParity.RoleMode
    let isVerifying: Bool
    let errorKey: String?
    let selectedTab: RootTab
    private let requestMode: @MainActor (RootTabBarParity.RoleMode) -> Void
    private let selectTab: @MainActor (RootTab) -> Void

    init(
        activeMode: RootTabBarParity.RoleMode = .consumer,
        isVerifying: Bool = false,
        errorKey: String? = nil,
        selectedTab: RootTab = .home,
        requestMode: @escaping @MainActor (RootTabBarParity.RoleMode) -> Void,
        selectTab: @escaping @MainActor (RootTab) -> Void = { _ in }
    ) {
        self.isAvailable = true
        self.activeMode = activeMode
        self.isVerifying = isVerifying
        self.errorKey = errorKey
        self.selectedTab = selectedTab
        self.requestMode = requestMode
        self.selectTab = selectTab
    }

    private init() {
        self.isAvailable = false
        self.activeMode = .consumer
        self.isVerifying = false
        self.errorKey = nil
        self.selectedTab = .home
        self.requestMode = { _ in }
        self.selectTab = { _ in }
    }

    static let unavailable = MerchantRootModeSwitch()

    @MainActor func callAsFunction(_ mode: RootTabBarParity.RoleMode) {
        requestMode(mode)
    }

    @MainActor func select(_ tab: RootTab) {
        selectTab(tab)
    }
}

/// Token captured at the moment a child merchant surface begins an access reload.
/// Ensures late/out-of-order observations cannot resurrect a revoked or exited merchant grant.
struct MerchantAccessObservationToken: Equatable, Sendable {
    let verificationGeneration: UInt64
    let containerGeneration: UUID
    let accountID: Int
    let sessionRevision: UInt64
}

/// Environment hook allowing child merchant surfaces (such as `MerchantHomeView`) to capture an observation token
/// before `await reader.merchantAccess()` and report the result back only if the token still matches.
struct MerchantAccessObservationHook {
    var begin: @MainActor () -> MerchantAccessObservationToken?
    var complete: @MainActor (MerchantAccessObservationToken, MerchantAccess?, String?) -> Void

    static let noop = MerchantAccessObservationHook(
        begin: { nil },
        complete: { _, _, _ in }
    )
}

private struct MerchantRootModeSwitchKey: EnvironmentKey {
    static let defaultValue = MerchantRootModeSwitch.unavailable
}

private struct MerchantAccessObserverKey: EnvironmentKey {
    static let defaultValue = MerchantAccessObservationHook.noop
}

extension EnvironmentValues {
    var merchantRootModeSwitch: MerchantRootModeSwitch {
        get { self[MerchantRootModeSwitchKey.self] }
        set { self[MerchantRootModeSwitchKey.self] = newValue }
    }
    var merchantAccessObserver: MerchantAccessObservationHook {
        get { self[MerchantAccessObserverKey.self] }
        set { self[MerchantAccessObserverKey.self] = newValue }
    }
}

/// Authoritative coordinator for switching between Consumer Mode (`玩家视角`) and Merchant Root Mode (`商家工作台`).
/// UI mode selection never manufactures merchant authorization: `.merchantTabs` is entered only when
/// `reader.merchantAccess()` succeeds with `active == true && (merchantID ?? 0) > 0` for the current account and session revision.
@MainActor
final class MerchantRootModeCoordinator: ObservableObject {
    enum ResolvedRoute: Equatable {
        case consumerTabs
        case merchantTabs(MerchantAccess)
    }

    @Published private(set) var requestedMode: RootTabBarParity.RoleMode = .consumer
    @Published private(set) var verifiedAccess: MerchantAccess? = nil
    @Published private(set) var verifiedAccountID: Int? = nil
    @Published private(set) var verifiedSessionRevision: UInt64? = nil
    @Published private(set) var isVerifying: Bool = false
    @Published private(set) var statusErrorKey: String? = nil
    @Published var selectedMerchantTab: MerchantRootBusinessTab = .workbench
    @Published private(set) var merchantContainerGeneration = UUID()

    private var verificationGeneration: UInt64 = 0
    /// Manual consumer choice for one account and session revision. Identity changes drop it.
    private var consumerHold: ConsumerModeHold?
    /// One automatic request per account, revision, and merchant/player signal. Refreshes do not repeat it.
    private var autoMerchantRequest: AutoMerchantRequest?
    private var anchoredAccountID: Int?
    private var anchoredRevision: UInt64?

    private struct ConsumerModeHold: Equatable {
        let accountID: Int
        let revision: UInt64
    }

    private struct AutoMerchantRequest: Equatable {
        let accountID: Int
        let revision: UInt64
        let wantsMerchant: Bool
    }

    var selectedRootTab: RootTab {
        get { selectedMerchantTab.rootTab }
        set { selectedMerchantTab = MerchantRootBusinessTab(rootTab: newValue) }
    }

    /// Evaluates whether a specific merchant business tab has read/entry permission under a verified `MerchantAccess`.
    static func allowsBusinessTab(_ tab: MerchantRootBusinessTab, access: MerchantAccess) -> Bool {
        guard access.active, let merchantID = access.merchantID, merchantID > 0, access.role != nil else {
            return false
        }
        switch tab {
        case .workbench:
            return true
        case .marketing:
            return access.isOwner || access.role == .manager || access.role == .marketing || access.allows(.couponManage) || access.allows(.basicRead)
        case .templates:
            return access.allows(.projects)
        case .cooperation:
            return access.isOwner || access.allows(.coopManage)
        case .mine:
            return true
        }
    }

    func resolvedRoute(
        accountID: Int?,
        isSignedIn: Bool,
        isConfigured: Bool,
        revision: UInt64
    ) -> ResolvedRoute {
        // Lane G: the merchant root console is hidden in the player Release build.
        guard PlayerLaunch.merchantCenterEnabled, isConfigured, isSignedIn, let accountID, accountID > 0 else {
            return .consumerTabs
        }
        guard requestedMode == .merchant,
              verifiedAccountID == accountID,
              verifiedSessionRevision == revision,
              let access = verifiedAccess,
              access.active,
              let merchantID = access.merchantID,
              merchantID > 0,
              access.role != nil else {
            return .consumerTabs
        }
        return .merchantTabs(access)
    }

    func activeMerchantAccess(
        accountID: Int?,
        isSignedIn: Bool,
        isConfigured: Bool,
        revision: UInt64
    ) -> MerchantAccess? {
        if case .merchantTabs(let access) = resolvedRoute(
            accountID: accountID,
            isSignedIn: isSignedIn,
            isConfigured: isConfigured,
            revision: revision
        ) {
            return access
        }
        return nil
    }

    func isMerchantModeActive(
        accountID: Int?,
        isSignedIn: Bool = true,
        isConfigured: Bool = true,
        revision: UInt64
    ) -> Bool {
        activeMerchantAccess(
            accountID: accountID,
            isSignedIn: isSignedIn,
            isConfigured: isConfigured,
            revision: revision
        ) != nil
    }

    func tabBarState(
        accountID: Int?,
        isSignedIn: Bool,
        isConfigured: Bool,
        revision: UInt64
    ) -> RootTabBarParity.TabBarState {
        let active = isMerchantModeActive(
            accountID: accountID,
            isSignedIn: isSignedIn,
            isConfigured: isConfigured,
            revision: revision
        )
        return RootTabBarParity.TabBarState(
            mode: active ? .merchant : .consumer,
            selectedTab: active ? selectedMerchantTab.rootTab : .mine,
            isAuthenticated: isSignedIn
        )
    }

    func selectBusinessTab(_ tab: MerchantRootBusinessTab) {
        guard requestedMode == .merchant, let access = verifiedAccess, access.active, (access.merchantID ?? 0) > 0 else {
            return
        }
        selectedMerchantTab = tab
    }

    func selectRootTab(_ tab: RootTab) {
        selectBusinessTab(MerchantRootBusinessTab(rootTab: tab))
    }

    /// Asks for merchant mode once when `api/userInfo` says `role=merchant` or `userType=2`.
    /// A consumer hold for the same account and session revision suppresses that request.
    /// `requestMerchantMode` is how that account returns to merchant mode. The role string is not admission.
    func adoptSignedInAccount<Reader: MerchantReading>(
        reader: Reader,
        accountID: Int?,
        role: String,
        userType: Int?,
        isSignedIn: Bool,
        isConfigured: Bool,
        revision: UInt64
    ) async {
        handleSessionChange(accountID: accountID, isSignedIn: isSignedIn, isConfigured: isConfigured, revision: revision)
        guard isConfigured, isSignedIn, let signedInAccount = accountID, signedInAccount > 0 else { return }
        if let held = consumerHold, held == ConsumerModeHold(accountID: signedInAccount, revision: revision) { return }
        let wantsMerchant = RootTabBarParity.initialRequestedMode(role: role, userType: userType) == .merchant
        let key = AutoMerchantRequest(accountID: signedInAccount, revision: revision, wantsMerchant: wantsMerchant)
        if autoMerchantRequest == key { return }
        autoMerchantRequest = key
        anchoredAccountID = signedInAccount
        anchoredRevision = revision
        guard wantsMerchant else { return }
        if isMerchantModeActive(accountID: signedInAccount, isSignedIn: isSignedIn, isConfigured: isConfigured, revision: revision) {
            return
        }
        await requestMerchantMode(reader: reader, accountID: signedInAccount, clearingConsumerHold: false)
    }

    /// Requests switching into Merchant Root Mode by freshly verifying `reader.merchantAccess()`.
    /// Never grants merchant mode from UI intent or unverified role strings.
    @discardableResult
    func requestMerchantMode<Reader: MerchantReading>(
        reader: Reader,
        accountID: Int?,
        initialTab: MerchantRootBusinessTab = .workbench,
        clearingConsumerHold: Bool = true
    ) async -> Bool {
        guard PlayerLaunch.merchantCenterEnabled else { return false } // Lane G: no merchant mode in Release
        if clearingConsumerHold {
            consumerHold = nil
        } else if let held = consumerHold, let currentAccount = accountID, currentAccount > 0,
                  held == ConsumerModeHold(accountID: currentAccount, revision: reader.sessionRevision) {
            return false
        }
        if let currentAccount = accountID, currentAccount > 0 {
            anchoredAccountID = currentAccount
            anchoredRevision = reader.sessionRevision
        }
        verificationGeneration &+= 1
        let generation = verificationGeneration

        guard reader.isConfigured else {
            clearMerchantGrant(errorKey: "auth.notConfigured")
            return false
        }
        guard reader.isSignedIn, let accountID, accountID > 0 else {
            clearMerchantGrant(errorKey: "merchant.signIn")
            return false
        }

        let revision = reader.sessionRevision
        // Previous grant is never usable while access is being verified.
        verifiedAccess = nil
        verifiedAccountID = nil
        verifiedSessionRevision = nil
        requestedMode = .consumer
        selectedMerchantTab = .workbench
        isVerifying = true
        statusErrorKey = nil
        merchantContainerGeneration = UUID()

        do {
            let access = try await reader.merchantAccess()
            try Task.checkCancellation()
            guard generation == verificationGeneration,
                  reader.isConfigured,
                  reader.isSignedIn,
                  reader.sessionRevision == revision else {
                if generation == verificationGeneration { isVerifying = false }
                return false
            }
            guard access.active, let merchantID = access.merchantID, merchantID > 0, access.role != nil else {
                clearMerchantGrant(errorKey: access.application?.titleKey ?? "merchant.access.inactive")
                return false
            }
            verifiedAccess = access
            verifiedAccountID = accountID
            verifiedSessionRevision = revision
            requestedMode = .merchant
            selectedMerchantTab = Self.allowsBusinessTab(initialTab, access: access) ? initialTab : .workbench
            isVerifying = false
            statusErrorKey = nil
            merchantContainerGeneration = UUID()
            return true
        } catch is CancellationError {
            if generation == verificationGeneration {
                isVerifying = false
            }
            return false
        } catch {
            guard generation == verificationGeneration, reader.sessionRevision == revision else {
                if generation == verificationGeneration { isVerifying = false }
                return false
            }
            let key: String
            if error as? MerchantReadError == .accessDenied {
                key = "merchant.access.denied"
            } else if error as? APIError == .unauthorized {
                key = "auth.expired"
            } else if error as? APIError == .malformedResponse {
                key = "merchant.invalidResponse"
            } else {
                key = "merchant.loadFailed"
            }
            clearMerchantGrant(errorKey: key)
            return false
        }
    }

    /// Re-verifies current merchant access and immediately tears down merchant mode if revoked or expired.
    /// When Merchant Root Mode is already active for `(accountID, reader.sessionRevision)`, a cancelled
    /// revalidation read never revokes the active grant, whereas a completed revocation/denial closes it immediately.
    @discardableResult
    func revalidateMerchantMode<Reader: MerchantReading>(
        reader: Reader,
        accountID: Int?
    ) async -> Bool {
        guard reader.isConfigured else {
            clearMerchantGrant(errorKey: "auth.notConfigured")
            return false
        }
        guard reader.isSignedIn, let accountID, accountID > 0 else {
            clearMerchantGrant(errorKey: "merchant.signIn")
            return false
        }
        if let verifiedAccountID, verifiedAccountID != accountID {
            resetConsumerMode()
            return false
        }
        if let verifiedSessionRevision, verifiedSessionRevision != reader.sessionRevision {
            resetConsumerMode()
            return false
        }
        guard let token = beginAccessObservation(accountID: accountID, revision: reader.sessionRevision) else {
            let preservedTab = selectedMerchantTab
            return await requestMerchantMode(reader: reader, accountID: accountID, initialTab: preservedTab)
        }
        do {
            let access = try await reader.merchantAccess()
            try Task.checkCancellation()
            applyObservedMerchantAccess(
                token: token,
                access: access,
                errorKey: nil,
                currentAccountID: accountID,
                currentRevision: reader.sessionRevision
            )
            return isMerchantModeActive(
                accountID: accountID,
                isSignedIn: reader.isSignedIn,
                isConfigured: reader.isConfigured,
                revision: reader.sessionRevision
            )
        } catch is CancellationError {
            return isMerchantModeActive(
                accountID: accountID,
                isSignedIn: reader.isSignedIn,
                isConfigured: reader.isConfigured,
                revision: reader.sessionRevision
            )
        } catch {
            guard !Task.isCancelled else {
                return isMerchantModeActive(
                    accountID: accountID,
                    isSignedIn: reader.isSignedIn,
                    isConfigured: reader.isConfigured,
                    revision: reader.sessionRevision
                )
            }
            let key: String
            if error as? MerchantReadError == .accessDenied {
                key = "merchant.access.denied"
            } else if error as? APIError == .unauthorized {
                key = "auth.expired"
            } else if error as? APIError == .notConfigured {
                key = "auth.notConfigured"
            } else if error as? APIError == .malformedResponse {
                key = "merchant.invalidResponse"
            } else {
                key = "merchant.loadFailed"
            }
            applyObservedMerchantAccess(
                token: token,
                access: nil,
                errorKey: key,
                currentAccountID: accountID,
                currentRevision: reader.sessionRevision
            )
            return false
        }
    }

    /// Captures a strict observation lease at the moment a child merchant surface initiates an access reload.
    /// Returns `nil` when Merchant Root Mode is not currently active for `(accountID, revision)`.
    func beginAccessObservation(accountID: Int?, revision: UInt64) -> MerchantAccessObservationToken? {
        guard requestedMode == .merchant,
              !isVerifying,
              let verifiedAccess,
              verifiedAccess.active,
              (verifiedAccess.merchantID ?? 0) > 0,
              let verifiedAccountID,
              let verifiedSessionRevision,
              let accountID,
              accountID > 0,
              verifiedAccountID == accountID,
              verifiedSessionRevision == revision else {
            return nil
        }
        verificationGeneration &+= 1
        return MerchantAccessObservationToken(
            verificationGeneration: verificationGeneration,
            containerGeneration: merchantContainerGeneration,
            accountID: verifiedAccountID,
            sessionRevision: verifiedSessionRevision
        )
    }

    /// Applies an authoritative merchant access snapshot observed by a child merchant surface (e.g., workbench reload)
    /// using the `token` captured when that reload started.
    /// Rejects late/out-of-order observations and never restores merchant mode after a switch to `.consumer` or revocation.
    func applyObservedMerchantAccess(
        token: MerchantAccessObservationToken,
        access: MerchantAccess?,
        errorKey: String?,
        currentAccountID: Int?,
        currentRevision: UInt64
    ) {
        guard requestedMode == .merchant,
              !isVerifying,
              verifiedAccess != nil,
              let verifiedAccountID,
              let verifiedSessionRevision,
              let currentAccountID,
              currentAccountID > 0,
              verifiedAccountID == currentAccountID,
              verifiedSessionRevision == currentRevision,
              token.accountID == verifiedAccountID,
              token.sessionRevision == verifiedSessionRevision,
              token.containerGeneration == merchantContainerGeneration,
              token.verificationGeneration == verificationGeneration else {
            return
        }
        verificationGeneration &+= 1
        guard errorKey == nil,
              let access,
              access.active,
              let merchantID = access.merchantID,
              merchantID > 0,
              access.role != nil else {
            clearMerchantGrant(errorKey: errorKey ?? access?.application?.titleKey ?? "merchant.access.inactive")
            return
        }
        let previousAccess = verifiedAccess
        verifiedAccess = access
        self.verifiedAccountID = currentAccountID
        self.verifiedSessionRevision = currentRevision
        requestedMode = .merchant
        isVerifying = false
        statusErrorKey = nil
        if !Self.allowsBusinessTab(selectedMerchantTab, access: access) {
            selectedMerchantTab = .workbench
        }
        if previousAccess != access {
            merchantContainerGeneration = UUID()
        }
    }

    /// Switches back to Player/Consumer Mode and destroys all merchant container navigation state.
    /// The choice sticks for the current account and session revision until `requestMerchantMode` or an identity change.
    func switchToConsumerMode() {
        rememberConsumerChoice()
        resetConsumerMode()
    }

    /// Cleans up merchant mode whenever account identity, sign-in state, or session revision changes.
    func handleSessionChange(
        accountID: Int?,
        isSignedIn: Bool,
        isConfigured: Bool,
        revision: UInt64
    ) {
        forgetConsumerChoiceUnlessCurrent(accountID: accountID, isSignedIn: isSignedIn, isConfigured: isConfigured, revision: revision)
        if !isConfigured || !isSignedIn || accountID == nil {
            if requestedMode != .consumer || verifiedAccess != nil || isVerifying || statusErrorKey != nil || selectedMerchantTab != .workbench {
                resetConsumerMode()
            }
            return
        }
        if let verifiedAccountID, verifiedAccountID != accountID {
            resetConsumerMode()
            return
        }
        if let verifiedSessionRevision, verifiedSessionRevision != revision {
            resetConsumerMode()
            return
        }
    }

    private func rememberConsumerChoice() {
        let accountID = verifiedAccountID ?? anchoredAccountID
        let revision = verifiedSessionRevision ?? anchoredRevision
        guard let accountID, accountID > 0, let revision else { return }
        consumerHold = ConsumerModeHold(accountID: accountID, revision: revision)
    }

    private func forgetConsumerChoiceUnlessCurrent(
        accountID: Int?,
        isSignedIn: Bool,
        isConfigured: Bool,
        revision: UInt64
    ) {
        guard let held = consumerHold else { return }
        let current = isConfigured && isSignedIn && held.accountID == accountID && held.revision == revision
        if !current {
            consumerHold = nil
            autoMerchantRequest = nil
        }
    }

    private func resetConsumerMode() {
        verificationGeneration &+= 1
        isVerifying = false
        requestedMode = .consumer
        verifiedAccess = nil
        verifiedAccountID = nil
        verifiedSessionRevision = nil
        selectedMerchantTab = .workbench
        statusErrorKey = nil
        merchantContainerGeneration = UUID()
    }

    func makeModeSwitch(session: AppSession) -> MerchantRootModeSwitch {
        guard PlayerLaunch.merchantCenterEnabled else { return .unavailable } // Lane G: no 商家工作台 switch in Release
        let isActive = isMerchantModeActive(
            accountID: session.account?.id,
            isSignedIn: session.isSignedIn,
            isConfigured: session.isConfigured,
            revision: session.sessionRevision
        )
        return MerchantRootModeSwitch(
            activeMode: isActive ? .merchant : .consumer,
            isVerifying: isVerifying,
            errorKey: statusErrorKey,
            selectedTab: isActive ? selectedMerchantTab.rootTab : .mine,
            requestMode: { [weak self] mode in
                guard let self else { return }
                switch mode {
                case .consumer:
                    self.switchToConsumerMode()
                case .merchant:
                    Task {
                        await self.requestMerchantMode(reader: session, accountID: session.account?.id)
                    }
                }
            },
            selectTab: { [weak self] tab in
                self?.selectRootTab(tab)
            }
        )
    }

    private func clearMerchantGrant(errorKey: String?) {
        isVerifying = false
        requestedMode = .consumer
        verifiedAccess = nil
        verifiedAccountID = nil
        verifiedSessionRevision = nil
        selectedMerchantTab = .workbench
        statusErrorKey = errorKey
        merchantContainerGeneration = UUID()
    }
}

/// Account row and banner for switching between Player Mode (`玩家视角`) and Merchant Root Mode (`商家工作台`).
@MainActor
struct MerchantAccountModeSwitchRow: View {
    let modeSwitch: MerchantRootModeSwitch

    private var bannerState: RootTabBarParity.TabBarState {
        RootTabBarParity.TabBarState(
            mode: modeSwitch.activeMode,
            selectedTab: modeSwitch.selectedTab,
            isAuthenticated: true
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if modeSwitch.activeMode == .merchant {
                Button {
                    modeSwitch(.consumer)
                } label: {
                    Label("rootMode.consumer", systemImage: "arrow.uturn.backward.circle")
                }
                .accessibilityIdentifier("account.consumerRootSwitch")
            } else {
                Button {
                    modeSwitch(.merchant)
                } label: {
                    Label("rootMode.merchant", systemImage: "square.grid.2x2")
                }
                .disabled(modeSwitch.isVerifying)
                .accessibilityIdentifier("account.merchantRootSwitch")
            }

            if modeSwitch.isVerifying {
                ProgressView("merchant.checkingAccess")
                    .font(.footnote)
                    .accessibilityIdentifier("merchant.rootMode.verifying")
            }

            if let errorKey = modeSwitch.errorKey {
                Text(LocalizedStringKey(errorKey))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("merchant.rootMode.error")
            }

            MerchantRootModeSwitchBannerView(
                state: bannerState,
                canSwitchToMerchant: true,
                onSelectMode: { modeSwitch($0) },
                onSelectTab: { tab in
                    if modeSwitch.activeMode == .merchant {
                        modeSwitch.select(tab)
                    }
                }
            )
        }
    }
}

/// Verified Merchant 5-tab Root Container (`工作台`, `营销`, `模板`, `合作`, `我的`) with return/revocation cleanup.
@MainActor
struct SessionMerchantRootContainerView: View {
    @ObservedObject var session: AppSession
    @ObservedObject var coordinator: MerchantRootModeCoordinator
    let access: MerchantAccess
    var onReturnToConsumer: (RootTab?) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedMarketingSuggestion: MerchantInsightDestination?

    private var recommendationOrigin: MerchantInsightOrigin? {
        .init(merchantID: access.merchantID, readerScope: session.merchantOperationsReader.scope)
    }

    var body: some View {
        TabView(selection: $coordinator.selectedMerchantTab) {
            NavigationStack {
                MerchantHomeView(
                    reader: session,
                    marketingModel: session.merchantMarketingCoordinator,
                    marketingDestination: { AnyView(SessionMerchantMarketingDestination(session: session, destination: $0)) },
                    openApplication: { onReturnToConsumer(.mine) },
                    openSignIn: { onReturnToConsumer(.mine) },
                    operationsReader: session.merchantOperationsReader,
                    operationsDestinationFactory: { session.merchantOperationsDestination($0, access: $1) },
                    businessReader: session.merchantBusinessReader,
                    businessJournal: session.merchantBusinessJournal,
                    contentService: session.merchantContentService,
                    cooperationFlowReader: session.cooperationFlowReader,
                    engagementReader: session.merchantEngagementReader,
                    exportRecovery: session.merchantExportRecovery,
                    predictionReader: session.merchantPredictionReader
                )
                .environment(\.merchantPredictionWorkbenchEntry, { AnyView(SessionMerchantPredictionEntry(session: session)) })
                // Same scan-to-redeem destination the Mine tab provides, so the workbench scan entry
                // opens verification instead of the code preview fallback.
                .environment(\.nativeVerificationDestination, {
                    AnyView(SessionNativeVerificationView().modifier(MerchantVerificationPopupCompanionModifier(flow: session.nativeVerificationFlow)))
                })
                .environment(\.merchantAccessObserver, MerchantAccessObservationHook(
                    begin: {
                        coordinator.beginAccessObservation(
                            accountID: session.account?.id,
                            revision: session.sessionRevision
                        )
                    },
                    complete: { token, observedAccess, errorKey in
                        coordinator.applyObservedMerchantAccess(
                            token: token,
                            access: observedAccess,
                            errorKey: errorKey,
                            currentAccountID: session.account?.id,
                            currentRevision: session.sessionRevision
                        )
                    }
                ))
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        switchToConsumerToolbarButton
                    }
                }
            }
            .tabItem { merchantTabLabel(.workbench).accessibilityIdentifier("rootTabBar.tab.merchant.0") }
            .tag(MerchantRootBusinessTab.workbench)

            NavigationStack {
                Group {
                    if MerchantRootModeCoordinator.allowsBusinessTab(.marketing, access: access) {
                        MerchantMarketingView(
                            model: session.merchantMarketingCoordinator,
                            recommendationOrigin: recommendationOrigin,
                            onSuggestion: { route in selectedMarketingSuggestion = route }
                        )
                        // Parity marketing P1: 发活动, 我的内容 / 管理, the coupon deck and 合作机会 open their MP destinations.
                        .environment(\.merchantMarketingLinks, MerchantMarketingLinks(
                            activityPublisher: { AnyView(SessionActivityPublishingDestination().environmentObject(session)) },
                            projects: {
                                AnyView(MerchantProjectsView(reader: session, contentService: session.merchantContentService,
                                                             workspaceReadFactory: session.merchantProjectWorkspaceReadFactory))
                            },
                            coupons: { AnyView(SessionCouponManagementView()) },
                            coopCenter: { session.merchantCoopCenterDestination(initialTab: .plaza) }))
                        .navigationDestination(item: $selectedMarketingSuggestion) { route in
                            Group {
                                if case .recommendation(let target) = route, target.origin != recommendationOrigin {
                                    AnyView(Text("merchantMarketing.stale"))
                                } else if case .cooperationSettings(let origin) = route, origin != recommendationOrigin {
                                    AnyView(Text("merchantMarketing.stale"))
                                } else if case .cooperationCenter(let origin) = route, origin != recommendationOrigin {
                                    AnyView(Text("merchantMarketing.stale"))
                                } else {
                                    AnyView(SessionMerchantMarketingDestination(session: session, destination: route))
                                }
                            }
                            .cyPushedChrome(domain: .merchant)
                        }
                    } else {
                        // MC7-10-2 (marketing/index.wxml:13): 当前身份不能查看营销 + 申请入驻 (or 返回 for a member).
                        MerchantDeniedState(title: "merchant.gate.marketing.denied", identifier: "merchant.marketing")
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        switchToConsumerToolbarButton
                    }
                }
            }
            .tabItem { merchantTabLabel(.marketing).accessibilityIdentifier("rootTabBar.tab.merchant.1") }
            .tag(MerchantRootBusinessTab.marketing)

            NavigationStack {
                Group {
                    if MerchantRootModeCoordinator.allowsBusinessTab(.templates, access: access) {
                        MerchantProjectsView(
                            reader: session,
                            contentService: session.merchantContentService,
                            workspaceReadFactory: session.merchantProjectWorkspaceReadFactory,
                            showsRootHeader: true
                        )
                    } else {
                        SessionMerchantProjectBrowseView(session: session)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        switchToConsumerToolbarButton
                    }
                }
            }
            .tabItem { merchantTabLabel(.templates).accessibilityIdentifier("rootTabBar.tab.merchant.2") }
            .tag(MerchantRootBusinessTab.templates)

            NavigationStack {
                Group {
                    if MerchantRootModeCoordinator.allowsBusinessTab(.cooperation, access: access) {
                        // Parity relation P0: the 合作 tab root is MP 发现 (帖子 / 俱乐部); the cooperation tools list moves
                        // behind the trailing toolbar item instead of being the tab's primary content.
                        SessionCoopRelationDiscoveryView(session: session, reader: session.cooperationFlowReader)
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    NavigationLink {
                                        CooperationFlowWorkbench(reader: session.cooperationFlowReader, operationScope: "MERCHANT")
                                            .cyPushedChrome(domain: .merchant)
                                    } label: { Label("cooprelation.tools", systemImage: "square.grid.2x2") }
                                        .accessibilityIdentifier("merchant.cooperation.tools")
                                }
                            }
                    } else {
                        MerchantFailureView(
                            errorKey: "merchant.access.denied",
                            identifier: "merchant.cooperation",
                            retry: { Task { _ = await coordinator.revalidateMerchantMode(reader: session, accountID: session.account?.id) } },
                            apply: { onReturnToConsumer(.mine) }
                        )
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        switchToConsumerToolbarButton
                    }
                }
            }
            .tabItem { merchantTabLabel(.cooperation).accessibilityIdentifier("rootTabBar.tab.merchant.3") }
            .tag(MerchantRootBusinessTab.cooperation)

            Group {
                if let account = session.account {
                    AccountView(
                        account: account,
                        privateHomeCoordinator: session.privateHomeCoordinator,
                        onOpenGuideDestination: { destination in
                            onReturnToConsumer(destination == .roam ? .roam : .home)
                        }
                    )
                    .id(session.sessionRevision)
                } else {
                    WelcomeView()
                }
            }
            .tabItem { merchantTabLabel(.mine).accessibilityIdentifier("rootTabBar.tab.merchant.4") }
            .tag(MerchantRootBusinessTab.mine)
        }
        .id(coordinator.merchantContainerGeneration)
        .cyScreenStyle()
        .cyTabBarAccessibilityIdentifiers(["rootTabBar.tab.merchant.0", "rootTabBar.tab.merchant.1", "rootTabBar.tab.merchant.2", "rootTabBar.tab.merchant.3", "rootTabBar.tab.merchant.4"])
        .cyTabSelectionFeedback(coordinator.selectedMerchantTab)
        .roleTheme(.merchant)
        .onChange(of: recommendationOrigin) { _, _ in selectedMarketingSuggestion = nil }
        .onChange(of: session.merchantMarketingCoordinator.scopeIdentity) { _, _ in selectedMarketingSuggestion = nil }
        .onChange(of: selectedMarketingSuggestion) { oldValue, newValue in
            if oldValue != nil && newValue == nil {
                Task { _ = await coordinator.revalidateMerchantMode(reader: session, accountID: session.account?.id) }
            }
        }
        .onChange(of: coordinator.selectedMerchantTab) { _, _ in
            Task { _ = await coordinator.revalidateMerchantMode(reader: session, accountID: session.account?.id) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { _ = await coordinator.revalidateMerchantMode(reader: session, accountID: session.account?.id) }
            }
        }
    }

    private var switchToConsumerToolbarButton: some View {
        Button {
            onReturnToConsumer(nil)
        } label: {
            Label("rootMode.consumer", systemImage: "arrow.uturn.backward.circle")
        }
        .accessibilityIdentifier("merchant.rootMode.switchToConsumer")
    }

    private func merchantTabLabel(_ tab: MerchantRootBusinessTab) -> some View {
        CYDomainTabLabel(tab: tab.rootTab, selected: coordinator.selectedMerchantTab.rootTab, domain: .merchant)
    }
}

/// Floating publish button (`+ 发布`) for the Publish/Template tab (`pages/template`).
@MainActor
struct PublishTabFloatingButton: View {
    var title: String = PublishTabFloatingSheetParity.fabButtonTitle
    var action: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        // System prominent capsule button (the one primary action on the tab).
        Button(action: action) {
            Label {
                Text(verbatim: CoreLoopCopy(locale: locale).tr(title))
            } icon: {
                Image(systemName: "plus.circle.fill")
            }
            .frame(minHeight: CYSpacing.minTouchTarget)
            .foregroundStyle(CYColor.textOnAccent)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .accessibilityIdentifier("publishTab.floatingButton")
    }
}

/// Floating publish capability sheet (`pages/template` + `/api/publish/home`).
@MainActor
struct PublishTabFloatingSheetView: View {
    let presentation: PublishTabFloatingSheetParity.SheetPresentation
    var onSelectAction: ((PublishTabFloatingSheetParity.ActionKind) -> Void)? = nil
    var onClose: (() -> Void)? = nil
    @Environment(\.locale) private var locale
    private var copy: CoreLoopCopy { CoreLoopCopy(locale: locale) }

    var body: some View {
        NavigationStack {
            List {
                if let quotaBadgeText = presentation.quotaBadgeText {
                    Section {
                        Label {
                            Text(verbatim: copy.tr(quotaBadgeText))
                        } icon: {
                            Image(systemName: "sparkles").foregroundStyle(.tint)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("publishTab.sheet.quotaBadge")
                    }
                }
                Section {
                    ForEach(presentation.actions) { item in
                        Button {
                            guard item.isEnabled else { return }
                            onSelectAction?(item.kind)
                        } label: {
                            HStack(spacing: CYSpacing.md) {
                                Label {
                                    VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                                        Text(verbatim: copy.tr(item.title))
                                            .foregroundStyle(item.isEnabled ? Color.primary : Color.secondary)
                                        Text(verbatim: copy.tr(item.subtitle))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        if let reason = item.disabledReason, !item.isEnabled {
                                            Text(verbatim: copy.tr(reason))
                                                .font(.footnote)
                                                .foregroundStyle(.orange)
                                                .accessibilityIdentifier("publishTab.sheet.disabledReason.\(item.id)")
                                        }
                                    }
                                } icon: {
                                    Image(systemName: item.systemImage)
                                }
                                Spacer(minLength: CYSpacing.sm)
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                                    .accessibilityHidden(true)
                            }
                            .contentShape(Rectangle())
                        }
                        .disabled(!item.isEnabled)
                        .accessibilityIdentifier("publishTab.sheet.action.\(item.id)")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text(verbatim: copy.tr(presentation.sheetTitle))).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onClose {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(copy.t("关闭", "Close"), action: onClose)
                            .accessibilityIdentifier("publishTab.sheet.close")
                    }
                }
            }
        }
        .themeDomain(.player)
        .cyDomainScreen(.topicEditor)
    }
}

/// Inline segmented mode bar switching between List mode (`pages/search2`) and Map mode (`pages/searchmap`)
/// inside the single unified search screen.
@MainActor
struct UnifiedSearchModeBar: View {
    @Environment(\.locale) private var locale
    @Binding var mode: UnifiedSearchExperience.PresentationMode
    @Binding var mapScope: UnifiedSearchExperience.MapScope

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("", selection: $mode) {
                ForEach(UnifiedSearchExperience.PresentationMode.allCases, id: \.self) { item in
                    Label {
                        Text(verbatim: item.title(locale: locale))
                    } icon: {
                        Image(systemName: item.systemImage)
                    }
                    .tag(item)
                    .accessibilityIdentifier("unifiedSearch.mode.\(item.rawValue)")
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityIdentifier("unifiedSearch.modePicker")

            if mode == .map {
                Picker("", selection: $mapScope) {
                    ForEach(UnifiedSearchExperience.MapScope.allCases, id: \.self) { scope in
                        Text(verbatim: scope.title(locale: locale))
                            .tag(scope)
                            .accessibilityIdentifier("unifiedSearch.mapScope.\(scope.rawValue)")
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityIdentifier("unifiedSearch.mapScopePicker")
            }
        }
    }
}

/// Single unified search screen merging the 3 mini-program search entries (`pages/index`, `pages/search2`, `pages/searchmap`)
/// where Map Search is an inline mode (`.map`) of the same screen rather than a separate pushed page.
@MainActor
struct UnifiedSearchContainerView<Destination: View>: View {
    let reader: any SearchMapReading
    var historyNamespace: String? = nil
    var publicMerchant = PublicMerchantHomeContext()
    var onSignIn: (() -> Void)? = nil
    var recommendedKeywords: [String] = []
    var publicLayers: MapPublicLayerCaller? = nil
    var initialArea: RoamSearchArea? = nil
    let destination: (SearchMapDestination) -> Destination

    @State private var experience: UnifiedSearchExperience

    init(
        reader: any SearchMapReading,
        origin: UnifiedSearchExperience.EntryOrigin = .homeSearchBar,
        initialMode: UnifiedSearchExperience.PresentationMode? = nil,
        initialQuery: GlobalSearchQuery = .init(),
        initialArea: RoamSearchArea? = nil,
        historyNamespace: String? = nil,
        publicMerchant: PublicMerchantHomeContext? = nil,
        onSignIn: (() -> Void)? = nil,
        recommendedKeywords: [String] = [],
        publicLayers: MapPublicLayerCaller? = nil,
        destination: @escaping (SearchMapDestination) -> Destination
    ) {
        self.reader = reader
        self.initialArea = initialArea
        self.historyNamespace = historyNamespace
        self.publicMerchant = publicMerchant ?? PublicMerchantHomeContext()
        self.onSignIn = onSignIn
        self.recommendedKeywords = recommendedKeywords
        self.publicLayers = publicLayers
        self.destination = destination
        _experience = State(initialValue: UnifiedSearchExperience(
            origin: origin,
            mode: initialMode,
            query: initialQuery
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            UnifiedSearchModeBar(
                mode: Binding(
                    get: { experience.mode },
                    set: { experience.switchMode($0) }
                ),
                mapScope: Binding(
                    get: { experience.mapScope },
                    set: { experience.switchMapScope($0) }
                )
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            switch experience.mode {
            case .list:
                GlobalSearchView(
                    reader: reader,
                    historyNamespace: historyNamespace,
                    publicMerchant: publicMerchant,
                    onSignIn: onSignIn,
                    recommendedKeywords: recommendedKeywords,
                    publicLayers: publicLayers,
                    destination: destination
                )
                .accessibilityIdentifier("unifiedSearch.surface.list")
            case .map:
                SearchMapExplorerView(
                    reader: reader,
                    mode: experience.mapScope == .city ? .city : .nearby,
                    initialFilter: experience.query,
                    initialArea: initialArea,
                    onSignIn: onSignIn,
                    destination: destination
                )
                .id(experience.mapScope)
                .accessibilityIdentifier("unifiedSearch.surface.map")
            }
        }
        .accessibilityIdentifier("unifiedSearch.container")
    }
}


/// verify-r1 2.5: extra 首页 更多玩法 menu entries supplied by the session root (square, official events, templates,
/// project editor), each with its old accessibility identifier.
private struct HomeMoreMenuContentKey: EnvironmentKey {
    static let defaultValue: AnyView? = nil
}

extension EnvironmentValues {
    var homeMoreMenuContent: AnyView? {
        get { self[HomeMoreMenuContentKey.self] }
        set { self[HomeMoreMenuContentKey.self] = newValue }
    }
}
