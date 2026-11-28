import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import Questify

/// fix/1128b-team-reg: each gap builds the shipped Release composition (`RegionalLaunchConfiguration.shippedComposition`,
/// the reviewed China deployment) and proves the service is switched on and admits the exact path(s).
@MainActor final class Fix1128bTeamRegCompositionTests: XCTestCase {
    private let bundle = "invalid.example.questify.ios"
    private let realm = "cn-prod"

    // MARK: Gap #6 / #7 — team writes go through `api/team/command`

    func testGap6ReleaseTeamWritesUseTheCommandWriterTheLeaseAdmits() async throws {
        let recorder = Fix1128bRecorder()
        let composition = shipped(recorder)
        let player = try playerContext(composition)
        let transport = composition.transport()
        transport.current = {
            .init(epoch: player.session.epoch, accountID: player.session.accountID, role: player.role, token: player.session.token)
        }
        let writes = composition.teamWrites(player, transport: transport)
        let writer = try XCTUnwrap(writes.commands, "Release must compose the team command writer")
        XCTAssertTrue(TeamCommandWriter.paths.isSubset(of: writer.approval.paths))
        let api = try XCTUnwrap(composition.reviewed?.regional.apiConfiguration)
        XCTAssertTrue(writer.approval.allows(configuration: api, namespace: player.session.namespace,
                                             accountID: player.session.accountID, path: "api/team/command"))
        recorder.payload = #"{"code":200,"data":{"requestId":"r","state":"APPLIED","message":"原请求已执行"}}"#
        let receipt = await writer.submitReceipt(key: "team-4", path: "api/team/command",
                                                 fields: ["action": "quit", "targetId": "4"],
                                                 requestID: TeamCommandWriter.requestID(for: UUID()))
        XCTAssertEqual(recorder.paths.last, "api/team/command", "the composition firewall admits the signed command")
        XCTAssertEqual(receipt.terminal, .applied(200))
        recorder.payload = #"{"code":200,"data":{"requestId":"r","state":"REJECTED","message":"暂时无法加入该队伍"}}"#
        let rejected = await writer.submitReceipt(key: "team-5", path: "api/team/command", fields: ["action": "disband", "targetId": "5"])
        XCTAssertEqual(rejected.terminal, .rejected(200))
        XCTAssertEqual(rejected.message, "暂时无法加入该队伍")
    }

    func testGap6SignedOutHasNoTeamWrites() {
        let composition = shipped(Fix1128bRecorder())
        let none = composition.teamWrites(nil, transport: composition.transport())
        XCTAssertNil(none.commands)
        XCTAssertNil(none.approval)
    }

    // MARK: helpers

    func shipped(_ recorder: Fix1128bRecorder) -> AppCompositionRoot {
        RegionalLaunchConfiguration.shippedComposition(build: .init(
            market: "CN", baseURL: ReviewedMarketLaunch.chinaProductionBaseURL, bundleIdentifier: bundle, realm: realm),
            makeTransport: { recorder })
    }

    func playerContext(_ composition: AppCompositionRoot, role: String = "player") throws -> RuntimeDependencyContext {
        let namespace = try XCTUnwrap(composition.reviewed?.storageScope.service)
        let base = try XCTUnwrap(URL(string: ReviewedMarketLaunch.chinaProductionBaseURL))
        let session = try PlayExperienceSession(accountID: 7, epoch: 1, namespace: namespace, token: "player-token", role: role)
        return RuntimeDependencyContext(market: .china, baseURL: base, role: role, session: session)
    }
}

final class Fix1128bRecorder: HTTPTransport {
    var paths: [String] = []
    var methods: [String] = []
    var payload = #"{"code":200,"data":[]}"#
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        paths.append(request.url?.path.split(separator: "/").drop(while: { $0 != "api" }).joined(separator: "/") ?? "")
        methods.append(request.httpMethod ?? "")
        return (Data(payload.utf8), 200)
    }
}
