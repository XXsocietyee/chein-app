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
    @Environment(\.squareDeletion) private var deletion
    @Environment(\.squareShareLink) private var shareLink
    @Environment(\.squareAuthorFollowState) private var followState
    @Environment(\.analyticsEventClient) private var analytics
    @Environment(\.ugcSafetyContext) private var ugcSafety
    @Environment(\.locale) private var locale
    @State private var shareRoute: ShareRoute?
    private struct ShareRoute: Identifiable { let id = UUID(); let payload: CYSquareSharePayload; let url: URL }
    @State private var showsAuthorProfile = false
    @State private var relatedTopic: SquareRelatedTopicSelection?
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
    @QuestifyReduceMotion private var reduceMotion
    private struct Key: Hashable { let id: Int; let generation: SquareContentGeneration; let scope: UUID; let configured: Bool }
    private var key: Key { Key(id: id, generation: contentGeneration, scope: reader.scope, configured: reader.isConfigured) }
    var body: some View {
        List {
            if let governanceContext { SquareGovernanceEntryView(context: governanceContext) }
            if let deletion { SquareDeletionStatusView(coordinator: deletion) { Task { await verifyDeletion() } } }
            if reader.isOfflineExample { Text("square.offlineExample").cyText(.meta) }
            if !reader.isConfigured { SquareIssueView(error: APIError.notConfigured) }
            else if loadedKey != key { CYSkeleton() }
            else {
                if detailLoading { CYSkeleton() }
                if let detailIssue {
                    // C-S3 (MP square/detail index.wxml:12-27): the cause decides the title; a way back is always there.
                    if post == nil {
                        SquareDetailIssueView(error: detailIssue, retry: { Task { await reload() } }, back: { dismiss() })
                    } else { SquareIssueView(error: detailIssue) { Task { await reload() } } }
                }
                if let post {
                    UGCBlockedFilterContainer(memberID: post.memberID, authorName: post.nickname) {
                        Section {
                            SquarePostContent(post: post, mediaScope: reader.scope, showsCounts: actions?.identity.accountID == nil,
                                              avatarMenuItems: avatarMenuItems(post), onAvatarPick: { pickAvatarItem($0, post: post) },
                                              onFollow: inlineFollow(post)).accessibilityIdentifier("square.detailPost")
                            if !post.videos.isEmpty { SquarePostVideoList(videos: post.videos) }
                            if post.isTopicTemplate || post.referenceTitle != nil {
                                // C-S1: MP feed-play-card on the detail page (看看模板 / 试玩).
                                SquareDetailPlayCard(post: post, source: .init(id: id, generation: contentGeneration), reader: reader) { relatedTopic = $0 }
                            } else {
                                SquareRelatedTopicLink(post: post, source: .init(id: id, generation: contentGeneration), squareReader: reader) { relatedTopic = $0 }
                            }
                            // Mini `components/route-map`: live route only with a provider; the post's own snapshot is already in the gallery.
                            if let topicID = post.topicID, topicID > 0 { CYSquareRouteMapCard(topicID: topicID) }
                            if let actions, actions.identity.accountID != nil {
                                postActions(post, actions: actions)
                            }
                            if post.memberID == 0 {
                                Text(verbatim: "—").cyText(.body).foregroundStyle(CYColor.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("square.author.unknown")
                            } else if let viewer = actions?.identity.accountID, viewer == post.memberID {
                                CreativeSquareAuthorDeleteSection(signedIn: reader.isSignedIn, highlightedPostID: post.id, load: { try await reader.ownCreativeSquareIDs() }, remove: { try await reader.deleteOwnCreativeSquare(postID: $0) })
                            }
                            if let accountReader, post.memberID > 0 {
                                NavigationLink { SocialPublicProfileView(memberID: post.memberID, reader: accountReader, squareReader: reader, actions: actions) } label: { Label("social.viewAuthor", systemImage: "person.crop.circle") }
                                    .accessibilityIdentifier("social.viewAuthor")
                            }
                        }.cyMiniCardRow()
                    } blockedPlaceholder: {
                        Section {
                            UGCBlockedNoticeBanner(
                                messageKey: "ugc.safety.blockedBanner.hidden",
                                memberID: post.memberID,
                                authorName: post.nickname
                            )
                        }.cyMiniCardRow()
                    }
                }
                // Detail failure never renders orphan comments without their post context.
                if let post, !(ugcSafety?.isBlocked(memberID: post.memberID, authorName: post.nickname) ?? false) {
                    Section("square.comments") {
                        if let commentIssue { SquareIssueView(error: commentIssue) { Task { await loadComments(operation: generation, captured: key) } } }
                        ForEach(SquareComment.threaded(comments.items)) { comment in
                            UGCBlockedFilterContainer(memberID: comment.memberID, authorName: comment.nickname) {
                                commentRow(comment).accessibilityIdentifier("square.comment.\(comment.id)")
                            }
                        }
                        if commentsLoading { CYSkeleton() }
                        else if comments.items.isEmpty && commentIssue == nil {
                            Text(LocalizedStringKey(SquareDetailPageModel.emptyCommentsTitleKey))
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("square.noComments")
                        }
                        if !commentsLoading && comments.hasMore && commentIssue == nil {
                            // C-S9 (MP onReachBottom): reaching the end loads the next page; the button stays for VoiceOver.
                            CYPillButton("square.moreComments", style: .secondary) { Task { await loadComments(operation: generation, captured: key) } }.accessibilityIdentifier("square.moreComments")
                                .onAppear { Task { await loadComments(operation: generation, captured: key) } }
                        }
                    }.cyMiniCardRow()
                }
            }
        }
        // Mini-program `.detail.theme-dark`: ink ground, elevated post card and comment card (radius 16, 12pt apart).
        .cyMiniListScreen()
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
                CYFooterBar {
                    Button { editor = .init(purpose: .comment, target: .post(post.id), text: "") } label: {
                        Label("square.xcx.commentPlaceholder", systemImage: "text.bubble")
                            .cyText(.body).foregroundStyle(CYColor.textSecondary)
                            .padding(.horizontal, CYSpacing.lg)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .background(Capsule().fill(CYColor.bgSurfaceSubtle))
                            .overlay(Capsule().strokeBorder(CYColor.borderSubtle, lineWidth: 1))
                            .contentShape(Capsule())
                    }.buttonStyle(.plain).disabled(!post.viewerCanComment).opacity(post.viewerCanComment ? 1 : 0.5)
                        .accessibilityIdentifier("square.commentBar")
                }
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
        .onChange(of: key) { _, _ in relatedTopic = nil }
        .onChange(of: relatedTopicContext?.reader.scope) { _, _ in relatedTopic = nil }
        .sheet(item: $editor, onDismiss: { applyFollowReceipt() }) { item in Group {
            if let actions { NavigationStack { SocialActionEditorView(purpose: item.purpose, target: item.target, coordinator: actions, initialText: item.text, contentGeneration: contentGeneration, initialEnabled: item.enabled) }.id(actions.identity) }
        }.cySheet(detents: [.large]) }
        .sheet(item: $shareRoute) { route in CYSquareShareSheet(payload: route.payload, url: route.url) }
        .navigationDestination(isPresented: $showsAuthorProfile) {
            if let accountReader, let post, post.memberID > 0 {
                SocialPublicProfileView(memberID: post.memberID, reader: accountReader, squareReader: reader, actions: actions)
            }
        }
        .onChange(of: key) { _, _ in shareRoute = nil; showsAuthorProfile = false; blockTarget = nil }
        .overlay {
            if let target = blockTarget {
                CYModal(
                    title: String(localized: LocalizedStringResource("ugc.safety.block.confirmTitle", table: "UGCSafety", locale: locale)),
                    message: String(localized: LocalizedStringResource("ugc.safety.block.confirmMessage", table: "UGCSafety", locale: locale)),
                    cancelTitle: String(localized: LocalizedStringResource("ugc.safety.block.cancel", table: "UGCSafety", locale: locale)),
                    confirmTitle: String(localized: LocalizedStringResource("ugc.safety.block.confirmButton", table: "UGCSafety", locale: locale)),
                    isDestructive: true,
                    onCancel: { blockTarget = nil },
                    onConfirm: {
                        let targetToBlock = target
                        blockTarget = nil
                        Task {
                            try? await ugcSafety?.blockUser(memberID: targetToBlock.memberID, authorName: targetToBlock.authorName)
                        }
                    }
                )
            }
        }
        .sheet(item: $reportTarget) { item in
            NavigationStack { SquareReportView(target: item.target, context: reportContext) }
                .cySheet(detents: [.large])
        }
        .sheet(isPresented: $showsWorkspaceEdit) { Group {
            if let workspace { NavigationStack { SquareWorkspaceView(coordinator: workspace, initialPostID: id, initialLane: contentGeneration == .communityV1 ? .communityV1 : .legacy) }.id(workspace.session) }
        }.cySheet(detents: [.large]) }
        .sheet(item: deletionBinding) { item in Group {
            if let deletion {
                SquareDeletionConfirmView(target: item.target, excerpt: SquareDeletionConfirmView.excerpt(post?.contents), coordinator: deletion)
            }
        }.cySheet() }
        .onChange(of: deletion?.phase) { _, phase in
            // A confirmed comment deletion refreshes the thread; a deleted post leaves no stale body on screen.
            if case .done(let target)? = phase { if case .post = target { post = nil; comments = SquareCommentPagination() } else { Task { await reload() } } }
        }
        .onChange(of: key) { _, _ in deletion?.retire() }
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
            onDoubleTapLike: actions == nil ? nil : { post in self.openReviewed(.init(purpose: .like, target: .post(post.id), text: "")) },
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
    /// Mini-program `actions`: like, comment and favourite with their counts. Favourite only where it can work.
    private func postActions(_ post: SquarePost, actions: SocialActionCoordinator) -> some View {
        HStack(spacing: 28) {
            Button { editor = .init(purpose: .like, target: .post(post.id), text: "") } label: {
                Label { Text(verbatim: SquareCountDisplay.text(post.likeCount)).contentTransition(reduceMotion ? .opacity : .numericText()) } icon: { Image(systemName: post.isLiked == 1 ? "heart.fill" : "heart").symbolEffect(.bounce, options: .nonRepeating, isActive: !reduceMotion && post.isLiked == 1) }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: post.isLiked)
            .tint(post.isLiked == 1 ? .red : .primary)
            .accessibilityLabel(post.likeCount.map { Text("square.xcx.likesA11y \($0)") } ?? Text(verbatim: SquareCountDisplay.unknownMark)).accessibilityAddTraits(post.isLiked == 1 ? .isSelected : []).accessibilityIdentifier("square.detail.like")
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
            if post.generation.showsBookmark { // C-S11: the one Core rule for 收藏
                Button { editor = .init(purpose: .bookmark, target: .post(post.id), text: ""); editor?.enabled = post.isBookmarked != 1 } label: { Image(systemName: post.isBookmarked == 1 ? "star.fill" : "star").symbolEffect(.bounce, options: .nonRepeating, isActive: !reduceMotion && post.isBookmarked == 1) }
                    .tint(post.isBookmarked == 1 ? CYColor.warningText : .primary).accessibilityAddTraits(post.isBookmarked == 1 ? .isSelected : []) // C-S2: saved state shows
                    .accessibilityLabel(Text(LocalizedStringKey(post.isBookmarked == 1 ? "square.bookmark.remove" : "square.bookmark.add"))).accessibilityHint(Text("social.editor.bookmark")).accessibilityIdentifier("square.detail.bookmark")
            }
            // Mini `act-share` sits right after the other actions (owner 2026-11-09, Threads-style).
            if let route = makeShareRoute(for: post) {
                Button {
                    shareRoute = route
                    MiniProgramAnalytics.track(analytics, "content_share", bizType: "square", bizID: MiniProgramAnalytics.bizID(post.id), pagePath: "/pages/square/detail/index")
                } label: { Image(systemName: "paperplane") }
                    .tint(.primary)
                    .accessibilityLabel(Text("share.entry", tableName: "SocialParity")).accessibilityIdentifier("square.detail.share")
            }
            Spacer(minLength: 0)
        }
        .buttonStyle(.borderless).cyText(.body).labelStyle(.titleAndIcon)
        .frame(minHeight: 44)
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
                }
            }
            if post.generation != .unknown {
                Button("square.report", systemImage: "exclamationmark.bubble") {
                    if post.generation == .legacySquare { editor = .init(purpose: .report, target: .post(post.id), text: "") }
                    else if let target = try? SquareReportTarget(post: post) { reportTarget = .init(target: target) }
                }
                .accessibilityLabel(Text("square.report"))
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
            Text("square.xcx.commentDeleted").cyText(.bodyCompact).foregroundStyle(.secondary)
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
    /// Mini-program comment row: avatar, name and time; the text; then like count, reply and the overflow actions.
    private func liveCommentRow(_ comment: SquareComment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            SquareAuthorAvatar(source: comment.avatar, size: 32)
                .overlay(alignment: .bottomTrailing) { commentFollowBadge(comment) }
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    if let accountReader, comment.memberID > 0 {
                        NavigationLink { SocialPublicProfileView(memberID: comment.memberID, reader: accountReader, squareReader: reader, actions: actions) } label: { commentAuthor(comment) }
                            .buttonStyle(.borderless).tint(.primary)
                    } else {
                        commentAuthor(comment)
                    }
                    Spacer(minLength: 8)
                    if !comment.createTime.isEmpty { SquareXcxRelativeTime(createTime: comment.createTime, now: Date()).cyText(.meta).foregroundStyle(.secondary) }
                }
                if let name = comment.replyName(in: comments.items) {
                    Text("square.replyingTo \(name)").cyText(.meta).foregroundStyle(.secondary)
                }
                if let contents = comment.contents { Text(verbatim: contents).textSelection(.enabled) }
                NativeMediaGalleryEntry(sources: comment.images, scope: reader.scope, titleKey: "media.destination.squareImages")
                HStack(spacing: 20) {
                    let likeLabel = Label { Text(verbatim: SquareCountDisplay.text(comment.likeCount)) } icon: { Image(systemName: comment.isLiked == 0 ? "heart" : "heart.fill") }
                        .cyText(.meta).foregroundStyle(comment.isLiked == 0 ? AnyShapeStyle(.secondary) : AnyShapeStyle(CYColor.dangerText))
                    if let actions, actions.identity.accountID != nil {
                        // C-S4 (MP comment row): like and 回复 act inline; the ⋯ menu keeps block / delete.
                        Button { editor = .init(purpose: .commentLike, target: .comment(postID: id, commentID: comment.id), text: "", enabled: comment.isLiked == 0) } label: { likeLabel }
                            .buttonStyle(.borderless)
                            .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget).contentShape(Rectangle())
                            .accessibilityLabel(Text(comment.isLiked == 0 ? LocalizedStringKey("square.like") : LocalizedStringKey("square.unlike")))
                            .accessibilityValue(comment.likeCount.map { Text("square.xcx.likesA11y \($0)") } ?? Text(verbatim: SquareCountDisplay.unknownMark))
                            .accessibilityIdentifier("square.comment.like.\(comment.id)")
                        if post?.viewerCanComment == true {
                            Button { editor = .init(purpose: .comment, target: .comment(postID: id, commentID: comment.id), text: "") } label: {
                                Text("social.reply").cyText(.meta).foregroundStyle(.secondary)
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
                        Button { reportComment(comment) } label: { Text("square.report").cyText(.meta).foregroundStyle(.secondary) }
                            .buttonStyle(.borderless)
                            .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget).contentShape(Rectangle()) // C-S5
                            .accessibilityLabel(Text("square.report"))
                            .accessibilityIdentifier("squareReport.commentEntry.\(comment.id)")
                    }
                    Spacer(minLength: 0)
                    if let actions, actions.identity.accountID != nil,
                       SquareAuthorSafety.showsBlockEntry(authorMemberID: comment.memberID, viewerMemberID: actions.identity.accountID)
                        || (comment.memberID == actions.identity.accountID && post.flatMap { SquareDeletionTarget(post: $0, comment: comment) }.map { deletion?.isAllowed($0) == true } == true) {
                        // ⋯ only when it holds something (block / delete); like and 回复 are inline (C-S4).
                        Menu {
                            if SquareAuthorSafety.showsBlockEntry(authorMemberID: comment.memberID, viewerMemberID: actions.identity.accountID) {
                                Button("square.block", systemImage: "hand.raised") {
                                    blockTarget = .init(memberID: comment.memberID, authorName: comment.nickname)
                                }
                                    .accessibilityIdentifier("square.block.commentEntry.\(comment.id)")
                            }
                            if comment.memberID == actions.identity.accountID, let post,
                               let target = SquareDeletionTarget(post: post, comment: comment), deletion?.isAllowed(target) == true {
                                Button("square.xcx.delete.comment", systemImage: "trash", role: .destructive) { deletion?.prepare(target) }
                                    .accessibilityIdentifier("square.delete.commentEntry.\(comment.id)")
                            }
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
        if let nickname = comment.nickname, !nickname.isEmpty { Text(verbatim: nickname).cyText(.bodyMedium) }
        else { Text("square.unknownAuthor").cyText(.bodyMedium) }
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
    private func reload() async {
        generation += 1
        let operation = generation, captured = key
        post = nil; comments = SquareCommentPagination(); detailIssue = nil; commentIssue = nil
        detailLoading = false; commentsLoading = false; loadedKey = captured
        guard reader.isConfigured else { return }
        detailLoading = true
        // Independent read states: a comment failure does not discard a successfully loaded post.
        async let detailTask: Void = loadDetail(operation: operation, captured: captured)
        async let commentTask: Void = loadComments(operation: operation, captured: captured)
        _ = await (detailTask, commentTask)
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
                .cyText(.sectionTitle)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if !signedIn {
                Text("cooperation.login").cyText(.body).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            } else {
                switch phase {
                case .loading: CYSkeleton().accessibilityLabel(Text(verbatim: locale.pick("读取中", "Loading")))
                case .empty:
                    Text(verbatim: locale.pick("还没有你发布的广场帖", "You have no square posts")).cyText(.body).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                case .failed:
                    Text(verbatim: locale.pick("列表没有读出来，请重试", "The list did not load. Try again.")).cyText(.body).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    CYPillButton(verbatim: locale.pick("重试", "Try again"), style: .secondary, fullWidth: dynamicTypeSize.isAccessibilitySize) { Task { await reload() } }
                case .ready:
                    if let highlightedPostID, !ids.contains(highlightedPostID) {
                        Text(verbatim: locale.pick("这篇已经不在你的列表里", "This post is no longer in your list")).cyText(.meta).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
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
                .cyText(.body)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: CYSpacing.sm)
            }
            CYPillButton(
                verbatim: locale.pick("删除", "Delete"),
                style: .secondary,
                fullWidth: dynamicTypeSize.isAccessibilitySize,
                compact: !dynamicTypeSize.isAccessibilitySize
            ) {
                Task { await delete(id) }
            }
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
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            if post.isTopicTemplate {
                Text("square.xcx.templateBadge").cyText(.caption, weight: .bold).foregroundStyle(CYColor.textSecondary)
            }
            if let title = post.referenceTitle { Text(verbatim: title).cyText(.cardTitle).cyWrapText() }
            if post.isTopicTemplate, let topicID = post.topicID, topicID > 0, TopicTemplateUseFactory.isLive {
                TopicTemplateUseSection(templateID: topicID, scope: nil, readOnly: false) { copiedDestination?($0) }
            }
            SquareRelatedTopicLink(post: post, source: source, squareReader: reader, titleKey: "square.play.try", onSelect: onSelectTopic)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("square.detail.playCard")
    }
}

/// C-S3: MP square/detail error shells — 社区暂未开放 / 没有找到这条帖文 / 这条帖文暂不可用 / 动态加载失败 (+ 重试),
/// each with 返回上一页.
struct SquareDetailIssueView: View {
    let error: Error
    let retry: () -> Void
    let back: () -> Void
    private enum Kind { case closed, notFound, unavailable, failed }
    private var kind: Kind {
        switch error as? SquareReadFailure {
        case .communityRequired: return .closed
        case .unavailable: return .unavailable
        case .server(let code, _) where code == 404: return .notFound
        default: return .failed
        }
    }
    private var titleKey: LocalizedStringKey {
        switch kind {
        case .closed: return "square.detail.closed"
        case .notFound: return "square.detail.notFound"
        case .unavailable: return "square.detail.unavailable"
        case .failed: return "square.detail.failed"
        }
    }
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Label(titleKey, systemImage: kind == .failed ? "exclamationmark.circle" : "doc.text.magnifyingglass")
                    .cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                    .accessibilityIdentifier("square.error")
                if kind == .failed, let failure = error as? SquareReadFailure, case let .server(_, message) = failure, let message, !message.isEmpty {
                    Text(verbatim: message).cyText(.meta).foregroundStyle(CYColor.textSecondary).textSelection(.enabled)
                }
                if kind == .failed {
                    Button("square.retry", action: retry).buttonStyle(.cySecondary(fullWidth: true)).accessibilityIdentifier("square.retry")
                }
                Button("square.detail.back", action: back).buttonStyle(.cySecondary(fullWidth: true))
                    .accessibilityIdentifier("square.detail.back")
            }
            .padding(.vertical, CYSpacing.sm)
        }
    }
}
