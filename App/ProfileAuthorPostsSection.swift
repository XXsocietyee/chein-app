import SwiftUI

/// P108 author-feed refresh is independent of profile editing and profile-header reads.
@MainActor struct ProfileAuthorPostsSection: View {
    let memberID: Int
    let accountReader: any SocialAccountReading
    let squareReader: any SquareReading
    var actions: SocialActionCoordinator? = nil
    var isCurrent: @MainActor () -> Bool = { true }
    var retainedModel: ProfileAuthorPostsRefreshController? = nil
    var onOpenPost: ((SquarePost) -> Void)? = nil
    /// 11-28 05:35 sweep (P30, MP pull-down only): the host's pull to refresh bumps this; there is no refresh row.
    var refreshTrigger: Int = 0
    @State private var ownedModel = ProfileAuthorPostsRefreshController()
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    @Environment(\.rootSignIn) private var rootSignIn
    private var model: ProfileAuthorPostsRefreshController { retainedModel ?? ownedModel }
    private var context: ProfileAuthorPostsContext {
        .init(memberID: memberID, accountReader: accountReader, squareReader: squareReader)
    }
    var body: some View {
        Section("social.posts") {
            if !isCurrent() { Text("social.changed") }
            else if !context.isSignedIn {
                // mp-states r3 (MP global 登录, cy-empty no-permission): one state with 登录 inside it.
                ContentUnavailableView {
                    Label { Text("social.postsSignIn").accessibilityIdentifier("social.profile.postsSignIn") } icon: {
                        Image(systemName: "person.crop.circle")
                    }
                } actions: {
                    if let signIn = rootSignIn.signedOutAction(fallback: rootTabSwitch) {
                        Button("mp.common.signIn", action: signIn)
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("profile.posts.signIn")
                    }
                }
                .listRowBackground(Color.clear)
            }
            else if !context.isConfigured { SocialIssueView(error: APIError.notConfigured) }
            else {
                if model.context != context || (model.isBusy && !model.pagination.hasLoadedPage) {
                    ProgressView("social.loading")
                } else {
                    if model.activeOperation == .refresh && model.pagination.hasLoadedPage {
                        ProgressView("profile.postsRefresh.refreshing")
                            .accessibilityIdentifier("profile.postsRefresh.refreshing")
                    }
                    if model.retainsPreviousResult {
                        Text("profile.postsRefresh.retained").cyText(.bodyCompact).foregroundStyle(.secondary)
                            .accessibilityIdentifier("profile.postsRefresh.retained")
                    }
                    if let error = model.error {
                        // mp-states r3 (MP cy/profile wxml:276 cy-error 帖文加载失败 · 重试): one state, 重试 inside it.
                        SocialIssueView(error: error, retry: retryAction(), failureTitle: "profile.posts.failed",
                                        identifierPrefix: "profile.postsRefresh.")
                        .disabled(model.isBusy)
                    }
                    ForEach(model.visibleRows(for: context, isCurrent: isCurrent())) { post in
                        if let onOpenPost {
                            Button {
                                guard model.canOpen(post, context: context, isCurrent: isCurrent()) else { return }
                                onOpenPost(post)
                            } label: { SquarePostContent(post: post, showImages: false) }
                            .accessibilityIdentifier("profile.postsRefresh.post.\(post.id)")
                        } else {
                            NavigationLink {
                                if model.canOpen(post, context: context, isCurrent: isCurrent()) {
                                    SquareDetailView(id: post.id, contentGeneration: post.generation, reader: squareReader, accountReader: accountReader, actions: actions)
                                } else { Text("social.changed") }
                            } label: { SquarePostContent(post: post, showImages: false) }
                            .accessibilityIdentifier("profile.postsRefresh.post.\(post.id)")
                        }
                        NativeMediaGalleryEntry(sources: post.images, scope: squareReader.scope, titleKey: "media.destination.squareImages")
                    }
                    if model.pagination.hasLoadedPage && model.pagination.items.isEmpty {
                        // MP cy/profile 推文 `cy-empty`: 还没有帖文 (same copy as the club posts tab); system empty view (P30).
                        ContentUnavailableView {
                            Label {
                                Text("club.tab.feed.empty").accessibilityIdentifier("profile.postsRefresh.empty")
                            } icon: {
                                Image(systemName: "text.bubble")
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                    if model.pagination.continuationInvalid {
                        Text("square.invalidCursor").accessibilityIdentifier("profile.postsRefresh.invalidCursor")
                    }
                    if model.activeOperation == .more { ProgressView("social.loading") }
                    else if model.pagination.hasLoadedPage && model.pagination.hasMore && model.error == nil {
                        Button("square.loadMore") { Task { await model.loadMore(memberID: memberID, accountReader: accountReader, squareReader: squareReader, isCurrent: isCurrent) } }
                            .disabled(model.isBusy)
                            .accessibilityIdentifier("profile.postsRefresh.more")
                    }
                }
            }
        }
        .task(id: context) { await model.activate(memberID: memberID, accountReader: accountReader, squareReader: squareReader, isCurrent: isCurrent) }
        .onDisappear { model.suspend() }
        .onChange(of: refreshTrigger) { _, _ in
            guard !model.isBusy else { return }
            Task { await refresh() }
        }
    }
    private func retryAction() -> (() -> Void)? {
        guard model.failedOperation != nil else { return nil }
        let model = model, memberID = memberID, accountReader = accountReader, squareReader = squareReader, isCurrent = isCurrent
        return { Task { await model.retry(memberID: memberID, accountReader: accountReader, squareReader: squareReader, isCurrent: isCurrent) } }
    }
    private func refresh() async {
        await model.refresh(memberID: memberID, accountReader: accountReader, squareReader: squareReader, isCurrent: isCurrent)
    }
}
