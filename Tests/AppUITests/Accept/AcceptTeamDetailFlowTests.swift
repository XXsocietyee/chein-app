import XCTest

/// Team detail. Design fixture `t5-team-detail`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptTeamDetailFlowTests: XCTestCase {
    func testTeamDetailFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "t5-team-detail", markers: ["team.detail.card", "team.loading"], en: "Synthetic harbor companions", zh: "Synthetic harbor companions")
    }
}
