import XCTest

/// Club tab root (`ClubHomeView`). Design fixture `core-club-tab-facts`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptClubTabRootTests: XCTestCase {
    func testClubTabRoot() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "core-club-tab-facts", markers: ["club.openDirectory", "club.fixture.notice"], en: "Discover", zh: "发现")
    }
}
