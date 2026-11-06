import XCTest
import CryptoKit
@testable import QuestifyCore

/// Synthetic contract tests only. No installed draft, license or production resource is written.
@MainActor final class ModInstallationBindingRecoveryTests: XCTestCase {
    private static let hash = String(repeating: "a", count: 64)
    private static let requirements: [ModInstallationRequirement] = [
        .init(key: "home", kind: .site), .init(key: "host", kind: .npc),
        .init(key: "product", kind: .sku), .init(key: "entry", kind: .routeEntry)
    ]
    private static func resource(_ kind: ModInstallationKind, _ id: Int64, region: String? = nil, hash: String? = nil) -> ModInstallationResource {
        .init(kind: kind, id: id, merchantId: 10, label: "Owned \(kind.rawValue) \(id)", region: region, fingerprint: hash ?? Self.hash)
    }
    private static let resources: [ModInstallationResource] = [
        resource(.site, 10), resource(.poi, 20, region: "east"), resource(.poi, 21, region: "west"),
        resource(.npc, 30), resource(.sku, 40), resource(.routeEntry, 50, region: "east"), resource(.routeEntry, 51, region: "west")
    ]
    private static func options(merchant: Int64?, resources: [ModInstallationResource]? = nil,
                                merchants: [ModInstallationResource]? = nil,
                                requirements: [ModInstallationRequirement]? = nil) -> ModInstallationOptions {
        .init(schema: "mod-installation-options-v1", licenseId: "license", moduleId: "module", releaseId: "release",
              contentHash: hash, termsHash: hash, title: "Licensed content", requiredBindings: requirements ?? Self.requirements,
              merchants: merchants ?? [resource(.site, 10)], resources: merchant == nil ? [] : (resources ?? Self.resources))
    }
    private static func receipt(_ attempt: ModInstallationAttempt, installed: Bool = false) -> ModInstallationReceipt {
        .init(schema: "mod-installation-receipt-v1", requestId: attempt.request.requestId, licenseId: "license", moduleId: "module", releaseId: "release",
              contentHash: hash, termsHash: hash, state: installed ? .installed : .prepared, merchantId: 10, anchorPoiId: attempt.request.anchorPoiId,
              region: attempt.region, bindingHash: hash, draftId: installed ? 60 : nil, editKind: "MEMBER_TEMPLATE",
              createdAt: "2026-10-21T00:00:00.000000Z", errorCode: nil, published: false, executable: false,
              requiredGates: ["MERCHANT_FACT_CONFIRMATION", "THEME_CONTENT_REVIEW", "W02_PUBLISH"], bindings: attempt.bindings)
    }
    private final class Memory: TemplateAuthoringStorage {
        var values: [String: Data] = [:], writes = 0
        func read(_ key: String) throws -> Data? { values[key] }
        func write(_ data: Data, key: String) throws { writes += 1; values[key] = data }
        func remove(_ key: String) throws { writes += 1; values.removeValue(forKey: key) }
    }
    private final class Service: ModInstallationServing {
        var isCurrent = true, canMutate = true
        var resources = ModInstallationBindingRecoveryTests.resources
        var merchants = [ModInstallationBindingRecoveryTests.resource(.site, 10)]
        var requirements = ModInstallationBindingRecoveryTests.requirements
        var optionReads: [Int64?] = [], requestReads: [String] = [], editorReads: [String] = [], writes: [String] = []
        var rows: [ModInstallationReceipt] = [], lastAttempt: ModInstallationAttempt?
        var failMerchantRead = false, failRootRead = false, failPrepareResponse = false, failPrepareNotFound = false
        var onOptionsRead: ((Int64?) -> Void)?
        var optionsGate: ((Int64?) async -> Void)?
        func invalidate() { isCurrent = false }
        func options(identity: ModInstallationIdentity, merchantId: Int64?) async throws -> ModInstallationOptions {
            optionReads.append(merchantId); onOptionsRead?(merchantId)
            if merchantId == nil ? failRootRead : failMerchantRead { throw ModInstallationIssue.unavailable }
            let result = ModInstallationBindingRecoveryTests.options(merchant: merchantId, resources: resources, merchants: merchants, requirements: requirements)
            if let optionsGate { await optionsGate(merchantId) }
            return result
        }
        func history(identity: ModInstallationIdentity) async throws -> [ModInstallationReceipt] { rows }
        func request(_ requestId: String, identity: ModInstallationIdentity) async throws -> ModInstallationReceipt {
            requestReads.append(requestId)
            guard let receipt = rows.first(where: { $0.requestId == requestId }) else { throw ModInstallationIssue.requestNotFound }; return receipt
        }
        func prepare(_ attempt: ModInstallationAttempt) async throws -> ModInstallationReceipt {
            writes.append("prepare:" + attempt.request.requestId); lastAttempt = attempt
            if failPrepareNotFound { throw ModInstallationIssue.requestNotFound }
            let receipt = ModInstallationBindingRecoveryTests.receipt(attempt); rows = [receipt]
            if failPrepareResponse { throw ModInstallationIssue.unknownOutcome }; return receipt
        }
        func install(_ prepared: ModInstallationReceipt) async throws -> ModInstallationReceipt {
            writes.append("install:" + prepared.requestId)
            let installed = ModInstallationBindingRecoveryTests.receipt(try XCTUnwrap(lastAttempt), installed: true); rows = [installed]; return installed
        }
        func cancel(_ prepared: ModInstallationReceipt) async throws -> ModInstallationReceipt { XCTFail("Unexpected cancellation"); throw ModInstallationIssue.disabled }
        func preview(_ receipt: ModInstallationReceipt) async throws -> ModInstallationPreview {
            .init(schema: "mod-installation-preview-v1", requestId: receipt.requestId, licenseId: receipt.licenseId,
                  bindingHash: receipt.bindingHash, fields: ["title": "Saved content", "ruleInstructions": "Bound owned resources"])
        }
        func facts(_ receipt: ModInstallationReceipt) async throws -> ModInstallationFacts {
            .init(schema: "mod-installation-facts-v1", requestId: receipt.requestId, licenseId: receipt.licenseId,
                  draftId: try XCTUnwrap(receipt.draftId), merchantId: receipt.merchantId, bindingHash: receipt.bindingHash,
                  draftContentHash: ModInstallationBindingRecoveryTests.hash, title: "Saved content", rules: "Bound owned resources",
                  confirmed: false, bindings: receipt.bindings)
        }
        func templateEditor(_ installation: ModInstallationReceipt) async throws -> ModInstallationTemplateEditorState {
            editorReads.append(installation.requestId)
            let fields = ["title": "Saved content", "ruleInstructions": "Bound owned resources"]
            let snapshot: [String: Any] = ["bizType": "TEMPLATE", "bizId": 60, "title": fields["title"]!, "ruleInstructions": fields["ruleInstructions"]!]
            let json = try JSONSerialization.data(withJSONObject: snapshot, options: [.sortedKeys])
            let hash = SHA256.hash(data: json).map { String(format: "%02x", $0) }.joined()
            return .init(schema: "mod-installation-template-editor-v1", installationRequestId: installation.requestId,
                         licenseId: installation.licenseId, bindingHash: installation.bindingHash, draftContentHash: hash,
                         snapshotJson: String(decoding: json, as: UTF8.self), templateId: 60, fields: fields,
                         editable: true, factsConfirmed: false, validationMethod: nil, advancedConfigJson: nil,
                         draftStatus: 0, checkStatus: 0, status: 0, publishStatus: 0, auditTaskId: nil, auditStatus: nil)
        }
        func confirmFacts(_ facts: ModInstallationFacts, receipt: ModInstallationReceipt) async throws -> ModInstallationFacts { XCTFail("Unexpected fact confirmation"); throw ModInstallationIssue.disabled }
    }
    /// Continuations model a response captured before backgrounding and delivered afterward.
    @MainActor private final class ReadGate {
        let entered = XCTestExpectation(description: "Resource read reached its response gate")
        private var response: CheckedContinuation<Void, Never>?
        private var released = false
        func pause() async {
            guard !released else { return }
            await withCheckedContinuation { continuation in
                response = continuation; entered.fulfill()
            }
        }
        func release() { released = true; response?.resume(); response = nil }
    }
    private func waitUntilIdle(_ controller: ModInstallationController) async {
        let idle = expectation(description: "Queued read finishes")
        let waiter = Task {
            while controller.busy && !Task.isCancelled { try? await Task.sleep(nanoseconds: 1_000_000) }
            if !Task.isCancelled { idle.fulfill() }
        }
        await fulfillment(of: [idle], timeout: 2); waiter.cancel(); XCTAssertFalse(controller.busy)
    }
    private func fixture() throws -> (ModInstallationController, Service, Memory) {
        let context = RuntimeDependencyContext(market: .china, baseURL: URL(string: "https://example.invalid")!, role: "merchant",
            session: try .init(accountID: 7, epoch: 1, namespace: "synthetic-binding-recovery", token: "synthetic", role: "merchant"))
        let service = Service(), memory = Memory(), identity = Self.options(merchant: nil).identity
        return (.init(identity: identity, service: service, store: .init(storage: memory, context: context, identity: identity)), service, memory)
    }
    private func selectAll(_ controller: ModInstallationController) async {
        await controller.recover(); await controller.selectMerchant(10); controller.selectAnchor(20)
        for (requirement, id) in zip(Self.requirements, [Int64(10), 30, 40, 50]) { controller.select(id, for: requirement) }
        XCTAssertTrue(controller.canPrepare)
    }
    func testForegroundRecoveryRereadsSelectedMerchantAndPreservesUnchangedChoicesWithoutWrites() async throws {
        let (controller, service, memory) = try fixture(); await selectAll(controller)
        let choices = controller.selections; service.optionReads = []
        await controller.recover()
        XCTAssertEqual(service.optionReads, [nil, 10]); XCTAssertEqual(controller.selections, choices)
        XCTAssertEqual(controller.selectedAnchorPoiId, 20); XCTAssertTrue(controller.canPrepare)
        XCTAssertTrue(service.writes.isEmpty); XCTAssertEqual(memory.writes, 0)
    }
    func testChangedFingerprintRequiresExplicitReselectionNeverSilentReplacement() async throws {
        let (controller, service, _) = try fixture(); await selectAll(controller)
        service.resources = service.resources.map { $0.kind == .sku ? Self.resource(.sku, 40, hash: String(repeating: "b", count: 64)) : $0 }
        await controller.recover()
        XCTAssertNil(controller.selections["SKU:product"]); XCTAssertEqual(controller.selections["NPC:host"], 30)
        XCTAssertEqual(controller.messageKey, "bindingsChanged"); XCTAssertFalse(controller.canPrepare); XCTAssertTrue(service.writes.isEmpty)
        controller.select(40, for: Self.requirements[2]); XCTAssertTrue(controller.canPrepare)
    }
    func testRemovedOrUnapprovedResourceIsNotKeptByID() async throws {
        let (controller, service, _) = try fixture(); await selectAll(controller)
        service.resources.removeAll { $0.kind == .npc }; await controller.recover()
        XCTAssertNil(controller.selections["NPC:host"]); XCTAssertFalse(controller.canPrepare)
        controller.select(30, for: Self.requirements[1]); XCTAssertNil(controller.selections["NPC:host"])
    }
    func testRemovedMerchantClearsSelectionAndDoesNotRequestItsResources() async throws {
        let (controller, service, _) = try fixture(); await selectAll(controller)
        service.merchants = []; service.optionReads = []; await controller.recover()
        XCTAssertEqual(service.optionReads, [nil]); XCTAssertNil(controller.selectedMerchantId)
        XCTAssertNil(controller.selectedAnchorPoiId); XCTAssertTrue(controller.selections.isEmpty)
        XCTAssertTrue(controller.canSelect); XCTAssertFalse(controller.canPrepare); XCTAssertTrue(service.writes.isEmpty)
    }
    func testMerchantChangingBetweenRootAndScopedReadAlsoRequiresReselection() async throws {
        let (controller, service, _) = try fixture(); await selectAll(controller)
        service.onOptionsRead = { id in if id != nil { service.merchants = [Self.resource(.site, 10, hash: String(repeating: "b", count: 64))] } }
        await controller.recover()
        XCTAssertNil(controller.selectedMerchantId); XCTAssertTrue(controller.selections.isEmpty); XCTAssertFalse(controller.canPrepare)
    }
    func testChangedAnchorFingerprintClearsDependentChoices() async throws {
        let (controller, service, _) = try fixture(); await selectAll(controller)
        service.resources = service.resources.map { $0.kind == .poi && $0.id == 20 ? Self.resource(.poi, 20, region: "east", hash: String(repeating: "b", count: 64)) : $0 }
        await controller.recover()
        XCTAssertNil(controller.selectedAnchorPoiId); XCTAssertTrue(controller.selections.isEmpty); XCTAssertFalse(controller.canPrepare)
    }
    func testFailedResourceReadKeepsExplainableSelectionButBlocksUntilSuccessfulRetry() async throws {
        let (controller, service, _) = try fixture(); await selectAll(controller)
        let choices = controller.selections, previous = controller.options
        service.failMerchantRead = true; await controller.recover()
        XCTAssertEqual(controller.options, previous); XCTAssertEqual(controller.selections, choices)
        XCTAssertEqual(controller.messageKey, "error.bindingsRecovery")
        XCTAssertFalse(controller.canPrepare); XCTAssertFalse(controller.canConfirm); XCTAssertFalse(controller.canSelect)
        await controller.prepare(); XCTAssertTrue(service.writes.isEmpty)
        service.failMerchantRead = false; await controller.recover(); XCTAssertTrue(controller.canPrepare)
        XCTAssertEqual(controller.selections, choices); XCTAssertTrue(service.writes.isEmpty)
    }
    func testLateResourceResponseAfterSessionRevocationCannotRestoreSelections() async throws {
        let (controller, service, _) = try fixture(); await selectAll(controller)
        service.onOptionsRead = { id in if id != nil { service.isCurrent = false } }; await controller.recover()
        XCTAssertNil(controller.options); XCTAssertNil(controller.selectedMerchantId); XCTAssertTrue(controller.selections.isEmpty)
        XCTAssertFalse(controller.canPrepare); XCTAssertTrue(service.writes.isEmpty)
    }
    func testChangedRequirementsDoNotRewriteOriginalVersionContract() async throws {
        let (controller, service, _) = try fixture(); await selectAll(controller)
        service.requirements = [.init(key: "different", kind: .sku)]; await controller.recover()
        XCTAssertFalse(controller.canPrepare); XCTAssertFalse(controller.canSelect); XCTAssertTrue(service.writes.isEmpty)
    }
    func testAnchorRegionFiltersMapChoicesAndDirectCrossRegionSelectionIsRejected() async throws {
        let (controller, _, _) = try fixture(); await selectAll(controller)
        XCTAssertEqual(controller.bindingResources(for: Self.requirements[3]).map(\.id), [50])
        controller.select(51, for: Self.requirements[3]); XCTAssertEqual(controller.selections["ROUTE_ENTRY:entry"], 50)
        var selections = controller.selections; selections["ROUTE_ENTRY:entry"] = 51
        XCTAssertThrowsError(try ModInstallationAttempt(options: Self.options(merchant: 10), merchantId: 10, anchorPoiId: 20, selections: selections))
        controller.selectAnchor(21); XCTAssertNil(controller.selections["ROUTE_ENTRY:entry"])
        XCTAssertEqual(controller.selections["SITE:home"], 10); XCTAssertEqual(controller.selections["SKU:product"], 40)
        XCTAssertEqual(controller.bindingResources(for: Self.requirements[3]).map(\.id), [51]); XCTAssertFalse(controller.canPrepare)
        controller.select(51, for: Self.requirements[3]); XCTAssertTrue(controller.canPrepare)
    }
    func testInterruptedBindingContinuesThroughOriginalReceiptAndPrivateEditorWithoutAutoInstall() async throws {
        let (controller, service, _) = try fixture(); await selectAll(controller); await controller.recover()
        XCTAssertTrue(service.writes.isEmpty); await controller.prepare()
        let prepared = try XCTUnwrap(controller.receipt), key = prepared.requestId
        XCTAssertEqual(service.writes, ["prepare:" + key]); XCTAssertNil(prepared.memberTemplateID)
        XCTAssertTrue(controller.canConfirm); await controller.confirmInstall(prepared)
        let installed = try XCTUnwrap(controller.receipt)
        XCTAssertEqual(service.writes, ["prepare:" + key, "install:" + key]); XCTAssertEqual(installed.requestId, key)
        XCTAssertEqual(installed.memberTemplateID?.rawValue, 60); XCTAssertFalse(installed.published); XCTAssertFalse(installed.executable)
        let editor = try XCTUnwrap(controller.templateEditor(installed)); XCTAssertEqual(editor.installation, installed)
        await editor.open(); XCTAssertTrue(editor.canEdit); XCTAssertEqual(editor.state?.templateId, 60)
        XCTAssertEqual(service.editorReads, [key]); XCTAssertFalse(editor.canSubmitReview)
        await controller.refreshFacts(); XCTAssertEqual(controller.receipt, installed)
        XCTAssertEqual(controller.facts?.bindings, installed.bindings); XCTAssertEqual(controller.facts?.confirmed, false)
    }
    func testUnknownPrepareOnlyReadsOriginalKeyAndDoesNotReselectOrWrite() async throws {
        let (controller, service, _) = try fixture(); await selectAll(controller)
        service.failPrepareResponse = true; await controller.prepare()
        let key = try XCTUnwrap(controller.attempt?.request.requestId), writes = service.writes
        service.optionReads = []; await controller.recover()
        XCTAssertEqual(service.requestReads, [key]); XCTAssertEqual(controller.receipt?.requestId, key)
        XCTAssertEqual(service.optionReads, [nil]); XCTAssertEqual(service.writes, writes); XCTAssertTrue(controller.canConfirm)
    }
    func testExplicitRetryAfterMissingOriginalFinishesReadBarrierWithoutReplacementKey() async throws {
        let (controller, service, _) = try fixture(); await selectAll(controller)
        service.failPrepareResponse = true; await controller.prepare()
        let key = try XCTUnwrap(controller.attempt?.request.requestId)
        service.rows = []; await controller.recover()
        XCTAssertTrue(controller.canRetryOriginalPrepare); XCTAssertFalse(controller.canConfirm)
        service.failPrepareResponse = false; await controller.retryOriginalPrepare()
        XCTAssertEqual(service.writes, ["prepare:" + key, "prepare:" + key])
        XCTAssertEqual(service.requestReads, [key, key]); XCTAssertEqual(controller.receipt?.requestId, key)
        XCTAssertTrue(controller.canConfirm)
    }
    func testDirectPrepareNotFoundThenFailedRetryReadBarrierCannotReuseOldReadiness() async throws {
        let (controller, service, _) = try fixture(); await selectAll(controller)
        service.failPrepareNotFound = true; await controller.prepare()
        let key = try XCTUnwrap(controller.attempt?.request.requestId)
        XCTAssertTrue(controller.canRetryOriginalPrepare)
        service.failPrepareNotFound = false; service.failRootRead = true
        await controller.retryOriginalPrepare()
        let receipt = try XCTUnwrap(controller.receipt), writes = service.writes
        XCTAssertEqual(receipt.requestId, key); XCTAssertFalse(controller.canConfirm)
        await controller.confirmInstall(receipt); XCTAssertEqual(service.writes, writes)
        XCTAssertEqual(writes, ["prepare:" + key, "prepare:" + key])
        service.failRootRead = false; await controller.recover(); XCTAssertTrue(controller.canConfirm)
    }
    func testFailedRecoveryCannotConfirmPreviouslyPreparedReceipt() async throws {
        let (controller, service, _) = try fixture(); await selectAll(controller); await controller.prepare()
        let receipt = try XCTUnwrap(controller.receipt), writes = service.writes
        service.failRootRead = true; await controller.recover()
        XCTAssertEqual(controller.receipt, receipt); XCTAssertFalse(controller.canConfirm)
        await controller.confirmInstall(receipt); XCTAssertEqual(service.writes, writes)
        service.failRootRead = false; await controller.recover(); XCTAssertTrue(controller.canConfirm)
    }
    func testBusyMerchantReadCoalescesForegroundRefreshAndDoesNotExposeOldChoices() async throws {
        let (controller, service, _) = try fixture(); await controller.recover()
        let old = ReadGate(), fresh = ReadGate(); var scopedReads = 0
        service.optionsGate = { id in
            if id == 10 { scopedReads += 1; await (scopedReads == 1 ? old : fresh).pause() }
        }
        let selecting = Task { await controller.selectMerchant(10) }; await fulfillment(of: [old.entered], timeout: 2)
        service.resources.removeAll { $0.kind == .npc }
        await controller.recover(); await controller.recover()
        old.release(); await selecting.value
        XCTAssertFalse(controller.canSelect); XCTAssertFalse(controller.canPrepare)
        await fulfillment(of: [fresh.entered], timeout: 2); fresh.release()
        await waitUntilIdle(controller)
        XCTAssertEqual(scopedReads, 2); XCTAssertEqual(service.optionReads, [nil, 10, nil, 10])
        XCTAssertFalse(controller.options?.resources.contains(where: { $0.kind == .npc }) ?? true)
        XCTAssertTrue(controller.canSelect); XCTAssertTrue(service.writes.isEmpty)
    }
    func testForegroundDuringRecoveryQueuesOneLatestReadWithoutUnlockingBetweenRounds() async throws {
        let (controller, service, _) = try fixture(); await selectAll(controller)
        let old = ReadGate(), fresh = ReadGate(); var scopedReads = 0
        service.optionsGate = { id in
            if id == 10 { scopedReads += 1; await (scopedReads == 1 ? old : fresh).pause() }
        }
        let recovering = Task { await controller.recover() }; await fulfillment(of: [old.entered], timeout: 2)
        service.resources = service.resources.map { $0.kind == .sku ? Self.resource(.sku, 40, hash: String(repeating: "b", count: 64)) : $0 }
        await controller.recover(); await controller.recover()
        old.release(); await recovering.value
        XCTAssertFalse(controller.canPrepare); XCTAssertFalse(controller.canConfirm)
        await fulfillment(of: [fresh.entered], timeout: 2); fresh.release()
        await waitUntilIdle(controller)
        XCTAssertEqual(scopedReads, 2); XCTAssertNil(controller.selections["SKU:product"])
        XCTAssertEqual(controller.messageKey, "bindingsChanged"); XCTAssertFalse(controller.canPrepare); XCTAssertTrue(service.writes.isEmpty)
    }
    func testInvalidationDropsQueuedRecoveryAndCannotAcceptLateResourceResponse() async throws {
        let (controller, service, _) = try fixture(); await controller.recover()
        let old = ReadGate(); service.optionsGate = { id in if id == 10 { await old.pause() } }
        let selecting = Task { await controller.selectMerchant(10) }; await fulfillment(of: [old.entered], timeout: 2)
        await controller.recover(); controller.invalidate(); old.release(); await selecting.value
        await Task.yield()
        XCTAssertEqual(service.optionReads, [nil, 10]); XCTAssertNil(controller.options); XCTAssertNil(controller.selectedMerchantId)
        XCTAssertFalse(controller.canSelect); XCTAssertFalse(controller.canPrepare); XCTAssertTrue(service.writes.isEmpty)
    }
    func testCanonicallyEquivalentButByteDifferentRegionsAreNotTheSameBackendRegion() async throws {
        let (controller, service, _) = try fixture()
        let composed = "\u{00e9}", decomposed = "e\u{0301}"
        XCTAssertEqual(composed, decomposed); XCTAssertFalse(composed.utf8.elementsEqual(decomposed.utf8))
        service.resources = service.resources.map {
            if $0.kind == .poi && $0.id == 20 { return Self.resource(.poi, 20, region: composed) }
            if $0.kind == .routeEntry && $0.id == 50 { return Self.resource(.routeEntry, 50, region: decomposed) }
            return $0
        }
        await controller.recover(); await controller.selectMerchant(10); controller.selectAnchor(20)
        XCTAssertTrue(controller.bindingResources(for: Self.requirements[3]).isEmpty)
        XCTAssertThrowsError(try ModInstallationAttempt(options: Self.options(merchant: 10, resources: service.resources),
            merchantId: 10, anchorPoiId: 20, selections: ["SITE:home": 10, "NPC:host": 30, "SKU:product": 40, "ROUTE_ENTRY:entry": 50]))
    }
    func testReadOnlyApprovalCanRestoreChoicesButCannotPrepare() async throws {
        let (controller, service, _) = try fixture(); await selectAll(controller)
        service.canMutate = false; await controller.recover()
        XCTAssertTrue(controller.canSelect); XCTAssertFalse(controller.canPrepare)
        await controller.prepare(); XCTAssertTrue(service.writes.isEmpty)
    }
}
