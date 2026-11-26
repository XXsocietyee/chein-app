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
    /// Top-level `reasonCode` from `journey-api.js` `call` (`Object.assign({ httpStatus }, body)`).
    /// Report and settle use it for `RUN_NOT_FOUND` / `RUN_SCOPE_MISMATCH`. A number is not a code.
    public let reasonCode: String?

    public init(httpStatus: Int?, code: String?, netFail: Bool, message: String?, dataJSON: Data?, receiptReread: Bool, reasonCode: String? = nil) {
        self.httpStatus = httpStatus
        self.code = code
        self.netFail = netFail
        self.message = message
        self.dataJSON = dataJSON
        self.receiptReread = receiptReread
        self.reasonCode = reasonCode
    }

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
    /// `landing/index.js` `storeKey('gift', token)` → `journey-claim:gift:` + the last 24 characters.
    public static func giftClaim(_ token: String) -> String { "journey-claim:gift:" + String(token.suffix(24)) }
    public static func seatCancel(_ invitationID: String) -> String { "journey-seat-cancel:" + invitationID }
    /// One id per registration, seat, trimmed name, and normalized phone. A form edit mints a new id.
    public static func seatTransferPhone(registrationID: String, seatNo: Int, name: String, phone: String) -> String {
        "journey-seat-phone:" + registrationID + ":" + String(seatNo) + ":" + name + ":" + phone
    }
    /// U08-02: one retained id per run until the server gives a finished answer.
    public static func runFeedback(_ runID: String) -> String { "journey-run-feedback:" + runID }
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
/// Issuing a referral link and claiming a gift do not: money stays off.
/// The affiliate summary is the read `GET /api/marketing/affiliate/summary?limit=20`.
/// A production host is refused unless `productionLease` names that host. Seat release is not an export.
public struct JourneyLoopSource {
    public static let moneyWritesEnabled = false
    /// hengyin `journey-api.js`. The export table lives here: `App/MPParityKit.swift` already owns `struct MPParityBindings`.
    public static let sourceRevision = "1c80c5aea8f721ca8575e6108048495b100f5576"

    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    private let store: any JourneyRequestStoring
    private let nowMillis: @Sendable () -> Int64
    private let entropy: @Sendable () -> String
    private let productionLease: JourneyProductionLease?

    public enum EndpointClass: String, Equatable, Sendable {
        case production
        case nonProduction
    }

    public init(configuration: APIConfiguration, transport: any HTTPTransport,
                store: any JourneyRequestStoring = JourneyMemoryRequestStore(),
                endpointClass: EndpointClass = .nonProduction,
                nowMillis: @escaping @Sendable () -> Int64 = { Int64(Date().timeIntervalSince1970 * 1000) },
                entropy: @escaping @Sendable () -> String = { JourneyLoopSource.randomEntropy() },
                productionLease: JourneyProductionLease? = nil) throws {
        let host = (configuration.baseURL.host ?? "").lowercased()
        let production = endpointClass == .production || PWaveProductionBoundary.isProductionHost(host)
        if production {
            guard let productionLease, productionLease.host == host,
                  PWaveProductionBoundary.isProductionHost(host) else {
                throw JourneyRefusal.productionEndpoint
            }
            self.productionLease = productionLease
        } else {
            self.productionLease = nil
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

    /// `@Anonymous` on the server (`ApiReferralLandingController`): a signed-out invitee reads the landing too.
    /// A nil session sends no Authorization header; a present one must still be a valid token.
    public func referral(token credential: String, sessionToken: String?) async throws -> JourneyEnvelope {
        guard Self.acceptableToken(credential) else { throw JourneyRefusal.invalidRequest }
        return try await postLanding(.referral, credential: credential, sessionToken: sessionToken)
    }

    public func gift(token credential: String, sessionToken: String?) async throws -> JourneyEnvelope {
        guard Self.acceptableToken(credential) else { throw JourneyRefusal.invalidRequest }
        return try await postLanding(.gift, credential: credential, sessionToken: sessionToken)
    }

    /// Form `POST /api/topic/info-to-user` (`id=`), the read the seats and settle pages use for the topic name and cover.
    /// `@Anonymous` on the server; a nil session sends no Authorization header. Not a write.
    public func topicInfo(id: String, token: String?) async throws -> JourneyEnvelope {
        guard Self.isID(id) else { throw JourneyRefusal.invalidRequest }
        if let token, !AuthRequestBuilder.isValidToken(token) { throw JourneyRefusal.invalidRequest }
        let request = try make(method: "POST", path: "/api/topic/info-to-user", query: [], token: token,
                               body: Data("id=\(id)".utf8), contentType: "application/x-www-form-urlencoded;")
        return await perform(request, receiptReread: false)
    }

    public func affiliate(token: String) async throws -> JourneyEnvelope {
        try await get(.affiliate, query: [URLQueryItem(name: "limit", value: "20")], token: token)
    }

    public func seatInvitation(id: String, token: String) async throws -> JourneyEnvelope {
        try await get(.seatInvitation, invitationID: id, query: [], token: token)
    }

    /// Form post, matching `rate` (`form: true` in journey-api.js). Not a money write.
    /// Settle rating. `requestID` is one submit intent, reused on retry. Server accepts `[A-Za-z0-9_-]{16,64}`.
    public func rate(ownerType: Int, ownerID: String, rating: Int, contents: String, requestID: String, token: String) async throws -> JourneyEnvelope {
        guard ownerType == 1 || ownerType == 2 else { throw JourneyRefusal.invalidRequest }
        guard Self.isID(ownerID), (1...5).contains(rating), contents.utf8.count <= 2000 else { throw JourneyRefusal.invalidRequest }
        guard Self.isCommentRequestID(requestID) else { throw JourneyRefusal.invalidRequest }
        let fields = [
            "owner_type": String(ownerType),
            "owner_id": ownerID,
            "rating": String(rating),
            "contents": contents,
            "reply_id": "0",
            "request_id": requestID
        ]
        return try await postForm(.rate, fields: fields, token: token)
    }

    public static func isCommentRequestID(_ value: String) -> Bool {
        guard (16...64).contains(value.utf8.count) else { return false }
        return value.unicodeScalars.allSatisfy { scalar in
            let code = scalar.value
            return (48...57).contains(code) || (65...90).contains(code) || (97...122).contains(code) || code == 45 || code == 95
        }
    }

    /// Empty multipart `POST /api/user/info`, the same self read the profile editor uses. Not a write.
    public func playerProfile(token: String) async throws -> JourneyEnvelope {
        guard AuthRequestBuilder.isValidToken(token) else { throw JourneyRefusal.invalidRequest }
        var request = try make(method: "POST", path: "/api/user/info", query: [], token: token, body: nil, contentType: nil)
        let boundary = "JourneyProfileRead"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("--\(boundary)--\r\n".utf8)
        return await perform(request, receiptReread: false)
    }

    // MARK: Money stays off

    /// Synchronous legacy entry: never sends. The live issue is `issueReferralToken` (JREF-r11-1).
    public func issueReferral(targetType: Int, targetID: String, token: String) throws -> JourneyEnvelope {
        _ = (targetType, targetID, token)
        throw JourneyRefusal.moneyOff
    }

    /// JREF-r11-1: `POST /api/marketing/referral/token` JSON `{targetType, targetId}` (MP
    /// subpackageJourney/utils/journey-api.js:48). Sent only when the player taps share (MP settle/index.js:264-279,
    /// report/index.js:132-147). Referral attribution feeds payouts, so it follows the payout money switch
    /// (`ReleaseMoneyWriteSwitch.payoutEnabled`, on in Release since owner 2026-11-25); with it off nothing is sent.
    public func issueReferralToken(targetType: Int, targetID: String, token: String) async throws -> JourneyEnvelope {
        guard ReleaseMoneyWriteSwitch.payoutEnabled else { throw JourneyRefusal.moneyOff }
        guard targetType == 1 || targetType == 2, Self.isID(targetID), let target = Int(targetID),
              AuthRequestBuilder.isValidToken(token) else { throw JourneyRefusal.invalidRequest }
        let path = try resolve(Self.journey(.issueReferral))
        let body: [String: Any] = ["targetType": NSNumber(value: targetType), "targetId": NSNumber(value: target)]
        let data = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        let request = try make(method: "POST", path: path, query: [], token: token, body: data, contentType: "application/json")
        return await perform(request, receiptReread: false)
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

    /// `POST /api/play/seat-invitations/transfer-phone` JSON `{registrationId, seatNo, name, phone, requestId}`.
    /// `registrationId` and `seatNo` are numbers. `name` is trimmed (1–20). `phone` is the normalized mainland mobile.
    /// Not a money write. A same-form retry reuses the saved request id.
    public func seatTransferPhone(registrationID: String, seatNo: Int, name: String, phone: String, token: String) async throws -> JourneyEnvelope {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isID(registrationID), let registration = Int(registrationID),
              registration > 0, registration <= 9_007_199_254_740_991, seatNo > 1 else { throw JourneyRefusal.invalidRequest }
        guard (1...20).contains(trimmed.unicodeScalars.count), let mobile = Self.normalizeMobile(phone) else { throw JourneyRefusal.invalidRequest }
        let key = JourneyRequestKey.seatTransferPhone(registrationID: registrationID, seatNo: seatNo, name: trimmed, phone: mobile)
        guard let requestID = retainedOrNew(key: key, prefix: "seatphone") else { throw JourneyRefusal.invalidRequest }
        store.write(key, requestID)
        let body: [String: Any] = [
            "name": trimmed,
            "phone": mobile,
            "registrationId": NSNumber(value: registration),
            "requestId": requestID,
            "seatNo": NSNumber(value: seatNo)
        ]
        let result = try await postJSONObject(.seatTransferPhone, body: body, token: token, receiptReread: false)
        return settle(key: key, result: result)
    }

    /// `POST /api/play/seat-invitations/claim-phone/{token}` JSON `{}`. Not a money write.
    public func seatClaimPhone(token credential: String, sessionToken: String) async throws -> JourneyEnvelope {
        guard Self.acceptableToken(credential), !credential.contains("/") else { throw JourneyRefusal.invalidRequest }
        return try await postJSONObject(.seatClaimPhone, tokenSegment: credential, body: [:], token: sessionToken, receiptReread: false)
    }

    /// `GET /api/play/seat-invitations/mine`. Not a money write.
    public func seatMine(token: String) async throws -> JourneyEnvelope {
        try await get(.seatMine, query: [], token: token)
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

    // MARK: Post-game feedback (U08-02)

    /// On the reviewed production host the write goes out only once the path is in the owner's grant
    /// (`ChinaReviewedRouteCapability`); until then the entry stays hidden rather than failing as "unknown".
    public var sendsRunFeedback: Bool {
        productionLease == nil || ChinaReviewedRouteCapability.admitsChinaProductionCall(Self.journey(.runFeedback).path)
    }

    /// `POST /api/play/feedback/submit`. A retained id is reused until the answer is final; the caller keeps the
    /// draft unchanged while the answer is unknown, because new text under the same id is a 409.
    public func runFeedback(_ draft: PostGameFeedbackDraft, token: String) async throws -> JourneyEnvelope {
        try await write(.runFeedback, key: JourneyRequestKey.runFeedback(draft.runID), prefix: "runfb", token: token) { requestID in
            draft.body(requestID: requestID)
        } validate: {
            guard sendsRunFeedback else { throw JourneyRefusal.productionEndpoint }
            guard draft.problem == nil else { throw JourneyRefusal.invalidRequest }
        }
    }

    /// Same request id, same draft: the server returns the stored receipt instead of writing again.
    public func rereadRunFeedback(_ draft: PostGameFeedbackDraft, token: String) async throws -> JourneyEnvelope {
        guard sendsRunFeedback else { throw JourneyRefusal.productionEndpoint }
        guard draft.problem == nil else { throw JourneyRefusal.invalidRequest }
        return try await reread(.runFeedback, key: JourneyRequestKey.runFeedback(draft.runID), token: token) { requestID in
            draft.body(requestID: requestID)
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

    /// Mainland mobile after stripping spaces, dashes, and parentheses, and a leading +86 / 0086 / 86.
    public static func normalizeMobile(_ raw: String) -> String? {
        var digits = raw
        for mark in [" ", "-", "(", ")", "（", "）", "\u{00A0}"] {
            digits = digits.replacingOccurrences(of: mark, with: "")
        }
        if digits.hasPrefix("+86") { digits = String(digits.dropFirst(3)) }
        else if digits.hasPrefix("0086") { digits = String(digits.dropFirst(4)) }
        else if digits.count == 13, digits.hasPrefix("86") { digits = String(digits.dropFirst(2)) }
        guard digits.range(of: #"^1[3-9]\d{9}$"#, options: .regularExpression) != nil else { return nil }
        return digits
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

    private func get(_ name: Self.Journey, invitationID: String? = nil, tokenSegment: String? = nil, query: [URLQueryItem], token: String) async throws -> JourneyEnvelope {
        let binding = Self.journey(name)
        if productionLease != nil, JourneyProductionLease.refused.contains(name) { throw JourneyRefusal.moneyOff }
        guard !binding.money else { throw JourneyRefusal.moneyOff }
        guard AuthRequestBuilder.isValidToken(token) else { throw JourneyRefusal.invalidRequest }
        let path = try resolve(binding, invitationID: invitationID, tokenSegment: tokenSegment)
        let request = try make(method: "GET", path: path, query: query, token: token, body: nil, contentType: nil)
        return await perform(request, receiptReread: false)
    }

    private func postJSON(_ name: Self.Journey, invitationID: String? = nil, body: [String: String], token: String, receiptReread: Bool) async throws -> JourneyEnvelope {
        let binding = Self.journey(name)
        if productionLease != nil, JourneyProductionLease.refused.contains(name) { throw JourneyRefusal.moneyOff }
        guard !binding.money, binding.json else { throw JourneyRefusal.moneyOff }
        guard AuthRequestBuilder.isValidToken(token) else { throw JourneyRefusal.invalidRequest }
        let path = try resolve(binding, invitationID: invitationID)
        let data = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        let request = try make(method: "POST", path: path, query: [], token: token, body: data, contentType: "application/json")
        return await perform(request, receiptReread: receiptReread)
    }

    private func postJSONObject(_ name: Self.Journey, tokenSegment: String? = nil, body: [String: Any], token: String, receiptReread: Bool) async throws -> JourneyEnvelope {
        let binding = Self.journey(name)
        if productionLease != nil, JourneyProductionLease.refused.contains(name) { throw JourneyRefusal.moneyOff }
        guard !binding.money, binding.json else { throw JourneyRefusal.moneyOff }
        guard AuthRequestBuilder.isValidToken(token) else { throw JourneyRefusal.invalidRequest }
        let path = try resolve(binding, tokenSegment: tokenSegment)
        let data = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        let request = try make(method: "POST", path: path, query: [], token: token, body: data, contentType: "application/json")
        return await perform(request, receiptReread: receiptReread)
    }

    private func postLanding(_ name: Self.Journey, credential: String, sessionToken: String?) async throws -> JourneyEnvelope {
        guard let sessionToken else {
            let binding = Self.journey(name)
            if productionLease != nil, JourneyProductionLease.refused.contains(name) { throw JourneyRefusal.moneyOff }
            guard !binding.money, binding.json else { throw JourneyRefusal.moneyOff }
            let data = try JSONSerialization.data(withJSONObject: ["token": credential], options: [.sortedKeys])
            let request = try make(method: "POST", path: try resolve(binding, invitationID: nil), query: [], token: nil,
                                   body: data, contentType: "application/json")
            return await perform(request, receiptReread: false)
        }
        return try await postJSON(name, body: ["token": credential], token: sessionToken, receiptReread: false)
    }

    private func postForm(_ name: Self.Journey, fields: [String: String], token: String) async throws -> JourneyEnvelope {
        let binding = Self.journey(name)
        if productionLease != nil, JourneyProductionLease.refused.contains(name) { throw JourneyRefusal.moneyOff }
        guard !binding.money, binding.form else { throw JourneyRefusal.invalidRequest }
        guard AuthRequestBuilder.isValidToken(token) else { throw JourneyRefusal.invalidRequest }
        let order = ["owner_type", "owner_id", "rating", "contents", "reply_id", "request_id"]
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

    private func resolve(_ binding: Self.JourneyCase, invitationID: String? = nil, tokenSegment: String? = nil) throws -> String {
        if binding.path.contains("{token}") {
            guard let tokenSegment, Self.acceptableToken(tokenSegment), !tokenSegment.contains("/") else { throw JourneyRefusal.invalidRequest }
            return binding.path.replacingOccurrences(of: "{token}", with: tokenSegment)
        }
        guard binding.path.contains("{invitationId}") else { return binding.path }
        guard let invitationID, Self.isID(invitationID), !invitationID.contains("/") else { throw JourneyRefusal.invalidRequest }
        return binding.path.replacingOccurrences(of: "{invitationId}", with: invitationID)
    }

    private func make(method: String, path: String, query: [URLQueryItem], token: String?, body: Data?, contentType: String?) throws -> URLRequest {
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
        if let token { request.setValue(token, forHTTPHeaderField: "Authorization") }
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
                                   message: failure.message, dataJSON: nil, receiptReread: receiptReread,
                                   reasonCode: failure.reasonCode)
        }
    }

    static func envelope(data: Data, status: Int, receiptReread: Bool) -> JourneyEnvelope {
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let code = object.flatMap { Self.codeString($0["code"]) } ?? (object == nil ? String(status) : nil)
        let resolved = code ?? String(status)
        let message = object?["msg"] as? String
        let reason = (object?["reasonCode"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return JourneyEnvelope(httpStatus: status, code: resolved, netFail: false, message: message,
                               dataJSON: Self.jsonData(object?["data"] as Any?), receiptReread: receiptReread,
                               reasonCode: reason?.isEmpty == false ? reason : nil)
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
        case seatTransferPhone
        case seatClaimPhone
        case seatMine
        case giftClaim
        /// Not a `journey-api.js` export: U08-02 problem feedback, backend `ApiPlayFeedbackController`.
        case runFeedback
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
        JourneyCase(name: .seatTransferPhone, method: "POST", path: "/api/play/seat-invitations/transfer-phone", json: true, form: false, money: false),
        JourneyCase(name: .seatClaimPhone, method: "POST", path: "/api/play/seat-invitations/claim-phone/{token}", json: true, form: false, money: false),
        JourneyCase(name: .seatMine, method: "GET", path: "/api/play/seat-invitations/mine", json: false, form: false, money: false),
        JourneyCase(name: .giftClaim, method: "POST", path: "/api/marketing/product/gifts/claim", json: true, form: false, money: true),
        JourneyCase(name: .runFeedback, method: "POST", path: "/api/play/feedback/submit", json: true, form: false, money: false)
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

/// Report and settle load decisions from `subpackageJourney/pages/report/index.js` `_fail`
/// and `pages/settle/index.js` `reload`. A non-OK body is `failed` (暂未加载 + 重新加载),
/// not the missing-link state. `RUN_NOT_FOUND` / `RUN_SCOPE_MISMATCH` are the gone cases.
public enum JourneyReportRead {
    public enum Surface: Equatable, Sendable { case report, settle }
    public enum Disposition: Equatable, Sendable {
        case auth
        case gone
        case denied(String?)
        case failed
    }

    /// Nil means `code` is 200 and `data` is present: the caller decodes `reportView`.
    /// 401 wins over a reason code, matching both pages.
    public static func reject(_ envelope: JourneyEnvelope, surface: Surface) -> Disposition? {
        if envelope.httpStatus == 401 || envelope.code == "401" { return .auth }
        if envelope.ok && envelope.dataJSON != nil { return nil }
        switch surface {
        case .report:
            if envelope.reasonCode == "RUN_NOT_FOUND" || envelope.reasonCode == "RUN_SCOPE_MISMATCH" { return .gone }
            if envelope.code == "403" || envelope.httpStatus == 403 { return .denied(envelope.message) }
            return .failed
        case .settle:
            if envelope.reasonCode == "RUN_NOT_FOUND" { return .gone }
            return .failed
        }
    }

    /// An explicit run id that comes back as a different run is not this run (`report.runId !== query.runId`).
    /// A missing answered id does not count: the page only compares when both sides are present.
    public static func runDisagrees(asked: String?, answered: String?) -> Bool {
        guard let asked, !asked.isEmpty, let answered, !answered.isEmpty else { return false }
        return asked != answered
    }
}

/// Seats page: no session is the login state. 403 stays denied. Every other non-OK read is a reload failure.
public enum JourneySeatsSessionGate {
    public enum Phase: Equatable, Sendable { case auth, denied, failed, ready }

    public static func phase(hasValidSession: Bool, envelope: JourneyEnvelope?) -> Phase {
        guard hasValidSession else { return .auth }
        guard let envelope, envelope.ok, envelope.dataJSON != nil else {
            if envelope?.code == "403" || envelope?.httpStatus == 403 { return .denied }
            return .failed
        }
        return .ready
    }
}

/// L09-058: the invite answer's `invitationId` + `token` is shared only while that seat is still `INVITED`.
public struct JourneyHeldSeatInvite: Equatable, Sendable {
    public let invitationID: String
    public let token: String
    public init(invitationID: String, token: String) {
        self.invitationID = invitationID
        self.token = token
    }
}

public enum JourneyHeldSeatInviteRule {
    public struct Seat: Equatable, Sendable {
        public let invitationID: String
        public let state: String
        public init(invitationID: String, state: String) {
            self.invitationID = invitationID
            self.state = state
        }
    }

    /// The invite write keeps a hold only when the answer has both an id and a token.
    public static func hold(invitationID: String?, token: String?) -> JourneyHeldSeatInvite? {
        guard let invitationID, JourneyLoopSource.isID(invitationID),
              let token, JourneyLoopSource.acceptableToken(token) else { return nil }
        return JourneyHeldSeatInvite(invitationID: invitationID, token: token)
    }

    /// After each seats read, drop the hold when that seat is gone or no longer `INVITED`.
    public static func afterRead(hold: JourneyHeldSeatInvite?, seats: [Seat]) -> JourneyHeldSeatInvite? {
        guard let hold else { return nil }
        let match = seats.first { $0.invitationID == hold.invitationID }
        guard let match, match.state == "INVITED" else { return nil }
        return hold
    }
}

/// DEC-F12 B phone transfer. Validation matches `journey-view.js` `transferErrors` / `normalizePhone`.
/// The write itself is `JourneyLoopSource.seatTransferPhone`. This does not send.
public enum JourneySeatPhoneTransfer {
    public static func nameError(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "请填写称呼" }
        if trimmed.unicodeScalars.count > 20 { return "最多 20 个字" }
        return nil
    }

    public static func phoneError(_ phone: String) -> String? {
        JourneyLoopSource.normalizeMobile(phone) == nil ? "手机号格式不对" : nil
    }

    /// `seatsView` `who`: PHONE channel and INVITED or CLAIMED, name then masked phone.
    public static func who(channel: String?, state: String?, name: String?, maskedPhone: String?) -> String {
        guard channel == "PHONE", state == "INVITED" || state == "CLAIMED" else { return "" }
        let parts = [name, maskedPhone].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return parts.joined(separator: " ")
    }

    /// Empty seat above seat 1, and the server said phone transfer is supported, and the buyer is the caller, and the page is not read-only.
    public static func canTransfer(state: String, seatNo: Int, phoneTransferSupported: Bool, buyerIsCaller: Bool, readOnly: Bool) -> Bool {
        state == "AVAILABLE" && seatNo > 1 && phoneTransferSupported && buyerIsCaller && !readOnly
    }
}

/// Landing claim branches (`landing/index.js` `_claimGift` / `_claimSeat`).
/// The HTTP write stays money-off (`JourneyLoopSource.giftClaim` throws). This only classifies an envelope.
public enum JourneyGiftClaimBody {
    /// `POST /api/marketing/product/gifts/claim` JSON `{ token, requestId }`. Not sent while money is off.
    public static func fields(token: String, requestID: String) -> [String: String]? {
        guard JourneyLoopSource.acceptableToken(token), JourneyLoopSource.isRequestID(requestID) else { return nil }
        return ["requestId": requestID, "token": token]
    }
}

public enum JourneyLandingClaim {
    public enum FollowUp: Equatable, Sendable {
        /// Network, `fail`, or a 5xx. Keep the saved request id. The button becomes 查询领取结果.
        case unconfirmed
        /// A finished refusal. Drop the request id. Seat claim may offer 自己购买.
        case refused(message: String?, buyOwn: Bool)
        case giftClaimed(canView: Bool)
        case seatClaimed(seatNo: String?)
    }

    public static func gift(_ envelope: JourneyEnvelope, targetID: String?) -> FollowUp {
        if envelope.unconfirmed { return .unconfirmed }
        guard envelope.ok else { return .refused(message: envelope.message, buyOwn: false) }
        return .giftClaimed(canView: targetID.map(JourneyLoopSource.isID) ?? false)
    }

    public static func seat(_ envelope: JourneyEnvelope, canBuyOwn: Bool) -> FollowUp {
        if envelope.unconfirmed { return .unconfirmed }
        guard envelope.ok, envelope.dataJSON != nil else { return .refused(message: envelope.message, buyOwn: canBuyOwn) }
        return .seatClaimed(seatNo: seatNo(envelope.dataJSON))
    }

    private static func seatNo(_ data: Data?) -> String? {
        guard let object = PostGameJSON.object(data) else { return nil }
        if let number = PostGameJSON.int(object["seatNo"]) { return String(number) }
        return PostGameJSON.string(object["seatNo"])
    }
}

/// `journey-view.js` `rankScopes` plus the report page's 更多 split.
/// Wire query is `GET /api/rank/list` with `scope`, `scopeId`, `period` (`journey-api.js` `rank` + `idQuery`).
public enum JourneyRankBoardContract {
    public struct Tab: Equatable, Sendable {
        public enum Kind: String, Equatable, Sendable {
            case quest, city, country, world, club, team
        }
        public let kind: Kind
        public let scopeID: String
        public init(kind: Kind, scopeID: String) {
            self.kind = kind
            self.scopeID = scopeID
        }
    }

    public struct Menu: Equatable, Sendable {
        /// 本关 and 队内. Empty when the run has neither a topic id nor a team id.
        public let tabs: [Tab]
        /// 更多: city, country, world, club. World is always present.
        public let more: [Tab]
    }

    /// Report `onLoad`: `cityCode` and `countryCode` are kept raw; `clubId` only when it is an id.
    public struct LinkCodes: Equatable, Sendable {
        public let cityCode: String
        public let countryCode: String
        public let clubID: String
        public init(cityCode: String, countryCode: String, clubID: String) {
            self.cityCode = cityCode
            self.countryCode = countryCode
            self.clubID = clubID
        }

        public static func parse(_ query: [String: String]) -> LinkCodes {
            let club = query["clubId"].flatMap { JourneyLoopSource.isID($0) ? $0 : nil } ?? ""
            return LinkCodes(cityCode: query["cityCode"] ?? "", countryCode: query["countryCode"] ?? "", clubID: club)
        }
    }

    public static func menu(topicID: String?, cityCode: String?, countryCode: String?, clubID: String?, teamID: String?) -> Menu {
        var tabs: [Tab] = []
        if let topicID, JourneyLoopSource.isID(topicID) { tabs.append(Tab(kind: .quest, scopeID: topicID)) }
        if let teamID, JourneyLoopSource.isID(teamID) { tabs.append(Tab(kind: .team, scopeID: teamID)) }
        var more: [Tab] = []
        if let city = acceptedCity(cityCode) { more.append(Tab(kind: .city, scopeID: city)) }
        if let country = acceptedCountry(countryCode) { more.append(Tab(kind: .country, scopeID: country)) }
        more.append(Tab(kind: .world, scopeID: ""))
        if let clubID, JourneyLoopSource.isID(clubID) { more.append(Tab(kind: .club, scopeID: clubID)) }
        return Menu(tabs: tabs, more: more)
    }

    /// First `choices[].teamCapacity.teamId` that `choicesView` would keep.
    public static func teamID(choicesJSON: Data?) -> String? {
        guard let object = PostGameJSON.object(choicesJSON) else { return nil }
        let choices = object["choices"] as? [Any] ?? []
        for choice in choices {
            guard let row = choice as? [String: Any], let cap = row["teamCapacity"] as? [String: Any] else { continue }
            if let id = PostGameJSON.id(cap["teamId"]) { return id }
        }
        return nil
    }

    /// Drops empty `scopeId` (world) and empty / `"0"` period, the same as `idQuery`.
    public static func query(scope: String, scopeID: String, period: String?) -> [URLQueryItem] {
        JourneyLoopSource.idQuery([("scope", scope), ("scopeId", scopeID.isEmpty ? nil : scopeID), ("period", period)])
    }

    private static func acceptedCity(_ raw: String?) -> String? {
        guard let raw, (2...32).contains(raw.utf8.count) else { return nil }
        let ok = raw.unicodeScalars.allSatisfy { scalar in
            let value = scalar.value
            return (48...57).contains(value) || (65...90).contains(value) || (97...122).contains(value) || value == 45 || value == 95
        }
        return ok ? raw : nil
    }

    private static func acceptedCountry(_ raw: String?) -> String? {
        guard let raw, raw.utf8.count == 2 else { return nil }
        let letters = raw.unicodeScalars.allSatisfy { ("A"..."Z").contains($0) || ("a"..."z").contains($0) }
        return letters ? raw.uppercased() : nil
    }
}
