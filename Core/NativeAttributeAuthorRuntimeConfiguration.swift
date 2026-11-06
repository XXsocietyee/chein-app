import Foundation

/// Independent reviewed deployment input, never decoded from a topic response, UserDefaults,
/// projectRead/projectWrite or a role string. Every method capability is explicit even when
/// several methods share a URL. A real owner supplies and rotates issuanceID on replacement.
public struct NativeAttributeAuthorRuntimeConfiguration: Equatable {
    public let market: RegionalMarket
    public let approval: OperationEndpointApproval
    public let operations: Set<NativeAttributeAuthorHostEndpoint>
    public let issuanceID: UUID

    public init(market: RegionalMarket, approval: OperationEndpointApproval,
                operations: Set<NativeAttributeAuthorHostEndpoint>, issuanceID: UUID) throws {
        guard !operations.isEmpty,
              approval.paths == Set(operations.map(Self.path)) else { throw APIError.invalidConfiguration }
        self.market = market; self.approval = approval; self.operations = operations; self.issuanceID = issuanceID
    }
    public static func path(_ endpoint: NativeAttributeAuthorHostEndpoint) -> String {
        switch endpoint {
        case .definitions, .inspectCurrent, .save, .delete: return "api/topic/attribute-author"
        case .requestReceipt: return "api/topic/attribute-author/request"
        case .references: return "api/topic/attribute-author/references"
        case .validate: return "api/topic/attribute-author/validate"
        case .legacyList, .legacyRegister, .legacyDelete: return "api/topic/state-keys"
        case .publishCheck: return "api/topic/publish-check"
        case .modulePreflight: return "api/topic/module-preflight"
        }
    }
    /// Exact deployment/account context only. The host still supplies the original topic/source binding.
    public func matchesDeployment(_ context: RuntimeDependencyContext) -> Bool {
        market == .china && context.market == market &&
        approval.baseURL.absoluteString.utf8.elementsEqual(context.baseURL.absoluteString.utf8) &&
        approval.namespace.utf8.elementsEqual(context.session.namespace.utf8) &&
        approval.accountID == context.session.accountID
    }
    public func matches(_ context: RuntimeDependencyContext, binding: NativeAttributeAuthorBinding) -> Bool {
        matchesDeployment(context) && !binding.isLocked &&
        approval.baseURL.absoluteString.utf8.elementsEqual(binding.server.utf8) &&
        approval.namespace.utf8.elementsEqual(binding.namespace.utf8) &&
        Int64(approval.accountID) == binding.accountID && context.session.epoch == binding.epoch
    }
    public func permits(_ endpoint: NativeAttributeAuthorHostEndpoint, context: RuntimeDependencyContext,
                        binding: NativeAttributeAuthorBinding) -> Bool {
        matches(context, binding: binding) && operations.contains(endpoint) && approval.paths.contains(Self.path(endpoint))
    }
}

/// First-party selection of an ALREADY reviewed original configuration. This is not an
/// approval issuer: it never creates an endpoint approval, account, address, operation,
/// credential or issuanceID. An empty source remains closed. Not Codable/UserDefaults.
@MainActor public final class NativeAttributeAuthorConfigurationSource {
    public private(set) var revision: UInt64 = 0
    private var selected: NativeAttributeAuthorRuntimeConfiguration?
    private static let operations: Set<NativeAttributeAuthorHostEndpoint> = [
        .definitions, .inspectCurrent, .references, .validate, .save, .delete, .requestReceipt
    ]
    public init(configuration: NativeAttributeAuthorRuntimeConfiguration? = nil) throws {
        try Self.requireOriginal(configuration); selected = configuration
    }
    /// The owner supplies the existing externally reviewed issuance; no operation is added
    /// to make an incomplete capability set usable. Old captures retire even for A -> nil -> A.
    public func replace(with configuration: NativeAttributeAuthorRuntimeConfiguration?) throws {
        try Self.requireOriginal(configuration)
        guard revision < UInt64.max else { selected = nil; throw APIError.invalidConfiguration }
        revision += 1; selected = configuration
    }
    public func revoke() { if revision < UInt64.max { revision += 1 }; selected = nil }
    public func configuration(for context: RuntimeDependencyContext) -> NativeAttributeAuthorRuntimeConfiguration? {
        guard let selected, selected.matchesDeployment(context) else { return nil }
        return selected
    }
    private static func requireOriginal(_ configuration: NativeAttributeAuthorRuntimeConfiguration?) throws {
        guard let configuration else { return }
        guard !configuration.operations.isEmpty, configuration.operations.isSubset(of: operations) else {
            throw APIError.invalidConfiguration
        }
        // The existing RuntimeConfiguration initializer already requires exact path equality
        // and a caller-provided issuanceID. Legacy registry/publish/other operations stay separate.
    }
}
