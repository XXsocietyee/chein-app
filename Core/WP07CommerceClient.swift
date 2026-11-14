import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// HANDOVER 36, WP-07. Group and school quotes, coupon usability, and the two writes that stay closed.
/// A quote total is the nested registration `payAmount`. Catalog cash is not a price.
/// `couponDeductYuan` on the usability screen stays 0: holding a coupon does not reduce a registration.
/// Create and activate do not collect a card. A real charge for a digital good stays on StoreKit.
public struct WP07CommerceClient {
    public static let quotePath = "api/marketing/group-checkout/quote"
    public static let createPath = "api/marketing/group-checkout/create"
    public static let activatePath = "api/marketing/product/activate"
    public static let usabilityPath = "api/coupon/usability"
    /// Merchant redemption does not deduct the registration. This stays 0.
    public static let couponDeductYuan = Decimal.zero

    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    private let token: String
    private let apiHost: String?
    /// The App's purchase gate (`MPCommerceGate` and `ReviewedAreaSwitch.moneyPayments(host:)`); Core cannot see those types.
    private let writesOpen: @Sendable () -> Bool

    public init(configuration: APIConfiguration, transport: any HTTPTransport, token: String, apiHost: String?,
                writesOpen: @escaping @Sendable () -> Bool = { false }) {
        self.configuration = configuration
        self.transport = transport
        self.token = token
        self.apiHost = apiHost
        self.writesOpen = writesOpen
    }

    /// POST `/api/marketing/group-checkout/quote`. The body is product id and quantity. No amount.
    public func quote(productID: Int, quantity: Int = 1) async throws -> GroupCheckoutDisplay {
        guard productID > 0, (1...100).contains(quantity), AuthRequestBuilder.isValidToken(token) else {
            throw APIError.invalidRequest
        }
        let body = try JSONSerialization.data(withJSONObject: ["productId": productID, "quantity": quantity], options: [.sortedKeys])
        let data = try await post(Self.quotePath, body: body, contentType: "application/json")
        return try GroupCheckoutDisplay.decode(data)
    }

    /// POST `/api/coupon/usability`. Read-only. The registration deduction stays 0.
    public func usability() async throws -> [CouponUsabilityRow] {
        guard AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        let data = try await post(Self.usabilityPath, body: nil, contentType: nil)
        return try CouponUsabilityRow.decodeList(data)
    }

    /// Group/school create. Stays behind the commerce gate and the money switch. Does not charge a card.
    public func create(productID: Int) throws -> Never {
        _ = (productID, Self.createPath, token, apiHost, commerceWritesOpen)
        throw WP07CommerceRefusal.closed
    }

    /// First-play activation. Stays behind the same gate. Does not charge a card.
    public func activate(topicID: Int) throws -> Never {
        _ = (topicID, Self.activatePath, token, apiHost, commerceWritesOpen)
        throw WP07CommerceRefusal.closed
    }

    /// True only when purchases are on and this host is not www.chengyinhub.com. Still not a card charge.
    public var commerceWritesOpen: Bool {
        writesOpen()
    }

    private func post(_ path: String, body: Data?, contentType: String?) async throws -> Data {
        var request = URLRequest(url: path.split(separator: "/").reduce(configuration.baseURL) { $0.appendingPathComponent(String($1)) })
        request.httpMethod = "POST"
        request.httpBody = body
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.httpShouldHandleCookies = false
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let contentType { request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        let (bytes, status) = try await transport.send(request)
        if status == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(status) else { throw APIError.httpStatus(status) }
        let object = try JSONSerialization.jsonObject(with: bytes) as? [String: Any]
        guard let object, PlatformPassJSON.isBizOK(object) else {
            throw APIError.businessCode(PlatformPassJSON.code((try? JSONSerialization.jsonObject(with: bytes) as? [String: Any])?["code"]) ?? -1)
        }
        guard let data = PlatformPassJSON.dataValue(object) else { throw APIError.malformedResponse }
        let encoded = try JSONSerialization.data(withJSONObject: data)
        return encoded
    }
}

public enum WP07CommerceRefusal: Error, Equatable, Sendable {
    case closed
}

/// Server quote for a group or school product. `totalText` is `quote.payAmount`. Nil is unknown.
public struct GroupCheckoutDisplay: Equatable, Sendable {
    public let productName: String?
    public let productKind: Int?
    public let tierLabel: String?
    public let totalText: String?
    public let activityID: String?
    public let ticketID: String?

    public var isEmpty: Bool {
        productName == nil && productKind == nil && tierLabel == nil && totalText == nil
    }

    public init(productName: String?, productKind: Int?, tierLabel: String?, totalText: String?, activityID: String?, ticketID: String?) {
        self.productName = productName
        self.productKind = productKind
        self.tierLabel = tierLabel
        self.totalText = totalText
        self.activityID = activityID
        self.ticketID = ticketID
    }

    static func decode(_ data: Data) throws -> GroupCheckoutDisplay {
        let value = try JSONSerialization.jsonObject(with: data)
        guard let object = value as? [String: Any] else { throw APIError.malformedResponse }
        let name = Self.trimmed(object["productName"])
        let kind = Self.whole(object["productKind"])
        let quote = object["quote"] as? [String: Any]
        let tier = quote.flatMap(Self.tierLabel)
        let total = try quote.map(Self.totalText)
        if name == nil, kind == nil, tier == nil, total == nil {
            return GroupCheckoutDisplay(productName: nil, productKind: nil, tierLabel: nil, totalText: nil, activityID: nil, ticketID: nil)
        }
        return GroupCheckoutDisplay(
            productName: name,
            productKind: kind,
            tierLabel: tier,
            totalText: total ?? nil,
            activityID: Self.identifier(object["activityId"]),
            ticketID: Self.identifier(object["ticketId"]))
    }

    /// Tier label from `quote.marketingAdjustments` where `kind` is the server tier. No local tier.
    static func tierLabel(_ quote: [String: Any]) -> String? {
        let rows = quote["marketingAdjustments"] as? [[String: Any]] ?? []
        let labels = rows.compactMap { row -> String? in
            guard let kind = row["kind"] as? String, kind.lowercased().contains("tier") else { return nil }
            return trimmed(row["label"])
        }
        guard !labels.isEmpty else { return nil }
        return labels.joined(separator: " · ")
    }

    /// `payAmount` only. Catalog cash is ignored even when the payload carries it.
    static func totalText(_ quote: [String: Any]) throws -> String? {
        let encoded = try JSONSerialization.data(withJSONObject: quote)
        let decoded = try JSONDecoder().decode(RegistrationQuote.self, from: encoded)
        guard let amount = decoded.payAmount else { return nil }
        return NSDecimalNumber(decimal: amount).stringValue
    }

    private static func trimmed(_ value: Any?) -> String? {
        guard let text = value as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func whole(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let int = number.intValue
        guard number.doubleValue == Double(int) else { return nil }
        return int
    }

    private static func identifier(_ value: Any?) -> String? {
        guard let whole = whole(value), whole > 0 else { return nil }
        return String(whole)
    }
}

/// One held coupon from `/api/coupon/usability`. Read-only. It does not change `couponDeductYuan`.
public struct CouponUsabilityRow: Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String?
    public let usable: Bool
    public let reason: String?
    /// Face amount when the server sent one. Not a registration deduction.
    public let faceText: String?

    public static let knownReasons: Set<String> = ["AVAILABLE", "USED", "EXPIRED", "DISABLED", "NOT_STARTED", "COUPON_MISSING"]

    static func decodeList(_ data: Data) throws -> [CouponUsabilityRow] {
        let value = try JSONSerialization.jsonObject(with: data)
        guard let rows = value as? [[String: Any]] else { throw APIError.malformedResponse }
        return try rows.compactMap { row in
            guard let history = GroupCheckoutDisplay.wholeNumber(row["historyId"]), history > 0 else { return nil }
            let face = try Self.face(row["amount"])
            return CouponUsabilityRow(
                id: String(history),
                name: Self.trimmed(row["name"]),
                usable: (row["usable"] as? Bool) == true || ((row["usable"] as? NSNumber).map { CFGetTypeID($0) == CFBooleanGetTypeID() && $0.boolValue } ?? false),
                reason: Self.trimmed(row["reason"]),
                faceText: face)
        }
    }

    private static func trimmed(_ value: Any?) -> String? {
        guard let text = value as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func face(_ value: Any?) throws -> String? {
        if value == nil || value is NSNull { return nil }
        let encoded = try JSONSerialization.data(withJSONObject: ["amount": value as Any])
        struct Box: Decodable { let amount: Decimal? }
        return try JSONDecoder().decode(Box.self, from: encoded).amount.map { NSDecimalNumber(decimal: $0).stringValue }
    }
}

extension GroupCheckoutDisplay {
    static func wholeNumber(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let int = number.intValue
        guard number.doubleValue == Double(int), int > 0 || number.intValue == 0 else { return nil }
        return int
    }
}
