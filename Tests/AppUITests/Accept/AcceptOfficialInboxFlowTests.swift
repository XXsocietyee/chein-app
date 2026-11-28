import XCTest

/// Official inbox. Design fixture `t5-official-inbox`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptOfficialInboxFlowTests: XCTestCase {
    func testOfficialInboxFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "t5-official-inbox", markers: ["official.inbox.content"], en: "Official event invitations", zh: "官方活动邀约")
    }
}
