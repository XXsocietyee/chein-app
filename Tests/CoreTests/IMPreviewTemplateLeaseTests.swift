import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

final class IMPreviewTemplateLeaseTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_763_000_000)

    private func viewer(accountID: Int = 7) throws -> RuntimeDependencyContext {
        let session = try PlayExperienceSession(accountID: accountID, epoch: 1, namespace: "preview-tests", token: "synthetic-token", role: "player")
        let base = try XCTUnwrap(URL(string: "https://preview.example.test"))
        return RuntimeDependencyContext(market: .china, baseURL: base, role: "player", session: session)
    }

    private func filePreview() throws -> BusinessRuntimeRouteTemplate {
        try XCTUnwrap(IMPreviewRouteTemplates.template(for: .imFilePreview))
    }

    private func makeLease(viewer: RuntimeDependencyContext, conversationID: Int64 = 11, expiresAt: Date? = nil) throws -> IMPreviewTemplateLease {
        try XCTUnwrap(IMPreviewTemplateLease(template: try filePreview(), viewer: viewer, conversationID: conversationID,
                                             expiresAt: expiresAt ?? now.addingTimeInterval(3600)))
    }

    private func issued(_ lease: IMPreviewTemplateLease, method: String, path: String, messageID: Int64 = 42,
                        messageConversationID: Int64 = 11, viewer: RuntimeDependencyContext, at: Date? = nil) -> BusinessRuntimeRoute? {
        lease.issue(method: method, path: path, messageID: messageID, messageConversationID: messageConversationID,
                    viewer: viewer, now: at ?? now)
    }

    func testBoundViewerAndConversationIssuesTheConcreteGet() throws {
        let owner = try viewer()
        let lease = try makeLease(viewer: owner)
        let route = try XCTUnwrap(issued(lease, method: "GET", path: "api/im/file/message/42/preview", viewer: owner))
        XCTAssertEqual(route.method, "GET")
        XCTAssertEqual(route.path, "api/im/file/message/42/preview")
        XCTAssertTrue(BusinessRuntimeFeature.imFilePreview.accepts(route))
        let templatePath = try filePreview().path
        if let blocked = try? BusinessRuntimeRoute(method: "GET", path: templatePath) {
            XCTAssertFalse(BusinessRuntimeFeature.imFilePreview.accepts(blocked))
        }
        let mismatchedID = issued(lease, method: "GET", path: "api/im/file/message/99/preview", messageID: 42, viewer: owner)
        XCTAssertNil(mismatchedID)
        let otherAccount = try viewer(accountID: 8)
        let otherViewer = issued(lease, method: "GET", path: "api/im/file/message/42/preview", viewer: otherAccount)
        XCTAssertNil(otherViewer)
        let video = try XCTUnwrap(IMPreviewRouteTemplates.template(for: .imVideoPreview))
        let videoPath = try XCTUnwrap(video.concretePath(for: 42))
        let otherTemplate = issued(lease, method: video.method, path: videoPath, viewer: owner)
        XCTAssertNil(otherTemplate)
        XCTAssertEqual(IMPreviewRouteTemplates.all.count, 6)
        XCTAssertEqual(Set(IMPreviewRouteTemplates.all.map(\.method)), ["GET"])
        XCTAssertEqual(BusinessRuntimeRouteTemplate.maximumIdentifierLength, 19)
    }

    func testPathTraversalRefusesAndIssuesNothing() throws {
        let owner = try viewer()
        let lease = try makeLease(viewer: owner)
        let attacks = [
            "api/im/file/message/../preview",
            "api/im/file/message/42/../preview",
            "api/../im/file/message/42/preview",
            "api/im/file/message/42/preview/..",
            "api/im/file/message/42/preview/extra",
            "api/im/file/message//preview",
            "api/im/file/message/42a/preview",
            "api/im/file/message/042/preview",
            "api/im/file/message/0/preview",
            "api/im/file/message/" + String(repeating: "9", count: 20) + "/preview",
            "api/im/file/message/{id}/preview",
            "/api/im/file/message/42/preview"
        ]
        for path in attacks {
            let refused = issued(lease, method: "GET", path: path, viewer: owner)
            XCTAssertNil(refused, path)
        }
        XCTAssertNil(BusinessRuntimeRouteTemplate(method: "GET", path: "api/im/{id}/message/{id}/preview", feature: .imFilePreview))
    }

    func testEncodedSlashAndBackslashRefusesAndIssuesNothing() throws {
        let owner = try viewer()
        let lease = try makeLease(viewer: owner)
        let attacks = [
            "api/im/file/message/42%2fpreview",
            "api/im/file/message/42%2Fpreview",
            "api/im/file/%2fmessage/42/preview",
            "api/im/file/message/%2e%2e/preview",
            "api/im/file/message/42%5cpreview",
            "api/im/file/message/42%5Cpreview",
            "api/im/file/message/42/preview%5c",
            "api/im/file/message/42/preview%252f",
            "api\\im\\file\\message\\42\\preview"
        ]
        for path in attacks {
            let refused = issued(lease, method: "GET", path: path, viewer: owner)
            XCTAssertNil(refused, path)
        }
    }

    func testWrongConversationRefusesAndIssuesNothing() throws {
        let owner = try viewer()
        let lease = try makeLease(viewer: owner, conversationID: 11)
        let wrong = issued(lease, method: "GET", path: "api/im/file/message/42/preview", messageConversationID: 22, viewer: owner)
        XCTAssertNil(wrong)
        let other = try XCTUnwrap(IMPreviewTemplateLease(template: try filePreview(), viewer: owner, conversationID: 22, expiresAt: now.addingTimeInterval(60)))
        let reused = other.issue(method: "GET", path: "api/im/file/message/42/preview", messageID: 42, messageConversationID: 11, viewer: owner, now: now)
        XCTAssertNil(reused)
        let same = issued(lease, method: "GET", path: "api/im/file/message/42/preview", messageConversationID: 11, viewer: owner)
        XCTAssertNotNil(same)
    }

    func testWrongVerbRefusesAndIssuesNothing() throws {
        let owner = try viewer()
        let lease = try makeLease(viewer: owner)
        let post = issued(lease, method: "POST", path: "api/im/file/message/42/preview", viewer: owner)
        let put = issued(lease, method: "PUT", path: "api/im/file/message/42/preview", viewer: owner)
        let lower = issued(lease, method: "get", path: "api/im/file/message/42/preview", viewer: owner)
        XCTAssertNil(post)
        XCTAssertNil(put)
        XCTAssertNil(lower)
        for feature in [BusinessRuntimeFeature.imFilePreviewStatus, .imVideoPreview, .imVideoPreviewStatus, .imVoicePlayback, .imVoicePlaybackStatus] {
            let template = try XCTUnwrap(IMPreviewRouteTemplates.template(for: feature))
            let path = try XCTUnwrap(template.concretePath(for: 42))
            let bound = try XCTUnwrap(IMPreviewTemplateLease(template: template, viewer: owner, conversationID: 11, expiresAt: now.addingTimeInterval(60)))
            let refused = bound.issue(method: "POST", path: path, messageID: 42, messageConversationID: 11, viewer: owner, now: now)
            XCTAssertNil(refused, path)
            let route = try XCTUnwrap(bound.issue(method: "GET", path: path, messageID: 42, messageConversationID: 11, viewer: owner, now: now))
            XCTAssertEqual(route.method, "GET")
            XCTAssertEqual(route.path, path)
        }
    }

    func testExpiredLeaseRefusesAndIssuesNothing() throws {
        let owner = try viewer()
        let lease = try makeLease(viewer: owner, expiresAt: now)
        let atExpiry = issued(lease, method: "GET", path: "api/im/file/message/42/preview", viewer: owner, at: now)
        let after = issued(lease, method: "GET", path: "api/im/file/message/42/preview", viewer: owner, at: now.addingTimeInterval(1))
        XCTAssertNil(atExpiry)
        XCTAssertNil(after)
        let live = try makeLease(viewer: owner, expiresAt: now.addingTimeInterval(1))
        let still = issued(live, method: "GET", path: "api/im/file/message/42/preview", viewer: owner, at: now)
        let ended = issued(live, method: "GET", path: "api/im/file/message/42/preview", viewer: owner, at: now.addingTimeInterval(1))
        XCTAssertNotNil(still)
        XCTAssertNil(ended)
    }

    func testCatalogStaysOnTheMissingOwnerGrant() throws {
        XCTAssertEqual(ChinaReviewedRouteCapability.imRecipientPreviewGrant, IMPreviewRouteTemplates.grantPatterns)
        let expected: Set<String> = [
            "/api/im/file/message/{}/authorization",
            "/api/im/file/message/{}/preview",
            "/api/im/video/message/{}/authorization",
            "/api/im/video/message/{}/preview",
            "/api/im/voice/message/{}",
            "/api/im/voice/message/{}/authorization"
        ]
        XCTAssertEqual(IMPreviewRouteTemplates.grantPatterns, expected)
        for pattern in expected {
            XCTAssertTrue(ChinaReviewedRouteCapability.channelsSocialOwnerGrant.contains(pattern), pattern)
            XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: pattern), .missing, pattern)
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall(pattern), pattern)
        }
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/im/file/message/42/preview"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/im/voice/message/42"))
        XCTAssertFalse(IMPreviewRouteTemplates.grantPatterns.contains("/api/native/channels/read-through"))
        let invented = BusinessRuntimeRouteTemplate(method: "GET", path: "api/channels/{id}/members", feature: .imChannelMentionMemberRead)
        let outsider = try XCTUnwrap(invented)
        let owner = try viewer()
        XCTAssertNil(IMPreviewTemplateLease(template: outsider, viewer: owner, conversationID: 11, expiresAt: now.addingTimeInterval(60)))
    }
}
