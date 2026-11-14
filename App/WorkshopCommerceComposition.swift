import Foundation

@MainActor enum WorkshopCommerceComposition {
    static func make(context: RuntimeDependencyContext, approval: WorkshopCommerceApproval?,
                     currentApproval: @escaping () -> WorkshopCommerceApproval?,
                     current: @escaping () -> RuntimeDependencyContext?, storage: any TemplateAuthoringStorage,
                     enableApprovedStoreKit: Bool = false, readOnly: Bool = false,
                     onUnauthorized: @escaping (RuntimeDependencyContext) -> Void = { _ in }) -> WorkshopCommerceController? {
        guard let approval, approval.matches(context), currentApproval()?.revision == approval.revision,
              ContentDraftContextFence.matches(current(), context) else { return nil }
        let lease = ContentDraftSessionLease(context: context, current: current)
        guard let service = try? WorkshopCommerceService(lease: lease, approval: approval, currentApproval: currentApproval, readOnly: readOnly, onUnauthorized: onUnauthorized) else { return nil }
        let payments = ReviewedAreaSwitch.moneyPayments(apiHost: context.baseURL.host)
        let native = enableApprovedStoreKit && !readOnly && payments ? WorkshopStoreKitFactory.make(service: service, approval: approval) : nil
        return WorkshopCommerceController(service: service, pending: WorkshopCommercePendingStore(storage: storage, context: context), nativePurchases: native)
    }
}
