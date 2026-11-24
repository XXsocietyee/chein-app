import SwiftUI

/// Opens a page-map path on the screen that already exists. A path with no composable screen keeps the
/// parity kit's unavailable state. Nothing here grants a read, a write, or a payment.
@MainActor struct MPReviewedPageScreen: View {
    let page: String
    let query: [String: String]
    @EnvironmentObject private var session: AppSession
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    /// RNEAR-5 / RTEAMS-4: the signed-out team pages offer 登录, which opens 我的 (the app's sign-in home).
    private var openSignIn: (() -> Void)? {
        guard rootTabSwitch.isAvailable else { return nil }
        return { session.dismissNativeEntry(); rootTabSwitch(.mine) }
    }

    var body: some View {
        screen
            .accessibilityIdentifier("mp.deepLink.screen")
    }

    @ViewBuilder private var screen: some View {
        switch page {
        case "pages/index/index":
            // PC-A-1-8: 首页 is a tab root (MP switchTab). Close the link and select the tab instead of pushing a second
            // home with its own NavigationStack; a host without the tab switch keeps the old screen.
            if rootTabSwitch.isAvailable {
                MPTabHandoff { session.dismissNativeEntry(); rootTabSwitch(.home) }
            } else {
                SessionHomeFeedView().environmentObject(session)
            }
        case "pages/template/index", "pages/templatedetail2/templatedetail2":
            // PC-A-2-6: the same 应用 / 发布 capabilities as the 发布 tab entry.
            DiscoveryTemplateBrowserView(
                reader: session,
                authoringFactory: { session.templateAuthoringEditor(adopting: $0) },
                authoringRevision: session.sessionRevision,
                authoringCompletion: session.templateAuthoringCompletionContext,
                publishDestination: {
                    AnyView(SessionPublishingModesView().environmentObject(session).id(session.publishingSession?.epoch))
                }
            )
            .id(session.templateAuthoringViewIdentity)
        case "pages/templatedetail/topic-preview/index", "pages/templatedetail/topic-detail/index":
            // PC-A-7-1 / PC-A-8-1: a shared topic-template link lands on that template, not the shelf root.
            if let id = reviewedID(query) {
                DiscoveryTopicTemplatePreview(coordinator: session.publicTopicTemplateCoordinator(id: id))
                    .cyPushedChrome()
            } else { unavailable }
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
            // PLAYC-1: old circle links with a topicId forward to play (MP redirectTo pages/play/index).
            switch PlayRuntimeAuxiliaryBinding.resolveCircleRetirement(query: query) {
            case .missingParameter:
                PlayCircleRetiredLinkView(goHome: { session.dismissNativeEntry() })
            case .redirectToPlay(let scope, _, _, _):
                SessionPlayRuntimeView(session: session, destination: .journey(scope))
            }
        case "pages/play/index":
            // PLAY-10: shared / redirected play links (topicId or activityId).
            if let id = positiveID(query["activityId"]) {
                SessionPlayRuntimeView(session: session, destination: .journey(.activity(id)))
            } else if let id = positiveID(query["topicId"]) {
                SessionPlayRuntimeView(session: session, destination: .journey(.topic(id)))
            } else { unavailable }
        case "pages/activity/detail/index":
            if let id = reviewedID(query) {
                ActivityDetailView(id: id, reader: session, playReaderForActivity: { session.playReader(for: .activity($0)) }, registrationEnabled: true)
            } else { unavailable }
        case "pages/activity/baoming/baoming":
            // PC-C-2 routing: MP baoming is the registration step of one activity; land on its detail with the sheet open.
            if let id = reviewedID(query, key: "activityId") {
                ActivityDetailView(id: id, reader: session, playReaderForActivity: { session.playReader(for: .activity($0)) }, registrationEnabled: true, opensRegistrationOnLoad: true)
            } else { unavailable }
        case "pages/activity/official-organizer/index":
            if let id = reviewedID(query), let access = session.officialActionCoordinator?.organizer {
                OfficialOrganizerConsoleView(eventID: id, access: access)
            } else { unavailable }
        case "pages/activity/list/index":
            OfficialEventsBrowserView(reader: session.officialEventReader, actions: session.officialActionCoordinator,
                                      onClose: { session.dismissNativeEntry() }, onLogin: signIn)
        case "pages/activity/official-detail/index":
            if let id = reviewedID(query) {
                // PC-C-4-5: guests get a working 登录; THEME missions open their topic (same wiring as 首页).
                OfficialEventDetailView(id: id, reader: session.officialEventReader, actions: session.officialActionCoordinator, onLogin: signIn,
                                        topicLinks: OfficialTopicLinks(reader: session.topicReader, destination: { AnyView(SessionTopicDetailView(id: $0, session: session)) }))
            } else { unavailable }
        case "pages/activity/official-inbox/index":
            OfficialInboxView(reader: session.officialEventReader, actions: session.officialActionCoordinator)
        case "pages/activity/official-mine/index":
            OfficialPublishedView(reader: session.officialEventReader, actions: session.officialActionCoordinator)
        case "subpackageA/pages/infomation/infomation":
            // PC-D-2-1: the mode cards keep their 去看看 (MP switchTab to 首页 / 漫游).
            SocialPlayGuideView(reader: session.socialAccountReader,
                                onOpenDestination: rootTabSwitch.isAvailable ? { destination in
                                    session.dismissNativeEntry()
                                    rootTabSwitch(destination == .roam ? .roam : .home)
                                } : nil,
                                templateReader: session)
        case "subpackageA/pages/infomationdetail/infomationdetail":
            if let id = reviewedID(query) {
                SocialInformationView(id: id, reader: session.socialAccountReader)
            } else { unavailable }
        case "subpackageA/pages/assetcenter/income-detail/income-detail":
            // PC-D-4-1: no coop-finance grant on this host, so no 主办分润 button (same as SessionWalletCommerceView).
            WalletIncomeView(reader: session.walletHistoryReader, onCooperationFinance: {}, showsCooperationFinance: false)
        case "subpackageA/pages/assetcenter/earnings/index":
            SessionWalletCommerceView().environmentObject(session)
        case "subpackageA/pages/assetcenter/analysis/index":
            // PC-D-6-1: 分析 is the income analysis page, not 我的资产.
            WalletIncomeAnalysisView(reader: session.walletHistoryReader, onSignIn: signIn)
        case "subpackageP3/pages/growthcenter/index/index":
            GrowthCenterView(reader: session.growthCenterReader)
        case "subpackageP3/pages/growthcenter/leaderboard/index":
            GrowthLeaderboardView(reader: session.growthCenterReader)
        case "subpackageP3/pages/stamp-camera/index/index":
            SessionRoamStampCameraView().environmentObject(session)
        case "subpackageRoam/citystamp/index":
            // RSTAMP-1: the 3-step 投一张换一张 flow keeps kind / place.
            SessionRoamCityStampFlowView(kind: query["kind"], place: query["place"]).environmentObject(session)
        case "subpackageRoam/session/index":
            // RSESS-1: a friend's ?shareToken= link lands on the shared footprint; the owner's own id opens the record.
            if let token = query["shareToken"], !token.isEmpty {
                RoamSharedFootprintView(token: token, reader: session.makeRoamShareSnapshotReader(), onOpenRoam: { session.dismissNativeEntry() })
            } else if let sessionID = query["sessionId"] ?? query["id"], !sessionID.isEmpty {
                RoamPassportRecordView(reader: session.roamPassportHistoryReader, sessionID: sessionID, localReader: session.roamExperienceReader)
            } else { unavailable }
        case "subpackageRoam/official-route/index":
            // RROUTE-1: MP official-route takes a decimal id only.
            if let reader = session.officialRouteReader, let id = positiveID(query["id"]) { OfficialRouteDetailView(reader: reader, routeID: String(id)) } else { unavailable }
        case "pages/play/poi-challenge/index":
            // PLAYPOI-2: the challenge reads its node by poiId.
            if let id = positiveID(query["poiId"]) { ChallengePOIHostView(poiID: id, reader: session.roamReader) } else { unavailable }
        case "subpackageRoam/citynode-code/index":
            RoamCityVoucherCodeView(poiID: positiveID(query["poiId"]), name: query["name"])
        case "subpackageP3/pages/stamp-album/index/index":
            RoamStampAlbumView(reader: session.roamExperienceReader)
        case "subpackageP3/pages/badge-wall/index/index":
            ObjectBadgeWallView(reader: session.profileReader, media: session.makeObjectCardImageLoader())
        case "subpackageP3/pages/object-cards/index/index":
            SessionObjectCardsView().environmentObject(session)
        case "subpackageB/pages/im/list/index":
            SessionMessagingHome(session: session)
        case "subpackageB/pages/im/chat/index":
            if let id = reviewedID(query, key: "conversationId") {
                MessagingHistoryView(conversationID: id, reader: session.messagingReader, sender: session.messageSender(for: id),
                                     mediaReader: session.socialMessageMediaReader, expanded: session.imExpandedNavigation)
                    .id(session.messagingViewIdentity)
            } else { SessionMessagingHome(session: session) }
        case "pages/topic/merchantinfo/merchantinfo":
            // PC-B-2-1, MP merchantinfo.js:339-353: topicId (± registration id) = the project/承接 view, the backend decides the role;
            // a bare id = browsing that topic's chapters from the brand square.
            if let topicID = reviewedID(query, key: "topicId") {
                MerchantContentDocumentView(service: session.merchantContentService, query: .project(topicID: topicID), focusedTopicID: topicID)
                    .cyPushedChrome()
            } else if let id = reviewedID(query) {
                MerchantContentDocumentView(service: session.merchantContentService, query: .chapters(topicID: id))
                    .cyPushedChrome()
            } else { unavailable }
        case "pages/topic/merchantapply/index":
            // The application form lives on the topic's chapters screen (MerchantContentEditor is presented from there).
            if let topicID = reviewedID(query, key: "topicId") {
                MerchantContentDocumentView(service: session.merchantContentService, query: .chapters(topicID: topicID))
                    .cyPushedChrome()
            } else { unavailable }
        case "pages/topic/pricing/index", "pages/topic/pricing/partner/index":
            // PC-B-4-3: MP pricing reads `topicId || id`; the partner page is reached from the pricing lineup.
            if let topicID = reviewedID(query, key: "topicId") ?? reviewedID(query), let context = session.publisherLifecycleContext {
                PublisherPricingView(topicID: topicID, client: context.client, coordinator: context.coordinator)
            } else { unavailable }
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
        case "pages/club/detail/index":
            // MP detail onLoad: `tab` = manage | overview; `owner` without an id resolves my own club.
            if let id = reviewedID(query) {
                clubDetail(id, tab: ClubDetailTab(rawValue: query["tab"] ?? "").flatMap { [.manage, .overview].contains($0) ? $0 : nil })
            } else if query["owner"] != nil { ownedClubs } else { unavailable }
        case "pages/club/workbench/index":
            // CLB-workbench-01/02: the workbench is the club page's 管理 tab; no id → my own club.
            if let id = clubQueryID(query) { clubDetail(id, tab: .manage) } else { ownedClubs }
        case "pages/club/apply/index":
            clubGovernance { g in ClubGovernanceReadView(operation: .hostStatus, scope: .init(), identity: session.clubIdentity, access: g.access, coordinator: g.coordinator) }
        case "pages/club/create/index":
            clubOperations(.create)
        case "pages/club/edit/index":
            if let id = clubQueryID(query) { clubOperations(.club(id)) } else { unavailable }
        case "pages/club/badges/index":
            if let id = clubQueryID(query), let host = badgeHost(id) { ClubBadgeManagementView(host: host).id(host.id) } else { unavailable }
        case "pages/club/customers/index":
            clubRead(.customers, .init(clubID: clubQueryID(query)), needsClub: true)
        case "pages/club/customer-detail/index":
            clubRead(.customer, .init(clubID: clubQueryID(query), memberID: queryID(query, "memberId")), needsClub: true)
        case "pages/club/checkin-detail/index":
            clubRead(.checkin, .init(clubID: clubQueryID(query), registrationID: queryID(query, "registrationId")), needsClub: true)
        case "pages/club/enroll/index":
            if let id = clubQueryID(query) {
                clubGovernance { g in ClubEnrollmentView(clubID: id, focusTopicID: queryID(query, "topicId"), identity: session.clubIdentity, access: g.access, coordinator: g.coordinator) }
            } else { unavailable }
        case "pages/club/event-ops/index":
            if let id = clubQueryID(query) {
                clubGovernance { g in ClubOpsEventView(scope: .init(clubID: id, topicID: queryID(query, "topicId"), activityID: queryID(query, "activityId")), identity: session.clubIdentity, access: g.access, coordinator: g.coordinator) }
            } else { unavailable }
        case "pages/club/group-code/index":
            if let activity = queryID(query, "activityId") {
                clubGovernance { g in ClubGovernanceCommandForm(route: .init(operation: .issueGroupCode, scope: .init(topicID: queryID(query, "topicId"), activityID: activity)), identity: session.clubIdentity, access: g.access, coordinator: g.coordinator) }
            } else { unavailable }
        case "pages/club/join-requests/index":
            if let id = clubQueryID(query) {
                let management = session.clubManagementContext
                ClubManagementView(clubID: id, identity: session.clubIdentity, access: management.access, coordinator: management.coordinator, viewerRevision: management.viewerRevision)
            } else { unavailable }
        case "pages/club/notify/index":
            clubRead(.audienceCounts, .init(clubID: clubQueryID(query), activityID: queryID(query, "activityId")), needsClub: true)
        case "pages/club/topic-detail/index", "pages/club/topic-story/index":
            // MP topic-detail reads topicId (or id); the story opens one row down from the topic page.
            if let topic = queryID(query, "topicId") ?? reviewedID(query) {
                clubRead(.topicOverview, .init(clubID: queryID(query, "clubId"), topicID: topic, activityID: queryID(query, "activityId")), needsClub: false)
            } else { unavailable }
        case "pages/club/governance/index":
            // MP governance onLoad (ClubGovernanceEntryRoute): manage → the governance workspace; report / appeal → 我的平台工单.
            switch ClubGovernanceEntryRoute.resolve(query) {
            case .success(let route):
                if case .manage = route.mode {
                    clubGovernance { g in ClubGovernanceWorkspaceView(clubID: route.clubID, identity: session.clubIdentity, access: g.access, coordinator: g.coordinator) }
                } else { clubRead(.cases, .init(clubID: route.clubID), needsClub: true) }
            case .failure: unavailable
            }
        case "pages/club/roles/index":
            clubRead(.roles, .init(clubID: clubQueryID(query), activityID: queryID(query, "activityId")), needsClub: true)
        case "pages/topic/index/index":
            if let id = reviewedID(query) { SessionTopicDetailView(id: id, session: session) } else { unavailable }
        case "pages/templatedetail/templatedetail":
            // PC-A-6-2: the link opens the template with 应用, as in-app entries do.
            if let id = reviewedID(query) {
                DiscoveryTemplateDetailView(id: id, reader: session, authoringFactory: { session.templateAuthoringEditor(adopting: $0) },
                                            authoringRevision: session.sessionRevision, authoringCompletion: session.templateAuthoringCompletionContext)
                    .id(session.templateAuthoringViewIdentity)
            } else { unavailable }
        case "pages/square/detail/index":
            if let id = reviewedID(query) {
                SquareDetailView(id: id, reader: session.squareReader, accountReader: session.socialAccountReader, actions: session.socialActionCoordinator)
            } else { unavailable }
        case "subpackageMember/orderinfo/orderinfo":
            if let id = reviewedID(query) {
                ProfileOrderDetailView(id: id, reader: session.ownedOrderReader)
                    .environment(\.profileOrderInvoicePresentation, { [weak session] in session?.makeInvoiceLaunchPresentation() })
            }
            else if query["outTradeNo"] != nil { SessionOwnedOrdersView(session: session) }
            else { unavailable }
        case "pages/merchant/index/index":
            SessionMerchantOverviewView(session: session)
        case "pages/merchant/relation/index", "pages/merchant/relation":
            SessionCoopRelationDiscoveryView(session: session, reader: session.cooperationFlowReader)
        case "pages/search2/index", "pages/search2/result/index", "pages/talent/search/index":
            // PC-A-3-2: the MP keyword / filters run the search at once.
            SessionLinkedSearchView(initialQuery: MPSearchLinkQuery.query(query), onSignIn: signIn).environmentObject(session)
        case "pages/searchmap/index":
            SessionLinkedSearchView(initialQuery: MPSearchLinkQuery.mapQuery(query["params"]), startsOnMap: true, onSignIn: signIn).environmentObject(session)
        // Parity X2 / batch A #10 / batch D #6: merchant and coop MP paths open their native screens instead of
        // 该页面暂未开放 (query-free forms; the link rules still reject unknown keys).
        case "pages/merchant/profile/index":
            // MC7-03-2 (profile/index.js:39-64): ?id= is the legacy merchant row; poiId (MC-G03, Gemini) and both/neither
            // stay on the invalid state.
            if query["poiId"] == nil, let id = reviewedID(query), let row = PublicMerchantRowID(id) {
                PublicMerchantHomeView(target: .legacyMerchantRowID(row), context: session.publicMerchantHomeContext)
                    .cyPushedChrome()
            } else { unavailable }
        case "pages/merchant/ledger/batch-detail/index":
            // MC7-08-5 (batch-detail/index.wxml:52): ?batchId= opens the batch; without it 缺少结算批次信息 + 返回上一页.
            // The link rule must also accept batchId (Cursor, Core/MiniProgramPageLink.swift).
            if let batchID = queryID(query, "batchId") {
                MerchantLedgerBatchDetailView(reader: session.merchantBusinessReader, batchID: batchID,
                    owner: .init(scope: session.merchantBusinessReader.scope, authorizationGeneration: session.merchantBusinessReader.authorizationGeneration),
                    onReturn: {})
                    .cyPushedChrome(domain: .merchant)
            } else {
                MerchantMissingParamState(title: "merchant.gate.batch.missingParam")
            }
        case "pages/merchant/ledger/order-detail/index":
            // MC7-07-1 / MC7-07-2 (ledger/order-detail/index.js:23-31,63): recordType + recordId open that ledger record;
            // activity_ticket / session_fee keep their type (Core MerchantOrderDetailLink). Missing pair → 缺少核销记录信息.
            if let ref = MerchantOrderDetailLink.record(query) {
                MerchantBusinessPage(reader: session.merchantBusinessReader, journal: session.merchantBusinessJournal,
                                     query: .redemption(recordID: ref.recordType == "redemption" ? ref.recordID : ref.recordKey))
                    .cyPushedChrome(domain: .merchant)
            } else {
                MerchantMissingParamState(title: "merchant.gate.redemption.missingParam")
            }
        case "pages/merchant/apply/index":
            MerchantOnboardingView(session: session, coordinator: session.merchantOnboardingCoordinator)
        case "pages/merchant/verify-records/index":
            MerchantBusinessPage(reader: session.merchantBusinessReader, journal: session.merchantBusinessJournal, query: .verificationRecords)
                .cyPushedChrome(domain: .merchant)
        case "pages/merchant/team/index":
            MerchantBusinessPage(reader: session.merchantBusinessReader, journal: session.merchantBusinessJournal, query: .operators)
                .cyPushedChrome(domain: .merchant)
        case "pages/merchant/coop-center/index":
            session.merchantCoopCenterDestination()
        case "pages/coop/nearby/index":
            SessionNearbyMerchantsView(session: session)
        case "pages/square/list/index":
            SessionSquareBrowserView(session: session, onClose: { session.dismissNativeEntry() }, onSignIn: {})
        case "pages/shezhi/shezhi":
            // B-SZ-12: `?scene=settings-deregister` opens 账号注销; the other scenes open Settings itself.
            if query["scene"] == "settings-deregister", let coordinator = session.accountComplianceCoordinator {
                AccountComplianceSheet(coordinator: coordinator, destination: .cancellation, market: session.operationalMarket, legalReader: session.legalReader)
            } else {
                // Settings reads the unread badge owner (NativeChannelNotificationSettingsEntry); the link sheet sits
                // outside the root's badge lifecycle, so it carries its own (no push binding, reads only).
                SettingsView().environmentObject(session)
                    .modifier(NativeOriginalUnreadBadgeLifecycle(session: session))
            }
        case "pages/shezhi/marketing/index":
            // B-MK-04: 营销消息与优惠券 is a pushed page, so no close button.
            if let coordinator = session.accountComplianceCoordinator {
                AccountComplianceSheet(coordinator: coordinator, destination: .marketing, market: session.operationalMarket,
                                       legalReader: session.legalReader, showsCloseButton: false)
            } else { unavailable }
        case "pages/gerenziliao/gerenziliao":
            // JSEAT-3: the lobby's 编辑 opens the same own-profile editor as 我的 → 编辑资料.
            // A3-08: `?field=introduction|category` opens that editor after the first load.
            if session.account != nil {
                ProfileEditView(coordinator: session.profileEditCoordinator, sessionRevision: session.contentDetailRevision, categoryReader: session,
                                currentReviewReader: session.profileCurrentReviewReader, nicknameReader: session.profileNicknameReader,
                                savedMedia: session.profileSavedMediaReaders, initialField: query["field"])
            } else { unavailable }
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
            // One shared wallet host: 开始游戏, pending orders, sign-in; `focusId` lands on that registration.
            SessionTicketWalletHost(isPushed: true, focusTopicID: reviewedID(query, key: "topicId"),
                                    focusRegistrationID: reviewedID(query, key: "focusId"))
                .environmentObject(session)
        case "subpackageMember/mycanyuinfo/mycanyuinfo":
            if let id = reviewedID(query) { SessionParticipationDetailHost(id: id).environmentObject(session) } else { unavailable }
        case "subpackageMember/character/index":
            if let id = reviewedID(query, key: "topicId") {
                PlayerJourneyRouteDestination(route: .characterCard(topicID: id, activityID: nil)).environmentObject(session)
            } else { unavailable }
        case "subpackageMember/mycanyu/mycanyu":
            SessionPlayerJourneyView(destination: .participations).environmentObject(session)
        case "subpackageMember/myinvite/myinvite":
            SocialInviteHistoryView(reader: session.profileInviteHistoryReader, squareReader: session.squareReader, actions: session.socialActionCoordinator)
        case "subpackageMember/report-mine/index":
            SquareReportProgressView(session: session)
        case "subpackageMember/appeal-mine/index":
            MemberScoreAppealListView(session: session)
        case "subpackageMember/invoice/index":
            invoice { InvoiceLaunchHistoryView(model: $0, onSignIn: signIn) }
        case "subpackageMember/invoice-detail/index":
            if let id = reviewedID(query) {
                invoice { InvoiceLaunchDetailView(model: $0, applicationID: Int64(id), onSignIn: signIn) }
            } else { unavailable }
        case "subpackageMember/invoice-apply/index":
            invoice { InvoiceLaunchApplyView(model: $0, onSignIn: signIn) }
        case "subpackageMember/invoice-titles/index":
            invoice { InvoiceLaunchTitlesView(model: $0, onSignIn: signIn) }
        case "subpackageMember/invoice-title-edit/index":
            invoice { InvoiceLaunchTitleEditor(model: $0, title: nil, onSignIn: signIn) }
        case "subpackageMember/points-history/index":
            PassMarketPointsBridge.destination(for: session)()
        case "subpackageMember/coupon-wallet/index", "subpackageMember/coupon-qr/index":
            // coupon-qr needs the owner-scoped coupon selection to mint a code; the link lands on the wallet,
            // one tap from the code (the code page itself re-checks the owner).
            AccountCollectionCouponsView(reader: session.accountCollectionReader)
        case "subpackageMember/free-explore/index":
            freeExplore
        case "subpackageMember/complaint/index":
            ProfileComplaintDeepLinkScreen(session: session)
        case "subpackageMember/orient-score/index":
            if let topic = reviewedID(query, key: "topicId") {
                OrientScoreDeepLinkScreen(session: session, topicID: topic, activityID: reviewedID(query, key: "activityId") ?? 0,
                                          sessionID: reviewedID(query, key: "sessionId"))
            } else { unavailable }
        case "subpackageMember/report-detail/index":
            if let id = reviewedID(query, key: "reportId") {
                MemberReportProgressDeepLinkScreen(reportID: Int64(id), session: session)
            } else { unavailable }
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
            SessionRoamNearbyTeamsView(onSignIn: openSignIn).environmentObject(session)
        case "subpackageRoam/my-teams/index":
            // RTEAMS-1: a topic team card opens 本场招募 by owner; otherwise the 我的队伍 tab.
            if let ownerID = positiveID(query["ownerId"]), let ownerType = positiveID(query["ownerType"]), ownerType <= 2 {
                OrientLobbyTeamsView(ownerType: ownerType, ownerID: ownerID, scopeTitle: query["scope"]).environmentObject(session)
            } else {
                SessionRoamNearbyTeamsView(initialTab: query["tab"] == "open" ? 0 : 1, onSignIn: openSignIn).environmentObject(session)
            }
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

    @Environment(\.clubBadgeHostFactory) private var badgeHost

    private func clubDetail(_ id: Int, tab: ClubDetailTab?) -> some View {
        ClubDetailView(id: id, reader: session, onSignIn: {}, actionCoordinator: session.clubActionCoordinator,
                       management: session.clubManagementContext, community: session.clubCommunityContext,
                       publicRoster: session.clubPublicRosterReader, requestedTab: tab)
    }

    private var ownedClubs: some View {
        ClubOwnedView(reader: session, onSignIn: {}, actionCoordinator: session.clubActionCoordinator,
                      management: session.clubManagementContext, community: session.clubCommunityContext,
                      publicRoster: session.clubPublicRosterReader)
    }

    /// Club governance screens carry the same environment the 管理 workspace sheet sets.
    @ViewBuilder private func clubGovernance<Content: View>(@ViewBuilder _ content: (ClubGovernanceContext) -> Content) -> some View {
        if let g = session.clubManagementContext.governance {
            content(g)
                .environment(\.clubEnrollmentProfile, g.enrollmentProfile)
                .environment(\.clubOwnerRefundCoordinator, g.ownerRefund)
                .environment(\.clubOpsTimeFactory, g.opsTimeFactory)
                .environment(\.clubCustomerTopics, g.customerTopics)
                .environment(\.clubStoryTemplates, g.storyTemplates)
                .environment(\.clubTerminalSessions, g.terminalSessions)
                .environment(\.clubOwnerFunds, g.ownerFunds)
        } else { unavailable }
    }

    @ViewBuilder private func clubRead(_ operation: ClubGovernanceRead, _ scope: ClubGovernanceScope, needsClub: Bool) -> some View {
        if needsClub && scope.clubID == nil { unavailable } else {
            clubGovernance { g in ClubGovernanceReadView(operation: operation, scope: scope, identity: session.clubIdentity, access: g.access, coordinator: g.coordinator) }
        }
    }

    @ViewBuilder private func clubOperations(_ target: ClubOperationsTarget) -> some View {
        let management = session.clubManagementContext
        if let operations = management.operations {
            ClubOperationsWorkspaceView(target: target, identity: session.clubIdentity, access: operations.access, coordinator: operations.coordinator, hostApplication: management.governance)
        } else { unavailable }
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

    /// PC-C-3-1 / X7: 登录 leaves the link and opens 我的, where sign-in lives (no dead `{}`).
    private func signIn() {
        session.dismissNativeEntry()
        if rootTabSwitch.isAvailable { rootTabSwitch(.mine) }
    }

    @ViewBuilder private func invoice<V: View>(@ViewBuilder _ make: (InvoiceLaunchPresentation) -> V) -> some View {
        if let model = session.makeInvoiceLaunchPresentation() { make(model) } else { unavailable }
    }

    /// `free-explore?registrationId=` opens that order (its 自由探索权益 entry hosts the bundle read);
    /// `?topicId=` opens the topic (the catalog entry before purchase); `?requestId=` (purchase receipt) opens 我的订单.
    @ViewBuilder private var freeExplore: some View {
        if let id = reviewedID(query, key: "registrationId") {
            ProfileOrderDetailView(id: id, reader: session.ownedOrderReader)
        } else if let id = reviewedID(query, key: "topicId") {
            SessionTopicDetailView(id: id, session: session)
        } else if query["requestId"] != nil {
            SessionOwnedOrdersView(session: session)
        } else {
            CYStateLayout(kind: .generic, title: Text("mp.route.missingParam"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var unavailable: some View {
        CYEmptyState(systemImage: "tray", "mp.route.unavailable", messageIdentifier: "mp.route.unavailable")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CYNight.ink0.ignoresSafeArea())
    }
}

/// Canonical positive decimal id for a named query key (already checked by `MiniProgramPageLink`).
private func positiveID(_ text: String?) -> Int? {
    guard let text, text.utf8.count <= 18, text.utf8.allSatisfy({ (48...57).contains($0) }),
          let value = Int(text), value > 0, String(value) == text else { return nil }
    return value
}

/// Canonical positive decimal id, the same shape `MiniProgramPageLink` already required.
/// MP club pages read `clubId` first and fall back to `id`.
private func clubQueryID(_ query: [String: String]) -> Int? { queryID(query, "clubId") ?? reviewedID(query) }

private func queryID(_ query: [String: String], _ key: String) -> Int? {
    guard let text = query[key], text.utf8.count <= 18, text.utf8.allSatisfy({ (48...57).contains($0) }),
          let value = Int(text), value > 0, String(value) == text else { return nil }
    return value
}

private func reviewedID(_ query: [String: String], key: String = "id") -> Int? {
    guard let text = query[key], text.utf8.count <= 18, text.utf8.allSatisfy({ (48...57).contains($0) }),
          let value = Int(text), value > 0, String(value) == text else { return nil }
    return value
}

/// PC-A-1-8: a link to a tab root performs the tab switch once and draws nothing.
private struct MPTabHandoff: View {
    let perform: @MainActor () -> Void
    @State private var done = false
    var body: some View {
        Color.clear
            .accessibilityHidden(true)
            .onAppear { guard !done else { return }; done = true; perform() }
    }
}
