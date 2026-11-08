import Foundation

/// RP-07: maps the unserved `api/merchant/offer-withdrawal/request/withdraw` onto production
/// `POST /api/coop/offer/withdraw` (ApiCoopController `offerWithdraw`; mini-program
/// `pages/topic/merchantinfo/merchantinfo.js` sends `{offerId, reason}` as JSON).
/// Production has NO `current` or `result` (receipt) route, so after any transport failure or 5xx the
/// outcome is UNKNOWN, never "not withdrawn". Gated: `allowed` defaults to false. NOT COMPILED.
public enum RePoint07OfferWithdrawalOutcome: Equatable {
    case withdrawn(enrollmentPaused: Bool?, message: String?)
    case rejected(code: Int, message: String?)
    case unknown
    case disabled
    case invalid
}

public struct RePoint07OfferWithdrawalClient {
    public static let productionPath = "api/coop/offer/withdraw"
    private let baseURL: URL
    private let token: () -> String?
    private let transport: any HTTPTransport
    private let allowed: () -> Bool

    public init(baseURL: URL, token: @escaping () -> String?, transport: any HTTPTransport, allowed: @escaping () -> Bool = { false }) {
        self.baseURL = baseURL; self.token = token; self.transport = transport; self.allowed = allowed
    }

    /// Body is exactly `{offerId, reason}`. The iOS-only hashes/requestId are NOT sent (backend ignores them).
    public func request(offerID: Int, reason: String) throws -> URLRequest {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard offerID > 0, !trimmed.isEmpty, trimmed.utf16.count <= 500,
              let credential = token(), AuthRequestBuilder.isValidToken(credential) else { throw Adapt2Failure.invalid }
        var r = URLRequest(url: baseURL.appendingPathComponent(Self.productionPath))
        r.httpMethod = "POST"; r.httpShouldHandleCookies = false
        r.cachePolicy = .reloadIgnoringLocalCacheData; r.timeoutInterval = 30
        r.httpBody = try JSONSerialization.data(withJSONObject: ["offerId": offerID, "reason": trimmed], options: [.sortedKeys])
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue(credential, forHTTPHeaderField: "Authorization")
        return r
    }

    public func withdraw(offerID: Int, reason: String) async -> RePoint07OfferWithdrawalOutcome {
        guard allowed() else { return .disabled }
        guard let r = try? request(offerID: offerID, reason: reason) else { return .invalid }
        let result: (Data, Int)
        do { result = try await transport.send(r) } catch { return .unknown }
        do {
            let u = try Adapt2AjaxEnvelope.unwrap(status: result.1, body: result.0)
            var paused: Bool?
            if let d = u.data, let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] { paused = o["enrollmentPaused"] as? Bool }
            return .withdrawn(enrollmentPaused: paused, message: u.message)
        } catch let f as Adapt2Failure {
            switch f {
            case .rejected(let c, let m): return .rejected(code: c, message: m)
            default: return .unknown   // 401/5xx/malformed: cannot read back, so UNKNOWN
            }
        } catch { return .unknown }
    }
}
