#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

final class QuickPublishValidationTests: XCTestCase {
    override func tearDown() { W8Text.languageOverride = nil; super.tearDown() }

    private func confirmedNode(name: String) throws -> QuickPublishNode {
        var node = QuickPublishNode()
        node.name = name
        node.confirmedPlace = try PublishingPlace(id: "p", name: "Cafe", address: "1 Main", latitude: 31.2, longitude: 121.4)
        return node
    }

    func testEmptyDraftExplainsTitleAndStops() {
        XCTAssertEqual(QuickPublishValidation.issues(QuickPublishDraft()), [.titleMissing, .noStops])
    }

    func testPerStopIssuesAreIndexed() throws {
        var draft = QuickPublishDraft()
        draft.title = "Route"
        var unconfirmed = QuickPublishNode()
        unconfirmed.name = "Dock"
        var unnamed = try confirmedNode(name: "  ")
        unnamed.name = " "
        draft.nodes = [try confirmedNode(name: "A"), unconfirmed, unnamed]
        XCTAssertEqual(QuickPublishValidation.issues(draft), [.placeUnconfirmed(index: 2), .stopNameMissing(index: 3)])
    }

    func testNoIssuesExactlyWhenProfessionalSeedSucceeds() throws {
        var draft = QuickPublishDraft()
        draft.title = "Route"
        draft.nodes = [try confirmedNode(name: "A")]
        XCTAssertTrue(QuickPublishValidation.issues(draft).isEmpty)
        XCTAssertNoThrow(try draft.professionalSeed())
        draft.nodes[0].confirmedPlace = nil
        XCTAssertFalse(QuickPublishValidation.issues(draft).isEmpty)
        XCTAssertThrowsError(try draft.professionalSeed())
    }

    func testMessagesAreBilingual() {
        W8Text.languageOverride = "en"
        XCTAssertEqual(QuickPublishIssue.placeUnconfirmed(index: 2).message, "Confirm the location of stop 2 on the map")
        W8Text.languageOverride = "zh-Hans"
        XCTAssertEqual(QuickPublishIssue.placeUnconfirmed(index: 2).message, "请在地图上确认第 2 站的位置")
    }
}
#endif
