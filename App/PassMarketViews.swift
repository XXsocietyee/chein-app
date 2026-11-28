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
    /// mp-mine r3: MP giftRow `name` (catalog product name). Nil keeps the state as the row title.
    var name: String? = nil

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
    @Environment(\.locale) private var locale
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

    var body: some View {
        List {
            if let balance = state.pointBalance { Section { balanceRow(balance) } }
            Section {
                Picker(selection: $tab) {
                    ForEach(PassMarketTab.allCases) { item in
                        Text(item.title).tag(item).accessibilityIdentifier("passMarket.tab.\(item.rawValue)")
                    }
                } label: { EmptyView() }
                .cyAdaptiveSegmented()
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            if state.refreshFailed {
                Section { CYOfflineStrip() }
            }
            switch state.content {
            case .loading:
                Section {
                    ProgressView { Text("cy.state.loading") }.frame(maxWidth: .infinity)
                        .accessibilityIdentifier("passMarket.loading")
                }
            case .failed(let message):
                ContentUnavailableView {
                    Label { message.map { Text(verbatim: $0) } ?? Text("mp.common.loadFailed") } icon: { Image(systemName: "exclamationmark.triangle") }
                } actions: {
                    Button { onReload(false) } label: { Text("action.retry") }
                        .buttonStyle(.bordered).controlSize(.large)
                        .accessibilityIdentifier("passMarket.retry")
                }
                .accessibilityIdentifier("passMarket.error")
            case .ready(let content):
                switch tab {
                case .shop: shop(content)
                case .orders where !state.signedIn, .gifts where !state.signedIn: signInPrompt
                case .orders: orders(content)
                case .gifts: gifts(content)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { onReload(true) }
        .cyPushedChrome(domain: .player)
        .cyPageTitle("mp.pass.title")
        .onAppear { if !didSetTab { tab = initialTab; didSetTab = true } }
    }

    private var signInPrompt: some View {
        ContentUnavailableView {
            Label("mp.pass.signIn.orders", systemImage: "person.crop.circle")
        } actions: {
            if let onSignIn {
                Button(action: onSignIn) { Text("mp.pass.signIn.action") }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .accessibilityIdentifier("passMarket.signIn")
            }
        }
        .accessibilityIdentifier("passMarket.signInPrompt")
    }

    // r2-store balance row: read-only server balance; points are earned, never sold (no top-up packs here).
    @ViewBuilder private func balanceRow(_ balance: Int) -> some View {
        let label = LabeledContent {
            if pointsDestination != nil { Text("mp.pass.pointsHistory") }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("mp.pass.points").font(.subheadline).foregroundStyle(.secondary)
                Text(balance, format: .number).font(.largeTitle.weight(.semibold)).monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("passMarket.points")
        if let pointsDestination {
            NavigationLink { pointsDestination() } label: { label }
        } else {
            label
        }
    }

    /// A list row that runs an action and reads like a navigation row (title, optional sub line, chevron).
    private func actionRow<Title: View>(_ action: @escaping () -> Void, @ViewBuilder title: () -> Title) -> some View {
        Button(action: action) {
            HStack {
                title()
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .foregroundStyle(.primary)
    }

    @ViewBuilder private func shop(_ content: PassMarketContent) -> some View {
        if let member = state.member {
            Section {
                actionRow(onOpenMembership) { memberLabel(member) }
                    .accessibilityIdentifier("passMarket.member")
            }
        }
        if content.products.isEmpty && state.member == nil {
            ContentUnavailableView {
                Label { Text("mp.pass.empty.shop").accessibilityIdentifier("passMarket.shop.empty") } icon: { Image(systemName: "tray") }
            }
        }
        if !content.products.isEmpty {
            Section {
                ForEach(content.products) { product in
                    Group {
                        if let onOpenProduct {
                            actionRow({ onOpenProduct(product.id) }) { PassProductCardView(product: product) }
                        } else {
                            PassProductCardView(product: product)
                        }
                    }
                    .accessibilityIdentifier("passMarket.product.\(product.id)")
                }
            }
        }
        let openRedeem = (state.platformCodeEnabled ? onOpenPlatformCode : nil) ?? onOpenRedeem
        if (state.member != nil && onOpenLibrary != nil) || openRedeem != nil {
            Section {
                if state.member != nil, let onOpenLibrary {
                    actionRow(onOpenLibrary) { Text("mp.pass.library") }
                        .accessibilityIdentifier("passMarket.library")
                }
                // One 兑换码 row: the session state's flag (tip) or the host's status read (member-a), never both.
                if let openRedeem {
                    actionRow(openRedeem) { Text("mp.pass.redeem") }
                        .accessibilityIdentifier("passMarket.redeem")
                }
            }
        }
    }

    private func memberLabel(_ side: PassMemberEntrySide) -> some View {
        // MP `mk-member` is text only (通行证 + side line) with a chevron; no emblem.
        VStack(alignment: .leading, spacing: 2) {
            Text("mp.pass.member").font(.headline)
            Group {
                switch side {
                case .activeUntil(let until): Text("mp.pass.member.until \(until)")
                case .plans(let plans): Text(verbatim: plans)
                case .themeCount(let count): Text("mp.pass.member.count \(count)")
                case .none: EmptyView()
                }
            }
            .font(.subheadline).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func orders(_ content: PassMarketContent) -> some View {
        let rows = content.orders
        if rows.isEmpty && content.passOrders.isEmpty {
            ContentUnavailableView {
                Label { Text("mp.pass.empty.orders").accessibilityIdentifier("passMarket.orders.empty") } icon: { Image(systemName: "tray") }
            }
        } else {
            if !content.passOrders.isEmpty { Section { passOrders(content.passOrders) } }
            if !rows.isEmpty { Section { catalogOrders(rows) } }
        }
    }

    /// `market/passes` 通行证订单 group: name + sub, status (and refund progress), amount, then `time` under it. Tap opens the order.
    private func passOrders(_ rows: [PlatformPassSubscriptionOrder]) -> some View {
        ForEach(rows) { row in
            let line = LabeledContent {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(verbatim: row.amount.isEmpty ? MPText.unknown : LocaleDisplay.yuanAmounts(in: MPParityBindings.moneyText(row.amount), locale: locale)).monospacedDigit()
                    if !row.time.isEmpty {
                        Text(verbatim: LocaleDisplay.civil(row.time, locale: locale)).font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                    }
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: row.name)
                    Text(verbatim: [row.sub, row.refundText.isEmpty ? row.stateText : row.refundText]
                        .filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Group {
                if let onOpenPassOrder {
                    actionRow({ onOpenPassOrder(row.orderNo) }) { line }
                } else {
                    line
                }
            }
            .accessibilityIdentifier("passMarket.passOrder.\(row.orderNo)")
        }
    }

    private func catalogOrders(_ rows: [PassOrderRow]) -> some View {
        ForEach(rows) { row in
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    (row.name.map { Text(verbatim: $0) } ?? Text("mp.pass.order.fallbackName"))
                    row.state.text.font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if let amount = row.amountText { Text(verbatim: LocaleDisplay.yuanAmounts(in: amount, locale: locale)).monospacedDigit() }
                    if let time = row.timeText { Text(verbatim: time).font(.subheadline).foregroundStyle(.secondary) }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("passMarket.order.\(row.id)")
        }
    }

    @ViewBuilder private func gifts(_ content: PassMarketContent) -> some View {
        if content.giftsBought.isEmpty && content.giftsReceived.isEmpty {
            ContentUnavailableView {
                Label { Text("mp.pass.empty.gifts").accessibilityIdentifier("passMarket.gifts.empty") } icon: { Image(systemName: "tray") }
            }
        } else {
            if !content.giftsBought.isEmpty {
                Section {
                    ForEach(content.giftsBought) { giftRow($0, bought: true) }
                } header: { Text("mp.pass.gift.sent") }
            }
            if !content.giftsReceived.isEmpty {
                Section {
                    ForEach(content.giftsReceived) { giftRow($0, bought: false) }
                } header: { Text("mp.pass.gift.received") }
            }
        }
    }

    private func giftRow(_ row: PassGiftRow, bought: Bool) -> some View {
        LabeledContent {
            if let time = row.timeText { Text(verbatim: time).monospacedDigit() }
        } label: {
            // MP gift row: title = name || state; the state moves to the sub line when a name is known.
            VStack(alignment: .leading, spacing: 2) {
                if let name = row.name {
                    Text(verbatim: name)
                    row.stateText(bought: bought).font(.subheadline).foregroundStyle(.secondary)
                } else {
                    row.stateText(bought: bought)
                }
                if let deadline = row.claimDeadlineText {
                    Text("mp.pass.gift.deadline \(deadline)").font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("passMarket.gift.\(row.id)")
    }
}

/// Shop row content: kind + city line, name, validity, "includes N works · seats", price.
struct PassProductCardView: View {
    let product: PassProductCard

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                if let kind = product.kind {
                    Text(kind.label).font(.footnote.weight(.semibold)).foregroundStyle(.tint)
                }
                if let city = product.city { Text(verbatim: city).font(.footnote).foregroundStyle(.secondary) }
            }
            Text(verbatim: product.name).font(.headline).foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
            if let validity = product.validity { validity.text.font(.subheadline).foregroundStyle(.secondary) }
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
                    PassPriceText(cash: product.cashPriceText, points: product.pointsPrice).font(.headline)
                }
                VStack(alignment: .leading, spacing: 4) {
                    if product.coverCount > 0 {
                        if let seats = product.seats {
                            Text("mp.pass.coverSeats \(product.coverCount) \(seats)")
                        } else {
                            Text("mp.pass.cover \(product.coverCount)")
                        }
                    }
                    PassPriceText(cash: product.cashPriceText, points: product.pointsPrice).font(.headline)
                }
            }
            .font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Unit price only: "¥99.00 / 300 points"; nothing when both are missing.
struct PassPriceText: View {
    @Environment(\.locale) private var locale
    let cash: String?
    let points: Int?
    var body: some View {
        HStack(spacing: 4) {
            if let cash { Text(verbatim: LocaleDisplay.yuanAmounts(in: cash, locale: locale)) }
            if cash != nil && points != nil { Text(verbatim: "/") }
            if let points { Text("mp.pass.points.amount \(points)") }
        }
        .monospacedDigit()
        .foregroundStyle(.primary)
    }
}

// MARK: - Detail

enum PassBuyState: Equatable {
    case loading
    /// Refused quote or closed channel: the reason sentence only, no buttons.
    case unavailable(reason: String?)
    /// Group / school products: go through the registration checkout (activity signup), not this page.
    case checkout(activityID: String?, ticketID: String?)
    /// Group quote failed: MP `market/pass` buy.state `requote` (报价暂不可用 + 重试, index.js:108, wxml:42).
    case requote
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
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
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
                ProgressView { Text("cy.state.loading") }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("passDetail.loading")
            case .failed(let reason):
                ContentUnavailableView {
                    Label { reason.map { Text(verbatim: $0) } ?? Text("mp.common.loadFailed") } icon: { Image(systemName: "exclamationmark.triangle") }
                } actions: {
                    // MP `market/pass` index.js:61: a server reason (off sale, not found …) takes 返回; a read failure takes 重试.
                    if reason != nil {
                        Button { dismiss() } label: { Text("action.back") }
                            .buttonStyle(.bordered).controlSize(.large)
                            .accessibilityIdentifier("passDetail.back")
                    } else {
                        Button(action: onRetry) { Text("action.retry") }
                            .buttonStyle(.bordered).controlSize(.large)
                            .accessibilityIdentifier("passDetail.retry")
                    }
                }
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
        .cySheet(item: Binding(get: { state.giftShare }, set: { if $0 == nil { onResultDone(true) } })) { share in
            PassGiftReadySheet(share: share, productName: state.product.value?.name ?? "")
        }
    }

    private func content(_ product: PassProductCard) -> some View {
        List {
            Section {
                PassTicketHero(face: product.faceText ?? product.name)
                    .frame(maxWidth: .infinity)
            }
            Section {
                let rows = facts(product)
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    LabeledContent { row.1 } label: { row.0 }
                }
            }
            if !product.topics.isEmpty {
                Section {
                    ForEach(Array(product.topics.enumerated()), id: \.offset) { _, topic in
                        Text(verbatim: topic)
                    }
                } header: { Text("mp.pass.detail.topics") }
            }
            if product.giftAllowed {
                Section {
                    Picker(selection: Binding(get: { state.forGift ? ForWhom.gift : ForWhom.me }, set: { onSetForGift($0 == .gift) })) {
                        ForEach(ForWhom.allCases) { whom in
                            (whom == .me ? Text("mp.pass.detail.forMe") : Text("mp.pass.detail.forGift"))
                                .tag(whom)
                                .accessibilityIdentifier("passDetail.for.\(whom.rawValue)")
                        }
                    } label: { EmptyView() }
                    .cyAdaptiveSegmented()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            if let groupQuote = state.groupQuote {
                Section {
                    GroupCheckoutPanel(phase: groupQuote, onRetry: onRetry)
                }
            } else if !state.checkout.isEmpty {
                Section {
                    ForEach(state.checkout) { row in
                        LabeledContent {
                            Text(verbatim: row.valueText).font(.headline).monospacedDigit()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                (row.kind == .price ? Text("mp.pass.detail.price") : row.kind == .cash ? Text("mp.pass.detail.cash") : Text("mp.pass.detail.points"))
                                if let note = row.note { Text(verbatim: note).font(.subheadline).foregroundStyle(.secondary) }
                            }
                        }
                        .foregroundStyle(row.off ? Color.secondary : Color.primary)
                    }
                } header: { Text("mp.pass.detail.checkout") }
            }
            // mp-mine r3: MP market/pass has no 首次使用时激活 block (wxml:10-48), so none is drawn here.
        }
        .listStyle(.insetGrouped)
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

    /// Bottom bar on the system bar material: one prominent action, or the read-only reason / pay facts.
    private var bar: some View {
        VStack(spacing: 8) { barContent }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.bar)
    }

    @ViewBuilder private var barContent: some View {
        switch state.buy {
        case .loading:
            ProgressView().frame(minHeight: 44).accessibilityIdentifier("passDetail.quoteLoading")
        case .unavailable(let reason):
            (reason.map { Text(verbatim: $0) } ?? Text("mp.pass.buy.unavailable"))
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("passDetail.unavailable")
        case .requote:
            Text("mp.pass.buy.requote")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            Button(action: onRetry) { Text("action.retry").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .accessibilityIdentifier("passDetail.requote")
        case .signIn:
            Button { onSignIn?() } label: { Text("mp.pass.buy.signIn").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .accessibilityIdentifier("passDetail.signIn")
        case .checkout(let activityID, let ticketID):
            if let activityID, let onOpenCheckout {
                Button { onOpenCheckout(activityID, ticketID) } label: { Text("mp.pass.buy.checkout").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .accessibilityIdentifier("passDetail.checkout")
            } else {
                Text("mp.pass.buy.useCheckout").font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        case .buyable(let modes, let cashReason):
            if let cashReason, state.checkout.isEmpty {
                Text(verbatim: cashReason).font(.subheadline).foregroundStyle(.secondary)
            }
            // Gate OFF: the pay modes are shown as facts, not buttons.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    ForEach(modes) { mode in
                        Text(verbatim: LocaleDisplay.yuanAmounts(in: mode.amountText, locale: locale)).font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(modes) { mode in
                        Text(verbatim: LocaleDisplay.yuanAmounts(in: mode.amountText, locale: locale)).font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            }
            MPGatedNote(text: Text("mp.gate.purchase"), identifier: "passDetail.purchaseOff")
        }
    }
}

/// cy-pass-unlock: one page per server fact, 下一步 advances, 完成 returns to the orders tab.
struct PassUnlockStepsView: View {
    let steps: [PassUnlockStep]
    let face: String
    let onDone: () -> Void
    @State private var index = 0

    var body: some View {
        let step = steps[min(index, steps.count - 1)]
        ZStack {
            Rectangle().fill(.background).ignoresSafeArea()
            VStack(spacing: 24) {
                PassTicketHero(face: face)
                VStack(spacing: 8) {
                    Text(verbatim: step.eyebrow).font(.footnote.weight(.semibold)).foregroundStyle(.tint)
                    Text(verbatim: step.title).font(.title.weight(.bold)).foregroundStyle(.primary).multilineTextAlignment(.center)
                    if let line = step.line { Text(verbatim: line).font(.subheadline).foregroundStyle(.secondary) }
                    ForEach(step.rows, id: \.self) { Text(verbatim: $0).font(.subheadline).foregroundStyle(.secondary) }
                }
                .id(step.id)
                ProgressView(value: Double(min(index, steps.count - 1) + 1), total: Double(max(steps.count, 1)))
                    .frame(maxWidth: 160)
                    .accessibilityHidden(true)
                Button {
                    if index < steps.count - 1 {
                        index += 1
                    } else {
                        onDone()
                    }
                } label: {
                    Text(LocalizedStringKey(index < steps.count - 1 ? "mp.pass.unlock.next" : "mp.pass.unlock.done"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .accessibilityIdentifier("passDetail.unlock.next")
            }
            .padding(32)
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
        ContentUnavailableView {
            Label { Text("mp.pass.giftReady.title") } icon: { Image(systemName: "gift.fill").foregroundStyle(.tint) }
        } description: {
            Text("mp.pass.giftReady.note")
        } actions: {
            ShareLink(item: share.url, message: Text("mp.pass.giftReady.shareTitle \(productName)")) {
                Text("mp.pass.giftReady.send")
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .accessibilityIdentifier("passDetail.giftReady.send")
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("passDetail.giftReady")
    }
}

/// MP `cy-pass-object` seal (`po__mark`): the brand mark `/images/cy_logo_mark.png` as a template, in the accent.
struct PassSealMark: View {
    var body: some View {
        MPAsset.BrandLogo.cyLogoMark
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .foregroundStyle(.tint)
            .frame(width: 44, height: 44)
            .accessibilityHidden(true)
    }
}

/// r3-pass header: the MP seal over the pass face (native r2: no shards, glow or foil).
struct PassTicketHero: View {
    let face: String

    var body: some View {
        VStack(spacing: 8) {
            PassSealMark()
            Text(verbatim: face).font(.headline).lineLimit(2).multilineTextAlignment(.center)
        }
        .padding(.vertical, 12)
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
    @Environment(\.dismiss) private var dismiss

    private var failedReason: String? { if case .failed(let reason) = state.phase { return reason } else { return nil } }
    private var claimed: Bool { if case .claimed = state.phase { return true } else { return false } }

    var body: some View {
        ContentUnavailableView {
            Label {
                Group {
                    if claimed { Text("mp.gift.claimed") }
                    else if let failedReason { Text(verbatim: failedReason) }
                    else { Text("mp.gift.title") }
                }
                .accessibilityAddTraits(.updatesFrequently)
                .accessibilityIdentifier("passGift.status")
            } icon: {
                Image(systemName: claimed ? "checkmark.circle.fill" : "gift.fill")
                    .foregroundStyle(failedReason == nil ? (claimed ? Color.green : Color.accentColor) : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
            }
        } description: {
            if failedReason == nil, state.phase == .unknown { Text("mp.gift.unknown") }
        } actions: {
            if failedReason == nil {
                // MP gf__bar: 领取 / 查看 / 还在确认结果 (`market/gift/index.wxml:21-27`). MKT-3-1: no app-only gate.
                if claimed {
                    Button(action: onOpenGifts) { Text("mp.gift.view") }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                        .accessibilityIdentifier("passGift.view")
                } else {
                    Button {
                        guard !state.claiming else { return }
                        onClaim()
                    } label: {
                        ZStack {
                            Text("mp.gift.claim").opacity(state.claiming ? 0 : 1)
                            if state.claiming { ProgressView() }
                        }
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .accessibilityIdentifier("passGift.claim")
                }
            } else {
                // MP failed bar: secondary 返回 (`market/gift/index.wxml:18-20`).
                Button { dismiss() } label: { Text("action.back") }
                    .buttonStyle(.bordered).controlSize(.large)
                    .accessibilityIdentifier("passGift.back")
            }
        }
        .cyPushedChrome(domain: .player)
        .navigationTitle(Text("mp.gift.nav"))
        .navigationBarTitleDisplayMode(.inline)
        .cyHaptic(.success, trigger: claimed)
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
    @Environment(\.locale) private var locale
    let phase: MPLoad<PlatformPassSubscriptionOrder>
    let onRetry: () -> Void
    @State private var copied = false
    @State private var openAssistant = false

    var body: some View {
        List {
            switch phase {
            case .loading:
                Section {
                    ProgressView { Text("cy.state.loading") }.frame(maxWidth: .infinity)
                        .accessibilityIdentifier("passOrder.loading")
                }
            case .failed(let message):
                ContentUnavailableView {
                    Label { message.map { Text(verbatim: $0) } ?? Text("mp.common.loadFailed") } icon: { Image(systemName: "exclamationmark.triangle") }
                } actions: {
                    Button(action: onRetry) { Text("action.retry") }
                        .buttonStyle(.bordered).controlSize(.large)
                        .accessibilityIdentifier("passOrder.retry")
                }
                .accessibilityIdentifier("passOrder.error")
            case .ready(let order):
                content(order)
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { onRetry() }
        .cyPushedChrome(domain: .player)
        .cyPageTitle("mp.passOrder.title")
        .navigationDestination(isPresented: $openAssistant) { MPReviewedPageScreen(page: "subpackageB/pages/im/list/index", query: [:]) }
    }

    private func fact(_ title: Text, _ value: Text) -> some View {
        LabeledContent { value } label: { title }
    }

    @ViewBuilder private func content(_ order: PlatformPassSubscriptionOrder) -> some View {
        Section {
            LabeledContent {
                Text(verbatim: order.amount.isEmpty ? MPText.unknown : LocaleDisplay.yuanAmounts(in: MPParityBindings.moneyText(order.amount), locale: locale))
                    .font(.headline).monospacedDigit().foregroundStyle(.primary)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: order.name)
                    if !order.sub.isEmpty { Text(verbatim: order.sub).font(.subheadline).foregroundStyle(.secondary) }
                }
            }
            // The order facts group (was the MP card id); on the head row so row ids below stay their own.
            .accessibilityIdentifier("passOrder.rows")
            fact(Text("mp.passOrder.state"), Text(verbatim: order.stateText))
            if !order.refundText.isEmpty {
                fact(Text("mp.passOrder.refund"), Text(verbatim: order.refundText))
            }
            switch order.refundDetail {
            case .refunded(let amount, let time):
                fact(Text("mp.passOrder.refundAmount"), Text(verbatim: LocaleDisplay.yuanAmounts(in: MPParityBindings.moneyText(amount), locale: locale)))
                if !time.isEmpty {
                    fact(Text("mp.passOrder.refundTime"), Text(verbatim: time))
                }
            case .rejected(let reason, _):
                if !reason.isEmpty {
                    fact(Text("mp.passOrder.rejectReason"), Text(verbatim: reason))
                }
                Button { openAssistant = true } label: {
                    HStack {
                        LabeledContent { Text("mp.passOrder.review.assistant") } label: { Text("mp.passOrder.review") }
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .contentShape(Rectangle())
                }
                .foregroundStyle(.primary)
                .accessibilityIdentifier("passOrder.review")
            case nil:
                EmptyView()
            }
            if !order.validTo.isEmpty {
                fact(Text("mp.passOrder.validTo"), Text(verbatim: order.validTo))
            }
            if !order.time.isEmpty {
                fact(Text("mp.passOrder.paidTime"), Text(verbatim: LocaleDisplay.civil(order.time, locale: locale)))
            }
            Button {
                LocalPasteboard.copy(order.orderNo)
                copied = true
            } label: {
                LabeledContent {
                    copied ? Text("mp.passOrder.copied") : Text("mp.passOrder.copy")
                } label: { Text("mp.passOrder.number").foregroundStyle(.primary) }
            }
            .sensoryFeedback(.success, trigger: copied)
            .accessibilityIdentifier("passOrder.copy")
        }
        if order.canResume || order.canCancel || order.canRefund {
            Section {
                PassOrderRefusedWrites(order: order, onWritten: onRetry)
            }
        }
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
    /// MP pass-order `onRefundSubmit`: an empty reason keeps 提交申请 tappable and answers 请填写退款原因.
    @State private var reasonMissing = false
    /// R8-MEM-5-1: MP `cy-inline-error` notice. A refused write says so instead of doing nothing.
    @State private var refusedNotice = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MPGatedNote(text: Text("mp.passOrder.gated"), identifier: "passOrder.gated")
            if refusedNotice {
                Label { Text("mp.passOrder.refused") } icon: { Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange) }
                    .font(.subheadline)
                    .accessibilityIdentifier("passOrder.refused")
            }
            if order.canResume {
                Button { refuse(.resume) } label: { Text("mp.passOrder.resume").frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered).controlSize(.large)
                    .accessibilityIdentifier("passOrder.resume")
            }
            if order.canCancel {
                Button(role: .destructive) { confirmCancel = true } label: { Text("mp.passOrder.cancel").frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered).controlSize(.large)
                    .accessibilityIdentifier("passOrder.cancel")
            }
            if order.canRefund {
                Button(role: .destructive) { refunding = true } label: { Text("mp.passOrder.refundApply").frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered).controlSize(.large)
                    .accessibilityIdentifier("passOrder.refund")
            }
        }
        .padding(.vertical, 4)
        .confirmationDialog(Text("mp.passOrder.cancel"), isPresented: $confirmCancel, titleVisibility: .visible) {
            Button(role: .destructive) { refuse(.cancel) } label: { Text("mp.passOrder.cancel") }
            Button(role: .cancel) {} label: { Text("common.cancel") }
        }
        .cySheet(isPresented: $refunding) {
            NavigationStack {
                Form {
                    // R8-MEM-5-2: MP OR-024 refund terms above the reason (fixed MP defaults until server terms are wired).
                    Section {
                        LabeledContent { Text("mp.member.fact.renewal.value") } label: { Text("mp.member.fact.renewal") }
                        LabeledContent { Text("mp.member.fact.refund.value") } label: { Text("mp.member.fact.refund") }
                    }
                    .accessibilityIdentifier("passOrder.refund.terms")
                    Section {
                        TextField(text: $reason, axis: .vertical) { Text("mp.passOrder.refundApply.placeholder") }
                            .lineLimit(3...6)
                            .onChange(of: reason) { _, newValue in
                                if newValue.count > 200 { reason = String(newValue.prefix(200)) }
                                if reasonMissing, !newValue.isEmpty { reasonMissing = false }
                            }
                    } header: {
                        Text("mp.passOrder.refundApply.reason")
                    } footer: {
                        VStack(alignment: .leading, spacing: 4) {
                            if reasonMissing {
                                Label { Text("mp.passOrder.refundApply.placeholder") } icon: { Image(systemName: "exclamationmark.circle") }
                                    .foregroundStyle(.red)
                                    .accessibilityIdentifier("passOrder.refund.reasonMissing")
                            }
                            Text(verbatim: "\(reason.count)/200").monospacedDigit()
                        }
                    }
                    Section {
                        Button(role: .destructive) {
                            let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { reasonMissing = true; return }
                            refunding = false
                            refuse(.refund, reason: trimmed)
                        } label: {
                            Text("mp.passOrder.refundApply.submit")
                        }
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
    /// MP `codeTitle`: empty until a status or result says something (the nav title already reads 兑换码).
    @State private var titleKey = ""
    @State private var claimed = false
    @State private var topicID: Int?
    @State private var openingLibrary = false
    @State private var openingTopic = false

    var body: some View {
        Form {
            // MP gf-hero: gift icon (check once claimed), dimmed on an error, with `codeTitle` under it when there is one.
            Section {
                VStack(spacing: CYSpacing.sm) {
                    Image(systemName: claimed ? "checkmark.circle.fill" : "gift.fill")
                        .font(.largeTitle)
                        .foregroundStyle(codeError ? Color.secondary : (claimed ? Color.green : Color.accentColor))
                        .contentTransition(.symbolEffect(.replace))
                        .accessibilityHidden(true)
                    if !titleKey.isEmpty {
                        Text(LocalizedStringKey(titleKey))
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.updatesFrequently)
                            .accessibilityIdentifier("platformCode.title")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, CYSpacing.sm)
            }
            if statusReady, codeOn, !claimed {
                Section {
                    TextField("platformCode.placeholder", text: $code)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onChange(of: code) { _, value in
                            if value.count > 64 { code = String(value.prefix(64)) }
                            // MP onCodeInput clears codeTitle / codeErr while typing.
                            if !working { titleKey = "" }
                        }
                        .accessibilityIdentifier("platformCode.input")
                }
                Section {
                    Button {
                        guard !working else { return }
                        Task { await redeem() }
                    } label: {
                        ZStack {
                            Text("platformCode.submit").opacity(working ? 0 : 1)
                            if working { ProgressView() }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .disabled(working || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("platformCode.submit")
                }
            }
            if claimed {
                Section {
                    Button { play() } label: { Text("platformCode.play").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("platformCode.play")
                }
            }
        }
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

    private var codeError: Bool {
        !titleKey.isEmpty && titleKey != "platformCode.success" && titleKey != "platformCode.replayed"
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
