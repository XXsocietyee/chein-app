import XCTest

/// Official published. Design fixture `t5-official-mine`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptOfficialPublishedFlowTests: XCTestCase {
    func testOfficialPublishedFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "t5-official-mine", markers: ["official.published.content"], en: "My published", zh: "我发布的")
    }
}
