import Foundation
import CoreFoundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Read-only platform pass and market client.
/// Source: hengyin `chengyinhub-xcx` `1c80c5aea8f721ca8575e6108048495b100f5576`
/// (`subpackageMember/utils/platform-pass.js`, `pass-library.js`, `market-view.js`,
/// `market/membership`, `market/library`, `market/passes`).
/// Purchase, quote, and gift claim are compiled on this type and always refuse.
/// Money stays off: this type does not build a payment body or call a pay route.
public struct PlatformPass: Sendable {
    public static let miniProgramCommit = "1c80c5aea8f721ca8575e6108048495b100f5576"
    public static let moneyEnabled = false

    public static let overviewPath = "api/platform-pass"
    public static let libraryPath = "api/platform-pass/library"
    public static let productListPath = "api/marketing/product/list"
    public static let ordersPath = "api/marketing/product/orders"
    public static let giftsBoughtPath = "api/marketing/product/gifts/bought"
    public static let giftsReceivedPath = "api/marketing/product/gifts/received"
    public static let pointsPath = "api/user/info"
    public static let purchasePath = "api/platform-pass/orders"
    public static let quotePath = "api/marketing/product/quote"
    public static let orderPath = "api/marketing/product/order"
    public static let claimPath = "api/marketing/product/gifts/claim"

    public static var writesReachable: Bool {
        moneyEnabled && ReleaseMoneyWriteSwitch.paymentEnabled && ReleaseMoneyWriteSwitch.payoutEnabled
            && ReleaseMoneyWriteSwitch.withdrawalEnabled && ReleaseMoneyWriteSwitch.virtualGoodsEnabled
    }

    private let configuration: APIConfiguration
    private let transport: any HTTPTransport

    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    /// GET `/api/platform-pass`. A merchant viewer returns before the request (membership page).
    public func overview(token: String, viewerIsMerchant: Bool) async throws -> PlatformPassOverview {
        if viewerIsMerchant { return .merchantBlocked }
        let data = try await get(Self.overviewPath, query: [], token: token)
        return try PlatformPassOverview.decode(data)
    }

    /// GET `/api/platform-pass/library`. `kind` is `all`, `city`, or `free`. Merchants do not read it.
    public func library(kind: String, token: String, viewerIsMerchant: Bool) async throws -> PlatformPassLibrary {
        if viewerIsMerchant { return .merchantBlocked }
        let query = try Self.libraryQuery(kind)
        let data = try await get(Self.libraryPath, query: query, token: token)
        return try PlatformPassLibrary.decode(data)
    }

    /// GET `/api/marketing/product/list?limit=20`.
    public func productList(token: String) async throws -> [PlatformPassProduct] {
        let data = try await get(Self.productListPath, query: [URLQueryItem(name: "limit", value: "20")], token: token)
        return try PlatformPassProduct.decodeList(data)
    }

    /// GET `/api/marketing/product/orders?limit=20`.
    public func orders(token: String) async throws -> [PlatformPassOrder] {
        let data = try await get(Self.ordersPath, query: [URLQueryItem(name: "limit", value: "20")], token: token)
        return try PlatformPassOrder.decodeList(data)
    }

    /// GET bought and received gift lists. Either failure fails the read; nothing is claimed.
    public func gifts(token: String) async throws -> PlatformPassGifts {
        let bought = try await get(Self.giftsBoughtPath, query: [URLQueryItem(name: "limit", value: "20")], token: token)
        let received = try await get(Self.giftsReceivedPath, query: [URLQueryItem(name: "limit", value: "20")], token: token)
        return try PlatformPassGifts.decode(bought: bought, received: received)
    }

    /// POST `/api/user/info` and read `point`. Missing or non-numeric stays nil, never 0.
    public func points(token: String) async throws -> Double? {
        let object = try await send(Self.pointsPath, method: "POST", query: [], token: token)
        guard let data = PlatformPassJSON.dictionary(PlatformPassJSON.dataValue(object)) else { return nil }
        return PlatformPassJSON.number(data["point"])
    }

    /// Platform-pass purchase. Compiled, never sends.
    public func purchase(planCode: String, channel: String, token: String) throws -> Never {
        _ = (planCode, channel, token, Self.moneyEnabled, Self.writesReachable, Self.purchasePath)
        throw PlatformPassWriteRefusal.unreachable
    }

    /// Marketing quote. Compiled, never sends.
    public func quote(productID: String, token: String) throws -> Never {
        _ = (productID, token, Self.moneyEnabled, Self.writesReachable, Self.quotePath)
        throw PlatformPassWriteRefusal.unreachable
    }

    /// Marketing order. Compiled, never sends.
    public func order(productID: String, token: String) throws -> Never {
        _ = (productID, token, Self.moneyEnabled, Self.writesReachable, Self.orderPath)
        throw PlatformPassWriteRefusal.unreachable
    }

    /// Gift claim. Compiled, never sends.
    public func claim(giftToken: String, requestID: String, token: String) throws -> Never {
        _ = (giftToken, requestID, token, Self.moneyEnabled, Self.writesReachable, Self.claimPath)
        throw PlatformPassWriteRefusal.unreachable
    }

    private static func libraryQuery(_ kind: String) throws -> [URLQueryItem] {
        var query = [URLQueryItem(name: "limit", value: "100")]
        switch kind {
        case "all": break
        case "city": query.append(URLQueryItem(name: "productType", value: "1"))
        case "free": query.append(URLQueryItem(name: "productType", value: "2"))
        default: throw APIError.invalidRequest
        }
        return query
    }

    private func get(_ path: String, query: [URLQueryItem], token: String) async throws -> Any {
        let object = try await send(path, method: "GET", query: query, token: token)
        guard let data = PlatformPassJSON.dataValue(object) else { throw APIError.malformedResponse }
        return data
    }

    private func send(_ path: String, method: String, query: [URLQueryItem], token: String) async throws -> [String: Any] {
        guard AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        var request = URLRequest(url: try url(path, query: query))
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.httpShouldHandleCookies = false
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (bytes, status) = try await transport.send(request)
        if status == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(status) else { throw APIError.httpStatus(status) }
        let object = try PlatformPassJSON.object(bytes)
        guard PlatformPassJSON.isBizOK(object) else { throw APIError.businessCode(PlatformPassJSON.code(object["code"]) ?? -1) }
        return object
    }

    private func url(_ path: String, query: [URLQueryItem]) throws -> URL {
        let built = path.split(separator: "/").reduce(configuration.baseURL) { partial, part in
            partial.appendingPathComponent(String(part))
        }
        guard !query.isEmpty else { return built }
        var parts = URLComponents(url: built, resolvingAgainstBaseURL: false)
        parts?.queryItems = query
        guard let url = parts?.url else { throw APIError.invalidRequest }
        return url
    }
}

public enum PlatformPassWriteRefusal: Error, Equatable, Sendable {
    case unreachable
}

public struct PlatformPassPlan: Equatable, Sendable {
    public let code: String
    public let title: String
    public let priceFen: Int
    public let validDays: Int?

    public init(code: String, title: String, priceFen: Int, validDays: Int?) {
        self.code = code
        self.title = title
        self.priceFen = priceFen
        self.validDays = validDays
    }
}

public struct PlatformPassHolding: Equatable, Sendable {
    public let active: Bool
    public let validTo: String?
    public let coverageEnd: String?

    public init(active: Bool, validTo: String?, coverageEnd: String?) {
        self.active = active
        self.validTo = validTo
        self.coverageEnd = coverageEnd
    }
}

public struct PlatformPassOverview: Equatable, Sendable {
    public let enabled: Bool
    public let merchantBlocked: Bool
    public let libraryCount: Int?
    public let plans: [PlatformPassPlan]
    public let holding: PlatformPassHolding
    public let jsapiAvailable: Bool
    public let xpayAvailable: Bool

    public static let merchantBlocked = PlatformPassOverview(
        enabled: false, merchantBlocked: true, libraryCount: nil, plans: [],
        holding: PlatformPassHolding(active: false, validTo: nil, coverageEnd: nil),
        jsapiAvailable: false, xpayAvailable: false)

    public init(enabled: Bool, merchantBlocked: Bool, libraryCount: Int?, plans: [PlatformPassPlan],
                holding: PlatformPassHolding, jsapiAvailable: Bool, xpayAvailable: Bool) {
        self.enabled = enabled
        self.merchantBlocked = merchantBlocked
        self.libraryCount = libraryCount
        self.plans = plans
        self.holding = holding
        self.jsapiAvailable = jsapiAvailable
        self.xpayAvailable = xpayAvailable
    }

    static func decode(_ data: Any) throws -> PlatformPassOverview {
        guard let object = PlatformPassJSON.dictionary(data) else { throw APIError.malformedResponse }
        let plans = PlatformPassJSON.array(object["plans"]).compactMap { row -> PlatformPassPlan? in
            guard let code = PlatformPassJSON.text(row["planCode"]), let price = PlatformPassJSON.int(row["priceFen"]) else { return nil }
            return PlatformPassPlan(code: code, title: PlatformPassJSON.text(row["title"]) ?? "", priceFen: price,
                                    validDays: PlatformPassJSON.int(row["validDays"]))
        }
        let holding = PlatformPassJSON.dictionary(object["holding"]) ?? [:]
        let channels = PlatformPassJSON.dictionary(object["channels"]) ?? [:]
        return PlatformPassOverview(
            enabled: PlatformPassJSON.flag(object["enabled"]),
            merchantBlocked: false,
            libraryCount: PlatformPassJSON.int(object["libraryCount"]),
            plans: plans,
            holding: PlatformPassHolding(active: PlatformPassJSON.flag(holding["active"]),
                                         validTo: PlatformPassJSON.text(holding["validTo"]),
                                         coverageEnd: PlatformPassJSON.text(holding["coverageEnd"])),
            jsapiAvailable: PlatformPassJSON.flag(PlatformPassJSON.dictionary(channels["jsapi"])?["available"]),
            xpayAvailable: PlatformPassJSON.flag(PlatformPassJSON.dictionary(channels["xpay"])?["available"]))
    }
}

public struct PlatformPassLibraryCard: Equatable, Sendable {
    public let id: String
    public let title: String
    public let cover: String
    public let city: String
    public let kind: String
    public let data: String
    public let free: Bool
    public let tags: [String]
    /// Server `productType`: 1 city orienteering, 2 free explore. Nil when the row omitted it.
    public let productType: Int?
    /// Whole minutes from `totalTime` seconds. Nil when the duration is missing; never a stand-in 0.
    public let minuteCount: Int?
}

public struct PlatformPassLibrary: Equatable, Sendable {
    public let enabled: Bool
    public let covered: Bool
    public let merchantBlocked: Bool
    public let cards: [PlatformPassLibraryCard]

    public static let merchantBlocked = PlatformPassLibrary(enabled: false, covered: false, merchantBlocked: true, cards: [])

    static func decode(_ data: Any) throws -> PlatformPassLibrary {
        guard let object = PlatformPassJSON.dictionary(data) else { throw APIError.malformedResponse }
        let enabled = PlatformPassJSON.flag(object["enabled"])
        let covered = PlatformPassJSON.flag(object["covered"])
        guard enabled else { return PlatformPassLibrary(enabled: false, covered: false, merchantBlocked: false, cards: []) }
        let cards = PlatformPassJSON.array(object["rows"]).compactMap { PlatformPassLibraryCard.make($0, covered: covered) }
        return PlatformPassLibrary(enabled: true, covered: covered, merchantBlocked: false, cards: cards)
    }
}

extension PlatformPassLibraryCard {
    static func make(_ row: [String: Any], covered: Bool) -> PlatformPassLibraryCard? {
        guard let id = PlatformPassJSON.text(row["topicId"]), let name = PlatformPassJSON.text(row["name"]) else { return nil }
        let productType = PlatformPassJSON.int(row["productType"])
        let kind = Self.kind(productType)
        let city = PlatformPassJSON.text(row["addressName"]) ?? ""
        let minuteCount = Self.minuteCount(PlatformPassJSON.number(row["totalTime"]))
        let minutes = minuteCount.map { "约 \($0) 分钟" } ?? ""
        return PlatformPassLibraryCard(
            id: id, title: name, cover: PlatformPassJSON.text(row["imgUrl"]) ?? "", city: city, kind: kind,
            data: [kind, minutes].filter { !$0.isEmpty }.joined(separator: " · "),
            free: covered, tags: [kind, city].filter { !$0.isEmpty },
            productType: productType, minuteCount: minuteCount)
    }

    private static func kind(_ productType: Int?) -> String {
        switch productType {
        case 1: return "城市定向"
        case 2: return "自由探索"
        default: return ""
        }
    }

    private static func minuteCount(_ seconds: Double?) -> Int? {
        guard let seconds, seconds > 0 else { return nil }
        return max(1, Int((seconds / 60).rounded()))
    }
}

public struct PlatformPassProduct: Equatable, Sendable {
    public let id: String
    public let name: String
    public let kind: String
    public let city: String
    public let validity: String
    public let seats: String
    public let price: String
    public let coverCount: Int
    public let topics: [String]
    public let topicIDs: [String]
    public let giftOnly: Bool
    public let isExtraSeat: Bool
    public let cashPrice: Double?
    public let pointsPrice: Double?
    public let productKind: Int
    public let validityKind: Int?
    public let validDays: Int?

    public init(id: String, name: String, kind: String, city: String, validity: String, seats: String, price: String,
                coverCount: Int, topics: [String], topicIDs: [String], giftOnly: Bool, isExtraSeat: Bool,
                cashPrice: Double?, pointsPrice: Double?, productKind: Int, validityKind: Int?, validDays: Int?) {
        self.id = id
        self.name = name
        self.kind = kind
        self.city = city
        self.validity = validity
        self.seats = seats
        self.price = price
        self.coverCount = coverCount
        self.topics = topics
        self.topicIDs = topicIDs
        self.giftOnly = giftOnly
        self.isExtraSeat = isExtraSeat
        self.cashPrice = cashPrice
        self.pointsPrice = pointsPrice
        self.productKind = productKind
        self.validityKind = validityKind
        self.validDays = validDays
    }

    static func decodeList(_ data: Any) throws -> [PlatformPassProduct] {
        guard let rows = PlatformPassJSON.rows(data) else { throw APIError.malformedResponse }
        return rows.compactMap { PlatformPassJSON.dictionary($0).flatMap(decode) }
    }

    static func decode(_ row: [String: Any]) -> PlatformPassProduct? {
        guard let id = PlatformPassJSON.text(row["productId"]) else { return nil }
        let items = PlatformPassJSON.array(row["items"])
        let kind = PlatformPassJSON.int(row["productKind"]) ?? 0
        let route = PlatformPassJSON.int(row["purchaseRoute"]) ?? 0
        let seats = PlatformPassJSON.int(row["seatCount"])
        return PlatformPassProduct(
            id: id,
            name: PlatformPassJSON.text(row["productName"]) ?? "",
            kind: Self.kindText(kind),
            city: PlatformPassJSON.text(row["saleCity"]) ?? "",
            validity: Self.validity(row),
            seats: (seats ?? 0) > 1 ? "\(seats ?? 0) 人" : "",
            price: Self.price(cash: PlatformPassJSON.number(row["cashPrice"]), points: PlatformPassJSON.number(row["pointsPrice"])),
            coverCount: items.count,
            topics: items.compactMap { PlatformPassJSON.text($0["topicTitle"]) },
            topicIDs: items.compactMap { PlatformPassJSON.text($0["topicId"]) },
            giftOnly: kind == 7,
            isExtraSeat: kind == 8 || route == 3,
            cashPrice: PlatformPassJSON.number(row["cashPrice"]),
            pointsPrice: PlatformPassJSON.number(row["pointsPrice"]),
            productKind: kind,
            validityKind: PlatformPassJSON.int(row["validityKind"]),
            validDays: PlatformPassJSON.int(row["validDays"]))
    }

    private static func kindText(_ kind: Int) -> String {
        switch kind {
        case 1: return "单关票"
        case 2: return "城市包"
        case 3: return "时限通票"
        case 4: return "固定期年卡"
        case 5: return "团体票"
        case 6: return "学校团体票"
        case 7: return "礼品通行证"
        case 8: return "加座"
        default: return ""
        }
    }

    private static func validity(_ row: [String: Any]) -> String {
        switch PlatformPassJSON.int(row["validityKind"]) {
        case 1:
            guard let days = PlatformPassJSON.int(row["validDays"]) else { return "" }
            return "购买后 \(days) 天内有效"
        case 2:
            let from = MPParityChinaClock.dotDay(PlatformPassJSON.text(row["fixedValidFrom"]))
            let to = MPParityChinaClock.dotDay(PlatformPassJSON.text(row["fixedValidTo"]))
            if !from.isEmpty, !to.isEmpty { return "\(from) – \(to)" }
            return to.isEmpty ? "" : "有效至 \(to)"
        case 3:
            guard let days = PlatformPassJSON.int(row["validDays"]) else { return "" }
            return "首次游玩起 \(days) 天内有效"
        default:
            return ""
        }
    }

    private static func price(cash: Double?, points: Double?) -> String {
        var parts: [String] = []
        if let cash { parts.append("¥" + Self.fixed(cash)) }
        if let points { parts.append(Self.plain(points) + " 积分") }
        return parts.joined(separator: " / ")
    }

    private static func fixed(_ value: Double) -> String { PlatformPassNumber.fixed(value) }
    private static func plain(_ value: Double) -> String { PlatformPassNumber.plain(value) }
}

public struct PlatformPassOrder: Equatable, Sendable {
    public let orderNo: String
    public let productID: String
    public let state: String
    public let amount: String
    public let time: String

    public func row(nameByID: [String: String]) -> PlatformPassOrderRow {
        PlatformPassOrderRow(key: orderNo, name: nameByID[productID] ?? "通行证订单", state: state, amount: amount, time: time)
    }

    static func decodeList(_ data: Any) throws -> [PlatformPassOrder] {
        guard let rows = PlatformPassJSON.rows(data) else { throw APIError.malformedResponse }
        return rows.compactMap { PlatformPassJSON.dictionary($0).flatMap(decode) }
    }

    static func decode(_ row: [String: Any]) -> PlatformPassOrder? {
        guard let orderNo = PlatformPassJSON.text(row["orderNo"]) else { return nil }
        let payMode = PlatformPassJSON.int(row["payMode"]) ?? 0
        let amount: String
        if payMode == 2 {
            amount = PlatformPassJSON.number(row["pointsAmount"]).map { Self.plain($0) + " 积分" } ?? ""
        } else {
            amount = PlatformPassJSON.number(row["cashAmount"]).map { "¥" + Self.fixed($0) } ?? ""
        }
        let when = PlatformPassJSON.text(row["paidAt"]) ?? PlatformPassJSON.text(row["createdAt"])
        return PlatformPassOrder(orderNo: orderNo, productID: PlatformPassJSON.text(row["productId"]) ?? "",
                                 state: Self.state(row), amount: amount, time: MPParityChinaClock.dotDay(when))
    }

    private static func state(_ row: [String: Any]) -> String {
        switch PlatformPassJSON.text(row["statusLabel"]) {
        case "PAID":
            if PlatformPassJSON.int(row["fulfillmentState"]) == 2 { return "已购买 · 首次游玩时开始计算有效期" }
            if PlatformPassJSON.int(row["fulfillmentKind"]) == 2 { return "已购买 · 礼品" }
            return "已购买"
        case "PENDING_CASH":
            return "待支付"
        case "CANCELLED":
            return "已取消"
        case "REFUNDED":
            return "已退款"
        default:
            return "状态待确认"
        }
    }

    private static func fixed(_ value: Double) -> String { PlatformPassNumber.fixed(value) }
    private static func plain(_ value: Double) -> String { PlatformPassNumber.plain(value) }
}

enum PlatformPassNumber {
    static func fixed(_ value: Double) -> String {
        let cents = Int((value * 100).rounded())
        let whole = abs(cents) / 100
        let frac = abs(cents) % 100
        return "\(cents < 0 ? "-" : "")\(whole).\(frac < 10 ? "0" : "")\(frac)"
    }

    static func plain(_ value: Double) -> String {
        if value.rounded() == value { return String(Int(value.rounded())) }
        return fixed(value)
    }
}

public struct PlatformPassOrderRow: Equatable, Sendable {
    public let key: String
    public let name: String
    public let state: String
    public let amount: String
    public let time: String
}

public struct PlatformPassGift: Equatable, Sendable {
    public let key: String
    public let state: String
    public let expires: String
    public let time: String
    public let claimReachable: Bool
    /// Claim deadline as `yyyy.MM.dd`, or empty when this gift has no deadline. The sentence stays in `expires`.
    public let claimDay: String

    static func decodeList(_ data: Any, side: String) throws -> [PlatformPassGift] {
        guard let rows = PlatformPassJSON.rows(data) else { throw APIError.malformedResponse }
        return rows.compactMap { PlatformPassJSON.dictionary($0).flatMap { decode($0, side: side) } }
    }

    static func decode(_ row: [String: Any], side: String) -> PlatformPassGift? {
        guard let id = PlatformPassJSON.text(row["giftId"]) else { return nil }
        let status = PlatformPassJSON.int(row["status"])
        var state: String
        switch status {
        case 0: state = "待领取"
        case 1: state = "已领取"
        case 2: state = "已过期"
        case 3: state = "已撤销"
        default: state = "状态待确认"
        }
        if side == "bought", status == 0 { state = "待领取 · 领取前你和对方都不能游玩" }
        if side == "bought", status == 3 { state = "已撤销 · 退回给你" }
        let claimDay = status == 0 ? MPParityChinaClock.dotDay(PlatformPassJSON.text(row["claimExpiresAt"])) : ""
        let when = PlatformPassJSON.text(row["claimedAt"]) ?? PlatformPassJSON.text(row["createdAt"])
        return PlatformPassGift(key: side + "-" + id, state: state,
                                expires: claimDay.isEmpty ? "" : "领取截止 \(claimDay)",
                                time: MPParityChinaClock.dotDay(when), claimReachable: false, claimDay: claimDay)
    }
}

public struct PlatformPassGifts: Equatable, Sendable {
    public let bought: [PlatformPassGift]
    public let received: [PlatformPassGift]
    public let claimReachable: Bool

    static func decode(bought: Any, received: Any) throws -> PlatformPassGifts {
        PlatformPassGifts(bought: try PlatformPassGift.decodeList(bought, side: "bought"),
                          received: try PlatformPassGift.decodeList(received, side: "received"),
                          claimReachable: false)
    }
}

enum PlatformPassJSON {
    static func object(_ data: Data) throws -> [String: Any] {
        let value = try JSONSerialization.jsonObject(with: data)
        guard let object = value as? [String: Any] else { throw APIError.malformedResponse }
        return object
    }

    static func isBizOK(_ object: [String: Any]) -> Bool { code(object["code"]) == 200 }

    static func code(_ value: Any?) -> Int? {
        if value is Bool || value is NSNull { return nil }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return nil }
            let int = number.intValue
            guard number.doubleValue == Double(int) else { return nil }
            return int
        }
        if let text = value as? String { return Int(text) }
        return nil
    }

    static func dataValue(_ object: [String: Any]) -> Any? {
        let value = object["data"]
        if value == nil || value is NSNull { return nil }
        return value
    }

    static func flag(_ value: Any?) -> Bool {
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() { return number.boolValue }
        return false
    }

    static func number(_ value: Any?) -> Double? {
        if value == nil || value is NSNull || value is Bool { return nil }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return nil }
            let double = number.doubleValue
            return double.isFinite ? double : nil
        }
        if let text = value as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let double = Double(trimmed), double.isFinite else { return nil }
            return double
        }
        return nil
    }

    static func int(_ value: Any?) -> Int? {
        guard let double = number(value), double.rounded() == double, double <= Double(Int.max), double >= Double(Int.min) else { return nil }
        return Int(double)
    }

    static func text(_ value: Any?) -> String? {
        if let text = value as? String { return text.isEmpty ? nil : text }
        if let int = int(value) { return String(int) }
        return nil
    }

    static func rows(_ value: Any?) -> [Any]? {
        if let list = value as? [Any] { return list }
        if let list = value as? NSArray { return list.map { $0 } }
        return nil
    }

    static func array(_ value: Any?) -> [[String: Any]] {
        (rows(value) ?? []).compactMap { $0 as? [String: Any] }
    }

    static func dictionary(_ value: Any?) -> [String: Any]? {
        if let object = value as? [String: Any] { return object }
        guard let object = value as? NSDictionary else { return nil }
        var result: [String: Any] = [:]
        for (key, item) in object {
            guard let key = key as? String else { return nil }
            result[key] = item
        }
        return result
    }
}

/// China civil clock for pass dates. Midnight rolls back one millisecond for the "playable through" day,
/// matching `order-status.js` `passUntilText`. Unknown input is empty, never today.
enum MPParityChinaClock {
    static func dotDay(_ raw: String?) -> String {
        guard let ms = MoneyParityTime.timestamp(raw) else { return "" }
        let parts = clock(ms)
        return String(format: "%04d.%02d.%02d", parts.year, parts.month, parts.day)
    }

    /// Mini-program sentence. The App shows the same day through a localized string.
    static func passUntil(_ raw: String?) -> String {
        guard let shown = shown(raw) else { return "" }
        return "可玩至 \(shown.month) 月 \(shown.day) 日"
    }

    static func shownMonthDay(_ raw: String?) -> (month: Int, day: Int)? {
        guard let shown = shown(raw) else { return nil }
        return (shown.month, shown.day)
    }

    private static func shown(_ raw: String?) -> (year: Int, month: Int, day: Int, hour: Int, minute: Int)? {
        guard let ms = MoneyParityTime.timestamp(raw) else { return nil }
        let parts = clock(ms)
        if parts.hour == 0, parts.minute == 0, ms % 60_000 == 0 { return clock(ms - 1) }
        return parts
    }

    private static func clock(_ ms: Int64) -> (year: Int, month: Int, day: Int, hour: Int, minute: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        let date = Date(timeIntervalSince1970: TimeInterval(ms + MoneyParityTime.chinaOffsetMs) / 1000)
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return (parts.year ?? 0, parts.month ?? 0, parts.day ?? 0, parts.hour ?? 0, parts.minute ?? 0)
    }
}
