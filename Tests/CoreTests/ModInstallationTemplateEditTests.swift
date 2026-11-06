import XCTest
import CryptoKit
@testable import QuestifyCore

@MainActor final class ModInstallationTemplateEditTests: XCTestCase {
    private let fixtureHash = String(repeating: "a", count: 64)
    private func installation() -> ModInstallationReceipt {
        .init(schema: "mod-installation-receipt-v1", requestId: "00000000-0000-0000-0000-000000000001", licenseId: "license", moduleId: "module", releaseId: "release", contentHash: fixtureHash, termsHash: fixtureHash, state: .installed, merchantId: 10, anchorPoiId: 20, region: "test", bindingHash: fixtureHash, draftId: 30, editKind: "MEMBER_TEMPLATE", createdAt: "2026-10-21T00:00:00.000000Z", errorCode: nil, published: false, executable: false, requiredGates: ["MERCHANT_FACT_CONFIRMATION", "THEME_CONTENT_REVIEW", "W02_PUBLISH"], bindings: [])
    }
    private func context(account: Int = 7, epoch: UInt64 = 1) throws -> RuntimeDependencyContext {
        .init(market: .china, baseURL: URL(string: "https://example.com/native")!, role: "merchant", session: try .init(accountID: account, epoch: epoch, namespace: "synthetic-installed-template", token: "synthetic-session", role: "merchant"))
    }
    private static func digest(_ text: String) -> String { SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined() }
    private static func snapshot(_ title: String = "Original", description: String = "Preserved") -> String {
        "{\"bizType\":\"TEMPLATE\",\"bizId\":30,\"title\":\"\(title)\",\"ruleInstructions\":\"Rules\",\"description\":\"\(description)\"}"
    }
    private func pending(action: String = "SAVE") -> ModInstallationTemplateEditPending {
        .init(installation: installation(), command: .init(editRequestId: "00000000-0000-0000-0000-000000000002", action: action, expectedDraftHash: Self.digest(Self.snapshot()), fields: action == "SAVE" ? ["title": "Changed"] : [:]), reviewedSnapshotJson: Self.snapshot(), receipt: nil)
    }
    private final class Memory: TemplateAuthoringStorage {
        var values: [String: Data] = [:]; var failWrite = false; var failRead = false
        func read(_ key: String) throws -> Data? { if failRead { throw ModInstallationIssue.storageUnavailable }; return values[key] }
        func write(_ data: Data, key: String) throws { if failWrite { throw ModInstallationIssue.storageUnavailable }; values[key] = data }
        func remove(_ key: String) throws { values.removeValue(forKey: key) }
    }
    func testFullSnapshotIdentityHashAndUnrelatedContentMustMatch() throws {
        let original = pending(); try original.validate()
        let changed = Self.snapshot("Changed")
        let receipt = ModInstallationTemplateEditReceipt(schema: "mod-installation-template-edit-receipt-v1", installationRequestId: installation().requestId, editRequestId: original.id, action: "SAVE", previousDraftHash: original.command.expectedDraftHash, resultDraftHash: Self.digest(changed), snapshotJson: changed, templateId: 30, auditTaskId: nil)
        try receipt.validate(original)
        let unrelated = Self.snapshot("Changed", description: "LOST")
        let wrong = ModInstallationTemplateEditReceipt(schema: receipt.schema, installationRequestId: receipt.installationRequestId, editRequestId: receipt.editRequestId, action: receipt.action, previousDraftHash: receipt.previousDraftHash, resultDraftHash: Self.digest(unrelated), snapshotJson: unrelated, templateId: 30, auditTaskId: nil)
        XCTAssertThrowsError(try wrong.validate(original))
        XCTAssertThrowsError(try ModInstallationTemplateEditCommand.snapshot(changed, hash: original.command.expectedDraftHash, templateId: 30))
        XCTAssertThrowsError(try ModInstallationTemplateEditCommand.snapshot(changed, hash: Self.digest(changed), templateId: 999))
    }
    func testNoClientIdentityStatusAdvancedGraphOrMixedReviewChanges() {
        for fields in [["id": "30"], ["memberId": "7"], ["status": "1"], ["advancedConfigJson": "{}"], ["title": " "], ["ruleInstructions": "{{SITE:other}}"]] {
            XCTAssertThrowsError(try ModInstallationTemplateEditCommand(editRequestId: pending().id, action: "SAVE", expectedDraftHash: fixtureHash, fields: fields).validate())
        }
        XCTAssertThrowsError(try ModInstallationTemplateEditCommand(editRequestId: pending().id, action: "REVIEW", expectedDraftHash: fixtureHash, fields: ["title": "Changed"]).validate())
        XCTAssertThrowsError(try ModInstallationTemplateEditCommand(editRequestId: pending().id, action: "CONFIRM_FACTS", expectedDraftHash: fixtureHash, fields: ["title": "Changed"]).validate())
    }
    func testDurableOriginalKeyAccountIsolationAndReadback() throws {
        let memory = Memory(), original = pending(), store = ModInstallationPendingStore(storage: memory, context: try context(), identity: installation().identity)
        memory.failWrite = true; XCTAssertThrowsError(try store.beginTemplateEdit(original)); XCTAssertNil(try store.loadTemplateEdit(installation: installation()))
        memory.failWrite = false; try store.beginTemplateEdit(original)
        let restored = ModInstallationPendingStore(storage: memory, context: try context(epoch: 2), identity: installation().identity)
        XCTAssertEqual(try restored.loadTemplateEdit(installation: installation()), original)
        XCTAssertNil(try ModInstallationPendingStore(storage: memory, context: context(account: 8), identity: installation().identity).loadTemplateEdit(installation: installation()))
        let other = ModInstallationTemplateEditPending(installation: installation(), command: .init(editRequestId: UUID().uuidString.lowercased(), action: "SAVE", expectedDraftHash: original.command.expectedDraftHash, fields: ["title": "Other"]), reviewedSnapshotJson: original.reviewedSnapshotJson, receipt: nil)
        XCTAssertThrowsError(try restored.beginTemplateEdit(other))
    }
    private final class Service: ModInstallationServing {
        var failCurrent = false
        var isCurrent = true; var canMutate = true; var canReviewInstalledTemplate = false
        var writes = 0; var reads = 0; var loseResponse = false; var committed: [String: ModInstallationTemplateEditReceipt] = [:]
        var snapshot = ModInstallationTemplateEditTests.snapshot(); var confirmed = false; var submitted = false
        let installation: ModInstallationReceipt
        init(_ installation: ModInstallationReceipt) { self.installation = installation }
        func invalidate() { isCurrent = false }
        func templateEditor(_ installation: ModInstallationReceipt) async throws -> ModInstallationTemplateEditorState {
            if failCurrent { throw ModInstallationIssue.unavailable }
            let fields = try JSONDecoder().decode([String: TemplateAuthoringJSON].self, from: Data(snapshot.utf8)).filter { ModInstallationTemplateEditCommand.editable.contains($0.key) }.compactMapValues(\.string)
            return .init(schema: "mod-installation-template-editor-v1", installationRequestId: installation.requestId, licenseId: installation.licenseId, bindingHash: installation.bindingHash, draftContentHash: ModInstallationTemplateEditTests.digest(snapshot), snapshotJson: snapshot, templateId: 30, fields: fields, editable: !submitted, factsConfirmed: confirmed, validationMethod: 1, advancedConfigJson: nil, draftStatus: submitted ? 1 : 0, checkStatus: 0, status: 0, publishStatus: 0, auditTaskId: submitted ? 90 : nil, auditStatus: submitted ? 0 : nil)
        }
        func saveTemplateEdit(_ pending: ModInstallationTemplateEditPending) async throws -> ModInstallationTemplateEditReceipt {
            writes += 1
            if let old = committed[pending.id] { return old }
            if pending.command.action == "SAVE" {
                var fields = try JSONDecoder().decode([String: TemplateAuthoringJSON].self, from: Data(snapshot.utf8))
                for (key, value) in pending.command.fields { fields[key] = .string(value) }
                snapshot = String(decoding: try JSONEncoder().encode(fields), as: UTF8.self); confirmed = false
            } else if pending.command.action == "CONFIRM_FACTS" { confirmed = true }
            else { guard confirmed, canReviewInstalledTemplate else { throw ModInstallationIssue.prepareRejected }; submitted = true }
            let receipt = ModInstallationTemplateEditReceipt(schema: "mod-installation-template-edit-receipt-v1", installationRequestId: installation.requestId, editRequestId: pending.id, action: pending.command.action, previousDraftHash: pending.command.expectedDraftHash, resultDraftHash: ModInstallationTemplateEditTests.digest(snapshot), snapshotJson: snapshot, templateId: 30, auditTaskId: submitted ? 90 : nil)
            committed[pending.id] = receipt
            if loseResponse { throw ModInstallationIssue.unavailable }; return receipt
        }
        func templateEditReceipt(_ pending: ModInstallationTemplateEditPending) async throws -> ModInstallationTemplateEditReceipt { reads += 1; guard let value = committed[pending.id] else { throw ModInstallationIssue.requestNotFound }; return value }
        func options(identity: ModInstallationIdentity, merchantId: Int64?) async throws -> ModInstallationOptions { throw ModInstallationIssue.unavailable }
        func prepare(_ attempt: ModInstallationAttempt) async throws -> ModInstallationReceipt { throw ModInstallationIssue.unavailable }
        func request(_ requestId: String, identity: ModInstallationIdentity) async throws -> ModInstallationReceipt { throw ModInstallationIssue.unavailable }
        func install(_ prepared: ModInstallationReceipt) async throws -> ModInstallationReceipt { throw ModInstallationIssue.unavailable }
        func cancel(_ prepared: ModInstallationReceipt) async throws -> ModInstallationReceipt { throw ModInstallationIssue.unavailable }
        func preview(_ receipt: ModInstallationReceipt) async throws -> ModInstallationPreview { throw ModInstallationIssue.unavailable }
        func facts(_ receipt: ModInstallationReceipt) async throws -> ModInstallationFacts { throw ModInstallationIssue.unavailable }
        func confirmFacts(_ facts: ModInstallationFacts, receipt: ModInstallationReceipt) async throws -> ModInstallationFacts { throw ModInstallationIssue.unavailable }
        func history(identity: ModInstallationIdentity) async throws -> [ModInstallationReceipt] { throw ModInstallationIssue.unavailable }
    }
    func testLostSaveThenExplicitFactsAndReviewRecoveredWithoutSecondReview() async throws {
        let memory = Memory(), installation = installation(), service = Service(installation)
        let store = ModInstallationPendingStore(storage: memory, context: try context(), identity: installation.identity)
        let editor = ModInstallationTemplateEditor(installation: installation, service: service, store: store)
        await editor.open(); XCTAssertFalse(editor.canSubmitReview)
        editor.setText("title", value: "Changed"); editor.prepare("SAVE"); service.loseResponse = true
        await editor.confirm(try XCTUnwrap(editor.review)); XCTAssertEqual(service.writes, 1); XCTAssertNil(editor.pending?.receipt)
        let restored = ModInstallationTemplateEditor(installation: installation, service: service, store: ModInstallationPendingStore(storage: memory, context: try context(epoch: 2), identity: installation.identity))
        await restored.open(); XCTAssertEqual(service.writes, 1); XCTAssertEqual(service.reads, 1); XCTAssertEqual(restored.draft["title"], "Changed")
        XCTAssertTrue(restored.canConfirmFacts); XCTAssertFalse(service.confirmed); XCTAssertFalse(service.submitted)
        service.loseResponse = false; restored.prepare("CONFIRM_FACTS"); await restored.confirm(try XCTUnwrap(restored.review))
        XCTAssertEqual(service.writes, 2); XCTAssertTrue(service.confirmed); XCTAssertFalse(service.submitted); XCTAssertFalse(restored.canSubmitReview)
        service.canReviewInstalledTemplate = true; restored.prepare("REVIEW"); service.loseResponse = true
        let review = try XCTUnwrap(restored.review); await restored.confirm(review); XCTAssertEqual(service.writes, 3)
        let again = ModInstallationTemplateEditor(installation: installation, service: service, store: store)
        await again.open(); XCTAssertEqual(service.writes, 3); XCTAssertEqual(again.pending?.receipt?.editRequestId, review.id); XCTAssertEqual(again.pending?.receipt?.auditTaskId, 90); XCTAssertFalse(again.canEdit)
        service.isCurrent = false; XCTAssertFalse(again.isCurrent); again.prepare("SAVE"); XCTAssertNil(again.review)
    }
    func testStorageFailurePreventsOriginalMutation() async throws {
        let memory = Memory(), installation = installation(), service = Service(installation)
        let editor = ModInstallationTemplateEditor(installation: installation, service: service, store: ModInstallationPendingStore(storage: memory, context: try context(), identity: installation.identity))
        await editor.open(); editor.setText("title", value: "Changed"); editor.prepare("SAVE"); memory.failWrite = true
        await editor.confirm(try XCTUnwrap(editor.review)); XCTAssertEqual(service.writes, 0)
    }
    func testReviewGrantNeverInferredFromInstallationGrant() throws {
        let context = try context()
        let original = try ModInstallationApproval(context: context, expiresAt: Date().addingTimeInterval(60), readApprovalReference: "synthetic-read", installApprovalReference: "synthetic-install")
        XCTAssertNil(original.templateReviewApprovalReference)
        let separate = try ModInstallationApproval(context: context, expiresAt: Date().addingTimeInterval(60), readApprovalReference: "synthetic-read", installApprovalReference: "synthetic-install", templateReviewApprovalReference: "synthetic-review")
        XCTAssertNotNil(separate.templateReviewApprovalReference); XCTAssertNotEqual(original.revision, separate.revision)
    }
    func testCommittedReceiptSurvivesFailedCurrentReadWithoutStaleEditAuthority() async throws {
        let memory = Memory(), original = installation(), service = Service(original)
        let store = ModInstallationPendingStore(storage: memory, context: try context(), identity: original.identity)
        let editor = ModInstallationTemplateEditor(installation: original, service: service, store: store)
        await editor.open(); editor.setText("title", value: "Changed"); editor.prepare("SAVE")
        let command = try XCTUnwrap(editor.review); service.failCurrent = true
        await editor.confirm(command)
        XCTAssertEqual(service.writes, 1); XCTAssertNotNil(editor.pending?.receipt)
        XCTAssertEqual(editor.messageKey, "templateEdit.unavailable")
        XCTAssertNil(editor.state); XCTAssertFalse(editor.canEdit); XCTAssertFalse(editor.canConfirmFacts)
        XCTAssertFalse(editor.canSubmitReview); XCTAssertFalse(editor.canReadSavedRehearsal)
        XCTAssertEqual(try store.loadTemplateEdit(installation: original)?.receipt, editor.pending?.receipt)
        editor.prepare("SAVE"); XCTAssertNil(editor.review)
        let restarted = ModInstallationTemplateEditor(installation: original, service: service,
            store: ModInstallationPendingStore(storage: memory, context: try context(epoch: 2), identity: original.identity))
        await restarted.open(); XCTAssertNotNil(restarted.pending?.receipt); XCTAssertNil(restarted.state)
        XCTAssertFalse(restarted.canEdit); XCTAssertEqual(service.writes, 1)
        service.failCurrent = false; await restarted.open()
        XCTAssertTrue(restarted.canEdit); XCTAssertEqual(restarted.draft["title"], "Changed"); XCTAssertEqual(service.writes, 1)
        service.isCurrent = false; await restarted.open()
        XCTAssertNil(restarted.state); XCTAssertFalse(restarted.canEdit); XCTAssertNotNil(restarted.pending?.receipt)
    }
    func testFailedCurrentOrJournalRefreshRetiresPriorConfirmationWithoutDiscardingDraft() async throws {
        let memory = Memory(), original = installation(), service = Service(original)
        let editor = ModInstallationTemplateEditor(installation: original, service: service,
            store: ModInstallationPendingStore(storage: memory, context: try context(), identity: original.identity))
        await editor.open(); editor.setText("title", value: "Unsaved"); editor.prepare("SAVE")
        XCTAssertNotNil(editor.review); memory.failRead = true; await editor.open()
        XCTAssertNil(editor.state); XCTAssertNil(editor.review); XCTAssertFalse(editor.canEdit)
        XCTAssertEqual(editor.draft["title"], "Unsaved"); XCTAssertEqual(service.writes, 0)
        memory.failRead = false; service.failCurrent = true; await editor.open()
        XCTAssertNil(editor.state); XCTAssertFalse(editor.canEdit); XCTAssertEqual(service.writes, 0)
    }

}
