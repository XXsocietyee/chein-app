import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Deployment permission is separate from server permission and the immutable review.
/// Each grant covers the exact command, including its content, audience and targets.
/// Inputs are never persisted or read from remote feature flags.
public struct OfficialActionProductionApproval {
    public let market: RegionalMarket
    public let endpoints: OperationEndpointApproval
    public let commands: [OfficialActionCommand]
    public let reviewedPolicyVersion: String
    /// Gap #17 (1128 plan, G-10b): the signed-in player's own participation commands on any event / party the server
    /// shows them: v1 报名 / 完成, v2 到达 (`/events/{id}/arrivals`), inbox 接受 / 拒绝 / 退出 and organizer 接受 / 拒绝.
    /// Publish, broadcast and merchant invites stay exact-command only. The server checks every target.
    public let playerTargets: Bool
    public init(market: RegionalMarket, endpoints: OperationEndpointApproval,
                commands: [OfficialActionCommand], reviewedPolicyVersion: String) throws {
        guard !commands.isEmpty, !reviewedPolicyVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw APIError.invalidConfiguration }
        for command in commands {
            _ = try command.payload()
            guard let reads = Self.readPaths(for: command), reads.union([command.path]).isSubset(of: endpoints.paths) else { throw APIError.invalidConfiguration }
        }
        self.market = market; self.endpoints = endpoints; self.commands = commands; self.reviewedPolicyVersion = reviewedPolicyVersion
        playerTargets = false
    }
    /// Gap #17: the Release player grant. `endpoints` must carry every `playerTargetPaths` template.
    public init(playerMarket market: RegionalMarket, endpoints: OperationEndpointApproval, reviewedPolicyVersion: String) throws {
        guard market == .china, Self.playerTargetPaths.isSubset(of: endpoints.paths),
              !reviewedPolicyVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw APIError.invalidConfiguration }
        self.market = market; self.endpoints = endpoints; commands = []; self.reviewedPolicyVersion = reviewedPolicyVersion
        playerTargets = true
    }
    /// `ApiOfficialEventController` participation routes (POST) and their read-backs (GET), as templates.
    public static let playerTargetPaths: Set<String> = [
        "api/official/events/{}", "api/official/events/{}/signup", "api/official/events/{}/complete",
        "api/official/events/{}/arrivals", "api/official/v2/party-inbox", "api/official/can-publish",
        "api/official/v2/parties/{}/ACCEPT", "api/official/v2/parties/{}/DECLINE", "api/official/v2/parties/{}/WITHDRAW",
        "api/official/v2/organizer-invites/{}/accept", "api/official/v2/organizer-invites/{}/decline"
    ]
    func matches(_ context: RuntimeDependencyContext) -> Bool {
        market == .china && context.market == market && endpoints.baseURL == context.baseURL &&
        endpoints.namespace == context.session.namespace && endpoints.accountID == context.session.accountID
    }
    func permits(_ command: OfficialActionCommand, context: RuntimeDependencyContext) -> Bool {
        guard matches(context) else { return false }
        if commands.contains(command) && Self.readPaths(for: command) != nil { return true }
        return admitsPlayerTarget(command)
    }
    /// The read-backs one command may use under this approval.
    func approvedReadPaths(for command: OfficialActionCommand) -> Set<String>? {
        if let exact = Self.readPaths(for: command) { return exact }
        guard playerTargets, case .arrival(let evidence) = command else { return nil }
        return ["api/official/events/\(evidence.eventID)"]
    }
    private func admitsPlayerTarget(_ command: OfficialActionCommand) -> Bool {
        // `payload()` is nil for a bodiless command; only a throw means the input is invalid.
        guard playerTargets else { return false }
        do { _ = try command.payload() } catch { return false }
        switch command {
        case .signup, .complete, .arrival, .respond: break
        case .publish, .broadcast, .inviteMerchants: return false
        }
        guard let reads = approvedReadPaths(for: command) else { return false }
        return reads.union([command.path]).allSatisfy { endpoints.paths.contains(Self.template($0)) }
    }
    /// Numeric segments become `{}`; every other segment (including the party action) stays literal.
    public static func template(_ path: String) -> String {
        path.split(separator: "/", omittingEmptySubsequences: false).map { segment -> String in
            !segment.isEmpty && segment.allSatisfy({ $0.isASCII && $0.isNumber }) ? "{}" : String(segment)
        }.joined(separator: "/")
    }
    static func readPaths(for command: OfficialActionCommand) -> Set<String>? {
        switch command {
        case .publish, .broadcast: return ["api/official/can-publish", "api/official/my-published"]
        case .signup(let id), .complete(let id): return ["api/official/events/\(id)"]
        case .respond(_, let type, _, _):
            return type == "OFFICIAL" ? ["api/official/v2/party-inbox", "api/official/can-publish"] : ["api/official/v2/party-inbox"]
        // Current hosts lack authoritative roam/location evidence and the topic,
        // optional node and terms required by the merchant-invite source contract.
        case .arrival, .inviteMerchants: return nil
        }
    }
}

/// Current projection, never delivery/reward/attendance proof. A missing party is
/// inconclusive: the source inbox excludes DECLINED/WITHDRAWN rows.
public enum OfficialActionReadback: Equatable {
    case event(OfficialEvent), published(OfficialPublished), party(OfficialPartyInvite?)
}
@MainActor protocol OfficialActionProtectedAccess: OfficialActionAccess {
    var readback: OfficialActionReadback? { get }
    func send(_ command: OfficialActionCommand, authorization: OfficialActionDispatchAuthorization) async throws -> OfficialActionReceipt
}

/// Private, single-dispatch transport. Only the coordinator can supply the
/// durable-lock/review authorization required by the factory before a POST.
@MainActor private final class OfficialActionProductionTransport: HTTPTransport {
    let expected: URLRequest
    let captured: RuntimeDependencyContext
    let current: () -> RuntimeDependencyContext?
    let transport: any HTTPTransport
    let authorization: OfficialActionDispatchAuthorization
    var dispatched = false
    init(expected: URLRequest, captured: RuntimeDependencyContext, transport: any HTTPTransport,
         current: @escaping () -> RuntimeDependencyContext?, authorization: OfficialActionDispatchAuthorization) {
        self.expected = expected; self.captured = captured; self.transport = transport
        self.current = current; self.authorization = authorization
    }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        try authorization.validate()
        guard !dispatched, current() == captured, request.url == expected.url,
              request.httpMethod == "POST", request.httpBody == expected.httpBody,
              request.httpBodyStream == nil, request.allHTTPHeaderFields == expected.allHTTPHeaderFields else { throw OfficialActionFailure.stale }
        dispatched = true
        let response = try await transport.send(request)
        try authorization.validate()
        guard current() == captured else { throw OfficialActionFailure.unknown }
        return response
    }
}

@MainActor private final class OfficialActionReviewTransport: HTTPTransport {
    let captured: RuntimeDependencyContext
    let paths: Set<String>
    let transport: any HTTPTransport
    let current: () -> RuntimeDependencyContext?
    let valid: () -> Bool
    init(captured: RuntimeDependencyContext, paths: Set<String>, transport: any HTTPTransport,
         current: @escaping () -> RuntimeDependencyContext?, valid: @escaping () -> Bool) {
        self.captured = captured; self.paths = paths; self.transport = transport; self.current = current; self.valid = valid
    }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        try Task.checkCancellation()
        guard valid(), current() == captured, request.httpMethod == "GET", request.httpBody == nil, request.httpBodyStream == nil,
              request.value(forHTTPHeaderField: "Authorization") == captured.session.token,
              paths.contains(where: { captured.baseURL.appendingPathComponent($0) == request.url }) else { throw OfficialActionFailure.disabled }
        let result = try await transport.send(request)
        try Task.checkCancellation()
        guard valid(), current() == captured else { throw OfficialActionFailure.stale }
        return result
    }
}

/// Normal AppSession composition. Nil approval performs no read or write requests.
/// Existing synthetic/review-only adapters remain separate from this production path.
@MainActor public final class OfficialActionProductionFactory: OfficialActionAccess, OfficialActionProtectedAccess {
    private let api: APIConfiguration?
    /// Gap #17: read on every use, so a coordinator built before sign-in picks up the signed-in player's grant.
    private let approvalSource: () -> OfficialActionProductionApproval?
    private var approval: OfficialActionProductionApproval? { approvalSource() }
    private let transport: any HTTPTransport
    private let current: () -> RuntimeDependencyContext?
    private let currentIdentity: () -> OfficialActionIdentity?
    private var storedReadback: OfficialActionReadback?
    public var readback: OfficialActionReadback? { _ = identity; return storedReadback }
    private var observedContext: RuntimeDependencyContext?
    private var observedIdentity: OfficialActionIdentity?
    private var scopedIdentity: OfficialActionIdentity?
    public var identity: OfficialActionIdentity? {
        guard let context = current(), let identity = currentIdentity(), identity.accountID == context.session.accountID,
              identity.namespace == context.session.namespace else {
            observedContext = nil; observedIdentity = nil; scopedIdentity = nil; storedReadback = nil
            return nil
        }
        if observedContext != context || observedIdentity != identity {
            observedContext = context; observedIdentity = identity; storedReadback = nil
            scopedIdentity = .init(accountID: identity.accountID, epoch: UUID(), namespace: identity.namespace)
        }
        return scopedIdentity
    }
    public var enabled: Bool {
        guard let api, let approval, let context = current(), identity != nil else { return false }
        return api.baseURL == context.baseURL && approval.matches(context)
    }
    public init(api: APIConfiguration?, approval: OfficialActionProductionApproval? = nil, transport: any HTTPTransport,
                current: @escaping () -> RuntimeDependencyContext?, identity: @escaping () -> OfficialActionIdentity?) {
        self.api = api; self.approvalSource = { approval }; self.transport = transport; self.current = current; self.currentIdentity = identity
    }
    public init(api: APIConfiguration?, approvalSource: @escaping () -> OfficialActionProductionApproval?, transport: any HTTPTransport,
                current: @escaping () -> RuntimeDependencyContext?, identity: @escaping () -> OfficialActionIdentity?) {
        self.api = api; self.approvalSource = approvalSource; self.transport = transport; self.current = current; self.currentIdentity = identity
    }
    private func capture(_ command: OfficialActionCommand) throws -> (APIConfiguration, RuntimeDependencyContext, OfficialActionIdentity) {
        guard enabled, let api, let context = current(), let identity, approval?.permits(command, context: context) == true else { throw OfficialActionFailure.disabled }
        return (api, context, identity)
    }
    private func reader(_ command: OfficialActionCommand, api: APIConfiguration, context: RuntimeDependencyContext,
                        identity: OfficialActionIdentity) throws -> OfficialEventService {
        guard let paths = approval?.approvedReadPaths(for: command) else { throw OfficialActionFailure.disabled }
        return OfficialEventService(configuration: api, transport: OfficialActionReviewTransport(captured: context, paths: paths,
            transport: transport, current: current, valid: { [weak self] in
                self?.identity == identity && self?.approval?.permits(command, context: context) == true
            }))
    }
    public func snapshot(for command: OfficialActionCommand) async throws -> OfficialActionSnapshot {
        storedReadback = nil
        let (api, context, identity) = try capture(command)
        let reader = try reader(command, api: api, context: context, identity: identity)
        let token = context.session.token
        let value: OfficialActionSnapshot
        switch command {
        case .publish:
            value = .init(identity: identity, publisher: try await reader.canPublish(token: token))
        case .broadcast(let draft):
            let permission = try await reader.canPublish(token: token)
            var event: OfficialEvent?
            if let id = draft.eventID { event = try await reader.myPublished(token: token).events.first { $0.id == id } }
            value = .init(identity: identity, publisher: permission, event: event)
        case .signup(let id), .complete(let id):
            value = .init(identity: identity, event: try await reader.detail(id: id, token: token))
        case .respond(let id, let type, _, _):
            let permission = type == "OFFICIAL" ? try await reader.canPublish(token: token) : false
            let invite = try await reader.partyInbox(token: token).first { $0.id == id && $0.partyType == type }
            value = .init(identity: identity, publisher: permission, invite: invite)
        case .arrival(let evidence):
            // Gap #17: MP roam `verifyEventArrival` re-reads the event; the mission must still be open.
            value = .init(identity: identity, event: try await reader.detail(id: evidence.eventID, token: token))
        case .inviteMerchants: throw OfficialActionFailure.disabled
        }
        guard self.identity == identity, current() == context else { throw OfficialActionFailure.stale }
        return value
    }
    /// A naked service call cannot bypass the review or durable lock.
    public func send(_ command: OfficialActionCommand) async throws -> OfficialActionReceipt { throw OfficialActionFailure.forbidden }
    func send(_ command: OfficialActionCommand, authorization: OfficialActionDispatchAuthorization) async throws -> OfficialActionReceipt {
        storedReadback = nil
        try authorization.validate()
        let (api, context, identity) = try capture(command)
        guard authorization.review.command == command, authorization.review.snapshot.identity == identity else { throw OfficialActionFailure.stale }
        let expected = try OfficialActionService.request(command, configuration: api, token: context.session.token)
        guard expected.httpBody == authorization.review.body else { throw OfficialActionFailure.stale }
        let scoped = OfficialActionProductionTransport(expected: expected, captured: context, transport: transport,
                                                       current: current, authorization: authorization)
        let writer = OfficialActionService(configuration: api, transport: scoped, enabled: true)
        let receipt = try await writer.send(command, token: context.session.token)
        // The POST has completed. Every readback failure is now unknown, including an
        // explicit GET rejection; it must never release a submitted operation's lock.
        do {
            let reader = try reader(command, api: api, context: context, identity: identity)
            let facts: OfficialActionReadback
            switch command {
            case .publish, .broadcast:
                let published = try await reader.myPublished(token: context.session.token)
                switch receipt {
                case .published(let id): guard published.events.contains(where: { $0.id == id && $0.isCompleteRecord }) else { throw OfficialActionFailure.unknown }
                case .broadcastSubmitted(let id): guard published.broadcasts.contains(where: { $0.id == id }) else { throw OfficialActionFailure.unknown }
                default: throw OfficialActionFailure.unknown
                }
                facts = .published(published)
            case .signup(let id), .complete(let id): facts = .event(try await reader.detail(id: id, token: context.session.token))
            case .respond(let id, let type, _, _): facts = .party(try await reader.partyInbox(token: context.session.token).first { $0.id == id && $0.partyType == type })
            case .arrival(let evidence): facts = .event(try await reader.detail(id: evidence.eventID, token: context.session.token))
            case .inviteMerchants: throw OfficialActionFailure.disabled
            }
            try authorization.validate()
            guard self.identity == identity, current() == context else { throw OfficialActionFailure.unknown }
            storedReadback = facts
            return receipt
        } catch { throw OfficialActionFailure.unknown }
    }
}
