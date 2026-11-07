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
    @State private var notice: String?

    var body: some View {
        ScrollView {
            if let coordinator {
                StoryParticipationView(
                    coordinator: coordinator,
                    onJoinTap: { notice = W8Text.t("暂时无法在此申请加入，请在城瘾小程序或俱乐部页面中操作。", "Joining isn't available here yet. Use the club page.") },
                    onSubmitNodeAnswer: { nodeID in
                        do { _ = try coordinator.buildAnswerRequest(nodeId: nodeID) }
                        catch { notice = error.localizedDescription; return }
                        notice = W8Text.t("答案暂时无法在此提交。", "Answers can't be submitted from here yet.")
                    }
                )
                .padding()
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 120)
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
        .alert(notice ?? "", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button(W8Text.t("好", "OK"), role: .cancel) {}
        }
    }
}
