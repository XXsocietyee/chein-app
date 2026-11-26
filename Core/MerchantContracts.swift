import Foundation

public struct MerchantDashboard: Decodable, Equatable {
    public let revenue: String?
    public let pendingOrders: Int
    public let revenue7d: [MerchantRevenuePoint]
    enum CodingKeys: String, CodingKey { case revenue, pendingOrders, revenue7d }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        revenue = try c.decodeIfPresent(String.self, forKey: .revenue)
        pendingOrders = try c.decodeIfPresent(Int.self, forKey: .pendingOrders) ?? 0
        revenue7d = try c.decodeIfPresent([MerchantRevenuePoint].self, forKey: .revenue7d) ?? []
    }
}

public struct MerchantRevenuePoint: Decodable, Equatable {
    public let date: String
    public let amount: String?
}

public struct MerchantTodo: Decodable, Equatable {
    public let pendingVerify: Int
    public let verifiedCount: Int
    public let pendingScanConfirm: Int
    public let pendingOrders: Int
    public let refundCount: Int
    /// Prediction rounds still awaiting the merchant's answer (mini-program todo-summary).
    /// Expired rounds are no longer reported, so the reminder disappears with zero.
    public let pendingPredict: Int
    public let biddingTopics: Int
    /// nil when the server omits `byProject`: per-project chips are then unknown, not "no todo".
    public let byProject: [MerchantProjectTodo]?
    enum CodingKeys: String, CodingKey { case pendingVerify, verifiedCount, pendingScanConfirm, pendingOrders, refundCount, pendingPredict, biddingTopics, byProject }
    public init(aftercareRefundCount: Int) {
        pendingVerify = 0
        verifiedCount = 0
        pendingScanConfirm = 0
        pendingOrders = 0
        refundCount = max(0, aftercareRefundCount)
        pendingPredict = 0
        biddingTopics = 0
        byProject = nil
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pendingVerify = try c.decodeIfPresent(Int.self, forKey: .pendingVerify) ?? 0
        verifiedCount = try c.decodeIfPresent(Int.self, forKey: .verifiedCount) ?? 0
        pendingScanConfirm = try c.decodeIfPresent(Int.self, forKey: .pendingScanConfirm) ?? 0
        pendingOrders = try c.decodeIfPresent(Int.self, forKey: .pendingOrders) ?? 0
        refundCount = try c.decodeIfPresent(Int.self, forKey: .refundCount) ?? 0
        // Negative or non-integer counts never become a visible reminder.
        pendingPredict = max(0, (try? c.decodeIfPresent(Int.self, forKey: .pendingPredict)) ?? 0)
        biddingTopics = max(0, (try? c.decodeIfPresent(Int.self, forKey: .biddingTopics)) ?? 0)
        byProject = (try? c.decodeIfPresent([MerchantProjectTodo].self, forKey: .byProject)) ?? nil
    }
    /// Non-owner aftercare readers receive only the aftercare refund count; order, verification,
    /// prediction, bidding, and per-project fields stay owner-only.
    public func scoped(for access: MerchantAccess) -> MerchantTodo {
        access.isOwner ? self : Self(aftercareRefundCount: access.canReadAftercare ? refundCount : 0)
    }
    /// Completed verifications are not pending work.
    public var hasPendingWork: Bool { pendingVerify > 0 || pendingScanConfirm > 0 || pendingOrders > 0 || refundCount > 0 }
}

public struct MerchantProjectTodo: Decodable, Equatable {
    /// Source strings are preserved; "01" is not the canonical owner ID "1".
    public let ownerType: String
    public let ownerID: String
    public let pendingVerify: Int
    public let pendingScanConfirm: Int
    enum CodingKeys: String, CodingKey { case ownerType, ownerId, pendingVerify, pendingScanConfirm }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func scalar(_ key: CodingKeys) throws -> String {
            if let value = try? c.decode(String.self, forKey: key) { return value }
            if let value = try? c.decode(Int.self, forKey: key) { return String(value) }
            throw DecodingError.dataCorruptedError(forKey: key, in: c, debugDescription: "Missing project owner")
        }
        ownerType = try scalar(.ownerType); ownerID = try scalar(.ownerId)
        pendingVerify = max(0, (try? c.decodeIfPresent(Int.self, forKey: .pendingVerify)) ?? 0)
        pendingScanConfirm = max(0, (try? c.decodeIfPresent(Int.self, forKey: .pendingScanConfirm)) ?? 0)
    }
}

public struct MerchantEvent: Decodable, Equatable {
    public let content: String
    /// Already rendered by server as MM-dd HH:mm; never reinterpret as a Date.
    public let time: String
    /// Optional ownership metadata for the recent-project activity destination.
    /// Preserve source strings: "01" is not the canonical owner ID "1".
    public let projectOwnerType: String?
    public let projectOwnerID: String?
    /// Source 我的消息 fields: `label` (收入到账 / 核销 / …), `type` (income / verify / stationInvite) and, for a
    /// pending station invite, `gameActivityId`. Absent stays nil; never invented.
    public let label: String?
    public let type: String?
    public let gameActivityID: Int?
    public init(content: String, time: String, projectOwnerType: String? = nil, projectOwnerID: String? = nil,
                label: String? = nil, type: String? = nil, gameActivityID: Int? = nil) {
        self.content = content; self.time = time
        self.projectOwnerType = projectOwnerType; self.projectOwnerID = projectOwnerID
        self.label = label; self.type = type; self.gameActivityID = gameActivityID
    }
    private enum CodingKeys: String, CodingKey { case content, time, ownerType, ownerId, label, type, gameActivityId }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        content = try c.decode(String.self, forKey: .content)
        time = try c.decode(String.self, forKey: .time)
        func scalar(_ key: CodingKeys) -> String? {
            if let value = try? c.decode(String.self, forKey: key) { return value }
            if let value = try? c.decode(Int.self, forKey: key) { return String(value) }
            return nil
        }
        projectOwnerType = scalar(.ownerType); projectOwnerID = scalar(.ownerId)
        label = try? c.decodeIfPresent(String.self, forKey: .label)
        type = try? c.decodeIfPresent(String.self, forKey: .type)
        gameActivityID = scalar(.gameActivityId).flatMap { Int($0) }
    }
}

public enum MerchantOrderStatus: Int, CaseIterable {
    case awaitingPayment = 0, awaitingShipment, shipped, awaitingReview, completed, closed, invalid
    public var titleKey: String { "merchant.order.status.\(rawValue)" }
}
public enum MerchantAftersaleStatus: Int, CaseIterable {
    case none = 1, processing, refunding, refunded
    public var titleKey: String { "merchant.order.aftersale.\(rawValue)" }
}
public struct MerchantOrderFilter: Equatable {
    public var status: MerchantOrderStatus?
    public var aftersaleStatus: MerchantAftersaleStatus?
    public init(status: MerchantOrderStatus? = nil, aftersaleStatus: MerchantAftersaleStatus? = nil) {
        self.status = status; self.aftersaleStatus = aftersaleStatus
    }
}

public struct MerchantOrder: Decodable, Equatable {
    public let id: Int?
    public let orderSn: String?
    public let status: Int?
    public let aftersaleStatus: Int?
    public let createTime: String?
    public let payAmount: String?
    enum CodingKeys: String, CodingKey { case id, orderSn, status, aftersaleStatus, createTime, payAmount }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.merchantInteger(.id)
        orderSn = try c.decodeIfPresent(String.self, forKey: .orderSn)
        status = try c.decodeIfPresent(Int.self, forKey: .status)
        aftersaleStatus = try c.decodeIfPresent(Int.self, forKey: .aftersaleStatus)
        createTime = try c.decodeIfPresent(String.self, forKey: .createTime)
        if let text = try? c.decode(String.self, forKey: .payAmount) { payAmount = text }
        else if let number = try? c.decode(Decimal.self, forKey: .payAmount) { payAmount = NSDecimalNumber(decimal: number).stringValue }
        else { payAmount = nil }
    }
}

/// Snapshot from project/my, not an invented project detail response.
public struct MerchantProject: Decodable, Equatable, Identifiable {
    public var id: String { "\(bizType):\(projectID)" }
    public let projectID: Int
    public let bizType: String
    public let title: String
    public let state: String?
    public let ownerType: String?
    public let addressName: String?
    public let pendingVerifyCount: Int?
    public let projectTypeText: String?
    public let stateText: String?
    public let acceptStatusText: String?
    public let startTime: String?
    public let endTime: String?
    public let signupCount: Int
    public let viewCount: Int
    /// Cover from `imgUrl` (host) or `topicImgUrl` (join). Nil keeps the logo mark.
    public let thumb: String?
    /// Join cards match upcoming-runs on this topic. Host cards leave it nil.
    public let visitTopicID: Int?
    public let isJoinCard: Bool
    enum CodingKeys: String, CodingKey {
        case id, bizType, title, projectTypeText, stateText, acceptStatusText, startTime, endTime, signupCount, viewCount
        case state, ownerType, addressName, pendingVerifyCount
        case imgUrl, topicImgUrl, role, topicId
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = c.merchantInteger(.id), id > 0 else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Invalid project ID")
        }
        projectID = id
        bizType = try c.decode(String.self, forKey: .bizType)
        state = try c.decodeIfPresent(String.self, forKey: .state)
        ownerType = try c.decodeIfPresent(String.self, forKey: .ownerType)
        addressName = try c.decodeIfPresent(String.self, forKey: .addressName)
        pendingVerifyCount = try c.decodeIfPresent(Int.self, forKey: .pendingVerifyCount)
        if let pendingVerifyCount, pendingVerifyCount < 0 {
            throw DecodingError.dataCorruptedError(forKey: .pendingVerifyCount, in: c, debugDescription: "Invalid pending verification count")
        }
        title = try c.decodeIfPresent(String.self, forKey: .title)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        projectTypeText = try c.decodeIfPresent(String.self, forKey: .projectTypeText)
        stateText = try c.decodeIfPresent(String.self, forKey: .stateText)
        acceptStatusText = try c.decodeIfPresent(String.self, forKey: .acceptStatusText)
        startTime = try c.decodeIfPresent(String.self, forKey: .startTime)
        endTime = try c.decodeIfPresent(String.self, forKey: .endTime)
        signupCount = try c.decodeIfPresent(Int.self, forKey: .signupCount) ?? 0
        viewCount = try c.decodeIfPresent(Int.self, forKey: .viewCount) ?? 0
        let hostImage = Self.firstImage(try c.decodeIfPresent(String.self, forKey: .imgUrl))
        let joinImage = Self.firstImage(try c.decodeIfPresent(String.self, forKey: .topicImgUrl))
        let role = try c.decodeIfPresent(String.self, forKey: .role)
        let topic = c.merchantInteger(.topicId)
        isJoinCard = role == "join" || bizType == "join" || bizType == "registration" || ownerType == "join"
            || (joinImage != nil && hostImage == nil)
        thumb = isJoinCard ? (joinImage ?? hostImage) : (hostImage ?? joinImage)
        visitTopicID = isJoinCard ? (topic ?? projectID) : topic
    }
    private static func firstImage(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let piece = raw.split(separator: ",").lazy.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
        guard let piece, piece.hasPrefix("https://") || piece.hasPrefix("http://") else { return nil }
        return piece
    }
}

/// One row of POST `api/merchant/upcoming-runs` (pages/merchant/index/index.js). Visit text follows utils/merchant-workbench.js.
public struct MerchantUpcomingRun: Decodable, Equatable {
    public let topicID: Int
    public let clubName: String
    public let paidCount: Int
    public let arrivalStart: String?
    public let startTime: String?
    enum CodingKeys: String, CodingKey { case topicId, clubName, paidCount, arrivalStart, startTime }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let topic = c.merchantInteger(.topicId), topic > 0 else {
            throw DecodingError.dataCorruptedError(forKey: .topicId, in: c, debugDescription: "Invalid topic")
        }
        topicID = topic
        clubName = try c.decodeIfPresent(String.self, forKey: .clubName)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let count = c.merchantInteger(.paidCount) { paidCount = count }
        else if let text = try c.decodeIfPresent(String.self, forKey: .paidCount), let count = Int(text) { paidCount = count }
        else { paidCount = 0 }
        arrivalStart = try c.decodeIfPresent(String.self, forKey: .arrivalStart)
        startTime = try c.decodeIfPresent(String.self, forKey: .startTime)
    }
}

public enum MerchantUpcomingVisit {
    /// Join cards only. First run per topic with a club name and paidCount > 0.
    public static func line(runs: [MerchantUpcomingRun], topicID: Int, roleJoin: Bool, now: Date = Date()) -> String? {
        guard roleJoin else { return nil }
        guard let run = runs.first(where: { $0.topicID == topicID && !$0.clubName.isEmpty && $0.paidCount > 0 }) else { return nil }
        return text(run, now: now)
    }
    private static func text(_ run: MerchantUpcomingRun, now: Date) -> String? {
        guard let instant = chinaInstant(run.arrivalStart ?? run.startTime) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .gmt
        let parts = calendar.dateComponents([.month, .day, .hour, .minute, .weekday], from: instant)
        guard let month = parts.month, let day = parts.day, let hour = parts.hour, let minute = parts.minute, let weekday = parts.weekday else { return nil }
        let clock = String(format: "%02d:%02d", hour, minute)
        let todayKey = calendar.dateComponents([.year, .month, .day], from: now)
        let runKey = calendar.dateComponents([.year, .month, .day], from: instant)
        if todayKey == runKey { return "今天 \(clock) · \(run.paidCount) 人已报名" }
        let names = ["日", "一", "二", "三", "四", "五", "六"]
        let week = names[(weekday - 1) % 7]
        return "\(run.clubName) · \(month)月\(day)日 周\(week) \(clock) 到店"
    }
    /// Bare `YYYY-MM-DD HH:mm[:ss]` is China time. Offset ISO keeps its own zone.
    private static func chinaInstant(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if value.hasSuffix("Z") || value.range(of: #"[+-]\d\d:?\d\d$"#, options: .regularExpression) != nil {
            let parser = ISO8601DateFormatter()
            parser.formatOptions = [.withInternetDateTime]
            return parser.date(from: value.replacingOccurrences(of: " ", with: "T"))
        }
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "Asia/Shanghai")
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"] {
            parser.dateFormat = format
            if let date = parser.date(from: value) { return date }
        }
        return nil
    }
}

public struct MerchantProjectPage: Decodable, Equatable {
    public let rows: [MerchantProject]
    public let total: Int
    enum CodingKeys: String, CodingKey { case rows, total }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rows = try c.decode([MerchantProject].self, forKey: .rows)
        let reported = c.merchantInteger(.total)
        total = reported.flatMap { $0 >= 0 ? $0 : nil } ?? rows.count
    }
    public var hasUnloadedRows: Bool { total > rows.count }
}

/// Flutter merchant_money.dart explicitly identifies this domain as CNY.
/// Decimal normalization avoids a binary floating-point roundtrip. Absence is not zero.
public enum MerchantMoney {
    public static func display(_ raw: String?) -> String {
        guard let raw else { return "—" }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.range(of: #"^[+-]?[0-9]+(?:\.[0-9]+)?$"#, options: .regularExpression) != nil,
              var amount = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")), !amount.isNaN else { return "—" }
        var rounded = Decimal()
        NSDecimalRound(&rounded, &amount, 2, .plain)
        var result = NSDecimalNumber(decimal: rounded).stringValue
        if !result.contains(".") { result += ".00" }
        else if result.split(separator: ".", omittingEmptySubsequences: false).last?.count == 1 { result += "0" }
        return "¥" + result
    }
}
