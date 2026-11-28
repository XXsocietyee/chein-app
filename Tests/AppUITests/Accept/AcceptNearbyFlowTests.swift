import XCTest

/// Nearby teams. Design fixture `r3-roam-nearby`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptNearbyFlowTests: XCTestCase {
    func testNearbyFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "r3-roam-nearby", markers: ["nearby.section", "nearby.search", "nearby.w208.header"], en: "Nearby teams", zh: "附近的队伍")
    }
}
