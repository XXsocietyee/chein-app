import XCTest

/// Enrollment roster. Design fixture `d4-enroll`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptEnrollmentFlowTests: XCTestCase {
    func testEnrollmentFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "d4-enroll", markers: ["club.enroll.screen"], en: "Enrollment roster", zh: "报名名册")
    }
}
