import SwiftUI

private struct AccountCollectionFavoritesGateKey: Hashable {
    let readerID: ObjectIdentifier
    let readerScope: UUID
    let gateID: ObjectIdentifier?
    let gateScope: UUID?
    let authenticated: Bool
    let configured: Bool
    @MainActor init(reader: any AccountCollectionReading, gate: (any SquareCommunityFeatureReading)?) {
        readerID = ObjectIdentifier(reader)
        readerScope = reader.scope
        gateID = gate.map { ObjectIdentifier($0) }
        gateScope = gate?.scope
        authenticated = reader.isAuthenticated
        configured = reader.isConfigured
    }
}

@MainActor struct AccountCollectionFavoritesView: View {
    let reader: any AccountCollectionReading
    let onOpenTopic: (Int) -> Void
    var pageSize = 10
    var onOpenPost: ((SquareContentRoute) -> Void)? = nil
    var favoriteRemoval: ProfileFavoriteRemovalController? = nil
    var communityGate: (any SquareCommunityFeatureReading)? = nil
    @Environment(\.playerGapService) private var playerGapService
    @Environment(\.locale) private var locale
    @State private var selectedTab: Tab = .posts
    @State private var gateModel = AccountCollectionCommunityGateModel()
    private enum Tab: Hashable { case posts, topics, cityNodes }
    private var gateKey: AccountCollectionFavoritesGateKey { AccountCollectionFavoritesGateKey(reader: reader, gate: communityGate) }
    /// Nil, signed-out, unconfigured, pending, denied, and failed all stay closed.
    private var postsAllowed: Bool { gateModel.postsAllowed(reader: reader, gate: communityGate) }
    private var showsCityNodesTab: Bool { playerGapService != nil }
    var body: some View {
        VStack(spacing: 0) {
            // A4-02: 删除我的帖文 lives on 我的帖文 / 帖文详情 / 俱乐部, not on 我的收藏 (MP mylike has no such block).
            if postsAllowed || showsCityNodesTab {
                // X5 (MP owner ruling 2026-07-31): tabs switch content areas, as on mylike (system segmented control).
                Picker(selection: $selectedTab) {
                    if postsAllowed { Text("social.posts").tag(Tab.posts) }
                    Text("searchMap.kind.topic").tag(Tab.topics)
                    if showsCityNodesTab { Text("accountCollection.favorites.nodesTab").tag(Tab.cityNodes) }
                } label: {
                    Text("accountCollection.favorites.title")
                }
                .cyAdaptiveSegmented()
                .padding(.horizontal).padding(.vertical, 8)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(Text("accountCollection.favorites.title"))
                    .accessibilityIdentifier("accountCollection.favorites.tabs")
            }
            if showsCityNodesTab && selectedTab == .cityNodes {
                List { CityFavoriteNodesSection() }
                    .listStyle(.insetGrouped)
            } else if postsAllowed && selectedTab == .posts {
                AccountCollectionFavoritePostsView(reader: reader, pageSize: pageSize, onOpenPost: onOpenPost, favoriteRemoval: favoriteRemoval)
            } else {
                AccountCollectionFavoriteTopicsView(reader: reader, onOpenTopic: onOpenTopic, pageSize: pageSize, retryGate: {
                    await gateModel.load(reader: { reader }, gate: { communityGate }, forceRetry: gateModel.failed)
                })
            }
        }
        .cyPageTitle("accountCollection.favorites.title")
        .cyHideTabBar()
        .task(id: gateKey) { await gateModel.load(reader: { reader }, gate: { communityGate }) }
        .onChange(of: gateKey) { _, _ in
            gateModel.invalidateIfIdentityChanged(reader: { reader }, gate: { communityGate })
        }
    }
}

/// The host resets the whole collection for session revisions. Each tab has its
/// own reader lifecycle, so switching tabs cancels a pending page completion.
@MainActor private struct AccountCollectionFavoriteTopicsView: View {
    let reader: any AccountCollectionReading
    let onOpenTopic: (Int) -> Void
    var pageSize = 10
    var retryGate: (() async -> Void)? = nil
    @StateObject private var model = AccountCollectionFavoritesScreenModel()
    @Environment(\.topicUnlikeController) private var unlike
    @Environment(\.locale) private var locale
    @State private var unliked: Set<Int> = []
    @State private var showRecommendNote = false
    private var key: AccountCollectionLoadKey { AccountCollectionLoadKey(reader: reader) }
    @State private var skeletonShown = false
    private var isLoadingNow: Bool { model.state.isLoading || model.state.loadedScope != key.scope }
    var body: some View {
        List {
            if reader.isOfflineExample { Label("accountCollection.offlineExample", systemImage: "testtube.2").font(.footnote).foregroundStyle(.secondary) }
            if !reader.isAuthenticated { AccountCollectionIssueView(issue: .login, favorites: true) }
            else if !reader.isConfigured { AccountCollectionIssueView(issue: .notConfigured) }
            else if isLoadingNow || skeletonShown {
                // Loading-to-content (docs/release/motion-spec-loading.md): spinner after 120 ms, held 350 ms.
                if skeletonShown {
                    ProgressView { Text("accountCollection.loading") }.frame(maxWidth: .infinity)
                }
            } else if let issue = model.state.issue {
                AccountCollectionIssueView(issue: issue, retry: { Task { await refresh() } }, favorites: true)
            } else {
                // mylike.wxml 推荐说明: shown once topics exist; honest that unfavoriting keeps recorded interest.
                if !model.state.visibleRows(scope: key.scope).filter({ !unliked.contains($0.id) }).isEmpty {
                    Button { showRecommendNote = true } label: {
                        Label { Text("member.favorites.recommendNote.entry", tableName: "MemberProfile") } icon: { Image(systemName: "info.circle") }
                    }
                    .accessibilityIdentifier("accountCollection.favorites.recommendNote")
                }
                if model.state.visibleRows(scope: key.scope).filter({ !unliked.contains($0.id) }).isEmpty {
                    ContentUnavailableView("accountCollection.favorites.empty", systemImage: "tray")
                        .accessibilityIdentifier("accountCollection.favorites.empty")
                }
                ForEach(Array(model.state.visibleRows(scope: key.scope).filter { !unliked.contains($0.id) }.enumerated()), id: \.element.id) { _, topic in
                    Button { onOpenTopic(topic.id) } label: { AccountCollectionFavoriteCard(topic: topic) }
                        .accessibilityIdentifier("accountCollection.favorite.\(topic.id)")
                        .overlay(alignment: .topTrailing) {
                            HStack(spacing: 0) {
                                // A4-04: MP mylike topic card 分享 (wxml:50-55) → the public topic link.
                                if let url = PublicContentShareLink.topic(id: topic.id) {
                                    ShareLink(item: url, subject: Text(verbatim: topic.name)) {
                                        // MP: pages/mylike/mylike.wxml:90 (icon_up.png, 32rpx glyph in the glass circle)
                                        MPAsset.FeatureIcon.iconUp.resizable().scaledToFit().frame(width: 16, height: 16)
                                            .frame(width: 44, height: 44)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(Text("accountCollection.favorite.share"))
                                    .accessibilityIdentifier("accountCollection.favorite.share.\(topic.id)")
                                }
                                if let unlike, unlike.isAvailable { TopicUnlikeButton(topicID: topic.id, controller: unlike) }
                            }
                        }
                        // A4-06: MP onReachBottom — the last card loads the next page; 加载更多 stays as the fallback.
                        .onAppear {
                            let rows = model.state.visibleRows(scope: key.scope)
                            guard topic.id == rows.last?.id, model.state.pagination.hasMore, !model.state.isLoadingMore,
                                  model.state.moreIssue == nil else { return }
                            Task { await loadMore() }
                        }
                }
                if let issue = model.state.moreIssue {
                    AccountCollectionIssueView(issue: issue, retry: { Task { await loadMore() } })
                } else if model.state.isLoadingMore { ProgressView { Text("cy.state.loading") }.frame(maxWidth: .infinity) }
                else if model.state.pagination.hasMore {
                    Button("accountCollection.loadMore") { Task { await loadMore() } }
                        .accessibilityIdentifier("accountCollection.favorites.loadMore")
                } else if !model.state.visibleRows(scope: key.scope).isEmpty {
                    Text("member.favorites.topicsEnd", tableName: "MemberProfile").font(.footnote).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).accessibilityIdentifier("accountCollection.favorites.end")
                }
            }
        }
        .listStyle(.insetGrouped)
        .cySkeletonTiming(isLoading: isLoadingNow && reader.isAuthenticated && reader.isConfigured, visible: $skeletonShown)
        // mylike.js onPullDownRefresh parity. Native restyle r1 (spec §3.1): pull to refresh is the one refresh.
        .refreshable { await refresh() }
        .modifier(AccountCollectionReadLifecycle(key: key, refresh: refresh, cancel: model.cancelPending))
        .modifier(TopicUnlikeFlow(controller: unlike) { unliked.insert($0) })
        .cySheet(isPresented: $showRecommendNote) {
            MemberFavoritesRecommendNoteSheet { showRecommendNote = false }
                .themeDomain(.player)
                .cySheet()
        }
    }
    private func refresh() async {
        guard reader.isAuthenticated, reader.isConfigured else { model.invalidate(); return }
        unliked = []
        async let gateReload: Void = reloadGate()
        await model.refresh(reader: reader, pageSize: pageSize)
        await gateReload
    }
    private func reloadGate() async { await retryGate?() }
    private func loadMore() async {
        guard reader.isAuthenticated, reader.isConfigured else { model.invalidate(); return }
        await model.loadMore(reader: reader, pageSize: pageSize)
    }
}

/// Native list row (thumbnail + title + metadata); artwork and topic routes remain server-backed.
private struct AccountCollectionFavoriteCard: View {
    let topic: TopicSummary
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if let url = QuestifyCardArtwork.safeURL(topic.imageURL) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() }
                        else { Image(systemName: "photo").foregroundStyle(.secondary) }
                    }
                } else {
                    Image(systemName: "photo").foregroundStyle(.secondary)
                }
            }
            .frame(width: 64, height: 64)
            .clipped()
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                if topic.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("accountCollection.favorites.untitled").font(.headline)
                } else {
                    Text(verbatim: topic.name).font(.headline)
                }
                Group {
                    if let categories = topic.favoriteCategoryText {
                        Label { Text(verbatim: categories) } icon: { Image(systemName: "tag").accessibilityHidden(true) }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text("accountCollection.favorites.categories") + Text(verbatim: ": " + categories))
                            .accessibilityIdentifier("accountCollection.favorite.categories.\(topic.id)")
                    }
                    // Unknown stop count is an em dash (pages/mylike page model), never 未知 or 0.
                    TopicTotalStops(count: topic.locationCount, identifier: "accountCollection.totalStops.\(topic.id)", unknownMark: AccountCollectionFavoritesDisplay.unknownMark)
                    if let place = topic.addressName, !place.isEmpty {
                        Label { Text(verbatim: place) } icon: { Image(systemName: "mappin.and.ellipse").accessibilityHidden(true) }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text("accountCollection.favorites.place") + Text(verbatim: ": " + place))
                    }
                }
                .font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Room for the share / unlike controls overlaid at the top trailing corner.
            .padding(.trailing, 88)
        }
        .foregroundStyle(.primary)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("accountCollection.favorites.openHint"))
    }
}

@MainActor struct AccountCollectionAccountLinks: View {
    let reader: any AccountCollectionReading
    let onOpenTopic: (Int) -> Void
    var rewards: (any NonCashRewardReading)? = nil
    var pledge: RewardPledgeEntry? = nil
    var onOpenPost: ((SquareContentRoute) -> Void)? = nil
    var favoriteRemoval: ProfileFavoriteRemovalController? = nil
    var couponReader: (any AccountCollectionReading)? = nil
    private var ownedCouponReader: any AccountCollectionReading { couponReader ?? reader }
    var favoritesReader: (any AccountCollectionReading)? = nil
    private var savedReader: any AccountCollectionReading { favoritesReader ?? reader }
    var rewardMerchant: PublicMerchantHomeContext? = nil
    var communityGate: (any SquareCommunityFeatureReading)? = nil
    var body: some View {
        let saved = savedReader, renderedScope = saved.scope
        Section {
            NavigationLink {
                NonCashRewardsView(reader: reader, rewards: rewards, merchantHome: rewardMerchant, pledge: pledge).id(reader.scope)
            } label: { Label("rewards.title", systemImage: "gift") }
            .accessibilityIdentifier("rewards.open")
            NavigationLink {
                AccountCollectionFavoritesView(reader: saved, onOpenTopic: { id in
                    guard saved.isAuthenticated, saved.isConfigured, saved.scope == renderedScope else { return }
                    onOpenTopic(id)
                }, onOpenPost: onOpenPost.map { open in { route in
                    guard saved.isAuthenticated, saved.isConfigured, saved.scope == renderedScope else { return }
                    open(route)
                } }, favoriteRemoval: favoriteRemoval, communityGate: communityGate).id(renderedScope)
            } label: { Label("accountCollection.favorites.title", systemImage: "heart") }
            .accessibilityIdentifier("accountCollection.openFavorites")
            NavigationLink {
                AccountCollectionCouponsView(reader: ownedCouponReader).id(ownedCouponReader.scope)
            } label: { Label("accountCollection.coupons.title", systemImage: "ticket") }
            .accessibilityIdentifier("accountCollection.openCoupons")
        }
    }
}

@MainActor private struct AccountCollectionFavoritePostsView: View {
    let reader: any AccountCollectionReading
    let pageSize: Int
    let onOpenPost: ((SquareContentRoute) -> Void)?
    let favoriteRemoval: ProfileFavoriteRemovalController?
    @StateObject private var model = AccountCollectionPostsScreenModel()
    private var key: AccountCollectionLoadKey { AccountCollectionLoadKey(reader: reader) }
    @State private var skeletonShown = false
    private var isLoadingNow: Bool { model.state.isLoading || model.state.loadedScope != key.scope }
    var body: some View {
        let renderedScope = key.scope
        List {
            if let favoriteRemoval, reader.isAuthenticated, reader.isConfigured {
                ProfileFavoriteRecoverySection(scope: renderedScope, controller: favoriteRemoval,
                    isCurrent: { reader.isAuthenticated && reader.isConfigured && reader.scope == renderedScope },
                    onRemoved: { await refresh() })
            }
            if reader.isOfflineExample { Label("accountCollection.offlineExample", systemImage: "testtube.2").font(.footnote).foregroundStyle(.secondary) }
            if !reader.isAuthenticated { AccountCollectionIssueView(issue: .login, favorites: true) }
            else if !reader.isConfigured { AccountCollectionIssueView(issue: .notConfigured) }
            else if isLoadingNow || skeletonShown {
                // Loading-to-content (docs/release/motion-spec-loading.md): spinner after 120 ms, held 350 ms.
                if skeletonShown {
                    ProgressView { Text("accountCollection.loading") }.frame(maxWidth: .infinity)
                }
            } else if let issue = model.state.issue {
                AccountCollectionIssueView(issue: issue, retry: { Task { await refresh() } }, favorites: true)
            } else if case .unknown? = model.pagePhase {
                // A missing or UNKNOWN list is not an empty collection.
                ContentUnavailableView {
                    Label("accountCollection.favorites.unknown", systemImage: "questionmark.circle")
                } actions: {
                    Button("accountCollection.retry") { Task { await refresh() } }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("accountCollection.retry")
                }
                .accessibilityIdentifier("accountCollection.posts.unknown")
            } else {
                if model.state.visibleRows(scope: key.scope).isEmpty {
                    ContentUnavailableView {
                        Label { Text("member.favorites.postsEmpty", tableName: "MemberProfile") } icon: { Image(systemName: "tray") }
                    }
                    .accessibilityIdentifier("accountCollection.posts.empty")
                }
                ForEach(model.state.visibleRows(scope: key.scope)) { post in
                    Button {
                        guard reader.isAuthenticated, reader.isConfigured,
                              model.state.loadedScope == reader.scope, post.generation == .legacySquare else { return }
                        onOpenPost?(.init(id: post.id, generation: post.generation))
                    } label: {
                        // A4-05 (mylike.wxml:25-27): the standard post card, images included.
                        SquarePostContent(post: post, compact: true, showImages: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(.primary)
                    }
                    .disabled(onOpenPost == nil)
                    .accessibilityIdentifier("accountCollection.post.\(post.id)")
                    // A4-06: the last post loads the next page (MP onReachBottom); 加载更多 stays as the fallback.
                    .onAppear {
                        guard post.id == model.state.visibleRows(scope: key.scope).last?.id, model.state.pagination.hasMore,
                              !model.state.isLoadingMore, model.state.moreIssue == nil else { return }
                        Task { await loadMore() }
                    }
                    // A4-05: 取消收藏 sits behind the card's ··· menu (same reviewed removal flow and sheet).
                    .overlay(alignment: .topTrailing) {
                        HStack(spacing: 0) {
                            // r8 A4-05b (MP mylike.wxml:25-27): 分享 on the favourite post card, public posts only.
                            if let url = PublicContentShareLink.squarePost(PublicContentShareLink.l5Post(from: post)) {
                                ShareLink(item: url) {
                                    Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(Text("fixr8.favorites.post.share"))
                                .accessibilityIdentifier("accountCollection.post.share.\(post.id)")
                            }
                            if let favoriteRemoval {
                                ProfileFavoriteRemovalEntry(post: post, scope: key.scope, controller: favoriteRemoval,
                                    isCurrent: { reader.isAuthenticated && reader.isConfigured && reader.scope == renderedScope && model.state.loadedScope == renderedScope },
                                    onRemoved: { await refresh() }, presentsAsMenu: true)
                            }
                        }
                    }
                    NativeMediaGalleryEntry(sources: post.images, scope: reader.scope, titleKey: "media.destination.squareImages")
                }
                if let issue = model.state.moreIssue {
                    AccountCollectionIssueView(issue: issue, retry: { Task { await loadMore() } })
                } else if model.state.isLoadingMore { ProgressView { Text("cy.state.loading") }.frame(maxWidth: .infinity) }
                else if model.state.pagination.hasMore {
                    Button("accountCollection.loadMore") { Task { await loadMore() } }
                        .accessibilityIdentifier("accountCollection.posts.loadMore")
                } else if !model.state.visibleRows(scope: key.scope).isEmpty {
                    Text("member.favorites.postsEnd", tableName: "MemberProfile").font(.footnote).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).accessibilityIdentifier("accountCollection.posts.end")
                }
            }
        }
        .listStyle(.insetGrouped)
        .cySkeletonTiming(isLoading: isLoadingNow && reader.isAuthenticated && reader.isConfigured, visible: $skeletonShown)
        .refreshable { await refresh() }
        .modifier(AccountCollectionReadLifecycle(key: key, refresh: refresh, cancel: model.cancelPending))
    }
    private func refresh() async {
        guard reader.isAuthenticated, reader.isConfigured else { model.invalidate(); return }
        await model.refresh(reader: reader, pageSize: pageSize)
    }
    private func loadMore() async {
        guard reader.isAuthenticated, reader.isConfigured else { model.invalidate(); return }
        await model.loadMore(reader: reader, pageSize: pageSize)
    }
}
