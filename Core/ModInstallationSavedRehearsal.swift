import Foundation
import Observation

/// Immutable server-saved content, admitted only after the existing current-license
/// options GET. Never accepts an editor buffer, old fact receipt, or public demo DTO.
public struct ModInstallationSavedRehearsalSnapshot: Equatable {
    public let installation: ModInstallationReceipt
    public let saved: ModInstallationTemplateEditorState
    public let advanced: TemplateAdvancedDraft
    public init(installation: ModInstallationReceipt, saved: ModInstallationTemplateEditorState, options: ModInstallationOptions) throws {
        try saved.validate(installation)
        try options.validate(licenseId: installation.licenseId)
        guard options.identity == installation.identity,
              Set(options.requiredBindings.map(\.id)) == Set(installation.bindings.map(\.id)),
              saved.editable, saved.validationMethod == 0,
              let json = saved.advancedConfigJson, !json.isEmpty else { throw ModInstallationIssue.malformed }
        let snapshot = try ModInstallationTemplateEditCommand.snapshot(saved.snapshotJson, hash: saved.draftContentHash, templateId: saved.templateId)
        let fields = snapshot.filter { ModInstallationTemplateEditCommand.editable.contains($0.key) }.compactMapValues(\.string)
        guard Set(fields.keys) == Set(saved.fields.keys),
              fields.allSatisfy({ key, value in saved.fields[key]?.utf8.elementsEqual(value.utf8) == true }),
              snapshot["advancedConfigJson"]?.string?.utf8.elementsEqual(json.utf8) == true,
              snapshot["validationMethod"] == .number(0) else { throw ModInstallationIssue.malformed }
        self.installation = installation; self.saved = saved
        advanced = try TemplateBranchRehearsalAdapter.exactDraft(json: json)
    }
}

/// One isolated, non-persisted visit. Contains no network, editor writer, quota,
/// completion, reward, billing or publish port. Retirement can never be undone.
@MainActor @Observable public final class ModInstallationSavedRehearsal: Identifiable {
    public let id = UUID()
    public private(set) var started = false
    private var frozen: ModInstallationSavedRehearsalSnapshot?
    private var visible = false
    private var retired = false
    private let current: () -> Bool
    init(snapshot: ModInstallationSavedRehearsalSnapshot, current: @escaping () -> Bool) {
        frozen = snapshot; self.current = current
    }
    public var snapshot: ModInstallationSavedRehearsalSnapshot? { visible && !retired && current() ? frozen : nil }
    public var available: Bool { snapshot != nil }
    public func appear() {
        guard !retired, current() else { retire(); return }; visible = true
    }
    public func start() {
        guard available else { retire(); return }; started = true
    }
    public func admitBranch() -> Bool {
        guard available, started else { retire(); return false }; return true
    }
    public func retire() { visible = false; retired = true; started = false; frozen = nil }
}
