import XCTest

/// Badge wall. Design fixture `d4-badges`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptBadgeWallFlowTests: XCTestCase {
    func testBadgeWallFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "d4-badges", markers: ["objects.badge.summary", "profile.badges.emptyState"], en: "My badges", zh: "我的徽章")
    }
}
