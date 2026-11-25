import Foundation

/// `pages/merchant/utils/merchant-finance.js` `normalizeMerchantFinanceRoute`.
/// Unknown `view` is `链接已失效` (nil). A bare path is the legacy tab 0, 核销.
public struct MerchantFinanceRoute: Equatable {
    public enum View: String, Equatable { case redemptions, settlement, messages }
    public static let expired = "链接已失效"
    public let view: View
    public let source: String
    public let topicID: Int?
    public let ownerType: Int?
    public let ownerID: Int?
    public static func normalize(_ query: [String: String]) -> Self? {
        if query["ownerType"] != nil || query["ownerId"] != nil {
            guard query["view"] == View.messages.rawValue,
                  let ownerType = canonicalID(query["ownerType"] ?? ""),
                  let ownerID = canonicalID(query["ownerId"] ?? ""),
                  ownerType == 1 || ownerType == 2 else { return nil }
            return Self(view: .messages, source: "", topicID: nil, ownerType: ownerType, ownerID: ownerID)
        }
        if let raw = query["view"], !raw.isEmpty {
            guard let view = View(rawValue: raw) else { return nil }
            let topicID = view == .redemptions ? canonicalID(query["topicId"] ?? "") : nil
            let source = view == .settlement ? (query["source"] ?? "") : ""
            return Self(view: view, source: source, topicID: topicID, ownerType: nil, ownerID: nil)
        }
        switch query["tab"] ?? "0" {
        case "0": return Self(view: .redemptions, source: "", topicID: nil, ownerType: nil, ownerID: nil)
        case "1": return Self(view: .messages, source: "", topicID: nil, ownerType: nil, ownerID: nil)
        case "2": return Self(view: .settlement, source: "", topicID: nil, ownerType: nil, ownerID: nil)
        case "3": return Self(view: .settlement, source: "coop", topicID: nil, ownerType: nil, ownerID: nil)
        default: return nil
        }
    }
    static func canonicalID(_ text: String) -> Int? {
        guard text.utf8.count <= 18, text.utf8.allSatisfy({ (48...57).contains($0) }),
              let value = Int(text), value > 0, String(value) == text else { return nil }
        return value
    }
}

/// `pages/merchant/profile/index` accepts exactly one of `id` and `poiId`.
public enum MerchantPublicHomeLink: Equatable {
    case merchant(Int)
    case poi(Int)
    public static func target(_ query: [String: String]) -> Self? {
        let id = MerchantFinanceRoute.canonicalID(query["id"] ?? "")
        let poi = MerchantFinanceRoute.canonicalID(query["poiId"] ?? "")
        switch (id, poi) {
        case (let id?, nil): return .merchant(id)
        case (nil, let poi?): return .poi(poi)
        default: return nil
        }
    }
}

/// Order-detail link. Missing `recordType` or `recordId` is `缺少核销记录信息`.
public enum MerchantOrderDetailLink {
    public static let missing = "缺少核销记录信息"
    public static let missingRecord = "这条核销记录不存在或已不可见"
    public static func record(_ query: [String: String]) -> MerchantLedgerRecordRef? {
        guard let type = query["recordType"], let id = query["recordId"] else { return nil }
        return MerchantLedgerRecordRef(recordType: type, recordID: id)
    }
}

/// Settlement-detail `onLoad`: source finance|club, otherwise ledger. Club needs `clubId`.
public struct MerchantSettlementDetailLink: Equatable {
    public enum Source: String, Equatable { case finance, ledger, club }
    public static let missing = "缺少结算记录信息"
    public let source: Source
    public let recordID: String
    public let clubID: Int?
    public let personal: Bool
    public let recordKey: String
    public static func resolve(_ query: [String: String]) -> Self? {
        let source: Source = query["source"] == "finance" || query["source"] == "club" ? Source(rawValue: query["source"]!)! : .ledger
        let personal = query["personal"] == "1"
        let clubByID = source == .club && !(query["id"] ?? "").isEmpty
        let recordKey = source == .ledger || clubByID ? "id" : "topicId"
        let recordID = query[recordKey] ?? ""
        let clubID = source == .club ? MerchantFinanceRoute.canonicalID(query["clubId"] ?? "") : nil
        guard !recordID.isEmpty, source != .club || clubID != nil else { return nil }
        return Self(source: source, recordID: recordID, clubID: clubID, personal: personal, recordKey: recordKey)
    }
}

public struct CoopListLink: Equatable {
    public let tab: String?
    public let topicID: Int?
    public let topicName: String?
    public let merchantScope: Bool
    public init(_ query: [String: String]) {
        let tab = query["tab"]
        self.tab = tab == "sent" || tab == "received" ? tab : nil
        topicID = MerchantFinanceRoute.canonicalID(query["topicId"] ?? "")
        let name = query["topicName"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        topicName = name.isEmpty ? nil : name
        merchantScope = query["scope"] == "MERCHANT"
    }
}

public struct CoopInviteLink: Equatable {
    public let type: Int
    public let toID: Int?
    public let topicID: Int?
    public let originApplyID: Int?
    public let toName: String?
    /// Only `MERCHANT` is kept. Any other value is absent, matching the list page.
    public let scope: String?
    public init?(_ query: [String: String]) {
        let raw = query["type"] ?? "1"
        guard raw == "0" || raw == "1", let type = Int(raw) else { return nil }
        self.type = type
        toID = query["toId"].flatMap(MerchantFinanceRoute.canonicalID)
        topicID = query["topicId"].flatMap(MerchantFinanceRoute.canonicalID)
        originApplyID = query["originApplyId"].flatMap(MerchantFinanceRoute.canonicalID)
        let name = query["toName"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        toName = name.isEmpty ? nil : name
        scope = query["scope"] == "MERCHANT" ? "MERCHANT" : nil
    }
}

public struct CoopInviteDetailLink: Equatable {
    public let inviteID: Int?
    public let box: String
    public init(_ query: [String: String]) {
        inviteID = MerchantFinanceRoute.canonicalID(query["inviteId"] ?? "")
        box = query["box"] == "sent" ? "sent" : "received"
    }
}

public struct CoopNearbyLink: Equatable {
    public let topicID: Int?
    public let topicName: String?
    public init(_ query: [String: String]) {
        topicID = MerchantFinanceRoute.canonicalID(query["topicId"] ?? "")
        let name = query["topicName"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        topicName = name.isEmpty ? nil : name
    }
}

/// Shared 404 / 「记录不存在|不可见」 detector from `finance-detail-load.js`.
public enum MerchantFinanceDetailLoad {
    public static let batchMissingParam = "缺少结算批次信息"
    public static let batchMissingRecord = "这条结算批次不存在或已不可见"
    public static func isMissingRecord(code: String?, statusCode: String?, message: String?) -> Bool {
        if code == "404" || statusCode == "404" { return true }
        return (message ?? "").range(of: #"记录(?:不可见|不存在)"#, options: .regularExpression) != nil
    }
}
