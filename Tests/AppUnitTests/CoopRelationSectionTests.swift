import XCTest
@testable import Questify

final class CoopRelationSectionTests: XCTestCase {
    // Parity relation P0/P1: MP 帖子 (default) / 俱乐部; 商家 removed 2026-10-22.
    func testPostsIsTheDefaultWhenAFeedIsInjectedOtherwiseClubs() {
        XCTAssertEqual(CoopRelationSection.effective(selected: nil, feedAvailable: true), .posts)
        XCTAssertEqual(CoopRelationSection.effective(selected: nil, feedAvailable: false), .clubs)
        XCTAssertEqual(CoopRelationSection.merchants.relationKind, .merchants)
    }
    func testExplicitSelectionWinsButPostsFallsBackWithoutAFeed() {
        XCTAssertEqual(CoopRelationSection.effective(selected: .posts, feedAvailable: true), .posts)
        XCTAssertEqual(CoopRelationSection.effective(selected: .clubs, feedAvailable: true), .clubs)
        XCTAssertEqual(CoopRelationSection.effective(selected: .clubs, feedAvailable: false), .clubs)
        XCTAssertEqual(CoopRelationSection.effective(selected: .posts, feedAvailable: false), .clubs)
        XCTAssertEqual(CoopRelationSection.effective(selected: .merchants, feedAvailable: true), .posts)
    }
    func testAvailableSegmentsAndRelationKinds() {
        XCTAssertEqual(CoopRelationSection.available(feedAvailable: true), [.posts, .clubs])
        XCTAssertEqual(CoopRelationSection.available(feedAvailable: false), [.clubs])
        XCTAssertNil(CoopRelationSection.posts.relationKind)
        XCTAssertEqual(CoopRelationSection.clubs.relationKind, .clubs)
        XCTAssertEqual(CoopRelationSection.merchants.relationKind, .merchants)
    }
    func testMerchantRelationPageRouteAndDataSource() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let screen = try String(contentsOf: root.appendingPathComponent("App/MPReviewedPageScreen.swift"), encoding: .utf8)
        XCTAssertTrue(screen.contains("\"pages/merchant/relation/index\""))
        XCTAssertTrue(screen.contains("SessionCoopRelationDiscoveryView(session: session, reader: session.cooperationFlowReader)"))
        XCTAssertEqual(CoopFlowRead.relations.path, "api/merchant/relation-home")
    }
}
