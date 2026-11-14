import Foundation

/// NEW purchased-version owner metadata contract; separate from FREE claims and purchase execution.
public enum WorkshopPurchasedIssue: Error, Equatable {
    case unavailable, disabled, unauthorized, forbidden, notFound, malformed, staleSession, staleRead, invalid
}
public struct WorkshopPurchasedItem: Decodable, Equatable, Identifiable {
    public enum Status: String, Decodable { case active = "ACTIVE", suspended = "SUSPENDED", revoked = "REVOKED" }
    public enum Permission: String, Decodable { case allowed = "ALLOWED", prohibited = "PROHIBITED" }
    public enum Adaptation: String, Decodable { case bindResourcesOnly = "BIND_RESOURCES_ONLY", localAdaptation = "LOCAL_ADAPTATION" }
    public struct Limit: Decodable, Equatable {
        public let unlimited: Bool
        public let maximum: Int64
        private enum CodingKeys: String, CodingKey { case unlimited, maximum }
        public init(from decoder: Decoder) throws {
            try WorkshopPurchasedWire.exactKeys(decoder, ["unlimited", "maximum"])
            let c = try decoder.container(keyedBy: CodingKeys.self)
            unlimited = try c.decode(Bool.self, forKey: .unlimited); maximum = try c.decode(Int64.self, forKey: .maximum)
            guard maximum >= 0, !unlimited || maximum == 0 else { throw WorkshopPurchasedIssue.malformed }
        }
    }
    public let licenseId, moduleId, purchasedVersionId, contentHash, acquiredAt, termsVersion, termsHash: String
    public let status: Status
    public let commercialUse, translation: Permission
    public let adaptation: Adaptation
    public let allowedRegions: [String]
    public let themeLimit, merchantLimit, runLimit: Limit
    public var id: String { licenseId }
    public var permitsContentUse: Bool { false }
    public var permitsPurchase: Bool { false }
    private enum CodingKeys: String, CodingKey {
        case licenseId, moduleId, purchasedVersionId, contentHash, acquiredAt, termsVersion, termsHash, status
        case commercialUse, adaptation, translation, allowedRegions, themeLimit, merchantLimit, runLimit
        case acquisition, buyerKind, useDuration, updates, redistribution, contentUseStatus, purchaseActionStatus
    }
    public init(from decoder: Decoder) throws {
        try WorkshopPurchasedWire.exactKeys(decoder, ["licenseId", "moduleId", "purchasedVersionId", "contentHash", "acquiredAt", "termsVersion", "termsHash", "status", "commercialUse", "adaptation", "translation", "allowedRegions", "themeLimit", "merchantLimit", "runLimit", "acquisition", "buyerKind", "useDuration", "updates", "redistribution", "contentUseStatus", "purchaseActionStatus"])
        let c = try decoder.container(keyedBy: CodingKeys.self)
        licenseId = try c.decode(String.self, forKey: .licenseId)
        let moduleNumber = try c.decode(Int64.self, forKey: .moduleId)
        guard moduleNumber > 0 else { throw WorkshopPurchasedIssue.malformed }
        moduleId = String(moduleNumber)
        purchasedVersionId = try c.decode(String.self, forKey: .purchasedVersionId); contentHash = try c.decode(String.self, forKey: .contentHash)
        acquiredAt = try c.decode(String.self, forKey: .acquiredAt); termsVersion = try c.decode(String.self, forKey: .termsVersion)
        termsHash = try c.decode(String.self, forKey: .termsHash); status = try c.decode(Status.self, forKey: .status)
        commercialUse = try c.decode(Permission.self, forKey: .commercialUse); adaptation = try c.decode(Adaptation.self, forKey: .adaptation)
        translation = try c.decode(Permission.self, forKey: .translation); allowedRegions = try c.decode([String].self, forKey: .allowedRegions)
        themeLimit = try c.decode(Limit.self, forKey: .themeLimit); merchantLimit = try c.decode(Limit.self, forKey: .merchantLimit); runLimit = try c.decode(Limit.self, forKey: .runLimit)
        guard WorkshopPurchasedWire.license(licenseId), [purchasedVersionId, termsVersion].allSatisfy({ WorkshopPurchasedWire.bounded($0, 128) }),
              [contentHash, termsHash].allSatisfy(WorkshopPurchasedWire.hash), WorkshopPurchasedWire.timestamp(acquiredAt),
              !allowedRegions.isEmpty, allowedRegions.count <= 100, Set(allowedRegions.map { Data($0.utf8) }).count == allowedRegions.count,
              allowedRegions.allSatisfy({ $0.range(of: #"\A[0-9]{6}\z"#, options: .regularExpression) != nil }),
              !themeLimit.unlimited, themeLimit.maximum >= 1, !merchantLimit.unlimited, merchantLimit.maximum == 0,
              !runLimit.unlimited, runLimit.maximum == 0,
              try c.decode(String.self, forKey: .acquisition) == "PAID", try c.decode(String.self, forKey: .buyerKind) == "INDIVIDUAL",
              try c.decode(String.self, forKey: .useDuration) == "PERPETUAL_PURCHASED_VERSION",
              try c.decode(String.self, forKey: .updates) == "EXACT_PURCHASED_VERSION", try c.decode(String.self, forKey: .redistribution) == "PROHIBITED",
              ["PRIVATE_DRAFT_INSTALL_AVAILABLE", "LICENSE_DISABLED"].contains(try c.decode(String.self, forKey: .contentUseStatus)),
              try c.decode(String.self, forKey: .purchaseActionStatus) == "EXACT_VERSION_PURCHASED" else { throw WorkshopPurchasedIssue.malformed }
    }
}
public struct WorkshopPurchasedPage: Decodable, Equatable {
    public let items: [WorkshopPurchasedItem]
    public let nextBeforeOrderLineId: Int64?
    public let hasMore: Bool
    public let checkedAt: String
    private enum CodingKeys: String, CodingKey { case items, nextBeforeOrderLineId, hasMore, checkedAt }
    public init(from decoder: Decoder) throws {
        let keys = try WorkshopPurchasedWire.keySet(decoder)
        let required: Set<String> = ["schema", "scope", "items", "hasMore", "checkedAt"]
        guard required.isSubset(of: keys), keys.isSubset(of: required.union(["nextBeforeOrderLineId"])) else { throw WorkshopPurchasedIssue.malformed }
        try WorkshopPurchasedWire.metadata(decoder)
        let c = try decoder.container(keyedBy: CodingKeys.self)
        checkedAt = try c.decode(String.self, forKey: .checkedAt); hasMore = try c.decode(Bool.self, forKey: .hasMore)
        nextBeforeOrderLineId = try c.decodeIfPresent(Int64.self, forKey: .nextBeforeOrderLineId)
        var input = try c.nestedUnkeyedContainer(forKey: .items), values: [WorkshopPurchasedItem] = [], seen = Set<String>()
        while !input.isAtEnd { guard values.count < 50 else { throw WorkshopPurchasedIssue.malformed }; let item = try input.decode(WorkshopPurchasedItem.self); guard seen.insert(item.id).inserted else { throw WorkshopPurchasedIssue.malformed }; values.append(item) }
        guard WorkshopPurchasedWire.timestamp(checkedAt), hasMore == keys.contains("nextBeforeOrderLineId"), nextBeforeOrderLineId.map({ $0 > 0 }) != false,
              !hasMore || values.count == 50 else { throw WorkshopPurchasedIssue.malformed }; items = values
    }
}
public struct WorkshopPurchasedDetail: Decodable, Equatable {
    public let item: WorkshopPurchasedItem
    /// The bare license has no checkedAt. Unknown is an em dash.
    public let checkedAt: String
    public init(item: WorkshopPurchasedItem) { self.item = item; checkedAt = "—" }
    public init(from decoder: Decoder) throws {
        item = try WorkshopPurchasedItem(from: decoder)
        checkedAt = "—"
    }
}
enum WorkshopPurchasedWire {
    private struct Key: CodingKey { let stringValue: String; let intValue: Int? = nil; init?(stringValue: String) { self.stringValue = stringValue }; init?(intValue: Int) { return nil } }
    static func keySet(_ decoder: Decoder) throws -> Set<String> {
        Set(try decoder.container(keyedBy: Key.self).allKeys.map(\.stringValue))
    }
    static func exactKeys(_ decoder: Decoder, _ expected: Set<String>) throws {
        guard try keySet(decoder) == expected else { throw WorkshopPurchasedIssue.malformed }
    }
    private enum Metadata: String, CodingKey { case schema, scope }
    static func metadata(_ decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Metadata.self)
        guard try c.decode(String.self, forKey: .schema) == "workshop-purchased-v2",
              try c.decode(String.self, forKey: .scope) == "INDIVIDUAL" else { throw WorkshopPurchasedIssue.malformed }
    }
    static func bounded(_ s: String, _ max: Int) -> Bool { !s.isEmpty && s.utf8.count <= max }
    static func license(_ s: String) -> Bool {
        s.range(of: #"\AWKO_[a-f0-9]{32}\z"#, options: .regularExpression) != nil
    }
    static func hash(_ s: String) -> Bool { s.utf8.count == 64 && s.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) } }
    static func timestamp(_ s: String) -> Bool { WorkshopOwnedWire.timestamp(s) }
}
