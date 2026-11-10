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
    @State private var selectedTab: Tab = .posts
    @State private var gateModel = AccountCollectionCommunityGateModel()
    private enum Tab: Hashable { case posts, topics }
    private var gateKey: AccountCollectionFavoritesGateKey { AccountCollectionFavoritesGateKey(reader: reader, gate: communityGate) }
    /// Nil, signed-out, unconfigured, pending, denied, and failed all stay closed.
    private var postsAllowed: Bool { gateModel.postsAllowed(reader: reader, gate: communityGate) }
    var body: some View {
        VStack(spacing: 0) {
            if postsAllowed {
                Picker("accountCollection.favorites.title", selection: $selectedTab) {
                    Text("social.posts").tag(Tab.posts)
                    Text("searchMap.kind.topic").tag(Tab.topics)
                }
                .pickerStyle(.segmented).padding(.horizontal, CYSpacing.pageHorizontal).padding(.vertical, CYSpacing.md)
                .accessibilityIdentifier("accountCollection.favorites.tabs")
            }
            if postsAllowed && selectedTab == .posts {
                AccountCollectionFavoritePostsView(reader: reader, pageSize: pageSize, onOpenPost: onOpenPost, favoriteRemoval: favoriteRemoval)
            } else {
                AccountCollectionFavoriteTopicsView(reader: reader, onOpenTopic: onOpenTopic, pageSize: pageSize, retryGate: {
                    await gateModel.load(reader: { reader }, gate: { communityGate }, forceRetry: gateModel.failed)
                })
            }
        }
        .appNavigationTitle("accountCollection.favorites.title")
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
    @State private var unliked: Set<Int> = []
    @State private var showRecommendNote = false
    private var key: AccountCollectionLoadKey { AccountCollectionLoadKey(reader: reader) }
    var body: some View {
        List {
            if reader.isOfflineExample { CYStatusChip("accountCollection.offlineExample", tone: .neutral, systemImage: "testtube.2").listRowBackground(Color.clear).listRowSeparator(.hidden) }
            if !reader.isAuthenticated { AccountCollectionIssueView(issue: .login) }
            else if !reader.isConfigured { AccountCollectionIssueView(issue: .notConfigured) }
            else if model.state.isLoading || model.state.loadedScope != key.scope {
                CYSkeleton()
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
                    CYEmptyState(systemImage: "heart", "accountCollection.favorites.empty", messageIdentifier: "accountCollection.favorites.empty", kind: .favorites)
                        .listRowBackground(Color.clear).listRowSeparator(.hidden)
                }
                ForEach(model.state.visibleRows(scope: key.scope).filter { !unliked.contains($0.id) }) { topic in
                    Button { onOpenTopic(topic.id) } label: { AccountCollectionFavoriteCard(topic: topic) }
                        .buttonStyle(QuestifyCardButtonStyle())
                        .accessibilityIdentifier("accountCollection.favorite.\(topic.id)")
                        .overlay(alignment: .topTrailing) {
                            if let unlike, unlike.isAvailable { TopicUnlikeButton(topicID: topic.id, controller: unlike).padding(8) }
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
                    Text("member.favorites.topicsEnd", tableName: "MemberProfile").font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                        .frame(maxWidth: .infinity).accessibilityIdentifier("accountCollection.favorites.end")
                }
            }
        }
        .listStyle(.insetGrouped)
        .cyGroupedSurface()
        // mylike.js onPullDownRefresh parity: same guarded refresh as the toolbar button.
        .refreshable { await refresh() }
        .appNavigationTitle("accountCollection.favorites.title")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { Task { await refresh() } } label: { Label("accountCollection.refresh", systemImage: "arrow.clockwise") }
                    .disabled(model.state.isLoading || !reader.isAuthenticated || !reader.isConfigured)
                    .accessibilityIdentifier("accountCollection.favorites.refresh")
            }
        }
        .modifier(AccountCollectionReadLifecycle(key: key, refresh: refresh, cancel: model.cancelPending))
        .modifier(TopicUnlikeFlow(controller: unlike) { unliked.insert($0) })
        .alert(Text("member.favorites.recommendNote.title", tableName: "MemberProfile"), isPresented: $showRecommendNote) {
            Button(role: .cancel) {} label: { Text("member.favorites.recommendNote.dismiss", tableName: "MemberProfile") }
        } message: {
            Text("member.favorites.recommendNote.body", tableName: "MemberProfile")
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
                    .lineLimit(1).truncationMode(.tail)
                    .accessibilityIdentifier("accountCollection.favorite.categories.\(topic.id)")
            }
            TopicTotalStops(count: topic.locationCount, identifier: "accountCollection.totalStops.\(topic.id)")
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
            else if model.state.isLoading || model.state.loadedScope != key.scope {
                CYSkeleton()
            } else if let issue = model.state.issue {
                AccountCollectionIssueView(issue: issue, retry: { Task { await refresh() } })
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
                        SquarePostContent(post: post, compact: true, showImages: false)
                            .padding(CYSpacing.lg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(CYColor.borderSubtle))
                    }
                    .buttonStyle(QuestifyCardButtonStyle())
                    .disabled(onOpenPost == nil)
                    .accessibilityIdentifier("accountCollection.post.\(post.id)")
                    .questifyCardListRow()
                    if let favoriteRemoval {
                        ProfileFavoriteRemovalEntry(post: post, scope: key.scope, controller: favoriteRemoval,
                            isCurrent: { reader.isAuthenticated && reader.isConfigured && reader.scope == renderedScope && model.state.loadedScope == renderedScope },
                            onRemoved: { await refresh() })
                    }
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
                    Text("member.favorites.postsEnd", tableName: "MemberProfile").font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                        .frame(maxWidth: .infinity).accessibilityIdentifier("accountCollection.posts.end")
                }
            }
        }
        .listStyle(.insetGrouped)
        .cyGroupedSurface()
        .refreshable { await refresh() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { Task { await refresh() } } label: { Label("accountCollection.refresh", systemImage: "arrow.clockwise") }
                    .disabled(model.state.isLoading || !reader.isAuthenticated || !reader.isConfigured)
                    .accessibilityIdentifier("accountCollection.posts.refresh")
            }
        }
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
