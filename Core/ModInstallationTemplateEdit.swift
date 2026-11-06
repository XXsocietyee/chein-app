import Foundation
import Observation
import CryptoKit

public struct ModInstallationTemplateEditorState: Codable, Equatable {
    public let schema, installationRequestId, licenseId, bindingHash, draftContentHash, snapshotJson: String
    public let templateId: Int64
    public let fields: [String: String]
    public let editable, factsConfirmed: Bool
    public let validationMethod: Int?
    public let advancedConfigJson: String?
    public let draftStatus, checkStatus: Int?
    public let status, publishStatus, auditTaskId: Int64?
    public let auditStatus: Int?
    func validate(_ installation: ModInstallationReceipt) throws {
        try installation.validate(identity: installation.identity)
        guard installation.memberTemplateID != nil, schema == "mod-installation-template-editor-v1", installationRequestId == installation.requestId,
              licenseId == installation.licenseId, templateId == installation.draftId, bindingHash == installation.bindingHash,
              Set(fields.keys).isSubset(of: Set(ModInstallationTemplateEditCommand.editable)),
              fields["title"]?.isEmpty == false, fields["ruleInstructions"]?.isEmpty == false,
              !editable || (draftStatus == 0 && status == 0 && publishStatus == 0),
              auditTaskId == nil || auditTaskId! > 0, auditStatus == nil || (0...4).contains(auditStatus!) else { throw ModInstallationIssue.malformed }
        let snapshot = try ModInstallationTemplateEditCommand.snapshot(snapshotJson, hash: draftContentHash, templateId: templateId)
        for (key, text) in fields { guard snapshot[key] == .string(text) else { throw ModInstallationIssue.malformed } }
        if let advancedConfigJson, !advancedConfigJson.isEmpty { _ = try ContentDraftJSON.parse(advancedConfigJson) }
    }
}
public struct ModInstallationTemplateEditCommand: Codable, Equatable {
    public static let editable = ["title", "description", "players", "usageLocation", "requiredMaterials", "difficulty", "ruleInstructions", "merchantGuide", "questionName", "questionAnswer", "feedbackText", "questionA", "questionB", "questionC", "questionD", "correctAnswer", "storyText", "hint1", "hint2", "answerReveal", "photoRequireDesc"]
    public let editRequestId, action, expectedDraftHash: String
    public let fields: [String: String]
    func validate() throws {
        guard UUID(uuidString: editRequestId)?.uuidString.lowercased() == editRequestId,
              ["SAVE", "CONFIRM_FACTS", "REVIEW"].contains(action), Set(fields.keys).isSubset(of: Set(Self.editable)),
              (action == "SAVE" ? !fields.isEmpty : fields.isEmpty) else { throw ModInstallationIssue.malformed }
        try ModInstallationValidation.hash(expectedDraftHash)
        var bytes = 0
        for (key, text) in fields {
            bytes += text.utf8.count
            guard text.utf16.count <= (key == "title" ? 512 : 32000), !text.contains("{{"),
                  !["<script", "<iframe", "javascript:", "https://", "http://", "file://"].contains(where: text.lowercased().contains),
                  !["title", "ruleInstructions"].contains(key) || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ModInstallationIssue.malformed }
        }
        guard bytes <= 262144 else { throw ModInstallationIssue.malformed }
    }
    static func snapshot(_ text: String, hash: String, templateId: Int64) throws -> [String: TemplateAuthoringJSON] {
        try ModInstallationValidation.hash(hash)
        guard text.utf8.count <= 1048576, SHA256.hash(data: Data(text.utf8)).map({ String(format: "%02x", $0) }).joined() == hash else { throw ModInstallationIssue.malformed }
        _ = try ContentDraftJSON.parse(text)
        let value = try JSONDecoder().decode([String: TemplateAuthoringJSON].self, from: Data(text.utf8))
        struct Identity: Decodable { let bizType: String; let bizId: Int64 }
        let identity = try JSONDecoder().decode(Identity.self, from: Data(text.utf8))
        guard identity.bizType == "TEMPLATE", identity.bizId == templateId else { throw ModInstallationIssue.malformed }
        return value
    }
}
public struct ModInstallationTemplateEditReceipt: Codable, Equatable {
    public let schema, installationRequestId, editRequestId, action, previousDraftHash, resultDraftHash, snapshotJson: String
    public let templateId: Int64
    public let auditTaskId: Int64?
    func validate(_ pending: ModInstallationTemplateEditPending) throws {
        let command = pending.command; try command.validate()
        guard schema == "mod-installation-template-edit-receipt-v1", installationRequestId == pending.installation.requestId,
              editRequestId == command.editRequestId, action == command.action, templateId == pending.installation.draftId,
              previousDraftHash == command.expectedDraftHash,
              (action == "REVIEW" ? (auditTaskId ?? 0) > 0 : auditTaskId == nil) else { throw ModInstallationIssue.malformed }
        let snapshot = try ModInstallationTemplateEditCommand.snapshot(snapshotJson, hash: resultDraftHash, templateId: templateId)
        var expected = try ModInstallationTemplateEditCommand.snapshot(pending.reviewedSnapshotJson, hash: previousDraftHash, templateId: templateId)
        for (key, text) in command.fields { expected[key] = .string(text) }
        guard snapshot == expected else { throw ModInstallationIssue.malformed }
        if action != "SAVE" { guard previousDraftHash == resultDraftHash else { throw ModInstallationIssue.malformed } }
    }
}
public struct ModInstallationTemplateEditPending: Codable, Equatable, Identifiable {
    public var id: String { command.editRequestId }
    public let installation: ModInstallationReceipt
    public let command: ModInstallationTemplateEditCommand
    public let reviewedSnapshotJson: String
    public var receipt: ModInstallationTemplateEditReceipt?
    func validate() throws {
        try installation.validate(identity: installation.identity); try command.validate()
        guard installation.memberTemplateID != nil, let id = installation.draftId else { throw ModInstallationIssue.malformed }
        _ = try ModInstallationTemplateEditCommand.snapshot(reviewedSnapshotJson, hash: command.expectedDraftHash, templateId: id)
        if let receipt { try receipt.validate(self) }
    }
}

/// Scoped to one authoritative installed ID; does not opt global TemplateAuthoring into existing-ID writes.
@MainActor @Observable public final class ModInstallationTemplateEditor: Identifiable {
    public let id = UUID()
    public let installation: ModInstallationReceipt
    public private(set) var state: ModInstallationTemplateEditorState?
    public private(set) var draft: [String: String] = [:]
    public private(set) var pending: ModInstallationTemplateEditPending?
    public private(set) var review: ModInstallationTemplateEditPending?
    public private(set) var busy = false
    public private(set) var retryOriginalAvailable = false
    public private(set) var messageKey: String?
    private let service: any ModInstallationServing
    private let store: ModInstallationPendingStore
    private var rehearsalGeneration = UUID()
    init(installation: ModInstallationReceipt, service: any ModInstallationServing, store: ModInstallationPendingStore) {
        self.installation = installation; self.service = service; self.store = store
    }
    public var isCurrent: Bool { service.isCurrent }
    public var canEdit: Bool { isCurrent && service.canMutate && !busy && state?.editable == true && (pending == nil || pending?.receipt != nil) }
    public var hasChanges: Bool { draft != state?.fields }
    public var canConfirmFacts: Bool { canEdit && !hasChanges && state?.factsConfirmed == false }
    public var canSubmitReview: Bool { canEdit && !hasChanges && state?.factsConfirmed == true && service.canReviewInstalledTemplate }
    public func open() async {
        guard !busy else { return }; invalidateSavedRehearsal(); busy = true; defer { busy = false }
        // A refresh/receipt is not fresh draft authority. Preserve the original journal and receipt.
        state = nil; review = nil
        do {
            try check(); pending = try store.loadTemplateEdit(installation: installation)
            if let original = pending, original.receipt == nil { try await reconcile(original); return }
            try await readCurrent()
        } catch ModInstallationIssue.requestNotFound { messageKey = "templateEdit.unknown" }
        catch { messageKey = "templateEdit.unavailable" }
    }
    public func setText(_ key: String, value: String) {
        guard canEdit, ModInstallationTemplateEditCommand.editable.contains(key) else { return }; invalidateSavedRehearsal(); draft[key] = value; review = nil
    }
    public func prepare(_ action: String) {
        guard canEdit, let state, (action == "SAVE" ? hasChanges : (action == "CONFIRM_FACTS" ? canConfirmFacts : canSubmitReview)) else { return }
        invalidateSavedRehearsal()
        do {
            let changes = action == "SAVE" ? draft.filter { state.fields[$0.key] != $0.value } : [:]
            let command = ModInstallationTemplateEditCommand(editRequestId: UUID().uuidString.lowercased(), action: action, expectedDraftHash: state.draftContentHash, fields: changes)
            try command.validate(); review = .init(installation: installation, command: command, reviewedSnapshotJson: state.snapshotJson, receipt: nil); messageKey = nil
        } catch { messageKey = "templateEdit.invalid" }
    }
    public func cancelReview() { review = nil }
    public func confirm(_ original: ModInstallationTemplateEditPending) async {
        guard canEdit, review == original, original.command.action != "REVIEW" || canSubmitReview else { return }; invalidateSavedRehearsal(); busy = true; defer { busy = false }
        do { try check(); try store.beginTemplateEdit(original); pending = original; review = nil; try await dispatch(original) }
        catch { messageKey = pending?.receipt == nil ? "templateEdit.unknown" : "templateEdit.unavailable" }
    }
    public func retryOriginal() async {
        guard !busy, isCurrent, service.canMutate, retryOriginalAvailable, let original = pending, original.receipt == nil,
              original.command.action != "REVIEW" || service.canReviewInstalledTemplate else { return }
        invalidateSavedRehearsal(); busy = true; defer { busy = false }
        do {
            try check(); guard try store.loadTemplateEdit(installation: installation) == original else { throw ModInstallationIssue.pendingConflict }
            do { try await reconcile(original) }
            catch ModInstallationIssue.requestNotFound { try check(); try await dispatch(original) }
        } catch { messageKey = pending?.receipt == nil ? "templateEdit.unknown" : "templateEdit.unavailable" }
    }
    /// This entry is deliberately independent of canMutate/review approval. No local
    /// text is saved, reset, copied into the snapshot, or used as license evidence.
    public var savedRehearsalReadEnabled: Bool { isCurrent && service.canReadInstalledTemplateRehearsal }
    public var canReadSavedRehearsal: Bool {
        savedRehearsalReadEnabled && !busy && state != nil && review == nil &&
        (pending == nil || pending?.receipt != nil)
    }
    public func invalidateSavedRehearsal() { rehearsalGeneration = UUID() }
    public func readSavedRehearsal() async throws -> ModInstallationSavedRehearsal {
        guard canReadSavedRehearsal else { throw ModInstallationIssue.disabled }
        invalidateSavedRehearsal(); let ticket = rehearsalGeneration
        busy = true; defer { busy = false }
        try checkSavedRehearsal(ticket)
        let saved = try await service.templateEditor(installation)
        try checkSavedRehearsal(ticket)
        // The editor GET attests ownership, not an ACTIVE commerce license. The
        // existing options GET separately rechecks owner + ACTIVE + frozen artifact/terms.
        let options = try await service.options(identity: installation.identity, merchantId: nil)
        try checkSavedRehearsal(ticket)
        let snapshot = try ModInstallationSavedRehearsalSnapshot(installation: installation, saved: saved, options: options)
        return ModInstallationSavedRehearsal(snapshot: snapshot) { [weak self] in
            guard let self, !self.busy else { return false }
            return (try? self.checkSavedRehearsal(ticket)) != nil
        }
    }
    private func checkSavedRehearsal(_ ticket: UUID) throws {
        try Task.checkCancellation(); try check()
        guard rehearsalGeneration == ticket, service.canReadInstalledTemplateRehearsal, review == nil,
              pending == nil || pending?.receipt != nil else { throw ModInstallationIssue.disabled }
        let stored = try store.loadTemplateEdit(installation: installation)
        guard stored == pending, stored == nil || stored?.receipt != nil else { throw ModInstallationIssue.pendingConflict }
        // A lost fact-confirmation response is also an unresolved write, even if
        // it originated from the parent installation screen rather than this editor.
        if let attempt = try store.load() {
            guard attempt.pendingAction == nil, attempt.pendingFacts == nil else { throw ModInstallationIssue.pendingConflict }
        }
    }
    private func dispatch(_ original: ModInstallationTemplateEditPending) async throws {
        retryOriginalAvailable = false
        do { try accept(try await service.saveTemplateEdit(original)); try await readCurrent() }
        catch ModInstallationIssue.prepareRejected {
            try check(); try store.rejectTemplateEdit(original); pending = nil; messageKey = "templateEdit.rejected"; try await readCurrent()
        }
    }
    private func reconcile(_ original: ModInstallationTemplateEditPending) async throws {
        retryOriginalAvailable = false
        do { try accept(try await service.templateEditReceipt(original)); try await readCurrent() }
        catch ModInstallationIssue.requestNotFound { try check(); retryOriginalAvailable = true; messageKey = "templateEdit.unknown"; throw ModInstallationIssue.requestNotFound }
    }
    private func accept(_ receipt: ModInstallationTemplateEditReceipt) throws {
        try check(); guard var original = pending else { throw ModInstallationIssue.pendingConflict }; try receipt.validate(original)
        original.receipt = receipt; try store.acceptTemplateEdit(original); pending = original; messageKey = "templateEdit.received"
    }
    private func readCurrent() async throws {
        // Failed or revoked current reads must not re-enable edits from the pre-write state.
        state = nil; review = nil
        let value = try await service.templateEditor(installation); try check(); try value.validate(installation); state = value; draft = value.fields
    }
    private func check() throws { guard isCurrent else { throw ModInstallationIssue.staleSession } }
}
