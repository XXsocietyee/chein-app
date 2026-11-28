import XCTest
@testable import QuestifyCore

/// mp-journey r3: 旅程手记 rows follow MP pages/play/index.js `buildJournal` (city run, linear route).
final class PlayJournalTests: XCTestCase {
    func testCityRunKeysStationsInOrderAndHidesTheRoadAhead() throws {
        let nodes = #"[{"nodeId":3,"sortId":3,"name":"C","done":false,"description":"Third\nmore"},{"nodeId":1,"sortId":1,"name":"A","done":true,"description":"First line"},{"nodeId":2,"sortId":2,"name":"B","done":false,"description":"Second"},{"nodeId":4,"sortId":4,"name":"D","done":false,"description":"Fourth"}]"#
        let rows = PlayJournal.rows(in: try snapshot(mode: 1, nodes: nodes))
        XCTAssertEqual(rows.map(\.id), [1, 2, 3, 4])
        XCTAssertEqual(rows.map(\.key), [.station(1), .now, .ahead, .ahead])
        XCTAssertEqual(rows[0].excerpt, "First line")
        XCTAssertTrue(rows[0].opensStory)
        XCTAssertEqual(rows[2].excerpt, "Third")
        XCTAssertFalse(rows[2].redacted)
        XCTAssertFalse(rows[2].opensStory)
        XCTAssertNil(rows[3].excerpt)
        XCTAssertTrue(rows[3].redacted)
        XCTAssertNil(rows[3].story)
    }

    func testFreeExplorationListsFinishedFirstAndUnvisitedByNameOnly() throws {
        let nodes = #"[{"nodeId":1,"name":"A","done":false,"description":"a"},{"nodeId":2,"name":"B","done":true,"description":"b"},{"nodeId":3,"name":"C","done":false,"description":"c"}]"#
        let rows = PlayJournal.rows(in: try snapshot(mode: 2, nodes: nodes))
        XCTAssertEqual(rows.map(\.id), [2, 1, 3])
        XCTAssertEqual(rows.map(\.key), [.step(1), .now, .notYet])
        XCTAssertNil(rows[2].excerpt)
    }

    /// mp-journey-b r3: MP `orderedJourneyNodes` / `resolveNextRouteNode` for a BRANCH_GRAPH run — finished stations in
    /// decision-log order as 我的第 K 步, then the recommended PLAYABLE station (此刻), then the rest; hidden stations stay out.
    func testBranchRouteFollowsTheDecisionLogNotStationOrder() throws {
        let nodes = #"[{"nodeId":1,"sortId":1,"name":"A"},{"nodeId":2,"sortId":2,"name":"B"},{"nodeId":3,"sortId":5,"name":"C"},{"nodeId":4,"sortId":3,"name":"D"},{"nodeId":5,"sortId":4,"name":"E"}]"#
        let route = #"{"routeMode":"BRANCH_GRAPH","sessionId":31,"version":2,"status":"ACTIVE","recommendedNodeId":4,"nodeStates":{"1":"COMPLETED","2":"DISCOVERED_LOCKED","3":"COMPLETED","4":"PLAYABLE","5":"HIDDEN"},"decisionLog":[{"fromNodeId":1,"toNodeId":3},{"fromNodeId":3,"toNodeId":4}]}"#
        let data = "{\"topicId\":9,\"mode\":1,\"playable\":true,\"registered\":true,\"nodes\":\(nodes),\"routeState\":\(route)}"
        let wire = try JSONDecoder().decode(PlayWireValue.self, from: Data(data.utf8))
        let rows = PlayJournal.rows(in: try PlaySnapshot(scope: .topic(9), result: wire.decoded()))
        XCTAssertEqual(rows.map(\.id), [1, 3, 4, 2])
        XCTAssertEqual(rows.map(\.key), [.step(1), .step(2), .now, .ahead])
        XCTAssertFalse(rows[3].redacted)
    }

    func testNightWarningOnlyForALiteralTrue() throws {
        func wire(_ text: String) throws -> PlayWireValue { try JSONDecoder().decode(PlayWireValue.self, from: Data(text.utf8)) }
        XCTAssertTrue(PlayNightWarning.isOn(try wire(#"{"nodeId":1,"nightWarning":true}"#)))
        XCTAssertFalse(PlayNightWarning.isOn(try wire(#"{"nodeId":1,"nightWarning":false}"#)))
        XCTAssertFalse(PlayNightWarning.isOn(try wire(#"{"nodeId":1,"nightWarning":"yes"}"#)))
        XCTAssertFalse(PlayNightWarning.isOn(try wire(#"{"nodeId":1}"#)))
        XCTAssertFalse(PlayNightWarning.isOn(nil))
    }

    func testFlyScoreFollowsTheMPFirstTimeRule() throws {
        func wire(_ text: String) throws -> PlayWireValue { try JSONDecoder().decode(PlayWireValue.self, from: Data(text.utf8)) }
        XCTAssertEqual(PlayFlyScore.points(try wire(#"{"nodeId":1,"firstTime":true,"xp":9}"#)), 9)
        XCTAssertEqual(PlayFlyScore.points(try wire(#"{"nodeId":1,"score":"12"}"#)), 12)
        XCTAssertNil(PlayFlyScore.points(try wire(#"{"nodeId":1,"firstTime":false,"xp":9}"#)))
        XCTAssertNil(PlayFlyScore.points(try wire(#"{"nodeId":1,"xp":0}"#)))
        XCTAssertNil(PlayFlyScore.points(nil))
    }

    func testCouponToastFollowsTheCompletedNodeCoupon() throws {
        func wire(_ text: String) throws -> PlayWireValue { try JSONDecoder().decode(PlayWireValue.self, from: Data(text.utf8)) }
        let city = try snapshot(mode: 1, nodes: #"[{"nodeId":1,"couponId":"55","done":true},{"nodeId":2,"done":false}]"#)
        XCTAssertEqual(city.result.nodes.first?.couponID, 55)
        XCTAssertTrue(PlayCouponToast.shows(receipt: try wire(#"{"nodeId":1,"completed":true}"#), snapshot: city))
        XCTAssertFalse(PlayCouponToast.shows(receipt: try wire(#"{"nodeId":2,"completed":true}"#), snapshot: city))
        XCTAssertFalse(PlayCouponToast.shows(receipt: nil, snapshot: city))
        let shopDay = try snapshot(mode: 2, nodes: #"[{"nodeId":1,"couponId":55}]"#)
        XCTAssertFalse(PlayCouponToast.shows(receipt: try wire(#"{"nodeId":1}"#), snapshot: shopDay))
    }

    /// MP `_applyAiScore`: a card only when the photo receipt carries `aiScore.score > 0`; no placeholder score.
    func testAIScoreCardFollowsThePhotoReceipt() throws {
        func wire(_ text: String) throws -> PlayWireValue { try JSONDecoder().decode(PlayWireValue.self, from: Data(text.utf8)) }
        let card = try XCTUnwrap(PlayAIScoreCard(receipt: try wire(#"{"nodeId":4,"aiScore":{"score":86.5,"comment":" 构图清楚 ","note":""}}"#)))
        XCTAssertEqual(card.nodeID, 4)
        XCTAssertEqual(card.score, 86.5)
        XCTAssertEqual(card.comment, "构图清楚")
        XCTAssertNil(card.note)
        XCTAssertEqual(PlayAIScoreCard(receipt: try wire(#"{"nodeId":4,"aiScore":{"score":"72","note":"仅供参考"}}"#))?.note, "仅供参考")
        XCTAssertNil(PlayAIScoreCard(receipt: try wire(#"{"nodeId":4,"aiScore":{"score":0}}"#)))
        XCTAssertNil(PlayAIScoreCard(receipt: try wire(#"{"nodeId":4}"#)))
        XCTAssertNil(PlayAIScoreCard(receipt: try wire(#"{"aiScore":{"score":90}}"#)))
        XCTAssertNil(PlayAIScoreCard(receipt: nil))
    }

    func testRouteNoticeAndTimeLineFollowTheMPBanner() throws {
        func result(_ text: String) throws -> PlayNodesResult {
            try JSONDecoder().decode(PlayNodesResult.self, from: Data(text.utf8))
        }
        let ended = try result(#"{"playable":true,"nodes":[{"nodeId":7}],"routeState":{"routeMode":"LINEAR","status":"EXPIRED"}}"#)
        XCTAssertEqual(PlayRunRouteNotice.of(ended.routeState), .ended)
        XCTAssertNil(PlayRunRouteNotice.of(try result(#"{"nodes":[{"nodeId":7}],"routeState":{"routeMode":"LINEAR","status":"ACTIVE"}}"#).routeState))
        XCTAssertEqual(PlayRunRouteNotice.timeLine(try result(#"{"playable":false,"timeNote":"活动已结束","nodes":[]}"#)), "活动已结束")
        XCTAssertNil(PlayRunRouteNotice.timeLine(try result(#"{"playable":true,"timeNote":"活动已结束","nodes":[]}"#)))
    }

    func testPuzzleSummaryCountsDoneStopsHeldToAHundred() throws {
        let run = try snapshot(mode: 1, nodes: #"[{"nodeId":1,"done":true,"puzzleScore":140},{"nodeId":2,"done":true,"puzzleScore":30},{"nodeId":3,"done":false,"puzzleScore":90},{"nodeId":4,"done":true}]"#)
        let summary = PlayPuzzleSummary(snapshot: run)
        XCTAssertEqual(summary.score, 130)
        XCTAssertEqual(summary.count, 2)
    }

    /// mp-journey-b r3: MP finish grid 解谜分 · 个人最佳 — the completion receipt's `puzzlePersonalBest` wins, else the
    /// nodes read; 0, missing or a bad value shows nothing and never fails the route.
    func testPuzzlePersonalBestPrefersTheReceiptThenTheNodesRead() throws {
        func result(_ text: String) throws -> PlayNodesResult {
            try JSONDecoder().decode(PlayNodesResult.self, from: Data(text.utf8))
        }
        let read = try result(#"{"nodes":[{"nodeId":1}],"puzzlePersonalBest":"86"}"#)
        XCTAssertEqual(read.puzzlePersonalBest, 86)
        XCTAssertEqual(PlayPuzzleSummary.personalBest(result: read, receipt: nil), 86)
        let receipt = try JSONDecoder().decode(PlayWireValue.self, from: Data(#"{"nodeId":1,"puzzlePersonalBest":92}"#.utf8))
        XCTAssertEqual(PlayPuzzleSummary.personalBest(result: read, receipt: receipt), 92)
        let bad = try result(#"{"nodes":[{"nodeId":1}],"puzzlePersonalBest":"n/a"}"#)
        XCTAssertNil(bad.puzzlePersonalBest)
        XCTAssertNil(PlayPuzzleSummary.personalBest(result: try result(#"{"nodes":[],"puzzlePersonalBest":0}"#), receipt: nil))
    }

    /// MP `play-route-state.js` keeps attributes with a text label and a finite number value; 旅程手记 lists them first.
    func testRouteAttributesKeepLabelledNumbersOnly() throws {
        let route = #"{"routeMode":"LINEAR","attributes":[{"key":"courage","label":"勇气","value":3},{"label":"体力","value":2.5},{"label":"坏","value":"7"},{"value":1},"x"]}"#
        let state = try JSONDecoder().decode(PlayRouteState.self, from: Data(route.utf8))
        XCTAssertEqual(state.attributes.map(\.label), ["勇气", "体力"])
        XCTAssertEqual(state.attributes.map(\.valueText), ["3", "2.5"])
        let none = try JSONDecoder().decode(PlayRouteState.self, from: Data(#"{"routeMode":"LINEAR","attributes":"bad"}"#.utf8))
        XCTAssertEqual(none.attributes, [])
        XCTAssertEqual(PlayJournal.attributes(in: try snapshot(mode: 1, nodes: "[]")), [])
    }

    /// MP `orderedJourneyNodes` / `resolveNextRouteNode`: a branch route lists finished stops first (decision-log
    /// order, labelled 我的第 K 步), then the recommended PLAYABLE stop as 此刻, then the rest; hidden stops stay out.
    func testBranchRouteFollowsTheDecisionLogAndTheRecommendedStop() throws {
        let nodes = #"[{"nodeId":1,"sortId":1,"name":"A"},{"nodeId":2,"sortId":2,"name":"B"},{"nodeId":3,"sortId":3,"name":"C"},{"nodeId":4,"sortId":4,"name":"D"},{"nodeId":5,"sortId":5,"name":"E"}]"#
        let route = #"{"routeMode":"BRANCH_GRAPH","sessionId":501,"status":"ACTIVE","version":2,"recommendedNodeId":4,"nodeStates":{"1":"COMPLETED","2":"DISCOVERED_LOCKED","3":"COMPLETED","4":"PLAYABLE","5":"HIDDEN"},"decisionLog":[{"fromNodeId":3,"toNodeId":1},{"fromNodeId":1,"toNodeId":4}]}"#
        let rows = PlayJournal.rows(in: try branchSnapshot(nodes: nodes, route: route))
        XCTAssertEqual(rows.map(\.id), [3, 1, 4, 2])
        XCTAssertEqual(rows.map(\.key), [.step(1), .step(2), .now, .ahead])
        let noFocus = #"{"routeMode":"BRANCH_GRAPH","sessionId":501,"status":"ACTIVE","version":2,"recommendedNodeId":2,"nodeStates":{"1":"COMPLETED","2":"DISCOVERED_LOCKED"}}"#
        let locked = PlayJournal.rows(in: try branchSnapshot(nodes: nodes, route: noFocus))
        XCTAssertEqual(locked.map(\.key), [.step(1), .ahead])
    }

    private func branchSnapshot(nodes: String, route: String) throws -> PlaySnapshot {
        let data = "{\"topicId\":9,\"mode\":1,\"playable\":true,\"registered\":true,\"nodes\":\(nodes),\"routeState\":\(route)}"
        let wire = try JSONDecoder().decode(PlayWireValue.self, from: Data(data.utf8))
        let authority = try JSONDecoder().decode(PlayRouteState.self, from: Data(route.utf8))
        return try PlaySnapshot(scope: .topic(9), result: wire.decoded(), authority: authority)
    }

    private func snapshot(mode: Int, nodes: String) throws -> PlaySnapshot {
        let data = "{\"topicId\":9,\"mode\":\(mode),\"playable\":true,\"registered\":true,\"nodes\":\(nodes),\"chapters\":[{\"chapterId\":8,\"name\":\"Chapter\"}]}"
        let wire = try JSONDecoder().decode(PlayWireValue.self, from: Data(data.utf8))
        return try PlaySnapshot(scope: .topic(9), result: wire.decoded())
    }
}
