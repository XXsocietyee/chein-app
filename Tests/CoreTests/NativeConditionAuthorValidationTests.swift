import Foundation
import XCTest
#if canImport(QuestifyCore)
@testable import QuestifyCore
#elseif canImport(Questify)
@testable import Questify
#endif

final class NativeConditionAuthorValidationTests: XCTestCase {
    private func issues(condition: String = "[]", effects: String = "[]") throws -> [NativeConditionAuthorIssue] {
        let raw = NativeConditionAuthorWireTests.graph.replacingOccurrences(of: #""conditions":[]"#, with: #""conditions":"# + condition)
            .replacingOccurrences(of: #""effects":[]"#, with: #""effects":"# + effects)
        let d = try NativeConditionAuthorDocument(raw: raw, surface: .routeGraph, scope: NativeConditionAuthorWireTests.scope)
        return NativeConditionAuthorValidation.issues(d, catalog: NativeConditionAuthorWireTests.catalog, attributes: nil)
    }
    func testEveryConfirmedLeafShape() throws {
        for condition in [
            #"{"op":"IN","var":"clue.word","values":["open","closed"]}"#,
            #"{"op":"ITEM_HELD","itemId":"key","quantity":1}"#,
            #"{"op":"ITEM_ACQUIRED","itemId":"medal","quantity":1}"#,
            #"{"op":"CONSUME_ITEM","itemId":"key","quantity":999}"#,
            #"{"op":"NODE_COMPLETED","nodeId":20}"#,
            #"{"op":"VISIT_COUNT","nodeId":20,"comparator":"GTE","value":2}"#,
            #"{"op":"EDGE_VISITS","edgeId":"gate","value":1}"#,
            #"{"op":"ROLE_IN","values":["NAVIGATOR","DECODER"]}"#,
            #"{"op":"TIME_BETWEEN","start":1750000000000,"end":1750000000001}"#,
            #"{"op":"EQ","var":"sys.passed.20","value":0}"#
        ] { XCTAssertTrue(try issues(condition: condition).isEmpty, condition) }
    }
    func testAllNumericComparatorsAndEffectsUseDeclaredTypes() throws {
        for op in NativeConditionAuthorValidation.comparisons {
            XCTAssertTrue(try issues(condition: #"{"op":""# + op + #"","var":"counter.hp","value":1.25}"#).isEmpty)
        }
        XCTAssertTrue(try issues(condition: #"{"op":"EQ","var":"counter.hp","value":"1"}"#).contains { $0.code == "number" })
        XCTAssertTrue(try issues(condition: #"{"op":"EQ_STR","var":"counter.hp","value":"1"}"#).contains { $0.code == "undeclared" })
        XCTAssertTrue(try issues(condition: #"{"op":"EQ","var":"counter.missing","value":1}"#).contains { $0.code == "undeclared" })
    }
    func testConsumeUnderNestedNOTAlwaysRejected() throws {
        let raw = #"{"op":"NOT","child":{"op":"NOT","child":[{"op":"CONSUME_ITEM","itemId":"key","quantity":1}]}}"#
        XCTAssertTrue(try issues(condition: raw).contains { $0.code == "consumeUnderNot" })
        XCTAssertTrue(try issues(condition: #"{"op":"CONSUME_ITEM","itemId":"medal","quantity":1}"#).contains { $0.code == "itemScope" })
    }
    func testUnsupportedOriginalDesignNeedsRealBackendAdapters() throws {
        for op in ["AT_NODE", "TIME_LEFT", "TEAM_SIZE", "TEAM_HAS_TAG", "WEATHER_IN"] {
            let found = try issues(condition: #"{"op":""# + op + #""}"#)
            XCTAssertTrue(found.contains { $0.code == "backendDependency" && !$0.detail.isEmpty }, op)
        }
        XCTAssertTrue(try issues(effects: #"[{"op":"EMIT_EVENT","type":"CUSTOM","payload":{}}]"#).isEmpty)
        XCTAssertTrue(try issues(effects: #"[{"op":"EMIT_EVENT","type":"TIME_TICK","payload":{}}]"#).contains { $0.code == "backendDependency" })
        XCTAssertTrue(try issues(effects: #"[{"op":"EMIT_EVENT","type":"CUSTOM","payload":{"amount":1}}]"#).contains { $0.code == "backendDependency" })
        XCTAssertEqual(NativeConditionAuthorFields.blank(operation: "EMIT_EVENT", effect: true), .object(["op": .string("EMIT_EVENT"), "type": .string("CUSTOM"), "payload": .object([:])]))
    }
    func testTimeWindowsRequireEpochIntegerAndOrderedEndpoints() throws {
        for raw in [#"{"op":"TIME_BETWEEN","start":10,"end":10}"#, #"{"op":"TIME_BETWEEN","start":"10","end":20}"#, #"{"op":"TIME_BETWEEN","start":-1,"end":20}"#] {
            XCTAssertFalse(try issues(condition: raw).isEmpty)
        }
    }
    func testOriginalEffectsAndNestedChoiceAreDeclarations() throws {
        let effects = #"[{"op":"SET","var":"counter.hp","value":3},{"op":"INC","var":"counter.hp","value":-1},{"op":"FLOOR","var":"counter.hp","value":2},{"op":"ADD_TAG","value":"tag.done"},{"op":"SET_STR","var":"clue.word","value":""},{"op":"ADD_ITEM","itemId":"key","quantity":1},{"op":"REMOVE_ITEM","itemId":"key","quantity":1},{"op":"GRANT_BADGE","scope":"TOPIC_MEDAL","badgeId":"medal"},{"op":"UNLOCK_NODE","nodeId":21},{"op":"RANDOM_CHOICE","choices":[{"weight":1,"effects":[{"op":"RANDOM_CHOICE","choices":[{"weight":2,"effects":[]}]}]}]}]"#
        XCTAssertTrue(try issues(effects: effects).isEmpty)
        XCTAssertTrue(try issues(effects: #"[{"op":"GRANT_BADGE","scope":"GLOBAL","badgeId":"medal"}]"#).contains { $0.code == "topicMedal" })
        XCTAssertTrue(try issues(effects: #"[{"op":"REMOVE_ITEM","itemId":"medal","quantity":1}]"#).contains { $0.code == "itemScope" })
    }
    func testPassedFactHasNoInitializerOrWritableEffectEvenInChoice() throws {
        let raw = NativeConditionAuthorWireTests.graph.replacingOccurrences(of: #""counter.hp":10"#, with: #""counter.hp":10,"sys.passed.20":0"#)
        let d = try NativeConditionAuthorDocument(raw: raw, surface: .routeGraph, scope: NativeConditionAuthorWireTests.scope)
        XCTAssertTrue(NativeConditionAuthorValidation.issues(d, catalog: NativeConditionAuthorWireTests.catalog, attributes: nil).contains { $0.code == "readonly" })
        XCTAssertTrue(try issues(effects: #"[{"op":"RANDOM_CHOICE","choices":[{"weight":1,"effects":[{"op":"SET","var":"sys.passed.20","value":1}]}]}]"#).contains { $0.code == "readonly" })
        XCTAssertTrue(try issues(condition: #"{"op":"EQ","var":"sys.passed.99","value":0}"#).contains { $0.code == "undeclared" })
        for key in ["sys.passed.bad", "sys.passed.020", "sys.passed."] {
            let malformed = NativeConditionAuthorWireTests.graph.replacingOccurrences(of: #""counter.hp":10"#, with: #""counter.hp":10,"# + "\"" + key + "\":0")
            let invalid = try NativeConditionAuthorDocument(raw: malformed, surface: .routeGraph, scope: d.scope)
            XCTAssertTrue(NativeConditionAuthorValidation.issues(invalid, catalog: NativeConditionAuthorWireTests.catalog, attributes: nil).contains { $0.code == "readonly" })
        }
    }
    func testChoiceBoundsAndUnknownFieldsAreNotDiscarded() throws {
        for weight in ["0", "10001", "1.5", #""1""#] {
            XCTAssertTrue(try issues(effects: #"[{"op":"RANDOM_CHOICE","choices":[{"weight":"# + weight + #" ,"effects":[]}]}]"#).contains { $0.code == "integer" })
        }
        XCTAssertTrue(try issues(effects: #"[{"op":"INC","var":"counter.hp","value":1,"future":true}]"#).contains { $0.code == "unknownField" })
    }
    func testExpressionDepthAndNodeBudgets() throws {
        var expression = #"{"op":"HAS_TAG","value":"a"}"#
        for _ in 0..<18 { expression = #"{"op":"NOT","child":"# + expression + "}" }
        XCTAssertTrue(try issues(condition: expression).contains { $0.code == "conditionLimit" })
        let children = Array(repeating: #"{"op":"HAS_TAG","value":"a"}"#, count: 513).joined(separator: ",")
        XCTAssertTrue(try issues(condition: "[" + children + "]").contains { $0.code == "conditionLimit" })
    }
    func testProjectionIsScopedAndNeverAnInitializer() throws {
        let d = try NativeConditionAuthorDocument(raw: NativeConditionAuthorWireTests.graph, surface: .routeGraph, scope: NativeConditionAuthorWireTests.scope)
        let projection = NativeConditionAuthorAttributeProjection(scope: .init(accountID: 9, namespace: "other", epoch: 1, authorizationRevision: "x", documentIdentity: "topic:20", sourceRevision: "7", incarnation: UUID()), definitionVersion: "2", origin: .publishedDefinition, references: [])
        XCTAssertTrue(NativeConditionAuthorValidation.issues(d, catalog: NativeConditionAuthorWireTests.catalog, attributes: projection).contains { $0.code == "attributeScope" })
        XCTAssertFalse(try d.serialized().contains("initialValue"))
    }
    func testTemplateConsumerGapIsExplicitAndRawSurvives() throws {
        let raw = #"{"op":"ANY_OF","children":[{"op":"EQ","var":"counter.hp","value":1}],"future":true}"#
        let d = try NativeConditionAuthorDocument(raw: raw, surface: .templateCondition, scope: NativeConditionAuthorWireTests.scope)
        XCTAssertEqual(try d.serialized(), raw)
        XCTAssertTrue(NativeConditionAuthorValidation.issues(d, catalog: NativeConditionAuthorWireTests.catalog, attributes: nil).contains { $0.code == "templateContract" })
    }
    func testCurrentBackendNodeRequirementsArePreservedAndValidated() throws {
        let raw = String(NativeConditionAuthorWireTests.graph.dropLast()) + #", "nodeRequirements":[{"nodeId":20,"allowedTicketIds":[2],"allowedPurchaseKinds":[1,3],"requiredRoleCodes":["NAVIGATOR"],"requireOpen":true,"requireReachable":false,"maxDistanceMeters":100}]}"#
        let d = try NativeConditionAuthorDocument(raw: String(raw), surface: .routeGraph, scope: NativeConditionAuthorWireTests.scope)
        XCTAssertTrue(NativeConditionAuthorValidation.issues(d, catalog: NativeConditionAuthorWireTests.catalog, attributes: nil).isEmpty)
        XCTAssertEqual(try d.serialized(), raw)
    }
    func testOutcomeMustBelongToOriginalSourceNodeAndTrigger() throws {
        let raw = NativeConditionAuthorWireTests.graph.replacingOccurrences(of: #""outcomeCode":"TRY""#, with: #""outcomeCode":"OTHER_NODE_ONLY""#)
        var catalog = NativeConditionAuthorWireTests.catalog
        catalog.sourceOutcomes["21"] = [.init(triggerType: "CHOICE", code: "OTHER_NODE_ONLY", label: "Other")]
        let d = try NativeConditionAuthorDocument(raw: raw, surface: .routeGraph, scope: NativeConditionAuthorWireTests.scope)
        XCTAssertTrue(NativeConditionAuthorValidation.issues(d, catalog: catalog, attributes: nil).contains { $0.code == "outcomeScope" })
    }
    func testOriginalRPGProjectionEnablesOnlyItsRegisteredLeaves() throws {
        let raw = NativeConditionAuthorWireTests.graph.replacingOccurrences(of: #""conditions":[]"#, with: #""conditions":{"op":"CHECK_RESULT","checkId":"gate","in":["SUCCESS"]}"#)
        let d = try NativeConditionAuthorDocument(raw: raw, surface: .routeGraph, scope: NativeConditionAuthorWireTests.scope)
        var catalog = NativeConditionAuthorWireTests.catalog
        XCTAssertTrue(NativeConditionAuthorValidation.issues(d, catalog: catalog, attributes: nil).contains { $0.code == "registryDependency" })
        catalog.rpg = .init(scope: d.scope, definitionVersion: "7", supportedOperations: ["CHECK_RESULT"],
                            checks: [.init(id: "gate", label: "Gate")], checkResults: [.init(id: "SUCCESS", label: "Success")], conditions: [], equipment: [])
        XCTAssertTrue(NativeConditionAuthorValidation.issues(d, catalog: catalog, attributes: nil).isEmpty)
        let unknown = try NativeConditionAuthorDocument(raw: raw.replacingOccurrences(of: #""checkId":"gate""#, with: #""checkId":"other""#), surface: .routeGraph, scope: d.scope)
        XCTAssertTrue(NativeConditionAuthorValidation.issues(unknown, catalog: catalog, attributes: nil).contains { $0.code == "registryReference" })
    }
    func testPartyNumericFactRequiresOriginalDeclarationAndIsReadOnly() throws {
        let raw = NativeConditionAuthorWireTests.graph.replacingOccurrences(of: #""conditions":[]"#, with: #""conditions":{"op":"GTE","var":"sys.party.size","value":2}"#)
        let d = try NativeConditionAuthorDocument(raw: raw, surface: .routeGraph, scope: NativeConditionAuthorWireTests.scope)
        var catalog = NativeConditionAuthorWireTests.catalog
        XCTAssertTrue(NativeConditionAuthorValidation.issues(d, catalog: catalog, attributes: nil).contains { $0.code == "undeclared" })
        catalog.numericFacts = [.init(id: "sys.party.size", label: "Original party size")]
        XCTAssertTrue(NativeConditionAuthorValidation.issues(d, catalog: catalog, attributes: nil).isEmpty)
        let write = try NativeConditionAuthorDocument(raw: raw.replacingOccurrences(of: #""effects":[]"#, with: #""effects":[{"op":"SET","var":"sys.party.size","value":3}]"#), surface: .routeGraph, scope: d.scope)
        XCTAssertTrue(NativeConditionAuthorValidation.issues(write, catalog: catalog, attributes: nil).contains { $0.code == "readonly" })
        XCTAssertFalse(try d.serialized().contains(#""sys.party.size":2"#))
    }
    func testOriginalTopologyConstraintsRemainAuthorChecks() throws {
        let raw = NativeConditionAuthorWireTests.graph.replacingOccurrences(of: #""toNodeId":21,"trigger""#, with: #""toNodeId":20,"trigger""#)
            .replacingOccurrences(of: #", "fallbacks":[]"#, with: "")
        let d = try NativeConditionAuthorDocument(raw: raw, surface: .routeGraph, scope: NativeConditionAuthorWireTests.scope)
        let errors = NativeConditionAuthorValidation.issues(d, catalog: NativeConditionAuthorWireTests.catalog, attributes: nil)
        XCTAssertTrue(errors.contains { $0.code == "loop" })
        let terminalOutgoing = NativeConditionAuthorWireTests.graph.replacingOccurrences(of: #""fromNodeId":20"#, with: #""fromNodeId":21"#)
        let terminal = try NativeConditionAuthorDocument(raw: terminalOutgoing, surface: .routeGraph, scope: d.scope)
        XCTAssertTrue(NativeConditionAuthorValidation.issues(terminal, catalog: NativeConditionAuthorWireTests.catalog, attributes: nil).contains { $0.code == "terminalOutgoing" })
    }
}
