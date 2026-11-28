import XCTest

/// Project editor. Design fixture `t11-fabu`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptProjectEditorFlowTests: XCTestCase {
    func testProjectEditorFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "t11-fabu", markers: ["projectEdit.name"], en: "Edit topic", zh: "编辑主题")
    }
}
