import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// US launch r1, lane app-pay; fix 11-28 (audit P0-3 / P1-3, branch fix/1128-us-pay).
// Every Stripe / Apple Pay wire detail the app relies on lives in this one file. The contract is the backend's
// `ApiStripePayController` (hengyin `us/r3-functional`, chengyinhub-admin/.../api/ApiStripePayController.java):
//   POST /api/pay/stripe/intent    intent(String id)
//   POST /api/pay/stripe/applepay  applePay(String id, String tokenId, String paymentData,
//                                           String transactionIdentifier, String paymentNetwork,
//                                           String paymentMethodDisplayName)
//   POST /api/pay/stripe/checkout  checkout(String id)
// None of them has `@RequestBody`: Spring binds form / query parameters, so the app sends
// `application/x-www-form-urlencoded` with `id` = the registration id (same shape as `/api/registration/pay/app`).
// The server takes amount and currency from the order and answers `amount` in MINOR units (cents,
// StripePaymentService.intentView / createCheckout: `amount = frozen.amountMinor`).
// The order is paid when the server says so: the confirm answer's `paymentStatus`, then the registration status
// read (`/api/registration/info`, the same read the China flow uses). A client-side result is never settlement.
// The China flow (WeChat / Alipay via /api/registration/pay[/app]) does not use anything in this file.

/// Paths of the US Stripe channel. Relative to `APIConfiguration.baseURL`.
public enum StripePayRoute: String, CaseIterable, Equatable, Sendable {
    case intent = "api/pay/stripe/intent"
    case applePay = "api/pay/stripe/applepay"
    case checkout = "api/pay/stripe/checkout"

    public var routePath: String { "/" + rawValue }
}

/// Wire constants pinned to the backend. Change them here only.
public enum StripePayWire {
    /// Quote / order `paymentChannels` values that mean the US Stripe channel is open for this order
    /// (RegistrationCheckoutServiceImpl.attachStripePaymentChannels: APPLE_PAY always, APP_STRIPE when Checkout is ready).
    public static let stripeChannel = "APP_STRIPE"
    public static let applePayChannel = "APPLE_PAY"
    /// The only currency this channel accepts (StripePaymentService.CURRENCY_USD). Any other currency stays on the China flow.
    public static let currency = "USD"
    /// Apple Pay merchant identifier (also in Config/Questify.entitlements `com.apple.developer.in-app-payments`).
    public static let merchantIdentifier = "merchant.com.chengyinhub.chengyinApp"
    public static let countryCode = "US"
    /// Hosts a Stripe Checkout URL may point at. Anything else is refused before Safari opens.
    public static let checkoutHosts: Set<String> = ["checkout.stripe.com"]
    /// `application/x-www-form-urlencoded`: the controller binds plain `String` parameters.
    public static let contentType = "application/x-www-form-urlencoded; charset=utf-8"
    /// Minor units per major unit for USD (cents).
    public static let minorPerMajor: Int64 = 100

    /// Parameter names of `ApiStripePayController`, exactly as the Java signatures spell them.
    public enum Field {
        /// Registration id (`Convert.toLong(id)`), every route.
        public static let id = "id"
        /// A Stripe `tok_…` token. The app never sends it: it sends the raw PassKit token instead (exactly one of the two).
        public static let tokenId = "tokenId"
        /// `PKPaymentToken.paymentData` as its UTF-8 JSON text (Stripe `pk_token`).
        public static let paymentData = "paymentData"
        /// `PKPaymentToken.transactionIdentifier` (Stripe `pk_token_transaction_id`).
        public static let transactionIdentifier = "transactionIdentifier"
        /// `PKPaymentMethod.network` raw value (Stripe `pk_token_payment_network`).
        public static let paymentNetwork = "paymentNetwork"
        /// `PKPaymentMethod.displayName` (Stripe `pk_token_instrument_name`).
        public static let paymentMethodDisplayName = "paymentMethodDisplayName"
    }

    /// `errorCode` values `StripePaymentService` puts next to `code` / `msg` (StripePayException).
    public enum ErrorCode {
        public static let declined = "PAYMENT_DECLINED"
        public static let outcomeUnknown = "PAYMENT_OUTCOME_UNKNOWN"
        public static let alreadyPaid = "ORDER_ALREADY_PAID"
        public static let expired = "ORDER_EXPIRED"
        public static let intentCanceled = "STRIPE_INTENT_CANCELED"
        public static let amountChanged = "ORDER_AMOUNT_CHANGED"
        public static let intentMismatch = "STRIPE_INTENT_MISMATCH"
        public static let currencyNotSupported = "CURRENCY_NOT_SUPPORTED"
    }

    /// `guarded(...)` answers `error("Please sign in")` (code 500) when the member token does not resolve.
    public static let signInMessage = "Please sign in"
}

/// Whether the US Stripe branch replaces the China pay button for this order.
/// Audit P1-3: the backend decides USD per topic (RegistrationCheckoutServiceImpl.isUsd → STRIPE_CHANNEL_REQUIRED 409 on
/// the China route), so the choice keys off the quote / order `currency` and `paymentChannels`, never the remembered
/// storefront market. A China-storefront player on a USD topic pays with Stripe; a US-storefront player on a CNY topic
/// pays with the China channels.
public enum StripePayEligibility {
    /// The order is a USD order: an explicit `currency == USD`, or (quote without currency) a channel list carrying the
    /// Stripe or Apple Pay channel, which the backend only exposes for USD orders.
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

    /// The US branch shows with the payment money switch on, for a USD order that lists at least one Stripe channel.
    /// Everything else keeps the China flow untouched.
    public static func applies(currency: String?, paymentChannels: [String]?) -> Bool {
        guard ReleaseMoneyWriteSwitch.paymentEnabled,
              isUSDOrder(currency: currency, paymentChannels: paymentChannels) else { return false }
        return offersApplePay(paymentChannels: paymentChannels) || offersCard(paymentChannels: paymentChannels)
    }

    /// The market whose pay channels this order uses: USD → `.unitedStates` (Stripe), anything else → `.china`
    /// (WeChat Pay / Alipay). Nil when there is no quote or order yet, so the caller may fall back for display only.
    public static func payMarket(currency: String?, paymentChannels: [String]?) -> RegionalMarket? {
        let hasCurrency = currency?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        guard hasCurrency || paymentChannels != nil else { return nil }
        return isUSDOrder(currency: currency, paymentChannels: paymentChannels) ? .unitedStates : .china
    }

    /// `/api/registration/payment-readiness` reports WeChat Pay only (`isPaymentReady() = wechatPayService.isReady()`).
    /// For a USD order the backend's own `paymentChannels` are the readiness (APPLE_PAY only when Stripe `isReady()`),
    /// so a WeChat outage never blocks a Stripe order and a Stripe outage never falls back to the China route (409).
    /// Nil for a non-USD order: keep the WeChat probe.
    public static func readiness(currency: String?, paymentChannels: [String]?) -> RegistrationPaymentReadiness? {
        guard isUSDOrder(currency: currency, paymentChannels: paymentChannels) else { return nil }
        let ready = offersApplePay(paymentChannels: paymentChannels) || offersCard(paymentChannels: paymentChannels)
        return RegistrationPaymentReadiness(ready: ready, message: nil)
    }

    /// P32: Apple Pay first when the device can pay and the order offers it, else Card. Empty when neither is offered.
    public static func methods(paymentChannels: [String]?, applePayAvailable: Bool) -> [RegistrationPayMethod] {
        var methods: [RegistrationPayMethod] = []
        if applePayAvailable, offersApplePay(paymentChannels: paymentChannels) { methods.append(.applePay) }
        if offersCard(paymentChannels: paymentChannels) { methods.append(.card) }
        return methods
    }
}

// MARK: Requests

/// A request body for `ApiStripePayController`: plain form fields.
public protocol StripePayFormBody: Sendable {
    var formFields: [String: String] { get }
}

/// Strict `application/x-www-form-urlencoded` encoding: RFC 3986 unreserved ASCII stays, everything else
/// (including `+`, `/`, `=` and `&` inside the PassKit JSON) is percent-encoded. Keys are sorted so the body is stable.
public enum StripePayForm {
    static let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    public static func encode(_ fields: [String: String]) -> String {
        fields.keys.sorted().map { key in
            escape(key) + "=" + escape(fields[key] ?? "")
        }.joined(separator: "&")
    }

    static func escape(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }
}

/// `POST /api/pay/stripe/intent` and `/checkout`: `id=<registrationId>`. No amount or currency: the server reads them from the order.
public struct StripeIntentRequest: StripePayFormBody, Equatable {
    public let registrationID: Int

    public init(registrationID: Int) throws {
        guard registrationID > 0 else { throw APIError.invalidRequest }
        self.registrationID = registrationID
    }

    public var formFields: [String: String] { [StripePayWire.Field.id: String(registrationID)] }
}

/// `POST /api/pay/stripe/applepay`: `id` plus the raw PassKit token (`paymentData`, `transactionIdentifier`,
/// `paymentNetwork`, `paymentMethodDisplayName`); the server turns it into a Stripe card token. `tokenId` is never sent
/// (the backend wants exactly one of the two). Transient: never persisted, logged, or shown.
public struct StripeApplePayConfirmRequest: StripePayFormBody, Equatable {
    public let registrationID: Int
    /// `PKPaymentToken.paymentData` as a UTF-8 JSON string.
    public let paymentData: String
    public let transactionIdentifier: String
    public let paymentNetwork: String?
    public let paymentMethodDisplayName: String?

    public init(intent: StripeIntentRequest, paymentData: Data, paymentMethodDisplayName: String?,
                paymentNetwork: String?, transactionIdentifier: String) throws {
        guard !paymentData.isEmpty, paymentData.count <= 64 * 1024,
              let text = String(data: paymentData, encoding: .utf8),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !transactionIdentifier.isEmpty else { throw APIError.invalidRequest }
        registrationID = intent.registrationID
        self.paymentData = text
        self.transactionIdentifier = transactionIdentifier
        self.paymentNetwork = StripePayDecoding.string(paymentNetwork)
        self.paymentMethodDisplayName = StripePayDecoding.string(paymentMethodDisplayName)
    }

    public var formFields: [String: String] {
        var fields = [
            StripePayWire.Field.id: String(registrationID),
            StripePayWire.Field.paymentData: paymentData,
            StripePayWire.Field.transactionIdentifier: transactionIdentifier
        ]
        if let paymentNetwork { fields[StripePayWire.Field.paymentNetwork] = paymentNetwork }
        if let paymentMethodDisplayName { fields[StripePayWire.Field.paymentMethodDisplayName] = paymentMethodDisplayName }
        return fields
    }
}

// MARK: Money

/// USD minor units (cents) from the backend, shown in major units.
public enum StripePayMoney {
    /// `amount` of the intent / checkout view: a positive whole number of cents. Fractions or non-positive values are malformed.
    public static func minorUnits(_ raw: Any?) -> Int64? {
        guard let value = StripePayDecoding.decimal(raw), value > .zero else { return nil }
        var source = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 0, .plain)
        guard rounded == value, rounded <= Decimal(Int64.max / 2) else { return nil }
        return NSDecimalNumber(decimal: rounded).int64Value
    }

    /// Cents → dollars (`2500` → `25`), exact decimal, for `PKPaymentSummaryItem` and labels.
    public static func major(fromMinor minor: Int64) -> Decimal {
        Decimal(minor) / Decimal(StripePayWire.minorPerMajor)
    }

    /// Dollars → cents, used to check the sheet amount against the order's payable amount.
    public static func minor(fromMajor major: Decimal) -> Int64? {
        var source = major * Decimal(StripePayWire.minorPerMajor)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 0, .plain)
        guard rounded == source else { return nil }
        return NSDecimalNumber(decimal: rounded).int64Value
    }
}

// MARK: Responses

/// `data` of `POST /api/pay/stripe/intent` (StripePaymentService.intentView). Amount is shown on the Apple Pay sheet
/// only; the server charges the order's own frozen amount whatever the sheet says. `clientSecret` and
/// `publishableKey` are not kept.
public struct StripeIntent: Equatable, Sendable {
    public let paymentIntentID: String?
    public let registrationID: Int?
    /// Backend `amount`: minor units (cents).
    public let amountMinor: Int64
    public let currency: String
    public let status: String?
    public let checkoutAvailable: Bool

    public init(paymentIntentID: String?, registrationID: Int? = nil, amountMinor: Int64, currency: String,
                status: String? = nil, checkoutAvailable: Bool = false) {
        self.paymentIntentID = paymentIntentID; self.registrationID = registrationID; self.amountMinor = amountMinor
        self.currency = currency; self.status = status; self.checkoutAvailable = checkoutAvailable
    }

    /// Major units (dollars) for the Apple Pay summary item and labels.
    public var amount: Decimal { StripePayMoney.major(fromMinor: amountMinor) }

    /// The intent already succeeded or is processing (a second confirm would be refused server-side).
    public var alreadySettling: Bool { ["succeeded", "processing"].contains(status?.lowercased() ?? "") }

    /// Accepts `amount` (cents, the backend field) or `amountMinor`; `paymentIntentId`, `registrationId`, `currency`,
    /// `status`, `checkoutAvailable`. A non-USD or non-positive / fractional amount is malformed for this channel.
    static func decode(_ data: [String: Any]) -> StripeIntent? {
        let currency = (StripePayDecoding.string(data["currency"]) ?? "").uppercased()
        guard currency == StripePayWire.currency,
              let minor = StripePayMoney.minorUnits(data["amount"] ?? data["amountMinor"]) else { return nil }
        return StripeIntent(paymentIntentID: StripePayDecoding.string(data["paymentIntentId"]),
                            registrationID: StripePayDecoding.int(data["registrationId"]),
                            amountMinor: minor, currency: currency,
                            status: StripePayDecoding.string(data["status"]),
                            checkoutAvailable: StripePayDecoding.bool(data["checkoutAvailable"]) ?? false)
    }
}

/// `data` of `POST /api/pay/stripe/checkout` (StripePaymentService.createCheckout).
public struct StripeCheckoutSession: Equatable, Sendable {
    public let url: URL
    public let amountMinor: Int64?

    static func decode(_ data: [String: Any]) -> StripeCheckoutSession? {
        let currency = StripePayDecoding.string(data["currency"])?.uppercased()
        guard currency == nil || currency == StripePayWire.currency,
              let url = StripePayDecoding.checkoutURL(data["checkoutUrl"] ?? data["url"]) else { return nil }
        return StripeCheckoutSession(url: url, amountMinor: StripePayMoney.minorUnits(data["amount"]))
    }
}

/// `data` of `POST /api/pay/stripe/applepay`: the intent view plus the order's `paymentStatus` / `registrationStatus`
/// read right after the server settled a succeeded intent.
public struct StripeConfirmResult: Equatable, Sendable {
    public let status: String
    public let paymentStatus: Int?
    public let registrationStatus: Int?

    public init(status: String, paymentStatus: Int? = nil, registrationStatus: Int? = nil) {
        self.status = status; self.paymentStatus = paymentStatus; self.registrationStatus = registrationStatus
    }

    /// Stripe accepted the token (the Apple Pay sheet may show success). Not settlement on its own.
    public var authorizedOrProcessing: Bool {
        ["succeeded", "processing", "requires_capture"].contains(status.lowercased())
    }

    /// The server marked the order paid in this same answer (`paymentStatus == 2`).
    public var serverMarkedPaid: Bool { RegistrationAppPayResolver.isPaid(paymentStatus) }

    static func decode(_ data: [String: Any]) -> StripeConfirmResult? {
        guard let status = StripePayDecoding.string(data["status"]) else { return nil }
        return StripeConfirmResult(status: status, paymentStatus: StripePayDecoding.int(data["paymentStatus"]),
                                   registrationStatus: StripePayDecoding.int(data["registrationStatus"]))
    }
}

public enum StripePayFailure: Error, Equatable, Sendable {
    /// Payment switch closed / not configured: nothing was sent.
    case closed
    /// No valid member token: nothing was sent.
    case signedOut
    case invalid
    /// `code != 200` with the server message (consent missing, order not found, Stripe unavailable…).
    case rejected(String?)
    /// `PAYMENT_DECLINED`: the card was declined; the player may try again.
    case declined(String?)
    /// `ORDER_ALREADY_PAID`: read the status back, it is most likely paid.
    case alreadyPaid
    /// `ORDER_EXPIRED` / `STRIPE_INTENT_CANCELED` / amount changed: the order must be rebuilt.
    case expired(String?)
    /// `PAYMENT_OUTCOME_UNKNOWN` or a transport failure after the request left: the charge may still land.
    case outcomeUnknown
    /// HTTP 401/403, `code == 401` or "Please sign in": the session is expired.
    case unauthorized
    case unknown
}

// MARK: Service

/// Single-shot HTTP calls for the US Stripe channel. Never retries; a timeout stays unknown and the
/// caller reconciles through the registration status read.
public enum StripePayService {
    public static func makeRequest(_ route: StripePayRoute, body: some StripePayFormBody,
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
        request.setValue(StripePayWire.contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.httpBody = Data(StripePayForm.encode(body.formFields).utf8)
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
        let result = await call(.applePay, body: body, configuration: configuration, transport: transport, token: token) {
            StripeConfirmResult.decode($0)
        }
        // The token left the device: an unreadable answer is an unknown outcome, never "not charged".
        if case .failure(.unknown) = result { return .failure(.outcomeUnknown) }
        return result
    }

    public static func checkout(_ body: StripeIntentRequest, configuration: APIConfiguration,
                                transport: any HTTPTransport, token: String) async -> Result<StripeCheckoutSession, StripePayFailure> {
        await call(.checkout, body: body, configuration: configuration, transport: transport, token: token) {
            StripeCheckoutSession.decode($0)
        }
    }

    static func call<Value>(_ route: StripePayRoute, body: some StripePayFormBody, configuration: APIConfiguration,
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
        let code = StripePayDecoding.int(object["code"])
        if code == 200 {
            guard let payload = object["data"] as? [String: Any], let value = decode(payload) else { return .failure(.unknown) }
            return .success(value)
        }
        return .failure(mapFailure(code: code, errorCode: StripePayDecoding.string(object["errorCode"]),
                                message: StripePayDecoding.string(object["msg"])))
    }

    /// Maps a `code != 200` envelope (`AjaxResult` with StripePayException `code` / `errorCode` / `msg`).
    static func mapFailure(code: Int?, errorCode: String?, message: String?) -> StripePayFailure {
        if code == 401 || message == StripePayWire.signInMessage { return .unauthorized }
        switch errorCode {
        case StripePayWire.ErrorCode.declined: return .declined(message)
        case StripePayWire.ErrorCode.outcomeUnknown: return .outcomeUnknown
        case StripePayWire.ErrorCode.alreadyPaid: return .alreadyPaid
        case StripePayWire.ErrorCode.expired, StripePayWire.ErrorCode.intentCanceled,
             StripePayWire.ErrorCode.amountChanged, StripePayWire.ErrorCode.intentMismatch:
            return .expired(message)
        default: return .rejected(message)
        }
    }
}

// MARK: Result after the provider

/// What the US pay rows show after Apple Pay or Stripe Checkout, mirroring the China rows (`RegistrationAppPayStage`):
/// paid (ticket in the wallet) / checking with Refresh / not completed with Pay again. Only a server value says paid.
public enum StripePayStage: Equatable, Sendable {
    case idle
    /// `paymentStatus == 2` from the server: the ticket is in the wallet.
    case paid
    /// The charge may have landed but the server has not said paid yet: "Checking payment…" with Refresh.
    case checking
    /// The server read says unpaid after the player came back (Checkout closed, or Apple Pay cancelled): Pay again.
    case notCompleted
}

public enum StripePayStageResolver {
    /// After the Apple Pay sheet sent a token. `confirm` is the applepay answer (nil if it never arrived), `paymentStatus`
    /// the registration status read that follows it. A token that left the device never maps to "not completed".
    public static func afterApplePay(confirm: StripeConfirmResult?, paymentStatus: Int?) -> StripePayStage {
        if RegistrationAppPayResolver.isPaid(paymentStatus) { return .paid }
        if paymentStatus == nil, confirm?.serverMarkedPaid == true { return .paid }
        return .checking
    }

    /// After Stripe Checkout (Safari) closed: one status read decides. Unpaid → the player can pay again;
    /// no answer → checking.
    public static func afterCheckout(paymentStatus: Int?) -> StripePayStage {
        guard let paymentStatus else { return .checking }
        return RegistrationAppPayResolver.isPaid(paymentStatus) ? .paid : .notCompleted
    }

    /// A manual Refresh: paid wins, otherwise stay checking.
    public static func refreshed(paymentStatus: Int?) -> StripePayStage {
        RegistrationAppPayResolver.isPaid(paymentStatus) ? .paid : .checking
    }
}

enum StripePayDecoding {
    static func string(_ raw: Any?) -> String? {
        guard let raw, !(raw is NSNull) else { return nil }
        let text = (raw as? String) ?? (raw as? NSNumber)?.stringValue
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    static func int(_ raw: Any?) -> Int? {
        guard let raw, !(raw is NSNull) else { return nil }
        if let value = raw as? Int { return value }
        if let number = raw as? NSNumber { return number.intValue }
        if let text = raw as? String { return Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return nil
    }

    static func bool(_ raw: Any?) -> Bool? {
        guard let raw, !(raw is NSNull) else { return nil }
        if let value = raw as? Bool { return value }
        if let number = raw as? NSNumber { return number.boolValue }
        if let text = raw as? String { return ["true", "1"].contains(text.lowercased()) }
        return nil
    }

    static func decimal(_ raw: Any?) -> Decimal? {
        guard let raw, !(raw is NSNull) else { return nil }
        if let value = raw as? Decimal { return value }
        if let value = raw as? Int { return Decimal(value) }
        if let value = raw as? Int64 { return Decimal(value) }
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
