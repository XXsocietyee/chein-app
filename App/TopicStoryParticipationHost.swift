import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Mini-program `pages/club/topic-story` + `topic/components/project-join` surface from the topic page.
/// DESIGNED: stations come from the already-read topic chapters; join and answer go through an injected
/// writer (StoryParticipationWriterFactory) that is gated by default, so they explain "Not available yet".
@available(macOS 14.0, *)
@MainActor struct TopicStoryParticipationLink: View {
    let topicID: Int
    let chapters: [TopicChapter]

    var body: some View {
        if !chapters.isEmpty {
            Section {
                NavigationLink {
                    TopicStoryParticipationScreen(topicID: topicID, chapters: chapters)
                } label: {
                    Label(W8Text.t("参与剧情", "Join the story"), systemImage: "book.pages")
                }
                .accessibilityIdentifier("topic.storyParticipation")
            }
        }
    }
}

@available(macOS 14.0, *)
@MainActor private struct TopicStoryParticipationScreen: View {
    let topicID: Int
    let chapters: [TopicChapter]
    @State private var coordinator: StoryParticipationCoordinator?
    @StateObject private var actions = StoryParticipationActionModel(writer: StoryParticipationWriterFactory.makeWriter())

    var body: some View {
        ScrollView {
            if let coordinator {
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    StoryParticipationView(
                        coordinator: coordinator,
                        onJoinTap: { Task { await actions.join(coordinator: coordinator) } },
                        onSubmitNodeAnswer: { nodeID in
                            Task { await actions.submitAnswer(nodeId: nodeID, coordinator: coordinator) }
                        },
                        joinBlocked: actions.joinState == .unavailable,
                        answerFeedback: StoryParticipationFeedbackMapping.answerFeedback(actions.answerStates)
                    )
                    if let message = StoryParticipationFeedbackMapping.joinMessage(actions.joinState) {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("story.joinMessage")
                    }
                }
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.vertical, CYSpacing.lg)
            } else {
                CYLoadingState().frame(minHeight: 120)
            }
        }
        .navigationTitle(W8Text.t("参与剧情", "Join the story"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard coordinator == nil else { return }
            let model = StoryParticipationCoordinator(topicId: topicID, fromSource: "topic")
            let raw: [PlayWireValue] = chapters.enumerated().flatMap { index, chapter in
                chapter.nodes.map { node in
                    PlayWireValue.object([
                        "nodeId": .integer(Int64(node.id)),
                        "chapterNo": .integer(Int64(index + 1)),
                        "chapterTitle": .string(chapter.title),
                        "name": .string(node.name),
                        "description": .string(node.description ?? "")
                    ])
                }
            }
            model.loadStoryNodes(raw)
            coordinator = model
        }
    }
}
