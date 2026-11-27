import SwiftUI

/// Additive host context. Session closures reuse the host's ClubReadIdentity epoch.
/// Factory is absent by default; constructing a context never enables writes/uploads.
@MainActor
struct ClubCommunityContext {
    let service: ClubCommunityService
    let currentSession: () throws -> ClubCommunitySession
    let coordinator: ClubCommunityCoordinator?
    let evidence: (Int, ClubCommunityPost?, ClubCommunityComment?) async throws -> ClubCommunityEvidence
    var images: any ClubCommunityImageUploading = ClubCommunityDisabledImages()
    var postImagePicker: ClubPostImagePickerContext = .disabled
    /// CLB-G05: `/api/registration/my-joined` for 「带上一次游玩记录」. Nil hides the row.
    var loadPostRefs: (() async throws -> [ClubPostRefOption])? = nil
    /// CLB-G10: `POST /api/user/follow/action` `{follow_member_id, follow: 1}`. Nil hides the 「+」 pill.
    var followAuthor: ((Int) async throws -> Void)? = nil
    var onAuthor: ((Int) -> Void)? = nil
    var onTopic: ((Int) -> Void)? = nil
    var feedSourceScope: () -> ClubCommunityFeedSourceContext? = { nil }
    var feedSourceDestination: ((Int, ClubCommunityFeedSourceContext) -> AnyView?)? = nil
    /// Relation / discover creative-square lane. Nil leaves the club feed unchanged.
    /// The closure's cursor is nil on the first page. A throw fails the whole feed.
    var creativeSquareLane: (@MainActor (Int?) async throws -> RelationCreativeSquareLane)? = nil
}

@MainActor
final class ClubCommunityViewModel: ObservableObject {
    let context: ClubCommunityContext
    @Published private(set) var snapshot: ClubCommunitySnapshot?
    @Published private(set) var imageReadScope = UUID()
    @Published private(set) var feedSourceReadScope: ClubCommunityFeedSourceContext?
    @Published private(set) var loading = false
    @Published var notice: String?
    @Published var review: ClubCommunityReview?
    @Published private(set) var busy = false
    @Published private(set) var pendingRecord: ClubCommunityPendingRecord?
    /// CLB-G10: authors followed from a post card in this session (MP `onFollowPost` flips every post by the author).
    @Published private(set) var followedAuthors: Set<Int> = []
    private var followPending: Set<Int> = []
    /// MP `pages/club/detail/index.js:3224-3243`: optimistic follow, roll back on failure, show the server `msg`
    /// (else 关注没成功 / 网络错误，请重试).
    func followAuthor(_ memberID: Int) async {
        guard memberID > 0, let follow = context.followAuthor, !followPending.contains(memberID) else { return }
        followPending.insert(memberID)
        followedAuthors.insert(memberID)
        defer { followPending.remove(memberID) }
        do {
            try await follow(memberID)
        } catch let refusal as MPGapServerRefusal {
            followedAuthors.remove(memberID)
            notice = refusal.message.flatMap { $0.isEmpty ? nil : $0 } ?? "club.follow.failed"
        } catch {
            followedAuthors.remove(memberID)
            notice = "club.follow.networkFailed"
        }
    }
    private var generation: UInt64 = 0
    private var postCursor = ClubCommunityReadCursor()
    private var feedCursor = ClubCommunityFeedCursor()
    var canLoadMorePosts: Bool { postCursor.hasMore && !loading && !busy }
    /// Cross-club `scope:"all"` feed. A club-scoped list uses `canLoadMorePosts` instead.
    var canLoadMoreFeed: Bool { feedCursor.hasMore && !loading && !busy }
    private var identity: ClubReadIdentity?
    private var pendingDraft: (ClubCommunityOperation, Int, ClubCommunityPost?, ClubReadIdentity)?
    func stageDraft(_ operation: ClubCommunityOperation, clubID: Int, post: ClubCommunityPost?) {
        guard let identity = try? context.currentSession().identity else { return }
        pendingDraft = (operation, clubID, post, identity)
    }
    func reviewPendingDraft() async {
        guard let draft = pendingDraft else { return }; pendingDraft = nil
        guard (try? context.currentSession().identity) == draft.3 else { return }
        await prepare(draft.0, clubID: draft.1, post: draft.2)
    }
    init(context: ClubCommunityContext) { self.context = context }
    func suspend() {
        generation &+= 1; pendingDraft = nil; review = nil; loading = false
        context.coordinator?.cancel()
    }
    func invalidate() {
        suspend(); postCursor.reset(); feedCursor.reset(); imageReadScope = UUID(); snapshot = nil; notice = nil; pendingRecord = nil
    }
    private func pendingEvidenceProbe(
        clubID: Int,
        post: ClubCommunityPost? = nil,
        comment: ClubCommunityComment? = nil
    ) -> ClubCommunityEvidence? {
        guard clubID > 0, let session = try? context.currentSession(), session.identity.isSignedIn else { return nil }
        return ClubCommunityEvidence(
            identity: session.identity,
            clubID: clubID,
            joined: false,
            owner: false,
            administrator: false,
            post: post,
            comment: comment
        )
    }
    /// Recovers any durable pending record for `(clubID, post, comment)` on page entry or after restart.
    @discardableResult
    func recoverPendingState(
        clubID: Int,
        post: ClubCommunityPost? = nil,
        comment: ClubCommunityComment? = nil
    ) -> ClubCommunityPendingRecord? {
        guard let coordinator = context.coordinator,
              let probe = pendingEvidenceProbe(clubID: clubID, post: post, comment: comment) else {
            pendingRecord = nil
            return nil
        }
        let locked = coordinator.recoverPendingLock(for: probe)
        let record = coordinator.pendingRecord(for: probe)
        pendingRecord = record
        if locked || record != nil {
            notice = "club.community.unknown"
        }
        return record
    }
    /// Queries the authoritative same-request outcome for an unresolved pending operation on `(clubID, post, comment)`.
    /// Never generates a new request ID, never re-submits the write, and never infers success from list reads.
    func reconcilePending(
        clubID: Int,
        post: ClubCommunityPost? = nil,
        comment: ClubCommunityComment? = nil,
        refresh: ClubCommunityRead
    ) async {
        guard !busy,
              let coordinator = context.coordinator,
              let session = try? context.currentSession(),
              let probe = pendingEvidenceProbe(clubID: clubID, post: post, comment: comment) else {
            notice = "club.community.offline"
            return
        }
        let ticket = generation
        func isCurrent(_ expectedGeneration: UInt64) -> Bool {
            !Task.isCancelled && generation == expectedGeneration &&
                (try? context.currentSession()) == session
        }
        guard isCurrent(ticket) else { return }
        busy = true
        defer { busy = false }
        do {
            let outcome = try await coordinator.reconcilePendingOperation(for: probe)
            guard isCurrent(ticket) else { return }
            pendingRecord = coordinator.pendingRecord(for: probe)
            switch outcome {
            case .acknowledgedRefreshRequired:
                let refreshTicket = generation &+ 1
                await load(refresh)
                guard isCurrent(refreshTicket) else { return }
                if snapshot != nil { notice = "club.community.refreshRequired" }
            case .moderationQueued:
                let refreshTicket = generation &+ 1
                await load(refresh)
                guard isCurrent(refreshTicket) else { return }
                if snapshot != nil { notice = "club.community.queued" }
            case .rejected:
                notice = "club.community.actionUnavailable"
            default:
                notice = "club.community.unknown"
            }
        } catch {
            guard isCurrent(ticket) else { return }
            pendingRecord = coordinator.pendingRecord(for: probe)
            notice = "club.community.unknown"
        }
    }
    func loadMorePosts(clubID: Int) async {
        guard canLoadMorePosts, postCursor.clubID == clubID, let beforeID = postCursor.beforeID else { return }
        await load(.posts(clubID: clubID, beforeID: beforeID, limit: 20))
    }
    func loadMoreFeed() async {
        guard canLoadMoreFeed, let beforeID = feedCursor.beforeID else { return }
        await load(.feed(limit: 20, beforeID: beforeID))
    }
    func load(_ operation: ClubCommunityRead) async {
        let keepsVisibleFeed: Bool
        if case .feed(_, let beforeID) = operation { keepsVisibleFeed = beforeID != nil } else { keepsVisibleFeed = false }
        generation &+= 1; let ticket = generation
        imageReadScope = UUID()
        if !keepsVisibleFeed { snapshot = nil }
        loading = true; notice = nil
        feedSourceReadScope = nil
        let sourceScope = context.feedSourceScope()
        do {
            let session = try context.currentSession(); identity = session.identity
            let result: ClubCommunitySnapshot
            if case let .feed(limit, beforeID) = operation {
                let lane: RelationCreativeSquareLane?
                if let fetch = context.creativeSquareLane, beforeID == nil || feedCursor.communityHasMore {
                    lane = try await fetch(beforeID == nil ? nil : feedCursor.communityCursor)
                } else {
                    lane = nil
                }
                result = try await context.service.readDiscoverFeed(limit: limit, beforeID: beforeID, session: session, community: lane) {
                    guard try self.context.currentSession() == session else { throw ClubCommunityFailure.stale }
                }
            } else {
                result = try await context.service.read(operation, session: session) {
                    guard try self.context.currentSession() == session else { throw ClubCommunityFailure.stale }
                }
            }
            guard ticket == generation, try context.currentSession() == session else { return }
            if case .posts = operation { snapshot = try postCursor.accept(result, identity: session.identity) }
            else if case .feed = operation { snapshot = try feedCursor.accept(result, identity: session.identity) }
            else { snapshot = result }
            if case .feed = operation, context.feedSourceScope() == sourceScope {
                feedSourceReadScope = sourceScope
            }
            loading = false
        } catch {
            guard ticket == generation, (try? context.currentSession().identity) == identity else { return }; loading = false; notice = "club.community.loadError"
        }
    }
    func prepare(_ operation: ClubCommunityOperation, clubID: Int, post: ClubCommunityPost? = nil, comment: ClubCommunityComment? = nil) async {
        guard !busy, let coordinator = context.coordinator else { notice = "club.community.offline"; return }
        if recoverPendingState(clubID: clubID, post: post, comment: comment) != nil {
            notice = "club.community.unknown"
            return
        }
        busy = true; defer { busy = false }
        do {
            let session = try context.currentSession(), ticket = generation
            let evidence = try await context.evidence(clubID, post, comment)
            guard ticket == generation, try context.currentSession() == session else { throw ClubCommunityFailure.stale }
            let candidate = try await coordinator.prepare(operation, evidence: evidence)
            guard ticket == generation, try context.currentSession() == session else { coordinator.cancel(); throw ClubCommunityFailure.stale }
            review = candidate
        } catch {
            _ = recoverPendingState(clubID: clubID, post: post, comment: comment)
            if notice != "club.community.unknown" {
                notice = "club.community.actionUnavailable"
            }
        }
    }
    /// The visible confirmation authorizes only its immutable original review.
    @discardableResult
    func confirm(expected: ClubCommunityReview, refresh: ClubCommunityRead) async -> Bool {
        guard !busy, let review, review == expected, let coordinator = context.coordinator,
              let session = try? context.currentSession(), session.identity == expected.evidence.identity else { return false }
        let ticket = generation
        func isCurrent(_ expectedGeneration: UInt64) -> Bool {
            !Task.isCancelled && generation == expectedGeneration &&
                (try? context.currentSession()) == session
        }
        guard isCurrent(ticket) else { return false }
        let targetClubID = review.evidence.clubID
        let targetPost = review.evidence.post
        let targetComment = review.evidence.comment
        busy = true; self.review = nil
        defer { busy = false }
        do {
            try await coordinator.confirm(review)
            guard isCurrent(ticket) else { return false }
            pendingRecord = coordinator.pendingRecord(for: review.evidence)
            let queued = coordinator.outcome == .moderationQueued
            let refreshTicket = generation &+ 1
            await load(refresh)
            guard isCurrent(refreshTicket) else { return false }
            // Original write success is separate from current read authority/availability.
            // Do not claim refreshed content exists when load cleared it and failed.
            if snapshot != nil { notice = queued ? "club.community.queued" : "club.community.refreshRequired" }
        } catch {
            guard isCurrent(ticket) else { return false }
            _ = recoverPendingState(clubID: targetClubID, post: targetPost, comment: targetComment)
            notice = coordinator.outcome == .unknownLocked ? "club.community.unknown" : "club.community.actionUnavailable"
        }
        return true
    }
    func cancelReview() { review = nil; context.coordinator?.cancel() }
}

@MainActor
struct ClubCommunityEntry: View {
    let clubID: Int
    let identity: ClubReadIdentity
    let context: ClubCommunityContext
    /// CLB-detail-31 (MP detail js:744, 1956-1959): a `postId` link opens the feed and scrolls to that post.
    var focusPostID: Int? = nil
    @State private var opensFocusedPost = false
    var body: some View {
        NavigationLink {
            ClubCommunityFeedView(context: context, identity: identity, clubID: clubID)
        } label: { Label("club.community.posts", systemImage: "text.bubble") }
            .accessibilityIdentifier("club.community.entry")
            .navigationDestination(isPresented: $opensFocusedPost) {
                ClubCommunityFeedView(context: context, identity: identity, clubID: clubID, focusPostID: focusPostID)
            }
            .task(id: focusPostID) { if focusPostID != nil { opensFocusedPost = true } }
    }
}

private struct ClubCommunityDestination: Hashable {
    enum Screen: Hashable { case detail, comments, history }
    let post: ClubCommunityPost
    let clubID: Int?
    let screen: Screen
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.post == rhs.post && lhs.clubID == rhs.clubID && lhs.screen == rhs.screen }
    func hash(into hasher: inout Hasher) { hasher.combine(post.id); hasher.combine(post.version); hasher.combine(clubID); hasher.combine(screen) }
}

@MainActor
struct ClubCommunityFeedView: View {
    let identity: ClubReadIdentity
    let clubID: Int?
    @StateObject private var model: ClubCommunityViewModel
    @State private var page = 1
    @State private var composing = false
    @State private var destination: ClubCommunityDestination?
    @State private var discussion = ClubPostDiscussionState()
    @State private var discussionItemID: String?
    @State private var sourceDestination: ClubCommunityFeedSource?
    @State private var toastMessage: LocalizedStringKey?
    @Environment(\.clubCustomerTopics) private var topics
    @Environment(\.clubPostPlayHost) private var discussionHost
    /// CLB-detail-31: scroll to this post once it is in the loaded feed (one time per appearance).
    private let focusPostID: Int?
    /// CLB-detail-14 (MP detail wxml:96-158): on the club page the feed sits inline under 帖文, so the page header and
    /// tab bar come in as leading sections of this List (the feed keeps its own navigation, refresh and sheets).
    private let leading: AnyView?
    @State private var didFocusPost = false
    init(context: ClubCommunityContext, identity: ClubReadIdentity, clubID: Int? = nil, focusPostID: Int? = nil,
         leading: AnyView? = nil) {
        self.identity = identity; self.clubID = clubID; self.focusPostID = focusPostID; self.leading = leading
        _model = StateObject(wrappedValue: ClubCommunityViewModel(context: context))
    }
    private var operation: ClubCommunityRead { clubID.map { .posts(clubID: $0, page: page) } ?? .feed(page: page) }
    /// CLB-detail-16: compose only for members and the owner (MP wxml:100); the server still enforces memberPostAllowed.
    @State private var canPost = false
    private var canCompose: Bool { clubID != nil && identity.isSignedIn && canPost }
    var body: some View {
        ScrollViewReader { proxy in
        List {
            if let leading { leading }
            if model.loading {
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(Text("club.community.loading"))
                }
            }
            if let notice = model.notice { Section { communityNotice(notice, identifier: "club.community.notice") } }
            if let pending = model.pendingRecord, let clubID { pendingLock(pending, clubID: clubID, identifierPrefix: "club.community") }
            if let snapshot = model.snapshot {
                if clubID == nil, snapshot.posts.isEmpty {
                    // Cross-club feed (发现 · 帖文): mini-program cy-empty shows one title, 还没有帖文.
                    ContentUnavailableView(LocalizedStringKey(ClubTabPresentation.feedEmptyKeys(clubCount: snapshot.clubCount).title),
                                           systemImage: "text.bubble")
                        .accessibilityIdentifier("clubTab.feed.emptyHint")
                } else if snapshot.clubCount == 0 {
                    ContentUnavailableView("club.community.joinFirst", systemImage: "person.3")
                } else if snapshot.posts.isEmpty {
                    // CLB-detail-15 (parity r2): MP 暂无帖文, with 入会后可发布 for viewers who cannot post yet.
                    ContentUnavailableView {
                        Label("club.community.empty", systemImage: "text.bubble")
                    } description: {
                        if clubID != nil && !canCompose { Text("club.community.emptyJoinHint") }
                    }
                }
                // CLB-detail-05: MP cy-club-pinned-notice, one line + chevron for the pinned 公告, opening the post.
                if let clubID, let pinned = snapshot.posts.first(where: { $0.pinned && $0.type == 2 }) {
                    Section {
                        Button { destination = .init(post: pinned, clubID: pinned.clubID ?? clubID, screen: .detail) } label: {
                            HStack {
                                Label {
                                    VStack(alignment: .leading) {
                                        Text("club.community.pinnedNotice").font(.subheadline).foregroundStyle(.secondary)
                                        Text(verbatim: pinned.content.isEmpty ? "—" : pinned.content).lineLimit(1)
                                    }
                                } icon: { Image(systemName: "pin.fill").foregroundStyle(.tint) }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary).accessibilityHidden(true)
                            }
                            .contentShape(Rectangle())
                        }
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("club.community.pinnedNotice")
                    }
                }
                ForEach(snapshot.feedItems) { item in
                    Section {
                        UGCBlockedFilterContainer(memberID: item.post.authorMemberID, authorName: item.post.nickname) {
                            feedItem(item, snapshot: snapshot)
                        }
                        .id(item.id)
                    }
                }
                // CLB-detail-15: the next page loads when the end of the list scrolls in (MP onReachBottom).
                // The same row pages the cross-club feed (`scope:"all"`, `beforeId`).
                if clubID == nil ? model.canLoadMoreFeed : model.canLoadMorePosts {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(Text("club.community.loading"))
                        .onAppear {
                            Task {
                                if let clubID { await model.loadMorePosts(clubID: clubID) }
                                else { await model.loadMoreFeed() }
                            }
                        }
                }
            }
            // CLB-detail-15: pull to refresh covers a loaded feed; the button is only the retry when nothing loaded.
            if (model.snapshot == nil && !model.loading) || writesUnavailable {
                Section {
                    if model.snapshot == nil, !model.loading {
                        Button("action.retry") { Task { await model.load(operation) } }
                            .disabled(model.busy)
                    }
                } footer: {
                    if writesUnavailable { Text("club.community.offline") }
                }
            }
        }
        .onChange(of: model.snapshot?.feedItems.map(\.id)) { _, ids in
            guard !didFocusPost, let focusPostID, let ids,
                  let target = model.snapshot?.feedItems.first(where: { $0.post.id == focusPostID }), ids.contains(target.id) else { return }
            didFocusPost = true
            withAnimation { proxy.scrollTo(target.id, anchor: .top) }
        }
        }
        .modifier(ClubCommunityPushedTitle(title: clubID == nil || leading != nil ? nil : LocalizedStringKey("club.community.posts")))
        .toolbar {
            if canCompose {
                ToolbarItem(placement: .primaryAction) {
                    Button { composing = true } label: { Label("club.community.create", systemImage: "square.and.pencil") }
                        .disabled(model.busy || model.pendingRecord != nil || model.context.coordinator?.permitsInjectedWrites != true)
                        .accessibilityIdentifier("club.community.compose")
                }
            }
        }
        .refreshable { await model.load(operation) }
        .background(alignment: .topLeading) { ClubPostDiscussionFixtureTraceView() }
        .navigationDestination(item: $destination) { target in
            switch target.screen {
            case .detail:
                ClubCommunityPostDetailView(
                    context: model.context,
                    identity: identity,
                    clubID: target.clubID,
                    post: target.post
                )
            case .comments:
                if let clubID = target.clubID { ClubCommunityCommentsView(context: model.context, identity: identity, clubID: clubID, post: target.post) }
            case .history:
                ClubCommunityHistoryView(context: model.context, identity: identity, postID: target.post.id)
            }
        }
        .navigationDestination(item: $sourceDestination) { selected in
            if currentFeedSource(selected),
               let target = model.context.feedSourceDestination?(selected.clubID, selected.context) {
                target
            } else {
                Color.clear.onAppear { if sourceDestination?.id == selected.id { sourceDestination = nil } }
            }
        }
        .onChange(of: model.context.feedSourceScope()) { _, _ in sourceDestination = nil }
        .onChange(of: sourceDestination) { old, new in
            if old != nil, new == nil, model.context.feedSourceScope() == old?.context,
               (try? model.context.currentSession().identity) == identity { Task { await model.load(operation) } }
        }
        .onChange(of: identity) { _, _ in destination = nil; sourceDestination = nil; discussion.close() }
        .onChange(of: destination) { oldValue, newValue in
            if oldValue != nil, newValue == nil, (try? model.context.currentSession().identity) == identity {
                Task {
                    await model.load(operation)
                    if let clubID { _ = model.recoverPendingState(clubID: clubID) }
                }
            }
        }
        .onChange(of: model.imageReadScope) { _, _ in sourceDestination = nil; discussion.close() }
        .onChange(of: topics.viewerRevision) { _, _ in discussion.close() }
        .task(id: identity) {
            model.invalidate()
            page = 1
            await model.load(operation)
            if let clubID { _ = model.recoverPendingState(clubID: clubID) }
            canPost = false
            if let clubID, let evidence = try? await model.context.evidence(clubID, nil, nil), evidence.identity == identity {
                canPost = evidence.allows(.create(content: "", images: []))
            }
        }
        .task(id: page) { await model.load(operation) }
        // Pushing a row destination must not remove the NavigationLink that owns it.
        // Identity changes still clear all private snapshots in the task above.
        .onDisappear { model.suspend() }
        .cySheet(isPresented: $composing, onDismiss: { Task { await model.reviewPendingDraft() } }) {
            if let clubID { ClubCommunityComposer(model: model, clubID: clubID, post: nil) }
        }
        .clubIslandStatus(message: $toastMessage, tone: .info, surface: "community")
        .cySheet(item: $model.review, onDismiss: { model.cancelReview() }) { review in
            ClubCommunityReviewView(review: review, model: model, refresh: operation) { settled in
                toastMessage = ClubCommunityToast.message(for: settled)
            }
        }
    }
    private var writesUnavailable: Bool { model.context.coordinator?.permitsInjectedWrites != true }
    private func communityNotice(_ key: String, identifier: String) -> some View {
        Text(LocalizedStringKey(key))
            .foregroundStyle(.secondary)
            .accessibilityIdentifier(identifier)
    }
    private func pendingLock(_ pending: ClubCommunityPendingRecord, clubID: Int, identifierPrefix: String, post: ClubCommunityPost? = nil, refresh: ClubCommunityRead? = nil) -> some View {
        let read = refresh ?? operation
        return Section {
            Text(LocalizedStringKey("club.community.pendingLocked"))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("\(identifierPrefix).pendingLocked.\(pending.operationKind)")
            if model.context.coordinator?.permitsAuthoritativeOutcomeQueries == true {
                Button("club.community.reconcilePending") {
                    Task { await model.reconcilePending(clubID: clubID, post: post, refresh: read) }
                }
                .disabled(model.busy || model.loading)
                .accessibilityIdentifier("\(identifierPrefix).reconcilePending")
            }
        }
    }
    @ViewBuilder private func feedItem(_ item: ClubCommunityFeedItem, snapshot: ClubCommunitySnapshot) -> some View {
        let post = item.post
        let target = discussionTarget(post, acceptedPosts: snapshot.posts)
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            if clubID == nil {
                let selection = feedSource(item, snapshot: snapshot)
                ClubCommunityFeedSourceEntry(name: post.clubName, itemID: item.id,
                    openClub: selection.map { selected in { openFeedSource(selected) } })
            }
            if item.isRepost {
                Label("club.community.repostedBy \(item.reposterName)", systemImage: "arrow.2.squarepath")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !item.repostTime.isEmpty {
                    Text(verbatim: item.repostTime)
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
            ClubCommunityPostTile(post: post, clubID: post.clubID ?? clubID, identity: identity, model: model,
                commentsExpanded: discussionItemID == item.id && discussion.selection?.post.id == post.id, canOpenComments: target != nil,
                openComments: {
                    if let target {
                        if discussionItemID != item.id { discussion.close() }
                        discussionItemID = item.id
                        toggleDiscussion(target)
                    }
                },
                openHistory: { destination = .init(post: post, clubID: post.clubID ?? clubID, screen: .history) },
                openDetail: { destination = .init(post: post, clubID: post.clubID ?? clubID, screen: .detail) })
            if let selected = discussion.selection, discussionItemID == item.id, selected.post == post {
                ClubPostDiscussionPanel(target: selected, source: model, close: { discussion.close() }).id(selected.id)
            }
        }
        // Several controls share one List row: each keeps its own hit area.
        .buttonStyle(.borderless)
    }
    private func feedSource(_ item: ClubCommunityFeedItem, snapshot: ClubCommunitySnapshot) -> ClubCommunityFeedSource? {
        guard clubID == nil, !model.loading, !model.busy, model.context.feedSourceDestination != nil,
              let scope = model.feedSourceReadScope, scope.identity == identity,
              model.context.feedSourceScope() == scope,
              (try? model.context.currentSession().identity) == identity else { return nil }
        return .init(item: item, snapshot: snapshot, context: scope,
            generation: model.imageReadScope, readerIdentity: ObjectIdentifier(model))
    }
    private func currentFeedSource(_ selected: ClubCommunityFeedSource) -> Bool {
        !model.loading && (try? model.context.currentSession().identity) == identity &&
            model.feedSourceReadScope == selected.context && selected.isCurrent(snapshot: model.snapshot,
                context: model.context.feedSourceScope(), generation: model.imageReadScope,
                readerIdentity: ObjectIdentifier(model))
    }
    private func openFeedSource(_ selected: ClubCommunityFeedSource) {
        guard !model.busy, currentFeedSource(selected),
              model.context.feedSourceDestination?(selected.clubID, selected.context) != nil else { return }
        discussion.close(); sourceDestination = selected
    }
    private func discussionTarget(_ post: ClubCommunityPost, acceptedPosts: [ClubCommunityPost]) -> ClubPostDiscussionSelection? {
        guard let id = post.clubID ?? clubID else { return nil }
        return .init(post: post, acceptedPosts: acceptedPosts, context: .init(clubID: id, identity: identity,
            readScope: model.imageReadScope, viewerRevision: topics.viewerRevision))
    }
    private func toggleDiscussion(_ target: ClubPostDiscussionSelection) {
        guard !model.busy, (discussionHost?.isCurrent() ?? true), (try? model.context.currentSession().identity) == identity else { return }
        discussion.toggle(target, acceptedPosts: model.snapshot?.posts, context: .init(clubID: target.context.clubID,
            identity: identity, readScope: model.imageReadScope, viewerRevision: topics.viewerRevision))
    }
}

@MainActor
struct ClubCommunityPostTile: View {
    let post: ClubCommunityPost
    let clubID: Int?
    let identity: ClubReadIdentity
    @ObservedObject var model: ClubCommunityViewModel
    var commentsExpanded = false
    var canOpenComments = true
    let openComments: () -> Void
    let openHistory: () -> Void
    var openDetail: (() -> Void)? = nil
    @State private var editing = false
    @State private var evidence: ClubCommunityEvidence?
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize
    private var canLike: Bool {
        let target = clubID ?? post.clubID
        return target != nil && identity.isSignedIn && !model.busy && model.context.coordinator?.permitsInjectedWrites == true
    }
    /// MP post-card: `showFollow && post.isFollowTheUser == 0 && post.memberId && post.memberId != userId`.
    private var followableAuthor: Int? {
        guard clubID != nil, model.context.followAuthor != nil, identity.isSignedIn, post.followsAuthor == false,
              let author = post.followMemberID, author != identity.accountID, post.authorMemberID != identity.accountID
        else { return nil }
        return author
    }
    private func allows(_ operation: ClubCommunityOperation) -> Bool {
        // CLB-detail-04: the menu only decides which rows to show. Freshness (< 60 s) is
        // enforced again in `ClubCommunityCoordinator.prepare`, which re-reads evidence, so
        // a page left open for a minute keeps edit / pin / delete / report visible.
        guard let evidence, evidence.identity == identity, evidence.post == post else { return false }
        return evidence.allows(operation)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            HStack(alignment: .center, spacing: CYSpacing.sm) {
                ClubPostAuthorProfile(post: post, clubID: clubID, identity: identity, model: model)
                if let author = followableAuthor {
                    Spacer(minLength: 0)
                    // CLB-G10: MP cy-post-card `show-follow` (detail wxml:117-119, post-card wxml:15-17).
                    ClubGapFollowAuthorButton(isFollowing: model.followedAuthors.contains(author)) {
                        Task { await model.followAuthor(author) }
                    }
                }
            }
            if post.activityCard.showsActivity {
                SquareCloudStravaBlock(
                    card: post.activityCard,
                    title: post.sportName.isEmpty ? nil : post.sportName,
                    onDoubleTapLike: canLike ? { Task { await model.prepare(.toggleLike, clubID: clubID ?? post.clubID ?? 0, post: post) } } : nil,
                    onRepost: canLike ? { Task { await model.prepare(.repost(!post.reposted), clubID: clubID ?? post.clubID ?? 0, post: post) } } : nil)
            }
            ClubPostDiscussionBody(post: post, expanded: commentsExpanded, open: canOpenComments ? openComments : nil)
            ClubPostImageGallery(post: post, clubID: clubID, identity: identity, model: model)
            if !post.sportName.isEmpty, (post.refType == 1 || !post.sportCover.isEmpty) {
                ClubPostReferenceView(post: post, clubID: clubID, identity: identity, model: model, openComments: openComments)
                ClubPostPlayPreview(post: post, clubID: clubID, identity: identity, model: model, openComments: openComments)
            }
            // CLB-detail-43 (MP cy-post-card): inside a club the counts ride on 赞 / 评论 in the one action bar; the
            // cross-club feed has no action bar, so it keeps the count row.
            // MC8-28-3: a cross-club post that names its club gets the full action bar below instead.
            if clubID == nil, post.clubID == nil, post.likeCount > 0 || post.commentCount > 0 {
                tileActions {
                    countLabel(post.likeCount, symbol: "heart")
                    countLabel(post.commentCount, symbol: "bubble")
                }
                .accessibilityElement(children: .combine)
            }
            if let clubID = clubID ?? post.clubID.flatMap({ $0 > 0 ? $0 : nil }) {
                tileActions {
                    Button { Task { await model.prepare(.toggleLike, clubID: clubID, post: post) } } label: {
                        // C5 social: rolling count + heart swap/bounce on the viewer's like (MP cy-post-card 赞 · n).
                        CYSocialCountLabel(count: post.likeCount, symbol: "heart", active: post.liked, activeSymbol: "heart.fill",
                                           emptyTitle: "club.community.like")
                    }
                        .accessibilityLabel(Text("club.community.like"))
                        .accessibilityValue(post.likeCount > 0 ? Text(verbatim: String(post.likeCount)) : Text(verbatim: ""))
                        .disabled(!identity.isSignedIn || model.busy || model.context.coordinator?.permitsInjectedWrites != true)
                    Button(action: openComments) {
                        if commentsExpanded { Label("club.discussion.collapse", systemImage: "bubble") }
                        else { CYSocialCountLabel(count: post.commentCount, symbol: "bubble", emptyTitle: "club.community.comments") }
                    }
                        .accessibilityLabel(Text(LocalizedStringKey(commentsExpanded ? "club.discussion.collapse" : "club.community.comments")))
                        .accessibilityValue(!commentsExpanded && post.commentCount > 0 ? Text(verbatim: String(post.commentCount)) : Text(verbatim: ""))
                        .disabled(!canOpenComments)
                        .accessibilityIdentifier("club.community.comments.\(post.id)")
                    // CLB-detail-03: MP show-repost / show-share on club posts (repost through the reviewed write path).
                    Button { Task { await model.prepare(.repost(!post.reposted), clubID: clubID, post: post) } } label: {
                        Label(post.reposted ? "club.community.unrepost" : "club.community.repost", systemImage: "arrow.2.squarepath")
                    }
                    .disabled(!identity.isSignedIn || model.busy || model.context.coordinator?.permitsInjectedWrites != true)
                    .accessibilityIdentifier("club.community.repost.\(post.id)")
                    // CLB-detail-30 (fix-r3-club-a round 3): the wired post path travels as an in-app link with the excerpt.
                    if let link = ClubShareLink.post(clubID: clubID, postID: post.id) {
                        Group {
                            if let url = ClubShareURL.url(link) {
                                ShareLink(item: url, message: Text(verbatim: ClubPostShareText.text(post: post, locale: locale))) {
                                    Label("club.community.share", systemImage: "square.and.arrow.up")
                                }
                            } else {
                                ShareLink(item: link.path) { Label("club.community.share", systemImage: "square.and.arrow.up") }
                            }
                        }
                        .accessibilityIdentifier("club.community.share.\(post.id)")
                    }
                }
                Menu {
                    if allows(.update(content: post.content, images: post.images, requestID: "display")) { Button("club.community.edit") { editing = true } }
                    if allows(.pin(!post.pinned, requestID: "display")) { Button(post.pinned ? "club.community.unpin" : "club.community.pin") { Task { await model.prepare(.pin(!post.pinned, requestID: UUID().uuidString), clubID: clubID, post: post) } } }
                    if allows(.delete) { Button("club.community.delete", role: .destructive) { Task { await model.prepare(.delete, clubID: clubID, post: post) } } }
                    if allows(.report) {
                        Button("club.community.report") { Task { await model.prepare(.report, clubID: clubID, post: post) } }
                            .accessibilityLabel(Text("club.community.report"))
                    }
                } label: { Label("club.community.actions", systemImage: "ellipsis") }
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .disabled(!identity.isSignedIn || model.busy || model.context.coordinator?.permitsInjectedWrites != true)
            }
            tileActions {
                if let openDetail {
                    Button(action: openDetail) { Text("club.community.detail") }
                        .frame(minHeight: CYSpacing.minTouchTarget)
                        .accessibilityIdentifier("club.community.detail.\(post.id)")
                }
                // CLB-detail-17: MP shows 历史 only for an edited post (version > 0).
                if post.version > 0 {
                    Button(action: openHistory) { Text("club.community.history") }
                        .frame(minHeight: CYSpacing.minTouchTarget)
                        .accessibilityIdentifier("club.community.history.\(post.id)")
                }
                if post.authorMemberID != identity.accountID {
                    UGCSafetyMenuButton(
                        presentation: UGCReportPresentationTarget(
                            target: .clubPost(clubID: post.clubID ?? clubID ?? 0, postID: post.id),
                            subjectTitle: post.content,
                            authorMemberID: post.authorMemberID,
                            authorName: post.nickname,
                            clubID: post.clubID ?? clubID
                        ),
                        compactLabel: true
                    )
                    .accessibilityIdentifier("club.community.safety.\(post.id)")
                }
            }
        }
        .buttonStyle(.borderless)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("club.community.post.\(post.id)")
        .task(id: identity) {
            evidence = nil
            if let clubID, let fresh = try? await model.context.evidence(clubID, post, nil), fresh.identity == identity { evidence = fresh }
        }
        .cySheet(isPresented: $editing, onDismiss: { Task { await model.reviewPendingDraft() } }) { if let clubID { ClubCommunityComposer(model: model, clubID: clubID, post: post) } }
    }
    @ViewBuilder private func tileActions<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: CYSpacing.sm, content: content)
        } else {
            HStack(spacing: CYSpacing.md, content: content)
        }
    }
    /// The action's count when there is one (MP shows the number beside the icon), else its name.
    private func countLabel(_ count: Int, symbol: String) -> some View {
        CYSocialCountLabel(count: count, symbol: symbol)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}

@MainActor
struct ClubCommunityPostDetailView: View {
    let identity: ClubReadIdentity
    let clubID: Int?
    let post: ClubCommunityPost
    @StateObject private var model: ClubCommunityViewModel
    @State private var showingHistory = false
    @State private var toastMessage: LocalizedStringKey?

    init(context: ClubCommunityContext, identity: ClubReadIdentity, clubID: Int?, post: ClubCommunityPost) {
        self.identity = identity
        self.clubID = clubID
        self.post = post
        _model = StateObject(wrappedValue: ClubCommunityViewModel(context: context))
    }

    private var commentsOperation: ClubCommunityRead {
        .comments(postID: post.id, page: 1)
    }

    var body: some View {
        List {
            Section {
                ClubCommunityPostTile(
                    post: post,
                    clubID: post.clubID ?? clubID,
                    identity: identity,
                    model: model,
                    commentsExpanded: true,
                    canOpenComments: false,
                    openComments: {},
                    openHistory: { showingHistory = true }
                )
            }
            if let pending = model.pendingRecord, let targetClubID = post.clubID ?? clubID {
                Section {
                    Text(LocalizedStringKey("club.community.pendingLocked"))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("club.community.detail.pendingLocked.\(pending.operationKind)")
                    if pending.operationKind == "like", pending.target.postID == post.id {
                        // Mini-program like readback: the server's current like state for this post only.
                        ClubPostLikeStateButton(postID: post.id, clubID: targetClubID)
                    }
                    if model.context.coordinator?.permitsAuthoritativeOutcomeQueries == true {
                        Button("club.community.reconcilePending") {
                            Task {
                                await model.reconcilePending(
                                    clubID: targetClubID,
                                    post: post,
                                    refresh: commentsOperation
                                )
                            }
                        }
                        .disabled(model.busy || model.loading)
                        .accessibilityIdentifier("club.community.detail.reconcilePending")
                    }
                }
            }
            Section {
                if model.loading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(Text("club.community.loading"))
                }
                if let notice = model.notice {
                    Text(LocalizedStringKey(notice))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("club.community.detail.notice")
                }
                if model.snapshot?.comments.isEmpty == true {
                    ContentUnavailableView("club.community.noComments", systemImage: "bubble")
                }
                ForEach(model.snapshot?.comments ?? []) { comment in
                    UGCBlockedFilterContainer(memberID: comment.memberID, authorName: comment.nickname) {
                        HStack(alignment: .top, spacing: CYSpacing.sm) {
                            ClubCommunityCommentRow(comment: comment)
                            if comment.memberID != identity.accountID {
                                UGCSafetyMenuButton(
                                    presentation: UGCReportPresentationTarget(
                                        target: .clubPostComment(commentID: comment.id),
                                        subjectTitle: comment.content,
                                        authorMemberID: comment.memberID,
                                        authorName: comment.nickname,
                                        clubID: post.clubID ?? clubID
                                    ),
                                    compactLabel: true
                                )
                                .buttonStyle(.borderless)
                            }
                        }
                        .accessibilityIdentifier("club.community.detail.comment.\(comment.id)")
                    }
                }
            } header: {
                Text("club.community.comments")
            }
        }
        .navigationTitle(Text("club.community.detail"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.load(commentsOperation) }
        .navigationDestination(isPresented: $showingHistory) {
            ClubCommunityHistoryView(context: model.context, identity: identity, postID: post.id)
        }
        .task(id: identity) {
            model.invalidate()
            await model.load(commentsOperation)
            if let targetClubID = post.clubID ?? clubID {
                _ = model.recoverPendingState(clubID: targetClubID, post: post)
            }
        }
        .onDisappear { model.suspend() }
        .clubIslandStatus(message: $toastMessage, tone: .info, surface: "community")
        .cySheet(item: $model.review, onDismiss: { model.cancelReview() }) { review in
            ClubCommunityReviewView(review: review, model: model, refresh: commentsOperation) { settled in
                toastMessage = ClubCommunityToast.message(for: settled)
            }
        }
    }
}

@MainActor
struct ClubCommunityComposer: View {
    @ObservedObject var model: ClubCommunityViewModel
    let clubID: Int
    let post: ClubCommunityPost?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .body) private var editorMinHeight: CGFloat = 120
    @State private var content = ""
    @State private var images: [String] = []
    @State private var uploading = false
    @State private var canAnnounce = false
    @State private var asAnnouncement = false
    @State private var postRef: ClubPostRefOption?
    @StateObject private var imageBridge: ClubPostImageComposerBridge
    init(model: ClubCommunityViewModel, clubID: Int, post: ClubCommunityPost?) {
        self.model = model
        self.clubID = clubID
        self.post = post
        _imageBridge = StateObject(
            wrappedValue: ClubPostImageComposerBridge(
                context: model.context.postImagePicker,
                clubID: clubID,
                postID: post?.id
            )
        )
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $content)
                        .frame(minHeight: editorMinHeight)
                        .accessibilityLabel(Text("club.community.content"))
                        .accessibilityIdentifier("club.community.content")
                } footer: {
                    // The MP prompt while empty; the 300-character limit once typing starts.
                    if content.isEmpty {
                        Text(verbatim: locale.pick("有什么新鲜好玩的分享吗？", "Share something new?"))
                    } else {
                        Text(verbatim: "\(content.count)/300")
                            .monospacedDigit()
                            .foregroundStyle(content.count > 300 ? AnyShapeStyle(Color.red) : AnyShapeStyle(HierarchicalShapeStyle.secondary))
                    }
                }
                Section {
                    ClubPostImageSectionView(
                        bridge: imageBridge,
                        images: $images,
                        uploading: $uploading,
                        notice: $model.notice
                    )
                }
                if post == nil, model.context.loadPostRefs != nil || canAnnounce {
                    Section {
                        if let loadPostRefs = model.context.loadPostRefs {
                            // CLB-G05: MP cy-post-compose club mode (index.wxml:63-92) — one play record per post.
                            ClubGapPlayRecordPickerRow(selected: $postRef, load: loadPostRefs)
                        }
                        if canAnnounce {
                            // MP post-compose 作为公告发布 (owner / content managers only).
                            Toggle(isOn: $asAnnouncement) { Text("club.community.asNotice") }
                                .accessibilityIdentifier("club.community.asNotice")
                        }
                    }
                }
            }
            .navigationTitle(post == nil ? Text("club.community.create") : Text("club.community.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if let post {
                        ClubPostEditExitControl(post: post, clubID: clubID, source: model,
                            content: $content, images: $images, canExit: { !model.busy && !uploading && !imageBridge.isBusy }, close: { dismiss() })
                    } else { Button("club.community.cancel") { dismiss() } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("club.community.review") {
                        let operation: ClubCommunityOperation = post == nil ? .create(content: content, images: images, notice: canAnnounce && asAnnouncement, ref: postRef) : .update(content: content, images: images, requestID: UUID().uuidString)
                        model.stageDraft(operation, clubID: clubID, post: post)
                        dismiss()
                    }
                    .disabled(model.busy || uploading || imageBridge.isBusy || content.count > 300 || (content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && images.isEmpty))
                    .accessibilityIdentifier("club.community.reviewDraft")
                }
            }
            .task {
                guard post == nil, let evidence = try? await model.context.evidence(clubID, nil, nil) else { return }
                canAnnounce = evidence.allows(.create(content: "", images: [], notice: true))
            }
            .onAppear {
                if content.isEmpty && images.isEmpty {
                    content = post?.content ?? ""
                    images = post?.images ?? []
                }
                imageBridge.bind(initialReferences: images)
            }
            .onDisappear {
                imageBridge.invalidate()
            }
        }
        .interactiveDismissDisabled(post.map {
            model.busy || uploading || imageBridge.isBusy || ClubPostEditDraft(content: content, images: images) !=
                ClubPostEditDraft(content: $0.content, images: $0.images)
        } ?? false)
    }
}

/// Pushed club-scoped screens title themselves; the cross-club feed sits under its host's title.
private struct ClubCommunityPushedTitle: ViewModifier {
    let title: LocalizedStringKey?
    @ViewBuilder func body(content: Content) -> some View {
        if let title {
            content.navigationTitle(Text(title)).navigationBarTitleDisplayMode(.inline)
        } else {
            content
        }
    }
}

/// Share message for a club post (MP share card title): the club name and the first line of the post.
enum ClubPostShareText {
    static func text(post: ClubCommunityPost, locale: Locale) -> String {
        let excerpt = post.content.split(separator: "\n").first.map(String.init).map { String($0.prefix(60)) } ?? ""
        let club = post.clubName.isEmpty ? locale.pick("俱乐部", "Club") : post.clubName
        return excerpt.isEmpty ? locale.pick("来看看「\(club)」的帖子", "A post from \(club)")
            : locale.pick("「\(club)」：\(excerpt)", "\(club): \(excerpt)")
    }
}

private enum ClubCommunityToast {
    static func message(for operation: ClubCommunityOperation) -> LocalizedStringKey? {
        switch operation {
        case .pin(true, _): return "club.community.pin.toast"
        case .pin(false, _): return "club.community.unpin.toast"
        case .delete, .deleteComment: return "club.community.delete.toast"
        default: return nil
        }
    }
}

@MainActor
struct ClubCommunityReviewView: View {
    let review: ClubCommunityReview
    @ObservedObject var model: ClubCommunityViewModel
    let refresh: ClubCommunityRead
    var onSettled: ((ClubCommunityOperation) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    private var isDestructiveOperation: Bool {
        switch review.operation {
        case .delete, .deleteComment, .report, .reportComment: return true
        default: return false
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(LocalizedStringKey("club.community." + review.operation.labelKey))
                        .font(.headline)

                    // X10 (parity r1): name the post / comment by its words, never by internal ids.
                    if let target = review.evidence.comment?.content ?? review.evidence.post?.content,
                       !target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(verbatim: target)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }

                    switch review.operation {
                    case let .create(content, images, _, _), let .update(content, images, _):
                        Text(verbatim: content)
                        ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                            ClubCommunityReferenceCover(reference: image, index: index)
                        }
                    case let .comment(content):
                        let commentValue = content.isEmpty ? PageTemplateVoiceOver.dash : content
                        Text(verbatim: commentValue)
                            .accessibilityLabel(PageTemplateVoiceOver.spoken(commentValue, locale: locale))
                    case .report, .reportComment:
                        Text("club.community.queuedExplanation")
                            .foregroundStyle(.secondary)
                    case .toggleLike, .repost:
                        Text("club.community.toggleWarning")
                            .foregroundStyle(.secondary)
                    case let .pin(pinned, _):
                        Text(pinned ? "club.community.pin" : "club.community.unpin")
                    default:
                        Text("club.community.deleteWarning")
                            .foregroundStyle(.red)
                    }
                } footer: {
                    // E2E R13: the note follows the same grant that admits the write; a granted Confirm never says "unavailable".
                    if model.context.coordinator?.permitsInjectedWrites != true {
                        Label { Text("club.community.offline") } icon: { Image(systemName: "wifi.slash") }
                    }
                }

                Section {
                    Button(role: isDestructiveOperation ? .destructive : nil) {
                        Task {
                            if await model.confirm(expected: review, refresh: refresh) {
                                onSettled?(review.operation)
                                dismiss()
                            }
                        }
                    } label: {
                        Text("club.community.confirm")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(model.busy)
                    .accessibilityIdentifier("club.community.confirm")
                }
            }
            .navigationTitle(Text("club.community.review"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("club.community.cancel") {
                        model.cancelReview()
                        dismiss()
                    }
                    .disabled(model.busy)
                }
            }
        }
        .cyDomainSheet(detents: [.half, .full])
        .interactiveDismissDisabled(model.busy)
    }
}

@MainActor
struct ClubCommunityCommentsView: View {
    let identity: ClubReadIdentity, clubID: Int, post: ClubCommunityPost
    @StateObject private var model: ClubCommunityViewModel
    @State private var content = ""
    @State private var evidence: ClubCommunityEvidence?
    init(context: ClubCommunityContext, identity: ClubReadIdentity, clubID: Int, post: ClubCommunityPost) {
        self.identity = identity; self.clubID = clubID; self.post = post
        _model = StateObject(wrappedValue: ClubCommunityViewModel(context: context))
    }
    private var operation: ClubCommunityRead { .comments(postID: post.id, page: 1) }
    var body: some View {
        List {
            if model.loading || model.notice != nil {
                Section {
                    if model.loading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel(Text("club.community.loading"))
                    }
                    if let notice = model.notice {
                        Text(LocalizedStringKey(notice))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if let pending = model.pendingRecord {
                Section {
                    Text(LocalizedStringKey("club.community.pendingLocked"))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("club.community.comments.pendingLocked.\(pending.operationKind)")
                    if model.context.coordinator?.permitsAuthoritativeOutcomeQueries == true {
                        Button("club.community.reconcilePending") {
                            Task { await model.reconcilePending(clubID: clubID, post: post, refresh: operation) }
                        }
                        .disabled(model.busy || model.loading)
                        .accessibilityIdentifier("club.community.comments.reconcilePending")
                    }
                }
            }
            Section {
                if model.snapshot?.comments.isEmpty == true {
                    ContentUnavailableView("club.community.noComments", systemImage: "bubble")
                }
                ForEach(model.snapshot?.comments ?? []) { comment in
                    UGCBlockedFilterContainer(memberID: comment.memberID, authorName: comment.nickname) {
                        VStack(alignment: .leading, spacing: CYSpacing.sm) {
                            HStack(alignment: .top, spacing: CYSpacing.sm) {
                                ClubCommunityCommentRow(comment: comment)
                                Spacer(minLength: 0)
                                if comment.memberID != identity.accountID {
                                    UGCSafetyMenuButton(
                                        presentation: UGCReportPresentationTarget(
                                            target: .clubPostComment(commentID: comment.id),
                                            subjectTitle: comment.content,
                                            authorMemberID: comment.memberID,
                                            authorName: comment.nickname,
                                            clubID: clubID
                                        ),
                                        compactLabel: true
                                    )
                                }
                            }
                            let moderator = evidence?.owner == true || evidence?.administrator == true || post.viewerCanManage
                            if identity.isSignedIn {
                                let canDelete = comment.memberID == identity.accountID || moderator
                                Button(canDelete ? "club.community.deleteComment" : "club.community.reportComment", role: canDelete ? .destructive : nil) {
                                    Task { await model.prepare(canDelete ? .deleteComment : .reportComment, clubID: clubID, post: post, comment: comment) }
                                }
                                .font(.subheadline)
                                .disabled(model.busy || model.context.coordinator?.permitsInjectedWrites != true)
                            }
                        }
                        .buttonStyle(.borderless)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("club.community.comment.\(comment.id)")
                    }
                }
            }
            Section {
                TextField("club.community.commentContent", text: $content, axis: .vertical)
                    .lineLimit(1...6)
                    .accessibilityIdentifier("club.community.commentContent")
                Button("club.community.review") { Task { await model.prepare(.comment(content), clubID: clubID, post: post) } }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !identity.isSignedIn || model.busy || model.pendingRecord != nil || model.context.coordinator?.permitsInjectedWrites != true)
            }
        }
        .navigationTitle(Text("club.community.comments"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.load(operation) }
        .task(id: identity) {
            model.invalidate(); content = ""; evidence = nil
            await model.load(operation)
            _ = model.recoverPendingState(clubID: clubID, post: post)
            if let fresh = try? await model.context.evidence(clubID, post, nil), fresh.identity == identity { evidence = fresh }
        }
        .onDisappear { model.invalidate(); content = ""; evidence = nil }
        .cySheet(item: $model.review, onDismiss: { model.cancelReview() }) { review in ClubCommunityReviewView(review: review, model: model, refresh: operation) }
    }
}

@MainActor
struct ClubCommunityHistoryView: View {
    let identity: ClubReadIdentity, postID: Int
    @StateObject private var model: ClubCommunityViewModel
    @Environment(\.locale) private var locale
    init(context: ClubCommunityContext, identity: ClubReadIdentity, postID: Int) {
        self.identity = identity; self.postID = postID; _model = StateObject(wrappedValue: ClubCommunityViewModel(context: context))
    }
    var body: some View {
        List {
            if model.loading || model.notice != nil {
                Section {
                    if model.loading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel(Text("club.community.loading"))
                    }
                    if let notice = model.notice {
                        Text(LocalizedStringKey(notice))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if model.snapshot?.history.isEmpty == true {
                ContentUnavailableView("club.community.noHistory", systemImage: "clock.arrow.circlepath")
            }
            ForEach(model.snapshot?.history ?? []) { revision in
                Section {
                    LabeledContent("club.community.version") {
                        Text(verbatim: String(revision.snapshotVersion)).monospacedDigit()
                    }
                    let contentValue = revision.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? PageTemplateVoiceOver.dash : revision.content
                    Text(verbatim: contentValue)
                        .accessibilityLabel(PageTemplateVoiceOver.spoken(contentValue, locale: locale))
                    let timeValue = revision.createTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? PageTemplateVoiceOver.dash : revision.createTime
                    Text(verbatim: timeValue)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .accessibilityLabel(PageTemplateVoiceOver.spoken(timeValue, locale: locale))
                    ForEach(Array(revision.images.enumerated()), id: \.offset) { index, value in
                        ClubCommunityReferenceCover(reference: value, index: index)
                    }
                }
            }
        }
        .navigationTitle(Text("club.community.history"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.load(.history(postID: postID)) }
            .task(id: identity) { model.invalidate(); await model.load(.history(postID: postID)) }
            .onDisappear { model.invalidate() }
    }
}

private struct ClubCommunityCommentRow: View {
    let comment: ClubCommunityComment
    @Environment(\.locale) private var locale
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            if comment.nickname.isEmpty {
                Text("club.community.user")
            } else {
                Text(verbatim: comment.nickname)
            }
            Text(verbatim: shown(comment.content))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(PageTemplateVoiceOver.spoken(shown(comment.content), locale: locale))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
    private func shown(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? PageTemplateVoiceOver.dash : value
    }
}

private struct ClubCommunityReferenceCover: View {
    let reference: String
    let index: Int
    var body: some View {
        let trimmed = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Color.clear
                .aspectRatio(16.0 / 10.0, contentMode: .fit)
                .overlay {
                    if let url = Self.https(trimmed) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image { image.resizable().scaledToFill() }
                            else { CYCoverArt(seed: trimmed, showsDebugLabel: false) }
                        }
                    } else {
                        CYCoverArt(seed: trimmed.isEmpty ? "club-community" : trimmed, showsDebugLabel: false)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
                .accessibilityLabel(Text("club.community.image") + Text(verbatim: " \(index + 1)"))
            if !trimmed.isEmpty {
                Text(verbatim: trimmed)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
    }
    private static func https(_ value: String) -> URL? {
        guard let url = URL(string: value), url.scheme?.lowercased() == "https" else { return nil }
        return url
    }
}
