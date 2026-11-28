import XCTest

/// Messages inbox. Design fixture `d2-inbox`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptInboxFlowTests: XCTestCase {
    func testInboxFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "d2-inbox", markers: ["messaging.list.scope"], en: "Messages", zh: "消息")
    }
}
