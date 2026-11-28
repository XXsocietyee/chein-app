import XCTest

/// Play guide. Design fixture `e5-guide`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptPlayGuideFlowTests: XCTestCase {
    func testPlayGuideFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "e5-guide", markers: ["social.guide"], en: "Play guide", zh: "城瘾玩法")
    }
}
