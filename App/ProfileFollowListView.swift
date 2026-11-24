import SwiftUI

@MainActor struct ProfileFollowListAccountEntry: View {
    @ObservedObject var session: AppSession
    var body: some View {
        NavigationLink {
            ProfileFollowListView(flow: session.makeProfileFollowListFlow(), squareReader: session.squareReader,
                actions: session.socialActionCoordinator).id(session.contentDetailRevision)
        } label: {
            Label { Text("followList.title", tableName: "ProfileFollowList") } icon: { Image(systemName: "person.2") }
        }.accessibilityIdentifier("profile.followList.entry")
    }
}

@MainActor struct ProfileFollowListView: View {
    @Environment(\.themeDomain) private var domain
    @Environment(\.locale) private var locale
    @State private var flow: ProfileFollowListFlow
    let squareReader: any SquareReading
    let actions: SocialActionCoordinator?
    @Environment(\.scenePhase) private var scenePhase
    init(flow: ProfileFollowListFlow, squareReader: any SquareReading, actions: SocialActionCoordinator? = nil) {
        _flow = State(initialValue: flow); self.squareReader = squareReader; self.actions = actions
    }
    var body: some View {
        ScrollViewReader { proxy in
            List {
                if !flow.isConfigured {
                    CYEmptyState(systemImage: "person.2", "followList.unavailable", tableName: "ProfileFollowList",
                                 messageIdentifier: "profile.followList.unavailable")
                } else {
                    Picker(selection: Binding(get: { flow.kind }, set: { flow.selectKind($0) })) {
                        Text("followList.following", tableName: "ProfileFollowList").tag(ProfileFollowListKind.following)
                        Text("followList.followers", tableName: "ProfileFollowList").tag(ProfileFollowListKind.followers)
                    } label: { Text("followList.title", tableName: "ProfileFollowList") }
                    .pickerStyle(.segmented).padding(.vertical, Theme.Space.s1).accessibilityIdentifier("profile.followList.kind")
                    Text("followList.notFriends", tableName: "ProfileFollowList").cyText(.meta).foregroundStyle(Theme.Color.textSecondary(in: domain))
                    if let error = flow.error {
                        SocialIssueView(error: error, retry: flow.canRetry ? { flow.retry() } : nil)
                    }
                    ForEach(flow.visibleRows) { member in
                        Button { flow.open(member) } label: {
                            HStack(spacing: Theme.Space.s3) {
                                Group {
                                    if let avatar = member.avatar { SquareImage(source: avatar).frame(width: 48, height: 48).clipShape(Circle()) }
                                    else { E3Avatar(seed: SocialText.nonempty(member.nickname) ?? String(member.id), size: 48) }
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    if let name = SocialText.nonempty(member.nickname) { Text(verbatim: name).cyText(.bodyMedium).fixedSize(horizontal: false, vertical: true) }
                                    else { Text("square.unknownAuthor").cyText(.bodyMedium).fixedSize(horizontal: false, vertical: true) }
                                }
                                Spacer(minLength: Theme.Space.s2)
                                // State pill (the row itself opens the profile): outlined + check when followed, never colour alone.
                                CYStatusChip(verbatim: member.isFollow ? (flow.kind == .followers ? locale.pick("互相关注", "Mutual") : locale.pick("已关注", "Following")) : locale.pick("未关注", "Not following"),
                                             tone: member.isFollow ? .success : .neutral,
                                             systemImage: member.isFollow ? "checkmark" : nil)
                            }.frame(minHeight: 56).foregroundStyle(CYColor.textPrimary)
                        }.disabled(flow.loading || flow.error != nil)
                        .id(member.id)
                        .listRowInsets(EdgeInsets(top: Theme.Space.s2, leading: Theme.Space.pageX, bottom: Theme.Space.s2, trailing: Theme.Space.pageX))
                        .listRowBackground(Theme.Color.bgPage(in: domain))
                        .accessibilityIdentifier("profile.followList.member.\(member.id)")
                    }
                    if flow.loading { CYLoadingStateView(rows: 1).accessibilityLabel(Text("social.loading")) }
                    else if flow.hasLoaded && flow.visibleRows.isEmpty && flow.error == nil {
                        CYEmptyState(systemImage: "person.2", flow.kind == .following ? "followList.emptyFollowing" : "followList.emptyFollowers",
                                     tableName: "ProfileFollowList", messageIdentifier: "profile.followList.empty")
                    }
                    if flow.hasMore && !flow.loading && flow.error == nil {
                        CYPillButton("square.loadMore", style: .secondary) { flow.more() }
                            .accessibilityIdentifier("profile.followList.more")
                    }
                }
            }
            .cyGroupedSurface()
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.Color.bgPage(in: domain))
            .navigationTitle(Text("followList.title", tableName: "ProfileFollowList")).navigationBarTitleDisplayMode(.inline)
            .privacySensitive().accessibilityIdentifier("profile.followList")
            .refreshable { await flow.refresh() }
            .onAppear { flow.appear(foreground: scenePhase == .active) }
            .onDisappear { flow.suspend() }
            .onChange(of: scenePhase) { _, phase in flow.setForeground(phase == .active) }
            .onChange(of: flow.returnAnchorMemberID) { _, memberID in
                guard let memberID else { return }
                proxy.scrollTo(memberID, anchor: .center)
                flow.didRestoreReturnAnchor(memberID)
            }
            .background {
                if let selection = flow.selection {
                    Color.clear.navigationDestination(item: selectionBinding(selection)) { selected in
                        ProfileFollowListMemberDestination(flow: flow, selected: selected,
                            squareReader: squareReader, actions: actions)
                    }.id(selection.id)
                }
            }
        }
        .themeDomain(domain)
        .cyDomainScreen(.player)
    }
    private func selectionBinding(_ selected: ProfileFollowListSelection) -> Binding<ProfileFollowListSelection?> {
        Binding(get: { flow.selection == selected ? selected : nil }, set: { value in
            if value == nil { flow.close(selected.id) }
        })
    }
}

/// Keep this reader stable while its profile is covered by the existing review/editor.
@MainActor private struct ProfileFollowListMemberDestination: View {
    let flow: ProfileFollowListFlow
    let selected: ProfileFollowListSelection
    let squareReader: any SquareReading
    let actions: SocialActionCoordinator?
    @State private var reader: ProfilePublicInfoReader?
    var body: some View {
        Group {
            if !flow.owns(selected) { CYEmptyState(systemImage: "arrow.clockwise", "social.changed") }
            else if let reader {
                ProfilePublicInfoHost(reader: reader) { currentReader in
                    SocialPublicProfileView(memberID: selected.memberID, reader: currentReader, squareReader: squareReader,
                        actions: actions, showsStartChat: false, isCurrent: { flow.owns(selected) && currentReader.isCurrent })
                }
            } else { CYLoadingStateView(rows: 1).accessibilityLabel(Text("social.loading")) }
        }.onAppear {
            if reader == nil { reader = flow.memberReader(for: selected) }
        }
    }
}

/// Pure display for the existing pagination button; the original flow owns every read.
private struct ProfileFollowListMoreStyle: ViewModifier {
    @Environment(\.themeDomain) private var domain
    @ViewBuilder func body(content: Content) -> some View {
        content.buttonStyle(.bordered)
            .cyText(.button)
            .tint(Theme.Color.accent(in: domain))
    }
}
