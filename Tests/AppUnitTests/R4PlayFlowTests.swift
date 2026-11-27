import XCTest
import SwiftUI
@testable import Questify
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// ui/r4-play-flow: the play HUD geometry (401:4731), the 战报 stats (204:15044) and the share palette (210:10082).
@MainActor final class R4PlayFlowTests: XCTestCase {
    func testArrowTurnsInFifteenDegreeSteps() {
        XCTAssertEqual(PlayHUDGeometry.steppedRotation(bearing: 97, heading: 0), 90)
        XCTAssertEqual(PlayHUDGeometry.steppedRotation(bearing: 98, heading: 0), 105)
        XCTAssertEqual(PlayHUDGeometry.steppedRotation(bearing: 10, heading: 350), 15, "relative bearing wraps through north")
        XCTAssertEqual(PlayHUDGeometry.steppedRotation(bearing: 355, heading: 0), 0, "359° rounds to north, never 360")
    }

    func testArrowTakesTheShortWayRound() {
        XCTAssertEqual(PlayHUDGeometry.unwrapped(from: 345, to: 0), 360)
        XCTAssertEqual(PlayHUDGeometry.unwrapped(from: 15, to: 345), -15)
        XCTAssertEqual(PlayHUDGeometry.unwrapped(from: 90, to: 105), 105)
    }

    func testBearingAndDistance() {
        // Due east along the equator, then due north.
        XCTAssertEqual(PlayHUDGeometry.bearingDegrees(fromLatitude: 0, longitude: 0, toLatitude: 0, longitude: 1), 90, accuracy: 0.001)
        XCTAssertEqual(PlayHUDGeometry.bearingDegrees(fromLatitude: 31, longitude: 121, toLatitude: 32, longitude: 121), 0, accuracy: 0.001)
        let meters = PlayHUDGeometry.distanceMeters(fromLatitude: 31.2, longitude: 121.4, toLatitude: 31.2, longitude: 121.4019)
        XCTAssertEqual(meters, 180, accuracy: 3)
    }

    func testOneDistanceText() {
        XCTAssertEqual(PlayHUDGeometry.distanceText(183), "180 m")
        XCTAssertEqual(PlayHUDGeometry.distanceText(2), "10 m", "never 0 m while a stop is still ahead")
        XCTAssertEqual(PlayHUDGeometry.distanceText(998), "1.0 km")
        XCTAssertEqual(PlayHUDGeometry.distanceText(1234), "1.2 km")
        XCTAssertEqual(PlayHUDGeometry.distanceText(.nan), "—")
    }

    func testReportKeepsTheThreeMPTiles() {
        var report = JourneyReport(legacy: false, result: nil, dateLabel: nil, nodesText: "6/6", elapsedText: nil, score: nil,
                                   rank: nil, rankBasisCount: nil, penaltyText: nil, rewardItems: nil, runID: nil, topicID: nil,
                                   activityID: nil, coverURL: nil, nodes: [], finished: true, inProgress: false)
        // mp-journey r3: the MP always shows 完成节点 · 用时 · 解谜分 (report wxml:17-21); unread values render muted.
        XCTAssertEqual(JourneyReportView.stats(report).map(\.value), ["6/6", nil, nil])
        report.elapsedText = "23:10"; report.score = 120
        XCTAssertEqual(JourneyReportView.stats(report).map(\.value), ["6/6", "23:10", "120"])
    }

    func testSharePaletteHasNoMustard() {
        XCTAssertFalse(CYShareCardTint.pickable.contains(.gold))
        XCTAssertEqual(CYShareCardTint.pickable.count, CYShareCardTint.allCases.count - 1)
    }
}
