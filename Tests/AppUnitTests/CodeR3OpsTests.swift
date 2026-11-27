import XCTest
import SwiftUI
@testable import Questify

/// Code r3 · ops worker (ui/h-code-r3-ops): the topic editor's 主题详情 count, the one delete rule, the club
/// consequence mapping and the OpsR3 copy.
@MainActor
final class CodeR3OpsTests: XCTestCase {
    /// mp-publish r3: the card counts the MP `TOPIC_DETAIL_ISSUE_KEYS` (subtitle, description, imgUrl, categoryIds);
    /// the name is edited on page 1 and the dates are not in the 主题详情 sheet.
    func testTopicCardCountsTheFourTopicDetailSheetFields() {
        var draft = ProjectEditDraft()
        XCTAssertEqual(ProjectEditTopicCard.missingCount(draft), 4)
        draft.name = "外滩钟声"
        draft.subtitle = "夜里的钟楼"
        draft.description = "  "
        draft.imgUrl = "https://example.invalid/cover.jpg"
        XCTAssertEqual(ProjectEditTopicCard.missingCount(draft), 2, "a blank description still counts as missing")
        draft.description = "三章"
        draft.categoryIDs = [1]
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
        XCTAssertEqual(ClubGovernanceConsequence(.endTopic), .endTopic)
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

    // r4 · club workbench (`170:1744`, ui/r4-club-merchant): only 待审批 is read; unknown counts are "—", never 0.
    func testClubWorkbenchSummaryKeepsUnknownAsDash() throws {
        let unknown = try JSONDecoder().decode(ClubRecord.self, from: Data(#"{"id":9,"isOwner":true}"#.utf8))
        let summary = ClubWorkbenchSummary(club: unknown)
        XCTAssertNil(summary.pendingApprovals)
        XCTAssertEqual(summary.now, .unknown)
        XCTAssertEqual(ClubWorkbenchSummary.display(summary.pendingApprovals), "—")
        XCTAssertEqual(ClubWorkbenchSummary.display(summary.pendingCheckins), "—")
        XCTAssertEqual(ClubWorkbenchSummary.display(summary.sessionsThisWeek), "—")

        let three = try JSONDecoder().decode(ClubRecord.self, from: Data(#"{"id":9,"isOwner":true,"pendingJoinRequestCount":3}"#.utf8))
        XCTAssertEqual(ClubWorkbenchSummary(club: three).now, .approvals(3))
        XCTAssertEqual(ClubWorkbenchSummary.display(3), "3")

        let zero = try JSONDecoder().decode(ClubRecord.self, from: Data(#"{"id":9,"isOwner":true,"pendingJoinRequestCount":0}"#.utf8))
        XCTAssertEqual(ClubWorkbenchSummary(club: zero).now, .clear)
        XCTAssertEqual(ClubWorkbenchSummary.display(0), "0")
    }

    func testClubR4CopyIsBilingual() {
        let zh = Locale(identifier: "zh-Hans"), en = Locale(identifier: "en")
        for key in ["r4club.now.title", "r4club.now.approvals", "r4club.now.approve", "r4club.tile.approvals",
                    "r4club.tile.checkins", "r4club.tile.sessions", "r4club.header.invite", "r4club.header.share"] {
            XCTAssertNotEqual(ClubR4Text.string(key, locale: zh), key, key)
            XCTAssertNotEqual(ClubR4Text.string(key, locale: en), key, key)
        }
        XCTAssertEqual(String(format: ClubR4Text.string("r4club.now.approvals", locale: zh), 3), "3 位入会申请待审批")
        XCTAssertNotEqual(OpsR3Text.string("r3club.consequence.endTopic.title", locale: zh), "r3club.consequence.endTopic.title")
    }

    func testClubR4DateReadsTheSourceDayAsHandbookDate() {
        let zh = Locale(identifier: "zh-Hans")
        // The handbook frame reads 11月15日 周六, which is 2025-11-15 (2026-11-15 is a Sunday).
        let text = ClubR4Date.day("2025-11-15", locale: zh)
        XCTAssertTrue(text.contains("11月15日"), text)
        XCTAssertTrue(text.contains("周六"), text)
        XCTAssertEqual(ClubR4Date.day("下周六", locale: zh), "下周六")
    }

    // r4 · creator map (`237:32444`): the Form preview and the full-bleed page keep distinct identifiers and copy.
    func testEditorMapPreviewAndPageCopy() {
        XCTAssertEqual(ProjectEditNodeMap<EmptyView>.identifier(fullBleed: false), "projectEdit.map")
        XCTAssertEqual(ProjectEditNodeMap<EmptyView>.identifier(fullBleed: true), "projectEdit.mapPage")
        let zh = Locale(identifier: "zh-Hans"), en = Locale(identifier: "en")
        XCTAssertEqual(OpsR3Text.string("editor.map.open", locale: zh), "打开地图")
        XCTAssertEqual(OpsR3Text.string("editor.map.title", locale: en), "Map")
    }

    // r4 · 协作详情 rating (MR-36): a tapped star maps onto the existing review score and its word.
    func testCoopStarMapsOntoTheReviewScore() {
        let zh = Locale(identifier: "zh-Hans")
        XCTAssertEqual(CoopReviewScore(rawValue: String(4))?.scoreValue, 4)
        XCTAssertEqual(CoopReviewScore(rawValue: String(5))?.option(locale: zh).title, "5 星 · 很满意")
        XCTAssertNil(CoopReviewScore(rawValue: String(0)))
    }
}
