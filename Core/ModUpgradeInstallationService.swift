import Foundation

/// Adapter, not another installer. The original controller owns resource binding, preview, install,
/// receipt recovery and all existing content-review gates. Only prepare gains source→target provenance.
@MainActor public final class ModUpgradeInstallationService: ModInstallationServing {
    private let base: any ModInstallationServing
    private let upgrade: any ModUpgradeServing
    private let intents: ModUpgradeIntentStore
    private let pending: ModInstallationPendingStore
    private let selected: ModUpgradeIntent
    public init(base: any ModInstallationServing, upgrade: any ModUpgradeServing, intents: ModUpgradeIntentStore,
                pending: ModInstallationPendingStore, selected: ModUpgradeIntent) throws {
        try selected.validate()
        self.base = base; self.upgrade = upgrade; self.intents = intents; self.pending = pending; self.selected = selected
        try check()
    }
    public var isCurrent: Bool { base.isCurrent && upgrade.isCurrent }
    public var canMutate: Bool {
        guard isCurrent, base.canMutate, upgrade.canStage,
              let saved = try? intents.load(), saved.rejectionReason == nil else { return false }
        return true
    }
    public var canReviewInstalledTemplate: Bool { canMutate && base.canReviewInstalledTemplate }
    // Read grants stay independently scoped to the original installation service. Stage permission is not a read grant.
    public var canReadCompatibility: Bool { isCurrent && base.canReadCompatibility }
    public var canReadInstalledTemplateRehearsal: Bool { isCurrent && base.canReadInstalledTemplateRehearsal }
    public func compatibility(identity: ModInstallationIdentity) async throws -> ModInstallationCompatibility {
        try check()
        guard canReadCompatibility, identity == selected.target else { throw ModInstallationIssue.disabled }
        let result = try await base.compatibility(identity: identity); try check()
        try result.validate(identity); return result
    }
    public var allowsAdditionalDrafts: Bool { false }
    public func invalidate() { base.invalidate(); upgrade.invalidate() }
    private func check(mutating: Bool = false) throws {
        try Task.checkCancellation()
        guard isCurrent else { throw ModInstallationIssue.staleSession }
        guard !mutating || canMutate else { throw ModInstallationIssue.disabled }
        do {
            guard let saved = try intents.load(), saved.source == selected.source,
                  saved.candidate == selected.candidate else { throw ModInstallationIssue.pendingConflict }
        } catch ModUpgradeIssue.storageUnavailable { throw ModInstallationIssue.storageUnavailable }
    }
    private func intent(for requestId: String) throws -> ModUpgradeIntent {
        try check()
        do {
            guard var saved = try intents.load() else { throw ModInstallationIssue.pendingConflict }
            // Crash between the installation journal write and provenance write: bind the SAME durable command.
            if saved.installation == nil {
                guard let original = try pending.load(), original.request.requestId == requestId else { throw ModInstallationIssue.pendingConflict }
                saved = try intents.bind(original)
            }
            guard saved.installation?.requestId == requestId else { throw ModInstallationIssue.pendingConflict }
            return saved
        } catch ModUpgradeIssue.storageUnavailable { throw ModInstallationIssue.storageUnavailable }
    }
    private func check(receipt: ModInstallationReceipt, mutating: Bool = false) throws {
        try check(mutating: mutating)
        guard receipt.identity == selected.target else { throw ModInstallationIssue.pendingConflict }
        let original = try intent(for: receipt.requestId)
        guard let command = original.installation, receipt.merchantId == command.merchantId,
              receipt.anchorPoiId == command.anchorPoiId,
              receipt.bindings.map(\.binding).sorted(by: { $0.id < $1.id }) == command.bindings.sorted(by: { $0.id < $1.id }) else { throw ModInstallationIssue.pendingConflict }
        try receipt.validate(identity: receipt.identity)
    }
    public func options(identity: ModInstallationIdentity, merchantId: Int64?) async throws -> ModInstallationOptions {
        try check(); guard identity == selected.target else { throw ModInstallationIssue.pendingConflict }
        let result = try await base.options(identity: identity, merchantId: merchantId); try check(); return result
    }
    public func prepare(_ attempt: ModInstallationAttempt) async throws -> ModInstallationReceipt {
        try check(mutating: true)
        guard attempt.identity == selected.target, try pending.load() == attempt else { throw ModInstallationIssue.pendingConflict }
        do {
            let original = try intents.bind(attempt) // Persist exact original command + selection BEFORE POST.
            try check(mutating: true)
            let receipt = try await upgrade.stage(original, attempt: attempt)
            try check(mutating: true); try attempt.validate(receipt: receipt); return receipt
        } catch ModUpgradeIssue.preflightRejected(let reason) {
            do { try intents.markRejected(reason, attempt: attempt) }
            catch { throw ModInstallationIssue.storageUnavailable }
            // The original controller may clear only its uncreated preflight after durable proof is saved.
            throw ModInstallationIssue.prepareRejected
        } catch ModUpgradeIssue.storageUnavailable { throw ModInstallationIssue.storageUnavailable }
        catch ModUpgradeIssue.unauthorized { throw ModInstallationIssue.unauthorized }
        catch ModUpgradeIssue.notFound { throw ModInstallationIssue.requestNotFound }
    }
    public func request(_ requestId: String, identity: ModInstallationIdentity) async throws -> ModInstallationReceipt {
        guard identity == selected.target else { throw ModInstallationIssue.pendingConflict }
        do {
            let original = try intent(for: requestId)
            let result = try await upgrade.request(original); try check(); return result
        } catch ModUpgradeIssue.notFound { throw ModInstallationIssue.requestNotFound }
        catch ModUpgradeIssue.unauthorized { throw ModInstallationIssue.unauthorized }
    }
    public func history(identity: ModInstallationIdentity) async throws -> [ModInstallationReceipt] {
        try check(); guard identity == selected.target else { throw ModInstallationIssue.pendingConflict }
        guard let saved = try intents.load(), let original = saved.installation else { return [] }
        return [try await request(original.requestId, identity: identity)]
    }
    public func install(_ prepared: ModInstallationReceipt) async throws -> ModInstallationReceipt {
        try check(receipt: prepared, mutating: true)
        let result = try await base.install(prepared); try check(mutating: true); return result
    }
    public func cancel(_ prepared: ModInstallationReceipt) async throws -> ModInstallationReceipt {
        try check(receipt: prepared, mutating: true)
        let result = try await base.cancel(prepared); try check(mutating: true); return result
    }
    public func preview(_ receipt: ModInstallationReceipt) async throws -> ModInstallationPreview {
        try check(receipt: receipt)
        let result = try await base.preview(receipt); try check(); return result
    }
    public func facts(_ receipt: ModInstallationReceipt) async throws -> ModInstallationFacts {
        try check(receipt: receipt)
        let result = try await base.facts(receipt); try check(); return result
    }
    public func confirmFacts(_ facts: ModInstallationFacts, receipt: ModInstallationReceipt) async throws -> ModInstallationFacts {
        try check(receipt: receipt, mutating: true)
        let result = try await base.confirmFacts(facts, receipt: receipt); try check(mutating: true); return result
    }
    public func templateEditor(_ installation: ModInstallationReceipt) async throws -> ModInstallationTemplateEditorState {
        try check(receipt: installation)
        let result = try await base.templateEditor(installation); try check(); return result
    }
    public func saveTemplateEdit(_ value: ModInstallationTemplateEditPending) async throws -> ModInstallationTemplateEditReceipt {
        try check(receipt: value.installation, mutating: true)
        let result = try await base.saveTemplateEdit(value); try check(mutating: true); return result
    }
    public func templateEditReceipt(_ value: ModInstallationTemplateEditPending) async throws -> ModInstallationTemplateEditReceipt {
        try check(receipt: value.installation)
        let result = try await base.templateEditReceipt(value); try check(); return result
    }
    public func qaEditor(_ installation: ModInstallationReceipt) async throws -> ModInstallationQaEditorState {
        try check(receipt: installation)
        let result = try await base.qaEditor(installation); try check(); return result
    }
    public func saveQaEdit(_ value: ModInstallationQaEditPending) async throws -> ModInstallationQaEditReceipt {
        try check(receipt: value.installation, mutating: true)
        let result = try await base.saveQaEdit(value); try check(mutating: true); return result
    }
    public func qaEditReceipt(_ value: ModInstallationQaEditPending) async throws -> ModInstallationQaEditReceipt {
        try check(receipt: value.installation)
        let result = try await base.qaEditReceipt(value); try check(); return result
    }
}
