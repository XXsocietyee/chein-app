import SwiftUI

/// The session host should observe AppSession and apply .id(reader.scope) to this subtree.
@MainActor struct SquareBrowserView: View {
    let reader: any SquareReading
    var accountReader: (any SocialAccountReading)? = nil
    var actions: SocialActionCoordinator? = nil
    var workspace: SquareWorkspaceCoordinator? = nil
    var governance: SquareGovernanceCoordinator? = nil
    var governanceAccess: ((Int?) -> SquareGovernanceSessionAccess)? = nil
    var onSignIn: (() -> Void)? = nil
    /// Optional source "即将开始" strip (official events within 24h); nil hides it.
    var upcomingReader: (any OfficialEventReading)? = nil
    var upcomingDestination: ((Int) -> AnyView)? = nil
    /// Reporter progress survives unavailable or deleted feed targets; nil preserves fixture callers.
    var reportProgressDestination: (() -> AnyView)? = nil
    @State private var showsWorkspace = false
    @State private var showsComposer = false
    @State private var showsReportProgress = false
    @State private var repostPrefill = ""
    @State private var cloudEditor: SquareCloudEditorRoute?
    @State private var actionPost: SquarePost?
    @State private var cloudReport: SquareCloudReportRoute?
    @State private var profileMember: SquareCloudProfileRoute?
    var onClose: (() -> Void)? = nil
    @Environment(\.squareReportContext) private var reportContext
    @State private var query = SquareQuery()
    @State private var keyword = ""
    @State private var cityCode = ""
    @State private var topicCode = ""
    @State private var communityID = ""
    @State private var pagination = SquareFeedPagination()
    @State private var loadedKey: Key?
    @State private var generation = 0
    /// Fetch lifecycle of the feed (docs/release/state-machines/views.md). Items live in `pagination`; a failed
    /// load-more keeps them, so the phase carries no value (`.loaded(())` = last fetch succeeded).
    @State private var phase: CYPhase<Void, Error> = .idle
    private var loading: Bool { phase.isLoading }
    private var issue: Error? { phase.failure }
    @State private var path: [Int] = []
    /// Source `canUseCommunity(false)`: owner-bound flags; anything but a literal true keeps the community closed.
    @State private var communityGate: SquareCommunityFeatures?
    @State private var gateScope: UUID?
    private var gateReader: (any SquareCommunityFeatureReading)? { reader as? any SquareCommunityFeatureReading }
    private var gatePending: Bool { gateReader != nil && gateScope != reader.scope }
    private var communityClosed: Bool { gateReader != nil && gateScope == reader.scope && communityGate?.read != true }
    private struct Key: Hashable { let scope: UUID; let configured: Bool; let query: SquareQuery }
    private var key: Key { Key(scope: reader.scope, configured: reader.isConfigured, query: query) }
    var body: some View {
        NavigationStack(path: $path) {
            List {
                // 我的草稿 and 举报进度 are demoted into the toolbar menu; governance keeps its own entry.
                if let context = governanceContext(postID: nil) { SquareGovernanceEntryView(context: context) }
                Section {
                    if reader.showsOfflineExampleNote { Text("square.offlineExample").font(.caption).foregroundStyle(.secondary) }
                    Picker("square.feed", selection: $query.mode) {
                        ForEach(SquareFeedMode.visible, id: \.self) { mode in Text(mode.labelKey).tag(mode) }
                    }.accessibilityIdentifier("square.feed")
                    filters
                }
                if let upcomingReader, reader.isConfigured { SquareXcxUpcomingStrip(reader: upcomingReader, destination: upcomingDestination) }
                if !reader.isConfigured { squareState(APIError.notConfigured, retry: nil) }
                else if gatePending { loadingRow }
                else if communityClosed {
                    ContentUnavailableView {
                        Label { Text("square.xcx.closedTitle").accessibilityIdentifier("square.communityClosed") } icon: { Image(systemName: "lock") }
                    } description: {
                        Text("square.xcx.closedDetail")
                    } actions: {
                        Button("square.retry") { gateScope = nil; Task { await loadGate(); await load(reset: true) } }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("square.retry")
                    }
                }
                else if query.mode.requiresAccount && !reader.isSignedIn { squareState(SquareReadFailure.signInRequired, retry: nil) }
                else if loadedKey != key { loadingRow }
                else {
                    if let issue { squareState(issue, retry: { Task { await load(reset: !pagination.hasLoadedPage) } }) }
                    if pagination.items.isEmpty && !loading && issue == nil {
                        if query.keyword != nil {
                            feedEmpty("square.empty", systemImage: "magnifyingglass", messageIdentifier: "square.empty")
                        } else {
                            // Source empty feed: 广场还很安静 / 成为第一个发布创意路线的人吧.
                            feedEmpty("square.xcx.emptyTitle", detail: "square.xcx.emptyDetail", systemImage: "square.and.pencil", messageIdentifier: "square.empty")
                        }
                    }
                    ForEach(pagination.items) { post in
                        UGCBlockedFilterContainer(memberID: post.memberID, authorName: post.nickname) {
                            VStack(alignment: .leading, spacing: 0) {
                                NavigationLink(value: post.id) { SquareXcxPostCard(post: post, mediaScope: reader.scope, showsMedia: false) }
                                    .accessibilityIdentifier("square.row.\(post.id)")
                                    .contextMenu {
                                        if actions?.identity.accountID != post.memberID, post.memberID > 0 {
                                            UGCReviewSafetyFooter(
                                                target: post.generation == .communityV1
                                                    ? .community(targetType: .content, targetID: post.id)
                                                    : .creativeSquarePost(id: post.id),
                                                subjectTitle: post.contents,
                                                authorMemberID: post.memberID,
                                                authorName: post.nickname
                                            )
                                        }
                                    }
                                NativeMediaGalleryEntry(sources: post.images, scope: reader.scope, titleKey: "media.destination.squareImages", compact: true)
                            }
                        }
                    }
                    if pagination.continuationInvalid { Text("square.invalidCursor").accessibilityIdentifier("square.invalidCursor") }
                    if loading { loadingRow }
                    else if pagination.hasMore && issue == nil {
                        Button { Task { await load(reset: false) } } label: { Text("square.loadMore").frame(maxWidth: .infinity) }
                            .buttonStyle(.borderless)
                            .accessibilityIdentifier("square.loadMore")
                    }
                }
            }
            .appNavigationTitle("square.xcx.navTitle")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Int.self) { id in SquareDetailView(id: id, contentGeneration: .communityV1, reader: reader, accountReader: accountReader, actions: actions, governanceContext: governanceContext(postID: id), workspace: workspace) }
            .navigationDestination(item: $profileMember) { member in
                if let accountReader { SocialPublicProfileView(memberID: member.id, reader: accountReader, squareReader: reader, actions: actions) }
            }
            .toolbar { if let onClose { ToolbarItem(placement: .cancellationAction) { Button("action.close", action: onClose) } } }
            .toolbar {
                if workspace != nil || reportProgressDestination != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            if let workspace {
                                Button("squareWorkspace.title", systemImage: "doc.text") { showsWorkspace = true }
                                    .accessibilityIdentifier("square.workspace.entry")
                                    .disabled(workspace.busy)
                            }
                            if reportProgressDestination != nil {
                                Button { showsReportProgress = true } label: { Label { memberReportProgressText("report.history.title") } icon: { Image(systemName: "flag") } }
                                    .accessibilityIdentifier("squareReport.progress.entry")
                            }
                        } label: { Label("roam.toolbar.more", systemImage: "ellipsis.circle") }
                            .accessibilityIdentifier("square.more")
                    }
                }
                if let actions {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("social.editor.createPost", systemImage: "square.and.pencil") { if workspace != nil { showsWorkspace = true } else { showsComposer = true } }
                            .disabled(actions.identity.accountID == nil).accessibilityIdentifier("social.compose")
                    }
                }
            }
            .cySheet(isPresented: $showsComposer) { Group {
                if let actions {
                    SquareCloudComposerView(coordinator: actions, offline: reader.isOfflineExample, prefill: repostPrefill, joinedHosted: { reader.isOfflineExample ? .offline : .permission }, completed: { reader.isOfflineExample ? .offline : .permission }, onClose: { showsComposer = false; repostPrefill = "" })
                        .id(actions.identity)
                }
            }.cySheet(detents: [.large]) }
            .cySheet(item: $cloudEditor) { item in Group {
                if let actions { NavigationStack { SocialActionEditorView(purpose: item.purpose, target: item.target, coordinator: actions, initialText: item.text, contentGeneration: item.generation) }.id(actions.identity) }
            }.cySheet(detents: [.large]) }
            .cySheet(item: $actionPost) { post in Group {
                SquareCloudPostActions(owner: post.memberID == actions?.identity.accountID, bookmarkable: post.generation == .communityV1 && actions != nil, bookmarked: false, summary: post.contents ?? "", onEdit: editAction(post), onBookmark: bookmarkAction(post), onDelete: nil, onReport: reportAction(post), onClose: { actionPost = nil })
            }.cySheet(detents: [.large]) }
            .cySheet(item: $cloudReport) { item in
                NavigationStack { SquareReportView(target: item.target, context: reportContext) }.presentationDetents([.large])
            }
            .cySheet(isPresented: $showsWorkspace) { Group {
                if let workspace { NavigationStack { SquareWorkspaceView(coordinator: workspace) }.id(workspace.session) }
            }.cySheet(detents: [.large]) }
            .navigationDestination(isPresented: $showsReportProgress) { reportProgressDestination?() }
            .environment(\.squareCloudFeed, cloudFeed)
            .listStyle(.insetGrouped)
            .searchable(text: $keyword, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "square.search")
            .onSubmit(of: .search) { query.keyword = keyword.isEmpty ? nil : keyword }
            .onChange(of: keyword) { _, value in if value.isEmpty { query.keyword = nil } }
            .onChange(of: reader.scope) { _, _ in path = []; generation += 1; pagination = SquareFeedPagination(); loadedKey = nil; dismissCloudSheets() }
            .task(id: key) { await loadGate(); await load(reset: true) }
            .refreshable { await load(reset: true) }
            .onDisappear { generation += 1; settleLoading() }
            .accessibilityIdentifier("square.browser")
        }
        .cyDomainScreen(.player)
    }
    private func governanceContext(postID: Int?) -> SquareGovernanceContext? {
        guard let governance, let governanceAccess else { return nil }
        return .init(coordinator: governance, access: governanceAccess(postID), communityPostRead: reader.isConfigured,
            openPost: { id in guard reader.isConfigured, id > 0 else { return }; path.append(id) },
            openDrafts: { if workspace != nil { showsWorkspace = true } }, signIn: { onSignIn?() })
    }
    @ViewBuilder private func squareState(_ error: Error, retry: (() -> Void)?) -> some View {
        let offline = (error as? APIError) == .notConfigured
            || (error as? URLError)?.code == .notConnectedToInternet
            || (error as? SquareReadFailure) == .unavailable
        let message: String? = {
            guard let failure = error as? SquareReadFailure, case let .server(_, text) = failure else { return nil }
            let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }()
        ContentUnavailableView {
            Label { Text(squareIssueKey(error)).accessibilityIdentifier("square.error") } icon: { Image(systemName: offline ? "wifi.slash" : "exclamationmark.triangle") }
        } description: {
            if let message { Text(verbatim: message) }
        } actions: {
            if let retry { Button("square.retry", action: retry).buttonStyle(.bordered).accessibilityIdentifier("square.retry") }
        }
    }

    private func feedEmpty(_ title: LocalizedStringKey, detail: LocalizedStringKey? = nil, systemImage: String, messageIdentifier: String) -> some View {
        ContentUnavailableView {
            Label { Text(title).accessibilityIdentifier(messageIdentifier) } icon: { Image(systemName: systemImage) }
        } description: {
            if let detail { Text(detail) }
        }
    }

    private var loadingRow: some View {
        ProgressView { Text("cy.state.loading") }.frame(maxWidth: .infinity).accessibilityIdentifier("square.loading")
    }

    private func squareIssueKey(_ error: Error) -> LocalizedStringKey {
        if error as? APIError == .notConfigured { return "square.notConfigured" }
        if error as? APIError == .unauthorized { return "square.unauthorized" }
        switch error as? SquareReadFailure {
        case .signInRequired: return "square.signInRequired"
        case .cityRequired: return "square.cityRequired"
        case .topicRequired: return "square.topicRequired"
        case .communityRequired: return "square.communityRequired"
        case .unavailable: return "square.unavailable"
        default: return "square.failed"
        }
    }

    @ViewBuilder private var filters: some View {
        if query.mode == .nearby {
            TextField("square.cityCode", text: $cityCode).textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("square.cityCode")
            Button("square.applyFilter") { query.cityCode = cityCode }.accessibilityIdentifier("square.applyFilter")
        } else if query.mode == .topic {
            TextField("square.topicCode", text: $topicCode).textInputAutocapitalization(.never).autocorrectionDisabled()
            Button("square.applyFilter") { query.topicCode = topicCode }
        } else if query.mode == .community {
            TextField("square.communityID", text: $communityID).keyboardType(.numberPad)
            Button("square.applyFilter") { query.communityID = Int(communityID.trimmingCharacters(in: .whitespacesAndNewlines)) }
        }
    }
    private func loadGate() async {
        guard let gateReader, reader.isConfigured, gateScope != reader.scope else { return }
        let scope = reader.scope
        let value = try? await gateReader.communityFeatures()
        guard !Task.isCancelled, scope == reader.scope else { return }
        communityGate = value; gateScope = scope
    }
    /// Guard: only an in-flight fetch falls back to idle; a failure stays visible.
    private func settleLoading() { if phase.isLoading { phase = .idle } }
    private func load(reset: Bool) async {
        guard reset || !loading else { return }
        // A closed or unresolved community gate never requests the feed (source aborts reads when closed).
        guard !gatePending, !communityClosed else { pagination = SquareFeedPagination(); loadedKey = nil; settleLoading(); return }
        generation += 1
        let operation = generation, captured = key
        if reset { pagination = SquareFeedPagination(); loadedKey = nil }
        phase = .idle
        guard reader.isConfigured, !query.mode.requiresAccount || reader.isSignedIn else { return }
        phase = .loading
        defer { if operation == generation { settleLoading() } }
        let cursor = reset ? nil : pagination.nextCursor
        do {
            let page = try await reader.squareFeed(query: captured.query, cursor: cursor)
            try Task.checkCancellation()
            guard operation == generation, captured == key else { return }
            try pagination.accept(page, requestedCursor: cursor); phase = .loaded(()); loadedKey = captured
        } catch is CancellationError { }
        catch {
            guard operation == generation, captured == key else { return }
            phase = .failed(error, retry: nil); loadedKey = captured
        }
    }
    private var cloudFeed: SquareCloudFeedContext {
        SquareCloudFeedContext(
            viewerID: actions?.identity.accountID,
            offline: reader.isOfflineExample,
            onDoubleTapLike: actions == nil ? nil : { post in self.openCloudEditor(.like, .post(post.id), "", post.generation == .legacySquare ? .legacySquare : .communityV1) },
            onFollow: actions == nil ? nil : { post in guard post.memberID > 0 else { return }; self.openCloudEditor(.toggleFollow, .member(post.memberID), "", .legacySquare) },
            onRepost: actions == nil ? nil : { self.repost($0) },
            onReport: actions == nil ? nil : { self.report($0) },
            onProfile: accountReader == nil ? nil : { post in guard post.memberID > 0 else { return }; self.dismissCloudSheets(); self.profileMember = .init(id: post.memberID) },
            onCopyLink: { SquarePublicLinkCopy.copyIfPublic($0) },
            onActions: actions == nil ? nil : { self.presentActions($0) })
    }
    private func dismissCloudSheets() {
        showsComposer = false
        showsWorkspace = false
        cloudEditor = nil
        actionPost = nil
        cloudReport = nil
        repostPrefill = ""
    }
    private func openCloudEditor(_ purpose: SocialEditorPurpose, _ target: SocialActionTarget, _ text: String, _ generation: SquareContentGeneration) {
        guard actions != nil else { return }
        showsComposer = false
        showsWorkspace = false
        actionPost = nil
        cloudReport = nil
        cloudEditor = .init(purpose: purpose, target: target, text: text, generation: generation)
    }
    private func presentActions(_ post: SquarePost) {
        showsComposer = false
        showsWorkspace = false
        cloudEditor = nil
        cloudReport = nil
        actionPost = post
    }
    private func presentReport(_ target: SquareReportTarget) {
        showsComposer = false
        showsWorkspace = false
        cloudEditor = nil
        actionPost = nil
        cloudReport = .init(target: target)
    }
    private func repost(_ post: SquarePost) {
        let card = SquareShareCard.build(id: post.id, audience: post.audience, lifecycle: post.lifecycle, contents: post.contents, images: post.images)
        guard card.includesPost, actions != nil else { return }
        cloudEditor = nil
        actionPost = nil
        cloudReport = nil
        showsWorkspace = false
        repostPrefill = card.title
        showsComposer = true
    }
    private func report(_ post: SquarePost) {
        if post.generation == .legacySquare { openCloudEditor(.report, .post(post.id), "", .legacySquare); return }
        if let target = try? SquareReportTarget(post: post) { presentReport(target) }
    }
    private func editAction(_ post: SquarePost) -> (() -> Void)? {
        guard let actions, post.memberID == actions.identity.accountID, workspace != nil || post.generation != .communityV1 else { return nil }
        return {
            actionPost = nil
            if workspace != nil { showsComposer = false; cloudEditor = nil; cloudReport = nil; showsWorkspace = true }
            else { openCloudEditor(.editPost, .post(post.id), post.contents ?? "", post.generation == .legacySquare ? .legacySquare : .communityV1) }
        }
    }
    private func bookmarkAction(_ post: SquarePost) -> (() -> Void)? {
        guard actions != nil, post.generation == .communityV1 else { return nil }
        return { actionPost = nil; openCloudEditor(.bookmark, .post(post.id), "", .communityV1) }
    }
    private func reportAction(_ post: SquarePost) -> (() -> Void)? {
        guard actions != nil else { return nil }
        if post.generation == .legacySquare { return { actionPost = nil; openCloudEditor(.report, .post(post.id), "", .legacySquare) } }
        guard (try? SquareReportTarget(post: post)) != nil else { return nil }
        return { actionPost = nil; report(post) }
    }
}

private struct SquareCloudEditorRoute: Identifiable {
    let id = UUID()
    let purpose: SocialEditorPurpose
    let target: SocialActionTarget
    let text: String
    let generation: SquareContentGeneration
}

private struct SquareCloudReportRoute: Identifiable {
    let id = UUID()
    let target: SquareReportTarget
}

private struct SquareCloudProfileRoute: Identifiable, Hashable {
    let id: Int
}

/// Design fixtures (`d2-square`) render as a screenshot of the real page: the 示例内容 note is hidden there while
/// `isOfflineExample` still keeps every write offline.
@MainActor protocol SquareOfflineNoteHiding { var hidesOfflineExampleNote: Bool { get } }
extension SquareReading {
    var showsOfflineExampleNote: Bool {
        isOfflineExample && (self as? any SquareOfflineNoteHiding)?.hidesOfflineExampleNote != true
    }
}
