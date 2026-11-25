import SwiftUI

/// Opens a page-map path on the screen that already exists. A path with no composable screen keeps the
/// parity kit's unavailable state. Nothing here grants a read, a write, or a payment.
@MainActor struct MPReviewedPageScreen: View {
    let page: String
    let query: [String: String]
    @EnvironmentObject private var session: AppSession
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    /// Perks deep link: the TEST-only template executor (nil where merchant writes are closed).
    @Environment(\.coopFlowPreviewWrite) private var coopFlowWrite
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
                },
                searchDestination: { AnyView(SessionLinkedSearchView().environmentObject(session)) }
            )
            .id(session.templateAuthoringViewIdentity)
        case "pages/templatedetail/topic-preview/index":
            // Flow gap PC-A-7-2: topic-preview is the MP card deck; 查看详情 pushes topic-detail.
            if let id = reviewedID(query) {
                DiscoveryTopicTemplateDeckHost(coordinator: session.publicTopicTemplateCoordinator(id: id),
                                               readonly: query["readonly"] == "1",
                                               makeDetail: { session.publicTopicTemplateCoordinator(id: id) })
                    .cyPushedChrome()
            } else { unavailable }
        case "pages/templatedetail/topic-detail/index":
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
            case .redirectToPlay(let scope, _, let inviteCode, let registrationID):
                SessionPlayRuntimeView(session: session, destination: .journey(scope), inviteCode: inviteCode, registrationID: registrationID)
            }
        case "pages/play/index":
            // PLAY-10: shared / redirected play links (topicId or activityId).
            // PLAYC-r7-1: carry inviteCode / registrationId (MP play/index.js:673, 701), validated like the circle link.
            let invite = playLinkInviteCode(query)
            let registration = positiveID(query["registrationId"] ?? query["regId"])
            if let id = positiveID(query["activityId"]) {
                SessionPlayRuntimeView(session: session, destination: .journey(.activity(id)), registrationID: registration)
            } else if let id = positiveID(query["topicId"]) {
                SessionPlayRuntimeView(session: session, destination: .journey(.topic(id)), inviteCode: invite, registrationID: registration)
            } else { unavailable }
        case "pages/activity/detail/index":
            if let id = reviewedID(query) {
                ActivityDetailView(id: id, reader: session, playReaderForActivity: { session.playReader(for: .activity($0)) }, registrationEnabled: true)
            } else { unavailable }
        case "pages/activity/baoming/baoming":
            // PC-C-2 routing: MP baoming is the registration step of one activity; land on its detail with the sheet open.
            if let id = reviewedID(query, key: "activityId") {
                ActivityDetailView(id: id, reader: session, playReaderForActivity: { session.playReader(for: .activity($0)) }, registrationEnabled: true, opensRegistrationOnLoad: true,
                                   registrationTicketID: positiveID(query["ticketId"]))
            } else { unavailable }
        case "pages/activity/official-organizer/index":
            if let id = reviewedID(query), let access = session.officialActionCoordinator?.organizer {
                OfficialOrganizerConsoleView(eventID: id, access: access)
            } else { unavailable }
        case "pages/activity/list/index":
            // R7-PC-C3-1: pushed into the caller's stack; system back, no extra 关闭.
            OfficialEventsBrowserView(reader: session.officialEventReader, actions: session.officialActionCoordinator,
                                      onClose: nil, onLogin: signIn)
        case "pages/activity/official-detail/index":
            if let id = reviewedID(query) {
                // PC-C-4-5: guests get a working 登录; THEME missions open their topic (same wiring as 首页).
                OfficialEventDetailView(id: id, reader: session.officialEventReader, actions: session.officialActionCoordinator, onLogin: signIn,
                                        topicLinks: OfficialTopicLinks(reader: session.topicReader, destination: { AnyView(SessionTopicDetailView(id: $0, session: session)) }))
            } else { unavailable }
        case "pages/activity/official-inbox/index":
            // R7-PC-C5-1: guests get a 登录 button, as on the MP.
            OfficialInboxView(reader: session.officialEventReader, actions: session.officialActionCoordinator, onLogin: signIn)
        case "pages/activity/official-mine/index":
            OfficialPublishedView(reader: session.officialEventReader, actions: session.officialActionCoordinator, onLogin: signIn)
        case "subpackageA/pages/infomation/infomation":
            // PC-D-2-1: the mode cards keep their 去看看 (MP switchTab to 首页 / 漫游).
            SocialPlayGuideView(reader: session.socialAccountReader,
                                onOpenDestination: rootTabSwitch.isAvailable ? { destination in
                                    session.dismissNativeEntry()
                                    rootTabSwitch(destination == .roam ? .roam : .home)
                                } : nil,
                                templateReader: session)
            // R7-PC-D2-1: 去发布广场 / 更多玩法 leave this entry for the 发布 tab, like the mode cards.
            .environment(\.rootTabSwitch, rootTabSwitch.isAvailable ? RootTabSwitch { tab in
                session.dismissNativeEntry()
                rootTabSwitch(tab)
            } : .unavailable)
        case "subpackageA/pages/infomationdetail/infomationdetail":
            if let id = reviewedID(query) {
                SocialInformationView(id: id, reader: session.socialAccountReader)
            } else { unavailable }
        case "subpackageA/pages/assetcenter/income-detail/income-detail":
            // PC-D-4-1: no coop-finance grant on this host, so no 主办分润 button (same as SessionWalletCommerceView).
            WalletIncomeView(reader: session.walletHistoryReader, onCooperationFinance: {}, showsCooperationFinance: false,
                             merchantView: query["theme"] == "merchant")
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
            // SALBUM-r7-1: the session camera, so 打开集邮相机 is not the disabled bare camera.
            RoamStampAlbumView(reader: session.roamExperienceReader,
                               stampDestination: { [session] in AnyView(SessionRoamStampCameraView().environmentObject(session)) })
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
                    .merchantProjectHostDestinations(session: session)
                    .cyPushedChrome()
            } else if let id = reviewedID(query) {
                MerchantContentDocumentView(service: session.merchantContentService, query: .chapters(topicID: id))
                    .cyPushedChrome()
            } else { unavailable }
        case "pages/topic/merchantapply/index":
            // R7-PC-B3-5: MP merchantapply with a registration `id` edits it; with `topicId` + `nodeId` it is the 承接 form
            // for that node. A bare `topicId` keeps the chapters screen the form is opened from.
            if let registrationID = reviewedID(query) {
                MerchantContentEditView(service: session.merchantContentService, query: .registration(id: registrationID), kind: .registrationEdit(registrationID))
                    .cyPushedChrome()
            } else if let topicID = reviewedID(query, key: "topicId"), let nodeID = reviewedID(query, key: "nodeId") {
                MerchantContentEditView(service: session.merchantContentService, query: .chapters(topicID: topicID), kind: .registrationCreate(topicID: topicID, nodeID: nodeID),
                                        applyTarget: merchantApplyTarget(query))
                    .cyPushedChrome()
            } else if let topicID = reviewedID(query, key: "topicId") {
                MerchantContentDocumentView(service: session.merchantContentService, query: .chapters(topicID: topicID))
                    .cyPushedChrome()
            } else { unavailable }
        case "pages/topic/pricing/partner/index":
            // R7-PC-B5-1 (P0): MP partner page (`topicId`, `toType`, `toId`) — the partner's terms, not the pricing page.
            if let topicID = reviewedID(query, key: "topicId"), let context = session.publisherLifecycleContext,
               let row = PublisherPartnerLink.lineup(type: query["toType"], id: reviewedID(query, key: "toId")) {
                PublisherPartnerView(topicID: topicID, row: row, client: context.client)
                    .environment(\.topicLineupClubDestination, { clubID in
                    AnyView(MPReviewedPageScreen(page: "pages/club/detail/index", query: ["id": String(clubID)]).environmentObject(session))
                })
                .environment(\.topicLineupMerchantDestination, { memberID in
                    guard let owner = PublicMerchantOwnerID(memberID) else { return AnyView(EmptyView()) }
                    return AnyView(PublicMerchantHomeView(target: .ownerMemberID(owner), context: session.publicMerchantHomeContext))
                })
            } else { unavailable }
        case "pages/topic/pricing/index":
            // PC-B-4-3: MP pricing reads `topicId || id`; the partner page is reached from the pricing lineup.
            if let topicID = reviewedID(query, key: "topicId") ?? reviewedID(query), let context = session.publisherLifecycleContext {
                PublisherPricingView(topicID: topicID, client: context.client, coordinator: context.coordinator)
                    .environment(\.pricingChapterProjectDestination, { topicID in
                    AnyView(MerchantContentDocumentView(service: session.merchantContentService, query: .project(topicID: topicID), focusedTopicID: topicID))
                })
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
                clubDetail(id, tab: ClubDetailTab(rawValue: query["tab"] ?? "").flatMap { [.manage, .overview].contains($0) ? $0 : nil },
                           postID: positiveID(query["postId"]))
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
            } else if let topic = queryID(query, "topicId") {
                clubRead(.topicOverview, .init(clubID: queryID(query, "clubId"), topicID: topic), needsClub: false)
            } else { unavailable }
        case "pages/club/join-requests/index":
            if let id = clubQueryID(query) {
                let management = session.clubManagementContext
                ClubManagementView(clubID: id, identity: session.clubIdentity, access: management.access, coordinator: management.coordinator, viewerRevision: management.viewerRevision,
                                   joinRequestsOnly: true)
            } else { unavailable }
        case "pages/club/notify/index":
            // CLB-notify-01 / -06 (fix-r3-club-b round 3): the MP notify page is one composer: the selectable audience
            // list with counts, 标题 / 内容, 预览受众, then 发送给 N 人. The composer reads the counts itself and shows
            // the no-permission state, so the link opens it directly instead of a counts page with a second list.
            if let clubID = clubQueryID(query) {
                clubGovernance { g in ClubGovernanceCommandForm(route: .init(operation: .sendNotification, scope: .init(clubID: clubID, activityID: queryID(query, "activityId"))), identity: session.clubIdentity, access: g.access, coordinator: g.coordinator) }
            } else { unavailable }
        case "pages/club/topic-detail/index", "pages/club/topic-story/index":
            // MP topic-detail reads topicId (or id). CLB-topic-story-01: the story link opens the story itself, hosted by
            // the topic overview that owns its read (back returns to the topic page).
            if let topic = queryID(query, "topicId") ?? reviewedID(query) {
                let scope = ClubGovernanceScope(clubID: queryID(query, "clubId"), topicID: topic, activityID: queryID(query, "activityId"))
                if page == "pages/club/topic-story/index" {
                    clubGovernance { g in
                        ClubGovernanceReadView(operation: .topicOverview, scope: scope, identity: session.clubIdentity,
                                               access: g.access, coordinator: g.coordinator, opensStoryOnLoad: true)
                    }
                } else {
                    clubRead(.topicOverview, scope, needsClub: false)
                }
            } else { unavailable }
        case "pages/club/governance/index":
            // MP governance onLoad (ClubGovernanceEntryRoute): manage → the governance workspace; report / appeal → 我的平台工单.
            switch ClubGovernanceEntryRoute.resolve(query) {
            case .success(let route):
                // CLB-governance-11 (MP governance js:197-228): report opens the report form seeded with its target and
                // label; manage opens 成员治理 (the ban list and member actions); appeal opens the cases.
                switch route.mode {
                case .manage:
                    clubRead(.bans, .init(clubID: route.clubID), needsClub: true)
                case .report(let type, let targetID, let label):
                    clubGovernance { g in
                        ClubGovernanceCommandForm(route: .init(operation: .report, scope: .init(clubID: route.clubID),
                                                               seed: ["targetType": .string(type.rawValue), "targetId": .integer(targetID),
                                                                      "targetName": .string(label)]),
                                                  identity: session.clubIdentity, access: g.access, coordinator: g.coordinator)
                    }
                case .appeal:
                    clubRead(.cases, .init(clubID: route.clubID), needsClub: true)
                }
            case .failure: unavailable
            }
        case "pages/club/roles/index":
            // CLB-roles-02: the event tools put 「活动名 · 开始时间」 in `activityLabel`; the picker shows it (or 未命名).
            clubRead(.roles, .init(clubID: clubQueryID(query), activityID: queryID(query, "activityId")), needsClub: true)
                .environment(\.clubRoleActivityLabel, ClubRoleActivityLabel.entry(query["activityLabel"]))
        case "pages/topic/catalog/index":
            // A canonical id is the topic screen. Every other catalog link, including a non-canonical id, is home.
            if let link = MiniProgramPageLink(path: page, query: query), case .topic(let id) = link.catalogDestination {
                SessionTopicDetailView(id: id, session: session)
            } else if rootTabSwitch.isAvailable {
                MPTabHandoff { session.dismissNativeEntry(); rootTabSwitch(.home) }
            } else {
                SessionHomeFeedView().environmentObject(session)
            }
        case "pages/topic/index/index":
            if let id = reviewedID(query) {
                let preferSession = MiniProgramPageLink(path: page, query: query)?.opensSessionPickerFirst == true
                SessionTopicDetailView(id: id, session: session, preferSession: preferSession)
            } else { unavailable }
        case "pages/templatedetail/templatedetail":
            // R7-PC-A6-1: MP `scope=my` is the viewer's own template (member read), never the public `api/template/info`.
            if query["scope"] == "my", let id = positiveID(query["id"]).flatMap(MemberPlayTemplateID.init(rawValue:)) {
                SessionOwnedMemberTemplateDetailView(id: id).environmentObject(session)
            // PC-A-6-2: the link opens the template with 应用, as in-app entries do.
            } else if let id = reviewedID(query) {
                DiscoveryTemplateDetailView(id: id, reader: session, authoringFactory: { session.templateAuthoringEditor(adopting: $0) },
                                            authoringRevision: session.sessionRevision, authoringCompletion: session.templateAuthoringCompletionContext)
                    .id(session.templateAuthoringViewIdentity)
            } else { unavailable }
        case "pages/square/detail/index":
            if let id = reviewedID(query) {
                SquareDetailView(id: id, reader: session.squareReader, accountReader: session.socialAccountReader, actions: session.socialActionCoordinator)
            } else { unavailable }
        case "subpackageMember/orderinfo/orderinfo":
            // R7-MEM-17-1: the same lifecycle coordinator and ticket reader as 我的订单, so cancel / refund and 查看票 stay.
            if let id = reviewedID(query) {
                SessionOwnedOrderDetailView(session: session, id: id)
            } else if let outTradeNo = query["outTradeNo"] {
                // FIN-17-6: MP orderinfo.js:7-15 opens the order-center entry prefilled; without the G2 grant, 我的订单.
                if let service = CreatorEditorProduction.orderCenter(session: session) {
                    OrderCenterEntryView(model: OrderCenterEntryModel(service: service), initialOutTradeNo: outTradeNo)
                } else { SessionOwnedOrdersView(session: session) }
            }
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
        case "pages/merchant/ledger/index":
            MerchantLedgerSettlementOverview(reader: session.merchantBusinessReader, journal: session.merchantBusinessJournal,
                                             topicID: MerchantFinanceRoute.normalize(query)?.topicID)
                .cyPushedChrome(domain: .merchant)
        case "pages/merchant/ledger/order-detail/index":
            if let record = MerchantOrderDetailLink.record(query) {
                MerchantBusinessPage(reader: session.merchantBusinessReader, journal: session.merchantBusinessJournal,
                                     query: .redemption(recordID: record.recordKey))
                    .cyPushedChrome(domain: .merchant)
            } else {
                MerchantMissingParamState(title: LocalizedStringKey(MerchantOrderDetailLink.missing))
            }
        // MC7-35-1 / MC7-35-2: settlement-detail `source` finance | ledger | club (MerchantSettlementDetailLink).
        case "pages/coop/settlement-detail/index":
            CoopSettlementDetailRoute(reader: session.cooperationFlowReader, query: query)
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
        case "pages/merchant/apply/index":
            MerchantOnboardingView(session: session, coordinator: session.merchantOnboardingCoordinator)
        case "pages/merchant/verify-records/index":
            MerchantBusinessPage(reader: session.merchantBusinessReader, journal: session.merchantBusinessJournal, query: .verificationRecords)
                .cyPushedChrome(domain: .merchant)
        // fix/r3-merchant-coop-a round 3 (flows-g2 MISSING-ROUTE): bare MP links to half-a merchant pages open the
        // same native screens the workbench pushes. The page link rules keep these query-free.
        case "pages/merchant/aftercare/index", "pages/merchant/aftercare/detail/index":
            // aftercare/detail/index.js:50-54: a detail link without a valid refundId / manualCaseId redirects to the list.
            // The reviewed link rule admits no query on detail yet (Core request in the receipt), so it always lands here.
            MerchantBusinessPage(reader: session.merchantBusinessReader, journal: session.merchantBusinessJournal,
                                 query: .aftercare(.pending, page: 1))
                .cyPushedChrome(domain: .merchant)
        case "pages/merchant/reviews/index":
            MerchantBusinessPage(reader: session.merchantBusinessReader, journal: session.merchantBusinessJournal, query: .reviews(page: 1))
                .cyPushedChrome(domain: .merchant)
        case "pages/merchant/customer/index":
            MerchantBusinessPage(reader: session.merchantBusinessReader, journal: session.merchantBusinessJournal,
                                 query: .customers(MerchantCustomerQuery()))
                .cyPushedChrome(domain: .merchant)
        case "pages/merchant/crm-campaigns/index":
            MerchantCampaignHistoryHost(reader: session.merchantEngagementReader, journal: session.merchantBusinessJournal,
                                        exports: session.merchantExportRecovery)
                .id(session.merchantEngagementReader.scope)
                .cyPushedChrome(domain: .merchant)
        case "pages/merchant/marketing/index":
            SessionMerchantMarketingLinkScreen(session: session)
        case "pages/merchant/marketing/ai-insight/index":
            SessionMerchantMarketingLinkScreen(session: session, initialSurface: .insight)
        case "pages/merchant/predict/index":
            SessionMerchantPredictionLinkScreen(session: session)
        case "pages/merchant/team/index":
            // MC7-29-12: `?invite=` opens the operator invitation landing (same token rule as MerchantOperatorAcceptance).
            if let token = query["invite"], let invitation = try? MerchantOperatorAcceptance(token: token) {
                MerchantOperatorInvitationLandingView(invitation: invitation, reader: session.merchantEngagementReader,
                                                      journal: session.merchantBusinessJournal, exportRecovery: session.merchantExportRecovery,
                                                      requestSignIn: { openSignIn?() })
                    .id(session.sessionRevision)
            } else {
                MerchantBusinessPage(reader: session.merchantBusinessReader, journal: session.merchantBusinessJournal, query: .operators)
                    .cyPushedChrome(domain: .merchant)
            }
        // MC7-34-3: the MP's only entry to 分润明细 is this deep link.
        case "pages/coop/finance/index":
            CoopFinanceProfitView(reader: session.cooperationFlowReader)
                .environment(\.coopWalletReader, session.walletCommerceReader)
                .cyPushedChrome(domain: .merchant)
        // MC7-30-2: coop list opens on the linked tab. The topic-only scope (CooperationInboxTopicFilter) is not seeded yet.
        case "pages/coop/list/index":
            CooperationBrowserView(reader: session.cooperationReader, onClose: { session.dismissNativeEntry() },
                                   peerReader: session.cooperationFlowReader,
                                   initialDirection: CoopListLink(query).tab == "sent" ? .sent : .received,
                                   topicDestination: { AnyView(SessionTopicDetailView(id: $0, session: session)) })
                .id(session.cooperationReader.scope)
        // MC7-32-7: invite-detail `inviteId` + `box`.
        case "pages/coop/invite-detail/index":
            let link = CoopInviteDetailLink(query)
            if let inviteID = link.inviteID {
                CooperationInviteDetailView(key: CooperationInviteKey(id: inviteID, direction: link.box == "sent" ? .sent : .received),
                                            reader: session.cooperationReader, peerReader: session.cooperationFlowReader)
                    .cyPushedChrome(domain: .merchant)
            } else { unavailable }
        // MC7-31-10: the new-invitation page. The `type` / `toId` / `topicId` presets are not applied yet.
        case "pages/coop/invite/index":
            CoopFlowNewInvitationView(reader: session.cooperationFlowReader, operationScope: nil)
                .cyPushedChrome(domain: .merchant)
        // flows-g2 (round 3): merchant decor / city-node / game-node MP paths (query-free in MiniProgramPageLink).
        // decor opens 品牌中心 with the same factory and perks / city-node destinations as the merchant tab.
        case "pages/merchant/decor/index":
            MerchantOperationsHomeView(reader: session.merchantOperationsReader,
                                       destinationFactory: { session.merchantOperationsDestination($0, access: $1) })
                .environment(\.merchantPerkTemplatesDestination, {
                    AnyView(MerchantPerkTemplatesHost(reader: session.cooperationFlowReader, executor: coopFlowWrite?.executor()))
                })
                .environment(\.merchantCityNodeHubDestination, { AnyView(session.merchantCityNodeHub()) })
                .id(session.merchantOperationsReader.scope)
                .cyPushedChrome(domain: .merchant)
        case "pages/merchant/decor/gallery/index", "pages/merchant/decor/coop-setting/index", "pages/merchant/decor/ai-npc/index":
            MerchantDecorLinkedPage(reader: session.merchantOperationsReader,
                                    destination: page.contains("/gallery/") ? .gallery : page.contains("/coop-setting/") ? .cooperation : .character,
                                    open: { session.merchantOperationsDestination($0, access: $1) })
                .id(session.merchantOperationsReader.scope)
                .cyPushedChrome(domain: .merchant)
        case "pages/merchant/decor/perks/index":
            MerchantPerkTemplatesHost(reader: session.cooperationFlowReader, executor: coopFlowWrite?.executor())
                .cyPushedChrome(domain: .merchant)
        case "pages/merchant/citynode/index":
            session.merchantCityNodeHub()
                .cyPushedChrome(domain: .merchant)
        case "pages/merchant/citynode/create/index":
            MerchantCityNodeCreateView(service: session.merchantContentService, placeSearch: PublishingMapKitAdapter())
                .id(session.merchantContentService.scope)
                .cyPushedChrome(domain: .merchant)
        case "pages/merchant/game-node/index":
            // The link rule is query-free today, so `activityId` cannot arrive yet: the entry list (选择场次) opens instead.
            if let activityID = queryID(query, "activityId") {
                SessionMerchantGameNodeView(session: session, activityID: activityID)
                    .cyPushedChrome(domain: .merchant)
            } else {
                MerchantGameNodeEntryView(service: session.merchantGameNodeService, topicID: nil)
                    .id(session.merchantContentService.scope)
                    .cyPushedChrome(domain: .merchant)
            }
        case "pages/merchant/coop-center/index":
            session.merchantCoopCenterDestination()
        case "pages/coop/nearby/index":
            SessionNearbyMerchantsView(session: session)
        case "pages/square/list/index":
            SessionSquareBrowserView(session: session, onClose: { session.dismissNativeEntry() }, onSignIn: {})
        case "pages/shezhi/shezhi":
            // B-SZ-12: `?scene=` lands on the Settings row it names (MP shezhi.js:50, 231-244); unknown or
            // unavailable scenes (and settings-identity-picker, whose entries live on Settings) open Settings itself.
            if query["scene"] == "settings-deregister", let coordinator = session.accountComplianceCoordinator {
                AccountComplianceSheet(coordinator: coordinator, destination: .cancellation, market: session.operationalMarket, legalReader: session.legalReader)
            } else if query["scene"] == "settings-profile", session.account != nil {
                ProfileEditView(coordinator: session.profileEditCoordinator, sessionRevision: session.contentDetailRevision, categoryReader: session,
                                currentReviewReader: session.profileCurrentReviewReader, nicknameReader: session.profileNicknameReader,
                                savedMedia: session.profileSavedMediaReaders)
            } else if query["scene"] == "settings-feedback" {
                ProfileComplaintDeepLinkScreen(session: session)
            } else if query["scene"] == "settings-likes" {
                MPFavoritesLinkHost(session: session)
                    .id(session.profileFavoritesReader.scope)
            } else if query["scene"] == "settings-how-to-play" {
                ProfileGuideHost(reader: session.makeProfileGuideReader(),
                                 makeArticleReader: { session.makeProfileGuideArticleReader($0) },
                                 onOpenDestination: nil, templateReader: session)
                    .id(session.socialAccountReader.identity)
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
            } else if session.account == nil {
                // B-MK-07-r7: MP marketing/index.wxml:3 login gate — a signed-out link says so and offers 登录.
                CYEmptyState(systemImage: "person.crop.circle.badge.exclamationmark", "compliance.marketing.signedOut",
                             messageIdentifier: "compliance.marketing.signedOut",
                             actionTitle: openSignIn == nil ? nil : "compliance.marketing.signIn",
                             actionIdentifier: "compliance.marketing.signIn", actionStyle: .primary, action: openSignIn)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cyPageTitle("compliance.marketing")
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
            // A4-09-r7: topic and post taps use the same favourite navigation owners as 我的 (AccountView).
            MPFavoritesLinkHost(session: session)
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
            if session.account?.effectiveRole == "merchant" { SubscribeMessageProjectsEntry(session: session) }
            else { SessionOwnedOrdersView(session: session) }
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
            SocialInviteHistoryView(reader: session.profileInviteHistoryReader, squareReader: session.squareReader, actions: session.socialActionCoordinator, onSignIn: openSignIn)
        case "subpackageMember/report-mine/index":
            SquareReportProgressView(session: session)
        case "subpackageMember/appeal-mine/index":
            MemberScoreAppealListView(session: session)
        case "subpackageMember/invoice/index":
            // FIN-11-1: `invoice/index?id=` opens that application (MP invoice/index.js onLoad); the bare path is the history list.
            if let id = reviewedID(query) {
                invoice { InvoiceLaunchDetailView(model: $0, applicationID: Int64(id), onSignIn: signIn) }
            } else {
                invoice { InvoiceLaunchHistoryView(model: $0, onSignIn: signIn) }
            }
        case "subpackageMember/invoice-detail/index":
            if let id = reviewedID(query) {
                invoice { InvoiceLaunchDetailView(model: $0, applicationID: Int64(id), onSignIn: signIn) }
            } else {
                // R7-MEM-12-1: MP `cy-empty kind="missing-param"` + 返回, not the generic unavailable placeholder.
                MemberMissingLinkState(identifier: "invoiceDetail.missing")
            }
        case "subpackageMember/invoice-apply/index":
            invoice { InvoiceLaunchApplyView(model: $0, onSignIn: signIn) }
        case "subpackageMember/invoice-titles/index":
            invoice { InvoiceLaunchTitlesView(model: $0, onSignIn: signIn) }
        case "subpackageMember/invoice-title-edit/index":
            invoice { InvoiceLaunchTitleEditor(model: $0, title: nil, onSignIn: signIn) }
        case "subpackageMember/points-history/index":
            PassMarketPointsBridge.destination(for: session)()
        case "subpackageMember/coupon-wallet/index", "subpackageMember/coupon-qr/index":
            // coupon-qr needs the owner-scoped coupon selection to mint a code. The link lands on the wallet, which
            // pushes the code once the owner's list holds that history id unused (R7-MEM-9-1); otherwise the list stays.
            AccountCollectionCouponsView(reader: session.accountCollectionReader,
                                         focusHistoryID: page.hasSuffix("coupon-qr/index")
                                            ? (reviewedID(query, key: "couponHistoryId") ?? reviewedID(query, key: "historyId") ?? reviewedID(query))
                                            : nil)
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
            // R7-MEM-10-1: coupon.js `operationScope = options.scope === 'MERCHANT' ? 'MERCHANT' : ''`.
            SessionCouponManagementView(scope: query["scope"] == "MERCHANT" ? .merchant : .player).environmentObject(session)
        case "subpackageMember/tixian/tixian":
            WithdrawalSupportLandingView(reader: session.walletHistoryReader)
        case "subpackageMember/tixianjilu/tixianjilu", "pages/coop/withdraw/records/index":
            WithdrawalHistoryView(reader: session.walletHistoryReader,
                                  domain: page == "pages/coop/withdraw/records/index" ? .merchant : .player,
                                  onSignIn: openSignIn)
        case "pages/coop/withdraw/index":
            CoopWithdrawNoticeView(isSignedIn: session.account != nil)
        case "pages/userinfo/userinfo":
            // A2-01: MP share links use `userId`; `id` is the older key. `tab` picks the first tab (A2-06).
            if let id = positiveID(query["userId"]) ?? reviewedID(query) {
                SocialPublicProfileView(memberID: id, reader: session.socialAccountReader, squareReader: session.squareReader,
                                        actions: session.socialActionCoordinator, initialTab: query["tab"])
                    .environment(\.socialConversationDestination, session.socialConversationDestination) // A2-03 发消息
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

    private func clubDetail(_ id: Int, tab: ClubDetailTab?, postID: Int? = nil) -> some View {
        ClubDetailView(id: id, reader: session, onSignIn: {}, actionCoordinator: session.clubActionCoordinator,
                       management: session.clubManagementContext, community: session.clubCommunityContext,
                       publicRoster: session.clubPublicRosterReader, requestedTab: tab, focusPostID: postID)
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
    /// `?topicId=` shows the bundle catalog (MKT-7-1, MP `loadEntry` catalog read) with a way to the topic;
    /// `?requestId=` (purchase receipt) resolves to that order. No valid id is the MP missing-param state with 返回.
    @ViewBuilder private var freeExplore: some View {
        if let id = reviewedID(query, key: "registrationId") {
            ProfileOrderDetailView(id: id, reader: session.ownedOrderReader)
        } else if let id = reviewedID(query, key: "topicId") {
            FreeExploreTopicCatalogScreen(topicID: id, session: session, onSignIn: signIn)
        } else if let request = query["requestId"], FreeExploreReceiptResolveScreen.isValid(request) {
            // MKT-7-1: the purchase receipt resolves to that order's bundle detail (MP `loadEntry` receipt read).
            FreeExploreReceiptResolveScreen(requestID: request, session: session, onSignIn: signIn)
        } else {
            MemberMissingLinkState(identifier: "freeExplore.missing")
        }
    }

    private var unavailable: some View {
        CYEmptyState(systemImage: "tray", "mp.route.unavailable", messageIdentifier: "mp.route.unavailable")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CYNight.ink0.ignoresSafeArea())
    }
}

/// Canonical positive decimal id for a named query key (already checked by `MiniProgramPageLink`).
/// PLAYC-r7-1: the sanitized `inviteCode` of a play link (same rule as the retired circle link).
private func playLinkInviteCode(_ query: [String: String]) -> String? {
    if case .play(_, let inviteCode, _) = PlayCircleLegacyLink.resolve(query) { return inviteCode }
    return nil
}

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

/// R7-PC-B3-3, MP merchantapply index.wxml:61-64: 承接标的 = nodeName, then "topicName · chapterName". Only the names the link carries.
private func merchantApplyTarget(_ query: [String: String]) -> [String]? {
    func clean(_ key: String) -> String? {
        guard let raw = query[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        return String(raw.prefix(80))
    }
    let node = clean("nodeName"), topic = clean("topicName"), chapter = clean("chapterName")
    let route = [topic, chapter].compactMap { $0 }.joined(separator: " · ")
    let lines = [node, route.isEmpty ? nil : route].compactMap { $0 }
    return lines.isEmpty ? nil : lines
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


/// A4-09-r7: `pages/mylike/mylike` from a link. Same readers, selection guards and destinations as
/// 我的 › 我的收藏 (AccountView), so 主题 and 帖文 taps open their detail instead of doing nothing.
@MainActor private struct MPFavoritesLinkHost: View {
    @ObservedObject var session: AppSession
    @State private var savedTopicOwner = ProfileFavoriteTopicNavigationOwner()
    @State private var savedPostOwner = ProfileFavoriteNavigationOwner()
    var body: some View {
        let reader = session.profileFavoritesReader
        AccountCollectionFavoritesView(reader: reader, onOpenTopic: { id in
            guard let selected = reader.selectTopic(id, renderedScope: reader.scope) else { return }
            _ = savedTopicOwner.open(selected, scope: reader.scope)
        }, onOpenPost: { route in
            guard let selected = reader.selectPost(route, renderedScope: reader.scope) else { return }
            _ = savedPostOwner.open(selected, scope: reader.scope)
        }, favoriteRemoval: session.makeProfileFavoriteRemovalController(scope: reader.scope),
           communityGate: session.squareReader)
            .environment(\.topicUnlikeController, session.makeTopicUnlikeController())
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
    }
}

/// Builds the one lineup row a partner deep link names, through the public pricing-preview decoder (the row init is
/// Core-internal). `toType` is `club` or `merchant`.
enum PublisherPartnerLink {
    static func lineup(type: String?, id: Int?) -> PublisherLineup? {
        guard let type = type?.trimmingCharacters(in: .whitespacesAndNewlines), ["club", "merchant"].contains(type),
              let id, id > 0 else { return nil }
        let row: ProjectEditJSON = .object(["toType": .string(type), "toId": .number(Decimal(id))])
        return (try? PublisherPricingPreview(.object(["priceMin": .number(0), "lineup": .array([row])])))?.lineup.first
    }
}
