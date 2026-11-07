#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// subpackageRoam/my-teams: the 我的 tab's `loadMine` drives the real NearbyTeamService and the
/// scoped NearbyTeamHTTPReadTransport into a recording fake transport (no real host). Applications
/// are published only after a code-200 envelope; a refusal leaves the tab empty with a failure key.
private final class MyTeamsProofTransport: HTTPTransport {
    var requests: [URLRequest] = []
    var status = 200
    var response = #"{"code":200,"data":[{"teamId":502,"title":"Pending team","leaderName":"Jun","applyStatus":"PENDING","applyExpireTime":"2099-10-02T02:00:00Z"},{"teamId":506,"title":"Rejected application","applyStatus":"REJECTED"}]}"#
    func send(_ request: URLRequest) async throws -> (Data, Int) { requests.append(request); return (Data(response.utf8), status) }
}

@MainActor final class NearbyMyTeamsHTTPReadProofTests: XCTestCase {
    private let session = NearbyTeamSyntheticFixtures.session

    private func makeModel(_ transport: MyTeamsProofTransport) throws -> NearbyTeamCoordinator {
        let configuration = try APIConfiguration(baseURL: XCTUnwrap(URL(string: "https://example.com")))
        let approval = try OperationEndpointApproval(baseURL: configuration.baseURL, namespace: session.namespace, accountID: session.accountID,
                                                     paths: ["api/team/my-applications"])
        let reader = NearbyTeamHTTPReadTransport(configuration: configuration, transport: transport, approval: approval,
                                                 currentSession: { self.session }, token: { _ in "synthetic-token" })
        let service = NearbyTeamService(readTransport: reader, liveReadGrant: true, writeAdapter: nil)
        return NearbyTeamCoordinator(service: service, session: session, locks: NearbyTeamLockStore(defaults: nil))
    }

    func testLoadMinePostsMyApplicationsAndPublishesRowsOnlyAfterServerOK() async throws {
        let transport = MyTeamsProofTransport()
        let model = try makeModel(transport)
        XCTAssertTrue(transport.requests.isEmpty, "Construction is inert")
        await model.loadMine()
        XCTAssertEqual(transport.requests.count, 1)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/team/my-applications")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "synthetic-token")
        XCTAssertNil(request.httpBody)
        XCTAssertNil(model.messageKey)
        XCTAssertEqual(model.myApplications.map(\.id), [NearbyTeamID(502), NearbyTeamID(506)])
        XCTAssertEqual(model.myApplications.map(\.status), [.pending, .rejected])
    }

    func testRefusedOrFailedReadPublishesNoApplications() async throws {
        for (status, json) in [(200, #"{"code":500,"errorCode":"BUSY","msg":"busy"}"#), (502, #"{"code":200,"data":[]}"#), (200, "{}")] {
            let transport = MyTeamsProofTransport()
            transport.status = status; transport.response = json
            let model = try makeModel(transport)
            await model.loadMine()
            XCTAssertEqual(transport.requests.count, 1, json)
            XCTAssertTrue(model.myApplications.isEmpty, json)
            XCTAssertEqual(model.messageKey, "nearby.loadFailed", json)
        }
    }

    func testMissingReadGrantSendsNothing() async throws {
        let transport = MyTeamsProofTransport()
        let configuration = try APIConfiguration(baseURL: XCTUnwrap(URL(string: "https://example.com")))
        let approval = try OperationEndpointApproval(baseURL: configuration.baseURL, namespace: session.namespace, accountID: session.accountID,
                                                     paths: ["api/team/nearby"])
        let reader = NearbyTeamHTTPReadTransport(configuration: configuration, transport: transport, approval: approval,
                                                 currentSession: { self.session }, token: { _ in "synthetic-token" })
        let model = NearbyTeamCoordinator(service: NearbyTeamService(readTransport: reader, liveReadGrant: true, writeAdapter: nil),
                                          session: session, locks: NearbyTeamLockStore(defaults: nil))
        await model.loadMine()
        XCTAssertTrue(transport.requests.isEmpty)
        XCTAssertTrue(model.myApplications.isEmpty)
        XCTAssertEqual(model.messageKey, "nearby.unconfigured")
    }
}
#endif
