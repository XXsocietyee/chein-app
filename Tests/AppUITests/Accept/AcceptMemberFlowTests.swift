import XCTest

/// Member home. Design fixture `e4-member`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptMemberFlowTests: XCTestCase {
    func testMemberFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "e4-member", markers: ["account.mine.tabs"], en: "Me", zh: "我的")
    }
}
