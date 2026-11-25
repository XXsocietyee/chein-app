import Foundation
import CoreFoundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum ChannelRedeemRefusal: Error, Equatable, Sendable {
    case invalidRequest
    case notAdmitted
}

public struct ChannelRedeemEnvelope: Equatable, Sendable {
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

    public var confirmed: Bool {
        guard let httpStatus, !netFail else { return false }
        return (200...299).contains(httpStatus) || (400...499).contains(httpStatus)
    }
}

public struct ChannelRedeemReceipt: Equatable, Sendable {
    public static let unknownMark = "—"
    public let productName: String
    public let seatCount: String
    public let validFrom: String
    public let validTo: String
    public let registrationNo: String
    public let replayed: Bool
}

public enum ChannelRedeemPresentation: Equatable, Sendable {
    case pending
    case unavailable
    case expired
    case revoked
    case usedByOther
    case subjectMismatch
    case invalid
    case productUnsupported
    case currencyUnsupported
    case failed
    case redeemed(ChannelRedeemReceipt)
}

/// `POST /api/channel/redeem`. Provider-off answers stay unavailable. The body has the code and a request id only.
public struct ChannelRedeemSource {
    public static let path = "/api/channel/redeem"
    /// GET `api/channel/redeem/status` (`market/gift` `loadCodeStatus`, `market/passes` `loadRedeem`).
    /// Reads `platformCodeEnabled`. This is not the redeem write.
    public static let statusPath = "api/channel/redeem/status"

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

    public func redeem(code: String, token: String) async throws -> ChannelRedeemEnvelope {
        let key = "channel-redeem"
        if let text = store.read(key + ":body") {
            return try await send(Data(text.utf8), token: token, key: key)
        }
        let fields = try Self.fields(code: code, nowMillis: nowMillis(), entropy: entropy())
        let data = try Self.json(fields)
        store.write(key, fields["requestId"] as? String ?? "")
        store.write(key + ":body", String(decoding: data, as: UTF8.self))
        return try await send(data, token: token, key: key)
    }

    public static func presentation(_ envelope: ChannelRedeemEnvelope) -> ChannelRedeemPresentation {
        guard envelope.confirmed || envelope.ok else { return .pending }
        switch envelope.reasonCode {
        case "PROVIDER_NOT_CONFIGURED", "REFUND_DECISION_POINT_MISSING": return .unavailable
        case "CODE_EXPIRED": return .expired
        case "CODE_REVOKED": return .revoked
        case "ALREADY_REDEEMED_BY_OTHER": return .usedByOther
        case "SUBJECT_MISMATCH": return .subjectMismatch
        case "INVALID_CODE": return .invalid
        case "PRODUCT_VALIDITY_UNSUPPORTED": return .productUnsupported
        case "CURRENCY_UNSUPPORTED": return .currencyUnsupported
        default: break
        }
        guard envelope.ok, let object = object(envelope.dataJSON) else { return .failed }
        return .redeemed(receipt(object))
    }

    public static func fields(code: String, nowMillis: Int64, entropy: String) throws -> [String: Any] {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.utf8.count <= 64,
              trimmed.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value != 127 }),
              let requestID = JourneyLoopSource.makeRequestID(prefix: "cred", nowMillis: nowMillis, entropy: entropy) else {
            throw ChannelRedeemRefusal.invalidRequest
        }
        return ["code": trimmed, "requestId": requestID]
    }

    private func send(_ body: Data, token: String, key: String) async throws -> ChannelRedeemEnvelope {
        guard AuthRequestBuilder.isValidToken(token) else { throw ChannelRedeemRefusal.invalidRequest }
        let url = ["api", "channel", "redeem"].reduce(configuration.baseURL) { $0.appendingPathComponent($1) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.httpShouldHandleCookies = false
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        guard ChinaReviewedRouteCapability.hostTipSurfaceGrant.contains(Self.path) else { throw ChannelRedeemRefusal.notAdmitted }
        if let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any],
           object.keys.contains(where: { ["amount", "price", "payChannel", "payAmount"].contains($0) }) {
            throw ChannelRedeemRefusal.notAdmitted
        }
        do { try ChinaReviewedRouteCapability.refuseUnwiredChinaProduction(request) }
        catch { throw ChannelRedeemRefusal.notAdmitted }
        let envelope: ChannelRedeemEnvelope
        do {
            let (data, status) = try await transport.send(request)
            let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let code = object.flatMap { $0["code"] as? String } ?? (object?["code"] as? NSNumber).map { $0.stringValue }
            envelope = ChannelRedeemEnvelope(httpStatus: status, code: code ?? String(status), reasonCode: object?["reasonCode"] as? String,
                                             message: object?["msg"] as? String, dataJSON: Self.jsonData(object?["data"]), netFail: false)
        } catch {
            return ChannelRedeemEnvelope(httpStatus: nil, code: "fail", reasonCode: nil, message: nil, dataJSON: nil, netFail: true)
        }
        if envelope.confirmed {
            store.remove(key)
            store.remove(key + ":body")
        }
        return envelope
    }

    private static func receipt(_ object: [String: Any]) -> ChannelRedeemReceipt {
        let mark = ChannelRedeemReceipt.unknownMark
        let seats: String
        if let number = object["seatCount"] as? NSNumber, CFGetTypeID(number as CFTypeRef) != CFBooleanGetTypeID() {
            seats = number.stringValue
        } else if let text = object["seatCount"] as? String, !text.isEmpty {
            seats = text
        } else {
            seats = mark
        }
        return ChannelRedeemReceipt(
            productName: text(object["productName"]) ?? mark,
            seatCount: seats,
            validFrom: text(object["validFrom"]) ?? mark,
            validTo: text(object["validTo"]) ?? mark,
            registrationNo: text(object["registrationNo"]) ?? mark,
            replayed: object["replayed"] as? Bool ?? false)
    }

    private static func text(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func object(_ data: Data?) -> [String: Any]? {
        guard let data else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func json(_ fields: [String: Any]) throws -> Data {
        guard JSONSerialization.isValidJSONObject(fields),
              let data = try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]) else {
            throw ChannelRedeemRefusal.invalidRequest
        }
        return data
    }

    private static func jsonData(_ value: Any?) -> Data? {
        guard let value, !(value is NSNull), JSONSerialization.isValidJSONObject(value) else { return nil }
        return try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    }
}
