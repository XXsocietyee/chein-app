#if DEBUG
import Foundation
import XCTest
@testable import QuestifyCore

/// Synthetic, in-memory registration boundary. No endpoint, credential or payment exists here.
@MainActor
private final class ParitySliceService: RegistrationCoordinatingService {
    var quoteJSON = #"{"payAmount":12.5,"pointsUsable":true,"quoteSign":"parity-fixture-sign"}"#
    var createError: Error?
    private(set) var quotes: [RegistrationQuoteRequest] = []
    private(set) var creates: [RegistrationCreateIntent] = []
    private(set) var reads: [Int] = []
    func quote(_ selection: RegistrationQuoteRequest, token: String) async throws -> RegistrationQuote {
        quotes.append(selection)
        return try JSONDecoder().decode(RegistrationQuote.self, from: Data(quoteJSON.utf8))
    }
    func create(_ intent: RegistrationCreateIntent, token: String) async throws -> RegistrationCreateResult {
        creates.append(intent)
        if let createError { throw createError }
        return try JSONDecoder().decode(RegistrationCreateResult.self, from: Data(#"{"registrationId":41,"payableAmount":12.5}"#.utf8))
    }
    func readStatus(registrationID: Int, token: String) async throws -> RegistrationStatusSnapshot {
        reads.append(registrationID)
        return try JSONDecoder().decode(RegistrationStatusSnapshot.self, from: Data(#"{"id":41,"registrationStatus":1,"paymentStatus":1}"#.utf8))
    }
}

@MainActor
private final class ParityOrderReader: ProfileReading {
    var identity: ProfileReadIdentity? = .init(accountID: 1, epoch: 1)
    var isConfigured = true
    var orders: [ProfileOrder] = []
    private(set) var orderListReads = 0
    func profileOrders() async throws -> [ProfileOrder] { orderListReads += 1; return orders }
    func profileOrder(id: Int) async throws -> ProfileOrder { throw APIError.invalidRequest }
    func profileParticipants() async throws -> [ProfileParticipant] { [] }
    func profileParticipant(id: Int) async throws -> ProfileParticipant { throw APIError.invalidRequest }
    func profileBadges() async throws -> ProfileBadgeWall { .init(identities: [], medals: []) }
}

@MainActor
final class ActivityRegistrationParityW206Tests: XCTestCase {
    private func detail(_ fields: String) throws -> ActivityDetail {
        try JSONDecoder().decode(ActivityDetail.self, from: Data("{\"id\":7,\"name\":\"Parity fixture\"\(fields)}".utf8))
    }
    private func quote(_ json: String) throws -> RegistrationQuote {
        try JSONDecoder().decode(RegistrationQuote.self, from: Data(json.utf8))
    }
    private func order(id: Int, member: Int = 1, owner: Int = 7, ticket: Int = 11, type: Int = 2) throws -> ProfileOrder {
        try JSONDecoder().decode(ProfileOrder.self, from: Data("""
        {"id":\(id),"memberId":\(member),"ownerType":\(type),"ownerId":\(owner),"ticketId":\(ticket),"registrationStatus":1,"paymentStatus":0}
        """.utf8))
    }
    private func makeFlow(_ service: ParitySliceService, policy: RegistrationUICreationPolicy? = .offlineFixture,
                          identity: @escaping () -> ProfileReadIdentity? = { .init(accountID: 1, epoch: 1) },
                          onReadback: @escaping (RegistrationStatusSnapshot) -> Void = { _ in }) throws -> RegistrationUIFlow {
        let coordinator = RegistrationCoordinator(service: service, makeRequestID: { "parity-fixture-intent" })
        try coordinator.setAccount(id: 1, token: "fixture-only-token")
        let activity = try detail(#","omsTicketList":[{"id":11,"name":"Parity ticket","price":12.5,"remainingInventory":3}]"#)
        if let policy {
            return RegistrationUIFlow(activity: activity, coordinator: coordinator, currentIdentity: identity,
                                      quoteEnabled: true, creationPolicy: policy, onReadback: onReadback)
        }
        return RegistrationUIFlow(activity: activity, coordinator: coordinator, currentIdentity: identity,
                                  quoteEnabled: true, onReadback: onReadback)
    }
    private func ready(_ flow: RegistrationUIFlow) async {
        flow.open(); flow.setName("Parity Person"); flow.setPhone("13800000000")
        flow.setConsent(true); await flow.requestQuote()
    }

    // MARK: Activity detail header (分类 / 集合点 / 已报名)

    func testCategoryTextJoinsSourceNamesAndKeepsMissingUnconfirmed() throws {
        let joined = ActivityDetailHeaderFacts(detail: try detail(#","sysCategoryList":[{"categoryName":"City walk"},{"categoryName":"  "},{"categoryName":"Puzzle"},{"categoryId":3}]"#))
        XCTAssertEqual(joined.categoryText, "City walk · Puzzle")
        XCTAssertNil(ActivityDetailHeaderFacts(detail: try detail("")).categoryText)
        XCTAssertNil(ActivityDetailHeaderFacts(detail: try detail(#","sysCategoryList":[]"#)).categoryText)
    }

    func testMeetingPointFollowsSourcePrecedenceAndNeverInventsAPlace() throws {
        XCTAssertEqual(ActivityDetailHeaderFacts(detail: try detail(#","addressName":" Gate A ","address":"1 Road""#)).meetingPoint, .named("Gate A"))
        XCTAssertEqual(ActivityDetailHeaderFacts(detail: try detail(#","addressName":" ","address":"1 Road""#)).meetingPoint, .named("1 Road"))
        XCTAssertEqual(ActivityDetailHeaderFacts(detail: try detail(#","latitude":30.1,"longitude":120.2"#)).meetingPoint, .mapOnly)
        XCTAssertEqual(ActivityDetailHeaderFacts(detail: try detail(#","latitude":300,"longitude":120.2"#)).meetingPoint, .unconfirmed)
        XCTAssertEqual(ActivityDetailHeaderFacts(detail: try detail("")).meetingPoint, .unconfirmed)
    }

    func testRegistrationCountIsSourceTotalAndUnknownIsNotZero() throws {
        XCTAssertEqual(ActivityDetailHeaderFacts(detail: try detail(#","registrationCount":12,"registrationList":[{"id":1,"memberId":2,"nickname":"A"}]"#)).registrationCount, 12)
        XCTAssertNil(ActivityDetailHeaderFacts(detail: try detail(#","registrationList":[{"id":1,"memberId":2,"nickname":"A"}]"#)).registrationCount)
        XCTAssertNil(ActivityDetailHeaderFacts(detail: try detail(#","registrationCount":-1"#)).registrationCount)
        XCTAssertEqual(ActivityDetailHeaderFacts(detail: try detail(#","registrationCount":0"#)).registrationCount, 0)
    }

    func testSourceDetailSectionOrderPlacesMetaBetweenCancellationAndAbout() throws {
        let order = ActivityDetailSourceSection.allCases
        XCTAssertEqual(order.first, .header)
        XCTAssertLessThan(try XCTUnwrap(order.firstIndex(of: .cancelled)), try XCTUnwrap(order.firstIndex(of: .meta)))
        XCTAssertLessThan(try XCTUnwrap(order.firstIndex(of: .meta)), try XCTUnwrap(order.firstIndex(of: .about)))
        XCTAssertLessThan(try XCTUnwrap(order.firstIndex(of: .about)), try XCTUnwrap(order.firstIndex(of: .tickets)))
    }

    // MARK: Checkout (结算) facts

    func testAlreadyRegisteredBannerRequiresExactSourceFlag() throws {
        XCTAssertTrue(RegistrationCheckoutFacts(activity: try detail(#","isSignUp":1"#), ticket: nil).viewerAlreadyRegistered)
        for fields in ["", #","isSignUp":0"#, #","isSignUp":"1""#, #","isSignUp":2"#, #","isSignUp":null"#] {
            XCTAssertFalse(RegistrationCheckoutFacts(activity: try detail(fields), ticket: nil).viewerAlreadyRegistered, fields)
        }
    }

    func testTicketMeetingPointVenueAndOrderAmountStayUnknownWhenAbsent() throws {
        let activity = try detail(#","addressName":"Venue name","address":"Venue address","omsTicketList":[{"id":11,"name":"A","price":18,"meetingPoint":" North gate "},{"id":12,"name":"B","price":null,"meetingPoint":"  "},{"id":13,"name":"C","meetingPoint":5}]"#)
        XCTAssertEqual(activity.tickets.count, 3, "A malformed optional meeting point must not drop a ticket")
        let first = RegistrationCheckoutFacts(activity: activity, ticket: activity.tickets[0])
        XCTAssertEqual(first.meetingPoint, "North gate")
        XCTAssertEqual(first.venue, "Venue address", "Checkout source prefers address over addressName")
        XCTAssertEqual(first.orderAmount, Decimal(18))
        let second = RegistrationCheckoutFacts(activity: activity, ticket: activity.tickets[1])
        XCTAssertNil(second.meetingPoint); XCTAssertNil(second.orderAmount)
        XCTAssertNil(RegistrationCheckoutFacts(activity: activity, ticket: activity.tickets[2]).meetingPoint)
        let bare = RegistrationCheckoutFacts(activity: try detail(""), ticket: nil)
        XCTAssertNil(bare.venue); XCTAssertNil(bare.orderAmount); XCTAssertNil(bare.meetingPoint)
        XCTAssertEqual(RegistrationCheckoutFacts(activity: try detail(#","addressName":"Only name""#), ticket: nil).venue, "Only name")
    }

    func testClubBenefitUsesOnlyExplicitQuoteFields() throws {
        XCTAssertEqual(RegistrationCheckoutClubBenefit.from(try quote(#"{"payAmount":10,"memberDiscountYuan":2.5,"prioritySignupEnabled":true,"quoteSign":"s"}"#)), .discount(Decimal(string: "2.5")!))
        XCTAssertEqual(RegistrationCheckoutClubBenefit.from(try quote(#"{"payAmount":10,"memberDiscountYuan":0,"prioritySignupEnabled":true,"clubMember":true,"quoteSign":"s"}"#)), .priorityActive)
        XCTAssertEqual(RegistrationCheckoutClubBenefit.from(try quote(#"{"payAmount":10,"prioritySignupEnabled":true,"quoteSign":"s"}"#)), .priorityReserved)
        XCTAssertNil(RegistrationCheckoutClubBenefit.from(try quote(#"{"payAmount":10,"quoteSign":"s"}"#)))
        let malformed = try quote(#"{"payAmount":10,"prioritySignupEnabled":"true","clubMember":true,"quoteSign":"s"}"#)
        XCTAssertFalse(malformed.prioritySignupEnabled)
        XCTAssertNil(RegistrationCheckoutClubBenefit.from(malformed))
        XCTAssertEqual(RegistrationCheckoutClubBenefit.priorityActive.noteKey, "registrationParity.clubPriorityActive")
        XCTAssertEqual(RegistrationCheckoutClubBenefit.priorityReserved.noteKey, "registrationParity.clubPriorityReserved")
        XCTAssertNil(RegistrationCheckoutClubBenefit.discount(1).noteKey)
    }

    func testCheckoutSectionOrderMatchesSource() {
        XCTAssertEqual(RegistrationCheckoutSection.allCases,
                       [.alreadyRegistered, .participants, .activity, .ticket, .fees, .waitlist, .confirmation])
        XCTAssertEqual(RegistrationCheckoutFacts.sourceTitleKey, "registrationParity.title")
    }

    // MARK: discover → detail → quote → registration → order-status slice

    func testConfirmAndReadBackCreatesOnceAndReadsReturnedIDOnce() async throws {
        let service = ParitySliceService()
        var snapshots: [RegistrationStatusSnapshot] = []
        let flow = try makeFlow(service, onReadback: { snapshots.append($0) })
        await ready(flow)
        XCTAssertEqual(service.quotes.count, 1)
        await flow.confirmAndReadBack()
        XCTAssertTrue(service.creates.isEmpty, "Creation requires an explicit prepared review first")
        XCTAssertTrue(service.reads.isEmpty)
        XCTAssertTrue(flow.prepareConfirmation())
        await flow.confirmAndReadBack()
        XCTAssertEqual(service.creates.count, 1)
        XCTAssertEqual(service.creates.first?.requestID, "parity-fixture-intent")
        XCTAssertEqual(service.reads, [41])
        XCTAssertEqual(snapshots.map(\.registrationID), [41])
        guard case .responseReceived(let requestID, _) = flow.creationState else { return XCTFail("Expected create receipt") }
        XCTAssertEqual(requestID, "parity-fixture-intent")
        XCTAssertEqual(flow.coordinator.retainedIntent?.requestID, requestID)
        guard case .received(let snapshot) = flow.readbackState else { return XCTFail("Expected authoritative readback") }
        XCTAssertEqual(snapshot.registrationStatus, 1)
        // A repeated confirmation neither creates again nor re-reads the earlier intent.
        XCTAssertFalse(flow.prepareConfirmation())
        await flow.confirmAndReadBack()
        XCTAssertEqual(service.creates.count, 1); XCTAssertEqual(service.reads, [41])
        // Reopening keeps the same request identity and lock.
        flow.leave(); flow.open()
        XCTAssertEqual(flow.coordinator.retainedIntent?.requestID, "parity-fixture-intent")
        XCTAssertFalse(flow.canEdit)
    }

    func testCreationStaysDisabledByDefaultAndForDisabledPolicy() async throws {
        for policy in [nil, RegistrationUICreationPolicy.disabled] {
            let service = ParitySliceService()
            let flow = try makeFlow(service, policy: policy)
            XCTAssertEqual(flow.creationPolicy, .disabled)
            XCTAssertFalse(flow.creationPolicy.permitsCreation)
            await ready(flow)
            XCTAssertFalse(flow.consented, "Consent cannot be recorded while creation is disabled")
            XCTAssertEqual(flow.confirmationBlock, .creationDisabled)
            XCTAssertFalse(flow.prepareConfirmation())
            await flow.confirmAndReadBack()
            XCTAssertTrue(service.creates.isEmpty); XCTAssertTrue(service.reads.isEmpty)
        }
    }

    func testUnknownOutcomeStaysLockedAndOnlyReadsOwnedOrders() async throws {
        let service = ParitySliceService(); service.createError = URLError(.timedOut)
        let reader = ParityOrderReader()
        let flow = try makeFlow(service, identity: { reader.identity })
        let before = try await flow.uncertainOutcomeEvidence(orders: reader)
        XCTAssertEqual(before, .notApplicable); XCTAssertEqual(reader.orderListReads, 0)
        await ready(flow); XCTAssertTrue(flow.prepareConfirmation())
        await flow.confirmAndReadBack()
        guard case .outcomeUnknown(let requestID, _) = flow.creationState else { return XCTFail("Timeout must stay unknown") }
        XCTAssertEqual(requestID, "parity-fixture-intent")
        XCTAssertTrue(service.reads.isEmpty, "No registration ID exists to read")
        reader.orders = [try order(id: 40), try order(id: 44), try order(id: 45, member: 2),
                         try order(id: 46, owner: 8), try order(id: 47, ticket: 12), try order(id: 48, type: 1)]
        let evidence = try await flow.uncertainOutcomeEvidence(orders: reader)
        XCTAssertEqual(evidence, .matchingOrders([44, 40]))
        reader.orders = []
        let empty = try await flow.uncertainOutcomeEvidence(orders: reader)
        XCTAssertEqual(empty, .noMatchingOrder)
        XCTAssertEqual(reader.orderListReads, 2)
        // Evidence never unlocks or replays the retained intent.
        XCTAssertEqual(service.creates.count, 1)
        XCTAssertFalse(flow.prepareConfirmation()); await flow.confirmAndReadBack()
        XCTAssertEqual(service.creates.count, 1)
        XCTAssertEqual(flow.coordinator.retainedIntent?.requestID, "parity-fixture-intent")
        // A different reader account is not applicable and performs no read.
        let other = ParityOrderReader(); other.identity = .init(accountID: 2, epoch: 1)
        let mismatched = try await flow.uncertainOutcomeEvidence(orders: other)
        XCTAssertEqual(mismatched, .notApplicable); XCTAssertEqual(other.orderListReads, 0)
    }

    func testUncertainOutcomeMatcherRequiresOwnerTicketAndMember() throws {
        let selection = try RegistrationQuoteRequest(ownerID: 7, ticketID: 11)
        let intent = try RegistrationCreateIntent(selection: selection, quote: try quote(#"{"payAmount":1,"quoteSign":"s"}"#),
                                                  realName: "Parity Person", phone: "13800000000", requestID: "parity-matcher")
        let rows = [try order(id: 3), try order(id: 3), try order(id: 9, member: 4)]
        XCTAssertEqual(RegistrationUncertainOutcomeEvidence.match(orders: rows, intent: intent, accountID: 1), .matchingOrders([3]))
        XCTAssertEqual(RegistrationUncertainOutcomeEvidence.match(orders: [], intent: intent, accountID: 1), .noMatchingOrder)
    }

    // MARK: W4 Core Loop Business Rules (Four-Shop Policy, Limits, Quotas, Funds, Ownership, 24h Non-Refundable, Ticket & Refund)

    func testFourShopFixedCompensationStopsNewSalesWhileSoldContractsContinueFulfillment() {
        XCTAssertTrue(FourShopCompensationPolicy.requiresFourStoreContract(productType: 2, evidenceRule: "FOUR_STORE_REDEEM"))
        XCTAssertTrue(FourShopCompensationPolicy.requiresFourStoreContract(productType: 2, evidenceRule: " four_store_redeem "))
        XCTAssertTrue(FourShopCompensationPolicy.requiresFourStoreContract(productType: 2, evidenceRule: nil, requiresFourStoreContractFlag: true))
        XCTAssertFalse(FourShopCompensationPolicy.requiresFourStoreContract(productType: 1, evidenceRule: "FOUR_STORE_REDEEM"))
        XCTAssertFalse(FourShopCompensationPolicy.requiresFourStoreContract(productType: 2, evidenceRule: "SINGLE_STORE"))

        let finalization = FourShopCompensationPolicy.evaluateNewSaleFinalization(productType: 2, evidenceRule: "FOUR_STORE_REDEEM")
        XCTAssertEqual(
            finalization,
            .failure(.fourShopFixedCompensationStoppedNewSale(message: "四店固定补偿产品已停止新开售，已售合同继续履行"))
        )

        let ticketSale = FourShopCompensationPolicy.evaluateNewTicketSale(productType: 2, evidenceRule: "FOUR_STORE_REDEEM")
        XCTAssertEqual(
            ticketSale,
            .failure(.fourShopFixedCompensationStoppedNewTicketSale(message: "四店固定补偿产品已停止新售票，已售合同继续履行"))
        )

        let soldContract = FourShopCompensationPolicy.evaluateSoldContractFulfillment(
            registrationStatus: 2,
            paymentStatus: 2,
            verificationStatus: 0,
            productType: 2,
            evidenceRule: "FOUR_STORE_REDEEM"
        )
        XCTAssertTrue(soldContract.isSoldContract)
        XCTAssertTrue(soldContract.requiresFourStoreContract)
        XCTAssertTrue(soldContract.continuesFulfillment)
        XCTAssertTrue(soldContract.allowsDynamicQRPass)
        XCTAssertTrue(soldContract.allowsEntitlementRedemption)
        XCTAssertEqual(soldContract.fulfillmentNotice, "已售合同继续履行")

        let cancelledContract = FourShopCompensationPolicy.evaluateSoldContractFulfillment(
            registrationStatus: 3,
            paymentStatus: 3,
            verificationStatus: 0,
            productType: 2,
            evidenceRule: "FOUR_STORE_REDEEM"
        )
        XCTAssertFalse(cancelledContract.continuesFulfillment)
        XCTAssertFalse(cancelledContract.allowsDynamicQRPass)
    }

    func testExplorePassAndRegistrationLimitsQuotasFundsAndOwnershipRules() {
        // 1. Four-shop stop-sale gate inside RegistrationCoreLoopRules.validate
        let fourShopCtx = RegistrationCoreLoopRules.RegistrationRuleContext(
            productType: 2,
            ticketType: "EXPLORE_PASS",
            evidenceRule: "FOUR_STORE_REDEEM"
        )
        XCTAssertEqual(
            RegistrationCoreLoopRules.validate(fourShopCtx),
            .failure(.fourShopFixedCompensationStoppedNewTicketSale(message: "四店固定补偿产品已停止新售票，已售合同继续履行"))
        )

        // 2. Explore Pass per-order limit = 1
        let overOrderLimit = RegistrationCoreLoopRules.RegistrationRuleContext(
            productType: 2,
            ticketType: "EXPLORE_PASS",
            quantity: 2
        )
        XCTAssertEqual(
            RegistrationCoreLoopRules.validate(overOrderLimit),
            .failure(.explorePassOrderLimitExceeded(message: "探索票每单限购 1 张"))
        )

        // 3. Explore Pass points forbidden
        let pointsOnExplore = RegistrationCoreLoopRules.RegistrationRuleContext(
            productType: 2,
            ticketType: "EXPLORE_PASS",
            quantity: 1,
            usePoints: true
        )
        XCTAssertEqual(
            RegistrationCoreLoopRules.validate(pointsOnExplore),
            .failure(.explorePassPointsForbidden(message: "探店日不支持积分抵扣，请关闭积分后按全价购买"))
        )

        // 4. Explore Pass per-account live ticket limit = 1
        let accountLimitReached = RegistrationCoreLoopRules.RegistrationRuleContext(
            productType: 2,
            ticketType: "EXPLORE_PASS",
            quantity: 1,
            existingLiveExploreTicketsForTopic: 1
        )
        XCTAssertEqual(
            RegistrationCoreLoopRules.validate(accountLimitReached),
            .failure(.explorePassAccountLimitReached(
                code: "SHOP_DAY_ACCOUNT_TICKET_LIMIT_REACHED",
                message: "当前账号已持有该主题的有效探索票，不能重复购买"
            ))
        )

        // 5. Explore Pass cross-club session forbidden
        let crossClub = RegistrationCoreLoopRules.RegistrationRuleContext(
            productType: 2,
            ticketType: "EXPLORE_PASS",
            topicClubID: 10,
            sessionClubID: 20
        )
        XCTAssertEqual(
            RegistrationCoreLoopRules.validate(crossClub),
            .failure(.explorePassCrossClubForbidden(message: "自由探索只开放内容所属俱乐部的场次，不能跨俱乐部售票"))
        )

        // 6. Collectible / Second-clearing ownership gate (#22 二清闸)
        let nonPlatformPaid = RegistrationCoreLoopRules.RegistrationRuleContext(
            productType: 1,
            isPlatformOwned: false,
            payableAmount: Decimal(38)
        )
        XCTAssertEqual(
            RegistrationCoreLoopRules.validate(nonPlatformPaid),
            .failure(.nonPlatformPaidProductBlocked(
                message: "该产品暂不支持在线支付(平台正在办理支付资质,预计 2 个月内开放);如需报名请联系主办方"
            ))
        )

        // Free non-platform activity is allowed
        let nonPlatformFree = RegistrationCoreLoopRules.RegistrationRuleContext(
            productType: 1,
            isPlatformOwned: false,
            payableAmount: .zero
        )
        XCTAssertEqual(RegistrationCoreLoopRules.validate(nonPlatformFree), .success(()))

        // 7. Club membership & reserved quota gate
        let clubRequired = RegistrationCoreLoopRules.RegistrationRuleContext(
            activityClubID: 88,
            requiresClubMembership: true,
            viewerIsHost: false,
            viewerIsClubMember: false
        )
        XCTAssertEqual(
            RegistrationCoreLoopRules.validate(clubRequired),
            .failure(.clubMembershipRequired(message: "请先加入俱乐部再报名"))
        )

        let reservedProtected = RegistrationCoreLoopRules.RegistrationRuleContext(
            activityClubID: 88,
            requiresClubMembership: false,
            viewerIsHost: false,
            viewerIsClubMember: false,
            remainingInventory: 3,
            memberReservedQuota: 3
        )
        XCTAssertEqual(
            RegistrationCoreLoopRules.validate(reservedProtected),
            .failure(.memberReservedQuotaProtected(message: "剩余名额已为俱乐部会员保留"))
        )
    }

    func testOrderLevelPointsCapAnd24hNonRefundableQuoteRules() throws {
        // Order-level points cap is 50 yuan per order (never 50 * quantity)
        let computed = RegistrationCoreLoopRules.computeOrderPrice(
            unitPrice: Decimal(100),
            quantity: 2,
            memberDiscountRate: Decimal(string: "0.9"),
            couponDeductYuan: Decimal(10),
            usePoints: true,
            pointsUsableForProduct: true,
            userAvailablePoints: 10_000,
            pointDeductRate: Decimal(string: "0.01"),
            maxPointsDeductPerOrderYuan: 50
        )
        XCTAssertEqual(computed.orderTotalYuan, Decimal(200))
        XCTAssertEqual(computed.memberDiscountYuan, Decimal(20))
        XCTAssertEqual(computed.couponDeductYuan, Decimal(10))
        XCTAssertEqual(computed.pointsDeductYuan, Decimal(50))
        XCTAssertEqual(computed.pointsUsed, 5_000)
        XCTAssertEqual(computed.payAmount, Decimal(120))

        // 24h non-refundable quote decoding & confirmation requirement
        let nonRefundablePaid = try quote(#"{"payAmount":68,"pointsUsable":false,"refundableNow":false,"refundDeadline":"2026-11-08 14:00:00","quoteSign":"sig-1"}"#)
        XCTAssertEqual(nonRefundablePaid.refundableNow, false)
        XCTAssertEqual(nonRefundablePaid.refundDeadline, "2026-11-08 14:00:00")
        XCTAssertTrue(nonRefundablePaid.requiresNonRefundableConfirmation)
        XCTAssertEqual(NonRefundable24hNotice.feeRowNotice(for: nonRefundablePaid), "该场次已过集合前 24 小时退款截止时间，本单不可退")

        let nonRefundableZeroPay = try quote(#"{"payAmount":0,"pointsUsable":true,"refundableNow":false,"quoteSign":"sig-2"}"#)
        XCTAssertFalse(nonRefundableZeroPay.requiresNonRefundableConfirmation)
        XCTAssertNil(NonRefundable24hNotice.feeRowNotice(for: nonRefundableZeroPay))

        let refundableQuote = try quote(#"{"payAmount":68,"pointsUsable":true,"refundableNow":true,"refundDeadline":"2026-11-08 14:00:00","quoteSign":"sig-3"}"#)
        XCTAssertFalse(refundableQuote.requiresNonRefundableConfirmation)
        XCTAssertEqual(NonRefundable24hNotice.feeRowNotice(for: refundableQuote), "集合前 24 小时可退（截止 11-08 14:00）")

        // Points auto-disable evaluation
        let disableNoSupport = RegistrationCoreLoopRules.pointsAutoDisableEvaluation(
            usePoints: true,
            quote: nonRefundablePaid,
            userAvailablePoints: 500
        )
        XCTAssertTrue(disableNoSupport.shouldDisable)
        XCTAssertEqual(disableNoSupport.notice, "该票不支持积分抵扣")

        let disableZeroBalance = RegistrationCoreLoopRules.pointsAutoDisableEvaluation(
            usePoints: true,
            quote: nonRefundablePaid,
            userAvailablePoints: 0
        )
        XCTAssertTrue(disableZeroBalance.shouldDisable)
        XCTAssertEqual(disableZeroBalance.notice, "暂无可用积分")
    }

    func testTicketWindowSessionSortingOrderRebuildAndExpiryRefundRules() throws {
        let activity = try detail(#","omsTicketList":[{"id":1,"name":"晚场","price":68,"startTime":"2026-11-10 19:00:00","endTime":"2026-11-10 21:00:00"},{"id":2,"name":"早场","price":58,"startTime":"2026-11-10 09:00:00","endTime":"2026-11-10 11:00:00"},{"id":3,"name":"已开场","price":48,"startTime":"2026-11-01 09:00:00","endTime":"2026-11-01 11:00:00"}]"#)
        let now = try XCTUnwrap(TicketWindowRule.parseTicketDate("2026-11-05 12:00:00"))
        let selectable = TicketWindowRule.selectableSessionTickets(activity.tickets, now: now)
        XCTAssertEqual(selectable.map(\.id), [2, 1])
        XCTAssertEqual(TicketWindowRule.sessionOptionLabel(for: selectable[0]), "早场 · 11-10 09:00 · ¥58")
        XCTAssertEqual(TicketWindowRule.state(for: activity.tickets[2], now: now), .ended)

        // Checkout order rebuild classification
        XCTAssertEqual(
            CheckoutOrderRebuildRule.classifyPayFailure(code: 410, message: "订单已过期"),
            .rebuildExpiredPayOrder(userMessage: "订单已过期,请重新报名")
        )
        XCTAssertEqual(
            CheckoutOrderRebuildRule.classifyCreateFailure(code: 409, message: "该幂等键对应的报名已取消"),
            .rebuildTerminalIdempotencyConflict
        )
        XCTAssertEqual(
            CheckoutOrderRebuildRule.classifyCreateFailure(code: 409, message: "报价签名已失效"),
            .refreshQuoteAndReconfirm(userMessage: "价格已更新，请重新确认")
        )

        // Ticket expiry and order refund payout summary
        XCTAssertEqual(TicketExpiryAndOrderStatusRules.passExpiryText(validUntil: "2026-11-05 20:00:00", now: now), "今天过期")
        XCTAssertEqual(TicketExpiryAndOrderStatusRules.passExpiryText(validUntil: "2026-11-08 20:00:00", now: now), "3 天内过期")
        XCTAssertEqual(TicketExpiryAndOrderStatusRules.passExpiryText(validUntil: "2026-11-20 20:00:00", now: now), "")

        XCTAssertEqual(
            TicketExpiryAndOrderStatusRules.payoutSummary(status: 1, payoutStatus: 4),
            .init(label: "已退款", hint: "退款已原路退回", canCancelRefundApplication: false)
        )
        XCTAssertEqual(
            TicketExpiryAndOrderStatusRules.payoutSummary(status: 0, payoutStatus: nil),
            .init(label: "退款审核中", hint: "退款申请已提交，等待平台审核", canCancelRefundApplication: true)
        )
        XCTAssertTrue(
            TicketExpiryAndOrderStatusRules.canRequestOrderRefund(
                registrationStatus: 2,
                paymentStatus: 2,
                verificationStatus: 0,
                refundable: true
            )
        )
        XCTAssertFalse(
            TicketExpiryAndOrderStatusRules.canRequestOrderRefund(
                registrationStatus: 2,
                paymentStatus: 2,
                verificationStatus: 1,
                refundable: true
            )
        )
    }
}
#endif
