import Foundation

public struct ClubTopicMerchantRow: Equatable, Identifiable {
    /// A station/node identity, not a merchant or member identity.
    public let id: Int
    public let merchantName: String?
    public let stationName: String?
    public let state: String?
    /// Confirmed merchant phone for the copy button. Nil when the node has no phone.
    public let phone: String?
    /// Masked contact line. Unconfirmed merchants use the empty-contact sentence.
    public let contactText: String
    public var initial: String? { merchantName.map { String($0.prefix(1)) } }
}

/// P056 buildMerchantRows: exclude open recruitment slots and keep station order.
/// `phone` is the copy value. `phoneText`, `mobile`, and nested contact stay off the row.
public struct ClubTopicMerchantList: Equatable {
    public let scope: ClubGovernanceScope
    public let rows: [ClubTopicMerchantRow]
    public init(snapshot: ClubGovernanceSnapshot, context: ClubGovernanceReadContext) throws {
        try context.scope.validate()
        guard context.operation == .recruit, context.accepts(snapshot),
              (context.identity?.accountID ?? 0) > 0,
              let clubID = context.scope.clubID, clubID > 0,
              let topicID = context.scope.topicID, topicID > 0 else { throw ClubGovernanceFailure.targetChanged }
        guard snapshot.permissions?.allows(ClubGovernanceRead.recruit.permission, scope: context.scope) == true else { throw ClubGovernanceFailure.forbidden }
        let value = try ClubGovernanceValidation.validate(snapshot.value, operation: .recruit, scope: context.scope)
        try Self.checkScope(value, clubID: clubID, topicID: topicID)
        guard let nodes = value["nodes"].array else { throw ClubGovernanceFailure.malformed }
        let rawNodes = snapshot.value["nodes"].array ?? []
        var rows: [ClubTopicMerchantRow] = [], seen = Set<Int>()
        for (index, node) in nodes.enumerated() {
            try Self.checkScope(node, clubID: clubID, topicID: topicID)
            // Exact case-sensitive source condition. Unknown states remain visible.
            guard node["state"] != .string("OPEN") else { continue }
            guard let id = node["nodeId"].int, (1...9_007_199_254_740_991).contains(id), seen.insert(id).inserted else { throw ClubGovernanceFailure.malformed }
            let phone = Self.text(index < rawNodes.count ? rawNodes[index]["phone"] : .null)
            rows.append(.init(id: id, merchantName: Self.text(node["merchantName"]), stationName: Self.text(node["name"]),
                              state: Self.text(node["state"]), phone: phone, contactText: Self.contactText(phone)))
        }
        scope = context.scope; self.rows = rows
    }
    private static func checkScope(_ value: ClubGovernanceValue, clubID: Int, topicID: Int) throws {
        guard (value["clubId"] == .null || value["clubId"].int == clubID),
              (value["topicId"] == .null || value["topicId"].int == topicID) else { throw ClubGovernanceFailure.targetChanged }
    }
    private static func text(_ value: ClubGovernanceValue) -> String? {
        guard let text = value.string else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    /// `maskPhone` in pages/club/topic-detail/index.js. Fewer than 7 digits is unconfirmed.
    static func contactText(_ phone: String?) -> String {
        let digits = phone?.filter(\.isNumber) ?? ""
        guard digits.count >= 7 else { return "未确认，暂无联系方式" }
        return String(digits.prefix(3)) + "****" + String(digits.suffix(4))
    }
}
