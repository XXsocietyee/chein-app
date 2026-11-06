import XCTest
import CryptoKit
@testable import QuestifyCore

/// Authored XCTest. Synthetic owner/service/storage boundaries; no live API or Apple runtime claim.
@MainActor final class ModInstallationSavedRehearsalTests: XCTestCase {
    private static let hash = String(repeating: "a", count: 64)
    private static let graph = #"{"schemaVersion":1,"branch":{"enabled":true,"startStepId":"intro","steps":[{"id":"intro","title":"Start","body":"Saved story","terminal":false,"options":[{"id":"continue","label":"Continue","nextStepId":"end"}]},{"id":"end","title":"End","body":"Finished locally","terminal":true,"outcomeCode":"end","outcomeLabel":"End","options":[]}]}}"#
    private static func digest(_ text: String) -> String { SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined() }
    private static func installation() -> ModInstallationReceipt {
        .init(schema: "mod-installation-receipt-v1", requestId: "00000000-0000-0000-0000-000000000001", licenseId: "license", moduleId: "module", releaseId: "release", contentHash: hash, termsHash: hash, state: .installed, merchantId: 10, anchorPoiId: 20, region: "test", bindingHash: hash, draftId: 30, editKind: "MEMBER_TEMPLATE", createdAt: "2026-10-21T00:00:00.000000Z", errorCode: nil, published: false, executable: false, requiredGates: ["MERCHANT_FACT_CONFIRMATION", "THEME_CONTENT_REVIEW", "W02_PUBLISH"], bindings: [])
    }
    private static func saved(title: String = "Saved", graph: String = ModInstallationSavedRehearsalTests.graph) throws -> ModInstallationTemplateEditorState {
        let snapshot: [String: TemplateAuthoringJSON] = ["bizType": .string("TEMPLATE"), "bizId": .number(30), "title": .string(title), "ruleInstructions": .string("Saved rules"), "description": .string("Saved detail"), "validationMethod": .number(0), "advancedConfigJson": .string(graph)]
        let text = String(decoding: try JSONEncoder().encode(snapshot), as: UTF8.self)
        let installation = installation()
        return .init(schema: "mod-installation-template-editor-v1", installationRequestId: installation.requestId, licenseId: installation.licenseId, bindingHash: installation.bindingHash, draftContentHash: digest(text), snapshotJson: text, templateId: 30, fields: ["title": title, "ruleInstructions": "Saved rules", "description": "Saved detail"], editable: true, factsConfirmed: false, validationMethod: 0, advancedConfigJson: graph, draftStatus: 0, checkStatus: 0, status: 0, publishStatus: 0, auditTaskId: nil, auditStatus: nil)
    }
    private static func options() -> ModInstallationOptions {
        .init(schema: "mod-installation-options-v1", licenseId: "license", moduleId: "module", releaseId: "release", contentHash: hash, termsHash: hash, title: "Licensed", requiredBindings: [], merchants: [], resources: [])
    }
    private func changed<T: Codable>(_ original: T, _ update: (inout [String: Any]) -> Void) throws -> T {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        update(&object); return try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: object))
    }
    private func snapshot(saved: ModInstallationTemplateEditorState? = nil, options: ModInstallationOptions? = nil) throws -> ModInstallationSavedRehearsalSnapshot {
        try .init(installation: Self.installation(), saved: saved ?? Self.saved(), options: options ?? Self.options())
    }
    private func context() throws -> RuntimeDependencyContext {
        .init(market: .china, baseURL: URL(string: "https://example.test")!, role: "merchant", session: try .init(accountID: 7, epoch: 1, namespace: "synthetic-installed-rehearsal", token: "synthetic", role: "merchant"))
    }
    private final class Memory: TemplateAuthoringStorage {
        var values: [String: Data] = [:], writes = 0; var failRead = false
        func read(_ key: String) throws -> Data? { if failRead { throw ModInstallationIssue.storageUnavailable }; return values[key] }
        func write(_ data: Data, key: String) throws { writes += 1; values[key] = data }
        func remove(_ key: String) throws { writes += 1; values.removeValue(forKey: key) }
    }
    private final class Service: ModInstallationServing {
        var isCurrent = true, canMutate = true, canReadInstalledTemplateRehearsal = true
        var saved: ModInstallationTemplateEditorState
        var result = ModInstallationSavedRehearsalTests.options()
        var failEditor = false, inactiveLicense = false, writes = 0, editorReads = 0, optionReads = 0
        var onEditorRead: (() -> Void)?, onOptionsRead: (() -> Void)?
        init() throws { saved = try ModInstallationSavedRehearsalTests.saved() }
        func invalidate() { isCurrent = false }
        func templateEditor(_ installation: ModInstallationReceipt) async throws -> ModInstallationTemplateEditorState {
            editorReads += 1; onEditorRead?(); if failEditor { throw ModInstallationIssue.unavailable }; return saved
        }
        func options(identity: ModInstallationIdentity, merchantId: Int64?) async throws -> ModInstallationOptions {
            optionReads += 1; XCTAssertNil(merchantId); onOptionsRead?()
            if inactiveLicense { throw ModInstallationIssue.unavailable }; return result
        }
        func prepare(_ attempt: ModInstallationAttempt) async throws -> ModInstallationReceipt { writes += 1; throw ModInstallationIssue.disabled }
        func request(_ requestId: String, identity: ModInstallationIdentity) async throws -> ModInstallationReceipt { throw ModInstallationIssue.unavailable }
        func install(_ prepared: ModInstallationReceipt) async throws -> ModInstallationReceipt { writes += 1; throw ModInstallationIssue.disabled }
        func cancel(_ prepared: ModInstallationReceipt) async throws -> ModInstallationReceipt { writes += 1; throw ModInstallationIssue.disabled }
        func preview(_ receipt: ModInstallationReceipt) async throws -> ModInstallationPreview { throw ModInstallationIssue.unavailable }
        func facts(_ receipt: ModInstallationReceipt) async throws -> ModInstallationFacts { throw ModInstallationIssue.unavailable }
        func confirmFacts(_ facts: ModInstallationFacts, receipt: ModInstallationReceipt) async throws -> ModInstallationFacts { writes += 1; throw ModInstallationIssue.disabled }
        func saveTemplateEdit(_ pending: ModInstallationTemplateEditPending) async throws -> ModInstallationTemplateEditReceipt { writes += 1; throw ModInstallationIssue.disabled }
        func history(identity: ModInstallationIdentity) async throws -> [ModInstallationReceipt] { [] }
    }
    private func editor() throws -> (ModInstallationTemplateEditor, Service, Memory, ModInstallationPendingStore) {
        let service = try Service(), memory = Memory()
        let store = ModInstallationPendingStore(storage: memory, context: try context(), identity: Self.installation().identity)
        return (.init(installation: Self.installation(), service: service, store: store), service, memory, store)
    }
    private func deniedRead(_ editor: ModInstallationTemplateEditor, file: StaticString = #filePath, line: UInt = #line) async {
        do { _ = try await editor.readSavedRehearsal(); XCTFail("Unexpected admission", file: file, line: line) } catch { }
    }
    func testSavedSnapshotUsesExactSharedBranchWithoutDefaults() throws {
        let value = try snapshot()
        let exact = try JSONDecoder().decode([String: TemplateAuthoringJSON].self, from: Data(Self.graph.utf8))
        XCTAssertEqual(value.advanced.value, exact)
        var engine = TemplateCreatorRehearsal(); engine.startBranch(value.advanced)
        XCTAssertEqual(engine.branchStepID, "intro"); engine.chooseBranch("continue", draft: value.advanced)
        XCTAssertEqual(engine.branchStepID, "end"); XCTAssertEqual(engine.result, .matched)
        XCTAssertEqual(value.saved.fields["title"], "Saved")
    }
    func testLicenseReleaseContentAndTermsMustMatchOriginalInstallation() throws {
        for key in ["licenseId", "moduleId", "releaseId", "contentHash", "termsHash"] {
            let options = try changed(Self.options()) { $0[key] = key.hasSuffix("Hash") ? String(repeating: "b", count: 64) : "other" }
            XCTAssertThrowsError(try snapshot(options: options), key)
        }
    }
    func testBindingRequirementsMustMatchInstalledBindings() throws {
        let options = try changed(Self.options()) { $0["requiredBindings"] = [["key": "other", "kind": "POI"]] }
        XCTAssertThrowsError(try snapshot(options: options))
    }
    func testEditorIdentityAndBindingCannotBeSubstituted() throws {
        for key in ["installationRequestId", "licenseId", "bindingHash", "templateId"] {
            let saved = try changed(Self.saved()) { object in
                if key == "templateId" { object[key] = 99 }
                else { object[key] = key == "bindingHash" ? String(repeating: "b", count: 64) : "other" }
            }
            XCTAssertThrowsError(try snapshot(saved: saved), key)
        }
    }
    func testSavedHashAndAdvancedGraphMustBelongToFullSavedSnapshot() throws {
        let saved = try Self.saved()
        XCTAssertThrowsError(try snapshot(saved: changed(saved) { $0["draftContentHash"] = Self.hash }))
        XCTAssertThrowsError(try snapshot(saved: changed(saved) { $0["advancedConfigJson"] = Self.graph.replacingOccurrences(of: "Saved story", with: "Not saved") }))
        XCTAssertThrowsError(try snapshot(saved: changed(saved) { $0["validationMethod"] = 1 }))
    }
    func testMissingProjectedSavedTextAndNonPrivateDraftFailClosed() throws {
        XCTAssertThrowsError(try snapshot(saved: changed(Self.saved()) { $0["fields"] = ["title": "Saved", "ruleInstructions": "Saved rules"] }))
        XCTAssertThrowsError(try snapshot(saved: changed(Self.saved()) { $0["editable"] = false }))
        XCTAssertThrowsError(try snapshot(saved: changed(Self.saved()) { $0["publishStatus"] = 1 }))
    }
    func testUnsupportedAndDuplicateConfigNeverBecomesDefaultBranch() throws {
        for graph in ["{}", "{\"schemaVersion\":1,\"schemaVersion\":1,\"branch\":{}}", Self.graph.replacingOccurrences(of: "\"schemaVersion\":1", with: "\"reward\":{},\"schemaVersion\":1"), Self.graph.replacingOccurrences(of: "\"enabled\":true", with: "\"enabled\":false")] {
            XCTAssertThrowsError(try snapshot(saved: Self.saved(graph: graph)))
        }
    }
    func testReviewRequiredAndRetirementCannotRevive() throws {
        let visit = ModInstallationSavedRehearsal(snapshot: try snapshot(), current: { true })
        XCTAssertNil(visit.snapshot); visit.appear(); XCTAssertTrue(visit.available); XCTAssertFalse(visit.started)
        visit.start(); XCTAssertTrue(visit.admitBranch()); visit.retire(); visit.appear(); visit.start()
        XCTAssertFalse(visit.available); XCTAssertFalse(visit.admitBranch())
    }
    func testCapturedBranchActionBeforeReviewIsRejected() throws {
        let visit = ModInstallationSavedRehearsal(snapshot: try snapshot(), current: { true }); visit.appear()
        XCTAssertFalse(visit.admitBranch()); visit.start(); XCTAssertFalse(visit.available)
    }
    func testFreshSavedVersionReadPreservesOriginalBufferStateAndStorage() async throws {
        let (editor, service, memory, _) = try editor(); await editor.open(); editor.setText("title", value: "Unsaved buffer")
        let oldState = editor.state, oldDraft = editor.draft, oldStore = memory.values
        service.saved = try Self.saved(title: "Newer server save")
        let visit = try await editor.readSavedRehearsal(); visit.appear()
        XCTAssertEqual(visit.snapshot?.saved.fields["title"], "Newer server save")
        XCTAssertEqual(editor.state, oldState); XCTAssertEqual(editor.draft, oldDraft)
        visit.start(); XCTAssertTrue(visit.admitBranch()); visit.retire()
        XCTAssertEqual(editor.draft["title"], "Unsaved buffer"); XCTAssertTrue(editor.hasChanges)
        XCTAssertEqual(memory.values, oldStore); XCTAssertEqual(memory.writes, 0); XCTAssertEqual(service.writes, 0)
        XCTAssertEqual(service.editorReads, 2); XCTAssertEqual(service.optionReads, 1)
    }
    func testReadGrantDoesNotRequireInstallOrReviewWriteGrant() async throws {
        let (editor, service, _, _) = try editor(); service.canMutate = false; await editor.open()
        XCTAssertFalse(editor.canEdit); XCTAssertTrue(editor.canReadSavedRehearsal)
        let visit = try await editor.readSavedRehearsal(); visit.appear(); XCTAssertTrue(visit.available); XCTAssertEqual(service.writes, 0)
    }
    func testMissingGrantBlocksBothReadsEvenWithMutationPermission() async throws {
        let (editor, service, _, _) = try editor(); await editor.open(); service.canReadInstalledTemplateRehearsal = false
        XCTAssertFalse(editor.canReadSavedRehearsal); await deniedRead(editor)
        XCTAssertEqual(service.editorReads, 1); XCTAssertEqual(service.optionReads, 0)
    }
    func testInactiveLicenseCannotFallBackToSavedEditorOrPreviousVisit() async throws {
        let (editor, service, _, _) = try editor(); await editor.open()
        let old = try await editor.readSavedRehearsal(); old.appear(); XCTAssertTrue(old.available)
        service.inactiveLicense = true; await deniedRead(editor); XCTAssertFalse(old.available); XCTAssertEqual(service.writes, 0)
    }
    func testFailedFreshEditorReadNeverUsesOldStateAndSkipsLicenseRead() async throws {
        let (editor, service, _, _) = try editor(); await editor.open(); service.failEditor = true
        await deniedRead(editor); XCTAssertEqual(service.optionReads, 0); XCTAssertEqual(editor.state?.fields["title"], "Saved")
    }
    func testLateEditorReadAfterLeaveCannotPerformSecondRead() async throws {
        let (editor, service, _, _) = try editor(); await editor.open()
        service.onEditorRead = { editor.invalidateSavedRehearsal() }
        await deniedRead(editor); XCTAssertEqual(service.optionReads, 0)
    }
    func testLateLicenseReadAfterBackgroundCannotPresent() async throws {
        let (editor, service, _, _) = try editor(); await editor.open()
        service.onOptionsRead = { editor.invalidateSavedRehearsal() }; await deniedRead(editor)
        XCTAssertEqual(service.optionReads, 1); XCTAssertEqual(service.writes, 0)
    }
    func testOwnerOrGrantChangeDuringLicenseReadCannotPresent() async throws {
        let (editor, service, _, _) = try editor(); await editor.open()
        service.onOptionsRead = { service.isCurrent = false }; await deniedRead(editor)
        service.isCurrent = true; service.onOptionsRead = { service.canReadInstalledTemplateRehearsal = false }; await deniedRead(editor)
    }
    func testLaterVisitAndEditorChangesInvalidateCapturedBranchActions() async throws {
        let (editor, _, _, _) = try editor(); await editor.open()
        let old = try await editor.readSavedRehearsal(); old.appear(); old.start()
        let new = try await editor.readSavedRehearsal(); new.appear(); new.start()
        XCTAssertFalse(old.admitBranch()); XCTAssertTrue(new.admitBranch())
        editor.setText("title", value: "Changed later"); XCTAssertFalse(new.admitBranch())
    }
    func testRevokedGrantAndAccountCannotReviveRetiredVisit() async throws {
        let (editor, service, _, _) = try editor(); await editor.open()
        let visit = try await editor.readSavedRehearsal(); visit.appear(); visit.start()
        service.canReadInstalledTemplateRehearsal = false; XCTAssertFalse(visit.admitBranch())
        service.canReadInstalledTemplateRehearsal = true; XCTAssertFalse(visit.admitBranch())
        service.isCurrent = false; XCTAssertNil(visit.snapshot)
    }
    func testUnknownPersistedEditBlocksReadsWithoutRetryingOrWriting() async throws {
        let (editor, service, memory, store) = try editor(); await editor.open()
        let saved = try Self.saved()
        let pending = ModInstallationTemplateEditPending(installation: Self.installation(), command: .init(editRequestId: UUID().uuidString.lowercased(), action: "SAVE", expectedDraftHash: saved.draftContentHash, fields: ["title": "Unknown"]), reviewedSnapshotJson: saved.snapshotJson, receipt: nil)
        try store.beginTemplateEdit(pending); let before = memory.values
        await deniedRead(editor); XCTAssertEqual(service.editorReads, 1); XCTAssertEqual(service.optionReads, 0)
        XCTAssertEqual(memory.values, before); XCTAssertEqual(service.writes, 0)
    }
    func testUnknownParentFactWriteAlsoBlocksRehearsal() async throws {
        let (editor, service, _, store) = try editor(); await editor.open()
        var attempt = try ModInstallationAttempt(restoring: Self.installation())
        attempt.pendingFacts = .init(facts: .init(schema: "mod-installation-facts-v1", requestId: Self.installation().requestId, licenseId: "license", draftId: 30, merchantId: 10, bindingHash: Self.hash, draftContentHash: Self.hash, title: "Saved", rules: "Saved rules", confirmed: false, bindings: [])); try store.begin(attempt)
        await deniedRead(editor); XCTAssertEqual(service.editorReads, 1); XCTAssertEqual(service.optionReads, 0)
    }
    func testStorageFailureFailsClosedWithoutNetworkOrBufferLoss() async throws {
        let (editor, service, memory, _) = try editor(); await editor.open(); editor.setText("title", value: "Keep me")
        memory.failRead = true; await deniedRead(editor)
        XCTAssertEqual(editor.draft["title"], "Keep me"); XCTAssertEqual(service.editorReads, 1); XCTAssertEqual(service.writes, 0)
    }
    func testRepeatedTapWhileReadInFlightIsUnavailable() async throws {
        let (editor, service, _, _) = try editor(); await editor.open()
        service.onEditorRead = { XCTAssertTrue(editor.busy); XCTAssertFalse(editor.canReadSavedRehearsal) }
        _ = try await editor.readSavedRehearsal(); XCTAssertFalse(editor.busy)
    }
    func testApprovalDefaultsOffAndNeverMintsWriteAccess() throws {
        let context = try context()
        let absent = try ModInstallationApproval(context: context, expiresAt: Date().addingTimeInterval(60), readApprovalReference: "synthetic-read", installApprovalReference: "synthetic-install")
        let old = try ModInstallationService(lease: .init(context: context, current: { context }), approval: absent, currentApproval: { absent })
        XCTAssertTrue(old.canMutate); XCTAssertFalse(old.canReadInstalledTemplateRehearsal)
        var grant: ModInstallationApproval? = try .init(context: context, expiresAt: Date().addingTimeInterval(60), readApprovalReference: "synthetic-read", templateRehearsalReadApprovalReference: "synthetic-rehearsal")
        let service = try ModInstallationService(lease: .init(context: context, current: { context }), approval: XCTUnwrap(grant), currentApproval: { grant })
        XCTAssertTrue(service.canReadInstalledTemplateRehearsal); XCTAssertFalse(service.canMutate); XCTAssertFalse(service.canReviewInstalledTemplate)
        grant = nil; XCTAssertFalse(service.canReadInstalledTemplateRehearsal)
        XCTAssertThrowsError(try ModInstallationApproval(context: context, expiresAt: Date().addingTimeInterval(60), readApprovalReference: "synthetic-read", templateRehearsalReadApprovalReference: " "))
    }
}
