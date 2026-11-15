import XCTest
@testable import QuestifyCore

final class PlayRandomPresentationTests: XCTestCase {
    private func wire(_ json: String) throws -> PlayWireValue {
        try JSONDecoder().decode(PlayWireValue.self, from: Data(json.utf8))
    }

    func testRewardDropDecodesFromCompletionPayload() throws {
        let receipt = try wire(#"{"nodeId":42,"drop":{"dropType":1,"mult":2,"extraXp":24,"label":"探索值 ×2","randomReceiptId":"drop-1"}}"#)
        let drop = try XCTUnwrap(PlayRewardDrop.fromReward(receipt))
        XCTAssertEqual(drop.dropType, 1)
        XCTAssertEqual(drop.mult, 2)
        XCTAssertEqual(drop.extraXp, 24)
        XCTAssertEqual(drop.label, "探索值 ×2")
        XCTAssertEqual(drop.randomReceiptID, "drop-1")
        XCTAssertEqual(drop.toastMessage(locale: Locale(identifier: "zh_CN")), "随机掉落：探索值 ×2 +24 探索值")
        XCTAssertEqual(drop.toastMessage(locale: Locale(identifier: "en_US")), "Bonus drop: 探索值 ×2 +24 XP")
    }

    func testDispatchedMysteryTaskDecodesFromCheckinAndScanEntry() throws {
        let checkin = try wire(#"{"nodeId":10,"dispatchedTask":{"poolId":5,"poolName":"咖啡馆盲盒","nodeId":18,"nodeName":"寻找红色咖啡杯","dispatchDate":"2026-11-15","rule":"拍照上传","randomReceiptId":"dispatch-9"}}"#)
        let dispatched = try XCTUnwrap(PlayRandomDispatchedTask.fromResponse(checkin))
        XCTAssertEqual(dispatched.poolID, 5)
        XCTAssertEqual(dispatched.poolName, "咖啡馆盲盒")
        XCTAssertEqual(dispatched.nodeID, 18)
        XCTAssertEqual(dispatched.nodeName, "寻找红色咖啡杯")
        XCTAssertEqual(dispatched.ruleInstructions, "拍照上传")
        XCTAssertEqual(dispatched.revealTitle(locale: Locale(identifier: "zh_CN")), "今日盲盒任务：寻找红色咖啡杯")

        let json = #"{"action":"play","topicId":7,"activityId":12,"nodeId":10,"dispatchedTask":{"poolId":5,"nodeId":18,"nodeName":"寻找红色咖啡杯"}}"#
        let scan = try JSONDecoder().decode(DoorScanResult.self, from: Data(json.utf8))
        XCTAssertEqual(scan.dispatchedTask?.nodeID, 18)
        XCTAssertEqual(scan.dispatchedTask?.nodeName, "寻找红色咖啡杯")
    }

    func testMissingOrMalformedPayloadsReturnNil() throws {
        XCTAssertNil(PlayRewardDrop.fromReward(try wire(#"{"nodeId":1,"drop":null}"#)))
        XCTAssertNil(PlayRandomDispatchedTask.fromResponse(try wire(#"{"nodeId":1,"dispatchedTask":{"nodeId":0}}"#)))
    }

    func testBadgeAndCouponDropFallbackLabelsAndNodeExtras() throws {
        let badge = try XCTUnwrap(PlayRewardDrop(wire: try wire(#"{"dropType":2,"badgeCode":"FRAGMENT_A"}"#)))
        XCTAssertEqual(badge.label, "徽章碎片")
        XCTAssertEqual(badge.badgeCode, "FRAGMENT_A")

        let coupon = try XCTUnwrap(PlayRewardDrop(wire: try wire(#"{"dropType":3,"couponTemplateId":77}"#)))
        XCTAssertEqual(coupon.label, "商家彩蛋券")
        XCTAssertEqual(coupon.couponTemplateID, 77)

        let extras = PlayNodeExtras(raw: try wire(#"{"dispatchedTask":{"poolId":2,"nodeId":33,"nodeName":"探索隐藏角落"}}"#))
        XCTAssertEqual(extras.dispatchedTask?.nodeID, 33)
        XCTAssertEqual(extras.dispatchedTask?.nodeName, "探索隐藏角落")
    }
}
