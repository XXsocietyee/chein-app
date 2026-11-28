import XCTest
#if canImport(QuestifyCore)
@testable import QuestifyCore
#elseif canImport(Core)
@testable import Core
#endif

final class ColdStartFirstFrameSplitTests: XCTestCase {

    func testMeasureKeepsCriticalPathInsideIPhone12BudgetAndStartsDeferredWorkAfterTheFrame() {
        let lanes = ColdStartFirstFrameSplit.lanes
        XCTAssertEqual(Set(lanes.map(\.lane)), Set(ColdStartLane.allCases))
        XCTAssertEqual(ColdStartFirstFrameSplit.budgetMilliseconds, 1500)

        let measured = ColdStartFirstFrameSplit.measure()
        let critical = lanes.filter { $0.phase == .critical }.reduce(0) { $0 + $1.iphone12Milliseconds }
        let deferred = lanes.filter { $0.phase == .deferred }.reduce(0) { $0 + $1.iphone12Milliseconds }
        XCTAssertEqual(measured.criticalMilliseconds, critical)
        XCTAssertEqual(measured.deferredMilliseconds, deferred)
        XCTAssertEqual(measured.frameAtMilliseconds, critical)
        XCTAssertLessThanOrEqual(measured.criticalMilliseconds, 1500)
        XCTAssertGreaterThan(measured.criticalMilliseconds + measured.deferredMilliseconds, 1500)
        XCTAssertTrue(measured.deferredAfterFrame)
        XCTAssertTrue(measured.requiredDataCritical)
        XCTAssertTrue(measured.foldedBackExceedsBudget)
        XCTAssertTrue(measured.keepsIPhone12ColdStart)
        for lane in ColdStartFirstFrameSplit.firstScreenRequired {
            XCTAssertEqual(lanes.first { $0.lane == lane }?.phase, .critical)
        }
        for (lane, start) in measured.deferredStarts {
            XCTAssertGreaterThanOrEqual(start, measured.frameAtMilliseconds, lane.rawValue)
        }
        XCTAssertEqual(weight(.notificationDelegate), 15)
        XCTAssertEqual(weight(.controlCenterRoute), 5)
        XCTAssertEqual(weight(.homeSessionGraph), 640)
        XCTAssertEqual(weight(.homeFeedRequiredReads), 180)
        XCTAssertEqual(weight(.orphanedLiveActivities), 280)
        XCTAssertEqual(weight(.planActivityObservation), 240)
        XCTAssertEqual(weight(.externalGameCatalog), 300)
        XCTAssertEqual(weight(.personalLocationMonitor), 90)
        XCTAssertEqual(weight(.nonHomeTabBodies), 700)
        XCTAssertEqual(measured.criticalMilliseconds, 840)
        XCTAssertEqual(measured.deferredMilliseconds, 1610)
    }

    func testCountingNonHomeTabsAsCriticalMissesTheIPhone12Budget() {
        let folded = ColdStartFirstFrameSplit.lanes.map { lane -> ColdStartLaneWeight in
            guard lane.lane == .nonHomeTabBodies else { return lane }
            return ColdStartLaneWeight(lane: lane.lane, phase: .critical, iphone12Milliseconds: lane.iphone12Milliseconds)
        }
        let measured = ColdStartFirstFrameSplit.measure(lanes: folded)
        XCTAssertGreaterThan(measured.criticalMilliseconds, ColdStartFirstFrameSplit.budgetMilliseconds)
        XCTAssertFalse(measured.withinBudget)
        XCTAssertFalse(measured.keepsIPhone12ColdStart)
    }

    func testZeroWeightOrCriticalPathOverBudgetIsRejected() {
        let zero = [
            ColdStartLaneWeight(lane: .homeSessionGraph, phase: .critical, iphone12Milliseconds: 0),
            ColdStartLaneWeight(lane: .homeFeedRequiredReads, phase: .critical, iphone12Milliseconds: 100),
            ColdStartLaneWeight(lane: .orphanedLiveActivities, phase: .deferred, iphone12Milliseconds: 200),
        ]
        XCTAssertFalse(ColdStartFirstFrameSplit.measure(lanes: zero).withinBudget)

        let over = ColdStartFirstFrameSplit.lanes.map { lane -> ColdStartLaneWeight in
            guard lane.lane == .homeSessionGraph else { return lane }
            return ColdStartLaneWeight(lane: lane.lane, phase: .critical, iphone12Milliseconds: 1500)
        }
        let measured = ColdStartFirstFrameSplit.measure(lanes: over)
        XCTAssertGreaterThan(measured.criticalMilliseconds, ColdStartFirstFrameSplit.budgetMilliseconds)
        XCTAssertFalse(measured.withinBudget)
        XCTAssertFalse(measured.keepsIPhone12ColdStart)
    }

    private func weight(_ lane: ColdStartLane) -> Int {
        ColdStartFirstFrameSplit.lanes.first { $0.lane == lane }?.iphone12Milliseconds ?? -1
    }
}
