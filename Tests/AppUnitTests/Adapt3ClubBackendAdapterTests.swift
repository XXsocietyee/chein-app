import Foundation
import XCTest
@testable import Questify

/// ADAPT-3. Fixtures copy the AjaxResult shapes produced by hengyin@4ac8c249
/// (ApiClubController / ApiClubRoleController). No live endpoint, no approvals, no secrets.
final class Adapt3ClubBackendAdapterTests: XCTestCase {
    private final class Wire: HTTPTransport {
        var requests: [URLRequest] = []
        var reply: (Data, Int)
        var fail = false
        init(_ body: String, status: Int = 200) { reply = (Data(body.utf8), status) }
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            if fail { throw URLError(.timedOut) }
            return reply
        }
    }
    private let base = URL(string: "https://example.test/")!
    private let token = "synthetic-token"

    private func client(_ wire: Wire) throws -> Adapt3ClubBackendClient {
        try Adapt3ClubBackendClient(baseURL: base, token: token, transport: wire)
    }
    private func body(_ request: URLRequest) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any])
    }
    private func assertJSONPost(_ request: URLRequest, path: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(request.httpMethod, "POST", file: file, line: line)
        XCTAssertEqual(request.url?.path, path, file: file, line: line)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json", file: file, line: line)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "synthetic-token", file: file, line: line)
    }

    func testRejectsInvalidTokenAndBase() {
        XCTAssertThrowsError(try Adapt3ClubBackendClient(baseURL: base, token: " ", transport: Wire("{}")))
    }

    func testApproveMapsToClubJoinRequestRouteWithJSONBody() async throws {
        let wire = Wire(#"{"msg":"已通过入会申请","code":200}"#)
        let outcome = try await client(wire).reviewJoinRequest(approve: true, clubID: 7, memberID: 42)
        XCTAssertEqual(outcome, .applied(Adapt3Empty(), message: "已通过入会申请"))
        let request = try XCTUnwrap(wire.requests.first)
        assertJSONPost(request, path: "/api/club/join-request/approve")
        let sent = try body(request)
        XCTAssertEqual(Set(sent.keys), ["clubId", "memberId"])
        XCTAssertEqual(sent["clubId"] as? Int, 7); XCTAssertEqual(sent["memberId"] as? Int, 42)
    }

    func testRejectCarriesTrimmedReviewReasonAndEnforcesBackendLimit() async throws {
        let wire = Wire(#"{"msg":"已拒绝入会申请","code":200}"#)
        let c = try client(wire)
        _ = try await c.reviewJoinRequest(approve: false, clubID: 7, memberID: 42, reviewReason: "  名额已满  ")
        XCTAssertEqual(wire.requests.last?.url?.path, "/api/club/join-request/reject")
        XCTAssertEqual(try body(try XCTUnwrap(wire.requests.last))["reviewReason"] as? String, "名额已满")
        XCTAssertThrowsError(try c.joinReviewRequest(approve: false, clubID: 7, memberID: 42, reviewReason: String(repeating: "a", count: 501)))
        XCTAssertNoThrow(try c.joinReviewRequest(approve: false, clubID: 7, memberID: 42, reviewReason: String(repeating: "a", count: 500)))
        XCTAssertThrowsError(try c.joinReviewRequest(approve: true, clubID: 0, memberID: 42, reviewReason: nil))
        XCTAssertThrowsError(try c.joinReviewRequest(approve: true, clubID: 7, memberID: -1, reviewReason: nil))
    }

    func testAlreadyProcessedApplicationIsBusinessRejectionNotSuccess() async throws {
        let wire = Wire(#"{"msg":"入会申请不存在或已处理","code":500}"#)
        let outcome = try await client(wire).reviewJoinRequest(approve: true, clubID: 7, memberID: 42)
        XCTAssertEqual(outcome, .rejected(code: 500, message: "入会申请不存在或已处理"))
    }

    func testLeaveMapsToQuitWithIdBodyAndDistinguishesNotMember() async throws {
        let left = Wire(#"{"msg":"已退出","code":200,"data":{"membershipAccessEnd":"2026-11-08 10:00:00"}}"#)
        let outcome = try await client(left).leave(clubID: 7)
        XCTAssertEqual(outcome, .applied(.left, message: "已退出"))
        assertJSONPost(try XCTUnwrap(left.requests.first), path: "/api/club/quit")
        XCTAssertEqual(try body(try XCTUnwrap(left.requests.first)).keys.sorted(), ["id"])
        let absent = Wire(#"{"msg":"未加入","code":200,"data":{"membershipAccessEnd":null}}"#)
        let r1 = try await client(absent).leave(clubID: 7)
        XCTAssertEqual(r1, .applied(.notMember, message: "未加入"))
        let owner = Wire(#"{"msg":"主理人不能直接退出；请先在成员治理中转让主理人，或解散俱乐部","code":500}"#)
        if case .rejected(let code, _) = try await client(owner).leave(clubID: 7) { XCTAssertEqual(code, 500) } else { XCTFail("owner leave must be rejected") }
    }

    func testWelcomeNoteSaveRequiresServerReadBackToEqualTrimmedText() async throws {
        let ok = Wire(#"{"msg":"已保存","code":200,"data":{"welcomeNote":"欢迎加入"}}"#)
        let r2 = try await client(ok).saveWelcomeNote(clubID: 7, note: " 欢迎加入 ")
        XCTAssertEqual(r2, .applied("欢迎加入", message: "已保存"))
        let request = try XCTUnwrap(ok.requests.first)
        assertJSONPost(request, path: "/api/club/open-settings/welcome-note")
        XCTAssertEqual(try body(request).keys.sorted(), ["id", "welcomeNote"])
        XCTAssertNil(request.value(forHTTPHeaderField: "X-Club-Welcome-Request-Id"))
        let different = Wire(#"{"msg":"已保存","code":200,"data":{"welcomeNote":"别的内容"}}"#)
        let r3 = try await client(different).saveWelcomeNote(clubID: 7, note: "欢迎加入")
        XCTAssertEqual(r3, .unknown)
        let missing = Wire(#"{"msg":"已保存","code":200,"data":null}"#)
        let r4 = try await client(missing).saveWelcomeNote(clubID: 7, note: "欢迎加入")
        XCTAssertEqual(r4, .unknown)
        let clear = Wire(#"{"msg":"已保存","code":200,"data":{"welcomeNote":""}}"#)
        let r5 = try await client(clear).saveWelcomeNote(clubID: 7, note: "   ")
        XCTAssertEqual(r5, .applied("", message: "已保存"))
    }

    func testWelcomeNoteRejectsOverlongTextAndReadsBackFromDetail() async throws {
        let c = try client(Wire("{}"))
        XCTAssertThrowsError(try c.welcomeNoteRequest(clubID: 7, note: String(repeating: "字", count: 201)))
        XCTAssertNoThrow(try c.welcomeNoteRequest(clubID: 7, note: String(repeating: "字", count: 200)))
        let detail = Wire(#"{"msg":"操作成功","code":200,"data":{"id":7,"name":"跑团","welcomeNote":"欢迎加入","isOwner":true}}"#)
        let r6 = try await client(detail).readWelcomeNote(clubID: 7)
        XCTAssertEqual(r6, .applied("欢迎加入", message: "操作成功"))
        assertJSONPost(try XCTUnwrap(detail.requests.first), path: "/api/club/detail")
    }

    func testRoleAssignReplayHasNoExpiryKeyAndValidatesCommittedAssignment() async throws {
        let fixture = #"{"msg":"操作成功","code":200,"data":{"id":88,"targetMemberId":42,"roleCode":"CLUB_OPERATOR","scopeType":"CLUB","scopeId":7,"expiresAt":null,"assignedAt":1793000000000,"version":0}}"#
        let wire = Wire(fixture)
        let id = "club-native-3F2504E0-4F89-41D3-9A0C-0305E82C3301"
        let outcome = try await client(wire).replayRoleAssignment(clubID: 7, activityID: nil, targetMemberID: 42, roleCode: "CLUB_OPERATOR", requestID: id)
        XCTAssertEqual(outcome, .applied(88, message: "操作成功"))
        let request = try XCTUnwrap(wire.requests.first)
        assertJSONPost(request, path: "/api/club/roles/assign")
        XCTAssertEqual(Set(try body(request).keys), ["clubId", "targetMemberId", "roleCode", "requestId"])
        let mismatch = Wire(fixture)
        let other = try await client(mismatch).replayRoleAssignment(clubID: 7, activityID: nil, targetMemberID: 43, roleCode: "CLUB_OPERATOR", requestID: id)
        XCTAssertEqual(other, .unknown)
        let event = Wire(fixture)
        let scoped = try await client(event).replayRoleAssignment(clubID: 7, activityID: 9, targetMemberID: 42, roleCode: "CLUB_OPERATOR", requestID: id)
        XCTAssertEqual(scoped, .unknown, "CLUB-scoped row must not satisfy an activity-scoped replay")
        XCTAssertEqual(try body(try XCTUnwrap(event.requests.first))["activityId"] as? Int, 9)
    }

    func testRoleAssignConflictAndRevokeReplayMapping() async throws {
        let id = "club-native-3F2504E0-4F89-41D3-9A0C-0305E82C3301"
        let conflict = Wire(#"{"msg":"角色分配 requestId 与原请求不一致","code":409}"#)
        let r7 = try await client(conflict).replayRoleAssignment(clubID: 7, activityID: nil, targetMemberID: 42, roleCode: "CLUB_OPERATOR", requestID: id)
        XCTAssertEqual(r7, .conflict(message: "角色分配 requestId 与原请求不一致"))
        let revoke = Wire(#"{"msg":"角色已撤销","code":200}"#)
        let applied = try await client(revoke).replayRoleRevocation(clubID: 7, activityID: nil, assignmentID: 88, version: 0, reason: "主理人撤销", requestID: id)
        XCTAssertEqual(applied, .applied(Adapt3Empty(), message: "角色已撤销"))
        let request = try XCTUnwrap(revoke.requests.first)
        assertJSONPost(request, path: "/api/club/roles/revoke")
        XCTAssertEqual(Set(try body(request).keys), ["clubId", "assignmentId", "version", "reason", "requestId"])
        let stale = Wire(#"{"msg":"角色状态已变化，请刷新","code":409}"#)
        let r8 = try await client(stale).replayRoleRevocation(clubID: 7, activityID: 9, assignmentID: 88, version: 0, reason: "r", requestID: id)
        XCTAssertEqual(r8, .conflict(message: "角色状态已变化，请刷新"))
        XCTAssertEqual(try body(try XCTUnwrap(stale.requests.first))["activityId"] as? Int, 9)
        XCTAssertThrowsError(try client(stale).roleRevokeRequest(clubID: 7, activityID: nil, assignmentID: 88, version: 0, reason: "  ", requestID: id))
        XCTAssertThrowsError(try client(stale).roleRevokeRequest(clubID: 7, activityID: nil, assignmentID: 88, version: -1, reason: "r", requestID: id))
    }

    func testEnvelopeAndTransportClassification() async throws {
        let id = "club-native-3F2504E0-4F89-41D3-9A0C-0305E82C3301"
        func revoke(_ wire: Wire) async throws -> Adapt3Outcome<Adapt3Empty> {
            try await client(wire).replayRoleRevocation(clubID: 7, activityID: nil, assignmentID: 88, version: 0, reason: "r", requestID: id)
        }
        let anonymous = try await revoke(Wire(#"{"msg":"请先登录","code":500}"#))
        XCTAssertEqual(anonymous, .unauthorized)
        let forbiddenCode = try await revoke(Wire(#"{"msg":"俱乐部身份无效或权限不足","code":403}"#))
        XCTAssertEqual(forbiddenCode, .forbidden)
        let http401 = try await revoke(Wire("", status: 401))
        XCTAssertEqual(http401, .unauthorized)
        let http500 = try await revoke(Wire("<html>", status: 500))
        XCTAssertEqual(http500, .unknown)
        let malformed = try await revoke(Wire("not json"))
        XCTAssertEqual(malformed, .unknown)
        let boolCode = try await revoke(Wire(#"{"msg":"x","code":true}"#))
        XCTAssertEqual(boolCode, .unknown)
        let broken = Wire(#"{"code":200}"#); broken.fail = true
        let transport = try await revoke(broken)
        XCTAssertEqual(transport, .unknown)
        let missingCode = try await revoke(Wire(#"{"msg":"角色已撤销"}"#))
        XCTAssertEqual(missingCode, .unknown)
    }
}
