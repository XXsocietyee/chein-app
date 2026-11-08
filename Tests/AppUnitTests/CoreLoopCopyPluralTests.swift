import XCTest
@testable import Questify

final class CoreLoopCopyPluralTests: XCTestCase {
    private let en = CoreLoopCopy(locale: Locale(identifier: "en"))

    func testOnlyExactlyOneIsSingular() {
        XCTAssertEqual(en.tr("1 天内过期"), "Expires in 1 day")
        XCTAssertEqual(en.tr("0 天内过期"), "Expires in 0 days")
        XCTAssertEqual(en.tr("3 天内过期"), "Expires in 3 days")
        XCTAssertEqual(en.tr("剩余可发布 1 个主题"), "1 topic publish left")
        XCTAssertEqual(en.tr("剩余可发布 2 个主题"), "2 topic publishes left")
        XCTAssertEqual(en.tr("全队已完成 1 个节点"), "Team completed 1 node")
        XCTAssertEqual(en.tr("全队已完成 4 个节点"), "Team completed 4 nodes")
    }

    func testPaidAttendeeRefundSentence() {
        let tail = " 位已付款玩家全额退款,不可撤销。活动同时下架。"
        XCTAssertEqual(en.tr("将给 1" + tail), "1 paid attendee will receive a full refund. This cannot be undone and the event will be unlisted.")
        XCTAssertEqual(en.tr("将给 5" + tail), "5 paid attendees will receive a full refund. This cannot be undone and the event will be unlisted.")
    }

    func testChineseLocalePassesThrough() {
        let zh = CoreLoopCopy(locale: Locale(identifier: "zh-Hans"))
        XCTAssertEqual(zh.tr("1 天内过期"), "1 天内过期")
    }
}
