import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Read-only applicant view of `GET /api/audit/{taskId}/detail`.
/// Status comes from `data.task`. Timeline rows come from `data.timeline`
/// (the same object the applicant detail returns next to `task`).
/// A missing or unrecognized field is an em dash. This type does not call
/// `POST /api/audit/appeal`, notification mark-read, or any governance write.
enum IMReviewAuditDetail {
    static let unknown = "—"

    /// Cards sent to the reported party. The detail route answers 403 for them,
    /// and the mini-program does not send the read.
    static func hidesDetail(cardTitle: String?) -> Bool {
        guard let title = cardTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else { return false }
        return title == "你的组局已关闭" || title == "你参与的组局已关闭"
    }

    static func taskID(_ raw: String) -> Int64? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.allSatisfy({ $0.isASCII && $0.isNumber }),
              let value = Int64(trimmed), value > 0, String(value) == trimmed else { return nil }
        return value
    }

    static func request(baseURL: URL, taskID: String, token: String) throws -> URLRequest {
        guard AuthRequestBuilder.isValidToken(token), let id = self.taskID(taskID) else { throw APIError.invalidRequest }
        var parts = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        var path = parts?.path ?? ""
        if path == "/" { path = "" }
        if path.hasSuffix("/") { path.removeLast() }
        path += "/api/audit/\(id)/detail"
        parts?.path = path
        parts?.query = nil
        parts?.fragment = nil
        guard let url = parts?.url else { throw APIError.invalidRequest }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.httpBody = nil
        request.httpShouldHandleCookies = false
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        return request
    }

    static func record(json: Data, locale: Locale) throws -> IMReviewAuditRecord {
        guard let root = try? JSONSerialization.jsonObject(with: json) as? [String: Any] else { throw APIError.malformedResponse }
        if integer(root["code"]) == 401 { throw APIError.unauthorized }
        guard integer(root["code"]) == 200, let payload = dictionary(root["data"]),
              let task = dictionary(payload["task"]) else { throw APIError.malformedResponse }
        let rows = array(payload["timeline"]) ?? array(task["timeline"]) ?? []
        return IMReviewAuditRecord(
            statusLabel: statusLabel(task["status"], locale: locale),
            timeline: rows.enumerated().compactMap { index, item in
                guard let row = dictionary(item) else { return nil }
                return IMReviewAuditRecord.Step(
                    id: index,
                    time: text(row["createTime"]) ?? unknown,
                    label: actionLabel(row["action"], locale: locale),
                    reason: text(row["reasonText"]))
            })
    }

    private static func statusLabel(_ value: Any?, locale: Locale) -> String {
        switch integer(value) {
        case 0: return String(localized: LocalizedStringResource("mpd.review.status.pending", locale: locale))
        case 1: return String(localized: LocalizedStringResource("mpd.review.status.approved", locale: locale))
        case 2: return String(localized: LocalizedStringResource("mpd.review.status.rejected", locale: locale))
        case 3: return String(localized: LocalizedStringResource("mpd.review.status.escalated", locale: locale))
        case 4: return String(localized: LocalizedStringResource("mpd.review.status.withdrawn", locale: locale))
        default: return unknown
        }
    }

    private static func actionLabel(_ value: Any?, locale: Locale) -> String {
        switch text(value) {
        case "SUBMIT": return String(localized: LocalizedStringResource("mpd.review.action.submit", locale: locale))
        case "APPROVE": return String(localized: LocalizedStringResource("mpd.review.action.approve", locale: locale))
        case "REJECT": return String(localized: LocalizedStringResource("mpd.review.action.reject", locale: locale))
        case "REVERT": return String(localized: LocalizedStringResource("mpd.review.action.revert", locale: locale))
        default: return unknown
        }
    }

    private static func dictionary(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    private static func array(_ value: Any?) -> [Any]? {
        value as? [Any]
    }

    private static func text(_ value: Any?) -> String? {
        guard let raw = value as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// JSON numbers and canonical integer strings only. Booleans are not statuses.
    private static func integer(_ value: Any?) -> Int? {
        if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
            let int = number.intValue
            guard number.doubleValue == Double(int) else { return nil }
            return int
        }
        if let raw = value as? String {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let int = Int(trimmed), String(int) == trimmed else { return nil }
            return int
        }
        return nil
    }
}

/// One GET. The transport is the session's existing transport. No second request is built.
@MainActor struct IMReviewAuditHTTPReader: IMReviewAuditReading {
    let configuration: APIConfiguration
    let transport: any HTTPTransport
    var token: () -> String?
    var locale: Locale

    init(configuration: APIConfiguration, transport: any HTTPTransport, token: @escaping () -> String?, locale: Locale = .current) {
        self.configuration = configuration
        self.transport = transport
        self.token = token
        self.locale = locale
    }

    func record(taskID: String) async throws -> IMReviewAuditRecord {
        guard let token = token(), AuthRequestBuilder.isValidToken(token) else { throw APIError.unauthorized }
        let request = try IMReviewAuditDetail.request(baseURL: configuration.baseURL, taskID: taskID, token: token)
        try Task.checkCancellation()
        let (data, status) = try await transport.send(request)
        try Task.checkCancellation()
        if status == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(status) else { throw APIError.httpStatus(status) }
        return try IMReviewAuditDetail.record(json: data, locale: locale)
    }
}

/// Holds the reader off `AppSession` so that file does not grow.
@MainActor final class IMReviewAuditSessionReader: IMReviewAuditReading {
    private weak var session: AppSession?
    init(session: AppSession) { self.session = session }

    func record(taskID: String) async throws -> IMReviewAuditRecord {
        guard let session, let configuration = session.regionalConfiguration?.apiConfiguration else { throw APIError.notConfigured }
        let owner = session.account?.id
        guard let token = session.token, AuthRequestBuilder.isValidToken(token), owner != nil else { throw APIError.unauthorized }
        let reader = IMReviewAuditHTTPReader(configuration: configuration, transport: session.runtimeHTTPTransport, token: { token }, locale: .autoupdatingCurrent)
        let record = try await reader.record(taskID: taskID)
        guard session.account?.id == owner, session.token == token else { throw APIError.unauthorized }
        return record
    }
}
