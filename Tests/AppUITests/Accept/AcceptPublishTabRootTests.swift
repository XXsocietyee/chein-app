import XCTest

/// Publish tab root (`PublishTabRootView`). Design fixture `hfeat-publish-tab-root`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptPublishTabRootTests: XCTestCase {
    func testPublishTabRoot() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "hfeat-publish-tab-root", markers: ["discovery.shelf", "discovery.unavailable", "discovery.globalSearch"], en: "Publish", zh: "发布")
    }
}
