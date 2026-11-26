import CoreFoundation
import SwiftUI

// Mini-program `subpackageMember/market/passes` (list: on sale / my orders / gifts), `market/pass` (detail + quote),
// and `market/gift` (claim a gift). Purchase and gift claim stay OFF (`MPCommerceGate`): the offer and the quote are
// drawn read-only with one sentence where the pay buttons would be. Every number is a server fact; unknown is an em dash.

enum PassMarketTab: String, CaseIterable, Identifiable, Hashable {
    case shop, orders, gifts
    var id: String { rawValue }
    var title: LocalizedStringKey {
        switch self {
        case .shop: "mp.pass.tab.shop"
        case .orders: "mp.pass.tab.orders"
        case .gifts: "mp.pass.tab.gifts"
        }
    }
}

/// Server `productKind` 1...8.
enum PassProductKind: Int, Equatable {
    case singleLevel = 1, cityBundle, timedPass, fixedYear, group, schoolGroup, giftPass, extraSeat
    var label: LocalizedStringKey {
        switch self {
        case .singleLevel: "mp.pass.kind.single"
        case .cityBundle: "mp.pass.kind.city"
        case .timedPass: "mp.pass.kind.timed"
        case .fixedYear: "mp.pass.kind.year"
        case .group: "mp.pass.kind.group"
        case .schoolGroup: "mp.pass.kind.school"
        case .giftPass: "mp.pass.kind.gift"
        case .extraSeat: "mp.pass.kind.extraSeat"
        }
    }
}

/// Validity wording: fixed periods are a fixed period (never "subscription"); first-use products count from first play.
enum PassValidity: Equatable {
    case daysAfterPurchase(Int)
    case fixedRange(from: String, to: String)
    case fixedUntil(String)
    case daysFromFirstPlay(Int)

    var text: Text {
        switch self {
        case .daysAfterPurchase(let days): Text("mp.pass.validity.afterPurchase \(days)")
        case .fixedRange(let from, let to): Text(verbatim: "\(from) – \(to)")
        case .fixedUntil(let to): Text("mp.pass.validity.until \(to)")
        case .daysFromFirstPlay(let days): Text("mp.pass.validity.firstPlay \(days)")
        }
    }
}

struct PassProductCard: Identifiable, Equatable {
    let id: String
    let name: String
    let kind: PassProductKind?
    let city: String?
    let validity: PassValidity?
    /// Seats when more than one (one-person products show no seat line).
    let seats: Int?
    /// "¥99.00" (cash) and points; both nil means no price line (never 0).
    let cashPriceText: String?
    let pointsPrice: Int?
    let topics: [String]
    let giftAllowed: Bool
    let giftOnly: Bool
    let isExtraSeat: Bool
    /// Ticket face text for the hero (server city / kind).
    let faceText: String?

    var coverCount: Int { topics.count }
}

enum PassOrderState: Equatable {
    case paid, paidAwaitingFirstPlay, paidGift
    case pendingCash(blockedReason: String?)
    case cancelled, refunded, unknown

    var text: Text {
        switch self {
        case .paid: Text("mp.pass.order.paid")
        case .paidAwaitingFirstPlay: Text("mp.pass.order.awaitingFirstPlay")
        case .paidGift: Text("mp.pass.order.paidGift")
        case .pendingCash(let reason):
            if let reason { Text("mp.pass.order.pendingReason \(reason)") } else { Text("mp.pass.order.pending") }
        case .cancelled: Text("mp.pass.order.cancelled")
        case .refunded: Text("mp.pass.order.refunded")
        case .unknown: Text("mp.common.statusUnknown")
        }
    }
}

struct PassOrderRow: Identifiable, Equatable {
    let id: String
    /// Product name when the catalog knows it; nil reads "Pass order".
    let name: String?
    let state: PassOrderState
    let amountText: String?
    let timeText: String?
}

enum PassGiftStatus: Equatable { case pending, claimed, expired, revoked, unknown }

struct PassGiftRow: Identifiable, Equatable {
    let id: String
    let status: PassGiftStatus
    let claimDeadlineText: String?
    let timeText: String?

    func stateText(bought: Bool) -> Text {
        switch status {
        case .pending: bought ? Text("mp.pass.gift.pendingBought") : Text("mp.pass.gift.pending")
        case .claimed: Text("mp.pass.gift.claimed")
        case .expired: Text("mp.pass.gift.expired")
        case .revoked: bought ? Text("mp.pass.gift.revokedBought") : Text("mp.pass.gift.revoked")
        case .unknown: Text("mp.common.statusUnknown")
        }
    }
}

/// Platform pass (membership) entry on the shop tab; nil when the server says the pass is not enabled or the account is a merchant.
enum PassMemberEntrySide: Equatable {
    case activeUntil(String)
    case plans(String)
    case themeCount(Int)
    case none
}

struct PassMarketContent: Equatable {
    var products: [PassProductCard]
    var orders: [PassOrderRow]
    var giftsBought: [PassGiftRow]
    var giftsReceived: [PassGiftRow]
    /// City-pass subscription orders (`GET /api/platform-pass/orders`), listed first in 我的订单.
    var passOrders: [PlatformPassSubscriptionOrder] = []
}

struct PassMarketState: Equatable {
    var content: MPLoad<PassMarketContent> = .loading
    /// `/api/user/info.point`; nil hides the balance card (never 0).
    var pointBalance: Int? = nil
    var member: PassMemberEntrySide? = nil
    /// Quiet refresh failed while content stays on screen.
    var refreshFailed = false
    /// False for a guest: the on-sale tab still loads; 我的订单 and 礼品 ask to sign in.
    var signedIn = true
    /// `ChannelRedeemSource.status`. The 兑换码 row is shown only when this is true.
    var platformCodeEnabled = false
}

/// Logic stub for Cursor: `/api/marketing/product/list|orders|gifts/bought|gifts/received`, `/api/platform-pass`, `/api/user/info`.
@MainActor protocol PassMarketBinding: AnyObject, Observable {
    var state: PassMarketState { get }
    func load(quiet: Bool)
}

@MainActor struct PassMarketHost: View {
    let binding: any PassMarketBinding
    var initialTab: PassMarketTab = .shop
    @State private var route: MPParityRoute?
    @State private var loadedOnce = false
    /// MP passes `redeemEnabled`: only a signed-in player whose status read says on sees the 兑换码 row.
    @State private var redeemEnabled = false
    @Environment(\.mpParity) private var bindings
    /// Points history (`POST /api/points/list`). Nil keeps the balance card read-only.
    @Environment(\.passMarketPointsDestination) private var pointsDestination

    var body: some View {
        PassMarketView(state: binding.state, initialTab: initialTab,
                       onReload: { binding.load(quiet: $0) },
                       onOpenProduct: bindings.passDetail == nil ? nil : { route = .pass(productID: $0) },
                       onOpenMembership: { route = .reveal(paid: nil) },
                       onOpenLibrary: bindings.passLibrary == nil ? nil : { route = .library(kind: .all) },
                       pointsDestination: pointsDestination,
                       onOpenPassOrder: bindings.passOrder == nil ? nil : { route = .passOrder(orderNo: $0) },
                       onSignIn: { PlayerJourneySignInBridge.shared.request() },
                       onOpenPlatformCode: { route = .platformCode },
                       onOpenRedeem: redeemEnabled ? { route = .platformCode } : nil)
            // Mini-program onShow: the first appearance loads with a skeleton; coming back (from detail, reveal,
            // membership) refreshes quietly so a list already on screen never flashes back to loading.
            .task {
                binding.load(quiet: loadedOnce)
                loadedOnce = true
                // MP loadRedeem(): signed out, closed or unreadable → no row.
                if bindings.isSignedIn?() == true, let read = bindings.passRedeemEnabled { redeemEnabled = await read() }
                else { redeemEnabled = false }
            }
            .mpParityRouteDestination($route)
    }
}

struct PassMarketView: View {
    let state: PassMarketState
    var initialTab: PassMarketTab = .shop
    let onReload: (_ quiet: Bool) -> Void
    let onOpenProduct: ((String) -> Void)?
    let onOpenMembership: () -> Void
    let onOpenLibrary: (() -> Void)?
    /// Points history destination (mini-program `points-history`); nil keeps the balance card read-only.
    let pointsDestination: (() -> AnyView)?
    /// City-pass order row → `market/pass-order?orderNo=`. Nil keeps the rows read-only.
    var onOpenPassOrder: ((String) -> Void)? = nil
    /// Guest on 我的订单 / 礼品: `ensureLoginFor('登录后查看自己的订单和礼品')`.
    var onSignIn: (() -> Void)? = nil
    /// Opens `market/gift?mode=code` when the server says platform codes are on.
    var onOpenPlatformCode: (() -> Void)? = nil
    /// MP 兑换码 row (`goRedeem` → `gift?mode=code`) from the host's own status read. Nil hides it unless
    /// `state.platformCodeEnabled` already shows the row.
    var onOpenRedeem: (() -> Void)? = nil

    @State private var tab: PassMarketTab = .shop
    @State private var didSetTab = false
    /// Continuity r1 (10): the balance card is the zoom source of the points ledger it opens.
    @Namespace private var pointsHero

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                if let balance = state.pointBalance { balanceCard(balance).padding(.horizontal, CYSpacing.pageHorizontal) }
                MPChipTabs(tabs: PassMarketTab.allCases, selection: $tab, title: { Text($0.title) }, identifier: { "passMarket.tab.\($0.rawValue)" })
                if state.refreshFailed {
                    CYOfflineStrip().padding(.horizontal, CYSpacing.pageHorizontal)
                }
                MPLoadSwitch(load: state.content, errorTitle: "mp.common.loadFailed", identifier: "passMarket", onRetry: { onReload(false) }) { content in
                    Group {
                        switch tab {
                        case .shop: shop(content)
                        case .orders where !state.signedIn, .gifts where !state.signedIn: signInPrompt
                        case .orders: orders(content)
                        case .gifts: gifts(content)
                        }
                    }
                    .padding(.horizontal, CYSpacing.pageHorizontal)
                    .transition(.opacity)
                }
            }
            .padding(.vertical, CYSpacing.lg)
        }
        .cyAnimation(value: tab)
        .refreshable { onReload(true) }
        .cyPushedChrome(domain: .player)
        .cyPageTitle("mp.pass.title")
        .onAppear { if !didSetTab { tab = initialTab; didSetTab = true } }
    }

    private var signInPrompt: some View {
        CYStateLayout(kind: .orders, title: Text("mp.pass.signIn.orders"),
                      primary: onSignIn.map { action -> (title: LocalizedStringKey, action: () -> Void) in (title: "mp.pass.signIn.action", action: action) },
                      primaryStyle: .primary, primaryIdentifier: "passMarket.signIn")
            .accessibilityIdentifier("passMarket.signInPrompt")
    }

    // r2-store balance card: read-only server balance; points are earned, never sold (no top-up packs here).
    @ViewBuilder private func balanceCard(_ balance: Int) -> some View {
        let label = HStack {
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                Text("mp.pass.points").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                Text(verbatim: String(balance)).cyText(.dataXL).monospacedDigit().foregroundStyle(CYColor.textPrimary)
                    .contentTransition(.numericText())
            }
            Spacer()
            if pointsDestination != nil {
                HStack(spacing: CYSpacing.xs) { Text("mp.pass.pointsHistory"); Image(systemName: "chevron.right") }
                    .cyText(.label).foregroundStyle(CYColor.textSecondary)
            }
        }
        .cyDomainCard(radius: CYRadius.lg, padding: CYSpacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("passMarket.points")
        if let pointsDestination {
            // The card (and its balance number) zooms into the ledger's balance header; the ledger fades its history in
            // after the midpoint (`walletLedgerZoomArrival`). iOS 17 / Reduce Motion: the plain push, unchanged.
            NavigationLink {
                pointsDestination()
                    .environment(\.walletLedgerZoomArrival, true)
                    .cyHeroDestinationWithFallback("passMarket.points", in: pointsHero)
            } label: { label.cyHeroSource("passMarket.points", in: pointsHero, cornerRadius: CYRadius.lg) }.buttonStyle(.cyPressable)
        } else {
            label
        }
    }

    @ViewBuilder private func shop(_ content: PassMarketContent) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            if let member = state.member {
                Button(action: onOpenMembership) { memberCard(member) }
                    .buttonStyle(.cyPressable)
                    .accessibilityIdentifier("passMarket.member")
            }
            if content.products.isEmpty && state.member == nil {
                CYEmptyState(systemImage: "tray", "mp.pass.empty.shop", messageIdentifier: "passMarket.shop.empty")
            }
            ForEach(Array(content.products.enumerated()), id: \.element.id) { index, product in
                Group {
                    if let onOpenProduct {
                        Button { onOpenProduct(product.id) } label: { PassProductCardView(product: product) }
                            .buttonStyle(.cyPressable)
                    } else {
                        PassProductCardView(product: product)
                    }
                }
                .cyStaggerAppear(index)
                .accessibilityIdentifier("passMarket.product.\(product.id)")
            }
            if state.member != nil, let onOpenLibrary {
                Button(action: onOpenLibrary) {
                    MPCard { MPRow(title: Text("mp.pass.library"), chevron: true) }
                }
                .buttonStyle(.cyPressable)
                .accessibilityIdentifier("passMarket.library")
            }
            // One 兑换码 row: the session state's flag (tip) or the host's status read (member-a), never both.
            if let openRedeem = (state.platformCodeEnabled ? onOpenPlatformCode : nil) ?? onOpenRedeem {
                Button(action: openRedeem) {
                    MPCard { MPRow(title: Text("mp.pass.redeem"), chevron: true) }
                }
                .buttonStyle(.cyPressable)
                .accessibilityIdentifier("passMarket.redeem")
            }
        }
    }

    private func memberCard(_ side: PassMemberEntrySide) -> some View {
        // MP `mk-member` is text only (通行证 + side line) with a chevron; no emblem.
        HStack(spacing: CYSpacing.md) {
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                Text("mp.pass.member").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                switch side {
                case .activeUntil(let until): Text("mp.pass.member.until \(until)").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                case .plans(let plans): Text(verbatim: plans).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                case .themeCount(let count): Text("mp.pass.member.count \(count)").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                case .none: EmptyView()
                }
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(CYColor.textTertiary).accessibilityHidden(true)
        }
        .padding(CYSpacing.lg)
        .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func orders(_ content: PassMarketContent) -> some View {
        let rows = content.orders
        if rows.isEmpty && content.passOrders.isEmpty {
            CYEmptyState(systemImage: "tray", "mp.pass.empty.orders", messageIdentifier: "passMarket.orders.empty")
        } else {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                if !content.passOrders.isEmpty { passOrders(content.passOrders) }
                if !rows.isEmpty { catalogOrders(rows) }
            }
        }
    }

    /// `market/passes` 通行证订单 group: name + sub, status (and refund progress), amount. Tap opens the order.
    private func passOrders(_ rows: [PlatformPassSubscriptionOrder]) -> some View {
        MPRows(items: rows) { row in
            let line = MPRow(title: Text(verbatim: row.name),
                             sub: Text(verbatim: [row.sub, row.refundText.isEmpty ? row.stateText : row.refundText]
                                .filter { !$0.isEmpty }.joined(separator: " · ")),
                             value: Text(verbatim: row.amount.isEmpty ? MPText.unknown : MPParityBindings.moneyText(row.amount)),
                             chevron: onOpenPassOrder != nil)
            Group {
                if let onOpenPassOrder {
                    Button { onOpenPassOrder(row.orderNo) } label: { line }.buttonStyle(.cyPressable)
                } else {
                    line
                }
            }
            .accessibilityIdentifier("passMarket.passOrder.\(row.orderNo)")
        }
    }

    private func catalogOrders(_ rows: [PassOrderRow]) -> some View {
        MPRows(items: rows) { row in
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                    (row.name.map { Text(verbatim: $0) } ?? Text("mp.pass.order.fallbackName")).cyText(.bodyMedium)
                    row.state.text.cyText(.meta).foregroundStyle(CYColor.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: CYSpacing.xxs) {
                    if let amount = row.amountText { Text(verbatim: amount).cyText(.bodyMedium).monospacedDigit() }
                    if let time = row.timeText { Text(verbatim: time).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                }
            }
            .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.md)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("passMarket.order.\(row.id)")
            }
    }

    @ViewBuilder private func gifts(_ content: PassMarketContent) -> some View {
        if content.giftsBought.isEmpty && content.giftsReceived.isEmpty {
            CYEmptyState(systemImage: "tray", "mp.pass.empty.gifts", messageIdentifier: "passMarket.gifts.empty")
        } else {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                if !content.giftsBought.isEmpty {
                    MPSectionHeader(title: "mp.pass.gift.sent")
                    MPRows(items: content.giftsBought) { giftRow($0, bought: true) }
                }
                if !content.giftsReceived.isEmpty {
                    MPSectionHeader(title: "mp.pass.gift.received").padding(.top, CYSpacing.sm)
                    MPRows(items: content.giftsReceived) { giftRow($0, bought: false) }
                }
            }
        }
    }

    private func giftRow(_ row: PassGiftRow, bought: Bool) -> some View {
        MPRow(title: row.stateText(bought: bought),
              sub: row.claimDeadlineText.map { Text("mp.pass.gift.deadline \($0)") },
              value: row.timeText.map { Text(verbatim: $0) })
            .accessibilityIdentifier("passMarket.gift.\(row.id)")
    }
}

/// Shop card: kind + city header, name, validity, "includes N works · seats", price.
struct PassProductCardView: View {
    let product: PassProductCard

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            HStack(spacing: CYSpacing.sm) {
                if let kind = product.kind {
                    Text(kind.label).cyText(.caption).foregroundStyle(CYNight.lanternHot)
                        .padding(.horizontal, CYSpacing.sm).padding(.vertical, CYSpacing.xxs)
                        .background(CYNight.lantern.opacity(0.14), in: Capsule())
                }
                if let city = product.city { Text(verbatim: city).cyText(.caption).foregroundStyle(CYColor.textSecondary) }
                Spacer()
            }
            Text(verbatim: product.name).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                .multilineTextAlignment(.leading)
            if let validity = product.validity { validity.text.cyText(.meta).foregroundStyle(CYColor.textSecondary) }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    if product.coverCount > 0 {
                        if let seats = product.seats {
                            Text("mp.pass.coverSeats \(product.coverCount) \(seats)")
                        } else {
                            Text("mp.pass.cover \(product.coverCount)")
                        }
                    }
                    Spacer()
                    PassPriceText(cash: product.cashPriceText, points: product.pointsPrice).cyText(.cardTitle)
                }
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    if product.coverCount > 0 {
                        if let seats = product.seats {
                            Text("mp.pass.coverSeats \(product.coverCount) \(seats)")
                        } else {
                            Text("mp.pass.cover \(product.coverCount)")
                        }
                    }
                    PassPriceText(cash: product.cashPriceText, points: product.pointsPrice).cyText(.cardTitle)
                }
            }
            .cyText(.meta).foregroundStyle(CYColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cyDomainCard(radius: CYRadius.lg, padding: CYSpacing.lg)
        .accessibilityElement(children: .combine)
    }
}

/// Unit price only: "¥99.00 / 300 points"; nothing when both are missing.
struct PassPriceText: View {
    let cash: String?
    let points: Int?
    var body: some View {
        HStack(spacing: CYSpacing.xs) {
            if let cash { Text(verbatim: cash) }
            if cash != nil && points != nil { Text(verbatim: "/") }
            if let points { Text("mp.pass.points.amount \(points)") }
        }
        .monospacedDigit()
        .foregroundStyle(CYColor.textPrimary)
    }
}

// MARK: - Detail

enum PassBuyState: Equatable {
    case loading
    /// Refused quote or closed channel: the reason sentence only, no buttons.
    case unavailable(reason: String?)
    /// Group / school products: go through the registration checkout (activity signup), not this page.
    case checkout(activityID: String?, ticketID: String?)
    /// Quote allows these pay modes. Drawn read-only while `MPCommerceGate.purchasesEnabled` is false.
    case buyable(payModes: [PassPayMode], cashReason: String?)
    /// Guest: 购买 asks to sign in first (`market/pass` index.js:80).
    case signIn
}

struct PassPayMode: Identifiable, Equatable {
    enum Mode: Int { case cash = 1, points = 2 }
    let mode: Mode
    /// "Pay ¥99.00" / "Redeem 300 points", formatted from the quote.
    let amountText: String
    var id: Int { mode.rawValue }
}

struct PassCheckoutRow: Identifiable, Equatable {
    enum Kind: String { case price, cash, points }
    let kind: Kind
    let valueText: String
    /// Cash closed: the reason under the label and the row dimmed.
    let note: String?
    let off: Bool
    var id: String { kind.rawValue }
}

struct PassDetailState: Equatable {
    var product: MPLoad<PassProductCard> = .loading
    var forGift = false
    var buy: PassBuyState = .loading
    var checkout: [PassCheckoutRow] = []
    /// r3-pass unlock steps after a self-use PAID order (never set while the purchase gate is OFF).
    var unlockSteps: [PassUnlockStep] = []
    /// Gift bought: the claim link from the order reply (shown once in the 礼品已买好 sheet). Never set while the gate is OFF.
    var giftShare: PassGiftShare? = nil
    /// Group/school quote from `/api/marketing/group-checkout/quote`. Nil for other kinds.
    var groupQuote: MPLoad<GroupCheckoutDisplay>? = nil
    /// First topic on the product, for the activation panel. Nil shows the empty state.
    var activateTopicID: String? = nil
}

/// pass-unlock-view.js `unlockSteps`: one step per server fact (已到账 / 可玩主题 / 有效期 / 同行); no fact, no step.
struct PassUnlockStep: Identifiable, Equatable {
    let id: String
    let eyebrow: String
    let title: String
    let line: String?
    let rows: [String]
}

struct PassGiftShare: Identifiable, Equatable {
    let url: URL
    var id: String { url.absoluteString }
}

/// Logic stub for Cursor: `/api/marketing/product/{id}`, `/quote` (fulfillment SELF / GIFT). Order / pay / unlock stay unbound.
@MainActor protocol PassDetailBinding: AnyObject, Observable {
    var state: PassDetailState { get }
    func load()
    func setForGift(_ forGift: Bool)
    /// Unlock steps finished or gift sheet closed: the mini-program redirects to passes (orders / gifts tab).
    func dismissResult()
}

extension PassDetailBinding {
    func dismissResult() {}
}

@MainActor struct PassDetailHost: View {
    let binding: any PassDetailBinding
    var onOpenCheckout: ((String, String?) -> Void)? = nil
    @State private var route: MPParityRoute?

    var body: some View {
        PassDetailView(state: binding.state, onRetry: { binding.load() }, onSetForGift: { binding.setForGift($0) },
                       onOpenCheckout: onOpenCheckout ?? openActivitySignup,
                       onResultDone: { gift in
                           binding.dismissResult()
                           route = .passes(tab: gift ? .gifts : .orders)
                       },
                       onSignIn: { PlayerJourneySignInBridge.shared.request() })
            .task { binding.load() }
            .mpParityRouteDestination($route)
    }

    /// Group / school product 去报名: MP `baoming?activityId&ticketId`. The native baoming route lands on the activity
    /// with the registration sheet open and the pass ticket preselected (MKT-2-1). A malformed ticket id is dropped,
    /// so signup still opens and asks for the ticket.
    private func openActivitySignup(_ activityID: String, _ ticketID: String?) {
        guard let id = Int(activityID), id > 0, String(id) == activityID else { return }
        var query = ["activityId": activityID]
        if let ticketID, let t = Int(ticketID), t > 0, String(t) == ticketID { query["ticketId"] = ticketID }
        route = .screen(page: "pages/activity/baoming/baoming", query: query)
    }
}

struct PassDetailView: View {
    let state: PassDetailState
    let onRetry: () -> Void
    let onSetForGift: (Bool) -> Void
    /// Activity signup for group products (activityID, ticketID). Nil hides the button and keeps the sentence.
    let onOpenCheckout: ((String, String?) -> Void)?
    /// Unlock steps finished (false) or gift sheet closed (true).
    var onResultDone: (Bool) -> Void = { _ in }
    /// Guest 购买 → sign in.
    var onSignIn: (() -> Void)? = nil

    private enum ForWhom: String, CaseIterable, Identifiable { case me, gift; var id: String { rawValue } }

    var body: some View {
        Group {
            switch state.product {
            case .loading:
                CYLoadingStateView(rows: 3).padding(CYSpacing.pageHorizontal).frame(maxHeight: .infinity, alignment: .top)
                    .accessibilityIdentifier("passDetail.loading")
            case .failed(let reason):
                CYStateLayout(kind: .failure, title: reason.map { Text(verbatim: $0) } ?? Text("mp.common.loadFailed"),
                              primary: (title: "action.retry", action: onRetry), primaryStyle: .secondary, primaryIdentifier: "passDetail.retry")
                    .frame(maxHeight: .infinity)
                    .accessibilityIdentifier("passDetail.error")
            case .ready(let product):
                content(product)
            }
        }
        .cyPushedChrome(domain: .player)
        .navigationTitle(state.product.value.map { Text(verbatim: $0.name) } ?? Text(verbatim: ""))
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if !state.unlockSteps.isEmpty {
                PassUnlockStepsView(steps: state.unlockSteps, face: state.product.value?.faceText ?? state.product.value?.name ?? "") { onResultDone(false) }
                    .transition(.opacity)
            }
        }
        .sheet(item: Binding(get: { state.giftShare }, set: { if $0 == nil { onResultDone(true) } })) { share in
            PassGiftReadySheet(share: share, productName: state.product.value?.name ?? "")
                .cyPlayerSheetGlass()
        }
    }

    private func content(_ product: PassProductCard) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                PassTicketHero(face: product.faceText ?? product.name)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, CYSpacing.md)
                MPCard {
                    let rows = facts(product)
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        if index > 0 { MPDivider() }
                        MPRow(title: row.0, value: row.1)
                    }
                }
                if !product.topics.isEmpty {
                    MPSectionHeader(title: "mp.pass.detail.topics")
                    MPCard {
                        ForEach(Array(product.topics.enumerated()), id: \.offset) { index, topic in
                            if index > 0 { MPDivider() }
                            MPRow(title: Text(verbatim: topic))
                        }
                    }
                }
                if product.giftAllowed {
                    MPChipTabs(tabs: ForWhom.allCases, selection: Binding(get: { state.forGift ? .gift : .me }, set: { onSetForGift($0 == .gift) }),
                               title: { ($0 == .me ? Text("mp.pass.detail.forMe") : Text("mp.pass.detail.forGift")) },
                               identifier: { "passDetail.for.\($0.rawValue)" })
                        .padding(.horizontal, -CYSpacing.pageHorizontal)
                }
                if let groupQuote = state.groupQuote {
                    MPCard {
                        GroupCheckoutPanel(phase: groupQuote, onRetry: onRetry)
                            .padding(CYSpacing.lg)
                    }
                } else if !state.checkout.isEmpty {
                    MPSectionHeader(title: "mp.pass.detail.checkout")
                    MPCard {
                        ForEach(Array(state.checkout.enumerated()), id: \.element.id) { index, row in
                            if index > 0 { MPDivider() }
                            MPRow(title: (row.kind == .price ? Text("mp.pass.detail.price") : row.kind == .cash ? Text("mp.pass.detail.cash") : Text("mp.pass.detail.points")),
                                  sub: row.note.map { Text(verbatim: $0) }, value: Text(verbatim: row.valueText), strong: true, muted: row.off)
                        }
                    }
                }
                MPCard {
                    PassActivatePanel(topicID: state.activateTopicID)
                        .padding(CYSpacing.lg)
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.bottom, CYSpacing.jumbo)
        }
        .safeAreaInset(edge: .bottom) { bar }
    }

    private func facts(_ product: PassProductCard) -> [(Text, Text)] {
        var rows: [(Text, Text)] = []
        if let kind = product.kind { rows.append((Text("mp.pass.detail.kind"), Text(kind.label))) }
        if let city = product.city { rows.append((Text("mp.pass.detail.city"), Text(verbatim: city))) }
        if let validity = product.validity { rows.append((Text("mp.pass.detail.validity"), validity.text)) }
        if let seats = product.seats { rows.append((Text("mp.pass.detail.seats"), Text("mp.pass.seats \(seats)"))) }
        if state.forGift || product.seats == nil {
            rows.append((Text("mp.pass.detail.user"), (state.forGift ? Text("mp.pass.detail.userFriend") : Text("mp.pass.detail.userMe"))))
        }
        return rows
    }

    @ViewBuilder private var bar: some View {
        MPBottomBar {
            switch state.buy {
            case .loading:
                ProgressView().frame(minHeight: CYSpacing.minTouchTarget).accessibilityIdentifier("passDetail.quoteLoading")
            case .unavailable(let reason):
                (reason.map { Text(verbatim: $0) } ?? Text("mp.pass.buy.unavailable"))
                    .cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary).multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                    .accessibilityIdentifier("passDetail.unavailable")
            case .signIn:
                CYPillButton("mp.pass.buy.signIn") { onSignIn?() }
                    .accessibilityIdentifier("passDetail.signIn")
            case .checkout(let activityID, let ticketID):
                if let activityID, let onOpenCheckout {
                    CYPillButton("mp.pass.buy.checkout") { onOpenCheckout(activityID, ticketID) }
                        .accessibilityIdentifier("passDetail.checkout")
                } else {
                    Text("mp.pass.buy.useCheckout").cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                }
            case .buyable(let modes, let cashReason):
                if let cashReason, state.checkout.isEmpty {
                    Text(verbatim: cashReason).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                }
                // Gate OFF: the pay modes are shown as facts, not buttons.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: CYSpacing.sm) {
                        ForEach(modes) { mode in
                            Text(verbatim: mode.amountText).cyText(.label).foregroundStyle(CYColor.textSecondary)
                                .padding(.horizontal, CYSpacing.md).frame(minHeight: 36)
                                .background(CYColor.bgElevated, in: Capsule())
                        }
                    }
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        ForEach(modes) { mode in
                            Text(verbatim: mode.amountText).cyText(.label).foregroundStyle(CYColor.textSecondary)
                                .padding(.horizontal, CYSpacing.md).frame(minHeight: 36)
                                .background(CYColor.bgElevated, in: Capsule())
                        }
                    }
                }
                MPGatedNote(text: Text("mp.gate.purchase"), identifier: "passDetail.purchaseOff")
            }
        }
    }
}

/// cy-pass-unlock: one card per server fact, 下一步 advances, 完成 returns to the orders tab.
struct PassUnlockStepsView: View {
    let steps: [PassUnlockStep]
    let face: String
    let onDone: () -> Void
    @State private var index = 0
    @QuestifyReduceMotion private var reduceMotion

    var body: some View {
        let step = steps[min(index, steps.count - 1)]
        ZStack {
            CYColor.bgPage.opacity(0.96).ignoresSafeArea()
            VStack(spacing: CYSpacing.xl) {
                PassTicketHero(face: face)
                VStack(spacing: CYSpacing.sm) {
                    Text(verbatim: step.eyebrow).cyText(.caption).tracking(0.6).foregroundStyle(CYNight.lanternHot)
                    Text(verbatim: step.title).cyText(.pageTitle).foregroundStyle(CYColor.textPrimary).multilineTextAlignment(.center)
                    if let line = step.line { Text(verbatim: line).cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary) }
                    ForEach(step.rows, id: \.self) { Text(verbatim: $0).cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary) }
                }
                .id(step.id)
                .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                HStack(spacing: CYSpacing.xs) {
                    ForEach(steps.indices, id: \.self) { i in
                        Capsule().fill(i == index ? CYColor.textPrimary : CYColor.textTertiary).frame(width: i == index ? 18 : 6, height: 6)
                    }
                }
                .accessibilityHidden(true)
                CYPillButton(index < steps.count - 1 ? "mp.pass.unlock.next" : "mp.pass.unlock.done") {
                    if index < steps.count - 1 {
                        withAnimation(CYMotion.resolve(CYMotion.standard, reduceMotion: reduceMotion)) { index += 1 }
                    } else {
                        onDone()
                    }
                }
                .accessibilityIdentifier("passDetail.unlock.next")
            }
            .padding(CYSpacing.xxl)
        }
        .cyHaptic(.success, trigger: index)
        .accessibilityIdentifier("passDetail.unlock")
    }
}

/// 礼品已买好: the claim link is shown once; neither side can play until the friend claims it.
struct PassGiftReadySheet: View {
    let share: PassGiftShare
    let productName: String

    var body: some View {
        VStack(spacing: CYSpacing.lg) {
            Image(systemName: "gift.fill").cyText(.display).foregroundStyle(CYNight.lanternHot)
                .padding(CYSpacing.lg).background { Circle().fill(CYNight.glow(radius: 40)) }
                .accessibilityHidden(true)
            Text("mp.pass.giftReady.title").cyText(.sheetTitle).foregroundStyle(CYColor.textPrimary)
            Text("mp.pass.giftReady.note").cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary).multilineTextAlignment(.center)
            ShareLink(item: share.url, message: Text("mp.pass.giftReady.shareTitle \(productName)")) {
                Text("mp.pass.giftReady.send")
            }
            .buttonStyle(CYPillButtonStyle(style: .primary))
            .accessibilityIdentifier("passDetail.giftReady.send")
        }
        .padding(CYSpacing.xxl)
        .cyDomainSheet(detents: [.half])
        .accessibilityIdentifier("passDetail.giftReady")
    }
}

/// MP `cy-pass-object` seal (`po__seal` / `po__ring` / `po__mark`): a gold disc with an inner ring and the brand
/// mark `/images/cy_logo_mark.png` toned dark gold (`sepia … brightness(.35)`), here the catalog image as a template.
struct PassSealMark: View {
    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [CYNight.lanternHot, CYNight.lantern, CYNight.ember],
                                         center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 30))
            Circle().strokeBorder(CYNight.ember.opacity(0.6), lineWidth: 1.5).padding(5)
            MPAsset.BrandLogo.cyLogoMark
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(CYNight.ember)
                .accessibilityHidden(true)
                .padding(12)
        }
        .frame(width: 48, height: 48)
        .accessibilityHidden(true)
    }
}

/// r3-pass hero: a lantern-gold city pass that assembles from shards on appear (cross-fade under Reduce Motion).
struct PassTicketHero: View {
    let face: String
    @State private var assembled = false
    @QuestifyReduceMotion private var reduceMotion

    private static let shards: [(x: CGFloat, y: CGFloat, r: Double)] = [(-90, -60, -24), (80, -70, 18), (-110, 40, 30), (100, 50, -20), (0, -110, 12), (10, 100, -14)]

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous)
        ZStack {
            CYNight.glow(radius: 120).frame(width: 340, height: 260).opacity(assembled ? 0.8 : 0)
            ZStack {
                ForEach(Array(Self.shards.enumerated()), id: \.offset) { index, shard in
                    shape.fill(LinearGradient(colors: [CYNight.lanternHot, CYNight.lantern, CYNight.ember.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 220, height: 132)
                        .mask {
                            // Each shard shows one sixth of the face; together they read as one ticket.
                            GeometryReader { geo in
                                let column = CGFloat(index % 3), row = CGFloat(index / 3)
                                Rectangle().frame(width: geo.size.width / 3 + 1, height: geo.size.height / 2 + 1)
                                    .offset(x: column * geo.size.width / 3, y: row * geo.size.height / 2)
                            }
                        }
                        .offset(x: assembled ? 0 : shard.x, y: assembled ? 0 : shard.y)
                        .rotationEffect(.degrees(assembled ? 0 : shard.r))
                        .opacity(assembled ? 1 : 0.35)
                        .animation(reduceMotion ? CYMotion.reduced : .spring(response: 0.55, dampingFraction: 0.72).delay(Double(index) * 0.04), value: assembled)
                }
                VStack(spacing: CYSpacing.xs) {
                    PassSealMark()
                    Text(verbatim: face).cyText(.cardTitle).lineLimit(2).multilineTextAlignment(.center)
                }
                .foregroundStyle(CYNight.ink0)
                .padding(.horizontal, CYSpacing.lg)
                .frame(width: 220, height: 132)
                .opacity(assembled ? 1 : 0)
                .animation(CYMotion.resolve(CYMotion.entrance.delay(0.35), reduceMotion: reduceMotion), value: assembled)
            }
            .cyFoil(in: shape, active: assembled)
        }
        .frame(height: 200)
        .onAppear { assembled = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: face))
    }
}

// MARK: - Gift claim

enum PassGiftClaimPhase: Equatable {
    case ready
    case claimed(registrationID: String?)
    /// Reason sentence from the claim reason code ("gift already claimed", "token expired"...).
    case failed(reason: String)
    /// Network loss: same request id resent on the next tap.
    case unknown
    /// MP `MISSING_LINK_CODES` (`market/gift/index.js:10,119`): cy-empty 链接已失效 · 返回.
    case missing
}

struct PassGiftClaimState: Equatable {
    var phase: PassGiftClaimPhase = .ready
    var claiming = false
}

/// `/api/marketing/product/gifts/claim` with a stable request id (`market/gift/index.js:101-123`). Not money: MP-first.
@MainActor protocol PassGiftClaimBinding: AnyObject, Observable {
    var state: PassGiftClaimState { get }
    func claim()
}

@MainActor struct PassGiftClaimHost: View {
    let binding: any PassGiftClaimBinding
    @State private var route: MPParityRoute?
    @State private var orderID: String?
    @Environment(\.mpParity) private var bindings
    var body: some View {
        if binding.state.phase == .missing {
            MemberMissingLinkState(title: "mp.gift.linkInvalid", identifier: "passGift.missing")
        } else {
            claimView
        }
    }

    private var claimView: some View {
        // Mini-program goOrder: the claimed registration's order detail when the server returned one, else 礼品 tab.
        PassGiftClaimView(state: binding.state, onClaim: { binding.claim() }, onOpenGifts: {
            if case .claimed(let id?) = binding.state.phase, bindings.orderDetail != nil { orderID = id } else { route = .passes(tab: .gifts) }
        })
        .mpParityRouteDestination($route)
        .navigationDestination(item: $orderID) { id in bindings.orderDetail?(id) ?? AnyView(EmptyView()) }
    }
}

struct PassGiftClaimView: View {
    let state: PassGiftClaimState
    let onClaim: () -> Void
    let onOpenGifts: () -> Void
    @State private var popped = false
    @State private var glowing = false
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    private var failedReason: String? { if case .failed(let reason) = state.phase { return reason } else { return nil } }
    private var claimed: Bool { if case .claimed = state.phase { return true } else { return false } }

    var body: some View {
        VStack(spacing: CYSpacing.xl) {
            Spacer()
            ZStack {
                if !claimed && failedReason == nil {
                    Circle().stroke(CYNight.lantern.opacity(0.5), lineWidth: 2)
                        .frame(width: 120, height: 120)
                        .scaleEffect(glowing ? 1.6 : 1)
                        .opacity(glowing ? 0 : 0.8)
                        .animation(reduceMotion ? nil : .easeOut(duration: 2.4).repeatForever(autoreverses: false), value: glowing)
                }
                Circle().fill(failedReason == nil ? CYNight.glow(radius: 60) : RadialGradient(colors: [CYColor.bgElevated], center: .center, startRadius: 0, endRadius: 1))
                    .frame(width: 120, height: 120)
                Image(systemName: claimed ? "checkmark" : "gift.fill")
                    .cyText(.display)
                    .foregroundStyle(failedReason == nil ? (claimed ? CYNight.verify : CYNight.lanternHot) : CYColor.textTertiary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .scaleEffect(popped ? 1 : 0.6)
            .opacity(popped ? 1 : 0)
            .accessibilityHidden(true)
            Group {
                if claimed { Text("mp.gift.claimed") }
                else if let failedReason { Text(verbatim: failedReason) }
                else { Text("mp.gift.title") }
            }
            .cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary).multilineTextAlignment(.center)
            .padding(.horizontal, CYSpacing.xxl)
            .accessibilityAddTraits(.updatesFrequently)
            .accessibilityIdentifier("passGift.status")
            Spacer()
            if failedReason == nil {
                // MP gf__bar: 领取 / 查看 / 还在确认结果 (`market/gift/index.wxml:21-27`). MKT-3-1: no app-only gate.
                MPBottomBar {
                    if state.phase == .unknown { Text("mp.gift.unknown").cyText(.meta).foregroundStyle(CYColor.textSecondary) }
                    if claimed {
                        CYPillButton("mp.gift.view", action: onOpenGifts).accessibilityIdentifier("passGift.view")
                    } else {
                        CYMorphButton("mp.gift.claim", state: state.claiming ? .working : .idle, action: onClaim).identifier("passGift.claim")
                    }
                }
            } else {
                // MP failed bar: secondary 返回 (`market/gift/index.wxml:18-20`).
                MPBottomBar {
                    Button { dismiss() } label: { Text("action.back") }
                        .buttonStyle(.cySecondary(fullWidth: true))
                        .accessibilityIdentifier("passGift.back")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .cyPushedChrome(domain: .player)
        .navigationTitle(Text("mp.gift.nav"))
        .navigationBarTitleDisplayMode(.inline)
        .cyHaptic(.success, trigger: claimed)
        .onAppear {
            withAnimation(CYMotion.resolve(.spring(response: 0.45, dampingFraction: 0.6), reduceMotion: reduceMotion)) { popped = true }
            glowing = true
        }
    }
}

// MARK: - Pass order (`subpackageMember/market/pass-order`)

/// City-pass order: status, refund progress, validity, paid day, copy the order number.
/// 继续付款 calls `confirmPassOrder`, 取消订单 calls `cancelPassOrder`, 申请退款 calls `refundApplyPassOrder`.
/// `PlatformPass.moneyEnabled` stays false, so each of those throws `PlatformPassWriteRefusal.unreachable` and sends nothing.
/// Pay is not called. The gate note stays.
@MainActor protocol PassOrderDetailBinding: AnyObject, Observable {
    var phase: MPLoad<PlatformPassSubscriptionOrder> { get }
    func load()
}

@MainActor struct PassOrderDetailHost: View {
    let binding: any PassOrderDetailBinding
    var body: some View {
        PassOrderDetailView(phase: binding.phase, onRetry: { binding.load() })
            .task { binding.load() }
    }
}

struct PassOrderDetailView: View {
    let phase: MPLoad<PlatformPassSubscriptionOrder>
    let onRetry: () -> Void
    @State private var copied = false
    @State private var openAssistant = false

    var body: some View {
        ScrollView {
            MPLoadSwitch(load: phase, errorTitle: "mp.common.loadFailed", identifier: "passOrder", onRetry: onRetry) { order in
                content(order)
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
        }
        .refreshable { onRetry() }
        .cyPushedChrome(domain: .player)
        .cyPageTitle("mp.passOrder.title")
        .navigationDestination(isPresented: $openAssistant) { MPReviewedPageScreen(page: "subpackageB/pages/im/list/index", query: [:]) }
    }

    private func content(_ order: PlatformPassSubscriptionOrder) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            MPCard {
                MPRow(title: Text(verbatim: order.name), sub: order.sub.isEmpty ? nil : Text(verbatim: order.sub),
                      value: Text(verbatim: order.amount.isEmpty ? MPText.unknown : MPParityBindings.moneyText(order.amount)), strong: true)
                MPDivider()
                MPRow(title: Text("mp.passOrder.state"), value: Text(verbatim: order.stateText))
                if !order.refundText.isEmpty {
                    MPDivider()
                    MPRow(title: Text("mp.passOrder.refund"), value: Text(verbatim: order.refundText))
                }
                switch order.refundDetail {
                case .refunded(let amount, let time):
                    MPDivider()
                    MPRow(title: Text("mp.passOrder.refundAmount"), value: Text(verbatim: MPParityBindings.moneyText(amount)))
                    if !time.isEmpty {
                        MPDivider()
                        MPRow(title: Text("mp.passOrder.refundTime"), value: Text(verbatim: time))
                    }
                case .rejected(let reason, _):
                    if !reason.isEmpty {
                        MPDivider()
                        MPRow(title: Text("mp.passOrder.rejectReason"), value: Text(verbatim: reason))
                    }
                    MPDivider()
                    Button { openAssistant = true } label: {
                        MPRow(title: Text("mp.passOrder.review"), value: Text("mp.passOrder.review.assistant"), chevron: true)
                    }
                    .buttonStyle(.cyPressable)
                    .accessibilityIdentifier("passOrder.review")
                case nil:
                    EmptyView()
                }
                if !order.validTo.isEmpty {
                    MPDivider()
                    MPRow(title: Text("mp.passOrder.validTo"), value: Text(verbatim: order.validTo))
                }
                if !order.time.isEmpty {
                    MPDivider()
                    MPRow(title: Text("mp.passOrder.paidTime"), value: Text(verbatim: order.time))
                }
                MPDivider()
                Button {
                    LocalPasteboard.copy(order.orderNo)
                    copied = true
                } label: {
                    MPRow(title: Text("mp.passOrder.number"),
                          value: copied ? Text("mp.passOrder.copied") : Text("mp.passOrder.copy"))
                }
                .buttonStyle(.cyPressable)
                .sensoryFeedback(.success, trigger: copied)
                .accessibilityIdentifier("passOrder.copy")
            }
            .accessibilityIdentifier("passOrder.rows")
            if order.canResume || order.canCancel || order.canRefund {
                PassOrderRefusedWrites(order: order, onWritten: onRetry)
            }
        }
        .transition(.opacity)
    }
}

/// Resume, cancel, and refund sit on the contracts from `cursor-mp-cov-member`.
/// The three writes throw before any transport send. No pay request is built.
private struct PassOrderRefusedWrites: View {
    let order: PlatformPassSubscriptionOrder
    /// R9-MEM-5-1: MP market/pass-order/index.js:70-127 re-reads the order after a write succeeds.
    var onWritten: () -> Void = {}
    @Environment(\.passOrderWriteSession) private var session
    @State private var confirmCancel = false
    @State private var refunding = false
    @State private var reason = ""
    /// R8-MEM-5-1: MP `cy-inline-error` notice. A refused write says so instead of doing nothing.
    @State private var refusedNotice = false

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            MPGatedNote(text: Text("mp.passOrder.gated"), identifier: "passOrder.gated")
            if refusedNotice {
                CYNoteBanner(text: Text("mp.passOrder.refused"), symbol: "exclamationmark.triangle", tone: .warning)
                    .accessibilityIdentifier("passOrder.refused")
            }
            if order.canResume {
                Button { refuse(.resume) } label: { Text("mp.passOrder.resume").cyText(.body) }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("passOrder.resume")
            }
            if order.canCancel {
                Button(role: .destructive) { confirmCancel = true } label: { Text("mp.passOrder.cancel").cyText(.body) }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("passOrder.cancel")
            }
            if order.canRefund {
                Button(role: .destructive) { refunding = true } label: { Text("mp.passOrder.refundApply").cyText(.body) }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("passOrder.refund")
            }
        }
        .confirmationDialog(Text("mp.passOrder.cancel"), isPresented: $confirmCancel, titleVisibility: .visible) {
            Button(role: .destructive) { refuse(.cancel) } label: { Text("mp.passOrder.cancel") }
            Button(role: .cancel) {} label: { Text("common.cancel") }
        }
        .sheet(isPresented: $refunding) {
            NavigationStack {
                Form {
                    // R8-MEM-5-2: MP OR-024 refund terms above the reason (fixed MP defaults until server terms are wired).
                    Section {
                        LabeledContent { Text("mp.member.fact.renewal.value").cyText(.bodyCompact) } label: { Text("mp.member.fact.renewal").cyText(.bodyCompact) }
                        LabeledContent { Text("mp.member.fact.refund.value").cyText(.bodyCompact) } label: { Text("mp.member.fact.refund").cyText(.bodyCompact) }
                    }
                    .accessibilityIdentifier("passOrder.refund.terms")
                    Section {
                        TextField(text: $reason, axis: .vertical) { Text("mp.passOrder.refundApply.placeholder") }
                            .cyText(.body)
                            .lineLimit(3...6)
                            .onChange(of: reason) { _, newValue in
                                if newValue.count > 200 { reason = String(newValue.prefix(200)) }
                            }
                    } header: {
                        Text("mp.passOrder.refundApply.reason").cyText(.caption)
                    } footer: {
                        Text(verbatim: "\(reason.count)/200").cyText(.caption, monospacedDigit: true)
                    }
                    Section {
                        Button(role: .destructive) {
                            let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            refunding = false
                            refuse(.refund, reason: trimmed)
                        } label: {
                            Text("mp.passOrder.refundApply.submit").cyText(.body)
                        }
                        .disabled(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("passOrder.refund.submit")
                    }
                }
                .navigationTitle(Text("mp.passOrder.refundApply"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { refunding = false } label: { Text("common.cancel") }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private enum Write { case resume, cancel, refund }

    /// Money stays off. A missing reader does not invent a sender. Every refusal shows the gate notice.
    /// R9-MEM-5-1: only a refusal shows 已拒绝; a TEST write that succeeds re-reads the order like the MP (index.js:70-127).
    private func refuse(_ write: Write, reason: String = "") {
        refusedNotice = false
        guard PlatformPass.moneyEnabled == false, MPParityBindings.moneyEnabled == false else { refusedNotice = true; return }
        guard let session, let client = session.makePlatformPassReader() else { refusedNotice = true; return }
        let token = session.passReadToken() ?? ""
        let kind: PlatformPass.OrderWriteKind
        switch write {
        case .resume: kind = .confirm
        case .cancel: kind = .cancel
        case .refund: kind = .refundApply
        }
        // MKT-5-3: send only while the TEST derivation for this kind is on. The default throws and sends nothing.
        if PlatformPass.orderWriteEnabled(kind) {
            let orderNo = order.orderNo
            Task {
                do {
                    switch kind {
                    case .confirm: _ = try await client.sendConfirmPassOrder(orderNo: orderNo, token: token)
                    case .cancel: _ = try await client.sendCancelPassOrder(orderNo: orderNo, token: token)
                    case .refundApply: _ = try await client.sendRefundApplyPassOrder(orderNo: orderNo, reason: reason, token: token)
                    }
                    onWritten()
                } catch {
                    refusedNotice = true
                }
            }
            return
        }
        do {
            switch write {
            case .resume:
                _ = PlatformPass.passOrderConfirmPath(orderNo: order.orderNo)
                try client.confirmPassOrder(orderNo: order.orderNo, token: token)
            case .cancel:
                _ = PlatformPass.passOrderCancelPath(orderNo: order.orderNo)
                try client.cancelPassOrder(orderNo: order.orderNo, token: token)
            case .refund:
                _ = PlatformPass.passOrderRefundApplyPath(orderNo: order.orderNo)
                try client.refundApplyPassOrder(orderNo: order.orderNo, reason: reason, token: token)
            }
            onWritten()
        } catch {
            refusedNotice = true
        }
    }
}

private struct PassOrderWriteSessionKey: EnvironmentKey {
    static let defaultValue: AppSession? = nil
}

extension EnvironmentValues {
    var passOrderWriteSession: AppSession? {
        get { self[PassOrderWriteSessionKey.self] }
        set { self[PassOrderWriteSessionKey.self] = newValue }
    }
}

/// `market/gift?mode=code`. Six results: 无效 / 过期 / 你已兑换 / 他人已兑换 / 不属于此账号 / 暂不可用. 去玩 does not claim a gift.
@MainActor struct PlatformCodeRedeemPage: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.mpParity) private var bindings
    @State private var code = ""
    @State private var codeOn = false
    @State private var statusReady = false
    @State private var working = false
    @State private var titleKey = "platformCode.title"
    @State private var claimed = false
    @State private var topicID: Int?
    @State private var openingLibrary = false
    @State private var openingTopic = false

    var body: some View {
        VStack(spacing: CYSpacing.lg) {
            Text(LocalizedStringKey(titleKey))
                .cyText(.sheetTitle)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("platformCode.title")
            if statusReady, codeOn, !claimed {
                TextField("platformCode.placeholder", text: $code)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: code) { _, value in
                        if value.count > 64 { code = String(value.prefix(64)) }
                    }
                    .accessibilityIdentifier("platformCode.input")
                CYMorphButton("platformCode.submit", state: working ? .working : .idle) { Task { await redeem() } }
                    .disabled(working || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("platformCode.submit")
            }
            if claimed {
                CYPillButton("platformCode.play") { play() }
                    .accessibilityIdentifier("platformCode.play")
            }
        }
        .padding(CYSpacing.pageHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CYColor.bgPage.ignoresSafeArea())
        .navigationTitle(Text("platformCode.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadStatus() }
        .navigationDestination(isPresented: $openingLibrary) {
            if let make = bindings.passLibrary { PassLibraryHost(binding: make(), initialKind: .all) }
        }
        .navigationDestination(isPresented: $openingTopic) {
            if let topicID { SessionTopicDetailView(id: topicID, session: session) }
        }
    }

    private func loadStatus() async {
        guard let token = session.token, AuthRequestBuilder.isValidToken(token),
              let base = session.currentRuntimeDependencyContext?.baseURL,
              let configuration = try? APIConfiguration(baseURL: base) else {
            statusReady = true
            codeOn = false
            titleKey = "platformCode.signIn"
            return
        }
        let source = ChannelRedeemSource(configuration: configuration, transport: session.composition.makeTransport())
        codeOn = (try? await source.status(token: token)) == true
        statusReady = true
        if !codeOn { titleKey = "platformCode.unavailable" }
    }

    private func redeem() async {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard codeOn, !trimmed.isEmpty, trimmed.utf8.count <= 64 else { return }
        guard let token = session.token, AuthRequestBuilder.isValidToken(token) else {
            titleKey = "platformCode.signIn"
            return
        }
        guard let base = session.currentRuntimeDependencyContext?.baseURL,
              let configuration = try? APIConfiguration(baseURL: base) else { return }
        working = true
        defer { working = false }
        let source = ChannelRedeemSource(configuration: configuration, transport: session.composition.makeTransport())
        do {
            let envelope = try await source.redeemPlatformCode(code: trimmed, token: token)
            apply(envelope)
        } catch {
            titleKey = "platformCode.unknown"
        }
    }

    private func apply(_ envelope: ChannelRedeemEnvelope) {
        if envelope.ok {
            claimed = true
            topicID = Self.singleTopic(envelope.dataJSON)
            let replayed = Self.replayed(envelope.dataJSON)
            titleKey = replayed ? "platformCode.replayed" : "platformCode.success"
            return
        }
        claimed = false
        switch envelope.reasonCode {
        case "CODE_REQUIRED", "INVALID_CODE": titleKey = "platformCode.invalid"
        case "CODE_EXPIRED": titleKey = "platformCode.expired"
        case "ALREADY_REDEEMED_BY_OTHER": titleKey = "platformCode.used"
        case "SUBJECT_MISMATCH": titleKey = "platformCode.mismatch"
        default: titleKey = "platformCode.unavailable"
        }
    }

    private func play() {
        if topicID != nil { openingTopic = true } else { openingLibrary = true }
    }

    private static func replayed(_ data: Data?) -> Bool {
        guard let data, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let number = object["replayed"] as? NSNumber else { return false }
        return CFGetTypeID(number as CFTypeRef) == CFBooleanGetTypeID() && number.boolValue
    }

    private static func singleTopic(_ data: Data?) -> Int? {
        guard let data, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let ids = object["topicIds"] as? [Int], ids.count == 1, ids[0] > 0 { return ids[0] }
        if let ids = object["topicIds"] as? [NSNumber], ids.count == 1, ids[0].intValue > 0 { return ids[0].intValue }
        return nil
    }
}
