import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// `POST /api/registration/pay` (and `/pay/app`) channel selector for RM-02.
public enum RegistrationPayChannel: String, Equatable, Sendable {
    case standard = "api/registration/pay"
    case app = "api/registration/pay/app"

    public var routePath: String { "/" + rawValue }
}

/// Non-retryable refusal or preflight block before dispatching `/api/registration/pay`.
public enum RegistrationPayBlockReason: String, Equatable, Sendable {
    case moneyPaymentsClosed
    case signedOut
    case notReady
    case quoteUnavailable
    case quoteStale
    case missingConsent
    case invalidRegistrationID
    case alreadyAttempted
}

/// Decoded payload from `POST /api/registration/pay` or `POST /api/registration/pay/app`.
public struct RegistrationPayResponse: Equatable, Sendable {
    public let registrationID: Int
    public let registrationNo: String?
    public let paymentStatus: Int?
    public let registrationStatus: Int?
    public let payableAmount: Decimal?
    public let payParams: [String: String]?
    public let message: String?

    public var hasPaymentParameters: Bool { payParams?.isEmpty == false }

    public init(registrationID: Int, registrationNo: String? = nil, paymentStatus: Int? = nil,
                registrationStatus: Int? = nil, payableAmount: Decimal? = nil,
                payParams: [String: String]? = nil, message: String? = nil) {
        self.registrationID = registrationID
        self.registrationNo = registrationNo
        self.paymentStatus = paymentStatus
        self.registrationStatus = registrationStatus
        self.payableAmount = payableAmount
        self.payParams = payParams
        self.message = message
    }
}

/// Single-attempt payment dispatch state. Errors and 410s never auto-retry.
public enum RegistrationPayOutcome: Equatable, Sendable {
    case idle
    case checkingReadiness
    case paying
    case blocked(RegistrationPayBlockReason, message: String? = nil)
    case paidOrParametersReceived(RegistrationPayResponse)
    case expiredNeedsRebuild(message: String)
    case rejected(code: Int?, message: String)
    case unauthorized
    case outcomeUnknown(message: String?)
}

/// Single-shot HTTP executor for `POST /api/registration/pay` and `/pay/app`.
/// Never retries automatically on timeout, 410, 5xx, or cancellation.
public enum RegistrationPayService {
    public static func makeRequest(configuration: APIConfiguration, token: String,
                                   registrationID: Int,
                                   channel: RegistrationPayChannel = .standard) throws -> URLRequest {
        guard !ReleaseMoneyWriteSwitch.blocks(channel.routePath) else {
            throw APIError.notConfigured
        }
        guard AuthRequestBuilder.isValidToken(token) else {
            throw APIError.unauthorized
        }
        guard registrationID > 0 else {
            throw APIError.invalidRequest
        }
        var request = try AuthRequestBuilder.makeFormRequest(
            url: configuration.baseURL.appendingPathComponent(channel.rawValue),
            fields: ["id": String(registrationID)],
            token: token
        )
        request.timeoutInterval = 20
        return request
    }

    public static func decode(_ data: Data, status: Int, registrationID: Int) -> RegistrationPayOutcome {
        if status == 401 || status == 403 {
            return .unauthorized
        }
        guard (200..<300).contains(status),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return .outcomeUnknown(message: nil)
        }
        let code = (object["code"] as? Int) ?? (object["code"] as? String).flatMap(Int.init)
        let msg = (object["msg"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard code == 200 else {
            switch CheckoutOrderRebuildRule.classifyPayFailure(code: code, message: msg, canRebuild: true) {
            case .rebuildExpiredPayOrder(let userMessage):
                return .expiredNeedsRebuild(message: userMessage)
            case .preserveIntent(let userMessage):
                return .rejected(code: code, message: userMessage ?? "支付请求暂未成功")
            case .rebuildTerminalIdempotencyConflict, .refreshQuoteAndReconfirm:
                return .rejected(code: code, message: msg ?? "支付请求暂未成功")
            }
        }
        let payload = object["data"] as? [String: Any] ?? [:]
        let decodedID = (payload["registrationId"] as? Int)
            ?? (payload["id"] as? Int)
            ?? registrationID
        let regNo = payload["registrationNo"] as? String
        let payStatus = (payload["paymentStatus"] as? Int) ?? (payload["paymentStatus"] as? String).flatMap(Int.init)
        let regStatus = (payload["registrationStatus"] as? Int) ?? (payload["registrationStatus"] as? String).flatMap(Int.init)
        let payable = parseDecimal(payload["payableAmount"])
        let rawParams = payload["payParams"] as? [String: Any]
        var stringParams: [String: String]?
        if let rawParams, !rawParams.isEmpty {
            var mapped: [String: String] = [:]
            for (k, v) in rawParams {
                if v is NSNull { continue }
                mapped[k] = String(describing: v)
            }
            if !mapped.isEmpty { stringParams = mapped }
        }
        return .paidOrParametersReceived(
            RegistrationPayResponse(
                registrationID: decodedID > 0 ? decodedID : registrationID,
                registrationNo: regNo,
                paymentStatus: payStatus,
                registrationStatus: regStatus,
                payableAmount: payable,
                payParams: stringParams,
                message: (msg?.isEmpty == false) ? msg : nil
            )
        )
    }

    /// Executes at most ONE HTTP call after verifying Release switch, readiness, quote, and consent.
    public static func submit(configuration: APIConfiguration, transport: any HTTPTransport,
                              token: String, registrationID: Int,
                              readiness: RegistrationPaymentReadiness?,
                              quoteUsable: Bool, quoteFresh: Bool, consented: Bool,
                              channel: RegistrationPayChannel = .standard) async -> RegistrationPayOutcome {
        guard ReleaseMoneyWriteSwitch.isEnabled(.payment),
              !ReleaseMoneyWriteSwitch.blocks(channel.routePath) else {
            return .blocked(.moneyPaymentsClosed)
        }
        guard AuthRequestBuilder.isValidToken(token) else {
            return .blocked(.signedOut)
        }
        guard registrationID > 0 else {
            return .blocked(.invalidRegistrationID)
        }
        guard let readiness, readiness.ready else {
            return .blocked(.notReady, message: readiness?.message)
        }
        guard quoteUsable else {
            return .blocked(.quoteUnavailable)
        }
        guard quoteFresh else {
            return .blocked(.quoteStale)
        }
        guard consented else {
            return .blocked(.missingConsent)
        }
        let request: URLRequest
        do {
            request = try makeRequest(configuration: configuration, token: token,
                                      registrationID: registrationID, channel: channel)
        } catch let error as APIError where error == .unauthorized {
            return .blocked(.signedOut)
        } catch {
            return .blocked(.moneyPaymentsClosed)
        }
        do {
            let (data, status) = try await transport.send(request)
            return decode(data, status: status, registrationID: registrationID)
        } catch let error as APIError where error == .unauthorized {
            return .unauthorized
        } catch {
            // Single-shot rule: network/timeout/cancel stays outcomeUnknown and NEVER retries automatically.
            return .outcomeUnknown(message: nil)
        }
    }

    private static func parseDecimal(_ raw: Any?) -> Decimal? {
        guard let raw, !(raw is NSNull) else { return nil }
        if let num = raw as? NSNumber { return num.decimalValue }
        if let str = raw as? String {
            return Decimal(string: str.trimmingCharacters(in: .whitespacesAndNewlines),
                           locale: Locale(identifier: "en_US_POSIX"))
        }
        return nil
    }
}

/// Stateful controller managing readiness check + single-shot payment with strict non-retry locking.
@MainActor
public final class RegistrationPayModel {
    public private(set) var outcome: RegistrationPayOutcome = .idle
    public private(set) var attemptedRegistrationIDs: Set<Int> = []
    public private(set) var dispatchCount = 0
    public var onChange: (() -> Void)?

    public init() {}

    public func isLocked(registrationID: Int) -> Bool {
        attemptedRegistrationIDs.contains(registrationID)
    }

    public func pay(registrationID: Int,
                    paymentsOpen: Bool,
                    readiness: RegistrationPaymentReadiness?,
                    readinessReader: (@MainActor () async -> RegistrationPaymentReadiness?)? = nil,
                    quote: RegistrationQuote?,
                    quoteReceivedAt: Date?,
                    consented: Bool,
                    requiresFreshQuote: Bool = true,
                    now: () -> Date = Date.init,
                    channel: RegistrationPayChannel = .standard,
                    executor: (@MainActor (Int, RegistrationPayChannel, RegistrationPaymentReadiness) async -> RegistrationPayOutcome)?) async {
        guard paymentsOpen, ReleaseMoneyWriteSwitch.isEnabled(.payment) else {
            outcome = .blocked(.moneyPaymentsClosed)
            onChange?()
            return
        }
        guard registrationID > 0 else {
            outcome = .blocked(.invalidRegistrationID)
            onChange?()
            return
        }
        guard !attemptedRegistrationIDs.contains(registrationID) else {
            outcome = .blocked(.alreadyAttempted)
            onChange?()
            return
        }
        guard consented else {
            outcome = .blocked(.missingConsent)
            onChange?()
            return
        }
        if requiresFreshQuote {
            guard let quote, quote.isUsableForCreate else {
                outcome = .blocked(.quoteUnavailable)
                onChange?()
                return
            }
            guard let quoteReceivedAt,
                  now().timeIntervalSince(quoteReceivedAt) >= 0,
                  now().timeIntervalSince(quoteReceivedAt) < 120 else {
                outcome = .blocked(.quoteStale)
                onChange?()
                return
            }
        }
        var currentReadiness = readiness
        if currentReadiness == nil, let readinessReader {
            outcome = .checkingReadiness
            onChange?()
            currentReadiness = await readinessReader()
        }
        guard let verifiedReadiness = currentReadiness, verifiedReadiness.ready else {
            outcome = .blocked(.notReady, message: currentReadiness?.message)
            onChange?()
            return
        }
        guard let executor else {
            outcome = .blocked(.moneyPaymentsClosed)
            onChange?()
            return
        }
        // Single-shot fence BEFORE the first suspension point: never auto-retry on any error/timeout.
        attemptedRegistrationIDs.insert(registrationID)
        dispatchCount += 1
        outcome = .paying
        onChange?()
        outcome = await executor(registrationID, channel, verifiedReadiness)
        onChange?()
    }
}

public extension RegistrationQuoteState {
    var quoteValue: RegistrationQuote? {
        if case .received(let quote) = self { return quote }
        return nil
    }
}

