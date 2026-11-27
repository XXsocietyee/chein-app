import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// US launch r1, lane app-pay. Every Stripe / Apple Pay wire detail the app relies on lives in this one file
// so it can be adjusted to the backend lane's contract (hengyin `us/r1-backend`, docs/receipts/us-r1-backend.md)
// without touching the UI. Endpoints follow docs/briefs/us-launch-r1.md (lane be-us):
//   POST /api/pay/stripe/intent    create (or reuse) the PaymentIntent for an existing order. Server takes the
//                                  amount and currency from the order, never from the client.
//   POST /api/pay/stripe/applepay  confirm the PaymentIntent with an Apple Pay token.
//   POST /api/pay/stripe/checkout  optional Stripe Checkout session URL (card fallback).
// The webhook marks the order paid; the app never treats a client-side result as settlement and always
// reconciles through the existing order-status poll (`OrderPaymentVerifier`).
// The China flow (WeChat / Alipay via /api/registration/pay[/app]) does not use anything in this file.

/// Paths of the US Stripe channel. Relative to `APIConfiguration.baseURL`.
public enum StripePayRoute: String, CaseIterable, Equatable, Sendable {
    case intent = "api/pay/stripe/intent"
    case applePay = "api/pay/stripe/applepay"
    case checkout = "api/pay/stripe/checkout"

    public var routePath: String { "/" + rawValue }
}

/// Wire constants the backend lane may rename. Change them here only.
public enum StripePayWire {
    /// Quote `paymentChannels` values that mean the US Stripe channel is open for this order.
    public static let stripeChannel = "APP_STRIPE"
    public static let applePayChannel = "APPLE_PAY"
    /// The only currency this channel accepts. Any other currency stays on the China flow.
    public static let currency = "USD"
    /// Apple Pay merchant identifier (also in Config/Questify.entitlements `com.apple.developer.in-app-payments`).
    public static let merchantIdentifier = "merchant.com.chengyinhub.chengyinApp"
    public static let countryCode = "US"
    /// Business type sent with every request so the server can find the order table.
    public static let registrationBizType = "REGISTRATION"
    /// Hosts a Stripe Checkout URL may point at. Anything else is refused before Safari opens.
    public static let checkoutHosts: Set<String> = ["checkout.stripe.com"]
}

/// Whether the US branch replaces the China pay button for this order.
public enum StripePayEligibility {
    /// The order is a USD order: an explicit `currency == USD`, or (old quote without currency) a channel list
    /// carrying the Stripe or Apple Pay channel, which the backend only exposes for USD quotes.
    public static func isUSDOrder(currency: String?, paymentChannels: [String]?) -> Bool {
        if let currency = currency?.trimmingCharacters(in: .whitespacesAndNewlines), !currency.isEmpty {
            return currency.uppercased() == StripePayWire.currency
        }
        guard let paymentChannels else { return false }
        return paymentChannels.contains(StripePayWire.stripeChannel) || paymentChannels.contains(StripePayWire.applePayChannel)
    }

    public static func offersApplePay(paymentChannels: [String]?) -> Bool {
        paymentChannels?.contains(StripePayWire.applePayChannel) == true
    }

    public static func offersCard(paymentChannels: [String]?) -> Bool {
        paymentChannels?.contains(StripePayWire.stripeChannel) == true
    }

    /// The US branch shows only in the US market, with the payment money switch on, for a USD order
    /// that lists at least one Stripe channel. Everything else keeps the China flow untouched.
    public static func applies(market: RegionalMarket?, currency: String?, paymentChannels: [String]?) -> Bool {
        guard market == .unitedStates, ReleaseMoneyWriteSwitch.paymentEnabled,
              isUSDOrder(currency: currency, paymentChannels: paymentChannels) else { return false }
        return offersApplePay(paymentChannels: paymentChannels) || offersCard(paymentChannels: paymentChannels)
    }
}

// MARK: Requests

/// `POST /api/pay/stripe/intent` and `/checkout` body. No amount or currency: the server reads them from the order.
public struct StripeIntentRequest: Encodable, Equatable, Sendable {
    public let registrationID: Int
    public let orderNo: String?
    public let bizType: String

    public init(registrationID: Int, orderNo: String? = nil, bizType: String = StripePayWire.registrationBizType) throws {
        guard registrationID > 0 else { throw APIError.invalidRequest }
        let trimmed = orderNo?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.registrationID = registrationID
        self.orderNo = (trimmed?.isEmpty == false) ? trimmed : nil
        self.bizType = bizType
    }

    private enum CodingKeys: String, CodingKey { case registrationId, orderNo, bizType }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(registrationID, forKey: .registrationId)
        try c.encodeIfPresent(orderNo, forKey: .orderNo)
        try c.encode(bizType, forKey: .bizType)
    }
}

/// `POST /api/pay/stripe/applepay` body. Field names follow Stripe's Apple Pay token parameters (`pk_token*`)
/// so the server can create the Stripe token (`POST /v1/tokens`) and confirm with
/// `payment_method_data[card][token]`. Transient: never persisted, logged, or shown.
public struct StripeApplePayConfirmRequest: Encodable, Sendable {
    public let registrationID: Int
    public let orderNo: String?
    public let paymentIntentID: String?
    public let bizType: String
    /// `PKPaymentToken.paymentData` as a UTF-8 JSON string (Stripe `pk_token`).
    public let pkToken: String
    /// Same bytes, base64. Kept so the server can pick either form.
    public let pkTokenBase64: String
    public let pkTokenInstrumentName: String?
    public let pkTokenPaymentNetwork: String?
    public let pkTokenTransactionID: String

    public init(intent: StripeIntentRequest, paymentIntentID: String?, paymentData: Data,
                instrumentName: String?, paymentNetwork: String?, transactionIdentifier: String) throws {
        guard !paymentData.isEmpty, paymentData.count <= 64 * 1024,
              let text = String(data: paymentData, encoding: .utf8), !text.isEmpty,
              !transactionIdentifier.isEmpty else { throw APIError.invalidRequest }
        registrationID = intent.registrationID
        orderNo = intent.orderNo
        bizType = intent.bizType
        self.paymentIntentID = paymentIntentID?.isEmpty == false ? paymentIntentID : nil
        pkToken = text
        pkTokenBase64 = paymentData.base64EncodedString()
        pkTokenInstrumentName = instrumentName
        pkTokenPaymentNetwork = paymentNetwork
        pkTokenTransactionID = transactionIdentifier
    }

    private enum CodingKeys: String, CodingKey {
        case registrationId, orderNo, paymentIntentId, bizType
        case pkToken, pkTokenBase64, pkTokenInstrumentName, pkTokenPaymentNetwork, pkTokenTransactionId
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(registrationID, forKey: .registrationId)
        try c.encodeIfPresent(orderNo, forKey: .orderNo)
        try c.encodeIfPresent(paymentIntentID, forKey: .paymentIntentId)
        try c.encode(bizType, forKey: .bizType)
        try c.encode(pkToken, forKey: .pkToken)
        try c.encode(pkTokenBase64, forKey: .pkTokenBase64)
        try c.encodeIfPresent(pkTokenInstrumentName, forKey: .pkTokenInstrumentName)
        try c.encodeIfPresent(pkTokenPaymentNetwork, forKey: .pkTokenPaymentNetwork)
        try c.encode(pkTokenTransactionID, forKey: .pkTokenTransactionId)
    }
}

// MARK: Responses

/// `data` of `POST /api/pay/stripe/intent`. Amount is shown on the Apple Pay sheet only; the server charges
/// the order's own amount whatever the sheet says.
public struct StripeIntent: Equatable, Sendable {
    public let paymentIntentID: String?
    public let orderNo: String?
    /// Major units (dollars). Derived from `amountMinor` (Stripe cents) when the server sends that.
    public let amount: Decimal
    public let currency: String
    public let status: String?
    public let checkoutURL: URL?

    public init(paymentIntentID: String?, orderNo: String?, amount: Decimal, currency: String,
                status: String? = nil, checkoutURL: URL? = nil) {
        self.paymentIntentID = paymentIntentID; self.orderNo = orderNo; self.amount = amount
        self.currency = currency; self.status = status; self.checkoutURL = checkoutURL
    }

    /// Accepts `paymentIntentId`/`id`, `amount` (major) or `amountMinor`/`amountCents` (minor), `currency`,
    /// `status`, `checkoutUrl`/`url`. A non-USD or non-positive amount is malformed for this channel.
    static func decode(_ data: [String: Any]) -> StripeIntent? {
        let currency = (StripePayDecoding.string(data["currency"]) ?? "").uppercased()
        guard currency == StripePayWire.currency else { return nil }
        let amount: Decimal?
        if let minor = StripePayDecoding.decimal(data["amountMinor"]) ?? StripePayDecoding.decimal(data["amountCents"]) {
            amount = minor / 100
        } else {
            amount = StripePayDecoding.decimal(data["amount"])
        }
        guard let amount, amount > .zero else { return nil }
        return StripeIntent(paymentIntentID: StripePayDecoding.string(data["paymentIntentId"]) ?? StripePayDecoding.string(data["id"]),
                            orderNo: StripePayDecoding.string(data["orderNo"]),
                            amount: amount, currency: currency,
                            status: StripePayDecoding.string(data["status"]),
                            checkoutURL: StripePayDecoding.checkoutURL(data["checkoutUrl"] ?? data["url"]))
    }
}

/// `data` of `POST /api/pay/stripe/applepay`. A success here only ends the Apple Pay sheet;
/// the order is paid when the webhook says so and the order-status poll observes it.
public struct StripeConfirmResult: Equatable, Sendable {
    public let status: String
    public var authorizedOrProcessing: Bool {
        ["succeeded", "processing", "requires_capture", "paid"].contains(status.lowercased())
    }
}

public enum StripePayFailure: Error, Equatable, Sendable {
    case closed
    case signedOut
    case invalid
    case rejected(String?)
    case unauthorized
    case unknown
}

// MARK: Service

/// Single-shot HTTP calls for the US Stripe channel. Never retries; a timeout stays unknown and the
/// caller reconciles through the order-status poll.
public enum StripePayService {
    public static func makeRequest<Body: Encodable>(_ route: StripePayRoute, body: Body,
                                                    configuration: APIConfiguration, token: String) throws -> URLRequest {
        guard ReleaseMoneyWriteSwitch.paymentEnabled, !ReleaseMoneyWriteSwitch.blocks(route.routePath) else {
            throw APIError.notConfigured
        }
        guard AuthRequestBuilder.isValidToken(token) else { throw APIError.unauthorized }
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent(route.rawValue))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        request.httpBody = try encoder.encode(body)
        return request
    }

    public static func createIntent(_ body: StripeIntentRequest, configuration: APIConfiguration,
                                    transport: any HTTPTransport, token: String) async -> Result<StripeIntent, StripePayFailure> {
        await call(.intent, body: body, configuration: configuration, transport: transport, token: token) {
            StripeIntent.decode($0)
        }
    }

    public static func confirmApplePay(_ body: StripeApplePayConfirmRequest, configuration: APIConfiguration,
                                       transport: any HTTPTransport, token: String) async -> Result<StripeConfirmResult, StripePayFailure> {
        await call(.applePay, body: body, configuration: configuration, transport: transport, token: token) {
            StripePayDecoding.string($0["status"]).map(StripeConfirmResult.init(status:))
        }
    }

    public static func checkoutURL(_ body: StripeIntentRequest, configuration: APIConfiguration,
                                   transport: any HTTPTransport, token: String) async -> Result<URL, StripePayFailure> {
        await call(.checkout, body: body, configuration: configuration, transport: transport, token: token) {
            StripePayDecoding.checkoutURL($0["url"] ?? $0["checkoutUrl"])
        }
    }

    static func call<Body: Encodable, Value>(_ route: StripePayRoute, body: Body, configuration: APIConfiguration,
                                             transport: any HTTPTransport, token: String,
                                             decode: ([String: Any]) -> Value?) async -> Result<Value, StripePayFailure> {
        let request: URLRequest
        do {
            request = try makeRequest(route, body: body, configuration: configuration, token: token)
        } catch let error as APIError where error == .unauthorized {
            return .failure(.signedOut)
        } catch let error as APIError where error == .notConfigured {
            return .failure(.closed)
        } catch {
            return .failure(.invalid)
        }
        let data: Data, status: Int
        do {
            (data, status) = try await transport.send(request)
        } catch let error as APIError where error == .unauthorized {
            return .failure(.unauthorized)
        } catch {
            return .failure(.unknown)
        }
        if status == 401 || status == 403 { return .failure(.unauthorized) }
        guard (200..<300).contains(status),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return .failure(.unknown) }
        let code = (object["code"] as? Int) ?? (object["code"] as? String).flatMap(Int.init)
        let message = (object["msg"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if code == 401 { return .failure(.unauthorized) }
        guard code == 200 else { return .failure(.rejected(message?.isEmpty == false ? message : nil)) }
        guard let payload = object["data"] as? [String: Any], let value = decode(payload) else { return .failure(.unknown) }
        return .success(value)
    }
}

enum StripePayDecoding {
    static func string(_ raw: Any?) -> String? {
        guard let raw, !(raw is NSNull) else { return nil }
        let text = (raw as? String) ?? (raw as? NSNumber)?.stringValue
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    static func decimal(_ raw: Any?) -> Decimal? {
        guard let raw, !(raw is NSNull) else { return nil }
        if let number = raw as? NSNumber { return number.decimalValue }
        if let text = raw as? String {
            return Decimal(string: text.trimmingCharacters(in: .whitespacesAndNewlines), locale: Locale(identifier: "en_US_POSIX"))
        }
        return nil
    }

    /// Only an https URL on a Stripe Checkout host opens in Safari.
    static func checkoutURL(_ raw: Any?) -> URL? {
        guard let text = string(raw), let url = URL(string: text), url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased(), StripePayWire.checkoutHosts.contains(host) else { return nil }
        return url
    }
}
