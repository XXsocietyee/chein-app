import XCTest

/// Privacy. Design fixture `cur6-privacy`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptPrivacyFlowTests: XCTestCase {
    func testPrivacyFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "cur6-privacy", markers: ["privacy.guide.summaryItems"], en: "Privacy", zh: "隐私保护")
    }
}
