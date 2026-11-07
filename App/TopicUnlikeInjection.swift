import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Where the favorites screen gets its confirmed-unlike controller.
/// The transport must be the composition-issued one that allows only
/// `api/topic/like` and `api/topic/like_list`; until composition supplies it
/// the provider is nil and favorites stay read-only (the heart is not shown).
@MainActor enum TopicUnlikeInjectionSource {
    /// Composition hook (worker G1): assign once at launch, see the report for the exact line.
    static var transportProvider: (@MainActor (RuntimeDependencyContext) -> (any HTTPTransport)?)?

    static func controller(for session: AppSession) -> TopicUnlikeController? {
        guard let provider = transportProvider, let context = session.currentRuntimeDependencyContext,
              let transport = provider(context) else { return nil }
        return TopicUnlikeFactory.makeController(context: context, transport: transport,
            current: { [weak session] in session?.currentRuntimeDependencyContext },
            // A 401 surfaces as a failed (not removed) state; session expiry stays with AppSession (G1).
            onUnauthorized: {},
            lifetime: TopicUnlikeFactory.maximumLifetime)
    }
}

/// Injects the controller into the environment and rebuilds it whenever the
/// session revision changes, so a retired account can never confirm an unlike.
@MainActor struct TopicUnlikeInjection: ViewModifier {
    @ObservedObject var session: AppSession
    @State private var controller: TopicUnlikeController?
    func body(content: Content) -> some View {
        content
            .environment(\.topicUnlikeController, controller)
            .task(id: session.sessionRevision) { controller = TopicUnlikeInjectionSource.controller(for: session) }
            .onDisappear { controller = nil }
    }
}

/// Optional-session convenience so existing call sites without a session keep compiling.
@MainActor struct TopicUnlikeInjectionIfAvailable: ViewModifier {
    let session: AppSession?
    @ViewBuilder func body(content: Content) -> some View {
        if let session { content.modifier(TopicUnlikeInjection(session: session)) } else { content }
    }
}
