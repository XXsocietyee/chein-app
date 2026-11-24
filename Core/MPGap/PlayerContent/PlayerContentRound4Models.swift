import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Round-4 Core models & service for `player-content` Gemini items:
/// `R7-PC-B3-2`, `R7-PC-B1-12`, `R7-PC-B2-2`, `R7-PC-B1-22`.

// MARK: - R7-PC-B3-2: Merchant Apply Map & Photo Picker State

public struct MerchantApplyLocationSelection: Equatable, Sendable {
    public let address: String
    public let latitude: Double
    public let longitude: Double

    public init(address: String, latitude: Double, longitude: Double) {
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct MerchantApplyPrefillSummary: Equatable, Sendable {
    public let shopName: String
    public let address: String
    public let latitude: Double?
    public let longitude: Double?
    public let picURLs: [String]

    public init(
        shopName: String,
        address: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        picURLs: [String] = []
    ) {
        self.shopName = shopName
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.picURLs = picURLs
    }
}

// MARK: - R7-PC-B1-12: Post-Purchase Pass Reveal & Marketing Consent

public struct TopicPurchaseRevealCardModel: Equatable, Sendable {
    public let coverURL: String?
    public let topicName: String
    public let kindText: String
    public let untilText: String
    public let daysText: String
    public let durationLine: String?
    public let merchantRowID: Int?
    public let merchantOwnerMemberID: Int?

    public init(
        coverURL: String?,
        topicName: String,
        kindText: String,
        untilText: String,
        daysText: String,
        durationLine: String? = nil,
        merchantRowID: Int? = nil,
        merchantOwnerMemberID: Int? = nil
    ) {
        self.coverURL = coverURL
        self.topicName = topicName
        self.kindText = kindText
        self.untilText = untilText
        self.daysText = daysText
        self.durationLine = durationLine
        self.merchantRowID = merchantRowID
        self.merchantOwnerMemberID = merchantOwnerMemberID
    }
}

// MARK: - Round-4 Service (`R7-PC-B2-2`, `R7-PC-B1-12`)

@MainActor
public final class PlayerContentRound4Service {
    public static let paths: Set<String> = [
        "api/coop/contact",
        "api/merchant/crm/marketing-consents"
    ]

    public let baseURL: URL
    private let token: () -> String?
    private let transport: any HTTPTransport

    public init(baseURL: URL, token: @escaping () -> String?, transport: any HTTPTransport) {
        self.baseURL = baseURL
        self.token = token
        self.transport = transport
    }

    func makeRequest(_ path: String, method: String, json: [String: PlayWireValue]? = nil) throws -> URLRequest {
        guard let token = token(), AuthRequestBuilder.isValidToken(token) else {
            throw APIError.invalidRequest
        }
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            request.httpBody = try encoder.encode(json)
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

    /// `R7-PC-B2-2`: `POST /api/coop/contact {id}` -> returns `conversationId`.
    public func contactHost(inviteID: Int) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/coop/contact",
            method: "POST",
            json: ["id": .integer(Int64(inviteID))]
        ) else { return .unauthorized }
        return await send(req)
    }

    /// `R7-PC-B1-12`: `POST /api/merchant/crm/marketing-consents`
    public func submitMarketingConsent(
        merchantRowID: Int,
        merchantOwnerMemberID: Int,
        optedIn: Bool,
        requestID: String
    ) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/merchant/crm/marketing-consents",
            method: "POST",
            json: [
                "merchantRowId": .integer(Int64(merchantRowID)),
                "merchantOwnerMemberId": .integer(Int64(merchantOwnerMemberID)),
                "channel": .string("APP"),
                "optedIn": .bool(optedIn),
                "requestId": .string(requestID)
            ]
        ) else { return .unauthorized }
        return await send(req)
    }
}
