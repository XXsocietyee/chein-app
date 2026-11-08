#if canImport(QuestifyCore)
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

/// Screen states of pages/club/badges/index driven through a fake transport:
/// loading/empty/error/ready, owner-only notice for non-owners, member picker states.
@MainActor final class ClubBadgeScreenStateTests: XCTestCase {
    private final class Wire: HTTPTransport {
        var handler: (URLRequest) throws -> (Data, Int) = { _ in (Data(), 503) }
        var requests: [URLRequest] = []
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return try handler(request)
        }
    }

    @MainActor private final class Scenario {
        let source: ClubBadgeOriginalConsumerRecoveryTests.Fixture
        let wire = Wire()
        var owner = true
        var badgesStatus = 200
        var badgeRows: [[String: Any]] = [["badgeCode": "CLUB7_1", "badgeName": "Trail", "clubId": 7]]
        var memberStatus = 200
        var memberRows: [[String: Any]] = [["memberId": 42, "nickname": "Ada", "role": 0, "isOwner": false]]
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
                    if self.badgesStatus != 200 { return (Data(), self.badgesStatus) }
                    let body: [String: Any] = ["code": 200, "data": self.badgeRows]
                    return (try JSONSerialization.data(withJSONObject: body), 200)
                }
                if path.hasSuffix("api/club/members") {
                    if self.memberStatus != 200 { return (Data(), self.memberStatus) }
                    let body: [String: Any] = ["code": 200, "data": self.memberRows]
                    return (try JSONSerialization.data(withJSONObject: body), 200)
                }
                throw ClubBadgeManagementFailure.invalid
            }
        }
    }

    func testEmptyListShowsEmptyStateAndOwnerKeepsCreate() async throws {
        let s = try Scenario()
        s.badgeRows = []
        await s.flow.refresh()
        XCTAssertEqual(s.flow.screenState, .empty)
        XCTAssertTrue(s.flow.isOwner)
        XCTAssertTrue(s.flow.canCreate)
        XCTAssertFalse(s.flow.showsOwnerOnlyNotice)
    }

    func testNonOwnerSeesReadOnlyListWithOwnerOnlyNotice() async throws {
        let s = try Scenario()
        s.owner = false
        await s.flow.refresh()
        XCTAssertEqual(s.flow.screenState, .ready)
        XCTAssertEqual(s.flow.badges.count, 1)
        XCTAssertTrue(s.flow.showsOwnerOnlyNotice)
        XCTAssertFalse(s.flow.canCreate)
        XCTAssertFalse(s.flow.canGrant)
    }

    func testFirstLoadFailureIsErrorStateAndRetryRecovers() async throws {
        let s = try Scenario()
        s.badgesStatus = 503
        await s.flow.refresh()
        XCTAssertEqual(s.flow.screenState, .error)
        s.badgesStatus = 200
        await s.flow.refresh()
        XCTAssertEqual(s.flow.screenState, .ready)
    }

    func testUnconfiguredReadIsHonestNotAvailable() async throws {
        let s = try Scenario()
        s.source.approval = nil
        XCTAssertEqual(s.flow.screenState, .notAvailable)
    }

    func testMemberPickerErrorRetryThenReady() async throws {
        let s = try Scenario()
        await s.flow.refresh()
        XCTAssertEqual(s.flow.memberPickerState, .closed)
        s.memberStatus = 503
        await s.flow.openGrant(try XCTUnwrap(s.flow.badges.first))
        XCTAssertEqual(s.flow.memberPickerState, .error)
        s.memberStatus = 200
        await s.flow.retryMembers()
        XCTAssertEqual(s.flow.memberPickerState, .ready)
        XCTAssertEqual(s.flow.members.count, 1)
    }

    func testMemberPickerEmptyRoster() async throws {
        let s = try Scenario()
        s.memberRows = []
        await s.flow.refresh()
        await s.flow.openGrant(try XCTUnwrap(s.flow.badges.first))
        XCTAssertEqual(s.flow.memberPickerState, .empty)
    }
}
#endif
