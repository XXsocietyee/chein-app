import XCTest

/// Growth center. Design fixture `d4-growth`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptGrowthCenterFlowTests: XCTestCase {
    func testGrowthCenterFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "d4-growth", markers: ["growth.refresh"], en: "Growth center", zh: "成长中心")
    }
}
