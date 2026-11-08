import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Exact method + exact URL allow-list for the appeal endpoints. Unmounted: nothing constructs this yet.
///   POST …/api/free-explore/bundle/voucher/appeal
///   GET  …/api/free-explore/bundle/voucher/appeal/receipt?idempotencyKey=
///   GET  …/api/free-explore/bundle/voucher/appeal?registrationId=
/// `Authorization` must equal the captured token; writes are refused unless `writeAllowed()`; the permission is
/// re-checked after the network call (a change mid-flight is `.outcomeUnknown`, never a clean failure).
@MainActor final class BundleAppealTransport: HTTPTransport {
    private let baseURL: URL
    private let token: String
    private let underlying: any HTTPTransport
    private let isCurrent: () -> Bool
    private let writeAllowed: () -> Bool
    private let onUnauthorized: () -> Void
    private var retired = false
    private static let bodyCap = 16_384
    private static let responseCap = 1_048_576

    init(baseURL: URL, token: String, underlying: any HTTPTransport, isCurrent: @escaping () -> Bool,
         writeAllowed: @escaping () -> Bool = { false }, onUnauthorized: @escaping () -> Void = {}) throws {
        guard AuthRequestBuilder.isValidToken(token) else { throw FreeExploreLaunchFailure.invalid }
        self.baseURL = baseURL; self.token = token; self.underlying = underlying
        self.isCurrent = isCurrent; self.writeAllowed = writeAllowed; self.onUnauthorized = onUnauthorized
    }

    func retire() { retired = true }
    private var base: String { baseURL.appendingPathComponent("api/free-explore/bundle/voucher/appeal").absoluteString }

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        try Task.checkCancellation()
        guard !retired, isCurrent() else { throw FreeExploreLaunchFailure.staleSession }
        guard let url = request.url, var parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              request.httpBodyStream == nil,
              request.value(forHTTPHeaderField: "Authorization") == token else { throw FreeExploreLaunchFailure.disabled }
        let query = parts.query; parts.query = nil
        let bare = parts.url?.absoluteString
        let write: Bool
        switch request.httpMethod {
        case "POST":
            guard bare == base, query == nil, writeAllowed(), let body = request.httpBody, body.count <= Self.bodyCap,
                  request.value(forHTTPHeaderField: "Content-Length") == String(body.count) else { throw FreeExploreLaunchFailure.disabled }
            write = true
        case "GET":
            guard request.httpBody == nil,
                  (bare == base && query?.hasPrefix("registrationId=") == true)
                    || (bare == base + "/receipt" && query?.hasPrefix("idempotencyKey=") == true) else { throw FreeExploreLaunchFailure.disabled }
            write = false
        default: throw FreeExploreLaunchFailure.disabled
        }
        let result: (Data, Int)
        do { result = try await underlying.send(request) } catch {
            if write { throw FreeExploreLaunchFailure.outcomeUnknown }
            throw error
        }
        guard !retired, isCurrent() else { throw write ? FreeExploreLaunchFailure.outcomeUnknown : FreeExploreLaunchFailure.staleSession }
        if write, !writeAllowed() { throw FreeExploreLaunchFailure.outcomeUnknown }
        if result.1 == 401 { onUnauthorized() }
        if result.1 == 403 { retire() }
        if result.0.count <= Self.responseCap, let object = try? JSONSerialization.jsonObject(with: result.0) as? [String: Any] {
            if object["code"] as? Int == 401 { onUnauthorized() }
            if object["code"] as? Int == 403 { retire() }
            // Business 409 LOGIN_REQUIRED is login loss: not a 401, never clears the pending command.
        }
        return result
    }
}
