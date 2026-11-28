import SwiftUI

@MainActor struct SquareDetailView: View {
    let id: Int
    var contentGeneration: SquareContentGeneration = .legacySquare
    let reader: any SquareReading
    var accountReader: (any SocialAccountReading)? = nil
    var actions: SocialActionCoordinator? = nil
    var governanceContext: SquareGovernanceContext? = nil
    var workspace: SquareWorkspaceCoordinator? = nil
    @Environment(\.squareReportContext) private var reportContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.squareRelatedTopic) private var relatedTopicContext
    @Environment(\.squarePlayDestination) private var playDestination
    @Environment(\.squareDeletion) private var deletion
    @Environment(\.squareShareLink) private var shareLink
    @Environment(\.squareAuthorFollowState) private var followState
    @Environment(\.squareViewerAvatar) private var viewerAvatar
    @Environment(\.analyticsEventClient) private var analytics
    @Environment(\.ugcSafetyContext) private var ugcSafety
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private struct ShareRoute: Identifiable { let id = UUID(); let payload: CYSquareSharePayload; let url: URL }
    @State private var showsAuthorProfile = false
    @State private var relatedTopic: SquareRelatedTopicSelection?
    @State private var playTopic: SquareRelatedTopicSelection?
    @State private var reportTarget: ReportRoute?
    private struct ReportRoute: Identifiable { let id = UUID(); let target: SquareReportTarget }
    @State private var showsWorkspaceEdit = false
    @State private var blockTarget: BlockTarget?
    private struct BlockTarget: Identifiable { let id = UUID(); let memberID: Int; let authorName: String? }
    private struct EditorRoute: Identifiable { let id = UUID(); let purpose: SocialEditorPurpose; let target: SocialActionTarget; let text: String; var enabled = true }
    @State private var editor: EditorRoute?
    @State private var followWriteMember: Int?
    @State private var cloudProfile: SquareDetailProfileRoute?
    @State private var post: SquarePost?
    @State private var detailIssue: Error?
    @State private var commentIssue: Error?
    @State private var comments = SquareCommentPagination()
    @State private var detailLoading = false
    @State private var commentsLoading = false
    @State private var generation = 0
    @State private var loadedKey: Key?
    /// MP post-actions 删除 for a legacy square post (index.js:775-805 `/api/creativesquare/delete`, danger confirm first).
    @State private var legacyDeleteConfirm = false
    @State private var legacyDeleting = false
    @State private var legacyDeleted = false
    @State private var legacyDeleteFailed = false
    /// MP A-04 `deleteComment` on a legacy comment: danger confirm (club.comment.delete), then `/api/comment/delete`.
    @State private var legacyCommentTarget: SquareComment?
    @State private var legacyCommentDeleting = false
    @State private var legacyCommentDeleteFailed = false
    /// fix-1128b-social #1 (MP square/detail index.js:493-540): v1 like / bookmark / comment-like toggle at once and the
    /// shown state is the server's re-read, not a local guess.
    @State private var instantBusy = false
    @State private var instantMessage: String?
    @State private var instantOwner = UUID()
    @QuestifyReduceMotion private var reduceMotion
    private struct Key: Hashable { let id: Int; let generation: SquareContentGeneration; let scope: UUID; let configured: Bool }
    private var key: Key { Key(id: id, generation: contentGeneration, scope: reader.scope, configured: reader.isConfigured) }
    var body: some View {
        List {
            if let governanceContext { SquareGovernanceEntryView(context: governanceContext) }
            if let deletion { SquareDeletionStatusView(coordinator: deletion) { Task { await verifyDeletion() } } }
            if reader.showsOfflineExampleNote { Text("square.offlineExample").font(.caption).foregroundStyle(.secondary) }
            if !reader.isConfigured { SquareIssueView(error: APIError.notConfigured) }
            else if loadedKey != key { ProgressView { Text("mpr3.square.detail.loading") }.frame(maxWidth: .infinity) }
            else {
                // P10: the loading state says what loads (MP shows the detail skeleton here).
                if detailLoading { ProgressView { Text("mpr3.square.detail.loading") }.frame(maxWidth: .infinity) }
                if legacyDeleted {
                    // MP deleteDone 回执: the post is gone and the page falls to 这条帖文暂不可用 with a way back.
                    Label("square.xcx.delete.postDone", systemImage: "checkmark.circle").foregroundStyle(.secondary)
                        .accessibilityIdentifier("square.delete.postDone")
                }
                if let detailIssue {
                    // C-S3 (MP square/detail index.wxml:12-27): the cause decides the title; a way back is always there.
                    if post == nil {
                        SquareDetailIssueView(error: detailIssue, retry: { Task { await reload() } }, back: { dismiss() })
                    } else { SquareIssueView(error: detailIssue) { Task { await reload() } } }
                }
                if let post {
                    UGCBlockedFilterContainer(memberID: post.memberID, authorName: post.nickname) {
                        Section {
                            // MP post-body order: text, then the play card, then the photo strip (index.wxml:56-99).
                            SquarePostContent(post: post, showImages: false, mediaScope: reader.scope, showsCounts: actions?.identity.accountID == nil,
                                              avatarMenuItems: avatarMenuItems(post), onAvatarPick: { pickAvatarItem($0, post: post) },
                                              onFollow: inlineFollow(post)).accessibilityIdentifier("square.detailPost")
                            let cardFacts = SquarePostCardFacts(post)
                            if cardFacts.isCompletionShare {
                                // MP cy-completion-share-card replaces the play card and the photo strip (index.wxml:57-92).
                                SquareDetailCompletionCard(post: post, cover: cardFacts.playCover, showsTitleRow: !post.strava.showsActivity, scope: reader.scope)
                                SquareRelatedTopicLink(post: post, source: .init(id: id, generation: contentGeneration), squareReader: reader) { relatedTopic = $0 }
                            } else if post.isTopicTemplate || post.referenceTitle != nil {
                                // C-S1: MP feed-play-card on the detail page (看看模板 / 试玩).
                                SquareDetailPlayCard(post: post, source: .init(id: id, generation: contentGeneration), reader: reader) { openPlay($0) }
                            } else {
                                SquareRelatedTopicLink(post: post, source: .init(id: id, generation: contentGeneration), squareReader: reader) { relatedTopic = $0 }
                            }
                            if !cardFacts.isCompletionShare && !post.images.isEmpty {
                                NativeMediaGalleryEntry(sources: post.images, scope: reader.scope, titleKey: "media.destination.squareImages")
                            }
                            if let routeImage = post.routeImage {
                                NativeMediaGalleryEntry(sources: [routeImage], scope: reader.scope, titleKey: "media.destination.squareImages")
                            }
                            if !post.videos.isEmpty { SquarePostVideoList(videos: post.videos) }
                            if !SquarePostCardFacts(post).isCompletionShare || post.strava.showsActivity {
                                SquareDetailMedalPill(gold: post.medalGold, silver: post.medalSilver, bronze: post.medalBronze)
                            }
                            // Mini `components/route-map`: live route only with a provider; the post's own snapshot is already in the gallery.
                            if let topicID = post.topicID, topicID > 0 { CYSquareRouteMapCard(topicID: topicID) }
                            if let actions, actions.identity.accountID != nil {
                                postActions(post, actions: actions)
                            }
                            if let instantMessage {
                                Label(LocalizedStringKey(instantMessage), systemImage: "exclamationmark.circle")
                                    .font(.footnote).foregroundStyle(CYColor.warningText)
                                    .accessibilityIdentifier("square.detail.instantMessage")
                            }
                            // The MP detail has no 我的广场 list: the author deletes this post from the ⋯ menu (post-actions 删除).
                            if legacyDeleteFailed {
                                Label("square.xcx.delete.failed", systemImage: "exclamationmark.triangle").foregroundStyle(CYColor.dangerText)
                                    .accessibilityIdentifier("square.delete.postFailed")
                            }
                            // Round 4 flow (MP square/detail goUserInfoClcik): the author's page opens from the avatar menu
                            // (访问个人主页); the MP has no separate 查看作者主页 row.
                        }
                    } blockedPlaceholder: {
                        Section {
                            UGCBlockedNoticeBanner(
                                messageKey: "ugc.safety.blockedBanner.hidden",
                                memberID: post.memberID,
                                authorName: post.nickname
                            )
                        }
                    }
                }
                // Detail failure never renders orphan comments without their post context.
                if let post, !(ugcSafety?.isBlocked(memberID: post.memberID, authorName: post.nickname) ?? false) {
                    Section("square.comments") {
                        if legacyCommentDeleteFailed {
                            // MP toast 删除失败，请重试 stays visible in the thread it belongs to.
                            Label("square.xcx.delete.failed", systemImage: "exclamationmark.triangle").foregroundStyle(CYColor.dangerText)
                                .accessibilityIdentifier("square.delete.legacyCommentFailed")
                        }
                        if let commentIssue {
                            // Round 4 copy (MP square/detail wxml): the comment section failure reads 评论加载失败 / 重试.
                            SquareIssueView(error: commentIssue, retry: { Task { await loadComments(operation: generation, captured: key) } },
                                            title: comments.items.isEmpty ? "fixr3.square.commentsFailed" : "fixr3.square.moreCommentsFailed")
                        }
                        ForEach(SquareComment.threaded(comments.items)) { comment in
                            UGCBlockedFilterContainer(memberID: comment.memberID, authorName: comment.nickname) {
                                commentRow(comment).accessibilityIdentifier("square.comment.\(comment.id)")
                            }
                        }
                        if commentsLoading {
                            // MP 正在加载更多评论… under the list; the first page says what loads too (P10).
                            ProgressView { Text(comments.items.isEmpty ? LocalizedStringKey("club.discussion.loading") : LocalizedStringKey("mpr3.square.detail.loadingMoreComments")) }
                                .frame(maxWidth: .infinity)
                        }
                        else if comments.items.isEmpty && commentIssue == nil {
                            Text(LocalizedStringKey(SquareDetailPageModel.emptyCommentsTitleKey))
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("square.noComments")
                        }
                        if !commentsLoading && comments.hasMore && commentIssue == nil {
                            // C-S9 (MP onReachBottom): reaching the end loads the next page; the button stays for VoiceOver.
                            Button { Task { await loadComments(operation: generation, captured: key) } } label: { Text("square.moreComments").frame(maxWidth: .infinity) }
                                .buttonStyle(.borderless)
                                .accessibilityIdentifier("square.moreComments")
                                .onAppear { Task { await loadComments(operation: generation, captured: key) } }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .cyPushedChrome(domain: .player)
        .appNavigationTitle("square.detail").navigationBarTitleDisplayMode(.inline)
        .cyHideTabBar()
        .toolbar {
            // Mini-program `ph-more`: edit, delete and report live in one overflow menu.
            if let post, let actions, actions.identity.accountID != nil, loadedKey == key {
                ToolbarItem(placement: .topBarTrailing) { postMenu(post, actions: actions) }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let post, let actions, actions.identity.accountID != nil, loadedKey == key {
                // Source sticky bar "留下你的评论"; opens the existing reviewed comment editor.
                // r10 N-25: system bar material + divider instead of the custom CYFooterBar (square/detail/index.wxml).
                // MP david_npl: the viewer's avatar sits left of the comment field (default avatar when none is known).
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 12) {
                        SquareAuthorAvatar(source: commentBarAvatar(actions), size: 32)
                            .accessibilityHidden(true)
                        Button { editor = .init(purpose: .comment, target: .post(post.id), text: "") } label: {
                            Label("square.xcx.commentPlaceholder", systemImage: "text.bubble")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled(!post.viewerCanComment)
                        .accessibilityIdentifier("square.commentBar")
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(.bar)
            }
        }
        .navigationDestination(item: $cloudProfile) { member in
            if let accountReader {
                SocialPublicProfileView(memberID: member.id, reader: accountReader, squareReader: reader, actions: actions)
                    .cyPushedChrome(domain: .player)
            }
        }
        .navigationDestination(item: $relatedTopic) { selected in
            if let context = relatedTopicContext {
                SquareRelatedTopicDestination(selection: selected, squareReader: reader, topicReader: context.reader)
            } else { SocialIssueView(error: SocialActionBlock.changed) }
        }
        .modifier(SquarePlayPushModifier(selection: $playTopic, squareReader: reader))
        .onChange(of: key) { _, _ in relatedTopic = nil }
        .onChange(of: key) { _, _ in playTopic = nil }
        .onChange(of: relatedTopicContext?.reader.scope) { _, _ in relatedTopic = nil }
        .cySheet(item: $editor, onDismiss: { applyFollowReceipt(); refreshAfterEditor() }) { item in Group {
            if let actions { NavigationStack { SocialActionEditorView(purpose: item.purpose, target: item.target, coordinator: actions, initialText: item.text, contentGeneration: contentGeneration, initialEnabled: item.enabled) }.id(actions.identity) }
        }.cySheet(detents: [.large]) }
        .navigationDestination(isPresented: $showsAuthorProfile) {
            if let accountReader, let post, post.memberID > 0 {
                SocialPublicProfileView(memberID: post.memberID, reader: accountReader, squareReader: reader, actions: actions)
                    .cyPushedChrome(domain: .player)
            }
        }
        .onChange(of: key) { _, _ in showsAuthorProfile = false; blockTarget = nil }
        .alert(
            Text(verbatim: String(localized: LocalizedStringResource("ugc.safety.block.confirmTitle", table: "UGCSafety", locale: locale))),
            isPresented: Binding(get: { blockTarget != nil }, set: { if !$0 { blockTarget = nil } }),
            presenting: blockTarget
        ) { target in
            Button(role: .destructive) {
                let targetToBlock = target
                blockTarget = nil
                Task {
                    try? await ugcSafety?.blockUser(memberID: targetToBlock.memberID, authorName: targetToBlock.authorName)
                }
            } label: {
                Text(verbatim: String(localized: LocalizedStringResource("ugc.safety.block.confirmButton", table: "UGCSafety", locale: locale)))
            }
            Button(role: .cancel) { blockTarget = nil } label: {
                Text(verbatim: String(localized: LocalizedStringResource("ugc.safety.block.cancel", table: "UGCSafety", locale: locale)))
            }
        } message: { _ in
            Text(verbatim: String(localized: LocalizedStringResource("ugc.safety.block.confirmMessage", table: "UGCSafety", locale: locale)))
        }
        .cySheet(item: $reportTarget) { item in
            NavigationStack { SquareReportView(target: item.target, context: reportContext) }
                .cySheet(detents: [.large])
        }
        .cySheet(isPresented: $showsWorkspaceEdit) { Group {
            if let workspace { NavigationStack { SquareWorkspaceView(coordinator: workspace, initialPostID: id, initialLane: contentGeneration == .communityV1 ? .communityV1 : .legacy) }.id(workspace.session) }
        }.cySheet(detents: [.large]) }
        .cySheet(item: deletionBinding) { item in Group {
            if let deletion {
                SquareDeletionConfirmView(target: item.target, excerpt: SquareDeletionConfirmView.excerpt(post?.contents), coordinator: deletion)
            }
        }.presentationDetents([.medium, .large]) }
        .onChange(of: deletion?.phase) { _, phase in
            // A confirmed comment deletion refreshes the thread; a deleted post leaves no stale body on screen.
            if case .done(let target)? = phase { if case .post = target { post = nil; comments = SquareCommentPagination() } else { Task { await reload() } } }
        }
        .onChange(of: key) { _, _ in deletion?.retire(); legacyDeleteConfirm = false; legacyCommentTarget = nil; legacyCommentDeleteFailed = false }
        .confirmationDialog(Text("square.xcx.delete.commentTitle"), isPresented: Binding(get: { legacyCommentTarget != nil }, set: { if !$0 { legacyCommentTarget = nil } }), titleVisibility: .visible, presenting: legacyCommentTarget) { comment in
            Button("square.xcx.delete.commentConfirm", role: .destructive) {
                let commentID = comment.id
                legacyCommentTarget = nil
                Task { await deleteLegacyComment(commentID) }
            }
        } message: { _ in
            Text("square.xcx.delete.commentIrreversible")
        }
        .confirmationDialog(Text("square.xcx.delete.postConfirm"), isPresented: $legacyDeleteConfirm, titleVisibility: .visible) {
            Button("square.xcx.delete.postConfirm", role: .destructive) {
                if let postID = post?.id { Task { await deleteLegacyPost(postID) } }
            }
        } message: {
            Text("square.xcx.delete.postIrreversible")
        }
        .task(id: key) { await reload() }
        .refreshable { await reload() }
        .onDisappear { generation += 1; detailLoading = false; commentsLoading = false }
        .environment(\.squareCloudFeed, detailCloudFeed)
        .accessibilityIdentifier("square.detail")
    }
    private var detailCloudFeed: SquareCloudFeedContext {
        SquareCloudFeedContext(
            viewerID: actions?.identity.accountID,
            offline: reader.isOfflineExample,
            onDoubleTapLike: actions == nil ? nil : { post in self.doubleTapLike(post) },
            onFollow: actions == nil ? nil : { post in guard post.memberID > 0 else { return }; self.openReviewed(.init(purpose: .toggleFollow, target: .member(post.memberID), text: "")) },
            onRepost: actions == nil ? nil : { post in
                let card = SquareShareCard.build(id: post.id, audience: post.audience, lifecycle: post.lifecycle, contents: post.contents, images: post.images)
                guard card.includesPost else { return }
                self.openReviewed(.init(purpose: .createPost, target: .newPost, text: card.title))
            },
            onReport: actions == nil ? nil : { self.reportCloud($0) },
            onProfile: accountReader == nil ? nil : { post in guard post.memberID > 0 else { return }; self.cloudProfile = .init(id: post.memberID) },
            onCopyLink: { SquarePublicLinkCopy.copyIfPublic($0) })
    }
    private func openReviewed(_ route: EditorRoute) {
        reportTarget = nil
        showsWorkspaceEdit = false
        followWriteMember = route.purpose == .toggleFollow ? route.target.memberID : nil
        editor = route
    }
    private func reportCloud(_ post: SquarePost) {
        if post.generation == .legacySquare || contentGeneration == .legacySquare {
            openReviewed(.init(purpose: .report, target: .post(post.id), text: ""))
        } else if let target = try? SquareReportTarget(post: post) {
            editor = nil
            showsWorkspaceEdit = false
            reportTarget = .init(target: target)
        }
    }
    /// Like · comment · bookmark · share: four body-size labels with counts pass 375 pt at AX5, so they stack (same order).
    private var postActionLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.sm))
            : AnyLayout(HStackLayout(spacing: 28))
    }
    /// Mini-program `actions`: like, comment and favourite with their counts. Favourite only where it can work.
    private func postActions(_ post: SquarePost, actions: SocialActionCoordinator) -> some View {
        postActionLayout {
            Button { likeTapped(post, actions: actions) } label: {
                Label { Text(verbatim: SquareCountDisplay.text(post.likeCount)).contentTransition(reduceMotion ? .opacity : .numericText()) } icon: {
                    let heart = Image(systemName: post.isLiked == 1 ? "heart.fill" : "heart")
                    if #available(iOS 18.0, *) {
                        heart.symbolEffect(.bounce, options: .nonRepeating, isActive: !reduceMotion && post.isLiked == 1)
                    } else {
                        heart
                    }
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: post.isLiked)
            .tint(post.isLiked == 1 ? .red : .primary)
            .disabled(instantBusy)
            .accessibilityLabel(Text(post.isLiked == 1 ? LocalizedStringKey("square.unlike") : LocalizedStringKey("square.like")))
            .accessibilityValue(post.likeCount.map { Text("square.xcx.likesA11y \($0)") } ?? Text(verbatim: SquareCountDisplay.unknownMark)).accessibilityAddTraits(post.isLiked == 1 ? .isSelected : []).accessibilityIdentifier("square.detail.like")
            if post.viewerCanComment {
                Button { editor = .init(purpose: .comment, target: .post(post.id), text: "") } label: {
                    Label { Text(verbatim: SquareCountDisplay.text(post.commentCount)) } icon: { Image(systemName: "bubble.right") }
                }
                .tint(.primary)
                .accessibilityLabel(post.commentCount.map { Text("square.xcx.commentsA11y \($0)") } ?? Text(verbatim: SquareCountDisplay.unknownMark)).accessibilityIdentifier("square.detail.comment")
            } else {
                Label { Text(verbatim: SquareCountDisplay.text(post.commentCount)) } icon: { Image(systemName: "bubble.right") }
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(post.commentCount.map { Text("square.xcx.commentsA11y \($0)") } ?? Text(verbatim: SquareCountDisplay.unknownMark))
            }
            if post.generation == .communityV1 {
                Button { bookmarkTapped(post, actions: actions) } label: {
                    let star = Image(systemName: post.isBookmarked == 1 ? "star.fill" : "star")
                    if #available(iOS 18.0, *) {
                        star.symbolEffect(.bounce, options: .nonRepeating, isActive: !reduceMotion && post.isBookmarked == 1)
                    } else {
                        star
                    }
                }
                    .disabled(instantBusy)
                    .tint(post.isBookmarked == 1 ? .orange : .primary).accessibilityAddTraits(post.isBookmarked == 1 ? .isSelected : []) // C-S2: saved state shows
                    .accessibilityLabel(Text(LocalizedStringKey(post.isBookmarked == 1 ? "square.bookmark.remove" : "square.bookmark.add"))).accessibilityHint(Text("social.editor.bookmark")).accessibilityIdentifier("square.detail.bookmark")
            }
            // Mini `act-share` sits right after the other actions (owner 2026-11-09, Threads-style).
            // native-r2 N-24: the system share sheet straight from `ShareLink` (no custom half sheet in between).
            if let route = makeShareRoute(for: post) {
                ShareLink(item: route.url, preview: SharePreview(route.payload.excerpt ?? "城瘾Hub")) { Image(systemName: "paperplane") }
                    .tint(.primary)
                    .simultaneousGesture(TapGesture().onEnded {
                        MiniProgramAnalytics.track(analytics, "content_share", bizType: "square", bizID: MiniProgramAnalytics.bizID(post.id), pagePath: "/pages/square/detail/index")
                    })
                    .accessibilityLabel(Text("share.entry", tableName: "SocialParity")).accessibilityIdentifier("square.detail.share")
            }
            Spacer(minLength: 0)
        }
        .buttonStyle(.borderless).font(.body).labelStyle(.titleAndIcon)
        .frame(minHeight: 44)
        .cyHaptic(.selection, trigger: post.isLiked)
        .cyHaptic(.selection, trigger: post.isBookmarked)
    }
    /// Mini `square-share.js`: a publicly shareable post links to its parsed detail URL. Anything else has no public URL.
    private func makeShareRoute(for post: SquarePost) -> ShareRoute? {
        guard let shareLink else { return nil }
        (shareLink as? SquarePublicShareLink)?.note(post)
        let payload = CYSquareSharePayload(post: post)
        guard let postID = payload.postID, let url = shareLink.shareURL(postID: postID) else { return nil }
        return ShareRoute(payload: payload, url: url)
    }
    /// Mini `goUserInfoClcik`: follow only when the state is known and not yet following, then visit profile.
    private func avatarMenuItems(_ post: SquarePost) -> [CYAnchoredMenuItem] {
        (followState as? SquareAuthorFollowConformer)?.record(post)
        guard post.memberID > 0 else { return [] }
        var items: [CYAnchoredMenuItem] = []
        if let actions, let viewer = actions.identity.accountID, viewer != post.memberID,
           followState?.isFollowing(memberID: post.memberID) == false {
            items.append(.init(id: "follow", title: "avatarMenu.follow", tableName: "SocialParity", systemImage: "plus"))
        }
        if accountReader != nil { items.append(.init(id: "profile", title: "avatarMenu.profile", tableName: "SocialParity")) }
        return items
    }
    /// C-S8 (MP square/detail wxml:44): inline 关注 when the viewer is known not to follow the author, the author is
    /// not the viewer, and the post has no play cover (the MP hides it then).
    /// MP square/detail 试玩 (`goPlay`, index.js:186-193) opens the play page directly; without a session play page
    /// (fixtures, other hosts) it keeps the related-topic push.
    private func openPlay(_ selected: SquareRelatedTopicSelection) {
        if playDestination != nil { playTopic = selected } else { relatedTopic = selected }
    }
    private func inlineFollow(_ post: SquarePost) -> (() -> Void)? {
        guard let actions, let viewer = actions.identity.accountID, post.memberID > 0, post.memberID != viewer,
              !SquarePostCardFacts(post).hasPlayCover,
              followState?.isFollowing(memberID: post.memberID) == false else { return nil }
        return { openReviewed(.init(purpose: .toggleFollow, target: .member(post.memberID), text: "")) }
    }
    private func applyFollowReceipt() {
        guard let memberID = followWriteMember else { return }
        followWriteMember = nil
        guard let actions, case .acknowledged(let receipt) = actions.state(target: .member(memberID)),
              let followed = receipt.followed else { return }
        (followState as? SquareAuthorFollowConformer)?.apply(memberID: memberID, followed: followed)
    }
    private func pickAvatarItem(_ key: String, post: SquarePost) {
        switch key {
        case "follow": openReviewed(.init(purpose: .toggleFollow, target: .member(post.memberID), text: ""))
        case "profile": showsAuthorProfile = true
        default: break
        }
    }
    private func postMenu(_ post: SquarePost, actions: SocialActionCoordinator) -> some View {
        Menu {
            if post.memberID == actions.identity.accountID {
                if workspace != nil || contentGeneration != .communityV1 {
                    Button("square.edit", systemImage: "pencil") { if workspace != nil { showsWorkspaceEdit = true } else { editor = .init(purpose: .editPost, target: .post(post.id), text: post.contents ?? "") } }
                }
                if let target = SquareDeletionTarget(post: post), deletion?.isAllowed(target) == true {
                    Button("square.xcx.delete.post", systemImage: "trash", role: .destructive) { deletion?.prepare(target) }
                        .accessibilityIdentifier("square.delete.postEntry")
                } else if post.generation == .legacySquare, reader.isSignedIn {
                    // MP post-actions 删除 on a legacy post: confirm, then `/api/creativesquare/delete`.
                    Button("square.xcx.delete.post", systemImage: "trash", role: .destructive) { legacyDeleteConfirm = true }
                        .disabled(legacyDeleting)
                        .accessibilityIdentifier("square.delete.legacyPostEntry")
                }
            }
            if post.generation != .unknown {
                Button(LocalizedStringKey(postReported(post) ? "social1128.reported" : "square.report"), systemImage: "exclamationmark.bubble") {
                    if post.generation == .legacySquare { editor = .init(purpose: .report, target: .post(post.id), text: "") }
                    else if let target = try? SquareReportTarget(post: post) { reportTarget = .init(target: target) }
                }
                .disabled(postReported(post))
                .accessibilityLabel(Text(LocalizedStringKey(postReported(post) ? "social1128.reported" : "square.report")))
                .accessibilityIdentifier("squareReport.postEntry")
            }
            if SquareAuthorSafety.showsBlockEntry(authorMemberID: post.memberID, viewerMemberID: actions.identity.accountID) {
                Button("square.block", systemImage: "hand.raised") {
                    blockTarget = .init(memberID: post.memberID, authorName: post.nickname)
                }
                    .accessibilityLabel(Text("square.block"))
                    .accessibilityIdentifier("square.block.postEntry")
            }
        } label: {
            Label("social.actions", systemImage: "ellipsis.circle").labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel(Text("social.actions"))
        .accessibilityIdentifier("social.post.actions")
    }
    @ViewBuilder private func commentRow(_ comment: SquareComment) -> some View {
        if comment.lifecycle == "DELETED" {
            // Source deleted-row placeholder; the removed body is never shown.
            Text("square.xcx.commentDeleted").font(.subheadline).foregroundStyle(.secondary)
                .padding(.leading, comment.parentID == nil ? 0 : 12)
        } else { liveCommentRow(comment) }
    }
    /// MP square/detail wxml:133-135: the 加号 `icon_jia` on a commenter's avatar follows them. Shown only when the
    /// follow state is known to be "not following" and the commenter is not the viewer (same rule as the post avatar menu).
    @ViewBuilder private func commentFollowBadge(_ comment: SquareComment) -> some View {
        if let actions, let viewer = actions.identity.accountID, comment.memberID > 0, comment.memberID != viewer,
           followState?.isFollowing(memberID: comment.memberID) == false {
            Button { openReviewed(.init(purpose: .toggleFollow, target: .member(comment.memberID), text: "")) } label: {
                MPAsset.FeatureIcon.iconJia.resizable().scaledToFit().frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .frame(width: CYSpacing.minTouchTarget, height: CYSpacing.minTouchTarget).contentShape(Rectangle())
            .offset(x: 16, y: 16)
            .accessibilityLabel(Text("avatarMenu.follow", tableName: "SocialParity"))
            .accessibilityIdentifier("square.comment.follow.\(comment.id)")
        }
    }
    /// Like · reply · report · delete · ⋯ in one row; at AX text sizes they stack so no action is pushed off screen.
    private var commentActionLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(spacing: 20))
    }
    /// Mini-program comment row: avatar, name and time; the text; then like count, reply and the overflow actions.
    private func liveCommentRow(_ comment: SquareComment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            SquareAuthorAvatar(source: comment.avatar, size: 32)
                .overlay(alignment: .bottomTrailing) { commentFollowBadge(comment) }
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    if let accountReader, comment.memberID > 0 {
                        NavigationLink { SocialPublicProfileView(memberID: comment.memberID, reader: accountReader, squareReader: reader, actions: actions).cyPushedChrome(domain: .player) } label: { commentAuthor(comment) }
                            .buttonStyle(.borderless).tint(.primary)
                    } else {
                        commentAuthor(comment)
                    }
                    Spacer(minLength: 8)
                    if !comment.createTime.isEmpty { SquareXcxRelativeTime(createTime: comment.createTime, now: Date()).font(.caption).foregroundStyle(.secondary) }
                }
                if let name = comment.replyName(in: comments.items) {
                    Text("square.replyingTo \(name)").font(.caption).foregroundStyle(.secondary)
                }
                if let contents = comment.contents { Text(verbatim: contents).textSelection(.enabled) }
                NativeMediaGalleryEntry(sources: comment.images, scope: reader.scope, titleKey: "media.destination.squareImages")
                commentActionLayout {
                    let likeLabel = Label { Text(verbatim: SquareCountDisplay.text(comment.likeCount)) } icon: { Image(systemName: comment.isLiked == 0 ? "heart" : "heart.fill") }
                        .font(.caption).foregroundStyle(comment.isLiked == 0 ? AnyShapeStyle(.secondary) : AnyShapeStyle(.red))
                    if let actions, actions.identity.accountID != nil {
                        // C-S4 (MP comment row): like and 回复 act inline; the ⋯ menu keeps block / delete.
                        Button { commentLikeTapped(comment, actions: actions) } label: { likeLabel }
                            .disabled(instantBusy)
                            .buttonStyle(.borderless)
                            .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget).contentShape(Rectangle())
                            .accessibilityLabel(Text(comment.isLiked == 0 ? LocalizedStringKey("square.like") : LocalizedStringKey("square.unlike")))
                            .accessibilityValue(comment.likeCount.map { Text("square.xcx.likesA11y \($0)") } ?? Text(verbatim: SquareCountDisplay.unknownMark))
                            .accessibilityIdentifier("square.comment.like.\(comment.id)")
                            .cyHaptic(.selection, trigger: comment.isLiked)
                        if post?.viewerCanComment == true {
                            Button { editor = .init(purpose: .comment, target: .comment(postID: id, commentID: comment.id), text: "") } label: {
                                Text("social.reply").font(.caption).foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget).contentShape(Rectangle())
                            .accessibilityIdentifier("square.comment.reply.\(comment.id)")
                        }
                    } else {
                        likeLabel
                            .accessibilityLabel(comment.likeCount.map { Text("square.xcx.likesA11y \($0)") } ?? Text(verbatim: SquareCountDisplay.unknownMark))
                    }
                    // Mini-program comment row keeps 举报 visible beside the like count, not inside the overflow.
                    if let actions, actions.identity.accountID != nil, comment.generation != .unknown {
                        Button { reportComment(comment) } label: { Text(LocalizedStringKey(commentReported(comment) ? "social1128.reported" : "square.report")).font(.caption).foregroundStyle(.secondary) }
                            .buttonStyle(.borderless)
                            .disabled(commentReported(comment))
                            .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget).contentShape(Rectangle()) // C-S5
                            .accessibilityLabel(Text(LocalizedStringKey(commentReported(comment) ? "social1128.reported" : "square.report")))
                            .accessibilityIdentifier("squareReport.commentEntry.\(comment.id)")
                    }
                    // MP A-04 (index.wxml:162-164): the author's own comment shows 删除 inline, right after 举报.
                    if let actions, actions.identity.accountID != nil, comment.memberID == actions.identity.accountID, let post,
                       let target = SquareDeletionTarget(post: post, comment: comment), deletion?.isAllowed(target) == true {
                        Button(role: .destructive) { deletion?.prepare(target) } label: { Text("square.xcx.delete.comment").font(.caption) }
                            .buttonStyle(.borderless)
                            .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget).contentShape(Rectangle())
                            .accessibilityLabel(Text("square.xcx.delete.commentConfirm"))
                            .accessibilityIdentifier("square.delete.commentEntry.\(comment.id)")
                    }
                    if comment.generation == .legacySquare, let actions, let viewer = actions.identity.accountID, comment.memberID == viewer {
                        Button(role: .destructive) { legacyCommentTarget = comment } label: { Text("square.xcx.delete.comment").font(.caption) }
                            .buttonStyle(.borderless)
                            .disabled(legacyCommentDeleting)
                            .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget).contentShape(Rectangle())
                            .accessibilityLabel(Text("square.xcx.delete.commentConfirm"))
                            .accessibilityIdentifier("square.delete.legacyCommentEntry.\(comment.id)")
                    }
                    Spacer(minLength: 0)
                    if let actions, actions.identity.accountID != nil,
                       SquareAuthorSafety.showsBlockEntry(authorMemberID: comment.memberID, viewerMemberID: actions.identity.accountID) {
                        // ⋯ holds only 屏蔽 (App Store UGC safety); like, 回复, 举报 and 删除 are inline as in the MP.
                        Menu {
                            Button("square.block", systemImage: "hand.raised") {
                                blockTarget = .init(memberID: comment.memberID, authorName: comment.nickname)
                            }
                                .accessibilityIdentifier("square.block.commentEntry.\(comment.id)")
                        } label: {
                            Label("social.actions", systemImage: "ellipsis").labelStyle(.iconOnly).frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("social.comment.actions.\(comment.id)")
                    }
                }
            }
        }
        .padding(.leading, comment.parentID == nil ? 0 : 24)
    }
    private func reportComment(_ comment: SquareComment) {
        if comment.generation == .legacySquare { editor = .init(purpose: .report, target: .comment(postID: id, commentID: comment.id), text: "") }
        else if let post, let target = try? SquareReportTarget(post: post, comment: comment) { reportTarget = .init(target: target) }
    }
    @ViewBuilder private func commentAuthor(_ comment: SquareComment) -> some View {
        if let nickname = comment.nickname, !nickname.isEmpty { Text(verbatim: nickname).font(.subheadline.weight(.semibold)) }
        else { Text("square.unknownAuthor").font(.subheadline.weight(.semibold)) }
    }
    private struct DeletionRoute: Identifiable { let target: SquareDeletionTarget; var id: SquareDeletionTarget { target } }
    private var deletionBinding: Binding<DeletionRoute?> {
        Binding(get: {
            if case .confirming(let target)? = deletion?.phase { return DeletionRoute(target: target) }
            if case .sending(let target)? = deletion?.phase { return DeletionRoute(target: target) }
            return nil
        }, set: { if $0 == nil { deletion?.cancel() } })
    }
    /// Unknown-outcome readback through the same scoped reads; a failed read keeps the unknown lock.
    private func verifyDeletion() async {
        guard let deletion, case .unknown(let target) = deletion.phase else { return }
        await reload()
        guard loadedKey == key else { return }
        switch target {
        case .post:
            if post != nil { deletion.resolveUnknown(stillPresent: true) }
            else if (detailIssue as? SquareReadFailure) == .unavailable || (detailIssue as? APIError) == .httpStatus(404) { deletion.resolveUnknown(stillPresent: false) }
        case .comment(_, let commentID, _):
            guard post != nil, commentIssue == nil, !comments.hasMore else { return }
            let row = comments.items.first { $0.id == commentID }
            deletion.resolveUnknown(stillPresent: row.map { $0.lifecycle != "DELETED" } ?? false)
        }
    }
    // MARK: fix-1128b-social #3 已举报 (MP square/detail: a reported post / comment shows 已举报 and cannot be reported again)

    /// True once this viewer's report on the v1 target is submitted or pending (the coordinator's durable lock).
    private func isReported(_ target: SquareReportTarget?) -> Bool {
        guard let target, let reportContext, let identity = reportContext.access.identity else { return false }
        return reportContext.coordinator.isLocked(target: target, identity: identity)
    }
    private func postReported(_ post: SquarePost) -> Bool {
        _ = reportTarget?.id
        guard post.generation == .communityV1 else { return false }
        return isReported(try? SquareReportTarget(post: post))
    }
    private func commentReported(_ comment: SquareComment) -> Bool {
        _ = reportTarget?.id
        guard comment.generation == .communityV1, let post else { return false }
        return isReported(try? SquareReportTarget(post: post, comment: comment))
    }

    // MARK: fix-1128b-social #1 immediate v1 toggles

    private func likeTapped(_ post: SquarePost, actions: SocialActionCoordinator) {
        instantOrReview(.action(.like, enabled: post.isLiked != 1), target: .post(post.id),
                        fallback: .init(purpose: .like, target: .post(post.id), text: ""), actions: actions)
    }
    private func bookmarkTapped(_ post: SquarePost, actions: SocialActionCoordinator) {
        instantOrReview(.action(.bookmark, enabled: post.isBookmarked != 1), target: .post(post.id),
                        fallback: .init(purpose: .bookmark, target: .post(post.id), text: "", enabled: post.isBookmarked != 1), actions: actions)
    }
    private func commentLikeTapped(_ comment: SquareComment, actions: SocialActionCoordinator) {
        let target = SocialActionTarget.comment(postID: id, commentID: comment.id)
        instantOrReview(.communityCommentLike(enabled: comment.isLiked == 0, requestID: UUID().uuidString), target: target,
                        fallback: .init(purpose: .commentLike, target: target, text: "", enabled: comment.isLiked == 0), actions: actions)
    }
    /// MP double-tap likes only (it never unlikes).
    private func doubleTapLike(_ post: SquarePost) {
        guard let actions else { return }
        if contentGeneration == .communityV1, post.isLiked == 1 { return }
        likeTapped(post, actions: actions)
    }
    /// v1 with a live community writer: send now. Otherwise (legacy square, writes off) the reviewed editor opens.
    private func instantOrReview(_ command: SocialActionCommand, target: SocialActionTarget, fallback: EditorRoute,
                                 actions: SocialActionCoordinator) {
        guard contentGeneration == .communityV1, actions.availability(for: command, target: target) == .approved else {
            editor = fallback
            return
        }
        guard !instantBusy else { return }
        instantBusy = true
        instantMessage = nil
        Task { await runInstant(command, target: target, actions: actions) }
    }
    private func runInstant(_ command: SocialActionCommand, target: SocialActionTarget, actions: SocialActionCoordinator) async {
        let captured = key
        let outcome = await actions.sendImmediately(command, target: target, ownerID: instantOwner)
        instantBusy = false
        guard captured == key else { return }
        instantMessage = outcome.messageKey
        if outcome == .confirmed { await refreshAfterWrite(comments: target.commentID != nil) }
    }
    /// Server-confirmed state: re-read the post (counts, liked / saved) or the comment thread in place.
    private func refreshAfterWrite(comments refreshComments: Bool) async {
        let captured = key, operation = generation
        if refreshComments {
            comments = SquareCommentPagination()
            await loadComments(operation: operation, captured: captured)
            return
        }
        guard let value = try? await reader.squareDetail(route: .init(id: id, generation: contentGeneration)) else { return }
        guard captured == key, operation == generation else { return }
        post = value
    }
    /// A comment or reply sent from the editor shows in the thread and the post's comment count (MP reloads both).
    private func refreshAfterEditor() {
        guard contentGeneration == .communityV1 else { return }
        Task {
            await refreshAfterWrite(comments: false)
            await refreshAfterWrite(comments: true)
        }
    }
    private func reload() async {
        generation += 1
        let operation = generation, captured = key
        post = nil; comments = SquareCommentPagination(); detailIssue = nil; commentIssue = nil
        legacyDeleted = false; legacyDeleteFailed = false
        detailLoading = false; commentsLoading = false; loadedKey = captured
        guard reader.isConfigured else { return }
        detailLoading = true
        // Independent read states: a comment failure does not discard a successfully loaded post.
        async let detailTask: Void = loadDetail(operation: operation, captured: captured)
        async let commentTask: Void = loadComments(operation: operation, captured: captured)
        _ = await (detailTask, commentTask)
    }
    /// MP deleteSquarePost: soft delete with ownership checked server side; on success the detail falls to its
    /// unavailable state (这条帖文暂不可用 · 返回上一页). The re-read list must no longer hold the post.
    private func deleteLegacyPost(_ postID: Int) async {
        guard !legacyDeleting, postID > 0 else { return }
        legacyDeleting = true; legacyDeleteFailed = false
        defer { legacyDeleting = false }
        let captured = key
        do {
            let remaining = try await reader.deleteOwnCreativeSquare(postID: postID)
            guard captured == key else { return }
            guard !remaining.contains(postID) else { legacyDeleteFailed = true; return }
            generation += 1
            post = nil; comments = SquareCommentPagination(); commentIssue = nil
            detailLoading = false; commentsLoading = false
            detailIssue = SquareReadFailure.unavailable
            legacyDeleted = true
        } catch is CancellationError {
        } catch { if captured == key { legacyDeleteFailed = true } }
    }
    private func commentBarAvatar(_ actions: SocialActionCoordinator) -> String? {
        guard let viewerAvatar, viewerAvatar.memberID == actions.identity.accountID, !viewerAvatar.avatar.isEmpty else { return nil }
        return viewerAvatar.avatar
    }
    /// MP index.js:918-966: after `/api/comment/delete` succeeds the thread re-reads (count and list stay server truth).
    private func deleteLegacyComment(_ commentID: Int) async {
        guard !legacyCommentDeleting, commentID > 0 else { return }
        legacyCommentDeleting = true; legacyCommentDeleteFailed = false
        defer { legacyCommentDeleting = false }
        let captured = key
        do {
            try await reader.deleteOwnLegacyComment(commentID: commentID)
            guard captured == key else { return }
            await reload()
        } catch is CancellationError {
        } catch { if captured == key { legacyCommentDeleteFailed = true } }
    }
    private func loadDetail(operation: Int, captured: Key) async {
        defer { if operation == generation { detailLoading = false } }
        do {
            let value = try await reader.squareDetail(route: .init(id: id, generation: contentGeneration))
            try Task.checkCancellation()
            guard operation == generation, captured == key else { return }
            post = value
        } catch is CancellationError { }
        catch { if operation == generation, captured == key { detailIssue = error } }
    }
    private func loadComments(operation: Int, captured: Key) async {
        guard !commentsLoading, comments.hasMore, operation == generation, captured == key else { return }
        commentsLoading = true; commentIssue = nil
        defer { if operation == generation { commentsLoading = false } }
        do {
            let page = try await reader.squareComments(route: .init(id: id, generation: contentGeneration), pageNumber: comments.nextPage)
            try Task.checkCancellation()
            guard operation == generation, captured == key else { return }
            try comments.accept(page)
        } catch is CancellationError { }
        catch { if operation == generation, captured == key { commentIssue = error } }
    }
}

private struct SquareDetailProfileRoute: Identifiable, Hashable {
    let id: Int
}

/// Author's own legacy square posts. Delete posts `api/creativesquare/delete`, then the list is read again.
@MainActor struct CreativeSquareAuthorDeleteSection: View {
    let signedIn: Bool
    var highlightedPostID: Int? = nil
    let load: () async throws -> [Int]
    let remove: (Int) async throws -> [Int]
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var phase = Phase.loading
    @State private var ids: [Int] = []
    @State private var removing = false
    private enum Phase { case loading, empty, ready, failed }
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text(verbatim: locale.pick("我的广场", "My square posts"))
                .font(.headline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if !signedIn {
                Text("cooperation.login").foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                switch phase {
                case .loading: ProgressView { Text(verbatim: locale.pick("读取中", "Loading")) }.frame(maxWidth: .infinity)
                case .empty:
                    ContentUnavailableView(locale.pick("还没有你发布的广场帖", "You have no square posts"), systemImage: "square.and.pencil")
                case .failed:
                    Text(verbatim: locale.pick("列表没有读出来，请重试", "The list did not load. Try again.")).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button { Task { await reload() } } label: { Text(verbatim: locale.pick("重试", "Try again")) }
                        .buttonStyle(.bordered)
                case .ready:
                    if let highlightedPostID, !ids.contains(highlightedPostID) {
                        Text(verbatim: locale.pick("这篇已经不在你的列表里", "This post is no longer in your list")).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(ids, id: \.self) { id in
                        authorRow(id)
                    }
                }
            }
        }
        .accessibilityIdentifier("square.authorDelete")
        .task { await reload() }
    }
    private func authorRow(_ id: Int) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.sm))
            : AnyLayout(HStackLayout(alignment: .center, spacing: CYSpacing.sm))
        return layout {
            Text(verbatim: "#\(id)")
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: CYSpacing.sm)
            }
            Button(role: .destructive) { Task { await delete(id) } } label: {
                Text(verbatim: locale.pick("删除", "Delete"))
            }
            .buttonStyle(.bordered)
            .controlSize(dynamicTypeSize.isAccessibilitySize ? .regular : .small)
            .disabled(removing)
        }
    }
    private func reload() async {
        guard signedIn else { return }
        phase = .loading
        do {
            let value = try await load()
            ids = value
            phase = value.isEmpty ? .empty : .ready
        } catch { phase = .failed }
    }
    private func delete(_ id: Int) async {
        guard !removing, id > 0 else { return }
        removing = true
        defer { removing = false }
        do {
            ids = try await remove(id)
            phase = ids.isEmpty ? .empty : .ready
        } catch { phase = .failed }
    }
}

/// MP square/detail `feed-play-card` (fix-parity C-S1): the 可直接开局的模板 badge, 看看模板 (copy the template into an
/// editable topic, then open it in the editor) and 试玩 (the related topic, where play starts). The copy is only offered
/// once the topic-template write is live; the topic link keeps its own access checks.
@MainActor private struct SquareDetailPlayCard: View {
    let post: SquarePost
    let source: SquareContentRoute
    let reader: any SquareReading
    let onSelectTopic: (SquareRelatedTopicSelection) -> Void
    @Environment(\.topicTemplateCopiedDestination) private var copiedDestination
    @Environment(\.topicEditorDestination) private var editorDestination
    @State private var copiedDraft: CopiedTopicDraft?
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            if post.isTopicTemplate {
                Text("square.xcx.templateBadge").font(.caption.bold()).foregroundStyle(.secondary)
            }
            if let title = post.referenceTitle { Text(verbatim: title).font(.headline).fixedSize(horizontal: false, vertical: true) }
            if post.isTopicTemplate, let topicID = post.topicID, topicID > 0, TopicTemplateUseFactory.isLive {
                TopicTemplateUseSection(templateID: topicID, scope: nil, readOnly: false) { topicID in
                    if let copiedDestination { copiedDestination(topicID) } else { copiedDraft = CopiedTopicDraft(id: topicID) }
                }
            }
            SquareRelatedTopicLink(post: post, source: source, squareReader: reader, titleKey: "square.play.try", onSelect: onSelectTopic)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("square.detail.playCard")
        .navigationDestination(item: $copiedDraft) { draft in
            if let editorDestination { editorDestination(draft.id, nil) }
        }
    }
}

/// C-S3: MP square/detail error shells — 社区暂未开放 / 没有找到这条帖文 / 这条帖文暂不可用 / 动态加载失败 (+ 重试),
/// each with 返回上一页.
struct SquareDetailIssueView: View {
    let error: Error
    let retry: () -> Void
    let back: () -> Void
    private enum Kind { case closed, gone, notFound, unavailable, failed }
    /// MP index.js:25 `GONE_POST_MSG`: a removed / under-review / missing post is an expired link (链接已失效 · 返回), not a load failure.
    static let gonePrefixes = ["内容不存在", "已删除", "审核中", "数据不存在", "参数不合规", "帖文不存在"]
    private var kind: Kind {
        switch error as? SquareReadFailure {
        case .communityRequired: return .closed
        case .unavailable: return .unavailable
        case .server(_, let message?) where Self.gonePrefixes.contains(where: { message.hasPrefix($0) }): return .gone
        case .server(let code, _) where code == 404: return .notFound
        default: return .failed
        }
    }
    private var titleKey: LocalizedStringKey {
        switch kind {
        case .closed: return "square.detail.closed"
        case .gone: return "mp.common.linkExpired"
        case .notFound: return "square.detail.notFound"
        case .unavailable: return "square.detail.unavailable"
        case .failed: return "square.detail.failed"
        }
    }
    var body: some View {
        Section {
            ContentUnavailableView {
                Label {
                    Text(titleKey).accessibilityIdentifier("square.error")
                } icon: {
                    // Round 4 image parity: MP `cy-empty kind="empty"` (社区暂未开放 / 这条帖文暂不可用) keeps the MP empty
                    // art; 没有找到这条帖文 (missing-param) and 动态加载失败 keep their state glyphs.
                    if kind == .closed || kind == .unavailable {
                        CYEmptyIllustration(kind: .generic, size: 96)
                    } else {
                        Image(systemName: kind == .failed ? "exclamationmark.circle" : "info.circle")
                    }
                }
            } description: {
                // MP index.js:1040-1086 `detailError`: the server message, else 服务暂时无法提供这条动态; a dropped request reads
                // 网络异常，请检查连接后重试 so the person knows what to do.
                if kind == .failed {
                    if let failure = error as? SquareReadFailure, case let .server(_, message) = failure {
                        if let message, !message.isEmpty { Text(verbatim: message).textSelection(.enabled) }
                        else { Text("mpr3.square.detail.serviceError") }
                    } else {
                        Text("mpr3.square.detail.networkError")
                    }
                }
            } actions: {
                if kind == .failed {
                    Button("square.retry", action: retry).buttonStyle(.borderedProminent).accessibilityIdentifier("square.retry")
                }
                // MP gone state's CTA is 返回; every other shell says 返回上一页.
                if kind == .gone {
                    Button(LocalizedStringKey("common.back"), action: back).buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("square.detail.back")
                } else {
                    Button("square.detail.back", action: back).buttonStyle(.bordered)
                        .accessibilityIdentifier("square.detail.back")
                }
            }
        }
    }
}

/// MP components/cy/completion-share-card (square/detail/index.wxml:57-75) on the detail page.
/// Title row (walk, title or 本次漫游, medals) and 路线节点 when no activity stats block already shows them,
/// then the result image (roam results are a tall image: fit, not fill). Stats and kudos come from the activity block.
struct SquareDetailCompletionCard: View {
    let post: SquarePost
    let cover: String?
    let showsTitleRow: Bool
    let scope: UUID
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsTitleRow {
                HStack(spacing: 10) {
                    Image(systemName: "figure.walk").foregroundStyle(.secondary).accessibilityHidden(true)
                    titleText.font(.headline)
                    Spacer(minLength: 0)
                    SquareDetailMedalPill(gold: post.medalGold, silver: post.medalSilver, bronze: post.medalBronze)
                }
                if post.dataType != 3 && post.nodeTotal > 0 {
                    LabeledContent {
                        Text(verbatim: String(post.nodeTotal)).monospacedDigit()
                    } label: {
                        Text("mpr3.square.detail.routeStops")
                    }
                    .accessibilityIdentifier("square.detail.completion.nodes")
                }
            }
            if let cover {
                NativeMediaGalleryEntry(sources: [cover], scope: scope, titleKey: "media.destination.squareImages")
            }
            commentPreview
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("square.detail.completionCard")
    }
    /// MP CommentPreview (completion-share-card/index.wxml:63-70, tail defaults true on the detail page):
    /// one comment (nick + text) unless the activity block already shows it, then 查看全部 N 条评论 when N > 0.
    @ViewBuilder private var commentPreview: some View {
        let count = post.commentCount ?? 0
        let author = post.strava.commentAuthor
        let line = post.strava.commentBody
        if showsTitleRow && (author != nil || line != nil) {
            HStack(alignment: .firstTextBaseline) {
                if let author { Text(verbatim: author).font(.subheadline.weight(.medium)) }
                if let line { Text(verbatim: line).font(.subheadline).foregroundStyle(.secondary).lineLimit(2) }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("square.detail.completion.comment")
        }
        if count > 0 {
            Text("mpr3.square.detail.allComments \(count)")
                .font(.footnote).foregroundStyle(.secondary)
                .accessibilityIdentifier("square.detail.completion.allComments")
        }
    }
    @ViewBuilder private var titleText: some View {
        if let title = post.referenceTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            Text(verbatim: title)
        } else {
            Text("square.xcx.completionFallback")
        }
    }
}

/// C-S10b (r9): MP components/cy/completion-share-card/index.wxml:17-22 (square/detail/index.wxml:57-66):
/// one medal image per tier that is above zero, then the sum. Hidden when every tier is zero or unknown.
struct SquareDetailMedalPill: View {
    let gold: Int?
    let silver: Int?
    let bronze: Int?
    @ScaledMetric(relativeTo: .subheadline) private var medalHeight: CGFloat = 20
    var body: some View {
        let g = gold ?? 0, s = silver ?? 0, b = bronze ?? 0
        if g > 0 || s > 0 || b > 0 {
            Label {
                Text("fixr9.ap.square.medals \(g + s + b)")
            } icon: {
                HStack(spacing: 2) {
                    if g > 0 { MPAsset.BadgeMedal.medalGold.resizable().scaledToFit() }
                    if s > 0 { MPAsset.BadgeMedal.medalSilver.resizable().scaledToFit() }
                    if b > 0 { MPAsset.BadgeMedal.medalBronze.resizable().scaledToFit() }
                }
                .frame(height: min(medalHeight, 40))
                .accessibilityHidden(true)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("square.detail.medals")
        }
    }
}
