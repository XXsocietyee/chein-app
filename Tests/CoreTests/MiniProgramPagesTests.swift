import XCTest
@testable import QuestifyCore

final class MiniProgramPagesTests: XCTestCase {
    func testEveryPageRoundTripsThroughItsPath() {
        XCTAssertGreaterThan(MiniProgramPage.allCases.count, 150)
        for page in MiniProgramPage.allCases {
            XCTAssertEqual(MiniProgramPage(path: page.rawValue), page)
            XCTAssertEqual(MiniProgramPage(path: "/" + page.rawValue + "?id=1"), page)
        }
        XCTAssertEqual(Set(MiniProgramPage.allCases.map(\.rawValue)).count, MiniProgramPage.allCases.count)
    }
    func testNativeContentSourcePathsAreInTheTableAndTyped() {
        let expected: [NativeContentTarget.Kind: (Int) -> AppRoute] = [
            .activity: { .activity($0) }, .club: { .club($0) }, .topic: { .topic($0) }, .template: { .template($0) },
            .post: { .post($0) }, .poi: { .poi($0) }, .roamSession: { .roamSession($0) },
        ]
        for kind in NativeContentTarget.Kind.allCases {
            XCTAssertNotNil(MiniProgramPage(path: kind.sourcePath), kind.sourcePath)
            XCTAssertEqual(AppRoute(miniProgramPath: kind.sourcePath, id: 7), expected[kind]?(7), kind.sourcePath)
        }
    }
    func testBadIdOrUnknownPageIsUnsupportedNeverTyped() {
        XCTAssertEqual(AppRoute(miniProgramPath: "/pages/activity/detail/index", id: nil), .unsupported("pages/activity/detail/index"))
        XCTAssertEqual(AppRoute(miniProgramPath: "/pages/activity/detail/index", id: 0), .unsupported("pages/activity/detail/index"))
        XCTAssertEqual(AppRoute(miniProgramPath: "/pages/activity/detail/index", id: -3), .unsupported("pages/activity/detail/index"))
        XCTAssertEqual(AppRoute(miniProgramPath: "/pages/does/not/exist"), .unsupported("/pages/does/not/exist"))
    }
    func testUntypedKnownPageIsUnsupportedWithBarePath() {
        XCTAssertEqual(AppRoute(miniProgramPath: "/pages/order/index", id: 5), .unsupported("pages/order/index"))
    }
    func testHomeFeedBridgeRoundTripsAndRouteIsCodable() throws {
        for d in [HomeFeedDestination.activity(3), .topic(9)] { XCTAssertEqual(AppRoute(d).homeFeedDestination, d) }
        XCTAssertNil(AppRoute.club(1).homeFeedDestination)
        let routes: [AppRoute] = [.activity(1), .poi(2), .unsupported("pages/x/y")]
        let data = try JSONEncoder().encode(routes)
        XCTAssertEqual(try JSONDecoder().decode([AppRoute].self, from: data), routes)
    }
}
