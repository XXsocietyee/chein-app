import Foundation
import CryptoKit
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Author and player calls for hengyin `ApiExternalGameController` (game-import-review).
/// Monetization is always NONE. A lost response stays on the saved request id and is not a success.
public enum ExternalGameReviewPaths {
    public static let submissions = "/api/external-game/submissions"
    public static let mine = "/api/external-game/submissions/mine"
    public static let catalog = "/api/external-game/catalog"
    public static let signingKey = "/api/external-game/signing-key"
    public static let reports = "/api/external-game/reports"
    public static let monetization = "NONE"
    public static let removalNote = "A submission still pending is escalated after the server review window (default 3 days, reason REVIEW_TIMEOUT). A game that leaves the approved catalog is removed on the next launch. A report stays open until the server marks it resolved."

    public static func detail(_ id: String) -> String { "/api/external-game/submissions/\(id)" }
    public static func cancel(_ id: String) -> String { "/api/external-game/submissions/\(id)/cancel" }
    public static func resubmit(_ id: String) -> String { "/api/external-game/submissions/\(id)/resubmit" }
    public static func catalogDetail(_ gameID: String) -> String { "/api/external-game/catalog/\(gameID)" }
    public static func monetization(_ gameID: String) -> String { "/api/external-game/catalog/\(gameID)/monetization" }
    public static let creatorSummary = "/api/external-game/creator/summary"
    public static let orders = "/api/external-game/orders"
    public static func orderDetail(_ orderNo: String) -> String { "/api/external-game/orders/\(orderNo)" }
    public static func confirmOrderTest(_ orderNo: String) -> String { "/api/external-game/orders/\(orderNo)/confirm-test" }
    public static let entitlementsMine = "/api/external-game/entitlements/mine"
    public static func nodeBinding(_ nodeID: Int) -> String { "/api/external-game/nodes/\(nodeID)/binding" }
    public static let sessionsStart = "/api/external-game/sessions/start"
    public static func sessionResult(_ sessionID: String) -> String { "/api/external-game/sessions/\(sessionID)/result" }
}

public enum ExternalGameReviewStatus: String, Equatable, Sendable {
    case pending = "PENDING"
    case approved = "APPROVED"
    case rejected = "REJECTED"
    case escalated = "ESCALATED"
    case cancelled = "CANCELLED"
}

public struct ExternalGameCatalogFact: Equatable, Sendable {
    public let submissionID: String
    public let gameID: String
    public let version: String
    public let name: String
    public let author: String?
    public let summary: String?
    public let contentRating: String
    public let permissions: [String]
    public let allowedDomains: [String]
    public let sha256: String
    public let monetization: String
    public let packageBytes: Int?
    public let fileCount: Int?
    public let downloadPath: String?
    public let downloadExpiresAt: String?
}

public struct ExternalGameSubmissionFact: Equatable, Sendable {
    public let submissionID: String
    public let gameID: String
    public let version: String
    public let name: String
    public let status: ExternalGameReviewStatus?
    public let rejectReason: String?
    public let canCancel: Bool
    public let canResubmit: Bool
    public let reviewDueAt: String?
}

public struct ExternalGameSigningKeyFact: Equatable, Sendable {
    public let keyID: String?
    public let algorithm: String?
    public let configured: Bool
    public let publicKeyRaw: Data?
}

public enum ExternalGameWriteOutcome: Equatable, Sendable {
    case confirmed(ExternalGameSubmissionFact, requestID: String)
    case refused(message: String, requestID: String)
    case unknown(requestID: String)
}

public enum ExternalGameReportOutcome: Equatable, Sendable {
    case confirmed(reportID: String, knownToCatalog: Bool, requestID: String)
    case refused(message: String, requestID: String)
    case unknown(requestID: String)
}

public enum ExternalGameCatalogRead: Equatable, Sendable {
    case loaded([ExternalGameCatalogFact])
    case failed
}

public struct ExternalGameReportDraft: Equatable, Sendable {
    public let gameID: String
    public let version: String?
    public let sha256: String?
    public let reasonCode: String
    public let detail: String?
    public let blocked: Bool
    public init(gameID: String, version: String?, sha256: String?, reasonCode: String, detail: String?, blocked: Bool) {
        self.gameID = gameID
        self.version = version
        self.sha256 = sha256
        self.reasonCode = reasonCode
        self.detail = detail
        self.blocked = blocked
    }
}

public struct ExternalGameReviewClient {
    public static let reasonCodes = ["INAPPROPRIATE_CONTENT", "MALICIOUS_CODE", "PAYMENT_OR_SCAM", "COPYRIGHT", "BROKEN", "OTHER"]
    /// HTML and JS only. The bridge names are the allowlist in `ExternalGameBridgeHandler`.
    public static let bridgeActions = ["getMetadata", "loadProgress", "saveProgress", "haptic", "submitResult"]
    public static let bridgeVersion = "1.0"

    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    private let store: any JourneyRequestStoring
    private let nowMillis: @Sendable () -> Int64
    private let entropy: @Sendable () -> String

    public init(configuration: APIConfiguration, transport: any HTTPTransport,
                store: any JourneyRequestStoring = JourneyMemoryRequestStore(),
                nowMillis: @escaping @Sendable () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) },
                entropy: @escaping @Sendable () -> String = { JourneyLoopSource.randomEntropy() }) {
        self.configuration = configuration
        self.transport = transport
        self.store = store
        self.nowMillis = nowMillis
        self.entropy = entropy
    }

    public static func workshopBinaryIsNotThisAPI(_ bytes: Data) -> Bool {
        bytes.starts(with: [0x50, 0x4b])
    }

    public func signingKey(token: String) async -> ExternalGameSigningKeyFact? {
        guard let data = await getData(ExternalGameReviewPaths.signingKey, query: [], token: token) else { return nil }
        return Self.signingKey(from: data)
    }

    public func catalog(token: String) async -> ExternalGameCatalogRead {
        var items: [ExternalGameCatalogFact] = []
        var cursor: String?
        var pages = 0
        while pages < 50 {
            pages += 1
            var query: [URLQueryItem] = [URLQueryItem(name: "limit", value: "20")]
            if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }
            guard let data = await getData(ExternalGameReviewPaths.catalog, query: query, token: token),
                  let page = Self.catalogPage(from: data) else { return .failed }
            items.append(contentsOf: page.items)
            guard page.hasMore, let next = page.nextCursor, !next.isEmpty, next != cursor else { return .loaded(items) }
            cursor = next
        }
        return .failed
    }

    public func downloadApproved(gameID: String, token: String) async -> Data? {
        guard ExternalGameValidator.isValidPackageID(gameID),
              let detailData = await getData(ExternalGameReviewPaths.catalogDetail(gameID), query: [], token: token),
              let fact = Self.catalogFact(from: detailData),
              let path = fact.downloadPath else { return nil }
        return await downloadPackage(downloadPath: path, token: token)
    }

    public func downloadPackage(downloadPath: String, token: String) async -> Data? {
        guard let url = downloadURL(downloadPath) else { return nil }
        guard let request = try? make(method: "GET", url: url, token: token, body: nil, contentType: nil) else { return nil }
        guard admit(request) else { return nil }
        do {
            let (data, status) = try await transport.send(request)
            guard (200...299).contains(status), Self.looksLikeArchive(data) else { return nil }
            return data
        } catch {
            return nil
        }
    }

    public func submit(archive: Data, token: String) async -> ExternalGameWriteOutcome {
        await sendArchive(key: "extgame-submit", path: ExternalGameReviewPaths.submissions, archive: archive, token: token)
    }

    public func resubmit(submissionID: String, archive: Data, token: String) async -> ExternalGameWriteOutcome {
        guard Self.isSubmissionID(submissionID) else { return .refused(message: "submissionId", requestID: "") }
        return await sendArchive(key: "extgame-resubmit:" + submissionID, path: ExternalGameReviewPaths.resubmit(submissionID), archive: archive, token: token)
    }

    public func cancel(submissionID: String, token: String) async -> ExternalGameWriteOutcome {
        guard Self.isSubmissionID(submissionID) else { return .refused(message: "submissionId", requestID: "") }
        let key = "extgame-cancel:" + submissionID
        let requestID = retainedOrNew(key: key, prefix: "extcan")
        guard let requestID else { return .unknown(requestID: "") }
        let body = Data("{\"requestId\":\"\(requestID)\"}".utf8)
        return await postJSON(key: key, path: ExternalGameReviewPaths.cancel(submissionID), body: body, requestID: requestID, token: token)
    }

    public func report(_ draft: ExternalGameReportDraft, token: String) async -> ExternalGameReportOutcome {
        let key = "extgame-report:" + draft.gameID
        let requestID = retainedOrNew(key: key, prefix: "extrep")
        guard let requestID else { return .unknown(requestID: "") }
        guard let body = Self.reportBody(draft, requestID: requestID) else {
            store.remove(key)
            return .refused(message: "request", requestID: requestID)
        }
        guard let request = try? make(method: "POST", path: ExternalGameReviewPaths.reports, token: token, body: body, contentType: "application/json") else {
            return .unknown(requestID: requestID)
        }
        guard admit(request) else {
            store.remove(key)
            return .refused(message: "not-admitted", requestID: requestID)
        }
        let parsed = await perform(request)
        guard let parsed else { return .unknown(requestID: requestID) }
        if parsed.ok, let object = parsed.data as? [String: Any], let reportID = Self.text(object, "reportId"), !reportID.isEmpty {
            store.remove(key)
            let known = Self.bool(object, "knownToCatalog") ?? false
            return .confirmed(reportID: reportID, knownToCatalog: known, requestID: requestID)
        }
        if parsed.confirmed {
            store.remove(key)
            return .refused(message: parsed.message ?? "—", requestID: requestID)
        }
        return .unknown(requestID: requestID)
    }

    public func submissions(token: String) async -> [ExternalGameSubmissionFact]? {
        guard let data = await getData(ExternalGameReviewPaths.mine, query: [URLQueryItem(name: "limit", value: "20")], token: token) else { return nil }
        return Self.submissionPage(from: data)
    }

    public static func signingKey(from data: Data) -> ExternalGameSigningKeyFact? {
        guard let object = envelopeData(data) else { return nil }
        let raw = (object["publicKeyRaw"] as? String).flatMap { Data(base64Encoded: $0) }
        let configured = bool(object, "configured") ?? false
        return ExternalGameSigningKeyFact(keyID: text(object, "keyId"), algorithm: text(object, "algorithm"), configured: configured, publicKeyRaw: raw)
    }

    public static func catalogPage(from data: Data) -> (items: [ExternalGameCatalogFact], hasMore: Bool, nextCursor: String?)? {
        guard let object = envelopeData(data), let rows = object["items"] as? [[String: Any]] else { return nil }
        let items = rows.compactMap(catalogFact)
        let more = bool(object, "hasMore") ?? false
        return (items, more, text(object, "nextCursor"))
    }

    public static func catalogFact(from data: Data) -> ExternalGameCatalogFact? {
        guard let object = envelopeData(data) else { return nil }
        return catalogFact(object)
    }

    public static func submissionFact(from data: Data) -> ExternalGameSubmissionFact? {
        guard let object = envelopeData(data) else { return nil }
        return submissionFact(object)
    }

    // MARK: - Sending

    private func sendArchive(key: String, path: String, archive: Data, token: String) async -> ExternalGameWriteOutcome {
        let saved = store.read(key + ":body").flatMap { Data(base64Encoded: $0) }
        let payload = saved ?? archive
        guard !Self.workshopBinaryIsNotThisAPI(payload), Self.looksLikeArchive(payload) else {
            return .refused(message: "archive", requestID: store.read(key) ?? "")
        }
        let requestID = retainedOrNew(key: key, prefix: "extsub")
        guard let requestID else { return .unknown(requestID: "") }
        if saved == nil { store.write(key + ":body", payload.base64EncodedString()) }
        let boundary = "cyext-" + requestID.replacingOccurrences(of: ":", with: "-")
        let body = Self.multipart(requestID: requestID, archive: payload, boundary: boundary)
        guard let request = try? make(method: "POST", path: path, token: token, body: body, contentType: "multipart/form-data; boundary=\(boundary)") else {
            return .unknown(requestID: requestID)
        }
        guard admit(request) else {
            store.remove(key)
            store.remove(key + ":body")
            return .refused(message: "not-admitted", requestID: requestID)
        }
        return finishSubmission(key: key, requestID: requestID, parsed: await perform(request))
    }

    private func postJSON(key: String, path: String, body: Data, requestID: String, token: String) async -> ExternalGameWriteOutcome {
        guard let request = try? make(method: "POST", path: path, token: token, body: body, contentType: "application/json") else {
            return .unknown(requestID: requestID)
        }
        guard admit(request) else {
            store.remove(key)
            return .refused(message: "not-admitted", requestID: requestID)
        }
        return finishSubmission(key: key, requestID: requestID, parsed: await perform(request))
    }

    private func finishSubmission(key: String, requestID: String, parsed: Parsed?) -> ExternalGameWriteOutcome {
        guard let parsed else { return .unknown(requestID: requestID) }
        if parsed.ok, let object = parsed.data as? [String: Any], let fact = Self.submissionFact(object) {
            store.remove(key)
            store.remove(key + ":body")
            return .confirmed(fact, requestID: requestID)
        }
        if parsed.confirmed {
            store.remove(key)
            store.remove(key + ":body")
            return .refused(message: parsed.message ?? "—", requestID: requestID)
        }
        return .unknown(requestID: requestID)
    }

    private func retainedOrNew(key: String, prefix: String) -> String? {
        if let existing = store.read(key), JourneyLoopSource.isRequestID(existing) { return existing }
        guard let created = JourneyLoopSource.makeRequestID(prefix: prefix, nowMillis: nowMillis(), entropy: entropy()) else { return nil }
        store.write(key, created)
        return created
    }

    private func getData(_ path: String, query: [URLQueryItem], token: String) async -> Data? {
        guard let request = try? make(method: "GET", path: path, query: query, token: token, body: nil, contentType: nil) else { return nil }
        guard admit(request) else { return nil }
        do {
            let (data, status) = try await transport.send(request)
            guard (200...299).contains(status) else { return nil }
            return data
        } catch {
            return nil
        }
    }

    private func perform(_ request: URLRequest) async -> Parsed? {
        do {
            let (data, status) = try await transport.send(request)
            return Self.parse(data: data, status: status)
        } catch {
            return nil
        }
    }

    private func admit(_ request: URLRequest) -> Bool {
        guard let url = request.url else { return false }
        do {
            try ChinaReviewedRouteCapability.refuseUnwiredChinaProduction(request)
        } catch {
            return false
        }
        var path = url.path
        let basePath = configuration.baseURL.path
        let prefix = basePath.count > 1 && basePath.hasSuffix("/") ? String(basePath.dropLast()) : basePath
        if path.hasPrefix(prefix) { path = String(path.dropFirst(prefix.count)) }
        if !path.hasPrefix("/") { path = "/" + path }
        let key = ChinaReviewedRouteCapability.externalGameGrantKey(ChinaReviewedRouteCapability.normalized(path))
        if key == "/api/external-game/orders" || key == "/api/external-game/orders/{}/confirm-test" {
            return !ChinaReviewedRouteCapability.targetsChinaProduction(url) && !ReleaseMoneyWriteSwitch.blocks(key)
        }
        return Self.granted.contains(key)
    }

    private static let granted: Set<String> = [
        "/api/external-game/submissions",
        "/api/external-game/submissions/mine",
        "/api/external-game/submissions/{}",
        "/api/external-game/submissions/{}/cancel",
        "/api/external-game/submissions/{}/resubmit",
        "/api/external-game/catalog",
        "/api/external-game/catalog/{}",
        "/api/external-game/catalog/{}/package",
        "/api/external-game/catalog/{}/monetization",
        "/api/external-game/creator/summary",
        "/api/external-game/entitlements/mine",
        "/api/external-game/nodes/{}/binding",
        "/api/external-game/sessions/start",
        "/api/external-game/sessions/{}/result",
        "/api/external-game/signing-key",
        "/api/external-game/reports"
    ]

    private func downloadURL(_ downloadPath: String) -> URL? {
        guard downloadPath.hasPrefix("/api/external-game/catalog/"),
              downloadPath.contains("/package?"),
              !downloadPath.contains("://"),
              !downloadPath.contains(".."),
              let parts = URLComponents(string: downloadPath),
              let path = parts.path.isEmpty ? nil : parts.path else { return nil }
        guard var base = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false) else { return nil }
        let prefix = base.path.hasSuffix("/") ? String(base.path.dropLast()) : base.path
        base.path = prefix + path
        base.query = parts.percentEncodedQuery
        return base.url
    }

    private func make(method: String, path: String, query: [URLQueryItem] = [], token: String, body: Data?, contentType: String?) throws -> URLRequest {
        let url = try Self.url(base: configuration.baseURL, path: path, query: query)
        return try make(method: method, url: url, token: token, body: body, contentType: contentType)
    }

    private func make(method: String, url: URL, token: String, body: Data?, contentType: String?) throws -> URLRequest {
        guard AuthRequestBuilder.isValidToken(token) else { throw ExternalGameReviewFailure.invalid }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30
        request.httpShouldHandleCookies = false
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let contentType { request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        request.httpBody = body
        return request
    }

    private static func url(base: URL, path: String, query: [URLQueryItem]) throws -> URL {
        var built = base
        for part in path.split(separator: "/").map(String.init) where part != "prod-api" {
            built.appendPathComponent(part)
        }
        guard var components = URLComponents(url: built, resolvingAgainstBaseURL: false) else { throw ExternalGameReviewFailure.invalid }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw ExternalGameReviewFailure.invalid }
        return url
    }

    private static func multipart(requestID: String, archive: Data, boundary: String) -> Data {
        var body = Data()
        func line(_ text: String) { body.append(Data(text.utf8)) }
        line("--\(boundary)\r\n")
        line("Content-Disposition: form-data; name=\"requestId\"\r\n\r\n")
        line(requestID + "\r\n")
        line("--\(boundary)\r\n")
        line("Content-Disposition: form-data; name=\"monetization\"\r\n\r\n")
        line(ExternalGameReviewPaths.monetization + "\r\n")
        line("--\(boundary)\r\n")
        line("Content-Disposition: form-data; name=\"archive\"; filename=\"game.questify-game.json\"\r\n")
        line("Content-Type: application/json\r\n\r\n")
        body.append(archive)
        line("\r\n--\(boundary)--\r\n")
        return body
    }

    private static func reportBody(_ draft: ExternalGameReportDraft, requestID: String) -> Data? {
        guard draft.gameID.range(of: "^[a-z0-9][a-z0-9._-]{2,63}$", options: .regularExpression) != nil,
              reasonCodes.contains(draft.reasonCode) else { return nil }
        if draft.reasonCode == "OTHER", (draft.detail ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
        var object: [String: Any] = ["requestId": requestID, "gameId": draft.gameID, "reasonCode": draft.reasonCode, "blocked": draft.blocked]
        if let version = draft.version { object["version"] = version }
        if let sha = draft.sha256 { object["sha256"] = sha }
        if let detail = draft.detail, !detail.isEmpty { object["detail"] = detail }
        return try? JSONSerialization.data(withJSONObject: object)
    }

    private static func looksLikeArchive(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["manifest"] is [String: Any], object["files"] is [String: Any] else { return false }
        return true
    }

    private static func isSubmissionID(_ value: String) -> Bool {
        value.range(of: "^[1-9][0-9]{0,18}$", options: .regularExpression) != nil
    }

    // MARK: - JSON

    private struct Parsed {
        let ok: Bool
        let confirmed: Bool
        let message: String?
        let data: Any?
    }

    private static func parse(data: Data, status: Int) -> Parsed {
        let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let code = root.flatMap { codeNumber($0["code"]) }
        let message = root.flatMap { text($0, "msg") } ?? root.flatMap { text($0, "message") }
        let ok = (200...299).contains(status) && code == 200
        let confirmed = (200...299).contains(status) || (400...499).contains(status)
        return Parsed(ok: ok, confirmed: confirmed, message: message, data: root?["data"] ?? root)
    }

    private static func envelopeData(_ data: Data) -> [String: Any]? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let nested = root["data"] as? [String: Any] { return nested }
        return root
    }

    private static func catalogFact(_ object: [String: Any]) -> ExternalGameCatalogFact? {
        guard let gameID = text(object, "gameId"), let name = text(object, "name"),
              let version = text(object, "version"), let rating = text(object, "contentRating"),
              let sha = text(object, "sha256"), let submissionID = text(object, "submissionId") else { return nil }
        return ExternalGameCatalogFact(
            submissionID: submissionID, gameID: gameID, version: version, name: name,
            author: text(object, "author"), summary: text(object, "summary"), contentRating: rating,
            permissions: strings(object, "permissions"), allowedDomains: strings(object, "allowedDomains"),
            sha256: sha, monetization: text(object, "monetization") ?? ExternalGameReviewPaths.monetization,
            packageBytes: int(object, "packageBytes"), fileCount: int(object, "fileCount"),
            downloadPath: text(object, "downloadPath"), downloadExpiresAt: text(object, "downloadExpiresAt"))
    }

    private static func submissionFact(_ object: [String: Any]) -> ExternalGameSubmissionFact? {
        guard let gameID = text(object, "gameId"), let name = text(object, "name"),
              let version = text(object, "version"), let submissionID = text(object, "submissionId") else { return nil }
        let raw = text(object, "status")
        return ExternalGameSubmissionFact(
            submissionID: submissionID, gameID: gameID, version: version, name: name,
            status: raw.flatMap(ExternalGameReviewStatus.init(rawValue:)),
            rejectReason: text(object, "rejectReason"),
            canCancel: bool(object, "canCancel") ?? false,
            canResubmit: bool(object, "canResubmit") ?? false,
            reviewDueAt: text(object, "reviewDueAt"))
    }

    private static func submissionPage(from data: Data) -> [ExternalGameSubmissionFact]? {
        guard let object = envelopeData(data), let rows = object["items"] as? [[String: Any]] else { return nil }
        return rows.compactMap(submissionFact)
    }

    static func text(_ object: [String: Any], _ key: String) -> String? {
        if let value = object[key] as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let number = object[key] as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
            return number.stringValue
        }
        return nil
    }

    private static func strings(_ object: [String: Any], _ key: String) -> [String] {
        (object[key] as? [String]) ?? []
    }

    private static func int(_ object: [String: Any], _ key: String) -> Int? {
        guard let number = object[key] as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        return number.intValue
    }

    private static func bool(_ object: [String: Any], _ key: String) -> Bool? {
        guard let number = object[key] as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }

    private static func codeNumber(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        return number.intValue
    }

    // MARK: - Monetization, Node Binding & Signed Result Callback

    public static func canonicalResultPayload(
        sessionID: String,
        gameID: String,
        nonce: String,
        passed: Bool,
        score: Int?,
        durationMs: Int64,
        digest: String
    ) -> String {
        "EXTGAME_RESULT|\(sessionID)|\(gameID)|\(nonce)|\(passed ? "1" : "0")|\(score.map(String.init) ?? "")|\(durationMs)|\(digest)"
    }

    public static func signResultPayload(
        sessionID: String,
        gameID: String,
        nonce: String,
        passed: Bool,
        score: Int?,
        durationMs: Int64,
        digest: String
    ) -> String {
        let canonical = canonicalResultPayload(
            sessionID: sessionID,
            gameID: gameID,
            nonce: nonce,
            passed: passed,
            score: score,
            durationMs: durationMs,
            digest: digest
        )
        let key = SymmetricKey(data: Data(nonce.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(canonical.utf8), using: key)
        return mac.map { String(format: "%02x", $0) }.joined()
    }

    public func monetizationConfig(gameID: String, token: String) async -> ExternalGameMonetizationFact? {
        guard let raw = await getData(ExternalGameReviewPaths.monetization(gameID), query: [], token: token),
              let data = Self.envelopeData(raw) else { return nil }
        return Self.monetizationFact(data)
    }

    public func saveMonetizationConfig(
        gameID: String,
        pricingMode: String,
        priceFen: Int,
        trafficRewardMode: String,
        channelFeeBearer: Int = 0,
        requestID: String? = nil,
        token: String
    ) async -> ExternalGameMonetizationFact? {
        let reqID = requestID ?? "egm-\(entropy())"
        let payload: [String: Any] = [
            "pricingMode": pricingMode,
            "priceFen": priceFen,
            "trafficRewardMode": trafficRewardMode,
            "channelFeeBearer": channelFeeBearer,
            "requestId": reqID
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload),
              let req = try? make(method: "PUT", path: ExternalGameReviewPaths.monetization(gameID), token: token, body: body, contentType: "application/json"),
              let parsed = await perform(req), parsed.ok,
              let data = Self.envelopeData(parsed.raw) else { return nil }
        return Self.monetizationFact(data)
    }

    public func creatorSummary(token: String) async -> ExternalGameCreatorSummary? {
        guard let raw = await getData(ExternalGameReviewPaths.creatorSummary, query: [], token: token),
              let data = Self.envelopeData(raw) else { return nil }
        let configs = (data["configs"] as? [[String: Any]] ?? []).compactMap(Self.monetizationFact)
        return ExternalGameCreatorSummary(
            paidOrders: Self.int(data, "paidOrders") ?? 0,
            grossSalesFen: Self.int64(data, "grossSalesFen") ?? 0,
            creatorSalesNetFen: Self.int64(data, "creatorSalesNetFen") ?? 0,
            trafficValidPlays: Self.int(data, "trafficValidPlays") ?? 0,
            trafficSettledPoints: Self.int(data, "trafficSettledPoints") ?? 0,
            trafficSettledFen: Self.int64(data, "trafficSettledFen") ?? 0,
            moneyGateOpen: Self.bool(data, "moneyGateOpen") ?? false,
            payoutGateOpen: Self.bool(data, "payoutGateOpen") ?? false,
            configs: configs
        )
    }

    public func myEntitlements(token: String) async -> [ExternalGameEntitlementFact]? {
        guard let raw = await getData(ExternalGameReviewPaths.entitlementsMine, query: [], token: token),
              let data = Self.envelopeData(raw),
              let items = data["items"] as? [[String: Any]] else { return nil }
        return items.compactMap { row in
            guard let gameID = Self.text(row, "gameId"),
                  let orderNo = Self.text(row, "orderNo"),
                  let status = Self.text(row, "status") else { return nil }
            return ExternalGameEntitlementFact(
                gameID: gameID,
                gameName: Self.text(row, "gameName"),
                version: Self.text(row, "version"),
                orderNo: orderNo,
                status: status
            )
        }
    }

    /// Purchase a paid external game. Fail-closed unless ReleaseMoneyWriteSwitch.paymentEnabled (TEST-only).
    public func purchaseGame(
        gameID: String,
        provider: String = "TEST_WALLET",
        requestID: String? = nil,
        token: String
    ) async -> ExternalGameOrderFact? {
        guard !ReleaseMoneyWriteSwitch.blocks(ExternalGameReviewPaths.orders) else { return nil }
        let reqID = requestID ?? "ego-\(entropy())"
        let payload: [String: Any] = ["gameId": gameID, "provider": provider, "requestId": reqID]
        guard let body = try? JSONSerialization.data(withJSONObject: payload),
              let req = try? make(method: "POST", path: ExternalGameReviewPaths.orders, token: token, body: body, contentType: "application/json"),
              let parsed = await perform(req), parsed.ok,
              let data = Self.envelopeData(parsed.raw) else { return nil }
        return Self.orderFact(data)
    }

    public func bindNode(nodeID: Int, gameID: String, minScore: Int = 0, requirePass: Bool = true, token: String) async -> Bool {
        let payload: [String: Any] = ["gameId": gameID, "minScore": minScore, "requirePass": requirePass]
        guard let body = try? JSONSerialization.data(withJSONObject: payload),
              let req = try? make(method: "PUT", path: ExternalGameReviewPaths.nodeBinding(nodeID), token: token, body: body, contentType: "application/json"),
              let parsed = await perform(req) else { return false }
        return parsed.ok
    }

    public func unbindNode(nodeID: Int, token: String) async -> Bool {
        guard let req = try? make(method: "DELETE", path: ExternalGameReviewPaths.nodeBinding(nodeID), token: token, body: nil, contentType: nil),
              let parsed = await perform(req) else { return false }
        return parsed.ok
    }

    public func startSession(
        gameID: String,
        nodeID: Int? = nil,
        topicID: Int? = nil,
        activityID: Int? = nil,
        token: String
    ) async -> ExternalGameSessionTicket? {
        var payload: [String: Any] = ["gameId": gameID]
        if let nodeID { payload["nodeId"] = nodeID }
        if let topicID { payload["topicId"] = topicID }
        if let activityID { payload["activityId"] = activityID }
        guard let body = try? JSONSerialization.data(withJSONObject: payload),
              let req = try? make(method: "POST", path: ExternalGameReviewPaths.sessionsStart, token: token, body: body, contentType: "application/json"),
              let parsed = await perform(req), parsed.ok,
              let data = Self.envelopeData(parsed.raw),
              let sessionID = Self.text(data, "sessionId"),
              let resolvedGameID = Self.text(data, "gameId"),
              let nonce = Self.text(data, "nonce"),
              let sessionSignature = Self.text(data, "sessionSignature") else { return nil }
        return ExternalGameSessionTicket(
            sessionID: sessionID,
            gameID: resolvedGameID,
            nodeID: Self.int(data, "nodeId"),
            nonce: nonce,
            issuedAtMs: Self.int64(data, "issuedAtMs") ?? 0,
            sessionSignature: sessionSignature
        )
    }

    public func submitSignedResult(
        ticket: ExternalGameSessionTicket,
        passed: Bool,
        score: Int?,
        durationMs: Int64,
        digest: String? = nil,
        token: String
    ) async -> ExternalGameResultOutcome? {
        let resolvedDigest = digest ?? {
            let raw = "\(passed ? "1" : "0"):\(score.map(String.init) ?? ""):\(durationMs)"
            let hash = SHA256.hash(data: Data(raw.utf8))
            return hash.map { String(format: "%02x", $0) }.joined()
        }()
        let signature = Self.signResultPayload(
            sessionID: ticket.sessionID,
            gameID: ticket.gameID,
            nonce: ticket.nonce,
            passed: passed,
            score: score,
            durationMs: durationMs,
            digest: resolvedDigest
        )
        var payload: [String: Any] = [
            "nonce": ticket.nonce,
            "passed": passed,
            "durationMs": durationMs,
            "resultDigest": resolvedDigest,
            "resultSignature": signature
        ]
        if let score { payload["score"] = score }
        guard let body = try? JSONSerialization.data(withJSONObject: payload),
              let req = try? make(method: "POST", path: ExternalGameReviewPaths.sessionResult(ticket.sessionID), token: token, body: body, contentType: "application/json"),
              let parsed = await perform(req), parsed.ok,
              let data = Self.envelopeData(parsed.raw),
              let sessionID = Self.text(data, "sessionId"),
              let gameID = Self.text(data, "gameId") else { return nil }
        return ExternalGameResultOutcome(
            sessionID: sessionID,
            gameID: gameID,
            nodeID: Self.int(data, "nodeId"),
            passed: Self.bool(data, "passed") ?? false,
            score: Self.int(data, "score"),
            xpAwarded: Self.int(data, "xpAwarded") ?? 0,
            medalRank: Self.int(data, "medalRank"),
            nodeCompleted: Self.bool(data, "nodeCompleted") ?? false,
            trafficEligible: Self.bool(data, "trafficEligible") ?? false,
            fraudReason: Self.text(data, "fraudReason"),
            replayed: Self.bool(data, "replayed") ?? false
        )
    }

    private static func monetizationFact(_ data: [String: Any]) -> ExternalGameMonetizationFact? {
        guard let gameID = Self.text(data, "gameId"),
              let pricingMode = Self.text(data, "pricingMode") else { return nil }
        return ExternalGameMonetizationFact(
            gameID: gameID,
            gameName: Self.text(data, "gameName"),
            pricingMode: pricingMode,
            priceFen: Self.int64(data, "priceFen") ?? 0,
            currency: Self.text(data, "currency") ?? "CNY",
            creatorShareBps: Self.int(data, "creatorShareBps") ?? 7000,
            channelFeeBearer: Self.int(data, "channelFeeBearer") ?? 0,
            trafficRewardMode: Self.text(data, "trafficRewardMode") ?? "NONE",
            rewardPerPlayPoints: Self.int(data, "rewardPerPlayPoints") ?? 0,
            rewardPerPlayFen: Self.int64(data, "rewardPerPlayFen") ?? 0,
            dailyUserCap: Self.int(data, "dailyUserCap") ?? 3,
            dailyGameCap: Self.int(data, "dailyGameCap") ?? 200,
            minDurationMs: Self.int(data, "minDurationMs") ?? 5000,
            reviewStatus: Self.text(data, "reviewStatus") ?? "NONE",
            reviewNote: Self.text(data, "reviewNote"),
            entitled: Self.bool(data, "entitled") ?? true,
            isOwner: Self.bool(data, "isOwner") ?? false,
            moneyGateOpen: Self.bool(data, "moneyGateOpen") ?? false
        )
    }

    private static func orderFact(_ data: [String: Any]) -> ExternalGameOrderFact? {
        guard let orderNo = Self.text(data, "orderNo"),
              let gameID = Self.text(data, "gameId") else { return nil }
        return ExternalGameOrderFact(
            orderNo: orderNo,
            gameID: gameID,
            amountFen: Self.int64(data, "amountFen") ?? 0,
            creatorShareBps: Self.int(data, "creatorShareBps") ?? 7000,
            channelFeeBearer: Self.int(data, "channelFeeBearer") ?? 0,
            channelFeeFen: Self.int64(data, "channelFeeFen") ?? 0,
            creatorNetFen: Self.int64(data, "creatorNetFen") ?? 0,
            platformShareFen: Self.int64(data, "platformShareFen") ?? 0,
            provider: Self.text(data, "provider") ?? "TEST_WALLET",
            state: Self.text(data, "state") ?? "PENDING",
            licenseStatus: Self.text(data, "licenseStatus") ?? "PENDING"
        )
    }

    private static func int64(_ object: [String: Any], _ key: String) -> Int64? {
        guard let number = object[key] as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        return number.int64Value
    }
}

public struct ExternalGameMonetizationFact: Equatable, Sendable {
    public let gameID: String
    public let gameName: String?
    public let pricingMode: String
    public let priceFen: Int64
    public let currency: String
    public let creatorShareBps: Int
    public let channelFeeBearer: Int
    public let trafficRewardMode: String
    public let rewardPerPlayPoints: Int
    public let rewardPerPlayFen: Int64
    public let dailyUserCap: Int
    public let dailyGameCap: Int
    public let minDurationMs: Int
    public let reviewStatus: String
    public let reviewNote: String?
    public let entitled: Bool
    public let isOwner: Bool
    public let moneyGateOpen: Bool
}

public struct ExternalGameCreatorSummary: Equatable, Sendable {
    public let paidOrders: Int
    public let grossSalesFen: Int64
    public let creatorSalesNetFen: Int64
    public let trafficValidPlays: Int
    public let trafficSettledPoints: Int
    public let trafficSettledFen: Int64
    public let moneyGateOpen: Bool
    public let payoutGateOpen: Bool
    public let configs: [ExternalGameMonetizationFact]
}

public struct ExternalGameOrderFact: Equatable, Sendable {
    public let orderNo: String
    public let gameID: String
    public let amountFen: Int64
    public let creatorShareBps: Int
    public let channelFeeBearer: Int
    public let channelFeeFen: Int64
    public let creatorNetFen: Int64
    public let platformShareFen: Int64
    public let provider: String
    public let state: String
    public let licenseStatus: String
}

public struct ExternalGameEntitlementFact: Equatable, Sendable, Identifiable {
    public var id: String { orderNo }
    public let gameID: String
    public let gameName: String?
    public let version: String?
    public let orderNo: String
    public let status: String
}

public struct ExternalGameSessionTicket: Equatable, Sendable {
    public let sessionID: String
    public let gameID: String
    public let nodeID: Int?
    public let nonce: String
    public let issuedAtMs: Int64
    public let sessionSignature: String
}

public struct ExternalGameResultOutcome: Equatable, Sendable {
    public let sessionID: String
    public let gameID: String
    public let nodeID: Int?
    public let passed: Bool
    public let score: Int?
    public let xpAwarded: Int
    public let medalRank: Int?
    public let nodeCompleted: Bool
    public let trafficEligible: Bool
    public let fraudReason: String?
    public let replayed: Bool
}

private enum ExternalGameReviewFailure: Error { case invalid }
