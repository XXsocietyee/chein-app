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

    func testNightWarningOnlyForALiteralTrue() throws {
        func wire(_ text: String) throws -> PlayWireValue { try JSONDecoder().decode(PlayWireValue.self, from: Data(text.utf8)) }
        XCTAssertTrue(PlayNightWarning.isOn(try wire(#"{"nodeId":1,"nightWarning":true}"#)))
        XCTAssertFalse(PlayNightWarning.isOn(try wire(#"{"nodeId":1,"nightWarning":false}"#)))
        XCTAssertFalse(PlayNightWarning.isOn(try wire(#"{"nodeId":1,"nightWarning":"yes"}"#)))
        XCTAssertFalse(PlayNightWarning.isOn(try wire(#"{"nodeId":1}"#)))
        XCTAssertFalse(PlayNightWarning.isOn(nil))
    }

    private func snapshot(mode: Int, nodes: String) throws -> PlaySnapshot {
        let data = "{\"topicId\":9,\"mode\":\(mode),\"playable\":true,\"registered\":true,\"nodes\":\(nodes),\"chapters\":[{\"chapterId\":8,\"name\":\"Chapter\"}]}"
        let wire = try JSONDecoder().decode(PlayWireValue.self, from: Data(data.utf8))
        return try PlaySnapshot(scope: .topic(9), result: wire.decoded())
    }
}
