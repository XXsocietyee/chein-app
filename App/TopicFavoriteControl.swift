import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// R7-PC-B1-1 (r1 PC-B-1-2): MP topic 收藏 — `POST api/topic/like {id, type: 1|0}`, seeded from the topic read's `isLike`.
/// Optimistic flip, rolled back with a toast when the write is rejected or its outcome is unknown.
/// The write rides the composition-issued like transport (`TopicUnlikeInjectionSource.transportProvider`, the same one
/// 我的收藏 uses for 取消点赞). Until composition supplies it there is no control and the button stays hidden (gate off).
@MainActor final class TopicFavoriteControl: ObservableObject {
    @Published private(set) var overrides: [Int: Bool] = [:]
    @Published private(set) var busy: Set<Int> = []
    @Published var toast: String?
    private let host: TopicLikeHostController

    init(host: TopicLikeHostController) { self.host = host }

    static func make(for session: AppSession) -> TopicFavoriteControl? {
        guard let provider = TopicUnlikeInjectionSource.transportProvider,
              let context = session.currentRuntimeDependencyContext,
              context.market == .china, TopicUnlikeFactory.allowedRoles.contains(context.role),
              let transport = provider(context),
              let configuration = try? APIConfiguration(baseURL: context.baseURL) else { return nil }
        let factory = TopicLikeOperationFactory(configuration: configuration)
        let host = TopicLikeHostController(
            likeGrantEnabled: true,
            requestBuilder: { id, direction, token in try factory.request(topicID: id, direction: direction, token: token) },
            transport: transport,
            currentScope: { [weak session] in
                guard let fresh = session?.currentRuntimeDependencyContext, fresh == context else { return nil }
                return try? TopicLikeScope(accountID: fresh.session.accountID, epoch: fresh.session.epoch, namespace: fresh.session.namespace)
            },
            token: { [weak session] in
                guard let session, session.currentRuntimeDependencyContext == context else { return nil }
                return session.token
            })
        return TopicFavoriteControl(host: host)
    }

    func isFavorited(_ topic: TopicDetail) -> Bool { overrides[topic.id] ?? (topic.isLike == 1) }

    func toggle(_ topic: TopicDetail, locale: Locale) {
        let id = topic.id
        guard !busy.contains(id) else { return }
        let was = isFavorited(topic)
        overrides[id] = !was
        busy.insert(id)
        Task { @MainActor in
            let state = try? await host.setLikeDirection(topicID: id, direction: TopicLikeDirection(liked: !was))
            busy.remove(id)
            switch state {
            case .confirmed(let liked)?: overrides[id] = liked
            case .sending?, .awaitingReadback?: break
            default:
                overrides[id] = was
                toast = appLocalized("topic.favorite.failed", locale: locale)
            }
        }
    }
}

private struct TopicFavoriteControlKey: EnvironmentKey { static let defaultValue: TopicFavoriteControl? = nil }
extension EnvironmentValues {
    /// Nil hides 收藏 on topic detail.
    var topicFavoriteControl: TopicFavoriteControl? {
        get { self[TopicFavoriteControlKey.self] }
        set { self[TopicFavoriteControlKey.self] = newValue }
    }
}

/// Builds the control for the current session and rebuilds it on every session revision, so a retired account can
/// never write a like.
@MainActor struct TopicFavoriteInjection: ViewModifier {
    @ObservedObject var session: AppSession
    @State private var control: TopicFavoriteControl?
    func body(content: Content) -> some View {
        content
            .environment(\.topicFavoriteControl, control)
            .task(id: session.sessionRevision) { control = TopicFavoriteControl.make(for: session) }
    }
}

/// Share + 收藏 for one topic, observing the control so the bookmark flips at once.
@MainActor struct TopicFavoriteToolbarActions: View {
    @ObservedObject var control: TopicFavoriteControl
    let topic: TopicDetail
    let onToast: (String) -> Void
    @Environment(\.locale) private var locale
    var body: some View {
        TopicXcxToolbarActions(shareURL: PublicContentShareLink.topic(id: topic.id), shareTitle: topic.name,
                               isFavorited: control.isFavorited(topic),
                               onToggleFavorite: { control.toggle(topic, locale: locale) })
            .disabled(control.busy.contains(topic.id))
            .onChange(of: control.toast) { _, message in
                guard let message else { return }
                onToast(message)
                control.toast = nil
            }
    }
}
