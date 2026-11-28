import XCTest

/// Welcome. Design fixture `welcome`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptWelcomeFlowTests: XCTestCase {
    func testWelcomeFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "welcome", markers: ["welcome.player", "welcome.browse"], en: "Browse as a guest", zh: "先逛一逛")
    }
}
