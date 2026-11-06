import Foundation
import Observation

public struct ModInstallationQaEditorState: Codable, Equatable {
    public struct Node: Codable, Equatable, Identifiable {
        public var id: String { sourceNodeId }
        public let sourceNodeId, title, advancedConfigJson: String
        public let nodeId, templateId: Int64
    }
    public let schema, installationRequestId, licenseId, bindingHash, draftContentHash, locale: String
    public let topicId: Int64
    public let nodes: [Node]
    func validate(_ installation: ModInstallationReceipt) throws {
        try installation.validate(identity: installation.identity)
        guard installation.topicID != nil, schema == "mod-installation-qa-editor-v1", installationRequestId == installation.requestId,
              licenseId == installation.licenseId, topicId == installation.draftId, bindingHash == installation.bindingHash,
              ["en", "zh-Hans"].contains(locale), (1...49).contains(nodes.count), Set(nodes.map(\.id)).count == nodes.count,
              Set(nodes.map(\.nodeId)).count == nodes.count, Set(nodes.map(\.templateId)).count == nodes.count else { throw ModInstallationIssue.malformed }
        try ModInstallationValidation.hash(draftContentHash)
        for node in nodes {
            guard node.nodeId > 0, node.templateId > 0, node.sourceNodeId.range(of: "\\A[a-z][a-z0-9_-]{0,63}\\z", options: .regularExpression) != nil else { throw ModInstallationIssue.malformed }
            try ModInstallationValidation.text(node.title, maximum: 1024)
            _ = try ModInstallationQaPick(json: node.advancedConfigJson)
        }
    }
}
public struct ModInstallationQaEditCommand: Codable, Equatable {
    public let editRequestId, sourceNodeId, expectedDraftHash: String
    public let config: [String: TemplateAuthoringJSON]
    public var configJSON: String { String(data: (try? JSONEncoder().encode(config)) ?? Data(), encoding: .utf8) ?? "" }
    func validate() throws {
        guard UUID(uuidString: editRequestId)?.uuidString.lowercased() == editRequestId else { throw ModInstallationIssue.malformed }; try ModInstallationValidation.hash(expectedDraftHash)
        guard sourceNodeId.range(of: "\\A[a-z][a-z0-9_-]{0,63}\\z", options: .regularExpression) != nil else { throw ModInstallationIssue.malformed }
        _ = try ModInstallationQaPick(json: configJSON)
    }
}
public struct ModInstallationQaEditReceipt: Codable, Equatable {
    public let schema, installationRequestId, editRequestId, sourceNodeId, previousDraftHash, resultDraftHash, advancedConfigJson: String
    public let topicId, templateId: Int64
    func validate(_ pending: ModInstallationQaEditPending) throws {
        let command = pending.command; try command.validate()
        guard schema == "mod-installation-qa-edit-receipt-v1", installationRequestId == pending.installation.requestId,
              editRequestId == command.editRequestId, sourceNodeId == command.sourceNodeId, topicId == pending.installation.draftId,
              templateId == pending.templateId, previousDraftHash == command.expectedDraftHash,
              try JSONDecoder().decode([String: TemplateAuthoringJSON].self, from: Data(advancedConfigJson.utf8)) == command.config else { throw ModInstallationIssue.malformed }
        try ModInstallationValidation.hash(resultDraftHash); _ = try ModInstallationQaPick(json: advancedConfigJson)
    }
}
public struct ModInstallationQaEditPending: Codable, Equatable, Identifiable {
    public var id: String { command.editRequestId }
    public let installation: ModInstallationReceipt
    public let command: ModInstallationQaEditCommand
    public let templateId: Int64
    public var receipt: ModInstallationQaEditReceipt?
    func validate() throws {
        try installation.validate(identity: installation.identity); try command.validate()
        guard installation.topicID != nil, templateId > 0 else { throw ModInstallationIssue.malformed }
        if let receipt { try receipt.validate(self) }
    }
}

/// Private installed question editor. Existing answer-selection model is reused, no local answer evaluator.
@MainActor @Observable public final class ModInstallationQaEditor: Identifiable {
    public let id = UUID()
    public let installation: ModInstallationReceipt
    public private(set) var state: ModInstallationQaEditorState?
    public private(set) var node: ModInstallationQaEditorState.Node?
    public private(set) var draft = TemplateAdvancedDraft()
    public private(set) var pending: ModInstallationQaEditPending?
    public private(set) var review: ModInstallationQaEditPending?
    public private(set) var busy = false
    public private(set) var retryOriginalAvailable = false
    public private(set) var messageKey: String?
    private var selectedNodeID: String?
    private let service: any ModInstallationServing
    private let store: ModInstallationPendingStore
    init(installation: ModInstallationReceipt, service: any ModInstallationServing, store: ModInstallationPendingStore) {
        self.installation = installation; self.service = service; self.store = store
    }
    public var isCurrent: Bool { service.isCurrent }
    public var canEdit: Bool { isCurrent && service.canMutate && !busy && state != nil && (pending == nil || pending?.receipt != nil) }
    public var answerSelection: TemplateQAAnswerSelection { .init(draft) }
    public func open() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        // A refresh/receipt is not fresh draft authority. Preserve the original journal and receipt.
        selectedNodeID = node?.id ?? selectedNodeID
        state = nil; review = nil; node = nil
        do {
            try check(); pending = try store.loadQaEdit(installation: installation)
            if let original = pending, original.receipt == nil { try await reconcile(original); return }
            try await readCurrent()
        } catch ModInstallationIssue.requestNotFound { messageKey = "qaEdit.unknown" }
        catch { messageKey = "qaEdit.unavailable" }
    }
    public func select(_ next: ModInstallationQaEditorState.Node) {
        guard canEdit, state?.nodes.contains(next) == true else { return }
        do { var value = TemplateAdvancedDraft(); value.value = try JSONDecoder().decode([String: TemplateAuthoringJSON].self, from: Data(next.advancedConfigJson.utf8)); draft = value; node = next; selectedNodeID = next.id; review = nil }
        catch { messageKey = "qaEdit.unavailable" }
    }
    public func text(_ key: String, option: Int? = nil) -> String {
        if let option { return draft.value["qa"]?.object?["options"]?.array?[safe: option]?.object?[key]?.string ?? "" }
        return draft.value["qa"]?.object?[key]?.string ?? ""
    }
    public func setText(_ key: String, value: String, option: Int? = nil) {
        guard canEdit, var qa = draft.value["qa"]?.object else { return }
        if let index = option, var rows = qa["options"]?.array, rows.indices.contains(index), var row = rows[index].object, ["label", "fb"].contains(key) {
            row[key] = .string(value); rows[index] = .object(row); qa["options"] = .array(rows)
        } else if option == nil, ["title", "lead"].contains(key) { qa[key] = .string(value) } else { return }
        draft.value["qa"] = .object(qa); review = nil
    }
    public var maxTries: Int { Int(draft.value["qa"]?.object?["maxTries"]?.number ?? 0) }
    public func setMaxTries(_ count: Int) {
        guard canEdit, (0...10).contains(count), var qa = draft.value["qa"]?.object else { return }
        qa["maxTries"] = .number(Double(count)); draft.value["qa"] = .object(qa); review = nil
    }
    public func answer(_ edit: TemplateQAAnswerSelection.Edit) {
        guard canEdit, let changed = answerSelection.applying(edit, to: draft) else { return }; draft = changed; review = nil
    }
    public func prepareReview() {
        guard canEdit, let state, let node else { return }
        do {
            let command = ModInstallationQaEditCommand(editRequestId: UUID().uuidString.lowercased(), sourceNodeId: node.sourceNodeId, expectedDraftHash: state.draftContentHash, config: draft.value)
            try command.validate(); review = .init(installation: installation, command: command, templateId: node.templateId, receipt: nil); messageKey = nil
        } catch { messageKey = "qaEdit.invalid" }
    }
    public func cancelReview() { review = nil }
    public func confirm(_ original: ModInstallationQaEditPending) async {
        guard canEdit, review == original else { return }; busy = true; defer { busy = false }
        do {
            try check(); try store.beginQaEdit(original); pending = original; review = nil
            try await dispatch(original)
        } catch { messageKey = pending?.receipt == nil ? "qaEdit.unknown" : "qaEdit.unavailable" }
    }
    public func retryOriginal() async {
        guard !busy, isCurrent, service.canMutate, retryOriginalAvailable, let original = pending, original.receipt == nil else { return }
        busy = true; defer { busy = false }
        do {
            try check(); guard try store.loadQaEdit(installation: installation) == original else { throw ModInstallationIssue.pendingConflict }
            do { try await reconcile(original) }
            catch ModInstallationIssue.requestNotFound { try check(); try await dispatch(original) }
        } catch { messageKey = pending?.receipt == nil ? "qaEdit.unknown" : "qaEdit.unavailable" }
    }
    private func dispatch(_ original: ModInstallationQaEditPending) async throws {
        retryOriginalAvailable = false
        do { try accept(try await service.saveQaEdit(original)); try await readCurrent() }
        catch ModInstallationIssue.prepareRejected {
            try check(); try store.rejectQaEdit(original); pending = nil; messageKey = "qaEdit.rejected"; try await readCurrent()
        }
    }
    private func reconcile(_ original: ModInstallationQaEditPending) async throws {
        retryOriginalAvailable = false
        do { try accept(try await service.qaEditReceipt(original)); try await readCurrent() }
        catch ModInstallationIssue.requestNotFound { try check(); retryOriginalAvailable = true; messageKey = "qaEdit.unknown"; throw ModInstallationIssue.requestNotFound }
    }
    private func accept(_ receipt: ModInstallationQaEditReceipt) throws {
        try check(); guard var original = pending else { throw ModInstallationIssue.pendingConflict }; try receipt.validate(original)
        original.receipt = receipt; try store.acceptQaEdit(original); pending = original; messageKey = "qaEdit.saved"
    }
    private func readCurrent() async throws {
        // Failed or revoked current reads must not re-enable edits from the pre-write state.
        selectedNodeID = node?.id ?? selectedNodeID
        state = nil; review = nil; node = nil
        let value = try await service.qaEditor(installation); try check(); try value.validate(installation)
        if let selected = value.nodes.first(where: { $0.id == selectedNodeID }) ?? value.nodes.first {
            var changed = TemplateAdvancedDraft(); changed.value = try JSONDecoder().decode([String: TemplateAuthoringJSON].self, from: Data(selected.advancedConfigJson.utf8)); draft = changed; node = selected; selectedNodeID = selected.id; state = value
        }
    }
    private func check() throws { guard isCurrent else { throw ModInstallationIssue.staleSession } }
}
private extension Array { subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil } }
