import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// MKT-7-2. Default off. A later mount passes `enabled: true`.
/// `RetainedPublicMerchantReviewHost` and `BundleCommerceMount` stay on their existing
/// `enabled: false` path; this hook does not replace `UnavailableBundleReviewClient`
/// and does not touch the route table.
public struct MerchantPublicReviewGate: Equatable, Sendable {
    public static let off = MerchantPublicReviewGate(enabled: false)
    public let enabled: Bool
    public init(enabled: Bool = false) { self.enabled = enabled }
}

public enum MerchantPublicReviewHookFailure: Error, Equatable {
    case disabled, invalid, unavailable, malformed
    /// A definite refusal (400, 403, or 409 whose message says 已评价). The pending review can be cleared.
    case rejected(Int, String?)
}

/// `POST /api/merchant/public-home` row. `memberId` is the requested id, and only when the payload echoes it.
public struct MerchantPublicHomeRow: Equatable, Sendable {
    public let merchantRowId: Int
    public let memberId: Int?
    public init(merchantRowId: Int, memberId: Int?) {
        self.merchantRowId = merchantRowId
        self.memberId = memberId
    }
}

/// `POST /api/merchant/reviews/create` body. The bundle flow always sends `imageUrls: []`.
public struct MerchantPublicReviewCreate: Equatable, Sendable {
    public let merchantRowId: Int
    public let registrationId: Int
    public let rating: Int
    public let content: String
    public let requestId: String
    public init(merchantRowId: Int, registrationId: Int, rating: Int, content: String, requestId: String) throws {
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard merchantRowId > 0, registrationId > 0, (1...5).contains(rating),
              (2...1000).contains(text.utf16.count),
              Self.validRequestID(requestId) else { throw MerchantPublicReviewHookFailure.invalid }
        self.merchantRowId = merchantRowId
        self.registrationId = registrationId
        self.rating = rating
        self.content = text
        self.requestId = requestId
    }
    public var fields: [String: Any] {
        ["merchantRowId": merchantRowId, "registrationId": registrationId, "rating": rating,
         "content": content, "imageUrls": [String](), "requestId": requestId]
    }
    static func validRequestID(_ value: String) -> Bool {
        !value.isEmpty && value.utf16.count <= 64 &&
            value.range(of: #"^[A-Za-z0-9._:-]+$"#, options: .regularExpression) != nil
    }
}

/// Core client for the three live merchant routes the bundle page reviews through.
/// There is no `/api/free-explore/bundle/review`. Every call refuses while the gate is off.
@MainActor public struct MerchantPublicReviewClient {
    public let gate: MerchantPublicReviewGate
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    public init(configuration: APIConfiguration, transport: any HTTPTransport, gate: MerchantPublicReviewGate = .off) {
        self.configuration = configuration
        self.transport = transport
        self.gate = gate
    }

    /// `POST /api/merchant/public-home` `{memberId}` → `data.id` as `merchantRowId`.
    public func publicHome(memberId: Int) async throws -> MerchantPublicHomeRow {
        guard gate.enabled else { throw MerchantPublicReviewHookFailure.disabled }
        guard memberId > 0 else { throw MerchantPublicReviewHookFailure.invalid }
        let data = try await sendOK(path: "api/merchant/public-home", query: [], body: ["memberId": memberId], token: nil)
        struct Envelope: Decodable { let code: Int; let data: Row?; struct Row: Decodable { let id: Int?; let memberId: Int? } }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data), envelope.code == 200,
              let row = envelope.data?.id, row > 0,
              envelope.data?.memberId == memberId else { throw MerchantPublicReviewHookFailure.malformed }
        return MerchantPublicHomeRow(merchantRowId: row, memberId: memberId)
    }

    /// `POST /api/merchant/reviews/public?merchantRowId&registrationId&pageNum&pageSize=20`.
    public func publicReviews(merchantRowId: Int, registrationId: Int, pageNum: Int, pageSize: Int = 20, token: String) async throws -> PublicMerchantReviewPage {
        guard gate.enabled else { throw MerchantPublicReviewHookFailure.disabled }
        guard merchantRowId > 0, registrationId > 0, pageNum > 0, pageSize == 20,
              AuthRequestBuilder.isValidToken(token) else { throw MerchantPublicReviewHookFailure.invalid }
        let query = [
            URLQueryItem(name: "merchantRowId", value: String(merchantRowId)),
            URLQueryItem(name: "registrationId", value: String(registrationId)),
            URLQueryItem(name: "pageNum", value: String(pageNum)),
            URLQueryItem(name: "pageSize", value: String(pageSize))
        ]
        let data = try await sendOK(path: "api/merchant/reviews/public", query: query, body: nil, token: token)
        struct Envelope: Decodable { let code: Int; let data: PublicMerchantReviewPage? }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data), envelope.code == 200,
              let page = envelope.data else { throw MerchantPublicReviewHookFailure.malformed }
        do { try page.validate(page: pageNum, size: pageSize) }
        catch { throw MerchantPublicReviewHookFailure.malformed }
        // free-explore-bundle.js reviews(): requestedRegistrationId must be this order,
        // and canCreate is only true for that same registration.
        guard page.eligibility.requestedRegistrationId == registrationId else { throw MerchantPublicReviewHookFailure.malformed }
        if page.eligibility.canCreate, page.eligibility.registrationId != registrationId {
            throw MerchantPublicReviewHookFailure.malformed
        }
        return page
    }

    /// `POST /api/merchant/reviews/create` `{merchantRowId, registrationId, rating, content, imageUrls, requestId}`.
    public func createReview(_ command: MerchantPublicReviewCreate, token: String) async throws -> PublicMerchantReviewReceipt {
        guard gate.enabled else { throw MerchantPublicReviewHookFailure.disabled }
        guard AuthRequestBuilder.isValidToken(token) else { throw MerchantPublicReviewHookFailure.invalid }
        let (data, status) = try await send(path: "api/merchant/reviews/create", query: [], body: command.fields, token: token)
        struct Envelope: Decodable { let code: Int; let msg: String?; let data: PublicMerchantReviewReceipt? }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else { throw MerchantPublicReviewHookFailure.malformed }
        if envelope.code != 200 {
            if Self.refused(code: envelope.code, message: envelope.msg, http: status) {
                throw MerchantPublicReviewHookFailure.rejected(envelope.code, envelope.msg)
            }
            throw MerchantPublicReviewHookFailure.malformed
        }
        guard (200..<300).contains(status), let receipt = envelope.data else { throw MerchantPublicReviewHookFailure.malformed }
        let checked = PublicMerchantReviewCommand.create(registrationID: command.registrationId, rating: command.rating,
                                                         content: command.content, images: [])
        do { try receipt.validate(checked) }
        catch { throw MerchantPublicReviewHookFailure.malformed }
        return receipt
    }

    /// 400, 403, or 409 whose text says 已评价. Other results stay unknown to the caller.
    private static func refused(code: Int, message: String?, http: Int) -> Bool {
        guard (200..<300).contains(http) || (400..<500).contains(http) else { return false }
        if code == 400 || code == 403 { return true }
        return code == 409 && message?.contains("已评价") == true
    }

    private func sendOK(path: String, query: [URLQueryItem], body: Any?, token: String?) async throws -> Data {
        let (data, status) = try await send(path: path, query: query, body: body, token: token)
        guard (200..<300).contains(status) else { throw MerchantPublicReviewHookFailure.unavailable }
        return data
    }

    private func send(path: String, query: [URLQueryItem], body: Any?, token: String?) async throws -> (Data, Int) {
        var components = URLComponents(url: configuration.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !query.isEmpty { components?.queryItems = query }
        guard let url = components?.url else { throw MerchantPublicReviewHookFailure.invalid }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue(token, forHTTPHeaderField: "Authorization") }
        if let body {
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        }
        try Task.checkCancellation()
        let (data, status) = try await transport.send(request)
        try Task.checkCancellation()
        guard data.count <= 1_048_576 else { throw MerchantPublicReviewHookFailure.unavailable }
        if !(200..<500).contains(status) { throw MerchantPublicReviewHookFailure.unavailable }
        return (data, status)
    }
}
