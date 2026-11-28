import XCTest
@testable import Questify

final class TopicPerkCapacityTests: XCTestCase {
    func testMissingAndUnlimitedCapacityShowNoLine() {
        XCTAssertNil(TopicDetailView.perkCapacity(nil))
        XCTAssertNil(TopicDetailView.perkCapacity(2_147_483_647))
    }

    func testCapacityIsNeverNegative() {
        XCTAssertEqual(TopicDetailView.perkCapacity(12), 12)
        XCTAssertEqual(TopicDetailView.perkCapacity(0), 0)
        XCTAssertEqual(TopicDetailView.perkCapacity(-3), 0)
    }
}
