import SwiftUI

/// CLB-topic-story-05 (MP `pages/club/topic-story/index.js:157-162, 271-285`): a merchant opens the story from the
/// topic workbench with `scope` and no `clubId`. The MP then reads the answer from
/// `POST /api/topic/host-node-answer` `{topicId, nodeId, scope}` (JSON body) instead of the club endpoint, and the
/// server decides whether this host may see it. The club entry keeps its own `.nodeAnswer` read.
struct ClubStoryHostAnswerContext {
    /// The link's `scope`; nil on every club entry.
    var scope: String? = nil
    var load: (@MainActor (_ topicID: Int, _ nodeID: Int, _ scope: String) async -> ClubHostNodeAnswer?)? = nil
    var isAvailable: Bool { scope != nil && load != nil }
}
private struct ClubStoryHostAnswerKey: EnvironmentKey {
    static let defaultValue = ClubStoryHostAnswerContext()
}
extension EnvironmentValues {
    var clubStoryHostAnswer: ClubStoryHostAnswerContext {
        get { self[ClubStoryHostAnswerKey.self] }
        set { self[ClubStoryHostAnswerKey.self] = newValue }
    }
}

@MainActor extension AppSession {
    /// Host entry only: an empty or missing `scope` keeps the club path (the MP posts the club endpoint when it has
    /// a clubId, and the presentation refuses a story with neither).
    func clubStoryHostAnswerContext(scope raw: String?) -> ClubStoryHostAnswerContext {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let scope = trimmed, !scope.isEmpty else { return .init() }
        return .init(scope: scope, load: { [weak self] topicID, nodeID, scope in
            guard let self, topicID > 0, nodeID > 0,
                  let token = self.token, AuthRequestBuilder.isValidToken(token),
                  let configuration = self.regionalConfiguration?.apiConfiguration,
                  self.regionalConfiguration?.showsRoute("/api/topic/host-node-answer") == true else { return nil }
            let stamp = self.sessionRevision
            let client = ClubRemainingGapClient(configuration: configuration, transport: self.runtimeHTTPTransport)
            do {
                let answer = try await client.fetchHostNodeAnswer(topicID: topicID, nodeID: nodeID, scope: scope, token: token)
                // A sign-out or account switch while the request was in flight drops the answer.
                guard self.sessionRevision == stamp, self.token == token else { return nil }
                return answer
            } catch {
                if error as? APIError == .unauthorized {
                    self.expireIfMatching(error: error, stamp: stamp, credential: token)
                }
                return nil
            }
        })
    }
}

/// The 答案 sheet body for the host entry: same rows and club-only notice as `ClubNodeAnswerContent`.
struct ClubStoryHostAnswerSheetContent: View {
    let topicID: Int
    let nodeID: Int
    let context: ClubStoryHostAnswerContext
    private enum Phase: Equatable { case loading, failed, loaded(ClubHostNodeAnswer) }
    @State private var phase: Phase = .loading
    var body: some View {
        List {
            switch phase {
            case .loading:
                HStack(spacing: 8) { ProgressView(); Text("club.story.answer.loading").foregroundStyle(.secondary) }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("club.story.hostAnswer.loading")
            case .failed:
                ContentUnavailableView {
                    Label {
                        Text("club.story.answer.failed").accessibilityIdentifier("club.story.hostAnswer.failed")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                } actions: {
                    Button("action.retry") { Task { await load() } }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("club.story.hostAnswer.retry")
                }
            case .loaded(let answer):
                ClubNodeAnswerContent(value: .object([
                    "question": answer.question.map(ClubGovernanceValue.string) ?? .null,
                    "answerReveal": answer.answerReveal.map(ClubGovernanceValue.string) ?? .null,
                ]))
            }
        }
        .accessibilityIdentifier("club.story.hostAnswer")
        .task(id: "\(topicID).\(nodeID)") { await load() }
    }
    private func load() async {
        guard let scope = context.scope, let loader = context.load else { phase = .failed; return }
        phase = .loading
        if let answer = await loader(topicID, nodeID, scope) { phase = .loaded(answer) } else { phase = .failed }
    }
}

/// One selected host answer; identity is per tap so a second tap re-reads.
struct ClubStoryHostAnswerTarget: Identifiable, Hashable {
    let id = UUID()
    let topicID: Int
    let nodeID: Int
    let name: String?
}
