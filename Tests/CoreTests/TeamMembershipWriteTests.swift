import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// P0-8: the five team membership writes, end to end through `TeamCoordinator` + `TeamHTTPService` with the
/// production read lease (`api/team/info`) and the reviewed write lease. Request shapes match
/// `ApiPlayTeamController` on `us/r3-functional`; every confirmed result is read back from the server.
private final class TeamMembershipWireTransport: HTTPTransport {
    enum Reply { case json(String, Int = 200), lost }
    var replies: [Reply]
    var requests: [URLRequest] = []
    init(_ replies: [Reply]) { self.replies = replies }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        guard !replies.isEmpty else { throw URLError(.badServerResponse) }
        switch replies.removeFirst() {
        case .json(let json, let status): return (Data(json.utf8), status)
        case .lost: throw URLError(.networkConnectionLost)
        }
    }
}

@MainActor final class TeamMembershipWriteTests: XCTestCase {
    private let base = URL(string: "https://example.com")!
    private func info(_ json: String = TeamSyntheticFixtures.detailJSON) -> TeamMembershipWireTransport.Reply {
        .json("{\"code\":200,\"data\":" + json + "}")
    }
    private func body(_ request: URLRequest?) -> String? {
        request?.httpBody.flatMap { String(data: $0, encoding: .utf8) }
    }
    private func make(_ transport: TeamMembershipWireTransport, writes: Set<String>, session: TeamSession,
                      journal: TeamMemoryJournal) throws -> TeamCoordinator {
        let configuration = try APIConfiguration(baseURL: base)
        let read = try OperationEndpointApproval(baseURL: base, namespace: session.storageNamespace, accountID: session.accountID,
                                                 paths: ["api/team/my", "api/team/info"])
        let write = try OperationEndpointApproval(baseURL: base, namespace: session.storageNamespace, accountID: session.accountID,
                                                  paths: writes)
        let service = TeamHTTPService(configuration: configuration, transport: transport, approval: write, journal: journal,
                                      currentSession: { session }, readApproval: read, requiresIDMembership: true)
        XCTAssertEqual(service.authority, .approved)
        return TeamCoordinator(service: service, journal: journal, currentSession: { session })
    }

    func testKickSendsExactBodyThenReadsBackServerRosterAndReleasesLock() async throws {
        let session = try TeamSyntheticFixtures.session(), journal = TeamMemoryJournal()
        let after = TeamSyntheticFixtures.detailJSON
            .replacingOccurrences(of: "\"joinedCount\":2", with: "\"joinedCount\":1")
            .replacingOccurrences(of: ",{\"memberId\":902,\"memberName\":\"Synthetic teammate\",\"role\":0}", with: "")
        let wire = TeamMembershipWireTransport([info(), info(), info(), .json(#"{"code":200,"msg":"成员已移出"}"#), info(after)])
        let c = try make(wire, writes: ["api/team/kick"], session: session, journal: journal)
        await c.loadDetail(.id(4101))
        c.prepare(.remove(teamID: 4101, memberID: 902))
        await c.confirm(try XCTUnwrap(c.review))
        XCTAssertEqual(c.writeState, .acknowledged)
        XCTAssertEqual(c.messageKey, "team.done.remove")
        XCTAssertTrue(journal.records.isEmpty)
        let kick = wire.requests[3]
        XCTAssertEqual(kick.url?.path, "/api/team/kick"); XCTAssertEqual(kick.httpMethod, "POST")
        XCTAssertEqual(kick.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(kick.value(forHTTPHeaderField: "Authorization"), "synthetic-team-token")
        XCTAssertEqual(body(kick), #"{"memberId":902,"teamId":4101}"#)

        let applied = await c.readBackConfirmedWrite()
        XCTAssertTrue(applied)
        XCTAssertEqual(wire.requests.count, 5)
        XCTAssertEqual(wire.requests[4].url?.path, "/api/team/info"); XCTAssertEqual(body(wire.requests[4]), #"{"teamId":4101}"#)
        XCTAssertEqual(c.detail?.members.map(\.id), [901]); XCTAssertEqual(c.detail?.team.joinedCount, 1)
        XCTAssertEqual(c.writeState, .idle); XCTAssertEqual(c.messageKey, "team.done.remove")
        // A second read-back has nothing left to confirm and sends nothing.
        let again = await c.readBackConfirmedWrite()
        XCTAssertFalse(again); XCTAssertEqual(wire.requests.count, 5)
    }

    func testJoinModeUsesServerConfirmedModeAndReadBack() async throws {
        let session = try TeamSyntheticFixtures.session(), journal = TeamMemoryJournal()
        let after = TeamSyntheticFixtures.detailJSON.replacingOccurrences(of: "\"joinMode\":2", with: "\"joinMode\":1")
        let wire = TeamMembershipWireTransport([info(), info(), info(), .json(#"{"code":200,"msg":"组队方式已更新","data":{"joinMode":1}}"#), info(after)])
        let c = try make(wire, writes: ["api/team/join-mode"], session: session, journal: journal)
        await c.loadDetail(.id(4101))
        c.prepare(.changeJoinMode(teamID: 4101, mode: .invitation))
        await c.confirm(try XCTUnwrap(c.review))
        XCTAssertEqual(c.writeState, .acknowledged); XCTAssertEqual(c.confirmedJoinMode, .invitation)
        XCTAssertEqual(c.messageKey, "team.done.joinMode")
        XCTAssertEqual(wire.requests[3].url?.path, "/api/team/join-mode")
        XCTAssertEqual(body(wire.requests[3]), #"{"joinMode":1,"teamId":4101}"#)
        let applied = await c.readBackConfirmedWrite()
        XCTAssertTrue(applied)
        XCTAssertEqual(c.detail?.team.joinMode, .invitation); XCTAssertNil(c.confirmedJoinMode); XCTAssertEqual(c.writeState, .idle)
    }

    func testJoinModeReplyWithAnotherModeIsUnknownAndStaysLocked() async throws {
        let session = try TeamSyntheticFixtures.session(), journal = TeamMemoryJournal()
        let wire = TeamMembershipWireTransport([info(), info(), info(), .json(#"{"code":200,"data":{"joinMode":2}}"#)])
        let c = try make(wire, writes: ["api/team/join-mode"], session: session, journal: journal)
        await c.loadDetail(.id(4101))
        c.prepare(.changeJoinMode(teamID: 4101, mode: .invitation))
        await c.confirm(try XCTUnwrap(c.review))
        XCTAssertEqual(c.writeState, .unknown); XCTAssertEqual(c.messageKey, "team.unknown"); XCTAssertNotNil(c.pending)
        let applied = await c.readBackConfirmedWrite()
        XCTAssertFalse(applied); XCTAssertEqual(wire.requests.count, 4)
    }

    func testDisbandRetiresTheTeamWithConfirmedCopyNotAnErrorPage() async throws {
        let session = try TeamSyntheticFixtures.session(), journal = TeamMemoryJournal()
        let wire = TeamMembershipWireTransport([info(), info(), info(), .json(#"{"code":200,"msg":"队伍已解散"}"#)])
        let c = try make(wire, writes: ["api/team/disband"], session: session, journal: journal)
        await c.loadDetail(.id(4101))
        c.prepare(.disband(teamID: 4101))
        await c.confirm(try XCTUnwrap(c.review))
        XCTAssertEqual(wire.requests[3].url?.path, "/api/team/disband"); XCTAssertEqual(body(wire.requests[3]), #"{"teamId":4101}"#)
        XCTAssertEqual(c.writeState, .acknowledged); XCTAssertEqual(c.retiredMembershipTeamID, 4101); XCTAssertNil(c.detail)
        XCTAssertEqual(c.messageKey, "team.done.disband")
        XCTAssertNil(TeamPagePresentation.blockingState(kind: .detail, messageKey: c.messageKey, hasDetail: false))
        // The retired team is never read again by this page; 我的队伍 re-reads the list instead.
        let applied = await c.readBackConfirmedWrite()
        XCTAssertFalse(applied); XCTAssertEqual(wire.requests.count, 4)
    }

    func testQuitSendsTeamIDOnlyAndRetires() async throws {
        let session = try TeamSyntheticFixtures.session(), journal = TeamMemoryJournal()
        let member = TeamSyntheticFixtures.detailJSON.replacingOccurrences(of: "\"leader\":true", with: "\"leader\":false")
        let wire = TeamMembershipWireTransport([info(member), info(member), info(member), .json(#"{"code":200,"msg":"已退出队伍"}"#)])
        let c = try make(wire, writes: ["api/team/quit"], session: session, journal: journal)
        await c.loadDetail(.id(4101))
        c.prepare(.leave(teamID: 4101))
        await c.confirm(try XCTUnwrap(c.review))
        XCTAssertEqual(wire.requests[3].url?.path, "/api/team/quit"); XCTAssertEqual(body(wire.requests[3]), #"{"teamId":4101}"#)
        XCTAssertEqual(c.messageKey, "team.done.leave"); XCTAssertEqual(c.retiredMembershipTeamID, 4101)
    }

    func testJoinByInviteCodeSendsTrimmedCodeOnlyAndOffersTheTeam() async throws {
        let session = try TeamSyntheticFixtures.session(), journal = TeamMemoryJournal()
        let preview = TeamSyntheticFixtures.detailJSON.replacingOccurrences(of: "\"joined\":true,\"leader\":true", with: "\"joined\":false,\"leader\":false")
        let wire = TeamMembershipWireTransport([info(preview), info(preview), info(preview), .json(#"{"code":200,"msg":"已加入队伍","data":{"id":4101}}"#)])
        let c = try make(wire, writes: ["api/team/join"], session: session, journal: journal)
        await c.loadDetail(.invitation(" SYNTHETIC-TEAM "))
        XCTAssertEqual(body(wire.requests[0]), #"{"inviteCode":"SYNTHETIC-TEAM"}"#)
        c.prepare(.join(teamID: 4101, inviteCode: "SYNTHETIC-TEAM"))
        await c.confirm(try XCTUnwrap(c.review))
        XCTAssertEqual(wire.requests[3].url?.path, "/api/team/join"); XCTAssertEqual(body(wire.requests[3]), #"{"inviteCode":"SYNTHETIC-TEAM"}"#)
        XCTAssertEqual(c.writeState, .acknowledged); XCTAssertEqual(c.messageKey, "team.done.join"); XCTAssertEqual(c.postJoinDetailID, 4101)
        // The invitation page keeps its 查看队伍 continuation; the member page reads with membership required.
        let applied = await c.readBackConfirmedWrite()
        XCTAssertFalse(applied); XCTAssertEqual(c.postJoinDetailID, 4101)
    }

    func testServerRejectionIsTerminalAndUsesTheMPRetryCopy() async throws {
        let session = try TeamSyntheticFixtures.session(), journal = TeamMemoryJournal()
        let wire = TeamMembershipWireTransport([info(), info(), info(), .json(#"{"code":500,"msg":"无权操作"}"#)])
        let c = try make(wire, writes: ["api/team/kick"], session: session, journal: journal)
        await c.loadDetail(.id(4101))
        c.prepare(.remove(teamID: 4101, memberID: 902))
        await c.confirm(try XCTUnwrap(c.review))
        XCTAssertEqual(c.writeState, .rejected); XCTAssertEqual(c.messageKey, "team.rejected"); XCTAssertTrue(journal.records.isEmpty)
        XCTAssertEqual(c.detail?.members.count, 2)
    }

    func testFailedReadBackKeepsTheLockAndTheRefreshMessage() async throws {
        let session = try TeamSyntheticFixtures.session(), journal = TeamMemoryJournal()
        let wire = TeamMembershipWireTransport([info(), info(), info(), .json(#"{"code":200}"#), .lost])
        let c = try make(wire, writes: ["api/team/kick"], session: session, journal: journal)
        await c.loadDetail(.id(4101))
        c.prepare(.remove(teamID: 4101, memberID: 902))
        await c.confirm(try XCTUnwrap(c.review))
        let applied = await c.readBackConfirmedWrite()
        XCTAssertFalse(applied)
        XCTAssertEqual(c.writeState, .acknowledged); XCTAssertEqual(c.readFailure, .network); XCTAssertEqual(c.messageKey, "team.refreshFailed")
    }

    func testWriteOutsideTheLeasePathsIsNeverSent() async throws {
        let session = try TeamSyntheticFixtures.session(), journal = TeamMemoryJournal()
        let wire = TeamMembershipWireTransport([info(), info(), info()])
        let c = try make(wire, writes: ["api/team/quit"], session: session, journal: journal)
        await c.loadDetail(.id(4101))
        c.prepare(.disband(teamID: 4101))
        await c.confirm(try XCTUnwrap(c.review))
        XCTAssertEqual(c.writeState, .notSent)
        XCTAssertFalse(wire.requests.contains { $0.url?.path == "/api/team/disband" })
    }

    func testEveryWriteHasServerConfirmedCopy() {
        let actions: [TeamAction] = [.join(teamID: 1, inviteCode: "A"), .leave(teamID: 1), .remove(teamID: 1, memberID: 2),
                                     .disband(teamID: 1), .changeJoinMode(teamID: 1, mode: .invitation)]
        XCTAssertEqual(Set(actions.compactMap(\.confirmedKey)), TeamAction.confirmedKeys)
        XCTAssertNil(TeamAction.create(context: TeamSyntheticFixtures.creation, size: 2, inviteOnly: false).confirmedKey)
    }
}
