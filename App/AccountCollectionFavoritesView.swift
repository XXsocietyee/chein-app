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
    private var favoriteTabs: [CYTabItem<Tab>] {
        var items: [CYTabItem<Tab>] = []
        if postsAllowed { items.append(.init(id: .posts, title: appLocalized("social.posts", locale: locale))) }
        items.append(.init(id: .topics, title: appLocalized("searchMap.kind.topic", locale: locale)))
        if showsCityNodesTab { items.append(.init(id: .cityNodes, title: appLocalized("accountCollection.favorites.nodesTab", locale: locale))) }
        return items
    }
    var body: some View {
        VStack(spacing: 0) {
            // A4-02: 删除我的帖文 lives on 我的帖文 / 帖文详情 / 俱乐部, not on 我的收藏 (MP mylike has no such block).
            if postsAllowed || showsCityNodesTab {
                // X5 (MP owner ruling 2026-07-31): underline tabs switch content areas, as on mylike.
                CYTabs(items: favoriteTabs, selection: $selectedTab, variant: .underline)
                    .padding(.horizontal, CYSpacing.pageHorizontal).padding(.vertical, CYSpacing.sm)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(Text("accountCollection.favorites.title"))
                    .accessibilityIdentifier("accountCollection.favorites.tabs")
            }
            if showsCityNodesTab && selectedTab == .cityNodes {
                List { CityFavoriteNodesSection() }
                    .listStyle(.insetGrouped)
                    .cyGroupedSurface()
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
    @State private var stagger = CYStaggerGate()
    private var isLoadingNow: Bool { model.state.isLoading || model.state.loadedScope != key.scope }
    var body: some View {
        List {
            if reader.isOfflineExample { CYStatusChip("accountCollection.offlineExample", tone: .neutral, systemImage: "testtube.2").listRowBackground(Color.clear).listRowSeparator(.hidden) }
            if !reader.isAuthenticated { AccountCollectionIssueView(issue: .login) }
            else if !reader.isConfigured { AccountCollectionIssueView(issue: .notConfigured) }
            else if isLoadingNow || skeletonShown {
                // Loading-to-content (docs/release/motion-spec-loading.md): skeleton after 120 ms, held 350 ms.
                if skeletonShown {
                    CYLoadingStateView(rows: 4)
                        .accessibilityLabel(Text("accountCollection.loading"))
                        .listRowBackground(Color.clear).listRowSeparator(.hidden).listRowInsets(EdgeInsets())
                        .transition(.opacity)
                }
            } else if let issue = model.state.issue {
                AccountCollectionIssueView(issue: issue, retry: { Task { await refresh() } })
            } else {
                // mylike.wxml 推荐说明: shown once topics exist; honest that unfavoriting keeps recorded interest.
                if !model.state.visibleRows(scope: key.scope).filter({ !unliked.contains($0.id) }).isEmpty {
                    Button { showRecommendNote = true } label: {
                        Label { Text("member.favorites.recommendNote.entry", tableName: "MemberProfile") } icon: { Image(systemName: "info.circle") }
                    }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("accountCollection.favorites.recommendNote")
                }
                if model.state.visibleRows(scope: key.scope).filter({ !unliked.contains($0.id) }).isEmpty {
                    CYEmptyState(systemImage: "heart", "accountCollection.favorites.empty", detail: "accountCollection.favorites.emptyHint", messageIdentifier: "accountCollection.favorites.empty", kind: .favorites)
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                }
                ForEach(Array(model.state.visibleRows(scope: key.scope).filter { !unliked.contains($0.id) }.enumerated()), id: \.element.id) { index, topic in
                    Button { onOpenTopic(topic.id) } label: { AccountCollectionFavoriteCard(topic: topic) }
                        .buttonStyle(QuestifyCardButtonStyle())
                        .cyStaggeredAppear(index: index, gate: stagger)
                        .accessibilityIdentifier("accountCollection.favorite.\(topic.id)")
                        .overlay(alignment: .topTrailing) {
                            HStack(spacing: CYSpacing.sm) {
                                // A4-04: MP mylike topic card 分享 (wxml:50-55) → the public topic link.
                                if let url = PublicContentShareLink.topic(id: topic.id) {
                                    ShareLink(item: url, subject: Text(verbatim: topic.name)) {
                                        Image(systemName: "square.and.arrow.up").font(.title3).padding(10)
                                            .background(.thinMaterial, in: Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(Text("accountCollection.favorite.share"))
                                    .accessibilityIdentifier("accountCollection.favorite.share.\(topic.id)")
                                }
                                if let unlike, unlike.isAvailable { TopicUnlikeButton(topicID: topic.id, controller: unlike) }
                            }
                            .padding(8)
                        }
                        // A4-06: MP onReachBottom — the last card loads the next page; 加载更多 stays as the fallback.
                        .onAppear {
                            let rows = model.state.visibleRows(scope: key.scope)
                            guard topic.id == rows.last?.id, model.state.pagination.hasMore, !model.state.isLoadingMore,
                                  model.state.moreIssue == nil else { return }
                            Task { await loadMore() }
                        }
                        .questifyCardListRow()
                }
                if let issue = model.state.moreIssue {
                    AccountCollectionIssueView(issue: issue, retry: { Task { await loadMore() } })
                } else if model.state.isLoadingMore { CYSkeleton() }
                else if model.state.pagination.hasMore {
                    Button("accountCollection.loadMore") { Task { await loadMore() } }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("accountCollection.favorites.loadMore")
                } else if !model.state.visibleRows(scope: key.scope).isEmpty {
                    Text("member.favorites.topicsEnd", tableName: "MemberProfile").cyText(.meta).foregroundStyle(CYColor.textTertiary)
                        .frame(maxWidth: .infinity).accessibilityIdentifier("accountCollection.favorites.end")
                }
            }
        }
        .listStyle(.insetGrouped)
        .cyGroupedSurface()
        .cySkeletonTiming(isLoading: isLoadingNow && reader.isAuthenticated && reader.isConfigured, visible: $skeletonShown)
        .cyAnimation(.easeInOut(duration: CYMotion.Duration.quick), value: skeletonShown)
        // mylike.js onPullDownRefresh parity. Native restyle r1 (spec §3.1): pull to refresh is the one refresh.
        .refreshable { await refresh() }
        .modifier(AccountCollectionReadLifecycle(key: key, refresh: refresh, cancel: model.cancelPending))
        .modifier(TopicUnlikeFlow(controller: unlike) { unliked.insert($0) })
        .sheet(isPresented: $showRecommendNote) {
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

/// Shared full-bleed card; artwork and topic routes remain server-backed.
private struct AccountCollectionFavoriteCard: View {
    let topic: TopicSummary
    var body: some View {
        QuestifyImageEntityCard(imageSource: topic.imageURL, title: topic.name,
                               fallbackTitle: "accountCollection.favorites.untitled",
                               fallbackSymbol: "photo", minimumHeight: 250) {
            if let categories = topic.favoriteCategoryText {
                QuestifyImageEntityMetadata(label: "accountCollection.favorites.categories", value: categories, systemImage: "tag")
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("accountCollection.favorite.categories.\(topic.id)")
            }
            // Unknown stop count is an em dash (pages/mylike page model), never 未知 or 0.
            TopicTotalStops(count: topic.locationCount, identifier: "accountCollection.totalStops.\(topic.id)", unknownMark: AccountCollectionFavoritesDisplay.unknownMark)
            if let place = topic.addressName, !place.isEmpty {
                QuestifyImageEntityMetadata(label: "accountCollection.favorites.place", value: place, systemImage: "mappin.and.ellipse")
            }
        }
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
            if reader.isOfflineExample { CYStatusChip("accountCollection.offlineExample", tone: .neutral, systemImage: "testtube.2").listRowBackground(Color.clear).listRowSeparator(.hidden) }
            if !reader.isAuthenticated { AccountCollectionIssueView(issue: .login) }
            else if !reader.isConfigured { AccountCollectionIssueView(issue: .notConfigured) }
            else if isLoadingNow || skeletonShown {
                // Loading-to-content (docs/release/motion-spec-loading.md): skeleton after 120 ms, held 350 ms.
                if skeletonShown {
                    CYLoadingStateView(rows: 4)
                        .accessibilityLabel(Text("accountCollection.loading"))
                        .listRowBackground(Color.clear).listRowSeparator(.hidden).listRowInsets(EdgeInsets())
                        .transition(.opacity)
                }
            } else if let issue = model.state.issue {
                AccountCollectionIssueView(issue: issue, retry: { Task { await refresh() } })
            } else if case .unknown? = model.pagePhase {
                // A missing or UNKNOWN list is not an empty collection.
                CYEmptyState(systemImage: "questionmark.circle", "accountCollection.favorites.unknown",
                             messageIdentifier: "accountCollection.posts.unknown", actionTitle: "accountCollection.retry",
                             actionIdentifier: "accountCollection.retry", kind: .failure) { Task { await refresh() } }
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
            } else {
                if model.state.visibleRows(scope: key.scope).isEmpty {
                    CYEmptyState(systemImage: "bookmark", "member.favorites.postsEmpty", tableName: "MemberProfile", messageIdentifier: "accountCollection.posts.empty", kind: .favorites)
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                }
                ForEach(model.state.visibleRows(scope: key.scope)) { post in
                    Button {
                        guard reader.isAuthenticated, reader.isConfigured,
                              model.state.loadedScope == reader.scope, post.generation == .legacySquare else { return }
                        onOpenPost?(.init(id: post.id, generation: post.generation))
                    } label: {
                        // A4-05 (mylike.wxml:25-27): the standard post card, images included.
                        SquarePostContent(post: post, compact: true, showImages: true)
                            .padding(CYSpacing.lg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).strokeBorder(CYColor.borderSubtle))
                    }
                    .buttonStyle(QuestifyCardButtonStyle())
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
                        if let favoriteRemoval {
                            ProfileFavoriteRemovalEntry(post: post, scope: key.scope, controller: favoriteRemoval,
                                isCurrent: { reader.isAuthenticated && reader.isConfigured && reader.scope == renderedScope && model.state.loadedScope == renderedScope },
                                onRemoved: { await refresh() }, presentsAsMenu: true)
                                .padding(.trailing, CYSpacing.xs)
                        }
                    }
                    .questifyCardListRow()
                    NativeMediaGalleryEntry(sources: post.images, scope: reader.scope, titleKey: "media.destination.squareImages")
                }
                if let issue = model.state.moreIssue {
                    AccountCollectionIssueView(issue: issue, retry: { Task { await loadMore() } })
                } else if model.state.isLoadingMore { CYSkeleton() }
                else if model.state.pagination.hasMore {
                    Button("accountCollection.loadMore") { Task { await loadMore() } }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("accountCollection.posts.loadMore")
                } else if !model.state.visibleRows(scope: key.scope).isEmpty {
                    Text("member.favorites.postsEnd", tableName: "MemberProfile").cyText(.meta).foregroundStyle(CYColor.textTertiary)
                        .frame(maxWidth: .infinity).accessibilityIdentifier("accountCollection.posts.end")
                }
            }
        }
        .listStyle(.insetGrouped)
        .cyGroupedSurface()
        .cySkeletonTiming(isLoading: isLoadingNow && reader.isAuthenticated && reader.isConfigured, visible: $skeletonShown)
        .cyAnimation(.easeInOut(duration: CYMotion.Duration.quick), value: skeletonShown)
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
