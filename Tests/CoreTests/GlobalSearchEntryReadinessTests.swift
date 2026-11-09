import XCTest
@testable import QuestifyCore

final class GlobalSearchEntryReadinessTests: XCTestCase {
    func testPlayerScopeIsTopicActivityAndClub() {
        XCTAssertEqual(GlobalSearchEntryReadiness.playerKinds, [.topic, .activity, .club])
        XCTAssertEqual(GlobalSearchKind.allCases, [.topic, .activity, .club, .merchant])
        XCTAssertFalse(GlobalSearchEntryReadiness.playerKinds.contains(.merchant))
        XCTAssertEqual(GlobalSearchEntryReadiness.unknownCount.unicodeScalars.map(\.value), [0x2014])
    }

    func testKnownZeroStaysZeroAndUnresolvedLaneIsEmDash() {
        let empty = GlobalSearchResults(rows: [])
        for kind in GlobalSearchEntryReadiness.playerKinds {
            XCTAssertEqual(GlobalSearchEntryReadiness.countText(empty, kind: kind), "0")
            XCTAssertNotEqual(GlobalSearchEntryReadiness.countText(empty, kind: kind), GlobalSearchEntryReadiness.unknownCount)
        }
        XCTAssertEqual(GlobalSearchEntryReadiness.playerTotalText(empty), "0")
        XCTAssertEqual(GlobalSearchEntryReadiness.phase(configured: true, loading: false, issueKey: nil, results: empty), .empty)

        let failed = GlobalSearchResults(rows: [], failedKinds: [.topic])
        XCTAssertEqual(failed.count(.topic), 0)
        XCTAssertEqual(GlobalSearchEntryReadiness.countText(failed, kind: .topic), "—")
        XCTAssertNotEqual(GlobalSearchEntryReadiness.countText(failed, kind: .topic), "0")
        XCTAssertEqual(GlobalSearchEntryReadiness.countText(failed, kind: .activity), "0")
        XCTAssertEqual(GlobalSearchEntryReadiness.playerTotalText(failed), "—")
        XCTAssertNotEqual(GlobalSearchEntryReadiness.playerTotalText(failed), "0")
        XCTAssertEqual(GlobalSearchEntryReadiness.phase(configured: true, loading: false, issueKey: nil, results: failed), .unknown)

        let gated = GlobalSearchResults(rows: [], gatedKinds: [.club])
        XCTAssertEqual(GlobalSearchEntryReadiness.countText(gated, kind: .club), "—")
        XCTAssertEqual(GlobalSearchEntryReadiness.playerTotalText(gated), "—")
    }

    func testRetainedRowsDoNotTurnAFailedLaneIntoAConfirmedCount() {
        let retained = GlobalSearchResults(
            rows: [GlobalSearchRow(kind: .topic, sourceID: 4, title: "外滩")],
            failedKinds: [.topic])
        XCTAssertEqual(retained.count(.topic), 1)
        XCTAssertEqual(GlobalSearchEntryReadiness.countText(retained, kind: .topic), "—")
        XCTAssertEqual(GlobalSearchEntryReadiness.playerTotalText(retained), "—")
        XCTAssertNotEqual(GlobalSearchEntryReadiness.playerTotalText(retained), "1")
        XCTAssertEqual(GlobalSearchEntryReadiness.phase(configured: true, loading: true, issueKey: nil, results: retained), .ready)
    }

    func testSuccessfulCountsSumOnlyPlayerLanes() {
        let results = GlobalSearchResults(rows: [
            GlobalSearchRow(kind: .topic, sourceID: 1, title: "路线"),
            GlobalSearchRow(kind: .topic, sourceID: 2, title: "另一条"),
            GlobalSearchRow(kind: .activity, sourceID: 3, title: "活动"),
            GlobalSearchRow(kind: .merchant, sourceID: 9, title: "Synthetic")
        ])
        XCTAssertEqual(GlobalSearchEntryReadiness.countText(results, kind: .topic), "2")
        XCTAssertEqual(GlobalSearchEntryReadiness.countText(results, kind: .activity), "1")
        XCTAssertEqual(GlobalSearchEntryReadiness.countText(results, kind: .club), "0")
        XCTAssertNil(GlobalSearchEntryReadiness.countText(results, kind: .merchant))
        XCTAssertEqual(GlobalSearchEntryReadiness.playerTotalText(results), "3")
        XCTAssertNotEqual(GlobalSearchEntryReadiness.playerTotalText(results), "4")
        XCTAssertEqual(GlobalSearchEntryReadiness.phase(configured: true, loading: false, issueKey: nil, results: results), .ready)
    }

    func testMerchantFailureDoesNotChangeASuccessfulPlayerTotal() {
        let results = GlobalSearchResults(
            rows: [GlobalSearchRow(kind: .activity, sourceID: 8, title: "活动")],
            failedKinds: [.merchant])
        XCTAssertNil(GlobalSearchEntryReadiness.countText(results, kind: .merchant))
        XCTAssertEqual(GlobalSearchEntryReadiness.countText(results, kind: .activity), "1")
        XCTAssertEqual(GlobalSearchEntryReadiness.playerTotalText(results), "1")
        XCTAssertEqual(GlobalSearchEntryReadiness.phase(configured: true, loading: false, issueKey: nil, results: results), .ready)
    }

    func testPlayerDenialsUseExistingKeysAndDoNotBecomeEmpty() {
        let failed = GlobalSearchResults(rows: [], failedKinds: [.topic, .activity, .club])
        XCTAssertEqual(GlobalSearchEntryReadiness.phase(configured: true, loading: false, issueKey: nil, results: failed),
                       .error("searchMap.allFailed"))
        let gated = GlobalSearchResults(rows: [], gatedKinds: [.topic, .activity, .club])
        XCTAssertEqual(GlobalSearchEntryReadiness.phase(configured: true, loading: false, issueKey: nil, results: gated),
                       .error("searchMap.partialSignIn"))
        let mixed = GlobalSearchResults(rows: [], failedKinds: [.topic], gatedKinds: [.activity, .club])
        XCTAssertEqual(GlobalSearchEntryReadiness.phase(configured: true, loading: false, issueKey: nil, results: mixed), .unknown)
        XCTAssertFalse(failed.showsEmptyState(for: nil, isLoading: false))
        XCTAssertTrue(GlobalSearchResults(rows: []).showsEmptyState(for: nil, isLoading: false))
    }

    func testFirstReadLoadingErrorAndIdleEntry() {
        XCTAssertEqual(GlobalSearchEntryReadiness.phase(configured: false, loading: true, issueKey: "searchMap.failed", results: nil),
                       .error("searchMap.notConfigured"))
        XCTAssertEqual(GlobalSearchEntryReadiness.phase(configured: true, loading: true, issueKey: "searchMap.failed", results: nil),
                       .loading)
        XCTAssertEqual(GlobalSearchEntryReadiness.phase(configured: true, loading: false, issueKey: " searchMap.failed ", results: nil),
                       .error("searchMap.failed"))
        XCTAssertEqual(GlobalSearchEntryReadiness.phase(configured: true, loading: false, issueKey: "  ", results: nil), .ready)
        let snapshot = GlobalSearchResults(rows: [])
        XCTAssertEqual(GlobalSearchEntryReadiness.phase(configured: false, loading: false, issueKey: nil, results: snapshot),
                       .error("searchMap.notConfigured"))
    }

    func testUnreadCategoryDirectoryIsUnknownNotZero() {
        XCTAssertEqual(GlobalSearchEntryReadiness.categoryPhase(loading: true, failed: false, loaded: false, count: 0), .loading)
        XCTAssertEqual(GlobalSearchEntryReadiness.categoryCountText(loading: true, failed: false, loaded: false, count: 0), "—")
        XCTAssertEqual(GlobalSearchEntryReadiness.categoryPhase(loading: false, failed: true, loaded: false, count: 0),
                       .error("searchMap.categoryFailed"))
        XCTAssertEqual(GlobalSearchEntryReadiness.categoryCountText(loading: false, failed: true, loaded: true, count: 4), "—")
        XCTAssertEqual(GlobalSearchEntryReadiness.categoryPhase(loading: false, failed: false, loaded: true, count: 0), .empty)
        XCTAssertEqual(GlobalSearchEntryReadiness.categoryCountText(loading: false, failed: false, loaded: true, count: 0), "0")
        XCTAssertEqual(GlobalSearchEntryReadiness.categoryPhase(loading: false, failed: false, loaded: true, count: 3), .ready)
        XCTAssertEqual(GlobalSearchEntryReadiness.categoryCountText(loading: false, failed: false, loaded: true, count: 3), "3")
        XCTAssertEqual(GlobalSearchEntryReadiness.categoryPhase(loading: false, failed: false, loaded: false, count: 0), .unknown)
        XCTAssertEqual(GlobalSearchEntryReadiness.categoryCountText(loading: false, failed: false, loaded: false, count: 0), "—")
        XCTAssertNotEqual(GlobalSearchEntryReadiness.categoryCountText(loading: false, failed: false, loaded: false, count: 0), "0")
        XCTAssertEqual(GlobalSearchEntryReadiness.categoryPhase(loading: false, failed: false, loaded: true, count: -1), .unknown)
        XCTAssertEqual(GlobalSearchEntryReadiness.categoryCountText(loading: false, failed: false, loaded: true, count: -1), "—")
    }
}
