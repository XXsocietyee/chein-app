import Foundation

/// R7-PC-C2-1: quote `delivery` (包含内容), MP pages/activity/utils/quote-view.js:20-71 (`deliveryRows`).
/// Decoded leniently: a malformed key is dropped, never fails the quote.
public struct RegistrationQuoteDelivery: Decodable, Equatable {
    public let purchaseKind: Int?
    public let ticketName: String?
    public let teamSize: Int?
    public let minPeople: Int?
    public let maxPeople: Int?
    /// MP `delivery.needAudit === 1` (quote-view.js:41); `true` is accepted too.
    public let needAudit: Bool
    public let serviceStartAt: Date?
    public let serviceEndAt: Date?
    public let beneficiaryKind: String?
    public let refundRule: String?

    private enum CodingKeys: String, CodingKey {
        case purchaseKind, ticketName, teamSize, minPeople, maxPeople, needAudit
        case serviceStartAt, serviceEndAt, beneficiaryKind, refundRule
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        purchaseKind = RegistrationLenient.int(c, .purchaseKind)
        ticketName = RegistrationLenient.string(c, .ticketName)
        teamSize = RegistrationLenient.int(c, .teamSize)
        minPeople = RegistrationLenient.int(c, .minPeople)
        maxPeople = RegistrationLenient.int(c, .maxPeople)
        if let flag = (try? c.decodeIfPresent(Bool.self, forKey: .needAudit)) ?? nil {
            needAudit = flag
        } else {
            needAudit = RegistrationLenient.int(c, .needAudit) == 1
        }
        serviceStartAt = RegistrationLenient.date(c, .serviceStartAt)
        serviceEndAt = RegistrationLenient.date(c, .serviceEndAt)
        beneficiaryKind = RegistrationLenient.string(c, .beneficiaryKind)
        refundRule = RegistrationLenient.string(c, .refundRule)
    }

    /// Port of `deliveryRows` (quote-view.js:29-51). Row ids: kind/perTicket/people/audit/window/beneficiary/refundRule.
    public func rows(locale: Locale) -> [ActivityDeliveryItem] {
        let zh = locale.language.languageCode?.identifier == "zh"
        func t(_ cn: String, _ en: String) -> String { zh ? cn : en }
        var rows: [ActivityDeliveryItem] = []
        // quote-view.js:21 PURCHASE_KIND_TEXT {1: 场次票, 2: 场次票, 3: 自由探索票}
        switch purchaseKind {
        case 1?, 2?: rows.append(.init(id: "kind", label: t("票种类型", "Ticket type"), value: t("场次票", "Session ticket")))
        case 3?: rows.append(.init(id: "kind", label: t("票种类型", "Ticket type"), value: t("自由探索票", "Free-explore ticket")))
        default: break
        }
        let perTicket = (ticketName ?? "").isEmpty
        if perTicket {
            rows.append(.init(id: "perTicket", label: t("包含内容", "Includes"), value: t("按票种分别说明", "Described per ticket type")))
        } else {
            if let people = peopleText(zh: zh) { rows.append(.init(id: "people", label: t("人数", "People"), value: people)) }
            if needAudit { rows.append(.init(id: "audit", label: t("报名审核", "Review"), value: t("需主办方审核", "Host review required"))) }
        }
        if let window = windowText(zh: zh) { rows.append(.init(id: "window", label: t("服务时间", "Service time"), value: window)) }
        if beneficiaryKind == "PAYER_SELF" {
            rows.append(.init(id: "beneficiary", label: t("使用人", "User"), value: t("付款人本人", "The payer")))
        }
        if !perTicket, let refundRule, !refundRule.isEmpty {
            rows.append(.init(id: "refundRule", label: t("退款", "Refund"), value: refundRule))
        }
        return rows
    }

    /// quote-view.js:53-62 `peopleText`.
    func peopleText(zh: Bool) -> String? {
        let min = minPeople.flatMap { $0 > 0 ? $0 : nil }
        let max = maxPeople.flatMap { $0 > 0 ? $0 : nil }
        let team = teamSize.flatMap { $0 > 0 ? $0 : nil }
        let unit = zh ? " 人" : " people"
        if let min, let max { return min == max ? "\(min)\(unit)" : "\(min)–\(max)\(unit)" }
        if let team { return zh ? "\(team) 人一队" : "Teams of \(team)" }
        if let max { return zh ? "最多 \(max) 人" : "Up to \(max) people" }
        if let min { return zh ? "\(min) 人起" : "From \(min) people" }
        return nil
    }

    /// quote-view.js:64-70 `serviceWindowText`, `formatMinuteDots` in China time (utils/datetime.js:118-121).
    func windowText(zh: Bool) -> String? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        f.dateFormat = "yyyy.MM.dd HH:mm"
        switch (serviceStartAt, serviceEndAt) {
        case let (start?, end?): return f.string(from: start) + " – " + f.string(from: end)
        case let (start?, nil): return f.string(from: start) + (zh ? " 起" : " onward")
        case let (nil, end?): return (zh ? "至 " : "Until ") + f.string(from: end)
        default: return nil
        }
    }
}

/// Lenient field readers shared by the quote extras. Never throw.
enum RegistrationLenient {
    static func int<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Int? {
        if let value = (try? c.decodeIfPresent(Int.self, forKey: key)) ?? nil { return value }
        if let text = (try? c.decodeIfPresent(String.self, forKey: key)) ?? nil { return Int(text.trimmingCharacters(in: .whitespaces)) }
        return nil
    }
    static func string<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> String? {
        guard let text = (try? c.decodeIfPresent(String.self, forKey: key)) ?? nil else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    static func decimal<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Decimal? {
        if let value = (try? c.decodeIfPresent(Decimal.self, forKey: key)) ?? nil { return value }
        if let text = (try? c.decodeIfPresent(String.self, forKey: key)) ?? nil {
            return Decimal(string: text.trimmingCharacters(in: .whitespaces), locale: Locale(identifier: "en_US_POSIX"))
        }
        return nil
    }
    /// utils/datetime.js:68-92 `toTimestamp`: 10 digits = seconds, 13 = ms, ISO with offset, else China wall time.
    static func date<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Date? {
        if let number = (try? c.decodeIfPresent(Double.self, forKey: key)) ?? nil {
            guard number.isFinite, number > 0 else { return nil }
            let seconds = (number.rounded() == number && String(Int64(number)).count == 10) ? number : number / 1000
            return Date(timeIntervalSince1970: seconds)
        }
        guard let raw = (try? c.decodeIfPresent(String.self, forKey: key)) ?? nil else { return nil }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return nil }
        if text.count == 10, let s = Double(text), text.allSatisfy(\.isNumber) { return Date(timeIntervalSince1970: s) }
        if text.count == 13, let ms = Double(text), text.allSatisfy(\.isNumber) { return Date(timeIntervalSince1970: ms / 1000) }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: text) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: text) { return date }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy/MM/dd HH:mm:ss", "yyyy-MM-dd"] {
            f.dateFormat = format
            if let date = f.date(from: text) { return date }
        }
        return nil
    }
}
