#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

/// Encodes the mini-program / Java behavior for money-critical rules (docs/parity/logic-parity-money.md).
final class MoneyParityRulesTests: XCTestCase {
    // 2026-11-07 00:00:00 Asia/Shanghai
    private let nov7 = Int64(1_793_980_800_000)

    // MARK: toTimestamp
    func testBareStringIsChinaTime() {
        XCTAssertEqual(MoneyParityTime.timestamp("2026-11-07 00:00:00"), nov7)
        XCTAssertEqual(MoneyParityTime.timestamp("2026/11/07"), nov7)
        XCTAssertEqual(MoneyParityTime.timestamp("2026-11-07T00:00"), nov7)
        XCTAssertEqual(MoneyParityTime.timestamp("  2026-11-07 00:00:00  "), nov7)
    }

    func testOffsetIsoIsNotReanchored() {
        XCTAssertEqual(MoneyParityTime.timestamp("2026-11-07T00:00:00Z"), 1_794_009_600_000)
        XCTAssertEqual(MoneyParityTime.timestamp("2026-11-07 00:00:00+08:00"), nov7)
        XCTAssertEqual(MoneyParityTime.timestamp("2026-11-07T00:00:00+0800"), nov7)
        XCTAssertEqual(MoneyParityTime.timestamp("2026-11-06T19:00:00-05:00"), 1_794_009_600_000)
    }

    func testEpochStrings() {
        XCTAssertEqual(MoneyParityTime.timestamp("1794009600"), 1_794_009_600_000)
        XCTAssertEqual(MoneyParityTime.timestamp("1794009600000"), 1_794_009_600_000)
        XCTAssertEqual(MoneyParityTime.timestamp(number: 1_794_009_600), 1_794_009_600_000)
        XCTAssertEqual(MoneyParityTime.timestamp(number: 1_794_009_600_000), 1_794_009_600_000)
    }

    func testInvalidFailsClosed() {
        XCTAssertNil(MoneyParityTime.timestamp(nil))
        XCTAssertNil(MoneyParityTime.timestamp(""))
        XCTAssertNil(MoneyParityTime.timestamp("0"))
        XCTAssertNil(MoneyParityTime.timestamp("2026-02-30 10:00:00"))
        XCTAssertNil(MoneyParityTime.timestamp("2026-13-01"))
        XCTAssertNil(MoneyParityTime.timestamp("2026-11-07 24:00:00"))
        XCTAssertNil(MoneyParityTime.timestamp("2026-11-07 10:60:00"))
        XCTAssertNil(MoneyParityTime.timestamp("not a date"))
        XCTAssertNil(MoneyParityTime.timestamp(number: 0))
        XCTAssertNil(MoneyParityTime.timestamp(number: .nan))
        XCTAssertNil(MoneyParityTime.timestamp(number: .infinity))
    }

    func testLeapDay() {
        XCTAssertNotNil(MoneyParityTime.timestamp("2028-02-29"))
        XCTAssertNil(MoneyParityTime.timestamp("2027-02-29"))
        XCTAssertNil(MoneyParityTime.timestamp("2100-02-29"))
        XCTAssertNotNil(MoneyParityTime.timestamp("2000-02-29"))
    }

    // MARK: ticket window
    private let start = Int64(1_794_045_600_000) // 2026-11-07 18:00 CST
    private let end = Int64(1_794_132_000_000)   // 2026-11-08 18:00 CST

    func testSessionStopsSellingAtStartInclusive() {
        func s(_ now: Int64) -> MoneyTicketWindow.State {
            MoneyTicketWindow.state(startMs: start, endMs: end, signupDeadlineMs: nil, selfGuided: false, nowMs: now)
        }
        XCTAssertEqual(s(start - 1), .available)
        XCTAssertEqual(s(start), .started)
        XCTAssertEqual(s(end), .started)
        XCTAssertEqual(s(end + 1), .ended)
    }

    func testEndOnlyBoundaryIsStrict() {
        func s(_ now: Int64) -> MoneyTicketWindow.State {
            MoneyTicketWindow.state(startMs: nil, endMs: end, signupDeadlineMs: nil, selfGuided: false, nowMs: now)
        }
        XCTAssertEqual(s(end), .available)
        XCTAssertEqual(s(end + 1), .ended)
        XCTAssertEqual(MoneyTicketWindow.state(startMs: nil, endMs: nil, signupDeadlineMs: nil, selfGuided: false, nowMs: end), .available)
    }

    func testSignupDeadlineIgnoredForTimedSessions() {
        let state = MoneyTicketWindow.state(startMs: start, endMs: end, signupDeadlineMs: start - 3_600_000, selfGuided: false, nowMs: start - 10)
        XCTAssertEqual(state, .available)
    }

    func testSelfGuided() {
        func s(end e: Int64?, deadline: Int64?, now: Int64) -> MoneyTicketWindow.State {
            MoneyTicketWindow.state(startMs: start, endMs: e, signupDeadlineMs: deadline, selfGuided: true, nowMs: now)
        }
        XCTAssertEqual(s(end: nil, deadline: nil, now: start), .ended)
        XCTAssertEqual(s(end: end, deadline: nil, now: end), .ended)
        XCTAssertEqual(s(end: end, deadline: nil, now: end - 1), .available)
        XCTAssertEqual(s(end: end, deadline: start, now: start), .closed)
        XCTAssertEqual(s(end: end, deadline: start, now: start - 1), .available)
        XCTAssertEqual(MoneyTicketWindow.text(.closed), "报名已截止")
        XCTAssertEqual(MoneyTicketWindow.text(.started), "场次已开始")
        XCTAssertEqual(MoneyTicketWindow.text(.ended), "场次已结束")
        XCTAssertEqual(MoneyTicketWindow.text(.available), "")
    }

    func testSignupClosedUsesTicketEndOnly() {
        XCTAssertFalse(MoneyTicketWindow.signupClosed(endTime: nil, nowMs: end + 1))
        XCTAssertFalse(MoneyTicketWindow.signupClosed(endTime: "2026-11-08 18:00:00", nowMs: end))
        XCTAssertTrue(MoneyTicketWindow.signupClosed(endTime: "2026-11-08 18:00:00", nowMs: end + 1))
    }

    // MARK: pass expiry
    func testPassExpiryUsesCalendarDays() {
        let now = Int64(1_794_065_400_000) // 2026-11-07 23:30 CST
        XCTAssertEqual(MoneyPassExpiry.daysLeft(until: "2026-11-08 00:30:00", nowMs: now), 1)
        XCTAssertEqual(MoneyPassExpiry.text(until: "2026-11-08 00:30:00", nowMs: now), "1 天内过期")
        // China midnight is the previous playable day, same as 「可玩至」.
        XCTAssertEqual(MoneyPassExpiry.daysLeft(until: "2026-11-08 00:00:00", nowMs: now), 0)
        XCTAssertEqual(MoneyPassExpiry.text(until: "2026-11-08 00:00:00", nowMs: now), "今天过期")
        XCTAssertEqual(MoneyPassExpiry.daysLeft(until: "2026-11-08 00:00:01", nowMs: now), 1)
        XCTAssertEqual(MoneyPassExpiry.text(until: "2026-11-07 23:59:00", nowMs: now), "今天过期")
        XCTAssertEqual(MoneyPassExpiry.text(until: "2026-11-07 23:30:00", nowMs: now), "今天过期")
        XCTAssertEqual(MoneyPassExpiry.text(until: "2026-11-07 23:29:59", nowMs: now), "")
        XCTAssertEqual(MoneyPassExpiry.text(until: "2026-11-14 12:00:00", nowMs: now), "7 天内过期")
        XCTAssertEqual(MoneyPassExpiry.text(until: "2026-11-15 12:00:00", nowMs: now), "")
        XCTAssertEqual(MoneyPassExpiry.text(until: nil, nowMs: now), "")
        XCTAssertEqual(MoneyPassExpiry.text(until: "garbage", nowMs: now), "")
    }

    // MARK: actual pay
    func testActualPaidZeroIsLegal() {
        XCTAssertEqual(MoneyActualPay.resolveActualPaidMinor(wechat: 0, payable: 1000, total: 1000), 0)
        XCTAssertEqual(MoneyActualPay.resolveActualPaidMinor(wechat: nil, payable: 0, total: 500), 0)
        XCTAssertEqual(MoneyActualPay.resolveActualPaidMinor(wechat: nil, payable: nil, total: 500), 500)
        XCTAssertNil(MoneyActualPay.resolveActualPaidMinor(wechat: nil, payable: nil, total: nil))
    }

    func testFreeOrderRequiresExplicitZeros() {
        XCTAssertTrue(MoneyActualPay.isFreeOrder(total: 0, payable: 0, point: nil, wechat: nil))
        XCTAssertTrue(MoneyActualPay.isFreeOrder(total: 0, payable: 0, point: 0, wechat: 0))
        XCTAssertFalse(MoneyActualPay.isFreeOrder(total: 0, payable: 0, point: 100, wechat: 0))
        XCTAssertFalse(MoneyActualPay.isFreeOrder(total: nil, payable: 0, point: nil, wechat: nil))
        XCTAssertFalse(MoneyActualPay.isFreeOrder(total: 1000, payable: 0, point: nil, wechat: nil))
    }

    // MARK: refund payout summary
    func testPayoutSummary() {
        func s(_ status: Int?, _ payout: Int?, amount: Int64? = nil, present: Bool = true) -> MoneyRefundPayout.Summary? {
            MoneyRefundPayout.summary(applicationPresent: present, status: status, payoutStatus: payout, refundAmountMinor: amount)
        }
        XCTAssertNil(s(0, 5, present: false))
        XCTAssertEqual(s(1, 1)?.key, .refunded)
        XCTAssertEqual(s(2, 4)?.text, "已退款")
        XCTAssertEqual(s(1, 2)?.refundText, "原路退款异常，平台正在人工处理")
        XCTAssertEqual(s(1, 3)?.refundText, "人工退款已处理，等待复核确认")
        XCTAssertEqual(s(0, 5)?.text, "退款审核中")
        XCTAssertNil(s(2, 5), "rejected application is not a refund in flight")
        XCTAssertNil(s(2, 0), "rejected wins over payout 0")
        XCTAssertEqual(s(1, 0)?.refundText, "微信已受理原路退款，到账以微信退款通知为准")
        XCTAssertEqual(s(1, 0)?.text, "退款处理中")
        XCTAssertEqual(s(1, 6)?.refundText, "退款已批准，正在提交原路退款")
        XCTAssertEqual(s(nil, nil)?.refundText, "退款进度更新中，请以微信退款通知为准")
        XCTAssertNil(s(0, 5, amount: 0), "zero-yuan order has no money to refund")
        XCTAssertNil(s(1, 6, amount: -1))
        XCTAssertEqual(s(1, 1, amount: 0)?.key, .refunded, "paid-out wins over zero amount")
    }

    func testCanRequestRefund() {
        XCTAssertTrue(MoneyRefundPayout.canRequestRefund(manualRefundCasePresent: false, payout: nil, registrationStatus: 2,
                                                         paymentStatus: 2, verificationStatus: 0, refundable: true))
        XCTAssertFalse(MoneyRefundPayout.canRequestRefund(manualRefundCasePresent: false, payout: nil, registrationStatus: 2,
                                                          paymentStatus: 2, verificationStatus: 1, refundable: true))
        XCTAssertFalse(MoneyRefundPayout.canRequestRefund(manualRefundCasePresent: false, payout: nil, registrationStatus: 2,
                                                          paymentStatus: 2, verificationStatus: nil, refundable: nil))
        XCTAssertFalse(MoneyRefundPayout.canRequestRefund(manualRefundCasePresent: true, payout: nil, registrationStatus: 2,
                                                          paymentStatus: 2, verificationStatus: 0, refundable: true))
        let inFlight = MoneyRefundPayout.summary(applicationPresent: true, status: 0, payoutStatus: 5, refundAmountMinor: nil)
        XCTAssertFalse(MoneyRefundPayout.canRequestRefund(manualRefundCasePresent: false, payout: inFlight, registrationStatus: 2,
                                                          paymentStatus: 2, verificationStatus: 0, refundable: true))
    }

    // MARK: refund policy (Java RefundPolicy)
    func testSessionRefundDeadlineIs24hBeforeAssembly() {
        let deadline = start - 86_400_000
        XCTAssertEqual(MoneyRefundPolicy.sessionRefundDeadline(assemblyMs: start), deadline)
        func v(now: Int64) -> MoneyRefundPolicy.Verdict {
            MoneyRefundPolicy.evaluate(ownerType: 2, paymentStatus: 2, verificationStatus: 0, ticketMode: nil, ticketStartMs: nil,
                                       ticketEndMs: nil, activityStartMs: start, snapshotDeadlineMs: nil,
                                       payableMinor: 6900, pointUsed: 0, nowMs: now)
        }
        XCTAssertTrue(v(now: deadline).refundable, "deadline instant is still refundable")
        XCTAssertFalse(v(now: deadline + 1).refundable)
        XCTAssertEqual(v(now: deadline).deadlineMs, deadline)
    }

    func testFreeSessionCancelsUntilStart() {
        func v(now: Int64) -> MoneyRefundPolicy.Verdict {
            MoneyRefundPolicy.evaluate(ownerType: 2, paymentStatus: 2, verificationStatus: 0, ticketMode: nil, ticketStartMs: nil,
                                       ticketEndMs: nil, activityStartMs: start, snapshotDeadlineMs: nil,
                                       payableMinor: 0, pointUsed: 0, nowMs: now)
        }
        XCTAssertTrue(v(now: start - 1).refundable)
        XCTAssertFalse(v(now: start).refundable)
    }

    func testPointsPaidZeroCashOrderIsNotFree() {
        let verdict = MoneyRefundPolicy.evaluate(ownerType: 2, paymentStatus: 2, verificationStatus: 0, ticketMode: nil, ticketStartMs: nil,
                                                 ticketEndMs: nil, activityStartMs: start, snapshotDeadlineMs: nil,
                                                 payableMinor: 0, pointUsed: 100, nowMs: start - 3_600_000)
        XCTAssertFalse(verdict.refundable, "inside the 24h window, a points-paid order follows the paid-order deadline")
    }

    func testRefundFailClosedCases() {
        XCTAssertFalse(MoneyRefundPolicy.evaluate(ownerType: 2, paymentStatus: 1, verificationStatus: 0, ticketMode: nil, ticketStartMs: nil,
                                                  ticketEndMs: nil, activityStartMs: start, snapshotDeadlineMs: nil,
                                                  payableMinor: 100, pointUsed: 0, nowMs: 0).refundable)
        XCTAssertFalse(MoneyRefundPolicy.evaluate(ownerType: 2, paymentStatus: 2, verificationStatus: 1, ticketMode: nil, ticketStartMs: nil,
                                                  ticketEndMs: nil, activityStartMs: start, snapshotDeadlineMs: nil,
                                                  payableMinor: 100, pointUsed: 0, nowMs: 0).refundable)
        let missing = MoneyRefundPolicy.evaluate(ownerType: 2, paymentStatus: 2, verificationStatus: 0, ticketMode: nil, ticketStartMs: nil,
                                                 ticketEndMs: nil, activityStartMs: nil, snapshotDeadlineMs: nil,
                                                 payableMinor: 100, pointUsed: 0, nowMs: 0)
        XCTAssertFalse(missing.refundable)
        XCTAssertTrue(missing.manualReview)
    }

    func testTopicModesUseTicketClocks() {
        let classic = MoneyRefundPolicy.evaluate(ownerType: 1, paymentStatus: 2, verificationStatus: 0, ticketMode: 1, ticketStartMs: start,
                                                 ticketEndMs: end, activityStartMs: nil, snapshotDeadlineMs: nil,
                                                 payableMinor: 100, pointUsed: 0, nowMs: start)
        XCTAssertTrue(classic.refundable)
        XCTAssertEqual(classic.deadlineMs, start)
        let free = MoneyRefundPolicy.evaluate(ownerType: 1, paymentStatus: 2, verificationStatus: 0, ticketMode: 2, ticketStartMs: start,
                                              ticketEndMs: end, activityStartMs: nil, snapshotDeadlineMs: nil,
                                              payableMinor: 100, pointUsed: 0, nowMs: end + 1)
        XCTAssertFalse(free.refundable)
        XCTAssertEqual(free.deadlineMs, end)
        let snap = MoneyRefundPolicy.evaluate(ownerType: 1, paymentStatus: 2, verificationStatus: 0, ticketMode: 1, ticketStartMs: start,
                                              ticketEndMs: end, activityStartMs: nil, snapshotDeadlineMs: end,
                                              payableMinor: 100, pointUsed: 0, nowMs: end)
        XCTAssertTrue(snap.refundable, "snapshot deadline overrides the live ticket clock")
    }

    // MARK: pricing (CmsRegistrationServiceImpl.computePrice)
    func testPointsDeductBelowCap() {
        let r = MoneyPricing.compute(unitMinor: 6900, quantity: 1, userPoints: 1000, usePoints: true)
        XCTAssertEqual(r.pointDeductMinor, 2000)
        XCTAssertEqual(r.pointUsed, 1000)
        XCTAssertEqual(r.payableMinor, 4900)
        XCTAssertEqual(r.paymentType, 2)
        XCTAssertEqual(r.pointPaymentMinor, 2000)
        XCTAssertEqual(r.wechatPaymentMinor, 4900)
    }

    func testPointsCapIsPerOrderNotPerTicket() {
        let r = MoneyPricing.compute(unitMinor: 6900, quantity: 3, userPoints: 100_000, usePoints: true)
        XCTAssertEqual(r.totalMinor, 20_700)
        XCTAssertEqual(r.pointDeductMinor, 5000)
        XCTAssertEqual(r.pointUsed, 2500)
        XCTAssertEqual(r.payableMinor, 15_700)
    }

    func testPointsCannotExceedTotalAndFullyPaidByPoints() {
        let r = MoneyPricing.compute(unitMinor: 3000, quantity: 1, userPoints: 5000, usePoints: true)
        XCTAssertEqual(r.pointDeductMinor, 3000)
        XCTAssertEqual(r.pointUsed, 1500)
        XCTAssertEqual(r.payableMinor, 0)
        XCTAssertEqual(r.paymentType, 0)
        XCTAssertEqual(r.pointPaymentMinor, 3000)
        XCTAssertEqual(r.wechatPaymentMinor, 0)
    }

    func testNoPointsToggleIsWechatOnly() {
        let r = MoneyPricing.compute(unitMinor: 6900, quantity: 2, userPoints: 99_999, usePoints: false)
        XCTAssertEqual(r.pointDeductMinor, 0)
        XCTAssertEqual(r.pointUsed, 0)
        XCTAssertEqual(r.paymentType, 1)
        XCTAssertEqual(r.wechatPaymentMinor, 13_800)
        XCTAssertEqual(r.pointPaymentMinor, 0)
    }

    func testToggleOnWithoutPointsStaysTypeTwo() {
        let r = MoneyPricing.compute(unitMinor: 6900, quantity: 1, userPoints: 0, usePoints: true)
        XCTAssertEqual(r.pointDeductMinor, 0)
        XCTAssertEqual(r.payableMinor, 6900)
        XCTAssertEqual(r.paymentType, 2)
    }

    func testZeroPriceWithToggleIsPointsTypeWithZero() {
        let r = MoneyPricing.compute(unitMinor: 0, quantity: 1, userPoints: 100, usePoints: true)
        XCTAssertEqual(r.totalMinor, 0)
        XCTAssertEqual(r.payableMinor, 0)
        XCTAssertEqual(r.paymentType, 0)
    }

    func testNegativeInputsAreClamped() {
        let r = MoneyPricing.compute(unitMinor: -500, quantity: -3, userPoints: -10, usePoints: true)
        XCTAssertEqual(r.totalMinor, 0)
        XCTAssertEqual(r.payableMinor, 0)
        XCTAssertEqual(r.pointUsed, 0)
    }

    func testClubMemberPriceIsMinOfListAndMemberPrice() {
        let r = MoneyPricing.compute(unitMinor: 10_000, memberUnitMinor: 8000, quantity: 2, userPoints: 0, usePoints: false)
        XCTAssertEqual(r.originalMinor, 20_000)
        XCTAssertEqual(r.totalMinor, 16_000)
        XCTAssertEqual(r.memberDiscountMinor, 4000)
        let higher = MoneyPricing.compute(unitMinor: 10_000, memberUnitMinor: 12_000, quantity: 1, userPoints: 0, usePoints: false)
        XCTAssertEqual(higher.totalMinor, 10_000)
        XCTAssertEqual(higher.memberDiscountMinor, 0)
    }

    func testFractionalFenRateRoundsHalfUpAndCeilsPoints() {
        // 0.005 yuan per point: 101 points == 0.505 yuan -> 0.51 (HALF_UP)
        let r = MoneyPricing.compute(unitMinor: 6900, quantity: 1, userPoints: 101, usePoints: true, rateMicroYuan: 5000)
        XCTAssertEqual(r.pointDeductMinor, 51)
        XCTAssertEqual(r.pointUsed, 101)
        XCTAssertEqual(r.payableMinor, 6849)
    }

    func testDefaultsMatchCmsConstants() {
        XCTAssertEqual(MoneyPricing.defaultRateMicroYuan, 20_000)
        XCTAssertEqual(MoneyPricing.defaultMaxPerOrderMinor, 5000)
    }

    func testPointsToggleNotice() {
        XCTAssertEqual(MoneyPricing.pointsToggleNotice(usePoints: true, quotedDeductMinor: 0, userPoints: 0), "暂无可用积分")
        XCTAssertEqual(MoneyPricing.pointsToggleNotice(usePoints: true, quotedDeductMinor: 0, userPoints: 50), "该票不支持积分抵扣")
        XCTAssertNil(MoneyPricing.pointsToggleNotice(usePoints: true, quotedDeductMinor: 100, userPoints: 50))
        XCTAssertNil(MoneyPricing.pointsToggleNotice(usePoints: false, quotedDeductMinor: 0, userPoints: 0))
    }

    // MARK: host cancel
    func testHostCancelResponseCode() {
        XCTAssertEqual(MoneyHostCancelParity.responseCode(NSNumber(value: 200)), 200)
        XCTAssertEqual(MoneyHostCancelParity.responseCode("200"), 200)
        XCTAssertNil(MoneyHostCancelParity.responseCode(NSNumber(value: true)))
        XCTAssertNil(MoneyHostCancelParity.responseCode(nil))
        XCTAssertNil(MoneyHostCancelParity.responseCode("ok"))
    }

    func testHostCancelPaidPlayers() {
        XCTAssertEqual(MoneyHostCancelParity.paidPlayers(NSNumber(value: 0)), 0)
        XCTAssertEqual(MoneyHostCancelParity.paidPlayers(NSNumber(value: 3)), 3)
        XCTAssertEqual(MoneyHostCancelParity.paidPlayers(NSNumber(value: 3.0)), 3)
        XCTAssertEqual(MoneyHostCancelParity.paidPlayers("7"), 7)
        XCTAssertNil(MoneyHostCancelParity.paidPlayers(NSNumber(value: 3.5)))
        XCTAssertNil(MoneyHostCancelParity.paidPlayers(NSNumber(value: -1)))
        XCTAssertNil(MoneyHostCancelParity.paidPlayers(NSNumber(value: true)))
        XCTAssertNil(MoneyHostCancelParity.paidPlayers(""))
        XCTAssertNil(MoneyHostCancelParity.paidPlayers(nil))
    }
}
#endif
