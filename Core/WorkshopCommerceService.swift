import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// An isolated, exact-route transport. Never broadens CompositionHTTPTransport's legacy grants.
/// HTTPS, no redirects, no shared cookie/cache persistence. Every request rechecks the current grant and account lease.
@MainActor public final class WorkshopCommerceService: WorkshopCommerceServing {
    private let lease: ContentDraftSessionLease
    private let approval: WorkshopCommerceApproval
    private let currentApproval: () -> WorkshopCommerceApproval?
    private let session: URLSession
    private let readOnly: Bool
    private var revoked = false
    private let onUnauthorized: (RuntimeDependencyContext) -> Void
    private final class NoRedirects: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
    }
    public init(lease: ContentDraftSessionLease, approval: WorkshopCommerceApproval,
                currentApproval: @escaping () -> WorkshopCommerceApproval?, readOnly: Bool = false, onUnauthorized: @escaping (RuntimeDependencyContext) -> Void = { _ in }) throws {
        guard approval.matches(lease.context), lease.context.baseURL.scheme == "https", currentApproval()?.revision == approval.revision else { throw WorkshopCommerceIssue.disabled }
        self.readOnly = readOnly; self.lease = lease; self.approval = approval; self.currentApproval = currentApproval; self.onUnauthorized = onUnauthorized
        let config = URLSessionConfiguration.ephemeral; config.httpCookieStorage = nil; config.urlCache = nil; config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config, delegate: NoRedirects(), delegateQueue: nil)
    }
    public func invalidate() { revoked = true; session.invalidateAndCancel() }
    public var canAcquire: Bool { !readOnly && (try? check()) != nil && approval.digitalPurchaseApprovalReference?.isEmpty == false }
    public var canCancelOrder: Bool { !readOnly && (try? check()) != nil && approval.cancellationApprovalReference != nil }
    public var canReadOwnedRelease: Bool { (try? check()) != nil && approval.ownedReleaseReadApprovalReference != nil }
    public func ownedReleaseRecord(_ licenseID: String) async throws -> WorkshopOwnedReleaseRecord {
        guard canReadOwnedRelease else { throw WorkshopCommerceIssue.disabled }
        return try await send("licenses/" + key(licenseID) + "/release-record")
    }
    public var canReadReversalStatus: Bool { (try? check()) != nil && approval.reversalStatusReadApprovalReference != nil }
    public func reversalStatus(_ orderKey: String) async throws -> WorkshopBuyerReversalStatus {
        guard canReadReversalStatus else { throw WorkshopCommerceIssue.disabled }
        return try await send("orders/" + key(orderKey) + "/reversal-status")
    }
    public func permitsPurchase(_ offer: WorkshopCommerceOffer) -> Bool { canAcquire && approval.permits(offer) }
    public func checkSession() throws { try check() }
    private func check() throws {
        try Task.checkCancellation()
        guard !revoked, lease.isCurrent else { throw WorkshopCommerceIssue.staleSession }
        guard let latest = currentApproval(), latest.revision == approval.revision, latest.matches(lease.context), approval.matches(lease.context) else { throw WorkshopCommerceIssue.disabled }
    }
    private func key(_ value: String) throws -> String {
        guard value.range(of: #"\A[A-Za-z0-9_-]{1,128}\z"#, options: .regularExpression) != nil else { throw WorkshopCommerceIssue.invalid }; return value
    }
    public func offers(before: String? = nil) async throws -> [WorkshopCommerceOffer] {
        if let before { return try await send("offers?before=" + key(before)) }
        return try await send("offers")
    }
    public func offer(_ id: String) async throws -> WorkshopCommerceOffer { try await send("offers/" + key(id)) }
    public func create(_ intent: WorkshopCommerceIntent, offer: WorkshopCommerceOffer) async throws -> WorkshopCommerceOrder {
        try check(); guard approval.permits(offer), intent.offerId == offer.offerId, intent.termsHash == offer.terms.hash else { throw WorkshopCommerceIssue.disabled }
        return try await send("orders", method: "POST", body: JSONEncoder().encode(intent))
    }
    public func lookupRequest(_ id: String) async throws -> WorkshopCommercePurchaseLookup { try await send("orders/by-request/" + key(id) + "/lookup") }
    public func readRequest(_ id: String) async throws -> WorkshopCommerceOrder { try await send("orders/by-request/" + key(id)) }
    public func orderOffer(_ key: String) async throws -> WorkshopCommerceOffer { try await send("orders/" + self.key(key) + "/offer") }
    public func order(_ key: String) async throws -> WorkshopCommerceOrder { try await send("orders/" + self.key(key)) }
    public func startPayment(_ order: WorkshopCommerceOrder, offer: WorkshopCommerceOffer) async throws -> WorkshopCommerceOrder {
        try check(); guard approval.permits(offer), order.offerId == offer.offerId, order.amountMinor == offer.priceMinor, order.currency == offer.currency else { throw WorkshopCommerceIssue.disabled }
        return try await send("orders/" + key(order.orderKey) + "/payment", method: "POST")
    }
    public func nativeContext(_ order: WorkshopCommerceOrder) async throws -> [String: String] {
        try await send("orders/" + key(order.orderKey) + "/native-context")
    }
    public func nativeDispatch(_ order: WorkshopCommerceOrder, offer: WorkshopCommerceOffer) async throws -> Bool {
        try check(); guard approval.permits(offer), order.offerId == offer.offerId,
            order.state == .nativeReady, !order.cancellationRequested else { throw WorkshopCommerceIssue.disabled }
        let value: WorkshopCommerceNativeDispatch = try await send("orders/" + key(order.orderKey) + "/native-dispatch", method: "POST")
        guard value.orderKey == order.orderKey else { throw WorkshopCommerceIssue.malformed }
        return value.dispatchAllowed
    }
    public func restoreNative(signedTransaction: String) async throws -> WorkshopCommerceOrder {
        try check(); guard !signedTransaction.isEmpty, signedTransaction.utf8.count <= 131072 else { throw WorkshopCommerceIssue.invalid }
        struct Body: Encodable { let signedTransaction: String }
        return try await send("native-transactions/restore", method: "POST", body: JSONEncoder().encode(Body(signedTransaction: signedTransaction)))
    }
    public func nativeTransaction(_ order: WorkshopCommerceOrder, signedTransaction: String) async throws -> WorkshopCommerceOrder {
        try check()
        guard !approval.readApprovalReference.isEmpty, !signedTransaction.isEmpty,
              signedTransaction.utf8.count <= 131072 else { throw WorkshopCommerceIssue.disabled }
        struct Body: Encodable { let signedTransaction: String }
        return try await send("orders/" + key(order.orderKey) + "/native-transaction", method: "POST", body: JSONEncoder().encode(Body(signedTransaction: signedTransaction)))
    }
    /// The owner-scoped backend license is the authority. Local StoreKit verification never substitutes for it.
    public func verifiedLicense(_ order: WorkshopCommerceOrder, offer: WorkshopCommerceOffer, requireActive: Bool = true) async throws -> WorkshopCommerceLicense {
        try check()
        guard (order.state == .paid || order.state == .acquiredFree), let id = order.licenseId,
              order.offerId == offer.offerId, order.amountMinor == offer.priceMinor,
              order.currency == offer.currency else { throw WorkshopCommerceIssue.malformed }
        let value = try await license(id)
        _ = try WorkshopCommerceLicenseSnapshot(license: value, order: order, offer: offer)
        guard !requireActive || value.status == "ACTIVE" else { throw WorkshopCommerceIssue.malformed }
        try check(); return value
    }
    public func reconcile(_ key: String) async throws -> WorkshopCommerceOrder { try await send("orders/" + self.key(key) + "/reconcile", method: "POST") }
    public func cancelRequest(_ intent: WorkshopCommerceIntent) async throws -> WorkshopCommerceOrder { try await send("orders/by-request/cancel", method: "POST", body: JSONEncoder().encode(intent)) }
    public func cancel(_ key: String) async throws -> WorkshopCommerceOrder { try await send("orders/" + self.key(key) + "/cancel", method: "POST") }
    public func licenses(before: String? = nil) async throws -> [WorkshopCommerceLicense] {
        if let before { return try await send("licenses?before=" + key(before)) }
        return try await send("licenses")
    }
    public func license(_ id: String) async throws -> WorkshopCommerceLicense { try await send("licenses/" + key(id)) }
    /// This returns only a reservation, never a published or installed-content success.
    public func reserve(_ command: WorkshopCommerceInstall) async throws -> WorkshopCommerceReservation {
        try check(); guard approval.installApprovalReference?.isEmpty == false else { throw WorkshopCommerceIssue.disabled }
        return try await send("install-reservations", method: "POST", body: JSONEncoder().encode(command))
    }
    public func release(licenseId: String, requestId: String) async throws -> WorkshopCommerceReservation {
        try await send("licenses/" + key(licenseId) + "/install-reservations/" + key(requestId) + "/release", method: "POST")
    }
    private struct Envelope<T: Decodable>: Decodable { let code: Int; let data: T? }
    private struct Code: Decodable { let code: Int }
    private func send<T: Decodable>(_ route: String, method: String = "GET", body: Data? = nil) async throws -> T {
        try check()
        guard !readOnly || (method == "GET" && body == nil) else { throw WorkshopCommerceIssue.disabled }
        if method == "POST" && route.hasSuffix("/cancel") { guard canCancelOrder else { throw WorkshopCommerceIssue.disabled } }
        if route.hasSuffix("/release-record") { guard canReadOwnedRelease else { throw WorkshopCommerceIssue.disabled } }
        if route.hasSuffix("/reversal-status") { guard canReadReversalStatus else { throw WorkshopCommerceIssue.disabled } }
        let parts = route.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        var components = URLComponents(url: lease.context.baseURL.appendingPathComponent("api/mod-commerce/" + String(parts[0])), resolvingAgainstBaseURL: false)
        if parts.count == 2 { components?.percentEncodedQuery = String(parts[1]) }
        guard let url = components?.url else { throw WorkshopCommerceIssue.invalid }
        var request = URLRequest(url: url); request.httpMethod = method
        request.httpBody = body; request.setValue(lease.context.session.token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control"); request.cachePolicy = .reloadIgnoringLocalCacheData
        try check(); let (data, response) = try await session.data(for: request); try check()
        guard let http = response as? HTTPURLResponse, data.count <= 524288, let text = String(data: data, encoding: .utf8),
              (try? ContentDraftJSON.parse(text)) != nil else { throw WorkshopCommerceIssue.malformed }
        let code = try? JSONDecoder().decode(Code.self, from: data).code
        if http.statusCode == 401 || code == 401 { try check(); onUnauthorized(lease.context); throw WorkshopCommerceIssue.unauthorized }
        guard (200..<300).contains(http.statusCode), code == 200 else { throw WorkshopCommerceIssue.unavailable }
        guard let result = try JSONDecoder().decode(Envelope<T>.self, from: data).data else { throw WorkshopCommerceIssue.malformed }; try check(); return result
    }
}
