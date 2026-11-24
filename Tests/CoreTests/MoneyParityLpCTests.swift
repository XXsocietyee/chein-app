#if canImport(QuestifyCore)
import Foundation
import XCTest
@testable import QuestifyCore

/// Review-finding regressions for money logic (docs/parity/logic-parity-money.md, "lp-c" section).
final class MoneyParityLpCRulesTests: XCTestCase {
    // MARK: finding 1 - RefundPolicy.verifiedVerdict
    private func verified(kind: Int?) -> MoneyRefundPolicy.Verdict {
        MoneyRefundPolicy.evaluate(ownerType: 1, paymentStatus: 2, verificationStatus: 1, ticketMode: 2, ticketStartMs: nil,
                                   ticketEndMs: 2_000, activityStartMs: nil, snapshotDeadlineMs: nil, payableMinor: 500,
                                   pointUsed: 0, nowMs: 1_000, purchaseKind: kind)
    }

    func testVerifiedExplorePassGoesToManualReview() {
        let v = verified(kind: 3)
        XCTAssertFalse(v.refundable)
        XCTAssertTrue(v.manualReview)
        XCTAssertEqual(v.reason, "已核销订单需人工核实,请联系客服")
        XCTAssertNil(v.deadlineMs)
    }

    func testVerifiedOtherKindsAndLegacyOrdersStayHardRefusal() {
        for kind in [nil, 1, 2] as [Int?] {
            let v = verified(kind: kind)
            XCTAssertFalse(v.refundable)
            XCTAssertFalse(v.manualReview)
            XCTAssertEqual(v.reason, "已核销报名不可退款")
        }
    }

    func testUnpaidStillWinsOverVerifiedExplorePass() {
        let v = MoneyRefundPolicy.evaluate(ownerType: 1, paymentStatus: 1, verificationStatus: 1, ticketMode: 2, ticketStartMs: nil,
                                           ticketEndMs: nil, activityStartMs: nil, snapshotDeadlineMs: nil, payableMinor: 500,
                                           pointUsed: 0, nowMs: 1_000, purchaseKind: 3)
        XCTAssertEqual(v.reason, "未支付订单无需退款")
        XCTAssertFalse(v.manualReview)
    }

    func testRefundPolicyAdapterConvertsDatesAndPassesPurchaseKind() {
        let now = Date(timeIntervalSince1970: 1_000)
        let v = MoneyRefundPolicyAdapter.evaluate(
            ownerType: 1, paymentStatus: 2, verificationStatus: 1, ticketMode: 2, purchaseKind: 3, ticketStart: nil,
            ticketEnd: Date(timeIntervalSince1970: 2_000), activityStart: nil, snapshotDeadline: nil, payableMinor: 500,
            pointUsed: 0, now: now)
        XCTAssertTrue(v.manualReview)
        let open = MoneyRefundPolicyAdapter.evaluate(
            ownerType: 1, paymentStatus: 2, verificationStatus: 0, ticketMode: 2, purchaseKind: 3, ticketStart: nil,
            ticketEnd: Date(timeIntervalSince1970: 2_000), activityStart: nil, snapshotDeadline: nil, payableMinor: 500,
            pointUsed: 0, now: now)
        XCTAssertTrue(open.refundable)
        XCTAssertEqual(open.deadlineMs, 2_000_000)
    }

    // MARK: finding 2 - TicketExpiryAndOrderStatusRules.payoutSummary vs utils/order-status.js
    func testPayoutSummaryZeroAmountHasNoInFlightPromise() {
        typealias R = TicketExpiryAndOrderStatusRules
        XCTAssertNil(R.payoutSummary(status: 1, payoutStatus: 6, refundAmount: 0))
        XCTAssertNil(R.payoutSummary(status: 0, payoutStatus: 5, refundAmount: -1))
        XCTAssertEqual(R.payoutSummary(status: 1, payoutStatus: 1, refundAmount: 0)?.label, "已退款", "paid-out wins over zero amount")
        XCTAssertEqual(R.payoutSummary(status: 0, payoutStatus: 5, refundAmount: 9)?.label, "退款审核中")
    }

    func testPayoutSummaryFallsBackToRefundingLikeTheSource() {
        typealias R = TicketExpiryAndOrderStatusRules
        let fallback = R.payoutSummary(status: nil, payoutStatus: 5, refundAmount: 9)
        XCTAssertEqual(fallback, .init(label: "退款处理中", hint: "退款进度更新中，请以微信退款通知为准", canCancelRefundApplication: false))
        // An application object with every field missing is still "application != null" in the source.
        XCTAssertEqual(R.payoutSummary(status: nil, payoutStatus: nil, applicationPresent: true)?.label, "退款处理中")
        XCTAssertNil(R.payoutSummary(status: nil, payoutStatus: nil, applicationPresent: false))
        XCTAssertNil(R.payoutSummary(status: nil, payoutStatus: nil), "legacy call shape: nothing present means no application")
        XCTAssertNil(R.payoutSummary(status: 2, payoutStatus: 5), "rejected is still not in flight")
    }

    func testCanRequestOrderRefundUsesAmountAndFallback() {
        typealias R = TicketExpiryAndOrderStatusRules
        // In-flight fallback blocks a new request.
        XCTAssertFalse(R.canRequestOrderRefund(registrationStatus: 2, paymentStatus: 2, verificationStatus: 0, refundable: true,
                                               refundApplicationStatus: nil, refundPayoutStatus: 5, refundAmount: 9,
                                               refundApplicationPresent: true))
        // A zero-yuan application is not a refund in flight.
        XCTAssertTrue(R.canRequestOrderRefund(registrationStatus: 2, paymentStatus: 2, verificationStatus: 0, refundable: true,
                                              refundApplicationStatus: 0, refundPayoutStatus: 5, refundAmount: 0,
                                              refundApplicationPresent: true))
        // Legacy call shape unchanged.
        XCTAssertTrue(R.canRequestOrderRefund(registrationStatus: 2, paymentStatus: 2, verificationStatus: 0, refundable: true))
        XCTAssertFalse(R.canRequestOrderRefund(registrationStatus: 2, paymentStatus: 2, verificationStatus: 0, refundable: true,
                                               refundApplicationStatus: 0))
    }

    // MARK: finding 4 - server notice
    func testCompletionNoticeKeepsServerWarningVerbatimAndTrimmed() {
        let warning = "活动已取消,已为 2 笔订单全额退款;另有 1 笔订单含已核销的票,无法自动退款,平台将人工跟进处理"
        XCTAssertEqual(ActivityHostCancelRules.completionNotice(serverMessage: "  \(warning)\n"), warning)
        XCTAssertNil(ActivityHostCancelRules.completionNotice(serverMessage: nil))
        XCTAssertNil(ActivityHostCancelRules.completionNotice(serverMessage: " \n "))
    }

    // MARK: finding 6 - pricing adapter
    func testPricingAdapterCapsPointsOncePerOrderAndNeverDeductsCoupon() {
        let out = MoneyPricingAdapter.compute(unitPrice: 100, quantity: 2, usePoints: true, userAvailablePoints: 10_000)
        XCTAssertEqual(out.price.orderTotalYuan, 200)
        XCTAssertEqual(out.price.memberDiscountYuan, 0)
        XCTAssertEqual(out.price.couponDeductYuan, 0)
        XCTAssertEqual(out.price.pointsDeductYuan, 50)
        XCTAssertEqual(out.price.pointsUsed, 2_500)
        XCTAssertEqual(out.price.payAmount, 150)
        XCTAssertEqual(out.breakdown.paymentType, 2)
        XCTAssertEqual(out.breakdown.wechatPaymentMinor, 15_000)
    }

    func testPricingAdapterMemberPriceAndPointsGate() {
        let member = MoneyPricingAdapter.compute(unitPrice: 100, quantity: 2, memberUnitPrice: 80)
        XCTAssertEqual(member.price.orderTotalYuan, 200)
        XCTAssertEqual(member.price.memberDiscountYuan, 40)
        XCTAssertEqual(member.price.payAmount, 160)
        XCTAssertEqual(member.breakdown.paymentType, 1)
        let gated = MoneyPricingAdapter.compute(unitPrice: 100, usePoints: true, pointsUsableForProduct: false, userAvailablePoints: 5_000)
        XCTAssertEqual(gated.price.pointsDeductYuan, 0)
        XCTAssertEqual(gated.price.pointsUsed, 0)
        XCTAssertEqual(gated.price.payAmount, 100)
    }

    func testPricingAdapterAgreesWithMoneyPricingOnFractionalRate() {
        let out = MoneyPricingAdapter.compute(unitPrice: 69, usePoints: true, userAvailablePoints: 101)
        let direct = MoneyPricing.compute(unitMinor: 6_900, quantity: 1, userPoints: 101, usePoints: true,
                                           rateMicroYuan: MoneyPricing.defaultRateMicroYuan)
        XCTAssertEqual(out.breakdown, direct)
        XCTAssertEqual(out.price.pointsUsed, Int(direct.pointUsed))
    }
}

private final class HostCancelScopeTransport: HTTPTransport, @unchecked Sendable {
    var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return (Data(#"{"code":200,"msg":"ok","data":{"paidPlayers":2}}"#.utf8), 200)
    }
}

@MainActor final class ActivityHostCancelScopeTests: XCTestCase {
    private func make(_ t: HostCancelScopeTransport) throws -> ActivityHostCancelHTTPAccess {
        .init(configuration: try APIConfiguration(baseURL: URL(string: "https://example.test/prod-api")!), transport: t,
              enabled: { true }, session: { (3, "synthetic-token") })
    }
    private func body(_ r: URLRequest) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: r.httpBody!) as! [String: Any]
    }

    func testDefaultSendsNoScopeLikeTheClubHostFlow() async throws {
        defer { ReleaseMoneyWriteSwitch.testDerivation = nil }
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .hostCancelRefund }
        let t = HostCancelScopeTransport(); let a = try make(t)
        _ = try await a.preview(activityID: 9)
        _ = try await a.cancel(activityID: 9, reason: "rain")
        for r in t.requests { XCTAssertNil(try body(r)["scope"]) }
    }

    func testMerchantScopeIsSentOnPreviewAndCancel() async throws {
        defer { ReleaseMoneyWriteSwitch.testDerivation = nil }
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .hostCancelRefund }
        let t = HostCancelScopeTransport(); let a = try make(t)
        a.operationScope = .merchant
        _ = try await a.preview(activityID: 9)
        _ = try await a.cancel(activityID: 9, reason: " rain ")
        XCTAssertEqual(t.requests.count, 2)
        for r in t.requests { XCTAssertEqual(try body(r)["scope"] as? String, "MERCHANT") }
        XCTAssertEqual(try body(t.requests[1])["reason"] as? String, "rain")
        XCTAssertEqual(try body(t.requests[1])["id"] as? Int, 9)
        XCTAssertEqual(t.requests[0].url?.path, "/prod-api/api/activity/cancel_preview")
    }
}
#endif
