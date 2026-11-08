import XCTest
@testable import QuestifyCore

@MainActor final class WP03PowerOfflinePolicyTests: XCTestCase {
    func testLowPowerReducesFixCadenceButKeepsCheckpoint() async throws {
        let rig = try WP03Rig(); await rig.model.start()
        let normal = rig.model.updateInterval
        rig.model.setPowerCondition(lowPower: true, offline: false)
        XCTAssertGreaterThan(rig.model.updateInterval, normal)
        XCTAssertEqual(rig.model.phase, .navigating)
        XCTAssertNotNil(rig.model.route)
        XCTAssertEqual(rig.model.checkpoint, .init(reference: rig.reference, ownerNamespace: "wp03-owner"))
        let policy = WalkingNavigationPowerPolicy()
        XCTAssertEqual(policy.fixInterval(.init(lowPower: false, offline: false)), 3)
        XCTAssertTrue(policy.keepsCheckpoint(.init(lowPower: true, offline: true)))
        // Accuracy is never traded for power: a weak fix still fails.
        rig.location.fix = try .init(coordinate: .init(latitude: 1, longitude: 1)!, accuracyMeters: 200, measuredAt: rig.wall, datum: .wgs84)
        await rig.model.update()
        XCTAssertEqual(rig.model.phase, .failed(.weakGPS))
    }
    func testOfflineKeepsCachedRouteAndShowsWeakState() async throws {
        let rig = try WP03Rig(); await rig.model.start()
        XCTAssertFalse(rig.model.showsWeakState)
        rig.model.setPowerCondition(lowPower: false, offline: true)
        XCTAssertTrue(rig.model.showsWeakState)
        // Walk off the route three times: offline must not replan or drop the cached route.
        rig.location.fix = try .init(coordinate: .init(latitude: 1.01, longitude: 1.0)!, accuracyMeters: 5, measuredAt: rig.wall, datum: .wgs84)
        for _ in 0..<4 { await rig.model.update() }
        XCTAssertNotNil(rig.model.route)
        XCTAssertEqual(rig.model.phase, .navigating)
        XCTAssertEqual(rig.planner.calls, 1)
        XCTAssertEqual(rig.model.replanCount, 0)
        rig.model.setPowerCondition(lowPower: false, offline: false)
        XCTAssertFalse(rig.model.showsWeakState)
    }
    func testRestartRestoresCheckpointUnderLowPower() async throws {
        let first = try WP03Rig(); await first.model.start()
        let checkpoint = try XCTUnwrap(first.model.checkpoint)
        let restored = try WP03Rig()
        restored.model.setPowerCondition(lowPower: true, offline: false)
        XCTAssertEqual(checkpoint.reference, restored.reference)
        XCTAssertEqual(restored.targets.calls, 0)      // nothing resumes until explicit start
        await restored.model.start()                   // re-authorizes and obtains a new route
        XCTAssertEqual(restored.targets.calls, 1)
        XCTAssertEqual(restored.model.phase, .navigating)
        XCTAssertEqual(restored.model.checkpoint, checkpoint)
        XCTAssertEqual(restored.model.updateInterval, 10)
    }
}
