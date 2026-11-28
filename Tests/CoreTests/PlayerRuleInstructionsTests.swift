import XCTest
@testable import QuestifyCore

/// Gap #15 / J-19: operator notes in a rule never reach the player. Same cases as MP utils/rule-steps.js stripOperatorNotes.
final class PlayerRuleInstructionsTests: XCTestCase {
    func testClosedNoteIsRemovedInBothBracketWidths() {
        XCTAssertEqual(PlayerRuleText.strippingOperatorNotes("拍一张门头照（运营提示：请商家提前布置）"), "拍一张门头照")
        XCTAssertEqual(PlayerRuleText.strippingOperatorNotes("Find the sign (运营备注: swap monthly) then scan"), "Find the sign then scan")
    }

    func testUnclosedNoteRunsToTheEndOfItsLineOnly() {
        XCTAssertEqual(PlayerRuleText.strippingOperatorNotes("第一步 找到店员(运营提示:记得\n第二步 扫码"), "第一步 找到店员\n第二步 扫码")
    }

    func testOrdinaryBracketsStay() {
        XCTAssertEqual(PlayerRuleText.strippingOperatorNotes("答对 3 题（限时 5 分钟）"), "答对 3 题（限时 5 分钟）")
    }

    func testNoteOnlyRuleIsHidden() {
        XCTAssertNil(PlayerRuleText.playerVisible("（运营提示：仅内部可见）"))
        XCTAssertNil(PlayerRuleText.playerVisible(nil))
        XCTAssertEqual(PlayerRuleText.playerVisible("  扫码打卡（运营提示：x）  "), "扫码打卡")
    }

    func testPlayNodeExposesThePlayerRule() throws {
        let node = try JSONDecoder().decode(PlayNode.self, from: Data(#"{"nodeId":9,"ruleInstructions":"扫码签到(运营提示:店员协助)"}"#.utf8))
        XCTAssertEqual(node.playerRuleInstructions, "扫码签到")
        XCTAssertEqual(node.ruleInstructions, "扫码签到(运营提示:店员协助)")
    }
}
