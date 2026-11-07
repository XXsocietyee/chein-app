import XCTest
@testable import Questify

final class IMCoopInviteCardsTests: XCTestCase {
    private func invites(_ json: String) throws -> CooperationInvites {
        try JSONDecoder().decode(CooperationInvites.self, from: Data(json.utf8))
    }
    private let sample = """
    {"received":[
      {"id":1,"status":1,"shareMode":1,"shareRate":30,"topicName":"Old project","partner":{"name":"Done Club"}},
      {"id":2,"status":0,"shareMode":2,"fixedFee":12.5,"topicName":"  Night walk ","message":" Join us ","partner":{"name":"Pending Club"}},
      {"id":3,"status":0,"inviteType":2,"partner":{"name":"Legacy"}}
    ],"sent":[{"id":9,"status":0,"shareMode":0,"topicId":77,"partner":{"name":"Cafe"}}]}
    """

    func testPendingReceivedInviteIsSortedFirstAndAwaitsAnswer() throws {
        let cards = IMCoopInviteCard.cards(try invites(sample), direction: .received)
        XCTAssertEqual(cards.map(\.key.id), [2, 1, 3])
        XCTAssertTrue(cards[0].awaitsMyAnswer)
        XCTAssertEqual(cards[0].topicName, "Night walk")
        XCTAssertEqual(cards[0].message, "Join us")
        XCTAssertEqual(cards[0].tone, .pending)
    }

    func testLegacyReadonlyInviteNeverAwaitsAnswer() throws {
        let cards = IMCoopInviteCard.cards(try invites(sample), direction: .received)
        XCTAssertFalse(cards.first { $0.key.id == 3 }!.awaitsMyAnswer)
    }

    func testSentInviteNeverAwaitsMyAnswerAndFallsBackToTopicNumber() throws {
        let cards = IMCoopInviteCard.cards(try invites(sample), direction: .sent)
        XCTAssertEqual(cards.count, 1)
        XCTAssertFalse(cards[0].awaitsMyAnswer)
        XCTAssertEqual(cards[0].topicName, "#77")
        XCTAssertEqual(cards[0].key.direction, .sent)
    }

    func testTermsLinesMatchMiniProgramWordingAndKeepMissingNumbersUnknown() throws {
        let cards = IMCoopInviteCard.cards(try invites(sample), direction: .received)
        XCTAssertEqual(cards[0].termsLine(chinese: true), "固定型 · ¥12.5 / 核销人头")
        XCTAssertEqual(cards[1].termsLine(chinese: false), "Revenue share · 30% of tickets")
        let missing = try invites(#"{"received":[{"id":5,"shareMode":1}],"sent":[]}"#)
        XCTAssertEqual(IMCoopInviteCard.cards(missing, direction: .received)[0].termsLine(chinese: true), "分成型 · 票款 ?%")
        let none = try invites(#"{"received":[{"id":6}],"sent":[]}"#)
        XCTAssertNil(IMCoopInviteCard.cards(none, direction: .received)[0].termsLine(chinese: true))
    }

    func testStatusTextIsBilingualAndUnknownIsExplicit() throws {
        let cards = IMCoopInviteCard.cards(try invites(#"{"received":[{"id":1,"status":5},{"id":2}],"sent":[]}"#), direction: .received)
        XCTAssertEqual(cards[0].statusText(chinese: true), "已过期")
        XCTAssertEqual(cards[0].statusText(chinese: false), "Expired")
        XCTAssertEqual(cards[1].statusText(chinese: false), "Unknown")
        XCTAssertEqual(cards[1].tone, .muted)
    }

    func testEmptyInboxProducesNoCards() throws {
        XCTAssertTrue(IMCoopInviteCard.cards(try invites(#"{"received":[],"sent":[]}"#), direction: .received).isEmpty)
    }
}
