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
                         requestedClubID: .constant(nil), authorSquare: session.squareReader)
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
            SettingsLegalDocumentView(type: .userAgreement, market: session.operationalMarket, reader: session.legalReader)
        case "pages/deregister/index":
            if let coordinator = session.accountComplianceCoordinator {
                AccountComplianceSheet(coordinator: coordinator, destination: .cancellation, market: session.operationalMarket, legalReader: session.legalReader)
            } else { unavailable }
        case "pages/team/detail/index":
            SessionTeamHomeView().environmentObject(session)
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
            ProjectEditView(coordinator: session.projectEditor(product: .city), sessionRevision: session.sessionRevision,
                            publisherClient: session.publisherLifecycleContext?.client,
                            publisherHost: { AnyView(SessionPublisherLifecycleView(session: session, resource: $0)) },
                            cloudDraftProjectsHost: { AnyView(SessionCreatorProjectsView(session: session)) })
                .id(session.projectEditorContextID)
        case "pages/publish/simple/index", "pages/publish/activity/index":
            SessionPublishingModesView().environmentObject(session)
        case "pages/publish/temp/index":
            TemplateAuthoringView(coordinator: session.templateAuthoringEditor(), sessionRevision: session.sessionRevision, metadataReader: session)
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
            SettingsView().environmentObject(session)
        case "pages/shezhi/about/index":
            SettingsAboutView(market: session.operationalMarket, appInformation: .current(), legalReader: session.legalReader)
        case "pages/address/address":
            ProfileParticipantsView(reader: session.profileReader)
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
            if let id = reviewedID(query) {
                SocialPublicProfileView(memberID: id, reader: session.socialAccountReader, squareReader: session.squareReader, actions: session.socialActionCoordinator)
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

    private var roam: some View {
        RoamBrowserView(reader: session.roamReader, nearbyEventsReader: session.roamNearbyEventsReader, nearbyPlayersReader: session.roamNearbyPlayersReader,
                        onChooseArea: {}, onOpenAccount: {}, experienceReader: session.roamExperienceReader, albumMetadataReader: session.roamAlbumMetadataReader,
                        tileMemoryReader: session.roamTileMemoryReader, sessionFactReader: session.roamSessionFactReader,
                        cityDestination: { AnyView(SessionCityPlayerView().environmentObject(session)) },
                        territoryDestination: { AnyView(SessionRoamTerritoryView().environmentObject(session)) },
                        nearbyTeamsDestination: { AnyView(SessionRoamNearbyTeamsView().environmentObject(session)) },
                        stampDestination: { AnyView(SessionRoamStampCameraView().environmentObject(session)) },
                        liveDestination: { AnyView(RoamLiveSessionView(controller: session.makeRoamLiveSessionController(), localHistoryReader: session.roamExperienceReader, albumMetadataReader: session.roamAlbumMetadataReader)) },
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
    }

    private var unavailable: some View {
        CYEmptyState(systemImage: "tray", "mp.route.unavailable", messageIdentifier: "mp.route.unavailable")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CYNight.ink0.ignoresSafeArea())
    }
}

/// Canonical positive decimal id, the same shape `MiniProgramPageLink` already required.
private func reviewedID(_ query: [String: String]) -> Int? {
    guard let text = query["id"], text.utf8.count <= 18, text.utf8.allSatisfy({ (48...57).contains($0) }),
          let value = Int(text), value > 0, String(value) == text else { return nil }
    return value
}
