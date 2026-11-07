import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Builds a `TopicUnlikeController` for one captured runtime context.
/// It never widens authority: China market, a player/club role, a context that is
/// still current, and an exact two-path endpoint approval bound to that account.
/// The transport must be the composition-issued one; this factory sends nothing itself.
@MainActor public enum TopicUnlikeFactory {
    public static let allowedRoles: Set<String> = ["player", "club"]
    /// Short lived on purpose: the favorites screen rebuilds the controller each time it appears.
    public static let maximumLifetime: TimeInterval = 3_600

    public static func makeController(context: RuntimeDependencyContext, transport: any HTTPTransport,
                                      current: @escaping () -> RuntimeDependencyContext?,
                                      onUnauthorized: @escaping () -> Void,
                                      lifetime: TimeInterval) -> TopicUnlikeController? {
        guard context.market == .china, allowedRoles.contains(context.role),
              lifetime.isFinite, lifetime > 0,
              let configuration = try? APIConfiguration(baseURL: context.baseURL),
              let endpoint = try? OperationEndpointApproval(baseURL: context.baseURL,
                  namespace: context.session.namespace, accountID: context.session.accountID,
                  paths: TopicUnlikeApproval.paths),
              let approval = try? TopicUnlikeApproval(endpoint: endpoint, accountID: context.session.accountID,
                  expiresAt: Date().addingTimeInterval(min(lifetime, maximumLifetime))) else { return nil }
        let session: () -> TopicUnlikeSession? = {
            guard let fresh = current(), fresh == context else { return nil }
            return try? TopicUnlikeSession(accountID: fresh.session.accountID, epoch: fresh.session.epoch,
                namespace: fresh.session.namespace, market: fresh.market, token: fresh.session.token)
        }
        return TopicUnlikeController(configuration: configuration, approvals: [approval], transport: transport,
            current: session, onUnauthorized: onUnauthorized)
    }
}
