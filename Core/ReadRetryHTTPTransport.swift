import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Configuration for automatic read retries with bounded exponential backoff and `Retry-After` compliance.
/// Mirrors `chengyinhub-xcx/utils/transport/request-client.js` (`400 * attemptIndex` backoff, read-only retries,
/// session/owner change abort) and `NetworkReachabilityAndRetryBackoffAudit`.
public struct ReadRetryPolicy: Equatable, Sendable {
    /// Bounded automatic retries on transient transport or `429`/`503` failures (`0...3`).
    public let maxAutoRetries: Int
    /// Backoff base delay in milliseconds (`200...2000`). Default matches mini-program `400ms`.
    public let baseDelayMs: Int
    /// Maximum jitter ratio applied above the exponential/Retry-After floor (`0.0...0.25`).
    public let jitterRatio: Double
    /// Strictly respects HTTP `429` / `503` `Retry-After` headers.
    public let respectsRetryAfterHeader: Bool

    public init(
        maxAutoRetries: Int = 2,
        baseDelayMs: Int = 400,
        jitterRatio: Double = 0.0,
        respectsRetryAfterHeader: Bool = true
    ) {
        self.maxAutoRetries = min(max(0, maxAutoRetries), 3)
        self.baseDelayMs = min(max(200, baseDelayMs), 2000)
        self.jitterRatio = min(max(0.0, jitterRatio), 0.25)
        self.respectsRetryAfterHeader = respectsRetryAfterHeader
    }

    public static let `default` = ReadRetryPolicy()
}

/// Thread-safe shared reachability flag updated by the App's `NWPathMonitor` (`NetworkReachability`)
/// and read by `ReadRetryHTTPTransport` without importing `Network.framework` into `QuestifyCore`.
public final class SharedNetworkReachabilityState: @unchecked Sendable {
    public static let shared = SharedNetworkReachabilityState()
    private let lock = NSLock()
    private var _isOnline: Bool = true

    public init(isOnline: Bool = true) {
        self._isOnline = isOnline
    }

    public var isOnline: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isOnline
    }

    public func setOnline(_ online: Bool) {
        lock.lock()
        _isOnline = online
        lock.unlock()
    }
}

/// Request ID correlation and `Retry-After` header helpers aligned with backend `RequestIdFilter.java`
/// (`[A-Za-z0-9_-]{8,64}`) and RFC 9110 `Retry-After`.
public enum HTTPRequestRetrySupport {
    public static let requestIDHeader = "X-Request-Id"
    public static let safeReadOptInHeader = "X-Questify-Safe-Read"

    private static let writeVerbMarkers: [String] = [
        "/create", "/delete", "/remove", "/update", "/edit", "/submit",
        "/pay", "/withdraw", "/refund", "/deposit", "/order", "/settlement",
        "/buy", "/tip", "/recharge", "/cancel", "/approve", "/reject",
        "/join", "/quit", "/assign", "/revoke", "/publish", "/stop",
        "/reveal", "/finish", "/discover", "/visit", "/checkin", "/upload",
        "/exchange", "/apply", "/save", "/bind", "/unbind", "/claim",
        "/recover", "/close", "/use", "/start", "/abandon", "/dispute",
        "/appeal", "/send", "/retry", "/settle", "/activate"
    ]

    /// True iff `value` satisfies `RequestIdFilter.SAFE_ID` (`[A-Za-z0-9_-]{8,64}`).
    public static func isValidRequestID(_ value: String) -> Bool {
        guard (8...64).contains(value.utf8.count) else { return false }
        return value.unicodeScalars.allSatisfy { scalar in
            let v = scalar.value
            return (v >= 48 && v <= 57) || (v >= 65 && v <= 90) || (v >= 97 && v <= 122) || v == 95 || v == 45
        }
    }

    /// Ensures `request` carries a valid `X-Request-Id` header matching `RequestIdFilter`.
    @discardableResult
    public static func ensureRequestID(on request: inout URLRequest, makeID: () -> String = { UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased() }) -> String {
        if let existing = request.value(forHTTPHeaderField: requestIDHeader), isValidRequestID(existing) {
            return existing
        }
        let generated = makeID()
        let safe = isValidRequestID(generated) ? generated : UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        request.setValue(safe, forHTTPHeaderField: requestIDHeader)
        return safe
    }

    /// Port of `request-client.js` write detection combined with strict HTTP method & money guards.
    /// Automatically retries ONLY safe/idempotent read requests, NEVER mutations or money writes.
    public static func isSafeAutoRetryRead(_ request: URLRequest) -> Bool {
        guard let url = request.url else { return false }
        let normalizedPath = ChinaReviewedRouteCapability.normalized(url.path)
        if ReleaseMoneyWriteSwitch.kind(for: normalizedPath) != nil { return false }
        if BackendIdempotentWriteRouteCatalog.isMoneyOrCashSensitiveWrite(normalizedPath) { return false }

        let lowered = normalizedPath.lowercased()
        if writeVerbMarkers.contains(where: { lowered.contains($0) }) { return false }

        let method = (request.httpMethod ?? "GET").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if method == "GET" || method == "HEAD" || method == "OPTIONS" {
            return true
        }
        if method == "POST", request.value(forHTTPHeaderField: safeReadOptInHeader) == "1" {
            return BackendIdempotentWriteRouteCatalog.idempotencySupport(for: method, path: normalizedPath) == nil
        }
        return false
    }

    /// Parses numeric delta-seconds or HTTP-date `Retry-After` headers.
    public static func parseRetryAfterSeconds(_ headerValue: String?, now: Date = Date()) -> Int? {
        guard let trimmed = headerValue?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        if let integer = Int(trimmed), integer >= 0 {
            return min(integer, 120)
        }
        let formatters = ["EEE, dd MMM yyyy HH:mm:ss zzz", "EEEE, dd-MMM-yy HH:mm:ss zzz", "EEE MMM d HH:mm:ss yyyy"]
        for format in formatters {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) {
                let delta = Int(ceil(date.timeIntervalSince(now)))
                return delta > 0 ? min(delta, 120) : 0
            }
        }
        return nil
    }

    /// Transient network errors eligible for safe-read retry (excluding cancellations & TLS trust failures).
    public static func isTransientTransportError(_ error: Error) -> Bool {
        if error is CancellationError { return false }
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost,
             .dnsLookupFailed, .notConnectedToInternet, .internationalRoamingOff,
             .callIsActive, .dataNotAllowed, .resourceUnavailable:
            return true
        default:
            return false
        }
    }

    /// True if JSON body looks like an envelope with `"code": 401`.
    public static func isEnvelopeUnauthorized(_ data: Data) -> Bool {
        guard data.count <= 65_536,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        if let code = object["code"] as? Int { return code == 401 }
        if let code = object["code"] as? String { return code == "401" }
        return false
    }
}

/// Transport decorator that:
/// 1. Attaches valid `X-Request-Id` correlation headers on outgoing requests (`RequestIdFilter.java`).
/// 2. Automatically retries safe read requests with exponential backoff (`400ms * 2^attempt`) & HTTP `429`/`503` `Retry-After`.
/// 3. Aborts immediately on cancellation, `401`, or session/owner fingerprint change (`request-client.js`).
/// 4. NEVER automatically retries any write request or money route.
public final class ReadRetryHTTPTransport: HTTPMetadataTransport, @unchecked Sendable {
    private let underlying: any HTTPTransport
    private let policy: ReadRetryPolicy
    private let isOnline: @Sendable () -> Bool
    private let sessionFingerprint: @Sendable () -> String?
    private let makeRequestID: @Sendable () -> String
    private let sleep: @Sendable (TimeInterval) async throws -> Void
    private let now: @Sendable () -> Date

    public init(
        underlying: any HTTPTransport,
        policy: ReadRetryPolicy = .default,
        isOnline: @escaping @Sendable () -> Bool = { true },
        sessionFingerprint: @escaping @Sendable () -> String? = { nil },
        makeRequestID: @escaping @Sendable () -> String = { UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased() },
        sleep: @escaping @Sendable (TimeInterval) async throws -> Void = { seconds in
            let nanos = UInt64(max(0, seconds) * 1_000_000_000)
            try await Task.sleep(nanoseconds: nanos)
        },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.underlying = underlying
        self.policy = policy
        self.isOnline = isOnline
        self.sessionFingerprint = sessionFingerprint
        self.makeRequestID = makeRequestID
        self.sleep = sleep
        self.now = now
    }

    public func send(_ request: URLRequest) async throws -> (Data, Int) {
        let (data, status, _) = try await sendWithHeaders(request)
        return (data, status)
    }

    public func sendWithHeaders(_ request: URLRequest) async throws -> (data: Data, status: Int, headers: [String: String]) {
        var outgoing = request
        outgoing.setValue(nil, forHTTPHeaderField: HTTPRequestRetrySupport.safeReadOptInHeader)
        HTTPRequestRetrySupport.ensureRequestID(on: &outgoing, makeID: makeRequestID)

        let capturedSession = sessionFingerprint()
        let safeToRetry = HTTPRequestRetrySupport.isSafeAutoRetryRead(request)
        let allowedRetries = safeToRetry ? policy.maxAutoRetries : 0

        var attemptIndex = 0
        while true {
            try Task.checkCancellation()
            guard sessionFingerprint() == capturedSession else { throw CancellationError() }

            do {
                let result = try await dispatch(outgoing)
                try Task.checkCancellation()
                guard sessionFingerprint() == capturedSession else { throw CancellationError() }

                if result.status == 401 || HTTPRequestRetrySupport.isEnvelopeUnauthorized(result.data) {
                    return result
                }

                let retryableStatus = (result.status == 429 || result.status == 503 || result.status == 502 || result.status == 504)
                guard safeToRetry, retryableStatus, attemptIndex < allowedRetries else {
                    return result
                }

                let reachability: NetworkReachabilityAndRetryBackoffAudit.ReachabilityState = isOnline() ? .satisfied : .unsatisfied
                guard reachability.allowsImmediateAutoRetry else {
                    return result
                }

                let retryAfterHeader = result.headers["retry-after"]
                let retryAfterSeconds = policy.respectsRetryAfterHeader
                    ? HTTPRequestRetrySupport.parseRetryAfterSeconds(retryAfterHeader, now: now())
                    : nil
                let delay = backoffDelaySeconds(statusCode: result.status, retryAfterSeconds: retryAfterSeconds, attemptIndex: attemptIndex)
                attemptIndex += 1
                try await sleep(delay)
            } catch {
                if error is CancellationError { throw error }
                guard safeToRetry,
                      attemptIndex < allowedRetries,
                      HTTPRequestRetrySupport.isTransientTransportError(error),
                      isOnline() else {
                    throw error
                }
                guard sessionFingerprint() == capturedSession else { throw CancellationError() }
                let delay = backoffDelaySeconds(statusCode: nil, retryAfterSeconds: nil, attemptIndex: attemptIndex)
                attemptIndex += 1
                try await sleep(delay)
            }
        }
    }

    private func dispatch(_ request: URLRequest) async throws -> (data: Data, status: Int, headers: [String: String]) {
        if let meta = underlying as? any HTTPMetadataTransport {
            return try await meta.sendWithHeaders(request)
        }
        let (data, status) = try await underlying.send(request)
        return (data, status, [:])
    }

    private func backoffDelaySeconds(statusCode: Int?, retryAfterSeconds: Int?, attemptIndex: Int) -> TimeInterval {
        // The audit helper returns nil outside its 0...2 attempt window; fall back to the plain exponential delay.
        let baseFloor = NetworkReachabilityAndRetryBackoffAudit.effectiveRetryDelaySeconds(
            httpStatusCode: statusCode ?? 0,
            retryAfterSecondsHeader: retryAfterSeconds,
            attemptIndex: attemptIndex,
            baseDelayMs: policy.baseDelayMs
        ) ?? (Double(policy.baseDelayMs) / 1000.0) * pow(2.0, Double(attemptIndex))
        let jitter = policy.jitterRatio > 0 ? baseFloor * Double.random(in: 0...policy.jitterRatio) : 0
        return baseFloor + jitter
    }
}
