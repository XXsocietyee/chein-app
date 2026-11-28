import XCTest

/// Official routes. Design fixture `r3-roam-routes`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptOfficialRoutesFlowTests: XCTestCase {
    func testOfficialRoutesFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "r3-roam-routes", markers: ["officialRoute.list"], en: "Official routes", zh: "官方路线")
    }
}
