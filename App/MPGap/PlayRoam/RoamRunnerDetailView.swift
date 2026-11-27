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
        // MP roam-runner (原型 otherSheet), in MP order: head (avatar · nickname · 正在附近漫游 · since) → 地盘 / 探店 / 在走
        // → TA 点亮的店 → 打个招呼 / 看 TA 的漫游. Nothing else is shown about another walker.
        Form {
            Section {
                HStack(spacing: CYSpacing.md) {
                    ZStack {
                        Circle().fill(CYColor.brandSoft)
                        Text(verbatim: runner.initial).font(.headline).foregroundStyle(CYColor.textPrimary)
                        if let avatar = runner.avatarURL {
                            BoundedMediaThumbnail(url: avatar) { Color.clear }.clipShape(Circle())
                        }
                    }
                    .frame(width: 52, height: 52)
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: runner.nickname).font(.headline)
                        Group {
                            if runner.sinceLabel.isEmpty {
                                Text("roamTools.runner.nearby")
                            } else {
                                Text("roamTools.runner.nearbySince \(runner.sinceLabel)")
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                if runner.explorePercent != nil || runner.shopCount != nil || !runner.elapsedLabel.isEmpty {
                    HStack(alignment: .top) {
                        if let explore = runner.explorePercent {
                            statCell(Text(verbatim: "\(explore)%"), label: "roamTools.runner.stat.territory")
                        }
                        if let shops = runner.shopCount {
                            statCell(Text(shops, format: .number), label: "roamTools.runner.stat.shops")
                        }
                        if !runner.elapsedLabel.isEmpty {
                            statCell(Text(verbatim: runner.elapsedLabel), label: "roamTools.runner.stat.walking")
                        }
                    }
                    .accessibilityIdentifier("roamTools.runner.stats")
                }
            }
            if !runner.shopPhotos.isEmpty {
                Section("roamTools.runner.shops") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: CYSpacing.sm) {
                            ForEach(Array(runner.shopPhotos.enumerated()), id: \.offset) { _, shop in
                                BoundedMediaThumbnail(url: shop.image) {
                                    Image(systemName: "photo").foregroundStyle(.secondary)
                                }
                                .frame(width: 88, height: 88)
                                .background(.background.secondary, in: .rect(cornerRadius: CYRadius.inner))
                                .clipShape(.rect(cornerRadius: CYRadius.inner))
                                .accessibilityElement()
                                .accessibilityLabel(Text(verbatim: shop.name))
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.md, bottom: CYSpacing.sm, trailing: CYSpacing.md))
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

    private func statCell(_ value: Text, label: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            value.font(.title3.bold()).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
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
