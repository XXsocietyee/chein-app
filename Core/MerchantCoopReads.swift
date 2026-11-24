import Foundation

/// Ledger detail identity. `activity_ticket` and `session_fee` share `redemption:`'s `recordType:recordId` shape.
public struct MerchantLedgerRecordRef: Equatable {
    public static let types = ["redemption", "activity_ticket", "session_fee"]
    public let recordType: String
    public let recordID: String
    public var recordKey: String { recordType + ":" + recordID }
    public init?(recordType: String, recordID: String) {
        guard Self.types.contains(recordType), Self.isRecordID(recordID) else { return nil }
        self.recordType = recordType
        self.recordID = recordID
    }
    public init?(wire: String) {
        guard let split = wire.firstIndex(of: ":") else { return nil }
        self.init(recordType: String(wire[..<split]), recordID: String(wire[wire.index(after: split)...]))
    }
    /// A bare decimal is a redemption id. A typed key keeps its own `recordType`.
    public init?(queryID: String) {
        if let typed = Self(wire: queryID) { self = typed; return }
        self.init(recordType: "redemption", recordID: queryID)
    }
    public static func isRecordID(_ value: String) -> Bool {
        !value.isEmpty && value.range(of: #"^[0-9]+$"#, options: .regularExpression) != nil && value.contains { $0 != "0" }
    }
}

/// `POST api/merchant/reviews/manage?filter=&pageNum=&pageSize=20`.
/// Filters are the manage tabs: all / pending / low / photo / platform.
public struct MerchantReviewManageRead: Equatable {
    public static let filters = ["all", "pending", "low", "photo", "platform"]
    public static let pageSize = 20
    public let filter: String
    public let page: Int
    public init(filter: String, page: Int) throws {
        guard Self.filters.contains(filter), page > 0, page <= Int.max / Self.pageSize else { throw MerchantBusinessFailure.invalid }
        self.filter = filter
        self.page = page
    }
    public func request() -> MerchantBusinessRequest {
        .query("api/merchant/reviews/manage", ["filter": filter, "pageNum": String(page), "pageSize": String(Self.pageSize)])
    }
    /// Absent or null counts stay unknown. A present object must carry every tab as a non-negative integer.
    public static func filterCounts(in object: MerchantBusinessObject) throws -> [String: Int]? {
        guard let value = object["filterCounts"] else { return nil }
        if value == .null { return nil }
        guard let source = value.object else { throw MerchantBusinessFailure.malformed }
        var counts: [String: Int] = [:]
        for key in filters {
            guard let count = source[key]?.integer, count >= 0 else { throw MerchantBusinessFailure.malformed }
            counts[key] = count
        }
        return counts
    }
    /// The echoed `filter` must be this request's filter. A payload that omits it still decodes.
    public func document(from payload: MerchantBusinessValue) throws -> MerchantBusinessDocument {
        if let echoed = payload.object?.mbText("filter"), echoed != filter { throw MerchantBusinessFailure.malformed }
        return try MerchantBusinessDocument(query: .reviews(page: page), payload: payload)
    }
}

/// `POST api/merchant/finance/redemptions`. `topicId` is sent only when the ledger link carried one.
public enum MerchantFinanceRedemptionList {
    public static func body(filter: String, page: Int, pageSize: Int, topicID: Int? = nil) throws -> MerchantBusinessObject {
        guard page > 0, pageSize > 0, page <= Int.max / pageSize else { throw MerchantBusinessFailure.invalid }
        if let topicID, topicID <= 0 { throw MerchantBusinessFailure.invalid }
        var fields: MerchantBusinessObject = ["filter": .string(filter), "pageNum": .int(page), "pageSize": .int(pageSize)]
        if let topicID { fields["topicId"] = .int(topicID) }
        return fields
    }
    public static func request(filter: String, page: Int, pageSize: Int, topicID: Int? = nil) throws -> MerchantBusinessRequest {
        .json("api/merchant/finance/redemptions", try body(filter: filter, page: page, pageSize: pageSize, topicID: topicID))
    }
}

/// Verify-records pages the same redemption list at `pageSize` 50 and appends while the page is full and `collected < total`.
public struct MerchantVerificationRecordPage: Equatable {
    public static let pageSize = 50
    public let page: Int
    public init(page: Int) throws {
        guard page > 0, page <= Int.max / Self.pageSize else { throw MerchantBusinessFailure.invalid }
        self.page = page
    }
    public func request() throws -> MerchantBusinessRequest {
        try MerchantFinanceRedemptionList.request(filter: "all", page: page, pageSize: Self.pageSize)
    }
    public static func hasMore(pageRowCount: Int, collected: Int, total: Int) -> Bool {
        pageRowCount == pageSize && collected < total
    }
}
