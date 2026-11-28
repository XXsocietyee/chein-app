import XCTest
import Foundation
import MapKit
@testable import Questify

/// fix-1128b-social (audit 1128-plan gaps #1-#4, #26, #27). Every test builds the shipped Release composition
/// (`RegionalLaunchConfiguration.reviewedDeployment` + `makeComposition`) and checks that the service is switched on
/// and admits the exact paths. Offline: the wire only records.
@MainActor final class MPFirstSocialApprovalsTests: XCTestCase {
    static let base = "https://social-1128b.example.test"
    static let token = "synthetic-social-7"

    final class Vault: AppTokenStorage {
        var value: String?
        func read() throws -> String? { value }
        func write(_ token: String) throws { value = token }
        func clear() throws { value = nil }
    }
    final class Wire: HTTPTransport {
        var requests: [URLRequest] = []
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return (Data(#"{"code":200,"data":{}}"#.utf8), 200)
        }
    }

    private func release(market: String = "CN") throws -> AppCompositionRoot {
        let suite = "social-1128b-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let build = RegionalLaunchConfiguration.BuildMetadata(market: market, baseURL: Self.base,
            bundleIdentifier: "com.questify.ios", realm: "social-1128b-" + UUID().uuidString.lowercased())
        let deployment = try RegionalLaunchConfiguration.reviewedDeployment(build: build)
        XCTAssertTrue(deployment.productionGatesEnabled)
        XCTAssertTrue(deployment.playerWritesEnabled)
        let vault = Vault()
        return RegionalLaunchConfiguration.makeComposition(reviewed: deployment, build: build,
            storage: .init(defaults: defaults, tokenStore: { _ in vault }), makeTransport: { Wire() })
    }

    private func context(_ root: AppCompositionRoot, role: String = "player", market: RegionalMarket = .china) throws -> RuntimeDependencyContext {
        RuntimeDependencyContext(market: market, baseURL: try XCTUnwrap(URL(string: Self.base)), role: role,
            session: try PlayExperienceSession(accountID: 7, epoch: 1, namespace: root.reviewed?.storageScope.service ?? "unconfigured",
                token: Self.token, role: role))
    }

    private func post(_ path: String, body: String = #"{"requestId":"req-1128b-0000000001"}"#, method: String = "POST") throws -> URLRequest {
        var request = URLRequest(url: try XCTUnwrap(URL(string: Self.base + "/" + path)))
        request.httpMethod = method
        request.setValue(Self.token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(body.utf8)
        return request
    }

    // MARK: Gap #4 发布 tab "+" and club 发布活动

    func testReleaseCompositionGrantsThePublishingRoutesToPlayersAndClubs() throws {
        let root = try release()
        for role in ["player", "club"] {
            let deps = root.sessionDependencies(try context(root, role: role))
            let configuration = try XCTUnwrap(deps.businessConfiguration, role)
            let read = Set((configuration.routes[.publishingRead] ?? []).map(\.path))
            let write = Set((configuration.routes[.publishingWrite] ?? []).map(\.path))
            XCTAssertTrue(read.isSuperset(of: ["api/publish/home", "api/activity/create-requests/read", "api/project/state-requests/context", "api/project/my"]), role)
            XCTAssertTrue(write.isSuperset(of: ["api/activity/create-requests/submit", "api/project/state-requests/submit", "api/topic/create"]), role)
            XCTAssertFalse(read.contains("api/ai/theme/draft/quota"), "AI quota keeps its own grant")
        }
    }

    func testMerchantGetsNoPublishingRoutes() throws {
        let root = try release()
        let configuration = root.sessionDependencies(try context(root, role: "merchant")).businessConfiguration
        XCTAssertTrue(configuration?.routes[.publishingRead]?.isEmpty ?? true)
        XCTAssertTrue(configuration?.routes[.publishingWrite]?.isEmpty ?? true)
    }

    func testCompositionTransportAndProductionHostAdmitThePublishingWrites() throws {
        let root = try release(), ctx = try context(root)
        let grant = try XCTUnwrap(root.playerWriteGrant(ctx))
        let baseURL = try XCTUnwrap(URL(string: Self.base))
        for path in ["api/activity/create-requests/submit", "api/project/state-requests/submit", "api/activity/info", "api/activity/update"] {
            XCTAssertTrue(ReviewedProductionFormMutationRoute.acceptsPlayerWrite(try post(path), baseURL: baseURL, token: Self.token, context: ctx, grant: grant), path)
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path), path)
        }
        XCTAssertFalse(ReviewedProductionFormMutationRoute.acceptsPlayerWrite(try post("api/activity/create-requests/submit", method: "GET"),
            baseURL: baseURL, token: Self.token, context: ctx, grant: grant))
        XCTAssertFalse(ReviewedProductionFormMutationRoute.acceptsPlayerWrite(try post("api/project/my", body: #"{"scope":"MERCHANT"}"#),
            baseURL: baseURL, token: Self.token, context: ctx, grant: grant), "the merchant project list stays refused")
    }

    // MARK: Gaps #1-#3 square writer

    func testReleaseCompositionIssuesTheCommunityWriterForPlayersAndClubs() throws {
        let root = try release()
        for role in ["player", "club"] {
            let ctx = try context(root, role: role)
            let approval = try XCTUnwrap(MPFirstSocialApprovals.community(root, ctx), role)
            XCTAssertTrue(approval.matches(ctx))
            XCTAssertTrue(SquareCommunityWriteApproval.admits(method: "POST", relativePath: "api/v1/community/posts/5/actions"))
            XCTAssertTrue(SquareCommunityWriteApproval.admits(method: "POST", relativePath: "api/v1/community/posts/5/comments"))
            let grants = MPFirstSocialApprovals.workspaceGrants(approval)
            XCTAssertTrue(grants.live && grants.media && grants.legal, role)
        }
        XCTAssertNil(MPFirstSocialApprovals.community(root, try context(root, role: "merchant")), "merchant stays off")
    }

    func testCompositionTransportAdmitsTheSquareWritesTheWriterSends() throws {
        let root = try release(), ctx = try context(root)
        let grant = try XCTUnwrap(root.playerWriteGrant(ctx))
        let baseURL = try XCTUnwrap(URL(string: Self.base))
        let writes: [(String, String, String)] = [
            ("POST", "api/v1/community/posts/5/actions", #"{"actionType":"LIKE","requestId":"req-1128b-0000000001","source":"APP_SQUARE"}"#),
            ("DELETE", "api/v1/community/posts/5/actions/BOOKMARK", #"{"requestId":"req-1128b-0000000002"}"#),
            ("POST", "api/v1/community/posts/5/comments", #"{"body":"好玩","clientRequestId":"req-1128b-0000000003"}"#),
            ("POST", "api/v1/community/comments/9/actions", #"{"requestId":"req-1128b-0000000004"}"#),
            ("POST", "api/v1/community/posts", #"{"clientRequestId":"post-1128b-0001","body":"x"}"#),
            ("POST", "api/v1/community/posts/5/publish", #"{"expectedVersion":0,"requestId":"publish-1128b-0001"}"#),
            ("POST", "api/v1/community/reports", #"{"targetType":"POST","targetId":5,"requestId":"report-1128b-0001"}"#)
        ]
        for (method, path, body) in writes {
            XCTAssertTrue(ReviewedProductionFormMutationRoute.acceptsPlayerWrite(try post(path, body: body, method: method),
                baseURL: baseURL, token: Self.token, context: ctx, grant: grant), path)
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path), path)
        }
    }

    // MARK: Gap #3 report (App Store 1.2)

    func testReportReceiptReadsAreAdmittedAndTheWriteRidesTheSquareGrant() throws {
        let root = try release(), ctx = try context(root)
        let grant = try XCTUnwrap(root.playerWriteGrant(ctx))
        let baseURL = try XCTUnwrap(URL(string: Self.base))
        var receipt = URLRequest(url: try XCTUnwrap(URL(string: Self.base + "/api/community-trust/reports/41")))
        receipt.httpMethod = "GET"; receipt.setValue(Self.token, forHTTPHeaderField: "Authorization")
        XCTAssertTrue(ReviewedProductionFormMutationRoute.acceptsPlayerWrite(receipt, baseURL: baseURL, token: Self.token, context: ctx, grant: grant))
        var mine = URLRequest(url: try XCTUnwrap(URL(string: Self.base + "/api/community-trust/reports/mine?requestId=report-1128b-0001")))
        mine.httpMethod = "GET"; mine.setValue(Self.token, forHTTPHeaderField: "Authorization")
        XCTAssertTrue(ReviewedProductionFormMutationRoute.acceptsPlayerWrite(mine, baseURL: baseURL, token: Self.token, context: ctx, grant: grant))
        XCTAssertEqual(MPFirstSocialApprovals.reportReadDecision(relative: "api/community-trust/reports/41", method: "POST", request: receipt), false)
        XCTAssertNil(MPFirstSocialApprovals.reportReadDecision(relative: "api/community-trust/reports/abc", method: "GET", request: receipt))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/v1/community/capabilities"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/community-trust/reports/41"))
        // The service the session builds once the writer is issued: reads on, report write granted.
        let service = SquareReportService(configuration: try APIConfiguration(baseURL: baseURL), transport: Wire(),
            readsEnabled: MPFirstSocialApprovals.community(root, ctx) != nil,
            grant: MPFirstSocialApprovals.community(root, ctx) != nil ? .reviewedInjection : .disabled)
        XCTAssertTrue(service.readsEnabled && service.writesEnabled)
    }

    // MARK: Gap #26 place pickers

    func testPlayerPublishPickersUseAnEnabledMapKitAdapterAndADroppedPinIsAPlace() throws {
        XCTAssertTrue(PublishingMapKitAdapter.playerPublishing.isEnabled)
        XCTAssertFalse(PublishingMapKitAdapter().isEnabled, "merchant pickers keep the default (off) adapter")
        let pin = try XCTUnwrap(PublishingMapKitAdapter.droppedPin(.init(latitude: 31.230416, longitude: 121.473701)))
        XCTAssertEqual(pin.latitude, 31.230416, accuracy: 0.000001)
        XCTAssertEqual(pin.longitude, 121.473701, accuracy: 0.000001)
        XCTAssertFalse(pin.name.isEmpty)
        XCTAssertEqual(pin.address, "31.230416, 121.473701")
        XCTAssertNil(PublishingMapKitAdapter.droppedPin(.init(latitude: 91, longitude: 0)))
    }

    // MARK: Gap #27 activity 编辑

    func testReleaseCompositionIssuesStableActivityEditingGrants() throws {
        let root = try release()
        let issue = MPFirstSocialApprovals.activityEditing(root)
        let api = try APIConfiguration(baseURL: try XCTUnwrap(URL(string: Self.base)))
        for role in ["player", "club"] {
            let ctx = try context(root, role: role)
            let grants = issue(ctx)
            XCTAssertNotNil(grants.revision, role)
            XCTAssertEqual(issue(ctx), grants, "the editing transport compares currentGrant == grants")
            XCTAssertTrue(grants.read?.allows(configuration: api, namespace: ctx.session.namespace, accountID: 7, path: ActivityEditingService.readPath) == true)
            XCTAssertTrue(grants.update?.allows(configuration: api, namespace: ctx.session.namespace, accountID: 7, path: ActivityEditingService.updatePath) == true)
            XCTAssertFalse(grants.read?.allows(configuration: api, namespace: ctx.session.namespace, accountID: 7, path: ActivityEditingService.updatePath) == true)
        }
        XCTAssertNil(issue(try context(root, role: "merchant")).revision, "merchant stays off")
        XCTAssertEqual(ActivityEditingService.readPath, "api/activity/info")
        XCTAssertEqual(ActivityEditingService.updatePath, "api/activity/update")
    }

    func testActivityEditRowRuleMatchesTheMiniProgramCanEdit() throws {
        func row(_ state: String, owner: String? = "club") throws -> CreatorContentProject {
            var object: [String: Any] = ["bizType": "activity", "id": 41, "sourceId": 41, "state": state, "title": "城市夜跑"]
            if let owner { object["ownerType"] = owner }
            return try JSONDecoder().decode(CreatorContentProject.self, from: JSONSerialization.data(withJSONObject: object))
        }
        for state in ["running", "notStarted", "offline", "pending", "rejected"] {
            XCTAssertTrue(MyProjectActivityEditRule.applies(try row(state), merchantScopeAccess: .init()), state)
        }
        XCTAssertFalse(MyProjectActivityEditRule.applies(try row("draft"), merchantScopeAccess: .init()))
        XCTAssertFalse(MyProjectActivityEditRule.applies(try row("running", owner: "merchant"), merchantScopeAccess: .init()))
    }

    func testUnitedStatesHasNoPlayerWriteGrantYet() throws {
        let root = try release(market: "US")
        let ctx = try context(root, market: .unitedStates)
        XCTAssertNil(root.playerWriteGrant(ctx), "US player writes stay behind the composition transport (receipt: owner action)")
        XCTAssertNil(MPFirstSocialApprovals.community(root, ctx))
        XCTAssertNil(MPFirstSocialApprovals.deletionApproval(root, ctx))
    }

    // MARK: K40 M-01d delete, M-11a governance, M-04b member/activity report

    func testReleaseCompositionIssuesSquareDeletionAndGovernanceForPlayersAndClubs() throws {
        let root = try release()
        let baseURL = try XCTUnwrap(URL(string: Self.base))
        let api = try APIConfiguration(baseURL: baseURL)
        for role in ["player", "club"] {
            let ctx = try context(root, role: role)
            let approval = try XCTUnwrap(MPFirstSocialApprovals.deletionApproval(root, ctx), role)
            XCTAssertTrue(approval.allows(configuration: api, namespace: ctx.session.namespace, accountID: 7, path: SquareDeletionTarget.postRoute), role)
            XCTAssertTrue(approval.allows(configuration: api, namespace: ctx.session.namespace, accountID: 7, path: SquareDeletionTarget.commentRoute), role)
            let coordinator = SquareDeletionCoordinator(service: SquareDeletionService(configuration: api, transport: Wire()),
                configuration: api, approval: approval, current: { (namespace: ctx.session.namespace, accountID: 7, token: Self.token) })
            XCTAssertTrue(coordinator.isAllowed(.post(id: 5, expectedVersion: 1)), role)
            XCTAssertTrue(coordinator.isAllowed(.comment(postID: 5, commentID: 9, expectedVersion: 2)), role)
            XCTAssertFalse(coordinator.isAllowed(.post(id: 0, expectedVersion: 1)))
            let governance = MPFirstSocialApprovals.governanceService(baseURL: baseURL, transport: Wire(), writerIssued: true)
            XCTAssertTrue(governance.readsEnabled, role)
            XCTAssertTrue(governance.allows(.appeal(enforcementID: 3, reason: "事实不符")), role)
            XCTAssertTrue(governance.allows(.markRead(notificationID: 8)), role)
            XCTAssertTrue(governance.allows(.preferences([.interactionEnabled: true])), role)
            XCTAssertFalse(governance.allows(.approveComment(postID: 5, commentID: 9)), "comment approve stays off")
            XCTAssertFalse(governance.allows(.deleteOwnComment(commentID: 9)), "own-comment delete stays on the square detail coordinator")
        }
        let merchant = try context(root, role: "merchant")
        XCTAssertNil(MPFirstSocialApprovals.deletionApproval(root, merchant), "merchant stays off")
        let quiet = MPFirstSocialApprovals.governanceService(baseURL: baseURL, transport: Wire(), writerIssued: false)
        XCTAssertFalse(quiet.readsEnabled)
        XCTAssertFalse(quiet.allowsInjectedWrites)
    }

    func testCompositionTransportAdmitsDeletionGovernanceAndTrustReports() throws {
        let root = try release(), ctx = try context(root)
        let grant = try XCTUnwrap(root.playerWriteGrant(ctx))
        let baseURL = try XCTUnwrap(URL(string: Self.base))
        let writes: [(String, String, String)] = [
            ("DELETE", "api/v1/community/posts/5", #"{"expectedVersion":1,"requestId":"sq-delete-1128k40"}"#),
            ("DELETE", "api/v1/community/posts/5/comments/9", #"{"expectedVersion":2,"requestId":"sq-delete-comment-k40"}"#),
            ("POST", "api/v1/community/appeals", #"{"enforcementId":3,"reason":"事实不符","evidenceAssetIds":[],"requestId":"appeal-k40-0001"}"#),
            ("POST", "api/v1/community/notifications/8/read", #"{"requestId":"read-k40-00000001"}"#),
            ("POST", "api/community-trust/reports/submit", #"{"targetType":"MEMBER","targetId":6,"reasonCode":"OTHER","description":"骚扰","requestId":"rpt-k40-member"}"#),
            ("POST", "api/community-trust/reports/submit", #"{"targetType":"ACTIVITY","targetId":7,"reasonCode":"OTHER","description":"活动","requestId":"rpt-k40-activity"}"#)
        ]
        for (method, path, body) in writes {
            XCTAssertTrue(ReviewedProductionFormMutationRoute.acceptsPlayerWrite(try post(path, body: body, method: method),
                baseURL: baseURL, token: Self.token, context: ctx, grant: grant), path)
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + path), path)
        }
        var notes = URLRequest(url: try XCTUnwrap(URL(string: Self.base + "/api/v1/community/notifications")))
        notes.httpMethod = "GET"
        notes.setValue(Self.token, forHTTPHeaderField: "Authorization")
        XCTAssertTrue(ReviewedProductionFormMutationRoute.acceptsPlayerWrite(notes, baseURL: baseURL, token: Self.token, context: ctx, grant: grant))
        XCTAssertFalse(ReviewedProductionFormMutationRoute.acceptsPlayerWrite(
            try post("api/v1/community/posts/5", body: #"{"expectedVersion":1}"#, method: "DELETE"),
            baseURL: baseURL, token: Self.token, context: ctx, grant: grant), "a delete without requestId stays refused")
        XCTAssertTrue(grant.reports.paths.contains("api/community-trust/reports/submit"))
    }
}
