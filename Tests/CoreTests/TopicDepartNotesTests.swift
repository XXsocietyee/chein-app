import XCTest
@testable import QuestifyCore

/// Route detail 「出发前」 (port P3 / C13; MP `pages/topic/utils/depart-notes.js`).

final class TopicDepartNotesTests: XCTestCase {
    private func topic(_ json: String) throws -> TopicDetail {
        try JSONDecoder().decode(TopicDetail.self, from: Data(json.utf8))
    }

    func testStoryKeepsNarrativeAndLiftsPracticalLines() {
        let split = TopicDepartNotes.split("今晚，猫没有回家。你要沿着老街找到它。过马路请注意红绿灯。\n\n【注意事项】\n1. 部分店铺18点打烊；\n2. 带好充电宝")
        XCTAssertEqual(split.story, "今晚，猫没有回家。你要沿着老街找到它。")
        XCTAssertEqual(split.notes, ["过马路请注意红绿灯", "部分店铺18点打烊", "带好充电宝"])
    }

    func testEmptyOrLiteralNullDescriptionHasNothing() {
        XCTAssertEqual(TopicDepartNotes.split(nil), .init(story: "", notes: []))
        XCTAssertEqual(TopicDepartNotes.split(" null "), .init(story: "", notes: []))
    }

    func testItemsUseOnlyFactsTheRouteSends() throws {
        // Ported from chengyin-ios; adapted to the MP buyOptions rules: tickets count only with sessions
        // (`activityList`), same-name tickets fold into the lowest 起 price, `teamSize` ≥ 2 is shared.
        let value = try topic(#"{"id":7,"name":"猫","selfPlay":1,"selfPlayPrice":30,"locationCount":6,"templateCount":3,"totalChapterCount":2,"productType":1,"finishMedalName":"老街寻猫","completeRewardCouponId":12,"activityList":[{"id":1,"name":"周六场"}],"omsTicketList":[{"id":1,"name":"双人票","price":59,"teamSize":2},{"id":2,"name":"双人票","price":49,"teamSize":2},{"id":3,"name":"单人票","price":29},{"id":4,"name":"待定票"}],"description":"雾很大。营业时间以门店为准。"}"#)
        XCTAssertEqual(TopicDepartNotes.items(for: value), [
            .price(name: nil, amount: 30, from: false, sharedBy: nil),
            .price(name: "双人票", amount: 49, from: true, sharedBy: 2),
            .price(name: "单人票", amount: 29, from: false, sharedBy: nil),
            .includes([.chapters(2), .stops(6), .plays(3)]),
            .pauseResume,
            .badge(name: "老街寻猫"),
            .coupon,
            .note("营业时间以门店为准"),
        ])
        XCTAssertEqual(TopicDepartNotes.split(value.introduction).story, "雾很大。")
    }

    func testTicketsWithoutSessionsAreNotPricesAndMedalImageFallsBackToRouteName() throws {
        let value = try topic(#"{"id":7,"name":"猫","productType":1,"finishMedalImg":"medal.png","omsTicketList":[{"id":1,"name":"双人票","price":49,"teamSize":2}]}"#)
        XCTAssertEqual(TopicDepartNotes.items(for: value), [.pauseResume, .badge(name: "猫 · 通关")])
    }

    func testFreeExplorationWithNothingKnownListsNothing() throws {
        XCTAssertEqual(TopicDepartNotes.items(for: try topic(#"{"id":7,"name":"漫游","productType":2,"finishMedalName":"  "}"#)), [])
    }
}
