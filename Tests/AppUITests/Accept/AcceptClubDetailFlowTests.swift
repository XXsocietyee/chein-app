import XCTest

/// Club detail. Design fixture `d4-detail`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptClubDetailFlowTests: XCTestCase {
    func testClubDetailFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "d4-detail", markers: ["club.detail.introduction", "club.detail.name", "club.detail.loading"], en: "Fixture club 81", zh: "示例俱乐部 81")
    }
}
