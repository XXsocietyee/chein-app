import XCTest
@testable import QuestifyCore

final class WP06DMSendGateTests: XCTestCase {
    private let gate = DirectMessageSendGate()

    func testExistingNonFriendSessionStillSendable() {
        XCTAssertEqual(gate.decide(.init(hasExistingSession: true, isFriend: false)), .allowed)
    }
    func testBlockedSenderRefused() {
        XCTAssertEqual(gate.decide(.init(hasExistingSession: true, isFriend: true, blocked: true)), .refused(.blocked))
    }
    func testBannedRefused() {
        XCTAssertEqual(gate.decide(.init(hasExistingSession: true, isFriend: true, banned: true)), .refused(.banned))
    }
    func testSelfRejectRefused() {
        XCTAssertEqual(gate.decide(.init(hasExistingSession: true, selfRejected: true)), .refused(.selfRejected))
    }
}
