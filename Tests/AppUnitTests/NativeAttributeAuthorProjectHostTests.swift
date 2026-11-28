import Foundation
import XCTest
#if canImport(Questify)
@testable import Questify
#endif

/// Uses the real private edit-detail decoder, ProjectEditCoordinator and ProjectEditModel.
/// Source only until the original App target is compiled and tested with Xcode.
@MainActor final class NativeAttributeAuthorProjectHostTests: XCTestCase {
    private final class Owner {
        var session: ProjectEditSession? = try? .init(accountID: 7, epoch: 1, storageNamespace: "fixture")
    }
    private final class Reader: ProjectEditServing {
        var authority: ProjectEditServiceAuthority { .readOnly }
        var snapshot: ProjectEditSnapshot
        var reads = 0
        var writes = 0
        init(snapshot: ProjectEditSnapshot) { self.snapshot = snapshot }
        func preflight(topicID: Int?, session: ProjectEditSession) async throws -> ProjectEditPreflight {
            reads += 1
            return .init(capability:.init(canProPublish:false,remaining:nil),snapshot:snapshot)
        }
        func submit(_ operation: ProjectEditPending, session: ProjectEditSession) async -> ProjectEditWriteOutcome {
            writes += 1; return .notSent
        }
        func terminalReceipt(operationID: UUID, session: ProjectEditSession) async throws -> ProjectEditWriteOutcome? { nil }
    }
    private func setup(version: Int? = 4, scope: ProjectEditScope = .full, owner: ProjectEditOwner = .personal)
        async throws -> (ProjectEditModel, Owner, Reader, ProjectEditMemoryStorage) {
        let ownerSession = Owner(), storage = ProjectEditMemoryStorage()
        var topic: [String:ProjectEditJSON] = ["id":.number(88),"productType":.number(1),"updateTime":.string("source-4")]
        if let version { topic["configVersion"] = .number(Decimal(version)) }
        let data = try JSONEncoder().encode(ProjectEditJSON.object(["code":.number(200),"data":.object([
            "topic":.object(topic),"editScope":.string(scope.rawValue),"chapters":.array([]),"tickets":.array([])])]))
        let snapshot = try ProjectEditContract.decodeEditDetail(data, expectedTopicID:88, owner:owner)
        let reader = Reader(snapshot:snapshot)
        let model = ProjectEditModel(coordinator:.init(initial:snapshot,service:reader,store:.init(storage:storage),currentSession:{ownerSession.session}))
        await model.load()
        return (model,ownerSession,reader,storage)
    }
    private func configuration() throws -> APIConfiguration { try .init(baseURL:URL(string:"https://example.com")!) }
    func testSourceBindingComesFromTheSameOriginalModelWithoutAnyWrite() async throws {
        let (model,owner,reader,storage) = try await setup()
        let source = try XCTUnwrap(NativeConditionAuthorProjectReadbackAdapter.Source.capture(model:model))
        let host = try XCTUnwrap(NativeAttributeAuthorProjectHost(model:model,configuration:configuration()))
        XCTAssertEqual(host.scope,source.scope); XCTAssertEqual(host.binding.accountID,Int64(try XCTUnwrap(owner.session).accountID))
        XCTAssertEqual(host.binding.topicID,88); XCTAssertEqual(host.binding.sourceConfigVersion,4)
        XCTAssertEqual(host.binding.authorizationRevision,"0:0"); XCTAssertEqual(host.currentBinding(),host.binding)
        XCTAssertEqual(reader.writes,0); XCTAssertTrue(storage.data.isEmpty)
    }
    func testMissingVersionOrNonFullScopeDoesNotMintBinding() async throws {
        let (missing,_,_,_) = try await setup(version:nil)
        XCTAssertNil(try NativeAttributeAuthorProjectHost(model:missing,configuration:configuration()))
        let (limited,_,_,_) = try await setup(scope:.whitelist)
        XCTAssertNil(try NativeAttributeAuthorProjectHost(model:limited,configuration:configuration()))
    }
    func testMerchantScopeComesFromOriginalOwnerRatherThanAViewFlag() async throws {
        let (model,_,_,_) = try await setup(owner:.merchant)
        let host = try XCTUnwrap(NativeAttributeAuthorProjectHost(model:model,configuration:configuration()))
        XCTAssertEqual(host.binding.requestScope,"MERCHANT")
        model.draft.owner = .personal
        XCTAssertNil(host.currentBinding())
    }
    func testAccountEpochChangeRetiresCapturedHostWithoutAlteringJournal() async throws {
        let (model,owner,reader,storage) = try await setup()
        let host = try XCTUnwrap(NativeAttributeAuthorProjectHost(model:model,configuration:configuration()))
        let before = storage.data
        owner.session = try .init(accountID:7,epoch:2,storageNamespace:"fixture")
        XCTAssertNil(host.currentBinding()); XCTAssertEqual(storage.data,before); XCTAssertEqual(reader.writes,0)
    }
    func testSameByteDraftSetterRetiresTheCapturedSourceIncarnation() async throws {
        let (model,_,_,_) = try await setup()
        let host = try XCTUnwrap(NativeAttributeAuthorProjectHost(model:model,configuration:configuration()))
        let unchanged = model.draft; model.draft = unchanged
        XCTAssertNil(host.currentBinding())
        let newHost = try XCTUnwrap(NativeAttributeAuthorProjectHost(model:model,configuration:configuration()))
        XCTAssertNotEqual(newHost.scope,host.scope)
    }
    func testChangingLocalVersionCannotPretendTheOriginalReadAdvanced() async throws {
        let (model,_,_,_) = try await setup()
        let host = try XCTUnwrap(NativeAttributeAuthorProjectHost(model:model,configuration:configuration()))
        model.draft.preserved["configVersion"] = .number(5)
        XCTAssertNil(host.currentBinding())
        XCTAssertNil(try NativeAttributeAuthorProjectHost(model:model,configuration:configuration()))
    }
    private final class AttributeStorage: TemplateAuthoringStorage {
        var values: [String: Data] = [:]
        func read(_ key: String) throws -> Data? { values[key] }
        func write(_ data: Data, key: String) throws { values[key] = data }
        func remove(_ key: String) throws { values[key] = nil }
    }
    private final class PrivateWire: HTTPTransport {
        var data = Data(), requests: [URLRequest] = []
        var afterRead: (() -> Void)?
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request); afterRead?(); return (data, 200)
        }
    }
    private func privateService(_ owner: Owner, _ wire: PrivateWire) throws -> ProjectEditHTTPService {
        try .init(configuration: configuration(), transport: wire, owner: .personal, currentCredentials: {
            owner.session.flatMap { try? .init(session: $0, token: "synthetic-entry-token") }
        })
    }
    private func privateDetail(published: Bool = false) throws -> Data {
        var topic: [String: ProjectEditJSON] = ["id": .number(88), "configVersion": .number(4),
            "productType": .number(1), "updateTime": .string("source-4"), "routeGraphJson": .null]
        if published {
            let attributes: ProjectEditJSON = .object(["schemaVersion": .number(1), "definitionVersion": .number(6),
                "sourceConfigVersion": .number(3), "sha256": .string(String(repeating: "a", count: 64)), "definitions": .array([])])
            let graph = try NativeAttributeAuthorWire.encode(.object(["runtimeSnapshotVersion": .number(1), "dynamicAttributes": attributes]))
            topic["publishedRouteGraphJson"] = .string(String(decoding: graph, as: UTF8.self))
            topic["publishedConfigVersion"] = .number(6)
        }
        return try NativeAttributeAuthorWire.encode(.object(["code": .number(200), "data": .object([
            "topic": .object(topic), "editScope": .string("FULL"), "themeRuntimeConfig": .null,
            "chapters": .array([]), "tickets": .array([])])]))
    }
    private func localDraft(_ binding: NativeAttributeAuthorBinding) throws -> NativeAttributeAuthorDraft {
        let row = #"[{"stateKey":"counter.temp","keyType":"counter","scope":"run","label":"Temp","initialValue":0,"minValue":0,"maxValue":10,"display":"number","sortOrder":0,"visible":true,"persistScope":"run","rules":[{"on":"CHECK_FAIL","op":"ADD","value":1}]}]"#
        return try .init(binding: binding, rawRows: Data(row.utf8))
    }
    func testFactoryLocalDraftCatalogAndConditionReturnUseOriginalPrivateReadAndStore() async throws {
        let (model, owner, original, _) = try await setup()
        let project = try XCTUnwrap(NativeAttributeAuthorProjectHost(model: model, configuration: configuration()))
        let wire = PrivateWire(); wire.data = try privateDetail()
        let catalog = NativeAttributeAuthorConditionCatalogReader(service: try privateService(owner, wire),
            currentSession: { owner.session }, currentSource: {
                guard project.currentBinding() == project.binding else { return nil }
                return .init(binding: project.binding, scope: project.scope, baseRevision: model.draft.baseRevision)
            })
        let storage = AttributeStorage(), store = NativeAttributeAuthorLocalStore(storage: storage)
        XCTAssertNil(project.localDraftDependencies(storage: storage, conditionCatalogReader: catalog, currentAccess: { true }))
        try store.save(.init(draft: localDraft(project.binding)))
        let factory = NativeAttributeAuthorProjectFactory(make: { _ in
            project.localDraftDependencies(storage: storage, conditionCatalogReader: catalog, currentAccess: { true })
        })
        let dependencies = try XCTUnwrap(factory.make(model))
        let coordinator = NativeAttributeAuthorCoordinator(binding: dependencies.binding, service: dependencies.service,
            store: dependencies.store, localDraftOnly: dependencies.localDraftOnly)
        await coordinator.load()
        let row = try XCTUnwrap(coordinator.draft?.rows.first), rule = try XCTUnwrap(row.rules.first)
        let target = NativeAttributeAuthorConditionTarget(coordinator: coordinator, row: row, rule: rule)
        let editor = try XCTUnwrap(dependencies.conditionEditor as? NativeAttributeAuthorConditionEditor)
        let host = try await editor.loadHost(condition: rule.condition, binding: project.binding,
            registeredKeys: [row.key], isCurrent: { target.isCurrent }, save: { target.save($0) })
        let session = try NativeConditionAuthorSession(host: host)
        let condition: ProjectEditJSON = .object(["op": .string("GTE"), "var": .string(row.key), "value": .number(1)])
        try session.replace(path: .init(), expected: .array([]), replacement: condition, revision: 0)
        try session.saveOriginalLocalDraft()
        XCTAssertEqual(session.state, .localSaved)
        XCTAssertEqual(try store.load(binding: project.binding)?.draft.rows.first?.rules.first?.condition, condition)
        XCTAssertNil(try store.load(binding: project.binding)?.pending)
        XCTAssertEqual(wire.requests.count, 1); XCTAssertEqual(wire.requests.first?.url?.path, "/api/topic/edit-detail")
        XCTAssertEqual(original.writes, 0); XCTAssertFalse(coordinator.canSave)
    }
    func testPublishedHostLoadsLockedSnapshotWithoutLocalStoreOrWriter() async throws {
        let (model, owner, original, _) = try await setup()
        let project = try XCTUnwrap(NativeAttributeAuthorProjectHost(model: model, configuration: configuration()))
        let wire = PrivateWire(); wire.data = try privateDetail(published: true)
        let reader = NativeAttributeAuthorPublishedReader(service: try privateService(owner, wire), currentSession: { owner.session })
        var access = true
        let host = NativeAttributeAuthorPublishedHost(project: project, reader: reader, currentAccess: { access })
        let coordinator = try await host.load()
        XCTAssertTrue(coordinator.binding.isLocked); XCTAssertEqual(coordinator.binding.sourceConfigVersion, 3)
        XCTAssertNotNil(coordinator.draft); XCTAssertFalse(coordinator.canEdit); XCTAssertFalse(coordinator.canReadChecks)
        XCTAssertEqual(wire.requests.count, 1); XCTAssertEqual(original.writes, 0)
        access = false; XCTAssertFalse(host.isCurrent)
        do { _ = try await host.load(); XCTFail("revoked source") } catch {}
        XCTAssertEqual(wire.requests.count, 1)
    }
    func testPublishedHostRejectsLateOriginalProjectRetirement() async throws {
        let (model, owner, _, _) = try await setup()
        let project = try XCTUnwrap(NativeAttributeAuthorProjectHost(model: model, configuration: configuration()))
        let wire = PrivateWire(); wire.data = try privateDetail(published: true)
        wire.afterRead = { model.draft.name = "Changed" }
        let reader = NativeAttributeAuthorPublishedReader(service: try privateService(owner, wire), currentSession: { owner.session })
        let host = NativeAttributeAuthorPublishedHost(project: project, reader: reader, currentAccess: { true })
        do { _ = try await host.load(); XCTFail("late source must not mount") } catch {}
        XCTAssertFalse(host.isCurrent)
    }

    // Controlled owner/child lifetime tests. These exercise the real model and original
    // stores; they are not evidence that a SwiftUI sheet has run on a device.
    func testOriginalParentLeaveChangesIncarnationAndInvalidatesBothChildSources() async throws {
        let (model, _, reader, _) = try await setup()
        let visit = try XCTUnwrap(NativeAuthorProjectVisit(model: model))
        let attribute = try XCTUnwrap(NativeAttributeAuthorProjectHost(model: model, configuration: configuration()))
        let incarnation = model.editorIncarnation, reads = reader.reads
        XCTAssertTrue(visit.isCurrent); XCTAssertEqual(attribute.currentBinding(), attribute.binding)
        model.leave() // The exact existing ProjectEditView.onDisappear target.
        XCTAssertNotEqual(model.editorIncarnation, incarnation)
        XCTAssertFalse(visit.isCurrent); XCTAssertNil(attribute.currentBinding())
        let requested = await visit.requestOriginalReadback()
        XCTAssertFalse(requested); XCTAssertEqual(reader.reads, reads); XCTAssertEqual(reader.writes, 0)
    }
    private func conditionHost(_ model: ProjectEditModel, visit: NativeAuthorProjectVisit) -> NativeAuthorConditionVisitHost {
        NativeAuthorConditionVisitHost(original: model.nativeConditionAuthorHost(attributes: nil, catalog: { _ in
            .init(nodes: [.init(id: "1", label: "A"), .init(id: "2", label: "B")], items: [], medals: [],
                  triggers: [.init(id: "CHOICE", label: "Choice")], outcomes: [.init(id: "TRY", label: "Try")],
                  sourceOutcomes: ["1": [.init(triggerType: "CHOICE", code: "TRY", label: "Try")]])
        }), visit: visit)
    }
    private var graph: String {
        #"{"schemaVersion":1,"routeExpressionVersion":2,"startNodeId":1,"terminalNodeIds":[2],"variables":{"counter.hp":1},"edges":[{"id":"e","fromNodeId":1,"toNodeId":2,"trigger":{"type":"CHOICE","outcomeCode":"TRY"},"conditions":[],"effects":[]}]}"#
    }
    func testSavedConditionReturnsToSameParentAndOldCloseCannotEditReopenedVisit() async throws {
        let (model, _, reader, storage) = try await setup()
        model.draft.preserved["routeGraphJson"] = .string(graph)
        let visit = try XCTUnwrap(NativeAuthorProjectVisit(model: model)), incarnation = model.editorIncarnation
        let host = conditionHost(model, visit: visit)
        let controller = NativeConditionAuthorController(host: host)
        visit.onRetire { [weak controller] in controller?.retire() }
        controller.append(.object(["op": .string("HAS_TAG"), "value": .string("tag.open")]),
                          to: NativeConditionAuthorPath().field("edges").index(0).field("conditions"))
        XCTAssertTrue(controller.issues.isEmpty); controller.save()
        XCTAssertEqual(controller.session?.state, .localSaved)
        XCTAssertTrue(visit.isCurrent); XCTAssertEqual(model.editorIncarnation, incarnation)
        let expected = try XCTUnwrap(host.capture()), saved = model.draft, bytes = storage.data, reads = reader.reads
        visit.retire() // The same close/background callback used by the presentation owner.
        XCTAssertTrue(model.ownsVisit); XCTAssertTrue(model.fullEdit)
        XCTAssertEqual(model.editorIncarnation, incarnation); XCTAssertEqual(model.draft, saved)
        XCTAssertNil(controller.document); XCTAssertNil(host.capture())
        XCTAssertThrowsError(try host.persistOriginalDraft(graph, replacing: expected))
        let reopened = try XCTUnwrap(NativeAuthorProjectVisit(model: model))
        XCTAssertTrue(reopened.isCurrent); XCTAssertNotEqual(reopened.id, visit.id)
        visit.retire(); XCTAssertTrue(reopened.isCurrent); XCTAssertFalse(visit.isCurrent)
        XCTAssertEqual(storage.data, bytes); XCTAssertEqual(reader.reads, reads); XCTAssertEqual(reader.writes, 0)
    }
    func testIdentityChangeCannotUseRetiredChildToRereadOrReplaceOriginalDraft() async throws {
        let (model, owner, reader, storage) = try await setup()
        let visit = try XCTUnwrap(NativeAuthorProjectVisit(model: model)), draft = model.draft
        let reads = reader.reads, bytes = storage.data
        owner.session = try .init(accountID: 9, epoch: 2, storageNamespace: "other")
        XCTAssertFalse(visit.isCurrent); visit.retire()
        let requested = await visit.requestOriginalReadback()
        XCTAssertFalse(requested); XCTAssertEqual(reader.reads, reads)
        XCTAssertEqual(model.draft, draft); XCTAssertEqual(storage.data, bytes); XCTAssertEqual(reader.writes, 0)
    }
    func testOriginalReadbackPreservesDirtyDraftAndStopsWhenOriginalLocalSaveFails() async throws {
        let (model, _, reader, storage) = try await setup()
        let visit = try XCTUnwrap(NativeAuthorProjectVisit(model: model))
        model.draft.name = "Unsaved original project"; let dirty = model.draft, reads = reader.reads
        visit.retire(); storage.failWrites = true
        let failed = await visit.requestOriginalReadback()
        XCTAssertFalse(failed); XCTAssertEqual(model.draft, dirty); XCTAssertEqual(reader.reads, reads)
        XCTAssertTrue(storage.data.isEmpty)
        storage.failWrites = false
        let requested = await visit.requestOriginalReadback()
        XCTAssertTrue(requested); XCTAssertEqual(reader.reads, reads + 1)
        let bytes = try XCTUnwrap(storage.data.values.first)
        XCTAssertEqual(try JSONDecoder().decode(ProjectEditEnvelope.self, from: bytes).draft, dirty)
        XCTAssertTrue(model.hasRestore); XCTAssertFalse(visit.isCurrent); XCTAssertEqual(reader.writes, 0)
    }
    private final class AttributeWire: NativeAttributeAuthorTransport {
        let response: (NativeAttributeAuthorRequest) throws -> Data
        var requests: [NativeAttributeAuthorRequest] = []
        init(response: @escaping (NativeAttributeAuthorRequest) throws -> Data) { self.response = response }
        func send(_ request: NativeAttributeAuthorRequest, finalCheck: @escaping @MainActor () throws -> Void) async throws -> (Data, Int) {
            try finalCheck(); requests.append(request); return (try response(request), 200)
        }
    }
    func testActualConfirmedAttributeReceiptSurvivesChildRetirementThenUsesOriginalProjectReader() async throws {
        let (model, _, reader, _) = try await setup()
        let project = try XCTUnwrap(NativeAttributeAuthorProjectHost(model: model, configuration: configuration()))
        let sourceDraft = try localDraft(project.binding)
        let originalRow = try XCTUnwrap(sourceDraft.rows.first).definition()
        var editedRow = originalRow; editedRow["label"] = .string("Edited")
        let wire = AttributeWire { request in
            let validation = request.path.hasSuffix("/validate"), mutation = request.mutates && !validation
            let data: ProjectEditJSON = request.method == .get ? .array([.object(originalRow)]) :
                .object(["definitions": .array([.object(editedRow)]), "warnings": .array([]),
                         "keys": .array([.object(editedRow)])])
            var root: [String: ProjectEditJSON] = ["code": .number(200), "topicId": .number(88),
                "configVersion": .number(mutation ? 5 : 4), "data": data]
            // Stale wire: a versioned mutation is only `.confirmed` when the reply carries the original
            // request receipt (`NativeAttributeAuthorService.submitWithReceipt` -> `verifyOriginalReceipt`,
            // protocol `original-attribute-author-request-v1`, in the 02c68098f tree). Without it the
            // coordinator correctly stays `.unknown`. Same proof shape as
            // Tests/CoreTests/NativeAttributeAuthorReceiptEvidencePreservationTests.swift.
            if mutation {
                let receipt: [String: ProjectEditJSON] = [
                    "protocolVersion": .string(NativeAttributeAuthorRequest.originalRequestProtocol),
                    "requestId": .string(request.requestKey.uuidString.lowercased()),
                    "payloadSHA256": .string(request.originalPayloadSHA256),
                    "method": .string(request.method.rawValue),
                    "topicId": .number(Decimal(request.binding.topicID)),
                    "expectedConfigVersion": .number(Decimal(request.binding.sourceConfigVersion)),
                    "state": .string("COMMITTED")]
                root["requestReceipt"] = .object(receipt)
            }
            return try NativeAttributeAuthorWire.encode(.object(root))
        }
        let storage = AttributeStorage()
        let dependencies = try XCTUnwrap(project.dependencies(transport: wire, storage: storage))
        let coordinator = NativeAttributeAuthorCoordinator(binding: dependencies.binding, service: dependencies.service, store: dependencies.store)
        let visit = try XCTUnwrap(NativeAuthorProjectVisit(model: model))
        let presentation = NativeAttributeAuthorProjectPresentation(visit: visit, content: .editing(dependencies, coordinator))
        await coordinator.load()
        var row = try XCTUnwrap(coordinator.draft?.rows.first); row.label = "Edited"
        XCTAssertTrue(coordinator.replace(row)); await coordinator.prepareSave(); await coordinator.confirm()
        XCTAssertEqual(coordinator.phase, .confirmed)
        let retired = try XCTUnwrap(coordinator.retiredSourceBinding)
        XCTAssertEqual(retired.sourceConfigVersion, 5)
        presentation.sourceRetired(retired); XCTAssertTrue(presentation.needsOriginalReadback)
        let journal = storage.values, reads = reader.reads
        visit.retire(); XCTAssertEqual(coordinator.phase, .retired)
        XCTAssertTrue(presentation.needsOriginalReadback)
        var latest = reader.snapshot.draft; latest.preserved["configVersion"] = .number(5); latest.baseRevision = "source-5"
        reader.snapshot = .init(topicID: 88, scope: .full, draft: latest)
        let requested = await visit.requestOriginalReadback()
        XCTAssertTrue(requested); XCTAssertEqual(reader.reads, reads + 1)
        XCTAssertEqual(model.draft.preserved["configVersion"], .number(5))
        XCTAssertEqual(storage.values, journal); XCTAssertEqual(reader.writes, 0)
        XCTAssertEqual(wire.requests.map(\.path), ["api/topic/attribute-author", "api/topic/attribute-author/validate", "api/topic/attribute-author"])
    }
    func testUnknownAttributeJournalDoesNotBecomeSourceRetirementOrTriggerProjectReadback() async throws {
        let (model, _, reader, _) = try await setup()
        let project = try XCTUnwrap(NativeAttributeAuthorProjectHost(model: model, configuration: configuration()))
        var draft = try localDraft(project.binding), row = try XCTUnwrap(draft.rows.first)
        row.label = "Pending"; try draft.replace(row)
        let requestKey = UUID()
        let request = try NativeAttributeAuthorRequest.definitionsWrite(draft, key: requestKey)
        var pending = NativeAttributeAuthorPending(request: request, draft: draft)
        // Stale fixture: `NativeAttributeAuthorLocalStore.save` rejects a versioned definitions write
        // without its exact validate target (`validatedTarget`, 02c68098f tree). Record the same
        // target the original validate step would have produced so the journal can be stored.
        let editedDefinition = try row.definition()
        let target: [String: ProjectEditJSON] = ["code": .number(200), "topicId": .number(88), "configVersion": .number(4),
            "data": .object(["definitions": .array([.object(editedDefinition)]), "warnings": .array([])])]
        pending.validatedTarget = try NativeAttributeAuthorValidatedTarget(draft: draft, requestKey: requestKey,
            response: try NativeAttributeAuthorWire.encode(.object(target)))
        let storage = AttributeStorage(), store = NativeAttributeAuthorLocalStore(storage: storage)
        try store.save(.init(draft: draft, pending: pending)); let journal = storage.values
        let service = NativeAttributeAuthorService(current: { project.currentBinding() }, contract: .versionedCandidate)
        let dependencies = NativeAttributeAuthorDependencies(binding: project.binding, service: service, store: store,
            projectFlow: nil, conditionEditor: nil)
        let coordinator = NativeAttributeAuthorCoordinator(binding: project.binding, service: service, store: store)
        let visit = try XCTUnwrap(NativeAuthorProjectVisit(model: model))
        let presentation = NativeAttributeAuthorProjectPresentation(visit: visit, content: .editing(dependencies, coordinator))
        await coordinator.load(); XCTAssertEqual(coordinator.phase, .unknown)
        let reads = reader.reads
        presentation.sourceRetired(project.binding) // Not a genuine coordinator retirement result.
        XCTAssertFalse(presentation.needsOriginalReadback)
        visit.retire(); XCTAssertEqual(coordinator.phase, .retired)
        XCTAssertFalse(presentation.needsOriginalReadback); XCTAssertEqual(storage.values, journal)
        XCTAssertEqual(reader.reads, reads); XCTAssertEqual(reader.writes, 0)
    }

    func testCanonicallyEqualDirtyTitleMustSaveExactBytesBeforeOriginalReadback() async throws {
        let (model, _, reader, storage) = try await setup()
        var baseline = reader.snapshot.draft; baseline.name = "\u{00E9}"
        reader.snapshot = .init(topicID: 88, scope: .full, draft: baseline)
        await model.load(force: true)
        let visit = try XCTUnwrap(NativeAuthorProjectVisit(model: model))
        model.draft.name = "e\u{0301}"
        XCTAssertEqual(model.draft, baseline) // Swift canonical equivalence is not a save certificate.
        let dirtyBytes = try XCTUnwrap(ProjectEditPendingMaterials.exactData(model.draft))
        XCTAssertNotEqual(dirtyBytes, ProjectEditPendingMaterials.exactData(baseline))
        let reads = reader.reads; visit.retire(); storage.failWrites = true
        let failed = await visit.requestOriginalReadback()
        XCTAssertFalse(failed); XCTAssertEqual(reader.reads, reads); XCTAssertTrue(storage.data.isEmpty)
        XCTAssertEqual(ProjectEditPendingMaterials.exactData(model.draft), dirtyBytes)
        storage.failWrites = false
        let requested = await visit.requestOriginalReadback()
        XCTAssertTrue(requested); XCTAssertEqual(reader.reads, reads + 1)
        let saved = try JSONDecoder().decode(ProjectEditEnvelope.self, from: XCTUnwrap(storage.data.values.first))
        XCTAssertEqual(Array(saved.draft.name.utf8), Array("e\u{0301}".utf8))
        XCTAssertEqual(ProjectEditPendingMaterials.exactData(saved.draft), dirtyBytes)
        XCTAssertTrue(model.hasRestore); XCTAssertEqual(reader.writes, 0)
    }

    func testCanonicallyEqualNamespaceCannotReuseOriginalChildReadback() async throws {
        let (model, owner, reader, storage) = try await setup()
        owner.session = try .init(accountID: 7, epoch: 1, storageNamespace: "fixture-\u{00E9}")
        await model.load(force: true)
        let originalSession = try XCTUnwrap(owner.session)
        let visit = try XCTUnwrap(NativeAuthorProjectVisit(model: model)), reads = reader.reads, bytes = storage.data
        owner.session = try .init(accountID: 7, epoch: 1, storageNamespace: "fixture-e\u{0301}")
        XCTAssertEqual(owner.session, originalSession) // Synthesized equality is not exact scope proof.
        XCTAssertNotEqual(Data(try XCTUnwrap(owner.session).storageNamespace.utf8), Data(originalSession.storageNamespace.utf8))
        XCTAssertNotNil(NativeConditionAuthorProjectReadbackAdapter.Source.capture(model: model))
        XCTAssertFalse(visit.isCurrent); visit.retire()
        let requested = await visit.requestOriginalReadback()
        XCTAssertFalse(requested); XCTAssertEqual(reader.reads, reads); XCTAssertEqual(storage.data, bytes)
        XCTAssertEqual(reader.writes, 0)
    }

    func testOriginalAdapterSavesBranchGraphThenCancelRevokeAndRestartKeepTheStore() async throws {
        let (model, owner, reader, storage) = try await setup()
        model.draft.preserved["routeMode"] = .string("BRANCH_GRAPH")
        model.draft.preserved["routeGraphJson"] = .string(graph)
        let parsed = try NativeConditionAuthorOriginalCatalog(raw: Data(branchCatalog.utf8), topicID: 88, configVersion: 4)
        let visit = try XCTUnwrap(NativeAuthorProjectVisit(model: model))
        let host = NativeAuthorConditionVisitHost(original: model.nativeConditionAuthorHost(
            attributes: nil, catalog: { parsed.catalog(for: $0) }), visit: visit)
        let controller = NativeConditionAuthorController(host: host)
        let before = storage.data
        controller.append(.object(["op": .string("HAS_TAG"), "value": .string("tag.open")]),
                          to: NativeConditionAuthorPath().field("edges").index(0).field("conditions"))
        XCTAssertTrue(controller.issues.isEmpty)
        controller.save()
        XCTAssertEqual(controller.session?.state, .localSaved)
        XCTAssertNotEqual(storage.data, before)
        XCTAssertEqual(reader.writes, 0)
        let saved = storage.data
        let expected = try XCTUnwrap(host.capture())
        visit.retire()
        XCTAssertThrowsError(try host.persistOriginalDraft(graph, replacing: expected))
        XCTAssertEqual(storage.data, saved)
        let restarted = try XCTUnwrap(NativeAuthorProjectVisit(model: model))
        XCTAssertTrue(restarted.isCurrent)
        XCTAssertFalse(visit.isCurrent)
        owner.session = try .init(accountID: 9, epoch: 2, storageNamespace: "other")
        XCTAssertFalse(restarted.isCurrent)
        let reads = reader.reads
        let requested = await restarted.requestOriginalReadback()
        XCTAssertFalse(requested)
        XCTAssertEqual(reader.reads, reads)
        XCTAssertEqual(storage.data, saved)
        XCTAssertEqual(reader.writes, 0)
    }

    private var branchCatalog: String {
        #"{"code":200,"data":{"topic":{"id":88,"configVersion":4},"routeConditionAuthorCatalog":{"schemaVersion":1,"surface":"GLOBAL_ROUTE","available":true,"topicId":88,"configVersion":4,"nodes":[{"id":1,"label":"A"},{"id":2,"label":"B"}],"outcomes":[{"nodeId":1,"trigger":"CHOICE","code":"TRY"}],"items":[],"types":[{"key":"counter.hp","type":"NUMBER"}],"edges":["e"],"rpg":null}}}"#
    }

    func testColdModelRestoresBranchGraphFromTheSameStoreWithoutASecondSaver() async throws {
        let (model, owner, reader, storage) = try await setup()
        model.draft.preserved["routeMode"] = .string("BRANCH_GRAPH")
        model.draft.preserved["routeGraphJson"] = .string(graph)
        let parsed = try NativeConditionAuthorOriginalCatalog(raw: Data(branchCatalog.utf8), topicID: 88, configVersion: 4)
        let visit = try XCTUnwrap(NativeAuthorProjectVisit(model: model))
        let host = NativeAuthorConditionVisitHost(original: model.nativeConditionAuthorHost(
            attributes: nil, catalog: { parsed.catalog(for: $0) }), visit: visit)
        let controller = NativeConditionAuthorController(host: host)
        controller.append(.object(["op": .string("HAS_TAG"), "value": .string("tag.open")]),
                          to: NativeConditionAuthorPath().field("edges").index(0).field("conditions"))
        XCTAssertTrue(controller.issues.isEmpty)
        controller.save()
        XCTAssertEqual(controller.session?.state, .localSaved)
        let savedDraft = model.draft, saved = storage.data
        XCTAssertEqual(savedDraft.preserved["routeMode"], .string("BRANCH_GRAPH"))
        XCTAssertNil(reader.snapshot.draft.preserved["routeGraphJson"])
        XCTAssertEqual(reader.writes, 0)
        visit.retire()
        let cold = ProjectEditModel(coordinator: .init(initial: reader.snapshot, service: reader,
            store: .init(storage: storage), currentSession: { owner.session }))
        XCTAssertFalse(cold === model)
        let reads = reader.reads
        await cold.load()
        XCTAssertTrue(cold.canRestore)
        XCTAssertNotEqual(cold.draft, savedDraft)
        cold.restore()
        XCTAssertEqual(cold.draft, savedDraft)
        XCTAssertEqual(cold.draft.preserved["routeMode"], .string("BRANCH_GRAPH"))
        XCTAssertEqual(reader.reads, reads + 1)
        XCTAssertEqual(reader.writes, 0)
        XCTAssertEqual(storage.data, saved)
        owner.session = try .init(accountID: 9, epoch: 2, storageNamespace: "other")
        let foreign = ProjectEditModel(coordinator: .init(initial: reader.snapshot, service: reader,
            store: .init(storage: storage), currentSession: { owner.session }))
        await foreign.load()
        XCTAssertFalse(foreign.canRestore)
        foreign.restore()
        XCTAssertNil(foreign.draft.preserved["routeGraphJson"])
        XCTAssertEqual(storage.data, saved)
        XCTAssertEqual(reader.writes, 0)
    }

    private var authoringDetail: String {
        #"{"code":200,"data":{"topic":{"id":88,"configVersion":4,"productType":1,"updateTime":"source-4","routeMode":"BRANCH_GRAPH","routeGraphJson":"{\"schemaVersion\":1,\"routeExpressionVersion\":2,\"startNodeId\":1,\"terminalNodeIds\":[2],\"variables\":{\"counter.hp\":1},\"edges\":[{\"id\":\"e\",\"fromNodeId\":1,\"toNodeId\":2,\"trigger\":{\"type\":\"CHOICE\",\"outcomeCode\":\"TRY\"},\"conditions\":[],\"effects\":[]}]}"},"editScope":"FULL","chapters":[{"id":1,"cmsTopicNodeList":[{"id":1},{"id":2}]}],"tickets":[],"routeConditionAuthorCatalog":{"schemaVersion":1,"surface":"GLOBAL_ROUTE","available":true,"topicId":88,"configVersion":4,"nodes":[{"id":1,"label":"A"},{"id":2,"label":"B"}],"outcomes":[{"nodeId":1,"trigger":"CHOICE","code":"TRY"}],"items":[],"types":[{"key":"counter.hp","type":"NUMBER"}],"edges":["e"],"rpg":null}}}"#
    }

    private func authoringSetup() async throws -> (ProjectEditModel, Owner, Reader, ProjectEditMemoryStorage) {
        let owner = Owner(), storage = ProjectEditMemoryStorage()
        let body = Data(authoringDetail.utf8)
        let snapshot = try ProjectEditContract.decodeEditDetail(body, expectedTopicID: 88, owner: .personal)
        let reader = Reader(snapshot: snapshot)
        let model = ProjectEditModel(coordinator: .init(initial: snapshot, service: reader, store: .init(storage: storage), currentSession: { owner.session }))
        await model.load()
        return (model, owner, reader, storage)
    }

    func testInstalledCatalogHostReadsOriginalDetailAndDropsAHeldResponse() async throws {
        let (model, owner, reader, storage) = try await authoringSetup()
        let before = model.draft, bytes = storage.data, reads = reader.reads
        let wire = PrivateWire()
        wire.data = Data(authoringDetail.utf8)
        let service = try privateService(owner, wire)
        let host = try XCTUnwrap(NativeConditionAuthorProjectCatalogHost(model: model, service: service, currentAccess: { true }))
        await host.load()
        XCTAssertTrue(host.ready)
        XCTAssertFalse(host.failed)
        XCTAssertNotNil(host.capture())
        XCTAssertEqual(wire.requests.count, 1)
        XCTAssertEqual(wire.requests.first?.httpMethod, "POST")
        XCTAssertTrue(wire.requests.first?.url?.absoluteString.contains("api/topic/edit-detail") == true)
        XCTAssertEqual(model.draft, before)
        XCTAssertEqual(storage.data, bytes)
        XCTAssertEqual(reader.reads, reads)
        XCTAssertEqual(reader.writes, 0)
        let late = try XCTUnwrap(NativeConditionAuthorProjectCatalogHost(model: model, service: service, currentAccess: { true }))
        wire.afterRead = { late.retire() }
        await late.load()
        XCTAssertFalse(late.ready)
        XCTAssertFalse(late.failed)
        XCTAssertNil(late.capture())
        XCTAssertEqual(model.draft, before)
        XCTAssertEqual(storage.data, bytes)
        XCTAssertEqual(reader.writes, 0)
        let cancelled = try XCTUnwrap(NativeConditionAuthorProjectCatalogHost(model: model, service: service, currentAccess: { true }))
        wire.afterRead = { withUnsafeCurrentTask { $0?.cancel() } }
        await cancelled.load()
        XCTAssertFalse(cancelled.ready)
        XCTAssertTrue(cancelled.failed)
        XCTAssertNil(cancelled.capture())
        XCTAssertEqual(model.draft, before)
        XCTAssertEqual(storage.data, bytes)
        XCTAssertEqual(reader.reads, reads)
        XCTAssertEqual(reader.writes, 0)
        XCTAssertEqual(wire.requests.count, 3)
    }

    /// Parks the original edit-detail send, then releases it after retire or cancel.
    /// The waiter resumes only after send has stored its continuation. This is not a process restart or a disk cold start.
    private final class ParkedDetailWire: HTTPTransport {
        var data = Data()
        private var parked: CheckedContinuation<(Data, Int), Error>?
        private var whenRegistered: CheckedContinuation<Void, Never>?
        private var closed = false
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            try await withCheckedThrowingContinuation { continuation in
                Task { @MainActor in
                    self.register(continuation)
                }
            }
        }
        @MainActor private func register(_ continuation: CheckedContinuation<(Data, Int), Error>) {
            if closed {
                continuation.resume(throwing: CancellationError())
                return
            }
            parked = continuation
            whenRegistered?.resume()
            whenRegistered = nil
        }
        @MainActor func waitUntilRegistered() async {
            if parked != nil || closed { return }
            await withTaskCancellationHandler {
                await withCheckedContinuation { (ready: CheckedContinuation<Void, Never>) in
                    if parked != nil || closed {
                        ready.resume()
                    } else {
                        whenRegistered = ready
                    }
                }
            } onCancel: {
                Task { @MainActor in self.close() }
            }
        }
        @MainActor func release() {
            parked?.resume(returning: (data, 200))
            parked = nil
        }
        @MainActor func close() {
            closed = true
            parked?.resume(throwing: CancellationError())
            parked = nil
            whenRegistered?.resume()
            whenRegistered = nil
        }
    }

    private func parkedService(_ owner: Owner, _ wire: ParkedDetailWire) throws -> ProjectEditHTTPService {
        try .init(configuration: configuration(), transport: wire, owner: .personal, currentCredentials: {
            owner.session.flatMap { try? .init(session: $0, token: "synthetic-entry-token") }
        })
    }

    func testCatalogHostDropsAResponseReleasedAfterTheSendParks() async throws {
        let (model, owner, reader, storage) = try await authoringSetup()
        let before = model.draft, bytes = storage.data, reads = reader.reads
        let retiredWire = ParkedDetailWire()
        retiredWire.data = Data(authoringDetail.utf8)
        defer { retiredWire.close() }
        let retiredHost = try XCTUnwrap(NativeConditionAuthorProjectCatalogHost(
            model: model, service: try parkedService(owner, retiredWire), currentAccess: { true }))
        let retiredTask = Task { await retiredHost.load() }
        await retiredWire.waitUntilRegistered()
        retiredHost.retire()
        retiredWire.release()
        await retiredTask.value
        XCTAssertFalse(retiredHost.ready)
        XCTAssertFalse(retiredHost.failed)
        XCTAssertNil(retiredHost.capture())
        XCTAssertEqual(model.draft, before)
        XCTAssertEqual(storage.data, bytes)
        XCTAssertEqual(reader.reads, reads)
        XCTAssertEqual(reader.writes, 0)
        let cancelledWire = ParkedDetailWire()
        cancelledWire.data = Data(authoringDetail.utf8)
        defer { cancelledWire.close() }
        let cancelledHost = try XCTUnwrap(NativeConditionAuthorProjectCatalogHost(
            model: model, service: try parkedService(owner, cancelledWire), currentAccess: { true }))
        let cancelledTask = Task { await cancelledHost.load() }
        await cancelledWire.waitUntilRegistered()
        cancelledTask.cancel()
        cancelledWire.release()
        await cancelledTask.value
        XCTAssertFalse(cancelledHost.ready)
        XCTAssertTrue(cancelledHost.failed)
        XCTAssertNil(cancelledHost.capture())
        XCTAssertEqual(model.draft, before)
        XCTAssertEqual(storage.data, bytes)
        XCTAssertEqual(reader.reads, reads)
        XCTAssertEqual(reader.writes, 0)
    }

    @MainActor private final class E16Wire: NativeAttributeAuthorTransport {
        var requests: [NativeAttributeAuthorRequest] = []
        var beforeFinal: (() -> Void)?
        var response: (NativeAttributeAuthorRequest) throws -> Data = { request in
            if request.path.hasSuffix("/references") {
                return Data(#"{"code":200,"topicId":88,"configVersion":4,"data":{"stateKey":"counter.temp","positions":[]}}"#.utf8)
            }
            return Data(#"{"code":200,"topicId":88,"configVersion":4,"data":[{"stateKey":"counter.temp","keyType":"counter","scope":"run","label":"温度","initialValue":10,"minValue":0,"maxValue":10,"display":"number","sortOrder":0,"visible":true,"persistScope":"run","rules":[]}]}"#.utf8)
        }
        func send(_ request: NativeAttributeAuthorRequest, finalCheck: @escaping @MainActor () throws -> Void) async throws -> (Data, Int) {
            beforeFinal?(); try finalCheck(); requests.append(request); return (try response(request), 200)
        }
    }
    func testNormalAttributeHostSuppliesOriginalE16ReaderWithoutGrantingWrites() async throws {
        let (model, _, original, _) = try await setup()
        let host = try XCTUnwrap(NativeAttributeAuthorProjectHost(model: model, configuration: configuration()))
        let wire = E16Wire(), storage = AttributeStorage()
        var allowed: Set<NativeAttributeAuthorHostEndpoint> = [.definitions, .references, .delete, .requestReceipt]
        let permits: (NativeAttributeAuthorHostEndpoint) -> Bool = { allowed.contains($0) }
        let references = host.e16ReferenceReader(transport: wire, endpointAllowed: permits, currentAccess: { true })
        let dependencies = try XCTUnwrap(host.dependencies(transport: wire, storage: storage,
            references: references, endpointAllowed: permits, currentAccess: { true }))
        let coordinator = NativeAttributeAuthorCoordinator(binding: dependencies.binding, service: dependencies.service, store: dependencies.store)
        await coordinator.load(); await coordinator.prepareDelete("counter.temp")
        XCTAssertEqual(coordinator.phase, .review); XCTAssertNil(coordinator.referenceReadback?.incompleteReason)
        XCTAssertTrue(coordinator.referenceReadback?.permitsDelete == true)
        XCTAssertEqual(wire.requests.map(\.path), ["api/topic/attribute-author", "api/topic/attribute-author/references"])
        XCTAssertFalse(coordinator.canSave); XCTAssertEqual(original.writes, 0)
        allowed.remove(.references)
        await coordinator.confirm()
        XCTAssertEqual(coordinator.phase, .blocked); XCTAssertNil(coordinator.pending)
        XCTAssertFalse(wire.requests.contains(where: \.mutates)); XCTAssertEqual(original.writes, 0)
    }
    func testE16HostFinalForwardRejectsRevocationAndSameModelReincarnation() async throws {
        for changeModel in [false, true] {
            let (model, _, original, _) = try await setup()
            let host = try XCTUnwrap(NativeAttributeAuthorProjectHost(model: model, configuration: configuration()))
            let wire = E16Wire(); var access = true
            let references = host.e16ReferenceReader(transport: wire, endpointAllowed: { $0 == .references }, currentAccess: { access })
            wire.beforeFinal = {
                if changeModel { let draft = model.draft; model.draft = draft } else { access = false }
            }
            do {
                _ = try await references(host.binding, "counter.temp", UUID())
                XCTFail("retired reference source was admitted")
            } catch {}
            XCTAssertTrue(wire.requests.isEmpty); XCTAssertEqual(original.writes, 0)
        }
    }
}
