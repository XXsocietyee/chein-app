import XCTest
@testable import QuestifyCore

/// Gap #24 (1128 plan R-02d): the live walk's own tiles become the fog the map draws.
final class RoamLiveFogProjectionTests: XCTestCase {
    private func record(all: [String], pending: [String]) throws -> RoamLiveRecord {
        let scope = try RoamHistoryScope(market: "cn", deployment: URL(string: "https://example.com/roam")!, accountID: 7)
        var value = RoamLiveRecord(scope: scope, clientSessionKey: String(repeating: "a", count: 32), startedAt: Date(timeIntervalSince1970: 1_700_000_000))
        value.allTiles = all; value.pendingTiles = pending
        return value
    }

    func testTheLiveRevealSwitchIsOn() {
        XCTAssertTrue(PersonalFogFeature.liveRevealEnabled)
    }

    func testNoTilesDrawNoFog() throws {
        XCTAssertNil(RoamLiveFogProjection.make(record: nil, owner: "k"))
        XCTAssertNil(RoamLiveFogProjection.make(record: try record(all: [], pending: []), owner: "k"))
    }

    func testAcknowledgedTilesAreConfirmedAndUnacknowledgedArePending() throws {
        let walked = try record(all: ["wtw3sjq", "wtw3sjr", "wtw3sjw"], pending: ["wtw3sjw"])
        let fog = try XCTUnwrap(RoamLiveFogProjection.make(record: walked, owner: "k"))
        XCTAssertEqual(fog.confirmed.count, 2)
        XCTAssertEqual(fog.pending.count, 1)
        XCTAssertTrue(fog.confirmed.contains(try FogCell(grid: .legacyRoamTile, code: "wtw3sjq")))
        XCTAssertTrue(fog.pending.contains(try FogCell(grid: .legacyRoamTile, code: "wtw3sjw")))
        // One geohash-6 block touched: 32 cells in the coverage area.
        XCTAssertEqual(fog.coverage, .known(confirmed: 2, pending: 1, areaCells: 32))
    }

    func testEveryNewCellOrAcknowledgementBumpsTheRevision() throws {
        let a = try XCTUnwrap(RoamLiveFogProjection.make(record: try record(all: ["wtw3sjq", "wtw3sjr"], pending: ["wtw3sjr"]), owner: "k"))
        let b = try XCTUnwrap(RoamLiveFogProjection.make(record: try record(all: ["wtw3sjq", "wtw3sjr"], pending: []), owner: "k"))
        let c = try XCTUnwrap(RoamLiveFogProjection.make(record: try record(all: ["wtw3sjq", "wtw3sjr", "wtw3sjw"], pending: []), owner: "k"))
        XCTAssertNotEqual(a.revision, b.revision)
        XCTAssertNotEqual(b.revision, c.revision)
    }

    func testNoIdentityReadsUnknownNeverZero() throws {
        let fog = try XCTUnwrap(RoamLiveFogProjection.make(record: try record(all: ["wtw3sjq"], pending: []), owner: nil))
        XCTAssertEqual(fog.coverage, .unknown(.noIdentity))
    }
}
