import Foundation

/// fix-1128-alipay (audit P0-4): Alipay app payment for a CNY registration, beside WeChat Pay.
/// Backend `us/r3-functional` `ApiAlipayPayController`: `POST /api/pay/alipay/order` (form `id`, member token)
/// returns `data.orderString` for the Alipay SDK; `POST /api/pay/alipay/query` (form `id`) returns
/// `data.paid` / `paymentStatus` / `registrationStatus` / `tradeStatus` and settles a paid trade whose notify was
/// lost. Failures carry a top-level `errorCode` (ALIPAY_NOT_CONFIGURED, ORDER_ALREADY_PAID, ORDER_EXPIRED, …).
/// The quote lists the `APP_ALIPAY` channel only while the backend is configured.
public enum AlipayAppPayRoute: String, CaseIterable, Sendable {
    case order = "api/pay/alipay/order"
    case query = "api/pay/alipay/query"

    public var routePath: String { "/" + rawValue }
}

/// The quote / order channel name the backend lists when Alipay app pay is configured.
public enum AlipayAppPayChannel {
    public static let quoteChannel = "APP_ALIPAY"

    /// Alipay is offered only when the backend lists `APP_ALIPAY` for this order and the app can hand the
    /// order string to Alipay. A missing channel list (older backend) never offers it.
    public static func offered(paymentChannels: [String]?, providerReady: Bool) -> Bool {
        guard providerReady, let paymentChannels else { return false }
        return paymentChannels.contains(where: { $0.uppercased() == quoteChannel })
    }
}

/// `data` of a successful `/api/pay/alipay/order`. The order string is transient: never persisted or shown.
public struct AlipayAppPayOrder: Equatable, Sendable {
    public let registrationID: Int
    public let registrationNo: String?
    public let orderString: String

    public init(registrationID: Int, registrationNo: String?, orderString: String) {
        self.registrationID = registrationID
        self.registrationNo = registrationNo
        self.orderString = orderString
    }

    /// The parameters `AlipaySDKPaymentAdapter.pay(registrationID:parameters:)` reads.
    public var adapterParameters: [String: String] { ["orderString": orderString] }
}

public enum AlipayAppPayOrderOutcome: Equatable, Sendable {
    case order(AlipayAppPayOrder)
    /// `ORDER_ALREADY_PAID`: read the result instead of paying twice.
    case alreadyPaid
    /// `ORDER_EXPIRED` (410): the player rebuilds the order.
    case expired(message: String?)
    /// `ALIPAY_NOT_CONFIGURED` / `ALIPAY_UNAVAILABLE`: offer WeChat Pay instead.
    case unavailable(message: String?)
    /// Any other refusal (currency, nothing to pay, consent, amount changed…), with the server copy.
    case rejected(errorCode: String?, message: String?)
    case unauthorized
    /// Transport failure or an unreadable answer. Nothing was opened.
    case unknown
}

/// `data` of `/api/pay/alipay/query`.
public struct AlipayAppPayQueryResult: Equatable, Sendable {
    public let paid: Bool
    public let paymentStatus: Int?
    public let registrationStatus: Int?
    /// Alipay `trade_status` when the server asked Alipay (WAIT_BUYER_PAY, TRADE_CLOSED, NOT_EXIST, UNKNOWN…).
    public let tradeStatus: String?

    public init(paid: Bool, paymentStatus: Int?, registrationStatus: Int?, tradeStatus: String?) {
        self.paid = paid
        self.paymentStatus = paymentStatus
        self.registrationStatus = registrationStatus
        self.tradeStatus = tradeStatus
    }

    /// Paid when the server says so, or the registration shows `paymentStatus == 2` (same gate as WeChat).
    public var isPaid: Bool { paid || RegistrationAppPayResolver.isPaid(paymentStatus) }

    /// Alipay has no payable trade for this order: the player left before paying.
    public var buyerDidNotPay: Bool {
        guard !isPaid, let tradeStatus else { return false }
        return ["NOT_EXIST", "TRADE_CLOSED"].contains(tradeStatus.uppercased())
    }
}

public enum AlipayAppPayService {
    public static func makeRequest(_ route: AlipayAppPayRoute, configuration: APIConfiguration,
                                   token: String, registrationID: Int) throws -> URLRequest {
        guard !ReleaseMoneyWriteSwitch.blocks(route.routePath) else { throw APIError.notConfigured }
        guard AuthRequestBuilder.isValidToken(token) else { throw APIError.unauthorized }
        guard registrationID > 0 else { throw APIError.invalidRequest }
        var request = try AuthRequestBuilder.makeFormRequest(
            url: configuration.baseURL.appendingPathComponent(route.rawValue),
            fields: ["id": String(registrationID)],
            token: token
        )
        request.timeoutInterval = 20
        return request
    }

    private static func envelope(_ data: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func int(_ value: Any?) -> Int? {
        if let number = value as? Int { return number }
        if let text = value as? String { return Int(text) }
        return nil
    }

    private static func text(_ value: Any?) -> String? {
        guard let raw = value as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public static func decodeOrder(_ data: Data, status: Int, registrationID: Int) -> AlipayAppPayOrderOutcome {
        if status == 401 { return .unauthorized }
        guard (200..<300).contains(status), let object = envelope(data) else { return .unknown }
        let code = int(object["code"])
        let message = text(object["msg"])
        guard code == 200 else {
            if code == 401 { return .unauthorized }
            let errorCode = text(object["errorCode"])
            switch errorCode ?? "" {
            case "ORDER_ALREADY_PAID": return .alreadyPaid
            case "ORDER_EXPIRED": return .expired(message: message)
            case "ALIPAY_NOT_CONFIGURED", "ALIPAY_UNAVAILABLE": return .unavailable(message: message)
            default: return .rejected(errorCode: errorCode, message: message)
            }
        }
        let payload = object["data"] as? [String: Any] ?? [:]
        guard let orderString = text(payload["orderString"]), orderString.utf8.count <= 8192,
              !orderString.contains("\n") else { return .unknown }
        let decodedID = int(payload["registrationId"]) ?? registrationID
        guard decodedID == registrationID else { return .unknown }
        return .order(AlipayAppPayOrder(registrationID: registrationID,
                                        registrationNo: text(payload["registrationNo"]),
                                        orderString: orderString))
    }

    /// Nil when the read failed or was refused; the player keeps "Checking payment…" with Refresh.
    public static func decodeQuery(_ data: Data, status: Int, registrationID: Int) -> AlipayAppPayQueryResult? {
        guard (200..<300).contains(status), let object = envelope(data), int(object["code"]) == 200,
              let payload = object["data"] as? [String: Any] else { return nil }
        if let decodedID = int(payload["registrationId"]), decodedID != registrationID { return nil }
        return AlipayAppPayQueryResult(paid: (payload["paid"] as? Bool) ?? false,
                                       paymentStatus: int(payload["paymentStatus"]),
                                       registrationStatus: int(payload["registrationStatus"]),
                                       tradeStatus: text(payload["tradeStatus"]))
    }

    /// One `order` call. Never retried automatically.
    public static func createOrder(configuration: APIConfiguration, transport: any HTTPTransport,
                                   token: String, registrationID: Int) async -> AlipayAppPayOrderOutcome {
        guard ReleaseMoneyWriteSwitch.isEnabled(.payment) else { return .unavailable(message: nil) }
        let request: URLRequest
        do {
            request = try makeRequest(.order, configuration: configuration, token: token, registrationID: registrationID)
        } catch APIError.unauthorized {
            return .unauthorized
        } catch {
            return .unavailable(message: nil)
        }
        guard let response = try? await transport.send(request) else { return .unknown }
        return decodeOrder(response.0, status: response.1, registrationID: registrationID)
    }

    /// One `query` read (the app's confirmation after Alipay returns, and the Refresh button).
    public static func query(configuration: APIConfiguration, transport: any HTTPTransport,
                             token: String, registrationID: Int) async -> AlipayAppPayQueryResult? {
        guard let request = try? makeRequest(.query, configuration: configuration, token: token,
                                             registrationID: registrationID),
              let response = try? await transport.send(request) else { return nil }
        return decodeQuery(response.0, status: response.1, registrationID: registrationID)
    }
}

/// What the pay step shows on the Alipay path. Same result states as WeChat Pay (`RegistrationAppPayStage`):
/// paid → ticket in the wallet; cancelled → Pay again; unknown → Checking payment… + Refresh.
public enum RegistrationAlipayStage: Equatable, Sendable {
    /// Ready: the "Pay ¥x with Alipay" button.
    case ready
    /// `POST /api/pay/alipay/order` in flight.
    case requestingOrder
    /// Alipay is open (or the player has not come back yet).
    case launching
    case paid
    case cancelled
    case checking
    /// Alipay could not be opened (not installed, not configured, or the backend has Alipay off).
    case alipayUnavailable(message: String?)
    /// The order expired: rebuild it.
    case expired(message: String?)
    case rejected(message: String?)
    case signedOut
}

public enum RegistrationAlipayResolver {
    /// After Alipay answers: the one `query` read decides (paid wins whatever Alipay said).
    public static func stage(providerReturn: TopicSelfPlayProviderReturn, query: AlipayAppPayQueryResult?) -> RegistrationAlipayStage {
        if query?.isPaid == true { return .paid }
        switch providerReturn {
        case .cancelled, .failed: return .cancelled
        case .returned: return .checking
        case .unknown: return query?.buyerDidNotPay == true ? .cancelled : .checking
        }
    }

    /// A manual Refresh: paid wins; otherwise keep "Checking payment…".
    public static func refreshed(query: AlipayAppPayQueryResult?) -> RegistrationAlipayStage {
        query?.isPaid == true ? .paid : .checking
    }

    /// The stage for an order answer that did not open Alipay. `nil` means open Alipay with the order.
    public static func stage(orderOutcome: AlipayAppPayOrderOutcome) -> RegistrationAlipayStage? {
        switch orderOutcome {
        case .order: return nil
        case .alreadyPaid: return .checking
        case .expired(let message): return .expired(message: message)
        case .unavailable(let message): return .alipayUnavailable(message: message)
        case .rejected(_, let message): return .rejected(message: message)
        case .unauthorized: return .signedOut
        case .unknown: return .checking
        }
    }

    /// The pay button is live in these stages.
    public static func canPay(_ stage: RegistrationAlipayStage) -> Bool {
        switch stage {
        case .ready, .cancelled, .rejected: return true
        case .requestingOrder, .launching, .paid, .checking, .alipayUnavailable, .expired, .signedOut: return false
        }
    }
}

/// Without the Alipay SDK binary, the order string goes to Alipay through its app URL and comes back on the
/// app's own scheme (`<scheme>://safepay/?<json>`). Pure helpers so the shapes are unit-tested.
public enum AlipayURLPayment {
    /// `alipay://alipayclient/?{"requestType":"SafePay","fromAppUrlScheme":…,"dataString":…}` (JSON, percent-encoded).
    public static func launchURL(orderString: String, fromScheme: String) -> URL? {
        let payload: [String: String] = ["requestType": "SafePay", "fromAppUrlScheme": fromScheme, "dataString": orderString]
        guard !orderString.isEmpty, !fromScheme.isEmpty,
              let json = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let text = String(data: json, encoding: .utf8) else { return nil }
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "alipay://alipayclient/?" + encoded)
    }

    /// The `ResultStatus` inside the return URL's JSON (`memo.ResultStatus`), or nil when absent.
    public static func resultStatus(from url: URL) -> String? {
        guard url.host?.lowercased() == "safepay" else { return nil }
        let raw = url.query ?? URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedQuery
        guard let raw, let decoded = raw.removingPercentEncoding, let data = decoded.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        return findStatus(object)
    }

    private static func findStatus(_ object: [String: Any]) -> String? {
        for (key, value) in object where key.lowercased() == "resultstatus" {
            if let text = value as? String { return text }
            if let number = value as? Int { return String(number) }
        }
        for value in object.values {
            if let nested = value as? [String: Any], let found = findStatus(nested) { return found }
        }
        return nil
    }
}

/// Reads the positive `id` field from a form body built by `AuthRequestBuilder.makeFormRequest` (multipart), or a
/// url-encoded `id=` body. Used by the app-side Alipay transport lease.
public enum RegistrationAlipayFormID {
    public static func registrationID(inFormBody body: String) -> Int? {
        let marker = "name=\"id\"\r\n\r\n"
        if let range = body.range(of: marker) {
            let rest = body[range.upperBound...]
            let value = rest.prefix(while: { $0.isASCII && $0.isNumber })
            guard let id = Int(value), id > 0 else { return nil }
            return id
        }
        let pairs = body.split(separator: "&")
        for pair in pairs where pair.hasPrefix("id=") {
            guard let id = Int(pair.dropFirst(3)), id > 0 else { return nil }
            return id
        }
        return nil
    }
}
