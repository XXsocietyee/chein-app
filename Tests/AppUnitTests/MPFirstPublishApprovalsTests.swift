import XCTest
import Foundation
@testable import Questify

/// fix-1128-publish: audit P0-7, P1-26, P1-27, P1-29. Offline: no transport is called.
@MainActor final class MPFirstPublishApprovalsTests: XCTestCase {
    private let base = "https://publish-1128.test"

    private func deployment(gates: Bool = true, writes: Bool = true) throws -> ReviewedAppDeployment {
        try ReviewedAppDeployment(market: .china, baseURL: base, approvedBaseURLs: [.china: [base]],
            verifiedCapabilities: [.domesticChinaPhone],
            bundleIdentifier: "test.questify.publish1128", realm: "publish-1128",
            productionGatesEnabled: gates, playerWritesEnabled: writes)
    }

    private func context(_ deployment: ReviewedAppDeployment, account: Int = 7, epoch: UInt64 = 1,
                         market: RegionalMarket = .china) throws -> RuntimeDependencyContext {
        let session = try PlayExperienceSession(accountID: account, epoch: epoch, namespace: deployment.storageScope.service,
                                                token: "synthetic-publish-\(account)", role: "player")
        return RuntimeDependencyContext(market: market, baseURL: URL(string: base)!, role: "player", session: session)
    }

    // MARK: P0-7 template authoring

    func testTemplateAuthoringPathsMatchTheR3Envelope() {
        XCTAssertEqual(MPFirstPublishApprovals.templateAuthoringReadPaths, ["api/template/author-requests/read"])
        XCTAssertEqual(MPFirstPublishApprovals.templateAuthoringSubmitPaths,
                       ["api/template/author-requests/submit", "api/template/draft", "api/template/publish"])
    }

    func testReviewedChinaPlayerWriteBuildIssuesTemplateAuthoringApprovals() throws {
        let d = try deployment(), root = AppCompositionRoot(deployment: .reviewed(d)), ctx = try context(d)
        let read = try XCTUnwrap(root.templateAuthoringOriginalReadApproval(ctx))
        let submit = try XCTUnwrap(root.templateAuthoringOriginalSubmitApproval(ctx))
        let api = try APIConfiguration(baseURL: URL(string: base)!)
        XCTAssertTrue(read.allows(configuration: api, namespace: ctx.session.namespace, accountID: 7, path: "api/template/author-requests/read"))
        XCTAssertFalse(read.allows(configuration: api, namespace: ctx.session.namespace, accountID: 7, path: "api/template/author-requests/submit"))
        for path in ["api/template/author-requests/submit", "api/template/draft", "api/template/publish"] {
            XCTAssertTrue(submit.allows(configuration: api, namespace: ctx.session.namespace, accountID: 7, path: path), path)
        }
        XCTAssertFalse(submit.allows(configuration: api, namespace: ctx.session.namespace, accountID: 8, path: "api/template/draft"))
    }

    func testTemplateAuthoringStaysOffWithoutPlayerWritesOrOutsideChina() throws {
        let off = try deployment(writes: false)
        XCTAssertNil(AppCompositionRoot(deployment: .reviewed(off)).templateAuthoringOriginalSubmitApproval(try context(off)))
        XCTAssertNil(AppCompositionRoot().templateAuthoringOriginalSubmitApproval(try context(off)))
        XCTAssertFalse(MPFirstPublishApprovals.enabled(.unconfigured))
        let d = try deployment()
        XCTAssertNil(MPFirstPublishApprovals.templateAuthoringSubmit(try context(d, market: .unitedStates)))
    }

    func testSubmitApprovalAdmitsTheDraftAndPublishRequestShape() throws {
        let d = try deployment(), ctx = try context(d)
        let approval = try XCTUnwrap(MPFirstPublishApprovals.templateAuthoringSubmit(ctx))
        let request = try TemplateAuthoringContract.request(.init(title: "城市寻宝"), intent: .saveDraft)
        let command = try TemplateAuthoringRequestReceipt.Command(request: request)
        XCTAssertEqual(command.originalPath, "api/template/draft")
        XCTAssertTrue(approval.paths.contains(command.originalPath))
        XCTAssertTrue(approval.paths.contains(TemplateAuthoringRequestReceipt.submitPath))
    }

    // MARK: P1-27 topic-editor media

    func testTopicEditorMediaApprovalsMatchTheEditorSession() throws {
        let d = try deployment(), root = AppCompositionRoot(deployment: .reviewed(d)), ctx = try context(d)
        let api = try APIConfiguration(baseURL: URL(string: base)!)
        let session = try ProjectEditSession(accountID: 7, epoch: 1, storageNamespace: ctx.session.namespace,
                                             viewerRevision: 1, configurationRevision: 0)
        let image = try XCTUnwrap(root.projectStoryImageUploadApproval(ctx))
        XCTAssertTrue(image.matches(configuration: api, session: session)); XCTAssertTrue(image.nativePicker)
        XCTAssertTrue(image.approvedOrigins.contains(base))
        let audio = try XCTUnwrap(root.projectStoryAudioUploadApproval(ctx))
        XCTAssertTrue(audio.matches(configuration: api, session: session)); XCTAssertTrue(audio.nativePicker)
        let node = try XCTUnwrap(root.projectNodeImageUploadApproval(ctx))
        XCTAssertTrue(node.matches(configuration: api, session: session))
        XCTAssertEqual(node, root.projectNodeImageUploadApproval(ctx), "node approval carries an id; it must stay stable")
        let cover = try XCTUnwrap(root.ownedTopicCoverApproval(ctx))
        for operation in [OwnedTopicCoverOperation.readCurrent, .readAsset, .upload, .select, .status] {
            XCTAssertTrue(cover.permits(operation, configuration: api, session: session))
        }
    }

    func testTopicEditorMediaStaysOffWithoutPlayerWrites() throws {
        let d = try deployment(writes: false), root = AppCompositionRoot(deployment: .reviewed(d)), ctx = try context(d)
        XCTAssertNil(root.projectStoryImageUploadApproval(ctx)); XCTAssertNil(root.projectStoryAudioUploadApproval(ctx))
        XCTAssertNil(root.projectNodeImageUploadApproval(ctx)); XCTAssertNil(root.ownedTopicCoverApproval(ctx))
    }

    // MARK: P1-29 我的项目 → 模板

    func testTemplateShelfLeaseIsStablePerSessionAndRenewedAfterExpiry() throws {
        let d = try deployment(), root = AppCompositionRoot(deployment: .reviewed(d)), ctx = try context(d, account: 11)
        let first = try XCTUnwrap(root.templateShelfReadApproval(ctx))
        XCTAssertTrue(first.matches(ctx))
        XCTAssertTrue(first === root.templateShelfReadApproval(ctx))
        first.revoke()
        let renewed = try XCTUnwrap(root.templateShelfReadApproval(ctx))
        XCTAssertFalse(first === renewed); XCTAssertTrue(renewed.matches(ctx))
        let other = try context(d, account: 11, epoch: 2)
        XCTAssertFalse(renewed === root.templateShelfReadApproval(other))
    }

    // MARK: P1-26 用这个模板 → editor

    func testCopiedTemplateOpensTheFabuEditorQuery() {
        XCTAssertEqual(PublishTabRootView.topicEditorQuery(topicID: 42, scope: nil), ["id": "42"])
        XCTAssertEqual(PublishTabRootView.topicEditorQuery(topicID: 42, scope: "MERCHANT"), ["id": "42", "scope": "MERCHANT"])
        XCTAssertEqual(PublishTabRootView.topicEditorQuery(topicID: 42, scope: ""), ["id": "42"])
    }
}
