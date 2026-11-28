import XCTest

/// Activity sign-up. Design fixture `e1-registration`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptRegistrationFlowTests: XCTestCase {
    func testRegistrationFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "e1-registration", markers: ["registration.form.sheet", "registration.fixture.open"], en: "Activity registration", zh: "活动报名")
    }
}
