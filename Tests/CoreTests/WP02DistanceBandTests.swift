import XCTest
@testable import QuestifyCore

@MainActor final class WP02DistanceBandTests: XCTestCase {
    /// Latitude degrees per metre on the equator, good enough to place fixtures.
    private func lat(_ meters: Double) -> Double { meters / 111_195 }
    private func visible(_ placements: [(id: Int, lat: Double, lon: Double, stale: Bool)]) throws -> PersonalLocationShareReceiverProjection {
        var projection = PersonalLocationShareReceiverProjection(recipientId: 1)
        var entries: [PersonalLocationShareSnapshot.Entry] = []
        for p in placements {
            let gid = WP02Fixture.uuid(p.id)
            let grant = WP02Fixture.grant(key: WP02Fixture.uuid(p.id + 1000), grantId: gid, owner: Int64(100 + p.id), recipient: 1)
            let obs = PersonalLocationShareObservation(grantId: gid, ownerId: grant.ownerId, recipientId: 1, sequence: 1,
                observedAtMs: WP02Fixture.now, datum: "WGS84", mode: .exact, latitude: p.lat, longitude: p.lon,
                stale: p.stale, version: 1, watermark: 1)
            entries.append(.init(grant: grant, observation: obs))
        }
        let snapshot = PersonalLocationShareSnapshot(recipientId: 1, serverNowMs: WP02Fixture.now, cursor: 1,
            displayLeaseUntilMs: WP02Fixture.now + 40_000, refreshAfterMs: 20_000, staleAfterMs: 30_000,
            policyId: "TEST_ONLY", policyVersion: 1, policyDigest: WP02Fixture.digest, entries: entries)
        let ticket = projection.beginRead()
        XCTAssertTrue(try projection.apply(snapshot, ticket: ticket, uptime: 100))
        return projection
    }
    func testDistanceRoundsToBandNeverExact() throws {
        let projection = try visible([(1, lat(300), 0, false), (2, lat(450), 0, false), (3, lat(700), 0, false),
                                      (4, lat(2_000), 0, false), (5, lat(10_000), 0, false)])
        let banded = projection.bandedDistances(observerLatitude: 0, observerLongitude: 0, uptime: 100)
        let byId = Dictionary(uniqueKeysWithValues: banded.map { ($0.grantId, $0.band) })
        XCTAssertEqual(byId[WP02Fixture.uuid(1)], .under500m)
        XCTAssertEqual(byId[WP02Fixture.uuid(2)], .under500m, "300 m and 450 m are indistinguishable")
        XCTAssertEqual(byId[WP02Fixture.uuid(3)], .under1km)
        XCTAssertEqual(byId[WP02Fixture.uuid(4)], .under3km)
        XCTAssertEqual(byId[WP02Fixture.uuid(5)], .beyond3km)
        XCTAssertNil(PersonalLocationShareDistanceBanding.band(observerLatitude: .nan, observerLongitude: 0, latitude: 0, longitude: 0))
    }
    func testBandOutputNeverContainsCoordinatesOrRawMeters() throws {
        let projection = try visible([(1, 0.0031234567, 0.0042345678, false)])
        let banded = try XCTUnwrap(projection.bandedDistances(observerLatitude: 0, observerLongitude: 0, uptime: 100).first)
        for child in Mirror(reflecting: banded).children {
            XCTAssertFalse(child.value is Double || child.value is Float, "\(child.label ?? "?") must not be a number with fractions")
        }
        XCTAssertEqual(Set(Mirror(reflecting: banded).children.compactMap(\.label)), ["grantId", "band", "stale"])
        let text = String(describing: banded) + String(reflecting: banded)
        for forbidden in ["0.0031", "0.0042", "3123", "4234", "latitude", "longitude", "meters"] {
            XCTAssertFalse(text.contains(forbidden), forbidden)
        }
    }
    func testNearbySortTrailCountErrorFieldsDoNotLeakExactDistance() throws {
        // Sort: same band orders by id, never by the hidden exact distance (id 2 is nearer than id 1).
        let near = try visible([(1, lat(400), 0, false), (2, lat(100), 0, false), (3, lat(5_000), 0, false)])
        let order = near.bandedDistances(observerLatitude: 0, observerLongitude: 0, uptime: 100).map(\.grantId)
        XCTAssertEqual(order, [WP02Fixture.uuid(1), WP02Fixture.uuid(2), WP02Fixture.uuid(3)])
        // Trail: moving inside one band yields an identical presentation, so a history reveals nothing finer.
        let a = try visible([(1, lat(120), 0, false)]).bandedDistances(observerLatitude: 0, observerLongitude: 0, uptime: 100)
        let b = try visible([(1, lat(480), 0, false)]).bandedDistances(observerLatitude: 0, observerLongitude: 0, uptime: 100)
        XCTAssertEqual(a, b)
        // Count: exactly one entry per visible grant, none for an unusable observer position.
        XCTAssertEqual(near.bandedDistances(observerLatitude: 0, observerLongitude: 0, uptime: 100).count, 3)
        XCTAssertTrue(near.bandedDistances(observerLatitude: .infinity, observerLongitude: 0, uptime: 100).isEmpty)
        XCTAssertTrue(near.bandedDistances(observerLatitude: 95, observerLongitude: 0, uptime: 100).isEmpty)
        // Stale entries keep the band but the flag follows the existing lease rules; expired ones vanish.
        let stale = try visible([(1, lat(100), 0, true)])
        XCTAssertEqual(stale.bandedDistances(observerLatitude: 0, observerLongitude: 0, uptime: 100).first?.stale, true)
        XCTAssertTrue(stale.bandedDistances(observerLatitude: 0, observerLongitude: 0, uptime: 100_000).isEmpty)
    }
}
