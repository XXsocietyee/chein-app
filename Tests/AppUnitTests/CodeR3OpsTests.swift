import XCTest
@testable import Questify

/// Code r3 · ops worker (ui/h-code-r3-ops): the topic editor's 主题详情 count, the one delete rule, the club
/// consequence mapping and the OpsR3 copy.
@MainActor
final class CodeR3OpsTests: XCTestCase {
    func testTopicCardCountsTheSixTopicDetailFields() {
        var draft = ProjectEditDraft()
        XCTAssertEqual(ProjectEditTopicCard.missingCount(draft), 6)
        draft.name = "外滩钟声"
        draft.description = "  "
        draft.imgUrl = "https://example.invalid/cover.jpg"
        XCTAssertEqual(ProjectEditTopicCard.missingCount(draft), 4, "a blank description still counts as missing")
        draft.description = "三章"
        draft.categoryIDs = [1]
        draft.startDate = "2026-11-22"
        draft.endDate = "2026-11-30"
        XCTAssertEqual(ProjectEditTopicCard.missingCount(draft), 0)
    }

    func testUndoCenterRestoresThroughTheToastAndTheUndoManager() {
        let center = ProjectEditUndoCenter()
        let manager = UndoManager()
        center.attach(manager)
        var restored = 0
        center.recordDelete(message: "已删除「第三章」", actionName: "删除章节") { restored += 1; return true }
        XCTAssertNotNil(center.toast)
        XCTAssertTrue(manager.canUndo)
        XCTAssertEqual(manager.undoActionName, "删除章节")
        center.toast?.onUndo?()
        XCTAssertEqual(restored, 1)
        XCTAssertNil(center.toast)
        XCTAssertFalse(manager.canUndo)
    }

    func testUndoCenterWithoutAnUndoManagerStillRestoresFromTheToast() {
        let center = ProjectEditUndoCenter()
        var restored = false
        center.recordDelete(message: "已删除「早鸟票」", actionName: "删除票种") { restored = true; return true }
        center.toast?.onUndo?()
        XCTAssertTrue(restored)
    }

    func testHeavyClubCommandsConfirmInTheConsequenceSheet() {
        XCTAssertEqual(ClubGovernanceConsequence(.ban), .ban)
        XCTAssertEqual(ClubGovernanceConsequence(.transferOwner), .transferOwner)
        XCTAssertEqual(ClubGovernanceConsequence(.revokeRole), .revokeRole)
        XCTAssertEqual(ClubGovernanceConsequence(.dissolve), .dissolve)
        for light in [ClubGovernanceMutation.unban, .report, .assignRole, .sendNotification, .cancelOccurrence, .saveCustomer] {
            XCTAssertNil(ClubGovernanceConsequence(light), "\(light) keeps the form's own confirm")
        }
    }

    func testOpsR3CopyIsBilingual() {
        let zh = Locale(identifier: "zh-Hans"), en = Locale(identifier: "en")
        for key in ["editor.title", "editor.canvas.list", "editor.canvas.map", "editor.settings", "r3merchant.refund.reject",
                    "r3merchant.refund.agree", "r3club.invite.title", "r3club.consequence.ban.title", "r3merchant.root.marketing"] {
            XCTAssertNotEqual(OpsR3Text.string(key, locale: zh), key, key)
            XCTAssertNotEqual(OpsR3Text.string(key, locale: en), key, key)
        }
    }
}
