import Foundation
import CoreFoundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum VideoBountyRefusal: Error, Equatable, Sendable {
    case invalidRequest
    case noSavedRequest
    case notAdmitted
}

/// One video-bounty call. A confirmed answer is HTTP 2xx or 4xx. Anything else stays unconfirmed.
public struct VideoBountyEnvelope: Equatable, Sendable {
    public let httpStatus: Int?
    public let code: String?
    public let reasonCode: String?
    public let message: String?
    public let dataJSON: Data?
    public let netFail: Bool
    public let receiptReread: Bool

    public var ok: Bool {
        guard let httpStatus, (200...299).contains(httpStatus), code == "200" else { return false }
        return true
    }

    /// The server answered. The saved request id may be dropped.
    public var confirmed: Bool {
        guard let httpStatus, !netFail else { return false }
        return (200...299).contains(httpStatus) || (400...499).contains(httpStatus)
    }

    public static let networkFailure = VideoBountyEnvelope(
        httpStatus: nil, code: "fail", reasonCode: nil, message: nil, dataJSON: nil, netFail: true, receiptReread: false)
}

public enum VideoBountyRequestKey {
    public static let submit = "video-bounty-submit"
    public static func appeal(_ submissionID: String) -> String { "video-bounty-appeal:" + submissionID }
    public static func cancel(_ submissionID: String) -> String { "video-bounty-cancel:" + submissionID }
}

/// Author campaign row from `GET /api/video-bounty/campaign/list`.
/// Only the four fields that endpoint returns. A missing campaign key is dropped, never filled in.
public struct VideoBountyCampaign: Equatable, Sendable {
    public let campaignKey: String
    public let title: String?
    public let description: String?
    public let windowDays: Int?
}

public struct VideoBountySubmissionFact: Equatable, Sendable {
    public let id: String
    public let platform: String?
    public let sourceURL: String?
    public let statusLabel: String
    public let reviewNote: String?
    public let windowEndText: String?
    public let canAppeal: Bool
    public let canCancel: Bool
}

/// Attribution read. `showsCounts` is true only for a confirmed `BOUND` row.
/// Every other status, including `UNKNOWN`, keeps counts as an em dash.
public struct VideoBountyAttributionFact: Equatable, Sendable {
    public static let unknownMark = "—"
    public static let unknown = VideoBountyAttributionFact(
        status: "UNKNOWN", confirmed: false, showsCounts: false,
        attributedOrders: unknownMark, paidOrders: unknownMark, paidAmount: unknownMark,
        refundedOrders: unknownMark, refundedAmount: unknownMark, amountCurrency: unknownMark)

    public let status: String
    public let confirmed: Bool
    public let showsCounts: Bool
    public let attributedOrders: String
    public let paidOrders: String
    public let paidAmount: String
    public let refundedOrders: String
    public let refundedAmount: String
    public let amountCurrency: String

    public init(status: String, confirmed: Bool, showsCounts: Bool, attributedOrders: String, paidOrders: String,
                paidAmount: String, refundedOrders: String, refundedAmount: String, amountCurrency: String) {
        self.status = status
        self.confirmed = confirmed
        self.showsCounts = showsCounts
        self.attributedOrders = attributedOrders
        self.paidOrders = paidOrders
        self.paidAmount = paidAmount
        self.refundedOrders = refundedOrders
        self.refundedAmount = refundedAmount
        self.amountCurrency = amountCurrency
    }
}

/// Accrual display. `amountText` nil means the amount was missing. This is not a balance.
public struct VideoBountyAccrualFact: Equatable, Sendable {
    public let id: String
    public let amountText: String?
    public let views: Int?
    public let groupViews: Int?
}

/// Port of `subpackageA/pages/video-bounty` plus `GET /api/video-bounty/campaign/list`.
/// Submit, appeal, and cancel keep one request id. An unconfirmed answer is re-posted as a receipt read.
/// Payout, withdraw, redeem, and wallet are not methods on this type.
/// Attribution reads return counts only. A missing count is an em dash, never 0.
public struct VideoBountySource {
    /// hengyin `ApiVideoBountyController` at the stub-ledger mini-program revision.
    public static let sourceRevision = "7fe779ceb"

    public static let paths: [String] = [
        "/api/video-bounty/submission/mine",
        "/api/video-bounty/accrual/mine",
        "/api/video-bounty/campaign/list",
        "/api/video-bounty/submission",
        "/api/video-bounty/submission/{}/appeal",
        "/api/video-bounty/submission/{}/cancel",
        "/api/video-bounty/submission/{}/attribution",
        "/api/video-bounty/campaign/{}/attribution"
    ]

    private static let blocked = ["payout", "withdraw", "redeem", "wallet"]

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

    // MARK: Reads

    public func submissions(token: String) async throws -> VideoBountyEnvelope {
        try await get("/api/video-bounty/submission/mine", token: token)
    }

    public func accruals(token: String) async throws -> VideoBountyEnvelope {
        try await get("/api/video-bounty/accrual/mine", token: token)
    }

    /// Open campaigns only. An empty list stays empty. This does not create a campaign.
    public func campaigns(token: String) async throws -> VideoBountyEnvelope {
        try await get("/api/video-bounty/campaign/list", token: token)
    }

    /// Author-only read. Null counts stay an em dash. This does not pay or withdraw.
    public func submissionAttribution(submissionID: String, token: String) async throws -> VideoBountyEnvelope {
        try await get(try Self.actionPath(submissionID, action: "attribution"), token: token)
    }

    /// Campaign owner read. `topicId` is required and is not a sharer or a price.
    public func campaignAttribution(campaignID: String, topicID: String, token: String) async throws -> VideoBountyEnvelope {
        guard Self.isID(campaignID), Self.isID(topicID) else { throw VideoBountyRefusal.invalidRequest }
        let item = URLQueryItem(name: "topicId", value: topicID)
        return try await get("/api/video-bounty/campaign/" + campaignID + "/attribution", query: [item], token: token)
    }

    // MARK: Writes

    public func submit(campaignKey: String, topicID: String, platform: String, sourceURL: String,
                       originGroupKey: String, token: String) async throws -> VideoBountyEnvelope {
        let key = VideoBountyRequestKey.submit
        if store.read(key) != nil {
            return try await sendLocked(key: key, path: "/api/video-bounty/submission", token: token)
        }
        let fields = try Self.submitFields(campaignKey: campaignKey, topicID: topicID, platform: platform,
                                           sourceURL: sourceURL, originGroupKey: originGroupKey)
        return try await sendNew(key: key, prefix: "vbsub", path: "/api/video-bounty/submission", fields: fields, token: token)
    }

    public func rereadSubmit(token: String) async throws -> VideoBountyEnvelope {
        try await sendLocked(key: VideoBountyRequestKey.submit, path: "/api/video-bounty/submission", token: token)
    }

    public func appeal(submissionID: String, note: String, token: String) async throws -> VideoBountyEnvelope {
        let path = try Self.actionPath(submissionID, action: "appeal")
        let key = VideoBountyRequestKey.appeal(submissionID)
        if store.read(key) != nil {
            return try await sendLocked(key: key, path: path, token: token)
        }
        let note = try Self.appealNote(note)
        return try await sendNew(key: key, prefix: "vbapl", path: path, fields: ["note": note], token: token)
    }

    public func rereadAppeal(submissionID: String, token: String) async throws -> VideoBountyEnvelope {
        try await sendLocked(key: VideoBountyRequestKey.appeal(submissionID),
                             path: try Self.actionPath(submissionID, action: "appeal"), token: token)
    }

    public func cancel(submissionID: String, token: String) async throws -> VideoBountyEnvelope {
        let path = try Self.actionPath(submissionID, action: "cancel")
        let key = VideoBountyRequestKey.cancel(submissionID)
        if store.read(key) != nil {
            return try await sendLocked(key: key, path: path, token: token)
        }
        guard Self.isID(submissionID) else { throw VideoBountyRefusal.invalidRequest }
        return try await sendNew(key: key, prefix: "vbcxl", path: path, fields: [:], token: token)
    }

    public func rereadCancel(submissionID: String, token: String) async throws -> VideoBountyEnvelope {
        try await sendLocked(key: VideoBountyRequestKey.cancel(submissionID),
                             path: try Self.actionPath(submissionID, action: "cancel"), token: token)
    }

    // MARK: Projection

    /// Nil when `data` is not an array. Rows without an id are dropped.
    public static func submissions(in envelope: VideoBountyEnvelope) -> [VideoBountySubmissionFact]? {
        guard let rows = array(envelope.dataJSON) else { return nil }
        return rows.compactMap(submission)
    }

    public static func accruals(in envelope: VideoBountyEnvelope) -> [VideoBountyAccrualFact]? {
        guard let rows = array(envelope.dataJSON) else { return nil }
        return rows.compactMap(accrual)
    }

    /// Nil when `data` is not an array. A row without a string `campaignKey` is skipped.
    /// Counts render only for `BOUND` with `confirmed == true`. Anything else, including a literal 0
    /// on an unconfirmed read, is an em dash. A missing status is `UNKNOWN`.
    public static func attribution(in envelope: VideoBountyEnvelope) -> VideoBountyAttributionFact? {
        guard envelope.ok else { return nil }
        guard let data = envelope.dataJSON else { return .unknown }
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        return attributionFact(object)
    }

    static func attributionFact(_ object: [String: Any]) -> VideoBountyAttributionFact {
        let raw = (object["status"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let status = raw.isEmpty ? "UNKNOWN" : raw
        let confirmed = object["confirmed"] as? Bool ?? false
        let shows = status == "BOUND" && confirmed
        let mark = VideoBountyAttributionFact.unknownMark
        func count(_ key: String) -> String {
            guard shows, let value = whole(object[key]) else { return mark }
            return String(value)
        }
        func money(_ key: String) -> String {
            guard shows, let decimal = decimal(object[key]), let digits = fixedTwo(decimal) else { return mark }
            return digits
        }
        let currency = shows ? (nonEmpty(object["amountCurrency"] as? String) ?? mark) : mark
        return VideoBountyAttributionFact(
            status: status, confirmed: confirmed, showsCounts: shows,
            attributedOrders: count("attributedOrders"), paidOrders: count("paidOrders"), paidAmount: money("paidAmount"),
            refundedOrders: count("refundedOrders"), refundedAmount: money("refundedAmount"), amountCurrency: currency)
    }

    public static func campaigns(in envelope: VideoBountyEnvelope) -> [VideoBountyCampaign]? {
        guard let rows = array(envelope.dataJSON) else { return nil }
        return rows.compactMap(campaign)
    }

    public static func amountText(payable: Any?, currency: Any?) -> String? {
        guard let decimal = decimal(payable) else { return nil }
        guard let digits = fixedTwo(decimal) else { return nil }
        let code = currency as? String
        if let code, !code.isEmpty, code != "CNY" { return code + " " + digits }
        return "¥" + digits
    }

    // MARK: Private send

    private func get(_ path: String, query: [URLQueryItem] = [], token: String) async throws -> VideoBountyEnvelope {
        guard AuthRequestBuilder.isValidToken(token) else { throw VideoBountyRefusal.invalidRequest }
        let request = try make(method: "GET", path: path, query: query, token: token, body: nil)
        try admit(request)
        return await perform(request, receiptReread: false)
    }

    private func sendNew(key: String, prefix: String, path: String, fields: [String: Any], token: String) async throws -> VideoBountyEnvelope {
        guard AuthRequestBuilder.isValidToken(token) else { throw VideoBountyRefusal.invalidRequest }
        guard let requestID = JourneyLoopSource.makeRequestID(prefix: prefix, nowMillis: nowMillis(), entropy: entropy()) else {
            throw VideoBountyRefusal.invalidRequest
        }
        var fields = fields
        fields["requestId"] = requestID
        let data = try Self.json(fields)
        store.write(key, requestID)
        store.write(Self.bodyKey(key), String(decoding: data, as: UTF8.self))
        do {
            let request = try make(method: "POST", path: path, token: token, body: data)
            try admit(request)
            let result = await perform(request, receiptReread: false)
            return settle(key: key, result: result)
        } catch VideoBountyRefusal.notAdmitted {
            store.remove(key)
            store.remove(Self.bodyKey(key))
            throw VideoBountyRefusal.notAdmitted
        }
    }

    private func sendLocked(key: String, path: String, token: String) async throws -> VideoBountyEnvelope {
        guard AuthRequestBuilder.isValidToken(token) else { throw VideoBountyRefusal.invalidRequest }
        guard let requestID = store.read(key), JourneyLoopSource.isRequestID(requestID),
              let text = store.read(Self.bodyKey(key)), !text.isEmpty else {
            throw VideoBountyRefusal.noSavedRequest
        }
        let request = try make(method: "POST", path: path, token: token, body: Data(text.utf8))
        try admit(request)
        let result = await perform(request, receiptReread: true)
        return settle(key: key, result: result)
    }

    private func settle(key: String, result: VideoBountyEnvelope) -> VideoBountyEnvelope {
        if result.confirmed {
            store.remove(key)
            store.remove(Self.bodyKey(key))
        }
        return result
    }

    private func admit(_ request: URLRequest) throws {
        guard let url = request.url else { throw VideoBountyRefusal.notAdmitted }
        let relative = "/" + url.path.split(separator: "/").drop(while: { $0 == "prod-api" }).map(String.init).joined(separator: "/")
        let key = ChinaReviewedRouteCapability.normalized(relative)
        guard Self.paths.contains(key), !Self.blocked.contains(where: { key.contains($0) }) else {
            throw VideoBountyRefusal.notAdmitted
        }
        do {
            try ChinaReviewedRouteCapability.refuseUnwiredChinaProduction(request)
        } catch {
            throw VideoBountyRefusal.notAdmitted
        }
    }

    private func make(method: String, path: String, query: [URLQueryItem] = [], token: String, body: Data?) throws -> URLRequest {
        var url = path.split(separator: "/").reduce(configuration.baseURL) { partial, part in
            partial.appendingPathComponent(String(part))
        }
        if !query.isEmpty {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { throw VideoBountyRefusal.invalidRequest }
            components.queryItems = query
            guard let built = components.url else { throw VideoBountyRefusal.invalidRequest }
            url = built
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.httpShouldHandleCookies = false
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        return request
    }

    private func perform(_ request: URLRequest, receiptReread: Bool) async -> VideoBountyEnvelope {
        do {
            let (data, status) = try await transport.send(request)
            return Self.envelope(data: data, status: status, receiptReread: receiptReread)
        } catch {
            var failure = VideoBountyEnvelope.networkFailure
            failure = VideoBountyEnvelope(httpStatus: failure.httpStatus, code: failure.code, reasonCode: failure.reasonCode,
                                          message: failure.message, dataJSON: nil, netFail: true, receiptReread: receiptReread)
            return failure
        }
    }

    private static func bodyKey(_ key: String) -> String { key + ":body" }

    static func envelope(data: Data, status: Int, receiptReread: Bool) -> VideoBountyEnvelope {
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let code = object.flatMap { codeString($0["code"]) } ?? (object == nil ? String(status) : nil)
        let reason = object.flatMap { $0["reasonCode"] as? String }
        let message = object?["msg"] as? String
        return VideoBountyEnvelope(httpStatus: status, code: code ?? String(status), reasonCode: reason,
                                   message: message, dataJSON: Self.jsonData(object?["data"] as Any?),
                                   netFail: false, receiptReread: receiptReread)
    }

    private static func submitFields(campaignKey: String, topicID: String, platform: String,
                                     sourceURL: String, originGroupKey: String) throws -> [String: Any] {
        let key = campaignKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let link = sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let group = originGroupKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...40).contains(key.utf8.count), campaignKeyAllowed(key),
              isID(topicID), let topic = Int64(topicID),
              ["tiktok", "reels", "youtube"].contains(platform),
              !link.isEmpty, link.utf8.count <= 512,
              group.utf8.count <= 64 else { throw VideoBountyRefusal.invalidRequest }
        var fields: [String: Any] = [
            "campaignKey": key,
            "topicId": NSNumber(value: topic),
            "platform": platform,
            "sourceUrl": link
        ]
        fields["originGroupKey"] = group.isEmpty ? NSNull() : group
        return fields
    }

    private static func appealNote(_ note: String) throws -> String {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.utf16.count <= 500 else { throw VideoBountyRefusal.invalidRequest }
        return trimmed
    }

    private static func actionPath(_ submissionID: String, action: String) throws -> String {
        guard isID(submissionID), !submissionID.contains("/") else { throw VideoBountyRefusal.invalidRequest }
        return "/api/video-bounty/submission/" + submissionID + "/" + action
    }

    private static func campaignKeyAllowed(_ key: String) -> Bool {
        guard let first = key.unicodeScalars.first, asciiAlphaNumeric(first) else { return false }
        return key.unicodeScalars.allSatisfy { asciiAlphaNumeric($0) || $0 == "-" || $0 == "_" }
    }

    private static func asciiAlphaNumeric(_ scalar: Unicode.Scalar) -> Bool {
        (48...57).contains(scalar.value) || (65...90).contains(scalar.value) || (97...122).contains(scalar.value)
    }

    private static func isID(_ value: String) -> Bool {
        guard (1...19).contains(value.utf8.count), value.utf8.first != 48 else { return false }
        return value.utf8.allSatisfy { (48...57).contains($0) }
    }

    private static func json(_ fields: [String: Any]) throws -> Data {
        guard JSONSerialization.isValidJSONObject(fields),
              let data = try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]) else {
            throw VideoBountyRefusal.invalidRequest
        }
        return data
    }

    private static func array(_ data: Data?) -> [[String: Any]]? {
        guard let data, let value = try? JSONSerialization.jsonObject(with: data) else { return nil }
        guard let rows = value as? [Any] else { return nil }
        return rows.compactMap { $0 as? [String: Any] }
    }

    private static func submission(_ row: [String: Any]) -> VideoBountySubmissionFact? {
        guard let id = identifier(row["id"]) else { return nil }
        let label = row["statusLabel"] as? String
        let status = ["SUBMITTED", "UNDER_REVIEW", "APPROVED", "REJECTED", "REVOKED", "APPEALING", "CANCELLED"].contains(label ?? "")
            ? label! : "UNKNOWN"
        let platform = row["platform"] as? String
        let knownPlatform = ["tiktok", "reels", "youtube"].contains(platform ?? "") ? platform : nil
        let url = (row["sourceUrl"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let note = status == "REJECTED" ? nonEmpty(row["reviewNote"] as? String) : nil
        let window = status == "APPROVED" ? dotDay(row["windowEndsAt"]) : nil
        return VideoBountySubmissionFact(
            id: id, platform: knownPlatform, sourceURL: url, statusLabel: status, reviewNote: note, windowEndText: window,
            canAppeal: status == "REJECTED",
            canCancel: ["SUBMITTED", "UNDER_REVIEW", "REJECTED", "APPEALING"].contains(status))
    }

    private static func accrual(_ row: [String: Any]) -> VideoBountyAccrualFact? {
        guard let id = identifier(row["id"]) else { return nil }
        return VideoBountyAccrualFact(id: id, amountText: amountText(payable: row["payableAmount"], currency: row["currency"]),
                                      views: whole(row["basisViews"]), groupViews: whole(row["groupBasisViews"]))
    }

    private static func campaign(_ row: [String: Any]) -> VideoBountyCampaign? {
        guard let key = row["campaignKey"] as? String else { return nil }
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return VideoBountyCampaign(campaignKey: trimmed, title: nonEmpty(row["title"] as? String),
                                   description: nonEmpty(row["description"] as? String), windowDays: whole(row["windowDays"]))
    }

    private static func identifier(_ value: Any?) -> String? {
        if let text = value as? String, isID(text) { return text }
        guard let number = jsonNumber(value), let whole = whole(number), whole > 0 else { return nil }
        return String(whole)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func whole(_ value: Any?) -> Int? {
        guard let number = jsonNumber(value) else { return nil }
        return whole(number)
    }

    private static func whole(_ number: NSNumber) -> Int? {
        let value = number.doubleValue
        guard value.isFinite, value.rounded() == value, value <= Double(Int.max), value >= Double(Int.min) else { return nil }
        return Int(value)
    }

    private static func decimal(_ value: Any?) -> Decimal? {
        if value is NSNull || value == nil { return nil }
        if let text = value as? String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let decimal = Decimal(string: trimmed, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
            return decimal
        }
        guard let number = jsonNumber(value) else { return nil }
        let double = number.doubleValue
        guard double.isFinite else { return nil }
        return Decimal(string: number.stringValue, locale: Locale(identifier: "en_US_POSIX"))
    }

    private static func fixedTwo(_ decimal: Decimal) -> String? {
        var source = decimal
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, 2, .plain)
        let negative = rounded < 0
        if negative {
            var minus = Decimal(-1)
            var positive = Decimal()
            NSDecimalMultiply(&positive, &rounded, &minus, .plain)
            rounded = positive
        }
        var cents = Decimal()
        var hundred = Decimal(100)
        NSDecimalMultiply(&cents, &rounded, &hundred, .plain)
        var whole = Decimal()
        NSDecimalRound(&whole, &cents, 0, .plain)
        let raw = NSDecimalNumber(decimal: whole).stringValue
        guard let int = Int64(raw), raw.allSatisfy({ $0.isNumber }) else { return nil }
        return (negative ? "-" : "") + "\(int / 100)." + String(format: "%02lld", int % 100)
    }

    private static func dotDay(_ value: Any?) -> String? {
        let ms: Int64?
        if let text = value as? String {
            ms = MoneyParityTime.timestamp(text)
        } else if let number = jsonNumber(value) {
            ms = MoneyParityTime.timestamp(number: number.doubleValue)
        } else {
            ms = nil
        }
        guard let ms else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        let date = Date(timeIntervalSince1970: TimeInterval(ms + MoneyParityTime.chinaOffsetMs) / 1000)
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
        return String(format: "%04d.%02d.%02d", year, month, day)
    }

    private static func jsonNumber(_ value: Any?) -> NSNumber? {
        guard let number = value as? NSNumber else { return nil }
        if CFGetTypeID(number as CFTypeRef) == CFBooleanGetTypeID() { return nil }
        return number
    }

    private static func codeString(_ value: Any?) -> String? {
        guard let value else { return nil }
        if let text = value as? String { return text }
        guard let number = jsonNumber(value) else { return nil }
        let double = number.doubleValue
        guard double.rounded() == double, abs(double) <= Double(Int.max) else { return nil }
        return String(Int(double))
    }

    private static func jsonData(_ value: Any?) -> Data? {
        guard let value, !(value is NSNull), JSONSerialization.isValidJSONObject(value) else { return nil }
        return try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    }
}
