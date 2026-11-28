import XCTest

/// Pass market. Design fixture `t5-pass-market`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptPassMarketFlowTests: XCTestCase {
    func testPassMarketFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "t5-pass-market", markers: ["passMarket.points"], en: "Passes", zh: "通行证")
    }
}
