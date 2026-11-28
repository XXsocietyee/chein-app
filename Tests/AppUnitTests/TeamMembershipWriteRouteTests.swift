#if canImport(QuestifyApp)
@testable import QuestifyApp
#endif
#if canImport(QuestifyCore)
import QuestifyCore
#elseif canImport(Core)
import Core
#endif
import XCTest
@testable import Questify

/// P0-8: the composition firewall admits exactly the requests `TeamHTTPService` sends for join / quit / kick /
/// disband / join-mode, and the lease factory issues those five paths only with the reviewed production gates.
@MainActor final class TeamMembershipWriteRouteTests: XCTestCase {
    private final class Recorder: HTTPTransport {
        var requests: [URLRequest] = []
        var replies: [String]
        init(_ replies: [String]) { self.replies = replies }
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return (Data((replies.isEmpty ? #"{"code":200}"# : replies.removeFirst()).utf8), 200)
        }
    }
    private let base = URL(string: "https://example.com")!

    private func sentRequest(_ action: TeamAction, detail: String) async throws -> URLRequest {
        let session = try TeamSyntheticFixtures.session(), journal = TeamMemoryJournal(), id = UUID()
        try journal.write(.init(operationID: id, ownerKey: session.ownerKey, targetKey: action.targetKey, joinMode: action.requestedJoinMode))
        let path = String(try TeamWriteContract(action).path.dropFirst())
        let ack = action.requestedJoinMode.map { "{\"code\":200,\"data\":{\"joinMode\":\($0.rawValue)}}" } ?? #"{"code":200}"#
        let recorder = Recorder(["{\"code\":200,\"data\":" + detail + "}", ack])
        let write = try OperationEndpointApproval(baseURL: base, namespace: session.storageNamespace, accountID: session.accountID,
                                                  paths: ReviewedTeamMembershipWriteRoute.approvalPaths)
        let service = TeamHTTPService(configuration: try APIConfiguration(baseURL: base), transport: recorder, approval: write,
                                      journal: journal, currentSession: { session })
        _ = await service.submit(action, operationID: id, session: session)
        let request = try XCTUnwrap(recorder.requests.last)
        XCTAssertEqual(request.url?.path, "/" + path)
        return request
    }

    func testEveryAdapterRequestPassesTheFirewall() async throws {
        let member = TeamSyntheticFixtures.detailJSON
        let preview = member.replacingOccurrences(of: "\"joined\":true,\"leader\":true", with: "\"joined\":false,\"leader\":false")
        let cases: [(TeamAction, String)] = [(.join(teamID: 4101, inviteCode: "SYNTHETIC-TEAM"), preview), (.leave(teamID: 4101), member),
                                             (.remove(teamID: 4101, memberID: 902), member), (.disband(teamID: 4101), member),
                                             (.changeJoinMode(teamID: 4101, mode: .invitation), member)]
        for (action, detail) in cases {
            let request = try await sentRequest(action, detail: detail)
            XCTAssertTrue(ReviewedTeamMembershipWriteRoute.accepts(request, baseURL: base, token: "synthetic-team-token"), action.key)
            XCTAssertFalse(ReviewedTeamMembershipWriteRoute.accepts(request, baseURL: base, token: "another-team-token"), action.key)
            XCTAssertFalse(ReviewedTeamMembershipWriteRoute.accepts(request, baseURL: base, token: nil), action.key)
        }
    }

    private func request(_ path: String, _ body: String, token: String = "synthetic-team-token") -> URLRequest {
        var request = URLRequest(url: base.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.httpBody = Data(body.utf8)
        return request
    }

    func testExactBodiesAreAcceptedAndNearMissesRefused() {
        let accepted = [("api/team/join", #"{"inviteCode":"ABC123"}"#), ("api/team/quit", #"{"teamId":7}"#),
                        ("api/team/disband", #"{"teamId":7}"#), ("api/team/kick", #"{"memberId":9,"teamId":7}"#),
                        ("api/team/join-mode", #"{"joinMode":2,"teamId":7}"#)]
        for (path, body) in accepted {
            XCTAssertTrue(ReviewedTeamMembershipWriteRoute.accepts(request(path, body), baseURL: base, token: "synthetic-team-token"), path)
        }
        let refused = [("api/team/join", #"{"inviteCode":" ABC123"}"#), ("api/team/join", #"{"inviteCode":"ABC","teamId":7}"#),
                       ("api/team/quit", #"{"teamId":"7"}"#), ("api/team/quit", #"{"teamId":0}"#), ("api/team/quit", #"{"teamId":true}"#),
                       ("api/team/disband", #"{"teamId":7,"memberId":9}"#), ("api/team/kick", #"{"teamId":7}"#),
                       ("api/team/kick", #"{"teamId":7,"memberId":9}"#), ("api/team/join-mode", #"{"joinMode":3,"teamId":7}"#),
                       ("api/team/create", #"{"maxMembers":2,"ownerId":1,"ownerType":2}"#), ("api/team/invite-code/rotate", #"{"teamId":7}"#),
                       ("api/team/apply", #"{"teamId":7}"#)]
        for (path, body) in refused {
            XCTAssertFalse(ReviewedTeamMembershipWriteRoute.accepts(request(path, body), baseURL: base, token: "synthetic-team-token"), path + " " + body)
        }
        var get = request("api/team/quit", #"{"teamId":7}"#); get.httpMethod = "GET"
        XCTAssertFalse(ReviewedTeamMembershipWriteRoute.accepts(get, baseURL: base, token: "synthetic-team-token"))
        var query = request("api/team/quit", #"{"teamId":7}"#); query.url = URL(string: "https://example.com/api/team/quit?teamId=7")
        XCTAssertFalse(ReviewedTeamMembershipWriteRoute.accepts(query, baseURL: base, token: "synthetic-team-token"))
        XCTAssertFalse(ReviewedTeamMembershipWriteRoute.accepts(request("api/team/quit", #"{"teamId":7}"#), baseURL: URL(string: "https://other.example.com")!, token: "synthetic-team-token"))
    }

    func testLeasePathsAreExactlyTheFiveMembershipWrites() throws {
        XCTAssertEqual(ReviewedTeamMembershipWriteRoute.approvalPaths,
                       ["api/team/join", "api/team/quit", "api/team/kick", "api/team/disband", "api/team/join-mode"])
        XCTAssertFalse(ReviewedTeamMembershipWriteRoute.approvalPaths.contains("api/team/create"))
        XCTAssertTrue(ReviewedTeamMembershipWriteRoute.approvalPaths.isDisjoint(with: ReviewedNearbyTeamWriteRoute.approvalPaths))
    }
}
