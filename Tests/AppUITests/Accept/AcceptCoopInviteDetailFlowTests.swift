import XCTest

/// Cooperation invite detail. Design fixture `t5-coop-invite-detail`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptCoopInviteDetailFlowTests: XCTestCase {
    func testCoopInviteDetailFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "t5-coop-invite-detail", markers: ["cooperation.detail.status", "cooperation.detail.partner"], en: "Collab details", zh: "协作详情")
    }
}
