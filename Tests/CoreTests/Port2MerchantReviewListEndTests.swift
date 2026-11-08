import XCTest
@testable import QuestifyCore

final class Port2MerchantReviewListEndTests: XCTestCase {
    func testEndMarkerOnlyWhenFullyLoadedAndNonEmpty() {
        XCTAssertTrue(MerchantReviewListEndPort.showsEnd(hasMore: false, loadedCount: 3))
        XCTAssertFalse(MerchantReviewListEndPort.showsEnd(hasMore: true, loadedCount: 3))
        XCTAssertFalse(MerchantReviewListEndPort.showsEnd(hasMore: false, loadedCount: 0))
    }
}
