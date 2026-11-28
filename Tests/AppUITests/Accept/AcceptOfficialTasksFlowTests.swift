import XCTest

/// Official tasks. Design fixture `r3-roam-tasks`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptOfficialTasksFlowTests: XCTestCase {
    func testOfficialTasksFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "r3-roam-tasks", markers: ["roam.tasks.browser"], en: "Official roaming events", zh: "漫游官方活动")
    }
}
