import XCTest
@testable import QuestifyCore
import Foundation

// All values synthetic. No network.
@MainActor private final class BNDShelfDouble: BundleShelfClient {
    var pages: [String?: String] = [:]
    var calls: [String?] = []
    func page(cursor: String?, limit: Int) async throws -> BundleShelfPage {
        calls.append(cursor)
        guard let json = pages[cursor] else { throw BundleShelfFailure.failed }
        return try JSONDecoder().decode(BundleShelfPage.self, from: Data(json.utf8))
    }
}

@MainActor final class BNDShelfModelTests: XCTestCase {
    private func row(_ id: Int) -> String { #"{"topicId":"\#(id)","topicName":"t\#(id)","fromPrice":"199.00","validityDays":30}"# }

    func testShelfUnavailableDefaultShowsNothingNotMockCards() async {
        let model = BundleShelfModel()
        await model.refresh()
        XCTAssertEqual(model.state, .unavailable)
        XCTAssertTrue(model.items.isEmpty)
        XCTAssertFalse(model.hasMore)
        XCTAssertFalse(model.saleEnabled)
    }

    func testDetailHidesPurchaseWhenSaleDisabled() throws {
        let off = try BundleDetailContent.decode(Data(#"{"topicId":"1","productType":2,"saleEnabled":false,"reservationEnabled":false,"items":[]}"#.utf8))
        XCTAssertFalse(off.showsPurchase)
        XCTAssertTrue(off.showsNotOnSale)
        let on = try BundleDetailContent.decode(Data(#"{"topicId":"1","productType":2,"saleEnabled":true,"reservationEnabled":false,"items":[]}"#.utf8))
        XCTAssertTrue(on.showsPurchase)
        XCTAssertFalse(on.showsNotOnSale)
    }

    func testDetailToleratesMissingComplianceFields() throws {
        let plain = try BundleDetailContent.decode(Data(#"{"topicId":"1","productType":2,"saleEnabled":true,"reservationEnabled":false,"items":[]}"#.utf8))
        XCTAssertFalse(plain.hasCompliance)
        XCTAssertNil(plain.agreementURL)
        XCTAssertTrue(plain.complianceDeclarations.isEmpty)
        // Reshaped extras must not hide the legacy catalog, and non-https links are dropped.
        let odd = try BundleDetailContent.decode(Data(#"{"topicId":"1","productType":2,"saleEnabled":true,"reservationEnabled":false,"items":[],"compliance":{"agreementUrl":"http://example.test/a","declarations":["d1",""]},"merchants":"bad","price":"199.00"}"#.utf8))
        XCTAssertEqual(odd.complianceDeclarations, ["d1"])
        XCTAssertNil(odd.agreementURL)
        XCTAssertNil(odd.extras?.merchants)
        XCTAssertEqual(odd.extras?.price?.text, "199.00")
        XCTAssertEqual(odd.catalog.topicId.text, "1")
    }

    func testShelfPaginationCursorStopsOnNil() async {
        let double = BNDShelfDouble()
        double.pages = [
            nil: #"{"items":[\#(row(1)),\#(row(2))],"nextCursor":"c2","saleEnabled":true,"reservationEnabled":false}"#,
            "c2": #"{"items":[\#(row(2)),\#(row(3))],"nextCursor":null}"#,
        ]
        let model = BundleShelfModel(client: double)
        await model.refresh()
        XCTAssertEqual(model.items.count, 2)
        XCTAssertTrue(model.hasMore)
        await model.loadMore()
        XCTAssertEqual(model.items.map(\.topicId.text), ["1", "2", "3"])
        XCTAssertFalse(model.hasMore)
        XCTAssertTrue(model.saleEnabled)
        await model.loadMore()
        XCTAssertEqual(double.calls.count, 2, "no request once the cursor is nil")
    }

    func testRepeatedCursorIsTreatedAsEnd() async {
        let double = BNDShelfDouble()
        double.pages = [
            nil: #"{"items":[\#(row(1))],"nextCursor":"c2"}"#,
            "c2": #"{"items":[\#(row(2))],"nextCursor":"c2"}"#,
        ]
        let model = BundleShelfModel(client: double)
        await model.refresh(); await model.loadMore()
        XCTAssertFalse(model.hasMore)
        XCTAssertEqual(model.items.count, 2)
    }
}
