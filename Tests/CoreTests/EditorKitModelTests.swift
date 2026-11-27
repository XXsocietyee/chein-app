import XCTest
@testable import QuestifyCore

/// Design hand-off r1 · review/full-config.md: Editor kit rules.
final class EditorKitModelTests: XCTestCase {
    func testDetentTableFollowsSectionThree() {
        XCTAssertEqual(EditorSheetFamily.node.detents, [.fraction(0.62), .large])
        XCTAssertEqual(EditorSheetFamily.chapter.detents, [.medium, .large])
        XCTAssertEqual(EditorSheetFamily.topicDetail.detents, [.large])
        XCTAssertEqual(EditorSheetFamily.textName.detents, [.height(200)])
        XCTAssertEqual(EditorSheetFamily.scanReply.detents, [.fit, .large])
        XCTAssertEqual(EditorSheetFamily.confirmImport.detents, [.large])
        XCTAssertEqual(EditorSheetFamily.publishResult.detents, [.fit])
        XCTAssertFalse(EditorSheetFamily.publishResult.isResizable)
        XCTAssertTrue(EditorSheetFamily.gameplayPicker.isResizable)
        XCTAssertEqual(EditorSheetFamily.gameplayPicker.openingDetent, .fraction(0.62))
        for family in EditorSheetFamily.allCases { XCTAssertFalse(family.detents.isEmpty, family.rawValue) }
    }

    func testFitHeightIsCappedAtSixtyTwoPercent() {
        XCTAssertEqual(EditorSheetDetentPlan.fitHeight(content: 200, chrome: 100, screen: 800), 300)
        XCTAssertEqual(EditorSheetDetentPlan.fitHeight(content: 900, chrome: 100, screen: 800), 800 * 0.62, accuracy: 0.001)
        XCTAssertEqual(EditorSheetDetentPlan.fitHeight(content: -5, chrome: 40, screen: 0), 40)
    }

    func testScrollOnlyAtLargestDetent() {
        XCTAssertFalse(EditorSheetDetentPlan.scrollEnabled(current: .medium, family: .chapter))
        XCTAssertTrue(EditorSheetDetentPlan.scrollEnabled(current: .large, family: .chapter))
        XCTAssertTrue(EditorSheetDetentPlan.scrollEnabled(current: .fit, family: .publishResult))
    }

    func testReorderMatchesArrayMoveSemantics() {
        var items = ["a", "b", "c", "d"]
        EditorReorder.move(&items, fromOffsets: IndexSet(integer: 0), toOffset: 3)
        XCTAssertEqual(items, ["b", "c", "a", "d"])
        EditorReorder.move(&items, fromOffsets: IndexSet(integer: 3), toOffset: 0)
        XCTAssertEqual(items, ["d", "b", "c", "a"])
        EditorReorder.move(&items, fromOffsets: IndexSet([0, 2]), toOffset: 4)
        XCTAssertEqual(items, ["b", "a", "d", "c"])
        EditorReorder.move(&items, fromOffsets: IndexSet(integer: 9), toOffset: 0)
        XCTAssertEqual(items, ["b", "a", "d", "c"])
    }

    func testMenuMovesAreOneStepAndBounded() {
        var items = [1, 2, 3]
        XCTAssertFalse(EditorReorder.apply(.moveUp, at: 0, in: &items))
        XCTAssertTrue(EditorReorder.apply(.moveDown, at: 0, in: &items))
        XCTAssertEqual(items, [2, 1, 3])
        XCTAssertTrue(EditorReorder.apply(.moveUp, at: 2, in: &items))
        XCTAssertEqual(items, [2, 3, 1])
        XCTAssertFalse(EditorReorder.apply(.moveDown, at: 2, in: &items))
        XCTAssertFalse(EditorReorder.apply(.delete, at: 1, in: &items))
        XCTAssertEqual(EditorRowAction.allCases.last, .delete)
        XCTAssertTrue(EditorRowAction.delete.isDestructive)
    }

    func testRuleStepsReorderRewritesStoredOrderOnly() throws {
        var steps = TemplateAuthoringRuleSteps(raw: "One\nTwo\nThree")
        let ids = steps.rows.map(\.id)
        try steps.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        XCTAssertEqual(steps.rows.map(\.id), [ids[2], ids[0], ids[1]])
        XCTAssertEqual(steps.storedText, "Three\nOne\nTwo")
        XCTAssertThrowsError(try steps.move(fromOffsets: IndexSet(integer: 5), toOffset: 0))
        var untouched = TemplateAuthoringRuleSteps(raw: " One \nTwo")
        try untouched.move(fromOffsets: IndexSet(integer: 0), toOffset: 1)
        XCTAssertEqual(untouched.storedText, " One \nTwo", "a no-op move keeps the original bytes")
    }

    func testAttemptLimitReplacesMagicZero() {
        XCTAssertEqual(EditorAttemptLimit(legacy: 0), .unlimited)
        XCTAssertEqual(EditorAttemptLimit(legacy: nil), .unlimited)
        XCTAssertEqual(EditorAttemptLimit(legacy: 4), .limited(4))
        XCTAssertEqual(EditorAttemptLimit.unlimited.legacyValue, 0)
        XCTAssertEqual(EditorAttemptLimit.unlimited.settingUnlimited(false), .limited(3))
        XCTAssertEqual(EditorAttemptLimit.limited(7).settingUnlimited(false), .limited(7))
        XCTAssertEqual(EditorAttemptLimit.limited(7).settingUnlimited(true), .unlimited)
    }

    func testMillisecondsShowAsSecondsWithOneDecimal() {
        XCTAssertEqual(EditorNumber.secondsText(milliseconds: 300), "0.3")
        XCTAssertEqual(EditorNumber.secondsText(milliseconds: 1250), "1.3")
        XCTAssertEqual(EditorNumber.milliseconds(secondsText: "0.3"), 300)
        XCTAssertNil(EditorNumber.milliseconds(secondsText: "-1"))
        XCTAssertNil(EditorNumber.milliseconds(secondsText: "abc"))
        XCTAssertTrue(EditorNumber.isOutOfRange(0, 1...10))
        XCTAssertFalse(EditorNumber.isOutOfRange(nil, 1...10))
    }

    func testUnknownValuesShowDash() {
        XCTAssertEqual(EditorUnknown.display(nil as String?), "—")
        XCTAssertEqual(EditorUnknown.display("  "), "—")
        XCTAssertEqual(EditorUnknown.display("钟楼"), "钟楼")
        XCTAssertEqual(EditorUnknown.display(nil as Int?), "—")
        XCTAssertEqual(EditorUnknown.display(39), "39")
    }

    func testCounterAndClamp() {
        let counter = EditorCounter(text: "城市漫游", limit: 4)
        XCTAssertEqual(counter.text, "4/4")
        XCTAssertTrue(counter.isAtLimit)
        XCTAssertEqual(EditorCounter.clamp("城市漫游团", limit: 4), "城市漫游")
        XCTAssertEqual(EditorCounter.clamp("短", limit: 4), "短")
    }

    func testReviewStatusNeverShowsRawCodes() {
        XCTAssertEqual(EditorReviewStatus(raw: "PENDING"), .pending)
        XCTAssertEqual(EditorReviewStatus(raw: "rejected"), .rejected)
        XCTAssertEqual(EditorReviewStatus(raw: "APPROVED"), .approved)
        XCTAssertEqual(EditorReviewStatus(raw: "SOMETHING_NEW"), .unknown)
        XCTAssertEqual(EditorReviewStatus(raw: nil), .unknown)
        for status in [EditorReviewStatus.pending, .rejected, .approved, .draft, .unknown] {
            XCTAssertTrue(status.key.hasPrefix("editorKit.review."))
        }
    }

    func testOutlineErrorsAndFirstError() {
        let errors = EditorOutline.errors(forIssues: ["templateAuthor.validation.descriptionLength", "templateRules.rowLimit", "playkitAuthor.validation.compass.xp"])
        XCTAssertEqual(errors, [.info, .rules, .reward])
        let outline = EditorOutline(current: .gameplay, errors: [.reward, .rules], done: [.info])
        XCTAssertEqual(outline.firstError, .rules)
        XCTAssertEqual(outline.state(.rules), .error)
        XCTAssertEqual(outline.state(.gameplay), .current)
        XCTAssertEqual(outline.state(.info), .done)
        XCTAssertEqual(outline.state(.tools), .normal)
        // mp-r3-publish: page order follows MP temp/index.wxml:1213 (gameplay first).
        XCTAssertEqual(EditorOutlineSection.allCases.map(\.rawValue), ["gameplay", "rules", "info", "reward", "feedback", "tools"])
    }

    func testStepProgressOnlyAllowsVisitedSegments() {
        var steps = EditorStepProgress(count: 3)
        XCTAssertFalse(steps.canSelect(1))
        XCTAssertTrue(steps.advance())
        XCTAssertTrue(steps.advance())
        XCTAssertFalse(steps.advance())
        XCTAssertTrue(steps.select(0))
        XCTAssertTrue(steps.canSelect(2))
        XCTAssertTrue(steps.isFilled(0))
        XCTAssertFalse(steps.isFilled(1))
        XCTAssertFalse(steps.select(3))
    }

    func testTicketSummaryUsesLowestKnownPoints() {
        XCTAssertEqual(EditorTicketSummary(prices: [59, 39, nil]).lowestPoints, 39)
        XCTAssertEqual(EditorTicketSummary(prices: [59, 39, nil]).kinds, 3)
        XCTAssertNil(EditorTicketSummary(prices: [nil]).lowestPoints)
        XCTAssertTrue(EditorTicketSummary(prices: []).isEmpty)
    }

    func testNoSheetOnASheet() {
        XCTAssertEqual(EditorPresentationRule.mode(sheetDepth: 0), .sheet)
        XCTAssertEqual(EditorPresentationRule.mode(sheetDepth: 1), .push)
        XCTAssertEqual(EditorPresentationRule.mode(sheetDepth: 2), .push)
    }

    func testChoiceControlRuleKeepsOwnerDropdownForD20() {
        XCTAssertEqual(EditorChoiceControl.forChoices(count: 3, longestLabel: 2, isVisual: false), .segmented)
        XCTAssertEqual(EditorChoiceControl.forChoices(count: 3, longestLabel: 2, isVisual: false, ownerDropdown: true), .popUp)
        XCTAssertEqual(EditorChoiceControl.forChoices(count: 5, longestLabel: 2, isVisual: false), .popUp)
        XCTAssertEqual(EditorChoiceControl.forChoices(count: 5, longestLabel: 2, isVisual: true), .tiles)
    }

    func testSaveStatesUseColourOnlyOnFailure() {
        XCTAssertEqual(EditorSaveState.allCases.filter(\.usesErrorColour), [.failed])
        XCTAssertEqual(EditorSaveState.saved.key, "editorKit.save.saved")
    }
}
