import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Backend-verified idempotency transport mechanism from `hengyin@067da9748`.
public enum BackendIdempotencyMechanism: Equatable, Codable, Sendable {
    /// JSON body string property (e.g. `requestId`, `idempotencyKey`, `request_id`).
    case jsonBodyKey(String)
    /// Form-urlencoded field or query/body field (e.g. `requestId`, `clientSessionKey`, `request_id`).
    case formFieldKey(String)
    /// HTTP request header idempotency key (e.g. `X-Club-Admission-Request-Id`).
    case requestHeader(String)
}

/// Catalog entry describing how a backend endpoint supports safe idempotent writes and optional receipt lookup.
public struct IdempotentWriteRouteSpec: Equatable, Sendable {
    public let method: String
    public let path: String
    public let mechanism: BackendIdempotencyMechanism
    public let receiptReadPath: String?
    public let isMoneyWrite: Bool

    public init(
        method: String = "POST",
        path: String,
        mechanism: BackendIdempotencyMechanism,
        receiptReadPath: String? = nil,
        isMoneyWrite: Bool = false
    ) {
        self.method = method.uppercased()
        self.path = ChinaReviewedRouteCapability.normalized(path)
        self.mechanism = mechanism
        self.receiptReadPath = receiptReadPath.map(ChinaReviewedRouteCapability.normalized)
        self.isMoneyWrite = isMoneyWrite
    }
}

/// Registry of backend write routes audited against `hengyin@067da9748` (`Api*Controller.java`).
/// Separates backend-idempotent non-money writes (eligible for durable offline queueing & replay with the
/// same stable idempotency key) from money/payout/withdrawal/commerce writes (NEVER auto-replayed).
public enum BackendIdempotentWriteRouteCatalog {
    public static let moneyOrCashSensitiveMarkers: [String] = [
        "/api/pay/", "/api/withdrawal/", "/api/asset/withdraw", "/api/wallet/",
        "/api/registration/pay", "/api/merchant/commerce/", "/api/marketing/group-checkout/",
        "/api/marketing/product/activate", "/api/club/settlement/", "/api/club/personal-receiver/",
        "/api/merchant/payout-account/", "/api/cart/", "/api/mod-commerce/", "/api/fund/preflight",
        "/api/coupon/publish", "/api/coupon/stop", "/api/coop/deposit/", "/api/invoice/",
        "/api/platform-pass/orders", "/api/rewards/noncash/claims/recover",
        "/api/ai/npc/voice-chat", "/api/video-bounty/accrual"
    ]

    /// True if `path` is a payment, payout, withdrawal, refund, deposit, settlement, coupon-lifecycle,
    /// invoice, or cash-adjacent mutation that MUST NEVER be automatically replayed.
    public static func isMoneyOrCashSensitiveWrite(_ rawPath: String) -> Bool {
        let path = ChinaReviewedRouteCapability.normalized(rawPath)
        if ReleaseMoneyWriteSwitch.kind(for: path) != nil { return true }
        let lower = path.lowercased()
        if moneyOrCashSensitiveMarkers.contains(where: { lower.hasPrefix($0) || lower == $0.dropLast() }) {
            return true
        }
        return lower.contains("/refund") || lower.contains("/payout") || lower.contains("/withdraw")
    }

    /// True when `request` targets a money/cash-sensitive route OR carries paid checkout parameters
    /// (for example `/api/registration/create` with `payChannel` or a positive payment amount).
    public static func isMoneyOrCashSensitiveRequest(_ request: URLRequest) -> Bool {
        guard let url = request.url else { return false }
        let path = ChinaReviewedRouteCapability.normalized(url.path)
        if isMoneyOrCashSensitiveWrite(path) { return true }
        if path == "/api/registration/create",
           let body = request.httpBody, !body.isEmpty,
           let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] {
            if let channel = object["payChannel"] as? String,
               !channel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return true
            }
            for key in ["payableAmount", "payAmount", "totalAmount"] {
                if let amount = (object[key] as? NSNumber)?.doubleValue, amount > 0 {
                    return true
                }
            }
        }
        return false
    }

    /// Verified non-money write routes whose backend controllers enforce idempotency on `hengyin@067da9748`.
    public static let nonMoneyIdempotentSpecs: [IdempotentWriteRouteSpec] = [
        // Roam & compliance
        .init(path: "/api/roam/presence-visibility", mechanism: .jsonBodyKey("requestId")),
        .init(path: "/api/roam/stamp/create", mechanism: .formFieldKey("idempotencyKey")),
        .init(path: "/api/roam/reveal", mechanism: .formFieldKey("clientSessionKey"), receiptReadPath: "/api/roam/session"),
        .init(path: "/api/capsules/create", mechanism: .jsonBodyKey("requestId"), receiptReadPath: "/api/capsules/receipt"),
        .init(path: "/api/exploration-goals/create", mechanism: .jsonBodyKey("requestId"), receiptReadPath: "/api/exploration-goals/receipt"),
        .init(path: "/api/compliance/consents", mechanism: .jsonBodyKey("requestId")),
        // Play & Orient
        .init(path: "/api/play/feedback/submit", mechanism: .jsonBodyKey("requestId")),
        .init(path: "/api/play/help/use", mechanism: .jsonBodyKey("requestId")),
        .init(path: "/api/play/help/skip", mechanism: .jsonBodyKey("requestId")),
        .init(path: "/api/play/help/shared", mechanism: .jsonBodyKey("requestId")),
        .init(path: "/api/play/advanced/action", mechanism: .jsonBodyKey("idempotencyKey"), receiptReadPath: "/api/play/advanced/receipt"),
        .init(path: "/api/play/orient/session/prepare", mechanism: .jsonBodyKey("idempotencyKey")),
        .init(path: "/api/play/orient/session/start", mechanism: .jsonBodyKey("idempotencyKey")),
        .init(path: "/api/play/orient/session/abandon", mechanism: .jsonBodyKey("idempotencyKey")),
        .init(path: "/api/orient/scoring/appeal", mechanism: .jsonBodyKey("idempotencyKey")),
        .init(path: "/api/orient/scoring/dispute", mechanism: .jsonBodyKey("idempotencyKey")),
        .init(path: "/api/orient/task/alternative/submit", mechanism: .jsonBodyKey("idempotencyKey")),
        // Club & Governance
        .init(path: "/api/club", mechanism: .jsonBodyKey("requestId")),
        .init(path: "/api/club/events", mechanism: .jsonBodyKey("requestId")),
        .init(path: "/api/club/post/update", mechanism: .jsonBodyKey("requestId")),
        .init(path: "/api/club/roles/assign", mechanism: .jsonBodyKey("requestId"), receiptReadPath: "/api/club/roles/assign-receipt"),
        .init(path: "/api/club/roles/revoke", mechanism: .jsonBodyKey("requestId")),
        .init(path: "/api/club/crm/customers/tag-remark", mechanism: .jsonBodyKey("requestId")),
        .init(path: "/api/club/event-ops/series/create", mechanism: .jsonBodyKey("requestId")),
        .init(path: "/api/club/join", mechanism: .requestHeader("X-Club-Admission-Request-Id")),
        .init(path: "/api/club/quit", mechanism: .requestHeader("X-Club-Admission-Request-Id")),
        .init(path: "/api/club/open-settings/welcome-note", mechanism: .requestHeader("X-Club-Welcome-Request-Id")),
        .init(path: "/api/club/badge/create", mechanism: .requestHeader("X-Club-Badge-Request-Id")),
        .init(path: "/api/club/badge/grant", mechanism: .requestHeader("X-Club-Badge-Request-Id")),
        // Authoring, Topic & Creator (non-money)
        .init(path: "/api/ai/npc/chat", mechanism: .jsonBodyKey("requestId"), receiptReadPath: "/api/ai/npc/chat/request"),
        .init(path: "/api/ai/theme/draft/prepare", mechanism: .jsonBodyKey("requestId"), receiptReadPath: "/api/ai/theme/draft/request"),
        .init(path: "/api/ai/theme/draft/execute", mechanism: .jsonBodyKey("requestId"), receiptReadPath: "/api/ai/theme/draft/request"),
        .init(path: "/api/template/topic-template/use", mechanism: .jsonBodyKey("requestId"), receiptReadPath: "/api/author-write/receipt"),
        .init(path: "/api/template/draft", mechanism: .jsonBodyKey("requestId"), receiptReadPath: "/api/author-write/receipt"),
        .init(path: "/api/template/publish", mechanism: .jsonBodyKey("requestId"), receiptReadPath: "/api/author-write/receipt"),
        .init(path: "/api/template/author-requests/submit", mechanism: .jsonBodyKey("requestId")),
        .init(path: "/api/activity/create-requests/submit", mechanism: .jsonBodyKey("requestId")),
        .init(path: "/api/topic/attribute-author", mechanism: .requestHeader("X-Attribute-Request-Id")),
        .init(method: "DELETE", path: "/api/topic/attribute-author", mechanism: .requestHeader("X-Attribute-Request-Id")),
        .init(path: "/api/creator/maintenance/tickets", mechanism: .jsonBodyKey("requestId")),
        // Profile, Friend, External Game, Merchant Desk
        .init(path: "/api/user/address/action", mechanism: .jsonBodyKey("requestId")),
        .init(path: "/api/friend/metadata/settle", mechanism: .jsonBodyKey("request_id")),
        .init(path: "/api/friend/removal/settle", mechanism: .jsonBodyKey("request_id")),
        .init(path: "/api/external-game/submissions", mechanism: .jsonBodyKey("requestId")),
        .init(path: "/api/registration/create", mechanism: .jsonBodyKey("requestId")),
        .init(path: "/api/merchant/authoring/jobs/cancel", mechanism: .jsonBodyKey("requestId")),
        .init(path: "/api/merchant/authoring/releases", mechanism: .jsonBodyKey("requestId")),
    ]

    public static func idempotencySupport(for method: String, path: String) -> IdempotentWriteRouteSpec? {
        let normalizedPath = ChinaReviewedRouteCapability.normalized(path)
        let normalizedMethod = method.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if isMoneyOrCashSensitiveWrite(normalizedPath) { return nil }
        return nonMoneyIdempotentSpecs.first { $0.method == normalizedMethod && $0.path == normalizedPath }
    }
}

public enum OfflineWriteQueueError: Error, Equatable, Sendable {
    case moneyWriteNeverAutoReplayed
    case routeNotIdempotent
    case invalidScope
    case invalidRequest
    case storageCorrupt
    case unauthorized
}

/// Account + realm + deployment scope key for durable offline queue isolation.
public struct OfflineWriteQueueScope: Equatable, Hashable, Codable, Sendable {
    public let accountID: Int
    public let realm: String
    public let baseURL: String

    public init(accountID: Int, realm: String, baseURL: String) throws {
        let trimmedRealm = realm.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBase = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard accountID > 0, !trimmedRealm.isEmpty, !trimmedBase.isEmpty else {
            throw OfflineWriteQueueError.invalidScope
        }
        self.accountID = accountID
        self.realm = trimmedRealm
        self.baseURL = trimmedBase
    }

    public var storageKey: String {
        "\(accountID)|\(realm)|\(baseURL)"
    }
}

public enum OfflineQueuedWriteStatus: String, Codable, Equatable, Sendable {
    /// Failed before reaching the server (offline / DNS / unreachable) and carries a verified non-money idempotency key.
    case queuedOffline
    /// Request may have reached the server (`networkConnectionLost`, timeout, 5xx); locked against silent auto-replay.
    case waitingExplicitConfirmation
    /// Server returned a deterministic 4xx / business rejection; stopped cleanly.
    case rejected
}

public struct OfflineQueuedWriteItem: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let scopeKey: String
    public let method: String
    public let path: String
    public let idempotencyKey: String
    public let mechanism: BackendIdempotencyMechanism
    public let contentType: String?
    public let bodyBase64: String
    public let safeHeaders: [String: String]
    public let createdAt: Date
    public var status: OfflineQueuedWriteStatus
    public var attemptCount: Int
    public var lastError: String?

    public var bodyData: Data { Data(base64Encoded: bodyBase64) ?? Data() }
}

public struct OfflineWriteQueueFlushReport: Equatable, Sendable {
    public let succeededCount: Int
    public let remainingQueuedCount: Int
    public let lockedUnknownCount: Int
    public let rejectedCount: Int
    public let abortedUnauthorized: Bool
    public let succeededPaths: [String]

    public init(
        succeededCount: Int,
        remainingQueuedCount: Int,
        lockedUnknownCount: Int,
        rejectedCount: Int,
        abortedUnauthorized: Bool,
        succeededPaths: [String] = []
    ) {
        self.succeededCount = succeededCount
        self.remainingQueuedCount = remainingQueuedCount
        self.lockedUnknownCount = lockedUnknownCount
        self.rejectedCount = rejectedCount
        self.abortedUnauthorized = abortedUnauthorized
        self.succeededPaths = succeededPaths
    }
}

/// Captures pre-send unreachable `URLRequest`s from opted-in write actions without altering service return values or adding retries.
public struct OfflinePreSendCaptureBox: Sendable {
    private let recordHandler: @Sendable (URLRequest, Error) -> Void

    public init(onPreSendOffline: @escaping @Sendable (URLRequest, Error) -> Void) {
        self.recordHandler = onPreSendOffline
    }

    public func recordIfPreSendOffline(request: URLRequest, error: Error) {
        recordHandler(request, error)
    }
}

/// Task-local scope for screens opting their non-money idempotent write calls into `OfflineIdempotentWriteQueue`.
public enum OfflineWriteCaptureContext {
    @TaskLocal public static var current: OfflinePreSendCaptureBox?
}

/// Pass-through transport wrapper that notifies `OfflineWriteCaptureContext.current` on pre-send unreachable failures.
public struct OfflineWriteCaptureTransport: HTTPTransport {
    private let underlying: any HTTPTransport

    public init(underlying: any HTTPTransport) {
        self.underlying = underlying
    }

    public func send(_ request: URLRequest) async throws -> (Data, Int) {
        do {
            return try await underlying.send(request)
        } catch {
            if OfflineIdempotentWriteQueue.isPreSendUnreachable(error) {
                OfflineWriteCaptureContext.current?.recordIfPreSendOffline(request: request, error: error)
            }
            throw error
        }
    }
}

/// Durable account+realm-scoped queue for non-money backend-idempotent writes (`requestId`/`idempotencyKey`/`X-*-Request-Id`).
/// Money/payout writes are strictly refused and NEVER auto-replayed. No bearer tokens are stored on disk.
@MainActor
public final class OfflineIdempotentWriteQueue {
    private let fileURL: URL
    private let operationIDStore: (any ClientOperationIDStore)?
    private let now: () -> Date
    public private(set) var items: [OfflineQueuedWriteItem] = []
    public private(set) var lastBlockedMoneyRoute: String?

    public init(
        fileURL: URL,
        operationIDStore: (any ClientOperationIDStore)? = nil,
        now: @escaping () -> Date = Date.init
    ) throws {
        self.fileURL = fileURL
        self.operationIDStore = operationIDStore
        self.now = now
        try reload()
    }

    public func queuedItems(for scope: OfflineWriteQueueScope) -> [OfflineQueuedWriteItem] {
        items.filter { $0.scopeKey == scope.storageKey && $0.status == .queuedOffline }
    }

    public func pendingItems(for scope: OfflineWriteQueueScope) -> [OfflineQueuedWriteItem] {
        items.filter { $0.scopeKey == scope.storageKey }
    }

    /// Validates, ensures an idempotency key, and prepares a non-money write `URLRequest`.
    /// Throws `.moneyWriteNeverAutoReplayed` for any money route or `.routeNotIdempotent` if unsupported.
    public func prepareIdempotentRequest(
        _ request: URLRequest,
        scope: OfflineWriteQueueScope,
        explicitKey: String? = nil
    ) throws -> (request: URLRequest, key: String, spec: IdempotentWriteRouteSpec) {
        guard let url = request.url else { throw OfflineWriteQueueError.invalidRequest }
        let path = ChinaReviewedRouteCapability.normalized(url.path)
        let method = (request.httpMethod ?? "POST").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if BackendIdempotentWriteRouteCatalog.isMoneyOrCashSensitiveRequest(request) {
            lastBlockedMoneyRoute = path
            throw OfflineWriteQueueError.moneyWriteNeverAutoReplayed
        }
        guard let spec = BackendIdempotentWriteRouteCatalog.idempotencySupport(for: method, path: path) else {
            throw OfflineWriteQueueError.routeNotIdempotent
        }

        var outgoing = request
        let resolvedKey = try resolveOrInjectIdempotencyKey(on: &outgoing, spec: spec, scope: scope, explicitKey: explicitKey)
        outgoing.setValue(resolvedKey, forHTTPHeaderField: HTTPRequestRetrySupport.requestIDHeader)
        return (outgoing, resolvedKey, spec)
    }

    /// Enqueues a verified non-money idempotent write when offline or pre-flight unreachable.
    /// NEVER accepts money writes; deduplicates by `(scopeKey, method, path, idempotencyKey)`.
    @discardableResult
    public func enqueueOfflineWrite(
        _ request: URLRequest,
        scope: OfflineWriteQueueScope,
        explicitKey: String? = nil,
        status: OfflineQueuedWriteStatus = .queuedOffline
    ) throws -> OfflineQueuedWriteItem {
        let (prepared, key, spec) = try prepareIdempotentRequest(request, scope: scope, explicitKey: explicitKey)
        if let existing = items.first(where: {
            $0.scopeKey == scope.storageKey && $0.method == spec.method && $0.path == spec.path && $0.idempotencyKey == key
        }) {
            return existing
        }

        // Persist non-sensitive headers only; Authorization is NEVER persisted to disk.
        var filteredHeaders: [String: String] = [:]
        for (headerKey, headerValue) in prepared.allHTTPHeaderFields ?? [:] {
            if headerKey.caseInsensitiveCompare("Authorization") == .orderedSame { continue }
            filteredHeaders[headerKey] = headerValue
        }

        let item = OfflineQueuedWriteItem(
            id: UUID(),
            scopeKey: scope.storageKey,
            method: spec.method,
            path: spec.path,
            idempotencyKey: key,
            mechanism: spec.mechanism,
            contentType: prepared.value(forHTTPHeaderField: "Content-Type"),
            bodyBase64: (prepared.httpBody ?? Data()).base64EncodedString(),
            safeHeaders: filteredHeaders,
            createdAt: now(),
            status: status,
            attemptCount: 0,
            lastError: nil
        )
        items.append(item)
        try persist()
        return item
    }

    /// Replays `.queuedOffline` non-money idempotent writes for `scope` when online with the exact saved key & body.
    public func flushPending(
        scope: OfflineWriteQueueScope,
        configuration: APIConfiguration,
        token: String,
        currentScope: () -> OfflineWriteQueueScope?,
        isOnline: () -> Bool,
        transport: any HTTPTransport
    ) async throws -> OfflineWriteQueueFlushReport {
        guard AuthRequestBuilder.isValidToken(token) else { throw OfflineWriteQueueError.unauthorized }
        var succeeded = 0
        var succeededPaths: [String] = []
        var abortedUnauthorized = false

        let candidates = items.filter { $0.scopeKey == scope.storageKey && $0.status == .queuedOffline }
        for item in candidates {
            try Task.checkCancellation()
            guard currentScope() == scope, isOnline() else { break }

            // Belt-and-suspenders money exclusion check on replay even for persisted disk entries.
            if BackendIdempotentWriteRouteCatalog.isMoneyOrCashSensitiveWrite(item.path) ||
                BackendIdempotentWriteRouteCatalog.idempotencySupport(for: item.method, path: item.path) == nil {
                lastBlockedMoneyRoute = item.path
                remove(id: item.id)
                continue
            }

            let targetURL = configuration.baseURL.appendingPathComponent(String(item.path.dropFirst()))
            var request = URLRequest(url: targetURL)
            request.httpMethod = item.method
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 20
            request.setValue(token, forHTTPHeaderField: "Authorization")
            for (headerKey, headerValue) in item.safeHeaders where headerKey.caseInsensitiveCompare("Authorization") != .orderedSame {
                request.setValue(headerValue, forHTTPHeaderField: headerKey)
            }
            request.setValue(item.idempotencyKey, forHTTPHeaderField: HTTPRequestRetrySupport.requestIDHeader)
            if let contentType = item.contentType, !contentType.isEmpty {
                request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            }
            if !item.bodyData.isEmpty {
                request.httpBody = item.bodyData
            }

            do {
                let (data, status) = try await transport.send(request)
                guard currentScope() == scope else { break }

                if status == 401 || HTTPRequestRetrySupport.isEnvelopeUnauthorized(data) {
                    abortedUnauthorized = true
                    break
                }
                if (200..<300).contains(status), Self.isEnvelopeSuccess(data) {
                    remove(id: item.id)
                    if let store = operationIDStore,
                       let existingID = store.existing(subject: scope.storageKey, object: item.path, body: item.bodyData) {
                        store.complete(existingID)
                    }
                    succeeded += 1
                    if !succeededPaths.contains(item.path) {
                        succeededPaths.append(item.path)
                    }
                } else if (400..<500).contains(status) || Self.isDefiniteBusinessRejection(data, status: status) {
                    update(id: item.id) {
                        $0.status = .rejected
                        $0.attemptCount += 1
                        $0.lastError = "HTTP \(status)"
                    }
                } else {
                    // Ambiguous 5xx / malformed reply after network dispatch: never blindly auto-replay again.
                    update(id: item.id) {
                        $0.status = .waitingExplicitConfirmation
                        $0.attemptCount += 1
                        $0.lastError = "HTTP \(status)"
                    }
                }
            } catch {
                if error is CancellationError { throw error }
                if let urlError = error as? URLError, Self.isPreSendUnreachable(urlError) {
                    update(id: item.id) {
                        $0.attemptCount += 1
                        $0.lastError = urlError.localizedDescription
                    }
                    break
                } else {
                    // Post-dispatch timeout / connection lost: outcome is unknown -> lock against auto-replay.
                    update(id: item.id) {
                        $0.status = .waitingExplicitConfirmation
                        $0.attemptCount += 1
                        $0.lastError = error.localizedDescription
                    }
                }
            }
        }

        try persist()
        let scoped = items.filter { $0.scopeKey == scope.storageKey }
        return OfflineWriteQueueFlushReport(
            succeededCount: succeeded,
            remainingQueuedCount: scoped.filter { $0.status == .queuedOffline }.count,
            lockedUnknownCount: scoped.filter { $0.status == .waitingExplicitConfirmation }.count,
            rejectedCount: scoped.filter { $0.status == .rejected }.count,
            abortedUnauthorized: abortedUnauthorized,
            succeededPaths: succeededPaths
        )
    }

    public func discardItem(id: UUID, scope: OfflineWriteQueueScope) throws {
        items.removeAll { $0.id == id && $0.scopeKey == scope.storageKey }
        try persist()
    }

    // MARK: - Helpers

    private func resolveOrInjectIdempotencyKey(
        on request: inout URLRequest,
        spec: IdempotentWriteRouteSpec,
        scope: OfflineWriteQueueScope,
        explicitKey: String?
    ) throws -> String {
        switch spec.mechanism {
        case .requestHeader(let headerName):
            if let existing = request.value(forHTTPHeaderField: headerName), HTTPRequestRetrySupport.isValidRequestID(existing) {
                return existing
            }
            let key = try mintKey(subject: scope.storageKey, path: spec.path, body: request.httpBody ?? Data(), explicitKey: explicitKey)
            request.setValue(key, forHTTPHeaderField: headerName)
            return key

        case .jsonBodyKey(let field):
            let contentType = (request.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
            if contentType.contains("application/x-www-form-urlencoded") {
                return try resolveOrInjectFormFieldKey(on: &request, field: field, path: spec.path, scope: scope, explicitKey: explicitKey)
            }
            var jsonObject: [String: Any] = [:]
            if let body = request.httpBody, !body.isEmpty {
                guard let parsed = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else {
                    throw OfflineWriteQueueError.invalidRequest
                }
                jsonObject = parsed
            }
            if let existing = jsonObject[field] as? String, HTTPRequestRetrySupport.isValidRequestID(existing) {
                if request.value(forHTTPHeaderField: "Content-Type") == nil {
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
                return existing
            }
            let key = try mintKey(subject: scope.storageKey, path: spec.path, body: request.httpBody ?? Data(), explicitKey: explicitKey)
            jsonObject[field] = key
            request.httpBody = try JSONSerialization.data(withJSONObject: jsonObject, options: [.sortedKeys])
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            return key

        case .formFieldKey(let field):
            return try resolveOrInjectFormFieldKey(on: &request, field: field, path: spec.path, scope: scope, explicitKey: explicitKey)
        }
    }

    private func resolveOrInjectFormFieldKey(
        on request: inout URLRequest,
        field: String,
        path: String,
        scope: OfflineWriteQueueScope,
        explicitKey: String?
    ) throws -> String {
        let bodyText = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        var components = URLComponents()
        components.percentEncodedQuery = bodyText
        var queryItems = components.queryItems ?? []
        if let existing = queryItems.first(where: { $0.name == field })?.value, HTTPRequestRetrySupport.isValidRequestID(existing) {
            return existing
        }
        let key = try mintKey(subject: scope.storageKey, path: path, body: request.httpBody ?? Data(), explicitKey: explicitKey)
        queryItems.append(URLQueryItem(name: field, value: key))
        components.queryItems = queryItems
        request.httpBody = Data((components.percentEncodedQuery ?? "").utf8)
        if request.value(forHTTPHeaderField: "Content-Type") == nil {
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        }
        return key
    }

    private func mintKey(subject: String, path: String, body: Data, explicitKey: String?) throws -> String {
        if let explicitKey, HTTPRequestRetrySupport.isValidRequestID(explicitKey) {
            return explicitKey
        }
        if let store = operationIDStore {
            let opID = try store.operationID(subject: subject, object: path, body: body)
            return opID.value
        }
        return UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    /// True ONLY for pre-send unreachable failures where the request never left the device (safe to auto-replay with idempotency key).
    /// Post-dispatch timeouts (`.timedOut`) and connection drops (`.networkConnectionLost`) return false and stay locked.
    nonisolated public static func isPreSendUnreachable(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return isPreSendUnreachable(urlError)
        }
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return false }
        return isPreSendUnreachable(URLError(URLError.Code(rawValue: nsError.code)))
    }

    nonisolated private static func isPreSendUnreachable(_ error: URLError) -> Bool {
        switch error.code {
        case .notConnectedToInternet, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff:
            return true
        default:
            return false
        }
    }

    private static func isEnvelopeSuccess(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        if let code = object["code"] as? Int { return code == 200 }
        if let code = object["code"] as? String { return code == "200" }
        return false
    }

    private static func isDefiniteBusinessRejection(_ data: Data, status: Int) -> Bool {
        guard (200..<300).contains(status),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = object["code"] as? Int else { return false }
        return (400..<500).contains(code)
    }

    private func remove(id: UUID) {
        items.removeAll { $0.id == id }
    }

    private func update(id: UUID, _ mutate: (inout OfflineQueuedWriteItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        mutate(&items[index])
    }

    private func reload() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { items = []; return }
        do {
            let data = try Data(contentsOf: fileURL)
            items = try JSONDecoder().decode([OfflineQueuedWriteItem].self, from: data)
        } catch {
            throw OfflineWriteQueueError.storageCorrupt
        }
    }

    private func persist() throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(items)
        try data.write(to: fileURL, options: .atomic)
    }
}
