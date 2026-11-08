import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Allow-listing transport for exactly two bundle routes (IWP-1, unmounted; nothing constructs it yet):
///   GET  {base}/api/free-explore/bundle/reservation/{id}/cancel-quote?useWaiver=true|false
///   POST {base}/api/free-explore/bundle/reservation/{id}/cancel   body {"useWaiver":Bool,"expectedOutcome":String}
/// Everything else (other path, query, method, host, header, body shape) is refused before the network.
/// `expectedOutcome` is mandatory here even though the server tolerates omission. The POST additionally needs
/// the injected `writeAllowed()` to be true (default false), before and after the network call.
@MainActor final class BundleCancelTransport: HTTPTransport {
    private let captured: RuntimeDependencyContext
    private let underlying: any HTTPTransport
    private let current: () -> RuntimeDependencyContext?
    private let writeAllowed: () -> Bool
    private let denied: () -> Void
    private var active = true
    private static let bodyCap = 4_096
    private static let responseCap = 1_048_576

    init(context: RuntimeDependencyContext, underlying: any HTTPTransport,
         current: @escaping () -> RuntimeDependencyContext?,
         writeAllowed: @escaping () -> Bool = { false },
         denied: @escaping () -> Void = {}) throws {
        guard context.market == .china, context.session.accountID > 0,
              AuthRequestBuilder.isValidToken(context.session.token) else { throw APIError.invalidConfiguration }
        captured = context; self.underlying = underlying; self.current = current
        self.writeAllowed = writeAllowed; self.denied = denied
    }

    var isCurrent: Bool { active && current() == captured }
    func retire() { active = false }

    private enum Route { case quote(String), cancel(String) }

    /// Exact-match route check. Returns nil for anything that is not one of the two allowed shapes.
    private func route(for request: URLRequest) -> Route? {
        guard let url = request.url,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.user == nil, parts.password == nil, parts.fragment == nil,
              request.httpBodyStream == nil,
              request.value(forHTTPHeaderField: "Authorization") == captured.session.token else { return nil }
        let prefix = "api/free-explore/bundle/reservation/"
        for (method, suffix) in [("GET", "/cancel-quote"), ("POST", "/cancel")] where request.httpMethod == method {
            // Rebuild the only acceptable URL and compare whole strings, so no variant can slip through.
            guard let id = Self.reservationID(in: parts.path, prefix: "/" + prefix, suffix: suffix) else { return nil }
            var expected = URLComponents(url: captured.baseURL.appendingPathComponent(prefix + id + suffix),
                                         resolvingAgainstBaseURL: false)
            if method == "GET" {
                guard let query = parts.queryItems, query.count == 1, query[0].name == "useWaiver",
                      query[0].value == "true" || query[0].value == "false" else { return nil }
                expected?.queryItems = [URLQueryItem(name: "useWaiver", value: query[0].value)]
            }
            guard expected?.url?.absoluteString == url.absoluteString else { return nil }
            return method == "GET" ? .quote(id) : .cancel(id)
        }
        return nil
    }

    private static func reservationID(in path: String, prefix: String, suffix: String) -> String? {
        guard path.hasPrefix(prefix), path.hasSuffix(suffix), path.count > prefix.count + suffix.count else { return nil }
        let id = String(path.dropFirst(prefix.count).dropLast(suffix.count))
        guard id.utf8.count <= 19, id.utf8.allSatisfy({ (48...57).contains($0) }),
              let value = Int64(id), value > 0, String(value) == id else { return nil }
        return id
    }

    /// Body must be exactly `{useWaiver: Bool, expectedOutcome: non-empty String}` and nothing else.
    private static func bodyIsExact(_ request: URLRequest) -> Bool {
        guard request.value(forHTTPHeaderField: "Content-Type") == "application/json; charset=utf-8",
              let body = request.httpBody, !body.isEmpty, body.count <= bodyCap,
              request.value(forHTTPHeaderField: "Content-Length") == String(body.count),
              let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any],
              Set(object.keys) == ["useWaiver", "expectedOutcome"],
              object["useWaiver"] is Bool,
              let outcome = object["expectedOutcome"] as? String, !outcome.isEmpty, outcome.utf8.count <= 64 else { return false }
        return true
    }

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        try Task.checkCancellation()
        guard let route = route(for: request) else {
            if request.httpMethod == "GET" { throw APIError.notConfigured }
            throw FreeExploreLaunchFailure.disabled
        }
        switch route {
        case .quote:
            guard isCurrent, request.httpBody == nil else { throw APIError.notConfigured }
            let result = try await underlying.send(request)
            try Task.checkCancellation()
            guard isCurrent else { throw APIError.notConfigured }
            try screen(result)
            return result
        case .cancel:
            guard Self.bodyIsExact(request), isCurrent, writeAllowed() else { throw FreeExploreLaunchFailure.disabled }
            let result = try await underlying.send(request)
            // The request may already have been applied: anything after this point is "unknown", never "failed".
            guard isCurrent, writeAllowed() else { throw FreeExploreLaunchFailure.outcomeUnknown }
            try screen(result)
            return result
        }
    }

    /// 403 retires this permission. A matching 401 is left for the client's session-expiry callback, and a
    /// business 409 LOGIN_REQUIRED is a definite refusal that must not retire anything.
    private func screen(_ result: (Data, Int)) throws {
        let code: Int?
        if result.0.count <= Self.responseCap {
            code = ((try? JSONSerialization.jsonObject(with: result.0)) as? [String: Any])?["code"] as? Int
        } else { code = nil }
        if result.1 == 403 || code == 403 { active = false; denied() }
    }
}
