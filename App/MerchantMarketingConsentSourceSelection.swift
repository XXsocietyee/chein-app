import Foundation

/// Explicit host selection only. Storing a configuration does not issue its endpoint or target grants.
@MainActor final class MerchantMarketingConsentSourceSelection {
    private final class WeakOwner {
        weak var coordinator: AccountComplianceCoordinator?
        init(_ coordinator: AccountComplianceCoordinator) { self.coordinator = coordinator }
    }
    private var selected: MerchantMarketingConsentRuntimeConfiguration?
    private var usedIssuances: Set<UUID> = []
    private var owners: [WeakOwner] = []
    private var defaultApprovals: [String: MerchantMarketingConsentOriginalApproval] = [:]
    private(set) var wasExplicitlyRevoked = false
    init() {}
    private func contextKey(_ context: RuntimeDependencyContext) -> String {
        "\(context.market.rawValue)|\(context.baseURL.absoluteString)|\(context.session.namespace)|\(context.session.accountID)|\(context.session.epoch)|\(context.role)"
    }
    func replace(with configuration: MerchantMarketingConsentRuntimeConfiguration?) throws {
        if let configuration, usedIssuances.contains(configuration.issuanceID) { throw APIError.invalidConfiguration }
        selected = nil
        wasExplicitlyRevoked = configuration == nil
        retire()
        selected = configuration
        if let configuration { usedIssuances.insert(configuration.issuanceID) }
    }
    func revoke() { selected = nil; wasExplicitlyRevoked = true; defaultApprovals.removeAll(); retire() }
    func approval(for context: RuntimeDependencyContext) -> MerchantMarketingConsentOriginalApproval? {
        selected?.approval(for: context)
    }
    func defaultApproval(for context: RuntimeDependencyContext) -> MerchantMarketingConsentOriginalApproval? {
        guard !wasExplicitlyRevoked, context.market == .china, context.session.accountID > 0 else { return nil }
        let key = contextKey(context)
        if let cached = defaultApprovals[key], cached.matches(context) { return cached }
        guard let created = try? MerchantMarketingConsentOriginalApproval(
            baseURL: context.baseURL, namespace: context.session.namespace,
            accountID: context.session.accountID, allowsAllValidRows: true
        ) else { return nil }
        defaultApprovals[key] = created
        return created
    }
    func register(_ coordinator: AccountComplianceCoordinator) {
        owners.removeAll { $0.coordinator == nil }
        if !owners.contains(where: { $0.coordinator === coordinator }) { owners.append(.init(coordinator)) }
    }
    private func retire() {
        owners.forEach { $0.coordinator?.retireMarketingSource() }
        owners.removeAll { $0.coordinator == nil }
    }
}

@MainActor extension AppCompositionRoot {
    func selectedMerchantMarketingConsentApproval(_ context: RuntimeDependencyContext) -> MerchantMarketingConsentOriginalApproval? {
        guard let reviewed, let api = reviewed.regional.apiConfiguration, reviewed.regional.market == context.market,
              api.baseURL.absoluteString.utf8.elementsEqual(context.baseURL.absoluteString.utf8),
              reviewed.storageScope.service.utf8.elementsEqual(context.session.namespace.utf8) else { return nil }
        if let explicit = merchantMarketingConsentSelection.approval(for: context) { return explicit }
        guard reviewed.productionGatesEnabled else { return nil }
        return merchantMarketingConsentSelection.defaultApproval(for: context)
    }
}
