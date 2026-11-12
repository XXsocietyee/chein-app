import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// GET allow-list for the mounted bundle screens. It never accepts a body, a POST, or a second registration.
/// Payment, payout, withdrawal, and virtual-goods URLs are not in the list.
@MainActor final class BundleCommerceReadTransport: HTTPTransport {
    private let context: RuntimeDependencyContext
    private let allowed: Set<String>
    private let underlying: any HTTPTransport
    private let current: () -> Bool
    private let denied: () -> Void
    private var active = true

    init(context: RuntimeDependencyContext, allowed: [String], underlying: any HTTPTransport,
         current: @escaping () -> Bool, denied: @escaping () -> Void) {
        self.context = context
        self.allowed = Set(allowed)
        self.underlying = underlying
        self.current = current
        self.denied = denied
    }

    func retire() { active = false }

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        try Task.checkCancellation()
        guard active, current(), request.httpMethod == "GET", request.httpBody == nil, request.httpBodyStream == nil,
              request.value(forHTTPHeaderField: "Authorization") == context.session.token,
              let url = request.url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.user == nil, components.password == nil, components.fragment == nil,
              allowed.contains(url.absoluteString) else { throw APIError.notConfigured }
        let result = try await underlying.send(request)
        try Task.checkCancellation()
        guard active, current() else { throw APIError.notConfigured }
        let bodyCode = (try? JSONSerialization.jsonObject(with: result.0) as? [String: Any])?["code"] as? Int
        if result.1 == 403 || bodyCode == 403 {
            active = false
            denied()
            throw APIError.notConfigured
        }
        return result
    }

    static func orderURL(base: URL, registrationID: FreeExploreLaunchID) -> String? {
        absolute(base: base, path: "order", query: [URLQueryItem(name: "registrationId", value: registrationID.text)])
    }

    static func refundQuoteURL(base: URL, registrationID: FreeExploreLaunchID) -> String? {
        absolute(base: base, path: "order/refund-quote", query: [URLQueryItem(name: "registrationId", value: registrationID.text)])
    }

    static func cancelQuoteURLs(base: URL, reservationID: FreeExploreLaunchID) -> [String] {
        ["false", "true"].compactMap { flag in
            absolute(base: base, path: "reservation/\(reservationID.text)/cancel-quote",
                     query: [URLQueryItem(name: "useWaiver", value: flag)])
        }
    }

    private static func absolute(base: URL, path: String, query: [URLQueryItem]) -> String? {
        var parts = URLComponents(url: base.appendingPathComponent("api/free-explore/bundle/" + path), resolvingAgainstBaseURL: false)
        if !query.isEmpty { parts?.queryItems = query.sorted { $0.name < $1.name } }
        return parts?.url?.absoluteString
    }
}

/// Cancel screen tools. The canceler is constructed with writes off. The service can re-read the order only.
struct BundleCommerceCancelTools {
    let canceler: BundleCancelCanceler
    let service: any FreeExploreLaunchServing
}
