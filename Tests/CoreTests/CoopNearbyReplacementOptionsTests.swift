#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

/// MP `pages/coop/nearby/index.js` `chooseChapterReplacement`: one 邀请补位 action per candidate, numbered per chapter.
final class CoopNearbyReplacementOptionsTests: XCTestCase {
    private func row(member: Int, chapter: Int, name: String, offer: Int?) -> MerchantContentValue {
        var fields: [String: MerchantContentValue] = [
            "memberId": .integer(member), "name": .string("老街茶馆"), "chapterId": .integer(chapter), "chapterName": .string(name),
        ]
        if let offer { fields["replacementOfOfferId"] = .integer(offer) }
        return .object(fields)
    }

    func testOneOptionPerCandidateNumberedOnlyWithinARepeatedChapter() {
        let rows = [
            row(member: 7, chapter: 1, name: "灯笼巷", offer: 11),
            row(member: 7, chapter: 2, name: "茶街", offer: 21),
            row(member: 7, chapter: 1, name: "灯笼巷", offer: 12),
            row(member: 7, chapter: 1, name: "灯笼巷", offer: 11),
            row(member: 8, chapter: 1, name: "灯笼巷", offer: 13),
            row(member: 7, chapter: 3, name: "码头", offer: nil),
        ]
        let options = CoopNearbyReplacementOption.options(merchantMemberID: 7, rows: rows)
        XCTAssertEqual(options.map { $0.label(chinese: true) },
                       ["邀请补位 · 灯笼巷（补位 1）", "邀请补位 · 茶街", "邀请补位 · 灯笼巷（补位 2）"])
        XCTAssertEqual(options.map { $0.label(chinese: false) },
                       ["Invite a replacement · 灯笼巷 (option 1)", "Invite a replacement · 茶街", "Invite a replacement · 灯笼巷 (option 2)"])
        XCTAssertEqual(options.map(\.replacementOfOfferID), [11, 21, 12])
        XCTAssertEqual(options.first?.confirmText(chinese: true), "邀请「老街茶馆」补位「灯笼巷」，商家可直接填写供给与节点。")
    }

    func testRowsWithoutAValidPairOrNameAreDropped() {
        let rows = [
            row(member: 7, chapter: 0, name: "灯笼巷", offer: 11),
            row(member: 7, chapter: 1, name: "  ", offer: 11),
            row(member: 7, chapter: 1, name: "灯笼巷", offer: 0),
        ]
        XCTAssertTrue(CoopNearbyReplacementOption.options(merchantMemberID: 7, rows: rows).isEmpty)
        XCTAssertTrue(CoopNearbyReplacementOption.options(merchantMemberID: 0, rows: rows).isEmpty)
    }

    func testFocusMatchesOnlyTheSameMerchantChapterAndOffer() throws {
        let option = CoopNearbyReplacementOption(merchantMemberID: 7, merchantName: "老街茶馆", chapterID: 1, chapterName: "灯笼巷",
                                                 replacementOfOfferID: 11, position: nil)
        let same = try ChapterReplacementInvitationCandidate(row: row(member: 7, chapter: 1, name: "灯笼巷", offer: 11))
        let other = try ChapterReplacementInvitationCandidate(row: row(member: 8, chapter: 1, name: "灯笼巷", offer: 11))
        XCTAssertTrue(option.matches(same))
        XCTAssertFalse(option.matches(other))
    }
}
#endif
