import XCTest

/// Topic template preview. Design fixture `topic-preview`. English and zh-Hans. Lane2 execution is not done on this VM.
final class AcceptTopicPreviewFlowTests: XCTestCase {
    func testTopicPreviewFlow() {
        continueAfterFailure = true
        XCUIAcceptSmoke.cover(self, fixture: "topic-preview", markers: ["discovery.topicPreview.content", "topicTemplate.use", "topicTemplate.use.unavailable"], en: "Route template", zh: "主题模板")
    }
}
