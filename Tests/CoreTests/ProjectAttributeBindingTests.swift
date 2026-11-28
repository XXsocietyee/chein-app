import XCTest
@testable import QuestifyCore

/// MP `pages/publish/utils/publish/attribute-binding.js` (conflicts / confirm / projection) and the 初始状态 buffer.
final class ProjectAttributeBindingTests: XCTestCase {
    private func definition(_ key: String, label: String, initial: Int, min: Int, max: Int) -> TopicAttributeDefinition {
        let row: PlayWireValue = .object(["stateKey": .string(key), "label": .string(label), "keyType": .string("counter"),
            "scope": .string("run"), "persistScope": .string("run"), "initialValue": .integer(Int64(initial)),
            "minValue": .integer(Int64(min)), "maxValue": .integer(Int64(max)), "visible": .bool(true),
            "displayType": .string("number"), "color": .null, "icon": .null, "sortOrder": .integer(0), "rulesJson": .null])
        return TopicAttributeDefinition(stateKey: key, label: label, keyType: "counter", scope: "run", persistScope: "run",
            initialValue: initial, minValue: min, maxValue: max, visible: true, fields: ProjectAttributeBinding.registryFields(row))
    }
    private var registry: TopicAttributeRegistry {
        .init(topicID: "7", configVersion: "3", registryVersion: "5",
              definitions: [definition("counter.gold", label: "金币", initial: 2, min: 0, max: 9),
                            definition("counter.fame", label: "名望", initial: 0, min: 0, max: 5)])
    }

    func testConflictsListOldFieldsAndUnrecordedOnes() throws {
        let rules = try ProjectAttributeBinding.rules(.string(#"{"attributes":[{"key":"counter.gold","label":"金币","initial":1,"min":0,"max":9,"visible":true}]}"#))
        let conflicts = try ProjectAttributeBinding.conflicts(rules: rules, registry: registry, enabledKeys: ["counter.gold", "counter.fame"])
        XCTAssertEqual(conflicts.map(\.key), ["counter.gold"]) // fame has no old row: nothing to accept
        let fields = conflicts[0].differences.map(\.field)
        XCTAssertTrue(fields.contains("initialValue")); XCTAssertFalse(fields.contains("label")); XCTAssertFalse(fields.contains("maxValue"))
        let initial = try XCTUnwrap(conflicts[0].differences.first { $0.field == "initialValue" })
        XCTAssertEqual(initial.previous, "1"); XCTAssertEqual(initial.registered, "2")
        let color = try XCTUnwrap(conflicts[0].differences.first { $0.field == "color" })
        XCTAssertNil(color.previous); XCTAssertNil(color.registered) // 旧配置未记录 / 未设置
    }

    func testConfirmNeedsEveryAcceptanceAndEnabledStatLinkSources() throws {
        let rules = try ProjectAttributeBinding.rules(.string(#"{"attributes":[{"key":"counter.gold","initial":1}],"statLinks":[{"sourceKey":"counter.fame"}]}"#))
        XCTAssertThrowsError(try ProjectAttributeBinding.confirm(rules: rules, registry: registry, enabledKeys: ["counter.gold", "counter.fame"], acceptedKeys: [])) {
            XCTAssertEqual($0 as? ProjectAttributeBinding.Issue, .unaccepted)
        }
        XCTAssertThrowsError(try ProjectAttributeBinding.confirm(rules: rules, registry: registry, enabledKeys: ["counter.gold"], acceptedKeys: ["counter.gold"])) {
            XCTAssertEqual($0 as? ProjectAttributeBinding.Issue, .statLink("counter.fame"))
        }
        let next = try ProjectAttributeBinding.confirm(rules: rules, registry: registry, enabledKeys: ["counter.gold", "counter.fame"], acceptedKeys: ["counter.gold"])
        XCTAssertEqual(next["stateEnabled"], .bool(true))
        XCTAssertEqual(next["attributeBinding"]?.object?["registryVersion"], .string("5"))
        let rows = try XCTUnwrap(next["attributes"]?.array)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].object?["initial"], .number(2)); XCTAssertEqual(rows[1].object?["label"], .string("名望"))
    }

    func testInitialStateBufferStagesTheBindingAndLocksCarry() throws {
        let raw: ProjectEditJSON = .string(#"{"schemaVersion":1,"hp":{"enabled":true,"init":10,"max":10},"luck":{"enabled":false,"init":3,"max":3},"attributes":[{"key":"clue.map","label":"地图","initial":1,"min":0,"max":1,"visible":true}],"attributeSnapshot":{"old":true}}"#)
        var state = ProjectInitialState(raw: raw)
        XCTAssertFalse(state.carryLocked); XCTAssertEqual(state.bindingEnabledKeys, [])
        let confirmed = try ProjectAttributeBinding.confirm(rules: state.bindingRules, registry: registry, enabledKeys: ["counter.fame"], acceptedKeys: [])
        state.bind(confirmed)
        XCTAssertTrue(state.carryLocked); XCTAssertEqual(state.bindingEnabledKeys, ["counter.fame"])
        XCTAssertEqual(state.counters.map(\.key), ["counter.fame"])
        let text = try XCTUnwrap(state.serialized(matching: raw)?.text)
        let object = try JSONDecoder().decode([String: ProjectEditJSON].self, from: Data(text.utf8))
        XCTAssertNil(object["attributeSnapshot"])
        XCTAssertEqual(object["stateEnabled"], .bool(true))
        XCTAssertEqual(object["attributes"]?.array?.count, 1)
        XCTAssertNotNil(object["attributeBinding"]?.object)
    }
}
