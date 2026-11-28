import XCTest

/// My teams. Design fixture `r3-roam-my-teams`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptMyTeamsFlowTests: XCTestCase {
    func testMyTeamsFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "r3-roam-my-teams", markers: ["nearby.mine.map", "nearby.section"], en: "My teams", zh: "我的队伍")
    }
}
