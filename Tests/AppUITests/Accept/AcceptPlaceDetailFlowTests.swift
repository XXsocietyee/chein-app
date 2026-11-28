import XCTest

/// Place detail. Design fixture `r3-roam-poi`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptPlaceDetailFlowTests: XCTestCase {
    func testPlaceDetailFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "r3-roam-poi", markers: ["roam.place.header"], en: "Bund Origin courtyard", zh: "外滩源庭院")
    }
}
