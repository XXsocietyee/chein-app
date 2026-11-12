import Foundation
import CoreFoundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum JourneyRefusal: Error, Equatable, Sendable {
    case invalidRequest
    case productionEndpoint
    case moneyOff
    case noSavedRequest
}

/// Result of one `journey-api.js` `call`. HTTP and business failures stay in the value.
/// A transport failure is `netFail` with `code == "fail"`, the same shape as the mini-program `fail` callback.
public struct JourneyEnvelope: Equatable, Sendable {
    public let httpStatus: Int?
    public let code: String?
    public let netFail: Bool
    public let message: String?
    public let dataJSON: Data?
    public let receiptReread: Bool

    public var ok: Bool { code == "200" }

    /// Timeout, transport failure, or a 5xx code. The saved request id stays. A 4xx is a finished answer.
    public var unconfirmed: Bool {
        if netFail || code == "fail" { return true }
        if let code, let number = Int(code), number >= 500 { return true }
        return false
    }

    public static let networkFailure = JourneyEnvelope(
        httpStatus: nil, code: "fail", netFail: true, message: "网络异常，请重试", dataJSON: nil, receiptReread: false)
}

/// Keys the mini-program already uses for a retained seat request id.
/// Cancel is kept here too: `journey-api.js` says the caller retains every write id and does not mint a new one on timeout.
public enum JourneyRequestKey {
    public static func seatInvite(_ registrationID: String) -> String { "journey-seat-invite:" + registrationID }
    public static func seatClaim(_ token: String) -> String { "journey-claim:seat:" + String(token.suffix(24)) }
    public static func seatCancel(_ invitationID: String) -> String { "journey-seat-cancel:" + invitationID }
}

public protocol JourneyRequestStoring: AnyObject, Sendable {
    func read(_ key: String) -> String?
    func write(_ key: String, _ value: String)
    func remove(_ key: String)
}

public final class JourneyMemoryRequestStore: JourneyRequestStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String] = [:]
    public init() {}
    public func read(_ key: String) -> String? { lock.lock(); defer { lock.unlock() }; return values[key] }
    public func write(_ key: String, _ value: String) { lock.lock(); defer { lock.unlock() }; values[key] = value }
    public func remove(_ key: String) { lock.lock(); defer { lock.unlock() }; values.removeValue(forKey: key) }
}

/// Port of `subpackageJourney/utils/journey-api.js`. Reads and the three seat writes go out.
/// Issuing a referral link and claiming a gift do not: money stays off. Seat release is not an export.
public struct JourneyLoopSource {
    public static let moneyWritesEnabled = false
    /// hengyin `journey-api.js`. The export table lives here: `App/MPParityKit.swift` already owns `struct MPParityBindings`.
    public static let sourceRevision = "1c80c5aea8f721ca8575e6108048495b100f5576"

    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    private let store: any JourneyRequestStoring
    private let nowMillis: @Sendable () -> Int64
    private let entropy: @Sendable () -> String

    public enum EndpointClass: String, Equatable, Sendable {
        case production
        case nonProduction
    }

    public init(configuration: APIConfiguration, transport: any HTTPTransport,
                store: any JourneyRequestStoring = JourneyMemoryRequestStore(),
                endpointClass: EndpointClass = .nonProduction,
                nowMillis: @escaping @Sendable () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) },
                entropy: @escaping @Sendable () -> String = { JourneyLoopSource.randomEntropy() }) throws {
        let host = configuration.baseURL.host ?? ""
        guard endpointClass != .production, !PWaveProductionBoundary.isProductionHost(host) else {
            throw JourneyRefusal.productionEndpoint
        }
        self.configuration = configuration
        self.transport = transport
        self.store = store
        self.nowMillis = nowMillis
        self.entropy = entropy
    }

    // MARK: Reads

    public func report(activityID: String? = nil, topicID: String? = nil, runID: String? = nil, token: String) async throws -> JourneyEnvelope {
        try await get(.report, query: Self.idQuery([("activityId", activityID), ("topicId", topicID), ("runId", runID)]), token: token)
    }

    public func memory(activityID: String? = nil, topicID: String? = nil, runID: String? = nil, token: String) async throws -> JourneyEnvelope {
        try await get(.memory, query: Self.idQuery([("activityId", activityID), ("topicId", topicID), ("runId", runID)]), token: token)
    }

    public func choices(activityID: String? = nil, topicID: String? = nil, token: String) async throws -> JourneyEnvelope {
        try await get(.choices, query: Self.idQuery([("activityId", activityID), ("topicId", topicID)]), token: token)
    }

    public func seats(registrationID: String, token: String) async throws -> JourneyEnvelope {
        guard Self.isID(registrationID) else { throw JourneyRefusal.invalidRequest }
        return try await get(.seats, query: [URLQueryItem(name: "registrationId", value: registrationID)], token: token)
    }

    public func rank(scope: String?, scopeID: String?, period: String?, token: String) async throws -> JourneyEnvelope {
        try await get(.rank, query: Self.idQuery([("scope", scope), ("scopeId", scopeID), ("period", period)]), token: token)
    }

    public func teamDetail(teamID: String, token: String) async throws -> JourneyEnvelope {
        guard Self.isID(teamID) else { throw JourneyRefusal.invalidRequest }
        return try await get(.teamDetail, query: [URLQueryItem(name: "teamId", value: teamID)], token: token)
    }

    public func teamRanking(ownerType: Int, ownerID: String, token: String) async throws -> JourneyEnvelope {
        guard ownerType == 1 || ownerType == 2, Self.isID(ownerID) else { throw JourneyRefusal.invalidRequest }
        return try await get(.teamRanking, query: [
            URLQueryItem(name: "ownerType", value: String(ownerType)),
            URLQueryItem(name: "ownerId", value: ownerID)
        ], token: token)
    }

    public func referral(token credential: String, sessionToken: String) async throws -> JourneyEnvelope {
        guard Self.acceptableToken(credential) else { throw JourneyRefusal.invalidRequest }
        return try await postJSON(.referral, body: ["token": credential], token: sessionToken, receiptReread: false)
    }

    public func gift(token credential: String, sessionToken: String) async throws -> JourneyEnvelope {
        guard Self.acceptableToken(credential) else { throw JourneyRefusal.invalidRequest }
        return try await postJSON(.gift, body: ["token": credential], token: sessionToken, receiptReread: false)
    }

    public func affiliate(token: String) async throws -> JourneyEnvelope {
        try await get(.affiliate, query: [URLQueryItem(name: "limit", value: "20")], token: token)
    }

    public func seatInvitation(id: String, token: String) async throws -> JourneyEnvelope {
        try await get(.seatInvitation, invitationID: id, query: [], token: token)
    }

    /// Form post, matching `rate` (`form: true` in journey-api.js). Not a money write.
    public func rate(ownerType: Int, ownerID: String, rating: Int, contents: String, token: String) async throws -> JourneyEnvelope {
        guard Self.isID(ownerID), (1...5).contains(rating), contents.utf8.count <= 2000 else { throw JourneyRefusal.invalidRequest }
        let fields = [
            "owner_type": String(ownerType),
            "owner_id": ownerID,
            "rating": String(rating),
            "contents": contents,
            "reply_id": "0"
        ]
        return try await postForm(.rate, fields: fields, token: token)
    }

    // MARK: Money stays off

    public func issueReferral(targetType: Int, targetID: String, token: String) throws -> JourneyEnvelope {
        _ = (targetType, targetID, token)
        throw JourneyRefusal.moneyOff
    }

    public func giftClaim(token credential: String, requestID: String, sessionToken: String) throws -> JourneyEnvelope {
        _ = (credential, requestID, sessionToken)
        throw JourneyRefusal.moneyOff
    }

    // MARK: Seat writes

    public func seatInvite(registrationID: String, token: String) async throws -> JourneyEnvelope {
        try await write(.seatInvite, key: JourneyRequestKey.seatInvite(registrationID), prefix: "seatinv", token: token) { requestID in
            ["registrationId": registrationID, "requestId": requestID]
        } validate: {
            guard Self.isID(registrationID) else { throw JourneyRefusal.invalidRequest }
        }
    }

    public func seatClaim(token credential: String, sessionToken: String) async throws -> JourneyEnvelope {
        try await write(.seatClaim, key: JourneyRequestKey.seatClaim(credential), prefix: "seat", token: sessionToken) { requestID in
            ["token": credential, "requestId": requestID]
        } validate: {
            guard Self.acceptableToken(credential) else { throw JourneyRefusal.invalidRequest }
        }
    }

    public func seatCancel(invitationID: String, token: String) async throws -> JourneyEnvelope {
        try await write(.seatCancel, key: JourneyRequestKey.seatCancel(invitationID), prefix: "seatcxl", token: token, invitationID: invitationID) { requestID in
            ["requestId": requestID]
        } validate: {
            guard Self.isID(invitationID) else { throw JourneyRefusal.invalidRequest }
        }
    }

    /// One more POST of the saved invite id. Does not mint a replacement. The server replays the stored receipt.
    public func rereadSeatInvite(registrationID: String, token: String) async throws -> JourneyEnvelope {
        let key = JourneyRequestKey.seatInvite(registrationID)
        guard Self.isID(registrationID) else { throw JourneyRefusal.invalidRequest }
        return try await reread(.seatInvite, key: key, token: token) { requestID in
            ["registrationId": registrationID, "requestId": requestID]
        }
    }

    public func rereadSeatClaim(token credential: String, sessionToken: String) async throws -> JourneyEnvelope {
        let key = JourneyRequestKey.seatClaim(credential)
        guard Self.acceptableToken(credential) else { throw JourneyRefusal.invalidRequest }
        return try await reread(.seatClaim, key: key, token: sessionToken) { requestID in
            ["token": credential, "requestId": requestID]
        }
    }

    public func rereadSeatCancel(invitationID: String, token: String) async throws -> JourneyEnvelope {
        let key = JourneyRequestKey.seatCancel(invitationID)
        guard Self.isID(invitationID) else { throw JourneyRefusal.invalidRequest }
        return try await reread(.seatCancel, key: key, token: token, invitationID: invitationID) { requestID in
            ["requestId": requestID]
        }
    }

    // MARK: Request ids and query

    /// Drops nil, "", "0", and 0. Other values are kept in order, matching `idQuery`.
    public static func idQuery(_ pairs: [(String, String?)]) -> [URLQueryItem] {
        pairs.compactMap { key, value in
            guard let value, value != "", value != "0" else { return nil }
            return URLQueryItem(name: key, value: value)
        }
    }

    public static func isRequestID(_ value: String) -> Bool {
        guard (1...64).contains(value.utf8.count) else { return false }
        return value.unicodeScalars.allSatisfy { scalar in
            let value = scalar.value
            return (48...57).contains(value) || (65...90).contains(value) || (97...122).contains(value)
                || value == 46 || value == 95 || value == 58 || value == 45
        }
    }

    /// Positive canonical id, the page's `isId` for a string (no leading zero, at most 19 digits).
    public static func isID(_ value: String) -> Bool {
        guard (1...19).contains(value.utf8.count), value.utf8.first != 48 else { return false }
        return value.utf8.allSatisfy { (48...57).contains($0) }
    }

    static func makeRequestID(prefix: String, nowMillis: Int64, entropy: String) -> String? {
        guard prefix.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) }),
              (1...16).contains(prefix.utf8.count),
              entropy.utf8.count == 8,
              entropy.unicodeScalars.allSatisfy({ ("0"..."9").contains($0) || ("a"..."z").contains($0) }) else { return nil }
        let millis = nowMillis < 0 ? 0 : nowMillis
        let id = prefix + "-" + base36(millis) + "-" + entropy
        return isRequestID(id) ? id : nil
    }

    public static func randomEntropy() -> String {
        let alphabet = Array("0123456789abcdefghijklmnopqrstuvwxyz")
        var generator = SystemRandomNumberGenerator()
        return String((0..<8).map { _ in alphabet[Int(generator.next(upperBound: UInt32(alphabet.count)))] })
    }

    // MARK: Private send

    private func get(_ name: Self.Journey, invitationID: String? = nil, query: [URLQueryItem], token: String) async throws -> JourneyEnvelope {
        let binding = Self.journey(name)
        guard !binding.money else { throw JourneyRefusal.moneyOff }
        guard AuthRequestBuilder.isValidToken(token) else { throw JourneyRefusal.invalidRequest }
        let path = try resolve(binding, invitationID: invitationID)
        let request = try make(method: "GET", path: path, query: query, token: token, body: nil, contentType: nil)
        return await perform(request, receiptReread: false)
    }

    private func postJSON(_ name: Self.Journey, invitationID: String? = nil, body: [String: String], token: String, receiptReread: Bool) async throws -> JourneyEnvelope {
        let binding = Self.journey(name)
        guard !binding.money, binding.json else { throw JourneyRefusal.moneyOff }
        guard AuthRequestBuilder.isValidToken(token) else { throw JourneyRefusal.invalidRequest }
        let path = try resolve(binding, invitationID: invitationID)
        let data = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        let request = try make(method: "POST", path: path, query: [], token: token, body: data, contentType: "application/json")
        return await perform(request, receiptReread: receiptReread)
    }

    private func postForm(_ name: Self.Journey, fields: [String: String], token: String) async throws -> JourneyEnvelope {
        let binding = Self.journey(name)
        guard !binding.money, binding.form else { throw JourneyRefusal.invalidRequest }
        guard AuthRequestBuilder.isValidToken(token) else { throw JourneyRefusal.invalidRequest }
        let order = ["owner_type", "owner_id", "rating", "contents", "reply_id"]
        let encoded = try order.map { key -> String in
            guard let value = fields[key] else { throw JourneyRefusal.invalidRequest }
            return try Self.formEscape(key) + "=" + Self.formEscape(value)
        }.joined(separator: "&")
        let request = try make(method: "POST", path: try resolve(binding, invitationID: nil), query: [], token: token,
                               body: Data(encoded.utf8), contentType: "application/x-www-form-urlencoded;")
        return await perform(request, receiptReread: false)
    }

    private func write(_ name: Self.Journey, key: String, prefix: String, token: String, invitationID: String? = nil,
                       body: (String) -> [String: String], validate: () throws -> Void) async throws -> JourneyEnvelope {
        try validate()
        guard let requestID = retainedOrNew(key: key, prefix: prefix) else { throw JourneyRefusal.invalidRequest }
        store.write(key, requestID)
        let result = try await postJSON(name, invitationID: invitationID, body: body(requestID), token: token, receiptReread: false)
        return settle(key: key, result: result)
    }

    private func reread(_ name: Self.Journey, key: String, token: String, invitationID: String? = nil,
                        body: (String) -> [String: String]) async throws -> JourneyEnvelope {
        guard let requestID = store.read(key), Self.isRequestID(requestID) else { throw JourneyRefusal.noSavedRequest }
        let result = try await postJSON(name, invitationID: invitationID, body: body(requestID), token: token, receiptReread: true)
        return settle(key: key, result: result)
    }

    private func retainedOrNew(key: String, prefix: String) -> String? {
        if let saved = store.read(key), Self.isRequestID(saved) { return saved }
        return Self.makeRequestID(prefix: prefix, nowMillis: nowMillis(), entropy: entropy())
    }

    private func settle(key: String, result: JourneyEnvelope) -> JourneyEnvelope {
        if !result.unconfirmed { store.remove(key) }
        return result
    }

    private func resolve(_ binding: Self.JourneyCase, invitationID: String?) throws -> String {
        guard binding.path.contains("{invitationId}") else { return binding.path }
        guard let invitationID, Self.isID(invitationID), !invitationID.contains("/") else { throw JourneyRefusal.invalidRequest }
        return binding.path.replacingOccurrences(of: "{invitationId}", with: invitationID)
    }

    private func make(method: String, path: String, query: [URLQueryItem], token: String, body: Data?, contentType: String?) throws -> URLRequest {
        var url = path.split(separator: "/").reduce(configuration.baseURL) { partial, part in
            partial.appendingPathComponent(String(part))
        }
        if !query.isEmpty {
            var parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
            parts?.queryItems = query
            guard let built = parts?.url else { throw JourneyRefusal.invalidRequest }
            url = built
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.httpShouldHandleCookies = false
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let contentType { request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        request.httpBody = body
        return request
    }

    private func perform(_ request: URLRequest, receiptReread: Bool) async -> JourneyEnvelope {
        do {
            let (data, status) = try await transport.send(request)
            return Self.envelope(data: data, status: status, receiptReread: receiptReread)
        } catch {
            let failure = JourneyEnvelope.networkFailure
            return JourneyEnvelope(httpStatus: failure.httpStatus, code: failure.code, netFail: failure.netFail,
                                   message: failure.message, dataJSON: nil, receiptReread: receiptReread)
        }
    }

    static func envelope(data: Data, status: Int, receiptReread: Bool) -> JourneyEnvelope {
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let code = object.flatMap { Self.codeString($0["code"]) } ?? (object == nil ? String(status) : nil)
        let resolved = code ?? String(status)
        let message = object?["msg"] as? String
        return JourneyEnvelope(httpStatus: status, code: resolved, netFail: false, message: message,
                               dataJSON: Self.jsonData(object?["data"] as Any?), receiptReread: receiptReread)
    }

    private static func codeString(_ value: Any?) -> String? {
        guard let value else { return nil }
        if let text = value as? String { return text }
        if let number = value as? NSNumber {
            if CFGetTypeID(number as CFTypeRef) == CFBooleanGetTypeID() { return nil }
            let double = number.doubleValue
            guard double.rounded() == double, abs(double) <= Double(Int.max) else { return nil }
            return String(Int(double))
        }
        return nil
    }

    private static func jsonData(_ value: Any?) -> Data? {
        guard let value, !(value is NSNull), JSONSerialization.isValidJSONObject(value) else { return nil }
        return try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    }

    static func acceptableToken(_ token: String) -> Bool {
        !token.isEmpty && token.utf16.count <= 512 && token.unicodeScalars.allSatisfy { $0.value >= 32 && $0.value != 127 }
    }

    private static func base36(_ value: Int64) -> String {
        let digits = Array("0123456789abcdefghijklmnopqrstuvwxyz")
        var number = UInt64(value < 0 ? 0 : value)
        if number == 0 { return "0" }
        var characters: [Character] = []
        while number > 0 {
            characters.append(digits[Int(number % 36)])
            number /= 36
        }
        return String(characters.reversed())
    }

    private static func formEscape(_ raw: String) throws -> String {
        // ASCII only. CharacterSet.alphanumerics includes non-ASCII letters, which a form body must still encode.
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        guard let encoded = raw.addingPercentEncoding(withAllowedCharacters: allowed) else { throw JourneyRefusal.invalidRequest }
        return encoded
    }
}

extension JourneyLoopSource {
    public static let landingPage = "subpackageJourney/pages/landing/index"

    /// One case per `journey-api.js` export. `money` cases stay named and are not sent.
    public enum Journey: String, CaseIterable, Equatable, Sendable {
        case report
        case memory
        case choices
        case seats
        case rank
        case teamDetail
        case teamRanking
        case rate
        case referral
        case gift
        case issueReferral
        case affiliate
        case seatInvite
        case seatInvitation
        case seatClaim
        case seatCancel
        case giftClaim
    }

    public struct JourneyCase: Equatable, Sendable {
        public let name: Journey
        public let method: String
        public let path: String
        public let json: Bool
        public let form: Bool
        /// Issue-link and gift-claim writes. Seat invite, cancel, and claim are not money.
        public let money: Bool
        public var sendsWhileMoneyOff: Bool { !money }
    }

    public static let journey: [JourneyCase] = [
        JourneyCase(name: .report, method: "GET", path: "/api/play/player-journey/report", json: false, form: false, money: false),
        JourneyCase(name: .memory, method: "GET", path: "/api/play/player-journey/memory", json: false, form: false, money: false),
        JourneyCase(name: .choices, method: "GET", path: "/api/play/player-journey/choices", json: false, form: false, money: false),
        JourneyCase(name: .seats, method: "GET", path: "/api/play/player-journey/seats", json: false, form: false, money: false),
        JourneyCase(name: .rank, method: "GET", path: "/api/rank/list", json: false, form: false, money: false),
        JourneyCase(name: .teamDetail, method: "GET", path: "/api/orient/team/detail", json: false, form: false, money: false),
        JourneyCase(name: .teamRanking, method: "GET", path: "/api/orient/team/ranking", json: false, form: false, money: false),
        JourneyCase(name: .rate, method: "POST", path: "/api/comment/add", json: false, form: true, money: false),
        JourneyCase(name: .referral, method: "POST", path: "/api/referral/landing/referral", json: true, form: false, money: false),
        JourneyCase(name: .gift, method: "POST", path: "/api/referral/landing/gift", json: true, form: false, money: false),
        JourneyCase(name: .issueReferral, method: "POST", path: "/api/marketing/referral/token", json: true, form: false, money: true),
        JourneyCase(name: .affiliate, method: "GET", path: "/api/marketing/affiliate/summary", json: false, form: false, money: false),
        JourneyCase(name: .seatInvite, method: "POST", path: "/api/play/seat-invitations/invite", json: true, form: false, money: false),
        JourneyCase(name: .seatInvitation, method: "GET", path: "/api/play/seat-invitations/{invitationId}", json: false, form: false, money: false),
        JourneyCase(name: .seatClaim, method: "POST", path: "/api/play/seat-invitations/claim", json: true, form: false, money: false),
        JourneyCase(name: .seatCancel, method: "POST", path: "/api/play/seat-invitations/{invitationId}/cancel", json: true, form: false, money: false),
        JourneyCase(name: .giftClaim, method: "POST", path: "/api/marketing/product/gifts/claim", json: true, form: false, money: true)
    ]

    public static func journey(_ name: Journey) -> JourneyCase {
        guard let item = journey.first(where: { $0.name == name }) else {
            preconditionFailure("journey case \(name.rawValue) missing from the parity table")
        }
        return item
    }

    /// `subpackageJourney/pages/landing/index?k=r|g|s&t=` plus optional `aid` / `tid`. Also accepts a `chein://` URL.
    /// A link only classifies the landing. It does not claim, pay, or start a run.
    public static func journeyLink(miniProgramPath path: String) -> CheinDeepLink? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.utf8.count <= 2048, !trimmed.contains("#") else { return nil }
        if trimmed.lowercased().hasPrefix("chein:") {
            return URL(string: trimmed).flatMap { CheinDeepLink(url: $0) }
        }
        var text = trimmed
        while text.hasPrefix("/") { text.removeFirst() }
        guard let components = URLComponents(string: "https://journey.invalid/" + text),
              components.path == "/" + landingPage else { return nil }
        return CheinDeepLink(landingQuery: components.queryItems ?? [])
    }
}
