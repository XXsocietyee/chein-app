import XCTest

/// Organizer console. Design fixture `t5-official-organizer`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptOfficialOrganizerFlowTests: XCTestCase {
    func testOfficialOrganizerFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "t5-official-organizer", markers: ["official.organizer.content", "official.organizer.loading"], en: "Organizer console", zh: "主办控制台")
    }
}
