import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// fix-1128b-social gap #1 (audit M-01b/c, M-13b). One reviewed `/api/v1/community` writer for one viewer
/// (market, host, namespace, account, epoch, role) until it expires. It admits only the exact post / comment routes
/// the mini-program sends (pages/square/detail/index.js:493-540, utils/community-post-api.js):
/// - like / bookmark: `POST posts/{id}/actions {actionType,requestId,source}`, `DELETE posts/{id}/actions/{LIKE|BOOKMARK} {requestId}`
/// - comment / reply: `POST posts/{id}/comments {body,clientRequestId,parentId?}`
/// - comment like: `POST comments/{id}/actions {requestId}`, `DELETE comments/{id}/actions/LIKE {requestId}`
/// (ApiCommunityPostController.java:128-183, us/r3-functional). Every write carries a request id, so a server replay
/// returns the same result (CommunityPostServiceImpl `isCommandReplay`).
public struct SquareCommunityWriteApproval: Equatable {
    public let market: RegionalMarket
    public let baseURL: URL
    public let namespace: String
    public let accountID: Int
    public let epoch: UInt64
    public let role: String
    public let expiresAt: Date

    public init(context: RuntimeDependencyContext, expiresAt: Date) throws {
        guard context.session.accountID > 0, !context.session.namespace.isEmpty,
              context.role == "player" || context.role == "club",
              expiresAt.timeIntervalSince1970.isFinite else { throw APIError.invalidConfiguration }
        market = context.market; baseURL = context.baseURL; namespace = context.session.namespace
        accountID = context.session.accountID; epoch = context.session.epoch; role = context.role
        self.expiresAt = expiresAt
    }

    public func matches(_ context: RuntimeDependencyContext, now: Date = Date()) -> Bool {
        context.market == market && context.baseURL == baseURL && context.session.namespace == namespace &&
            context.session.accountID == accountID && context.session.epoch == epoch && context.role == role && now < expiresAt
    }

    /// Exact method + template table. `{}` is one positive decimal id.
    static let templates: [(method: String, path: String)] = [
        ("POST", "api/v1/community/posts/{}/actions"),
        ("DELETE", "api/v1/community/posts/{}/actions/LIKE"),
        ("DELETE", "api/v1/community/posts/{}/actions/BOOKMARK"),
        ("POST", "api/v1/community/posts/{}/comments"),
        ("POST", "api/v1/community/comments/{}/actions"),
        ("DELETE", "api/v1/community/comments/{}/actions/LIKE")
    ]

    public static func admits(method: String, relativePath: String) -> Bool {
        let parts = relativePath.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        return templates.contains { template in
            guard template.method == method else { return false }
            let expected = template.path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
            guard expected.count == parts.count else { return false }
            for (want, have) in zip(expected, parts) {
                if want == "{}" {
                    guard let id = Int(have), id > 0, String(id) == have else { return false }
                } else if want != have { return false }
            }
            return true
        }
    }

    /// The request must target this approval's host with this viewer's token and an admitted method + path.
    public func admits(_ request: URLRequest, token: String) -> Bool {
        guard let url = request.url, let method = request.httpMethod, url.query == nil, url.fragment == nil,
              url.user == nil, url.password == nil, url.scheme == baseURL.scheme, url.host == baseURL.host, url.port == baseURL.port,
              request.value(forHTTPHeaderField: "Authorization") == token else { return false }
        let base = baseURL.path.hasSuffix("/") ? String(baseURL.path.dropLast()) : baseURL.path
        guard url.path.hasPrefix(base + "/") else { return false }
        return Self.admits(method: method, relativePath: String(url.path.dropFirst(base.count + 1)))
    }

    /// The v1 commands this writer sends. Legacy square, member and report commands keep their own access.
    public static func handles(_ command: SocialActionCommand) -> Bool {
        switch command {
        case .postAction, .communityComment, .communityCommentLike: return true
        default: return false
        }
    }
}

/// Adds the community writer in front of the member access. Member actions, legacy square commands and every read
/// still go to `base`, so follow / 私信 and the snapshot reads are unchanged.
@MainActor public final class SquareCommunityActionAccess: SocialActionAccess {
    private let base: any SocialActionAccess
    private let configuration: APIConfiguration?
    private let approval: () -> SquareCommunityWriteApproval?
    private let transport: any HTTPTransport
    private let current: () -> RuntimeDependencyContext?
    private let now: () -> Date

    public init(base: any SocialActionAccess, configuration: APIConfiguration?, transport: any HTTPTransport,
                approval: @escaping () -> SquareCommunityWriteApproval?,
                current: @escaping () -> RuntimeDependencyContext?, now: @escaping () -> Date = Date.init) {
        self.base = base; self.configuration = configuration; self.transport = transport
        self.approval = approval; self.current = current; self.now = now
    }

    public var identity: SocialAccountIdentity { base.identity }
    public var availability: SocialActionAvailability { liveApproval() != nil ? .approved : base.availability }

    private func liveApproval() -> (SquareCommunityWriteApproval, RuntimeDependencyContext, APIConfiguration)? {
        guard let configuration, let context = current(), let value = approval(),
              value.matches(context, now: now()), value.baseURL == configuration.baseURL,
              identity.accountID == context.session.accountID else { return nil }
        return (value, context, configuration)
    }

    public func availability(for command: SocialActionCommand, target: SocialActionTarget) -> SocialActionAvailability {
        guard SquareCommunityWriteApproval.handles(command) else { return base.availability(for: command, target: target) }
        return liveApproval() == nil ? .disabled : .approved
    }
    public func hasPending(target: SocialActionTarget) -> Bool { base.hasPending(target: target) }
    public func snapshot(target: SocialActionTarget) async throws -> SocialActionSnapshot {
        try await base.snapshot(target: target)
    }
    public func snapshot(target: SocialActionTarget, generation: SquareContentGeneration?) async throws -> SocialActionSnapshot {
        try await base.snapshot(target: target, generation: generation)
    }
    public func perform(_ command: SocialActionCommand, snapshot: SocialActionSnapshot,
                        expectedIdentity: SocialAccountIdentity) async throws -> SocialActionReceipt {
        try await perform(command, snapshot: snapshot, expectedIdentity: expectedIdentity, isCurrent: { true })
    }
    public func perform(_ command: SocialActionCommand, snapshot: SocialActionSnapshot, expectedIdentity: SocialAccountIdentity,
                        isCurrent: @escaping () -> Bool) async throws -> SocialActionReceipt {
        guard SquareCommunityWriteApproval.handles(command) else {
            return try await base.perform(command, snapshot: snapshot, expectedIdentity: expectedIdentity, isCurrent: isCurrent)
        }
        let request: URLRequest, context: RuntimeDependencyContext
        do {
            guard isCurrent(), identity == expectedIdentity, let live = liveApproval() else { throw SocialActionBlock.disabled }
            let grant = live.0, captured = live.1
            let built = try SocialActionRequestBuilder(configuration: live.2)
                .make(command, snapshot: snapshot, identity: expectedIdentity, token: captured.session.token)
            guard grant.admits(built, token: captured.session.token) else { throw SocialActionBlock.disabled }
            try Task.checkCancellation()
            request = built; context = captured
        } catch { throw SocialActionWriteFailure.notSent }
        let data: Data, status: Int
        do { (data, status) = try await transport.send(request) }
        catch { throw SocialActionWriteFailure.outcomeUnknown }
        guard current() == context, isCurrent() else { throw SocialActionWriteFailure.outcomeUnknown }
        return try Self.receipt(data: data, status: status)
    }

    /// `code == 200` is the server's confirmation; a business code (403 作者限制了谁可以回复, 409 该帖文已关闭互动 …) or a
    /// 401 is a rejection that applied nothing; an unreadable answer is an unknown outcome (never retried automatically).
    static func receipt(data: Data, status: Int) throws -> SocialActionReceipt {
        if status == 401 { throw SocialActionWriteFailure.rejected }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SocialActionWriteFailure.outcomeUnknown
        }
        let code = (root["code"] as? Int) ?? (root["code"] as? NSNumber)?.intValue
        guard let code else { throw SocialActionWriteFailure.outcomeUnknown }
        guard code == 200, (200..<300).contains(status) else {
            if (200..<500).contains(status) { throw SocialActionWriteFailure.rejected }
            throw SocialActionWriteFailure.outcomeUnknown
        }
        return SocialActionReceipt(synthetic: false)
    }
}

/// The MP toggles like / bookmark / comment-like straight away, without a review sheet. The result is the server's.
public enum SquareInstantActionOutcome: Equatable {
    case confirmed, signedOut, notSent, rejected, unknown

    /// Localizable key for the inline message, nil when confirmed.
    public var messageKey: String? {
        switch self {
        case .confirmed: return nil
        case .signedOut: return "social1128.instant.signedOut"
        case .notSent: return "social1128.instant.notSent"
        case .rejected: return "social1128.instant.rejected"
        case .unknown: return "social1128.instant.unknown"
        }
    }
}

public extension SocialActionCoordinator {
    /// Prepare (fresh read) and confirm in one step, then report the coordinator's final state for this target.
    func sendImmediately(_ command: SocialActionCommand, target: SocialActionTarget, ownerID: UUID) async -> SquareInstantActionOutcome {
        let expected = identity
        guard expected.accountID != nil else { return .signedOut }
        guard availability(for: command, target: target) == .approved else { return .notSent }
        do {
            let review = try await prepare(command, target: target, ownerID: ownerID, expectedIdentity: expected)
            await confirm(review)
        } catch SocialActionBlock.signIn {
            return .signedOut
        } catch SocialActionBlock.pending {
            return .unknown
        } catch {
            return .notSent
        }
        switch state(target: target, generation: command.requiredGeneration) {
        case .acknowledged: return .confirmed
        case .rejected: return .rejected
        case .outcomeUnknown, .submitting: return .unknown
        default: return .notSent
        }
    }
}
