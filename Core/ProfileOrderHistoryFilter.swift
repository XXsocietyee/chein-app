import Foundation

/// Supplemental read-only facts for P120 classification. Existing ProfileOrder fields,
/// requests and all payment/refund eligibility remain unchanged.
public struct ProfileOrderHistoryFacts: Decodable, Equatable {
    public let totalAmountIsZero: Bool
    public let hasRefundApplication: Bool
    public let firstSuccessfulScanAt: String?
    public let start: String?
    public let end: String?
    /// Gap #28 (MP `utils/order-status.js`): `cmsActivity.cancelTime` (主办取消), `topicCompleted` (P-22 通关),
    /// `exploreProgress` (P-03 探索票) and `serverNow` (U-033 server clock, epoch ms).
    public let activityCancelTime: String?
    public let topicCompleted: Bool
    public let exploreProgress: ProfileOrderExploreProgress?
    public let serverNow: Date?
    private enum CodingKeys: String, CodingKey {
        case totalAmount, refundApplication, firstSuccessfulScanAt, cmsActivity, cmsTopic, topicCompleted, exploreProgress, serverNow
    }
    private struct Owner: Decodable {
        let startDate: String?
        let startTime: String?
        let endDate: String?
        let endTime: String?
    }
    private struct Cancel: Decodable {
        let cancelTime: String?
        private enum CodingKeys: String, CodingKey { case cancelTime }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            if let text = try? c.decode(String.self, forKey: .cancelTime) { cancelTime = text }
            else if let number = try? c.decode(Int64.self, forKey: .cancelTime) { cancelTime = String(number) }
            else { cancelTime = nil }
        }
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let number = try? c.decode(Decimal.self, forKey: .totalAmount) {
            totalAmountIsZero = !number.isNaN && number == .zero
        } else if let text = try? c.decode(String.self, forKey: .totalAmount) {
            // Only an explicit complete zero literal. Decimal(string:) accepts numeric
            // prefixes, so never classify "0invalid" as a free order.
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            totalAmountIsZero = trimmed.range(of: #"^[+-]?(?:0+(?:\.0*)?|\.0+)(?:[eE][+-]?[0-9]+)?$"#,
                                             options: .regularExpression) != nil
        } else { totalAmountIsZero = false }
        hasRefundApplication = c.contains(.refundApplication) && (try? c.decodeNil(forKey: .refundApplication)) == false
        if let text = try? c.decode(String.self, forKey: .firstSuccessfulScanAt) {
            firstSuccessfulScanAt = text
        } else if (try? c.decode(Int.self, forKey: .firstSuccessfulScanAt)) == 0 {
            firstSuccessfulScanAt = "0"
        } else {
            firstSuccessfulScanAt = nil
        }
        let owner = (try? c.decode(Owner.self, forKey: .cmsActivity)) ?? (try? c.decode(Owner.self, forKey: .cmsTopic))
        func present(_ text: String?) -> String? { text?.isEmpty == false ? text : nil }
        start = present(owner?.startDate) ?? present(owner?.startTime)
        end = present(owner?.endDate) ?? present(owner?.endTime) ?? start
        activityCancelTime = present((try? c.decode(Cancel.self, forKey: .cmsActivity))?.cancelTime)
        topicCompleted = (try? c.decode(Bool.self, forKey: .topicCompleted)) == true
        exploreProgress = (try? c.decode(ProfileOrderExploreProgress.self, forKey: .exploreProgress)).flatMap { $0.required > 0 ? $0 : nil }
        if let millis = try? c.decode(Double.self, forKey: .serverNow), millis.isFinite, millis > 0 {
            serverNow = Date(timeIntervalSince1970: millis / 1000)
        } else { serverNow = nil }
    }
}

/// `exploreProgressOf` in order-status.js: only a positive `required` counts.
public struct ProfileOrderExploreProgress: Decodable, Equatable {
    public let redeemed: Int
    public let required: Int
    public let active: Bool
    private enum CodingKeys: String, CodingKey { case redeemed, required, active }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        redeemed = (try? c.decode(Int.self, forKey: .redeemed)) ?? 0
        required = (try? c.decode(Int.self, forKey: .required)) ?? 0
        active = (try? c.decode(Bool.self, forKey: .active)) == true
    }
}

/// order-status.js `endOf`: a date-only end (yyyy-MM-dd) covers the whole day, so it ends at 23:59:59.999.
public enum ProfileOrderHistoryClock {
    public static func end(_ raw: String?) -> Date? {
        guard let raw, let date = OrderLifecycleTime.date(raw) else { return nil }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.range(of: #"^\d{4}-\d{1,2}-\d{1,2}$"#, options: .regularExpression) != nil else { return date }
        return date.addingTimeInterval(86_399.999)
    }
}

/// Local Mini order-status.js projection only. Never use this classification to permit
/// payment, cancellation, refunds, verification, access or receipt acknowledgement.
public extension ProfileOrder {
    /// Gap #28: `summarizeOrderState` rule by rule, in the MP order. `now` is the device clock; the read's `serverNow`
    /// wins when present (U-033), so a phone with a wrong clock does not move the tag.
    func historyState(now: Date = Date()) -> OrderLifecycleState {
        let current = historyFacts.serverNow ?? now
        // 1. Money already returned (payout 1 / 4) is terminal; a manual case cannot cover it.
        let refund = historyRefundState
        if refund == .refunded { return .refunded }
        // 2. 人工售后.
        if manualRefundCaseStatus?.isEmpty == false { return .manualRefund }
        // 3. Any other live refund application (zero amount and rejected fall through).
        if let refund { return refund }
        // 4. 主办取消 is an activity fact (活动已取消).
        if let cancel = OrderLifecycleTime.date(historyFacts.activityCancelTime), cancel.timeIntervalSince1970 > 0 { return .cancelled }
        // 5. Registration status.
        switch registrationStatus {
        case 1: return .pendingPayment
        case 3: return .cancelled
        case 4: return .expired
        case 2: break
        default: return .unknown
        }
        let start = OrderLifecycleTime.date(historyFacts.start)
        // 6. P-03: an active explore ticket is in progress (未开始 before the start), whatever was redeemed.
        if let explore = historyFacts.exploreProgress, explore.active {
            if let start, current < start { return .notStarted }
            return .inProgress
        }
        // 7. Verified.
        if verificationStatus == 1 { return .completed }
        // 8. P-22: city orienteering cleared (server `topicCompleted`).
        if historyFacts.topicCompleted { return .completed }
        // 9. A paid first scan completes a ticket; for a self-play pass it only starts the run.
        let pass = isSelfPlayPass
        let scanned = OrderLifecycleTime.date(historyFacts.firstSuccessfulScanAt) != nil
        if paymentStatus == 2, scanned, !pass { return .completed }
        // 10. 不可退款 (never for a pass or a free order).
        let free = historyFacts.totalAmountIsZero && payableAmount == .zero
            && (pointPaymentAmount == nil || pointPaymentAmount == .zero)
            && (wechatPaymentAmount == nil || wechatPaymentAmount == .zero)
        if !pass && !free && refundable == false { return .nonRefundable }
        // 11. Ended: a pass by its `expiresAt`, anything else by the (whole-day) end, else the start.
        let end = pass ? OrderLifecycleTime.date(expiresAt) : ProfileOrderHistoryClock.end(historyFacts.end)
        if let end, current > end { return .completed }
        // 12. Not started.
        if let start, current < start { return .notStarted }
        // 13. A paid pass never scanned is usable (可使用), not in progress.
        if pass, !scanned { return .notStarted }
        return .inProgress
    }

    /// order-status.js `payoutSummary`: nil when there is no live refund (absent, zero amount or rejected).
    private var historyRefundState: OrderLifecycleState? {
        guard historyFacts.hasRefundApplication else { return nil }
        if refundPayoutStatus == 1 || refundPayoutStatus == 4 { return .refunded }
        if refundPayoutStatus == 2 || refundPayoutStatus == 3 { return .refunding }
        if let amount = refundAmount, !(amount > .zero) { return nil }
        if refundApplicationStatus == 2 { return nil }
        return .refunding
    }

    /// purchaseKind 2, else ownerType 1 with no ticket and an expiry. Ticket id 0 stays 0 and counts as no ticket.
    public var isSelfPlayPass: Bool {
        if let purchaseKind { return purchaseKind == 2 }
        let noTicket = ticketID == nil || ticketID == 0
        let expires = expiresAt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return ownerType == 1 && noTicket && !expires.isEmpty
    }

    /// Same key as not_started, with the source text 可使用. A future start stays 未开始.
    public func showsUnusedPass(now: Date = Date()) -> Bool {
        guard isSelfPlayPass, OrderLifecycleTime.date(historyFacts.firstSuccessfulScanAt) == nil else { return false }
        if let start = OrderLifecycleTime.date(historyFacts.start), now < start { return false }
        return historyState(now: now) == .notStarted
    }

    public func historyTagKey(now: Date = Date()) -> String {
        showsUnusedPass(now: now) ? "orderLifecycle.state.passReady" : "orderLifecycle.state." + historyState(now: now).rawValue
    }
}

public enum ProfileOrderHistoryFilter: String, CaseIterable, Identifiable, Hashable {
    case all, pendingPayment, notStarted, inProgress, completed, refunding, refunded, nonRefundable, manualRefund
    public var id: String { rawValue }
    public var titleKey: String {
        self == .all ? "profile.orderFilter.all" : "orderLifecycle.state." + rawValue
    }
    public func orders(in rows: [ProfileOrder], now: Date = Date()) -> [ProfileOrder] {
        self == .all ? rows : rows.filter { $0.historyState(now: now).rawValue == rawValue }
    }
}

public struct ProfileOrderFilterOwner: Equatable {
    public let readerID: ObjectIdentifier
    public let identity: ProfileReadIdentity?
    public let isConfigured: Bool
    public init(readerID: ObjectIdentifier, identity: ProfileReadIdentity?, isConfigured: Bool) {
        self.readerID = readerID; self.identity = identity; self.isConfigured = isConfigured
    }
    public var isCurrent: Bool { isConfigured && (identity?.accountID ?? 0) > 0 }
}
/// No order/PII snapshot retained here. Detail navigation preserves the choice;
/// reader replacement, revocation or account change cannot reuse a previous choice.
public struct ProfileOrderFilterSelection {
    private var owner: ProfileOrderFilterOwner?
    private var filter: ProfileOrderHistoryFilter = .all
    public init() {}
    public func value(for current: ProfileOrderFilterOwner) -> ProfileOrderHistoryFilter {
        owner == current && current.isCurrent ? filter : .all
    }
    public mutating func choose(_ next: ProfileOrderHistoryFilter, rendered: ProfileOrderFilterOwner, current: ProfileOrderFilterOwner) {
        guard rendered == current, current.isCurrent else { return }
        owner = current; filter = next
    }
    public mutating func retire() { owner = nil; filter = .all }
}
