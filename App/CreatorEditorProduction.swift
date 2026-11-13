import Foundation
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// G2 + G3. Builds the order-center reader and the creator topic editor from the shipped
/// China player grant. Nil when the grant lacks the routes, so their entries stay hidden.
/// The requests go through the session's composition transport, which re-checks the grant.
@MainActor enum CreatorEditorProduction {
    static func topicEditor(session: AppSession) -> TopicCreatorEditorService? {
        guard let pair = granted(session, paths: TopicCreatorEditorRoute.grantPaths) else { return nil }
        let (runtime, api) = pair
        return TopicCreatorEditorService(baseURL: api.baseURL, transport: session.runtimeHTTPTransport,
            token: { [weak session] in session?.token },
            enabled: { [weak session] in session.map { stillGranted($0, runtime, TopicCreatorEditorRoute.grantPaths) } ?? false },
            unauthorized: unauthorized(session, runtime))
    }

    static func orderCenter(session: AppSession) -> OrderCenterDetailService? {
        let paths: Set<String> = [OrderCenterDetailService.path]
        guard let pair = granted(session, paths: paths) else { return nil }
        let (runtime, api) = pair
        return OrderCenterDetailService(baseURL: api.baseURL, transport: session.runtimeHTTPTransport,
            token: { [weak session] in session?.token },
            enabled: { [weak session] in session.map { stillGranted($0, runtime, paths) } ?? false },
            unauthorized: unauthorized(session, runtime))
    }

    private static func granted(_ session: AppSession, paths: Set<String>) -> (RuntimeDependencyContext, APIConfiguration)? {
        guard let runtime = session.currentRuntimeDependencyContext, runtime.market == .china,
              runtime.role == "player" || runtime.role == "club",
              let grant = session.composition.playerWriteGrant(runtime), grant.play.paths.isSuperset(of: paths),
              let api = session.regionalConfiguration?.apiConfiguration, api.baseURL == runtime.baseURL else { return nil }
        return (runtime, api)
    }

    private static func stillGranted(_ session: AppSession, _ runtime: RuntimeDependencyContext, _ paths: Set<String>) -> Bool {
        guard let live = session.currentRuntimeDependencyContext, live == runtime,
              let grant = session.composition.playerWriteGrant(live) else { return false }
        return grant.play.paths.isSuperset(of: paths)
    }

    private static func unauthorized(_ session: AppSession, _ runtime: RuntimeDependencyContext) -> () -> Void {
        { [weak session] in
            guard let session, session.currentRuntimeDependencyContext == runtime else { return }
            session.expireIfMatching(error: APIError.unauthorized, stamp: runtime.session.epoch, credential: runtime.session.token)
        }
    }
}
