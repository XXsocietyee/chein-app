import XCTest

/// Profile edit. Design fixture `e4-profile-edit`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptProfileEditFlowTests: XCTestCase {
    func testProfileEditFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "e4-profile-edit", markers: ["profile.edit.reload", "profile.edit.loadingFirst"], en: "Edit profile", zh: "个人资料")
    }
}
