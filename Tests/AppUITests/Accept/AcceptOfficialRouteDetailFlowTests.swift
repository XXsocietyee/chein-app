import XCTest

/// Official route. Design fixture `r3-roam-route`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptOfficialRouteDetailFlowTests: XCTestCase {
    func testOfficialRouteDetailFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "r3-roam-route", markers: ["officialRoute.detail"], en: "Bund night walk", zh: "外滩夜色步行线")
    }
}
