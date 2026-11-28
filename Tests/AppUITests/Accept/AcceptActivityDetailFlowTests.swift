import XCTest

/// Activity detail. Design fixture `e1-activity-detail`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptActivityDetailFlowTests: XCTestCase {
    func testActivityDetailFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "e1-activity-detail", markers: ["activity.detail.content", "activity.more.toggle"], en: "More info", zh: "更多信息")
    }
}
