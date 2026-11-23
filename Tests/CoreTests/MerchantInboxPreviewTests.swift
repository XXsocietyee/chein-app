import XCTest
@testable import QuestifyCore

/// Parity merchant/index P1 (我的消息): mirrors `pages/merchant/utils/inbox-preview.js`.
final class MerchantInboxPreviewTests: XCTestCase {
    // 2026-11-20 12:00:00 +08:00
    private let now = Date(timeIntervalSince1970: 1_795_147_200)

    private func conversations(_ json: String) throws -> [MessagingConversation] {
        try JSONDecoder().decode([MessagingConversation].self, from: Data(json.utf8))
    }
    private func invites(_ json: String) throws -> [CooperationInvite] {
        try JSONDecoder().decode(CooperationInvites.self, from: Data(json.utf8)).received
    }

    func testEventDateUsesChinaYearAndRollsBackFutureRows() throws {
        let sameYear = try XCTUnwrap(MerchantInboxPreview.eventDate("11-20 09:30", now: now))
        XCTAssertEqual(sameYear.timeIntervalSince1970, now.timeIntervalSince1970 - 2.5 * 3600, accuracy: 1)
        let december = try XCTUnwrap(MerchantInboxPreview.eventDate("12-31 23:00", now: now))
        XCTAssertLessThan(december, now)
        XCTAssertNil(MerchantInboxPreview.eventDate("2026-11-20 09:30", now: now))
        XCTAssertNil(MerchantInboxPreview.eventDate("02-30 09:30", now: now))
    }

    func testMergeNewestFirstTakesThreeAndDropsGroupChats() throws {
        let convs = try conversations(#"[{"conversationId":1,"type":1,"lastMsgAt":"2026-11-20 11:00:00","unread":2,"counterparty":{"nickname":"阿青"}},{"conversationId":4,"type":4,"lastMsgAt":"2026-11-20 11:59:00"},{"conversationId":2,"type":2,"lastMsgAt":"2026-11-18 08:00:00"}]"#)
        let inv = try invites(#"{"sent":[],"received":[{"id":71,"status":0,"topicName":"夜游","createTime":"2026-11-20 11:30:00","partner":{"name":"星光俱乐部"}}]}"#)
        let events = [MerchantEvent(content: "完成一笔到店核销", time: "11-20 10:00", label: "核销", type: "verify")]
        let items = MerchantInboxPreview.build(conversations: convs, invites: inv, events: events, now: now)
        XCTAssertEqual(items.map(\.id), ["invite-71", "conv-1", "event-0"])
        XCTAssertEqual(items[0].invitePartner, "星光俱乐部")
        XCTAssertEqual(items[1].title, "阿青")
        XCTAssertTrue(items[1].unread)
        XCTAssertEqual(items[2].title, "核销")
    }

    func testReadMarksHideItemsAndUndatedSortLast() throws {
        let events = [MerchantEvent(content: "a", time: "bad", type: "income"), MerchantEvent(content: "b", time: "11-20 11:00", type: "income")]
        let all = MerchantInboxPreview.build(conversations: [], invites: [], events: events, now: now, limit: 50)
        XCTAssertEqual(all.map(\.id), ["event-1", "event-0"])
        XCTAssertEqual(all[1].rawTime, "bad")
        let read = Set([all[0].readKey])
        let left = MerchantInboxPreview.build(conversations: [], invites: [], events: events, now: now, isRead: { read.contains($0) })
        XCTAssertEqual(left.map(\.id), ["event-0"])
    }

    func testStationInviteSortsAsNowAndKeepsRawTime() {
        let e = MerchantEvent(content: "站点待接受", time: "11-25 19:00", type: "stationInvite", gameActivityID: 9)
        let item = MerchantInboxPreview.build(conversations: [], invites: [], events: [e], now: now)[0]
        XCTAssertEqual(item.date, now)
        XCTAssertEqual(item.rawTime, "11-25 19:00")
        XCTAssertEqual(item.kind, .event(type: "stationInvite", gameActivityID: 9))
    }

    func testEventDecodesLabelTypeAndGameActivity() throws {
        let e = try JSONDecoder().decode(MerchantEvent.self, from: Data(#"{"content":"x","time":"11-20 10:00","label":"收入到账","type":"income","gameActivityId":"12"}"#.utf8))
        XCTAssertEqual(e.label, "收入到账"); XCTAssertEqual(e.type, "income"); XCTAssertEqual(e.gameActivityID, 12)
        let bare = try JSONDecoder().decode(MerchantEvent.self, from: Data(#"{"content":"x","time":"11-20 10:00"}"#.utf8))
        XCTAssertNil(bare.label); XCTAssertNil(bare.type); XCTAssertNil(bare.gameActivityID)
    }

    func testReadMarksTrimToNewest() {
        var marks: [String: Double] = [:]
        for i in 0..<305 { marks["k\(i)"] = Double(i) }
        let kept = MerchantInboxPreview.trimmedReadMarks(marks)
        XCTAssertEqual(kept.count, 300)
        XCTAssertNil(kept["k0"]); XCTAssertNotNil(kept["k304"])
    }
}
