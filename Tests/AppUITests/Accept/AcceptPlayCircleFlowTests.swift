import XCTest

/// Play circle link. Design fixture `e5-circle-link`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptPlayCircleFlowTests: XCTestCase {
    func testPlayCircleFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "e5-circle-link", markers: ["playx.circleLink.missing", "playx.circleLink.home"], en: "Free exploration", zh: "自由探索")
    }
}
