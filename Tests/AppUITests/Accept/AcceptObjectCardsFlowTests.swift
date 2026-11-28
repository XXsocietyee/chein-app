import XCTest

/// Object cards. Design fixture `album-cards`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptObjectCardsFlowTests: XCTestCase {
    func testObjectCardsFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "album-cards", markers: ["objects.collection"], en: "Items", zh: "藏品")
    }
}
