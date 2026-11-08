import Foundation

// RePoint 03 - Club settlement READ adapter. NOT COMPILED.
// iOS route `api/club/settlements` (native-only, not served) -> production `POST /api/club/settlement/summary`.
// Evidence: ApiClubSettlementController.java:70 (chengyin), pages/club/settlement/index.js:107.
// Read only: the sibling `/withdraw` route is money movement and is deliberately NOT adapted.

public enum RePoint03SettlementError: Error, Equatable { case malformed, unverifiedTotal }

/// Request: JSON `{"clubId": <int>}`, POST, Content-Type application/json (controller takes @RequestBody Map).
public struct RePoint03SettlementRequest: Encodable, Equatable {
    public let clubId: Int
    public init?(clubID: Int) { guard clubID > 0 else { return nil }; clubId = clubID }
    public static let path = "api/club/settlement/summary"
    public static let method = "POST"
}

/// Production response wrapper is the RuoYi `AjaxResult`: `{code, msg, data}`.
struct RePoint03SettlementEnvelope: Decodable {
    let code: Int?
    let msg: String?
    let data: Payload?
    struct Payload: Decodable {
        let settledAmountText: String?
        let settledAmountStatus: String?
        let unverifiedSettledCount: Int?
        let isOwner: Bool?
        let topics: [Topic]?
    }
    struct Topic: Decodable {
        let id: Int?
        let topicId: Int?
        let name: String?
        let originalAmountText: String?
        let executedAdjustmentText: String?
        let netAmountText: String?
        let amountText: String?
        let amountStatus: String?
        let arrivedText: String?
        let paidText: String?
        let status: String?
    }
}

public struct RePoint03SettlementResult: Equatable {
    public let records: [ClubSettlementDetailRecord]
    /// nil == UNKNOWN (server withheld the total because some settled rows are unverified). Never 0.
    public let settledAmountText: String?
    public let unverifiedSettledCount: Int
    public let viewerIsOwner: Bool
}

public enum RePoint03ClubSettlementAdapter {
    public static func decode(_ data: Data) throws -> RePoint03SettlementResult {
        guard let env = try? JSONDecoder().decode(RePoint03SettlementEnvelope.self, from: data),
              env.code == 200, let payload = env.data, let topics = payload.topics,
              let unverified = payload.unverifiedSettledCount, let owner = payload.isOwner else {
            throw RePoint03SettlementError.malformed
        }
        let records: [ClubSettlementDetailRecord] = try topics.map { t in
            guard let id = t.id, let topicID = t.topicId, let name = t.name,
                  let original = t.originalAmountText, let adjust = t.executedAdjustmentText,
                  let net = t.netAmountText, let arrived = t.arrivedText, let paid = t.paidText,
                  let raw = t.status else { throw RePoint03SettlementError.malformed }
            let status: ClubSettlementDisplayStatus
            switch (raw, t.amountStatus) {
            case ("void", _): status = .void
            case ("pending", _): status = .pending
            case ("settled", "verified"): status = .credited
            case ("settled", "unverified"): status = .unverified
            default: throw RePoint03SettlementError.malformed
            }
            return ClubSettlementDetailRecord(id: id, topicID: topicID, name: name, amountText: t.amountText,
                                              status: status, originalAmountText: original,
                                              executedAdjustmentText: adjust, netAmountText: net,
                                              arrivedText: arrived, paidText: paid)
        }
        // Server contract: total is null iff unverifiedSettledCount > 0.
        if unverified == 0, payload.settledAmountText == nil { throw RePoint03SettlementError.malformed }
        return RePoint03SettlementResult(records: records,
                                         settledAmountText: unverified == 0 ? payload.settledAmountText : nil,
                                         unverifiedSettledCount: unverified, viewerIsOwner: owner)
    }
}
