import Foundation

public enum TicketWalletLane: Int, CaseIterable { case route = 1, activity = 2 }
public enum TicketWalletStatus: String { case ready, pending, verified, cancelled, expired, unknown }
public enum TicketWalletAction: String { case detail, paymentUnavailable, cancelled, expired, unknown }
public enum TicketWalletRedemption: String { case notImplemented, unpaid, cancelled, expired, complete, unknown }

/// Server `topicCompleted` on a `POST /api/registration/list` row. Read only.
/// A missing key or JSON null hides the completed state. Only a JSON boolean is a filter bucket.
/// Any other present value is unknown and stays an em dash; it never drops the ticket.
public enum TicketWalletTopicCompletion: Equatable {
    case absent
    case upcoming
    case completed
    case unknown
}

/// Narrow read projection of MyRegistration / RegistrationDetail. No code or payment credentials.
public struct TicketWalletTicket: Decodable, Equatable, Identifiable {
    public let id: Int
    public let ownerType: Int?
    public let ownerID: Int?
    public let activityID: Int?
    public let topicID: Int?
    /// `cmsTopic.id` when the list row includes the topic object. Focus prefers this over `ownerId`.
    public let cmsTopicID: Int?
    public let registrationNumber: String?
    public let registrationStatus: Int?
    public let verificationStatus: Int?
    public let title: String?
    public let participateDate: String?
    public let productType: Int?
    public let startDate: String?
    public let endDate: String?
    public let addressName: String?
    public let payableAmount: Decimal?
    public let realName: String?
    /// Source detail supplies masked phone text. It is never sent elsewhere or logged.
    public let phone: String?
    public let purchaseKind: String?
    public let entitlements: [TicketWalletEntitlement]
    public let verificationTime: String?
    /// Decoded from the same list (and detail) object. Never synthesized.
    public let topicCompletion: TicketWalletTopicCompletion
    /// Source `paymentStatus` (2 = paid). Nil on older responses that do not carry it.
    public let paymentStatus: Int?
    /// Source `usableState` (`UPCOMING` / `USABLE` / `EXPIRED`). Nil on older responses.
    public let usableState: String?
    /// Source `usableFrom` / `usableUntil`, `yyyy-MM-dd HH:mm:ss` Beijing time. Text only, never parsed into a status.
    public let usableFrom: String?
    public let usableUntil: String?
    /// Source `clearState` (`CLEARED` / `NOT_CLEARED`). Nil falls back to `topicCompleted`.
    public let clearState: String?
    /// Source `refundApplication` facts that decide 退款中 / refunded. No amounts are shown from it.
    public let refund: TicketWalletRefund?
    /// Source `manualRefundCaseStatus`: any value means a manual after-sale case is open (退款中).
    public let hasManualRefundCase: Bool
    /// `cmsActivity.imgUrl`, else `cmsTopic.imgUrl`. Nil when neither object carries one.
    public let coverURL: String?

    /// `true` / `false` are the 已通关 / 即将开始 buckets. Absent and unknown stay nil (全部 only).
    public var topicCompletedFlag: Bool? {
        switch topicCompletion {
        case .completed: return true
        case .upcoming: return false
        case .absent, .unknown: return nil
        }
    }

    public var status: TicketWalletStatus {
        // Source wxs precedence: verification takes precedence even for a cancelled row.
        if verificationStatus == 1 { return .verified }
        if registrationStatus == 3 { return .cancelled }
        if registrationStatus == 4 { return .expired }
        if registrationStatus == 2 { return .ready }
        if registrationStatus == 1 { return .pending }
        return .unknown
    }
    /// Opening behavior uses registrationStatus, independently of the displayed verification state.
    public var action: TicketWalletAction {
        switch registrationStatus {
        case 1: return .paymentUnavailable
        case 2: return .detail
        case 3: return .cancelled
        case 4: return .expired
        default: return .unknown
        }
    }
    public var pendingCount: Int { entitlements.filter { $0.status == 0 }.count }
    public var hasUnknownEntitlementStatus: Bool { entitlements.contains { ![0, 1, 2].contains($0.status ?? -1) } }
    /// Read-only explanation of the Flutter detail gate. Never authorizes code issuance.
    public var redemption: TicketWalletRedemption {
        switch registrationStatus {
        case 1: return .unpaid
        case 3: return .cancelled
        case 4: return .expired
        case 2:
            if entitlements.isEmpty { return verificationStatus == 1 ? .complete : .notImplemented }
            if pendingCount > 0 { return .notImplemented }
            return hasUnknownEntitlementStatus ? .unknown : .complete
        default: return .unknown
        }
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: TicketWalletKey.self)
        id = try c.requiredID("id")
        ownerType = try c.integer("ownerType"); ownerID = try c.integer("ownerId")
        activityID = try c.integer("activityId"); topicID = try c.integer("topicId")
        registrationNumber = try c.text("registrationNo")
        registrationStatus = try c.integer("registrationStatus")
        verificationStatus = try c.integer("verificationStatus")
        let activity = try c.decodeIfPresent(TicketWalletOwner.self, forKey: TicketWalletKey("cmsActivity"))
        let topic = try c.decodeIfPresent(TicketWalletOwner.self, forKey: TicketWalletKey("cmsTopic"))
        cmsTopicID = topic?.id
        let owner = activity ?? topic
        title = owner?.name; productType = owner?.productType
        startDate = owner?.startDate; endDate = owner?.endDate; addressName = owner?.addressName
        participateDate = try c.text("participateDate")
        payableAmount = try c.decodeIfPresent(Decimal.self, forKey: TicketWalletKey("payableAmount"))
        realName = try c.text("realName"); phone = try c.text("phone")
        if let raw = try? c.decode(Int.self, forKey: TicketWalletKey("purchaseKind")) {
            purchaseKind = [1: "GUIDED_TICKET", 2: "SELF_PASS", 3: "EXPLORE_PASS"][raw]
        } else { purchaseKind = try c.text("purchaseKind") }
        entitlements = try c.decodeIfPresent([TicketWalletEntitlement].self, forKey: TicketWalletKey("entitlements")) ?? []
        verificationTime = try c.text("verificationTime")
        topicCompletion = ticketWalletTopicCompletion(c)
        paymentStatus = try? c.integer("paymentStatus")
        usableState = (try? c.text("usableState")) ?? nil
        usableFrom = (try? c.text("usableFrom")) ?? nil
        usableUntil = (try? c.text("usableUntil")) ?? nil
        clearState = (try? c.text("clearState")) ?? nil
        refund = try? c.decodeIfPresent(TicketWalletRefund.self, forKey: TicketWalletKey("refundApplication"))
        let manual = TicketWalletKey("manualRefundCaseStatus")
        hasManualRefundCase = c.contains(manual) && (try? c.decodeNil(forKey: manual)) == false
        coverURL = activity?.imgUrl ?? topic?.imgUrl
    }
}

/// Source `refundApplication`. Unknown numbers stay nil; nothing here is a money write.
public struct TicketWalletRefund: Decodable, Equatable {
    public let status: Int?
    public let payoutStatus: Int?
    public let refundAmount: Decimal?
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: TicketWalletKey.self)
        status = try? c.integer("status"); payoutStatus = try? c.integer("payoutStatus")
        refundAmount = try? c.decodeIfPresent(Decimal.self, forKey: TicketWalletKey("refundAmount"))
    }
}

/// Mini-program 票夹 rule F13 (`subpackageMember/signup/index.js` usableTicket / walletOrder / refundingTicket):
/// the wallet holds only tickets the player can use. Unpaid, cancelled, expired and refunded tickets live in 我的订单.
public extension TicketWalletTicket {
    /// Money already returned (payout 1 / 4): the ticket leaves the wallet.
    var isRefunded: Bool { refund.map { $0.payoutStatus == 1 || $0.payoutStatus == 4 } ?? false }
    /// A refund in flight (review, paying out, manual case). The card stays and reads 退款中; it is locked.
    var isRefunding: Bool {
        if hasManualRefundCase { return true }
        guard let refund, !isRefunded else { return false }
        if refund.status == 2 { return false } // rejected: the ticket stays usable
        if let amount = refund.refundAmount, !(amount > 0) { return false }
        return true
    }
    /// `usableState == UPCOMING`: shown last, locked, tagged「M月D日开始」.
    var isUpcoming: Bool { usableState == "UPCOMING" }
    /// MP `usableTicket`. A response without `paymentStatus` (older server) is not dropped on that fact alone.
    var isWalletUsable: Bool {
        guard registrationStatus == 2, paymentStatus == nil || paymentStatus == 2, !isRefunded else { return false }
        if let usableState, !usableState.isEmpty { return usableState != "EXPIRED" }
        guard let until = TicketWalletTicket.sourceDate(usableUntil ?? endDate) else { return true }
        return until >= Date()
    }
    /// 已通关 / 未通关 from `clearState`, else the older `topicCompleted` (true only).
    var clearedFlag: Bool? {
        switch clearState {
        case "CLEARED"?: return true
        case "NOT_CLEARED"?: return false
        default: return clearState == nil && topicCompletion == .completed ? true : nil
        }
    }
    /// MP `startTag`:「M月D日开始」from `usableFrom`; nil when the date is unreadable (the caller shows 即将开始).
    var upcomingStartMonthDay: (month: Int, day: Int)? {
        guard let text = usableFrom, text.count >= 10 else { return nil }
        let parts = text.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return nil }
        return (parts[1], parts[2])
    }
    /// MP `walletOrder`: usable first by `usableUntil` ascending (no date last), upcoming after by `usableFrom`.
    /// Stable for equal keys.
    static func walletOrder(_ tickets: [TicketWalletTicket]) -> [TicketWalletTicket] {
        func key(_ t: TicketWalletTicket) -> Date { sourceDate(t.isUpcoming ? t.usableFrom : (t.usableUntil ?? t.endDate)) ?? .distantFuture }
        return tickets.enumerated().sorted { a, b in
            let ua = a.element.isUpcoming ? 1 : 0, ub = b.element.isUpcoming ? 1 : 0
            if ua != ub { return ua < ub }
            let ka = key(a.element), kb = key(b.element)
            return ka != kb ? ka < kb : a.offset < b.offset
        }.map(\.element)
    }
    /// Server `yyyy-MM-dd[ HH:mm[:ss]]`, Beijing time.
    static func sourceDate(_ text: String?) -> Date? {
        guard let text = text?.trimmingCharacters(in: .whitespaces), text.count >= 10 else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "Asia/Shanghai")
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd"] {
            f.dateFormat = format
            if let d = f.date(from: text) { return format == "yyyy-MM-dd" ? d.addingTimeInterval(86_399) : d }
        }
        return nil
    }
}

public extension TicketWalletSnapshot {
    /// The wallet view of a read: usable tickets only, in MP `walletOrder`. The lane failure is kept.
    var walletUsable: TicketWalletSnapshot {
        TicketWalletSnapshot(tickets: TicketWalletTicket.walletOrder(tickets.filter(\.isWalletUsable)), partialFailure: partialFailure)
    }
}

/// Missing or null hides completion. A non-boolean does not fail the row.
private func ticketWalletTopicCompletion(_ c: KeyedDecodingContainer<TicketWalletKey>) -> TicketWalletTopicCompletion {
    let key = TicketWalletKey("topicCompleted")
    guard c.contains(key) else { return .absent }
    if (try? c.decodeNil(forKey: key)) == true { return .absent }
    guard let value = try? c.decode(Bool.self, forKey: key) else { return .unknown }
    return value ? .completed : .upcoming
}

public struct TicketWalletEntitlement: Decodable, Equatable, Identifiable {
    public let id: Int
    /// Missing status stays unknown rather than becoming an unredeemed benefit.
    public let status: Int?
    public let chapterID: Int?
    public let chapterName: String?
    public let statusLabel: String?
    public let invalidReason: String?
    public let redeemedAt: String?
    /// FE-G5 perk terms from the entitlement snapshot. Each is optional; absent or
    /// malformed values stay nil and nothing is shown.
    public let included: Bool?
    public let extraSpendText: String?
    public let reserveRequired: Bool?
    /// FE-G6: an empty server label is no label; the row falls back to the local status name.
    public var displayStatusLabel: String? {
        guard let statusLabel, !statusLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return statusLabel
    }
    public var statusKey: String {
        switch status { case 0: return "pending"; case 1: return "redeemed"; case 2: return "invalid"; default: return "unknown" }
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: TicketWalletKey.self)
        id = try c.requiredID("id"); status = try c.integer("status")
        chapterID = try c.integer("chapterId"); chapterName = try c.text("chapterName")
        statusLabel = try c.text("statusLabel"); invalidReason = try c.text("invalidReason")
        redeemedAt = try c.text("redeemedAt")
        included = (try? c.decodeIfPresent(Bool.self, forKey: TicketWalletKey("included"))) ?? nil
        extraSpendText = (try? c.decodeIfPresent(String.self, forKey: TicketWalletKey("extraSpendText"))) ?? nil
        reserveRequired = (try? c.decodeIfPresent(Bool.self, forKey: TicketWalletKey("reserveRequired"))) ?? nil
    }
}

public enum TicketWalletReadFailure: Error, Equatable {
    case unavailable
    /// Nil message has fallback provenance; explicit backend prose is never treated as a key.
    case rejected(code: Int, message: String?)
}
public enum TicketWalletIssue: Equatable {
    case login, notConfigured, unavailable, malformed, network, failure
    case server(String)
    public init(_ error: Error) {
        if let failure = error as? TicketWalletReadFailure {
            switch failure {
            case .unavailable: self = .unavailable
            case .rejected(_, let message): self = message.map(Self.server) ?? .failure
            }
        } else if let api = error as? APIError {
            switch api {
            case .unauthorized: self = .login
            case .notConfigured: self = .notConfigured
            case .malformedResponse, .invalidRequest: self = .malformed
            default: self = .failure
            }
        } else if error is URLError { self = .network }
        else { self = .failure }
    }
    public var localizationKey: String {
        switch self {
        case .login: return "ticketWallet.issue.login"
        case .notConfigured: return "ticketWallet.issue.notConfigured"
        case .unavailable: return "ticketWallet.issue.unavailable"
        case .malformed: return "ticketWallet.issue.malformed"
        case .network: return "ticketWallet.issue.network"
        case .failure, .server: return "ticketWallet.issue.failure"
        }
    }
}
public struct TicketWalletLaneFailure: Equatable {
    public let lane: TicketWalletLane
    public let issue: TicketWalletIssue
    public init(lane: TicketWalletLane, issue: TicketWalletIssue) { self.lane = lane; self.issue = issue }
}
public struct TicketWalletSnapshot: Equatable {
    public let tickets: [TicketWalletTicket]
    public let partialFailure: TicketWalletLaneFailure?
    public init(tickets: [TicketWalletTicket], partialFailure: TicketWalletLaneFailure? = nil) {
        self.tickets = tickets; self.partialFailure = partialFailure
    }
}

/// Where a topic page should land in the wallet. Topic tickets only (`ownerType` 1).
/// The id is `cmsTopic.id`, then `ownerId`. A missing id does not match ticket 0.
public enum TicketWalletTopicFocus {
    public static func index(in tickets: [TicketWalletTicket], topicID: Int) -> Int? {
        guard topicID > 0 else { return nil }
        return tickets.firstIndex { ticket in
            guard ticket.ownerType == 1 else { return false }
            let focused = (ticket.cmsTopicID ?? 0) > 0 ? ticket.cmsTopicID : ticket.ownerID
            return focused == topicID
        }
    }
}

private struct TicketWalletOwner: Decodable {
    let id: Int?
    let name: String?
    let productType: Int?
    let startDate: String?
    let endDate: String?
    let addressName: String?
    let imgUrl: String?
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: TicketWalletKey.self)
        id = try c.integer("id")
        name = try c.text("name"); productType = try c.integer("productType")
        startDate = try c.text("startDate"); endDate = try c.text("endDate"); addressName = try c.text("addressName")
        imgUrl = try c.text("imgUrl")
    }
}
private struct TicketWalletKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(_ value: String) { stringValue = value }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}
private extension KeyedDecodingContainer where Key == TicketWalletKey {
    func text(_ key: String) throws -> String? { try decodeIfPresent(String.self, forKey: TicketWalletKey(key)) }
    func integer(_ key: String) throws -> Int? {
        let k = TicketWalletKey(key)
        guard contains(k), try !decodeNil(forKey: k) else { return nil }
        if let value = try? decode(Int.self, forKey: k) { return value }
        if let value = try? decode(String.self, forKey: k), let number = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) { return number }
        throw APIError.malformedResponse
    }
    func requiredID(_ key: String) throws -> Int {
        guard let value = try integer(key), value > 0 else { throw APIError.malformedResponse }
        return value
    }
}
