import SwiftUI

// G6 accessors (NPC/AI, creator/publishing, marketing/products). Kept out of AppSession.swift and
// AppCompositionRoot.swift, which are line-ratcheted. Every accessor is nil outside a signed-in China
// runtime context, and a nil accessor hides its entry.

extension AppSession {
    /// The G6 source on the live runtime context. Requests still pass `ChinaReviewedRouteCapability` per call.
    func g6Source() -> G6CapabilitySource? {
        guard let context = currentRuntimeDependencyContext, context.market == .china,
              let configuration = try? APIConfiguration(baseURL: context.baseURL) else { return nil }
        return G6CapabilitySource(configuration: configuration, transport: composition.makeTransport())
    }

    func g6Token() -> String? {
        guard let token, AuthRequestBuilder.isValidToken(token) else { return nil }
        return token
    }

    func g6MemberID() -> String? {
        guard let id = account?.id, id > 0 else { return nil }
        return String(id)
    }

    /// `POST /api/config/features` for the flags the roam prompt layer reads live. Nil when the read is not admitted.
    func g6FeatureFlagsReader() -> LaunchFeatureFlagsReader? {
        guard let context = currentRuntimeDependencyContext, context.market == .china,
              let configuration = try? APIConfiguration(baseURL: context.baseURL) else { return nil }
        let url = context.baseURL.appendingPathComponent(LaunchFeatureFlagsReader.path)
        let approved = !ChinaReviewedRouteCapability.targetsChinaProduction(url) || ChinaReviewedRouteCapability.admitsChinaProductionCall(url)
        // The caller re-checks the member on the main actor after the read; this closure only pins the start value.
        let captured = g6MemberID()
        return LaunchFeatureFlagsReader(configuration: configuration, transport: composition.makeTransport(), approved: approved,
                                        currentIdentity: { captured })
    }

    func g6Capabilities() -> G6Capabilities {
        G6Capabilities(
            source: { [weak self] in self?.g6Source() },
            token: { [weak self] in self?.g6Token() },
            member: { [weak self] in self?.g6MemberID() },
            flags: { [weak self] in self?.g6FeatureFlagsReader() })
    }

    /// The AI draft adapter: the V2 prepare/execute protocol on top of the existing quota/session client.
    /// Nil whenever the existing factory is nil, so the AI entry stays hidden exactly where it was hidden.
    var g6PublishingAIDraftFactory: (() -> any PublishingAIDraftServing)? {
        guard let base = publishingAIDraftFactory else { return nil }
        return { [weak self] in
            let existing = base()
            guard let self, let source = self.g6Source() else { return existing }
            let flow = G6AIThemeDraftFlow(source: source, store: G6DefaultsRequestStore.shared,
                                          member: { [weak self] in self?.g6MemberID() }, token: { [weak self] in self?.g6Token() })
            return G6AIThemeDraftAdapter(base: existing, flow: flow)
        }
    }
}

/// Survives relaunch so an unconfirmed AI draft identity is read back instead of re-prepared.
final class G6DefaultsRequestStore: JourneyRequestStoring, @unchecked Sendable {
    static let shared = G6DefaultsRequestStore(defaults: .standard)
    private let defaults: UserDefaults
    private let prefix = "g6.request."

    init(defaults: UserDefaults) { self.defaults = defaults }

    func read(_ key: String) -> String? { defaults.string(forKey: prefix + key) }
    func write(_ key: String, _ value: String) { defaults.set(value, forKey: prefix + key) }
    func remove(_ key: String) { defaults.removeObject(forKey: prefix + key) }
}

/// Wraps the existing client: session, quota and `canGenerate` stay the existing ones; generation is the V2 protocol.
@MainActor final class G6AIThemeDraftAdapter: PublishingAIDraftServing {
    private let base: any PublishingAIDraftServing
    let flow: G6AIThemeDraftFlow
    /// Set by the explicit "start a new draft" confirmation; consumed by the next generate.
    static var confirmedNew = false

    init(base: any PublishingAIDraftServing, flow: G6AIThemeDraftFlow) {
        self.base = base
        self.flow = flow
    }

    var session: PublishingSession? { base.session }
    var canGenerate: Bool { base.canGenerate }
    func quota() async throws -> PublishingAIQuota { try await base.quota() }
    func cancel() { base.cancel() }

    func generate(idea: String, product: ProjectEditProduct) async throws -> PublishingAIThemeDraft {
        let confirmed = Self.confirmedNew
        Self.confirmedNew = false
        let outcome = await flow.run(idea: idea, productType: product.rawValue, confirmedNew: confirmed)
        let locale = Locale.current
        switch outcome {
        case .succeeded(_, let resultJSON):
            guard let value = try? JSONDecoder().decode(ProjectEditJSON.self, from: resultJSON) else {
                throw PublishModesError.rejected(appLocalized("g6.ai.notConfirmed", locale: locale))
            }
            return try PublishingAIThemeDraft(value, product: product)
        case .succeededResultExpired: throw PublishModesError.rejected(appLocalized("g6.ai.expired", locale: locale))
        case .succeededResultUnavailable: throw PublishModesError.rejected(appLocalized("g6.ai.resultUnavailable", locale: locale))
        case .failed: throw PublishModesError.rejected(appLocalized("g6.ai.failed", locale: locale))
        case .unknown, .needsConfirmation: throw PublishModesError.rejected(appLocalized("g6.ai.unknown", locale: locale))
        case .processing: throw PublishModesError.rejected(appLocalized("g6.ai.processing", locale: locale))
        case .prepareUnconfirmed: throw PublishModesError.rejected(appLocalized("g6.ai.prepareUnconfirmed", locale: locale))
        case .contextUnavailable: throw PublishModesError.rejected(appLocalized("g6.ai.contextUnavailable", locale: locale))
        case .modeMismatch: throw PublishModesError.rejected(appLocalized("g6.ai.modeMismatch", locale: locale))
        case .networkUnconfirmed: throw PublishModesError.rejected(appLocalized("g6.ai.network", locale: locale))
        case .notConfirmed: throw PublishModesError.rejected(appLocalized("g6.ai.notConfirmed", locale: locale))
        case .storage: throw PublishModesError.rejected(appLocalized("g6.ai.storage", locale: locale))
        case .invalidInput: throw PublishModesError.rejected(appLocalized("g6.ai.promptRequired", locale: locale))
        }
    }
}
