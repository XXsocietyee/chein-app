import XCTest
@testable import Questify

@MainActor final class CoopRelationPostFeedFactoryTests: XCTestCase {
    func testNoCommunityContextMeansNoPostsSegment() {
        let hook = CoopRelationPostFeedFactory.make(community: nil, identity: { nil })
        XCTAssertNil(hook)
        XCTAssertEqual(CoopRelationSection.effective(selected: nil, feedAvailable: hook != nil), .merchants)
        XCTAssertEqual(CoopRelationSection.available(feedAvailable: hook != nil), [.merchants, .clubs])
    }

    func testSessionHostCallsPostFeedFactory() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let host = try String(contentsOf: root.appendingPathComponent("App/CoopRelationDiscoveryView.swift"), encoding: .utf8)
        XCTAssertTrue(host.contains("CoopRelationPostFeedFactory.make"))
        XCTAssertTrue(host.contains("session.clubCommunityContext"))
        XCTAssertNil(CoopRelationPostFeedFactory.make(community: nil, identity: { nil }))
    }
}
