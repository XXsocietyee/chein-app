import SwiftUI

/// Opens a page-map path on the screen that already exists. A path with no composable screen keeps the
/// parity kit's unavailable state. Nothing here grants a read, a write, or a payment.
@MainActor struct MPReviewedPageScreen: View {
    let page: String
    let query: [String: String]
    @EnvironmentObject private var session: AppSession

    var body: some View {
        screen
            .accessibilityIdentifier("mp.deepLink.screen")
    }

    @ViewBuilder private var screen: some View {
        switch page {
        case "pages/index/index":
            SessionHomeFeedView().environmentObject(session)
        case "pages/template/index", "pages/templatedetail/topic-preview/index", "pages/templatedetail/topic-detail/index", "pages/templatedetail2/templatedetail2":
            DiscoveryTemplateBrowserView(reader: session)
        case "pages/talent/list/index":
            ClubHomeView(reader: session, onSignIn: {}, actionCoordinator: session.clubActionCoordinator,
                         management: session.clubManagementContext, community: session.clubCommunityContext,
                         publicRoster: session.clubPublicRosterReader,
                         topicDestination: { AnyView(SessionTopicDetailView(id: $0, session: session)) },
                         requestedClubID: .constant(nil), authorSquare: session.squareReader,
                         initialTopTab: query["tab"] == "feed" ? .feed : nil)
        case "pages/member/index/index":
            if let account = session.account {
                AccountView(account: account).environmentObject(session)
            } else {
                unavailable
            }
        case "pages/roam/index":
            roam
        case "pages/privacy/index":
            PrivacyProtectionView(market: session.operationalMarket, legalReader: session.legalReader)
        case "pages/agreement/index":
            SettingsLegalDocumentView(type: SettingsLegalType.resolve(query["type"] ?? ""), market: session.operationalMarket, reader: session.legalReader)
        case "pages/deregister/index":
            if let coordinator = session.accountComplianceCoordinator {
                AccountComplianceSheet(coordinator: coordinator, destination: .cancellation, market: session.operationalMarket, legalReader: session.legalReader)
            } else { unavailable }
        case "pages/team/detail/index":
            // MP `team/detail?teamId=` (C-D1) opens that team; the bare path keeps the team list.
            if let teamID = positiveID(query["teamId"]) {
                SessionTeamDetailView(lookup: .id(teamID)).environmentObject(session)
            } else {
                SessionTeamHomeView().environmentObject(session)
            }
        case "pages/team/join/index":
            // MP `team/join?entry=code` (C-J1): type the 加入码, then the invitation page.
            TeamInvitationEntryView(makeCoordinator: { session.makeTeamCoordinator() })
        case "pages/play/circle/index":
            PlayCircleRetiredLinkView(goHome: { session.dismissNativeEntry() })
        case "pages/activity/detail/index":
            if let id = reviewedID(query) {
                ActivityDetailView(id: id, reader: session, playReaderForActivity: { session.playReader(for: .activity($0)) }, registrationEnabled: true)
            } else { unavailable }
        case "pages/activity/baoming/baoming":
            unavailable
        case "pages/activity/list/index":
            OfficialEventsBrowserView(reader: session.officialEventReader, actions: session.officialActionCoordinator, onClose: {}, onLogin: {})
        case "pages/activity/official-detail/index":
            if let id = reviewedID(query) {
                OfficialEventDetailView(id: id, reader: session.officialEventReader, actions: session.officialActionCoordinator)
            } else { unavailable }
        case "pages/activity/official-inbox/index":
            OfficialInboxView(reader: session.officialEventReader, actions: session.officialActionCoordinator)
        case "pages/activity/official-mine/index":
            OfficialPublishedView(reader: session.officialEventReader, actions: session.officialActionCoordinator)
        case "subpackageA/pages/infomation/infomation":
            SocialPlayGuideView(reader: session.socialAccountReader, templateReader: session)
        case "subpackageA/pages/infomationdetail/infomationdetail":
            if let id = reviewedID(query) {
                SocialInformationView(id: id, reader: session.socialAccountReader)
            } else { unavailable }
        case "subpackageA/pages/assetcenter/income-detail/income-detail":
            WalletIncomeView(reader: session.walletHistoryReader, onCooperationFinance: {})
        case "subpackageA/pages/assetcenter/earnings/index":
            SessionWalletCommerceView().environmentObject(session)
        case "subpackageA/pages/assetcenter/analysis/index":
            WalletAssetsView(reader: session.walletHistoryReader)
        case "subpackageP3/pages/growthcenter/index/index":
            GrowthCenterView(reader: session.growthCenterReader)
        case "subpackageP3/pages/growthcenter/leaderboard/index":
            GrowthLeaderboardView(reader: session.growthCenterReader)
        case "subpackageP3/pages/stamp-camera/index/index", "subpackageRoam/citystamp/index":
            SessionRoamStampCameraView().environmentObject(session)
        case "subpackageP3/pages/stamp-album/index/index":
            RoamStampAlbumView(reader: session.roamExperienceReader)
        case "subpackageP3/pages/badge-wall/index/index":
            ObjectBadgeWallView(reader: session.profileReader, media: session.makeObjectCardImageLoader())
        case "subpackageP3/pages/object-cards/index/index":
            SessionObjectCardsView().environmentObject(session)
        case "subpackageB/pages/im/list/index":
            SessionMessagingHome(session: session)
        case "pages/publish/fabu/index", "pages/publish/topicadd/topicadd":
            topicEditor
        case "pages/publish/simple/index":
            SessionPublishingModesView().environmentObject(session)
        case "pages/publish/activity/index":
            // C-A1: the 发布活动 form itself (not the publish menu); `?id=` edits that activity.
            SessionActivityPublishingDestination(editingID: positiveID(query["id"])).environmentObject(session)
        case "pages/publish/template-intro/index":
            // C-I1: the intro → name → editor flow the 发布 tab opens.
            sessionTemplateAuthoringEntry(session)
        case "pages/publish/temp/index":
            // C-T1: `?id=` opens that template's own editor; the bare path opens the editor, not the intro.
            if let id = positiveID(query["id"]).flatMap(MemberPlayTemplateID.init(rawValue:)) {
                SessionOwnedTemplateConfigurationView(id: id).environmentObject(session)
            } else {
                TemplateAuthoringView(coordinator: session.templateAuthoringEditor(), sessionRevision: session.sessionRevision, metadataReader: session,
                                     makeCoverService: { session.makeActivityCoverService() }, coverSession: { session.publishingSession },
                                     startsInEditor: true)
            }
        case "subpackageMember/mytemplate/mytemplate":
            TemplateAuthoringMineView(coordinator: session.templateShelfCoordinator(), sessionRevision: session.sessionRevision,
                                      memberDetail: { AnyView(SessionOwnedMemberTemplateDetailView(id: $0).environmentObject(session)) },
                                      ownerConfiguration: { AnyView(SessionOwnedTemplateConfigurationView(id: $0).environmentObject(session)) },
                                      creatorConsent: { AnyView(SessionWorkshopCreatorConsentView(selection: $0).environmentObject(session)) })
        case "pages/club/detail/index", "pages/club/workbench/index":
            if let id = reviewedID(query) {
                ClubDetailView(id: id, reader: session, onSignIn: {}, actionCoordinator: session.clubActionCoordinator,
                               management: session.clubManagementContext, community: session.clubCommunityContext,
                               publicRoster: session.clubPublicRosterReader)
            } else { unavailable }
        case "pages/topic/index/index":
            if let id = reviewedID(query) { SessionTopicDetailView(id: id, session: session) } else { unavailable }
        case "pages/templatedetail/templatedetail":
            if let id = reviewedID(query) { DiscoveryTemplateDetailView(id: id, reader: session) } else { unavailable }
        case "pages/square/detail/index":
            if let id = reviewedID(query) {
                SquareDetailView(id: id, reader: session.squareReader, accountReader: session.socialAccountReader, actions: session.socialActionCoordinator)
            } else { unavailable }
        case "subpackageMember/orderinfo/orderinfo":
            if let id = reviewedID(query) { ProfileOrderDetailView(id: id, reader: session.ownedOrderReader) } else { unavailable }
        case "pages/merchant/index/index":
            SessionMerchantOverviewView(session: session)
        case "pages/merchant/relation/index", "pages/merchant/relation":
            SessionCoopRelationDiscoveryView(session: session, reader: session.cooperationFlowReader)
        case "pages/search2/index", "pages/search2/result/index", "pages/searchmap/index", "pages/talent/search/index":
            SessionGlobalSearchView().environmentObject(session)
        case "pages/square/list/index":
            SessionSquareBrowserView(session: session, onClose: { session.dismissNativeEntry() }, onSignIn: {})
        case "pages/shezhi/shezhi":
            // B-SZ-12: `?scene=settings-deregister` opens 账号注销; the other scenes open Settings itself.
            if query["scene"] == "settings-deregister", let coordinator = session.accountComplianceCoordinator {
                AccountComplianceSheet(coordinator: coordinator, destination: .cancellation, market: session.operationalMarket, legalReader: session.legalReader)
            } else {
                SettingsView().environmentObject(session)
            }
        case "pages/shezhi/marketing/index":
            // B-MK-04: 营销消息与优惠券 is a pushed page, so no close button.
            if let coordinator = session.accountComplianceCoordinator {
                AccountComplianceSheet(coordinator: coordinator, destination: .marketing, market: session.operationalMarket,
                                       legalReader: session.legalReader, showsCloseButton: false)
            } else { unavailable }
        case "pages/gerenziliao/gerenziliao":
            // A3-08: `?field=introduction|category` opens that editor after the first load.
            ProfileEditView(coordinator: session.profileEditCoordinator, sessionRevision: session.contentDetailRevision, categoryReader: session,
                            currentReviewReader: session.profileCurrentReviewReader, nicknameReader: session.profileNicknameReader,
                            savedMedia: session.profileSavedMediaReaders, initialField: query["field"])
        case "pages/mylike/mylike":
            // A6 / X1: 我的收藏 from a link, with the same readers the 我的 page passes.
            AccountCollectionFavoritesView(reader: session.profileFavoritesReader, onOpenTopic: { _ in },
                                           favoriteRemoval: session.makeProfileFavoriteRemovalController(scope: session.profileFavoritesReader.scope),
                                           communityGate: session.squareReader)
                .environment(\.topicUnlikeController, session.makeTopicUnlikeController())
                .id(session.profileFavoritesReader.scope)
        case "pages/addressinfo/addressinfo":
            // X1: the participant form; `?id=` edits that participant.
            NavigationStack {
                if let id = reviewedID(query) {
                    ParticipantFormView(id: id, reader: session.participantReader, coordinator: session.participantCoordinator)
                } else {
                    ParticipantFormView(reader: session.participantReader, coordinator: session.participantCoordinator)
                }
            }
        case "pages/shezhi/about/index":
            SettingsAboutView(market: session.operationalMarket, appInformation: .current(), legalReader: session.legalReader)
        case "pages/address/address":
            // A5-02: the link gets the same coordinator as 我的 › 参与人信息, so add / edit / delete stay available.
            ProfileParticipantsView(reader: session.participantReader, coordinator: session.participantCoordinator)
        case "subpackageMember/order/order":
            SessionOwnedOrdersView(session: session)
        case "subpackageMember/signup/index", "subpackageMember/signupInfo/signupInfo", "subpackageMember/signupInfo2/signupInfo2":
            TicketWalletView(reader: session.ticketWalletReader, orderLifecycleCoordinator: session.orderLifecycleCoordinator)
        case "subpackageMember/mycanyu/mycanyu":
            SessionPlayerJourneyView(destination: .participations).environmentObject(session)
        case "subpackageMember/myinvite/myinvite":
            SocialInviteHistoryView(reader: session.profileInviteHistoryReader, squareReader: session.squareReader, actions: session.socialActionCoordinator)
        case "subpackageMember/report-mine/index":
            SquareReportProgressView(session: session)
        case "subpackageMember/appeal-mine/index":
            MemberScoreAppealListView(session: session)
        case "subpackageMember/coupon/coupon", "subpackageMember/couponInfo/couponInfo":
            SessionCouponManagementView().environmentObject(session)
        case "subpackageMember/tixian/tixian":
            WithdrawalSupportLandingView(reader: session.walletHistoryReader)
        case "subpackageMember/tixianjilu/tixianjilu", "pages/coop/withdraw/records/index":
            WithdrawalHistoryView(reader: session.walletHistoryReader)
        case "pages/coop/withdraw/index":
            CoopWithdrawNoticeView(isSignedIn: session.account != nil)
        case "pages/userinfo/userinfo":
            // A2-01: MP share links use `userId`; `id` is the older key. `tab` picks the first tab (A2-06).
            if let id = positiveID(query["userId"]) ?? reviewedID(query) {
                SocialPublicProfileView(memberID: id, reader: session.socialAccountReader, squareReader: session.squareReader,
                                        actions: session.socialActionCoordinator, initialTab: query["tab"])
            } else { unavailable }
        case "subpackageRoam/history/index":
            RoamHistoryView(reader: session.roamExperienceReader, toolsReader: session.roamPassportToolsReader, privateToolsReader: session.roamPrivateToolsReader)
        case "subpackageRoam/nearby/index":
            SessionRoamNearbyTeamsView().environmentObject(session)
        case "subpackageRoam/my-teams/index":
            SessionRoamNearbyTeamsView(initialTab: 1).environmentObject(session)
        case "subpackageRoam/official-routes/index":
            if let reader = session.officialRouteReader { OfficialRouteListView(reader: reader) } else { unavailable }
        case "subpackageTools/capsule/index":
            RoamCapsuleView(tools: session.roamPrivateToolsReader)
        case "subpackageTools/exploration-goals/index":
            RoamExplorationGoalsView(tools: session.roamPrivateToolsReader)
        case "subpackageTools/exploration-export/index":
            RoamExplorationExportView(tools: session.roamPrivateToolsReader)
        case "subpackageTools/anniversary/index":
            RoamAnniversaryView(reader: session.roamPassportToolsReader)
        case "subpackageTools/monthly-recap/index":
            RoamMonthlyRecapView(reader: session.roamPassportToolsReader)
        default:
            unavailable
        }
    }

    /// MP `fabu?id=&mode=&scope=&clubId=` (C-F11): `id` loads that topic's edit-detail; otherwise a new topic in the
    /// chosen mode. `scope=MERCHANT` only applies to a merchant account; the server still checks every write.
    @ViewBuilder private var topicEditor: some View {
        let owner: ProjectEditOwner = query["scope"] == "MERCHANT" && session.account?.effectiveRole == "merchant" ? .merchant : .personal
        if let topicID = positiveID(query["id"]) {
            if let target = ProjectEditRemoteTarget(topicID: topicID, owner: owner, readerScope: session.creatorContentReader.scope),
               let coordinator = session.projectEditor(target: target) {
                ProjectEditView(coordinator: coordinator, sessionRevision: session.sessionRevision,
                                publisherClient: session.publisherLifecycleContext?.client,
                                publisherHost: { AnyView(SessionPublisherLifecycleView(session: session, resource: $0)) })
                    .id(target.id + ":" + session.projectEditorContextID)
            } else {
                CYEmptyState(systemImage: "exclamationmark.arrow.triangle.2.circlepath", "projectRemote.stale", messageIdentifier: "projectRemote.stale")
            }
        } else {
            let product: ProjectEditProduct = query["mode"] == "2" ? .freeExplore : .city
            ProjectEditView(coordinator: session.projectEditor(product: product, owner: owner), sessionRevision: session.sessionRevision,
                            seed: topicSeed(product: product, owner: owner),
                            publisherClient: session.publisherLifecycleContext?.client,
                            publisherHost: { AnyView(SessionPublisherLifecycleView(session: session, resource: $0)) },
                            cloudDraftProjectsHost: { AnyView(SessionCreatorProjectsView(session: session)) })
                .id(session.projectEditorContextID)
        }
    }

    /// `clubId` preselects the club the MP locks for a club topic; nil keeps the plain new draft.
    private func topicSeed(product: ProjectEditProduct, owner: ProjectEditOwner) -> ProjectEditDraft? {
        guard let clubID = positiveID(query["clubId"]) else { return nil }
        var draft = ProjectEditDraft(product: product); draft.owner = owner; draft.clubID = clubID
        return draft
    }

    private var roam: some View {
        RoamBrowserView(reader: session.roamReader, nearbyEventsReader: session.roamNearbyEventsReader, nearbyPlayersReader: session.roamNearbyPlayersReader,
                        onChooseArea: {}, onOpenAccount: {}, experienceReader: session.roamExperienceReader, albumMetadataReader: session.roamAlbumMetadataReader,
                        tileMemoryReader: session.roamTileMemoryReader, sessionFactReader: session.roamSessionFactReader,
                        cityDestination: { AnyView(SessionCityPlayerView().environmentObject(session)) },
                        territoryDestination: { AnyView(SessionRoamTerritoryView().environmentObject(session)) },
                        nearbyTeamsDestination: { AnyView(SessionRoamNearbyTeamsView().environmentObject(session)) },
                        stampDestination: { AnyView(SessionRoamStampCameraView().environmentObject(session)) },
                        liveDestination: { AnyView(RoamLiveSessionView(controller: session.makeRoamLiveSessionController(), localHistoryReader: session.roamExperienceReader, albumMetadataReader: session.roamAlbumMetadataReader).environment(\.inGameChannelHost, session.inGameChannelHost)) },
                        posterDestination: { AnyView(SessionRoamPosterView(node: $0).environmentObject(session)) },
                        eventDestination: { target in
                            switch target {
                            case .activity(let id):
                                return AnyView(ActivityDetailView(id: id, reader: session, playReaderForActivity: { session.playReader(for: .activity($0)) }, registrationEnabled: true))
                            case .topic(let id):
                                return AnyView(SessionTopicDetailView(id: id, session: session))
                            }
                        },
                        nearbyEventDestination: { AnyView(RoamNearbyEventsDetailHost(target: $0, session: session)) },
                        playerProfileDestination: { memberID in
                            AnyView(SocialPublicProfileView(memberID: memberID, reader: session.socialAccountReader, squareReader: session.squareReader, actions: nil))
                        },
                        couponWalletDestination: session.makeRoamCouponWalletDestination(reader: session.roamReader),
                        officialRouteReader: session.officialRouteReader, mediaScope: session.platformConsumers.scope,
                        makeExternalMaps: session.platformConsumers.mapsFactory, entryReader: session.roamEntryNearbyReader,
                        entryTeams: { await session.roamEntryTeams(area: $0) },
                        myTeamsDestination: { AnyView(SessionRoamNearbyTeamsView(initialTab: 1).environmentObject(session)) },
                        nearbyTeamDestination: { AnyView(SessionRoamNearbyTeamsView(focusTeamID: $0).environmentObject(session)) },
                        toolsReader: session.roamPassportToolsReader, passportToolsReader: session.roamPassportToolsReader,
                        privateToolsReader: session.roamPrivateToolsReader,
                        anniversaryRouteDestination: { topicID in
                            guard let id = Int(topicID), id > 0, String(id) == topicID else { return AnyView(TopicIssueView(issue: .unavailable)) }
                            return AnyView(SessionTopicDetailView(id: id, session: session))
                        },
                        locationSettings: RoamSystemLocationSettingsProvider())
            .environment(\.roamPOIActions, session.makeRoamPOIActions())
            .environment(\.roamReceivedStampReader, session.roamReceivedStampReader)
            .environment(\.roamPassportHistoryReader, session.roamPassportHistoryReader)
            .environment(\.roamPlaceExtrasProvider, { poiID in poiID > 0 ? RoamPlaceExtrasProduction(poiID: poiID, session: session) : nil })
            .environment(\.inGameChannelHost, session.inGameChannelHost)
    }

    private var unavailable: some View {
        CYEmptyState(systemImage: "tray", "mp.route.unavailable", messageIdentifier: "mp.route.unavailable")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CYNight.ink0.ignoresSafeArea())
    }
}

/// Canonical positive decimal id, the same shape `MiniProgramPageLink` already required.
private func reviewedID(_ query: [String: String]) -> Int? { positiveID(query["id"]) }

private func positiveID(_ text: String?) -> Int? {
    guard let text, text.utf8.count <= 18, text.utf8.allSatisfy({ (48...57).contains($0) }),
          let value = Int(text), value > 0, String(value) == text else { return nil }
    return value
}
