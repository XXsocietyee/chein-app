import XCTest
@testable import QuestifyCore

final class WP09TeleportBackfillTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private func obs(_ lat: Double, _ lng: Double, at: TimeInterval) throws -> MapCoordinateObservation {
        try MapCoordinateObservation(latitude: lat, longitude: lng, datum: .wgs84, source: .deviceLocation,
                                     accuracyMeters: 5, observedAt: t0.addingTimeInterval(at))
    }
    func testImpossibleJumpFlaggedNotAccepted() throws {
        let a = try obs(31.2304, 121.4737, at: 0)
        let far = try obs(39.9042, 116.4074, at: 10) // Shanghai -> Beijing in 10 s
        guard case .flaggedImpossibleJump = MapCoordinateJumpGuard.evaluate(previous: a, next: far) else {
            return XCTFail("teleport must be flagged")
        }
        let near = try obs(31.2310, 121.4737, at: 10)
        XCTAssertEqual(MapCoordinateJumpGuard.evaluate(previous: a, next: near), .accepted)
        let earlier = try obs(31.2304, 121.4737, at: -5)
        XCTAssertEqual(MapCoordinateJumpGuard.evaluate(previous: a, next: earlier), .flaggedNonMonotonicTime)
    }
}
