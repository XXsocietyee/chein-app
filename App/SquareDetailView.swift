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
    @Environment(\.squareRelatedTopic) private var relatedTopicContext
    @Environment(\.squareDeletion) private var deletion
    @Environment(\.squareShareLink) private var shareLink
    @Environment(\.squareAuthorFollowState) private var followState
    @Environment(\.analyticsEventClient) private var analytics
    @State private var shareRoute: ShareRoute?
    private struct ShareRoute: Identifiable { let id = UUID(); let payload: CYSquareSharePayload; let url: URL }
    @State private var showsAuthorProfile = false
    @State private var relatedTopic: SquareRelatedTopicSelection?
    @State private var reportTarget: ReportRoute?
    private struct ReportRoute: Identifiable { let id = UUID(); let target: SquareReportTarget }
    @State private var showsWorkspaceEdit = false
    @State private var blockNotice = false
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
            if reader.isOfflineExample { Text("square.offlineExample").font(.caption) }
            if !reader.isConfigured { SquareIssueView(error: APIError.notConfigured) }
            else if loadedKey != key { CYSkeleton() }
            else {
                if detailLoading { CYSkeleton() }
                if let detailIssue { SquareIssueView(error: detailIssue) { Task { await reload() } } }
                if let post {
                    Section {
                        SquarePostContent(post: post, mediaScope: reader.scope, showsCounts: actions?.identity.accountID == nil,
                                          avatarMenuItems: avatarMenuItems(post), onAvatarPick: { pickAvatarItem($0, post: post) }).accessibilityIdentifier("square.detailPost")
                        if !post.videos.isEmpty { SquarePostVideoList(videos: post.videos) }
                        SquareRelatedTopicLink(post: post, source: .init(id: id, generation: contentGeneration), squareReader: reader) { relatedTopic = $0 }
                        // Mini `components/route-map`: live route only with a provider; the post's own snapshot is already in the gallery.
                        if let topicID = post.topicID, topicID > 0 { CYSquareRouteMapCard(topicID: topicID) }
                        if let actions, actions.identity.accountID != nil {
                            postActions(post, actions: actions)
                        }
                        if post.memberID == 0 {
                            Text(verbatim: "—")
                                .font(CYTypography.body)
                                .foregroundStyle(CYColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("square.author.unknown")
                        } else if let viewer = actions?.identity.accountID, viewer == post.memberID {
                            CreativeSquareAuthorDeleteSection(signedIn: reader.isSignedIn, highlightedPostID: post.id, load: { try await reader.ownCreativeSquareIDs() }, remove: { try await reader.deleteOwnCreativeSquare(postID: $0) })
                        }
                        if let accountReader, post.memberID > 0 {
                            NavigationLink { SocialPublicProfileView(memberID: post.memberID, reader: accountReader, squareReader: reader, actions: actions) } label: { Label("social.viewAuthor", systemImage: "person.crop.circle") }
                                .accessibilityIdentifier("social.viewAuthor")
                        }
                    }.cyMiniCardRow()
                }
                // Detail failure never renders orphan comments without their post context.
                if post != nil {
                    Section("square.comments") {
                        if let commentIssue { SquareIssueView(error: commentIssue) { Task { await loadComments(operation: generation, captured: key) } } }
                        ForEach(SquareComment.threaded(comments.items)) { comment in
                            commentRow(comment).accessibilityIdentifier("square.comment.\(comment.id)")
                        }
                        if commentsLoading { CYSkeleton() }
                        else if comments.items.isEmpty && commentIssue == nil {
                            Text(LocalizedStringKey(SquareDetailPageModel.emptyCommentsTitleKey))
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("square.noComments")
                        }
                        if !commentsLoading && comments.hasMore && commentIssue == nil {
                            CYPillButton("square.moreComments", style: .secondary) { Task { await loadComments(operation: generation, captured: key) } }.accessibilityIdentifier("square.moreComments")
                        }
                    }.cyMiniCardRow()
                }
            }
        }
        // Mini-program `.detail.theme-dark`: ink ground, elevated post card and comment card (radius 16, 12pt apart).
        .cyMiniListScreen()
        .appNavigationTitle("square.detail")
        .toolbar {
            // Mini-program `ph-more`: edit, delete and report live in one overflow menu.
            if let post, let actions, actions.identity.accountID != nil, loadedKey == key {
                ToolbarItem(placement: .topBarTrailing) { postMenu(post, actions: actions) }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let post, let actions, actions.identity.accountID != nil, loadedKey == key {
                // Source sticky bar "留下你的评论"; opens the existing reviewed comment editor.
                Button { editor = .init(purpose: .comment, target: .post(post.id), text: "") } label: {
                    Label("square.xcx.commentPlaceholder", systemImage: "text.bubble")
                        .font(CYTypography.body).foregroundStyle(CYColor.textSecondary)
                        .padding(.horizontal, CYSpacing.lg)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .background(Capsule().fill(CYNight.ink2))
                        .overlay(Capsule().strokeBorder(LinearGradient(colors: [CYNight.glassEdgeTop, CYNight.glassEdgeBottom], startPoint: .top, endPoint: .bottom), lineWidth: 1))
                        .contentShape(Capsule())
                }.buttonStyle(.plain).disabled(!post.viewerCanComment).opacity(post.viewerCanComment ? 1 : 0.5)
                    .padding(.horizontal, CYSpacing.pageHorizontal).padding(.vertical, CYSpacing.sm)
                    .background(.bar).accessibilityIdentifier("square.commentBar")
            }
        }
        .navigationDestination(item: $cloudProfile) { member in
            if let accountReader { SocialPublicProfileView(memberID: member.id, reader: accountReader, squareReader: reader, actions: actions) }
        }
        .navigationDestination(item: $relatedTopic) { selected in
            if let context = relatedTopicContext {
                SquareRelatedTopicDestination(selection: selected, squareReader: reader, topicReader: context.reader)
            } else { SocialIssueView(error: SocialActionBlock.changed) }
        }
        .onChange(of: key) { _, _ in relatedTopic = nil }
        .onChange(of: relatedTopicContext?.reader.scope) { _, _ in relatedTopic = nil }
        .sheet(item: $editor, onDismiss: { applyFollowReceipt() }) { item in
            if let actions { NavigationStack { SocialActionEditorView(purpose: item.purpose, target: item.target, coordinator: actions, initialText: item.text, contentGeneration: contentGeneration, initialEnabled: item.enabled) }.id(actions.identity) }
        }
        .sheet(item: $shareRoute) { route in CYSquareShareSheet(payload: route.payload, url: route.url) }
        .navigationDestination(isPresented: $showsAuthorProfile) {
            if let accountReader, let post, post.memberID > 0 {
                SocialPublicProfileView(memberID: post.memberID, reader: accountReader, squareReader: reader, actions: actions)
            }
        }
        .onChange(of: key) { _, _ in shareRoute = nil; showsAuthorProfile = false }
        .alert(Text("square.block.title"), isPresented: $blockNotice) {
            Button("square.block.ok", role: .cancel) { }
        } message: { Text("square.block.notAvailable") }
        .sheet(item: $reportTarget) { item in
            NavigationStack { SquareReportView(target: item.target, context: reportContext) }
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showsWorkspaceEdit) {
            if let workspace { NavigationStack { SquareWorkspaceView(coordinator: workspace, initialPostID: id, initialLane: contentGeneration == .communityV1 ? .communityV1 : .legacy) }.id(workspace.session) }
        }
        .sheet(item: deletionBinding) { item in
            if let deletion { NavigationStack { SquareDeletionConfirmView(target: item.target, excerpt: SquareDeletionConfirmView.excerpt(post?.contents), coordinator: deletion) }.presentationDetents([.medium]) }
        }
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
            if post.generation == .communityV1 {
                Button { editor = .init(purpose: .bookmark, target: .post(post.id), text: "") } label: { Image(systemName: "star") }
                    .tint(.primary)
                    .accessibilityLabel(Text("social.editor.bookmark")).accessibilityIdentifier("square.detail.bookmark")
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
        .buttonStyle(.borderless).font(.body).labelStyle(.titleAndIcon)
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
                .accessibilityIdentifier("squareReport.postEntry")
            }
            if SquareAuthorSafety.showsBlockEntry(authorMemberID: post.memberID, viewerMemberID: actions.identity.accountID) {
                Button("square.block", systemImage: "hand.raised") { blockNotice = true }
                    .accessibilityIdentifier("square.block.postEntry")
            }
        } label: {
            Label("social.actions", systemImage: "ellipsis.circle").labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityIdentifier("social.post.actions")
    }
    @ViewBuilder private func commentRow(_ comment: SquareComment) -> some View {
        if comment.lifecycle == "DELETED" {
            // Source deleted-row placeholder; the removed body is never shown.
            Text("square.xcx.commentDeleted").font(.footnote).foregroundStyle(.secondary)
                .padding(.leading, comment.parentID == nil ? 0 : 12)
        } else { liveCommentRow(comment) }
    }
    /// Mini-program comment row: avatar, name and time; the text; then like count, reply and the overflow actions.
    private func liveCommentRow(_ comment: SquareComment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            SquareAuthorAvatar(source: comment.avatar, size: 32)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    if let accountReader, comment.memberID > 0 {
                        NavigationLink { SocialPublicProfileView(memberID: comment.memberID, reader: accountReader, squareReader: reader, actions: actions) } label: { commentAuthor(comment) }
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
                HStack(spacing: 20) {
                    Label { Text(verbatim: SquareCountDisplay.text(comment.likeCount)) } icon: { Image(systemName: comment.isLiked == 0 ? "heart" : "heart.fill") }
                        .font(.caption).foregroundStyle(.secondary)
                        .accessibilityLabel(comment.likeCount.map { Text("square.xcx.likesA11y \($0)") } ?? Text(verbatim: SquareCountDisplay.unknownMark))
                    // Mini-program comment row keeps 举报 visible beside the like count, not inside the overflow.
                    if let actions, actions.identity.accountID != nil, comment.generation != .unknown {
                        Button { reportComment(comment) } label: { Text("square.report").font(.caption).foregroundStyle(.secondary) }
                            .buttonStyle(.borderless)
                            .frame(minHeight: CYSpacing.minTouchTarget)
                            .accessibilityIdentifier("squareReport.commentEntry.\(comment.id)")
                    }
                    Spacer(minLength: 0)
                    if let actions, actions.identity.accountID != nil {
                        Menu {
                            if post?.viewerCanComment == true {
                                Button("social.reply", systemImage: "arrowshape.turn.up.left") { editor = .init(purpose: .comment, target: .comment(postID: id, commentID: comment.id), text: "") }
                            }
                            Button(comment.isLiked == 0 ? LocalizedStringKey("square.like") : LocalizedStringKey("square.unlike"), systemImage: comment.isLiked == 0 ? "heart" : "heart.slash") { editor = .init(purpose: .commentLike, target: .comment(postID: id, commentID: comment.id), text: "", enabled: comment.isLiked == 0) }
                            if SquareAuthorSafety.showsBlockEntry(authorMemberID: comment.memberID, viewerMemberID: actions.identity.accountID) {
                                Button("square.block", systemImage: "hand.raised") { blockNotice = true }
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
                .font(CYTypography.sectionTitle)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if !signedIn {
                Text("cooperation.login").font(CYTypography.body).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            } else {
                switch phase {
                case .loading: CYSkeleton().accessibilityLabel(Text(verbatim: locale.pick("读取中", "Loading")))
                case .empty:
                    Text(verbatim: locale.pick("还没有你发布的广场帖", "You have no square posts")).font(CYTypography.body).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                case .failed:
                    Text(verbatim: locale.pick("列表没有读出来，请重试", "The list did not load. Try again.")).font(CYTypography.body).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
                    CYPillButton(verbatim: locale.pick("重试", "Try again"), style: .secondary, fullWidth: dynamicTypeSize.isAccessibilitySize) { Task { await reload() } }
                case .ready:
                    if let highlightedPostID, !ids.contains(highlightedPostID) {
                        Text(verbatim: locale.pick("这篇已经不在你的列表里", "This post is no longer in your list")).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary).fixedSize(horizontal: false, vertical: true)
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
                .font(CYTypography.body)
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
