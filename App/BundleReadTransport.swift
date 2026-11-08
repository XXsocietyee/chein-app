import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Read-only allow-list for the order screens (IWP-2). Unmounted: IWP-9 decides where it is composed.
/// Copy of the `FreeExploreBundleReadTransport` idea with the extra `order/receipt` route, kept in its own
/// file so the existing read host stays untouched. Exactly two GET routes, nothing else:
///   GET api/free-explore/bundle/order?registrationId=<bound id>
///   GET api/free-explore/bundle/order/receipt?requestId=<bound id>
/// `Authorization` must equal the captured session token. A 403 retires the permission; a matching 401 is left
/// to the client (`BundleAPIClient`) which calls the session-expiry callback.
@MainActor final class BundleReadTransport: HTTPTransport {
    private let baseURL: URL
    private let authorization: String
    private let registrationID: FreeExploreLaunchID
    private let receiptRequestIDs: Set<String>
    private let underlying: any HTTPTransport
    private let current: () -> Bool
    private let denied: () -> Void
    private var active = true
    private static let responseCap = 1_048_576

    init(baseURL: URL, authorization: String, registrationID: FreeExploreLaunchID, receiptRequestIDs: Set<String> = [],
         underlying: any HTTPTransport, current: @escaping () -> Bool, denied: @escaping () -> Void) throws {
        guard AuthRequestBuilder.isValidToken(authorization) else { throw FreeExploreLaunchFailure.invalid }
        self.baseURL = baseURL; self.authorization = authorization; self.registrationID = registrationID
        self.receiptRequestIDs = Set(receiptRequestIDs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) })
        self.underlying = underlying; self.current = current; self.denied = denied
    }

    var isCurrent: Bool { active && current() }
    func retire() { active = false }

    private func allowedURLs() -> Set<String> {
        func make(_ path: String, _ name: String, _ value: String) -> String? {
            var components = URLComponents(url: baseURL.appendingPathComponent("api/free-explore/bundle/" + path),
                                           resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: name, value: value)]
            return components?.url?.absoluteString
        }
        var urls = Set<String>()
        if let order = make("order", "registrationId", registrationID.text) { urls.insert(order) }
        for id in receiptRequestIDs {
            if let receipt = make("order/receipt", "requestId", id) { urls.insert(receipt) }
        }
        return urls
    }

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        try Task.checkCancellation()
        guard active, current(), request.httpMethod == "GET", request.httpBody == nil, request.httpBodyStream == nil,
              request.value(forHTTPHeaderField: "Authorization") == authorization,
              let url = request.url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.user == nil, components.password == nil, components.fragment == nil,
              allowedURLs().contains(url.absoluteString) else { throw APIError.notConfigured }
        let result = try await underlying.send(request)
        try Task.checkCancellation()
        guard active, current() else { throw APIError.notConfigured }
        guard result.0.count <= Self.responseCap else { throw FreeExploreLaunchFailure.malformed }
        let bodyCode = (try? JSONSerialization.jsonObject(with: result.0) as? [String: Any])?["code"] as? Int
        if result.1 == 403 || bodyCode == 403 { active = false; denied(); throw APIError.notConfigured }
        return result
    }
}
