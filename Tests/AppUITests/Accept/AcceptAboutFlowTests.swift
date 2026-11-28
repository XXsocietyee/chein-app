import XCTest

/// About. Design fixture `e4-about`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptAboutFlowTests: XCTestCase {
    func testAboutFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "e4-about", markers: ["settingsNative.about.appName"], en: "About", zh: "关于")
    }
}
