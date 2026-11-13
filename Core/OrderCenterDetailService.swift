import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// G2 order center deep link (`subpackageMember/components/cy/order-center-entry`).
/// POST form {outTradeNo}. A REGISTRATION order hands its id to the existing registration
/// order detail; any other kind shows the server's summary. The status is the server's
/// own `statusText`: this type never decides that an order is paid.
public struct OrderCenterSummary: Equatable {
    public enum Kind: String, CaseIterable { case registration = "REGISTRATION", clm = "CLM", commerce = "COMMERCE", dep = "DEP" }
    public let kind: Kind
    public let id: String
    public let orderNo: String
    public let title: String
    public let statusText: String
    public let amountText: String
    public let createdAtText: String?
}

public enum OrderCenterIssue: Error, Equatable {
    case invalidLink, signInRequired, forbidden, notFound, unavailable, malformed, disabled
}

@MainActor public final class OrderCenterDetailService {
    public static let path = "api/order-center/detail"
    private let baseURL: URL
    private let transport: any HTTPTransport
    private let token: () -> String?
    private let enabled: () -> Bool
    private let unauthorized: () -> Void

    public init(baseURL: URL, transport: any HTTPTransport, token: @escaping () -> String?,
                enabled: @escaping () -> Bool, unauthorized: @escaping () -> Void = {}) {
        self.baseURL = baseURL; self.transport = transport; self.token = token
        self.enabled = enabled; self.unauthorized = unauthorized
    }

    /// `reloadEntry`: the same link check, then the same status mapping as `failed`.
    public static func validOutTradeNo(_ value: String) -> Bool {
        value.range(of: "^[0-9A-Za-z_|*\\-]{6,32}$", options: .regularExpression) != nil
    }

    public func detail(outTradeNo: String) async throws -> OrderCenterSummary {
        guard Self.validOutTradeNo(outTradeNo) else { throw OrderCenterIssue.invalidLink }
        guard enabled() else { throw OrderCenterIssue.disabled }
        guard let token = token(), AuthRequestBuilder.isValidToken(token) else { throw OrderCenterIssue.signInRequired }
        var request = URLRequest(url: baseURL.appendingPathComponent(Self.path))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpBody = Data(TopicCreatorEditorService.formEncoded(["outTradeNo": outTradeNo]).utf8)
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        let data: Data, status: Int
        do { (data, status) = try await transport.send(request) } catch { throw OrderCenterIssue.unavailable }
        guard enabled() else { throw OrderCenterIssue.disabled }
        let envelope = data.count <= 262_144 ? try? JSONDecoder().decode(PlayWireValue.self, from: data) : nil
        let code = envelope?["code"].tolerantInteger
        switch status == 200 ? (code ?? -1) : status {
        case 200: break
        case 401, 2: unauthorized(); throw OrderCenterIssue.signInRequired
        case 403: throw OrderCenterIssue.forbidden
        case 404: throw OrderCenterIssue.notFound
        case 400: throw OrderCenterIssue.invalidLink
        default: throw OrderCenterIssue.unavailable
        }
        guard let summary = envelope.flatMap({ Self.summary($0["data"]) }) else { throw OrderCenterIssue.malformed }
        return summary
    }

    /// `summaryOf`: every display field is a non-empty string of at most 256, the amount is a decimal string.
    static func summary(_ value: PlayWireValue) -> OrderCenterSummary? {
        guard let kind = value["kind"].text.flatMap(OrderCenterSummary.Kind.init(rawValue:)),
              let id = value["id"].text, TopicCreatorEditorService.decimalID(id) else { return nil }
        var fields: [String: String] = [:]
        for key in ["orderNo", "title", "statusText"] {
            guard let text = value[key].text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  text.count <= 256 else { return nil }
            fields[key] = text
        }
        guard let amount = value["amountText"].text,
              amount.range(of: "^\\d{1,16}(\\.\\d{1,2})?$", options: .regularExpression) != nil else { return nil }
        let created = value["createdAtText"].text.flatMap { $0.count <= 64 ? $0 : nil }
        return OrderCenterSummary(kind: kind, id: id, orderNo: fields["orderNo"] ?? "", title: fields["title"] ?? "",
            statusText: fields["statusText"] ?? "", amountText: amount, createdAtText: created)
    }
}
