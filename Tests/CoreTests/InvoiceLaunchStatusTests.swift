import XCTest
#if canImport(QuestifyCore)
@testable import QuestifyCore

/// Source subpackageMember/invoice/base.js PLAYER_STATUS + backend UserInvoiceProcessingService statuses.
final class InvoiceLaunchStatusTests: XCTestCase {
    private func decode(_ status: String) throws -> InvoiceLaunchApplication {
        let json: [String: Any] = ["id": 51, "applicationNo": "SYNTHETIC-51", "status": status, "titleType": "PERSONAL",
            "titleName": "Synthetic title", "totalAmount": 14.25, "orderCount": 1, "orders": [Any]()]
        return try JSONDecoder().decode(InvoiceLaunchApplication.self, from: JSONSerialization.data(withJSONObject: json))
    }
    func testBackOfficeProcessingStatusesDecodeInsteadOfFailingTheWholeRead() throws {
        for raw in ["SUBMITTED", "CLAIMED", "PROCESSING", "ISSUE_UNKNOWN", "PAUSED", "ISSUED", "REJECTED", "CANCELLED"] {
            XCTAssertEqual(try decode(raw).status.rawValue, raw)
        }
        XCTAssertThrowsError(try decode("SOMETHING_ELSE"))
    }
    func testPlayerStateGroupsProcessingStatesLikeTheMiniProgram() {
        for status in [InvoiceLaunchStatus.submitted, .claimed, .processing, .issueUnknown] {
            XCTAssertEqual(status.playerState, .issuing); XCTAssertEqual(status.filterKey, "SUBMITTED")
            XCTAssertEqual(status.noticeKey, "notice.issuing")
        }
        XCTAssertEqual(InvoiceLaunchStatus.paused.playerState, .paused)
        XCTAssertEqual(InvoiceLaunchStatus.paused.filterKey, "SUBMITTED", "mini IN_TAB.ing includes paused")
        XCTAssertEqual(InvoiceLaunchStatus.paused.labelKey, "PAUSED")
        XCTAssertEqual(InvoiceLaunchStatus.claimed.labelKey, "SUBMITTED")
        XCTAssertEqual(InvoiceLaunchStatus.issued.filterKey, "ISSUED")
        XCTAssertEqual(InvoiceLaunchStatus.rejected.noticeKey, "notice.rejected")
        XCTAssertEqual(InvoiceLaunchStatus.cancelled.noticeKey, "notice.cancelled")
    }
}
#endif
