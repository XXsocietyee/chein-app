import XCTest
@testable import QuestifyCore

final class WP09ObservationReceiveTimeTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private func obs(sampled: Date, received: Date?, backfilled: Bool = false) throws -> MapCoordinateObservation {
        try MapCoordinateObservation(latitude: 31.23, longitude: 121.47, datum: .wgs84, source: .deviceLocation,
                                     accuracyMeters: 5, observedAt: sampled, receivedAt: received, isBackfilled: backfilled)
    }
    func testReceiveTimeRecordedSeparatelyFromSampleTime() throws {
        let o = try obs(sampled: t0, received: t0.addingTimeInterval(3))
        XCTAssertEqual(o.observedAt, t0)
        XCTAssertEqual(o.receivedAt, t0.addingTimeInterval(3))
        XCTAssertTrue(o.isOnlineNow(now: t0.addingTimeInterval(4), maxAge: 10))
        XCTAssertEqual(try o.projected(to: .gcj02).receivedAt, o.receivedAt)
        XCTAssertNil(try MapCoordinateObservation(latitude: 1, longitude: 1, datum: .wgs84, source: .backend).receivedAt)
    }
    func testBackfilledPointNotOnlineNow() throws {
        let flagged = try obs(sampled: t0, received: t0.addingTimeInterval(1), backfilled: true)
        XCTAssertFalse(flagged.isOnlineNow(now: t0.addingTimeInterval(2), maxAge: 10))
        // Received long after sampling: old sample, fresh receipt is still not online.
        let late = try obs(sampled: t0, received: t0.addingTimeInterval(600))
        XCTAssertFalse(late.isOnlineNow(now: t0.addingTimeInterval(601), maxAge: 10))
        let noReceive = try obs(sampled: t0, received: nil)
        XCTAssertFalse(noReceive.isOnlineNow(now: t0, maxAge: 10))
    }
}
