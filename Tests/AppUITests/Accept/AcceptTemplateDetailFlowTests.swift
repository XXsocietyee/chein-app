import XCTest

/// Template detail. Design fixture `template-detail`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptTemplateDetailFlowTests: XCTestCase {
    func testTemplateDetailFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "template-detail", markers: ["discovery.detail.content", "templateAuthor.adopt"], en: "Play details", zh: "玩法详情")
    }
}
