import XCTest

/// Club directory. Design fixture `d4-directory`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptClubDirectoryFlowTests: XCTestCase {
    func testClubDirectoryFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "d4-directory", markers: ["club.directory.81", "club.directory.refresh", "club.directory.loading"], en: "Fixture club 81", zh: "示例俱乐部 81")
    }
}
