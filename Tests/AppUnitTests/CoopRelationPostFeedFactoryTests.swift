import XCTest
@testable import Questify

@MainActor final class CoopRelationPostFeedFactoryTests: XCTestCase {
    func testNoCommunityContextMeansNoPostsSegment() {
        let hook = CoopRelationPostFeedFactory.make(community: nil, identity: { nil })
        XCTAssertNil(hook)
        XCTAssertEqual(CoopRelationSection.effective(selected: nil, feedAvailable: hook != nil), .clubs)
        XCTAssertEqual(CoopRelationSection.available(feedAvailable: hook != nil), [.clubs])
    }

    func testSessionHostCallsPostFeedFactory() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let host = try String(contentsOf: root.appendingPathComponent("App/CoopRelationDiscoveryView.swift"), encoding: .utf8)
        // Parity relation P0 (MP W2-17): the session host injects the club post feed (帖子 default tab).
        XCTAssertTrue(host.contains("CoopRelationPostFeedFactory.make(community: session.clubCommunityContext"))
        XCTAssertTrue(host.contains("cooperationRelationPostFeed,"))
        XCTAssertNil(CoopRelationPostFeedFactory.make(community: nil, identity: { nil }))
    }
}
