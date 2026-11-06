import Foundation
import XCTest
@testable import QuestifyCore

enum NativeAttributeAuthorTestFixtures {
    // Declaration values mirror original37 DynamicAttributeAuthoringProjectionTest's counter.temp.
    static let extendedRow = #"{"stateKey":"counter.temp","keyType":"counter","scope":"run","label":"温度","initialValue":10,"minValue":0,"maxValue":10,"display":"number","sortOrder":0,"visible":true,"persistScope":"run","rules":[]}"#
    static let row = #"{"stateKey":"counter.temp","keyType":"counter","scope":"run","label":"温度","initialValue":10}"#
    static func binding(epoch: UInt64 = 1, version: Int64 = 4, source: NativeAttributeAuthorBinding.Source = .current) throws -> NativeAttributeAuthorBinding {
        try .init(server: "https://fixture.invalid", namespace: "fixture", accountID: 7, epoch: epoch,
            authorizationRevision: "fixture-author", topicID: 88, sourceConfigVersion: version, requestScope: "", source: source)
    }
    static func draft(_ binding: NativeAttributeAuthorBinding? = nil, row: String = NativeAttributeAuthorTestFixtures.row) throws -> NativeAttributeAuthorDraft {
        try .init(binding: binding ?? self.binding(), rawRows: Data("[\(row)]".utf8))
    }
    static func envelope(_ rows: String) -> Data { Data("{\"code\":200,\"data\":[\(rows)]}".utf8) }
    static func validation(_ rows: String = NativeAttributeAuthorTestFixtures.row) -> Data { Data("{\"code\":200,\"data\":{\"definitions\":[\(rows)],\"warnings\":[]}}".utf8) }
}

final class NativeAttributeAuthorTests: XCTestCase {
    func testUnchangedSourceAndFutureMetadataArePreserved() throws {
        let raw = NativeAttributeAuthorTestFixtures.row.dropLast() + #", "future":{"nested":[1,"原字段"]},"id":99}"#
        var draft = try NativeAttributeAuthorTestFixtures.draft(row: String(raw))
        let original = draft.rawSource
        XCTAssertFalse(draft.hasChanges)
        XCTAssertTrue(try draft.changedRows().isEmpty)
        var row = try XCTUnwrap(draft.rows.first); row.label = "气温"
        try draft.replace(row)
        let request = try NativeAttributeAuthorRequest.save(draft.changedRows(), binding: draft.binding, key: UUID())
        let body = try XCTUnwrap(NativeAttributeAuthorWire.decode(XCTUnwrap(request.body)).object)
        let patch = try XCTUnwrap(body["keys"]?.array?.first?.object)
        XCTAssertEqual(Set(patch.keys), ["stateKey","keyType","scope","label","initialValue"])
        XCTAssertEqual(draft.rawSource, original)
        XCTAssertNotNil(draft.rows.first?.original["future"])
    }
    func testRegistrationEditPreservesLegacyShape() throws {
        let legacy = #"{"stateKey":"counter.old","keyType":"counter","scope":"run","label":"旧值","initialValue":3,"future":42}"#
        var draft = try NativeAttributeAuthorTestFixtures.draft(row: legacy)
        XCTAssertFalse(try XCTUnwrap(draft.rows.first).isDefinition)
        XCTAssertTrue(try draft.changedRows().isEmpty)
        var row = try XCTUnwrap(draft.rows.first); row.label = "旧名"; try draft.replace(row)
        XCTAssertEqual(try draft.changedRows().count, 1)
        let fields = try row.registrationPayload()
        XCTAssertEqual(Set(fields.keys), NativeAttributeAuthorRequest.registrationFields)
        XCTAssertNil(draft.rows[0].original["minValue"])
    }
    func testRegisteredIdentityAndIndependentScopeCannotChange() throws {
        let original = try XCTUnwrap(NativeAttributeAuthorTestFixtures.draft().rows.first)
        for field in ["key","type","scope"] {
            var row = original
            if field == "key" { row.key = "counter.renamed" }
            if field == "type" { row.keyType = "tag" }
            if field == "scope" { row.scope = "party" }
            XCTAssertThrowsError(try row.definition(), field)
        }
        var label = original; label.label = "洞察"; XCTAssertNoThrow(try label.definition())
    }
    func testRejectsDuplicateKeysAndNonintegralIntegerTokens() throws {
        for token in ["10.0", "1e1", "true", "2147483648"] {
            let raw = NativeAttributeAuthorTestFixtures.row.replacingOccurrences(of: "\"initialValue\":10", with: "\"initialValue\":\(token)")
            XCTAssertThrowsError(try NativeAttributeAuthorTestFixtures.draft(row: raw), token)
        }
        XCTAssertThrowsError(try NativeAttributeAuthorTestFixtures.draft(row: NativeAttributeAuthorTestFixtures.row + "," + NativeAttributeAuthorTestFixtures.row))
        let duplicate = NativeAttributeAuthorTestFixtures.row.dropLast() + #", "label":"重复"}"#
        XCTAssertThrowsError(try NativeAttributeAuthorTestFixtures.draft(row: String(duplicate)))
    }
    func testConditionsRetainOriginalTreeWithoutEvaluationOrMigration() throws {
        var row = try XCTUnwrap(NativeAttributeAuthorTestFixtures.draft(row: NativeAttributeAuthorTestFixtures.extendedRow).rows.first)
        let condition = try NativeAttributeAuthorWire.decode(Data(#"{"op":"ALL_OF","children":[{"op":"GTE","var":"counter.temp","value":1},{"op":"NOT","child":{"op":"HAS_TAG","value":"tag.ready"}}]}"#.utf8))
        var rule = NativeAttributeAuthorRule(); rule.condition = condition; row.rules = [rule]
        let encoded = try XCTUnwrap(try rule.encoded().object)
        XCTAssertEqual(encoded["when"], condition)
        let copy = rule.duplicate(); XCTAssertNotEqual(copy.id, rule.id); XCTAssertEqual(copy.condition, condition)
        let full = try NativeAttributeAuthorWire.encode(.object(row.definition()))
        XCTAssertNoThrow(try NativeAttributeAuthorWire.decode(full))
    }
    func testRangeFlagRulesAndMetadataFollowOriginal37Compiler() throws {
        var row = try XCTUnwrap(NativeAttributeAuthorTestFixtures.draft(row: NativeAttributeAuthorTestFixtures.extendedRow).rows.first)
        row.minimum = "10"; row.maximum = "10"; XCTAssertThrowsError(try row.definition())
        row.minimum = "0"; row.maximum = "10"; row.initial = "11"; XCTAssertThrowsError(try row.definition())
        row.initial = "10"; row.color = "red"; XCTAssertThrowsError(try row.definition())
        row.color = "#E5484D"; row.label = "123456789"; XCTAssertThrowsError(try row.definition())
        row.label = " 温度"; XCTAssertThrowsError(try row.definition())
        row.label = "温度"; XCTAssertNoThrow(try row.definition())
        var flag = NativeAttributeAuthorRow(); flag.key = "clue.ready"; flag.keyType = "flag"; flag.label = "就绪"; flag.maximum = "1"
        XCTAssertNoThrow(try flag.definition())
        flag.rules = [.init()]; XCTAssertThrowsError(try flag.definition())
    }
    func testClampAndResetDoNotSendAnObsoleteValue() throws {
        var rule = NativeAttributeAuthorRule(operation: "CLAMP", value: "-20")
        XCTAssertNil(try rule.encoded().object?["value"])
        rule.operation = "RESET"; XCTAssertNil(try rule.encoded().object?["value"])
        rule.operation = "ADD"; XCTAssertEqual(try rule.encoded().object?["value"], .number(-20))
    }
    func testReorderDoesNotRewritePresentationOrUnknownFields() throws {
        let second = NativeAttributeAuthorTestFixtures.extendedRow.replacingOccurrences(of: "counter.temp", with: "counter.other").replacingOccurrences(of: "\"sortOrder\":0", with: "\"sortOrder\":1")
        var draft = try NativeAttributeAuthorTestFixtures.draft(row: NativeAttributeAuthorTestFixtures.extendedRow + "," + second)
        try draft.reorder(["counter.other","counter.temp"])
        XCTAssertEqual(draft.rows.map(\.key), ["counter.other","counter.temp"])
        for row in try draft.changedRows() { XCTAssertEqual(Set(try row.changes().keys), ["sortOrder"]) }
    }
    func testLegacyAndDefinitionRowsDoNotUseJourneyInitialAttributeSchema() throws {
        let draft = try NativeAttributeAuthorTestFixtures.draft(row: NativeAttributeAuthorTestFixtures.extendedRow)
        var row = try XCTUnwrap(draft.rows.first); row.visible = false; row.persistScope = "topic"; row.display = "hidden"
        let fields = try row.definition()
        XCTAssertEqual(fields["initialValue"], .number(10)); XCTAssertNil(fields["initial"])
        XCTAssertNil(fields["schemaVersion"]); XCTAssertEqual(fields["persistScope"], .string("topic"))
    }
    func testFrozenSourceVersionAndDigestMustMatchOriginalBinding() throws {
        let digest = String(repeating: "a", count: 64)
        let binding = try NativeAttributeAuthorTestFixtures.binding(source: .locked(definitionVersion: 6, sourceConfigVersion: 4, sha256: digest))
        let raw = "{\"schemaVersion\":1,\"definitionVersion\":6,\"sourceConfigVersion\":4,\"sha256\":\"\(digest)\",\"definitions\":[\(NativeAttributeAuthorTestFixtures.row)]}"
        var draft = try NativeAttributeAuthorService.frozenDraft(binding: binding, source: Data(raw.utf8))
        XCTAssertThrowsError(try draft.add())
        XCTAssertThrowsError(try NativeAttributeAuthorService.frozenDraft(binding: binding, source: Data(raw.replacingOccurrences(of: "\"definitionVersion\":6", with: "\"definitionVersion\":7").utf8)))
        XCTAssertThrowsError(try NativeAttributeAuthorService.frozenDraft(binding: binding, source: Data(raw.replacingOccurrences(of: digest, with: String(repeating: "b", count: 64)).utf8)))
    }
    func testUnsentRecoveryNeedsExactAuthoritativeBaseline() throws {
        let old = try NativeAttributeAuthorTestFixtures.binding(), next = try NativeAttributeAuthorTestFixtures.binding(epoch: 2)
        var draft = try NativeAttributeAuthorTestFixtures.draft(old)
        var row = draft.rows[0]; row.label = "改名"; try draft.replace(row)
        let current = try NativeAttributeAuthorTestFixtures.draft(next)
        let recovered = try draft.recoverUnsent(binding: next, authoritative: current)
        XCTAssertEqual(recovered.rows[0].label, "改名"); XCTAssertEqual(recovered.binding.epoch, 2)
        let changed = try NativeAttributeAuthorTestFixtures.draft(next, row: NativeAttributeAuthorTestFixtures.row.replacingOccurrences(of: "\"initialValue\":10", with: "\"initialValue\":9"))
        XCTAssertThrowsError(try draft.recoverUnsent(binding: next, authoritative: changed))
    }
}
