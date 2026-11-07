import Foundation
import Observation

/// A supplied read grant is selected, never issued here. Revocation synchronously retires private evidence displays.
@MainActor @Observable final class UsageConsentReadSourceSelection {
    private final class WeakOwner {
        weak var value: UsageConsentReadCoordinator?
        init(_ value: UsageConsentReadCoordinator) { self.value = value }
    }
    private var selected: UsageConsentReadApproval?
    private var usedIssuances: Set<UUID> = []
    private var owners: [WeakOwner] = []
    private var defaultApprovals: [RuntimeDependencyContext: UsageConsentReadApproval] = [:]
    private(set) var wasExplicitlyRevoked = false
    private(set) var revision = UUID()
    init() {}
    func replace(with value: UsageConsentReadApproval?) throws {
        if let value, usedIssuances.contains(value.revision) { throw APIError.invalidConfiguration }
        selected = nil; wasExplicitlyRevoked = value == nil; retire(); revision = UUID()
        selected = value
        if let value { usedIssuances.insert(value.revision) }
    }
    func revoke() { selected = nil; wasExplicitlyRevoked = true; defaultApprovals.removeAll(); retire(); revision = UUID() }
    func approval(for context: RuntimeDependencyContext) -> UsageConsentReadApproval? {
        guard let selected, selected.endpoint.paths.contains(where: { selected.allows(context, path: $0) }) else { return nil }
        return selected
    }
    func defaultApproval(for context: RuntimeDependencyContext) -> UsageConsentReadApproval? {
        guard !wasExplicitlyRevoked, context.market == .china, context.session.accountID > 0 else { return nil }
        if let cached = defaultApprovals[context], cached.endpoint.paths.contains(where: { cached.allows(context, path: $0) }) {
            return cached
        }
        guard let endpoint = try? OperationEndpointApproval(
            baseURL: context.baseURL, namespace: context.session.namespace,
            accountID: context.session.accountID, paths: UsageConsentReadRoute.paths
        ), let created = try? UsageConsentReadApproval(endpoint: endpoint) else { return nil }
        defaultApprovals[context] = created
        return created
    }
    func register(_ coordinator: UsageConsentReadCoordinator) {
        owners.removeAll { $0.value == nil }
        if !owners.contains(where: { $0.value === coordinator }) { owners.append(.init(coordinator)) }
    }
    private func retire() {
        owners.forEach { $0.value?.retire() }; owners.removeAll { $0.value == nil }
    }
}
@MainActor extension AppCompositionRoot {
    func selectedUsageConsentReadApproval(_ context: RuntimeDependencyContext) -> UsageConsentReadApproval? {
        guard let reviewed, let api = reviewed.regional.apiConfiguration, reviewed.regional.market == context.market,
              api.baseURL.absoluteString.utf8.elementsEqual(context.baseURL.absoluteString.utf8),
              reviewed.storageScope.service.utf8.elementsEqual(context.session.namespace.utf8) else { return nil }
        if let explicit = usageConsentReadSelection.approval(for: context) { return explicit }
        guard reviewed.productionGatesEnabled else { return nil }
        return usageConsentReadSelection.defaultApproval(for: context)
    }
}
