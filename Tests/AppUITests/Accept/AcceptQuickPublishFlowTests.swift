import XCTest

/// Quick publish. Design fixture `publish-quick`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptQuickPublishFlowTests: XCTestCase {
    func testQuickPublishFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "publish-quick", markers: ["publishModes.quick.name", "publishModes.quick.steps"], en: "Quick route setup", zh: "快速配置")
    }
}
