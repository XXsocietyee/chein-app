import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// The signed-in viewer a waitlist lease was issued for. The token never leaves Core.
public struct RegistrationWaitlistLeaseSession: Equatable {
    public let accountID: Int
    public let namespace: String
    let token: String
    public init(accountID: Int, namespace: String, token: String) throws {
        guard accountID > 0, !namespace.isEmpty, AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        self.accountID = accountID; self.namespace = namespace; self.token = token
    }
}

/// Gap #8 (1128 plan, G-02): the Release player waitlist. `POST api/club/event-ops/waitlist/{status,join,cancel}` with
/// `{activityId, ticketId}` (`ApiClubEventOpsController`, MP `pages/activity/baoming/baoming.js:930-970`), scoped to one
/// activity and the reviewed endpoint lease, sent through the composition transport. Every write is preceded by a fresh
/// status read (join only when `canJoin`, cancel only when `canCancel`) and followed by an authoritative status read;
/// only that read-back is returned. Nothing is inferred from the join receipt alone.
@MainActor public final class RegistrationWaitlistLeaseService: RegistrationWaitlistServing {
    public let approval: OperationEndpointApproval
    public let activityID: Int
    private let configuration: APIConfiguration
    private let waitlist: RegistrationWaitlistService
    private let current: () -> RegistrationWaitlistLeaseSession?
    private var mutating: Set<RegistrationWaitlistScope> = []

    public init(configuration: APIConfiguration, transport: any HTTPTransport, approval: OperationEndpointApproval,
                activityID: Int, current: @escaping () -> RegistrationWaitlistLeaseSession?) throws {
        guard activityID > 0, approval.baseURL == configuration.baseURL,
              RegistrationProductionApproval.waitlistPaths.isSubset(of: approval.paths) else { throw APIError.invalidConfiguration }
        self.configuration = configuration; self.approval = approval; self.activityID = activityID
        self.current = current
        waitlist = RegistrationWaitlistService(configuration: configuration, transport: transport)
    }

    public func status(_ scope: RegistrationWaitlistScope) async throws -> RegistrationWaitlistStatus {
        guard !mutating.contains(scope) else { throw RegistrationPendingFailure.busy }
        return try await read(scope)
    }

    public func join(_ scope: RegistrationWaitlistScope) async throws -> RegistrationWaitlistStatus {
        try await mutate(join: true, scope: scope)
    }

    public func cancel(_ scope: RegistrationWaitlistScope) async throws -> RegistrationWaitlistStatus {
        try await mutate(join: false, scope: scope)
    }

    private func read(_ scope: RegistrationWaitlistScope) async throws -> RegistrationWaitlistStatus {
        let session = try check(scope, operation: "status")
        let result = try await waitlist.status(scope, accountID: session.accountID, token: session.token)
        try fence(session, scope: scope, operation: "status")
        return result
    }

    private func mutate(join: Bool, scope: RegistrationWaitlistScope) async throws -> RegistrationWaitlistStatus {
        guard !mutating.contains(scope) else { throw RegistrationPendingFailure.busy }
        mutating.insert(scope); defer { mutating.remove(scope) }
        let operation = join ? "join" : "cancel"
        let session = try check(scope, operation: operation)
        let before = try await read(scope)
        try fence(session, scope: scope, operation: operation)
        guard join ? before.canJoin : before.canCancel else { throw APIError.invalidRequest }
        if join { _ = try await waitlist.join(scope, accountID: session.accountID, token: session.token) }
        else { try await waitlist.cancel(scope, token: session.token) }
        try fence(session, scope: scope, operation: operation)
        let after = try await read(scope)
        guard Self.reconciles(after, join: join) else { throw APIError.malformedResponse }
        return after
    }

    static func reconciles(_ status: RegistrationWaitlistStatus, join: Bool) -> Bool {
        join ? [.waiting, .offered, .claimed, .converted].contains(status.state) : [.none, .cancelled, .expired].contains(status.state)
    }

    private func check(_ scope: RegistrationWaitlistScope, operation: String) throws -> RegistrationWaitlistLeaseSession {
        try Task.checkCancellation()
        guard scope.activityID == activityID, let session = current(),
              approval.allows(configuration: configuration, namespace: session.namespace, accountID: session.accountID,
                              path: "api/club/event-ops/waitlist/\(operation)") else { throw APIError.notConfigured }
        return session
    }

    private func fence(_ session: RegistrationWaitlistLeaseSession, scope: RegistrationWaitlistScope, operation: String) throws {
        guard try check(scope, operation: operation) == session else { throw APIError.unauthorized }
    }
}
