import XCTest

/// Roam history. Design fixture `r3-roam-history`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptRoamHistoryFlowTests: XCTestCase {
    func testRoamHistoryFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "r3-roam-history", markers: ["roam.experience.history.record", "roam.experience.history"], en: "Roaming history", zh: "漫游记录")
    }
}
