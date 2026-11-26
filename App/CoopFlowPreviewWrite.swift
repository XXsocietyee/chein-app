import SwiftUI

/// Parity X1: the cooperation review page (`CoopFlowRequestPreview`) used to end on a disabled 暂不可提交.
/// Same construction as `WP06ComplaintWrite`: a per-operation `CoopFlowService` approval, the existing fresh-evidence
/// coordinator and an in-process lock. Non-money writes open on the China market (`MPFirstCoopWrites`).
/// Deposit paths stay on `ReleaseMoneyWriteSwitch`. Cancelling an accepted cooperation stays on the TEST host.
@MainActor struct CoopFlowPreviewWriteFactory {
    let make: (CoopFlowMutation, Bool) -> CoopFlowCoordinator?
    /// Parity perks P0: an executor for unprotected template writes (perk-template/save, perk-template/delete),
    /// nil where those writes are closed so the perks page stays read-only there.
    var executor: () -> (any CoopFlowExecuting)? = { nil }
    /// Station-topic accept (`acceptSupplyStation`). Same per-operation `.handle` approval as the generic accept.
    var stationAccept: () -> ((_ inviteID: Int, _ reason: String?, _ stationID: Int) async throws -> CoopFlowJSON)? = { nil }

    func coordinator(for operation: CoopFlowMutation, cancelsAcceptedCooperation: Bool = false) -> CoopFlowCoordinator? {
        make(operation, cancelsAcceptedCooperation)
    }

    static func live(_ session: AppSession) -> CoopFlowPreviewWriteFactory {
        var factory = coordinators(session)
        factory.executor = { [weak session] in
            guard let session, let api = session.regionalConfiguration?.apiConfiguration,
                  MPFirstCoopWrites.admitsUnprotectedWrites(market: session.regionalConfiguration?.market, host: api.baseURL.host) else { return nil }
            return CoopFlowDormantExecutor(service: CoopFlowService(configuration: api, transport: session.runtimeHTTPTransport,
                                                                    dormantWritesEnabled: true))
        }
        factory.stationAccept = { [weak session] in
            guard let session, let api = session.regionalConfiguration?.apiConfiguration,
                  let flowSession = session.cooperationFlowReader.session else { return nil }
            let probe = CoopFlowMutation.handle(inviteID: 1, action: .accept, reason: nil)
            guard MPFirstCoopWrites.admits(probe, market: session.regionalConfiguration?.market, host: api.baseURL.host) else { return nil }
            let transport = session.runtimeHTTPTransport
            return { inviteID, reason, stationID in
                let protected = CoopFlowProtectedOperation(.handle(inviteID: inviteID, action: .accept, reason: reason))
                let endpoint = api.baseURL
                let service = CoopFlowService(configuration: api, transport: transport, dormantWritesEnabled: true,
                                              executionApproval: { protected.map { CoopFlowExecutionApproval(operations: [$0], endpoint: endpoint) } })
                return try await service.acceptSupplyStation(inviteID: inviteID, reason: reason, supplyStationID: stationID, session: flowSession)
            }
        }
        return factory
    }
    private static func coordinators(_ session: AppSession) -> CoopFlowPreviewWriteFactory {
        CoopFlowPreviewWriteFactory { [weak session] operation, cancelsAcceptedCooperation in
            guard let session, let api = session.regionalConfiguration?.apiConfiguration,
                  session.cooperationFlowReader.session != nil,
                  MPFirstCoopWrites.admits(operation, market: session.regionalConfiguration?.market, host: api.baseURL.host,
                                           cancelsAcceptedCooperation: cancelsAcceptedCooperation) else { return nil }
            let endpoint = api.baseURL
            let protected = CoopFlowProtectedOperation(operation)
            let service = CoopFlowService(configuration: api, transport: session.runtimeHTTPTransport, dormantWritesEnabled: true,
                                          executionApproval: { protected.map { CoopFlowExecutionApproval(operations: [$0], endpoint: endpoint) } })
            let reader = session.cooperationFlowReader
            let executor = CoopFlowDormantExecutor(service: service)
            return CoopFlowCoordinator(current: { reader.session },
                evidence: CoopFlowSourceEvidenceReader(reader: reader, additional: { op, _ in
                    // Invitations have no source read to re-check; the server validates the recipient and terms.
                    if case .invite = op { return CoopFlowEvidence(baseline: .null, permitted: true) }
                    return CoopFlowEvidence(baseline: .null, permitted: false)
                }),
                executor: executor, locks: CoopFlowPreviewMemoryLocks.shared,
                enabled: {
                    guard let session, let api = session.regionalConfiguration?.apiConfiguration else { return false }
                    return MPFirstCoopWrites.admits(operation, market: session.regionalConfiguration?.market, host: api.baseURL.host,
                                                    cancelsAcceptedCooperation: cancelsAcceptedCooperation)
                        && executor.permitsDispatch(operation)
                })
        }
    }
}

/// Process-local lock: a second confirm of the same operation in this process stays ambiguous. Nothing on disk.
@MainActor final class CoopFlowPreviewMemoryLocks: CoopFlowLockStore {
    static let shared = CoopFlowPreviewMemoryLocks()
    private var keys = Set<String>()
    func contains(_ key: String) throws -> Bool { keys.contains(key) }
    func acquire(_ key: String) throws { guard keys.insert(key).inserted else { throw CoopFlowFailure.ambiguous } }
    func complete(_ key: String) throws { keys.remove(key) }
}

private struct MerchantCoopInboxDestinationKey: EnvironmentKey {
    static let defaultValue: (@MainActor () -> AnyView)? = nil
}
extension EnvironmentValues {
    /// Parity coop/list P1: the workbench 协作邀请 row pushes the invitation list (no nested NavigationStack).
    var merchantCoopInboxDestination: (@MainActor () -> AnyView)? {
        get { self[MerchantCoopInboxDestinationKey.self] }
        set { self[MerchantCoopInboxDestinationKey.self] = newValue }
    }
}

private struct CoopFlowPreviewWriteFactoryKey: EnvironmentKey {
    static let defaultValue: CoopFlowPreviewWriteFactory? = nil
}
extension EnvironmentValues {
    var coopFlowPreviewWrite: CoopFlowPreviewWriteFactory? {
        get { self[CoopFlowPreviewWriteFactoryKey.self] }
        set { self[CoopFlowPreviewWriteFactoryKey.self] = newValue }
    }
}
