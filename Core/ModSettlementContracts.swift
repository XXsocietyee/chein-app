import Foundation

/// Matches W18.7 creator-only views. Amounts are integer minor units, never wallet balances or ticket revenue.
public struct ModSettlementRecord: Decodable, Equatable, Identifiable {
    public let id: String, orderKey: String, currency: String, state: ModSettlementState
    public let creatorId: Int64, amount: Int64, retainedAmount: Int64, version: Int64
    public let frozen: Bool
    public let freezeReason: String?, draftDigest: String, intentKey: String?, providerTransferId: String?
    public let createdAt: Date, updatedAt: Date
    public func validate(owner: Int64) throws {
        guard ModSettlementWire.settlementID(id), creatorId == owner, owner > 0,
              ModSettlementWire.reference(orderKey), ModSettlementWire.currency(currency), amount > 0, retainedAmount >= 0,
              version >= 0, ModSettlementWire.hex(draftDigest, count: 64), createdAt <= updatedAt,
              freezeReason.map({ ModSettlementWire.reference($0) }) ?? true,
              providerTransferId.map({ ModSettlementWire.reference($0) }) ?? true else { throw ModSettlementIssue.malformed }
        if let intentKey { guard intentKey.hasPrefix("MS"), ModSettlementWire.hex(String(intentKey.dropFirst(2)), count: 30) else { throw ModSettlementIssue.malformed } }
        if [.approved, .submitting, .unknown, .pending, .succeeded, .failed].contains(state), intentKey == nil { throw ModSettlementIssue.malformed }
        if state == .succeeded, providerTransferId == nil { throw ModSettlementIssue.malformed }
        if state == .draft, intentKey != nil { throw ModSettlementIssue.malformed }
    }
    public var isProviderConfirmedPaid: Bool { state == .succeeded && providerTransferId != nil }
}
public enum ModSettlementState: String, Decodable, Equatable {
    case draft = "DRAFT", approved = "APPROVED", submitting = "SUBMITTING", unknown = "UNKNOWN"
    case pending = "PENDING", succeeded = "SUCCEEDED", failed = "FAILED", cancelled = "CANCELLED"
    public var localizationKey: String { "modSettlement.state." + rawValue }
    public var explanationKey: String { "modSettlement.explanation." + rawValue }
}
public struct ModSettlementQualification: Decodable, Equatable {
    public let creatorId: Int64, revision: Int64
    public let reviewApproved: Bool
    public let expiresAt: Date?
    public let providerId: String?, currency: String?
    public func validate(owner: Int64) throws {
        guard creatorId == owner, owner > 0, revision > 0 else { throw ModSettlementIssue.malformed }
        if reviewApproved {
            guard expiresAt != nil, let providerId, ModSettlementWire.reference(providerId), let currency,
                  ModSettlementWire.currency(currency) else { throw ModSettlementIssue.malformed }
        }
    }
    public func presentationKey(now: Date = Date()) -> String {
        guard reviewApproved else { return "modSettlement.qualification.notApproved" }
        guard let expiresAt, expiresAt > now else { return "modSettlement.qualification.expired" }
        return "modSettlement.qualification.valid"
    }
}
public struct ModSettlementOverview {
    public let records: [ModSettlementRecord]
    public let qualification: ModSettlementQualification?
    public let readAt: Date
}
public enum ModSettlementIssue: Error, Equatable {
    case notConfigured, login, stale, unavailable, malformed, notFound
    public var localizationKey: String {
        switch self {
        case .notConfigured: return "modSettlement.issue.notConfigured"
        case .login: return "modSettlement.issue.login"
        case .stale: return "modSettlement.issue.stale"
        case .unavailable: return "modSettlement.issue.unavailable"
        case .malformed: return "modSettlement.issue.malformed"
        case .notFound: return "modSettlement.issue.notFound"
        }
    }
    public init(_ error: Error) {
        if let issue = error as? Self { self = issue } else { self = .unavailable }
    }
}
enum ModSettlementWire {
    static func hex(_ text: String, count: Int) -> Bool { text.utf8.count == count && text.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) } }
    static func settlementID(_ text: String) -> Bool { text.hasPrefix("ms_") && hex(String(text.dropFirst(3)), count: 64) }
    static func reference(_ text: String) -> Bool {
        !text.isEmpty && text.utf8.count <= 160 && text.utf8.allSatisfy { (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || [95, 46, 58, 47, 64, 45].contains($0) }
    }
    static func currency(_ text: String) -> Bool { text.utf8.count == 3 && text.utf8.allSatisfy { (65...90).contains($0) } }
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            let fractional = ISO8601DateFormatter(); fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let seconds = ISO8601DateFormatter(); seconds.formatOptions = [.withInternetDateTime]
            guard let value = fractional.date(from: raw) ?? seconds.date(from: raw), value.timeIntervalSince1970.isFinite else { throw ModSettlementIssue.malformed }
            return value
        }
        return decoder
    }
}

/// Original MOD purchase allocation, not the buyer's paid price, a wallet balance or a payout entitlement.
public struct ModCreatorIncomeFact: Decodable, Equatable, Identifiable {
    public let source, orderKey, modReleaseId, currency: String
    public let creatorId, creatorAmount, refundedAmount, chargebackAmount, revision: Int64
    public let paidAt: Date
    public let disputed: Bool
    public var id: String { orderKey }
    public func validate(owner: Int64) throws {
        guard source == "MOD_PURCHASE", owner > 0, creatorId == owner, ModCreatorIncomeWire.orderKey(orderKey),
              ModCreatorIncomeWire.key(modReleaseId), ["CNY", "USD"].contains(currency),
              creatorAmount >= 0, creatorAmount <= Int64(Int32.max), refundedAmount >= 0, refundedAmount <= creatorAmount,
              chargebackAmount >= 0, chargebackAmount <= creatorAmount - refundedAmount, revision > 0,
              paidAt.timeIntervalSince1970.isFinite else { throw ModSettlementIssue.malformed }
    }
    public func samePurchase(as other: Self) -> Bool {
        source == other.source && orderKey == other.orderKey && creatorId == other.creatorId &&
            modReleaseId == other.modReleaseId && currency == other.currency && creatorAmount == other.creatorAmount && paidAt == other.paidAt
    }
}
public struct ModCreatorIncomePage: Decodable {
    public let schema: String, creatorId: Int64, facts: [ModCreatorIncomeFact], nextCursor: String?
    public func validate(owner: Int64, before: String?) throws {
        guard schema == "mod-creator-income-page-v1", creatorId == owner, facts.count <= 50,
              Set(facts.map(\.orderKey)).count == facts.count else { throw ModSettlementIssue.malformed }
        var previous = before
        for fact in facts {
            try fact.validate(owner: owner)
            guard previous.map({ fact.orderKey < $0 }) ?? true else { throw ModSettlementIssue.malformed }
            previous = fact.orderKey
        }
        if let nextCursor { guard !facts.isEmpty, nextCursor == facts.last?.orderKey else { throw ModSettlementIssue.malformed } }
    }
}
public struct ModCreatorIncomeDetail: Decodable {
    public let schema: String, creatorId: Int64, current: ModCreatorIncomeFact
    public func validate(owner: Int64, orderKey: String, minimumRevision: Int64) throws {
        guard schema == "mod-creator-income-detail-v1", creatorId == owner, current.orderKey == orderKey,
              current.revision >= minimumRevision else { throw ModSettlementIssue.malformed }
        try current.validate(owner: owner)
    }
}
public struct ModCreatorIncomeRevisions: Decodable {
    public let schema: String, creatorId: Int64, orderKey: String, asOfRevision: Int64
    public let revisions: [ModCreatorIncomeFact], nextBeforeRevision: Int64?
    public func validate(owner: Int64, anchor: ModCreatorIncomeFact, before: Int64?) throws {
        guard schema == "mod-creator-income-revisions-v1", creatorId == owner, orderKey == anchor.orderKey,
              asOfRevision == anchor.revision, revisions.count <= 50,
              Set(revisions.map(\.revision)).count == revisions.count else { throw ModSettlementIssue.malformed }
        var previous = before
        for fact in revisions {
            try fact.validate(owner: owner)
            guard fact.samePurchase(as: anchor), fact.revision <= asOfRevision,
                  previous.map({ fact.revision < $0 }) ?? true else { throw ModSettlementIssue.malformed }
            previous = fact.revision
        }
        if before == nil { guard revisions.first == anchor else { throw ModSettlementIssue.malformed } }
        if let nextBeforeRevision {
            guard !revisions.isEmpty, nextBeforeRevision == revisions.last?.revision, nextBeforeRevision > 1 else { throw ModSettlementIssue.malformed }
        }
    }
}
enum ModCreatorIncomeWire {
    static func orderKey(_ value: String) -> Bool { value.hasPrefix("MOD") && ModSettlementWire.hex(String(value.dropFirst(3)), count: 29) }
    static func key(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 128 && value.utf8.allSatisfy {
            (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 95 || $0 == 45
        }
    }
    static func envelope(_ data: Data, kind: String) throws {
        guard let text = String(data: data, encoding: .utf8), (try? ContentDraftJSON.parse(text)) != nil,
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = root["data"] as? [String: Any] else { throw ModSettlementIssue.malformed }
        try fields(root, required: ["code", "data"], optional: ["msg"])
        let rows: [Any]
        switch kind {
        case "page":
            try fields(value, required: ["schema", "creatorId", "facts"], optional: ["nextCursor"])
            guard let facts = value["facts"] as? [Any], facts.count <= 50 else { throw ModSettlementIssue.malformed }; rows = facts
        case "detail":
            try fields(value, required: ["schema", "creatorId", "current"]); rows = [value["current"] as Any]
        case "revisions":
            try fields(value, required: ["schema", "creatorId", "orderKey", "asOfRevision", "revisions"], optional: ["nextBeforeRevision"])
            guard let facts = value["revisions"] as? [Any], facts.count <= 50 else { throw ModSettlementIssue.malformed }; rows = facts
        default: throw ModSettlementIssue.malformed
        }
        for row in rows {
            guard let row = row as? [String: Any] else { throw ModSettlementIssue.malformed }
            try fields(row, required: ["source", "orderKey", "creatorId", "modReleaseId", "currency", "creatorAmount", "refundedAmount", "chargebackAmount", "revision", "paidAt", "disputed"])
        }
    }
    private static func fields(_ value: [String: Any], required: Set<String>, optional: Set<String> = []) throws {
        let actual = Set(value.keys)
        guard required.isSubset(of: actual), actual.isSubset(of: required.union(optional)) else { throw ModSettlementIssue.malformed }
    }
}
