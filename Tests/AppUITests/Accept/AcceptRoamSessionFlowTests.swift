import XCTest

/// Roam session. Design fixture `r3-roam-session`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptRoamSessionFlowTests: XCTestCase {
    func testRoamSessionFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "r3-roam-session", markers: ["roam.experience.session"], en: "This roam", zh: "本次漫游")
    }
}
