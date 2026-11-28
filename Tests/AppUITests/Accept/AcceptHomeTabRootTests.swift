import XCTest

/// Home tab root (`HomeFeedView`). Design fixture `d2-home`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptHomeTabRootTests: XCTestCase {
    func testHomeTabRoot() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "d2-home", markers: ["homeFeed.kind", "homeFeed.empty", "homeFeed.feedFailed", "homeFeed.configurationUnavailable"], en: "Home", zh: "首页")
    }
}
