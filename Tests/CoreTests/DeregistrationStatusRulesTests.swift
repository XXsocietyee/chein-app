#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

/// Encodes utils/deregister-flow.js (precheck validation, cooling-off clock, apply gating, reconcile).
final class DeregistrationStatusRulesTests: XCTestCase {
    typealias R = DeregistrationStatusRules

    func testEligibleWithoutBlockersDefaultsToSMSWhenMethodAbsent() {
        XCTAssertEqual(R.evaluatePrecheck(status: "ELIGIBLE", blockers: [], verificationMethod: nil), .eligible(.sms))
        XCTAssertEqual(R.evaluatePrecheck(status: "ELIGIBLE", blockers: [], verificationMethod: "WECHAT"), .eligible(.wechat))
        XCTAssertEqual(R.evaluatePrecheck(status: "ELIGIBLE", blockers: [], verificationMethod: "UNAVAILABLE"), .eligible(.unavailable))
    }

    func testUnknownOrMalformedMethodIsNeverUsable() {
        XCTAssertEqual(R.evaluatePrecheck(status: "ELIGIBLE", blockers: [], verificationMethod: "UNKNOWN"), .eligible(.unavailable))
        XCTAssertEqual(R.evaluatePrecheck(status: "ELIGIBLE", blockers: [], verificationMethod: "sms"), .eligible(.unavailable))
    }

    func testEligibleWithBlockersIsMalformed() {
        XCTAssertEqual(R.evaluatePrecheck(status: "ELIGIBLE", blockers: ["open order"], verificationMethod: nil), .malformed)
    }

    func testBlockedNeedsAtLeastOneBlockerAndTrimsThem() {
        XCTAssertEqual(R.evaluatePrecheck(status: "BLOCKED", blockers: [], verificationMethod: nil), .malformed)
        XCTAssertEqual(R.evaluatePrecheck(status: "BLOCKED", blockers: ["  wallet balance \n"], verificationMethod: nil), .blocked(["wallet balance"]))
    }

    func testBlankBlockerTextAndUnknownStatusAreMalformed() {
        XCTAssertEqual(R.evaluatePrecheck(status: "BLOCKED", blockers: ["ok", "   "], verificationMethod: nil), .malformed)
        XCTAssertEqual(R.evaluatePrecheck(status: "PENDING", blockers: [], verificationMethod: nil), .malformed)
        XCTAssertEqual(R.evaluatePrecheck(status: "UNKNOWN", blockers: [], verificationMethod: nil), .malformed)
        XCTAssertEqual(R.evaluatePrecheck(status: "", blockers: [], verificationMethod: nil), .malformed)
    }

    func testCoolingOffClockUsesIsoOffsetEpochAndChinaLocalStrings() {
        let now = Date(timeIntervalSince1970: 1_800_000_000) // 2027-01-15T08:00:00Z
        XCTAssertTrue(R.executeAfterPassed("2027-01-15T07:59:59.000Z", now: now))
        XCTAssertTrue(R.executeAfterPassed("2027-01-15T15:59:59.000+08:00", now: now))
        XCTAssertFalse(R.executeAfterPassed("2027-01-15T16:00:01.000+08:00", now: now))
        XCTAssertTrue(R.executeAfterPassed("1799999999", now: now))
        XCTAssertTrue(R.executeAfterPassed("1799999999000", now: now))
        XCTAssertFalse(R.executeAfterPassed("1800000001", now: now))
        // Zone-less strings are China time: 16:00:00 local == 08:00:00Z == now (<= now passes).
        XCTAssertTrue(R.executeAfterPassed("2027-01-15 16:00:00", now: now))
        XCTAssertFalse(R.executeAfterPassed("2027-01-15 16:00:01", now: now))
    }

    func testCoolingOffClockTreatsMissingOrUnparseableAsNotPassed() {
        let now = Date()
        XCTAssertFalse(R.executeAfterPassed(nil, now: now))
        XCTAssertFalse(R.executeAfterPassed("", now: now))
        XCTAssertFalse(R.executeAfterPassed("   ", now: now))
        XCTAssertFalse(R.executeAfterPassed("soon", now: now))
        XCTAssertFalse(R.executeAfterPassed("0000000000", now: now), "epoch zero is not a deadline")
    }

    func testApplyGateOrder() {
        XCTAssertEqual(R.applyGate(eligible: false, submitting: false, confirmed: true, method: .sms, smsCode: "1"), .ignored)
        XCTAssertEqual(R.applyGate(eligible: true, submitting: true, confirmed: true, method: .sms, smsCode: "1"), .ignored)
        XCTAssertEqual(R.applyGate(eligible: true, submitting: false, confirmed: false, method: .sms, smsCode: "1"), .needsConfirmation)
        XCTAssertEqual(R.applyGate(eligible: true, submitting: false, confirmed: true, method: .unavailable, smsCode: "1"), .verificationUnavailable)
        XCTAssertEqual(R.applyGate(eligible: true, submitting: false, confirmed: true, method: .sms, smsCode: "  \n"), .needsCode)
        XCTAssertEqual(R.applyGate(eligible: true, submitting: false, confirmed: true, method: .sms, smsCode: " 123456 "), .ready)
        XCTAssertEqual(R.applyGate(eligible: true, submitting: false, confirmed: true, method: .wechat, smsCode: ""), .ready)
    }

    func testCanApplyNeedsEligibleConfirmedAndMethodSpecificEvidence() {
        XCTAssertFalse(R.canApply(eligible: true, confirmed: false, method: .sms, smsCode: "1"))
        XCTAssertFalse(R.canApply(eligible: false, confirmed: true, method: .wechat, smsCode: ""))
        XCTAssertFalse(R.canApply(eligible: true, confirmed: true, method: .sms, smsCode: " "))
        XCTAssertFalse(R.canApply(eligible: true, confirmed: true, method: .unavailable, smsCode: "123456"))
        XCTAssertTrue(R.canApply(eligible: true, confirmed: true, method: .sms, smsCode: "123456"))
        XCTAssertTrue(R.canApply(eligible: true, confirmed: true, method: .wechat, smsCode: ""))
    }

    func testReconcileAdoptsPendingOnlyFromTheEligibleForm() {
        XCTAssertTrue(R.adoptPendingAfterUnknownApply(serverStatus: "PENDING", localEligible: true))
        XCTAssertFalse(R.adoptPendingAfterUnknownApply(serverStatus: "PENDING", localEligible: false))
        XCTAssertFalse(R.adoptPendingAfterUnknownApply(serverStatus: "NORMAL", localEligible: true))
        XCTAssertFalse(R.adoptPendingAfterUnknownApply(serverStatus: nil, localEligible: true))
    }

    func testStatusRoutes() {
        XCTAssertEqual(R.route(status: "PENDING"), .pending)
        for status in ["NORMAL", "CANCELLED", "FAILED"] { XCTAssertEqual(R.route(status: status), .precheck) }
        for status in ["COMPLETED", "UNKNOWN", "", "pending"] { XCTAssertEqual(R.route(status: status), .unconfirmed) }
    }
}
#endif
