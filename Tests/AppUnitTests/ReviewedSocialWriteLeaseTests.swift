import Foundation
import XCTest
@testable import Questify

/// Channels + friends + team pool grants in the shipped China composition (contract §1–§8): non-money player/club
/// social writes are admitted, money stays refused.
@MainActor final class ReviewedSocialWriteLeaseTests: XCTestCase {
    private let base = URL(string: "https://composition.example.test")!
    private func context(role: String = "player", market: RegionalMarket = .china) throws -> RuntimeDependencyContext {
        .init(market: market, baseURL: base, role: role,
              session: try .init(accountID: 7, epoch: 1, namespace: "tests", token: "synthetic-token", role: role))
    }
    private func request(_ method: String, _ path: String, query: String? = nil, body: [String: Any]? = nil) -> URLRequest {
        var url = base.appendingPathComponent(path)
        if let query { url = URL(string: url.absoluteString + "?" + query)! }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("synthetic-token", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    func testSocialLeasesNeedPlayerWritesAndAPlayerOrClubRole() throws {
        let gates = ReviewedProductionGateLeases()
        XCTAssertNil(gates.socialWriters(try context()), "closed until the reviewed deployment enables player writes")
        gates.notePlayerWrites(true)
        let grant = try XCTUnwrap(gates.socialWriters(try context()))
        XCTAssertTrue(grant.friendRemoval.endpoint.paths.contains(NativeFriendRemovalApproval.removePath))
        XCTAssertEqual(grant.friendDirectory.endpoint.paths, NativeFriendDirectoryApproval.paths)
        XCTAssertTrue(grant.onboarding.endpoint.paths.contains(NativeChannelOnboardingApproval.submit))
        XCTAssertEqual(gates.socialWriters(try context())?.friendMetadata, grant.friendMetadata, "one issuance per context while it is live")
        XCTAssertNotNil(gates.socialWriters(try context(role: "club")))
        XCTAssertNil(gates.socialWriters(try context(role: "merchant")))
        XCTAssertNil(gates.socialWriters(try context(market: .unitedStates)))
        XCTAssertNotNil(gates.friendChannelInvite(try context(), mode: .mine))
        XCTAssertNotNil(gates.friendTeamInvite(try context(), mode: .team(5)))
        XCTAssertEqual(gates.friendTeamInvite(try context(), mode: .team(5))?.allowWrites, true)
        XCTAssertNotNil(gates.friendChannelSource(try context(), channelID: 1001))
        XCTAssertNil(gates.friendChannelSource(try context(), channelID: 0))
    }

    func testChannelManagementLeaseCoversClubsAndTeamsOnly() throws {
        let gates = ReviewedProductionGateLeases()
        gates.notePlayerWrites(true)
        let club = try NativeChannelManagementScope(guildKind: 1, guildID: try NativeChannelManagementID("42"))
        let hangout = try NativeChannelManagementScope(guildKind: 2, guildID: try NativeChannelManagementID("42"))
        let approval = try XCTUnwrap(gates.channelManagement(try context(), viewerRevision: 3, scope: club))
        XCTAssertEqual(approval.operations, ReviewedProductionGateLeases.channelManagementOperations)
        XCTAssertTrue(gates.channelManagement(try context(), viewerRevision: 3, scope: club) === approval)
        XCTAssertFalse(gates.channelManagement(try context(), viewerRevision: 4, scope: club) === approval)
        XCTAssertNil(gates.channelManagement(try context(), viewerRevision: 3, scope: hangout))
        XCTAssertNil(gates.channelManagement(try context(role: "merchant"), viewerRevision: 3, scope: club))
    }

    func testPlayerWriteRouteAdmitsAdmissionAndTeamPoolButNotMoney() throws {
        let gates = ReviewedProductionGateLeases()
        gates.notePlayerWrites(true)
        let context = try context()
        let grant = try XCTUnwrap(gates.playerWriters(context))
        func accepts(_ request: URLRequest) -> Bool {
            ReviewedProductionFormMutationRoute.acceptsPlayerWrite(request, baseURL: base, token: "synthetic-token", context: context, grant: grant)
        }
        XCTAssertTrue(accepts(request("POST", "api/join-request/submit", body: ["guild_kind": 1, "guild_id": 42, "request_id": "join-00000001"])))
        XCTAssertTrue(accepts(request("POST", "api/team/pool/hint", body: ["teamId": 5, "nodeId": 9, "requestId": "abcdefabcdefabcdef"])))
        XCTAssertTrue(accepts(request("GET", "api/team/pool", query: "teamId=5")))
        XCTAssertTrue(accepts(request("GET", "api/channel-platform/admission/requests/adm-00000000-0000-4000-8000-000000000009")))
        XCTAssertTrue(accepts(request("GET", "api/channels/1001")))
        XCTAssertFalse(accepts(request("GET", "api/channel-platform/admission/requests/bad id")))
        XCTAssertTrue(accepts(request("POST", "api/friend/request", body: ["peer_id": 8, "request_id": UUID().uuidString.lowercased()])))
        for money in ["api/registration/pay", "api/pay/create", "api/withdrawal/create", "api/club/settlement/withdraw", "api/wallet/withdraw"] {
            XCTAssertFalse(accepts(request("POST", money, body: ["id": 1])), money)
        }
        XCTAssertFalse(accepts(request("POST", "api/team/pool/hint", query: "teamId=5", body: ["teamId": 5])), "a write never carries a query")
    }
}
