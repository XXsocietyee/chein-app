import XCTest
@testable import QuestifyCore

/// w2-07: mini-program `pages/topic/index` display rules over `TopicDetail`.
final class TopicXcxFactsTests: XCTestCase {
    private func topic(_ extra: [String: Any]) throws -> TopicDetail {
        var raw: [String: Any] = ["id": 31, "name": "Synthetic route"]
        raw.merge(extra) { $1 }
        return try JSONDecoder().decode(TopicDetail.self, from: JSONSerialization.data(withJSONObject: raw))
    }

    func testStatBarSkipsMissingCellsAndFormatsLikeSource() throws {
        let value = try topic(["averageRating": 4.26, "totalTime": 9000, "startDate": "2026-07-04", "endDate": "2026-07-29 00:00:00",
                               "totalMileage": 3.5, "registrationMerchantCount": 4])
        XCTAssertEqual(TopicXcxFacts.statBar(value), [.rating(value: 4.3, stars: 4), .hours(text: "2.5+"), .open(start: "7.4", end: "7.29"),
                                                       .mileage(text: "3.5"), .merchants(4)])
        XCTAssertEqual(TopicXcxFacts.statBar(try topic(["averageRating": 0, "totalTime": 300, "registrationMerchantCount": 0])), [])
        XCTAssertEqual(TopicXcxFacts.statBar(try topic(["totalTime": 7200])), [.hours(text: "2+")])
    }

    func testDurationMatchesFormatTimeToChinese() {
        XCTAssertEqual(TopicXcxFacts.duration(seconds: nil), .zero)
        XCTAssertEqual(TopicXcxFacts.duration(seconds: 30), .underMinute)
        XCTAssertEqual(TopicXcxFacts.duration(seconds: 600), .minutes(10))
        XCTAssertEqual(TopicXcxFacts.duration(seconds: 7200), .hours(2))
        XCTAssertEqual(TopicXcxFacts.duration(seconds: 7260), .hoursMinutes(2, 1))
    }

    func testIncludesOrderAndFallbacks() throws {
        let value = try topic(["totalChapterCount": 3, "locationCount": 8, "templateCount": 2, "audioUrl": "https://example.invalid/a.mp3",
                               "audioDuration": 125, "finishMedalImg": "https://example.invalid/m.png", "completeRewardCouponId": 5])
        XCTAssertEqual(TopicXcxFacts.includes(value), [.chapters(3), .stops(8), .plays(2), .audioMinutes(2), .medal("Synthetic route · 通关"), .coupon])
        XCTAssertEqual(TopicXcxFacts.includes(try topic(["audioUrl": "https://example.invalid/a.mp3", "audioDuration": 20])), [.audio])
    }

    func testChapterCountLeavesEndingsOutOfTheChapterNumber() throws {
        let value = try topic(["totalChapterCount": 7, "chaptersList": [
            ["id": 1, "name": "开场"], ["id": 2, "name": "结局 · 离开"], ["id": 3, "name": "结局二"]
        ]])
        XCTAssertEqual(TopicXcxFacts.buyerChapterCounts(value).story, 5)
        XCTAssertEqual(TopicXcxFacts.buyerChapterCounts(value).endings, 2)
        XCTAssertEqual(TopicXcxFacts.includes(value).first, .chapterBreakdown(story: 5, endings: 2))
        XCTAssertFalse(TopicXcxFacts.hidesGeneratedChapterOrdinal("老门"))
        XCTAssertTrue(TopicXcxFacts.hidesGeneratedChapterOrdinal("结局 · 离开"))
        XCTAssertTrue(TopicXcxFacts.hidesGeneratedChapterOrdinal("终章"))
        XCTAssertTrue(TopicXcxFacts.hidesGeneratedChapterOrdinal("第一章 · 夜"))
        let guide = TopicXcxFacts.chapterGuide(description: "街口有灯。【题目】灯下的数字是多少")
        XCTAssertEqual(guide, "街口有灯。")
        XCTAssertEqual(TopicXcxFacts.heroIntro("一二三四五六七八九十一二三四五六七八九十多余"), "一二三四五六七八九十一二三四五六七八九十…")
        XCTAssertEqual(TopicXcxFacts.heroIntro("短简介"), "短简介")
    }

    func testVenueParsesBothParenthesisStyles() {
        XCTAssertEqual(TopicXcxFacts.venue("示例公园（示例路 1 号）")?.name, "示例公园")
        XCTAssertEqual(TopicXcxFacts.venue("示例公园（示例路 1 号）")?.address, "示例路 1 号")
        XCTAssertEqual(TopicXcxFacts.venue("Sample park (Sample road)")?.address, "Sample road")
        XCTAssertNil(TopicXcxFacts.venue("null"))
        XCTAssertNil(TopicXcxFacts.venue("Plain name")?.address)
    }

    func testSessionTimeSameDayAndSpan() {
        XCTAssertEqual(TopicXcxFacts.sessionTime(start: "2026-12-13 19:30:00", end: "2026-12-13 21:00:00"), "12-13 19:30–21:00")
        XCTAssertEqual(TopicXcxFacts.sessionTime(start: "2026-12-13 19:30:00", end: "2026-12-14 09:00:00"), "12-13 19:30 ~ 12-14 09:00")
        XCTAssertNil(TopicXcxFacts.sessionTime(start: "bad", end: nil))
    }

    func testActionStatesAndOwnerPricingRedirect() throws {
        XCTAssertEqual(TopicXcxFacts.action(try topic(["isSignUp": 1, "lifecycle": 2])), .ticketWallet)
        XCTAssertEqual(TopicXcxFacts.action(try topic(["lifecycle": 7])), .locked(7))
        XCTAssertEqual(TopicXcxFacts.action(try topic(["selfPlay": 1, "selfPlayPrice": 20])), .selfPlay(price: Decimal(20)))
        XCTAssertEqual(TopicXcxFacts.action(try topic([:])), .signUp)
        XCTAssertTrue(TopicXcxFacts.opensPricing(try topic(["isOwner": 1, "lifecycle": 2])))
        XCTAssertFalse(TopicXcxFacts.opensPricing(try topic(["lifecycle": 2])))
    }

    /// PC-B-1-3: MP `topicSaleClosed` — `saleEndAt`, else `endDate`; purchased / locked / merchant-closed keep their own state.
    func testSaleClosedStateAfterDeadline() throws {
        let now = IMInboxTime.parse("2026-11-23 12:00:00")!
        XCTAssertEqual(TopicXcxFacts.action(try topic(["endDate": "2026-11-20 00:00:00", "selfPlay": 1]), now: now), .closed)
        XCTAssertEqual(TopicXcxFacts.action(try topic(["saleEndAt": "2026-11-23 11:59:59", "endDate": "2026-12-31"]), now: now), .closed)
        XCTAssertEqual(TopicXcxFacts.action(try topic(["saleEndAt": "2026-11-30 00:00:00", "endDate": "2026-11-01"]), now: now), .signUp)
        XCTAssertEqual(TopicXcxFacts.action(try topic(["endDate": "bad"]), now: now), .signUp)
        XCTAssertEqual(TopicXcxFacts.action(try topic(["endDate": "2026-11-20", "isSignUp": 1]), now: now), .ticketWallet)
        XCTAssertEqual(TopicXcxFacts.action(try topic(["endDate": "2026-11-20", "lifecycle": 1]), now: now), .locked(1))
    }

    func testLineupPutsClubFirstAndDeduplicatesMerchants() throws {
        let merchant: [String: Any] = ["memberId": 9, "mmsMerchant": ["id": 3, "name": "Synthetic cafe"]]
        let value = try topic(["clubName": "Synthetic club", "clubId": 4, "chaptersList": [["id": 1, "name": "C", "nodes": [
            ["id": 1, "name": "A", "registrationMerchantList": [merchant]], ["id": 2, "name": "B", "registrationMerchantList": [merchant]]]]]])
        let lineup = TopicXcxFacts.lineup(value)
        XCTAssertEqual(lineup.first, .init(kind: .club, targetID: 4, name: "Synthetic club"))
        XCTAssertLessThanOrEqual(lineup.filter { $0.kind == .merchant }.count, 1)
    }

    func testOwnerReviewChipAndPublisherMatchTheTopicPage() throws {
        XCTAssertEqual(try topic(["isOwner": 1, "userStatus": 0, "status": 0]).ownerReviewLabel, "审核中")
        XCTAssertEqual(try topic(["isOwner": 1, "userStatus": 0, "status": 2]).ownerReviewLabel, "未通过")
        XCTAssertEqual(try topic(["isOwner": 1, "userStatus": 0, "status": 3, "rejectReason": "内容安全复核"]).ownerReviewLabel, "审核中")
        XCTAssertEqual(try topic(["isOwner": 1, "userStatus": 0, "status": 3]).ownerReviewLabel, "已下架")
        XCTAssertNil(try topic(["isOwner": 1, "userStatus": 1, "status": 2]).ownerReviewLabel)
        XCTAssertNil(try topic(["userStatus": 0, "status": 2]).ownerReviewLabel)
        let member = try topic(["contentPublisherName": "Ada", "contentPublisherType": "MEMBER", "umsMember": ["avatar": " https://example.invalid/a.png "]])
        XCTAssertEqual(member.publisher, TopicPublisher(name: "Ada", avatar: "https://example.invalid/a.png"))
        XCTAssertNil(try topic(["clubName": "Club", "contentPublisherType": "CLUB", "umsMember": ["avatar": "x"]]).publisher?.avatar)
    }

    func testFreeExploreOwnerOpensTheEditorAndSessionEntryPrefersSignup() throws {
        let editor = try topic(["isOwner": 1, "lifecycle": 2, "productType": 2, "contentPublisherType": "merchant"])
        XCTAssertEqual(TopicXcxFacts.ownerSaleRoute(editor), .some(.editor(scope: "MERCHANT")))
        XCTAssertFalse(TopicXcxFacts.opensPricing(editor))
        XCTAssertEqual(TopicXcxFacts.ownerSaleRoute(try topic(["isOwner": 1, "lifecycle": 2])), .some(.pricing(scope: nil)))
        let session = try topic(["selfPlay": 1, "activityList": [["id": 1, "name": "Night"]]])
        XCTAssertEqual(TopicXcxFacts.action(session, preferSession: true), .signUp)
        XCTAssertEqual(TopicXcxFacts.action(try topic(["selfPlay": 1]), preferSession: true), .selfPlay(price: nil))
    }
}
