import Foundation

/// Source checkout order (pages/activity/baoming): already-registered banner, 参与人信息,
/// 活动信息, 费用明细 (票种 → 订单金额 → 俱乐部会员权益 → 积分抵扣 → 总计), then the
/// waitlist card and the consent/submit bar. `RegistrationSheetView` follows this order for
/// a fresh form; retained/pending outcomes show only the activity and status sections.
public enum RegistrationCheckoutSection: String, CaseIterable {
    case alreadyRegistered, participants, activity, ticket, fees, waitlist, confirmation
}

/// Source 俱乐部会员权益 row: a server deduction, otherwise a priority-signup note.
/// Only explicit quote fields produce it; nothing is shown when neither is present.
public enum RegistrationCheckoutClubBenefit: Equatable {
    case discount(Decimal)
    case priorityActive
    case priorityReserved

    public static func from(_ quote: RegistrationQuote) -> RegistrationCheckoutClubBenefit? {
        if let amount = quote.memberDiscountYuan, amount > .zero { return .discount(amount) }
        guard quote.prioritySignupEnabled else { return nil }
        return quote.clubMember ? .priorityActive : .priorityReserved
    }

    /// Localized note for priority-only benefits; a discount is shown as an amount row.
    public var noteKey: String? {
        switch self {
        case .discount: return nil
        case .priorityActive: return "registrationParity.clubPriorityActive"
        case .priorityReserved: return "registrationParity.clubPriorityReserved"
        }
    }
}

/// Presentation-only checkout facts. Amounts stay nil when the source did not supply them;
/// the view must then show its explicit unavailable state, never zero or a converted value.
public struct RegistrationCheckoutFacts: Equatable {
    /// Source navigation title "结算". The sheet still uses `registration.form.title`
    /// because existing UI tests assert that navigation bar title.
    public static let sourceTitleKey = "registrationParity.title"

    /// Source banner condition `activityInfo.isSignUp === 1`; unknown is not signed up.
    public let viewerAlreadyRegistered: Bool
    /// Source `selectedTicket.meetingPoint`; the row is omitted when absent.
    public let meetingPoint: String?
    /// Source `activityInfo.address || activityInfo.addressName`; nil → 待确认集合地点.
    public let venue: String?
    /// Source 订单金额 is the selected ticket's listed price; nil means unknown.
    public let orderAmount: Decimal?

    public init(activity: ActivityDetail, ticket: ActivityTicket?) {
        viewerAlreadyRegistered = activity.signUpFlag == 1
        meetingPoint = ActivityDetailHeaderFacts.nonempty(ticket?.meetingPoint)
        venue = ActivityDetailHeaderFacts.nonempty(activity.summary.address)
            ?? ActivityDetailHeaderFacts.nonempty(activity.summary.addressName)
        orderAmount = ticket?.price
    }
}

// MARK: - Four-Shop Fixed Compensation Policy & Core Loop Business Rules

/// Backend & mini-program policy (`TopicSaleCanonicalV1.requiresFourStoreContract`,
/// `TopicSaleFinalizationServiceImpl.finalizeForSale`, `ExploreSaleSnapshotGate.assertSnapshotFrozen`):
/// Four-shop fixed compensation products (`productType == 2` with `evidenceRule == "FOUR_STORE_REDEEM"`
/// or `requiresFourStoreContract == true`) stop new sale finalization and stop new ticket sales,
/// while already-sold contracts (`registrationStatus == 2` / paid orders / existing tickets & entitlements)
/// continue to be fulfilled normally.
public enum FourShopCompensationPolicy: Equatable {
    public static let freeExploreProductType = 2
    public static let fourStoreRedeemEvidenceRule = "FOUR_STORE_REDEEM"
    public static let stopNewSaleFinalizationMessage = "四店固定补偿产品已停止新开售，已售合同继续履行"
    public static let stopNewTicketSaleMessage = "四店固定补偿产品已停止新售票，已售合同继续履行"
    public static let soldContractFulfillmentNotice = "已售合同继续履行"

    public struct SoldContractFulfillment: Equatable {
        public let isSoldContract: Bool
        public let requiresFourStoreContract: Bool
        public let continuesFulfillment: Bool
        public let allowsDynamicQRPass: Bool
        public let allowsEntitlementRedemption: Bool
        public let fulfillmentNotice: String?

        public init(
            isSoldContract: Bool,
            requiresFourStoreContract: Bool,
            continuesFulfillment: Bool,
            allowsDynamicQRPass: Bool,
            allowsEntitlementRedemption: Bool,
            fulfillmentNotice: String?
        ) {
            self.isSoldContract = isSoldContract
            self.requiresFourStoreContract = requiresFourStoreContract
            self.continuesFulfillment = continuesFulfillment
            self.allowsDynamicQRPass = allowsDynamicQRPass
            self.allowsEntitlementRedemption = allowsEntitlementRedemption
            self.fulfillmentNotice = fulfillmentNotice
        }
    }

    public static func requiresFourStoreContract(
        productType: Int?,
        evidenceRule: String?,
        requiresFourStoreContractFlag: Bool = false
    ) -> Bool {
        guard productType == freeExploreProductType else { return false }
        if requiresFourStoreContractFlag { return true }
        guard let normalized = evidenceRule?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
              !normalized.isEmpty else {
            return false
        }
        return normalized == fourStoreRedeemEvidenceRule
    }

    /// Evaluates whether a topic/product can finalize for new sale (`TopicSaleFinalizationServiceImpl.finalizeForSale`).
    public static func evaluateNewSaleFinalization(
        productType: Int?,
        evidenceRule: String?,
        requiresFourStoreContractFlag: Bool = false
    ) -> Result<Void, RegistrationCoreLoopRuleFailure> {
        if requiresFourStoreContract(
            productType: productType,
            evidenceRule: evidenceRule,
            requiresFourStoreContractFlag: requiresFourStoreContractFlag
        ) {
            return .failure(.fourShopFixedCompensationStoppedNewSale(message: stopNewSaleFinalizationMessage))
        }
        return .success(())
    }

    /// Evaluates whether a new ticket quote/registration/sale is permitted (`ExploreSaleSnapshotGate.assertSnapshotFrozen`).
    public static func evaluateNewTicketSale(
        productType: Int?,
        evidenceRule: String?,
        requiresFourStoreContractFlag: Bool = false
    ) -> Result<Void, RegistrationCoreLoopRuleFailure> {
        if requiresFourStoreContract(
            productType: productType,
            evidenceRule: evidenceRule,
            requiresFourStoreContractFlag: requiresFourStoreContractFlag
        ) {
            return .failure(.fourShopFixedCompensationStoppedNewTicketSale(message: stopNewTicketSaleMessage))
        }
        return .success(())
    }

    /// Evaluates fulfillment for an existing order/ticket. Sold contracts (`registrationStatus == 2` or
    /// paid `paymentStatus == 2` while active) always continue fulfillment even when the product is a
    /// four-shop fixed compensation product that has stopped new sales.
    public static func evaluateSoldContractFulfillment(
        registrationStatus: Int?,
        paymentStatus: Int?,
        verificationStatus: Int? = nil,
        productType: Int? = freeExploreProductType,
        evidenceRule: String? = fourStoreRedeemEvidenceRule,
        requiresFourStoreContractFlag: Bool = true
    ) -> SoldContractFulfillment {
        let isFourStore = requiresFourStoreContract(
            productType: productType,
            evidenceRule: evidenceRule,
            requiresFourStoreContractFlag: requiresFourStoreContractFlag
        )
        let isCancelledOrRefunded = registrationStatus == 3 || registrationStatus == 4 || paymentStatus == 3 || paymentStatus == 4
        let isSold = !isCancelledOrRefunded && (registrationStatus == 2 || paymentStatus == 2)
        let isUnverifiedSold = isSold && verificationStatus != 1
        return SoldContractFulfillment(
            isSoldContract: isSold,
            requiresFourStoreContract: isFourStore,
            continuesFulfillment: isSold,
            allowsDynamicQRPass: isUnverifiedSold,
            allowsEntitlementRedemption: isSold,
            fulfillmentNotice: (isSold && isFourStore) ? soldContractFulfillmentNotice : nil
        )
    }
}

/// Authoritative business-rule failures matching `CmsRegistrationServiceImpl`, `ExploreSaleSnapshotGate`,
/// `ExploreAccountTicketGate`, `TopicSaleFinalizationServiceImpl`, and `pages/activity/baoming/baoming.js`.
public enum RegistrationCoreLoopRuleFailure: Error, Equatable {
    case fourShopFixedCompensationStoppedNewSale(message: String)
    case fourShopFixedCompensationStoppedNewTicketSale(message: String)
    case explorePassOrderLimitExceeded(message: String)
    case explorePassAccountLimitReached(code: String, message: String)
    case explorePassPointsForbidden(message: String)
    case explorePassCrossClubForbidden(message: String)
    case exploreTopicNotSelling(message: String)
    case exploreSnapshotNotFrozen(message: String)
    case nonPlatformPaidProductBlocked(message: String)
    case clubMembershipRequired(message: String)
    case memberReservedQuotaProtected(message: String)
    case soldOut(message: String)
    case ticketWindowClosed(state: TicketWindowRule.WindowState, message: String)
    case nonRefundableConfirmationRequired(message: String)

    public var userMessage: String {
        switch self {
        case .fourShopFixedCompensationStoppedNewSale(let message),
             .fourShopFixedCompensationStoppedNewTicketSale(let message),
             .explorePassOrderLimitExceeded(let message),
             .explorePassAccountLimitReached(_, let message),
             .explorePassPointsForbidden(let message),
             .explorePassCrossClubForbidden(let message),
             .exploreTopicNotSelling(let message),
             .exploreSnapshotNotFrozen(let message),
             .nonPlatformPaidProductBlocked(let message),
             .clubMembershipRequired(let message),
             .memberReservedQuotaProtected(let message),
             .soldOut(let message),
             .ticketWindowClosed(_, let message),
             .nonRefundableConfirmationRequired(let message):
            return message
        }
    }
}

public enum RegistrationCoreLoopRules {
    public static let explorePassOrderLimitMessage = "探索票每单限购 1 张"
    public static let explorePassAccountLimitCode = "SHOP_DAY_ACCOUNT_TICKET_LIMIT_REACHED"
    public static let explorePassAccountLimitMessage = "当前账号已持有该主题的有效探索票，不能重复购买"
    public static let explorePassPointsForbiddenMessage = "探店日不支持积分抵扣，请关闭积分后按全价购买"
    public static let explorePassCrossClubMessage = "自由探索只开放内容所属俱乐部的场次，不能跨俱乐部售票"
    public static let exploreTopicNotSellingMessage = "该主题尚未完成招商与锁价,暂未开售"
    public static let exploreSnapshotMissingMessage = "该主题尚未生成销售快照，无法售票"
    public static let nonPlatformPaidProductBlockedMessage = "该产品暂不支持在线支付(平台正在办理支付资质,预计 2 个月内开放);如需报名请联系主办方"
    public static let clubMembershipRequiredMessage = "请先加入俱乐部再报名"
    public static let memberReservedQuotaMessage = "剩余名额已为俱乐部会员保留"
    public static let soldOutMessage = "名额已满"

    public struct RegistrationRuleContext: Equatable {
        public let productType: Int
        public let ticketType: String?
        public let quantity: Int
        public let usePoints: Bool
        public let existingLiveExploreTicketsForTopic: Int
        public let topicLifecycle: Int?
        public let directSaleOpen: Bool
        public let hasFrozenSaleSnapshot: Bool
        public let evidenceRule: String?
        public let requiresFourStoreContractFlag: Bool
        public let topicClubID: Int?
        public let sessionClubID: Int?
        public let isPlatformOwned: Bool
        public let payableAmount: Decimal
        public let activityClubID: Int?
        public let requiresClubMembership: Bool
        public let viewerIsHost: Bool
        public let viewerIsClubMember: Bool
        public let remainingInventory: Int?
        public let memberReservedQuota: Int
        public let hasActiveWaitlistOffer: Bool

        public init(
            productType: Int = 1,
            ticketType: String? = nil,
            quantity: Int = 1,
            usePoints: Bool = false,
            existingLiveExploreTicketsForTopic: Int = 0,
            topicLifecycle: Int? = 3,
            directSaleOpen: Bool = true,
            hasFrozenSaleSnapshot: Bool = true,
            evidenceRule: String? = nil,
            requiresFourStoreContractFlag: Bool = false,
            topicClubID: Int? = nil,
            sessionClubID: Int? = nil,
            isPlatformOwned: Bool = true,
            payableAmount: Decimal = .zero,
            activityClubID: Int? = nil,
            requiresClubMembership: Bool = false,
            viewerIsHost: Bool = false,
            viewerIsClubMember: Bool = false,
            remainingInventory: Int? = nil,
            memberReservedQuota: Int = 0,
            hasActiveWaitlistOffer: Bool = false
        ) {
            self.productType = productType
            self.ticketType = ticketType
            self.quantity = quantity
            self.usePoints = usePoints
            self.existingLiveExploreTicketsForTopic = existingLiveExploreTicketsForTopic
            self.topicLifecycle = topicLifecycle
            self.directSaleOpen = directSaleOpen
            self.hasFrozenSaleSnapshot = hasFrozenSaleSnapshot
            self.evidenceRule = evidenceRule
            self.requiresFourStoreContractFlag = requiresFourStoreContractFlag
            self.topicClubID = topicClubID
            self.sessionClubID = sessionClubID
            self.isPlatformOwned = isPlatformOwned
            self.payableAmount = payableAmount
            self.activityClubID = activityClubID
            self.requiresClubMembership = requiresClubMembership
            self.viewerIsHost = viewerIsHost
            self.viewerIsClubMember = viewerIsClubMember
            self.remainingInventory = remainingInventory
            self.memberReservedQuota = memberReservedQuota
            self.hasActiveWaitlistOffer = hasActiveWaitlistOffer
        }

        public var isExplorePass: Bool {
            productType == FourShopCompensationPolicy.freeExploreProductType
                || ticketType?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "EXPLORE_PASS"
        }
    }

    /// Validates all backend & mini-program limits, quotas, funds, ownership, and four-shop stop-sale gates.
    /// Never weakens any check.
    public static func validate(_ context: RegistrationRuleContext) -> Result<Void, RegistrationCoreLoopRuleFailure> {
        guard context.quantity > 0 else {
            return .failure(.soldOut(message: soldOutMessage))
        }

        // 1. Four-shop fixed compensation stop-new-sales gate (must precede or accompany Explore checks)
        if case .failure(let error) = FourShopCompensationPolicy.evaluateNewTicketSale(
            productType: context.isExplorePass ? FourShopCompensationPolicy.freeExploreProductType : context.productType,
            evidenceRule: context.evidenceRule,
            requiresFourStoreContractFlag: context.requiresFourStoreContractFlag
        ) {
            return .failure(error)
        }

        // 2. Free Explore / Explore Pass specific gates
        if context.isExplorePass {
            if context.topicLifecycle != 3 || !context.directSaleOpen {
                return .failure(.exploreTopicNotSelling(message: exploreTopicNotSellingMessage))
            }
            if !context.hasFrozenSaleSnapshot {
                return .failure(.exploreSnapshotNotFrozen(message: exploreSnapshotMissingMessage))
            }
            if let topicClubID = context.topicClubID, let sessionClubID = context.sessionClubID, topicClubID != sessionClubID {
                return .failure(.explorePassCrossClubForbidden(message: explorePassCrossClubMessage))
            }
            if context.quantity > 1 {
                return .failure(.explorePassOrderLimitExceeded(message: explorePassOrderLimitMessage))
            }
            if context.usePoints {
                return .failure(.explorePassPointsForbidden(message: explorePassPointsForbiddenMessage))
            }
            if context.existingLiveExploreTicketsForTopic > 0 {
                return .failure(.explorePassAccountLimitReached(
                    code: explorePassAccountLimitCode,
                    message: explorePassAccountLimitMessage
                ))
            }
        }

        // 3. Club access & member-reserved quota gate
        if let clubID = context.activityClubID, clubID > 0, !context.viewerIsHost, !context.viewerIsClubMember {
            if context.requiresClubMembership {
                return .failure(.clubMembershipRequired(message: clubMembershipRequiredMessage))
            }
            if !context.hasActiveWaitlistOffer,
               let remaining = context.remainingInventory,
               context.memberReservedQuota > 0,
               (remaining - context.quantity) < context.memberReservedQuota {
                return .failure(.memberReservedQuotaProtected(message: memberReservedQuotaMessage))
            }
        }

        // 4. Inventory quota gate
        if !context.hasActiveWaitlistOffer, let remaining = context.remainingInventory, remaining < context.quantity {
            return .failure(.soldOut(message: soldOutMessage))
        }

        // 5. Collectible / Second-clearing ownership gate (#22 二清闸): paid orders require platform ownership
        if context.payableAmount > .zero && !context.isPlatformOwned {
            return .failure(.nonPlatformPaidProductBlocked(message: nonPlatformPaidProductBlockedMessage))
        }

        return .success(())
    }

    public struct ComputedOrderPrice: Equatable {
        public let orderTotalYuan: Decimal
        public let memberDiscountYuan: Decimal
        public let couponDeductYuan: Decimal
        public let pointsDeductYuan: Decimal
        public let pointsUsed: Int
        public let payAmount: Decimal
    }

    /// Order-level price & points calculation matching `CmsRegistrationServiceImpl.computePrice`.
    /// Points cap (`maxPointsDeductPerOrderYuan`, default 50 yuan) is applied once per order, never multiplied by quantity.
    public static func computeOrderPrice(
        unitPrice: Decimal,
        quantity: Int = 1,
        memberDiscountRate: Decimal? = nil,
        couponDeductYuan: Decimal? = nil,
        usePoints: Bool = false,
        pointsUsableForProduct: Bool = true,
        userAvailablePoints: Int = 0,
        pointDeductRate: Decimal = Decimal(string: "0.01")!,
        maxPointsDeductPerOrderYuan: Decimal = 50
    ) -> ComputedOrderPrice {
        let validQty = max(1, quantity)
        let rawTotal = max(.zero, unitPrice) * Decimal(validQty)
        let orderTotal = roundYuan(rawTotal)

        let memberDiscount: Decimal = {
            guard let rate = memberDiscountRate, rate > .zero, rate < 1 else { return .zero }
            return min(orderTotal, roundYuan(orderTotal * (1 - rate)))
        }()
        let afterMember = max(.zero, orderTotal - memberDiscount)

        let couponDeduct: Decimal = {
            guard let coupon = couponDeductYuan, coupon > .zero else { return .zero }
            return min(afterMember, roundYuan(coupon))
        }()
        let afterCoupon = max(.zero, afterMember - couponDeduct)

        var pointsDeduct: Decimal = .zero
        var pointsUsed = 0
        if usePoints && pointsUsableForProduct && afterCoupon > .zero && userAvailablePoints > 0 && pointDeductRate > .zero {
            let orderCap = min(max(.zero, maxPointsDeductPerOrderYuan), afterCoupon)
            let maxByBalance = roundYuan(Decimal(userAvailablePoints) * pointDeductRate)
            let deduct = min(orderCap, maxByBalance)
            if deduct > .zero {
                pointsDeduct = deduct
                let needed = NSDecimalNumber(decimal: deduct).dividing(by: NSDecimalNumber(decimal: pointDeductRate))
                var roundedNeeded = Decimal()
                var neededDec = needed.decimalValue
                NSDecimalRound(&roundedNeeded, &neededDec, 0, .up)
                pointsUsed = max(0, NSDecimalNumber(decimal: roundedNeeded).intValue)
            }
        }

        let payAmount = max(.zero, afterCoupon - pointsDeduct)
        return ComputedOrderPrice(
            orderTotalYuan: orderTotal,
            memberDiscountYuan: memberDiscount,
            couponDeductYuan: couponDeduct,
            pointsDeductYuan: pointsDeduct,
            pointsUsed: pointsUsed,
            payAmount: payAmount
        )
    }

    /// Matches `baoming.js:1129-1133`: when `useDiscount` is enabled and the quote returns
    /// `!pointsUsable` or `pointsDeductYuan <= 0`, auto-disable the toggle and return the exact toast copy.
    public static func pointsAutoDisableEvaluation(
        usePoints: Bool,
        quote: RegistrationQuote,
        userAvailablePoints: Int? = nil
    ) -> (shouldDisable: Bool, notice: String?) {
        guard usePoints else { return (false, nil) }
        let deduct = quote.pointsDeductYuan ?? .zero
        if !quote.pointsUsable || deduct <= .zero {
            let notice = (userAvailablePoints ?? 1) <= 0 ? "暂无可用积分" : "该票不支持积分抵扣"
            return (true, notice)
        }
        return (false, nil)
    }

    private static func roundYuan(_ value: Decimal) -> Decimal {
        var input = value
        var result = Decimal()
        NSDecimalRound(&result, &input, 2, .plain)
        return result
    }
}

/// Ticket window & multi-session selector rules ported from `chengyinhub-xcx/utils/ticket-window.js`
/// and `pages/activity/baoming/baoming.js`.
public enum TicketWindowRule {
    public enum WindowState: String, Equatable {
        case available = ""
        case started = "started"
        case ended = "ended"
        case closed = "closed"

        public var label: String {
            switch self {
            case .available: return ""
            case .started: return "场次已开始"
            case .ended: return "场次已结束"
            case .closed: return "报名已截止"
            }
        }
    }

    public static func state(
        startTime: Date?,
        endTime: Date?,
        signupDeadline: Date?,
        selfGuided: Bool = false,
        now: Date = Date()
    ) -> WindowState {
        if selfGuided {
            guard let endTime else { return .ended }
            if now >= endTime { return .ended }
            if let signupDeadline, now >= signupDeadline { return .closed }
            return .available
        }
        if let startTime {
            if now >= startTime {
                if let endTime, now > endTime { return .ended }
                return .started
            }
        } else if let endTime, now > endTime {
            return .ended
        }
        // Source ticket-window.js: signupDeadline only closes self-guided tickets (handled above).
        return .available
    }

    public static func state(for ticket: ActivityTicket, selfGuided: Bool = false, now: Date = Date()) -> WindowState {
        state(
            startTime: parseTicketDate(ticket.startTime),
            endTime: parseTicketDate(ticket.endTime),
            signupDeadline: parseTicketDate(ticket.signupDeadline),
            selfGuided: selfGuided,
            now: now
        )
    }

    public static func ticketWindowPassed(_ ticket: ActivityTicket, selfGuided: Bool = false, now: Date = Date()) -> Bool {
        state(for: ticket, selfGuided: selfGuided, now: now) != .available
    }

    /// Matches `openTicketSheet` in `baoming.js`: filters out tickets whose window has passed and sorts by `startTime` ascending.
    public static func selectableSessionTickets(_ tickets: [ActivityTicket], selfGuided: Bool = false, now: Date = Date()) -> [ActivityTicket] {
        let active = tickets.filter { !ticketWindowPassed($0, selfGuided: selfGuided, now: now) }
        return sortBySessionStart(active)
    }

    public static func sortBySessionStart(_ tickets: [ActivityTicket]) -> [ActivityTicket] {
        tickets.enumerated().sorted { lhs, rhs in
            let lDate = parseTicketDate(lhs.element.startTime)
            let rDate = parseTicketDate(rhs.element.startTime)
            switch (lDate, rDate) {
            case let (l?, r?):
                if l != r { return l < r }
                return lhs.offset < rhs.offset
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.offset < rhs.offset
            }
        }.map(\.element)
    }

    /// Formats option label as `"{name} · {MM-DD HH:mm} · ¥{price}"` matching `baoming.js:1168`.
    public static func sessionOptionLabel(for ticket: ActivityTicket) -> String {
        let name = ticket.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "标准票" : ticket.name
        let timePart = formatSessionMinute(ticket.startTime) ?? "待定时间"
        let pricePart: String = {
            guard let price = ticket.price else { return "¥—" }
            return "¥\(NSDecimalNumber(decimal: price).stringValue)"
        }()
        return "\(name) · \(timePart) · \(pricePart)"
    }

    public static func parseTicketDate(_ raw: String?) -> Date? {
        guard let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        let normalized = text.replacingOccurrences(of: "T", with: " ")
        let formats = ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy/MM/dd HH:mm:ss", "yyyy/MM/dd HH:mm", "yyyy-MM-dd"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: normalized) { return date }
        }
        return ISO8601DateFormatter().date(from: text)
    }

    public static func formatSessionMinute(_ raw: String?) -> String? {
        guard let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        let normalized = text.replacingOccurrences(of: "T", with: " ")
        // Extract MM-DD HH:mm directly when matching YYYY-MM-DD HH:mm(:ss)
        if normalized.count >= 16 {
            let start = normalized.index(normalized.startIndex, offsetBy: 5)
            let end = normalized.index(normalized.startIndex, offsetBy: 16)
            let slice = String(normalized[start..<end]).replacingOccurrences(of: "/", with: "-")
            if slice.range(of: #"^\d{2}-\d{2} \d{2}:\d{2}$"#, options: .regularExpression) != nil {
                return slice
            }
        }
        return normalized
    }
}

/// Ported from `chengyinhub-xcx/utils/checkout/checkout-workflow.js`:
/// classifies `/api/registration/create` and `/api/registration/pay` errors for idempotent order rebuild vs quote refresh.
public enum CheckoutOrderRebuildRule: Equatable {
    public static let orderExpiredUserMessage = "订单已过期,请重新报名"
    public static let quoteUpdatedUserMessage = "价格已更新，请重新确认"
    public static let terminalIdempotencyPrefix = "该幂等键对应的报名已"

    public enum Action: Equatable {
        /// Pay returned 410 or "订单已过期": clear cached registrationId & requestId and rebuild order once.
        case rebuildExpiredPayOrder(userMessage: String)
        /// Create returned 409 with "该幂等键对应的报名已...": clear cached registrationId & requestId and retry create with a fresh key.
        case rebuildTerminalIdempotencyConflict
        /// Create returned 409 for quote/price change: refresh quote and ask user to re-confirm.
        case refreshQuoteAndReconfirm(userMessage: String)
        /// Unrelated error: surface without mutating idempotency key.
        case preserveIntent(userMessage: String?)
    }

    public static func isPayOrderExpired(code: Int?, message: String?) -> Bool {
        if code == 410 { return true }
        guard let message else { return false }
        return message.contains("订单已过期")
    }

    public static func isTerminalOrderConflict(code: Int?, message: String?) -> Bool {
        guard code == 409, let message else { return false }
        return message.hasPrefix(terminalIdempotencyPrefix)
    }

    public static func classifyPayFailure(code: Int?, message: String?, canRebuild: Bool = true) -> Action {
        if isPayOrderExpired(code: code, message: message), canRebuild {
            return .rebuildExpiredPayOrder(userMessage: orderExpiredUserMessage)
        }
        let trimmed = message?.trimmingCharacters(in: .whitespacesAndNewlines)
        return .preserveIntent(userMessage: (trimmed?.isEmpty == false) ? trimmed : (isPayOrderExpired(code: code, message: message) ? orderExpiredUserMessage : nil))
    }

    public static func classifyCreateFailure(code: Int?, message: String?, canRebuild: Bool = true) -> Action {
        if isTerminalOrderConflict(code: code, message: message), canRebuild {
            return .rebuildTerminalIdempotencyConflict
        }
        if code == 409 {
            return .refreshQuoteAndReconfirm(userMessage: quoteUpdatedUserMessage)
        }
        let trimmed = message?.trimmingCharacters(in: .whitespacesAndNewlines)
        return .preserveIntent(userMessage: (trimmed?.isEmpty == false) ? trimmed : nil)
    }
}

/// Ported from `pages/activity/baoming/baoming.js` & `baoming.wxml`:
/// 24-hour pre-gathering refund deadline notice and mandatory confirmation modal when `payAmount > 0 && refundableNow == false`.
public enum NonRefundable24hNotice: Equatable {
    public static let badgeTitle = "本单不可退"
    public static let modalTitle = "本单不可退"
    public static let modalContent = "该场次已过「集合前 24 小时」退款截止时间，支付后不可退款。确认继续下单？"
    public static let confirmButtonTitle = "继续下单"
    public static let cancelButtonTitle = "再想想"

    public static func feeRowNotice(for quote: RegistrationQuote) -> String? {
        if quote.refundableNow == false {
            if let payAmount = quote.payAmount, payAmount <= .zero {
                return nil
            }
            return "该场次已过集合前 24 小时退款截止时间，本单不可退"
        }
        if quote.refundableNow == true, let deadline = TicketWindowRule.formatSessionMinute(quote.refundDeadline) {
            return "集合前 24 小时可退（截止 \(deadline)）"
        }
        return nil
    }
}

/// Ported from `chengyinhub-xcx/utils/ticket-expiry.js` and `utils/order-status.js`.
public enum TicketExpiryAndOrderStatusRules {
    /// Returns remaining whole days until `validUntil` from `now`, or `nil` if invalid.
    public static func passDaysLeft(validUntil: String?, now: Date = Date()) -> Int? {
        // Source: natural-day count in China time; expired or unparsable == nil (see MoneyPassExpiry).
        MoneyPassExpiry.daysLeft(until: validUntil, nowMs: Int64((now.timeIntervalSince1970 * 1000).rounded(.down)))
    }

    /// Matches `passExpiryText` in `utils/ticket-expiry.js`:
    /// shows `"今天过期"` when `days == 0`, `"{days} 天内过期"` when `1 <= days <= 7`, and `""` otherwise.
    public static func passExpiryText(validUntil: String?, now: Date = Date()) -> String {
        MoneyPassExpiry.text(until: validUntil, nowMs: Int64((now.timeIntervalSince1970 * 1000).rounded(.down)))
    }

    public struct PayoutSummary: Equatable {
        public let label: String
        public let hint: String
        public let canCancelRefundApplication: Bool
    }

    /// Matches `payoutSummary` in `chengyinhub-xcx/utils/order-status.js`.
    public static func payoutSummary(status: Int?, payoutStatus: Int?) -> PayoutSummary? {
        guard status != nil || payoutStatus != nil else { return nil }
        if payoutStatus == 1 || payoutStatus == 4 {
            return PayoutSummary(label: "已退款", hint: "退款已原路退回", canCancelRefundApplication: false)
        }
        if payoutStatus == 2 {
            return PayoutSummary(label: "退款处理中", hint: "原路退款异常，平台正在人工处理", canCancelRefundApplication: false)
        }
        if payoutStatus == 3 {
            return PayoutSummary(label: "退款处理中", hint: "人工退款已处理，等待复核确认", canCancelRefundApplication: false)
        }
        // Source: a rejected application (status 2) is not a refund in flight.
        if status == 2 { return nil }
        if status == 0 {
            return PayoutSummary(label: "退款审核中", hint: "退款申请已提交，等待平台审核", canCancelRefundApplication: true)
        }
        if payoutStatus == 0 {
            return PayoutSummary(label: "退款处理中", hint: "微信已受理原路退款，到账以微信退款通知为准", canCancelRefundApplication: false)
        }
        if status == 1 {
            return PayoutSummary(label: "退款处理中", hint: "退款已批准，正在提交原路退款", canCancelRefundApplication: false)
        }
        return nil
    }

    /// Matches `canRequestOrderRefund` in `chengyinhub-xcx/utils/order-status.js`.
    public static func canRequestOrderRefund(
        registrationStatus: Int?,
        paymentStatus: Int?,
        verificationStatus: Int?,
        refundable: Bool?,
        manualRefundCaseStatus: Int? = nil,
        refundApplicationStatus: Int? = nil,
        refundPayoutStatus: Int? = nil
    ) -> Bool {
        if let manualRefundCaseStatus, manualRefundCaseStatus != 0 { return false }
        if payoutSummary(status: refundApplicationStatus, payoutStatus: refundPayoutStatus) != nil { return false }
        return registrationStatus == 2 && paymentStatus == 2 && verificationStatus != 1 && refundable == true
    }
}
