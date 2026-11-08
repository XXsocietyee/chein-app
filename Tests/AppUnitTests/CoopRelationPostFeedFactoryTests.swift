import XCTest
@testable import Questify

@MainActor final class CoopRelationPostFeedFactoryTests: XCTestCase {
    func testNoCommunityContextMeansNoPostsSegment() {
        let hook = CoopRelationPostFeedFactory.make(community: nil, identity: { nil })
        XCTAssertNil(hook)
        XCTAssertEqual(CoopRelationSection.effective(selected: nil, feedAvailable: hook != nil), .merchants)
        XCTAssertEqual(CoopRelationSection.available(feedAvailable: hook != nil), [.merchants, .clubs])
    }
}
