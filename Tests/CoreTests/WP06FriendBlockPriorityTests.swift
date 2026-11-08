import XCTest
@testable import QuestifyCore

final class WP06FriendBlockPriorityTests: XCTestCase {
    func testRequestToBlockedPeerNeverSent() {
        let blocked: (Int64) -> Bool = { $0 == 9 }
        XCTAssertFalse(NativeFriendRequestPolicy.mayRequest(peerID: 9, isBlocked: blocked))
        XCTAssertFalse(NativeFriendRequestPolicy.mayPerform(.init(peerID: 9, action: .request, message: "hi"), isBlocked: blocked))
        XCTAssertTrue(NativeFriendRequestPolicy.mayPerform(.init(peerID: 10, action: .request, message: "hi"), isBlocked: blocked))
        XCTAssertTrue(NativeFriendRequestPolicy.mayPerform(.init(peerID: 9, action: .reject, expectedVersion: 1), isBlocked: blocked))
        XCTAssertTrue(NativeFriendRequestPolicy.mayRequest(peerID: 9, isBlocked: nil))
    }
    func testUnblockDoesNotRestoreFriendship() {
        for previous in [NativeFriendRelation.friend, .pendingIncoming, .pendingOutgoing, .none] {
            XCTAssertEqual(NativeBlacklistRelationPolicy.relationAfterUnblock(previous: previous), .none)
        }
    }
    func testReviewFailClosedMapsToUserMessage() {
        XCTAssertEqual(NativeFriendRejectMessage.issueKey(forCode: 403), NativeFriendRejectMessage.reviewFailClosedKey)
        XCTAssertEqual(NativeFriendRejectMessage.issueKey(forCode: 401), "friend.sessionExpired")
        XCTAssertEqual(NativeFriendRejectMessage.issueKey(forCode: 409), "friend.conflict")
        XCTAssertEqual(NativeFriendRejectMessage.issueKey(forCode: 429), "friend.rejected")
    }
}
