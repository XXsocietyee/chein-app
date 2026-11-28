import XCTest

/// Template shelf. Design fixture `template-topics`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptTemplateShelfFlowTests: XCTestCase {
    func testTemplateShelfFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "template-topics", markers: ["discovery.shelf", "discovery.globalSearch"], en: "Templates", zh: "模板")
    }
}
