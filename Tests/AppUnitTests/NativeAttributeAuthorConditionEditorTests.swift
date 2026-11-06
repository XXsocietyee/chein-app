import Foundation
import XCTest
#if canImport(Questify)
@testable import Questify
#endif

@MainActor final class NativeAttributeAuthorConditionEditorTests: XCTestCase {
    private final class Storage: TemplateAuthoringStorage {
        var values: [String: Data] = [:]
        var fail = false
        func read(_ key: String) throws -> Data? { values[key] }
        func write(_ data: Data, key: String) throws {
            if fail { throw NativeAttributeAuthorError.storage }; values[key] = data
        }
        func remove(_ key: String) throws { values[key] = nil }
    }
    private final class Transport: NativeAttributeAuthorTransport {
        var requests: [NativeAttributeAuthorRequest] = []
        func send(_ request: NativeAttributeAuthorRequest, finalCheck: @escaping @MainActor () throws -> Void) async throws -> (Data, Int) {
            try finalCheck(); requests.append(request)
            return (Data(#"{"code":200,"topicId":88,"configVersion":4,"data":[{"stateKey":"counter.temp","keyType":"counter","scope":"run","label":"Temp","initialValue":0,"minValue":0,"maxValue":10,"display":"number","sortOrder":0,"visible":true,"persistScope":"run","rules":[{"on":"CHECK_FAIL","op":"ADD","value":-1}]}]}"#.utf8), 200)
        }
    }
    private func binding(epoch: UInt64 = 1) throws -> NativeAttributeAuthorBinding {
        try .init(server: "https://fixture.invalid", namespace: "fixture", accountID: 7, epoch: epoch,
                  authorizationRevision: "0:0", topicID: 88, sourceConfigVersion: 4, requestScope: "")
    }
    private func scope(_ binding: NativeAttributeAuthorBinding) throws -> NativeConditionAuthorScope {
        .init(accountID: 7, namespace: "fixture", epoch: binding.epoch, authorizationRevision: "0:0",
              documentIdentity: try ProjectEditDraftIdentity(topicID: 88).bucket, sourceRevision: "4:0", incarnation: UUID())
    }
    private var catalog: NativeConditionAuthorCatalog { .init(nodes: [], items: [], medals: [], triggers: [], outcomes: []) }
    private func setup() async throws -> (NativeAttributeAuthorCoordinator, Storage, Transport, NativeAttributeAuthorConditionTarget) {
        let binding = try binding(), storage = Storage(), transport = Transport()
        let service = NativeAttributeAuthorService(transport: transport, current: { binding }, contract: .versionedCandidate)
        let coordinator = NativeAttributeAuthorCoordinator(binding: binding, service: service, store: .init(storage: storage))
        await coordinator.load()
        let row = try XCTUnwrap(coordinator.draft?.rows.first), rule = try XCTUnwrap(row.rules.first)
        let target = NativeAttributeAuthorConditionTarget(coordinator: coordinator, row: row, rule: rule)
        return (coordinator, storage, transport, target)
    }
    private func condition(_ value: Int = 1) -> ProjectEditJSON {
        .object(["op": .string("GTE"), "var": .string("counter.temp"), "value": .number(Decimal(value))])
    }
    func testConditionReturnsThroughOriginalDurableCoordinatorWithoutHTTPWrite() async throws {
        let (coordinator, storage, transport, target) = try await setup()
        let binding = coordinator.binding, scope = try scope(binding), catalog = catalog
        let host = try XCTUnwrap(NativeAttributeAuthorConditionDraftHost(condition: nil, binding: binding,
            registeredKeys: ["counter.temp"], source: { $0 == binding ? (scope, catalog) : nil },
            isCurrent: { target.isCurrent }, save: { target.save($0) }))
        let session = try NativeConditionAuthorSession(host: host)
        try session.replace(path: .init(), expected: .array([]), replacement: condition(), revision: 0)
        try session.saveOriginalLocalDraft()
        XCTAssertEqual(session.state, .localSaved)
        XCTAssertEqual(coordinator.draft?.rows.first?.rules.first?.condition, condition())
        let stored = try NativeAttributeAuthorLocalStore(storage: storage).load(binding: binding)
        XCTAssertEqual(stored?.draft.rows.first?.rules.first?.condition, condition())
        XCTAssertNil(stored?.pending); XCTAssertTrue(transport.requests.allSatisfy { !$0.mutates })
        XCTAssertTrue(target.isCurrent)
    }
    func testFailedOriginalStorageNeverReportsConditionSaved() async throws {
        let (coordinator, storage, _, target) = try await setup()
        let binding = coordinator.binding, scope = try scope(binding), catalog = catalog
        let host = try XCTUnwrap(NativeAttributeAuthorConditionDraftHost(condition: nil, binding: binding,
            registeredKeys: ["counter.temp"], source: { _ in (scope, catalog) }, isCurrent: { target.isCurrent }, save: { target.save($0) }))
        let session = try NativeConditionAuthorSession(host: host)
        try session.replace(path: .init(), expected: .array([]), replacement: condition(), revision: 0)
        storage.fail = true
        XCTAssertThrowsError(try session.saveOriginalLocalDraft())
        XCTAssertNotEqual(session.state, .localSaved); XCTAssertNil(coordinator.draft?.rows.first?.rules.first?.condition)
        XCTAssertNil(coordinator.pending)
    }
    func testChangedRuleCannotBeOverwrittenByOldEditorCallback() async throws {
        let (coordinator, _, _, target) = try await setup()
        var row = try XCTUnwrap(coordinator.draft?.rows.first)
        row.rules[0].condition = condition(2); XCTAssertTrue(coordinator.replace(row))
        XCTAssertFalse(target.isCurrent); XCTAssertFalse(target.save(condition(3)))
        XCTAssertEqual(coordinator.draft?.rows.first?.rules.first?.condition, condition(2))
    }
    func testConcurrentRowMetadataCannotBeResurrectedByParentFormOnChange() async throws {
        let (coordinator, _, _, target) = try await setup()
        var row = try XCTUnwrap(coordinator.draft?.rows.first)
        row.label = "New"; XCTAssertTrue(coordinator.replace(row))
        XCTAssertFalse(target.isCurrent); XCTAssertFalse(target.save(condition()))
        XCTAssertEqual(coordinator.draft?.rows.first?.label, "New")
        XCTAssertNil(coordinator.draft?.rows.first?.rules.first?.condition)
    }
    func testRemovingOrCopyingRuleDoesNotReuseOldTarget() async throws {
        let (coordinator, _, _, target) = try await setup()
        var row = try XCTUnwrap(coordinator.draft?.rows.first)
        row.rules = [row.rules[0].duplicate()]; XCTAssertTrue(coordinator.replace(row))
        XCTAssertFalse(target.isCurrent); XCTAssertFalse(target.save(condition()))
    }
    func testPendingOrRetiredOwnerCannotReceiveLateCondition() async throws {
        let (coordinator, storage, _, target) = try await setup()
        let original = storage.values
        coordinator.retire()
        XCTAssertFalse(target.isCurrent); XCTAssertFalse(target.save(condition()))
        XCTAssertEqual(storage.values, original)
    }
    func testAttributeEdgePickerUsesExactOriginalCatalogRatherThanExpressionRoot() throws {
        let binding = try binding(), scope = try scope(binding)
        var catalog = catalog; catalog.edges = [.init(id: "original-edge", label: "Original")]
        let host = try XCTUnwrap(NativeAttributeAuthorConditionDraftHost(condition: nil, binding: binding,
            registeredKeys: ["counter.temp"], source: { _ in (scope, catalog) }, isCurrent: { true }, save: { _ in true }))
        let controller = NativeConditionAuthorController(host: host)
        XCTAssertEqual(controller.edgeReferences, catalog.edges)
        catalog.edges = []
        XCTAssertTrue(controller.edgeReferences.isEmpty)
    }
    func testSameIdentityCatalogChangeRetiresConditionHost() throws {
        let binding = try binding(), scope = try scope(binding)
        var catalog = catalog
        let host = try XCTUnwrap(NativeAttributeAuthorConditionDraftHost(condition: nil, binding: binding,
            registeredKeys: ["counter.temp"], source: { _ in (scope, catalog) }, isCurrent: { true }, save: { _ in XCTFail("stale save"); return true }))
        catalog.edges = [.init(id: "new-edge", label: "New")]
        XCTAssertNil(host.capture())
    }
    func testAccountEpochChangeRetiresConditionHost() throws {
        let binding = try binding(), captured = try scope(binding), catalog = catalog
        var current: NativeConditionAuthorScope? = captured
        let host = try XCTUnwrap(NativeAttributeAuthorConditionDraftHost(condition: nil, binding: binding,
            registeredKeys: ["counter.temp"], source: { _ in current.map { ($0, catalog) } }, isCurrent: { true }, save: { _ in XCTFail("stale save"); return true }))
        current = try scope(self.binding(epoch: 2))
        XCTAssertNil(host.capture())
    }
    func testWrongSourceOrMalformedKeysCannotCreateEditor() throws {
        let binding = try binding(), scope = try scope(binding), catalog = catalog
        for keys in [["counter.temp", "counter.temp"], ["sys.party.size"], ["counter."]] {
            XCTAssertNil(NativeAttributeAuthorConditionDraftHost(condition: nil, binding: binding, registeredKeys: keys,
                source: { _ in (scope, catalog) }, isCurrent: { true }, save: { _ in XCTFail("invalid save"); return true }))
        }
        XCTAssertNil(NativeAttributeAuthorConditionDraftHost(condition: nil, binding: binding, registeredKeys: ["counter.temp"],
            source: { _ in nil }, isCurrent: { true }, save: { _ in true }))
    }
}
