import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Network service for `member` MP gaps (`MKT-7-1`, `MKT-10-1`, `PLY-25-3/4`, `PLY-29-4`, `FIN-17-3`).
@MainActor
public final class MemberGapService {
    public static let paths: Set<String> = [
        "api/free-explore/bundle/order/receipt",
        "api/free-explore/bundle/catalog",
        "api/merchant/coupon-summary",
        "api/community-trust/reports/appeal",
        "api/orient/scoring/appeal",
        "api/invoice/orders/eligible"
    ]

    public let baseURL: URL
    private let token: () -> String?
    private let transport: any HTTPTransport

    public init(baseURL: URL, token: @escaping () -> String?, transport: any HTTPTransport) {
        self.baseURL = baseURL
        self.token = token
        self.transport = transport
    }

    func makeRequest(
        _ path: String,
        method: String,
        query: [String: String] = [:],
        json: [String: PlayWireValue]? = nil,
        form: [String: String]? = nil,
        requireAuth: Bool = true
    ) throws -> URLRequest {
        var url = baseURL.appendingPathComponent(path)
        if !query.isEmpty {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw APIError.invalidRequest
            }
            components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
            guard let built = components.url else { throw APIError.invalidRequest }
            url = built
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if requireAuth {
            guard let token = token(), AuthRequestBuilder.isValidToken(token) else {
                throw APIError.invalidRequest
            }
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            request.httpBody = try encoder.encode(json)
        } else if let form {
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            var components = URLComponents()
            components.queryItems = form.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
            let encoded = (components.percentEncodedQuery ?? "").replacingOccurrences(of: "+", with: "%2B")
            request.httpBody = Data(encoded.utf8)
        }
        return request
    }

    private func send(_ request: URLRequest) async -> PlayerGapReply {
        do {
            let (data, status) = try await transport.send(request)
            return PlayerGapReply.classify(data: data, status: status)
        } catch {
            return .unknown
        }
    }

    /// `MKT-7-1`: `GET /api/free-explore/bundle/order/receipt?requestId=`
    public func fetchFreeExploreReceipt(requestID: String) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/free-explore/bundle/order/receipt",
            method: "GET",
            query: ["requestId": requestID]
        ) else { return .unauthorized }
        return await send(req)
    }

    /// `MKT-7-1`: `GET /api/free-explore/bundle/catalog?topicId=`
    public func fetchFreeExploreCatalog(topicID: Int) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/free-explore/bundle/catalog",
            method: "GET",
            query: ["topicId": String(topicID)],
            requireAuth: false
        ) else { return .unknown }
        return await send(req)
    }

    /// `MKT-10-1`: `POST /api/merchant/coupon-summary`
    public func fetchMerchantCouponSummary() async -> PlayerGapReply {
        guard let req = try? makeRequest("api/merchant/coupon-summary", method: "POST", form: [:]) else {
            return .unauthorized
        }
        return await send(req)
    }

    /// `PLY-29-4`: `POST /api/community-trust/reports/appeal {reportId, reason, requestId}`
    public func submitReportAppeal(reportID: Int, reason: String, requestID: String) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/community-trust/reports/appeal",
            method: "POST",
            json: [
                "reportId": .integer(Int64(reportID)),
                "reason": .string(reason),
                "requestId": .string(requestID)
            ]
        ) else { return .unauthorized }
        return await send(req)
    }

    /// `PLY-25-4`: `POST /api/orient/scoring/appeal {sessionId, nodeId?, entryId?, reason}`
    public func submitOrientAppeal(
        sessionID: Int,
        nodeID: Int?,
        entryID: String?,
        reason: String
    ) async -> PlayerGapReply {
        var payload: [String: PlayWireValue] = [
            "sessionId": .integer(Int64(sessionID)),
            "reason": .string(reason)
        ]
        if let nodeID { payload["nodeId"] = .integer(Int64(nodeID)) }
        if let entryID { payload["entryId"] = .string(entryID) }
        guard let req = try? makeRequest("api/orient/scoring/appeal", method: "POST", json: payload) else {
            return .unauthorized
        }
        return await send(req)
    }

    /// `FIN-17-3`: `POST /api/invoice/orders/eligible {orderId}`
    public func checkInvoiceOrderEligible(orderID: Int) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/invoice/orders/eligible",
            method: "POST",
            json: ["orderId": .integer(Int64(orderID))]
        ) else { return .unauthorized }
        return await send(req)
    }
}
