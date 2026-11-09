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

final class SquareDetailPageReadyTests: XCTestCase {
    private let dash = SquareDetailPageModel.unknownMark

    private func post(_ json: String, loading: Bool = false, failure: Error? = nil, communityRead: Bool? = nil) -> SquareDetailPostState {
        SquareDetailPageModel.resolvePost(loading: loading, payload: Data(json.utf8), failure: failure, communityRead: communityRead)
    }

    private func comments(_ json: String?, loading: Bool = false, failure: Error? = nil, list: SquareDetailCommentList) -> SquareDetailCommentsState {
        SquareDetailPageModel.resolveComments(loading: loading, payload: json.map { Data($0.utf8) }, failure: failure, list: list)
    }

    private func readyPost(_ json: String, communityRead: Bool? = nil) throws -> SquareDetailPostFacts {
        guard case .ready(let facts) = post(json, communityRead: communityRead) else {
            XCTFail("expected a ready post")
            throw TestFailure()
        }
        return facts
    }

    func testUnknownMarkIsAnEmDashAndNotZero() {
        XCTAssertEqual(dash.unicodeScalars.map(\.value), [0x2014])
        XCTAssertNotEqual(dash, "0")
        XCTAssertEqual(SquareDetailPageModel.countText(nil), dash)
        XCTAssertEqual(SquareDetailPageModel.countText(0), "0")
        XCTAssertEqual(SquareDetailPageModel.countText(-3), dash)
        XCTAssertEqual(SquareDetailPageModel.countText("0"), dash)
        XCTAssertEqual(SquareDetailPageModel.countText("4"), dash)
        XCTAssertEqual(SquareDetailPageModel.countText(1.5), dash)
        XCTAssertEqual(SquareDetailPageModel.countText(true), dash)
        XCTAssertEqual(SquareDetailPageModel.countText("UNKNOWN"), dash)
    }

    func testLoadingEmptyErrorAndUnknownStaySeparate() throws {
        XCTAssertEqual(SquareDetailPageModel.resolvePost(loading: true, payload: nil, failure: nil), .loading)
        XCTAssertEqual(SquareDetailPageModel.resolvePost(loading: false, payload: nil, failure: nil), .empty)
        XCTAssertEqual(post("   \n", loading: true), .loading)
        XCTAssertEqual(post("{}"), .empty)
        XCTAssertEqual(post("null"), .empty)
        XCTAssertEqual(post(#"{"code":200,"data":null}"#), .empty)
        XCTAssertEqual(post(#"{"code":200,"data":{}}"#), .empty)
        XCTAssertEqual(post(#"{"code":200,"data":[]}"#), .empty)
        XCTAssertEqual(post(#"{"code":"200","data":{"id":701,"likeCount":1}}"#).isReadyID(701), true)
        XCTAssertEqual(post(#"{"code":401,"msg":"请先登录"}"#), .error(titleKey: "square.unauthorized", serverMessage: "请先登录"))
        XCTAssertEqual(post(#"{"code":500,"msg":" 暂时不行 "}"#), .error(titleKey: "square.failed", serverMessage: "暂时不行"))
        XCTAssertEqual(post(#"{"id":0}"#), .error(titleKey: "square.failed", serverMessage: nil))
        XCTAssertEqual(post(#"{"id":"701","likeCount":1}"#), .error(titleKey: "square.failed", serverMessage: nil))
        XCTAssertEqual(post(#"{"code":200,"data":"UNKNOWN"}"#), .unknown)
        XCTAssertEqual(post("\"UNKNOWN\""), .unknown)
        XCTAssertEqual(post(#"{"hello":1}"#), .unknown)

        let kept = #"{"id":701,"likeCount":2}"#
        XCTAssertEqual(post(kept, failure: SquareReadFailure.unavailable), .error(titleKey: "square.unavailable", serverMessage: nil))
        XCTAssertEqual(post(kept, failure: SquareReadFailure.server(code: 500, message: "保持原文")), .error(titleKey: "square.failed", serverMessage: "保持原文"))
        XCTAssertEqual(post(kept, failure: APIError.notConfigured), .error(titleKey: "square.notConfigured", serverMessage: nil))
        XCTAssertEqual(post(kept, failure: APIError.unauthorized), .error(titleKey: "square.unauthorized", serverMessage: nil))
        XCTAssertEqual(post(kept, failure: SquareReadFailure.signInRequired), .error(titleKey: "square.signInRequired", serverMessage: nil))
        XCTAssertEqual(SquareDetailPageModel.titleKey(for: APIError.malformedResponse), "square.failed")

        XCTAssertEqual(comments(nil, loading: true, list: .legacyRows), .loading)
        XCTAssertEqual(comments(nil, loading: false, list: .legacyRows), .unknown)
        XCTAssertEqual(comments(#"{"code":200,"data":{"rows":[]}}"#, list: .legacyRows), .empty)
        XCTAssertEqual(comments(#"{"code":200,"data":{"items":[]}}"#, list: .communityItems), .empty)
        XCTAssertEqual(comments(#"{"code":200,"data":{}}"#, list: .legacyRows), .unknown)
        XCTAssertEqual(comments(#"{"code":200,"data":{"rows":null}}"#, list: .legacyRows), .unknown)
        XCTAssertEqual(comments(#"{"code":200,"data":{"items":[{"id":801}]}}"#, list: .legacyRows), .unknown)
        XCTAssertEqual(comments(#"[{"id":801}]"#, list: .communityItems), .unknown)
        XCTAssertEqual(comments(#"{"code":200,"data":{"rows":"UNKNOWN"}}"#, list: .legacyRows), .unknown)
        XCTAssertEqual(comments(#"{"code":500,"msg":"评论失败"}"#, list: .legacyRows), .error(titleKey: "square.failed", serverMessage: "评论失败"))
        XCTAssertEqual(comments(#"{"code":200,"data":{"rows":[{"id":0}]}}"#, list: .legacyRows), .error(titleKey: "square.failed", serverMessage: nil))
        XCTAssertEqual(SquareDetailPageModel.emptyCommentsTitleKey, "square.xcx.noCommentsTitle")
        XCTAssertEqual(SquareDetailPageModel.emptyCommentsDetailKey, "square.xcx.noCommentsDetail")
        XCTAssertEqual(try readyPost(#"{"id":701}"#).id, 701)
    }

    func testOmittedCountsStayUnknownAndLiteralZeroStaysZero() throws {
        let omitted = try readyPost(#"{"id":701,"contents":"Synthetic"}"#)
        XCTAssertEqual(omitted.likeCountText, dash)
        XCTAssertEqual(omitted.commentCountText, dash)
        XCTAssertEqual(omitted.dislikeCountText, dash)
        XCTAssertEqual(omitted.nodeTotalText, dash)
        XCTAssertEqual(omitted.nodeDoneText, dash)
        XCTAssertEqual(omitted.memberLevelText, dash)
        XCTAssertEqual(omitted.imageCountText, dash)
        XCTAssertEqual(omitted.bookmarked, .unknown)
        XCTAssertEqual(omitted.viewerCanComment, .yes)
        XCTAssertFalse(omitted.sends)

        let nulled = try readyPost(#"{"id":701,"likeNum":null,"commentCount":null,"nolikeNum":null,"nodeTotal":null,"nodeDoneCount":null,"memberLevelId":null,"isBookmarked":null,"pics":null}"#)
        XCTAssertEqual(nulled.likeCountText, dash)
        XCTAssertEqual(nulled.commentCountText, dash)
        XCTAssertEqual(nulled.dislikeCountText, dash)
        XCTAssertEqual(nulled.nodeTotalText, dash)
        XCTAssertEqual(nulled.nodeDoneText, dash)
        XCTAssertEqual(nulled.memberLevelText, dash)
        XCTAssertEqual(nulled.imageCountText, dash)
        XCTAssertEqual(nulled.bookmarked, .unknown)

        let zero = try readyPost(#"{"id":701,"likeCount":0,"commentCount":0,"nolikeNum":0,"nodeTotal":0,"nodeDoneCount":0,"memberLevelId":0,"isBookmarked":0,"pics":""}"#)
        XCTAssertEqual(zero.likeCountText, "0")
        XCTAssertEqual(zero.commentCountText, "0")
        XCTAssertEqual(zero.dislikeCountText, "0")
        XCTAssertEqual(zero.nodeTotalText, "0")
        XCTAssertEqual(zero.nodeDoneText, "0")
        XCTAssertEqual(zero.memberLevelText, "0")
        XCTAssertEqual(zero.imageCountText, "0")
        XCTAssertEqual(zero.bookmarked, .no)

        let strings = try readyPost(#"{"id":701,"likeCount":"4","commentCount":"0","nodeTotal":"6","nodeDoneCount":"1"}"#)
        XCTAssertEqual(strings.likeCountText, dash)
        XCTAssertEqual(strings.commentCountText, dash)
        XCTAssertEqual(strings.nodeTotalText, dash)
        XCTAssertEqual(strings.nodeDoneText, dash)

        let doneMissing = try readyPost(#"{"post":{"id":702,"likeCount":5},"nodeTotal":6}"#)
        XCTAssertEqual(doneMissing.id, 702)
        XCTAssertEqual(doneMissing.likeCountText, "5")
        XCTAssertEqual(doneMissing.nodeTotalText, "6")
        XCTAssertEqual(doneMissing.nodeDoneText, dash)
    }

    func testKnownFactsDoNotBorrowAnotherField() throws {
        let post = try readyPost(#"{"id":701,"likeNum":12,"likeCount":4,"commentCount":3,"nolikeNum":1,"memberLevelId":"2","isBookmarked":1,"pics":"a;b","nodeTotal":6,"nodeDoneCount":2,"viewerCanComment":false}"#)
        XCTAssertEqual(post.likeCountText, "4")
        XCTAssertEqual(post.commentCountText, "3")
        XCTAssertEqual(post.dislikeCountText, "1")
        XCTAssertEqual(post.memberLevelText, "2")
        XCTAssertEqual(post.imageCountText, "2")
        XCTAssertEqual(post.nodeTotalText, "6")
        XCTAssertEqual(post.nodeDoneText, "2")
        XCTAssertEqual(post.bookmarked, .yes)
        XCTAssertEqual(post.viewerCanComment, .no)

        let alias = try readyPost(#"{"id":701,"likeCount":null,"likeNum":9,"pics":""}"#)
        XCTAssertEqual(alias.likeCountText, "9")
        XCTAssertEqual(alias.imageCountText, "0")

        let wrapped = try readyPost(#"{"post":{"id":702,"likeCount":5,"commentCount":1},"media":[{"media_type":"IMAGE","derived_object_key":"example/object-key"},{"mediaType":"MAP_SNAPSHOT","derivedObjectKey":"example/route-key"}],"viewerCanComment":false,"nodeDoneCount":1}"#)
        XCTAssertEqual(wrapped.likeCountText, "5")
        XCTAssertEqual(wrapped.commentCountText, "1")
        XCTAssertEqual(wrapped.imageCountText, "1")
        XCTAssertEqual(wrapped.nodeTotalText, dash)
        XCTAssertEqual(wrapped.nodeDoneText, "1")
        XCTAssertEqual(wrapped.viewerCanComment, .no)
        XCTAssertEqual(wrapped.bookmarked, .unknown)
    }

    func testCommentPageDoesNotInventContinuationOrACount() throws {
        guard case .ready(let page) = comments(#"{"code":200,"data":{"rows":[{"id":801,"like_count":2},{"id":802}],"hasMore":false}}"#, list: .legacyRows) else {
            return XCTFail("expected ready comments")
        }
        XCTAssertEqual(page.comments.map(\.id), [801, 802])
        XCTAssertEqual(page.comments.map(\.likeCountText), ["2", dash])
        XCTAssertEqual(page.hasMore, .no)

        guard case .ready(let community) = comments(#"{"code":200,"data":{"items":[{"id":803,"likeCount":0}]}}"#, list: .communityItems) else {
            return XCTFail("expected community comments")
        }
        XCTAssertEqual(community.comments, [SquareDetailCommentFacts(id: 803, likeCountText: "0")])
        XCTAssertEqual(community.hasMore, .unknown)

        guard case .ready(let same) = comments(#"{"code":200,"data":{"rows":[{"id":801,"likeCount":"2"}]}}"#, loading: true, list: .legacyRows) else {
            return XCTFail("an accepted comment page is not loading")
        }
        XCTAssertEqual(same.comments.first?.likeCountText, dash)
        XCTAssertEqual(comments(#"{"code":200,"data":{"rows":[{"id":801}]}}"#, failure: SquareReadFailure.unavailable, list: .legacyRows), .error(titleKey: "square.unavailable", serverMessage: nil))
    }

    func testClosedGateAndLiveRoutesDoNotMarkAnythingNew() throws {
        let closed = post(#"{"id":701,"likeCount":4}"#, communityRead: false)
        XCTAssertEqual(closed, .error(titleKey: "square.xcx.closedTitle", serverMessage: nil))
        let open = try readyPost(#"{"id":701,"likeCount":4}"#, communityRead: nil)
        XCTAssertEqual(open.likeCountText, "4")
        XCTAssertFalse(open.sends)
        XCTAssertFalse(SquareDetailPageModel.blockRouteIsLive)
        XCTAssertEqual(SquareAuthorSafety.blockAvailability, .notAvailableYet)
        for path in [SquareDetailPageModel.legacyDetailPath, SquareDetailPageModel.communityDetailPath, SquareDetailPageModel.legacyCommentsPath, SquareDetailPageModel.communityCommentsPath] {
            XCTAssertTrue(SquareDetailPageModel.existingRouteIsLive(path), path)
            XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: path), .liveInProduction)
        }
    }

    func testAcceptedPayloadWinsOverTheLoadingFlag() throws {
        guard case .ready(let facts) = post(#"{"id":701,"commentCount":2}"#, loading: true) else {
            return XCTFail("an accepted post is not loading")
        }
        XCTAssertEqual(facts.commentCountText, "2")
        XCTAssertEqual(facts.likeCountText, dash)
    }

#if DEBUG
    func testDebugFixtureDataCoversReadyUnknownZeroAndEmpty() throws {
        let ready = try readyPost(SquareDetailPageFixtureData.ready)
        XCTAssertEqual(ready.id, 701)
        XCTAssertEqual(ready.likeCountText, "12")
        XCTAssertEqual(ready.commentCountText, "3")
        XCTAssertEqual(ready.memberLevelText, "2")
        XCTAssertEqual(ready.bookmarked, .no)
        XCTAssertEqual(ready.imageCountText, "0")

        let unknown = try readyPost(SquareDetailPageFixtureData.unknownCounts)
        XCTAssertEqual(unknown.likeCountText, dash)
        XCTAssertEqual(unknown.commentCountText, dash)
        XCTAssertEqual(unknown.nodeTotalText, dash)

        let zero = try readyPost(SquareDetailPageFixtureData.literalZero)
        XCTAssertEqual(zero.likeCountText, "0")
        XCTAssertEqual(zero.commentCountText, "0")
        XCTAssertEqual(zero.memberLevelText, "0")

        let strings = try readyPost(SquareDetailPageFixtureData.numericStringCounts)
        XCTAssertEqual(strings.likeCountText, dash)
        XCTAssertEqual(strings.commentCountText, dash)

        XCTAssertEqual(post(SquareDetailPageFixtureData.emptyObject), .empty)
        guard case .ready(let envelope) = post(SquareDetailPageFixtureData.envelope) else {
            return XCTFail("envelope data is the same detail contract")
        }
        XCTAssertEqual(envelope.id, 701)
        XCTAssertEqual(envelope.likeCountText, "2")
        XCTAssertEqual(envelope.commentCountText, dash)
        XCTAssertEqual(comments(SquareDetailPageFixtureData.emptyComments, list: .legacyRows), .empty)
        XCTAssertEqual(comments(SquareDetailPageFixtureData.unknownCommentList, list: .legacyRows), .unknown)
        XCTAssertFalse(SquareDetailPageFixtureData.ready.contains("http"))
        XCTAssertFalse(SquareDetailPageFixtureData.envelope.contains("http"))
    }
#endif
}

private extension SquareDetailPostState {
    func isReadyID(_ id: Int) -> Bool {
        if case .ready(let facts) = self { return facts.id == id }
        return false
    }
}

private struct TestFailure: Error {}
#endif
