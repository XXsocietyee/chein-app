import XCTest

/// Play runtime. Design fixture `d2-play`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptPlayFlowTests: XCTestCase {
    func testPlayFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "d2-play", markers: ["playx.overview", "playx.loading", "playMode.loading"], en: "City orienteering", zh: "城市定向")
    }
}
