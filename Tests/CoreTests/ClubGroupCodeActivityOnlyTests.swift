import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

/// CLB-r11-group-code-01 (MP pages/club/group-code/index.js:44-62, 93-105): an activityId-only link issues straight away
/// with body `{activityId}`. It must not stop at the topic review read the MP never sends.
@MainActor final class ClubGroupCodeActivityOnlyTests: XCTestCase {
    private let url = URL(string: "https://example.com")!

    func testActivityOnlyLinkIssuesUnderReleaseChinaApproval() async throws {
        let context = RuntimeDependencyContext(market: .china, baseURL: url, role: "club",
            session: try .init(accountID: 701, epoch: 1, namespace: "test-cn", token: "test-token"))
        let wire = Wire(), dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let endpoints = try OperationEndpointApproval(baseURL: url, namespace: "test-cn", accountID: 701,
            paths: ClubMPFirstGovernance.paths(for: ClubMPFirstGovernance.governance))
        let approval = try ClubGovernanceProductionApproval(mpFirstMarket: .china, endpoints: endpoints, operations: ClubMPFirstGovernance.governance)
        let api = try APIConfiguration(baseURL: url)
        let current: () -> RuntimeDependencyContext? = { context }
        let access = ClubGovernanceSessionAccess(service: .init(configuration: api, transport: wire), currentSession: {
            try? .init(accountID: 701, epoch: 1, token: "test-token", storageNamespace: "test-cn")
        }, productionService: { command in
            ClubGovernanceProductionFactory(api: api, approval: approval, transport: wire, current: current).service(for: command)
        }, runtimeContext: current)
        let command = try ClubGovernanceCommand(operation: .issueGroupCode, scope: .init(activityID: 55), values: [:])
        XCTAssertTrue(command.skipsReviewRead)
        XCTAssertFalse(try ClubGovernanceCommand(operation: .issueGroupCode, scope: .init(topicID: 3, activityID: 55), values: [:]).skipsReviewRead)
        XCTAssertTrue(approval.permits(command, context: context))
        let coordinator = ClubGovernanceCoordinator(access: access, journal: ClubGovernanceFileIntentStore(directory: dir))
        let review = try await coordinator.prepare(command)
        let receipt = try await coordinator.confirm(review)
        XCTAssertEqual(receipt["code"].string, "GC-1")
        XCTAssertEqual(wire.requests.map { $0.url?.path ?? "" }, ["/api/verify/groupcode/issue"])
        XCTAssertEqual(try JSONDecoder().decode(ClubGovernanceValue.self, from: XCTUnwrap(wire.requests.last?.httpBody)),
                       .object(["activityId": .integer(55)]))
    }

    @MainActor private final class Wire: HTTPTransport {
        var requests: [URLRequest] = []
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            guard request.url?.path == "/api/verify/groupcode/issue" else { throw URLError(.unsupportedURL) }
            return (Data(#"{"code":200,"data":{"code":"GC-1","qrcodeUrl":"https://example.com/qr.png","activityId":55}}"#.utf8), 200)
        }
    }
}
