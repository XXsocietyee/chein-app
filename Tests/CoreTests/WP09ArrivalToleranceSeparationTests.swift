import XCTest
@testable import QuestifyCore

final class WP09ArrivalToleranceSeparationTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    func testNavigationToleranceDoesNotCountAsAuthoritativeArrival() {
        let node = ChallengePOINode(id: 1, name: "n", latitude: 31.2304, longitude: 121.4737, radiusM: 100)
        // ~0.001 deg lat ≈ 111 m: outside 100 m radius, inside 130 m tolerance.
        let lat = 31.2304 + 0.00115
        XCTAssertTrue(ChallengePOIRules.checkArrival(node: node, userLatitude: lat, userLongitude: 121.4737).withinRange)
        guard case .withinNavigationTolerance = ChallengePOIRules.assessArrival(node: node, userLatitude: lat, userLongitude: 121.4737) else {
            return XCTFail("tolerance band must not be authoritative arrival")
        }
        guard case .authoritativeArrival = ChallengePOIRules.assessArrival(node: node, userLatitude: 31.2304, userLongitude: 121.4737) else {
            return XCTFail("inside radius is arrival")
        }
        guard case .outOfRange = ChallengePOIRules.assessArrival(node: node, userLatitude: 31.2404, userLongitude: 121.4737) else {
            return XCTFail("far is out of range")
        }
    }
    func testInterpolatedPointsAddNoMileage() throws {
        func o(_ lat: Double, _ s: TimeInterval) throws -> MapCoordinateObservation {
            try MapCoordinateObservation(latitude: lat, longitude: 121.4737, datum: .wgs84, source: .deviceLocation,
                                         accuracyMeters: 5, observedAt: t0.addingTimeInterval(s))
        }
        var acc = RoamMileageAccumulator()
        acc.add(.measured(try o(31.2300, 0)))
        acc.add(.interpolated(try o(31.2305, 30)))
        XCTAssertEqual(acc.totalMeters, 0)
        acc.add(.measured(try o(31.2310, 60)))
        let expected = RoamExperienceMath.distanceMeters(try o(31.2300, 0).roamCoordinate, try o(31.2310, 60).roamCoordinate)
        XCTAssertEqual(acc.totalMeters, expected, accuracy: 0.01)
    }
}
