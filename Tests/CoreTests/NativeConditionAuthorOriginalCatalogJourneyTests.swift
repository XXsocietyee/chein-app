import Foundation
import XCTest
#if canImport(QuestifyCore)
@testable import QuestifyCore
#elseif canImport(Questify)
@testable import Questify
#endif

/// Directory, selection, and local save against the installed original catalog.
/// The bytes below are a fixture, not a live edit-detail call. Swift is not run here.
@MainActor final class NativeConditionAuthorOriginalCatalogJourneyTests: XCTestCase {
    private let wire = #"{"code":200,"data":{"topic":{"id":20,"configVersion":3},"routeConditionAuthorCatalog":{"schemaVersion":1,"surface":"GLOBAL_ROUTE","available":true,"topicId":20,"configVersion":3,"nodes":[{"id":20,"label":"起点"},{"id":21,"label":"终点"}],"outcomes":[{"nodeId":20,"trigger":"CHOICE","code":"TRY"},{"nodeId":20,"trigger":"CHOICE","code":"WIN"}],"items":[{"id":"key","kind":"ITEM"},{"id":"medal","kind":"MEDAL"}],"types":[{"key":"counter.hp","type":"NUMBER"},{"key":"clue.word","type":"STRING"},{"key":"sys.passed.20","type":"NUMBER"}],"edges":["gate"],"rpg":null}}}"#

    private func catalog() throws -> NativeConditionAuthorOriginalCatalog {
        try NativeConditionAuthorOriginalCatalog(raw: Data(wire.utf8), topicID: 20, configVersion: 3)
    }

    func testDirectoryComesFromTheOriginalCatalog() async throws {
        let scope = NativeConditionAuthorWireTests.scope
        let directory = try catalog().catalog(for: scope)
        XCTAssertEqual(directory.nodes.map(\.id), ["20", "21"])
        XCTAssertEqual(directory.nodes.map(\.label), ["起点", "终点"])
        XCTAssertEqual(directory.triggers, [.init(id: "CHOICE", label: "CHOICE")])
        XCTAssertEqual(directory.outcomes.map(\.id), ["TRY", "WIN"])
        XCTAssertEqual(directory.sourceOutcomes["20"], [
            .init(triggerType: "CHOICE", code: "TRY", label: "TRY"),
            .init(triggerType: "CHOICE", code: "WIN", label: "WIN")
        ])
        XCTAssertNil(directory.sourceOutcomes["21"])
        XCTAssertEqual(directory.items.map(\.id), ["key"])
        XCTAssertEqual(directory.medals.map(\.id), ["medal"])
        XCTAssertEqual(directory.edges.map(\.id), ["gate"])
        XCTAssertNil(directory.rpg)
        let attributes = try catalog().attributes(for: scope)
        XCTAssertEqual(attributes.definitionVersion, "3")
        XCTAssertEqual(attributes.references.first { $0.key == "counter.hp" }?.writable, true)
        XCTAssertEqual(attributes.references.first { $0.key == "sys.passed.20" }?.writable, false)
        XCTAssertEqual(attributes.references.first { $0.key == "clue.word" }?.type, .string)
    }

    func testSelectionOutsideTheDeclaredOutcomeDoesNotSave() async throws {
        let host = try Host(catalog: catalog())
        let session = try NativeConditionAuthorSession(host: host)
        try replaceOutcome("OTHER", in: session)
        XCTAssertTrue(session.issues.contains { $0.code == "outcomeScope" })
        XCTAssertThrowsError(try session.saveOriginalLocalDraft()) { error in
            guard case NativeConditionAuthorError.blocked = error else { return XCTFail("\(error)") }
        }
        XCTAssertEqual(host.writes, 0)
        XCTAssertEqual(host.submits, 0)
        XCTAssertFalse(host.raw.contains("OTHER"))
        XCTAssertNotEqual(session.state, .localSaved)
    }

    func testLegalOutcomeSelectionSavesLocallyOnceAndDoesNotSubmit() async throws {
        let host = try Host(catalog: catalog())
        let session = try NativeConditionAuthorSession(host: host)
        XCTAssertTrue(session.issues.isEmpty)
        try replaceOutcome("WIN", in: session)
        XCTAssertTrue(session.issues.isEmpty)
        try session.saveOriginalLocalDraft()
        XCTAssertEqual(host.writes, 1)
        XCTAssertEqual(host.submits, 0)
        XCTAssertEqual(session.state, .localSaved)
        XCTAssertNil(session.authoritative)
        XCTAssertTrue(host.raw.contains("WIN"))
        XCTAssertFalse(session.document.hasChanges)
    }

    func testEdgeEditDoesNotReplaceCatalogMaterials() async throws {
        var draft = ProjectEditDraft(product: .city)
        var start = ProjectEditNode()
        start.localMetadata["id"] = .number(20)
        var end = ProjectEditNode()
        end.localMetadata["id"] = .number(21)
        var chapter = ProjectEditChapter()
        chapter.nodes = [end, start]
        draft.chapters = [chapter]
        draft.name = "标题"
        draft.preserved["routeGraphJson"] = .string(NativeConditionAuthorWireTests.graph)
        draft.preserved["configVersion"] = .number(3)
        draft.preserved["routeMode"] = .string("BRANCH_GRAPH")
        let materials = try NativeConditionAuthorOriginalCatalog.sourceMaterials(draft)
        draft.name = "只改标题"
        XCTAssertEqual(try NativeConditionAuthorOriginalCatalog.sourceMaterials(draft), materials)
        let selected = NativeConditionAuthorWireTests.graph.replacingOccurrences(of: #""outcomeCode":"TRY""#, with: #""outcomeCode":"WIN""#)
        draft.preserved["routeGraphJson"] = .string(selected)
        XCTAssertEqual(try NativeConditionAuthorOriginalCatalog.sourceMaterials(draft), materials)
        draft.chapters[0].nodes[0].localMetadata["id"] = .number(22)
        XCTAssertNotEqual(try NativeConditionAuthorOriginalCatalog.sourceMaterials(draft), materials)
    }

    func testMissingGraphDuplicateNodeAndNonV2DoNotBecomeACatalog() async throws {
        XCTAssertThrowsError(try NativeConditionAuthorOriginalCatalog.sourceMaterials(ProjectEditDraft())) { error in
            XCTAssertEqual(error as? NativeConditionAuthorError, .incompatibleVersion)
        }
        var draft = ProjectEditDraft()
        draft.preserved["routeGraphJson"] = .string(NativeConditionAuthorWireTests.graph)
        var first = ProjectEditNode(); first.localMetadata["id"] = .number(20)
        var second = ProjectEditNode(); second.localMetadata["id"] = .number(20)
        var chapter = ProjectEditChapter(); chapter.nodes = [first, second]
        draft.chapters = [chapter]
        XCTAssertThrowsError(try NativeConditionAuthorOriginalCatalog.sourceMaterials(draft)) { error in
            XCTAssertEqual(error as? NativeConditionAuthorError, .staleEditor)
        }
        let old = NativeConditionAuthorWireTests.graph.replacingOccurrences(of: #""routeExpressionVersion":2"#, with: #""routeExpressionVersion":1"#)
        draft.chapters[0].nodes[1].localMetadata["id"] = .number(21)
        draft.preserved["routeGraphJson"] = .string(old)
        XCTAssertThrowsError(try NativeConditionAuthorOriginalCatalog.sourceMaterials(draft)) { error in
            XCTAssertEqual(error as? NativeConditionAuthorError, .incompatibleVersion)
        }
    }

    func testUnavailableDuplicateOutcomeAndUnknownOperationAreRejected() async throws {
        XCTAssertThrowsError(try NativeConditionAuthorOriginalCatalog(raw: Data(wire.replacingOccurrences(of: #""available":true"#, with: #""available":false"#).utf8), topicID: 20, configVersion: 3)) { error in
            XCTAssertEqual(error as? NativeConditionAuthorError, .invalidJSON)
        }
        let duplicated = wire.replacingOccurrences(of: #"{"nodeId":20,"trigger":"CHOICE","code":"WIN"}"#, with: #"{"nodeId":20,"trigger":"CHOICE","code":"TRY"},{"nodeId":20,"trigger":"CHOICE","code":"TRY"}"#)
        XCTAssertThrowsError(try NativeConditionAuthorOriginalCatalog(raw: Data(duplicated.utf8), topicID: 20, configVersion: 3)) { error in
            XCTAssertEqual(error as? NativeConditionAuthorError, .invalidJSON)
        }
        let dice = wire.replacingOccurrences(of: #""rpg":null"#, with: #""rpg":{"operations":["DICE"],"checks":["check.a"],"results":["SUCCESS"],"conditions":["cond.a"],"equipment":["item.a"]}"#)
        XCTAssertThrowsError(try NativeConditionAuthorOriginalCatalog(raw: Data(dice.utf8), topicID: 20, configVersion: 3)) { error in
            XCTAssertEqual(error as? NativeConditionAuthorError, .invalidJSON)
        }
        let fractional = wire.replacingOccurrences(of: #""id":20,"configVersion":3"#, with: #""id":20.0,"configVersion":3"#)
        XCTAssertThrowsError(try NativeConditionAuthorOriginalCatalog(raw: Data(fractional.utf8), topicID: 20, configVersion: 3)) { error in
            XCTAssertEqual(error as? NativeConditionAuthorError, .invalidJSON)
        }
    }

    private func replaceOutcome(_ code: String, in session: NativeConditionAuthorSession) throws {
        let path = NativeConditionAuthorPath().field("edges").index(0).field("trigger")
        let before = try XCTUnwrap(NativeConditionAuthorTree.value(session.document.value, at: path))
        try session.replace(path: path, expected: before, replacement: .object([
            "type": .string("CHOICE"), "outcomeCode": .string(code)
        ]), revision: session.document.revision)
    }

    private final class Host: NativeConditionAuthorDraftHosting {
        let parsed: NativeConditionAuthorOriginalCatalog
        let scope = NativeConditionAuthorWireTests.scope
        var raw = NativeConditionAuthorWireTests.graph
        var writes = 0
        var submits = 0
        init(catalog: NativeConditionAuthorOriginalCatalog) { parsed = catalog }
        func capture() -> NativeConditionAuthorCapture? {
            .init(scope: scope, raw: raw, surface: .routeGraph, catalog: parsed.catalog(for: scope),
                  attributes: parsed.attributes(for: scope), canEdit: true)
        }
        func persistOriginalDraft(_ raw: String, replacing expected: NativeConditionAuthorCapture) throws -> NativeConditionAuthorCapture {
            guard scope == expected.scope, self.raw.utf8.elementsEqual(expected.raw.utf8) else { throw NativeConditionAuthorError.staleEditor }
            writes += 1
            self.raw = raw
            return capture()!
        }
    }
}
