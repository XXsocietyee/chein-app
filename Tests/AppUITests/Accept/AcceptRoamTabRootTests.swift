import XCTest

/// Roam tab root (`RoamMapHomeView`). Design fixture `d2-roam`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptRoamTabRootTests: XCTestCase {
    func testRoamTabRoot() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "d2-roam", markers: ["city.roam.map", "roam.mapHome.sheet"], en: "Lantern Gate", zh: "灯笼门")
    }
}
