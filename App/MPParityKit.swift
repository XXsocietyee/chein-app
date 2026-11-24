import SwiftUI

// Mini-program parity kit (ui/mpmissing). Layout only: the screens built on this kit take display-ready values
// and hand intents back to a host. Reads, writes, request ids, and reason-code mapping belong to the bindings
// Cursor provides (see `MPParityBindings`). Nothing here talks to the network and nothing here holds mock data.

// MARK: - Commerce gate

/// Purchase, payment, payout, withdrawal and claim of virtual goods stay OFF in this release.
/// Screens still draw the offer read-only (price, plans, checkout summary) with one calm sentence instead of a live CTA.
enum MPCommerceGate {
    static let purchasesEnabled = false
    static let claimsEnabled = false
    static let payoutEnabled = false
}

// MARK: - Load phase

/// Common read phase. `failed` carries an already-localized server sentence when the binding has one; nil falls back to
/// the screen's own copy. Unknown is never drawn as 0: a missing number travels as nil and renders as an em dash.
enum MPLoad<Value: Equatable>: Equatable {
    case loading
    case failed(String?)
    case ready(Value)

    var value: Value? { if case .ready(let value) = self { return value } else { return nil } }
}

enum MPText {
    static let unknown = "—"
    static func orDash(_ value: String?) -> String {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return unknown }
        return value
    }
    static func orDash(_ value: Int?) -> String { value.map(String.init) ?? unknown }
}

// MARK: - Bindings (stubs for Cursor)

/// Host-provided factories. Every entry is nil by default, and a nil entry hides its row, link and route
/// (capability absent => hidden). Cursor fills these at the player root once the readers exist.
struct MPParityBindings {
    var videoBounty: (@MainActor () -> any VideoBountyBinding)?
    var passMarket: (@MainActor () -> any PassMarketBinding)?
    var passDetail: (@MainActor (_ productID: String) -> any PassDetailBinding)?
    var passGift: (@MainActor (_ token: String) -> any PassGiftClaimBinding)?
    var membership: (@MainActor () -> any PassMembershipBinding)?
    var passLibrary: (@MainActor () -> any PassLibraryBinding)?
    var passOrder: (@MainActor (_ orderNo: String) -> any PassOrderDetailBinding)?
    var journeyLanding: (@MainActor (_ link: JourneyLandingLink) -> any JourneyLandingBinding)?
    var journeySeats: (@MainActor (_ registrationID: String) -> any JourneySeatsBinding)?
    var journeyPromo: (@MainActor () -> any JourneyPromoBinding)?
    var journeyReport: (@MainActor (_ scope: JourneyRunScope) -> any JourneyReportBinding)?
    var journeySettle: (@MainActor (_ scope: JourneyRunScope) -> any JourneySettleBinding)?
    /// Account key used to remember "reveal already played" per account. Nil plays the short (idle) reveal.
    var revealAccountKey: (@MainActor () -> String?)?
    /// Merchant view (`roleGuard.isMerchantView`): merchants have no pass, so the 我的 row, the Explore store card and the
    /// checkout city-pass rows hide, and the reveal shows the one-sentence merchant state. Nil = player.
    var viewerIsMerchant: (@MainActor () -> Bool)?
    /// True when a player session can read private pass data (gift claim, pass orders).
    var isSignedIn: (@MainActor () -> Bool)?
    /// Explore store card (`utils/discover-store-card.js`): nil result = nothing on sale, card hidden.
    var passStoreCard: (@MainActor () async -> PassStoreCard?)?
    /// Theme checkout (`self-play-checkout`): pass coverage of one topic + on-sale city passes that cover it.
    var passCheckoutCover: (@MainActor (_ topicID: Int) async -> PassCheckoutCover?)?
    /// Order detail (`subpackageMember/orderinfo?id=`), used by gift claim "view" when the claim returned a registration.
    var orderDetail: (@MainActor (_ registrationID: String) -> AnyView)?

    @MainActor var isMerchant: Bool { viewerIsMerchant?() ?? false }

    static let none = MPParityBindings()
}

private struct MPParityBindingsKey: EnvironmentKey {
    static let defaultValue = MPParityBindings.none
}

extension EnvironmentValues {
    var mpParity: MPParityBindings {
        get { self[MPParityBindingsKey.self] }
        set { self[MPParityBindingsKey.self] = newValue }
    }
}

/// Run scope shared by report / settle (mini-program query `activityId`, `topicId`, `runId`, `topicName`).
struct JourneyRunScope: Hashable {
    var activityID: String?
    var topicID: String?
    var runID: String?
    var topicName: String?
    var registrationID: String?
    /// The viewer's `play_team` id when the run is a team run. Only this opens the in-team member board.
    var teamID: String?
}

// MARK: - Routes

/// Mini-program pages built on this branch, addressable from a deep link or an in-app entry.
/// Parsing the path is a convenience for the host router; presenting a route still needs its binding.
enum MPParityRoute: Hashable, Identifiable {
    case videoBounty(campaignKey: String?, topicID: String?)
    case passes(tab: PassMarketTab)
    case pass(productID: String)
    case gift(token: String)
    case membership
    case library(kind: PassLibraryKind)
    /// `subpackageMember/market/pass-order/index?orderNo=`: one city-pass order, read only.
    case passOrder(orderNo: String)
    case reveal(paid: PassRevealPaidFacts?)
    case journeyLanding(JourneyLandingLink)
    case journeySeats(registrationID: String)
    case journeyPromo
    case journeyReport(JourneyRunScope)
    case journeySettle(JourneyRunScope)
    /// WP-01 payout pages. They need no binding: each reads through `PayoutReceiverBridge` and shows one closed
    /// sentence while the payout area is off (production host, Release).
    case clubPayoutReceiver(clubID: Int?, mine: Bool)
    case merchantPayoutAccount
    case clubSettlement(clubID: Int?, mine: Bool, personal: Bool)
    /// `subpackageMember/order/order`. Signup, start, and refund subscribe messages share this list.
    case playerOrderList
    /// `pages/coop/list/index`. Absent `tab` is received; `tab=sent` is the sender list.
    case coopList(CooperationDirection)
    /// `subpackageA/pages/myproject/index`.
    case myProjects
    /// `pages/merchant/ledger/index`. Read-only settlement overview. Payout stays off.
    case merchantLedger
    /// A page-map path whose native screen already exists. The query is the one `MiniProgramPageLink` accepted.
    case screen(page: String, query: [String: String])

    var id: Self { self }

    /// `subpackageMember/market/passes/index?tab=orders` style input. Unknown or malformed pages/parameters return nil.
    init?(miniProgramPath path: String, query: [String: String]) {
        guard !path.contains("\\"), !path.contains(".."), !path.contains("://"),
              !path.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }) else { return nil }
        let page = path.hasPrefix("/") ? String(path.dropFirst()) : path
        func nonEmpty(_ key: String) -> String? {
            guard let v = query[key], !v.isEmpty, v.utf16.count <= 512,
                  v.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value != 127 }) else { return nil }
            return v
        }
        func positiveID(_ key: String) -> Int? {
            guard let raw = nonEmpty(key), raw.utf8.count <= 18,
                  raw.utf8.allSatisfy({ (48...57).contains($0) }),
                  let value = Int(raw), value > 0, String(value) == raw else { return nil }
            return value
        }
        func positiveIDString(_ key: String) -> String? { positiveID(key).map(String.init) }
        func safeIdentifier(_ key: String) -> String? {
            guard let v = nonEmpty(key),
                  v.range(of: "\\A[A-Za-z0-9._-]{1,64}\\z", options: .regularExpression) != nil else { return nil }
            return v
        }
        switch page {
        case "subpackageA/pages/video-bounty/index":
            if query["topicId"]?.isEmpty == false && positiveIDString("topicId") == nil { return nil }
            if query["campaignKey"]?.isEmpty == false && safeIdentifier("campaignKey") == nil { return nil }
            self = .videoBounty(campaignKey: safeIdentifier("campaignKey"), topicID: positiveIDString("topicId"))
        case "subpackageMember/market/passes/index":
            self = .passes(tab: query["tab"].flatMap(PassMarketTab.init(rawValue:)) ?? .shop)
        case "subpackageMember/market/pass/index":
            // R7-MEM-2-1: no id opens the page's missing state (商品不存在或已下架 + 返回), as MP load() does.
            if query["id"]?.isEmpty ?? true { self = .pass(productID: ""); return }
            guard let id = safeIdentifier("id") else { return nil }
            self = .pass(productID: id)
        case "subpackageMember/market/gift/index":
            // A missing token still opens the page, which shows the shared missing-link state (MKT-3-2).
            guard let token = nonEmpty("token") else { self = .gift(token: ""); return }
            guard !token.contains(".."), !token.contains("://") else { return nil }
            self = .gift(token: token)
        case "subpackageMember/market/membership/index":
            self = .membership
        case "subpackageMember/market/library/index":
            self = .library(kind: query["kind"].flatMap(PassLibraryKind.init(rawValue:)) ?? .all)
        case "subpackageMember/market/pass-order/index":
            // R7-MEM-5-1: no orderNo opens the missing-param state + 返回 (MP PG-041), not a read with an empty number.
            if query["orderNo"]?.isEmpty ?? true { self = .passOrder(orderNo: ""); return }
            guard let orderNo = nonEmpty("orderNo"), PlatformPassSubscriptionOrder.orderNoAllowed(orderNo) else { return nil }
            self = .passOrder(orderNo: orderNo)
        case "subpackagePass/reveal/index":
            // Paid reveal facts come only from verified in-app purchase flow, never from URL query params.
            self = .reveal(paid: nil)
        case "subpackageJourney/pages/landing/index":
            guard let link = JourneyLandingLink(query: query) else { return nil }
            self = .journeyLanding(link)
        case "subpackageJourney/pages/seats/index":
            guard let id = positiveIDString("registrationId") else { return nil }
            self = .journeySeats(registrationID: id)
        case "subpackageJourney/pages/promo/index":
            self = .journeyPromo
        case "subpackageJourney/pages/report/index", "subpackageJourney/pages/settle/index":
            for numericKey in ["activityId", "topicId", "runId", "registrationId", "teamId"] {
                if query[numericKey]?.isEmpty == false && positiveIDString(numericKey) == nil { return nil }
            }
            if let topicName = nonEmpty("topicName"), topicName.count > 128 { return nil }
            let scope = JourneyRunScope(activityID: positiveIDString("activityId"), topicID: positiveIDString("topicId"),
                                        runID: positiveIDString("runId"), topicName: nonEmpty("topicName"),
                                        registrationID: positiveIDString("registrationId"), teamID: positiveIDString("teamId"))
            self = page.hasSuffix("report/index") ? .journeyReport(scope) : .journeySettle(scope)
        case "pages/club/payout-receiver/index":
            let club = positiveID("clubId") ?? positiveID("id")
            if (nonEmpty("clubId") ?? nonEmpty("id")) != nil && club == nil { return nil }
            let mine = query["mine"] == "1"
            guard club != nil || mine else { return nil }
            self = .clubPayoutReceiver(clubID: club, mine: mine)
        case "pages/merchant/payout-account/index":
            self = .merchantPayoutAccount
        case "pages/club/settlement/index":
            let club = positiveID("clubId") ?? positiveID("id")
            if (nonEmpty("clubId") ?? nonEmpty("id")) != nil && club == nil { return nil }
            let mine = query["mine"] == "1"
            guard club != nil || mine else { return nil }
            self = .clubSettlement(clubID: club, mine: mine, personal: query["personal"] == "1")
        case "subpackageMember/order/order":
            if query["detailId"]?.isEmpty == false {
                guard let id = positiveIDString("detailId") else { return nil }
                self = .screen(page: "subpackageMember/orderinfo/orderinfo", query: ["id": id])
            } else {
                self = .playerOrderList
            }
        case "pages/coop/list/index":
            self = .coopList(query["tab"] == "sent" ? .sent : .received)
        case "subpackageA/pages/myproject/index":
            self = .myProjects
        case "pages/merchant/ledger/index":
            self = .merchantLedger
        default:
            // The page's link rule still applies on internal paths: parity r1 gave several pages required keys
            // (club governance `clubId`, customer-detail `memberId`, …), so a bare path must not open them.
            guard MiniProgramPageLink.reviewedPages[page] != nil, MiniProgramPageLink(path: page, query: query) != nil else { return nil }
            self = .screen(page: page, query: query)
        }
    }
}

/// Resolves a route to its screen when the binding exists; otherwise a quiet "not available" state.
@MainActor struct MPParityDestination: View {
    let route: MPParityRoute
    @Environment(\.mpParity) private var bindings

    var body: some View {
        switch route {
        case .videoBounty(let campaignKey, let topicID):
            if let make = bindings.videoBounty { VideoBountyHost(binding: make(), campaignKey: campaignKey, topicID: topicID) } else { unavailable }
        case .passes(let tab):
            if let make = bindings.passMarket { PassMarketHost(binding: make(), initialTab: tab) } else { unavailable }
        case .pass(let id) where id.isEmpty:
            MemberMissingLinkState(title: "g6.product.reason.PRODUCT_NOT_FOUND", identifier: "passDetail.missing")
        case .passOrder(let orderNo) where orderNo.isEmpty:
            MemberMissingLinkState(identifier: "passOrder.missing")
        case .pass(let id):
            if let make = bindings.passDetail { PassDetailHost(binding: make(id)) } else { unavailable }
        case .gift(let token):
            if token.isEmpty {
                // MP cy-empty missing-param: 链接已失效 + 返回 (the deep-link sheet has no system back).
                MemberMissingLinkState(title: "mp.gift.linkInvalid", identifier: "passGift.missing")
            } else if bindings.isSignedIn?() == false {
                CYStateLayout(kind: .generic, title: Text("mp.gift.signIn"),
                              primary: (title: "mp.pass.signIn.action", action: { PlayerJourneySignInBridge.shared.request() }),
                              primaryStyle: .primary, primaryIdentifier: "passGift.signIn")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let make = bindings.passGift { PassGiftClaimHost(binding: make(token)) } else { unavailable }
        case .membership:
            if let make = bindings.membership { PassMembershipHost(binding: make()) } else { unavailable }
        case .library(let kind):
            if let make = bindings.passLibrary { PassLibraryHost(binding: make(), initialKind: kind) } else { unavailable }
        case .passOrder(let orderNo):
            if let make = bindings.passOrder { PassOrderDetailHost(binding: make(orderNo)) } else { unavailable }
        case .reveal(let paid):
            PassRevealView(paid: paid, accountKey: bindings.revealAccountKey?(), isMerchant: bindings.isMerchant)
        case .journeyLanding(let link):
            if let make = bindings.journeyLanding { JourneyLandingHost(binding: make(link)) } else { unavailable }
        case .journeySeats(let id):
            if let make = bindings.journeySeats { JourneySeatsHost(binding: make(id)) } else { unavailable }
        case .journeyPromo:
            if let make = bindings.journeyPromo { JourneyPromoHost(binding: make()) } else { unavailable }
        case .journeyReport(let scope):
            if let make = bindings.journeyReport { JourneyReportHost(binding: make(scope), scope: scope) } else { unavailable }
        case .journeySettle(let scope):
            if let make = bindings.journeySettle { JourneySettleHost(binding: make(scope), scope: scope) } else { unavailable }
        case .clubPayoutReceiver(let clubID, let mine):
            ClubPayoutReceiverView(clubID: clubID, mine: mine)
        case .merchantPayoutAccount:
            MerchantPayoutAccountView()
        case .clubSettlement(let clubID, let mine, let personal):
            if let clubID { ClubPersonalSettlementView(clubID: clubID, personal: personal) } else if mine { ClubSettlementMineView() } else { unavailable }
        case .playerOrderList, .coopList, .myProjects, .merchantLedger:
            SubscribeMessageTapEntry(route: route)
        case .screen(let page, let query):
            MPReviewedPageScreen(page: page, query: query)
        }
    }

    private var unavailable: some View {
        CYEmptyState(systemImage: "tray", "mp.route.unavailable", messageIdentifier: "mp.route.unavailable")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CYNight.ink0.ignoresSafeArea())
    }
}

extension View {
    /// Pushes a parity route inside the caller's NavigationStack (deep links, cross-screen links).
    func mpParityRouteDestination(_ route: Binding<MPParityRoute?>) -> some View {
        navigationDestination(item: route) { MPParityDestination(route: $0) }
    }
}

// MARK: - Layout pieces

/// Pure canvas (`CYColor.bgPage`) with an optional single warm lantern glow at the top for hero reward/pass stages.
struct MPNightGround: View {
    var glow = false
    var body: some View {
        ZStack(alignment: .top) {
            CYColor.bgPage
            if glow {
                CYNight.glow(radius: 160).frame(height: 360).offset(y: -80).opacity(0.45)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Borderless flat grouped card (`cyDomainCard` surface, zero outer stroke).
struct MPCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .cyDomainCard(radius: CYRadius.lg, padding: 0)
    }
}

/// Title + optional sub line on the left, a value on the right (stacks at AX sizes). Text is already resolved (server or catalog).
struct MPRow: View {
    let title: Text
    var sub: Text? = nil
    var value: Text? = nil
    var strong = false
    var muted = false
    var chevron = false
    var leading: AnyView? = nil
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let stack = typeSize.isAccessibilitySize && value != nil
        let layout = stack
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.xs))
            : AnyLayout(HStackLayout(alignment: .center, spacing: CYSpacing.md))
        HStack(alignment: .center, spacing: CYSpacing.md) {
            if let leading { leading }
            layout {
                VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                    title.cyText(.bodyMedium)
                        .foregroundStyle(muted ? CYColor.textTertiary : CYColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let sub {
                        sub.cyText(.meta)
                            .foregroundStyle(CYColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if !stack { Spacer(minLength: CYSpacing.sm) }
                if let value {
                    value.font(strong ? CYTypography.cardTitle : CYTypography.bodyCompact)
                        .monospacedDigit()
                        .foregroundStyle(muted ? CYColor.textTertiary : (strong ? CYColor.textPrimary : CYColor.textSecondary))
                        .multilineTextAlignment(stack ? .leading : .trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if stack { Spacer(minLength: 0) }
            if chevron {
                Image(systemName: "chevron.right").cyText(.caption).foregroundStyle(CYColor.textTertiary).accessibilityHidden(true)
            }
        }
        .padding(.horizontal, CYSpacing.lg)
        .padding(.vertical, CYSpacing.md)
        .frame(minHeight: CYSpacing.minTouchTarget)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Hairline between rows inside an `MPCard`.
struct MPDivider: View {
    var body: some View { Rectangle().fill(CYColor.borderSubtle).frame(height: 0.5).padding(.leading, CYSpacing.lg).accessibilityHidden(true) }
}

/// Rows separated by hairlines.
struct MPRows<Item: Identifiable, Row: View>: View {
    let items: [Item]
    @ViewBuilder let row: (Item) -> Row
    var body: some View {
        MPCard {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { MPDivider() }
                row(item)
            }
        }
    }
}

struct MPSectionHeader: View {
    let title: LocalizedStringKey
    var body: some View {
        Text(title).cyText(.label).foregroundStyle(CYColor.textSecondary)
            .textCase(nil)
            .padding(.horizontal, CYSpacing.xs)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Chip tabs with a sliding selection pill (matched geometry; cross-fade under Reduce Motion).
struct MPChipTabs<Tab: Hashable & Identifiable>: View {
    let tabs: [Tab]
    @Binding var selection: Tab?
    let title: (Tab) -> Text
    var identifier: (Tab) -> String
    @Namespace private var pill

    init(tabs: [Tab], selection: Binding<Tab?>, title: @escaping (Tab) -> Text, identifier: @escaping (Tab) -> String = { "mp.tab.\($0.id)" }) {
        self.tabs = tabs; self._selection = selection; self.title = title; self.identifier = identifier
    }

    init(tabs: [Tab], selection: Binding<Tab>, title: @escaping (Tab) -> Text, identifier: @escaping (Tab) -> String = { "mp.tab.\($0.id)" }) {
        self.init(tabs: tabs, selection: Binding<Tab?>(get: { selection.wrappedValue }, set: { if let new = $0 { selection.wrappedValue = new } }),
                  title: title, identifier: identifier)
    }
    @QuestifyReduceMotion private var reduceMotion

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CYSpacing.sm) {
                ForEach(tabs) { tab in
                    let on = tab == selection
                    Button {
                        withAnimation(CYMotion.resolve(.spring(response: 0.32, dampingFraction: 0.82), reduceMotion: reduceMotion)) { selection = tab }
                    } label: {
                        title(tab)
                            .cyText(.label)
                            .foregroundStyle(on ? CYColor.textOnAccent : CYColor.textSecondary)
                            .padding(.horizontal, CYSpacing.lg)
                            .frame(minHeight: 36)
                            .background {
                                if on {
                                    Capsule(style: .continuous).fill(CYColor.selection).matchedGeometryEffect(id: "pill", in: pill)
                                } else {
                                    Capsule(style: .continuous).fill(CYColor.bgElevated)
                                }
                            }
                            .frame(minHeight: CYSpacing.minTouchTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? [.isSelected] : [])
                    .accessibilityIdentifier(identifier(tab))
                    .cyHaptic(.selection, trigger: on)
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
        }
        .accessibilityElement(children: .contain)
    }
}

/// Read-only note used where a commerce or claim CTA would sit while the gate is OFF.
struct MPGatedNote: View {
    let text: Text
    var identifier: String = "mp.gated"
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
            Image(systemName: "lock").cyText(.caption).accessibilityHidden(true)
            text.cyText(.meta).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(CYColor.textSecondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, CYSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }
}

/// Inline error under a field or above a bottom bar (mini-program `cy-inline-error`).
struct MPInlineError: View {
    let text: Text
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.xs) {
            Image(systemName: "exclamationmark.circle.fill").accessibilityHidden(true)
            text.fixedSize(horizontal: false, vertical: true)
        }
        .cyText(.meta)
        .foregroundStyle(CYColor.dangerText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Bottom bar delegating to `CYFooterBar` (one primary action per screen).
struct MPBottomBar<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        CYFooterBar {
            VStack(spacing: CYSpacing.sm) { content }
        }
    }
}

/// Avatar circle: remote image when present, else an initial.
struct MPAvatar: View {
    let url: URL?
    let initial: String
    var size: CGFloat = 40
    var body: some View {
        ZStack {
            Circle().fill(CYNight.ink2)
            if let url {
                AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Text(verbatim: initial).cyText(.label) }
                    .clipShape(Circle())
            } else {
                Text(verbatim: initial).cyText(.label).foregroundStyle(CYColor.textPrimary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Standard read-state switch for a whole screen: skeleton, error with retry, or content.
struct MPLoadSwitch<Value: Equatable, Content: View>: View {
    let load: MPLoad<Value>
    let errorTitle: LocalizedStringKey
    let identifier: String
    let onRetry: () -> Void
    @ViewBuilder let content: (Value) -> Content

    var body: some View {
        switch load {
        case .loading:
            CYLoadingStateView(rows: 3)
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .accessibilityIdentifier("\(identifier).loading")
        case .failed(let message):
            CYStateLayout(kind: .failure, title: message.map { Text(verbatim: $0) } ?? Text(errorTitle),
                          primary: (title: "action.retry", action: onRetry), primaryStyle: .secondary, primaryIdentifier: "\(identifier).retry")
                .accessibilityIdentifier("\(identifier).error")
        case .ready(let value):
            content(value)
        }
    }
}
