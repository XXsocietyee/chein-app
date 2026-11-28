import XCTest

/// Official event detail. Design fixture `t5-official-detail`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptOfficialDetailFlowTests: XCTestCase {
    func testOfficialDetailFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "t5-official-detail", markers: ["official.detail.content", "official.participationState", "official.leaderboard"], en: "Official event", zh: "活动详情")
    }
}
