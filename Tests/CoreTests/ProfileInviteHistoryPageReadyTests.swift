import XCTest
@testable import QuestifyCore

final class ProfileInviteHistoryPageReadyTests: XCTestCase {
    private typealias Page = ProfileInviteHistoryPageReady
    private let dash = "\u{2014}"

    private func member(_ id: Int) throws -> SocialInvitedMember {
        try JSONDecoder().decode(SocialInvitedMember.self, from: Data(#"{"id":\#(id),"nickname":"fixture"}"#.utf8))
    }
    private func pagination(members: Int, total: Int?, pageSize: Int = 100) throws -> SocialInvitePagination {
        var value = SocialInvitePagination()
        try value.accept(SocialInvitePage(members: (0..<members).map { try member($0 + 1) }, total: total, pageNumber: 1, pageSize: pageSize))
        return value
    }
    private func scan(_ json: String) throws -> SocialRewardScan {
        try JSONDecoder().decode(SocialRewardScan.self, from: Data(json.utf8))
    }

    func testNothingLoadedIsLoadingOrUnknownNeverEmpty() {
        XCTAssertEqual(Page.phase(loading: true, error: nil, pagination: nil, scan: nil), .loading)
        XCTAssertEqual(Page.phase(loading: false, error: nil, pagination: nil, scan: nil), .unknown)
        XCTAssertEqual(Page.phase(loading: false, error: nil, pagination: SocialInvitePagination(), scan: nil), .unknown)
    }

    func testFailureWinsAndKeepsItsKind() throws {
        XCTAssertEqual(Page.phase(loading: false, error: APIError.unauthorized, pagination: nil, scan: nil), .error(.signIn))
        XCTAssertEqual(Page.phase(loading: false, error: APIError.httpStatus(403), pagination: nil, scan: nil), .error(.denied))
        let rows = try pagination(members: 1, total: 1)
        XCTAssertEqual(Page.phase(loading: false, error: URLError(.timedOut), pagination: rows, scan: nil), .error(.failed))
    }

    func testAnAcceptedEmptyPageIsEmptyAndAKnownZeroTotalStaysZero() throws {
        let empty = try pagination(members: 0, total: 0)
        XCTAssertEqual(Page.phase(loading: false, error: nil, pagination: empty, scan: nil), .empty)
        XCTAssertEqual(Page.countText(0), "0")
    }

    func testMissingTotalIsAnEmDashNotZero() throws {
        let rows = try pagination(members: 2, total: nil, pageSize: 100)
        guard case .ready(let snapshot) = Page.phase(loading: false, error: nil, pagination: rows, scan: nil) else { return XCTFail("ready") }
        XCTAssertEqual(snapshot.totalText, dash)
        XCTAssertNotEqual(snapshot.totalText, "0")
        XCTAssertEqual(snapshot.loadedCountText, "2")
        XCTAssertFalse(snapshot.hasMore)
        XCTAssertEqual(Page.countText(nil), dash)
        XCTAssertEqual(Page.countText(-1), dash)
    }

    func testRewardCoverageDistinguishesMissingPartialAndComplete() throws {
        let rows = try pagination(members: 1, total: 1)
        func coverage(_ scan: SocialRewardScan?) -> Page.RewardCoverage? {
            guard case .ready(let snapshot) = Page.phase(loading: false, error: nil, pagination: rows, scan: scan) else { return nil }
            return snapshot.rewardCoverage
        }
        XCTAssertEqual(coverage(nil), .notSynchronized)
        XCTAssertEqual(coverage(try scan(#"{"rows":[],"total":5}"#)), .partial)
        XCTAssertEqual(coverage(try scan(#"{"rows":[],"total":null}"#)), .partial)
        XCTAssertEqual(coverage(try scan(#"{"rows":[],"total":0}"#)), .complete)
    }

    func testIdentifiersAndRoutesStayTheExistingReadOnlyPair() throws {
        XCTAssertEqual(Page.invitationsPath, "api/user/invite_list")
        XCTAssertEqual(Page.rewardsPath, "api/user/points/list")
        XCTAssertEqual(Page.identifier(for: .loading), "social.invites.loading")
        XCTAssertEqual(Page.identifier(for: .empty), "social.invites.empty")
        XCTAssertEqual(Page.identifier(for: .error(.failed)), "social.invites.error")
        XCTAssertEqual(Page.identifier(for: .unknown), "social.invites.unknown")
        let rows = try pagination(members: 1, total: 1)
        XCTAssertEqual(Page.identifier(for: Page.phase(loading: false, error: nil, pagination: rows, scan: nil)), "social.invites.ready")
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
    }
}
