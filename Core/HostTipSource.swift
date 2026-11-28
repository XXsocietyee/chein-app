import Foundation
import CoreFoundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum HostTipRefusal: Error, Equatable, Sendable {
    case invalidRequest
    case notAdmitted
}

/// Host-tip call. HTTP 501 with `CHANNEL_NOT_ENABLED` is a confirmed unavailable intent, not a payment.
public struct HostTipEnvelope: Equatable, Sendable {
    public let httpStatus: Int?
    public let code: String?
    public let reasonCode: String?
    public let message: String?
    public let dataJSON: Data?
    public let netFail: Bool

    public var ok: Bool {
        guard let httpStatus, (200...299).contains(httpStatus), code == "200" else { return false }
        return true
    }

    /// 2xx, 4xx, and the channel-off 501 are answers. Other 5xx stay unconfirmed.
    public var confirmed: Bool {
        guard let httpStatus, !netFail else { return false }
        if httpStatus == 501, reasonCode == "CHANNEL_NOT_ENABLED" { return true }
        return (200...299).contains(httpStatus) || (400...499).contains(httpStatus)
    }

    public static let networkFailure = HostTipEnvelope(
        httpStatus: nil, code: "fail", reasonCode: nil, message: nil, dataJSON: nil, netFail: true)
}

public struct HostTipConfigFact: Equatable, Sendable {
    public let clubID: String
    public let enabled: Bool
    public let minAmountText: String
    public let currency: String
    /// 0 host, 1 platform. Nil is an em dash.
    public let channelFeeBearer: Int?
    public let channelClosed: Bool
}

/// Prepare never reports a payment success. `paymentSucceeded` stays false.
public struct HostTipPrepareFact: Equatable, Sendable {
    public let unavailable: Bool
    public let payable: Bool
    public let paymentSucceeded: Bool
    public let intentID: String?
    public let status: String
    public let amountText: String
    public let reasonCode: String?

    public static let unknownMark = "—"
}

/// What the player is told after `POST /api/host-tip/prepare`. Prepare never takes money
/// (there is no host-tip pay step), so a payable intent is not a successful payment.
public enum HostTipPrepareBanner: Equatable, Sendable {
    /// Channel off or the prepare is not payable.
    case unavailable
    /// The payment switch is off. Copy says the payment did not succeed.
    case paymentClosed
    /// The switch is on and the prepare is payable. The intent list carries the status.
    /// This is not "payment closed" and it is not "paid".
    case pending
}

public enum HostTipPreparePresentation {
    /// P2-1: both branches used to say payment closed. A payable prepare says that only
    /// while the payment switch is off. While the switch is on, the result stays pending.
    public static func banner(fact: HostTipPrepareFact, paymentsOpen: Bool) -> HostTipPrepareBanner {
        if fact.paymentSucceeded { return .paymentClosed }
        if fact.unavailable { return .unavailable }
        if fact.payable { return paymentsOpen ? .pending : .paymentClosed }
        return .unavailable
    }
}

public struct HostTipIntentFact: Equatable, Sendable {
    public let id: String
    public let status: String
    public let amountText: String
    public let canCancel: Bool
}

/// `POST /api/host-tip/config`, `GET /api/host-tip/config/mine`, `POST /api/host-tip/prepare`,
/// `GET /api/host-tip/intent/mine`, `POST /api/host-tip/intent/{id}/cancel`.
/// The body never sends `hostSharePercent`, a pay channel, or a payout.
public struct HostTipSource {
    public static let paths: [String] = [
        "/api/host-tip/config",
        "/api/host-tip/config/mine",
        "/api/host-tip/prepare",
        "/api/host-tip/intent/mine",
        "/api/host-tip/intent/{}/cancel"
    ]

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

    public func configs(token: String) async throws -> HostTipEnvelope {
        try await send(method: "GET", path: "/api/host-tip/config/mine", body: nil, token: token)
    }

    public func saveConfig(clubID: String, enabled: Bool, minAmount: String, currency: String,
                           channelFeeBearer: Int, token: String) async throws -> HostTipEnvelope {
        let fields = try Self.configFields(clubID: clubID, enabled: enabled, minAmount: minAmount,
                                           currency: currency, channelFeeBearer: channelFeeBearer)
        return try await send(method: "POST", path: "/api/host-tip/config", body: Self.json(fields), token: token)
    }

    public func prepare(hostMemberID: String, clubID: String, amount: String, note: String, token: String) async throws -> HostTipEnvelope {
        let key = "host-tip-prepare:" + hostMemberID
        if let saved = store.read(key), let text = store.read(key + ":body") {
            return try await send(method: "POST", path: "/api/host-tip/prepare", body: Data(text.utf8), token: token, savedKey: key)
        }
        let fields = try Self.prepareFields(hostMemberID: hostMemberID, clubID: clubID, amount: amount, note: note,
                                            nowMillis: nowMillis(), entropy: entropy())
        let data = try Self.json(fields)
        store.write(key, fields["requestId"] as? String ?? "")
        store.write(key + ":body", String(decoding: data, as: UTF8.self))
        return try await send(method: "POST", path: "/api/host-tip/prepare", body: data, token: token, savedKey: key)
    }

    public func intents(token: String) async throws -> HostTipEnvelope {
        try await send(method: "GET", path: "/api/host-tip/intent/mine", body: nil, token: token)
    }

    public func cancel(intentID: String, token: String) async throws -> HostTipEnvelope {
        guard ContentLandingSource.isID(intentID) else { throw HostTipRefusal.invalidRequest }
        return try await send(method: "POST", path: "/api/host-tip/intent/" + intentID + "/cancel", body: nil, token: token)
    }

    public static func configs(in envelope: HostTipEnvelope) -> [HostTipConfigFact]? {
        guard envelope.ok, let rows = array(envelope.dataJSON) else { return nil }
        return rows.compactMap(config)
    }

    public static func intents(in envelope: HostTipEnvelope) -> [HostTipIntentFact]? {
        guard envelope.ok, let rows = array(envelope.dataJSON) else { return nil }
        return rows.compactMap(intent)
    }

    public static func prepareFact(_ envelope: HostTipEnvelope) -> HostTipPrepareFact? {
        guard envelope.confirmed || envelope.ok else { return nil }
        let object = object(envelope.dataJSON) ?? [:]
        let reason = envelope.reasonCode ?? (object["reasonCode"] as? String)
        let payable = bool(object["payable"]) ?? false
        let unavailable = envelope.httpStatus == 501 || reason == "CHANNEL_NOT_ENABLED" || payable == false
        let status = nonEmpty(object["status"] as? String) ?? (unavailable ? "CHANNEL_UNSUPPORTED" : HostTipPrepareFact.unknownMark)
        return HostTipPrepareFact(
            unavailable: unavailable, payable: payable && !unavailable, paymentSucceeded: false,
            intentID: identifier(object["id"]), status: status,
            amountText: amountText(object["amount"], currency: object["currency"]), reasonCode: reason)
    }

    public static func configFields(clubID: String, enabled: Bool, minAmount: String, currency: String,
                                    channelFeeBearer: Int) throws -> [String: Any] {
        guard let club = wholeID(clubID, allowZero: true), channelFeeBearer == 0 || channelFeeBearer == 1,
              let amount = decimal(minAmount), amount >= 0,
              currency.count == 3, currency.unicodeScalars.allSatisfy({ (65...90).contains($0.value) }) else {
            throw HostTipRefusal.invalidRequest
        }
        return [
            "clubId": NSNumber(value: club),
            "enabled": enabled,
            "minAmount": NSDecimalNumber(decimal: amount),
            "currency": currency,
            "channelFeeBearer": NSNumber(value: channelFeeBearer)
        ]
    }

    public static func prepareFields(hostMemberID: String, clubID: String, amount: String, note: String,
                                     nowMillis: Int64, entropy: String) throws -> [String: Any] {
        guard let host = wholeID(hostMemberID, allowZero: false), let value = decimal(amount), value > 0,
              let requestID = JourneyLoopSource.makeRequestID(prefix: "htip", nowMillis: nowMillis, entropy: entropy) else {
            throw HostTipRefusal.invalidRequest
        }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.utf16.count <= 200 else { throw HostTipRefusal.invalidRequest }
        var fields: [String: Any] = [
            "hostMemberId": NSNumber(value: host),
            "amount": NSDecimalNumber(decimal: value),
            "requestId": requestID
        ]
        if let club = wholeID(clubID, allowZero: true), club > 0 { fields["clubId"] = NSNumber(value: club) }
        if !trimmed.isEmpty { fields["note"] = trimmed }
        return fields
    }

    private func send(method: String, path: String, body: Data?, token: String, savedKey: String? = nil) async throws -> HostTipEnvelope {
        guard AuthRequestBuilder.isValidToken(token) else { throw HostTipRefusal.invalidRequest }
        let request = try make(method: method, path: path, token: token, body: body)
        do { try admit(request) } catch {
            if let savedKey {
                store.remove(savedKey)
                store.remove(savedKey + ":body")
            }
            throw error
        }
        let result = await perform(request)
        if let savedKey, result.confirmed {
            store.remove(savedKey)
            store.remove(savedKey + ":body")
        }
        return result
    }

    private func admit(_ request: URLRequest) throws {
        guard let url = request.url else { throw HostTipRefusal.notAdmitted }
        let relative = "/" + url.path.split(separator: "/").drop(while: { $0 == "prod-api" }).map(String.init).joined(separator: "/")
        let key = ChinaReviewedRouteCapability.normalized(relative)
        guard Self.paths.contains(key), ChinaReviewedRouteCapability.hostTipSurfaceGrant.contains(key) else {
            throw HostTipRefusal.notAdmitted
        }
        if let body = request.httpBody, let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] {
            let refused = ["hostSharePercent", "payChannel", "payAmount", "price", "payableAmount"]
            if object.keys.contains(where: { refused.contains($0) }) { throw HostTipRefusal.notAdmitted }
        }
        do { try ChinaReviewedRouteCapability.refuseUnwiredChinaProduction(request) }
        catch { throw HostTipRefusal.notAdmitted }
    }

    private func make(method: String, path: String, token: String, body: Data?) throws -> URLRequest {
        let url = path.split(separator: "/").reduce(configuration.baseURL) { partial, part in
            partial.appendingPathComponent(String(part))
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

    private func perform(_ request: URLRequest) async -> HostTipEnvelope {
        do {
            let (data, status) = try await transport.send(request)
            return Self.envelope(data: data, status: status)
        } catch {
            return .networkFailure
        }
    }

    static func envelope(data: Data, status: Int) -> HostTipEnvelope {
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let code = object.flatMap { codeString($0["code"]) } ?? (object == nil ? String(status) : nil)
        return HostTipEnvelope(httpStatus: status, code: code ?? String(status), reasonCode: object?["reasonCode"] as? String,
                               message: object?["msg"] as? String, dataJSON: Self.jsonData(object?["data"] as Any?), netFail: false)
    }

    private static func config(_ row: [String: Any]) -> HostTipConfigFact? {
        let clubText = identifier(row["clubId"]) ?? "0"
        let bearer = whole(row["channelFeeBearer"])
        let knownBearer = (bearer == 0 || bearer == 1) ? bearer : nil
        return HostTipConfigFact(
            clubID: clubText, enabled: bool(row["enabled"]) ?? false,
            minAmountText: amountText(row["minAmount"], currency: nil),
            currency: nonEmpty(row["currency"] as? String) ?? HostTipPrepareFact.unknownMark,
            channelFeeBearer: knownBearer,
            channelClosed: row["reasonCode"] as? String == "CHANNEL_NOT_ENABLED")
    }

    private static func intent(_ row: [String: Any]) -> HostTipIntentFact? {
        guard let id = identifier(row["id"]) else { return nil }
        let status = nonEmpty(row["status"] as? String) ?? "UNKNOWN"
        let cancel = ["CREATED", "AWAITING_PAYMENT", "CHANNEL_UNSUPPORTED"].contains(status)
        return HostTipIntentFact(id: id, status: status, amountText: amountText(row["amount"], currency: row["currency"]), canCancel: cancel)
    }

    static func amountText(_ value: Any?, currency: Any?) -> String {
        guard let decimal = decimal(value), let digits = fixedTwo(decimal) else { return HostTipPrepareFact.unknownMark }
        if let code = nonEmpty(currency as? String), code != "CNY" { return code + " " + digits }
        return "¥" + digits
    }

    private static func json(_ fields: [String: Any]) throws -> Data {
        guard JSONSerialization.isValidJSONObject(fields),
              let data = try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]) else {
            throw HostTipRefusal.invalidRequest
        }
        return data
    }

    private static func array(_ data: Data?) -> [[String: Any]]? {
        guard let data, let value = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return nil }
        return value.compactMap { $0 as? [String: Any] }
    }

    private static func object(_ data: Data?) -> [String: Any]? {
        guard let data else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func wholeID(_ value: String, allowZero: Bool) -> Int64? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let number = Int64(trimmed), String(number) == trimmed else { return nil }
        if number == 0 { return allowZero ? 0 : nil }
        return number > 0 ? number : nil
    }

    private static func identifier(_ value: Any?) -> String? {
        if let text = value as? String, wholeID(text, allowZero: false) != nil { return text }
        guard let number = jsonNumber(value), let whole = whole(number), whole > 0 else { return nil }
        return String(whole)
    }

    private static func bool(_ value: Any?) -> Bool? {
        if let flag = value as? Bool { return flag }
        return nil
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

    private static func jsonNumber(_ value: Any?) -> NSNumber? {
        guard let number = value as? NSNumber else { return nil }
        if CFGetTypeID(number as CFTypeRef) == CFBooleanGetTypeID() { return nil }
        return number
    }

    private static func codeString(_ value: Any?) -> String? {
        if let text = value as? String { return text }
        guard let number = jsonNumber(value), let whole = whole(number) else { return nil }
        return String(whole)
    }

    private static func jsonData(_ value: Any?) -> Data? {
        guard let value, !(value is NSNull), JSONSerialization.isValidJSONObject(value) else { return nil }
        return try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    }
}
