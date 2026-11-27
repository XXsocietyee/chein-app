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
    public static var stopNewTicketSaleMessage: String { W8Text.t("四店固定补偿产品已停止新售票，已售合同继续履行", "The four-store fixed-compensation product has stopped new ticket sales; sold contracts will still be fulfilled") }
    public static var soldContractFulfillmentNotice: String { W8Text.t("已售合同继续履行", "Sold contracts will still be fulfilled") }

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
    public static var explorePassPointsForbiddenMessage: String { W8Text.t("探店日不支持积分抵扣，请关闭积分后按全价购买", "Points can’t be used on store-visit days. Turn off points and buy at full price") }
    public static var explorePassCrossClubMessage: String { W8Text.t("自由探索只开放内容所属俱乐部的场次，不能跨俱乐部售票", "Free Explore only offers sessions of the club that owns the content; tickets can’t be sold across clubs") }
    public static var exploreTopicNotSellingMessage: String { W8Text.t("该主题尚未完成招商与锁价,暂未开售", "This topic hasn’t finished merchant onboarding and price locking, so it isn’t on sale yet") }
    public static var exploreSnapshotMissingMessage: String { W8Text.t("该主题尚未生成销售快照，无法售票", "This topic has no sales snapshot yet, so tickets can’t be sold") }
    public static var nonPlatformPaidProductBlockedMessage: String { W8Text.t("该产品暂不支持在线支付(平台正在办理支付资质,预计 2 个月内开放);如需报名请联系主办方", "This product doesn’t support online payment yet (the platform is obtaining payment qualifications, expected within 2 months). Contact the organizer to sign up") }
    public static var clubMembershipRequiredMessage: String { W8Text.t("请先加入俱乐部再报名", "Join the club before signing up") }
    public static var memberReservedQuotaMessage: String { W8Text.t("剩余名额已为俱乐部会员保留", "The remaining spots are reserved for club members") }
    public static var soldOutMessage: String { W8Text.t("名额已满", "Sold out") }

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

    /// Order total, member discount and coupon only.
    /// Points stay on the server quote (`RegistrationQuote.pointsDeductYuan` / `pointsUsed`).
    /// This function does not apply a client point-to-yuan rate.
    public static func computeOrderPrice(
        unitPrice: Decimal,
        quantity: Int = 1,
        memberDiscountRate: Decimal? = nil,
        couponDeductYuan: Decimal? = nil
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

        return ComputedOrderPrice(
            orderTotalYuan: orderTotal,
            memberDiscountYuan: memberDiscount,
            couponDeductYuan: couponDeduct,
            pointsDeductYuan: .zero,
            pointsUsed: 0,
            payAmount: afterCoupon
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
            let notice = (userAvailablePoints ?? 1) <= 0 ? W8Text.t("暂无可用积分", "No points available") : W8Text.t("该票不支持积分抵扣", "This ticket doesn’t support points")
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
            case .started: return W8Text.t("场次已开始", "Session has started")
            case .ended: return W8Text.t("场次已结束", "Session has ended")
            case .closed: return W8Text.t("报名已截止", "Sign-up has closed")
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
        // The registration form re-checks signupDeadline. A past deadline closes a timed session too.
        if let signupDeadline, now >= signupDeadline { return .closed }
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
        let name = ticket.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? W8Text.t("标准票", "Standard ticket") : ticket.name
        let timePart = formatSessionMinute(ticket.startTime) ?? W8Text.t("待定时间", "Time TBD")
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
    public static var orderExpiredUserMessage: String { W8Text.t("订单已过期,请重新报名", "The order has expired. Please sign up again") }
    public static var quoteUpdatedUserMessage: String { W8Text.t("价格已更新，请重新确认", "The price was updated. Please confirm again") }
    public static let terminalIdempotencyPrefix = "该幂等键对应的报名已"
    /// R11-PC-C-2: MP pages/activity/utils/quote-view.js:130-140 — a promotion-fingerprint 409 gets its own copy; both re-quote.
    public static let marketingConflictMarker = "优惠已变化或与本单不一致"
    public static var marketingConflictUserMessage: String { W8Text.t("优惠已变化或与本单不一致，请重新报价后再提交", "The offer changed or doesn't match this order. Get a new quote and submit again") }

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
            if message?.contains(marketingConflictMarker) == true {
                return .refreshQuoteAndReconfirm(userMessage: marketingConflictUserMessage)
            }
            return .refreshQuoteAndReconfirm(userMessage: quoteUpdatedUserMessage)
        }
        let trimmed = message?.trimmingCharacters(in: .whitespacesAndNewlines)
        return .preserveIntent(userMessage: (trimmed?.isEmpty == false) ? trimmed : nil)
    }
}

/// Ported from `pages/activity/baoming/baoming.js` & `baoming.wxml`:
/// 24-hour pre-gathering refund deadline notice and mandatory confirmation modal when `payAmount > 0 && refundableNow == false`.
public enum NonRefundable24hNotice: Equatable {
    public static var badgeTitle: String { W8Text.t("本单不可退", "Non-refundable") }
    public static var modalTitle: String { W8Text.t("本单不可退", "Non-refundable") }
    public static var modalContent: String { W8Text.t("该场次已开始，支付后不可退款。确认继续下单？", "This session has started. You can't get a refund after you pay. Continue with the order?") }
    public static var confirmButtonTitle: String { W8Text.t("继续下单", "Continue") }
    public static var cancelButtonTitle: String { W8Text.t("再想想", "Not now") }

    public static func feeRowNotice(for quote: RegistrationQuote) -> String? {
        if quote.refundableNow == false {
            if let payAmount = quote.payAmount, payAmount <= .zero {
                return nil
            }
            return W8Text.t("该场次已过集合前 24 小时退款截止时间，本单不可退", "This session is past the refund deadline (24 hours before meeting), so this order is non-refundable")
        }
        if quote.refundableNow == true, let deadline = TicketWindowRule.formatSessionMinute(quote.refundDeadline) {
            return W8Text.t("集合前 24 小时可退（截止 \(deadline)）", "Refundable until 24 hours before meeting (deadline \(deadline))")
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
    /// `refundAmount` mirrors `application.refundAmount` (present and not > 0 means nothing to refund, unless already
    /// paid out). `applicationPresent` mirrors `application != null`; when nil it is inferred from any non-nil field,
    /// which keeps the legacy two-argument call shape. Unknown/in-between states fall back to "退款处理中" like the source.
    public static func payoutSummary(status: Int?, payoutStatus: Int?, refundAmount: Decimal? = nil,
                                     applicationPresent: Bool? = nil) -> PayoutSummary? {
        let present = applicationPresent ?? (status != nil || payoutStatus != nil || refundAmount != nil)
        guard present else { return nil }
        if payoutStatus == 1 || payoutStatus == 4 {
            return PayoutSummary(label: W8Text.t("已退款", "Refunded"), hint: W8Text.t("退款已原路退回", "The refund was returned to the original payment method"), canCancelRefundApplication: false)
        }
        if payoutStatus == 2 {
            return PayoutSummary(label: W8Text.t("退款处理中", "Refund processing"), hint: W8Text.t("原路退款异常，平台正在人工处理", "The refund to the original payment method failed. The platform is handling it manually"), canCancelRefundApplication: false)
        }
        if payoutStatus == 3 {
            return PayoutSummary(label: W8Text.t("退款处理中", "Refund processing"), hint: W8Text.t("人工退款已处理，等待复核确认", "The manual refund was processed and is awaiting review"), canCancelRefundApplication: false)
        }
        // Source: a zero-yuan order has no money to refund, so no in-flight promise.
        if let refundAmount, !(refundAmount > 0) { return nil }
        // Source: a rejected application (status 2) is not a refund in flight.
        if status == 2 { return nil }
        if status == 0 {
            return PayoutSummary(label: W8Text.t("退款审核中", "Refund under review"), hint: W8Text.t("退款申请已提交，等待平台审核", "The refund request was submitted and is awaiting platform review"), canCancelRefundApplication: true)
        }
        if payoutStatus == 0 {
            return PayoutSummary(label: W8Text.t("退款处理中", "Refund processing"), hint: W8Text.t("微信已受理原路退款，到账以微信退款通知为准", "WeChat accepted the refund to the original payment method. Rely on the WeChat refund notice for the arrival time"), canCancelRefundApplication: false)
        }
        if status == 1 {
            return PayoutSummary(label: W8Text.t("退款处理中", "Refund processing"), hint: W8Text.t("退款已批准，正在提交原路退款", "The refund was approved and is being submitted to the original payment method"), canCancelRefundApplication: false)
        }
        return PayoutSummary(label: W8Text.t("退款处理中", "Refund processing"), hint: W8Text.t("退款进度更新中，请以微信退款通知为准", "The refund progress is updating. Rely on the WeChat refund notice"), canCancelRefundApplication: false)
    }

    /// Matches `canRequestOrderRefund` in `chengyinhub-xcx/utils/order-status.js`.
    public static func canRequestOrderRefund(
        registrationStatus: Int?,
        paymentStatus: Int?,
        verificationStatus: Int?,
        refundable: Bool?,
        manualRefundCaseStatus: Int? = nil,
        refundApplicationStatus: Int? = nil,
        refundPayoutStatus: Int? = nil,
        refundAmount: Decimal? = nil,
        refundApplicationPresent: Bool? = nil
    ) -> Bool {
        if let manualRefundCaseStatus, manualRefundCaseStatus != 0 { return false }
        if payoutSummary(status: refundApplicationStatus, payoutStatus: refundPayoutStatus, refundAmount: refundAmount,
                         applicationPresent: refundApplicationPresent) != nil { return false }
        return registrationStatus == 2 && paymentStatus == 2 && verificationStatus != 1 && refundable == true
    }
}

// MARK: - pages/activity/baoming/baoming read model

/// Checkout phases for the activity registration sheet.
/// UNKNOWN renders as `unknownMark` (an em dash). It is never 0 and never a guessed number.
/// This projection reads the quote the coordinator already holds. It does not open a route,
/// and payment, payout, withdrawal, and virtual goods stay hidden.
public enum RegistrationBaomingReadPhase: String, Equatable {
    case loading
    case empty
    case error
    case unknown
    case ready

    public static let unknownMark = "—"
}

/// A server money field. Nil, NaN, and a negative value stay unknown.
/// A literal zero stays zero.
public struct RegistrationBaomingAmountFact: Equatable {
    public enum Kind: Equatable {
        case unknown
        case amount(Decimal)
    }

    public let kind: Kind

    public init(serverAmount: Decimal?) {
        if let serverAmount, !serverAmount.isNaN, serverAmount >= .zero {
            kind = .amount(serverAmount)
        } else {
            kind = .unknown
        }
    }

    public var displayText: String {
        switch kind {
        case .unknown:
            return RegistrationBaomingReadPhase.unknownMark
        case .amount(let value):
            return NSDecimalNumber(decimal: value).stringValue
        }
    }
}

/// A server count. Nil and a negative value stay unknown. A literal zero stays zero.
public struct RegistrationBaomingCountFact: Equatable {
    public enum Kind: Equatable {
        case unknown
        case count(Int)
    }

    public let kind: Kind

    public init(serverCount: Int?) {
        if let serverCount, serverCount >= 0 {
            kind = .count(serverCount)
        } else {
            kind = .unknown
        }
    }

    public var displayText: String {
        switch kind {
        case .unknown:
            return RegistrationBaomingReadPhase.unknownMark
        case .count(let value):
            return String(value)
        }
    }
}

/// Facts the sheet can show from the existing `/api/registration/quote` contract
/// and the activity payload the sheet was already given. Missing fields stay unknown.
public struct RegistrationBaomingCheckoutFacts: Equatable {
    public let phase: RegistrationBaomingReadPhase
    public let payAmount: RegistrationBaomingAmountFact
    public let orderAmount: RegistrationBaomingAmountFact
    public let memberDiscount: RegistrationBaomingAmountFact
    public let couponDeduction: RegistrationBaomingAmountFact
    public let pointsDeduction: RegistrationBaomingAmountFact
    public let remainingInventory: RegistrationBaomingCountFact

    /// Quote totals never become a pay, payout, or virtual-goods action.
    public var paymentStaysHidden: Bool { true }

    public init(phase: RegistrationBaomingReadPhase,
                payAmount: RegistrationBaomingAmountFact,
                orderAmount: RegistrationBaomingAmountFact,
                memberDiscount: RegistrationBaomingAmountFact,
                couponDeduction: RegistrationBaomingAmountFact,
                pointsDeduction: RegistrationBaomingAmountFact,
                remainingInventory: RegistrationBaomingCountFact) {
        self.phase = phase
        self.payAmount = payAmount
        self.orderAmount = orderAmount
        self.memberDiscount = memberDiscount
        self.couponDeduction = couponDeduction
        self.pointsDeduction = pointsDeduction
        self.remainingInventory = remainingInventory
    }

    /// `sessionReady` is the coordinator's current account. `quoteState` is that same
    /// coordinator's quote. No second route is consulted.
    public static func project(sessionReady: Bool,
                               tickets: [ActivityTicket],
                               quoteState: RegistrationQuoteState,
                               selectedTicketID: Int?) -> Self {
        let phase = resolvePhase(sessionReady: sessionReady, tickets: tickets, quoteState: quoteState)
        guard phase == .ready, case .received(let quote) = quoteState else {
            return hidden(phase)
        }
        let ticket = selectedTicket(tickets, id: selectedTicketID)
        return Self(
            phase: .ready,
            payAmount: RegistrationBaomingAmountFact(serverAmount: quote.payAmount),
            orderAmount: RegistrationBaomingAmountFact(serverAmount: ticket?.price),
            memberDiscount: RegistrationBaomingAmountFact(serverAmount: quote.memberDiscountYuan),
            couponDeduction: RegistrationBaomingAmountFact(serverAmount: quote.couponDeductYuan),
            pointsDeduction: RegistrationBaomingAmountFact(serverAmount: quote.pointsDeductYuan),
            remainingInventory: RegistrationBaomingCountFact(serverCount: ticket?.remainingInventory)
        )
    }

    private static func resolvePhase(sessionReady: Bool,
                                     tickets: [ActivityTicket],
                                     quoteState: RegistrationQuoteState) -> RegistrationBaomingReadPhase {
        if !sessionReady { return .loading }
        switch quoteState {
        case .loading:
            return .loading
        case .unavailable(_):
            return .error
        case .idle:
            return tickets.isEmpty ? .empty : .unknown
        case .received(let quote):
            if tickets.isEmpty { return .empty }
            return quote.payAmount == nil ? .unknown : .ready
        }
    }

    private static func selectedTicket(_ tickets: [ActivityTicket], id: Int?) -> ActivityTicket? {
        if let id { return tickets.first { $0.id == id } }
        return tickets.first
    }

    private static func hidden(_ phase: RegistrationBaomingReadPhase) -> Self {
        Self(
            phase: phase,
            payAmount: RegistrationBaomingAmountFact(serverAmount: nil),
            orderAmount: RegistrationBaomingAmountFact(serverAmount: nil),
            memberDiscount: RegistrationBaomingAmountFact(serverAmount: nil),
            couponDeduction: RegistrationBaomingAmountFact(serverAmount: nil),
            pointsDeduction: RegistrationBaomingAmountFact(serverAmount: nil),
            remainingInventory: RegistrationBaomingCountFact(serverCount: nil)
        )
    }
}

@MainActor
extension RegistrationCoordinator {
    /// Projects this coordinator's current quote. It does not quote, create, or pay.
    public func baomingCheckoutFacts(tickets: [ActivityTicket], selectedTicketID: Int?) -> RegistrationBaomingCheckoutFacts {
        RegistrationBaomingCheckoutFacts.project(
            sessionReady: accountID != nil,
            tickets: tickets,
            quoteState: quoteState,
            selectedTicketID: selectedTicketID
        )
    }
}

#if DEBUG
/// In-memory checkout samples. No URL, credential, payment parameter, or live route.
public enum RegistrationBaomingFixtureData {
    public static let activityEmpty = #"{"id":9400,"name":"Offline fixture activity","omsTicketList":[]}"#
    public static let activityWithUnknownPrice = #"{"id":9400,"name":"Offline fixture activity","omsTicketList":[{"id":9401,"name":"Standard fixture ticket","price":null,"remainingInventory":null}]}"#
    public static let quoteKnown = #"{"payAmount":12.5,"pointsDeductYuan":2.5,"memberDiscountYuan":1,"couponDeductYuan":0.5,"pointsUsable":true,"clubMember":true,"quoteSign":"offline-only","refundableNow":true}"#
    public static let quoteKnownZero = #"{"payAmount":0,"pointsDeductYuan":0,"memberDiscountYuan":0,"couponDeductYuan":0,"pointsUsable":false,"clubMember":false,"quoteSign":"offline-only"}"#
    public static let quoteUnknownPay = #"{"pointsUsable":true,"quoteSign":"offline-only"}"#

    public static func activity(_ json: String) throws -> ActivityDetail {
        try JSONDecoder().decode(ActivityDetail.self, from: Data(json.utf8))
    }

    public static func quote(_ json: String) throws -> RegistrationQuote {
        try JSONDecoder().decode(RegistrationQuote.self, from: Data(json.utf8))
    }
}
#endif
