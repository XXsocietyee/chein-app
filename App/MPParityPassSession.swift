import SwiftUI

// Pass and market reads for the existing `MPParityBindings` struct (`App/MPParityKit.swift`).
// Purchase, quote, order, and gift claim stay unreachable. Money stays off.
// Unknown numbers stay nil or an em dash; a server 0 stays 0.

extension MPParityBindings {
    /// Mirrors `PlatformPass.moneyEnabled`. A true value here still cannot send a write:
    /// the read transport refuses those paths, and `PlatformPass` throws before the network.
    static let moneyEnabled = false

    struct OrderFacts: Equatable {
        var shown: Bool
        var selfPlayPass: Bool
        var untilMonth: Int?
        var untilDay: Int?
        var actualPaid: Double?
        var free: Bool
        var payReachable: Bool
        var refundReachable: Bool
    }

    /// `identity-policy.js` `isMerchantView`, presentation only. `debugView == "user"` stays a player.
    /// An empty role falls through to `userType == 2`. This does not admit a merchant session.
    static func viewerIsMerchant(role: String, userType: String = "", debugView: String = "") -> Bool {
        if debugView == "user" { return false }
        if !role.isEmpty { return role == "merchant" }
        return userType == "2"
    }

    /// Membership card on the passes shop. Nil hides it (merchant, or the overview is off).
    static func memberSide(viewerIsMerchant: Bool, overview: PlatformPassOverview) -> PassMemberEntrySide? {
        guard !viewerIsMerchant, !overview.merchantBlocked, overview.enabled else { return nil }
        if overview.holding.active {
            let day = MPParityChinaClock.dotDay(overview.holding.coverageEnd ?? overview.holding.validTo)
            return .activeUntil(day.isEmpty ? MPText.unknown : day)
        }
        // MKT-4-1: passes/index.js:84 `planSide` joins the passView card prices (month only, 首发价 ¥X).
        let prices = saleablePlans(overview).map { planPriceText($0) }.filter { !$0.isEmpty }
        if !prices.isEmpty { return .plans(prices.joined(separator: " · ")) }
        if let count = overview.libraryCount { return .themeCount(count) }
        return .none
    }

    /// MKT-4-1: platform-pass.js:101-108 `passView` sells the month plan only (owner 2026-11-13); other plans are not shown.
    static func saleablePlans(_ overview: PlatformPassOverview) -> [PlatformPassPlan] {
        overview.plans.filter { $0.code == "MONTH" }
    }

    /// platform-pass.js:84-86 `planCard`: the month price reads 首发价 ¥X (OR-047).
    static func planPriceText(_ plan: PlatformPassPlan) -> String {
        let price = yuanFen(plan.priceFen)
        guard plan.code == "MONTH", !price.isEmpty else { return price }
        return appLocalized("mp.member.plan.launchPrice \(price)", locale: .current)
    }

    static func membershipContent(_ overview: PlatformPassOverview) -> PassMembershipContent {
        let saleable = saleablePlans(overview)
        // platform-pass.js `bestCode`: 最划算 only when there is more than one plan to compare.
        let bestIndex = saleable.count > 1 ? saleable.enumerated().min { lhs, rhs in
            pricePerDay(lhs.element) < pricePerDay(rhs.element)
        }?.offset : nil
        let plans = saleable.enumerated().map { index, plan in
            planCard(plan, best: index == bestIndex)
        }
        let active = overview.holding.active
        let day = MPParityChinaClock.dotDay(overview.holding.coverageEnd ?? overview.holding.validTo)
        let block: PassBuyBlock?
        if plans.isEmpty { block = .notOnSale }
        else if !overview.jsapiAvailable, !overview.xpayAvailable { block = .deviceUnavailable }
        else { block = nil }
        return PassMembershipContent(
            active: active,
            untilText: active ? (day.isEmpty ? MPText.unknown : day) : nil,
            themeCount: overview.libraryCount,
            plans: plans,
            selectedPlan: plans.first { $0.best }?.code ?? plans.first?.code,
            buyBlock: block,
            validDays: Dictionary(saleable.compactMap { plan in plan.validDays.map { (plan.code, $0) } },
                                  uniquingKeysWith: { first, _ in first }),
            buyPrice: saleable.first.map { yuanFen($0.priceFen) }.flatMap { $0.isEmpty ? nil : $0 },
            planLabel: active ? overview.holding.planLabel : nil,
            teammate: active && overview.holding.teammateBenefit,
            expiring: active && overview.holding.expiring,
            daysLeft: active ? overview.holding.daysRemaining : nil,
            daysTotal: active ? overview.holding.daysTotal : nil,
            terms: overview.terms)
    }

    /// Explore feed card: city, period, and year passes that have a cash price and covered works.
    static func exploreCard(products: [PlatformPassProduct], locale: Locale = .current) -> PassStoreCard? {
        let selling = products.filter(isStorePass).sorted { ($0.cashPrice ?? 0) < ($1.cashPrice ?? 0) }
        guard let cheapest = selling.first, let cash = cheapest.cashPrice else { return nil }
        let price = yuan(cash)
        let priceText = selling.count > 1
            ? String(localized: LocalizedStringResource("mp.pass.store.from \(price)", locale: locale))
            : price
        let cities = Set(selling.map(\.city).filter { !$0.isEmpty })
        let title: String
        if cities.count == 1, let city = cities.first {
            title = String(localized: LocalizedStringResource("mp.pass.store.oneCity \(city)", locale: locale))
        } else {
            title = String(localized: LocalizedStringResource("mp.pass.store.many", locale: locale))
        }
        let meta: String
        if selling.count == 1 {
            meta = String(localized: LocalizedStringResource("mp.pass.store.themes \(selling[0].coverCount)", locale: locale))
        } else {
            meta = String(localized: LocalizedStringResource("mp.pass.store.kinds \(selling.count)", locale: locale))
        }
        var covers: [String] = []
        for name in selling.flatMap(\.topics) where !name.isEmpty && !covers.contains(name) && covers.count < 3 {
            covers.append(name)
        }
        return PassStoreCard(title: title, meta: meta, priceText: priceText, covers: covers)
    }

    /// Covered orders hide the city-pass rows. Gift and extra-seat products never appear. Purchase stays off.
    static func checkoutCover(topicCovered: Bool, products: [PlatformPassProduct], topicID: String,
                              locale: Locale = .current) -> PassCheckoutCover {
        let passes: [PassCheckoutPass]
        if topicCovered || topicID.isEmpty {
            passes = []
        } else {
            passes = products.filter { product in
                product.topicIDs.contains(topicID) && product.productKind != 7 && product.productKind != 8 && !product.name.isEmpty
            }.prefix(3).map { product in
                PassCheckoutPass(id: product.id, name: product.name,
                                 priceText: checkoutPrice(product, locale: locale),
                                 meta: checkoutMeta(product, locale: locale))
            }
        }
        return PassCheckoutCover(covered: topicCovered, passes: passes)
    }

    /// Self-play registration facts. Pay and refund stay false.
    static func orderFacts(id: String, purchaseKind: Int?, ownerType: Int?, ticketID: String?,
                           expiresAt: String?, wechatPaymentAmount: Double?, payableAmount: Double?,
                           totalAmount: Double?, pointPaymentAmount: Double?) -> OrderFacts {
        let shown = !id.isEmpty
        let selfPlay = purchaseKind != nil
            ? purchaseKind == 2
            : (ownerType == 1 && (ticketID ?? "").isEmpty && !(expiresAt ?? "").isEmpty)
        let paid = wechatPaymentAmount ?? payableAmount ?? totalAmount
        let free = totalAmount == 0 && payableAmount == 0
            && (pointPaymentAmount == nil || pointPaymentAmount == 0)
            && (wechatPaymentAmount == nil || wechatPaymentAmount == 0)
        let day = shown && selfPlay ? MPParityChinaClock.shownMonthDay(expiresAt) : nil
        return OrderFacts(shown: shown, selfPlayPass: shown && selfPlay, untilMonth: day?.month, untilDay: day?.day,
                          actualPaid: shown ? paid : nil, free: shown && free,
                          payReachable: false, refundReachable: false)
    }

    static func productCard(_ product: PlatformPassProduct) -> PassProductCard {
        PassProductCard(
            id: product.id,
            name: product.name.isEmpty ? MPText.unknown : product.name,
            kind: PassProductKind(rawValue: product.productKind),
            city: product.city.isEmpty ? nil : product.city,
            validity: validity(product),
            seats: seatCount(product.seats),
            cashPriceText: product.cashPrice.flatMap { $0.isFinite ? yuanFixed($0) : nil },
            pointsPrice: wholePoints(product.pointsPrice),
            topics: product.topics,
            giftAllowed: false,
            giftOnly: product.giftOnly,
            isExtraSeat: product.isExtraSeat,
            faceText: product.city.isEmpty ? (product.name.isEmpty ? MPText.unknown : product.name) : product.city)
    }

    static func orderRow(_ order: PlatformPassOrder, names: [String: String], locale: Locale = .current) -> PassOrderRow {
        let resolved = order.row(nameByID: names)
        let name = resolved.name == "通行证订单" ? nil : resolved.name
        return PassOrderRow(id: order.orderNo, name: name, state: orderState(order.state),
                            amountText: orderAmount(order.amount, locale: locale),
                            timeText: order.time.isEmpty ? MPText.unknown : order.time)
    }

    static func giftRow(_ gift: PlatformPassGift, names: [String: String] = [:]) -> PassGiftRow {
        let name = gift.name(nameByID: names)
        return PassGiftRow(id: gift.key, status: giftStatus(gift.state),
                    claimDeadlineText: gift.claimDay.isEmpty ? nil : gift.claimDay,
                    timeText: gift.time.isEmpty ? MPText.unknown : gift.time,
                    name: name.isEmpty ? nil : name)
    }

    static func libraryCard(_ card: PlatformPassLibraryCard) -> PassLibraryCard {
        let kind: PassLibraryKind?
        switch card.productType {
        case 1: kind = .city
        case 2: kind = .free
        default: kind = nil
        }
        return PassLibraryCard(
            id: card.id,
            title: card.title.isEmpty ? MPText.unknown : card.title,
            coverURL: card.cover.isEmpty ? nil : card.cover,
            city: card.city.isEmpty ? nil : card.city,
            kind: kind,
            minutes: card.minuteCount,
            freeWithPass: card.free)
    }

    static func wholePoints(_ value: Double?) -> Int? { wholePoints(value, allowZero: true) }

    private static func isStorePass(_ product: PlatformPassProduct) -> Bool {
        guard [2, 3, 4].contains(product.productKind), !product.topics.isEmpty, !product.name.isEmpty,
              let cash = product.cashPrice, cash.isFinite, cash >= 0 else { return false }
        return true
    }

    private static func pricePerDay(_ plan: PlatformPassPlan) -> Double {
        guard let days = plan.validDays, days > 0 else { return Double(plan.priceFen) }
        return Double(plan.priceFen) / Double(days)
    }

    private static func planCard(_ plan: PlatformPassPlan, best: Bool) -> PassPlanCard {
        let price = planPriceText(plan)
        let line: PassPlanCard.Line
        if plan.code == "MONTH" {
            // platform-pass.js:79-80: the month line is always 30天·不自动续费.
            line = .month
        } else if let days = plan.validDays, days >= 300 {
            let monthly = Double(plan.priceFen) / 100 / (Double(days) / 30)
            line = .year(monthlyText: yuan(monthly))
        } else if plan.validDays == 30 {
            line = .month
        } else {
            let title = plan.title.isEmpty ? MPText.unknown : plan.title
            line = .custom(title: title, days: plan.validDays)
        }
        return PassPlanCard(code: plan.code, priceText: price, line: line, best: best)
    }

    private static func validity(_ product: PlatformPassProduct) -> PassValidity? {
        switch product.validityKind {
        case 1:
            guard let days = product.validDays else { return nil }
            return .daysAfterPurchase(days)
        case 3:
            guard let days = product.validDays else { return nil }
            return .daysFromFirstPlay(days)
        case 2:
            let text = product.validity
            let parts = text.components(separatedBy: " – ")
            if parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty { return .fixedRange(from: parts[0], to: parts[1]) }
            let prefix = "有效至 "
            if text.hasPrefix(prefix) {
                let day = String(text.dropFirst(prefix.count))
                return day.isEmpty ? nil : .fixedUntil(day)
            }
            return nil
        default:
            return nil
        }
    }

    private static func seatCount(_ seats: String) -> Int? {
        let digits = seats.prefix { $0.isNumber }
        guard let count = Int(digits), count > 1 else { return nil }
        return count
    }

    private static func orderState(_ state: String) -> PassOrderState {
        switch state {
        case "已购买": return .paid
        case "已购买 · 首次游玩时开始计算有效期": return .paidAwaitingFirstPlay
        case "已购买 · 礼品": return .paidGift
        case "待支付": return .pendingCash(blockedReason: nil)
        case "已取消": return .cancelled
        case "已退款": return .refunded
        default: return .unknown
        }
    }

    private static func orderAmount(_ amount: String, locale: Locale) -> String {
        if amount.isEmpty { return MPText.unknown }
        let suffix = " 积分"
        if amount.hasSuffix(suffix), let points = Int(amount.dropLast(suffix.count)) {
            return String(localized: LocalizedStringResource("mp.pass.points.amount \(points)", locale: locale))
        }
        return moneyText(amount)
    }

    private static func giftStatus(_ state: String) -> PassGiftStatus {
        if state.hasPrefix("待领取") { return .pending }
        if state == "已领取" { return .claimed }
        if state.hasPrefix("已过期") { return .expired }
        if state.hasPrefix("已撤销") { return .revoked }
        return .unknown
    }

    private static func checkoutPrice(_ product: PlatformPassProduct, locale: Locale) -> String {
        if let cash = product.cashPrice, cash.isFinite { return yuan(cash) }
        if let points = wholePoints(product.pointsPrice) {
            return String(localized: LocalizedStringResource("mp.pass.points.amount \(points)", locale: locale))
        }
        return MPText.unknown
    }

    private static func checkoutMeta(_ product: PlatformPassProduct, locale: Locale) -> String? {
        var parts: [String] = []
        if !product.city.isEmpty { parts.append(product.city) }
        if product.coverCount > 0 {
            parts.append(String(localized: LocalizedStringResource("mp.pass.store.themes \(product.coverCount)", locale: locale)))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func wholePoints(_ value: Double?, allowZero: Bool) -> Int? {
        guard let value, value.isFinite, value.rounded() == value else { return nil }
        guard allowZero || value != 0 else { return nil }
        guard value <= Double(Int.max), value >= Double(Int.min) else { return nil }
        return Int(value.rounded())
    }

    /// Owner decision 9 (11-24): money is always two decimals through the shared `MoneyDisplay` formatter (¥12.50, ¥99.00).
    fileprivate static func yuan(_ value: Double) -> String { yuanFen(Int((value * 100).rounded())) }

    fileprivate static func yuanFixed(_ value: Double) -> String { yuan(value) }

    static func yuanFen(_ fen: Int) -> String {
        (fen < 0 ? "-" : "") + MoneyDisplay.yuan(Decimal(abs(fen)) / 100)
    }

    /// Server money text (`¥12.5`, `-¥3`) re-shown through `MoneyDisplay.text`; anything else is shown as given.
    static func moneyText(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let sign = trimmed.hasPrefix("-") ? "-" : ""
        let body = trimmed.drop { $0 == "-" }
        guard body.hasPrefix("¥") else { return raw }
        let digits = String(body.dropFirst())
        let formatted = MoneyDisplay.text(digits)
        return formatted == digits && !digits.contains(".") ? raw : sign + "¥" + formatted
    }
}

/// Forwards only the six pass reads and the points POST. Purchase, quote, order, and claim never leave the device.
struct PlatformPassReadOnlyTransport: HTTPTransport {
    let underlying: any HTTPTransport

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        guard let url = request.url, let method = request.httpMethod?.uppercased() else { throw APIError.invalidRequest }
        let path = url.path
        let refused = [PlatformPass.quotePath, PlatformPass.orderPath, PlatformPass.claimPath]
        if refused.contains(where: { Self.matches(path, $0) }) { throw PlatformPassWriteRefusal.unreachable }
        // The purchase URL doubles as the GET list of the viewer's pass orders: only the POST is a write.
        if method != "GET", Self.matches(path, PlatformPass.purchasePath) { throw PlatformPassWriteRefusal.unreachable }
        if method != "GET", Self.isPassOrderChild(path) { throw PlatformPassWriteRefusal.unreachable }
        let reads = [PlatformPass.overviewPath, PlatformPass.libraryPath, PlatformPass.productListPath,
                     PlatformPass.ordersPath, PlatformPass.giftsBoughtPath, PlatformPass.giftsReceivedPath,
                     PlatformPass.passOrdersPath]
        if method == "GET", reads.contains(where: { Self.matches(path, $0) }) || Self.isPassOrderDetail(path) || Self.isProductDetail(path) {
            return try await underlying.send(request)
        }
        // Theme library: the public catalog list, a read sent as POST with a JSON filter body.
        if method == "POST", Self.matches(path, PlatformPass.publicCatalogListPath), request.httpBody != nil {
            return try await underlying.send(request)
        }
        if method == "POST", Self.matches(path, PlatformPass.pointsPath),
           request.httpBody == nil, request.httpBodyStream == nil {
            return try await underlying.send(request)
        }
        throw APIError.notConfigured
    }

    /// `…/api/platform-pass/orders/{orderNo}` with one safe segment (pay, confirm, cancel and refund have two).
    private static func isPassOrderDetail(_ path: String) -> Bool {
        let prefix = "/" + PlatformPass.passOrdersPath + "/"
        guard let range = path.range(of: prefix, options: .backwards) else { return false }
        return PlatformPassSubscriptionOrder.orderNoAllowed(String(path[range.upperBound...]))
    }

    /// Anything below `…/api/platform-pass/orders/`: pay, confirm, cancel, refund-apply.
    private static func isPassOrderChild(_ path: String) -> Bool {
        path.contains("/" + PlatformPass.passOrdersPath + "/")
    }

    /// `…/api/marketing/product/{id}` where the id normalises like the route table (never list, quote, order, orders).
    private static func isProductDetail(_ path: String) -> Bool {
        let prefix = "/" + PlatformPass.productDetailPrefix
        guard let range = path.range(of: prefix, options: .backwards) else { return false }
        return G6CapabilitySource.productIDAllowed(String(path[range.upperBound...]))
    }

    private static func matches(_ path: String, _ relative: String) -> Bool {
        let full = relative.hasPrefix("/") ? relative : "/" + relative
        return path == full || path.hasSuffix(full)
    }
}

extension AppSession {
    var mpViewerIsMerchant: Bool {
        MPParityBindings.viewerIsMerchant(role: account?.role ?? "", userType: account?.userType.map(String.init) ?? "")
    }

    func passReadToken() -> String? { currentRuntimeDependencyContext?.session.token }

    /// MP `market/passes` `loadRedeem` / `market/gift` `loadCodeStatus`: signed-in only; closed, refused or unreadable is false.
    func loadPassRedeemEnabled() async -> Bool {
        guard let token = passReadToken(), let base = currentRuntimeDependencyContext?.baseURL,
              let configuration = try? APIConfiguration(baseURL: base) else { return false }
        let source = ChannelRedeemSource(configuration: configuration, transport: composition.makeTransport())
        return (try? await source.status(token: token)) ?? false
    }

    func makePlatformPassReader() -> PlatformPass? {
        guard let base = currentRuntimeDependencyContext?.baseURL,
              let configuration = try? APIConfiguration(baseURL: base) else { return nil }
        return PlatformPass(configuration: configuration,
                            transport: PlatformPassReadOnlyTransport(underlying: composition.makeTransport()))
    }

    func mpParityPassBindings() -> MPParityBindings {
        var bindings = MPParityBindings.none
        bindings.viewerIsMerchant = { [weak self] in self?.mpViewerIsMerchant ?? false }
        bindings.isSignedIn = { [weak self] in self?.passReadToken() != nil }
        bindings.passRedeemEnabled = { [weak self] in await self?.loadPassRedeemEnabled() ?? false }
        bindings.revealAccountKey = { [weak self] in self?.account.map { String($0.id) } }
        bindings.passMarket = { [weak self] in MPParityPassMarketModel(session: self) }
        bindings.passDetail = { [weak self] id in MPParityPassDetailModel(session: self, productID: id) }
        bindings.passGift = { [weak self] token in MPParityPassGiftModel(session: self, giftToken: token) }
        bindings.membership = { [weak self] in MPParityPassMembershipModel(session: self) }
        bindings.passLibrary = { [weak self] in MPParityPassLibraryModel(session: self) }
        bindings.passOrder = { [weak self] orderNo in MPParityPassOrderModel(session: self, orderNo: orderNo) }
        bindings.passStoreCard = { [weak self] in await self?.loadPassStoreCard() ?? nil }
        bindings.passCheckoutCover = { [weak self] topicID in await self?.loadPassCheckoutCover(topicID: topicID) ?? nil }
        bindings.orderDetail = { [weak self] id in
            guard let self else { return AnyView(EmptyView()) }
            return AnyView(MPParityRegistrationOrder(registrationID: id, session: self))
        }
        return bindings
    }

    func loadPassStoreCard() async -> PassStoreCard? {
        guard !mpViewerIsMerchant, let reader = makePlatformPassReader(), let token = passReadToken() else { return nil }
        guard let products = try? await reader.productList(token: token) else { return nil }
        return MPParityBindings.exploreCard(products: products)
    }

    func loadPassCheckoutCover(topicID: Int) async -> PassCheckoutCover? {
        guard topicID > 0, !mpViewerIsMerchant, let reader = makePlatformPassReader(), let token = passReadToken() else { return nil }
        let covered = (try? await topicReader.topicDetail(id: topicID))?.platformPassCovered ?? false
        guard let products = try? await reader.productList(token: token) else {
            return covered ? PassCheckoutCover(covered: true, passes: []) : nil
        }
        return MPParityBindings.checkoutCover(topicCovered: covered, products: products, topicID: String(topicID))
    }
}

/// Installs the filled bindings once for the player root. Closures read the live session.
struct MPParityPassEnvironment: ViewModifier {
    let session: AppSession
    @State private var bindings: MPParityBindings

    init(session: AppSession) {
        self.session = session
        _bindings = State(initialValue: session.mpParityPlayerReads())
    }

    func body(content: Content) -> some View {
        content.environment(\.mpParity, bindings)
            .environment(\.g6Capabilities, session.g6Capabilities())
            .modifier(PlayerJourneySignInSheet(bridge: .shared, session: session))
    }
}

/// Order detail for a claimed gift. No lifecycle coordinator, so pay and refund stay off this screen.
struct MPParityRegistrationOrder: View {
    let registrationID: String
    let session: AppSession

    var body: some View {
        if let id = Int(registrationID), id > 0 {
            ProfileOrderDetailView(id: id, reader: session.ownedOrderReader)
        } else {
            CYEmptyState(systemImage: "doc.text", "mp.route.unavailable", messageIdentifier: "mp.order.missing")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

@MainActor @Observable final class MPParityPassMarketModel: PassMarketBinding {
    private(set) var state = PassMarketState()
    private weak var session: AppSession?
    private var generation = 0

    init(session: AppSession?) { self.session = session }

    func load(quiet: Bool) {
        generation &+= 1
        let ticket = generation
        if !quiet {
            state.content = .loading
            state.refreshFailed = false
        }
        Task { [weak self] in await self?.reload(quiet: quiet, ticket: ticket) }
    }

    private func reload(quiet: Bool, ticket: Int) async {
        guard ticket == generation else { return }
        guard let session, let reader = session.makePlatformPassReader() else { state.content = .failed(nil); return }
        // Mini-program `market/passes`: the on-sale list is public; orders, gifts and pass orders need a session.
        // Points, the member overview and pass orders are optional: their failure never blanks the page.
        let token = session.passReadToken()
        let merchant = session.mpViewerIsMerchant
        state.signedIn = token != nil
        do {
            let products = try await reader.productList(token: token)
            var orders: [PlatformPassOrder] = []
            var gifts = PlatformPassGifts.empty
            var passOrders: [PlatformPassSubscriptionOrder] = []
            var points: Double?
            var overview: PlatformPassOverview?
            if let token {
                orders = try await reader.orders(token: token)
                gifts = try await reader.gifts(token: token)
                passOrders = (try? await reader.passOrders(token: token)) ?? []
                if !merchant {
                    if let memberID = session.account?.id, memberID > 0 {
                        points = try? await reader.points(token: token, memberID: memberID)
                    } else {
                        points = try? await reader.points(token: token)
                    }
                    overview = try? await reader.overview(token: token, viewerIsMerchant: false)
                }
            }
            guard ticket == generation else { return }
            var codeOn = false
            if let token, let base = session.currentRuntimeDependencyContext?.baseURL,
               let configuration = try? APIConfiguration(baseURL: base) {
                let source = ChannelRedeemSource(configuration: configuration, transport: session.composition.makeTransport())
                codeOn = (try? await source.status(token: token)) == true
            }
            guard ticket == generation else { return }
            assert(gifts.claimReachable == false)
            assert(gifts.bought.allSatisfy { $0.claimReachable == false })
            var names: [String: String] = [:]
            for product in products where !product.name.isEmpty { names[product.id] = product.name }
            state.content = .ready(PassMarketContent(
                // Buyer walk 1122: an extra seat is bought from its original order, so it is not listed as on sale.
                products: products.filter { !$0.isExtraSeat }.map(MPParityBindings.productCard),
                orders: orders.map { MPParityBindings.orderRow($0, names: names) },
                giftsBought: gifts.bought.map { MPParityBindings.giftRow($0, names: names) },
                giftsReceived: gifts.received.map { MPParityBindings.giftRow($0, names: names) },
                passOrders: passOrders))
            state.member = overview.flatMap { MPParityBindings.memberSide(viewerIsMerchant: false, overview: $0) }
            state.pointBalance = MPParityBindings.wholePoints(points)
            state.platformCodeEnabled = codeOn
            state.refreshFailed = false
        } catch is CancellationError {
            return
        } catch {
            guard ticket == generation else { return }
            if quiet, case .ready = state.content { state.refreshFailed = true }
            else { state.content = .failed(nil); state.refreshFailed = false }
        }
    }
}

@MainActor @Observable final class MPParityPassDetailModel: PassDetailBinding {
    private(set) var state = PassDetailState()
    private weak var session: AppSession?
    let productID: String

    init(session: AppSession?, productID: String) {
        self.session = session
        self.productID = productID
    }

    func load() {
        Task { [weak self] in await self?.reload() }
    }

    func setForGift(_ forGift: Bool) { state.forGift = forGift }

    func dismissResult() {}

    private func reload() async {
        state.unlockSteps = []
        state.giftShare = nil
        guard let session, !productID.isEmpty, let reader = session.makePlatformPassReader() else {
            state.product = .failed(nil)
            state.buy = .unavailable(reason: nil)
            return
        }
        // A guest sees the product (the read is public) and a 购买 button that asks to sign in.
        let token = session.passReadToken()
        // G6: the detail page reads `GET /api/marketing/product/{id}` like `subpackageMember/market/pass`.
        if let source = session.g6Source(), let g6Token = session.g6Token(), G6CapabilitySource.productIDAllowed(productID) {
            let envelope = try? await source.marketingProduct(id: productID, token: g6Token)
            if Task.isCancelled { return }
            switch envelope.map(G6MarketingProduct.outcome) ?? .failed(reasonCode: nil) {
            case .ready(let product):
                await apply(product)
            case .failed(let reasonCode):
                state.product = .failed(G6Copy.productReason(reasonCode))
                state.buy = .unavailable(reason: nil)
            }
            return
        }
        do {
            // `GET /api/marketing/product/{id}` like the mini-program, so an off-sale or older product still opens.
            let product = try await reader.product(id: productID, token: token)
            if Task.isCancelled { return }
            await apply(product)
            if token == nil, case .buyable = state.buy { state.buy = .signIn }
        } catch is CancellationError {
            return
        } catch {
            state.product = .failed(nil)
            state.buy = .unavailable(reason: nil)
        }
    }

    /// Group and school products quote `/api/marketing/group-checkout/quote`. The catalog cash price is not the total.
    private func apply(_ product: PlatformPassProduct) async {
        let card = MPParityBindings.productCard(product)
        state.product = .ready(card)
        // A gift-only product (kind 7) is always bought for a friend: 使用人 reads 领取礼品的好友.
        state.forGift = card.giftOnly
        state.activateTopicID = product.topicIDs.first
        guard card.kind == .group || card.kind == .schoolGroup else {
            state.groupQuote = nil
            state.checkout = Self.checkout(product)
            state.buy = Self.buy(product)
            return
        }
        state.checkout = []
        state.buy = .loading
        state.groupQuote = .loading
        guard let session, let client = WP07CommerceSession.client(session),
              let productID = Int(product.id), productID > 0 else {
            state.groupQuote = .failed(nil)
            state.buy = .unavailable(reason: nil)
            return
        }
        do {
            let display = try await client.quote(productID: productID)
            if Task.isCancelled { return }
            state.groupQuote = .ready(display)
            state.buy = .checkout(activityID: display.activityID, ticketID: display.ticketID)
        } catch is CancellationError {
            return
        } catch {
            state.groupQuote = .failed(nil)
            state.buy = .unavailable(reason: nil)
        }
    }

    private static func buy(_ product: PlatformPassProduct) -> PassBuyState {
        guard MPParityBindings.moneyEnabled == false, MPCommerceGate.purchasesEnabled == false else {
            return .unavailable(reason: nil)
        }
        // market-view.js: an extra seat is added from its original order and cannot be bought here.
        if product.isExtraSeat {
            return .unavailable(reason: String(localized: LocalizedStringResource("mp.pass.buy.extraSeat", locale: .current)))
        }
        var modes: [PassPayMode] = []
        if let cash = product.cashPrice, cash.isFinite {
            modes.append(PassPayMode(mode: .cash, amountText: MPParityBindings.yuan(cash)))
        }
        if let points = MPParityBindings.wholePoints(product.pointsPrice) {
            modes.append(PassPayMode(mode: .points, amountText: String(localized: LocalizedStringResource("mp.pass.points.amount \(points)", locale: .current))))
        }
        if modes.isEmpty { return .unavailable(reason: nil) }
        return .buyable(payModes: modes, cashReason: nil)
    }

    /// Before a quote the mini-program shows one 价格 row, "¥x / y 积分" (`market-view.js` 156-160).
    private static func checkout(_ product: PlatformPassProduct) -> [PassCheckoutRow] {
        var parts: [String] = []
        if let cash = product.cashPrice, cash.isFinite { parts.append(MPParityBindings.yuanFixed(cash)) }
        if let points = MPParityBindings.wholePoints(product.pointsPrice) {
            parts.append(String(localized: LocalizedStringResource("mp.pass.points.amount \(points)", locale: .current)))
        }
        guard !parts.isEmpty else { return [] }
        return [PassCheckoutRow(kind: .price, valueText: parts.joined(separator: " / "), note: nil, off: false)]
    }
}

@MainActor @Observable final class MPParityPassGiftModel: PassGiftClaimBinding {
    private(set) var state = PassGiftClaimState()
    private weak var session: AppSession?
    private let giftToken: String
    /// MP `this._reqId`: made on the first tap and resent unchanged on every retry (`market/gift/index.js:106`).
    private var requestID: String?

    init(session: AppSession?, giftToken: String) {
        self.session = session
        self.giftToken = giftToken
    }

    /// MKT-3-1: `POST /api/marketing/product/gifts/claim {token, requestId}` (`market/gift/index.js:101-123`).
    /// The claimer sends only the gift token, so this is not a money write (MP-first, owner rule 2026-11-25).
    func claim() {
        guard !state.claiming else { return }
        guard let session, let token = session.passReadToken(),
              let base = session.currentRuntimeDependencyContext?.baseURL,
              let configuration = try? APIConfiguration(baseURL: base) else {
            state.phase = .failed(reason: MPParityBindings.giftClaimReason(nil))
            return
        }
        let id = requestID ?? PlatformPassGiftClaimSource.requestID()
        requestID = id
        state.claiming = true
        let source = PlatformPassGiftClaimSource(configuration: configuration, transport: session.composition.makeTransport())
        let gift = giftToken
        Task { [weak self] in
            let outcome = await source.claim(giftToken: gift, requestID: id, token: token)
            self?.apply(outcome)
        }
    }

    private func apply(_ outcome: PlatformPassGiftClaimOutcome) {
        state.claiming = false
        switch outcome {
        case .claimed(let registrationID): state.phase = .claimed(registrationID: registrationID)
        case .missing: state.phase = .missing
        case .failed(let code): state.phase = .failed(reason: MPParityBindings.giftClaimReason(code))
        case .unknown: state.phase = .unknown
        }
    }
}

extension MPParityBindings {
    /// MP `claimReasonText` (`subpackageMember/utils/market-view.js:200-219`); default 礼品当前不可领取.
    static func giftClaimReason(_ code: String?) -> String {
        let key: String.LocalizationValue
        switch code {
        case "GIFT_CLAIM_EXPIRED": key = "mp.gift.reason.claimExpired"
        case "GIFT_NOT_FOUND": key = "mp.gift.reason.notFound"
        case "GIFT_NOT_FOR_YOU": key = "mp.gift.reason.notForYou"
        case "GIFT_ALREADY_CLAIMED": key = "mp.gift.reason.alreadyClaimed"
        case "GIFT_SOURCE_EXPIRED": key = "mp.gift.reason.sourceExpired"
        case "GIFT_SOURCE_ALREADY_USED": key = "mp.gift.reason.sourceUsed"
        default: key = "mp.gift.reason.unavailable"
        }
        return appLocalized(key, locale: Locale.current)
    }
}

@MainActor @Observable final class MPParityPassMembershipModel: PassMembershipBinding {
    private(set) var phase: PassMembershipPhase = .loading
    private weak var session: AppSession?

    init(session: AppSession?) { self.session = session }

    func load() { Task { [weak self] in await self?.reload() } }

    func selectPlan(_ code: String) {
        guard case .ready(var content) = phase, content.plans.contains(where: { $0.code == code }) else { return }
        content.selectedPlan = code
        phase = .ready(content)
    }

    private func reload() async {
        guard let session else { phase = .failed; return }
        if session.mpViewerIsMerchant { phase = .merchant; return }
        guard let reader = session.makePlatformPassReader(), let token = session.passReadToken() else {
            phase = .failed
            return
        }
        do {
            let overview = try await reader.overview(token: token, viewerIsMerchant: false)
            if overview.merchantBlocked { phase = .merchant; return }
            if !overview.enabled { phase = .notEnabled; return }
            phase = .ready(MPParityBindings.membershipContent(overview))
        } catch is CancellationError {
            return
        } catch {
            phase = .failed
        }
    }
}

@MainActor @Observable final class MPParityPassLibraryModel: PassLibraryBinding {
    private(set) var phase: PassLibraryPhase = .loading
    private weak var session: AppSession?
    private var generation = 0

    init(session: AppSession?) { self.session = session }

    func load(kind: PassLibraryKind) {
        generation &+= 1
        let ticket = generation
        phase = .loading
        Task { [weak self] in await self?.reload(kind: kind, ticket: ticket) }
    }

    private func reload(kind: PassLibraryKind, ticket: Int) async {
        guard ticket == generation else { return }
        // Mini-program `market/library` reads the public catalog: no pass switch, no account view, no session needed.
        guard let session, let reader = session.makePlatformPassReader() else { phase = .failed(nil); return }
        do {
            let cards = try await reader.publicLibrary(kind: kind.rawValue, token: session.passReadToken())
            guard ticket == generation else { return }
            phase = .ready(cards.map(MPParityBindings.libraryCard))
        } catch is CancellationError {
            return
        } catch {
            guard ticket == generation else { return }
            phase = .failed(nil)
        }
    }
}

/// `market/pass-order`: `GET /api/platform-pass/orders/{orderNo}`. A guest gets the shared sign-in request.
@MainActor @Observable final class MPParityPassOrderModel: PassOrderDetailBinding {
    private(set) var phase: MPLoad<PlatformPassSubscriptionOrder> = .loading
    private weak var session: AppSession?
    let orderNo: String

    init(session: AppSession?, orderNo: String) {
        self.session = session
        self.orderNo = orderNo
    }

    func load() {
        if phase.value == nil { phase = .loading }
        Task { [weak self] in await self?.reload() }
    }

    private func reload() async {
        guard let session, let reader = session.makePlatformPassReader() else { phase = .failed(nil); return }
        guard let token = session.passReadToken() else {
            PlayerJourneySignInBridge.shared.request()
            phase = .failed(nil)
            return
        }
        do {
            let order = try await reader.passOrderDetail(orderNo: orderNo, token: token)
            phase = .ready(order)
        } catch is CancellationError {
            return
        } catch {
            // Keep a row already on screen; only a first load turns into the error state.
            if phase.value == nil { phase = .failed(nil) }
        }
    }
}
