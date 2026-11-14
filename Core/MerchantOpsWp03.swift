import Foundation
import CoreFoundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct MerchantOpsWp03Call: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case read, money, merchantWrite }
    public let path: String
    public let method: String
    public let kind: Kind
    public let jsonBody: String?
    public let formBody: String?

    public init(path: String, kind: Kind, jsonBody: String? = nil, formBody: String? = nil) {
        self.path = path
        self.method = MerchantOpsWp03Catalog.method(for: path)
        self.kind = kind
        self.jsonBody = jsonBody
        self.formBody = formBody
    }

    public static func claimsStatus() -> MerchantOpsWp03Call {
        MerchantOpsWp03Call(path: MerchantOpsWp03Catalog.claimsStatus, kind: .read)
    }

    public static func claimsSubmit(merchantID: Int, requestID: String, contactName: String, contactPhone: String, statement: String, proofType: String, assetID: String) -> MerchantOpsWp03Call {
        let body: [String: Any] = [
            "merchantId": merchantID, "requestId": requestID, "contactName": contactName,
            "contactPhone": contactPhone, "statement": statement,
            "proofs": [["proofType": proofType, "assetId": assetID]]
        ]
        return MerchantOpsWp03Call(path: MerchantOpsWp03Catalog.claimsSubmit, kind: .merchantWrite, jsonBody: Self.encode(body))
    }

    public static func commerceOrder(bizType: String, requestID: String) -> MerchantOpsWp03Call {
        MerchantOpsWp03Call(path: MerchantOpsWp03Catalog.commerceOrder, kind: .money, jsonBody: Self.encode(["bizType": bizType, "requestId": requestID]))
    }

    public static func commerceOrderStatus(orderSn: String) -> MerchantOpsWp03Call {
        MerchantOpsWp03Call(path: MerchantOpsWp03Catalog.commerceOrderStatus, kind: .money, jsonBody: Self.encode(["orderSn": orderSn]))
    }

    public static func couponSummary() -> MerchantOpsWp03Call {
        MerchantOpsWp03Call(path: MerchantOpsWp03Catalog.couponSummary, kind: .read, jsonBody: "{}")
    }

    public static func npcReview() -> MerchantOpsWp03Call {
        MerchantOpsWp03Call(path: MerchantOpsWp03Catalog.npcReview, kind: .read)
    }

    public static func invitePreview(token: String) -> MerchantOpsWp03Call {
        MerchantOpsWp03Call(path: MerchantOpsWp03Catalog.invitePreview, kind: .read, jsonBody: Self.encode(["token": token]))
    }

    public static func shareCode(memberID: Int) -> MerchantOpsWp03Call {
        MerchantOpsWp03Call(path: MerchantOpsWp03Catalog.shareCode, kind: .merchantWrite, formBody: "memberId=\(memberID)")
    }

    public static func inviteRevoke(applicationID: Int) -> MerchantOpsWp03Call {
        MerchantOpsWp03Call(path: MerchantOpsWp03Catalog.inviteRevoke, kind: .merchantWrite, jsonBody: Self.encode(["applicationId": applicationID]))
    }

    private static func encode(_ object: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object),
              let text = String(data: data, encoding: .utf8) else { return nil }
        return text
    }
}

public struct MerchantOpsWp03Reply: Equatable, Sendable {
    public let sent: Bool
    public let succeeded: Bool
    public let httpStatus: Int?
    public let message: String
    public let detail: String
    public let isEmpty: Bool

    public static let unknown = "\u{2014}"
    public static let withheld = MerchantOpsWp03Reply(sent: false, succeeded: false, httpStatus: nil, message: unknown, detail: unknown, isEmpty: false)
}

public struct MerchantOpsWp03Client {
    public let baseURL: URL
    private let transport: any HTTPTransport

    public init(baseURL: URL, transport: any HTTPTransport) {
        self.baseURL = baseURL
        self.transport = transport
    }

    public func perform(_ call: MerchantOpsWp03Call, token: String?, allowsMoney: Bool, allowsMerchantWrite: Bool) async -> MerchantOpsWp03Reply {
        if call.kind == .money, !allowsMoney { return .withheld }
        if call.kind == .merchantWrite, !allowsMerchantWrite { return .withheld }
        guard let token, AuthRequestBuilder.isValidToken(token) else { return .withheld }
        let request: URLRequest
        do { request = try Self.request(baseURL: baseURL, call: call, token: token) }
        catch { return .withheld }
        do {
            let (data, status) = try await transport.send(request)
            return Self.reply(data: data, status: status)
        } catch {
            return MerchantOpsWp03Reply(sent: true, succeeded: false, httpStatus: nil, message: MerchantOpsWp03Reply.unknown, detail: MerchantOpsWp03Reply.unknown, isEmpty: false)
        }
    }

    static func request(baseURL: URL, call: MerchantOpsWp03Call, token: String) throws -> URLRequest {
        guard MerchantOpsWp03Catalog.paths.contains(call.path), call.method == MerchantOpsWp03Catalog.method(for: call.path),
              !call.path.contains(".."), AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        var root = baseURL.absoluteString
        if !root.hasSuffix("/") { root += "/" }
        guard let url = URL(string: root + call.path), url.query == nil else { throw APIError.invalidRequest }
        var request = URLRequest(url: url)
        request.httpMethod = call.method
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        if call.method == "GET" { return request }
        if let form = call.formBody {
            guard form.hasPrefix("memberId="), Int(form.dropFirst("memberId=".count)) != nil else { throw APIError.invalidRequest }
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data(form.utf8)
            return request
        }
        guard let json = call.jsonBody, let body = json.data(using: .utf8), !body.isEmpty else { throw APIError.invalidRequest }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return request
    }

    static func reply(data: Data, status: Int) -> MerchantOpsWp03Reply {
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let code = integer(object?["code"])
        let message = text(object?["msg"]) ?? MerchantOpsWp03Reply.unknown
        let payload = object?["data"]
        let empty = isEmpty(payload)
        let detail = fact(payload) ?? MerchantOpsWp03Reply.unknown
        let httpOK = (200..<300).contains(status)
        return MerchantOpsWp03Reply(sent: true, succeeded: httpOK && code == 200, httpStatus: status, message: message, detail: detail, isEmpty: empty)
    }

    private static func isEmpty(_ payload: Any?) -> Bool {
        if payload is NSNull || payload == nil { return true }
        if let rows = payload as? [Any] { return rows.isEmpty }
        guard let object = payload as? [String: Any] else { return false }
        if object.isEmpty { return true }
        if let total = integer(object["couponTotal"]), let live = integer(object["couponCount"]) {
            return total == 0 && live == 0
        }
        return false
    }

    private static func fact(_ payload: Any?) -> String? {
        if let rows = payload as? [Any] { return rows.isEmpty ? nil : String(rows.count) }
        guard let object = payload as? [String: Any] else { return nil }
        if let name = text(object["merchantName"]) { return name }
        if let url = text(object["qrcodeUrl"]) { return url }
        if let order = text(object["orderSn"]) { return order }
        if let total = integer(object["couponTotal"]), let received = integer(object["received"]), let verified = integer(object["verified"]) {
            return "\(total) \(received) \(verified)"
        }
        if let status = text(object["status"]) { return status }
        return nil
    }

    private static func text(_ value: Any?) -> String? {
        guard let text = value as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func integer(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber else { return nil }
        if CFGetTypeID(number) == CFBooleanGetTypeID() { return nil }
        let int = number.intValue
        guard number.doubleValue == Double(int) else { return nil }
        return int
    }
}
