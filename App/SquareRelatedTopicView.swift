import SwiftUI

struct SquareRelatedTopicContext {
    let squareScope: UUID
    let reader: any TopicReading
}
private struct SquareRelatedTopicContextKey: EnvironmentKey {
    static let defaultValue: SquareRelatedTopicContext? = nil
}
extension EnvironmentValues {
    var squareRelatedTopic: SquareRelatedTopicContext? {
        get { self[SquareRelatedTopicContextKey.self] }
        set { self[SquareRelatedTopicContextKey.self] = newValue }
    }
}

/// mp-nav r3 (B lane): MP square/detail `goPlay` (index.js:186-193) navigates straight to `pages/play/index?topicId=`.
/// The session root supplies the play page for a topic id; fixtures and other hosts leave it nil and keep the topic push.
private struct SquarePlayDestinationKey: EnvironmentKey {
    static let defaultValue: ((Int) -> AnyView)? = nil
}
extension EnvironmentValues {
    var squarePlayDestination: ((Int) -> AnyView)? {
        get { self[SquarePlayDestinationKey.self] }
        set { self[SquarePlayDestinationKey.self] = newValue }
    }
}

/// Pushes the play page for a selected related topic (試玩), fenced by the same read scopes as the topic push.
@MainActor struct SquarePlayPushModifier: ViewModifier {
    @Binding var selection: SquareRelatedTopicSelection?
    let squareReader: any SquareReading
    @Environment(\.squareRelatedTopic) private var context
    @Environment(\.squarePlayDestination) private var playDestination
    func body(content: Content) -> some View {
        content
            .navigationDestination(item: $selection) { selected in
                destination(selected)
            }
            .onChange(of: context?.reader.scope) { (_: UUID?, _: UUID?) in selection = nil }
    }
    @ViewBuilder private func destination(_ selected: SquareRelatedTopicSelection) -> some View {
        if let context, let playDestination, selected.isCurrent(squareScope: squareReader.scope, topicScope: context.reader.scope) {
            playDestination(selected.route.topicID)
        } else {
            SocialIssueView(error: SocialActionBlock.changed)
        }
    }
}

@MainActor struct SquareRelatedTopicLink: View {
    let post: SquarePost
    let source: SquareContentRoute
    let squareReader: any SquareReading
    var titleKey: LocalizedStringKey = "activity.viewTopic"
    let onSelect: (SquareRelatedTopicSelection) -> Void
    @Environment(\.squareRelatedTopic) private var context
    var body: some View {
        Group {
            if let context, context.squareScope == squareReader.scope,
               let route = SquareRelatedTopicRoute(post: post, source: source) {
                let selected = SquareRelatedTopicSelection(route: route, squareScope: context.squareScope, topicScope: context.reader.scope)
                Button {
                    guard selected.isCurrent(squareScope: squareReader.scope, topicScope: context.reader.scope) else { return }
                    onSelect(selected)
                } label: {
                    Label(titleKey, systemImage: "map")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("square.openRelatedTopic")
            }
        }
    }
}

@MainActor struct SquareRelatedTopicDestination: View {
    let selection: SquareRelatedTopicSelection
    let squareReader: any SquareReading
    let topicReader: any TopicReading
    var body: some View {
        Group {
            if selection.isCurrent(squareScope: squareReader.scope, topicScope: topicReader.scope) {
                // Existing reader enforces topic access. No publishing, purchase,
                // review, self-play or platform provider is injected here.
                TopicDetailView(id: selection.route.topicID, reader: topicReader)
                    .id(selection)
            } else { SocialIssueView(error: SocialActionBlock.changed) }
        }
        .privacySensitive()
    }
}
