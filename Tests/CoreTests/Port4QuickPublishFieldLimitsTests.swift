#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

final class Port4QuickPublishFieldLimitsTests: XCTestCase {
    func testSeedIdeaIsTrimmedAndCutToSixty() {
        XCTAssertEqual(QuickPublishFieldLimits.seededIdea("  hello  "), "hello")
        XCTAssertEqual(QuickPublishFieldLimits.seededIdea(String(repeating: "a", count: 80)).count, 60)
        XCTAssertEqual(QuickPublishFieldLimits.seededIdea(nil), "")
    }

    func testClampedDraftAppliesMiniProgramLimits() {
        var draft = QuickPublishDraft()
        draft.title = String(repeating: "t", count: 40)
        draft.description = String(repeating: "d", count: 600)
        var node = QuickPublishNode()
        node.name = String(repeating: "n", count: 31)
        node.description = String(repeating: "s", count: 301)
        draft.nodes = [node]
        let clamped = QuickPublishFieldLimits.clamped(draft)
        XCTAssertEqual(clamped.title.count, 30)
        XCTAssertEqual(clamped.description.count, 500)
        XCTAssertEqual(clamped.nodes[0].name.count, 30)
        XCTAssertEqual(clamped.nodes[0].description.count, 300)
        XCTAssertEqual(QuickPublishFieldLimits.clamp("短", to: 30), "短")
    }
}
#endif
