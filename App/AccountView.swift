import SwiftUI

@MainActor struct AccountView: View {
    let account: Account
    var privateHomeCoordinator: PrivateHomeCoordinator? = nil
    var nativeHomeReturnSelection: NativeHomeReturnSelectionCoordinator? = nil
    var onOpenGuideDestination: ((SocialGuideDestination) -> Void)? = nil
    /// W1-4: true when hosted as the Passport tab root (adds the actions + stamp grid, renames the title).
    var showsPassportOverview = false
    /// W3-6: a chein://ticket link asks for the ticket pass sheet; consumed (cleared) here.
    var presentsTicketPass: Binding<Bool>? = nil
    @EnvironmentObject private var session: AppSession
    @State private var savedTopicOwner = ProfileFavoriteTopicNavigationOwner()
    @State private var savedPostOwner = ProfileFavoriteNavigationOwner()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(RootPresentationCoordinator.self) private var presentation: RootPresentationCoordinator?
    @State private var showsSettings=false
    /// mp-mine r3: MP cy-profile tab (`activeTab`); self opens on 我的 (projects), as the MP self view does.
    @State private var mineTab = AccountMineTab.mine
    /// The identity card's ready user-info snapshot, shown on 关于 (MP reads one userInfo for the header and 关于).
    @State private var aboutSnapshot: MemberIdentitySnapshot?
    @Environment(\.socialRoamCapabilities) private var socialRoamCapabilities
    /// MP profileTabs: 帖文 only when the community is readable (here: the square bundle is injected).
    private var mineTabs: [AccountMineTab] {
        AccountMineTab.allCases.filter { $0 != .posts || socialRoamCapabilities?.squareMine != nil }
    }
    private var activeMineTab: AccountMineTab { mineTabs.contains(mineTab) ? mineTab : .mine }
    @State private var memberRefreshToken = 0
    @State private var settingsGuideHandoff = SettingsGuideHandoff()
    @State private var showsTickets=false
    @State private var showsTicketPass=false
    @State private var showsPassportWallet=false
    @State private var showsPointsLedger=false
    @State private var showsPointsHelp=false
    @State private var showsEditProfile=false
    @State private var showsPublicProfile=false
    @Environment(\.locale) private var locale
    @State private var showsPassportMessages=false
    @State private var showsPassportStamps=false
    @State private var showsPassportBadges=false
    @State private var opensWalletAfterPass=false
    @State private var showsCooperation=false
    @State private var confirmsLogout=false
    @State private var logoutConfirmation: AuthChannelSessionSnapshot?
    private var localCoverOwner: ProfileLocalCoverOwner? {
        ProfileLocalCoverOwner.make(accountID: account.id, configuration: session.regionalConfiguration)
    }
    var body: some View {
        NavigationStack {
            Form {
                // mp-mine r3 (14:13 visual check): MP order — identity card → 好友/关注/粉丝 → [开始探索][票夹][···] → tabs.
                // 积分 and 连续打卡 live on 成就 (showsMetrics: false); 账户余额 is the 我的 → 我的资产 row.
                MemberIdentityCardSection(account: account, reader: session.memberHomeReader, growth: session.growthCenterReader, onOpenTickets: { showsTicketPass = true },
                                          // A1-04: the avatar opens 个人资料 (MP onAvatarTap).
                                          onEditProfile: { showsEditProfile = true },
                                          refreshToken: memberRefreshToken, avatarAccess: session.memberIdentityAvatarAccess,
                                          onSnapshot: { aboutSnapshot = $0 },
                                          showsMetrics: false,
                                          // MP onPrimaryCta (self player) = goRoam.
                                          onStartExplore: onOpenGuideDestination.map { open in { open(.roam) } },
                                          moreMenu: AnyView(mineMoreMenu))
                // mp-mine r3: MP cy-profile tabs under the action row — 项目 · 帖文 · 成就 · 关于 (wxml TAB · 项目; 我的 is the page title);
                // a system segmented picker, as on the public profile (SocialPublicProfileView).
                Section {
                    Picker(selection: $mineTab) {
                        ForEach(mineTabs, id: \.self) { item in Text(item.titleKey).tag(item) }
                    } label: { Text("social.profileSection") }
                        .cyAdaptiveSegmented()
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(Text("social.profileSection"))
                        .accessibilityIdentifier("account.mine.tabs")
                }
                switch activeMineTab {
                case .mine: mineTabSections
                case .posts: postsTabSections
                case .achievements: achievementsTabSections
                case .about: aboutTabSections
                }
            }
            // Pull to refresh: light tick at release; the cards reload in place (numbers roll, nothing re-enters).
            .cyRefreshable { await MainActor.run { memberRefreshToken += 1 } }
            .cyDomainPageBackground()
            // Design hand-off r1 PL-11: the root title is the tab's label (我的), not 主页 / 护照; 消息 then 设置 at the right.
            .cyRootHeader(.mine)
            .modifier(SessionMessagingToolbarEntry(session: session))
            // Stamp grid cells zoom into the stamp detail (Passport tab only draws the cells).
            .cyPassportStampHost()
            .environment(\.nativeVerificationDestination, {
                AnyView(SessionNativeVerificationView().modifier(MerchantVerificationPopupCompanionModifier(flow: session.nativeVerificationFlow)))
            })
            .toolbar {
                ToolbarItem(placement:.topBarTrailing) {
                    Button {
                        if settingsGuideHandoff.begin() { showsSettings=true }
                    } label: {
                        // MP profile index.wxml:17 `/subpackageMember/images/icon_set.png`.
                        Label { Text("settings.title") } icon: { AccountPublishMPGlyph(MPAsset.FeatureIcon.iconSet, side: 22) }
                    }
                    .accessibilityLabel(Text("settings.title"))
                    .accessibilityIdentifier("account.settings")
                }
            }
            .navigationDestination(isPresented:$showsPassportWallet) { SessionWalletCommerceView().id(session.walletCommerceScope).cyPushedChrome() }
            .navigationDestination(isPresented:$showsPublicProfile) { publicProfileDestination }
            .navigationDestination(isPresented:$showsPointsLedger) { WalletLedgerView(reader: session.walletHistoryReader, kind: .assetPoints).id(session.walletCommerceScope).cyPushedChrome() }
            .navigationDestination(isPresented:$showsEditProfile) { ProfileEditView(coordinator:session.profileEditCoordinator,sessionRevision:session.contentDetailRevision,categoryReader:session,avatarDependencies:session.profileAvatarDependencies,currentReviewReader:session.profileCurrentReviewReader,nicknameReader:session.profileNicknameReader,savedMedia:session.profileSavedMediaReaders).localCover(owner:localCoverOwner,reader:session.socialAccountReader).cyPushedChrome() }
            .cySheet(isPresented:$showsPointsHelp) {
                NavigationStack {
                    WalletPointsTasksView(reader: session.walletHistoryReader).id(session.walletCommerceScope)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("common.close") { showsPointsHelp = false }.accessibilityIdentifier("member.pointsHelp.close") } }
                }
                .themeDomain(.player)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .navigationDestination(isPresented:$showsPassportMessages) { SessionMessagingHome(session: session).cyPushedChrome() }
            // A1-06: 邮票 opens the stamp album and 勋章 the badge wall, as the MP 收集册 piles do.
            .navigationDestination(isPresented:$showsPassportStamps) {
                // P-077 "See All": the account's stamp album (same page and read as the roam passport) when configured.
                if session.roamAlbumMetadataReader.isConfigured {
                    RoamAlbumMetadataDestination(reader: session.roamAlbumMetadataReader,
                        stampDestination: { [session] in AnyView(SessionRoamStampCameraView().environmentObject(session)) })
                        .id(session.roamAlbumMetadataReader.scope).cyPushedChrome()
                } else {
                    RoamStampAlbumView(reader: session.roamExperienceReader,
                    // SALBUM-r7-1: the camera item / empty CTA open the session camera, not the disabled bare one.
                    stampDestination: { [session] in AnyView(SessionRoamStampCameraView().environmentObject(session)) }).cyPushedChrome()
                }
            }
            .navigationDestination(isPresented:$showsPassportBadges) { ObjectBadgeWallView(reader: session.profileReader, media: session.makeObjectCardImageLoader()).cyPushedChrome() }
            .background {
                ProfileFavoriteTopicNavigationLayer(owner: savedTopicOwner) { selected in
                    ProfileFavoriteTopicDestination(selection: selected, session: session,
                        makeReader: { session.makeProfileFavoriteTopicReader(selected) }).id(selected.id).cyPushedChrome()
                }
                ProfileFavoriteNavigationLayer(owner: savedPostOwner) { selected in
                    ProfileFavoriteDetailDestination(selection: selected,
                        makeReader: { session.makeProfileFavoriteDetailReader(selected) },
                        accountReader: session.socialAccountReader, actions: session.socialActionCoordinator)
                        .id(selected.id)
                        .cyPushedChrome()
                }
            }
            .onChange(of: session.profileFavoritesReader.scope) { _, scope in
                savedPostOwner.updateScope(scope); savedTopicOwner.updateScope(scope)
            }
            .cySheet(isPresented:$showsSettings, onDismiss: settingsDismissHandler) { Group {
                let presentation = settingsGuideHandoff.presentation
                let revision = session.sessionRevision
                SettingsView(onOpenGuideDestination: onOpenGuideDestination.map { open in { destination in
                    guard showsSettings, session.sessionRevision == revision,
                          settingsGuideHandoff.request(presentation, action: {
                              guard session.sessionRevision == revision else { return }
                              open(destination)
                          }) else { return }
                    showsSettings = false
                } })
                .themeDomain(.player)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            }
            .cySheet(isPresented:$showsCooperation) { Group {
                CooperationBrowserView(reader:session.cooperationReader,onClose:{ showsCooperation=false },peerReader:session.cooperationFlowReader,topicDestination:{ AnyView(SessionTopicDetailView(id:$0,session:session)) }).id(session.cooperationReader.scope)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            }
            .cySheet(isPresented:$showsTicketPass, onDismiss: { if opensWalletAfterPass { opensWalletAfterPass = false; showsTickets = true } }) {
                TicketPassSheet(reader: session.ticketWalletReader, onClose: { showsTicketPass = false },
                                onOpenWallet: { opensWalletAfterPass = true; showsTicketPass = false },
                                lifecycleCoordinator: session.orderLifecycleCoordinator, makeTeamCoordinator: { session.makeTeamCoordinator() })
                    .environment(\.ticketWalletPlayProvider, ticketPlayProvider)
                    .id(session.ticketWalletReader.scope)
                    .themeDomain(.player)
                    .cySheet(detents: [.large])
            }
            // mp-nav r3: MP navigateTo /subpackageMember/market/passes/index is a page: the wallet pushes (no own stack, no close).
            .navigationDestination(isPresented:$showsTickets) { TicketWalletView(reader:session.ticketWalletReader,makeTeamCoordinator:{ session.makeTeamCoordinator() },orderLifecycleCoordinator:session.orderLifecycleCoordinator,isPushed:true).environment(\.ticketWalletPlayProvider, ticketPlayProvider).environment(\.ticketWalletPendingOrderProvider, ticketPendingOrderProvider).id(session.ticketWalletReader.scope).themeDomain(.player).cyPushedChrome() }
            // G-047: the system sign-out action sheet, bound to the snapshot captured when 退出登录 was tapped.
            .memberSignOutConfirmation(isPresented: $confirmsLogout, presenting: logoutConfirmation,
                                       confirmIdentifier: "auth.signOut.confirm") { expected in
                logoutConfirmation = nil; confirmsLogout = false
                Task { _ = await session.logout(matching: expected) }
            }
            .onChange(of: confirmsLogout) { _, visible in if !visible { logoutConfirmation = nil } }
        }
        .onAppear { savedPostOwner.appear(scope: session.profileFavoritesReader.scope, foreground: scenePhase == .active); savedTopicOwner.appear(scope: session.profileFavoritesReader.scope, foreground: scenePhase == .active) }
        .onDisappear { savedPostOwner.disappear(); savedTopicOwner.disappear(); logoutConfirmation = nil; confirmsLogout = false; presentation?.setSheet("passport", open: false) }
        .onChange(of: presentsTicketPass?.wrappedValue, initial: true) { _, requested in
            guard requested == true else { return }
            showsTicketPass = true; presentsTicketPass?.wrappedValue = false
        }
        .onChange(of: confirmsLogout) { _, visible in if !visible { logoutConfirmation = nil } }
        // Settings, Cooperation and the wallet cover the tabs: a replayed chein:// link waits until they close.
        .onChange(of: showsSettings || showsCooperation) { _, open in presentation?.setSheet("passport", open: open) }
        .onChange(of: session.authChannelSnapshot) { _, _ in logoutConfirmation = nil; confirmsLogout = false }
        .onChange(of: scenePhase) { _, phase in savedPostOwner.setForeground(phase == .active); savedTopicOwner.setForeground(phase == .active) }
    }

    /// MP 项目: 订单 → 项目 → 视频悬赏 → 我的资产 (账户余额 · 通行证与礼品), then the app-only rows.
    @ViewBuilder private var mineTabSections: some View {
        MotionR2ChecklistSection() // motion r2 R10: first-run checklist (hidden once done or off)
        ProfileAccountLinks(reader:session.profileReader,scoreAppealsDestination:{ AnyView(MemberScoreAppealListView(session: session)) },ordersDestination:{ AnyView(SessionOwnedOrdersView(session: session)) },participantReader:session.participantReader,participantCoordinator:session.participantCoordinator,orderLifecycleCoordinator:session.orderLifecycleCoordinator, mediaScope:session.platformConsumers.scope, makeExternalMaps:session.platformConsumers.mapsFactory, part: .orders)
        // MP 我的项目 (管理全部): the same project preview the public profile 我的 tab shows; legacy host keeps the creator rows.
        if showsPassportOverview {
            ProfileSelfProjectsEntry(memberID: account.id, accountReader: session.socialAccountReader,
                access: .init(session: session), isCurrent: { session.account?.id == account.id })
        }
        MPParityAccountLinks(part: .bounty) // promo / video bounty; hidden until their bindings are injected
        Section("wallet.assets") {
            // mp-mine r3: MP 我的 → 我的资产 is a row on the 我的 tab for every host (the Passport circle row is gone).
            // MP pc-asset: 账户余额 with the balance (P-49: unknown reads ¥0, never "—") → earnings/wallet.
            NavigationLink { SessionWalletCommerceView().id(session.walletCommerceScope).cyPushedChrome()                     } label: {
                LabeledContent {
                    Text(verbatim: MemberBalanceDisplay.text(aboutSnapshot?.balanceText ?? "0", locale: locale)).monospacedDigit()
                } label: {
                    Label { Text("member.card.balance", tableName: "MemberProfile") } icon: { Image(systemName: "wallet.pass") }
                }
            }.accessibilityIdentifier("account.wallet")
            ModSettlementAccountLink(makeReader: { session.makeModSettlementReader() })
            MPPassAssetsLink() // 通行证与礼品 under assets; hidden until its binding is injected, and for merchants
        }
        // App-only rows after the MP sections (MP 我的发票 is a 设置 row: SettingsInvoiceEntry, MP shezhi.js goInvoice).
        PlayerJourneyAccountLinks()
        if !showsPassportOverview { AccountRoleSections() } // Passport hosts these in Settings instead
        MPParityAccountLinks(part: .extras) // host tips, channel redeem, content landing
    }

    /// MP 帖文: the member's own posts (and bookmarks), shown only when the community bundle is readable.
    @ViewBuilder private var postsTabSections: some View {
        SquareMineAccountLinks() // 我的帖文 / 我的收藏; hidden without the G4 capability bundle
    }

    /// The member's own public profile (关于 row and the ··· menu).
    private var publicProfileDestination: some View {
        ProfilePublicInfoHost(reader: session.makeProfilePublicInfoReader(memberID: account.id)) { profileReader in
                SocialPublicProfileView(memberID: account.id, reader: profileReader, squareReader: session.squareReader, actions: session.socialActionCoordinator, selfOrdersAccess: .init(session: session), selfProjectsAccess: .init(session: session), selfGrowthAccess: .init(reader: session.growthCenterReader, owner: session.socialAccountReader.identity), memberAttributesService: session.makeCityMonopolyService(), weeklyPointsAccess: .init(reader: PassMarketPointsBridge.statistics(for: session), owner: session.socialAccountReader.identity), personalToolsAccess: .init(owner: session.socialAccountReader.identity, wallet: session.walletHistoryReader, complaint: session.cooperationFlowReader), selfCouponAccess: .init(reader: session.profileOwnedCouponReader, owner: session.socialAccountReader.identity), selfObjectCardsAccess: .init(reader: session.objectCardReader, owner: session.socialAccountReader.identity), selfMedalsReader: session.profileReader, selfEditAccess: .init(coordinator: session.profileEditCoordinator, sessionRevision: session.contentDetailRevision, categoryReader: session, nicknameReader: session.profileNicknameReader, currentReviewReader: session.profileCurrentReviewReader, savedMedia: session.profileSavedMediaReaders, avatarDependencies: session.profileAvatarDependencies), localCoverOwner: localCoverOwner, isCurrent: { profileReader.isCurrent })
            }.id(session.socialAccountReader.identity).cyPushedChrome()
    }

    /// The ··· menu after 开始探索 / 票夹: the public profile and 编辑资料 (both reachable elsewhere on 我的 too).
    @ViewBuilder private var mineMoreMenu: some View {
        Button { showsPublicProfile = true } label: { Label("social.profile", systemImage: "person.crop.rectangle") }
        Button { showsEditProfile = true } label: { Label("profile.edit.title", systemImage: "pencil") }
    }

    /// MP 成就: 积分 (如何获取积分) → 连续打卡 / 累计打卡 → 总积分排名 (成长中心), then stamps, badges and the 收集册.
    @ViewBuilder private var achievementsTabSections: some View {
        MemberAchievementMetricsSection(growth: session.growthCenterReader, refreshToken: memberRefreshToken,
                                        // A1-07: 积分 opens 积分明细 directly (MP goPointsHistory); 如何获取积分 opens 积分任务.
                                        onOpenPoints: { showsPointsLedger = true }, onOpenPointsHelp: { showsPointsHelp = true }) {
            NavigationLink { GrowthCenterView(reader:session.growthCenterReader).id(session.growthCenterReader.scope)
                    .environment(\.growthExploreHomeAction, onOpenGuideDestination.map { open in { open(.home) } })
                    .cyPushedChrome()
            } label: {
                Label("growth.title", systemImage: "chart.bar.xaxis")
            }.accessibilityIdentifier("account.growthCenter")
        }
        if showsPassportOverview {
            PassportOverviewSection(reader: session.roamExperienceReader, album: session.roamAlbumMetadataReader, growth: session.growthCenterReader, refreshToken: memberRefreshToken, onOpenTickets: { showsTicketPass = true },
                                    // verify-r1: 票夹 is the card's pill; no second 票夹 circle 250 pt lower (same destination).
                                    showsTicketsAction: false,
                                    // mp-mine r3: MP 成就 has no Wallet / Messages buttons; Wallet is a 我的 → 我的资产 row, Messages the toolbar entry.
                                    showsActions: false,
                                    onOpenWallet: { showsPassportWallet = true }, onOpenMessages: { showsPassportMessages = true },
                                    onOpenStamps: session.roamExperienceReader.isConfigured || session.roamAlbumMetadataReader.isConfigured ? { showsPassportStamps = true } : nil,
                                    onOpenBadges: { showsPassportBadges = true },
                                    badgeWall: session.profileReader)
        }
        Section("account.section.collection") {
            ProfileAccountLinks(reader:session.profileReader, part: .collection)
            NavigationLink { SessionObjectCardsView().cyPushedChrome()                     } label: {
                Label { Text("objects.title") } icon: { AccountPublishMPRowIcon(MPAsset.FeatureIcon.object3d) } // MP album 藏品 object-3d.png
            }.accessibilityIdentifier("account.objectCards")
            if session.playerGapService != nil {
                NavigationLink { List { CityFavoriteNodesSection() }.navigationTitle(Text("playerGap.cityFavorites.title")).navigationBarTitleDisplayMode(.inline).cyPushedChrome() } label: {
                    Label("playerGap.cityFavorites.title", systemImage: "mappin.and.ellipse")
                }.accessibilityIdentifier("account.cityFavorites")
            }
        }
    }

    /// MP 关于: profile and editing, then 探索与更多 (优惠券, 邀请), 当前权益, and the account rows MP keeps in 设置.
    @ViewBuilder private var aboutTabSections: some View {
        MemberAboutSection(snapshot: aboutSnapshot, onEdit: { showsEditProfile = true })
        Section {
            NavigationLink { publicProfileDestination } label: {
                Label("social.profile", systemImage: "person.crop.rectangle")
            }.accessibilityIdentifier("account.publicProfile")
            ProfileFollowListAccountEntry(session: session)
            NavigationLink { ProfileEditView(coordinator:session.profileEditCoordinator,sessionRevision:session.contentDetailRevision,categoryReader:session,avatarDependencies:session.profileAvatarDependencies,currentReviewReader:session.profileCurrentReviewReader,nicknameReader:session.profileNicknameReader,savedMedia:session.profileSavedMediaReaders).localCover(owner:localCoverOwner,reader:session.socialAccountReader).cyPushedChrome()                     } label: {
                Label("profile.edit.title", systemImage: "pencil")
            }.accessibilityIdentifier("account.editProfile")
        }
        ProfileLocalCoverSection(owner: localCoverOwner, reader: session.socialAccountReader)
        AccountCollectionAccountLinks(reader:session.accountCollectionReader,onOpenTopic:{
            guard let selected = session.profileFavoritesReader.selectTopic($0, renderedScope: session.profileFavoritesReader.scope) else { return }
            _ = savedTopicOwner.open(selected, scope: session.profileFavoritesReader.scope)
        },rewards:session.nonCashRewardReader,pledge:session.makeRewardPledgeEntry(),onOpenPost:{
            guard let selected = session.profileFavoritesReader.selectPost($0, renderedScope: session.profileFavoritesReader.scope) else { return }
            _ = savedPostOwner.open(selected, scope: session.profileFavoritesReader.scope)
        }, favoriteRemoval: session.makeProfileFavoriteRemovalController(scope: session.profileFavoritesReader.scope), couponReader: session.profileOwnedCouponReader, favoritesReader: session.profileFavoritesReader, rewardMerchant: session.readOnlyPublicMerchantHomeContext, communityGate: session.squareReader)
            .environment(\.topicUnlikeController, session.makeTopicUnlikeController())
            .id(session.accountCollectionReader.scope)
        MemberBenefitsSection(reader: session.memberHomeReader, earningsDestination: { AnyView(SessionWalletCommerceView().id(session.walletCommerceScope)) })
        Section {
            if !showsPassportOverview { // Passport has the Messages circle action instead
                NavigationLink { SessionMessagingHome(session: session).cyPushedChrome() } label: {
                    HStack {
                        Label("messaging.title", systemImage: "bubble.left.and.bubble.right")
                        IMUnreadEntryBadge(reader: session.imUnreadTotalReader)
                    }
                }.accessibilityIdentifier("account.messages")
            }
            // The Clubs tab is the one Clubs entry on the player bar.
            if !showsPassportOverview {
            NavigationLink { ClubHomeView(reader:session,actionCoordinator:session.clubActionCoordinator,management:session.clubManagementContext, community:session.clubCommunityContext, topicDestination: { AnyView(SessionTopicDetailView(id: $0, session: session)) }, authorSquare: session.squareReader).id(session.sessionRevision).cyPushedChrome() } label: {
                Label("club.title", systemImage: "person.3")
            }.accessibilityIdentifier("account.clubs")
            }
            if session.account?.effectiveRole == "club" { PayoutAccountLinks(audience: .club) }
            NavigationLink { SocialInviteHistoryView(reader: session.profileInviteHistoryReader, squareReader: session.squareReader, actions: session.socialActionCoordinator).id(session.profileInviteHistoryReader.identity).cyPushedChrome()
                    .environment(\.socialConversationDestination, session.socialConversationDestination) } label: {
                Label("social.invites.title", systemImage: "person.2.badge.plus")
            }.accessibilityIdentifier("account.inviteHistory")
            NavigationLink { SessionDoorInviterView(session: session).cyPushedChrome() } label: {
                Label("door.inviter.title", systemImage: "person.badge.plus")
            }.accessibilityIdentifier("door.inviter.entry")
            if session.playerGapService != nil {
                NavigationLink { Form { Section { PlayerCodeAndJoinSection() } }.navigationTitle(Text("playerGap.playerCode.title")).navigationBarTitleDisplayMode(.inline).cyPushedChrome() } label: {
                    Label("playerGap.playerCode.title", systemImage: "qrcode")
                }.accessibilityIdentifier("account.playerCode")
            }
        }
        Section {
            PrivateHomeAccountLink(coordinator: privateHomeCoordinator)
                .environment(\.nativeHomeReturnSelection, nativeHomeReturnSelection)
        }
        // mp-mine r3: 城瘾玩法, location sharing, 投诉建议, 我的举报, teams and support live in Settings (MP pages/shezhi).
        if WelcomeView.showsMerchantChoice && PlayerLaunch.merchantCenterEnabled { // Lane G: coop row hidden in Release
        Section {
            Button { showsCooperation=true } label: {
                Label("cooperation.title", systemImage: "person.2")
            }
            .accessibilityIdentifier("account.cooperation")
        }
        }
        // Passport has one sign-out: Settings (settings.signOut). The legacy account page keeps its own.
        if !showsPassportOverview {
        Section {
            // Native spec §3.6: sign out is a neutral centred row (deleting the account is the destructive one).
            Button {
                logoutConfirmation = session.signOutConfirmation(accountID: account.id)
                confirmsLogout = logoutConfirmation != nil
            } label: {
                Text("auth.signOut").frame(maxWidth: .infinity)
            }
            .accessibilityLabel(Text("auth.signOut"))
            .accessibilityIdentifier("account.signOut")
        }
        }
    }
    private var settingsDismissHandler: () -> Void {
        let presentation = settingsGuideHandoff.presentation
        return { settingsGuideHandoff.finish(presentation)?() }
    }

    @MainActor private var ticketPendingOrderProvider: TicketWalletPendingOrderProvider {
        TicketWalletPendingOrderProvider(reader: session.ticketWalletReader, coordinator: session.orderLifecycleCoordinator,
            revision: session.sessionRevision, currentRevision: { session.sessionRevision })
    }

    @MainActor private var ticketPlayProvider: TicketWalletPlayProvider {
        TicketWalletPlayProvider(reader: session.ticketWalletReader, revision: session.sessionRevision,
            currentRevision: { session.sessionRevision }) { entry in
            AnyView(SessionPlayRuntimeView(session: session, destination: .journey(entry.scope))
                .environment(\.playThemeAuxiliaryProvider, session.playThemeAuxiliaryProvider)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink {
                            TicketWalletDetailView(id: entry.registrationID, reader: session.ticketWalletReader)
                                .environment(\.ticketWalletPlayProvider, nil)
                                .id(session.ticketWalletReader.scope)
                        } label: { Label("ticketWallet.detail", systemImage: "ticket") }
                        .accessibilityIdentifier("ticketWallet.play.ticket")
                    }
                })
        }
    }
}

/// Creator and merchant rows. Hosted in Settings for the Passport tab (W1-4 follow-up); the legacy `AccountView`
/// keeps showing the creator rows inline. Gating is unchanged: merchant rows stay hidden for the player domain and the
/// mode switch needs `merchantRootModeSwitch.isAvailable`; Settings also hides the creator rows without a publishing session.
/// MP cy-profile `TAB_LABELS` order: 我的 · 帖文 · 成就 · 关于 (same keys as the public profile tabs).
enum AccountMineTab: String, CaseIterable, Hashable {
    case mine, posts, achievements, about
    var titleKey: LocalizedStringKey {
        switch self {
        case .mine: return "account.mine.tab.projects"
        case .posts: return "social.posts"
        case .achievements: return "social.achievements"
        case .about: return "social.about"
        }
    }
}

@MainActor struct AccountRoleSections: View {
    /// Settings: hide creator rows when the publishing capability (`session.publishingSession`) is absent.
    var gatesCreatorByCapability = false
    var showsMerchant = true
    @Environment(\.merchantRootModeSwitch) private var merchantRootModeSwitch
    @Environment(\.themeDomain) private var themeDomain
    @EnvironmentObject private var session: AppSession
    @State private var showsMerchantApplication = false

    var body: some View {
        Group {
            if !gatesCreatorByCapability || session.publishingSession != nil { creatorSection }
            // Lane G: merchant rows (overview, projects, 商家工作台, onboarding, mode switch) are hidden in Release.
            if showsMerchant && PlayerLaunch.merchantCenterEnabled && themeDomain != .player { merchantSection }
        }
        .navigationDestination(isPresented: $showsMerchantApplication) {
            MerchantOnboardingView(session: session, coordinator: session.merchantOnboardingCoordinator)
                .cyPushedChrome(domain: .merchant)
        }
    }

    @ViewBuilder private var creatorSection: some View {
        Section("profile.selfProjects.title") {
            NavigationLink {
                SessionCreatorProjectsView(session: session)
                    .cyPushedChrome(domain: .topicEditor)
            } label: { Label("creatorContent.projects", systemImage: "square.stack") }
            .accessibilityIdentifier("account.creatorProjects")
            WorkshopOwnedAccountLink(browser: session.workshopOwnedBrowser)
            WorkshopPurchasedAccountLink(browser: session.workshopPurchasedBrowser, makeInstall: { session.makeWorkshopPaidInstallController(item: $0) }, makeText: { session.makeWorkshopPaidInstalledTextController(reference: $0) }, makeProfessional: { session.makeWorkshopPaidProfessionalController(reference: $0) })
                .environment(\.workshopGeneratedTemplateReaderFactory, { session.makeOwnedMemberTemplateReader() })
            WorkshopCommerceAccountLink(makeController: { session.makeWorkshopCommerceController() },
                makeInstallationPair: { reference in
                    guard let pair = session.makeModInstallationWithOriginalReader(reference: reference) else { return nil }
                    return (pair.controller, pair.originalReader)
                })
            NavigationLink { WorkshopLicenseLibraryView().cyPushedChrome(domain: .topicEditor) } label: {
                Label { Text("workshopCommerce.library.title", tableName: "WorkshopCommerce") } icon: { Image(systemName: "checkmark.seal") }
            }.accessibilityIdentifier("account.workshopLicenses")
            OwnerDraftAccountLink(browser: session.ownerDraftBrowser)
            NavigationLink { ProjectEditLaunchView().id(session.sessionRevision).cyPushedChrome(domain: .topicEditor)                     } label: {
                Label("projectEdit.title", systemImage: "square.and.pencil")
            }.accessibilityIdentifier("account.projectEditor")
            NavigationLink { TemplateAuthoringLaunchView().id(session.templateAuthoringViewIdentity).cyPushedChrome(domain: .topicEditor)                     } label: {
                Label("templateAuthor.title", systemImage: "square.and.pencil")
            }.accessibilityIdentifier("account.templateAuthoring")
            NavigationLink { CreatorContentCenterView(reader:session.creatorContentReader, publisherContext: session.publisherLifecycleContext, creatorStudio: session.creatorStudioService).id(session.creatorContentReader.scope).cyPushedChrome(domain: .topicEditor)                     } label: {
                Label("creatorContent.center", systemImage: "pencil.and.outline")
            }.accessibilityIdentifier("account.creatorCenter")
        }
    }

    @ViewBuilder private var merchantSection: some View {
        Section { // players never see merchant rows; code stays for the merchant role
            if themeDomain != .player { // players never see merchant rows; code stays for the merchant role
            NavigationLink { SessionMerchantOverviewView(session: session).cyPushedChrome(domain: .merchant) } label: {
                Label("account.merchantOverview", systemImage: "chart.bar.doc.horizontal")
            }.accessibilityIdentifier("account.merchantOverview")
            NavigationLink { SessionMerchantProjectBrowseView(session: session).cyPushedChrome(domain: .merchant) } label: {
                Label("merchant.projects", systemImage: "calendar")
            }.accessibilityIdentifier("account.merchantProjectBrowse")
            NavigationLink { MerchantHomeView(reader:session,marketingModel:session.merchantMarketingCoordinator,marketingDestination:{ AnyView(SessionMerchantMarketingDestination(session:session,destination:$0)) },openApplication:{ showsMerchantApplication=true },operationsReader:session.merchantOperationsReader,operationsDestinationFactory:{ session.merchantOperationsDestination($0, access: $1) },businessReader:session.merchantBusinessReader,businessJournal:session.merchantBusinessJournal,contentService:session.merchantContentService,cooperationFlowReader:session.cooperationFlowReader,engagementReader:session.merchantEngagementReader,exportRecovery:session.merchantExportRecovery,predictionReader:session.merchantPredictionReader).environment(\.merchantPredictionWorkbenchEntry,{ AnyView(SessionMerchantPredictionEntry(session: session)) }).environment(\.merchantAnchorDestination, { access in AnyView(SessionMerchantAnchorView(access: access)) }).cyPushedChrome(domain: .merchant)                     } label: {
                Label("merchant.title", systemImage: "storefront")
            }.accessibilityIdentifier("account.merchant")
            PayoutAccountLinks(audience: .merchant)
            if merchantRootModeSwitch.isAvailable {
                MerchantAccountModeSwitchRow(modeSwitch: merchantRootModeSwitch)
            }
            Button { showsMerchantApplication=true } label: {
                Label("merchant.onboarding.openApplication", systemImage: "doc.text")
            }
            .accessibilityIdentifier("account.merchantApplication")
            }
        }
    }
}
