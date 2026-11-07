import XCTest
@testable import Questify

final class CoopRelationSectionTests: XCTestCase {
    func testPostsIsTheDefaultSegmentOnlyWhenAFeedIsInjected() {
        XCTAssertEqual(CoopRelationSection.effective(selected: nil, feedAvailable: true), .posts)
        XCTAssertEqual(CoopRelationSection.effective(selected: nil, feedAvailable: false), .merchants)
    }
    func testExplicitSelectionWinsButPostsFallsBackWithoutAFeed() {
        XCTAssertEqual(CoopRelationSection.effective(selected: .clubs, feedAvailable: true), .clubs)
        XCTAssertEqual(CoopRelationSection.effective(selected: .clubs, feedAvailable: false), .clubs)
        XCTAssertEqual(CoopRelationSection.effective(selected: .posts, feedAvailable: false), .merchants)
    }
    func testAvailableSegmentsAndRelationKinds() {
        XCTAssertEqual(CoopRelationSection.available(feedAvailable: true), [.posts, .merchants, .clubs])
        XCTAssertEqual(CoopRelationSection.available(feedAvailable: false), [.merchants, .clubs])
        XCTAssertNil(CoopRelationSection.posts.relationKind)
        XCTAssertEqual(CoopRelationSection.clubs.relationKind, .clubs)
        XCTAssertEqual(CoopRelationSection.merchants.relationKind, .merchants)
    }
}
