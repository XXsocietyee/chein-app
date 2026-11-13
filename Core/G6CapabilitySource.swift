import Foundation
import CoreFoundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// Capability gap G6: NPC/AI, creator/publishing, marketing/products (player).
// Source: hengyin `chengyinhub-xcx` `92eda912` (`pages/roam/index.js`, `utils/roam-npc-coordinator.js`,
// `utils/npc-roam-gate.js`, `pages/topic/index/index.js`, `pages/publish/simple/index.js`,
// `pages/publish/utils/ai-theme-draft-journal.js`, `pages/activity/utils/quote-view.js`,
// `subpackageA/utils/revenue-view.js`, `subpackageMember/market/pass/index.js`, `utils/author-write-recovery.js`,
// `subpackageMember/components/cy/npc-chat/index.js`).
// Reads and the two non-money AI draft writes only. Attribution claim, platform-pass order reads, quote, order,
// pay, and gift claim are not methods on this type.

public enum G6Refusal: Error, Equatable, Sendable {
    case invalidRequest
    case notAdmitted
}

/// One G6 call. `ok` is HTTP 2xx with business code 200. A transport failure is `netFail`.
public struct G6Envelope: Equatable, Sendable {
    public let httpStatus: Int?
    public let code: String?
    public let reasonCode: String?
    public let message: String?
    public let dataJSON: Data?
    public let netFail: Bool

    public init(httpStatus: Int?, code: String?, reasonCode: String?, message: String?, dataJSON: Data?, netFail: Bool) {
        self.httpStatus = httpStatus
        self.code = code
        self.reasonCode = reasonCode
        self.message = message
        self.dataJSON = dataJSON
        self.netFail = netFail
    }

    public var ok: Bool {
        guard let httpStatus, (200...299).contains(httpStatus), code == "200" else { return false }
        return true
    }

    /// The decoded `data` value, or nil when it was missing or JSON null.
    public var data: Any? {
        guard let dataJSON else { return nil }
        return try? JSONSerialization.jsonObject(with: dataJSON, options: [.fragmentsAllowed])
    }

    public static let networkFailure = G6Envelope(httpStatus: nil, code: "fail", reasonCode: nil, message: nil,
                                                  dataJSON: nil, netFail: true)
}

public struct G6CapabilitySource {
    public static let sourceRevision = "92eda912"

    /// Every path this type can build. The China production gate still decides which of them leave the device.
    public static let paths: [String] = [
        "/api/ai/npc/profile",
        "/api/ai/npc/event",
        "/api/ai/npc/chat",
        "/api/ai/npc/chat/request",
        "/api/ai/theme/draft/prepare",
        "/api/ai/theme/draft/execute",
        "/api/ai/theme/draft/request",
        "/api/ai/theme/draft/recovery",
        "/api/author-write/receipt",
        "/api/marketing/promotions/catalog",
        "/api/marketing/revenue/author/mine",
        "/api/marketing/product/{}"
    ]

    /// Listed G6 paths that stay hidden: no method builds them.
    public static let hiddenPaths: [String] = [
        "/api/marketing/attribution/claim",
        "/api/platform-pass/orders/{}"
    ]

    private static let blocked = ["pay", "order", "quote", "claim", "attribution", "withdraw", "payout", "redeem", "wallet", "gifts"]

    private let configuration: APIConfiguration
    private let transport: any HTTPTransport

    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    // MARK: NPC

    /// GET `/api/ai/npc/profile?scope=global` (roam prompt layer).
    public func npcGlobalProfile(token: String) async throws -> G6Envelope {
        try await send("GET", "/api/ai/npc/profile", query: [("scope", "global")], body: nil, token: token)
    }

    /// GET `/api/ai/npc/profile?scope=node&nodeId=` (topic main characters). Only reviewed NPCs come back.
    public func npcNodeProfiles(nodeID: Int, token: String) async throws -> G6Envelope {
        guard nodeID > 0 else { throw G6Refusal.invalidRequest }
        return try await send("GET", "/api/ai/npc/profile", query: [("scope", "node"), ("nodeId", String(nodeID))], body: nil, token: token)
    }

    /// GET `/api/ai/npc/event`. `cacheOnly=true` is always sent so a missing reviewed line never falls back to the greeting.
    public func npcEventLine(profileID: String, eventType: String, token: String) async throws -> G6Envelope {
        guard !profileID.isEmpty, G6RoamNPCGate.quota[eventType] != nil else { throw G6Refusal.invalidRequest }
        return try await send("GET", "/api/ai/npc/event",
                              query: [("profileId", profileID), ("eventType", eventType), ("cacheOnly", "true")], body: nil, token: token)
    }

    /// POST `/api/ai/npc/chat` (roam track of the shared chat shell). The mini program never mounts this track.
    public func npcChat(requestID: String, bizID: Int, message: String, token: String) async throws -> G6Envelope {
        guard G6NPCChat.isRequestID(requestID), bizID > 0 else { throw G6Refusal.invalidRequest }
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.unicodeScalars.count <= G6NPCChat.maxMessageCodePoints else { throw G6Refusal.invalidRequest }
        let body = try Self.json(["requestId": requestID, "bizId": NSNumber(value: bizID), "message": text])
        return try await send("POST", "/api/ai/npc/chat", query: [], body: body, token: token)
    }

    /// GET `/api/ai/npc/chat/request`: read back one unconfirmed question by its request id. Never resends.
    public func npcChatRequest(requestID: String, scope: String, bizID: Int, token: String) async throws -> G6Envelope {
        guard G6NPCChat.isRequestID(requestID), ["roam", "merchant"].contains(scope), bizID > 0 else { throw G6Refusal.invalidRequest }
        return try await send("GET", "/api/ai/npc/chat/request",
                              query: [("requestId", requestID), ("scope", scope), ("bizId", String(bizID))], body: nil, token: token)
    }

    // MARK: AI theme draft (V2)

    /// POST `/api/ai/theme/draft/prepare` `{prepareKey, idea, productType}`.
    public func aiDraftPrepare(prepareKey: String, idea: String, productType: Int, token: String) async throws -> G6Envelope {
        guard G6AIThemeDraft.isUUID(prepareKey), [1, 2].contains(productType) else { throw G6Refusal.invalidRequest }
        let text = idea.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw G6Refusal.invalidRequest }
        let body = try Self.json(["prepareKey": prepareKey, "idea": text, "productType": NSNumber(value: productType)])
        return try await send("POST", "/api/ai/theme/draft/prepare", query: [], body: body, token: token)
    }

    /// POST `/api/ai/theme/draft/execute` `{requestId}` with the server request id from prepare.
    public func aiDraftExecute(requestID: String, token: String) async throws -> G6Envelope {
        guard G6AIThemeDraft.isServerID(requestID) else { throw G6Refusal.invalidRequest }
        let body = try Self.json(["requestId": requestID])
        return try await send("POST", "/api/ai/theme/draft/execute", query: [], body: body, token: token)
    }

    /// GET `/api/ai/theme/draft/request` by request id, or by prepare key while the prepare answer is unconfirmed.
    public func aiDraftRequest(requestID: String?, prepareKey: String?, token: String) async throws -> G6Envelope {
        if let requestID {
            guard G6AIThemeDraft.isServerID(requestID) || G6AIThemeDraft.isUUID(requestID) else { throw G6Refusal.invalidRequest }
            return try await send("GET", "/api/ai/theme/draft/request", query: [("requestId", requestID)], body: nil, token: token)
        }
        guard let prepareKey, G6AIThemeDraft.isUUID(prepareKey) else { throw G6Refusal.invalidRequest }
        return try await send("GET", "/api/ai/theme/draft/request", query: [("prepareKey", prepareKey)], body: nil, token: token)
    }

    /// GET `/api/ai/theme/draft/recovery` (newest first, `beforeId` pages older).
    public func aiDraftRecovery(beforeID: String?, token: String) async throws -> G6Envelope {
        if let beforeID {
            guard G6AIThemeDraft.cursor(beforeID) != nil else { throw G6Refusal.invalidRequest }
            return try await send("GET", "/api/ai/theme/draft/recovery", query: [("beforeId", beforeID)], body: nil, token: token)
        }
        return try await send("GET", "/api/ai/theme/draft/recovery", query: [], body: nil, token: token)
    }

    // MARK: Creator

    /// GET `/api/author-write/receipt?operation=&requestId=`: only an explicit retry of a saved author write reads this.
    public func authorWriteReceipt(operation: String, requestID: String, token: String) async throws -> G6Envelope {
        guard G6AuthorWrite.isOperation(operation), !requestID.isEmpty, requestID.utf8.count <= 128 else { throw G6Refusal.invalidRequest }
        return try await send("GET", "/api/author-write/receipt", query: [("operation", operation), ("requestId", requestID)],
                              body: nil, token: token)
    }

    // MARK: Marketing reads

    /// GET `/api/marketing/promotions/catalog?ownerType=2&ownerId=` (activity sign-up).
    public func promotionCatalog(activityID: Int, token: String) async throws -> G6Envelope {
        guard activityID > 0 else { throw G6Refusal.invalidRequest }
        return try await send("GET", "/api/marketing/promotions/catalog",
                              query: [("ownerType", "2"), ("ownerId", String(activityID))], body: nil, token: token)
    }

    /// GET `/api/marketing/revenue/author/mine` (the caller's own allocation lines).
    public func authorRevenue(token: String) async throws -> G6Envelope {
        try await send("GET", "/api/marketing/revenue/author/mine", query: [], body: nil, token: token)
    }

    /// GET `/api/marketing/product/{id}`. Only a numeric or opaque id is addressed.
    public func marketingProduct(id: String, token: String) async throws -> G6Envelope {
        guard Self.productIDAllowed(id) else { throw G6Refusal.invalidRequest }
        return try await send("GET", "/api/marketing/product/" + id, query: [], body: nil, token: token)
    }

    public static func productIDAllowed(_ id: String) -> Bool {
        guard !id.isEmpty, id.utf8.count <= 40, !id.contains("/") else { return false }
        return ChinaReviewedRouteCapability.normalized("/api/marketing/product/" + id) == "/api/marketing/product/{}"
    }

    // MARK: Send

    private func send(_ method: String, _ path: String, query: [(String, String)], body: Data?, token: String) async throws -> G6Envelope {
        guard AuthRequestBuilder.isValidToken(token) else { throw G6Refusal.invalidRequest }
        let request = try make(method: method, path: path, query: query, token: token, body: body)
        try admit(request)
        do {
            let (data, status) = try await transport.send(request)
            return Self.envelope(data: data, status: status)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return .networkFailure
        }
    }

    private func admit(_ request: URLRequest) throws {
        guard let url = request.url else { throw G6Refusal.notAdmitted }
        let base = configuration.baseURL.path.hasSuffix("/") ? String(configuration.baseURL.path.dropLast()) : configuration.baseURL.path
        guard url.path == base || url.path.hasPrefix(base + "/") else { throw G6Refusal.notAdmitted }
        let key = ChinaReviewedRouteCapability.normalized(String(url.path.dropFirst(base.count)))
        guard Self.paths.contains(key), !Self.blocked.contains(where: { key.split(separator: "/").contains(Substring($0)) }) else {
            throw G6Refusal.notAdmitted
        }
        do {
            try ChinaReviewedRouteCapability.refuseUnwiredChinaProduction(request)
        } catch {
            throw G6Refusal.notAdmitted
        }
    }

    private func make(method: String, path: String, query: [(String, String)], token: String, body: Data?) throws -> URLRequest {
        let url = path.split(separator: "/").reduce(configuration.baseURL) { partial, part in
            partial.appendingPathComponent(String(part))
        }
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { throw G6Refusal.invalidRequest }
        if !query.isEmpty { parts.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) } }
        guard let final = parts.url else { throw G6Refusal.invalidRequest }
        var request = URLRequest(url: final)
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = path == "/api/ai/npc/chat" ? 30 : 20
        request.httpShouldHandleCookies = false
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        return request
    }

    public static func envelope(data: Data, status: Int) -> G6Envelope {
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let code = object.flatMap { G6JSON.codeString($0["code"]) } ?? String(status)
        let reason = object?["reasonCode"] as? String
        let message = object?["msg"] as? String
        return G6Envelope(httpStatus: status, code: code, reasonCode: reason, message: message,
                          dataJSON: G6JSON.data(object?["data"]), netFail: false)
    }

    static func json(_ fields: [String: Any]) throws -> Data {
        guard JSONSerialization.isValidJSONObject(fields),
              let data = try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]) else {
            throw G6Refusal.invalidRequest
        }
        return data
    }
}

/// JSON helpers shared by the G6 projections. Booleans are never numbers here.
enum G6JSON {
    static func number(_ value: Any?) -> NSNumber? {
        guard let number = value as? NSNumber else { return nil }
        if CFGetTypeID(number as CFTypeRef) == CFBooleanGetTypeID() { return nil }
        guard number.doubleValue.isFinite else { return nil }
        return number
    }

    /// Mini-program `isNum`: a finite number or numeric string. Null, empty, and booleans are not numbers.
    static func numeric(_ value: Any?) -> Double? {
        if let number = number(value) { return number.doubleValue }
        guard let text = value as? String, !text.isEmpty else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        guard let double = Double(trimmed), double.isFinite else { return nil }
        return double
    }

    static func integer(_ value: Any?) -> Int? {
        guard let number = number(value) else { return nil }
        let double = number.doubleValue
        guard double.rounded() == double, abs(double) <= 9_007_199_254_740_991 else { return nil }
        return Int(double)
    }

    static func text(_ value: Any?) -> String? {
        if let text = value as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let whole = integer(value) { return String(whole) }
        return nil
    }

    static func codeString(_ value: Any?) -> String? {
        if let text = value as? String { return text }
        guard let whole = integer(value) else { return nil }
        return String(whole)
    }

    static func data(_ value: Any?) -> Data? {
        guard let value, !(value is NSNull) else { return nil }
        if JSONSerialization.isValidJSONObject(value) {
            return try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        }
        return try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .fragmentsAllowed])
    }

    /// Mini-program `toFixed(2)` on a finite value.
    static func fixedTwo(_ value: Double) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    /// Milliseconds since 1970 for `yyyy-MM-dd HH:mm:ss` (China time), ISO strings, or numbers. Nil when unreadable.
    static func timestamp(_ value: Any?) -> Int64? {
        if let text = value as? String { return MoneyParityTime.timestamp(text) }
        if let number = number(value) { return MoneyParityTime.timestamp(number: number.doubleValue) }
        return nil
    }

    /// `yyyy.MM.dd` in China time, or nil.
    static func dotDay(_ value: Any?) -> String? {
        guard let ms = timestamp(value) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        let date = Date(timeIntervalSince1970: TimeInterval(ms + MoneyParityTime.chinaOffsetMs) / 1000)
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
        return String(format: "%04d.%02d.%02d", year, month, day)
    }
}
