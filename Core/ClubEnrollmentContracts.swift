import Foundation

/// Em dash for a count this roster cannot prove. A literal JSON 0 is the string "0".
public enum ClubEnrollmentCountText {
    public static let unknown = "\u{2014}"
    public static func display(_ count: Int?) -> String {
        guard let count, count >= 0 else { return unknown }
        return String(count)
    }
}

/// Read-only projection of the club roster. These counts never authorize a refund.
public struct ClubEnrollmentTeam: Equatable, Identifiable {
    public let id: Int
    public let name: String?
    public let image: String?
    public let date: String?
    public let signupCount: Int?
    public init(value: ClubGovernanceValue, clubID: Int) throws {
        try ClubEnrollmentDecode.object(value)
        id = try ClubEnrollmentDecode.id(value["id"])
        if value["clubId"] != .null { guard try ClubEnrollmentDecode.id(value["clubId"]) == clubID else { throw ClubGovernanceFailure.targetChanged } }
        name = try ClubEnrollmentDecode.text(value["name"])
        image = try ClubEnrollmentDecode.text(value["imgUrl"])
        date = try ClubEnrollmentDecode.text(value["startDate"]).map { String($0.prefix(10)) }
        signupCount = try ClubEnrollmentDecode.count(value["signupCount"])
    }
    /// Missing, null, `UNKNOWN`, and a numeric string are an em dash. A literal `0` stays `0`.
    public var signupCountText: String { ClubEnrollmentCountText.display(signupCount) }
    public static func list(_ value: ClubGovernanceValue, clubID: Int) throws -> [Self] {
        guard clubID > 0 else { throw ClubGovernanceFailure.invalidRequest }
        let teams = try ClubEnrollmentDecode.rows(value).map { try Self(value: $0, clubID: clubID) }
        try ClubEnrollmentDecode.unique(teams.map(\.id)); return teams
    }
}

public enum ClubEnrollmentCheckin: String, Equatable { case unknown, pending, done }
public struct ClubEnrollmentRegistrant: Equatable, Identifiable {
    public let id: Int
    public let memberID: Int?
    public let avatar: String?
    public let nickname: String?
    public let paymentStatus: Int?
    public let verificationStatus: Int?
    public var checkin: ClubEnrollmentCheckin {
        switch verificationStatus { case 0: return .pending; case 1: return .done; default: return .unknown }
    }
    fileprivate init(_ value: ClubGovernanceValue) throws {
        try ClubEnrollmentDecode.object(value)
        id = try ClubEnrollmentDecode.id(value["id"])
        memberID = value["memberId"] == .null ? nil : try ClubEnrollmentDecode.id(value["memberId"])
        avatar = try ClubEnrollmentDecode.text(value["avatar"])
        nickname = try ClubEnrollmentDecode.text(value["nickname"])
        paymentStatus = try ClubEnrollmentDecode.count(value["paymentStatus"])
        verificationStatus = try ClubEnrollmentDecode.count(value["verificationStatus"])
    }
}
public struct ClubEnrollmentTicket: Equatable, Identifiable {
    public let id: Int
    public let name: String?
    public let mode: Int?
    public let capacity: Int?
    public let deadline: String?
    public let teamStatus: Int?
    public let registrants: [ClubEnrollmentRegistrant]
    fileprivate init(_ value: ClubGovernanceValue) throws {
        try ClubEnrollmentDecode.object(value)
        id = try ClubEnrollmentDecode.id(value["id"])
        name = try ClubEnrollmentDecode.text(value["name"])
        mode = try ClubEnrollmentDecode.count(value["mode"])
        capacity = try ClubEnrollmentDecode.count(value["totalInventory"])
        deadline = try ClubEnrollmentDecode.text(value["signupDeadline"]).map { String($0.prefix(16)).replacingOccurrences(of: "T", with: " ") }
        teamStatus = try ClubEnrollmentDecode.count(value["teamStatus"])
        // Missing/null list is a source-supported empty list; malformed non-list is not.
        registrants = value["cmsRegistrationList"] == .null ? [] : try ClubEnrollmentDecode.rows(value["cmsRegistrationList"]).map(ClubEnrollmentRegistrant.init)
        try ClubEnrollmentDecode.unique(registrants.map(\.id))
    }
    /// Numerator of 「已报名 n / 上限」. The MP sets `signups` to the registrant list length.
    public var signups: Int { registrants.count }
    public var signupNumeratorText: String {
        if let capacity, capacity > 0 { return "\(signups) / \(capacity)" }
        return "\(signups) 人"
    }
    /// Nil inventory is unknown. A literal `0` stays `0` here; it is not rewritten to a blank.
    public var capacityText: String { ClubEnrollmentCountText.display(capacity) }
}
public struct ClubEnrollmentRoster: Equatable {
    public let clubID: Int
    public let topicID: Int
    public let canRefund: Bool
    public let tickets: [ClubEnrollmentTicket]
    /// 已支付 counts registrants whose `paymentStatus` is 2. Anyone else is not paid.
    public var paidCount: Int { tickets.reduce(0) { $0 + $1.registrants.filter { $0.paymentStatus == 2 }.count } }
    /// Unknown payment/checkin fields cannot safely contribute a definite refundable count.
    public var refundableCount: Int? {
        let rows = tickets.flatMap(\.registrants)
        guard rows.allSatisfy({ $0.paymentStatus != nil && ($0.paymentStatus != 2 || $0.checkin != .unknown) }) else { return nil }
        return rows.filter { $0.paymentStatus == 2 && $0.checkin == .pending }.count
    }
    public var paidCountText: String { ClubEnrollmentCountText.display(paidCount) }
    public var refundableCountText: String { ClubEnrollmentCountText.display(refundableCount) }
    public var deadline: String? { tickets.compactMap(\.deadline).first }
    public var teamStatus: Int? {
        if tickets.contains(where: { $0.teamStatus == 1 }) { return 1 }
        if tickets.contains(where: { $0.teamStatus == 2 }) { return 2 }
        return !tickets.isEmpty && tickets.allSatisfy({ $0.teamStatus == 0 }) ? 0 : nil
    }
    /// MP C-13: per-session 实收 / 已退 / 实收减退款 in fen; only the owner receives it.
    public let sessionMoney: [ClubEnrollmentSessionMoney]
    public init(value: ClubGovernanceValue, scope: ClubGovernanceScope) throws {
        try scope.validate(); try ClubEnrollmentDecode.object(value)
        sessionMoney = ClubEnrollmentSessionMoney.rows(value["sessionMoney"])
        clubID = try ClubEnrollmentDecode.id(value["clubId"])
        topicID = try ClubEnrollmentDecode.id(value["topicId"])
        guard clubID == scope.clubID, topicID == scope.topicID else { throw ClubGovernanceFailure.targetChanged }
        guard let canRefund = value["canRefund"].bool else { throw ClubGovernanceFailure.malformed }
        self.canRefund = canRefund
        tickets = try ClubEnrollmentDecode.rows(value["omsTicketList"]).map(ClubEnrollmentTicket.init)
        try ClubEnrollmentDecode.unique(tickets.map(\.id))
        try ClubEnrollmentDecode.unique(tickets.flatMap(\.registrants).map(\.id))
    }
}
private enum ClubEnrollmentDecode {
    static func object(_ value: ClubGovernanceValue) throws { guard value.object != nil else { throw ClubGovernanceFailure.malformed } }
    static func id(_ value: ClubGovernanceValue) throws -> Int { guard let number = value.int, number > 0 else { throw ClubGovernanceFailure.malformed }; return number }
    static func count(_ value: ClubGovernanceValue) throws -> Int? {
        switch value {
        case .null:
            return nil
        case .string(let text):
            // Do not parse through ClubGovernanceValue.int. A numeric string, including "0",
            // and the token UNKNOWN stay unknown. They are never stored as 0.
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.compare("UNKNOWN", options: .caseInsensitive) == .orderedSame { return nil }
            if Int(trimmed) != nil || Double(trimmed) != nil { return nil }
            throw ClubGovernanceFailure.malformed
        case .integer(let number):
            guard number >= 0 else { throw ClubGovernanceFailure.malformed }
            return number
        default:
            throw ClubGovernanceFailure.malformed
        }
    }
    static func text(_ value: ClubGovernanceValue) throws -> String? {
        if value == .null { return nil }; guard let text = value.string else { throw ClubGovernanceFailure.malformed }
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
    }
    static func rows(_ value: ClubGovernanceValue) throws -> [ClubGovernanceValue] {
        guard let rows = value.array, rows.allSatisfy({ $0.object != nil }) else { throw ClubGovernanceFailure.malformed }; return rows
    }
    static func unique(_ ids: [Int]) throws { guard Set(ids).count == ids.count else { throw ClubGovernanceFailure.malformed } }
}

/// CLB-enroll-01: MP enroll `sessionMoneyRows` (C-13). The server sends integer fen and computes the net;
/// the client only formats ¥ and never adds or subtracts. Rows without an activity id are dropped.
public struct ClubEnrollmentSessionMoney: Equatable, Identifiable {
    public let id: Int
    public let label: String?
    public let cancelled: Bool
    public let paidText: String
    public let refundedText: String
    public let netText: String
    public static func rows(_ value: ClubGovernanceValue) -> [Self] {
        (value.array ?? []).compactMap { row in
            guard row.object != nil, let id = row["activityId"].int else { return nil }
            let label = row["label"].string?.trimmingCharacters(in: .whitespacesAndNewlines)
            return .init(id: id, label: (label?.isEmpty ?? true) ? nil : label, cancelled: row["cancelled"] == .bool(true),
                         paidText: yuanText(row["paidFen"]), refundedText: yuanText(row["refundedFen"]), netText: yuanText(row["netFen"]))
        }
    }
    /// MP `yuanText` + utils/money-format `decimalText`: ¥0.0, ¥10.0, ¥10.5, ¥10.55; unknown is "—".
    public static func yuanText(_ fen: ClubGovernanceValue) -> String {
        guard let raw = fen.number, raw.isFinite else { return "—" }
        let cents = Int(abs(raw).rounded())
        let sign = raw < 0 && cents > 0 ? "-" : ""
        if cents == 0 { return "¥0.0" }
        let body = cents % 10 == 0 ? String(format: "%.1f", Double(cents) / 100) : String(format: "%.2f", Double(cents) / 100)
        return sign + "¥" + body
    }
}
