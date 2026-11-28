import XCTest

/// Community square. Design fixture `d2-square`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptSquareFlowTests: XCTestCase {
    func testSquareFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "d2-square", markers: ["square.browser", "square.feed"], en: "Square", zh: "广场")
    }
}
