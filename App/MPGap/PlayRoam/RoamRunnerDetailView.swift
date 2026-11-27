import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// ROAM-r11-4: what a nearby runner row can open (MP `pages/roam/index.js:2905-2933`). Nil in fixtures: rows stay plain.
struct RoamRunnerActions {
    let coordinator: SocialActionCoordinator
    /// 看 TA 的漫游 = TA 的主页 (MP `runnerOpenProfile` → pages/userinfo/userinfo?userId=).
    let profile: @MainActor (Int) -> AnyView
    /// IM conversation for a `conversationId` (MP `runnerSayHi` → subpackageB/pages/im/chat/index).
    let conversation: @MainActor (Int) -> AnyView
}

private struct RoamRunnerActionsKey: EnvironmentKey {
    static let defaultValue: RoamRunnerActions? = nil
}

extension EnvironmentValues {
    var roamRunnerActions: RoamRunnerActions? {
        get { self[RoamRunnerActionsKey.self] }
        set { self[RoamRunnerActionsKey.self] = newValue }
    }
}

private struct RoamRunnerConversation: Identifiable, Hashable { let id: Int }

/// MP roam-runner scene: the runner, 打个招呼 (a real `/api/im/start`, then the chat) and 看 TA 的漫游.
@MainActor struct RoamRunnerDetailView: View {
    let runner: RoamNearbyRunner
    let actions: RoamRunnerActions
    @State private var conversation: RoamRunnerConversation?

    var body: some View {
        Form {
            Section {
                LabeledContent("roamTools.runner.name") { Text(verbatim: runner.nickname) }
                if !runner.elapsedLabel.isEmpty {
                    LabeledContent("roamTools.runner.walking") { Text(verbatim: runner.elapsedLabel).monospacedDigit() }
                }
                if let explore = runner.explorePercent {
                    Text("roamTools.runners.explore \(explore)").monospacedDigit()
                }
            }
            Section {
                SocialProfileInlineStartChatButton(memberID: runner.id, coordinator: actions.coordinator,
                                                   onOpen: { conversation = RoamRunnerConversation(id: $0) }) { text, icon in
                    if icon == nil { text } else { Label("roamTools.runners.greet", systemImage: "hand.wave") }
                }
                NavigationLink {
                    actions.profile(runner.id)
                } label: {
                    Label("roamTools.runner.profile", systemImage: "person.crop.circle")
                }
                .accessibilityIdentifier("roamTools.runner.profile")
            }
        }
        .navigationTitle(Text(verbatim: runner.nickname))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $conversation) { target in
            actions.conversation(target.id)
        }
    }
}

extension AppSession {
    /// ROAM-r11-4: the profile and chat screens a nearby runner row opens.
    var roamRunnerActions: RoamRunnerActions {
        RoamRunnerActions(
            coordinator: socialActionCoordinator,
            profile: { [weak self] id in
                guard let self else { return AnyView(EmptyView()) }
                return AnyView(MPReviewedPageScreen(page: "pages/userinfo/userinfo", query: ["userId": String(id)]).environmentObject(self))
            },
            conversation: { [weak self] id in self?.socialConversationDestination(id) ?? AnyView(EmptyView()) })
    }
}
