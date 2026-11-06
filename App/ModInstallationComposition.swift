import Foundation

@MainActor enum ModInstallationComposition {
    /// Retain this pair together: both consumers use the same original service and lease.
    struct OriginalReaderContext {
        let controller: ModInstallationController
        let originalReader: H5OriginalInstallReader
    }

    static func make(reference: ModInstallationIdentity, context: RuntimeDependencyContext,
                     approval: ModInstallationApproval?, currentApproval: @escaping () -> ModInstallationApproval?,
                     current: @escaping () -> RuntimeDependencyContext?, storage: any TemplateAuthoringStorage,
                     onUnauthorized: @escaping (RuntimeDependencyContext) -> Void = { _ in }) -> ModInstallationController? {
        makeWithOriginalReader(reference: reference, context: context, approval: approval,
            currentApproval: currentApproval, current: current, storage: storage,
            onUnauthorized: onUnauthorized)?.controller
    }

    static func makeWithOriginalReader(reference: ModInstallationIdentity, context: RuntimeDependencyContext,
                     approval: ModInstallationApproval?, currentApproval: @escaping () -> ModInstallationApproval?,
                     current: @escaping () -> RuntimeDependencyContext?, storage: any TemplateAuthoringStorage,
                     onUnauthorized: @escaping (RuntimeDependencyContext) -> Void = { _ in }) -> OriginalReaderContext? {
        guard (try? reference.validate()) != nil, let approval, approval.matches(context),
              currentApproval()?.revision == approval.revision,
              ContentDraftContextFence.matches(current(), context) else { return nil }
        let lease = ContentDraftSessionLease(context: context, current: current)
        guard let service = try? ModInstallationService(lease: lease, approval: approval,
            currentApproval: currentApproval, onUnauthorized: onUnauthorized) else { return nil }
        let controller = ModInstallationController(identity: reference, service: service,
            store: ModInstallationPendingStore(storage: storage, context: context, identity: reference))
        return OriginalReaderContext(controller: controller, originalReader: H5OriginalInstallReader(service: service))
    }
}
