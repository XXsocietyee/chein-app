import Foundation

/// `pages/activity/utils/quote-view.js` `catalogView`. Empty offers, promotions, and tiers mean the block is not drawn.
/// Remaining time comes only from `windowEndsAt - serverNow`, never the device clock.
public struct G6PromotionCatalog: Equatable, Sendable {
    public struct Offer: Equatable, Sendable, Identifiable {
        public let id: String
        public let name: String
        public let available: Bool
        /// `省 ¥x.xx` amount text without the prefix, only when available with a positive difference.
        public let saveYuan: String?
        public let reasonCode: String?
    }

    public enum Remain: Equatable, Sendable { case days(Int), hours(Int), minutes(Int) }

    public struct Promotion: Equatable, Sendable, Identifiable {
        public let id: String
        public let name: String
        public let eligible: Bool
        public let remain: Remain?
        public let reasonCode: String?
    }

    public enum Range: Equatable, Sendable { case exact(Int), span(Int, Int), from(Int) }

    public struct Tier: Equatable, Sendable, Identifiable {
        public let id: String
        public let range: Range
        public let unitPrice: String
    }

    public let offers: [Offer]
    public let promotions: [Promotion]
    public let tiers: [Tier]
    public var show: Bool { !offers.isEmpty || !promotions.isEmpty || !tiers.isEmpty }

    public static let empty = G6PromotionCatalog(offers: [], promotions: [], tiers: [])

    public static let reasonCodes: Set<String> = [
        "TRIGGER_FACT_MISSING", "TRIGGER_WINDOW_EXPIRED", "ALREADY_USED", "MEMBER_LIMIT_REACHED", "BELOW_MIN_AMOUNT",
        "STACK_GROUP_TAKEN", "EXCLUSIVE_ALREADY_APPLIED", "OFFER_MEMBER_LIMIT", "OFFER_ITEMS_MISMATCH", "OFFER_WINDOW_CLOSED"
    ]

    init(offers: [Offer], promotions: [Promotion], tiers: [Tier]) {
        self.offers = offers
        self.promotions = promotions
        self.tiers = tiers
    }

    /// A failed read and a non-object payload both give the empty catalog.
    public init(envelope: G6Envelope) {
        guard envelope.ok, let data = envelope.data as? [String: Any] else { self = .empty; return }
        self.init(data: data)
    }

    public init(data: [String: Any]) {
        let serverNow = data["serverNow"]
        offers = (data["offers"] as? [Any] ?? []).compactMap { $0 as? [String: Any] }.compactMap { row in
            let name = row["name"] as? String ?? ""
            guard !name.isEmpty else { return nil }
            let available = Self.isTrue(row["available"])
            var save: String?
            if available, let difference = G6JSON.numeric(row["differenceAmount"]), difference > 0 { save = G6JSON.fixedTwo(difference) }
            let reason = available ? nil : (row["reasonCode"] as? String)
            return Offer(id: "offer-" + (Self.nonEmpty(row["offerCode"]) ?? name), name: name, available: available,
                         saveYuan: save, reasonCode: reason)
        }
        promotions = (data["promotions"] as? [Any] ?? []).compactMap { $0 as? [String: Any] }.compactMap { row in
            let name = row["name"] as? String ?? ""
            guard !name.isEmpty else { return nil }
            let eligible = Self.isTrue(row["eligible"])
            return Promotion(id: "promo-" + (Self.nonEmpty(row["promoCode"]) ?? name), name: name, eligible: eligible,
                             remain: eligible ? Self.remain(endsAt: row["windowEndsAt"], serverNow: serverNow) : nil,
                             reasonCode: eligible ? nil : (row["reasonCode"] as? String))
        }
        tiers = (data["tiers"] as? [Any] ?? []).compactMap { $0 as? [String: Any] }.compactMap { row in
            guard let price = G6JSON.numeric(row["unitPrice"]),
                  let range = Self.range(min: row["minQuantity"], max: row["maxQuantity"]) else { return nil }
            let code = Self.nonEmpty(row["tierCode"]) ?? G6JSON.text(row["id"]) ?? ""
            return Tier(id: "tier-" + code, range: range, unitPrice: G6JSON.fixedTwo(price))
        }
    }

    public static func remain(endsAt: Any?, serverNow: Any?) -> Remain? {
        guard let end = G6JSON.timestamp(endsAt), let now = G6JSON.timestamp(serverNow) else { return nil }
        let ms = Double(end - now)
        guard ms > 0 else { return nil }
        let hours = Int((ms / 3_600_000).rounded(.down))
        if hours >= 48 { return .days(hours / 24) }
        if hours >= 1 { return .hours(hours) }
        return .minutes(max(1, Int((ms / 60_000).rounded(.up))))
    }

    static func range(min: Any?, max: Any?) -> Range? {
        let low = G6JSON.numeric(min).flatMap { $0 != 0 ? Int(exactly: $0) : nil }
        let high = G6JSON.numeric(max).flatMap { $0 != 0 ? Int(exactly: $0) : nil }
        if let low, let high { return low == high ? .exact(low) : .span(low, high) }
        if let low { return .from(low) }
        return nil
    }

    private static func isTrue(_ value: Any?) -> Bool {
        guard let number = value as? NSNumber, CFGetTypeID(number as CFTypeRef) == CFBooleanGetTypeID() else { return false }
        return number.boolValue
    }

    private static func nonEmpty(_ value: Any?) -> String? {
        guard let text = value as? String, !text.isEmpty else { return nil }
        return text
    }
}

/// `subpackageA/utils/revenue-view.js`. Own author/referrer allocation lines, read only.
/// Positive lines and reversals are listed apart, never netted. A line without a readable amount is "pending", not 0.
public struct G6RevenueAllocations: Equatable, Sendable {
    public enum State: Equatable, Sendable {
        /// Not a participant, or no rows: the tab is not shown.
        case hidden
        case error
        case ready([Row])
    }

    public struct Line: Equatable, Sendable, Identifiable {
        public let id: String
        /// `author`, `referrer`, or nil for an unknown role.
        public let role: String?
        public let reversal: Bool
        /// Display text such as `¥12.30` / `−¥3.00`, or nil when the amount is unknown.
        public let amountText: String?
    }

    public struct Row: Equatable, Sendable, Identifiable {
        public let id: String
        /// 1 sign-up order, 2 pass order, nil other.
        public let orderType: Int?
        /// accrued, settleable, paid, partially_reversed, reversed, or unknown.
        public let status: String
        /// `yyyy.MM.dd` when status is accrued and a settleable date is known.
        public let settleableDay: String?
        public let lines: [Line]
    }

    public static let statuses: Set<String> = ["accrued", "settleable", "paid", "partially_reversed", "reversed", "unknown"]

    public static func state(_ envelope: G6Envelope) -> State {
        if envelope.netFail { return .error }
        if envelope.reasonCode == "NOT_PARTICIPANT" { return .hidden }
        guard envelope.ok, let rows = envelope.data as? [Any] else { return .error }
        let parsed = rows.compactMap { $0 as? [String: Any] }.compactMap(row)
        return parsed.isEmpty ? .hidden : .ready(parsed)
    }

    static func row(_ allocation: [String: Any]) -> Row? {
        guard let id = G6JSON.text(allocation["allocationId"]) else { return nil }
        let raw = allocation["statusText"] as? String ?? ""
        let status = statuses.contains(raw) ? raw : "unknown"
        let currency = allocation["currency"] as? String
        let lines = (allocation["lines"] as? [Any] ?? []).compactMap { $0 as? [String: Any] }
        var out: [Line] = []
        for (index, line) in lines.filter({ G6JSON.numeric($0["entryType"]) == 1 }).enumerated() {
            out.append(Line(id: "a\(index)", role: knownRole(line["role"]), reversal: false,
                            amountText: fen(line).map { yuan($0, currency: currency) }))
        }
        var order: [String] = []
        var groups: [String: (role: String?, fen: Int, unknown: Bool)] = [:]
        for line in lines where G6JSON.numeric(line["entryType"]) == 2 {
            let source = (line["sourceFact"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "refund"
            let role = line["role"] as? String
            let key = source + "|" + (role ?? "")
            if groups[key] == nil { order.append(key); groups[key] = (role: role, fen: 0, unknown: false) }
            if let value = fen(line) { groups[key]?.fen += value } else { groups[key]?.unknown = true }
        }
        for (index, key) in order.enumerated() {
            guard let group = groups[key] else { continue }
            out.append(Line(id: "r\(index)", role: knownRole(group.role), reversal: true,
                            amountText: group.unknown ? nil : yuan(-abs(group.fen), currency: currency)))
        }
        let orderType = G6JSON.integer(allocation["orderType"]).flatMap { [1, 2].contains($0) ? $0 : nil }
        return Row(id: id, orderType: orderType, status: status,
                   settleableDay: status == "accrued" ? G6JSON.dotDay(allocation["settleableAt"]) : nil, lines: out)
    }

    /// Integer `amountFen` first, then `amount` yuan rounded to fen. Nil when neither is readable.
    static func fen(_ line: [String: Any]) -> Int? {
        if let raw = line["amountFen"], !(raw is NSNull), !((raw as? String) == ""),
           let value = G6JSON.numeric(raw), value.rounded() == value, abs(value) <= 9_007_199_254_740_991 {
            return Int(value)
        }
        if let amount = G6JSON.numeric(line["amount"]) { return Int((amount * 100).rounded()) }
        return nil
    }

    static func yuan(_ fen: Int, currency: String?) -> String {
        let sign = fen < 0 ? "\u{2212}" : ""
        let prefix = (currency == nil || currency == "" || currency == "CNY") ? "¥" : (currency! + " ")
        let magnitude = abs(fen)
        return sign + prefix + String(magnitude / 100) + "." + String(format: "%02d", magnitude % 100)
    }

    private static func knownRole(_ value: Any?) -> String? {
        guard let role = value as? String, role == "author" || role == "referrer" else { return nil }
        return role
    }
}

/// `subpackageMember/market/pass/index.js` `load`: GET `/api/marketing/product/{id}` into the same card the list uses.
public enum G6MarketingProduct {
    public enum Outcome: Equatable, Sendable {
        case ready(PlatformPassProduct)
        /// A server reason code (`PRODUCT_NOT_FOUND`, ...) or nil for a plain failure.
        case failed(reasonCode: String?)
    }

    public static func outcome(_ envelope: G6Envelope) -> Outcome {
        guard envelope.ok, let data = envelope.data as? [String: Any], let product = PlatformPassProduct.decode(data) else {
            return .failed(reasonCode: envelope.netFail ? nil : envelope.reasonCode)
        }
        return .ready(product)
    }
}
