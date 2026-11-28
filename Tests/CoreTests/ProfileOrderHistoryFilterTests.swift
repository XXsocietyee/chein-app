import XCTest
@testable import QuestifyCore

final class ProfileOrderHistoryFilterTests: XCTestCase {
    private let now = OrderLifecycleTime.date("2026-10-11 12:00:00")!
    private func order(_ fields: String = "") throws -> ProfileOrder {
        try JSONDecoder().decode(ProfileOrder.self, from: Data(("{\"id\":1" + (fields.isEmpty ? "" : "," + fields) + "}").utf8))
    }
    func testNineMiniFiltersInSourceOrder() { XCTAssertEqual(ProfileOrderHistoryFilter.allCases.map(\.rawValue), ["all","pendingPayment","notStarted","inProgress","completed","refunding","refunded","nonRefundable","manualRefund"]) }
    /// Gap #28 (1128 plan): MP order-status.js — money already returned (payout 1 / 4) is terminal and beats 人工售后;
    /// 人工售后 beats every other state.
    func testManualRefundHasHighestPriority() throws {
        XCTAssertEqual(try order(#""manualRefundCaseStatus":"REVIEW","refundApplication":{"payoutStatus":1},"registrationStatus":1"#).historyState(now: now), .refunded)
        XCTAssertEqual(try order(#""manualRefundCaseStatus":"REVIEW","refundApplication":{"payoutStatus":0},"registrationStatus":1"#).historyState(now: now), .manualRefund)
    }
    func testPayoutOneAndFourOnlyAreRefunded() throws {
        for code in [1,4] { XCTAssertEqual(try order("\"refundApplication\":{\"payoutStatus\":\(code),\"refundAmount\":0},\"registrationStatus\":3").historyState(now: now), .refunded) }
        for code in [2,3] { XCTAssertEqual(try order("\"refundApplication\":{\"payoutStatus\":\(code)},\"registrationStatus\":3").historyState(now: now), .refunding) }
    }
    func testCancellationDoesNotImplyRefund() throws { XCTAssertEqual(try order(#""registrationStatus":3"#).historyState(now: now), .cancelled) }
    func testRejectedOrZeroRefundFallsBack() throws {
        for refund in [#"{"status":2,"refundAmount":5}"#, #"{"status":0,"refundAmount":0}"#] { XCTAssertEqual(try order("\"refundApplication\":\(refund),\"registrationStatus\":1").historyState(now: now), .pendingPayment) }
    }
    func testEmptyRefundObjectIsDistinctFromAbsentAndNull() throws {
        XCTAssertEqual(try order(#""refundApplication":{}"#).historyState(now: now), .refunding)
        XCTAssertEqual(try order(#""refundApplication":null"#).historyState(now: now), .unknown)
        XCTAssertEqual(try order().historyState(now: now), .unknown)
    }
    func testQueuedAndApprovedAreRefundingNotRefunded() throws {
        for code in [0,5,6,77] { XCTAssertEqual(try order("\"refundApplication\":{\"status\":1,\"payoutStatus\":\(code),\"refundAmount\":5}").historyState(now: now), .refunding) }
    }
    func testRegistrationPrecedesVerification() throws { XCTAssertEqual(try order(#""registrationStatus":4,"verificationStatus":1"#).historyState(now: now), .expired) }
    func testVerificationCompletesRegisteredOrder() throws { XCTAssertEqual(try order(#""registrationStatus":2,"verificationStatus":1"#).historyState(now: now), .completed) }
    func testFirstScanRequiresPaidAndValidTime() throws {
        XCTAssertEqual(try order(#""registrationStatus":2,"paymentStatus":2,"firstSuccessfulScanAt":"2026-10-10 12:00:00""#).historyState(now: now), .completed)
        for field in [#""paymentStatus":1,"firstSuccessfulScanAt":"2026-10-10""#, #""paymentStatus":2,"firstSuccessfulScanAt":"invalid""#] { XCTAssertEqual(try order(#""registrationStatus":2,"# + field).historyState(now: now), .inProgress) }
    }
    func testFirstScanPrecedesNonRefundable() throws { XCTAssertEqual(try order(#""registrationStatus":2,"paymentStatus":2,"firstSuccessfulScanAt":"2026-10-10","refundInfo":{"refundable":false}"#).historyState(now: now), .completed) }
    func testOnlyExplicitAllZeroAmountsAreFree() throws {
        XCTAssertEqual(try order(#""registrationStatus":2,"totalAmount":0,"payableAmount":0,"refundInfo":{"refundable":false}"#).historyState(now: now), .inProgress)
        for extra in [#""payableAmount":0"#, #""totalAmount":0,"payableAmount":0,"pointPaymentAmount":1"#, #""totalAmount":0,"payableAmount":0,"wechatPaymentAmount":1"#] { XCTAssertEqual(try order(#""registrationStatus":2,"refundInfo":{"refundable":false},"# + extra).historyState(now: now), .nonRefundable) }
    }
    func testTotalZeroLiteralDoesNotAcceptNumericPrefix() throws {
        for value in [#""0invalid""#, #""""#, "null", #""1e-999""#] { XCTAssertFalse(try order("\"totalAmount\":\(value)").historyFacts.totalAmountIsZero) }
        for value in ["0", #"" 0.00 ""#, #""0e9""#] { XCTAssertTrue(try order("\"totalAmount\":\(value)").historyFacts.totalAmountIsZero) }
    }
    func testSourceBusinessStartEndBoundaries() throws {
        let row = try order(#""registrationStatus":2,"cmsTopic":{"startDate":"2026-10-11 12:00:00","endDate":"2026-10-11 13:00:00"}"#)
        XCTAssertEqual(row.historyState(now: now.addingTimeInterval(-1)), .notStarted)
        XCTAssertEqual(row.historyState(now: now), .inProgress)
        XCTAssertEqual(row.historyState(now: now.addingTimeInterval(3600)), .inProgress)
        XCTAssertEqual(row.historyState(now: now.addingTimeInterval(3601)), .completed)
    }
    func testOwnerFallbackAndPrecedence() throws {
        let row = try order(#""registrationStatus":2,"cmsActivity":{"startTime":"2026-10-12","endTime":"2026-10-13"},"cmsTopic":{"startDate":"2020-01-01"}"#)
        XCTAssertEqual(row.historyFacts.start,"2026-10-12"); XCTAssertEqual(row.historyState(now:now),.notStarted)
    }
    func testMissingEndFallsBackToStartAndMissingDatesStayInProgress() throws {
        XCTAssertEqual(try order(#""registrationStatus":2,"cmsTopic":{"startDate":"2026-10-10"}"#).historyState(now:now),.completed)
        XCTAssertEqual(try order(#""registrationStatus":2"#).historyState(now:now),.inProgress)
    }
    func testFilteringPreservesSourceOrderAndUnknownInAll() throws {
        let rows = try JSONDecoder().decode([ProfileOrder].self,from:Data(#"[{"id":8,"registrationStatus":1},{"id":2,"registrationStatus":99},{"id":4,"registrationStatus":1}]"#.utf8))
        XCTAssertEqual(ProfileOrderHistoryFilter.pendingPayment.orders(in:rows,now:now).map(\.id),[8,4])
        XCTAssertEqual(ProfileOrderHistoryFilter.all.orders(in:rows,now:now),rows)
        XCTAssertTrue(ProfileOrderHistoryFilter.refunded.orders(in:rows,now:now).isEmpty)
    }
    func testSelectionRejectsStaleRenderedOwner() {
        let reader = NSObject(); let a = owner(reader,1), b = owner(reader,2); var s = ProfileOrderFilterSelection()
        s.choose(.completed,rendered:a,current:a); XCTAssertEqual(s.value(for:a),.completed)
        XCTAssertEqual(s.value(for:b),.all); s.choose(.refunded,rendered:a,current:b); XCTAssertEqual(s.value(for:b),.all)
    }
    func testReaderReplacementRevocationAndRetirementResetSelection() {
        let reader = NSObject(); let a = owner(reader,1); var s = ProfileOrderFilterSelection(); s.choose(.refunding,rendered:a,current:a)
        let other = NSObject(); XCTAssertEqual(s.value(for:owner(other,1)),.all)
        let denied = ProfileOrderFilterOwner(readerID:ObjectIdentifier(reader),identity:a.identity,isConfigured:false)
        XCTAssertEqual(s.value(for:denied),.all); s.choose(.completed,rendered:denied,current:denied); XCTAssertEqual(s.value(for:denied),.all)
        s.retire(); XCTAssertEqual(s.value(for:a),.all)
    }
    private func owner(_ reader:NSObject,_ account:Int)->ProfileOrderFilterOwner { .init(readerID:ObjectIdentifier(reader),identity:.init(accountID:account,epoch:1),isConfigured:true) }
    func testSourceRowModeAndActualPaidAmount() throws {
        XCTAssertEqual(try order(#""cmsActivity":{"name":"A","productType":2}"#).sourceMode, .cityOrienteering)
        XCTAssertEqual(try order(#""cmsTopic":{"name":"T","productType":2}"#).sourceMode, .freeExplore)
        XCTAssertEqual(try order(#""cmsTopic":{"name":"T","productType":1}"#).sourceMode, .cityOrienteering)
        XCTAssertNil(try order(#""cmsTopic":{"name":"T"}"#).sourceMode)
        XCTAssertNil(try order(#""cmsTopic":{"name":"T","productType":7}"#).sourceMode)
        XCTAssertEqual(try order(#""payableAmount":30,"wechatPaymentAmount":12"#).actualPaidAmount, 12)
        XCTAssertEqual(try order(#""payableAmount":30"#).actualPaidAmount, 30)
        XCTAssertNil(try order().actualPaidAmount)
    }
    func testUnusedSelfPlayPassReadsReadyInsteadOfInProgress() throws {
        let window = #""registrationStatus":2,"paymentStatus":2,"cmsTopic":{"startDate":"2026-10-01","endDate":"2026-12-01"}"#
        let pass = try order(window + #","purchaseKind":2"#)
        XCTAssertTrue(pass.isSelfPlayPass)
        XCTAssertEqual(pass.historyState(now: now), .notStarted)
        XCTAssertTrue(pass.showsUnusedPass(now: now))
        XCTAssertEqual(pass.historyTagKey(now: now), "orderLifecycle.state.passReady")
        XCTAssertEqual(pass.stateNotice(now: now)?.tagKey, "orderLifecycle.state.passReady")
        XCTAssertEqual(pass.stateNotice(now: now)?.titleKey, "orderLifecycle.state.passReady")
        // Gap #28 (order-status.js k7 N6): a pass's first scan only starts the run; it is in progress, not completed.
        let scanned = try order(window + #","purchaseKind":2,"firstSuccessfulScanAt":"2026-10-10 12:00:00""#)
        XCTAssertEqual(scanned.historyState(now: now), .inProgress)
        XCTAssertFalse(scanned.showsUnusedPass(now: now))
        let future = try order(#""registrationStatus":2,"purchaseKind":2,"cmsTopic":{"startDate":"2026-10-20","endDate":"2026-10-21"}"#)
        XCTAssertEqual(future.historyState(now: now), .notStarted)
        XCTAssertFalse(future.showsUnusedPass(now: now))
        XCTAssertEqual(future.historyTagKey(now: now), "orderLifecycle.state.notStarted")
        // U-033: once the server read time is past the start, 可使用 follows it even when the device clock is behind.
        let served = try order(#""registrationStatus":2,"paymentStatus":2,"purchaseKind":2,"serverNow":1792468800000,"cmsTopic":{"startDate":"2026-10-20","endDate":"2026-10-21"}"#)
        XCTAssertEqual(served.historyState(now: now), .notStarted)
        XCTAssertTrue(served.showsUnusedPass(now: now))
        XCTAssertEqual(served.historyTagKey(now: now), "orderLifecycle.state.passReady")
        let zeroTicket = try order(window + #","ownerType":1,"ticketId":0,"expiresAt":"2027-01-01 00:00:00""#)
        XCTAssertEqual(zeroTicket.ticketID, 0)
        XCTAssertTrue(zeroTicket.isSelfPlayPass)
        XCTAssertEqual(zeroTicket.historyTagKey(now: now), "orderLifecycle.state.passReady")
        let zeroScan = try order(window + #","purchaseKind":2,"firstSuccessfulScanAt":0"#)
        XCTAssertEqual(zeroScan.historyFacts.firstSuccessfulScanAt, "0")
        XCTAssertNil(OrderLifecycleTime.date(zeroScan.historyFacts.firstSuccessfulScanAt))
        XCTAssertTrue(zeroScan.showsUnusedPass(now: now))
        let other = try order(window + #","purchaseKind":1"#)
        XCTAssertFalse(other.isSelfPlayPass)
        XCTAssertEqual(other.historyState(now: now), .inProgress)
    }

    /// Gap #28: `summarizeOrderState` (MP utils/order-status.js) rule by rule. now = 2026-10-11 12:00 (+08:00).
    func testOrderStatusJSRuleTable() throws {
        let paid = #""registrationStatus":2,"paymentStatus":2"#
        let cases: [(String, String, OrderLifecycleState)] = [
            ("payout 1 beats manual case", #""manualRefundCaseStatus":"OPEN","refundApplication":{"payoutStatus":4}"#, .refunded),
            ("manual case beats refunding", #""manualRefundCaseStatus":"OPEN","refundApplication":{"status":0,"refundAmount":5}"#, .manualRefund),
            ("refund under review", #""refundApplication":{"status":0,"refundAmount":5},"# + paid, .refunding),
            ("zero refund falls back", #""refundApplication":{"status":0,"refundAmount":0},"registrationStatus":1"#, .pendingPayment),
            ("rejected refund falls back", #""refundApplication":{"status":2,"refundAmount":5},"registrationStatus":3"#, .cancelled),
            ("host cancelled activity", paid + #","cmsActivity":{"cancelTime":"2026-10-09 10:00:00","startDate":"2026-10-20"}"#, .cancelled),
            ("host cancelled (epoch ms)", paid + #","cmsActivity":{"cancelTime":1791511200000}"#, .cancelled),
            ("cancel time on topic is not an activity cancel", paid + #","cmsTopic":{"cancelTime":"2026-10-09 10:00:00","startDate":"2026-10-20"}"#, .notStarted),
            ("pending payment", #""registrationStatus":1"#, .pendingPayment),
            ("closed", #""registrationStatus":3"#, .cancelled),
            ("expired", #""registrationStatus":4"#, .expired),
            ("unknown status", #""registrationStatus":9"#, .unknown),
            ("explore active before start", paid + #","exploreProgress":{"redeemed":1,"required":3,"active":true},"cmsTopic":{"startDate":"2026-10-12"}"#, .notStarted),
            ("explore active beats verified", paid + #","verificationStatus":1,"exploreProgress":{"redeemed":1,"required":3,"active":true}"#, .inProgress),
            ("explore with required 0 is ignored", paid + #","verificationStatus":1,"exploreProgress":{"redeemed":0,"required":0,"active":true}"#, .completed),
            ("verified", paid + #","verificationStatus":1"#, .completed),
            ("topic completed", paid + #","topicCompleted":true,"cmsTopic":{"startDate":"2026-10-20"}"#, .completed),
            ("ticket first scan", paid + #","firstSuccessfulScanAt":"2026-10-10 09:00:00""#, .completed),
            ("pass first scan is in progress", paid + #","purchaseKind":2,"firstSuccessfulScanAt":"2026-10-10 09:00:00""#, .inProgress),
            ("non refundable paid ticket", paid + #","refundInfo":{"refundable":false}"#, .nonRefundable),
            ("non refundable never on a pass", paid + #","purchaseKind":2,"refundInfo":{"refundable":false}"#, .notStarted),
            ("date-only end covers the whole day", paid + #","cmsTopic":{"startDate":"2026-10-11","endDate":"2026-10-11"}"#, .inProgress),
            ("ended yesterday", paid + #","cmsTopic":{"startDate":"2026-10-10","endDate":"2026-10-10"}"#, .completed),
            ("pass ends by expiresAt, not the topic end", paid + #","purchaseKind":2,"expiresAt":"2026-10-11 11:00:00","firstSuccessfulScanAt":"2026-10-10 09:00:00","cmsTopic":{"endDate":"2026-12-01"}"#, .completed),
            ("pass ignores the topic end", paid + #","purchaseKind":2,"expiresAt":"2026-12-01 00:00:00","firstSuccessfulScanAt":"2026-10-10 09:00:00","cmsTopic":{"endDate":"2026-10-01"}"#, .inProgress),
            ("not started", paid + #","cmsActivity":{"startDate":"2026-10-11 13:00:00"}"#, .notStarted),
            ("unused pass is usable", paid + #","purchaseKind":2"#, .notStarted),
            ("in progress", paid, .inProgress),
        ]
        for (name, fields, expected) in cases {
            XCTAssertEqual(try order(fields).historyState(now: now), expected, name)
        }
    }

    /// U-033: the read's `serverNow` decides the time-based tag, not the device clock.
    func testServerNowWinsOverTheDeviceClock() throws {
        let row = try order(#""registrationStatus":2,"cmsActivity":{"startDate":"2026-10-11 13:00:00","endDate":"2026-10-11 14:00:00"},"serverNow":1791696600000"#)
        XCTAssertEqual(row.historyFacts.serverNow, Date(timeIntervalSince1970: 1_791_696_600))
        XCTAssertEqual(row.historyState(now: now), .inProgress, "server says 13:30 although the phone says 12:00")
        XCTAssertEqual(ProfileOrderHistoryClock.end("2026-10-11"), OrderLifecycleTime.date("2026-10-11")?.addingTimeInterval(86_399.999))
        XCTAssertEqual(ProfileOrderHistoryClock.end("2026-10-11 10:00:00"), OrderLifecycleTime.date("2026-10-11 10:00:00"))
    }
}
