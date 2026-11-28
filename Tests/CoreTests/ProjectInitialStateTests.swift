import XCTest
@testable import QuestifyCore

final class ProjectInitialStateTests: XCTestCase {
    private func object(_ raw: ProjectEditJSON?) throws -> [String: ProjectEditJSON] {
        let text = try XCTUnwrap(raw?.text); return try JSONDecoder().decode([String: ProjectEditJSON].self, from: Data(text.utf8))
    }
    func testFreshDefaultsStayDisabledAndNoOpPreservesNilNullEmptyAndOriginalBytes() throws {
        let values: [ProjectEditJSON?] = [nil, .null, .string(""), .string(" \n"), .string(" { \"schemaVersion\" : 1, \"future\" : \"e\\u0301\" } ")]
        for raw in values {
            let state = ProjectInitialState(raw: raw); XCTAssertFalse(state.readOnly)
            let result = try state.serialized(matching: raw)
            if let text = raw?.text { XCTAssertEqual(Array(try XCTUnwrap(result?.text).utf8), Array(text.utf8)) }
            else { XCTAssertEqual(result, raw) }
        }
        let fresh = ProjectInitialState(raw: nil); XCTAssertFalse(fresh.hp.enabled); XCTAssertFalse(fresh.luck.enabled)
        let existing = ProjectInitialState(raw: .string("{}")); XCTAssertTrue(existing.hp.enabled); XCTAssertTrue(existing.luck.enabled)
    }
    func testResourceEditPreservesUnknownNestedFieldsThoughtsAndAttributes() throws {
        let raw: ProjectEditJSON = .string(#"{"schemaVersion":1,"stateEnabled":true,"hp":{"enabled":true,"init":10,"max":10,"future":"e\u0301"},"luck":{"enabled":false,"init":3,"max":3},"attributes":[{"future":"keep"}],"thoughts":[{"key":"future","unknown":123}],"future":{"keep":[1,2,3]},"recovery":{"exhaustTag":"tag.tired","future":"keep"}}"#)
        var state = ProjectInitialState(raw: raw); state.hp.initial = "4"; state.hp.maximum = "5"
        let next = try object(state.serialized(matching: raw)), old = try object(raw)
        for key in ["attributes", "thoughts", "future"] { XCTAssertEqual(next[key], old[key]) }
        XCTAssertEqual(Array(try XCTUnwrap(next["hp"]?.object?["future"]?.text).utf8), Array("e\u{301}".utf8))
        XCTAssertEqual(next["recovery"]?.object?["exhaustTag"], .string("tag.tired"))
        XCTAssertEqual(next["recovery"]?.object?["future"], .string("keep"))
        XCTAssertEqual(next["hp"]?.object?["max"], .number(5)); XCTAssertEqual(next["hp"]?.object?["init"], .number(4))
    }
    func testLowerCapsShowsAndAppliesFourSourceBackedRecoveryAdjustments() throws {
        let raw: ProjectEditJSON = .string(#"{"schemaVersion":1,"hp":{"init":10,"max":10},"luck":{"init":3,"max":3},"recovery":{"stationEndIfHurt":2,"stageRestHpFloor":6,"stageRestLuckFloor":1,"exhaustRestHp":5}}"#)
        var state = ProjectInitialState(raw: raw); state.hp.initial = "1"; state.hp.maximum = "1"; state.luck.initial = "0"; state.luck.maximum = "0"
        XCTAssertEqual(state.recoveryChanges.count, 4)
        let next = try object(state.serialized(matching: raw)), recovery = try XCTUnwrap(next["recovery"]?.object)
        for key in ["stationEndIfHurt", "stageRestHpFloor", "exhaustRestHp"] { XCTAssertEqual(recovery[key], .number(1)) }
        XCTAssertEqual(recovery["stageRestLuckFloor"], .number(0))
    }
    func testDisableResetsUnsavedNumbersAndKeepsAttributeBackedStateEnabled() throws {
        let raw: ProjectEditJSON = .string(#"{"schemaVersion":1,"stateEnabled":true,"attributes":[{"key":"custom"}],"hp":{"enabled":true,"init":10,"max":10},"luck":{"enabled":false,"init":3,"max":3}}"#)
        var state = ProjectInitialState(raw: raw); state.hp.maximum = "5"; state.hp.initial = "2"; state.setEnabled(false, kind: .hp)
        XCTAssertEqual(state.hp.maximum, "10"); XCTAssertEqual(state.hp.initial, "10")
        let next = try object(state.serialized(matching: raw)); XCTAssertEqual(next["stateEnabled"], .bool(true))
        XCTAssertEqual(next["hp"]?.object?["enabled"], .bool(false))
    }
    func testInvalidVersionTypesDuplicateKeysOversizeAndNumericRangesStaySafe() throws {
        for text in [#"{"schemaVersion":2}"#, #"{"hp":false}"#, #"{"hp":{"init":"10"}}"#, #"{"recovery":{"stageRestHpFloor":"6"}}"#, #"{"hp":{},"hp":{}}"#, String(repeating: "x", count: 16385)] {
            let state = ProjectInitialState(raw: .string(text)); XCTAssertTrue(state.readOnly, text.prefix(80).description)
        }
        for pair in [("0","1"),("21","1"),("10","11"),("2.5","1")] {
            var state = ProjectInitialState(raw: nil); state.setEnabled(true, kind: .hp); state.hp.maximum = pair.0; state.hp.initial = pair.1
            XCTAssertThrowsError(try state.serialized(matching: nil))
        }
        var luck = ProjectInitialState(raw: nil); luck.setEnabled(true, kind: .luck); luck.luck.maximum = "6"
        XCTAssertThrowsError(try luck.serialized(matching: nil))
    }
    func testNumericNoOpAndExactSourceBindingRejectCanonicalEquivalentForeignRaw() throws {
        let raw: ProjectEditJSON = .string("{\"schemaVersion\":1,\"future\":\"e\u{301}\"}")
        var state = ProjectInitialState(raw: raw); state.hp.initial = "010"; state.hp.maximum = "+10"
        XCTAssertTrue(state.isUnchanged)
        XCTAssertEqual(Array(try XCTUnwrap(state.serialized(matching: raw)?.text).utf8), Array(try XCTUnwrap(raw.text).utf8))
        let other: ProjectEditJSON = .string("{\"schemaVersion\":1,\"future\":\"é\"}")
        XCTAssertThrowsError(try state.serialized(matching: other))
    }
    func testCarryRowsFollowMPAndRemovalRewritesOnlyAttributes() throws {
        let raw: ProjectEditJSON = .string(#"{"schemaVersion":1,"stateEnabled":true,"hp":{"enabled":true,"init":10,"max":10},"luck":{"enabled":false,"init":3,"max":3},"attributes":[{"key":"clue.map","label":"地图","initial":1},{"key":"tag.brave","label":"勇敢","initial":"1"},{"key":"clue.key","label":"钥匙","initial":0},{"key":"stat.power","label":"力量","initial":1}]}"#)
        var state = ProjectInitialState(raw: raw)
        XCTAssertEqual(state.carry.map(\.key), ["clue.map", "tag.brave"])
        XCTAssertEqual(state.carry.map(\.isClue), [true, false]); XCTAssertFalse(state.carryLocked)
        state.removeCarry("clue.map"); XCTAssertEqual(state.carry.map(\.key), ["tag.brave"]); XCTAssertFalse(state.isUnchanged)
        let next = try object(state.serialized(matching: raw))
        XCTAssertEqual(next["attributes"]?.array?.compactMap { $0.object?["key"]?.text }, ["tag.brave", "clue.key", "stat.power"])
        XCTAssertEqual(next["stateEnabled"], .bool(true))
        let bound: ProjectEditJSON = .string(#"{"schemaVersion":1,"attributeBinding":{"version":2},"attributes":[{"key":"clue.map","label":"地图","initial":1}]}"#)
        var locked = ProjectInitialState(raw: bound); XCTAssertTrue(locked.carryLocked)
        locked.removeCarry("clue.map"); XCTAssertEqual(locked.carry.count, 1); XCTAssertTrue(locked.isUnchanged)
    }
    func testAddCarryFollowsMPConfirmCarryPicker() throws {
        let raw: ProjectEditJSON = .string(#"{"schemaVersion":1,"stateEnabled":false,"hp":{"enabled":false,"init":10,"max":10},"luck":{"enabled":false,"init":3,"max":3},"attributes":[{"key":"clue.key","label":"钥匙","initial":0,"min":0,"max":1}]}"#)
        var state = ProjectInitialState(raw: raw)
        XCTAssertTrue(state.addCarry([(key: "clue.key", label: "钥匙"), (key: "tag.brave", label: "勇敢")]))
        XCTAssertEqual(state.carry.map(\.key), ["clue.key", "tag.brave"])
        let next = try object(state.serialized(matching: raw))
        let rows = next["attributes"]?.array?.compactMap { $0.object } ?? []
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0]["initial"], .number(1)); XCTAssertEqual(rows[0]["max"], .number(1))
        XCTAssertEqual(rows[1]["label"], .string("勇敢")); XCTAssertEqual(rows[1]["visible"], .bool(true))
        XCTAssertEqual(next["stateEnabled"], .bool(true))
        var full = ProjectInitialState(raw: raw)
        let many = (0..<32).map { (key: "tag.t\($0)", label: "T\($0)") }
        XCTAssertFalse(full.addCarry(many)); XCTAssertTrue(full.isUnchanged)
        let bound: ProjectEditJSON = .string(#"{"schemaVersion":1,"attributeBinding":{"version":2},"attributes":[]}"#)
        var locked = ProjectInitialState(raw: bound)
        XCTAssertFalse(locked.addCarry([(key: "clue.map", label: "地图")])); XCTAssertTrue(locked.isUnchanged)
    }
}
