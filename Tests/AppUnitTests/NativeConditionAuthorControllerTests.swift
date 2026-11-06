import Foundation
import XCTest
#if canImport(Questify)
@testable import Questify
#endif

@MainActor final class NativeConditionAuthorControllerTests: XCTestCase {
    private final class Host: NativeConditionAuthorDraftHosting {
        var scope = NativeConditionAuthorScope(accountID: 8, namespace: "app", epoch: 1, authorizationRevision: "1", documentIdentity: "topic:1", sourceRevision: "1", incarnation: UUID())
        var raw = #"{"schemaVersion":1,"routeExpressionVersion":2,"startNodeId":1,"terminalNodeIds":[2],"variables":{"counter.hp":1},"edges":[{"id":"e","fromNodeId":1,"toNodeId":2,"trigger":{"type":"CHOICE","outcomeCode":"TRY"},"conditions":[],"effects":[]}]}"#
        var editable = true
        var saves = 0
        func capture() -> NativeConditionAuthorCapture? {
            .init(scope: scope, raw: raw, surface: .routeGraph,
                  catalog: .init(nodes: [.init(id: "1", label: "A"), .init(id: "2", label: "B")], items: [], medals: [], triggers: [.init(id: "CHOICE", label: "Choice")], outcomes: [.init(id: "TRY", label: "Try")], sourceOutcomes: ["1": [.init(triggerType: "CHOICE", code: "TRY", label: "Try")]]), attributes: nil, canEdit: editable)
        }
        func persistOriginalDraft(_ raw: String, replacing expected: NativeConditionAuthorCapture) throws -> NativeConditionAuthorCapture {
            guard editable, expected.scope == scope, self.raw == expected.raw else { throw NativeConditionAuthorError.staleEditor }
            self.raw = raw; saves += 1; return capture()!
        }
    }
    func testPickerCannotOfferPassedFactsForWritableEffects() {
        let model = NativeConditionAuthorController(host: Host())
        XCTAssertTrue(model.attributes.contains { $0.key == "sys.passed.1" && !$0.writable })
        let writable = model.attributes.filter { $0.writable && !$0.key.hasPrefix("sys.passed.") }
        XCTAssertFalse(writable.contains { $0.key.hasPrefix("sys.passed.") })
    }
    func testControllerSavesThroughOriginalHost() throws {
        let host = Host(), model = NativeConditionAuthorController(host: host)
        let path = NativeConditionAuthorPath().field("edges").index(0).field("conditions")
        model.append(.object(["op": .string("HAS_TAG"), "value": .string("tag.open")]), to: path)
        XCTAssertTrue(model.issues.isEmpty); model.save()
        XCTAssertEqual(host.saves, 1); XCTAssertNil(model.errorKey)
    }
    func testStaleSheetRevisionCannotEditReorderedRow() throws {
        let host = Host(), model = NativeConditionAuthorController(host: host)
        let path = NativeConditionAuthorPath().field("edges").index(0).field("conditions")
        let old = try XCTUnwrap(model.value(path)), revision = try XCTUnwrap(model.document?.revision)
        model.append(.object(["op": .string("HAS_TAG"), "value": .string("tag.a")]), to: path)
        XCTAssertFalse(model.replace(path, expected: old, with: .array([]), revision: revision))
        XCTAssertEqual(model.value(path)?.nativeConditionArray?.count, 1)
    }
    func testAccountSwitchRedactsAllSourceAndPreventsWrites() {
        let host = Host(), model = NativeConditionAuthorController(host: host)
        host.scope = .init(accountID: 9, namespace: "other", epoch: 2, authorizationRevision: "2", documentIdentity: "topic:2", sourceRevision: "2", incarnation: UUID())
        model.refresh(); XCTAssertNil(model.document); XCTAssertTrue(model.attributes.isEmpty)
        XCTAssertTrue(model.issues.isEmpty); model.save(); XCTAssertEqual(host.saves, 0)
    }
    func testDraftLockDoesNotClearExistingSource() {
        let host = Host(), model = NativeConditionAuthorController(host: host), original = host.raw
        host.editable = false; model.save()
        XCTAssertEqual(host.raw, original); XCTAssertEqual(host.saves, 0); XCTAssertFalse(model.canEdit)
    }
}
