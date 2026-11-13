import Foundation
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
    public static let bridgeActions = ["getMetadata", "loadProgress", "saveProgress", "haptic"]
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
        guard let detailData = await getData(ExternalGameReviewPaths.catalogDetail(gameID), query: [], token: token),
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
}

private enum ExternalGameReviewFailure: Error { case invalid }
