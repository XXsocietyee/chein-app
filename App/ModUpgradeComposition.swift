import Foundation

@MainActor enum ModUpgradeComposition {
    static func make(reference: ModInstallationIdentity, context: RuntimeDependencyContext,
                     approval: ModUpgradeApproval?, currentApproval: @escaping () -> ModUpgradeApproval?,
                     installationApproval: ModInstallationApproval?, currentInstallationApproval: @escaping () -> ModInstallationApproval?,
                     current: @escaping () -> RuntimeDependencyContext?, storage: any TemplateAuthoringStorage,
                     transport: any HTTPTransport = URLSessionTransport(),
                     onUnauthorized: @escaping (RuntimeDependencyContext) -> Void = { _ in }) -> ModUpgradeController? {
        guard (try? reference.validate()) != nil, let approval, approval.matches(context),
              currentApproval()?.revision == approval.revision,
              ContentDraftContextFence.matches(current(), context) else { return nil }
        let lease = ContentDraftSessionLease(context: context, current: current)
        guard let service = try? ModUpgradeService(lease: lease, approval: approval, currentApproval: currentApproval,
            transport: transport, onUnauthorized: onUnauthorized) else { return nil }
        let intents = ModUpgradeIntentStore(storage: storage, context: context, source: reference)
        // This reader retains the existing installation read approval, never the upgrade stage grant.
        // Its independent lease is retired after the read; no installer/controller is opened by recovery.
        func originalContentReader(_ selected: ModUpgradeIntent) throws -> ModInstallationService {
            guard service.isCurrent, selected.source == reference, try intents.load() == selected,
                  let installationApproval, installationApproval.matches(context),
                  currentInstallationApproval()?.revision == installationApproval.revision,
                  ContentDraftContextFence.matches(current(), context) else { throw ModUpgradeIssue.unavailable }
            return try ModInstallationService(lease: ContentDraftSessionLease(context: context, current: current),
                approval: installationApproval, currentApproval: currentInstallationApproval, onUnauthorized: onUnauthorized)
        }
        return ModUpgradeController(source: reference, service: service, store: intents, makeInstallation: { selected in
            guard service.isCurrent, selected.source == reference, let target = selected.target,
                  let installationApproval, installationApproval.matches(context),
                  currentInstallationApproval()?.revision == installationApproval.revision,
                  ContentDraftContextFence.matches(current(), context) else { return nil }
            let installationLease = ContentDraftSessionLease(context: context, current: current)
            guard let base = try? ModInstallationService(lease: installationLease, approval: installationApproval,
                currentApproval: currentInstallationApproval, onUnauthorized: onUnauthorized) else { return nil }
            let journal = ModInstallationPendingStore(storage: ModUpgradeInstallationStorage(storage: storage, source: reference),
                context: context, identity: target)
            guard let adapted = try? ModUpgradeInstallationService(base: base, upgrade: service, intents: intents,
                pending: journal, selected: selected) else { return nil }
            return ModInstallationController(identity: target, service: adapted, store: journal)
        }, clearRejectedJournal: { rejected in
            guard let target = rejected.target, let original = rejected.installation, rejected.rejectionReason != nil else { throw ModUpgradeIssue.pendingConflict }
            let journal = ModInstallationPendingStore(storage: ModUpgradeInstallationStorage(storage: storage, source: reference),
                context: context, identity: target)
            if let pending = try journal.load() {
                guard pending.request == original, pending.receipt == nil else { throw ModUpgradeIssue.pendingConflict }
                try journal.discardRejectedPreflight(requestId: original.requestId)
            }
        }, verifyUnstagedJournalEmpty: { selected in
            guard selected.installation == nil, let target = selected.target else { throw ModUpgradeIssue.pendingConflict }
            let journal = ModInstallationPendingStore(storage: ModUpgradeInstallationStorage(storage: storage, source: reference),
                context: context, identity: target)
            guard try journal.load() == nil else { throw ModUpgradeIssue.pendingConflict }
        }, finishUninstalledJournal: { selected, receipt in
            guard let target = selected.target, let original = selected.installation,
                  receipt.identity == target, receipt.requestId == original.requestId,
                  receipt.state == .cancelled || receipt.state == .failed else { throw ModUpgradeIssue.pendingConflict }
            let journal = ModInstallationPendingStore(storage: ModUpgradeInstallationStorage(storage: storage, source: reference),
                context: context, identity: target)
            if let pending = try journal.load() {
                guard pending.request == original, pending.pendingFacts == nil else { throw ModUpgradeIssue.pendingConflict }
                _ = try journal.accept(receipt); try journal.finish(receipt)
            }
        }, recoverInstallationAttempt: { selected in
            guard service.isCurrent, selected.source == reference, let target = selected.target,
                  try intents.load() == selected,
                  ContentDraftContextFence.matches(current(), context) else { throw ModUpgradeIssue.pendingConflict }
            let journal = ModInstallationPendingStore(storage: ModUpgradeInstallationStorage(storage: storage, source: reference),
                context: context, identity: target)
            do { return try journal.load() }
            catch { throw ModUpgradeIssue.storageUnavailable }
        }, readOriginalPreview: { selected, receipt in
            let reader = try originalContentReader(selected); defer { reader.invalidate() }
            guard receipt.identity == selected.target, receipt.requestId == selected.installation?.requestId else { throw ModUpgradeIssue.pendingConflict }
            return try await reader.preview(receipt)
        }, readOriginalFacts: { selected, receipt in
            let reader = try originalContentReader(selected); defer { reader.invalidate() }
            guard receipt.identity == selected.target, receipt.requestId == selected.installation?.requestId else { throw ModUpgradeIssue.pendingConflict }
            return try await reader.facts(receipt)
        })
    }
}
