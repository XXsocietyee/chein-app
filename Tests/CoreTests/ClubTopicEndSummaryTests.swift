#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

final class ClubTopicEndSummaryTests: XCTestCase {
    private func body(state: String = "DONE", epoch: String = "3", failed: String = "[]", refunded: String = "2", manual: String = "0", extra: String = "") -> ClubGovernanceValue {
        ClubGovernanceFixtures.json(#"{"cancellationEpoch":\#(epoch),"cancellationState":"\#(state)","sessionTotal":4,"cancelledSessions":4,"refundedOrders":\#(refunded),"manualOrders":\#(manual),"closedPendingOrders":1,"failedSessions":\#(failed)\#(extra)}"#)
    }
    func testDoneClosesSheetAndReportsRefunds() {
        let summary = ClubTopicEndSummary.parse(body(), sentEpoch: 3)
        XCTAssertEqual(summary.outcome, .done); XCTAssertTrue(summary.shouldCloseSheet)
        XCTAssertEqual(summary.resultText(chinese: true), "已结束，退款 2 笔"); XCTAssertNil(summary.errorText(chinese: true))
    }
    func testManualOrdersAreNeverSwallowed() {
        let summary = ClubTopicEndSummary.parse(body(manual: "2"), sentEpoch: 3)
        XCTAssertEqual(summary.resultText(chinese: true), "2 笔需人工处理")
        XCTAssertEqual(summary.resultText(chinese: false), "2 order(s) need manual handling")
    }
    func testNoRefundText() {
        XCTAssertEqual(ClubTopicEndSummary.parse(body(refunded: "0"), sentEpoch: 3).resultText(chinese: true), "已结束，无可退订单")
    }
    func testFailedSessionsKeepSheetOpenWithFirstReason() {
        let summary = ClubTopicEndSummary.parse(body(failed: #"["场次A 已核销","场次B"]"#), sentEpoch: 3)
        XCTAssertEqual(summary.outcome, .partialFailure(count: 2, firstReason: "场次A 已核销"))
        XCTAssertFalse(summary.shouldCloseSheet); XCTAssertEqual(summary.errorText(chinese: true), "2 场没能取消：场次A 已核销")
    }
    func testPendingStateKeepsOriginalRequest() {
        let summary = ClubTopicEndSummary.parse(body(state: "PENDING"), sentEpoch: 3)
        XCTAssertEqual(summary.outcome, .stillProcessing); XCTAssertFalse(summary.shouldCloseSheet)
    }
    func testEpochMismatchOrMalformedFieldsStayUnconfirmed() {
        XCTAssertEqual(ClubTopicEndSummary.parse(body(epoch: "4"), sentEpoch: 3).outcome, .unconfirmed)
        XCTAssertEqual(ClubTopicEndSummary.parse(body(state: "DONE", refunded: "-1"), sentEpoch: 3).outcome, .unconfirmed)
        XCTAssertEqual(ClubTopicEndSummary.parse(body(refunded: "\"2\""), sentEpoch: 3).outcome, .unconfirmed)
        XCTAssertEqual(ClubTopicEndSummary.parse(body(state: "OTHER"), sentEpoch: 3).outcome, .unconfirmed)
        XCTAssertEqual(ClubTopicEndSummary.parse(body(failed: "[1]"), sentEpoch: 3).outcome, .unconfirmed)
        XCTAssertEqual(ClubTopicEndSummary.parse(.null, sentEpoch: 3).outcome, .unconfirmed)
        XCTAssertFalse(ClubTopicEndSummary.parse(.null, sentEpoch: 3).shouldCloseSheet)
    }
}
#endif
