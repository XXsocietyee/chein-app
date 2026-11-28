import XCTest

/// Settings. Design fixture `e4-settings`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptSettingsFlowTests: XCTestCase {
    func testSettingsFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "e4-settings", markers: ["settingsNative.openProfile", "settingsNative.profileSignedOut"], en: "Settings", zh: "设置")
    }
}
