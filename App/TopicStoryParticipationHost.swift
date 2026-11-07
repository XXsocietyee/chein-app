import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Mini-program `pages/club/topic-story` + `topic/components/project-join` surface from the topic page.
/// DESIGNED: stations come from the already-read topic chapters; join and answer submission have no approved
/// remote path here, so those actions explain that instead of posting.
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
                        .frame(minHeight: 44)
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
    @State private var joinBlocked = false
    @State private var answerFeedback: [Int: StoryAnswerFeedback] = [:]

    var body: some View {
        ScrollView {
            if let coordinator {
                StoryParticipationView(
                    coordinator: coordinator,
                    onJoinTap: { joinBlocked = true },
                    onSubmitNodeAnswer: { nodeID in
                        // Validate locally; a valid answer is never sent (no approved write path), so it is only "blocked".
                        do {
                            _ = try coordinator.buildAnswerRequest(nodeId: nodeID)
                            answerFeedback[nodeID] = .blocked
                        } catch {
                            answerFeedback[nodeID] = .invalid(error.localizedDescription)
                        }
                    },
                    joinBlocked: joinBlocked,
                    answerFeedback: answerFeedback
                )
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.vertical, CYSpacing.lg)
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .background(CYColor.bgPage.ignoresSafeArea())
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
