import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// fix-1128b-social gap #1 (audit M-01b/c, M-13b): the v1 like / bookmark / comment / comment-like writer.
@MainActor final class SquareCommunityActionAccessTests: XCTestCase {
    private let base = URL(string: "https://community-1128b.example.test/native")!

    private final class Wire: HTTPTransport {
        var requests: [URLRequest] = []
        var reply = #"{"code":200,"data":{}}"#
        var status = 200
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return (Data(reply.utf8), status)
        }
    }

    /// Reads only: hands back a v1 post / comment snapshot; it never writes.
    @MainActor private final class ReadOnlyBase: SocialActionAccess {
        let identity: SocialAccountIdentity
        let availability: SocialActionAvailability = .disabled
        var post: SquarePost
        var comment: SquareComment?
        var performed = 0
        init(identity: SocialAccountIdentity, post: SquarePost, comment: SquareComment? = nil) {
            self.identity = identity; self.post = post; self.comment = comment
        }
        func snapshot(target: SocialActionTarget) async throws -> SocialActionSnapshot {
            SocialActionSnapshot(target: target, post: post, comment: target.commentID == nil ? nil : comment)
        }
        func perform(_ command: SocialActionCommand, snapshot: SocialActionSnapshot, expectedIdentity: SocialAccountIdentity) async throws -> SocialActionReceipt {
            performed += 1
            throw SocialActionWriteFailure.notSent
        }
    }

    private func context(role: String = "player", account: Int = 7, market: RegionalMarket = .china) throws -> RuntimeDependencyContext {
        RuntimeDependencyContext(market: market, baseURL: base, role: role,
            session: try PlayExperienceSession(accountID: account, epoch: 1, namespace: "social-1128b", token: "synthetic-community-7", role: role))
    }

    private func v1Post(id: Int = 5) throws -> SquarePost {
        try JSONDecoder().decode(SquarePost.self, from: Data(#"{"post":{"id":\#(id),"authorId":3,"version":2,"lifecycle":"PUBLISHED"}}"#.utf8))
            .qualified(as: .communityV1)
    }

    func testTemplatesAdmitOnlyTheMiniProgramRoutes() {
        XCTAssertTrue(SquareCommunityWriteApproval.admits(method: "POST", relativePath: "api/v1/community/posts/5/actions"))
        XCTAssertTrue(SquareCommunityWriteApproval.admits(method: "DELETE", relativePath: "api/v1/community/posts/5/actions/LIKE"))
        XCTAssertTrue(SquareCommunityWriteApproval.admits(method: "DELETE", relativePath: "api/v1/community/posts/5/actions/BOOKMARK"))
        XCTAssertTrue(SquareCommunityWriteApproval.admits(method: "POST", relativePath: "api/v1/community/posts/5/comments"))
        XCTAssertTrue(SquareCommunityWriteApproval.admits(method: "POST", relativePath: "api/v1/community/comments/9/actions"))
        XCTAssertTrue(SquareCommunityWriteApproval.admits(method: "DELETE", relativePath: "api/v1/community/comments/9/actions/LIKE"))
        XCTAssertFalse(SquareCommunityWriteApproval.admits(method: "DELETE", relativePath: "api/v1/community/posts/5/actions/SHARE"))
        XCTAssertFalse(SquareCommunityWriteApproval.admits(method: "POST", relativePath: "api/v1/community/posts/abc/actions"))
        XCTAssertFalse(SquareCommunityWriteApproval.admits(method: "POST", relativePath: "api/v1/community/posts/05/actions"))
        XCTAssertFalse(SquareCommunityWriteApproval.admits(method: "GET", relativePath: "api/v1/community/posts/5/comments"))
        XCTAssertFalse(SquareCommunityWriteApproval.admits(method: "POST", relativePath: "api/v1/community/members/5/mute"))
    }

    func testApprovalIsBoundToTheViewerAndRefusesMerchants() throws {
        let ctx = try context()
        let approval = try SquareCommunityWriteApproval(context: ctx, expiresAt: Date().addingTimeInterval(60))
        XCTAssertTrue(approval.matches(ctx))
        XCTAssertFalse(approval.matches(try context(account: 8)))
        XCTAssertFalse(approval.matches(ctx, now: Date().addingTimeInterval(120)))
        XCTAssertThrowsError(try SquareCommunityWriteApproval(context: try context(role: "merchant"), expiresAt: Date().addingTimeInterval(60)))
    }

    private func access(_ wire: Wire, base: ReadOnlyBase, approved: Bool = true) throws -> SquareCommunityActionAccess {
        let ctx = try context()
        let approval = approved ? try SquareCommunityWriteApproval(context: ctx, expiresAt: Date().addingTimeInterval(600)) : nil
        return SquareCommunityActionAccess(base: base, configuration: try APIConfiguration(baseURL: self.base), transport: wire,
                                           approval: { approval }, current: { ctx })
    }

    func testImmediateLikeSendsOnceWithTheMiniProgramBodyAndIsServerConfirmed() async throws {
        let wire = Wire(), reader = ReadOnlyBase(identity: .init(accountID: 7, epoch: 1, role: "player"), post: try v1Post())
        let coordinator = SocialActionCoordinator(access: try access(wire, base: reader))
        XCTAssertEqual(coordinator.availability(for: .action(.like, enabled: true), target: .post(5)), .approved)
        let outcome = await coordinator.sendImmediately(.action(.like, enabled: true), target: .post(5), ownerID: UUID())
        XCTAssertEqual(outcome, .confirmed)
        XCTAssertEqual(wire.requests.count, 1)
        let request = try XCTUnwrap(wire.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/native/api/v1/community/posts/5/actions")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(body["actionType"] as? String, "LIKE")
        XCTAssertEqual(body["source"] as? String, "APP_SQUARE")
        XCTAssertNotNil(body["requestId"] as? String)
        XCTAssertEqual(reader.performed, 0, "v1 writes never fall back to the read-only base")
    }

    func testRemovingABookmarkUsesDelete() async throws {
        let wire = Wire()
        let reader = ReadOnlyBase(identity: .init(accountID: 7, epoch: 1, role: "player"), post: try v1Post())
        let coordinator = SocialActionCoordinator(access: try access(wire, base: reader))
        _ = await coordinator.sendImmediately(.action(.bookmark, enabled: false), target: .post(5), ownerID: UUID())
        XCTAssertEqual(wire.requests.last?.httpMethod, "DELETE")
        XCTAssertEqual(wire.requests.last?.url?.path, "/native/api/v1/community/posts/5/actions/BOOKMARK")
    }

    func testServerRejectionIsShownAndNothingIsSentWithoutAnApproval() async throws {
        let wire = Wire(); wire.reply = #"{"code":409,"msg":"该帖文已关闭互动"}"#
        let reader = ReadOnlyBase(identity: .init(accountID: 7, epoch: 1, role: "player"), post: try v1Post())
        let rejected = await SocialActionCoordinator(access: try access(wire, base: reader))
            .sendImmediately(.action(.like, enabled: true), target: .post(5), ownerID: UUID())
        XCTAssertEqual(rejected, .rejected)
        let closedWire = Wire()
        let closed = SocialActionCoordinator(access: try access(closedWire, base: reader, approved: false))
        XCTAssertEqual(closed.availability(for: .action(.like, enabled: true), target: .post(5)), .disabled)
        let outcome = await closed.sendImmediately(.action(.like, enabled: true), target: .post(5), ownerID: UUID())
        XCTAssertEqual(outcome, .notSent)
        XCTAssertTrue(closedWire.requests.isEmpty)
    }

    func testReceiptDecoding() {
        XCTAssertNoThrow(try SquareCommunityActionAccess.receipt(data: Data(#"{"code":200}"#.utf8), status: 200))
        XCTAssertThrowsError(try SquareCommunityActionAccess.receipt(data: Data(#"{"code":403}"#.utf8), status: 200)) {
            XCTAssertEqual($0 as? SocialActionWriteFailure, .rejected)
        }
        XCTAssertThrowsError(try SquareCommunityActionAccess.receipt(data: Data("<html>".utf8), status: 502)) {
            XCTAssertEqual($0 as? SocialActionWriteFailure, .outcomeUnknown)
        }
        XCTAssertThrowsError(try SquareCommunityActionAccess.receipt(data: Data(), status: 401)) {
            XCTAssertEqual($0 as? SocialActionWriteFailure, .rejected)
        }
    }
}
