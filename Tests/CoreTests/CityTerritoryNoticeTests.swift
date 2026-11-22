import XCTest
@testable import QuestifyCore

/// fix/city-gaps-r3 §4: the cityTerritory IM system card (DEFENDED and friends) parses into a navigation hint only.
final class CityTerritoryNoticeTests: XCTestCase {
    private func message(_ extra: [String: Any], sender: Int = 0, type: Int = 3, status: Int = 0) throws -> MessagingMessage {
        let extraText = String(decoding: try JSONSerialization.data(withJSONObject: extra), as: UTF8.self)
        let row: [String: Any] = ["id": 41, "conversationId": 7, "senderId": sender, "msgType": type, "status": status,
                                  "content": "有人挑战你的「老麦咖啡馆」失败了，你守住了这块地。", "extraJson": extraText,
                                  "createTime": "2026-11-21 09:30"]
        return try JSONDecoder().decode(MessagingMessage.self, from: JSONSerialization.data(withJSONObject: row))
    }

    func testDefendedCardParsesWithTerritoryAndPoints() throws {
        let notice = try XCTUnwrap(CityTerritoryNotice.parse(message: try message(
            ["cardType": "cityTerritory", "kind": "DEFENDED", "territoryId": "t-77", "title": "老麦咖啡馆", "points": 27, "currency": "POINTS"])))
        XCTAssertEqual(notice.kind, .defended)
        XCTAssertEqual(notice.territoryId, "t-77")
        XCTAssertEqual(notice.points, 27)
        XCTAssertTrue(notice.opensProperty)
        XCTAssertEqual(notice.createdAt, "2026-11-21 09:30")
    }

    func testTaskFailedDefenceKeepsZeroAndMissingTerritoryDoesNotLink() throws {
        let notice = try XCTUnwrap(CityTerritoryNotice.parse(message: try message(
            ["cardType": "cityTerritory", "kind": "DEFENDED", "title": "老麦咖啡馆", "points": 0, "currency": "POINTS"])))
        XCTAssertEqual(notice.points, 0)
        XCTAssertFalse(notice.opensProperty)
    }

    func testOtherCardsSendersAndCurrenciesAreRejected() throws {
        XCTAssertNil(CityTerritoryNotice.parse(message: try message(["cardType": "generic", "kind": "DEFENDED", "title": "x"])))
        XCTAssertNil(CityTerritoryNotice.parse(message: try message(["cardType": "cityTerritory", "kind": "NEW_KIND", "title": "x"])))
        XCTAssertNil(CityTerritoryNotice.parse(message: try message(["cardType": "cityTerritory", "kind": "RENT", "title": "x", "currency": "CNY"])))
        XCTAssertNil(CityTerritoryNotice.parse(message: try message(["cardType": "cityTerritory", "kind": "RENT", "title": "x"], sender: 9)))
        XCTAssertNil(CityTerritoryNotice.parse(message: try message(["cardType": "cityTerritory", "kind": "RENT", "title": "x"], status: 1)))
        XCTAssertNil(CityTerritoryNotice.parse(message: try message(["cardType": "cityTerritory", "kind": "RENT", "title": "  "])))
        let boolPoints = try XCTUnwrap(CityTerritoryNotice.parse(message: try message(
            ["cardType": "cityTerritory", "kind": "RENT", "title": "x", "points": true])))
        XCTAssertNil(boolPoints.points, "a boolean is not a number")
    }
}
