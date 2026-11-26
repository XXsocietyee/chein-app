import XCTest
@testable import QuestifyCore

final class ClubNonMoneyP0Tests: XCTestCase {
    func testCoopPoolApplyFollowsTheMiniProgramStates() {
        XCTAssertTrue(ClubCoopPoolApplyClient.canApply(state: "open"))
        XCTAssertTrue(ClubCoopPoolApplyClient.canApply(state: "declined"))
        XCTAssertTrue(ClubCoopPoolApplyClient.canApply(state: "withdrawn"))
        XCTAssertFalse(ClubCoopPoolApplyClient.canApply(state: "applied"))
        XCTAssertFalse(ClubCoopPoolApplyClient.canApply(state: "taken"))
        XCTAssertFalse(ClubCoopPoolApplyClient.canApply(state: nil))
    }

    func testTicketShareQueryReachesTheTopicPage() throws {
        let query = ["id": "8", "sourceClubId": "42", "clubCode": "club-42-t8"]
        let link = try XCTUnwrap(MiniProgramPageLink(path: "pages/topic/index/index", query: query))
        XCTAssertEqual(link.query["sourceClubId"], "42")
        XCTAssertEqual(link.query["clubCode"], "club-42-t8")
        XCTAssertNil(MiniProgramPageLink(path: "pages/topic/index/index", query: ["id": "8", "sourceClubId": "0", "clubCode": "EAST"]))
    }

    func testSelfPlayIntentCarriesTheShareChannelCode() throws {
        let topic = try XCTUnwrap(SelfPlayTopicID(rawValue: 8))
        let intent = try TopicSelfPlayIntent(topic: topic, realName: "Synthetic", phone: "13800000000", requestID: "synthetic-intent", sourceClubId: 42, sourceChannelCode: "club-42-t8")
        let body = try JSONDecoder().decode([String: ProjectEditJSON].self, from: JSONEncoder().encode(intent))
        XCTAssertEqual(body["sourceClubId"], .number(42))
        XCTAssertEqual(body["sourceChannelCode"], .string("club-42-t8"))
        let plain = try TopicSelfPlayIntent(topic: topic, realName: "Synthetic", phone: "13800000000", requestID: "synthetic-intent")
        let omitted = try JSONDecoder().decode([String: ProjectEditJSON].self, from: JSONEncoder().encode(plain))
        XCTAssertNil(omitted["sourceChannelCode"])
        XCTAssertThrowsError(try TopicSelfPlayIntent(topic: topic, realName: "Synthetic", phone: "13800000000", requestID: "synthetic-intent", sourceChannelCode: String(repeating: "A", count: 65)))
    }
}
