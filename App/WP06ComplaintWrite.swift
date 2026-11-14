import Foundation

/// Installs the complaint report writer on the existing preparation link.
/// Only `api/coop/complaint/report` is approved. Other cooperation writes stay closed.
@MainActor enum WP06ComplaintWrite {
    static func install() {
        if ProfileComplaintPreparationLink.submitterFactory == nil {
            ProfileComplaintPreparationLink.submitterFactory = { session in make(session) }
        }
    }

    static func make(_ session: AppSession) -> (any ProfileComplaintSubmitting)? {
        guard let api = session.regionalConfiguration?.apiConfiguration,
              session.cooperationFlowReader.session != nil else { return nil }
        let path = "/api/coop/complaint/report"
        guard !ReleaseMoneyWriteSwitch.blocks(path),
              ChinaReviewedRouteCapability.admitsChinaProductionCall(path) else { return nil }
        let endpoint = api.baseURL
        let service = CoopFlowService(
            configuration: api,
            transport: session.runtimeHTTPTransport,
            dormantWritesEnabled: true,
            executionApproval: {
                CoopFlowExecutionApproval(operations: [.complaint], endpoint: endpoint)
            })
        let reader = session.cooperationFlowReader
        let coordinator = CoopFlowCoordinator(
            current: { reader.session },
            evidence: CoopFlowSourceEvidenceReader(reader: reader),
            executor: CoopFlowDormantExecutor(service: service),
            locks: WP06ComplaintMemoryLocks(),
            enabled: { true })
        return ProfileComplaintCoordinatorSubmitter(coordinator: coordinator)
    }
}

/// Process-local complaint lock. A second confirm in this process stays ambiguous; nothing is written to disk.
@MainActor private final class WP06ComplaintMemoryLocks: CoopFlowLockStore {
    private var keys = Set<String>()
    func contains(_ key: String) throws -> Bool { keys.contains(key) }
    func acquire(_ key: String) throws {
        guard keys.insert(key).inserted else { throw CoopFlowFailure.ambiguous }
    }
    func complete(_ key: String) throws { keys.remove(key) }
}
