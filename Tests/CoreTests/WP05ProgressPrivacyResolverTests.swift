import XCTest
@testable import QuestifyCore

final class WP05ProgressPrivacyResolverTests: XCTestCase {
    typealias R = NativeChannelProgressPrivacyResolver
    private func values(agg: NativeChannelProgressScope = .channel, detail: NativeChannelProgressScope = .channel,
                        photo: NativeChannelProgressPhotoScope = .onlyMe,
                        board: NativeChannelProgressLeaderboardScope = .included) throws -> NativeChannelProgressPrivacyValues {
        try .init(aggregateScope: agg, detailScope: detail, photoScope: photo, leaderboardScope: board)
    }
    private func channel(agg: NativeChannelProgressScope = .publicAccess, detail: NativeChannelProgressScope = .channel,
                         photo: NativeChannelProgressPhotoScope = .team,
                         board: NativeChannelProgressLeaderboardScope = .included) -> R.ChannelPermission {
        .init(aggregateCeiling: agg, detailCeiling: detail, photoCeiling: photo, leaderboard: board)
    }

    func testStrictestScopeWinsAggregate() throws {
        XCTAssertEqual(R.resolve(preference: try values(agg: .publicAccess), channel: channel(agg: .team)).aggregateScope, .team)
        XCTAssertEqual(R.resolve(preference: try values(agg: .onlyMe), channel: channel(agg: .publicAccess)).aggregateScope, .onlyMe)
    }
    func testStrictestScopeWinsDetail() throws {
        XCTAssertEqual(R.resolve(preference: try values(detail: .channel), channel: channel(detail: .team)).detailScope, .team)
        XCTAssertEqual(R.resolve(preference: try values(detail: .onlyMe), channel: channel(detail: .channel)).detailScope, .onlyMe)
        // Detail is never wider than aggregate.
        XCTAssertEqual(R.resolve(preference: try values(agg: .team, detail: .channel), channel: channel()).detailScope, .team)
    }
    func testTeammatePhotoDefaultsClosed() throws {
        XCTAssertEqual(R.defaultPhotoScope, .onlyMe)
        let defaulted = R.resolve(preference: try values(photo: R.defaultPhotoScope), channel: channel(photo: .team))
        XCTAssertFalse(R.teammateCanSeePhotos(defaulted))
        // Channel keeps photos closed even if the user opts in.
        let closed = R.resolve(preference: try values(photo: .team), channel: channel(photo: .onlyMe))
        XCTAssertEqual(closed.photoScope, .onlyMe)
        XCTAssertFalse(R.teammateCanSeePhotos(closed))
        let open = R.resolve(preference: try values(photo: .team), channel: channel(photo: .team))
        XCTAssertTrue(R.teammateCanSeePhotos(open))
    }
    func testPhotoOriginalNeverWiderThanDetail() throws {
        for photo in NativeChannelProgressPhotoScope.allCases {
            let r = R.resolve(preference: try values(detail: .onlyMe, photo: photo), channel: channel(photo: .admin))
            XCTAssertEqual(r.photoScope, .onlyMe)
            XCTAssertFalse(R.teammateCanSeePhotos(r))
        }
    }
    func testAuditProjectionNotMergedIntoUserScopes() throws {
        let labels = Mirror(reflecting: R.resolve(preference: try values(), channel: channel())).children.compactMap { $0.label?.lowercased() }
        XCTAssertFalse(labels.contains { $0.contains("audit") })
        let raw = (NativeChannelProgressScope.allCases.map(\.rawValue) + NativeChannelProgressPhotoScope.allCases.map(\.rawValue)).map { $0.lowercased() }
        XCTAssertFalse(raw.contains { $0.contains("audit") })
        let permLabels = Mirror(reflecting: channel()).children.compactMap { $0.label?.lowercased() }
        XCTAssertFalse(permLabels.contains { $0.contains("audit") })
    }
    func testLeaderboardOutOverridesChannelIn() throws {
        XCTAssertEqual(R.resolve(preference: try values(board: .out), channel: channel(board: .included)).leaderboardScope, .out)
        XCTAssertEqual(R.resolve(preference: try values(board: .included), channel: channel(board: .out)).leaderboardScope, .out)
        XCTAssertEqual(R.resolve(preference: try values(board: .included), channel: channel(board: .included)).leaderboardScope, .included)
    }
}
