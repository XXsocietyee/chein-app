import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

/// Main action of pages/club/badges/index: owner selects a badge, selects a member, confirms, and the
/// grant is sent exactly once. Synthetic transport only; reuses the approved fixture of
/// ClubBadgeOriginalConsumerRecoveryTests and never contacts a server.
@MainActor final class ClubBadgeGrantFlowTests: XCTestCase {
    private final class Wire: HTTPTransport {
        var handler: (URLRequest) throws -> (Data, Int) = { _ in (Data(), 503) }
        var requests: [URLRequest] = []
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return try handler(request)
        }
        func count(suffix: String) -> Int { requests.filter { $0.url?.path.hasSuffix(suffix) == true }.count }
    }

    @MainActor private final class Scenario {
        let source: ClubBadgeOriginalConsumerRecoveryTests.Fixture
        let wire = Wire()
        var owner = true
        var grantStatus = 200
        lazy var service = ClubBadgeManagementService(context: source.context, clubID: 7, transport: wire,
            current: { self.source.current }, approval: { _ in self.source.approval })
        lazy var flow = ClubBadgeManagementFlow(service: service, journal: source.journal)
        init() throws {
            source = try ClubBadgeOriginalConsumerRecoveryTests.Fixture()
            wire.handler = { [unowned self] request in
                let path = request.url?.path ?? ""
                if path.hasSuffix("api/club/detail") {
                    return (try self.source.envelope(data: ["id": 7, "isOwner": self.owner]), 200)
                }
                if path.hasSuffix("api/club/badge/list") {
                    let body: [String: Any] = ["code": 200, "data": [["badgeCode": "CLUB7_1", "badgeName": "Trail", "clubId": 7]]]
                    return (try JSONSerialization.data(withJSONObject: body), 200)
                }
                if path.hasSuffix("api/club/members") {
                    let body: [String: Any] = ["code": 200, "data": [["memberId": 42, "nickname": "Ada", "role": 0, "isOwner": false]]]
                    return (try JSONSerialization.data(withJSONObject: body), 200)
                }
                if path.hasSuffix("api/club/badge/grant") {
                    if self.grantStatus != 200 { return (Data(), self.grantStatus) }
                    guard let pending = try self.source.journal.read(self.source.context, clubID: 7).first(where: { $0.outcome == "UNKNOWN" }) else {
                        throw ClubBadgeManagementFailure.invalid
                    }
                    let receipt: [String: Any] = [
                        "protocolVersion": 1, "clubId": 7, "actorMemberId": self.source.context.session.accountID,
                        "requestId": pending.requestID, "operation": "GRANT", "sourceSHA256": pending.sourceSHA256,
                        "state": "GRANTED", "badgeId": 11, "badgeCode": "CLUB7_1", "memberId": 42,
                        "appliedAt": 1_800_000_000_000 as Int64, "auditId": 15
                    ]
                    return (try self.source.envelope(data: receipt), 200)
                }
                throw ClubBadgeManagementFailure.invalid
            }
        }
    }

    func testOwnerGrantSendsExactBodyOnceOnlyAfterSecondConfirmation() async throws {
        let s = try Scenario()
        await s.flow.refresh()
        XCTAssertTrue(s.flow.isOwner)
        XCTAssertTrue(s.flow.canGrant)
        let badge = try XCTUnwrap(s.flow.badges.first)
        await s.flow.openGrant(badge)
        let member = try XCTUnwrap(s.flow.members.first)
        s.flow.selectMember(member)
        let review = try XCTUnwrap(s.flow.review)
        XCTAssertEqual(s.wire.count(suffix: "api/club/badge/grant"), 0, "Selecting a member must not send")
        await s.flow.confirmGrant(review)
        XCTAssertEqual(s.wire.count(suffix: "api/club/badge/grant"), 1)
        let grant = try XCTUnwrap(s.wire.requests.first(where: { $0.url?.path.hasSuffix("api/club/badge/grant") == true }))
        XCTAssertEqual(grant.httpMethod, "POST")
        XCTAssertNotNil(grant.value(forHTTPHeaderField: ClubBadgeManagementRoute.requestHeader))
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(grant.httpBody)) as? [String: Any])
        XCTAssertEqual(body["clubId"] as? Int, 7)
        XCTAssertEqual(body["memberId"] as? Int, 42)
        XCTAssertEqual(body["badgeCode"] as? String, "CLUB7_1")
        XCTAssertEqual(Set(body.keys), ["clubId", "memberId", "badgeCode"])
        guard case .confirmed(let receipt) = s.flow.resultPresentation else { return XCTFail("Success is shown only after the server receipt") }
        XCTAssertEqual(receipt.state, "GRANTED")
        XCTAssertEqual(receipt.memberId, 42)
    }

    func testNonOwnerCannotOpenGrantOrSend() async throws {
        let s = try Scenario()
        s.owner = false
        await s.flow.refresh()
        XCTAssertFalse(s.flow.isOwner)
        XCTAssertFalse(s.flow.canGrant)
        if let badge = s.flow.badges.first { await s.flow.openGrant(badge) }
        XCTAssertFalse(s.flow.pickerOpen)
        XCTAssertNil(s.flow.review)
        XCTAssertEqual(s.wire.count(suffix: "api/club/badge/grant"), 0)
    }

    func testOwnershipLostBeforeConfirmationNeverSendsGrant() async throws {
        let s = try Scenario()
        await s.flow.refresh()
        let badge = try XCTUnwrap(s.flow.badges.first)
        await s.flow.openGrant(badge)
        s.flow.selectMember(try XCTUnwrap(s.flow.members.first))
        let review = try XCTUnwrap(s.flow.review)
        s.owner = false
        await s.flow.confirmGrant(review)
        XCTAssertEqual(s.wire.count(suffix: "api/club/badge/grant"), 0)
        XCTAssertNil(s.flow.review)
        XCTAssertNotNil(s.flow.operationMessage)
        if case .confirmed = s.flow.resultPresentation { XCTFail("No success without a grant") }
    }

    func testServerFailureIsNeverShownAsSuccessAndIsNotRetried() async throws {
        let s = try Scenario()
        s.grantStatus = 503
        await s.flow.refresh()
        let badge = try XCTUnwrap(s.flow.badges.first)
        await s.flow.openGrant(badge)
        s.flow.selectMember(try XCTUnwrap(s.flow.members.first))
        let review = try XCTUnwrap(s.flow.review)
        await s.flow.confirmGrant(review)
        XCTAssertEqual(s.wire.count(suffix: "api/club/badge/grant"), 1)
        if case .confirmed = s.flow.resultPresentation { XCTFail("HTTP 503 must not confirm a grant") }
        XCTAssertFalse(s.flow.canGrant, "An unresolved original request blocks further grants")
    }
}
