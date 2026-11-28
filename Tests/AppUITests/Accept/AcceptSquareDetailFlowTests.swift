import XCTest

/// Square detail. Design fixture `d2-square-detail`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptSquareDetailFlowTests: XCTestCase {
    func testSquareDetailFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "d2-square-detail", markers: ["square.detail"], en: "Post", zh: "动态")
    }
}
