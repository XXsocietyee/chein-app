import XCTest

/// Search. Design fixture `d2-search`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptSearchFlowTests: XCTestCase {
    func testSearchFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "d2-search", markers: ["searchMap.citySearch", "searchMap.more"], en: "Find on the map", zh: "在地图上找")
    }
}
