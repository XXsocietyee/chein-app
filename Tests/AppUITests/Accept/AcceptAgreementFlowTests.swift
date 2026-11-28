import XCTest

/// User agreement. Design fixture `cur6-agreement`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptAgreementFlowTests: XCTestCase {
    func testAgreementFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "cur6-agreement", markers: ["settingsNative.legal.loading", "settingsNative.legal.noAcceptance"], en: "User service agreement", zh: "用户服务协议")
    }
}
