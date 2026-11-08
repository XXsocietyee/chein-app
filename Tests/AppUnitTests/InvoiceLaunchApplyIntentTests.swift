import XCTest
import Foundation
@testable import Questify

/// Submit-tap input ownership only; no real invoice or permission is created.
@MainActor final class InvoiceLaunchApplyIntentTests: XCTestCase {
    func testSelectionClearedBeforeQueuedExecutionKeepsOriginalIDs() async {
        let revision = UUID()
        var selection: Set<Int64> = [9, 2, 4]
        let intent = InvoiceLaunchApplyIntent(titleID: 12, selected: selection, identityRevision: revision)
        selection.removeAll()
        var delivered: [Int64] = []
        let accepted = await intent.submit(currentRevision: revision) { title, orders in
            XCTAssertEqual(title, 12); delivered = orders; return true
        }
        XCTAssertTrue(accepted); XCTAssertEqual(delivered, [2, 4, 9]); XCTAssertTrue(selection.isEmpty)
    }
    func testNewSelectionAndTitleCannotChangeCapturedIntent() async {
        let revision = UUID()
        var title: Int64 = 12
        var selected: Set<Int64> = [1, 3]
        let intent = InvoiceLaunchApplyIntent(titleID: title, selected: selected, identityRevision: revision)
        title = 18; selected = [50]
        _ = await intent.submit(currentRevision: revision) { sentTitle, orders in
            XCTAssertEqual(sentTitle, 12); XCTAssertEqual(orders, [1, 3]); return true
        }
        XCTAssertEqual(title, 18); XCTAssertEqual(selected, [50])
    }
    func testChangedIdentityNeverInvokesOperation() async {
        let intent = InvoiceLaunchApplyIntent(titleID: 12, selected: [1], identityRevision: UUID())
        var calls = 0
        let accepted = await intent.submit(currentRevision: UUID()) { _, _ in calls += 1; return true }
        XCTAssertFalse(accepted); XCTAssertEqual(calls, 0)
    }
    func testOperationFailureIsReturnedWithoutRetryOrClaimingReceipt() async {
        let revision = UUID()
        let intent = InvoiceLaunchApplyIntent(titleID: 12, selected: [1], identityRevision: revision)
        var calls = 0
        let accepted = await intent.submit(currentRevision: revision) { _, _ in calls += 1; return false }
        XCTAssertFalse(accepted); XCTAssertEqual(calls, 1)
    }
}

/// Synthetic list rules only; no network, no real invoice.
@MainActor final class InvoiceLaunchHistoryRulesTests: XCTestCase {
    private func application(id: Int64, status: String) throws -> InvoiceLaunchApplication {
        let json: [String: Any] = ["id": id, "applicationNo": "SYNTHETIC-\(id)", "status": status, "titleType": "PERSONAL",
            "titleName": "Synthetic title", "totalAmount": 14.25, "orderCount": 1, "orders": [Any]()]
        return try JSONDecoder().decode(InvoiceLaunchApplication.self, from: JSONSerialization.data(withJSONObject: json))
    }
    func testFilterKeepsOnlyMatchingStatusAndAllKeepsEverything() throws {
        let rows = [try application(id: 1, status: "SUBMITTED"), try application(id: 2, status: "ISSUED"),
                    try application(id: 3, status: "SUBMITTED")]
        XCTAssertEqual(InvoiceLaunchHistoryRules.rows(rows, filter: "all").map(\.id), [1, 2, 3])
        XCTAssertEqual(InvoiceLaunchHistoryRules.rows(rows, filter: "SUBMITTED").map(\.id), [1, 3])
        XCTAssertTrue(InvoiceLaunchHistoryRules.rows(rows, filter: "REJECTED").isEmpty)
    }
    func testOnlySubmittedCanBeWithdrawn() {
        XCTAssertTrue(InvoiceLaunchHistoryRules.canWithdraw(.submitted))
        for status in [InvoiceLaunchStatus.issued, .rejected, .cancelled] {
            XCTAssertFalse(InvoiceLaunchHistoryRules.canWithdraw(status))
        }
    }
    func testEmptyStateDistinguishesNoApplicationsFromEmptyFilter() {
        XCTAssertEqual(InvoiceLaunchHistoryRules.emptyKey(total: 0, filter: "ISSUED"), "empty")
        XCTAssertEqual(InvoiceLaunchHistoryRules.emptyKey(total: 3, filter: "all"), "empty")
        XCTAssertEqual(InvoiceLaunchHistoryRules.emptyKey(total: 3, filter: "ISSUED"), "emptyFiltered")
    }
    func testWithdrawNeedsConfirmationAndSuccessNoticeOnlyAfterServiceSuccess() {
        var flow = InvoiceLaunchWithdrawFlow()
        XCTAssertNil(flow.confirm())
        flow.ask(51); XCTAssertEqual(flow.confirming, 51); XCTAssertNil(flow.succeeded)
        flow.cancelAsk(); XCTAssertNil(flow.confirm())
        flow.ask(51)
        XCTAssertEqual(flow.confirm(), 51); XCTAssertNil(flow.confirming); XCTAssertNil(flow.succeeded)
        flow.finish(id: 51, success: false); XCTAssertNil(flow.succeeded)
        flow.finish(id: 51, success: true); XCTAssertEqual(flow.succeeded, 51)
        flow.ask(52); XCTAssertNil(flow.succeeded)
    }
    func testProcessingStatesGroupUnderProcessingFilterAndOnlySubmittedCanBeWithdrawn() throws {
        let rows = [try application(id: 1, status: "SUBMITTED"), try application(id: 2, status: "PROCESSING"),
                    try application(id: 3, status: "PAUSED"), try application(id: 4, status: "ISSUED")]
        XCTAssertEqual(InvoiceLaunchHistoryRules.rows(rows, filter: "SUBMITTED").map(\.id), [1, 2])
        XCTAssertEqual(InvoiceLaunchHistoryRules.rows(rows, filter: "all").map(\.id), [1, 2, 3, 4])
        for status in [InvoiceLaunchStatus.claimed, .processing, .issueUnknown, .paused] {
            XCTAssertFalse(InvoiceLaunchHistoryRules.canWithdraw(status))
        }
    }
    func testConfirmIsSingleUse() {
        var flow = InvoiceLaunchWithdrawFlow()
        flow.ask(7)
        XCTAssertEqual(flow.confirm(), 7)
        XCTAssertNil(flow.confirm())
    }
}
