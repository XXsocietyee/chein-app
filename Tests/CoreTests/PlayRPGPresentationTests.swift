import XCTest
@testable import QuestifyCore

final class PlayRPGPresentationTests: XCTestCase {
    override func tearDown() {
        W8Text.languageOverride = nil
        super.tearDown()
    }

    // MARK: Write availability

    func testEveryPlayWriteSurfaceIsHonestlyUnavailable() {
        for surface in PlayWriteSurface.allCases {
            let availability = PlayWriteAvailability.current(for: surface)
            XCTAssertEqual(availability.surface, surface)
            XCTAssertFalse(availability.isAvailable, "\(surface) has no approved write contract yet")
            XCTAssertFalse(availability.title.isEmpty)
            XCTAssertFalse(availability.message.isEmpty)
        }
    }

    func testUnavailableCopyIsBilingual() {
        W8Text.languageOverride = "en"
        let english = PlayWriteAvailability.current(for: .challengeSubmit)
        W8Text.languageOverride = "zh-Hans"
        let chinese = PlayWriteAvailability.current(for: .challengeSubmit)
        XCTAssertEqual(english.title, "Not available yet")
        XCTAssertEqual(chinese.title, "暂未开放")
        XCTAssertNotEqual(english.message, chinese.message)
    }

    // MARK: Challenge checklist

    private func node(photo: Bool, question: String = "", options: [String] = [], located: Bool = true) -> ChallengePOINode {
        ChallengePOINode(
            id: 7, name: "Clock Tower",
            latitude: located ? 31.2 : nil, longitude: located ? 121.4 : nil,
            radiusM: 100, photoRequired: photo, question: question, options: options)
    }

    func testChecklistListsOnlyApplicableSteps() {
        let full = ChallengePOIChecklist.items(
            node: node(photo: true, question: "Q?", options: ["A", "B"]),
            withinRange: true, distanceMeters: 10, photoConfirmed: false, answerProvided: false)
        XCTAssertEqual(full.map(\.kind), [.arrival, .photo, .answer])

        let minimal = ChallengePOIChecklist.items(
            node: node(photo: false, located: false),
            withinRange: true, distanceMeters: nil, photoConfirmed: false, answerProvided: true)
        XCTAssertTrue(minimal.isEmpty)
        XCTAssertTrue(ChallengePOIChecklist.isReady(minimal))
        XCTAssertEqual(ChallengePOIChecklist.progress(minimal), 1)
    }

    func testChecklistReadinessAndProgress() {
        let target = node(photo: true, question: "Q?", options: ["A", "B"])
        let pending = ChallengePOIChecklist.items(
            node: target, withinRange: false, distanceMeters: 240, photoConfirmed: true, answerProvided: false)
        XCTAssertFalse(ChallengePOIChecklist.isReady(pending))
        XCTAssertEqual(ChallengePOIChecklist.progress(pending), 1.0 / 3.0, accuracy: 0.0001)
        XCTAssertTrue(pending[0].detail.contains("240"))

        let ready = ChallengePOIChecklist.items(
            node: target, withinRange: true, distanceMeters: 12, photoConfirmed: true, answerProvided: true)
        XCTAssertTrue(ChallengePOIChecklist.isReady(ready))
        XCTAssertEqual(ChallengePOIChecklist.progress(ready), 1)
    }

    func testAnswerInputRules() {
        let choice = node(photo: false, question: "Q?", options: ["A", "B"])
        XCTAssertFalse(ChallengePOIChecklist.hasAnswerInput(node: choice, selectedOptionIndex: nil, textAnswer: ""))
        XCTAssertFalse(ChallengePOIChecklist.hasAnswerInput(node: choice, selectedOptionIndex: 5, textAnswer: ""))
        XCTAssertTrue(ChallengePOIChecklist.hasAnswerInput(node: choice, selectedOptionIndex: 1, textAnswer: ""))

        let text = node(photo: false, question: "Q?")
        XCTAssertFalse(ChallengePOIChecklist.hasAnswerInput(node: text, selectedOptionIndex: nil, textAnswer: "   "))
        XCTAssertTrue(ChallengePOIChecklist.hasAnswerInput(node: text, selectedOptionIndex: nil, textAnswer: " x "))

        let none = node(photo: true)
        XCTAssertTrue(ChallengePOIChecklist.hasAnswerInput(node: none, selectedOptionIndex: nil, textAnswer: ""))
    }

    // MARK: Character sheet draft

    private func attributes() -> [CharacterCardAttribute] {
        [
            CharacterCardAttribute(stateKey: "str", label: "Strength", value: 3, min: 0, max: 5, displayType: "stars", persistScope: "topic"),
            CharacterCardAttribute(stateKey: "wit", label: "Wit", value: 9, min: 1, max: 8, displayType: "bar", persistScope: "run")
        ]
    }

    func testDraftClampsInitialValuesAndAdjustments() {
        var draft = CharacterSheetDraft(attributes: attributes())
        XCTAssertEqual(draft.value(for: "wit"), 8, "out-of-range server value is clamped into its range")
        XCTAssertFalse(draft.isDirty)

        draft.adjust("str", by: 10)
        XCTAssertEqual(draft.value(for: "str"), 5)
        XCTAssertFalse(draft.canIncrement("str"))
        draft.adjust("str", by: -10)
        XCTAssertEqual(draft.value(for: "str"), 0)
        XCTAssertFalse(draft.canDecrement("str"))
        draft.adjust("missing", by: 1)
        XCTAssertNil(draft.value(for: "missing"))
    }

    func testDraftTracksChangesAndResets() {
        var draft = CharacterSheetDraft(attributes: attributes())
        draft.adjust("str", by: 1)
        XCTAssertTrue(draft.isDirty)
        XCTAssertEqual(draft.changes, [CharacterSheetChange(stateKey: "str", label: "Strength", from: 3, to: 4)])
        draft.adjust("str", by: -1)
        XCTAssertFalse(draft.isDirty, "returning to the original value is not a change")
        draft.adjust("wit", by: -2)
        draft.reset()
        XCTAssertFalse(draft.isDirty)
        XCTAssertEqual(draft.value(for: "wit"), 8)
    }

    // MARK: Dice roller

    func testRollerIsDeterministicPerSeedAndKeepsBoundedHistory() {
        var first = DiceRollerSession(seed: 42)
        var second = DiceRollerSession(seed: 42)
        for _ in 0..<12 {
            first.roll(mode: .normal, tier: "medium", skillValue: 2)
            second.roll(mode: .normal, tier: "medium", skillValue: 2)
        }
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.history.count, DiceRollerSession.historyLimit)
        XCTAssertEqual(first.history.first?.id, 12, "newest roll first")
    }

    func testRollerRespectsAdvantageAndDisadvantage() throws {
        var session = DiceRollerSession(seed: 7)
        session.roll(mode: .advantage, tier: "easy", skillValue: 0)
        let advantage = try XCTUnwrap(session.receipt)
        XCTAssertEqual(advantage.dice.count, 2)
        XCTAssertEqual(advantage.kept, advantage.dice.max())

        session.roll(mode: .disadvantage, tier: "hard", skillValue: 0)
        let disadvantage = try XCTUnwrap(session.receipt)
        XCTAssertEqual(disadvantage.kept, disadvantage.dice.min())
        XCTAssertEqual(disadvantage.dc, 16)
    }

    func testRollerAnnouncementAndClear() {
        var session = DiceRollerSession(seed: 1)
        W8Text.languageOverride = "en"
        XCTAssertEqual(session.announcement, "D20 ready to roll")
        session.roll(mode: .normal, tier: "medium", skillValue: 0)
        XCTAssertTrue(session.announcement.hasPrefix("D20 shows "))
        session.clear()
        XCTAssertNil(session.receipt)
        XCTAssertTrue(session.history.isEmpty)
    }
}
