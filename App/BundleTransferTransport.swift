import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// IWP-8c. Exact method + exact URL allow-list for the transfer endpoints. Nothing installs it: no approval,
/// lease or factory exists, `permitsWrites` defaults to `false`, and EP-BND-24 is not in the backend yet.
/// Same shape as `FreeExploreBundleReservationTransport`, but it neither reads nor stores the one-time code
/// and never logs request or response bodies.
@MainActor final class BundleTransferTransport: HTTPTransport {
    private let captured: RuntimeDependencyContext
    private let pending: BundleTransferPendingStore
    private let underlying: any HTTPTransport
    private let current: () -> RuntimeDependencyContext?
    private let permitsWrites: () -> Bool
    private let denied: () -> Void
    private var active = true
    private static let basePath = "api/free-explore/bundle/transfer"

    init(context: RuntimeDependencyContext, pending: BundleTransferPendingStore, underlying: any HTTPTransport,
         current: @escaping () -> RuntimeDependencyContext?,
         permitsWrites: @escaping () -> Bool = { false },
         denied: @escaping () -> Void = {}) {
        captured = context; self.pending = pending; self.underlying = underlying
        self.current = current; self.permitsWrites = permitsWrites; self.denied = denied
    }

    var isCurrent: Bool { active && current() == captured }
    func retire() { active = false }

    private enum Route { case read, send, claim, revoke }

    /// Exact URL match only; query strings are allowed on the read routes alone.
    private func route(for request: URLRequest) -> Route? {
        guard let url = request.url, let method = request.httpMethod,
              var parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let base = URLComponents(url: captured.baseURL, resolvingAgainstBaseURL: false),
              parts.scheme == base.scheme, parts.host == base.host, parts.port == base.port,
              parts.user == nil, parts.password == nil, parts.fragment == nil else { return nil }
        let query = parts.query
        parts.query = nil
        let prefix = (base.path.hasSuffix("/") ? String(base.path.dropLast()) : base.path) + "/" + Self.basePath
        let path = parts.path
        if method == "GET" {
            guard path == prefix || path == prefix + "/preview" || path == prefix + "/receipt" else { return nil }
            return .read
        }
        guard method == "POST", query == nil else { return nil }
        if path == prefix { return .send }
        if path == prefix + "/claim" { return .claim }
        if path.hasPrefix(prefix + "/"), path.hasSuffix("/revoke") {
            let id = path.dropFirst(prefix.count + 1).dropLast("/revoke".count)
            if !id.isEmpty, id.utf8.allSatisfy({ (48...57).contains($0) }) { return .revoke }
        }
        return nil
    }

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        try Task.checkCancellation()
        guard isCurrent, let route = route(for: request),
              request.value(forHTTPHeaderField: "Authorization") == captured.session.token else {
            throw FreeExploreLaunchFailure.disabled
        }
        if route == .read {
            guard request.httpBody == nil, request.httpBodyStream == nil else { throw FreeExploreLaunchFailure.disabled }
            let result = try await underlying.send(request)
            try Task.checkCancellation()
            guard isCurrent else { throw FreeExploreLaunchFailure.staleSession }
            observe(result)
            return result
        }
        guard permitsWrites(), request.httpBodyStream == nil,
              request.value(forHTTPHeaderField: "Content-Type") == "application/json; charset=utf-8",
              let body = request.httpBody, body.count <= 4_096,
              request.value(forHTTPHeaderField: "Content-Length") == String(body.count) else {
            throw FreeExploreLaunchFailure.disabled
        }
        // Send / claim must carry the idempotency key that was persisted BEFORE dispatch.
        if route == .send || route == .claim {
            let expected: BundleTransferPendingOperation.Kind = route == .send ? .send : .claim
            guard let operation = try pending.load(),
                  operation.kind == expected,
                  let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                  object["idempotencyKey"] as? String == operation.idempotencyKey else {
                throw FreeExploreLaunchFailure.disabled
            }
        }
        try Task.checkCancellation()
        guard isCurrent, permitsWrites() else { throw FreeExploreLaunchFailure.disabled }
        let result = try await underlying.send(request)
        guard isCurrent, permitsWrites() else { throw FreeExploreLaunchFailure.outcomeUnknown }
        observe(result)
        return result
    }

    /// 403 or business 409 LOGIN_REQUIRED retires the permission. The pending record is never touched here.
    /// A matching 401 is left for the client's session-expiry callback.
    private func observe(_ result: (Data, Int)) {
        if result.1 == 403 { denied(); return }
        guard result.0.count <= 1_048_576,
              let envelope = try? JSONSerialization.jsonObject(with: result.0) as? [String: Any] else { return }
        if envelope["code"] as? Int == 403 || envelope["businessCode"] as? String == BundleTransferBusinessCode.loginRequired {
            denied()
        }
    }
}
