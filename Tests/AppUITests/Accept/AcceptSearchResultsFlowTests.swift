import XCTest

/// Search results. Design fixture `d2-search-results`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptSearchResultsFlowTests: XCTestCase {
    func testSearchResultsFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "d2-search-results", markers: ["searchMap.resultScopes", "searchMap.loading", "searchMap.refreshResults", "searchMap.empty"], en: "Lantern Night Walk", zh: "灯笼夜行")
    }
}
