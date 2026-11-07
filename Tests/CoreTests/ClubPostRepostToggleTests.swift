#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

/// Encodes utils/club-post-repost.js toggleRepost / applyRepostState.
final class ClubPostRepostToggleTests: XCTestCase {
    typealias T = ClubPostRepostToggle
    private func row(_ id: String, community: Bool = false, reposted: Bool = false, count: Int = 0) -> T.Row {
        .init(id: id, isCommunity: community, state: .init(reposted: reposted, count: count))
    }

    func testFirstToggleRepostsOptimisticallyAndUsesRepostEndpoint() {
        var toggle = T()
        let ticket = toggle.begin(postID: "7", rows: [row("7", count: 3)])
        XCTAssertEqual(ticket?.endpoint, .repost)
        XCTAssertEqual(ticket?.endpoint.rawValue, "api/club/post/repost")
        XCTAssertEqual(ticket?.optimistic, .init(reposted: true, count: 4))
        XCTAssertEqual(ticket?.before, .init(reposted: false, count: 3))
    }

    func testToggleOfRepostedPostUsesUndoEndpointAndNeverGoesBelowZero() {
        var toggle = T()
        let ticket = toggle.begin(postID: "7", rows: [row("7", reposted: true, count: 0)])
        XCTAssertEqual(ticket?.endpoint.rawValue, "api/club/post/repost/undo")
        XCTAssertEqual(ticket?.optimistic, .init(reposted: false, count: 0))
    }

    func testNegativeStoredCountIsClampedBeforeToggle() {
        var toggle = T()
        let ticket = toggle.begin(postID: "7", rows: [row("7", count: -5)])
        XCTAssertEqual(ticket?.before.count, 0)
        XCTAssertEqual(ticket?.optimistic.count, 1)
    }

    func testSecondTapWhileInFlightSendsNothing() {
        var toggle = T()
        XCTAssertNotNil(toggle.begin(postID: "7", rows: [row("7")]))
        XCTAssertTrue(toggle.isPending(postID: "7"))
        XCTAssertNil(toggle.begin(postID: "7", rows: [row("7")]))
        XCTAssertNotNil(toggle.begin(postID: "8", rows: [row("8")]), "other posts are independent")
    }

    func testCommunityRowsAndUnknownIdsAreNeverReposted() {
        var toggle = T()
        XCTAssertNil(toggle.begin(postID: "7", rows: [row("7", community: true)]))
        XCTAssertNil(toggle.begin(postID: "9", rows: [row("7")]))
        // Colliding id: the club row is chosen, not the community row.
        let ticket = toggle.begin(postID: "7", rows: [row("7", community: true, count: 50), row("7", count: 1)])
        XCTAssertEqual(ticket?.before.count, 1)
    }

    func testServerTruthReplacesOptimisticStateAndFreesTheSlot() {
        var toggle = T()
        let ticket = toggle.begin(postID: "7", rows: [row("7", count: 3)])!
        let outcome = toggle.resolve(ticket, result: .response(.init(code: 200, message: nil, reposted: true, repostCount: 10)))
        XCTAssertEqual(outcome, .applied(.init(reposted: true, count: 10)))
        XCTAssertFalse(toggle.isPending(postID: "7"))
        XCTAssertNotNil(toggle.begin(postID: "7", rows: [row("7", reposted: true, count: 10)]))
    }

    func testMissingCountKeepsPreRequestCount() {
        var toggle = T()
        let ticket = toggle.begin(postID: "7", rows: [row("7", count: 3)])!
        XCTAssertEqual(toggle.resolve(ticket, result: .response(.init(code: 200, message: nil, reposted: true, repostCount: nil))),
                       .applied(.init(reposted: true, count: 3)))
    }

    func testNon200OrNonBooleanRollsBackWithServerMessageVerbatim() {
        var toggle = T()
        var ticket = toggle.begin(postID: "7", rows: [row("7", count: 3)])!
        XCTAssertEqual(toggle.resolve(ticket, result: .response(.init(code: 403, message: "server words", reposted: nil, repostCount: nil))),
                       .rolledBack(.init(reposted: false, count: 3), serverMessage: "server words"))
        ticket = toggle.begin(postID: "7", rows: [row("7", count: 3)])!
        XCTAssertEqual(toggle.resolve(ticket, result: .response(.init(code: 200, message: nil, reposted: nil, repostCount: 9))),
                       .rolledBack(.init(reposted: false, count: 3), serverMessage: nil))
    }

    func testNetworkFailureRollsBackToPreRequestState() {
        var toggle = T()
        let ticket = toggle.begin(postID: "7", rows: [row("7", reposted: true, count: 2)])!
        XCTAssertEqual(toggle.resolve(ticket, result: .networkFailure), .rolledBackNetwork(.init(reposted: true, count: 2)))
    }

    func testLateDuplicateResolutionIsIgnored() {
        var toggle = T()
        let ticket = toggle.begin(postID: "7", rows: [row("7")])!
        _ = toggle.resolve(ticket, result: .networkFailure)
        XCTAssertEqual(toggle.resolve(ticket, result: .networkFailure), .ignored)
        let newer = toggle.begin(postID: "7", rows: [row("7")])!
        XCTAssertEqual(toggle.resolve(ticket, result: .response(.init(code: 200, message: nil, reposted: true, repostCount: 1))), .ignored,
                       "an old ticket cannot settle the newer request")
        XCTAssertTrue(toggle.isPending(postID: "7"))
        _ = newer
    }

    func testApplyChangesOriginalAndRepostEntriesButNotCommunityRows() {
        let rows = [row("7"), row("7"), row("7", community: true), row("8")]
        let out = T.apply(.init(reposted: true, count: 5), toPostID: "7", in: rows)
        XCTAssertEqual(out[0].state, .init(reposted: true, count: 5))
        XCTAssertEqual(out[1].state, .init(reposted: true, count: 5))
        XCTAssertEqual(out[2].state, rows[2].state)
        XCTAssertEqual(out[3].state, rows[3].state)
    }
}
#endif
