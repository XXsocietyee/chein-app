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
    /// A JSON number 0 stays 0. Null, a missing key, a blank, and UNKNOWN do not decode as 0.
    func testLiteralZeroAmountStaysZeroAndUnknownDoesNotDecodeAsZero() throws {
        let zeroJSON: [String: Any] = ["id": 51, "applicationNo": "SYNTHETIC-51", "status": "SUBMITTED",
            "titleType": "PERSONAL", "titleName": "Synthetic title", "totalAmount": 0, "orderCount": 1,
            "orders": [["orderId": 21, "amount": 0]]]
        let zero = try JSONDecoder().decode(InvoiceLaunchApplication.self, from: JSONSerialization.data(withJSONObject: zeroJSON))
        try zero.validate()
        XCTAssertEqual(zero.totalAmount, 0)
        XCTAssertEqual(zero.orders[0].amount, 0)
        for bad in [NSNull(), "", "UNKNOWN"] as [Any] {
            var total = zeroJSON
            total["totalAmount"] = bad
            XCTAssertThrowsError(try JSONDecoder().decode(InvoiceLaunchApplication.self, from: JSONSerialization.data(withJSONObject: total)))
            var line = zeroJSON
            line["orders"] = [["orderId": 21, "amount": bad]]
            XCTAssertThrowsError(try JSONDecoder().decode(InvoiceLaunchApplication.self, from: JSONSerialization.data(withJSONObject: line)))
        }
        var missingTotal = zeroJSON
        missingTotal.removeValue(forKey: "totalAmount")
        XCTAssertThrowsError(try JSONDecoder().decode(InvoiceLaunchApplication.self, from: JSONSerialization.data(withJSONObject: missingTotal)))
        var missingLine = zeroJSON
        missingLine["orders"] = [["orderId": 21]]
        XCTAssertThrowsError(try JSONDecoder().decode(InvoiceLaunchApplication.self, from: JSONSerialization.data(withJSONObject: missingLine)))
    }
}
#endif
