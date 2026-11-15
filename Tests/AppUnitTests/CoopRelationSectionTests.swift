import XCTest
@testable import Questify

final class CoopRelationSectionTests: XCTestCase {
    func testMerchantsIsAlwaysTheDefaultSegmentEvenWhenAFeedIsInjected() {
        XCTAssertEqual(CoopRelationSection.effective(selected: nil, feedAvailable: true), .merchants)
        XCTAssertEqual(CoopRelationSection.effective(selected: nil, feedAvailable: false), .merchants)
        XCTAssertEqual(CoopRelationSection.merchants.relationKind, .merchants)
    }
    func testExplicitSelectionWinsButPostsFallsBackWithoutAFeed() {
        XCTAssertEqual(CoopRelationSection.effective(selected: .posts, feedAvailable: true), .posts)
        XCTAssertEqual(CoopRelationSection.effective(selected: .clubs, feedAvailable: true), .clubs)
        XCTAssertEqual(CoopRelationSection.effective(selected: .clubs, feedAvailable: false), .clubs)
        XCTAssertEqual(CoopRelationSection.effective(selected: .posts, feedAvailable: false), .merchants)
    }
    func testAvailableSegmentsAndRelationKinds() {
        XCTAssertEqual(CoopRelationSection.available(feedAvailable: true), [.merchants, .clubs, .posts])
        XCTAssertEqual(CoopRelationSection.available(feedAvailable: false), [.merchants, .clubs])
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
