import XCTest
@testable import QuestifyCore

/// mp-publish-b: 玩法设置 field copy from MP `publish/temp/index.wxml:136-174` (random · steps · estimate).
final class TemplateCreatorMPCopyTests: XCTestCase {
    private func field(_ family: TemplateCreatorFamily, _ id: String) -> TemplateCreatorField? {
        TemplateCreatorSchema.fields(family).first { $0.id == id }
    }

    func testRandomFieldsUseMPLabelsAndPlaceholders() throws {
        XCTAssertEqual(field(.random, "deckName")?.labelKey, "creator.mp.random.deckName")
        XCTAssertEqual(field(.random, "deckName")?.promptKey, "creator.mp.random.deckName.prompt")
        XCTAssertEqual(field(.random, "drawCount")?.labelKey, "creator.mp.random.drawCount")
        let items = try XCTUnwrap(field(.random, "items"))
        guard case .rows(let card, _, _, let identity) = items.kind else { return XCTFail("items are rows") }
        XCTAssertEqual(identity, "id")
        XCTAssertEqual(card.first { $0.id == "id" }?.promptKey, "creator.mp.random.id.prompt")
        XCTAssertEqual(card.first { $0.id == "id" }?.labelKey, "creator.field.id")
        XCTAssertEqual(card.first { $0.id == "weight" }?.labelKey, "creator.mp.random.weight")
        XCTAssertEqual(card.first { $0.id == "content" }?.promptKey, "creator.mp.random.content.prompt")
    }

    func testStepsAndEstimateUseMPCopyWithoutChangingWireFields() {
        XCTAssertEqual(field(.steps, "eyebrow")?.labelKey, "creator.mp.steps.eyebrow")
        XCTAssertNil(field(.steps, "goal")?.promptKey)
        XCTAssertEqual(TemplateCreatorSchema.fields(.estimate).map(\.id), ["title", "unit", "min", "max", "answer", "tolerance", "reveal", "xp"])
        XCTAssertEqual(field(.estimate, "answer")?.labelKey, "creator.mp.estimate.answer")
        XCTAssertEqual(field(.estimate, "reveal")?.promptKey, "creator.mp.estimate.reveal.prompt")
        XCTAssertEqual(field(.estimate, "tolerance")?.labelKey, "creator.field.tolerance")
        // The qa reveal toggle keeps its shared label.
        XCTAssertEqual(field(.qa, "reveal")?.labelKey, "creator.field.reveal")
    }
}
