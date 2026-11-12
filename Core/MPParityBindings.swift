import Foundation

/// Pass and market bindings. Pure: no network, no payment.
/// `viewerIsMerchant` follows `utils/identity/identity-policy.js` `isMerchantView`.
/// `passStoreCard` is the passes-page membership card (`market/passes` `loadMember`).
/// `passCheckoutCover` is `pages/topic/utils/checkout-view.js` when `platformPassCovered` is true.
/// `orderDetail` is `cy-scene-member-order-detail` (`id="orderDetail"`): self-play pass facts only.
/// Purchase and refund stay unreachable. Money stays off.
public enum MPParityBinding: String, CaseIterable, Sendable {
    case viewerIsMerchant
    case passStoreCard
    case passCheckoutCover
    case orderDetail
}

public enum MPParityBindings {
    public static let miniProgramCommit = PlatformPass.miniProgramCommit
    public static let passAndMarket = MPParityBinding.allCases
    public static let moneyEnabled = false

    /// `debugView == "user"` forces the player view. Empty role falls through to `userType == 2`.
    public static func viewerIsMerchant(role: String, userType: String = "", debugView: String = "") -> Bool {
        if debugView == "user" { return false }
        if !role.isEmpty { return role == "merchant" }
        return userType == "2"
    }

    public struct PassStoreCard: Equatable, Sendable {
        public let shown: Bool
        public let side: String
        public let purchaseReachable: Bool
    }

    /// Merchants and a disabled overview hide the card. A shown card still cannot purchase.
    public static func passStoreCard(viewerIsMerchant: Bool, overview: PlatformPassOverview) -> PassStoreCard {
        guard !viewerIsMerchant, overview.enabled else {
            return PassStoreCard(shown: false, side: "", purchaseReachable: false)
        }
        let holding = overview.holding
        let until = holding.active ? MPParityChinaClock.dotDay(holding.coverageEnd ?? holding.validTo) : ""
        let planSide = overview.plans.map { yuanFen($0.priceFen) }.filter { !$0.isEmpty }.joined(separator: " · ")
        let side: String
        if holding.active, !until.isEmpty {
            side = "有效期至 " + until
        } else if !planSide.isEmpty {
            side = planSide
        } else if let count = overview.libraryCount {
            side = "\(count) 个主题全部可玩"
        } else {
            side = ""
        }
        return PassStoreCard(shown: true, side: side, purchaseReachable: false)
    }

    public struct CheckoutLine: Equatable, Sendable {
        public let key: String
        public let label: String
        public let value: String
    }

    public struct CheckoutPass: Equatable, Sendable {
        public let id: String
        public let name: String
        public let meta: String
        public let price: String
    }

    public struct PassCheckoutCover: Equatable, Sendable {
        public let covered: Bool
        public let totalText: String
        public let payLabel: String
        public let bill: [CheckoutLine]
        public let passes: [CheckoutPass]
        public let purchaseReachable: Bool
    }

    /// Ready quote with `platformPassCovered` and a non-positive pay amount covers the ticket at ¥0.
    /// The pay label may say 免费领取; `purchaseReachable` stays false.
    public static func passCheckoutCover(selfPlayPrice: Double?, quoteState: String, payAmount: Double?,
                                         memberDiscountYuan: Double?, platformPassCovered: Bool,
                                         products: [PlatformPassProduct], topicID: String) -> PassCheckoutCover {
        let ready = quoteState == "ready"
        let quotedPay = ready ? finite(payAmount) : nil
        let pay = quotedPay ?? (quoteState == "refused" ? nil : finite(selfPlayPrice))
        let covered = ready && platformPassCovered && (pay.map { $0 <= 0 } ?? false)
        let discount = !covered ? positive(ready ? memberDiscountYuan : nil) : nil
        var bill: [CheckoutLine] = []
        if let pay {
            let list = covered ? (finite(memberDiscountYuan) ?? pay) : (discount.map { pay + $0 } ?? pay)
            bill.append(CheckoutLine(key: "pass", label: "自玩门票 × 1", value: yuan(list)))
            if let discount {
                bill.append(CheckoutLine(key: "club", label: "俱乐部会员", value: "-" + yuan(discount)))
            }
            if covered {
                bill.append(CheckoutLine(key: "member", label: "通行证", value: "你已可直接游玩"))
            }
        }
        let passes = covered ? [] : coveringPasses(products, topicID: topicID)
        let free = pay.map { $0 <= 0 } ?? false
        let refused = quoteState == "refused"
        let label: String
        if refused { label = "暂不可购买" }
        else if free { label = "免费领取" }
        else if let pay { label = "支付 " + yuan(pay) }
        else { label = "支付" }
        return PassCheckoutCover(covered: covered, totalText: pay.map(yuan) ?? "—", payLabel: label,
                                 bill: bill, passes: passes, purchaseReachable: false && !moneyEnabled)
    }

    public struct OrderDetail: Equatable, Sendable {
        public let shown: Bool
        public let orderID: String
        public let selfPlayPass: Bool
        public let untilText: String
        public let actualPaid: Double?
        public let free: Bool
        public let payReachable: Bool
        public let refundReachable: Bool
    }

    /// Registration order detail. `purchaseKind == 2` is a self-play pass; a missing kind uses
    /// topic owner, no ticket, and an expiry. Pay and refund are not reachable.
    public static func orderDetail(id: String, purchaseKind: Int?, ownerType: Int?, ticketID: String?,
                                   expiresAt: String?, wechatPaymentAmount: Double?, payableAmount: Double?,
                                   totalAmount: Double?, pointPaymentAmount: Double?) -> OrderDetail {
        let shown = !id.isEmpty
        let explicitKind = purchaseKind != nil
        let selfPlay = explicitKind ? purchaseKind == 2 : (ownerType == 1 && (ticketID ?? "").isEmpty && !(expiresAt ?? "").isEmpty)
        let paid = wechatPaymentAmount ?? payableAmount ?? totalAmount
        let free = totalAmount == 0 && payableAmount == 0
            && (pointPaymentAmount == nil || pointPaymentAmount == 0)
            && (wechatPaymentAmount == nil || wechatPaymentAmount == 0)
        return OrderDetail(shown: shown, orderID: id, selfPlayPass: shown && selfPlay,
                           untilText: shown && selfPlay ? MPParityChinaClock.passUntil(expiresAt) : "",
                           actualPaid: shown ? paid : nil, free: shown && free,
                           payReachable: false, refundReachable: false)
    }

    private static func coveringPasses(_ products: [PlatformPassProduct], topicID: String) -> [CheckoutPass] {
        guard !topicID.isEmpty else { return [] }
        return products.filter { product in
            product.topicIDs.contains(topicID) && product.productKind != 8 && product.productKind != 7 && !product.name.isEmpty
        }.prefix(3).map { product in
            var meta: [String] = []
            if !product.city.isEmpty { meta.append(product.city) }
            meta.append("\(product.coverCount) 个主题")
            if (product.validityKind == 1 || product.validityKind == 3), let days = product.validDays {
                meta.append("\(days) 天有效")
            }
            let price: String
            if let cash = product.cashPrice { price = yuan(cash) }
            else if let points = product.pointsPrice { price = plain(points) + " 积分" }
            else { price = "" }
            return CheckoutPass(id: product.id, name: product.name, meta: meta.joined(separator: " · "), price: price)
        }
    }

    private static func finite(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        return value
    }

    private static func positive(_ value: Double?) -> Double? {
        guard let value = finite(value), value > 0 else { return nil }
        return value
    }

    private static func yuan(_ value: Double) -> String {
        let cents = Int((value * 100).rounded())
        let whole = abs(cents) / 100
        let frac = abs(cents) % 100
        if frac == 0 { return "¥\(whole)" }
        return String(format: "¥%d.%02d", whole, frac)
    }

    private static func yuanFen(_ fen: Int) -> String {
        let whole = fen / 100
        let frac = abs(fen % 100)
        if frac == 0 { return "¥\(whole)" }
        return String(format: "¥%d.%02d", whole, frac)
    }

    private static func plain(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value.rounded())) : String(format: "%g", value)
    }
}

enum MPParityChinaClock {
    static func dotDay(_ raw: String?) -> String {
        guard let ms = MoneyParityTime.timestamp(raw) else { return "" }
        let parts = clock(ms)
        return String(format: "%04d.%02d.%02d", parts.year, parts.month, parts.day)
    }

    /// `order-status.js` `passUntilText`: midnight China rolls back one millisecond.
    static func passUntil(_ raw: String?) -> String {
        guard let ms = MoneyParityTime.timestamp(raw) else { return "" }
        let parts = clock(ms)
        let shown = (parts.hour == 0 && parts.minute == 0 && ms % 60_000 == 0) ? clock(ms - 1) : parts
        return "可玩至 \(shown.month) 月 \(shown.day) 日"
    }

    private static func clock(_ ms: Int64) -> (year: Int, month: Int, day: Int, hour: Int, minute: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        let date = Date(timeIntervalSince1970: TimeInterval(ms + MoneyParityTime.chinaOffsetMs) / 1000)
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return (parts.year ?? 0, parts.month ?? 0, parts.day ?? 0, parts.hour ?? 0, parts.minute ?? 0)
    }
}
