#if canImport(QuestifyCore)
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

/// pages/square/detail comment compose / reply / comment-like, driven through the reviewed
/// SocialActionCoordinator with a fake access (the same synthetic fixtures the existing suite uses),
/// plus the honest "block is not available yet" safety entry.
@MainActor final class SquareDetailInteractionTests: XCTestCase {
    @MainActor private final class Access: SocialActionAccess {
        var identity = SocialAccountIdentity(accountID: 81, epoch: 1, role: "player")
        var availability: SocialActionAvailability = .syntheticOnly
        var calls = 0
        var commands: [SocialActionCommand] = []
        var failure: Error?
        func snapshot(target: SocialActionTarget) async throws -> SocialActionSnapshot {
            .init(target: target, post: target.postID == nil ? nil : try SquareSyntheticFixtures.post(),
                  comment: try target.commentID.flatMap { id in try SquareSyntheticFixtures.comments().first { $0.id == id } })
        }
        func perform(_ command: SocialActionCommand, snapshot: SocialActionSnapshot, expectedIdentity: SocialAccountIdentity) async throws -> SocialActionReceipt {
            calls += 1; commands.append(command)
            if let failure { throw failure }
            return .init(synthetic: true)
        }
    }
    private func review(_ coordinator: SocialActionCoordinator, _ access: Access, _ command: SocialActionCommand, _ target: SocialActionTarget) async throws -> SocialActionReview {
        try await coordinator.prepare(command, target: target, ownerID: UUID(), expectedIdentity: access.identity)
    }

    func testCommentOnPostSendsOnlyAfterConfirmAndShowsAcknowledgement() async throws {
        let access = Access(), coordinator = SocialActionCoordinator(access: access)
        let target = SocialActionTarget.post(701)
        let r = try await review(coordinator, access, .comment(text: "Nice walk"), target)
        XCTAssertEqual(access.calls, 0, "Preparing the review must not send")
        await coordinator.confirm(r)
        XCTAssertEqual(access.calls, 1)
        XCTAssertEqual(access.commands, [.comment(text: "Nice walk")])
        XCTAssertEqual(coordinator.state(target: target, generation: .legacySquare), .acknowledged(.init(synthetic: true)))
    }

    func testReplyToCommentTargetsThatComment() async throws {
        let access = Access(), coordinator = SocialActionCoordinator(access: access)
        let target = SocialActionTarget.comment(postID: 701, commentID: 802)
        let r = try await review(coordinator, access, .comment(text: "Thanks"), target)
        await coordinator.confirm(r)
        XCTAssertEqual(access.calls, 1)
        XCTAssertEqual(r.target, target)
    }

    func testCommentLikeToggleIsOneReviewedWrite() async throws {
        let access = Access(), coordinator = SocialActionCoordinator(access: access)
        let target = SocialActionTarget.comment(postID: 701, commentID: 802)
        let r = try await review(coordinator, access, .toggleCommentLike, target)
        await coordinator.confirm(r); await coordinator.confirm(r)
        XCTAssertEqual(access.calls, 1, "A second confirm of the same review cannot send twice")
    }

    func testServerRejectionIsNeverShownAsAcknowledged() async throws {
        let access = Access(); access.failure = SocialActionWriteFailure.rejected
        let coordinator = SocialActionCoordinator(access: access)
        let target = SocialActionTarget.post(701)
        let r = try await review(coordinator, access, .comment(text: "Nope"), target)
        await coordinator.confirm(r)
        XCTAssertEqual(coordinator.state(target: target, generation: .legacySquare), .rejected)
    }

    func testDisabledAvailabilityNeverSends() async throws {
        let access = Access(); access.availability = .disabled
        let coordinator = SocialActionCoordinator(access: access)
        let target = SocialActionTarget.post(701)
        let r = try await review(coordinator, access, .comment(text: "Blocked"), target)
        await coordinator.confirm(r)
        XCTAssertEqual(access.calls, 0)
        XCTAssertEqual(coordinator.state(target: target, generation: .legacySquare), .notSent)
    }

    func testBlockEntryIsOnlyForOthersAndIsHonestlyNotAvailable() {
        XCTAssertTrue(SquareAuthorSafety.showsBlockEntry(authorMemberID: 90, viewerMemberID: 81))
        XCTAssertFalse(SquareAuthorSafety.showsBlockEntry(authorMemberID: 81, viewerMemberID: 81))
        XCTAssertFalse(SquareAuthorSafety.showsBlockEntry(authorMemberID: 90, viewerMemberID: nil))
        XCTAssertFalse(SquareAuthorSafety.showsBlockEntry(authorMemberID: 0, viewerMemberID: 81))
        XCTAssertEqual(SquareAuthorSafety.blockAvailability, .notAvailableYet)
    }
}
#endif
