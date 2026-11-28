import XCTest

/// Official events. Design fixture `e1-official`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptOfficialEventsFlowTests: XCTestCase {
    func testOfficialEventsFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "e1-official", markers: ["official.fixture.guest"], en: "Official events", zh: "官方活动")
    }
}
