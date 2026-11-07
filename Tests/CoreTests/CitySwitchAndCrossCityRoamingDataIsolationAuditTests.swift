import XCTest
@testable import QuestifyCore

final class CitySwitchAndCrossCityRoamingDataIsolationAuditTests: XCTestCase {
    func testCanonicalSurfacesPassCrossCityDataIsolationEvaluation() {
        let result = CitySwitchAndCrossCityRoamingDataIsolationAudit.evaluate()
        XCTAssertEqual(result.totalSurfaces, 4)
        XCTAssertEqual(result.compliantSurfaces, 4)
        XCTAssertTrue(result.isCityIsolationReady)
        XCTAssertEqual(
            CitySwitchAndCrossCityRoamingDataIsolationAudit.canonicalSurfaces.map(\.surfaceName),
            [
                "roam-map-poi-and-route-pins",
                "personal-fog-tile-overlay-store",
                "city-growth-leaderboard-standings",
                "home-city-featured-projects-feed"
            ]
        )
    }

    func testCrossCityCacheBleedWithoutCityCodeAndAccountKeyFailsCompliance() {
        var surfaces = CitySwitchAndCrossCityRoamingDataIsolationAudit.canonicalSurfaces
        surfaces[1] = CityPartitionIsolationCheck(
            id: "personal-fog-tile-overlay-store",
            surfaceName: "personal-fog-tile-overlay-store",
            keysCacheByCityCodeAndAccount: false,
            cancelsInFlightRequestsOnCitySwitch: true,
            resetsMapViewportDeltaCleanly: true
        )
        XCTAssertFalse(surfaces[1].isCompliant)

        let result = CitySwitchAndCrossCityRoamingDataIsolationAudit.evaluate(surfaces: surfaces)
        XCTAssertEqual(result.totalSurfaces, 4)
        XCTAssertEqual(result.compliantSurfaces, 3)
        XCTAssertFalse(result.isCityIsolationReady)
    }

    func testUncancelledInFlightRequestsOnCitySwitchFailsCompliance() {
        var surfaces = CitySwitchAndCrossCityRoamingDataIsolationAudit.canonicalSurfaces
        surfaces[2] = CityPartitionIsolationCheck(
            id: "city-growth-leaderboard-standings",
            surfaceName: "city-growth-leaderboard-standings",
            keysCacheByCityCodeAndAccount: true,
            cancelsInFlightRequestsOnCitySwitch: false,
            resetsMapViewportDeltaCleanly: true
        )
        XCTAssertFalse(surfaces[2].isCompliant)

        let result = CitySwitchAndCrossCityRoamingDataIsolationAudit.evaluate(surfaces: surfaces)
        XCTAssertEqual(result.compliantSurfaces, 3)
        XCTAssertFalse(result.isCityIsolationReady)
    }

    func testMissingMapViewportDeltaResetOnCitySwitchFailsCompliance() {
        var surfaces = CitySwitchAndCrossCityRoamingDataIsolationAudit.canonicalSurfaces
        surfaces[0] = CityPartitionIsolationCheck(
            id: "roam-map-poi-and-route-pins",
            surfaceName: "roam-map-poi-and-route-pins",
            keysCacheByCityCodeAndAccount: true,
            cancelsInFlightRequestsOnCitySwitch: true,
            resetsMapViewportDeltaCleanly: false
        )
        XCTAssertFalse(surfaces[0].isCompliant)

        let result = CitySwitchAndCrossCityRoamingDataIsolationAudit.evaluate(surfaces: surfaces)
        XCTAssertEqual(result.compliantSurfaces, 3)
        XCTAssertFalse(result.isCityIsolationReady)
    }

    func testW5CitySimulationLoopBudgetDeltaAndRecoveryRules() {
        let state = CitySimulationLoopState(
            cityCode: "310100",
            snapshotVersion: 10,
            actionsRemaining: 2,
            actionsPerRound: 3,
            activeHoldCount: 1,
            holdingLimit: 3,
            memberPointsFee: 15,
            fairnessCohortState: .counted
        )
        XCTAssertTrue(state.canExecuteNodeAction(category: .neutral, status: .available, hasVerifiedArrivalEvidence: false))
        XCTAssertFalse(state.canExecuteNodeAction(category: .operable, status: .available, hasVerifiedArrivalEvidence: false))
        XCTAssertTrue(state.canExecuteNodeAction(category: .operable, status: .available, hasVerifiedArrivalEvidence: true))
        XCTAssertFalse(state.canExecuteNodeAction(category: .neutral, status: .protected, hasVerifiedArrivalEvidence: true))

        let applied = state.applyingDelta(fromVersion: 10, toVersion: 11, actionsDelta: -1, holdsDelta: 1)
        XCTAssertEqual(applied.snapshotVersion, 11)
        XCTAssertEqual(applied.actionsRemaining, 1)
        XCTAssertEqual(applied.activeHoldCount, 2)
        XCTAssertEqual(applied.phase, .deltaStreamApplied)

        let gapped = applied.applyingDelta(fromVersion: 13, toVersion: 14)
        XCTAssertEqual(gapped.phase, .gapReloadRequired)

        let conflictKept = applied.resolvingMutationOutcome(
            isVersionConflict: true,
            taskAttemptKept: true,
            recoveredByIdempotentRequestID: false
        )
        XCTAssertTrue(conflictKept.taskAttemptKeptOnConflict)
        XCTAssertEqual(conflictKept.phase, .versionConflictAttemptKept)

        let recovered = applied.resolvingMutationOutcome(
            isVersionConflict: false,
            taskAttemptKept: false,
            recoveredByIdempotentRequestID: true
        )
        XCTAssertEqual(recovered.phase, .offlineRecoveryReconciled)
        XCTAssertEqual(recovered.actionsRemaining, 0)
    }
}
