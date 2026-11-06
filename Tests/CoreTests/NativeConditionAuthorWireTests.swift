import Foundation
import XCTest
#if canImport(QuestifyCore)
@testable import QuestifyCore
#elseif canImport(Questify)
@testable import Questify
#endif

/// Also supports the owner's same-module Core harness. Module discovery is explicit;
/// if neither real module is present, absent production symbols cause a build failure.
final class NativeConditionAuthorWireTests: XCTestCase {
    static let scope = NativeConditionAuthorScope(accountID: 8, namespace: "china:author", epoch: 1,
        authorizationRevision: "owner:1", documentIdentity: "topic:20", sourceRevision: "7", incarnation: UUID())
    static let catalog = NativeConditionAuthorCatalog(nodes: [.init(id: "20", label: "起点"), .init(id: "21", label: "终点")],
        items: [.init(id: "key", label: "钥匙")], medals: [.init(id: "medal", label: "主题勋章")],
        triggers: [.init(id: "CHOICE", label: "原触发类型")], outcomes: [.init(id: "TRY", label: "原结果")],
        sourceOutcomes: ["20": [.init(triggerType: "CHOICE", code: "TRY", label: "原结果")]])
    static let graph = #"{"schemaVersion":1,"routeExpressionVersion":2,"startNodeId":20,"terminalNodeIds":[21],"variables":{"counter.hp":10},"stringVariables":{"clue.word":"open"},"edges":[{"id":"gate","fromNodeId":20,"toNodeId":21,"trigger":{"type":"CHOICE","outcomeCode":"TRY"},"conditions":[],"effects":[]}],"fallbacks":[{"fromNodeId":20,"toNodeId":21}]}"#
    static let condition = NativeConditionAuthorPath().field("edges").index(0).field("conditions")
    static let effects = NativeConditionAuthorPath().field("edges").index(0).field("effects")
    func json(_ raw: String) throws -> ProjectEditJSON { try JSONDecoder().decode(ProjectEditJSON.self, from: Data(raw.utf8)) }
    func document(_ raw: String = NativeConditionAuthorWireTests.graph) throws -> NativeConditionAuthorDocument { try .init(raw: raw, surface: .routeGraph, scope: Self.scope) }
    func changed(_ raw: String, at path: NativeConditionAuthorPath = NativeConditionAuthorWireTests.condition) throws -> NativeConditionAuthorDocument {
        var d = try document(); let old = try XCTUnwrap(NativeConditionAuthorTree.value(d.value, at: path))
        try d.replace(at: path, expected: old, with: json(raw), revision: d.revision); return d
    }
    func codes(_ d: NativeConditionAuthorDocument) -> [String] { NativeConditionAuthorValidation.issues(d, catalog: Self.catalog, attributes: nil).map(\.code) }

    func testNoOpPreservesExactOriginalBytes() throws {
        let raw = " \n" + Self.graph + "\n "
        let d = try document(raw); XCTAssertFalse(d.hasChanges); XCTAssertEqual(try d.serialized().utf8.map { $0 }, Array(raw.utf8))
        XCTAssertTrue(d.canRoundTrip); XCTAssertTrue(codes(d).isEmpty)
    }
    func testNestedArrayAllAnyNotRoundTrip() throws {
        let d = try changed(#"{"op":"ALL_OF","children":[{"op":"ANY_OF","children":[{"op":"EQ","var":"counter.hp","value":5},{"op":"EQ_STR","var":"clue.word","value":"open"}]},{"op":"NOT","child":{"op":"HAS_TAG","value":"tag.closed"}}]}"#)
        XCTAssertTrue(codes(d).isEmpty)
        let decoded = try document(d.serialized()); XCTAssertTrue(NativeConditionAuthorTree.exact(decoded.value, d.value))
        XCTAssertEqual(NativeConditionAuthorTree.rows(d.value, at: Self.condition).map(\.operation), ["ALL_OF", "ANY_OF", "EQ", "EQ_STR", "NOT", "HAS_TAG"])
    }
    func testANDIsNotAnInventedOperation() throws {
        XCTAssertTrue(codes(try changed(#"{"op":"AND","children":[]}"#)).contains("unknownOperation"))
    }
    func testUnknownFieldsSurviveSiblingEditAndBlockSave() throws {
        var d = try changed(#"{"op":"EQ","var":"counter.hp","value":5,"future":{"n":9007199254740993,"text":"keep"}}"#)
        let original = try XCTUnwrap(NativeConditionAuthorTree.value(d.value, at: Self.condition))
        var row = try XCTUnwrap(original.nativeConditionObject); row["value"] = .number(6)
        try d.replace(at: Self.condition, expected: original, with: .object(row), revision: d.revision)
        XCTAssertTrue(codes(d).contains("unknownField"))
        let reopened = try document(d.serialized())
        let future = NativeConditionAuthorTree.value(reopened.value, at: Self.condition)?.nativeConditionObject?["future"]
        XCTAssertEqual(future?.nativeConditionObject?["n"]?.nativeConditionInteger, 9_007_199_254_740_993)
        XCTAssertEqual(future?.nativeConditionObject?["text"], .string("keep"))
    }
    func testUnsupportedVersionCannotBeEditedAndRawIsPreserved() throws {
        for replacement in ["3", #""2""#, "2.0", "2e0", "null", "true"] {
            let raw = Self.graph.replacingOccurrences(of: #""routeExpressionVersion":2"#, with: #""routeExpressionVersion":"# + replacement)
            var d = try document(raw); XCTAssertFalse(d.isExplicitV2); XCTAssertEqual(try d.serialized(), raw)
            XCTAssertThrowsError(try d.replace(at: .init(), expected: d.value, with: .object([:]), revision: 0))
        }
    }
    func testLegacyPassedInitializerIsNotMigratedOrDestroyed() throws {
        let raw = Self.graph.replacingOccurrences(of: #""routeExpressionVersion":2,"#, with: "")
            .replacingOccurrences(of: #""counter.hp":10"#, with: #""counter.hp":10,"sys.passed.20":0"#)
        let d = try document(raw); XCTAssertFalse(d.isExplicitV2); XCTAssertEqual(try d.serialized(), raw)
    }
    func testStrictCodecRejectsLossyDestructiveEdits() throws {
        let raw = Self.graph.replacingOccurrences(of: #""counter.hp":10"#, with: #""counter.hp":10,"future":12345678901234567890123456789012345678901234567890"#)
        let d = try document(raw)
        XCTAssertEqual(try d.serialized(), raw)
        if !d.canRoundTrip { XCTAssertTrue(codes(d).contains("lossless")) }
        else {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            XCTAssertEqual(try ContentDraftJSON.parse(raw), try ContentDraftJSON.parse(String(decoding: encoder.encode(d.value), as: UTF8.self)))
        }
    }
    func testKnownOperationChangeRetainsUnknownExtensions() throws {
        let original = try json(#"{"op":"EQ","var":"counter.hp","value":3,"future":{"x":1}}"#)
        let result = NativeConditionAuthorFields.changingOperation(original, to: "NOT", effect: false)
        XCTAssertEqual(result.nativeConditionObject?["future"], original.nativeConditionObject?["future"])
        XCTAssertNil(result.nativeConditionObject?["var"]); XCTAssertEqual(result.nativeConditionObject?["child"], .array([]))
    }
    func testInsertDeleteAndMoveAreExactAndOrdered() throws {
        let a = try json(#"[{"op":"EQ"},{"op":"NE"},{"op":"GT"}]"#)
        let moved = try NativeConditionAuthorTree.moving(0, to: 2, in: a)
        XCTAssertEqual(moved.nativeConditionArray?.compactMap { $0.nativeConditionObject?["op"]?.nativeConditionText }, ["NE", "GT", "EQ"])
        let removed = try NativeConditionAuthorTree.removing(1, from: moved)
        let inserted = try NativeConditionAuthorTree.inserting(.object(["op": .string("LT")]), at: 1, into: removed)
        XCTAssertEqual(inserted.nativeConditionArray?.compactMap { $0.nativeConditionObject?["op"]?.nativeConditionText }, ["NE", "LT", "EQ"])
        XCTAssertThrowsError(try NativeConditionAuthorTree.moving(5, to: 0, in: a))
    }
    func testRevisionFenceRejectsABAAndStalePath() throws {
        var d = try document(); let original = try XCTUnwrap(NativeConditionAuthorTree.value(d.value, at: Self.condition))
        try d.replace(at: Self.condition, expected: original, with: original, revision: 0)
        XCTAssertThrowsError(try d.replace(at: Self.condition, expected: original, with: original, revision: 0))
        XCTAssertThrowsError(try d.replace(at: Self.condition.index(3), expected: .null, with: .null, revision: d.revision))
    }
    func testUnicodePreimageUsesExactUTF8() {
        XCTAssertFalse(NativeConditionAuthorTree.exact(.string("é"), .string("e\u{301}")))
    }
    func testVersionGateIgnoresNestedKeysAndRecognizesEscapedRootKeys() {
        XCTAssertFalse(NativeConditionAuthorVersion.hasExplicitV2(#"{"schemaVersion":1,"nested":{"routeExpressionVersion":2}}"#))
        XCTAssertTrue(NativeConditionAuthorVersion.hasExplicitV2(#"{"schemaVersion":1,"routeExpression\u0056ersion":2}"#))
        XCTAssertFalse(NativeConditionAuthorVersion.hasExplicitV2(#"{"schemaVersion":1,"routeExpressionVersion":2,"routeExpressionVersion":2}"#))
    }
}
