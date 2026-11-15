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
        // Audit 2026-11-14 (ui/h-audit-bugs): the general club community feed is not this relation's posts, so the
        // session host no longer injects it and the Posts segment stays hidden until a relation-scoped source exists.
        XCTAssertFalse(host.contains("CoopRelationPostFeedFactory.make"))
        XCTAssertFalse(host.contains("session.clubCommunityContext"))
        XCTAssertFalse(host.contains("cooperationRelationPostFeed,"))
        XCTAssertNil(CoopRelationPostFeedFactory.make(community: nil, identity: { nil }))
    }
}
