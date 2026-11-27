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
        "api/merchant/crm/marketing-consents",
        "api/topic/chapter/self-supply"
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

    /// `R11-PC-B-3`: free-explore author 自己承接 = `POST /api/topic/chapter/self-supply {topicId, chapterId, perk}`
    /// (MP utils/fe-author-sale.js:59-77 `selfSupplyBody`, :117-128). The caller validates the perk first.
    public func selfSupply(topicID: Int, chapterID: Int, perk: TopicSelfSupplyPerk) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/topic/chapter/self-supply",
            method: "POST",
            json: [
                "topicId": .integer(Int64(topicID)),
                "chapterId": .integer(Int64(chapterID)),
                "perk": .object([
                    "name": .string(perk.name),
                    "redeemRule": .string(perk.redeemRule),
                    "validEnd": .string(perk.validEnd),
                    "capacity": .integer(Int64(perk.capacity))
                ])
            ]
        ) else { return .unauthorized }
        return await send(req)
    }

    /// `R7-PC-B1-12` / `R11-PC-C-3`: `GET /api/merchant/crm/marketing-consents`, then MP `pickOffer`
    /// (utils/marketing-consent-entry.js:52-72, 24-41). Any failure is nil (silent, fail-closed).
    public func loadMarketingConsentOffer(ownerMemberID: Int?) async -> MarketingConsentOffer? {
        guard let ownerMemberID, ownerMemberID > 0,
              let req = try? makeRequest("api/merchant/crm/marketing-consents", method: "GET") else { return nil }
        guard let rows = await send(req).data?.array else { return nil }
        return MarketingConsentOffer.pick(rows, ownerMemberID: ownerMemberID)
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
                // MP utils/marketing-consent-entry.js:83: the in-app channel is `IN_APP`.
                "channel": .string("IN_APP"),
                "optedIn": .bool(optedIn),
                "requestId": .string(requestID)
            ]
        ) else { return .unauthorized }
        return await send(req)
    }
}

/// R7-PC-B1-12 / R11-PC-C-3: one opt-in offer (MP utils/marketing-consent-entry.js `pickOffer`, :24-41).
public struct MarketingConsentOffer: Equatable, Sendable {
    public let merchantRowID: Int
    public let merchantOwnerMemberID: Int
    public let merchantName: String

    public init(merchantRowID: Int, merchantOwnerMemberID: Int, merchantName: String) {
        self.merchantRowID = merchantRowID
        self.merchantOwnerMemberID = merchantOwnerMemberID
        self.merchantName = merchantName
    }

    /// Exactly one row for the owner; it must not be opted in already and must carry a positive `merchantRowId`.
    public static func pick(_ rows: [PlayWireValue], ownerMemberID: Int) -> MarketingConsentOffer? {
        guard ownerMemberID > 0 else { return nil }
        let matches = rows.filter { $0["merchantOwnerMemberId"].tolerantInteger == ownerMemberID }
        guard matches.count == 1, let row = matches.first else { return nil }
        if case .bool(true) = row["inAppOptedIn"] { return nil }
        guard let rowID = row["merchantRowId"].tolerantInteger, rowID > 0 else { return nil }
        let name = row["merchantName"].text.flatMap { $0.isEmpty ? nil : $0 } ?? "商家"
        return MarketingConsentOffer(merchantRowID: rowID, merchantOwnerMemberID: ownerMemberID, merchantName: name)
    }

    /// MP `newRequestId` (marketing-consent-entry.js:104-108): one id per opt-in intent, reused on retry.
    public static func newRequestID() -> String {
        "consent-opt-in-" + String(Int(Date().timeIntervalSince1970 * 1000), radix: 36) + "-" + String(Int.random(in: 0...0xFFFFFF), radix: 36)
    }
}

/// R11-PC-B-3: MP `selfSupplyBody` perk (utils/fe-author-sale.js:59-77).
public struct TopicSelfSupplyPerk: Equatable, Sendable {
    public enum Problem: Equatable, Sendable { case name, capacity, validEnd }
    public let name: String
    public let redeemRule: String
    public let validEnd: String
    public let capacity: Int

    /// Trims and validates like MP: a name, a positive whole capacity, and `yyyy-MM-dd`.
    public static func validate(name: String, redeemRule: String, capacity: String, validEnd: String) -> Result<TopicSelfSupplyPerk, TopicSelfSupplyPerkError> {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return .failure(TopicSelfSupplyPerkError(problem: .name)) }
        guard let count = Int(capacity.trimmingCharacters(in: .whitespacesAndNewlines)), count > 0 else {
            return .failure(TopicSelfSupplyPerkError(problem: .capacity))
        }
        let end = validEnd.trimmingCharacters(in: .whitespacesAndNewlines)
        guard end.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else {
            return .failure(TopicSelfSupplyPerkError(problem: .validEnd))
        }
        return .success(TopicSelfSupplyPerk(name: trimmedName, redeemRule: redeemRule.trimmingCharacters(in: .whitespacesAndNewlines),
                                            validEnd: end, capacity: count))
    }
}
public struct TopicSelfSupplyPerkError: Error, Equatable, Sendable {
    public let problem: TopicSelfSupplyPerk.Problem
}
