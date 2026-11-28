import XCTest
@testable import Questify

/// K40 / plan M-11a. The requests `SquareNotificationLease` builds are the ones the China player
/// write lease already admits. Comment and preference mutations are not granted, so they are not sent.
@MainActor final class K40NotificationLeaseTests: XCTestCase {
    static let base = "https://notify-k40.example.test"
    static let token = "synthetic-token"

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
            return (Data(#"{"code":200,"data":{"items":[]}}"#.utf8), 200)
        }
    }

    func testPlayerLeaseNotificationsPassTheWriteFirewall() async throws {
        let suite = "k40-notify-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let build = RegionalLaunchConfiguration.BuildMetadata(market: "CN", baseURL: Self.base,
            bundleIdentifier: "com.questify.ios", realm: "k40-notify-" + UUID().uuidString.lowercased())
        let deployment = try RegionalLaunchConfiguration.reviewedDeployment(build: build)
        let root = RegionalLaunchConfiguration.makeComposition(reviewed: deployment, build: build,
            storage: .init(defaults: defaults, tokenStore: { _ in Vault() }), makeTransport: { Wire() })
        let baseURL = try XCTUnwrap(URL(string: Self.base))
        let context = RuntimeDependencyContext(market: .china, baseURL: baseURL, role: "player",
            session: try PlayExperienceSession(accountID: 7, epoch: 1, namespace: root.reviewed?.storageScope.service ?? "unconfigured",
                token: Self.token, role: "player"))
        let grant = try XCTUnwrap(root.playerWriteGrant(context))
        let wire = Wire()
        let service = SquareNotificationLease.service(baseURL: baseURL, transport: wire)
        XCTAssertTrue(service.readsEnabled)
        let page = try await service.notifications(token: Self.token) {}
        XCTAssertTrue(page.isEmpty)
        let list = try XCTUnwrap(wire.requests.first)
        XCTAssertEqual(list.httpMethod, "GET")
        XCTAssertEqual(list.url?.path, "/api/v1/community/notifications")
        XCTAssertTrue(ReviewedProductionFormMutationRoute.acceptsPlayerWrite(list, baseURL: baseURL, token: Self.token, context: context, grant: grant))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall(SquareNotificationLease.listPath))

        let snapshot = SquareGovernanceSnapshot(identity: .init(accountID: 7, epoch: 1, namespace: "notify"),
                                                enforcements: [], notifications: [], preferences: .object([:]))
        let read = try service.command(SquareGovernanceReview(snapshot: snapshot, action: .markRead(notificationID: 81), now: Date()), token: Self.token)
        XCTAssertTrue(ReviewedProductionFormMutationRoute.acceptsPlayerWrite(read, baseURL: baseURL, token: Self.token, context: context, grant: grant), "mark-read")
        let appeal = try service.command(SquareGovernanceReview(snapshot: snapshot, action: .appeal(enforcementID: 91, reason: "facts"), now: Date()), token: Self.token)
        XCTAssertTrue(ReviewedProductionFormMutationRoute.acceptsPlayerWrite(appeal, baseURL: baseURL, token: Self.token, context: context, grant: grant), "appeal")
        XCTAssertFalse(service.allows(.preferences([.socialEnabled: false])))
        XCTAssertFalse(service.allows(.approveComment(postID: 1, commentID: 2)))
        XCTAssertFalse(service.allows(.deleteOwnComment(commentID: 3)))
    }
}
