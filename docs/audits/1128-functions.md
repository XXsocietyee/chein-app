# Function audit 2026-11-28: player + club pages

**Summary: 136 screens, 398 controls checked, 65 broken** (Broken + Stub + Missing backend). Another **34 are Release-off**, and 8 of the defects are **P0**.

The owner asked: "Are all completed pages correct and are all functions working properly?" **No.** The read-only flows mostly work: the home feed, search, topic and activity detail, the club feed, join/apply/approve, IM text, phone and Apple sign-in, and profile. But **none of the four payment channels can take money in Release.** On top of that:
- WeChat login is absent.
- Accounts created with Apple cannot be deleted.
- Template publishing and team writes are dead.
- No share link or deep link can open the app.

Scope: first release = player + clubs. Merchant is gated off: `PlayerLaunch.merchantCenterEnabled` is false in Release (Core/PlayerLaunch.swift:10-14). One merchant page still leaks; see P1-14.

| Source | Ref |
|---|---|
| App | chein-app `origin/ui/combined-r7` @ `7a7d2708a` |
| Backend | hengyin `origin/us/r3-functional` @ `844c284e` |
| MP | hengyin `chengyinhub-xcx/` (app.json: 5 tabs, 32 sub-packages) |
| Method | Start at `SessionRootView` (App/QuestifyApp.swift:290). For each tab, follow NavigationLink, navigationDestination, sheet and fullScreenCover. Trace each control → coordinator → service → HTTP. Compare against an index of every backend `@*Mapping` (2,423 mappings). Check the Release composition: leases, approvals, `#if DEBUG`, flags. Then check MP parity. |

Counting notes:
- Screen counts are per area, so a screen reached from two tabs can count twice.
- Controls owned by another area are marked **Unverified (… lane)**. They are traced in that area's table.
- "Release-off" means an action is deliberately or accidentally gated off in Release. Where a visible entry leads to a gated-off action, that is listed as a defect in the fix list.

| Area | Screens | Controls | Broken / Stub / Missing backend | Release-off |
|---|---|---|---|---|
| 首页 (home, search, topic/activity detail, share, deep links) | 21 | 77 | 11 | 2 |
| 漫游 (map home, roam browser, live roam, teams, city, location) | 26 | 62 | 8 | 14 |
| 发布 + IM + notifications | 21 | 72 | 12 | 5 |
| 俱乐部 | 20 | 52 | 8 | 1 |
| 我的 + sign-in + settings + account deletion | 30 | 91 | 10 | 8 |
| Cross-tab money (registration, pay, refund, orders, tickets, check-in) | 18 | 44 | 16 | 4 |
| **Total** | **136** | **398** | **65** | **34** |

## Gates (Swift-free, run in the app repo at `7a7d2708a`)

| Gate | Result |
|---|---|
| `python3 tools/check_scaffold.py` | **PASS**, exit 0. Structural checks: 5,294 Swift files, 21,251 bilingual keys, page route table of 266 pages. l10n reports missing 0, untranslated 0, gaps 0. Release config check passed. Privacy manifest, design lint, typography lint, design consistency, a11y lint (2 range views left: ExternalGameCatalogLaunch, CYFloatingTabBarClearance), log redaction and the appsession ratchet all PASS. |
| `python3 tools/contract_ratchet.py --check` | **PASS** (exit 0): `52 failing, baseline 52, new 0, fixed 0` |
| `python3 tools/check_profile_read_failure_contract.py` | **PASS**: 11 tests OK |
| `python3 tools/check_mp_contract_coverage.py --mp-root chengyinhub-xcx` | exit 0. Of 1,046 MP request sites, 866 matched, 66 matched indirectly, **52 have no Swift contract** and 174 have no pin test. The 52 are listed in the appendix. |

These gates are static. None of them catches the P0s below, because each P0 is a composition or wiring choice that compiles, type-checks and is pinned by tests: a nil approval, a read-only service, a `#if DEBUG` block, or a JSON body sent to a form-param controller.


## Tab 1: 首页 (home)

_Area totals: SCREENS=21 CONTROLS=77 BROKEN=11 RELEASEOFF=2_


AREA=home. Root: `App/SessionHomeFeedView.swift` (首页 tab, `App/QuestifyApp.swift:325`). Release composition checked: `App/RegionalLaunchConfiguration.swift:56-63` grants reads `.homeAndSearch, .manualMap, .publicMapLayers, .publicTopicTemplateCatalogAndDetail, .officialPublicEventCatalogAndDetail, .playNodesAndRouteState`, `contentDetails: .activityAndTopic`, `productionGatesEnabled: true`, `playerWritesEnabled: true` (`:92-93`). `HomeFeedService` is built because `.homeAndSearch` is granted (`App/AppSession.swift:7312`). Every path below was checked against `be_endpoints.tsv` and against the string tables in `Core/ChinaReviewedRouteCapability.swift` (the transport allowlist). Registration, payment and ticket controls are only listed as entry points; the payment lane audits them.

| Screen | Control | App path → endpoint | Backend on us/r3-functional? | Status | Evidence (file:line) | Owning lane |
|---|---|---|---|---|---|---|
| 首页 feed | Initial load: 编辑精选 rail | HomeFeedView → HomeFeedService.section(.recommended) → POST api/topic/list {is_recommend=1,pageSize=5} | Yes, POST /api/topic/list | Works | Core/HomeFeedService.swift:38-41; Core/TopicService.swift:48; chengyinhub-admin/.../api/ApiTopicController.java:2654; MP chengyinhub-xcx/pages/index/index.js:725-728 | mp-home |
| 首页 feed | 附近活动 rail | POST api/activity/list {is_my=0,sort_type=2,pageNum=1,pageSize=4} (form) | Yes, POST /api/activity/list (form params `is_my,sort_type,...`) | Works | Core/HomeFeedService.swift:42-44; chengyinhub-admin/.../api/ApiActivityController.java:192-203; MP pages/index/index.js:757-762 | mp-home |
| 首页 feed | 即将上线 rail | POST api/activity/list {is_my=2,status=2,sort_type=2} | Yes. `status` is ignored by the BE (the public-shelf mapper applies it), which is harmless | Works | Core/HomeFeedService.swift:45-47; ApiActivityController.java:256-265; MP index.js:731-737 | mp-home |
| 首页 feed | 主题 / 活动 segmented stream + reach-bottom paging | POST api/topic/list (sortType 1) / api/activity/list {status=1,sort_type=1} | Yes | Works | App/HomeFeedView.swift:242-254,281-289; Core/HomeFeedService.swift:20-37 | mp-home |
| 首页 feed | Pull to refresh | model.reload → same reads | Yes | Works | App/HomeFeedView.swift:128 | mp-home |
| 首页 feed | Per-rail / stream retry rows + feed-down state | re-schedule the same reads | Yes | Works | App/HomeFeedView.swift:100-108,171-173,256 | mp-states |
| 首页 feed | Feed card tap → topic / activity detail push | router.pushHome → SessionTopicDetailView / ActivityDetailView | n/a (navigation) | Works | App/HomeFeedView.swift:374; App/SessionHomeFeedView.swift:180-191 | mp-home |
| 首页 feed | Stream card 地点 row / long-press 在地图中打开 | openURL(Apple Maps) (MP onAddressTap → openLocation) | n/a | Works | App/HomeFeedView.swift:1007-1040; MP index.js:1443-1448 | mp-home |
| 首页 hero | Banner 和朋友报名活动 | push OfficialEventsBrowserView → GET api/official/events | Yes, GET /api/official/events | Works | App/SessionHomeFeedView.swift:326-328,197-204; Core/OfficialEventService.swift:19; ApiOfficialEventController.java:142 | mp-activity |
| 首页 hero | Banner 成为俱乐部 | signed out → sign-in; signed in → MPReviewedPageScreen("pages/club/apply/index") (club lane audits the page) | Entry only (api/club/become-leader is audited by the club lane) | Works | App/SessionHomeFeedView.swift:329-330,256-261; App/MPReviewedPageScreen.swift:337-338 | mp-club |
| 首页 hero | Banner 成为商家 | filtered out by `PlayerLaunch.isHidden("pages/merchant/apply")`; `merchantCenterEnabled=false` in Release | — | Release-off | Core/HomeSearchTabParity.swift:139-142; Core/PlayerLaunch.swift:10-14; App/SessionHomeFeedView.swift:331 | mp-home |
| 首页 hero | Banner 小游戏 | shown only when `ExternalGameSessionRead.externalGamesOpen`; that is the test host only (`testHostOnly`). The MP has no such banner | — | Release-off | App/HomeSearchTabParityViews.swift:22-26; App/ExternalGameSession.swift:43-52; App/ReviewedAreaSwitch.swift:69-71 | mp-home |
| 首页 hero | Avatar → 我的 | rootTabSwitch(.mine) (MP goUser switchTab) | n/a | Works | App/HomeSearchTabParityViews.swift:142-152; MP index.js:697-700 | mp-home |
| 首页 hero | City menu (pick 上海/北京/…) | stored locally in `@AppStorage homeIndex.manualCity` (MP onManualCityChange) | n/a (local) | Works | App/SessionHomeFeedView.swift:318-323; MP index.js:1430-1435 | mp-home |
| 首页 feed | City location consent card 同意 | HomeCityLocationConsentModel.agree → POST api/compliance/consents | Yes, POST /api/compliance/consents | Works (consent is recorded, but no location follows, see P2) | App/HomeCityLocationConsentHost.swift:50-70; ApiComplianceController.java:64; MP index.js:1352-1376 | mp-home |
| 首页 feed | City location consent card 不同意 | local decline store | n/a | Works | App/HomeCityLocationConsentHost.swift:72-77 | mp-home |
| 首页 feed | City rail (CitySessionHomeRail) auto-load | on appear: `cityCaptureFix()` → RuntimeNativeLocationProvider (shows the permission primer if notDetermined) → city board load | Reads audited by the roam lane | Works (location asked without a tap, see P2) | App/CityKit/CityHomeRail.swift task; App/CityKit/CitySessionWiring.swift:23-25; App/RuntimeNativeLocationProvider.swift:20-32 | mp-roam |
| 首页 hero | 更多玩法 → 动态 | push SessionSquareBrowserView (reads api/v1/community/feeds/…) | Yes (community feed routes) | Works | App/SessionHomeFeedView.swift:97,213-217; Core/SquareService.swift | mp-home |
| 首页 hero | 更多玩法 → 官方活动 | push OfficialEventsBrowserView | Yes | Works | App/SessionHomeFeedView.swift:99 | mp-activity |
| 首页 hero | 更多玩法 → 浏览模板 | rootTabSwitch(.publish) (MP switchTab pages/template/index) | n/a | Works | App/SessionHomeFeedView.swift:102-106 | mp-nav |
| 首页 hero | 更多玩法 → 项目编辑 | sheet ProjectEditLaunchView (publish lane) | Entry only | Unverified (publish lane owns it) | App/SessionHomeFeedView.swift:107,49-60; App/ProjectEditLaunchView.swift | mp-publish |
| 首页 toolbar | 消息 | SessionMessagingToolbarEntry (messaging lane) | Entry only | Unverified (messaging lane owns it) | App/SessionHomeFeedView.swift:166 | mp-nav |
| 首页 toolbar | Map button → map search | push SessionLinkedSearchView(startsOnMap) → SearchMapExplorerView; empty until the user picks an area (`searchMap.areaRequired`) | — | Works | App/SessionHomeFeedView.swift:169-177,232-236; App/SearchMapExplorerView.swift:100-103,132-135 | mp-home |
| Map search | 选择区域 / 搜索此区域 / viewport search | RoamAreaPicker → GET api/city/nodes ?lat/lng… (+ POST api/activity/list, api/map/nearby) | Yes, GET /api/city/nodes, POST /api/map/nearby, /api/map/reverse-geocode | Works | App/SearchMapExplorerView.swift:234-251,278-285; Core/SearchMapService.swift:79,93,105-108 | mp-home |
| Map search | Filters / layers / clear selection / pin detail → destinations | local filters, then the same reads; pins open detail views | Yes, POST /api/map/public-layers | Works | App/SearchMapExplorerView.swift:317-410 | mp-home |
| 首页 search (in-place) | Search field submit (all lanes) | GlobalSearchView → SearchMapService: POST api/topic/list, api/activity/list (form), POST api/club/list, api/merchant/list (JSON), api/search/unified | Yes, all present. club/list and merchant/list take an @RequestBody JSON | Works | App/SessionHomeFeedView.swift:304-312; Core/SearchMapService.swift:154-177,205-215; ApiClubController.java:670-674; ApiMerchantController.java:524-526; ApiContentSearchController.java:40 | mp-home |
| 首页 search | History tap / swipe delete / clear all; recommended keywords | local history store | n/a | Works | App/GlobalSearchView.swift:259-290 | mp-home |
| 首页 search | Result scope chips (全部 / kinds) | local filter | n/a | Works | App/GlobalSearchView.swift:396-402,514-520 | mp-home |
| 首页 search | Result row → activity / topic / club / merchant / city-node detail | NavigationLink destination | Yes (detail reads) | Works | App/GlobalSearchView.swift:479; App/SessionGlobalSearchView.swift:26-34 | mp-home |
| 首页 search | Template results → template detail / topic-template deck | POST api/template/list, api/template/topic-template/list | Yes | Works | App/GlobalSearchLinksAndTemplates.swift:58-84; Core/DiscoveryService.swift:67,113 | mp-home |
| 首页 search | 在地图上找 / 更多找法 menu (nearby, layers, shops) | mapRoute pushes | Yes | Works | App/GlobalSearchView.swift:352-385 | mp-home |
| 首页 search | 重试本页 / 刷新搜索结果 / sign-in for gated lanes | re-run search; onSignIn | Yes | Works | App/GlobalSearchView.swift:426-449,505 | mp-states |
| 首页 feed | Continuation card (继续游戏 / 继续探索) | POST api/registration/my-joined + GET api/play/run-session/list → runtime or detail | Yes, both | Works | App/SessionHomeFeedView.swift:339-383; Core/PlayerJourneyService.swift:19 | mp-home |
| 首页 feed | Today ticket card → 票夹 | push SessionTicketWalletHost (ticket lane) | Entry only | Works (entry; the ticket lane audits the wallet) | App/SessionHomeFeedView.swift:149,219-222,361-370 | mp-journey |
| Topic detail | Load | POST api/topic/info-to-user {id} | Yes | Works | Core/TopicService.swift:64; ApiTopicController.java:2282; App/PlatformConsumerSessionOwner.swift:45 | mp-home |
| Topic detail | 收藏 toggle (+ seed) | POST api/topic/like {id,type 1/0}; seed POST api/topic/like_list | Yes, both | Works | App/TopicFavoriteHost.swift:65-89; ApiTopicController.java:1844,2881 | mp-home |
| Topic detail | Guest 收藏 | guestSignIn → 我的 tab / LoginView sheet | n/a | Works | App/TopicDetailView.swift:98; App/PlatformConsumerSessionOwner.swift:116-118 | mp-home |
| Topic detail | Toolbar share (ShareLink) | ShareLink(url = https://www.chengyinhub.com/pages/topic/index/index?id=N) | No web or app landing: no AASA on the BE/ops, no associated-domains entitlement | Broken | App/TopicXcxSections.swift:476-483; Core/PublicContentShareLink.swift:20-22,150-175; Config/Questify.entitlements | mp-nav |
| Topic detail | 分享海报 sheet + 分享 | TopicSharePosterCardView + ShareLink(same URL) | Same as the share row above | Broken | App/TopicXcxSections.swift:438-464 | mp-nav |
| Topic detail | ⋯ 举报 | UGCReportSheet → POST api/topic/report {id,reason} (reasons from GET api/v1/community/capabilities) | Yes, both (`topicReport(String id, String reason)`) | Works | Core/UGCContentSafetyService.swift:65-68,242-245; Core/ContentReportReasonRules.swift:8,25; ApiTopicController.java:1554-1559 | mp-home |
| Topic detail | ⋯ 屏蔽作者 | target has only `authorName: clubName`, no memberID → `blockedStore.block` skips api/im/block and records a local name block | Server not called | Stub | App/TopicDetailView.swift:101-110; Core/UGCContentSafetyService.swift:512-530 | mp-home |
| Topic detail | ⋯ 联系客服 | sheet SettingsSupportSafetyView | n/a | Works | App/UGCSafetyComponents.swift:645-677 | mp-home |
| Topic detail | 写评价 / reviews card | ContextualReviewComposer → ContextualReviewConfiguredWriter (api/comment/add); `approval` is nil in Release, so `isConfigured=false` and the composer says 评价提交暂不可用 | Yes, POST /api/comment/add {owner_type,owner_id,rating,contents,img_arr,request_id} | Stub | App/TopicDetailView.swift:516-522; App/AppSession.swift:6088-6094; App/ReviewedPlayerWriteLeases.swift:1460-1475 (no contextualReviewApproval); Core/ContextualOperationProduction.swift:174-179; App/ContextualReviewComposer.swift:122,161; ApiCommentController.java:107-117; MP pages/topic/index/index.js:2154 | mp-home |
| Topic detail | 移交给俱乐部承接 (owner) | POST api/club/my → POST api/topic/transfer-to-club | Yes, both | Works | App/TopicDetailView.swift:333-341,149-180; ApiTopicController.java:1595; ApiClubController.java:1389 | mp-home |
| Topic detail | 转为正式主题 (owner, Beta) | POST api/topic/beta/graduate | Yes | Works | App/TopicDetailView.swift:350-358,229-233; ApiTopicController.java:1804 | mp-home |
| Topic detail | 我的游玩记录 → TopicThemeRecordsView | GET api/play/theme/history, api/play/theme/card | Yes, both | Works | App/TopicDetailView.swift:424-430; Core/TopicService.swift:77,84 | mp-home |
| Topic detail | Linked activity row → ActivityDetailView | navigation | n/a | Works | App/TopicDetailView.swift:475 | mp-home |
| Topic detail | Session row / 立即购买 / paywall 解锁 / self-play | registration / checkout (payment lane) | Entry only | Unverified (payment lane) | App/TopicDetailView.swift:437-443,505,572-578 | mp-journey |
| Topic detail | Pull to refresh / load-failure retry | reload info-to-user | Yes | Works | App/TopicDetailView.swift:83,606 | mp-states |
| Activity detail | Load | POST api/activity/info {id} | Yes | Works | Core/ActivityService.swift:38-40; ApiActivityController.java:1360 | mp-activity |
| Activity detail | Toolbar share | CatalogShareCardView renders a PNG and shares the image only: no URL, no QR, nothing that opens the activity | n/a | Works (shares an image, nothing links back) | App/ActivityDetailView.swift:232-247,325-349; App/CatalogShareCardView.swift:7,84 | mp-activity |
| Activity detail | ⋯ 举报 | POST api/v1/community/reports {targetType:"ACTIVITY",targetId,reasonCode,policyVersion,description,evidenceAssetIds,requestId} | Route exists, but `CommunityPostServiceImpl.report` accepts only COMMENT or CONTENT: for ACTIVITY `post=null` → 404 "帖文不存在或不可见" | Broken | Core/UGCContentSafetyService.swift:79-80,230-239,352-369; chengyinhub-system/.../service/impl/CommunityPostServiceImpl.java:962-979 | backend |
| Activity detail | ⋯ 屏蔽主办方 | POST api/im/block {target_member_id} | Yes (`@RequestParam target_member_id`) | Works | Core/UGCContentSafetyService.swift:275-276,336-350; ApiImController.java:294-298 | mp-activity |
| Activity detail | 写评价 | same ContextualReviewConfiguredWriter with no approval → submit disabled | Yes, api/comment/add | Stub | App/ActivityDetailView.swift:464-471,286-290; App/ReviewedPlayerWriteLeases.swift:1460; MP subpackageMember/components/cy/scene-play-activity-detail (submitComment → /api/comment/add) | mp-activity |
| Activity detail | 主题路线 → topic | NavigationLink SessionTopicDetailView | n/a | Works | App/ActivityDetailView.swift:428-434,75 | mp-activity |
| Activity detail | People row → public profile | profileSelection → SocialPublicProfileView | Yes | Works | App/ActivityDetailView.swift:274-285,76 | mp-activity |
| Activity detail | 集合点 → Maps | directionsAction → MKMapItem | n/a | Works | App/ActivityDetailView.swift:664-670,832 | mp-activity |
| Activity detail | 关联玩法模板 rows | read-only rows; the MP `goTemplateDetail` tap has no native counterpart | n/a | Works (read-only; MP parity gap) | App/ActivityAssociatedPlaysSection.swift:1-20; MP scene-play-activity-detail index.wxml goTemplateDetail | mp-activity |
| Activity detail | 需要俱乐部 gate → club profile | CoopRelationClubProfileHost | Yes | Works | App/ActivityDetailView.swift:371-392,77-83 | mp-club |
| Activity detail | More info disclosure | local toggle | n/a | Works | App/ActivityDetailView.swift:492-510 | mp-activity |
| Activity detail | Footer 立即报名 / 查看票夹 / 继续探索 / 取消活动并退款 / cancelled 查看订单 | registration, wallet and refund (payment lane) | Entry only | Unverified (payment lane) | App/ActivityDetailView.swift:716-786,207-211 | mp-journey |
| Activity detail | In-game channel row | InGameChannelRowButton (messaging lane) | Entry only | Unverified (messaging lane) | App/ActivityDetailView.swift:481-490 | mp-activity |
| Activity detail | Pull to refresh / 重新加载 | api/activity/info | Yes | Works | App/ActivityDetailView.swift:192,519 | mp-states |
| Public profile | Load | POST api/user/public-info | Yes | Works | Core/SocialAccountService.swift; ApiUmsMemberController.java:505 | mp-home |
| Public profile | 关注 / 取消关注 | POST api/user/follow/action {follow_member_id, follow: 1/0} | Yes, same names (R10-07 explicit state) | Works | Core/SocialActionContracts.swift:141-146; App/SocialPublicProfileView.swift:579-630; ApiUmsMemberController.java:910-916 | mp-home |
| Public profile | 私信 | POST api/im/start {target_member_id} | Yes | Works | Core/SocialActionContracts.swift:147-149 | mp-nav |
| Public profile | ⋯ 举报用户 | POST api/v1/community/reports {targetType:"MEMBER"} | Same BE defect: only COMMENT or CONTENT is accepted → 404 | Broken | Core/UGCContentSafetyService.swift:220-229; CommunityPostServiceImpl.java:962-979; App/SocialPublicProfileView.swift:358-364 | backend |
| Public profile | ⋯ 屏蔽用户 | POST api/im/block {target_member_id} | Yes | Works | App/SocialPublicProfileView.swift:358; ApiImController.java:294 | mp-home |
| Template detail | Load | POST api/template/info {id} | Yes | Works | Core/DiscoveryService.swift:129-137; ApiTemplateController.java:663 | mp-home |
| Template detail | 应用 (adopt) | sign-in gate, then templateAuthoringEditor (publish lane) | Entry only | Works (entry) | App/DiscoveryTemplateDetailView.swift:103-122 | mp-publish |
| Template detail | 分享 | TemplateXbShareButton → ShareLink(https://www.chengyinhub.com/pages/templatedetail/templatedetail?id=N) | No landing (same as topic share) | Broken | App/DiscoveryTemplateDetailView.swift:126; App/TemplateDetailXbChrome.swift:61-72; Core/PublicContentShareLink.swift:25-27 | mp-nav |
| Template detail | ⋯ 举报 | POST api/template/report or api/template/personal-report {id,reason} | Yes, both | Works | Core/UGCContentSafetyService.swift:69-70; ApiTemplateController.java:735,755 | mp-home |
| Topic-template deck | 用这个模板 | TopicTemplateAdoptionService (installed because playerWritesEnabled) → POST api/template/topic-template/use, binding-status, binding | Yes | Works | App/TopicTemplateUseSection.swift:8-40; ApiTopicTemplateController.java:180,292,361 | mp-publish |
| Topic-template deck | 分享主题模板 | `topicTemplate(id:)` is nil (path not parsed) → ShareLink shares the plain text "/pages/templatedetail/topic-detail/index?id=N" | n/a | Broken | Core/PublicContentShareLink.swift:31-33; App/DiscoveryTemplateDetailView.swift:366-370,415-419 | mp-nav |
| Deep links | chein:// (onOpenURL → receiveCheinURL → pendingDeepLink → replayDeepLink) | iOS never delivers the scheme: `CFBundleURLTypes` is absent from Info.plist and the xcconfigs (only the DEBUG `--debug-open-url` hook feeds it) | n/a | Broken | App/QuestifyApp.swift:849; App/AppSession+DeepLink.swift:7-12,19-38; Config/Info.plist; docs/release/receipts/ui-cur-release-config.md:74-78 | mp-nav |
| Deep links | Universal links (onContinueUserActivity → receiveUniversalLink → HomeLanding push) | `NativeEntryLinkPolicy(verifiedHTTPSOrigins: [])` rejects every https host; no `com.apple.developer.associated-domains` in Config/Questify.entitlements; `docs/release/aasa.json` is not hosted | n/a | Broken | App/AppSession.swift:7092; Core/NativeEntryRouting.swift:46-50; App/MPParityDeepLinkEntry.swift:74-77; Config/Questify.entitlements | mp-nav |
| Deep links | Notification tap → MPNotificationTapRouter → HomeLanding (首页 push) | works for local notifications (CityNotifications set `page`); the app never calls registerForRemoteNotifications, so no server push can land | APNs exists on the BE only for Live Activities | Works (local notifications only) | App/MPParityDeepLinkEntry.swift:87-130; App/CityKit/CityNotifications.swift:42-82; App/QuestifyApp.swift:558-580; App/SessionHomeFeedView.swift:112-130 | mp-nav |


## Tab 2: 漫游 (roam)

_Area totals: SCREENS=26 CONTROLS=62 BROKEN=8 RELEASEOFF=14_


Scope: 漫游 tab, starting at `App/QuestifyApp.swift:325` `roamTab`. `NativeR2Flags.mapHome` defaults on (`App/NativeR2/MapHome/RoamMapHomeFlag.swift:6`), so the root is `RoamMapHomeView` with `roamMapHomeDependencies` (`App/QuestifyApp.swift:356-391`). The passport sheet is `roamBrowser` (`App/QuestifyApp.swift:395-415`). Release gates checked:
- `productionGatesEnabled` and `playerWritesEnabled` are both true in the shipped composition (`App/RegionalLaunchConfiguration.swift:93-94`).
- Almost every roam lease is China-only (`App/ReviewedPlayerWriteLeases.swift:1159,1168,1178,1189,1200,1212,1224,1267,1290`).
- The CITY lease needs `QUESTIFY_CITY_GAME_REGION`. It is empty outside Debug (`Config/Base.xcconfig:35-37`), so it is nil in Release.

xref note: every `api/city-game/*` path that xref.txt lists as unmatched does exist on BE. Those are prefix literals: the concrete children are at `ApiCityGameController.java:51-131`, `ApiCityGameR491Controller.java:52-176` and `ApiCityMonopolyController.java:52-124`. They are still **unreachable in Release**, because `CityGameProductionLease` is only minted when the region is non-empty (`App/ReviewedCityGameLease.swift:128-142`, `App/ReviewedPlayerWriteLeases.swift:875-877`).

| Screen | Control | App path → endpoint | Backend on us/r3-functional? | Status | Evidence (file:line) | Owning lane |
|---|---|---|---|---|---|---|
| RoamMapHomeView | Nearby places pins/list load | RoamMapHomeModel.loadPlaces → roamReader → GET /api/roam/pois (lat,lng,radius) | Yes ApiRoamController.java:129 | Works (China, signed-in, area set) | App/NativeR2/MapHome/RoamMapHomeView.swift:92-95; App/AppSession.swift:6630 | mp-roam |
| RoamMapHomeView | 附近活动 peek | roamEntryNearbyReader → GET /api/roam/entry/nearby | Yes ApiRoamController.java:183 | Works (China) | App/AppSession.swift:6349-6362; App/AppCompositionRoot.swift:540 | mp-roam |
| RoamMapHomeView | Search area / "my location" | Area comes only from `session.roamArea`, which is set by RoamAreaPicker (typed lat/lng) or the nearby-teams manual search; the device location is never used | n/a | Broken | App/QuestifyApp.swift:858; App/RoamAreaPicker.swift:3-13; App/AppSession.swift:6629; App/SessionNearbyTeamView.swift:55; MP chengyinhub-xcx/pages/roam/index.js:871,6107 (wx.getLocation) | mp-roam |
| RoamMapHomeView | 需要定位 · 去设置 (denied) | RoamSystemLocationSettingsProvider.openAppSettings → UIApplication.openSettingsURLString | n/a | Works (status read once in .task, never re-read on return from Settings) | App/NativeR2/MapHome/RoamMapHomeSheet.swift:167,200-215; App/RoamLocationSettingsDestination.swift:37-43 | mp-states |
| RoamMapHomeView | 选择区域 (section/menu) | showsAreaPicker → RoamAreaPicker (local only) | n/a | Works | App/NativeR2/MapHome/RoamMapHomeSheet.swift:191,508; App/RoamAreaPicker.swift:71-80 | mp-roam |
| RoamMapHomeView | 走起 / 继续漫游 | model.showsLive → RoamLiveSessionView cover | see Live rows | Works (China signed-in); guest/US gets "Live Roam isn't available for this account" with no sign-in CTA | App/NativeR2/MapHome/RoamMapHomeSheet.swift:232-237; App/RoamLiveSessionView.swift:383-387 | mp-states |
| RoamMapHomeView | 打开地图 · 寻找组队 | push .nearbyTeams → SessionRoamNearbyTeamsView | GET /api/team/nearby ApiPlayTeamController.java:141 | Works (China) | App/NativeR2/MapHome/RoamMapHomeSheet.swift:252-271 | mp-roam |
| RoamMapHomeView | 我的队伍 | push .myTeams → POST /api/team/my, /api/team/my-applications | Yes ApiPlayTeamController.java:273,187 | Works (China) | App/NativeR2/MapHome/RoamMapHomeSheet.swift:273-285; App/RoamNearbyTeamsView.swift:21-32 | mp-roam |
| RoamMapHomeView | Search submit | searchMapReader.citySearch → GET /api/city/nodes?keyword | Yes ApiCityNodeController.java:77 | Works | App/NativeR2/MapHome/RoamMapHomeModel.swift:334-341 | mp-roam |
| RoamMapHomeView | 上次漫游需要确认 · 确认漫游记录 | RoamRecoveryView → GET /api/roam/session?clientSessionKey | Yes ApiRoamController.java:576 | Works | App/NativeR2/MapHome/RoamMapHomeSheet.swift:219-227 | mp-roam |
| RoamMapHomeView | Pull to refresh / 重试 | reloadGeneration += 1 → re-reads above | Yes | Works | App/NativeR2/MapHome/RoamMapHomeSheet.swift:163,360 | mp-roam |
| RoamMapHomeView | Map modes menu: satellite / range | local state | n/a | Works | App/NativeR2/MapHome/RoamMapHomeSheet.swift:489-502 | mp-roam |
| RoamMapHomeView | Menu/more: 城市大富翁 board | showsCityBoard → SessionCityRoamRoot (store without lease) | Yes (ApiCityMonopolyController) | Release-off (entry visible, page says "not open in this build") | App/NativeR2/MapHome/RoamMapHomeSheet.swift:412-416,503-507; App/CityKit/CityRoamRootView.swift:480-481; Config/Base.xcconfig:35-37 | mp-roam |
| RoamMapHomeView | 官方线路 list / detail | officialRouteReader → GET /api/preset/route/list, /info?id | Yes ApiPresetController.java:59,67 | Works | App/NativeR2/MapHome/RoamMapHomeSheet.swift:406-410; Core/OfficialRoute.swift:116-121 | mp-roam |
| RoamMapHomeView | 漫游护照与工具 | showsPassport → roamBrowser sheet | — | Works | App/NativeR2/MapHome/RoamMapHomeSheet.swift:400-404 | mp-roam |
| Map place card | 路线 / 导航 (directions) | `dependencies.makeExternalMaps != nil`; `PlatformConsumerSessionOwner()` is built with no maps builder, so this is always nil | n/a | Release-off (button hidden; MP roam-place-card has wx.openLocation) | App/NativeR2/MapHome/RoamMapHomePlaceCard.swift:207-208,227-231; App/AppSession.swift:657; App/PlatformConsumerSessionOwner.swift:3-4,18-20 | mp-roam |
| Map place card | 分享 | ShareLink(PublicContentShareLink.poi) | n/a | Works | App/NativeR2/MapHome/RoamMapHomePlaceCard.swift:246 | mp-roam |
| Map place card | 详情 / event / team rows | push placeDetail / event / team | — | Works | App/NativeR2/MapHome/RoamMapHomePlaceCard.swift:238,318,380-384 | mp-roam |
| RoamBrowserView | Layer = 活动 (events) | effectiveReader = roamNearbyEventsReader; its access is `roamNearbyEventsReadAccess`, which defaults to nil and has no gate fallback | BE n/a (reader never configured) | Release-off (layer selectable, reads unconfigured) | App/RoamBrowserView.swift:97-99,461-466; App/AppCompositionRoot.swift:473,538; App/AppSession.swift:6321-6328 | mp-roam |
| RoamBrowserView | Layer = 玩家 (players) | roamNearbyPlayersReader → POST /api/roam/nearby-runners | Yes ApiRoamController.java:790 | Works (China) | App/AppCompositionRoot.swift:539; App/AppSession.swift:6334 | mp-roam |
| RoamBrowserView | Layer = 地点 + radius/filter | roamReader → GET /api/roam/pois | Yes | Works | App/RoamBrowserView.swift:110-125 | mp-roam |
| RoamBrowserView | More menu: 领地 | territoryDestination (always non-nil) → SessionRoamTerritoryView(service nil) | Yes /api/roam/territory/* ApiRoamTerritoryController.java:32-51 | Release-off (shows "Territory unavailable") | App/RoamBrowserView.swift:326-336; App/RoamTerritoryView.swift:8,124-131; App/ReviewedCityGameLease.swift:278-280 | mp-roam |
| RoamBrowserView | More menu: 城市 (cityDestination) | Dead branch: it only shows when territoryDestination is nil, and territoryDestination is never nil | — | Release-off | App/RoamBrowserView.swift:326-337; App/QuestifyApp.swift:396 | mp-roam |
| RoamBrowserView | More menu: 附近组队 / 选择区域 / 账号 / 重试 | nearby teams / area picker / openAccountOrSignIn / startLoad | Yes | Works | App/RoamBrowserView.swift:303-347 | mp-roam |
| RoamBrowserView | 玩法说明 / 开始 (NavigationLinks) | RoamPreflightRulesView / startDestination | — | Works | App/RoamBrowserView.swift:506-519 | mp-roam |
| RoamExperienceHubView (passport) | 漫游护照 history/summary/record | roamPassportHistoryReader → GET /api/roam/passport/history,/summary,/record | Yes ApiRoamPassportController.java:19,23,25 | Works (China) | App/AppSession.swift:6231-6242; App/AppCompositionRoot.swift:542-544 | mp-roam |
| RoamExperienceHubView | Received stamps section | roamReceivedStampReader → POST /api/roam/stamp/received | Yes ApiRoamStampController.java:246 | Release-off (roamReceivedStampReadAccess defaults to nil, no gate fallback) | App/AppSession.swift:6217-6229; App/AppCompositionRoot.swift:476,541 | mp-roam |
| RoamExperienceHubView | Album metadata / tile memory / session facts | roamAlbumMetadataReader, roamTileMemoryReader, roamSessionFactReader | (GET /api/roam/tiles, /tiles/page, /session exist) | Release-off (all three accesses default to nil) | App/AppCompositionRoot.swift:472,537,550-551 | mp-roam |
| RoamExperienceHubView (tools) | 时光胶囊 create/delete/list/detail | RoamPrivateToolsService → /api/capsules/* | Yes CapsuleController.java:14-26 | Works (China player, via roamPrivateToolsWrite) | Core/RoamPassportPrivateToolsReading.swift; App/AppCompositionRoot.swift:584-586; App/AppSession.swift:6282-6294 | mp-roam |
| RoamExperienceHubView (tools) | 探索目标 create/cancel/list | /api/exploration-goals/* | Yes PersonalExplorationGoalController.java:31-37 | Works (China player) | Core/RoamPassportPrivateToolsReading.swift | mp-roam |
| RoamExperienceHubView (tools) | 那年今日 / 月度回顾 | GET /api/exploration-anniversary, /api/monthly-recap | Yes ExplorationAnniversaryController.java:12; MonthlyRecapController.java:12 | Works (China player) | Core/RoamPassportTools.swift | mp-roam |
| RoamExplorationExportView | 准备 / 读取 / 分享 / 保存 | POST /api/personal-exploration-export/prepare,/page → ShareLink / fileExporter | Yes PersonalExplorationExportController.java:33-34 | Works (China player) | App/RoamExplorationExportView.swift:136,324-385 | mp-roam |
| RoamLiveSessionView | GO / 开始漫游 | consent hook → POST /api/compliance/consents(/latest); then POST /api/roam/reveal (sessionId=0, tiles, clientSessionKey), form-encoded | Yes ApiRoamController.java:600 (requires roam_location consent); ApiComplianceController.java:64,125 | Works (China) | Core/RoamLiveSessionController.swift:180-203; App/AppSessionRoamConsent.swift:6-12; Core/RoamLiveService.swift:20-27 | mp-roam |
| RoamLiveSessionView | Location primer → system prompt | CYPermissionPrimerScreen → SessionTrackedRoamLocationProvider → requestWhenInUseAuthorization | n/a | Works (When-In-Use only, no Always) | App/RoamLiveSessionView.swift:178-195; App/SessionBackgroundLocationTracker.swift:47 | mp-roam |
| RoamLiveSessionView | Denied → 去设置 | openSettingsURLString | n/a | Works | App/RoamLiveSessionView.swift:426 | mp-states |
| RoamLiveSessionView | Pause / Resume | controller.pause / resume → pulse (reveal every 10 s, pois every 30 s) | Yes | Works | App/RoamLiveSessionView.swift:685-711; Core/RoamLiveSessionController.swift:205-251 | mp-roam |
| RoamLiveSessionView | 结束漫游 (confirm dialog) | POST /api/roam/finish (sessionId, poiIds, distanceM), then GET /api/roam/session | Yes ApiRoamController.java:854 | Works | App/RoamLiveSessionView.swift:197-212; Core/RoamLiveService.swift:59-62 | mp-roam |
| RoamLiveSessionView | 点亮 / discover POI | POST /api/roam/poi/discover (sessionId, poiId, lat, lng) | Yes ApiRoamController.java:207 | Works | App/RoamLiveSessionView.swift:921-934; Core/RoamExperienceMutationContracts.swift:56-58 | mp-roam |
| RoamLiveSessionView | 探店 / visit shop (POI + registered shop) | POST /api/roam/shop/visit (sessionId, sourceType, sourceId, lat, lng); shops from POST /api/map/nearby | Yes ApiRoamController.java:309; ApiMapController.java:59 | Works | App/RoamLiveSessionView.swift:858-867; Core/RoamLiveService.swift:39-52 | mp-roam |
| RoamLiveSessionView | 打卡 check-in sheet | Local RoamCheckinSheet only; `.checkin` mutation (POST /api/roam/checkin) is never dispatched | Yes ApiRoamController.java:973 | Stub (MP posts /api/roam/checkin for 探索值) | App/RoamLiveSessionView.swift:862,926,1595-1618; MP chengyinhub-xcx/pages/roam/index.js:1152 | mp-roam |
| RoamLiveSessionView | Presence consent toggle + heartbeat | POST /api/roam/presence only when approval.presence==true; the Release lease is built with `presence: false` | Yes ApiRoamController.java:674 | Release-off (toggle hidden; iOS walkers never appear to others) | App/ReviewedPlayerWriteLeases.swift:1172; Core/RoamLiveService.swift:15; App/RoamLiveSessionView.swift:434-439 | mp-roam |
| Roam tools sheet | 附近的人位置分享 switch | POST /api/roam/presence-visibility (sessionId, visible, consentVersion=roam-presence-v1) | Yes ApiRoamController.java:725 (params match) | Release-off (presenceSwitch is nil when !presenceAvailable) | App/RoamLiveSessionView.swift:338-343; App/MPGap/PlayRoam/RoamSessionToolsSheetView.swift:125-126; Core/LocationShareContracts.swift:195-201 | mp-roam |
| Roam tools sheet | 附近正在走的人 list / runner detail | POST /api/roam/nearby-runners (needs presenceEnabled) | Yes ApiRoamController.java:790 | Release-off (always empty) | App/RoamLiveSessionView.swift:237-238 | mp-roam |
| Roam tools sheet | 清空本机缓存 | keychain clearAll + POST /api/roam/share/revoke | Yes ApiRoamShareController.java:111 | Works | App/MPGap/PlayRoam/RoamSessionToolsSheetView.swift:133-143,198-205; App/AppSessionRoamConsent.swift:17-19 | mp-roam |
| Roam tools sheet | 迷雾 / 地图样式 / 减少动态 | bindings to the live view | n/a | Works | App/MPGap/PlayRoam/RoamSessionToolsSheetView.swift:113-123; App/RoamLiveSessionView.swift:175 | mp-roam |
| Roam tools sheet | 位置权限 / 后台持续定位 / 到点提醒 rows | open Settings (background row always shows Off: no Always key) | n/a | Works | App/MPGap/PlayRoam/RoamSessionToolsSheetView.swift:128-131,160-172 | mp-roam |
| RoamLiveSessionView | 恢复 (recover) | GET /api/roam/session | Yes | Works | App/RoamLiveSessionView.swift:474-481 | mp-roam |
| RoamLiveSessionView | Live roam in US market | RoamLiveApproval.allows requires scope.market=="cn"; leases China-only | n/a | Release-off (US) | Core/RoamLiveContracts.swift:12-15; App/ReviewedPlayerWriteLeases.swift:1159,1168 | mp-roam |
| RoamItemDetailView | Place/node load + 重试 | GET /api/city/nodes/{id} (+ /api/city/places/{id}) | Yes ApiCityNodeController.java:98,107 | Works (signed-in; guest sees unauthorized state) | App/RoamItemDetailView.swift:90-104 | mp-roam |
| RoamItemDetailView | 收藏 toggle | POST /api/city/nodes/{id}/favorite (no body) | Yes ApiCityNodeController.java:143 | Works (China) | App/AppSession.swift:6395-6409; Core/RoamExperienceMutationContracts.swift:30,74 | mp-roam |
| RoamItemDetailView | 挑战 / 完成节点 | ChallengePOIHostView → POST /api/city/nodes/{id}/complete (lat,lng,answer,photoUrl,code) | Yes ApiCityNodeController.java:191 (params match) | Works (China) | App/RoamItemDetailView.swift:272; App/AppSession.swift:6410-6416 | mp-roam |
| SessionRoamStampCameraView | 拍城市贴纸 (capture + upload) | POST /api/common/uploadOSS → POST /api/roam/stamp/create (picUrl, caption, idempotencyKey) | Yes ApiCommonController.java:107; ApiRoamStampController.java:99 | Works (China) | App/SessionRoamMediaViews.swift:15-30; App/AppSession.swift:4478-4507 | mp-roam |
| SessionRoamStampCameraView | 投一张换一张 exchange | POST /api/roam/stamp/exchange (givenStampId) | Yes ApiRoamStampController.java:177 | Works | App/SessionRoamMediaViews.swift:19-23; Core/RoamExperienceContracts.swift:189 | mp-roam |
| RoamItemDetailView | 城市贴纸 / 今日城市签 rows | SessionRoamCityStampFlowView → stamp camera + exchange | Yes | Works | App/SessionRoamMediaViews.swift:52-76 | mp-roam |
| SessionRoamPosterView | 扫海报码 (poster button, always visible) | `cameraEnabled: false` is hard-coded; the executor has `enabled:false, approval:nil`; location is DisabledRoamPosterLocation | n/a | Stub (page shows "Camera, location and check-in aren't available right now") | App/RoamItemDetailView.swift:283-287; App/SessionRoamMediaViews.swift:36; App/AppSession.swift:4518-4527; App/RoamPosterScanView.swift:26,49 | mp-roam |
| RoamItemDetailView | 分享 POI | R9PublicShareButton(PublicContentShareLink.poi) | n/a | Works | App/RoamItemDetailView.swift:62-68 | mp-roam |
| RoamItemDetailView | 外部地图导航 | PlatformExternalMapHost(makeModel: nil) | n/a | Release-off (hidden) | App/RoamItemDetailView.swift:250; App/PlatformConsumerViews.swift:85-92; App/AppSession.swift:657 | mp-roam |
| SessionRoamCouponWalletView | Featured coupon → 券包 / show code | AccountCollectionCouponsView → POST /api/coupon/myrecvlist works, but `.environment(\.couponCodeFactory, nil)` removes the code (POST /api/coupon/qr-token) | Yes ApiCouponController.java:418,517 | Broken (an unused coupon can't be shown to the merchant from roam) | App/SessionRoamCouponWalletView.swift:33-35; App/AccountCollectionCouponsView.swift:75-84 | mp-roam |
| SessionRoamCouponWalletView | Destination guard | isCurrent captures reader.searchArea when the closure is built; a nil area falls back to the raw "roamEvent.unavailable" text | n/a | Works (edge: stale/blank state) | App/SessionRoamCouponWalletView.swift:5-21 | mp-states |
| SessionNearbyTeamsView | 使用我的位置 | RuntimeNativeLocationProvider fix → GET /api/team/nearby?lat&lng&radius | Yes ApiPlayTeamController.java:141 | Works (China) | App/NearbyTeamViews.swift:321-324,362-375 | mp-roam |
| SessionNearbyTeamsView | 范围 / 地图样式 / 搜索 / pull-to-refresh | local + GET /api/team/nearby | Yes | Works | App/NearbyTeamViews.swift:94,336-352 | mp-roam |
| SessionNearbyTeamsView | 申请加入 / 撤回申请 | NearbyTeamHTTPWriteAdapter → POST /api/team/apply {teamId,message}, /api/team/withdraw {teamId} (JSON) | Yes ApiPlayTeamController.java:152,166 | Works (China) | App/NearbyTeamViews.swift:433-435,598-601; Core/NearbyTeamHTTPWriteAdapter.swift:110-136 | mp-roam |
| SessionNearbyTeamsView | 申请人 / 同意 / 拒绝 | POST /api/team/applications; POST /api/team/handle {teamId,memberId,approved} | Yes ApiPlayTeamController.java:177,210 | Works (China) | App/NearbyTeamViews.swift:430,460-461; Core/NearbyTeamHTTPWriteAdapter.swift:124-137 | mp-roam |
| SessionNearbyTeamsView | 举报队伍 | POST /api/team/report | Yes ApiPlayTeamController.java:197 | Works | App/NearbyTeamViews.swift:443 | mp-roam |
| SessionNearbyTeamsView | Nearby teams in US market | nearbyTeamRead/Write leases China-only | n/a | Release-off (US) | App/ReviewedPlayerWriteLeases.swift:1267,1290 | mp-roam |
| TeamInvitationEntryView → TeamDetailView | 加入码 → 加入队伍 | makeTeamCoordinator() → TeamReadOnlyService (authority .readOnly, submit returns .notSent) → canSubmit false → "team.writesDisabled". POST /api/team/join is never sent | Yes ApiPlayTeamController.java:130 | Broken | App/SessionNearbyTeamView.swift:27; App/AppSession.swift:5330-5363,5247; Core/TeamService.swift:47,86; Core/TeamCoordinator.swift:118,296; App/TeamHomeView.swift:338,410-414 | mp-roam |
| TeamDetailView (from nearby/我的队伍) | 退出队伍 | same read-only coordinator → POST /api/team/quit never sent | Yes ApiPlayTeamController.java:222 | Broken | App/SessionTeamViews.swift:26; App/TeamHomeView.swift:240 | mp-roam |
| TeamDetailView | 解散队伍 | same → POST /api/team/disband never sent | Yes ApiPlayTeamController.java:245 | Broken | App/TeamHomeView.swift:241,398-400 | mp-roam |
| TeamDetailView | 移出成员 / 切换组队方式 | same → POST /api/team/kick, /api/team/join-mode never sent | Yes ApiPlayTeamController.java:233,85 | Broken | App/TeamHomeView.swift:207,228 | mp-roam |
| Roam / teams | 创建队伍 | Not reachable from roam; only TeamCreateView from an owned registration (TeamHTTPService) | Yes /api/team/create ApiPlayTeamController.java:66 | Unverified (MP my-teams create entry not traced; activity lane) | App/SessionTeamCreateComposition.swift:7-31 | mp-activity |
| SessionCityRoamRoot / CityRoamRootView | Board load / claim / upgrade / challenge / scout / shield / dice | CityMonopolyService → /api/city-game/territory/*, /dice/*, /season/* | Yes ApiCityMonopolyController.java:52-124 | Release-off (no CITY lease: region empty) | App/CityKit/CitySessionWiring.swift:12-19; App/ReviewedCityGameLease.swift:128-142,295-297; Config/Base.xcconfig:35-37 | mp-roam |
| SessionRoamTerritoryView | 附近/我的/排行 + claim/checkin | RoamTerritoryService → /api/roam/territory/nearby,/claim,/checkin,/leaderboard,/my | Yes ApiRoamTerritoryController.java:32-51 | Release-off | App/RoamTerritoryView.swift:8,124-131,411-483 | mp-roam |
| SessionCityPlayerView | 城市地图快照 / 更新 / 队伍参与 / 行动额度 | /api/city-game/state/*, /team-participation/*, /action-budget/* | Yes ApiCityGameController.java:67-93; ApiCityGameR491Controller.java:52-58 | Release-off (hard-coded zh titles) | App/CityPlayerView.swift:4-29; App/RoamTerritoryView.swift:38-42 | en-layout |
| PersonalLocationShareEntry (Settings / public profile) | Share my location / grants / revoke | PersonalLocationShareHTTPService → /api/location-share/personal/* with read/write approvals that are never installed (`installReviewedPersonalLocationShareApprovals` has no caller) | Yes ApiAppGapsPlayerController.java:38-59 | Release-off (entry visible, requests refused) | App/AppSession.swift:1028-1040; App/PersonalLocationShareHost.swift:36-46; App/SettingsView.swift:234; App/SocialPublicProfileView.swift:195 | mp-mine |


## Tab 3: 发布 (publish) + IM + notifications

_Area totals: SCREENS=21 CONTROLS=72 BROKEN=12 RELEASEOFF=5_


AREA=publish. Scope: the 发布 tab (`PublishTabRootView`) and everything reachable from it, IM/inbox/friends/report, and notifications/push. App = chein-app ui/combined-r7, BE = hengyin us/r3-functional.

Release composition: `RegionalLaunchConfiguration.shippedComposition` sets `productionGatesEnabled: true` and `playerWritesEnabled: true`, and pins the market to `.china` (App/RegionalLaunchConfiguration.swift:41-64, :93-94). The upload, cover and shelf approvals are init parameters of `AppCompositionRoot` with the default `{ _ in nil }`. The production `.init(deployment:storage:makeTransport:)` never overrides them (App/AppCompositionRoot.swift:457-463, :505, :517-521, :532, :576). The only places that construct the approval types are fixtures (App/ProjectStoryImageSynthetic.swift, App/ProjectStoryAudioSynthetic.swift, App/OwnedTopicCoverSynthetic.swift, App/OwnerDraftFixtureHost.swift:111).

| Screen | Control | App path → endpoint | Backend on us/r3-functional? | Status | Evidence (file:line) | Owning lane |
|---|---|---|---|---|---|---|
| 发布 tab root (template shelf) | 主题 shelf load | `DiscoveryService.topicTemplates` → POST `api/template/topic-template/list` `{}` | Yes | Works | Core/DiscoveryService.swift:112; chengyinhub-admin/.../api/ApiTopicTemplateController.java:73 | mp-publish |
| 发布 tab root | 玩法 shelf load (paged) | POST `api/template/list` form pageNum,pageSize,keyword,pack_type | Yes (pack_type, keyword bound) | Works | Core/DiscoveryService.swift:54-84; ApiTemplateController.java:574-581 | mp-publish |
| 发布 tab root | 主题/玩法 segmented picker | local tab + `.task(id: tab)` | n/a | Works | App/DiscoveryTemplateBrowserView.swift:107-111,154 | mp-publish |
| 发布 tab root | Pull to refresh | reloadCurrent → same reads | Yes | Works | App/DiscoveryTemplateBrowserView.swift:127 | mp-publish |
| 发布 tab root | Category filter menu / 全部分类 sheet / 清除筛选 | local filter of the loaded rows | n/a | Works | App/DiscoveryTemplateBrowserView.swift:157-162,305,551-575 | mp-publish |
| 发布 tab root | 搜索 link | `SessionGlobalSearchView` with `globalTemplateSearch` | Not traced (home lane) | Unverified | App/DiscoveryTemplateBrowserView.swift:113,211-219 | mp-home |
| 发布 tab root | 消息 bell + unread badge | `SessionMessagingToolbarEntry` → `SessionMessagingHome`; POST `api/im/unread-total` | Yes | Works | App/SessionMessagingEntry.swift:66-86; App/AppSession.swift:6506-6516; ApiImController.java:252 | mp-nav |
| 发布 tab root | “+” menu, signed in: pre-check | `publishingService.read(.capability)` → POST `api/publish/home` `{}`; checks `permission.canProPublish` | Yes (`permission.canProPublish`) | Works | App/PublishTabRootView.swift:69-90; Core/PublishModesContracts.swift:56; ApiPublishController.java:60,88 | mp-publish |
| 发布 tab root | “+” menu, signed out | shown when `session.isConfigured`; `publishHome` stays nil, so each choice shows the toast 发布信息尚未就绪 and retries. No login prompt (MP `ensureLoginFor('publish')`) | n/a | Broken | App/PublishTabRootView.swift:35-38,80-84; chengyinhub-xcx/components/tabBar/index.js:88-90 | mp-states |
| 发布 tab root | + → 自由探索 | `ProjectEditView(projectEditor(.freeExplore))` | Yes (see editor rows) | Works | App/PublishTabRootView.swift:150-163 | mp-publish |
| 发布 tab root | + → 城市定向 | `ProjectEditView(projectEditor(.city))` | Yes | Works | App/PublishTabRootView.swift:152-153 | mp-publish |
| 发布 tab root | + → 互动 (template authoring) | `sessionTemplateAuthoringEntry` → `TemplateAuthoringCoordinator(adapter: TemplateAuthoringAdapter(), requestService: nil)`. The adapter has no transport, so `canSubmit == false` and POST `api/template/draft` / `api/template/publish` is never sent; the screen shows 暂时无法发布 | Yes (ApiTemplateController.java:98,166) | Stub | App/SessionPublishingModesView.swift:87-93; App/AppSession.swift:4723-4731,4780; Core/TemplateAuthoringService.swift:15-26; Core/TemplateAuthoringCoordinator.swift:87-90,160; `templateAuthoringOriginal*Approval` never assigned (App/AppCompositionRoot.swift:1016-1017) | mp-publish |
| 发布 tab root | … → 我的项目 | `SessionCreatorProjectsView` → POST `api/project/my` | Yes | Works | App/PublishTabRootView.swift:47-50; Core/CreatorContentService.swift:14-16; ApiProjectController.java:205 | mp-publish |
| 发布 tab root | … → 内容中心 | `CreatorContentCenterView` → POST `api/creator/center` | Yes | Works | App/PublishTabRootView.swift:51-58; Core/CreatorContentService.swift:47 | mp-publish |
| Topic template deck (topic-preview) | Open from topic row | POST `api/template/topic-template/info` id | Yes | Works | App/DiscoveryTemplateBrowserView.swift:184-190,354; Core/DiscoveryService.swift:120; ApiTopicTemplateController.java:87 | mp-publish |
| Topic template deck | 用这个模板 | POST `/api/template/topic-template/use` {id,scope,requestId}. The copy succeeds, then `copiedDraft` pushes `editorDestination(...)`, but `\.topicEditorDestination` (and `topicTemplateCopiedDestination`) is never set under the 发布 tab, so an empty page is pushed. It is set only in SessionTopicDetailView and the MP deep-link pages | Yes (ApiTopicTemplateController.java:180) | Broken | App/DiscoveryTemplateDetailView.swift:851-860,931-937; App/PlatformConsumerSessionOwner.swift:100; App/MPReviewedPageScreen.swift:75,83; App/TopicXcxSections.swift:492 | mp-publish |
| Topic template deck | 查看详情 | pushes `DiscoveryTopicTemplatePreview` (same /info) | Yes | Works | App/DiscoveryTemplateDetailView.swift:100,905 | mp-publish |
| Play template detail | 玩法 card → detail | POST `api/template/info` id | Yes | Works | App/DiscoveryTemplateBrowserView.swift:433-434; Core/DiscoveryService.swift:127; ApiTemplateController.java:663 | mp-publish |
| Play template detail | 使用此模板 (adopt into authoring) | `templateAuthoringEditor(adopting:)` uses the same coordinator with no transport | Yes | Stub | App/AppSession.swift:4773-4787 | mp-publish |
| Project editor (fabu) | Open: capability + preflight | POST `api/publish/home`, POST `api/topic/edit-detail` | Yes | Works | Core/ProjectEditHTTPService.swift:104-112; App/ReviewedPlayerWriteLeases.swift:1092 | mp-publish |
| Project editor | 保存草稿 (cloud) | POST `api/topic/v2/create` or `api/topic/v2/update` JSON, saveDraft=1 (TopicCreateDTO fields) | Yes | Works | App/ProjectEditView.swift:648; Core/ProjectEditStoryContract.swift:7-37; Core/ProjectEditHTTPService.swift:129-171; ApiTopicController.java:393,756 | mp-publish |
| Project editor | 下一步 / 提交草稿 | v2/create saveDraft=0; for a server draft, v2/update saveDraft=0 (BE `submitDraftV2`). MP uses save → readback → POST `api/topic/publish-draft` instead | Yes | Works | App/ProjectEditView.swift:657-666; Core/ProjectEditSubmissionIntent.swift:16-17; chengyinhub-system/.../CmsTopicServiceImpl.java:3065-3067; chengyinhub-xcx/pages/publish/fabu/index.js:8058,8141 | mp-publish |
| Project editor | Local save / 使用本地草稿 / 清空本地草稿 | `ProjectEditLocalStore` (device only) | n/a | Works | App/ProjectEditView.swift:200,621-630,808-824 | mp-publish |
| Project editor | 发布前提示 / 检查结果 | GET `api/topic/publish-check?topicId&scope` | Yes | Works | Core/ProjectEditHTTPService.swift:264; Core/TopicPublicationFacts.swift:13; ApiTopicStateKeyController.java:246 | mp-publish |
| Project editor | Publication status (draft/review/public stages) | GET `api/topic/publish-status`. `projectEditorRoutes` removes it on the production host (`TestHostOnlyRouteAdmission`, false in Release) | Yes (ApiTopicStateKeyController.java:267) | Release-off | App/ReviewedPlayerWriteLeases.swift:1083-1096; Core/TestHostOnlyRouteAdmission.swift:11-24 | mp-publish |
| Project editor | Request retry / readback / resume post-processing | POST `api/topic/edit-requests/{submit,read,resume-post-processing}`, filtered out on production in the same way | Yes (ApiAppGapsTopicController.java:68-75) | Release-off | App/ReviewedPlayerWriteLeases.swift:1083-1096; Core/ProjectEditHTTPService.swift:38-40,163 | mp-publish |
| Project editor | 封面 (3:4) | PhotosPicker → crop → POST `api/common/uploadOSS` multipart file + bizType=image_3_4 → `url` → `draft.imgUrl`. Admitted through `grant.profile` | Yes (UploadImagePolicy ratio image_3_4) | Works | App/ProjectEditView.swift:1031; App/MPGap/AccountPublish/AccountPublishR10Mounts.swift:18-60; App/PlayerContentImageUpload.swift:22-40; App/ReviewedPlayerWriteLeases.swift:181,633; ApiCommonController.java:107-185; UploadImagePolicy.java:49 | mp-publish |
| Project editor | 图集 (up to 9, 16:9) → imgArr joined with `,` | same uploader, bizType=image_16_9 | Yes | Works | App/ProjectEditView.swift:1032; Core/RetainedImageContracts.swift:19-20 | mp-publish |
| Project editor | 结果卡封面 (1:1) | same uploader, image_1_1 | Yes | Works | App/MPGap/AccountPublish/ProjectEditThemeRulesSection.swift:310 | mp-publish |
| Project editor → chapter story | 添加图片 / 替换图片 | `ProjectStoryImageUploadClient`; `projectStoryImageUploadApproval` is nil in production, so the button is disabled and shows “Image upload is not configured…” | Yes (uploadOSS) | Stub | App/AppSession.swift:3911-3925; App/ProjectEditDetailForms.swift:131-135,186-198; App/AppCompositionRoot.swift:459 | mp-publish |
| Project editor → chapter story | 选择音频 | `ProjectStoryAudioUploadClient`; approval nil in production | Yes | Stub | App/AppSession.swift:3877-3893; App/ProjectEditDetailForms.swift:149-159 | mp-publish |
| Project editor → node | 添加节点图片 | `ProjectNodeImageUploadClient` (uploadOSS image_4_3); approval nil in production, so the button is disabled | Yes | Stub | App/AppSession.swift:3928-3946; App/ProjectNodeImageAuthorView.swift:114-115; App/AppCompositionRoot.swift:460 | mp-publish |
| Project editor | Owned-cover author sheet | `OwnedTopicCoverClient` (api/topic/cover/*); approval nil in production | Yes (ApiAppGapsTopicController.java:37,59) | Stub | App/AppSession.swift:3947-3960; App/ProjectEditView.swift:740 | mp-publish |
| Project editor | Review request / approved-release sheets | `api/approved-topic-release/v1/*`; features are not in the production business config | Yes (ApiAppGapsApprovedTopicReleaseController.java:29-64) | Release-off | App/AppSession.swift:3967-3971,4002-4006; App/ReviewedPlayerWriteLeases.swift:1439-1453 | mp-publish |
| Project editor | 到访方式 (free-explore visit config) | GET/POST `api/topic/free-explore/visit-config` | Yes (ApiTopicController.java:2248,2254) | Works | App/ProjectEditView.swift:1163; App/ReviewedPlayerWriteLeases.swift:1093-1095 | mp-publish |
| Project editor | 去登录 | `LoginView(intent:.player)` sheet | n/a | Works | App/ProjectEditView.swift:354,458 | mp-publish |
| 我的项目 | Topic/activity tabs list | POST `api/project/my` type,state,ownerType,pageNum,pageSize,scope | Yes (same param names) | Works | Core/CreatorContentService.swift:14-16; ApiProjectController.java:205-207 | mp-publish |
| 我的项目 | 上线/下线 topic | POST `/api/topic/update_user_status` {id,scope,expectedUserStatus} | Yes | Works | Core/MyProjectMutations.swift:5,56; App/CloudB3Production.swift:132-142 | mp-publish |
| 我的项目 | 删除 topic/activity, 上下架 activity | POST `/api/topic/delete`, `/api/activity/delete`, `/api/activity/update_publish_status` | Yes | Works | Core/MyProjectMutations.swift:5-10 | mp-publish |
| 我的项目 | 取消活动 | POST `/api/activity/cancel`; `allowsCancelActivity` needs `ReviewedAreaSwitch.moneyPayments` (refund), which is off on the production host | Yes | Release-off | App/CloudB3Production.swift:137-141 | mp-publish |
| 我的项目 | 模板 tab (我的模板 shelf) | `TemplateShelfReadTransport` → POST `api/template/my-list`; `templateShelfReadApproval` is never set in production, so the shelf has no reader | Yes (ApiTemplateController.java:400) | Stub | App/MyProjectTabViews.swift:277-283; App/AppSession.swift:4681-4691,4755-4766; App/AppCompositionRoot.swift:532 | mp-publish |
| 我的项目 | Topic row → project home | `MerchantContentDocumentView(.project)` → `api/project/home` | Yes | Unverified | App/ProjectOwnedContentViews.swift:153-155 | mp-publish |
| IM inbox (SessionMessagingHome) | Conversation list | POST `api/im/conversations` (production `gates.messagingHistory`) | Yes | Works | App/MessagingHomeView.swift:78-80; App/AppCompositionRoot.swift:533-535; ApiImController.java:44 | mp-nav |
| IM inbox | Search / 更多会话 | local filter, displayLimit += 30 | n/a | Works | App/MessagingHomeView.swift:114,174 | mp-nav |
| IM inbox | Swipe 标为已读 | POST `api/im/read` conversation_id | Yes | Works | Core/IMExpandedService.swift:58-59; ApiImController.java:172 | mp-nav |
| IM inbox | Swipe 免打扰 | POST `api/im/mute` conversation_id,muted (form, so `ApiImController`; the JSON variant is `consumes=application/json`) | Yes | Works | Core/IMExpandedService.swift:66; ApiImController.java:227; ApiChannelNotifyController.java:50 | mp-nav |
| IM inbox | 隐藏会话 | POST `api/im/delete` conversation_id | Yes | Works | Core/IMConversationSafety.swift:29-33; ApiImController.java:202 | mp-nav |
| IM inbox | 全部已读 | `IMConversationReadAll` → `api/im/read` for each conversation | Yes | Works | App/MessagingHomeView.swift:127-131,317-328 | mp-nav |
| IM inbox | Empty → 去广场 | pushes `SessionSquareBrowserView` | n/a | Works | App/MessagingHomeView.swift:151-153,255 | mp-nav |
| IM inbox | 发起会话 | `IMStartConversationView` → POST `api/im/start` target_member_id. The user must type a raw numeric member ID | Yes (ApiImController.java:267) | Works | App/IMExpandedViews.swift:531-560; Core/IMExpandedService.swift:57 | mp-nav |
| IM inbox → 好友 | List / requests | GET `api/friend/list`, `api/friend/requests` cursor,limit(,review_cursor) | Yes | Works | Core/NativeFriendService.swift:13,53,70; ApiFriendController.java:45,52; App/AppCompositionRoot.swift:602 | mp-nav |
| IM inbox → 好友 | Request / accept / reject / cancel | POST `api/friend/{action}` JSON peer_id,request_id,msg | Yes (ApiFriendController.java:67) | Works | Core/NativeFriendService.swift:14,91; App/ReviewedPlayerWriteLeases.swift:933-934 | mp-nav |
| IM inbox → 举报结果 | Report recovery entry | `NativeChannelReportRecoveryEntry` | Not traced | Unverified | App/SessionMessagingEntry.swift:58 | mp-nav |
| IM chat (MessagingHistoryView) | Load / older pages | POST `api/im/messages` conversation_id,cursor_id,size | Yes | Works | Core/MessagingService.swift:44; ApiImController.java:64 | mp-nav |
| IM chat | Send text | POST `api/im/send` form conversation_id,msg_type=1,content,client_message_id (`.imSend` route granted) | Yes (ApiImController.java:98-106) | Works | Core/MessageActionService.swift:34-35; App/AppSession.swift:6589-6597; App/ReviewedPlayerWriteLeases.swift:1448 | mp-nav |
| IM chat | Unknown-send receipt / retry | POST `api/im/send-receipt` | Yes | Works | Core/MessageActionService.swift:62; ApiImController.java:147 | mp-nav |
| IM chat | Read on open | POST `api/im/read` conversation_id,read_to,request_id | Yes | Works | Core/IMExpandedService.swift:61-64 | mp-nav |
| IM chat → + | 发送图片 | `IMImageUploadCoordinator` → uploadOSS (X-Upload-Request-ID) → send msg_type=2. The production business config has no `.imUpload` route and `imImageSelection` defaults to false, so the picker is disabled. The row still shows | Yes (ApiCommonController.java:107-125) | Release-off | App/AppSession.swift:6452-6463; App/RetainedImagePresenterHost.swift:19; App/ReviewedPlayerWriteLeases.swift:1439-1457; Core/BusinessRuntimeConfiguration.swift:73,315; App/IMExpandedViews.swift:275-279; MP chengyinhub-xcx/subpackageB/pages/im/chat/index.js:850-858 | mp-nav |
| IM chat → + | 发送路线 | send route card (`routeSendEnabled` defaults to writesEnabled) | Yes | Works | App/IMExpandedViews.swift:282-293; Core/IMExpandedService.swift:49 | mp-nav |
| IM chat → + | 发送位置 | send `.location` payload (ordinary send) | Yes | Works | App/IMExpandedViews.swift:295-309 | mp-nav |
| IM chat | Voice / video / file | Not offered in DMs (MP DMs: text, image, route only); offered only in the club channel host | n/a | Unverified | App/SessionIMExpandedContext.swift:10-12,23-37; App/NativeChannelMessageConversationHost.swift:92-120 | mp-club |
| IM chat → 更多 | 举报这条消息 | POST `api/im/report` form message_id,reason (the JSON variant is `consumes=application/json`) | Yes (ApiImController.java:367) | Works | Core/IMConversationSafety.swift:34; ApiChannelGovernanceController.java:118 | mp-nav |
| IM chat → 更多 | 举报对方 | `CommunityMemberReportSheet`: GET `api/community-trust/reports/taxonomy` → POST `.../submit` (MP `cy-report-sheet target-type=MEMBER`) | Yes (ApiCommunityTrustController.java:38,55) | Works | App/MessagingHistoryView.swift:768; App/CommunityMemberReportSheet.swift:6,263-288 | mp-nav |
| IM chat → 更多 | 拉黑 / 解除拉黑 | POST `api/im/block` / `api/im/unblock` target_member_id | Yes | Works | Core/IMConversationSafety.swift:36; ApiImController.java:294,322 | mp-nav |
| IM system conversation | 我的举报 row + unread | GET `api/v1/community/notifications` (REPORT_*) | Yes (ApiCommunityPostController.java:226) | Works | App/IMDriftEntries.swift:22-40; App/CloudB3Production.swift:98,230; App/SessionMessagingEntry.swift:40 | mp-nav |
| Report progress | Mark notification read | POST `api/v1/community/notifications/{id}/read` {requestId} | Yes (:243) | Works | Core/SquareGovernanceService.swift:104-105 | mp-nav |
| Push | APNs registration / device-token upload | No `registerForRemoteNotifications` and no token upload. `DevicePushRegistrationLifecycle` is a fixture model. BE has no device-token route; ApiChannelNotifyController `pushAttempts` says “无 APNs 发送端” | No | Missing backend | Core/DevicePushRegistrationLifecycle.swift:3-5; docs/release/receipts/ui-cur-release-config.md:54; ApiChannelNotifyController.java:99-105; Config/Questify.entitlements (aps-environment development) | backend |
| Push | Notification tap routing | `MPNotificationTapRouter` (UNUserNotificationCenter delegate) → `PushTapRouter(routeKeys:["page"])` → `session.receiveNativeIntent`; queues until the session is installed | n/a | Works | App/MPParityDeepLinkEntry.swift:89-151; App/QuestifyApp.swift:8,645 | mp-nav |
| Push | Foreground IM push → refresh open chat / island | posts `foregroundMessageArrived`; island or banner | n/a | Works | App/MPParityDeepLinkEntry.swift:124-143 | mp-nav |
| 内容草稿 (content-draft) | List / restore | `ContentDraftService` POST `api/content-draft/list|restore`; `ownerDraftReadApproval` exists only in fixtures, so the page shows ownerDraft.notConfigured | Yes (ApiContentDraftController.java:30,36) | Stub | App/OwnerDraftComposition.swift:3-17; App/OwnerDraftBrowserView.swift:13-21; App/AccountView.swift:464; App/AppCompositionRoot.swift:576 | mp-publish |
| 内容草稿 | Save / publish / delete | No production client (`VersionedContentDraftService` is never constructed); MP does not use content-draft | Yes (:25,41,47) | Stub | Core/VersionedContentDraftService.swift; Core/ChinaReviewedRouteCapability.swift:2035-2040 | mp-publish |
| Square (from IM empty state) | Post with images | uploadOSS bizType=COMMUNITY_POST → POST `api/v1/community/media/register` (BE canonicalises the url back to the key) → POST `api/v1/community/posts` → `/publish` | Yes (CommunityPostServiceImpl.java:145-151) | Works | Core/SquareWorkspaceService.swift:99-142 | mp-home |


## Tab 4: 俱乐部 (clubs)

_Area totals: SCREENS=20 CONTROLS=52 BROKEN=8 RELEASEOFF=1 UNVERIFIED=4_


Area: club (俱乐部 tab `ClubHomeView`, App/QuestifyApp.swift:426-427) and everything reachable from it. Release composition: `RegionalLaunchConfiguration.shippedComposition` pins both the CN and US builds to market `.china` on `https://www.chengyinhub.com/prod-api/` with `productionGatesEnabled` and `playerWritesEnabled` set to true (App/RegionalLaunchConfiguration.swift:40-95). So the club write gates (`market == .china`) are open in both storefronts.

**How sends are admitted.** Every club service sends through `compositionTransport` (App/AppSession.swift:2022, 7339-7341). That transport's `guardedSend` (App/AppCompositionRoot.swift:2605-3621) only sends a request that matches one of its named route branches or path allow-lists. Anything else throws `APIError.notConfigured` (final `else`, AppCompositionRoot.swift:3618-3621). The `ChinaReviewedRouteCapability.wiredPatterns` and `marks` tables are not consulted on this path. A backend route that exists but is missing from the App allow-lists is never sent. These are the club allow-lists:
- `ReviewedProductionGateLeases.clubCommunityPaths` (App/ReviewedPlayerWriteLeases.swift:623-627)
- `MPFirstClubWriteRoute.operationPaths` and `governancePaths` (App/MPFirstClubApprovals.swift:90-117)
- `ReviewedPlayerReadRoute.paths` (App/ReviewedPlayerWriteLeases.swift:506-512)
- the dedicated join/quit, role, public-topics, roster, community-read and badge route parsers.

| Screen | Control | App path → endpoint | Backend on us/r3-functional? | Status | Evidence (file:line) | Owning lane |
|---|---|---|---|---|---|---|
| ClubHomeView | 帖文 / 俱乐部 segmented top tabs (+ `requestedTopTab` feed\|club) | local state; applied once and then cleared | n/a | Works | App/ClubHomeView.swift:57-73,157-161 | mp-club |
| ClubHomeView | List load (created → joined → nearby) | `ClubService.home/my` → POST `api/club/home`, `api/club/my` (admitted by ReviewedPlayerReadRoute) | Yes: ApiClubController.java:1423, :1389 | Works | Core/ClubService.swift:19,36; App/ReviewedPlayerWriteLeases.swift:507 | mp-club |
| ClubHomeView | Club row tap → ClubDetailView | navigationDestination(item: openedClubID) | n/a | Works | App/ClubHomeView.swift:143-147,276 | mp-club |
| ClubHomeView | Inline 加入 pill (nearby) | `ClubActionCoordinator.prepare/confirm` → `ClubActionService` POST `api/club/join` `{id}` + X-Club-Admission-Request-Id/Action/Payload-SHA256 | Yes: ApiClubController.java:981 (reads the same headers) | Works | App/ClubHomeView.swift:347-378; Core/ClubActionService.swift:25-42; App/AppCompositionRoot.swift:3240-3255 | mp-club |
| ClubHomeView | 申请 pill / joined-row pill | opens the detail (`openedClubID`) | n/a | Works | App/ClubHomeView.swift:327-329 | mp-club |
| ClubHomeView | 创建你自己的俱乐部 (ClubOperationsEntryButton .create) | POST `api/club/create` (MPFirstClubWriteRoute.operationPaths) | Yes: ApiClubController.java:547 | Works | App/ClubHomeView.swift:96-108; App/MPFirstClubApprovals.swift:91 | mp-club |
| Create club form | Live name-taken check | `ClubOperationsService.checkClubName` → POST `api/club/name-check` | Yes: ApiClubController.java:560 | Broken: no App allow-list admits it, so the firewall throws and the check always returns `.unchecked` | Core/ClubOperationsService.swift:255; Core/ClubPlayerFlows.swift:28; App/AppCompositionRoot.swift:3618-3621 | mp-club |
| ClubHomeView | Leader quota line | `clubHomeBodyIfAvailable` → ClubTabPageModel | Yes (`api/club/home`) | Works | App/ClubHomeView.swift:111-116,404-411 | mp-club |
| ClubHomeView | Toolbar magnifier → ClubDirectoryView | POST `api/club/list` `{name?}` (final-else public reads list) | Yes: ApiClubController.java:670 | Works | App/ClubHomeView.swift:167-177; Core/ClubService.swift:46-48; App/AppCompositionRoot.swift:2713 | mp-club |
| ClubHomeView | Toolbar share (hub) | universal link `https://www.chengyinhub.com/pages/talent/list/index?tab=` | n/a | Works | App/ClubHomeView.swift:179-183; Core/PublicContentShareLink.swift:61-73 | mp-nav |
| ClubHomeView | Deep link `chein://club/<id>/join` | `replayDeepLink` → `deepLinkClubID` → detail (the join still needs the detail's confirmation) | n/a | Works | App/QuestifyApp.swift:547; Core/CheinDeepLink.swift:49; App/ClubHomeView.swift:153-156 | mp-nav |
| ClubHomeView | Offline-queued join section | `CYScreenOfflineWriteSection(routes: ["/api/club/join"])` | n/a | Works | App/ClubHomeView.swift:134 | mp-states |
| 帖文 feed (ClubCommunityFeedView) | Feed load / pull-to-refresh / load more | POST `api/club/post/feed` `{scope:"all",limit,beforeId}` (ClubCommunityReadRoute plus clubCommunityRead lease) | Yes: ApiClubController.java:2292 | Works | Core/ClubCommunityService.swift:107-112; App/AppCompositionRoot.swift:3326-3336 | mp-club |
| 帖文 feed | Signed-out 登录后查看帖文 + 登录 | `onSignIn` | n/a (BE allows a guest `scope=all`; the MP also gates it) | Works | App/ClubCommunityViews.swift:369-371,541-553 | mp-states |
| Post tile | 点赞 / double-tap like | POST `api/club/post/like` `{postId}` | Yes: :2409 | Works (P2: the MP sends `liked:<target>` so retries are idempotent; the app sends a bare toggle) | Core/ClubCommunityContracts.swift:208; chengyinhub-xcx/pages/club/detail/index.js:3257 | mp-club |
| Post tile | 转发 / 撤销转发 | POST `api/club/post/repost`, `repost/undo` `{postId}` | Yes: :2448, :2455 | Works | App/ClubCommunityViews.swift:782; Core/ClubCommunityContracts.swift:144 | mp-club |
| Post tile | Comments panel (list) | POST `api/club/post/comment/list` `{postId}` | Yes: :2710 | Works | Core/ClubCommunityContracts.swift:103 | mp-club |
| Comments | 发评论 | POST `api/club/post/comment/create` `{postId,content}` | Yes: :2725 | Works | App/ClubCommunityViews.swift:1391; Core/ClubCommunityContracts.swift:209-211 | mp-club |
| Comments | 删除评论 / 举报评论 | POST `api/club/post/comment/delete` \| `comment/report` `{id}` | Yes: :2774, :2813 | Works | App/ClubCommunityViews.swift:1374-1375 | mp-club |
| Post tile | Share post (ShareLink) | `ClubShareLink.post` → `pages/club/detail/index?id=&postId=` | n/a | Works | App/ClubCommunityViews.swift:790-799; Core/PublicContentShareLink.swift:75-79 | mp-nav |
| Post tile menu | 编辑 | POST `api/club/post/update` `{id,content,images,version,requestId}` | Yes: :2628 | Works | App/ClubCommunityViews.swift:806; Core/ClubCommunityContracts.swift:201-203 | mp-club |
| Post tile menu | 置顶 / 取消置顶 | POST `api/club/post/pin` `{id,pinned,version,requestId}` | Yes: :2679 | Broken: `api/club/post/pin` is missing from `clubCommunityPaths` and every other App allow-list. The firewall throws, `submit` maps the throw to `.unknown`, and `journal.markUnknown` leaves the post pending-locked. The dormant outcome query cannot reconcile it. | App/ClubCommunityViews.swift:807; App/ReviewedPlayerWriteLeases.swift:623-627; Core/ClubCommunityService.swift:470-480; App/AppSession.swift:906-908 | mp-club |
| Post tile menu | 删除 | POST `api/club/post/delete` `{id}` | Yes: :2761 | Works | App/ClubCommunityViews.swift:808 | mp-club |
| Post tile menu | 举报 | POST `api/club/post/report` `{id}` (same body as the MP) | Yes: :2793 | Works | App/ClubCommunityViews.swift:810; chengyinhub-xcx/pages/club/detail/index.js:1860 | mp-club |
| Post tile menu | 编辑历史 | POST `api/club/post/history` `{id}` | Yes: :2694 | Works | App/ClubCommunityViews.swift:825,1410-1456 | mp-club |
| Post detail | Like-state read | POST `api/club/post/like-state` | Yes: :2387 | Works | App/ReviewedPlayerWriteLeases.swift:674 | mp-club |
| Post tile | 「+」 follow author | POST `api/user/follow/action` | not verified in this lane | Unverified (owned by mp-mine) | App/ClubCommunityViews.swift:15-16,736 | mp-mine |
| Club detail · 帖文 | Composer row → ClubCommunityComposer → 发布 | POST `api/club/post/create` `{clubId,content,images?,type?,refType?,refId?}` | Yes: :2556 | Works | App/ClubCommunityViews.swift:585-605,1088-1096; Core/ClubCommunityContracts.swift:195-200 | mp-club |
| Composer | 选择图片 (attach images) | `ClubPostImageUploadClient` → POST `api/common/uploadOSS` | Yes: ApiCommonController.java:107 | Release-off: `clubPostImageUploadApproval` is never built in production (default `{ _, _ in nil }`, never reassigned). `canSelectImage` is false and the button is hidden. The MP composer uploads images. | App/AppCompositionRoot.swift:383; App/AppSession.swift:858,922-930; App/ClubPostImagePicker.swift:113-116; chengyinhub-xcx/pages/square/components/cy/post-compose/index.js:447 | mp-club |
| Composer | 作为公告发布 toggle (type 2) | part of `post/create` | Yes | Works | App/ClubCommunityViews.swift:1070-1074 | mp-club |
| Composer | 带上一次游玩记录 picker | `api/registration/my-joined` | yes (other lane) | Unverified (owned by mp-journey) | App/ClubCommunityViews.swift:1065-1068 | mp-journey |
| Composer | Cancel → 保存草稿 / 删除 / 继续编辑 | local draft | n/a | Works | App/ClubCommunityViews.swift:1167-1180 | mp-club |
| ClubDetailView | Detail load | POST `api/club/detail` `{id}` | Yes: :699 | Works | App/ReviewedPlayerWriteLeases.swift:507 | mp-club |
| ClubDetailView · ClubActionPanel | 加入 / 申请(留言) / 退出 (with confirm) | POST `api/club/join` `{id[,joinMessage]}` / `api/club/quit` `{id}` with original-receipt headers; readback through `api/club/admission/receipt` | Yes: :981, :1339, :1354 | Works | App/ClubDetailView.swift:396,550,562; Core/ClubActionService.swift:21-42; Core/ClubOrdinaryAdmissionRoute.swift:26-36 | mp-club |
| ClubDetailView | 举报俱乐部 | governance `cases/report` | Yes: ApiClubGovernanceController.java:98 | Works | App/ClubDetailView.swift:475; App/MPFirstClubApprovals.swift:96 | mp-club |
| ClubDetailView | Toolbar share / header invite | `PublicContentShareLink.club` | n/a | Works | App/ClubDetailView.swift:424,794 | mp-nav |
| ClubDetailView · 概览 | 查看全部成员 sheet (ClubMembersView) | POST `api/club/members` | Yes: :759 | Works | App/ClubDetailView.swift:261-283 | mp-club |
| ClubDetailView · 概览 | 本团贡献榜 inline plus sort, ClubPublicRosterView | POST `api/club/leaderboard` (governance read plus ClubPublicRosterRoute) | Yes: :2842 | Unverified: only `ClubPublicRosterRoute` admits it, and the governance-read body was not checked against that parser | App/ClubDetailView.swift:301-348; App/AppCompositionRoot.swift:3314-3325 | mp-club |
| ClubDetailView · 概览 | 进入群聊 | POST `api/club/chat` `{id}` | Yes: :1522 | Works | App/ClubDetailView.swift:365; App/ReviewedPlayerWriteLeases.swift:109-114 | mp-club |
| ClubDetailView · 概览 | 治理与安全 · 封禁申诉 | `api/club/governance/cases/mine` | Yes: ApiClubGovernanceController.java:125 | Works | App/ClubDetailView.swift:351-359 | mp-club |
| ClubDetailView · 活动 | Club activity list → topic detail | POST `api/club/topics` (ClubPublicTopicsRoute plus clubPublicTopics grant) | Yes: :1659 | Works | App/ClubDetailView.swift:171-185; App/AppCompositionRoot.swift:3306-3313 | mp-club |
| ClubDetailView · 活动 | 发布 + → SessionClubProjectLaunchView | publish lane | — | Unverified (owned by mp-publish) | App/ClubDetailView.swift:173-179 | mp-publish |
| ClubManagementView | 入会申请 list + 通过 / 拒绝 (reviewReason) | POST `api/club/join-requests` `{clubId}`; `join-request/approve\|reject` `{clubId,memberId[,reviewReason]}` | Yes: :1196, :1212, :1218 | Works | Core/ClubManagementService.swift:20,40-46; App/MPFirstClubApprovals.swift:109 | mp-club |
| ClubManagementView | 移除成员 | POST `api/club/remove-member` `{clubId,memberId}` | Yes: :935 | Broken: missing from every App allow-list, so the firewall throws and the user sees "outcome unknown" (`outcomeUnknown(.transport)`). The MP sends it (detail/index.js:3430). | App/ClubManagementView.swift:225; Core/ClubManagementContracts.swift:34; Core/ClubManagementService.swift:53-55 | mp-club |
| Roles (governance) | 委派 / 撤销角色 | POST `api/club/roles/assign` `{clubId,targetMemberId,roleCode,activityId?,customerPhoneVisible?,requestId}`; `roles/revoke` `{clubId,activityId?,assignmentId,version,reason,requestId}`; plus `-receipt` | Yes: ApiClubRoleController.java:131,151,159,168 (field names match) | Works | Core/ClubRoleAssignmentOriginal.swift:75-91; Core/ClubRoleRevocationOriginal.swift:80-94; App/AppCompositionRoot.swift:3282-3305 | mp-club |
| ClubDetailView · 管理 | 统计概览 (ClubStatsOverviewView) | governance read POST `api/stats/club` | Yes: ApiStatsController.java:68 | Broken: no App allow-list admits it; the firewall throws `notConfigured` | App/ClubDetailView.swift:196-200; App/ClubStatsOverviewView.swift:71; Core/ClubGovernanceContracts.swift:118 | mp-club |
| ClubDetailView · 管理 | 结算 (ClubGovernanceReadView .settlement) | governance read POST `api/club/settlement/summary` on compositionTransport | Yes: ApiClubSettlementController.java:80 | Broken: MPFirstClubWriteRoute refuses any path containing "settlement" (MPFirstClubApprovals.swift:146). `PayoutReceiverRouteGrant` only covers PayoutReceiverBridge's own transport. | App/ClubDetailView.swift:203-208; Core/ClubGovernanceContracts.swift:123; App/ReviewedPlayerWriteLeases.swift:1613-1620; App/PayoutReceiverBridge.swift:55 | mp-club |
| Club ops · 客户 | Customer list | governance read `api/club/crm/customers/list` | Yes: ApiClubCrmController.java:40 | Broken: not admitted (only `crm/customers/detail` and `tag-remark` are in governancePaths) | App/ClubGovernanceViews.swift:1980; App/MPFirstClubApprovals.swift:102-105 | mp-club |
| Club ops · 活动运营 | Series list | governance read `api/club/event-ops/series/list` | Yes: ApiClubEventOpsController.java:79 | Broken: not admitted (only `series/detail` is) | App/ClubOpsEventView.swift:268; App/MPFirstClubApprovals.swift:105 | mp-club |
| Club ops · 通知 | Audience counts before send | governance read `api/club/event-notification/audience-counts` | Yes: ApiClubEventNotificationController.java:34 | Broken: not admitted (preview, status and send are) | App/ClubNotificationAudienceView.swift:106; App/MPFirstClubApprovals.swift:101-104 | mp-club |
| ClubDetailView · 管理 | 编辑资料 / 公开可见 / 成员发帖 / 商家合作 / 成员角色 | `api/club/update-mine`, `open-settings/*`, `set-member-role` | Yes: :581, :1158, :1029, :1177, :2494 | Works | App/MPFirstClubApprovals.swift:90-93 | mp-club |
| ClubDetailView · 管理 | Ban / unban / transfer owner / dissolve (+ blockers) | `api/club/governance/*`, `dissolve`, `dissolution-blockers` | Yes: ApiClubGovernanceController.java:55-84; ApiClubController.java:1242,1307 | Works | App/MPFirstClubApprovals.swift:94-97 | mp-club |


## Tab 5: 我的 (mine) + sign-in

_Area totals: SCREENS=30 CONTROLS=91 BROKEN=10 RELEASEOFF=8_




| Screen | Control | App path → endpoint | Backend on us/r3-functional? | Status | Evidence (file:line) | Owning lane |
|---|---|---|---|---|---|---|
| WelcomeView (signed-out 我的 root) | 登录 (welcome.player) | sheet LoginView(intent:.player) | n/a (local) | Works | App/WelcomeView.swift:90-104 | mp-mine |
| WelcomeView (launch) | 创建账号 | onboardingCompleted=true → LoginView | n/a | Works | App/WelcomeView.swift:211-226 | mp-nav |
| WelcomeView (launch) | 先逛一逛 (guest browse) | onBrowse() closure | n/a | Works | App/WelcomeView.swift:233-241 | mp-nav |
| WelcomeView (launch) | 商家 role button | hidden: showsMerchantChoice=false && merchantCenterEnabled | n/a | Release-off | App/WelcomeView.swift:21,227; Core/PlayerLaunch.swift:10-14 | mp-nav |
| WelcomeView | consent checkbox | UsageConsentPolicy.agree/decline (local store) | n/a | Works | App/WelcomeView.swift:310-318 | mp-states |
| WelcomeView | 用户协议 / 隐私 links | SettingsLegalDocumentView ← SettingsBundledLegalReader (bundled CN text; privacy only when legalCatalogApproved) | n/a (bundled) | Works | App/WelcomeView.swift:191-199; Core/SettingsSourceLegalCatalog.swift:6-13 | mp-mine |
| WelcomeView | ··· menu: 草稿 / 设置 / 语言 | OwnerDraftGuestView / SettingsView(isPushed) / LanguageSwitcher | n/a | Works | App/WelcomeView.swift:246-257 | mp-nav |
| LoginView | 手机号登录 (push phone page) | path.append(.phone); gated session.supportsPhoneSignIn (CN: domesticChinaPhone verified) | n/a | Works | App/LoginView.swift:86-108; App/AppSession+PhoneSignIn.swift:9; App/RegionalLaunchConfiguration.swift:88 | mp-mine |
| LoginView | 微信登录 | WeChatAppAuthSection → WeChatAppAuthCoordinator → POST api/login/wechat/app {code} | Yes POST /api/login/wechat/app (code) ApiLoginController.java:634 | Release-off | gate all false + weChatSDKConfiguration=nil + no service passed: App/AppSession.swift:3412-3428; Core/WeChatAppAuth.swift:13-22,114; no CFBundleURLTypes/LSApplicationQueriesSchemes/associated-domains: Config/Info.plist, Config/Questify.entitlements | mp-mine |
| LoginView | WeChat SDK callback (onOpenURL / universal link) | QuestifyApp .onOpenURL → receiveNativeURL → weChatSDKDriver.handle | n/a | Release-off | App/QuestifyApp.swift:849-851; App/AppSession.swift:7193-7204; no URL scheme registered (App/AppSession+DeepLink.swift:20 "The app registers no URL scheme yet") | mp-nav |
| LoginView | 支付宝登录 | AlipayAppAuthSection → api/login/alipay/auth-info, api/login/alipay | MISSING (no /api/login/alipay* mapping) | Missing backend | App/AlipayAppAuthSection.swift:55-66; Core/AlipayAppAuth.swift:150-151; be_endpoints.tsv (absent) | backend |
| LoginView | Sign in with Apple | AuthChannelAppleButton (scopes email,fullName) → AuthChannelCoordinator.completeAppleAuthorization → POST api/login/apple form {identityToken} | Yes POST /api/login/apple (identityToken) ApiLoginController.java:811 | Works | App/AuthChannelAppleButton.swift:40-62; Core/AuthChannelService.swift:110-115; gate App/AppCompositionRoot.swift:24-26 | mp-mine |
| LoginView | Apple fullName/email forwarding | only identityToken sent; fullName discarded | BE names new users "城瘾用户" | Broken | App/AuthChannelAppleButton.swift:40-42; ApiLoginController.java:862-866 | backend |
| LoginView | 账号密码 form | #if DEBUG only (Release returns false) | POST /api/login | Release-off | App/LoginView.swift:20-27 | mp-mine |
| LoginView | 关闭 | cancelPendingLogin + dismiss | n/a | Works | App/LoginView.swift:205-210 | mp-nav |
| LoginView | agreement / privacy push | path.append(.legal) | n/a | Works | App/LoginView.swift:243-253 | mp-mine |
| Phone sign-in (AuthChannelView/PhoneSignInForm) | region picker +86 / +1 | PhoneCountryCode.allCases; wireValue E.164 for +1 | BE PhoneNumbers.parse accepts E.164 | Works | App/AuthChannelView.swift:200-222; Core/AuthChannelService.swift:13-21; ApiLoginController.java:557-562 | en-layout |
| Phone sign-in | 获取验证码 | AuthChannelCoordinator.sendSMSCode → POST api/sms/send form {phone}; 60s local cooldown | Yes POST /api/sms/send (phone) ApiLoginController.java:536 | Works | Core/AuthChannelService.swift:86-88; Core/AuthChannelCoordinator.swift:193-213 | mp-mine |
| Phone sign-in | rate-limit / daily-limit / intl-not-configured errors | BE returns code 500 + errorCode SMS_RATE_LIMITED/SMS_DAILY_LIMIT/SMS_INTL_NOT_CONFIGURED; app only maps HTTP/body 429 → all shown as generic `auth.channels.rejected` | errorCode present | Broken | Core/AuthChannelService.swift:64-84 (StatusEnvelope has no errorCode); Core/AuthChannelCoordinator.swift:172,180; chengyinhub-framework/.../SmsVerificationService.java:28-34,84-95 | mp-states |
| Phone sign-in | 登录 (verify) / auto-submit at 6 digits | POST api/login/phone form {phone, code} → then api/userInfo | Yes POST /api/login/phone (phone, code) ApiLoginController.java:552; /api/userInfo :267 | Works | Core/AuthChannelService.swift:107-123; App/AuthChannelView.swift:186 | mp-mine |
| Phone sign-in | wrong code / frozen / deleted account messages | BE msg ("验证码错误或已过期","账号已被冻结") dropped → generic rejected | n/a | Broken | Core/AuthChannelCoordinator.swift:180; ApiLoginController.java:569-585 | mp-states |
| Session | token refresh | none: no refresh route; 401 → expireIfMatching → signed out | BE has no refresh endpoint (AppTokenService sliding expiry) | Works | Core/APIConfiguration.swift:35 | backend |
| Session | 426 upgrade required | httpStatus(426) → upgradeRequired notice | n/a | Works | Core/AuthChannelCoordinator.swift:181-183 | mp-states |
| PassportView/AccountView 我的 | 设置 toolbar | push SettingsView(isPushed:true) | n/a | Works | App/AccountView.swift:93-103,150-164 | mp-nav |
| AccountView | 消息 toolbar | SessionMessagingToolbarEntry | (other lane) | Unverified | App/AccountView.swift:86 | mp-nav |
| AccountView | pull-to-refresh | memberRefreshToken += 1 → identity/achievement reloads | n/a | Works | App/AccountView.swift:82 | mp-mine |
| AccountView identity card | avatar tap → 个人资料 | showsEditProfile → ProfileEditView | n/a | Works | App/AccountView.swift:53-56,107 | mp-mine |
| AccountView identity card | 开始探索 | onOpenGuideDestination(.roam) | n/a | Works | App/AccountView.swift:60 | mp-mine |
| AccountView identity card | 票夹 pill | TicketPassSheet → TicketWalletView | (orders lane) | Unverified | App/AccountView.swift:172-182 | mp-mine |
| AccountView identity card | ··· menu 公开主页 / 编辑资料 | showsPublicProfile / showsEditProfile | api/user/public-info POST | Works | App/AccountView.swift:254-257; be_endpoints /api/user/public-info | mp-mine |
| AccountView 我的 tab | 订单 entry | ProfileAccountLinks(part:.orders) → SessionOwnedOrdersView (api/registration/list) | Yes POST /api/registration/list | Works | App/AccountView.swift:207; Core/ProfileService.swift:48 | mp-mine |
| AccountView 我的 tab | 我的项目 (管理全部) | ProfileSelfProjectsEntry | (publish lane) | Unverified | App/AccountView.swift:209-212 | mp-publish |
| AccountView 我的 tab | 视频悬赏 / promo | MPParityAccountLinks(.bounty) bound via mpParityPlayerReads (playerWritesEnabled) | (journey lane) | Unverified | App/AccountView.swift:213; App/PlayerJourneyReadBindings.swift:20-27 | mp-journey |
| AccountView 我的 tab | 账户余额 → wallet | SessionWalletCommerceView | (payment lane) | Unverified | App/AccountView.swift:217-223 | mp-mine |
| AccountView 帖文 tab | composer / own posts / bookmarks | OwnProfileComposerHost / ProfileAuthorPostsSection / SquareMineAccountLinks | (square lane) | Unverified | App/AccountView.swift:235-244 | mp-home |
| AccountView 成就 tab | 积分 → 积分明细 | WalletLedgerView(kind:.assetPoints) ← api/user/points/list | Yes POST /api/user/points/list | Works | App/AccountView.swift:106,262-263 | mp-mine |
| AccountView 成就 tab | 如何获取积分 sheet | WalletPointsTasksView | n/a | Works | App/AccountView.swift:108-116 | mp-mine |
| AccountView 成就 tab | 成长中心 | GrowthCenterView ← POST api/growth/center, api/play/growth, api/growth/leaderboard | Yes (all POST) | Works | App/AccountView.swift:264-270; Core/GrowthCenterService.swift:27-38; App/AppCompositionRoot.swift:559 | mp-mine |
| AccountView 成就 tab | 邮票 grid → 邮票册 | RoamAlbumMetadataDestination ← POST api/roam/stamp/list | Yes POST /api/roam/stamp/list | Works | App/PassportView.swift:107-140; App/AccountView.swift:119-130 | mp-roam |
| AccountView 成就 tab | 勋章 → 勋章墙 | ObjectBadgeWallView ← POST api/medal/wall | Yes POST /api/medal/wall | Works | App/AccountView.swift:131; Core/ProfileService.swift:112 | mp-mine |
| AccountView 成就 tab | 藏品 | SessionObjectCardsView | (object lane) | Unverified | App/AccountView.swift:284-287 | mp-mine |
| AccountView 成就 tab | 据点收藏 | CityFavoriteNodesSection ← GET api/city/nodes/favorites; toggle POST api/city/nodes/{id}/favorite | Yes GET /api/city/nodes/favorites; POST /api/city/nodes/{id}/favorite | Works | App/AccountView.swift:288-291; Core/PlayerGapRoutes.swift:215,228 | mp-mine |
| AccountView 关于 tab | 编辑 about | MemberAboutSection onEdit → ProfileEditView | n/a | Works | App/AccountView.swift:297 | mp-mine |
| AccountView 关于 tab | 我的收藏/点赞 (topics, posts) + 取消收藏 | AccountCollectionAccountLinks ← POST api/topic/like_list, api/creativesquare/list; remove POST api/topic/like (toggle), api/creativesquare/bookmark | Yes (all POST) | Works | App/AccountView.swift:298-306; Core/AccountCollectionService.swift:13-19; Core/TopicUnlike.swift:107; Core/ProfileFavoriteRemoval.swift:92 | mp-mine |
| AccountView 关于 tab | 我的优惠券 | couponReader ← POST api/coupon/myrecvlist | Yes | Works | Core/ProfileOwnedCouponReadRoute.swift:30 | mp-mine |
| AccountView 关于 tab | 邀请好友 (个人码) | PlayerCodeAndJoinSection ← POST api/user/player-code (returns MP wxacode) | Yes POST /api/user/player-code ApiUmsMemberController.java:144 | Works | App/AccountView.swift:310-314; App/ReviewedPlayerWriteLeases.swift:155 | mp-mine |
| AccountView 关于 tab | 邀请记录 | SocialInviteHistoryView ← POST api/user/invite_list multipart {pageNum}; rewards api/user/points/list | Yes POST /api/user/invite_list :480 | Works | Core/ProfileInviteHistoryReadRoute.swift:29-45 | mp-mine |
| AccountView 关于 tab | 填写邀请人 (door.inviter.entry) | SessionDoorInviterView → DoorInviterSheet(enabled:false); DoorReferralService(bindingEnabled:false) → api/user/setInviter never sent | Yes POST /api/user/setInviter (inviter_id) :775 | Stub | App/NativeEntryLandingView.swift:10-18; App/AppSessionDoorEntry.swift:26-27; Core/DoorReferralService.swift:54-56 | mp-mine |
| AccountView 关于 tab | 当前权益 → earnings | MemberBenefitsSection | (wallet lane) | Unverified | App/AccountView.swift:323 | mp-mine |
| AccountView 关于 tab | 关注/粉丝 list | ProfileFollowListAccountEntry ← GET api/user/follow-list | Yes GET /api/user/follow-list | Works | App/AccountView.swift:329; Core/ChinaReviewedRouteCapability.swift:1810 | mp-mine |
| AccountView 关于 tab | 私人主页 (account.privateHome) | PrivateHomeAccountLink(coordinator:nil) → CYEmptyState "privateHome.disabled"; ReviewedAppDeployment.privateHome never set | Yes GET/PUT/DELETE /api/native/home | Release-off | App/PrivateHomeView.swift:3-12; App/PrivateHomeComposition.swift:26; App/RegionalLaunchConfiguration.swift:84-97 (no privateHome:) | mp-mine |
| AccountView 关于 tab | 合作 (cooperation) | hidden: showsMerchantChoice && merchantCenterEnabled | n/a | Release-off | App/AccountView.swift:357-364 | mp-mine |
| ProfileEditView | 昵称/简介/标签 保存 | ProfileEditService.save → POST api/user/update JSON {name,introduction,avatar,wechat,casePics,tagIds,caseIntroducton} | Yes @RequestBody UmsMemberUpdateDTO (same field names incl. caseIntroducton) ApiUmsMemberController.java:650 | Works | Core/ProfileEditService.swift:69-90; Core/ProfileEditContracts.swift:184-187 | mp-mine |
| ProfileEditView | 昵称可用检查 / 推荐 | POST api/user/nickname/check {nickname}, /suggest {baseName,cursor} | Yes :125,:131 | Works | Core/ProfileNicknameAvailabilityService.swift:145-157 | mp-mine |
| ProfileEditView | 头像上传 | ProfileAvatarUploadClient → POST api/common/uploadOSS multipart bizType=image_1_1 → api/user/update {avatar}; approval = playerWriteGrant.avatar (CN, role player/club) | Yes POST /api/common/uploadOSS | Works | Core/ProfileAvatarUpload.swift:142-160; App/AppSession+ProfileAvatar.swift:7-27; App/ReviewedPlayerWriteLeases.swift:904-905 | mp-mine |
| ProfileEditView | 审核中 state | GET api/user/profile/review | Yes GET /api/user/profile/review :756 | Works | Core/ProfileCurrentReview.swift:127 | mp-states |
| ProfileEditView | 绑定/更换手机号 (MP gerenziliao getwxbindphone) | ProfileEditGapPhoneBindRow never mounted; AccountPublishRemainingClient.bindPhone always throws notConfigured | POST /api/getwxbindphone (MP-only WeChat code) | Stub | App/MPGap/AccountPublish/AccountPublishGapRemainingViews.swift:5-24; Core/MPGap/AccountPublish/AccountPublishGapRemaining.swift:53-59; chengyinhub-xcx/pages/gerenziliao/gerenziliao.js:838 | mp-mine |
| SettingsView | 个人资料 card | POST api/user/info multipart {member_id} → ProfileEditView (player/club) | Yes POST /api/user/info (member_id) :531 | Works | App/SettingsView.swift:52-70,150-185 | mp-mine |
| SettingsView | 个人资料 card (merchant-role account) | route.target=.brand → MerchantOperationsDocumentView(.decor) — not gated by merchantCenterEnabled | n/a | Broken | App/ProfileSettingsProfileRoute.swift:30-45,149-153 | mp-mine |
| SettingsView | signed-out row → 登录 | sheet LoginView(.player) | n/a | Works | App/SettingsView.swift:71-77,291 | mp-mine |
| SettingsView | 成为俱乐部主理人 | SettingsClubHostRouter POST api/club/my → apply/create/manage | (club lane) | Unverified | App/SettingsAccountEntries.swift:18-34,58-80 | mp-club |
| SettingsView | 成为商家 | hidden (merchantCenterEnabled) | n/a | Release-off | App/SettingsAccountEntries.swift:35-40 | mp-mine |
| SettingsView | 城瘾玩法 | ProfileGuideHost ← POST api/common/infomation_list / _detail | Yes | Works | App/SettingsView.swift:205-213; Core/ProfileGuideRead.swift:25-26 | mp-mine |
| SettingsView | 我的收藏 | ProfileSettingsFavoritesEntry (same like_list / creativesquare/list) | Yes | Works | App/SettingsView.swift:214; App/ProfileSettingsFavoritesRoute.swift:128 | mp-mine |
| SettingsView | 邀请与收益 | SettingsInvitePromoEntry (bindings.journeyPromo, players only) | (journey lane) | Unverified | App/SettingsView.swift:519-530 | mp-journey |
| SettingsView | 隐私与定位 / 位置共享 | SettingsPrivacyLocationEntry / PersonalLocationShareEntry | (roam lane) | Unverified | App/SettingsView.swift:219-226 | mp-roam |
| SettingsView | AI 对话记录 | NPCChatDataReadSettingsEntry | (play lane) | Unverified | App/SettingsView.swift:227 | mp-mine |
| SettingsView | 营销消息与优惠券 | AccountComplianceMarketingSettingsEntry → POST api/compliance/consents | Yes POST /api/compliance/consents | Works | App/SettingsView.swift:228; Core/AccountComplianceService.swift:228 | mp-mine |
| SettingsView | 帖文处置与申诉 | SettingsPostGovernanceEntry (session.squareGovernance()) | (square lane) | Unverified | App/SettingsPostGovernanceView.swift:11 | mp-home |
| SettingsView | 投诉建议 | ProfileComplaintPreparationLink → WP06ComplaintWrite → POST api/coop/complaint/report JSON; topics/mine | Yes @RequestBody CoopComplaint ApiCoopController.java:1294 | Works | App/ProfileComplaintPreparationView.swift:5-21; App/WP06ComplaintWrite.swift:12-30 | mp-mine |
| SettingsView | 我的申诉 (积分申诉) | MemberScoreAppealSettingsEntry ← GET api/orient/scoring/mine, api/member/reputation; POST api/orient/scoring/appeal | Yes | Works | Core/MemberScoreAppealReadContracts.swift:106-134; Core/MPGap/Member/MemberGapService.swift:136 | mp-mine |
| SettingsView | 我的举报 | SquareReportProgressView | (square lane) | Unverified | App/SettingsView.swift:236-243 | mp-home |
| SettingsView | 发票 | SettingsInvoiceEntry (makeInvoiceLaunchPresentation) | (payment lane) | Unverified | App/SettingsInvoiceEntry.swift:8 | mp-mine |
| SettingsView | 用户服务协议 / 隐私政策 / 关于 | SettingsSupportSections → bundled legal + SettingsAboutView | n/a (bundled, CN text only) | Works | App/SettingsView.swift:245-248; Core/SettingsSourceLegalCatalog.swift:7-8 | mp-mine |
| SettingsView | 账号注销 (phone-bound account) | AccountCompliance: GET api/user/deregister/status, POST precheck, POST api/compliance/consents(AGREE), POST api/sms/send {phone from api/user/info}, POST apply form {requestId, smscode}, POST cancel, GET result | Yes ApiAccountDeregistrationController.java:50-128 (apply: smscode,wxcode,requestId) | Works | Core/MPGap/AccountPublish/AccountPublishGapModels.swift:362-386; App/AccountComplianceViews.swift:82-120; Core/AccountComplianceService.swift:456-460 | mp-mine |
| SettingsView | 账号注销 (Apple-only / no-phone account) | app requires 6-digit smscode (AuthChannelInput.code) and never sends wxcode; no phone → "missing bound phone" error; BE requires SMS if phone else wxcode vs wxOpenId — Apple accounts have neither | BE path exists but unreachable for phone="" & wxOpenId="" | Broken | Core/AccountComplianceService.swift:456; Core/AccountComplianceCoordinator.swift:484-491; ApiAccountDeregistrationController.java:78-83; ApiLoginController.java:868-871 | mp-mine |
| SettingsView | 团队 | SessionTeamHomeView | (club lane) | Unverified | App/SettingsView.swift:252-258 | mp-club |
| SettingsView | 客服工单 | SupportTicketReadEntry → POST api/support/tickets/list {cursor}, /detail {ticket_no,cursor} | Yes @RequestBody Map ApiAppGapsSupportController.java:24-37 | Works | Core/SupportTicketReadContracts.swift:100-115 | mp-mine |
| SettingsView | 创作者 rows | AccountRoleSections(gatesCreatorByCapability) (merchant section hidden) | (publish lane) | Unverified | App/SettingsView.swift:262; App/AccountView.swift:395-400 | mp-publish |
| SettingsView | 通知权限 | NativeNotificationPermissionEntry → UNUserNotificationCenter auth only; app never calls registerForRemoteNotifications, no device-token route | No APNs token endpoint on BE | Stub | App/NativeNotificationPermissionEntry.swift:5-11 (no registerForRemoteNotifications anywhere in App/) | mp-mine |
| SettingsView | 频道通知 / 送达记录 / 角标 | NativeChannelNotificationSettingsEntry → POST api/im/mute, api/im/read; GET api/im/device/attempts | Yes | Works | App/NativeChannelNotificationHostEntry.swift:4-21; Core/NativeChannelNotificationService.swift:145-146 | mp-mine |
| SettingsView | 地区 (read-only) | storefrontMarket ?? operationalMarket | n/a | Works | App/SettingsView.swift:276-278 | en-layout |
| SettingsView | 语言 picker | @AppStorage AppLanguage | n/a | Works | App/SettingsView.swift:279-287 | en-layout |
| SettingsView | 安全 / 声音 | SettingsSupportSafetyEntry / SettingsSoundPreferencesView (local) | n/a | Works | App/SettingsView.swift:288; :444 | mp-mine |
| SettingsView | 商家工具 | hidden (merchantCenterEnabled && role merchant) | n/a | Release-off | App/SettingsView.swift:297-304 | mp-mine |
| SettingsView | search | SettingsSearchResults (local index) | n/a | Works | App/SettingsView.swift:404-490 | mp-mine |
| SettingsView | 退出登录 | SettingsSignOutEntry → confirmation → logout(matching:) → POST api/logout then clear vault | Yes POST /api/logout ApiLoginController.java:181 | Works | App/SettingsAccountEntries.swift:100-115; App/AppSession.swift:7611-7653; Core/AuthService.swift:100 | mp-mine |
| Participants (常用联系人/address) | list / add / edit / delete | ProfileParticipantRoute: POST api/user/address/list, info{id}, action multipart{fullName,mobilePhone,isDefault,requestId}, delete{id} | Yes form params ApiUmsMemberController.java:796-830 | Works | Core/ProfileParticipantTransport.swift:7-55; Core/PlayerContentMPContract.swift:191-198 | mp-mine |
| Participants | +1 phone / setDefault | BE requires ^1[3-9]\d{9}$ and areaCode "+86"; app create forces isDefault=0, no setDefault route | BE rejects US numbers | Broken | ApiUmsMemberController.java:843-858; Core/ProfileParticipantTransport.swift:52 | backend |
| Merchant gate | PlayerLaunch.merchantCenterEnabled Release value | false unless DEBUG/TEST; Release config defines neither | n/a | Works | Core/PlayerLaunch.swift:10-14; Questify.xcodeproj/project.pbxproj:53503,53631,65959 (DEBUG only) | mp-nav |
| Merchant gate | deep links / universal links / push to merchant pages | PlayerLaunch.gate(intent) → home | n/a | Works | App/AppSession.swift:7212; Core/PlayerLaunch.swift:62-65 | mp-nav |


## Cross-tab: registration, payment, refund, orders, tickets, check-in

_Area totals: SCREENS=18 CONTROLS=44 BROKEN=16 RELEASEOFF=4_


AREA=money. App = chein-app @ ui/combined-r7, BE = hengyin @ us/r3-functional. Money gates as built for Release: `ReleaseMoneyWriteSwitch.paymentEnabled` / `refundEnabled` are ON for any installed host, production included (App/ReviewedAreaSwitch.swift:3-6,78-90,107-110; App/RegionalLaunchConfiguration.swift:21). `virtualGoods` is always OFF (App/ReviewedAreaSwitch.swift:87). `/api/registration/pay[/app]` is `forcedOff` as "virtual-goods" but `opens()` re-admits it because the payment kind is on (Core/ChinaReviewedRouteCapability.swift:69,796,2741). So the pay requests leave the device in Release. The defects below come after that gate.

| Screen | Control | App path → endpoint | Backend on us/r3-functional? | Status | Evidence (file:line) | Owning lane |
|---|---|---|---|---|---|---|
| RegistrationSheetView (baoming) | 确认报名 (free ticket) | RegistrationUIFlow.confirm → RegistrationCoordinator.confirm → POST /api/registration/create JSON, no payChannel | Yes, @RequestBody RegistrationRequest | Works | Core/RegistrationCoordinator.swift:259-264; App/ReviewedPlayerWriteLeases.swift:70-72; chengyinhub-admin/.../api/ApiRegistrationController.java:140 | mp-activity |
| RegistrationSheetView (baoming) | 付款 / 确认价格并付款 (paid ticket) | confirmRegistration → flow.confirmAndReadBack → coordinator.confirm returns `.blocked(.paymentRequired)` when payAmount≠0, so no create is sent. The transport lease also rejects any create body that has payChannel or a positive amount. Copy: "当前只开放免费报名" | Yes (create supports payChannel APP/ALIPAY) | Broken | Core/RegistrationCoordinator.swift:256,263; App/RegistrationSheetView.swift:537-541,601; App/ReviewedPlayerWriteLeases.swift:432-440; chengyinhub-system/.../RegistrationCheckoutServiceImpl.java:381-388 | mp-activity |
| RegistrationSheetView | 价格明细 (quote) | POST /api/registration/quote JSON | Yes | Works | Core/RegistrationProduction.swift:19; ApiRegistrationController.java:104 | mp-activity |
| RegistrationSheetView | 检查支付服务 (payment readiness) | RegistrationPaymentReadinessSection → POST /api/registration/payment-readiness | Yes | Works | App/RegistrationPaymentReadinessSection.swift:3,50; Core/PayoutReceiverClient.swift:560; ApiRegistrationController.java:127 | mp-activity |
| RegistrationSheetView (retained pending order) | 立即支付 | RegistrationPaySection(channel: .standard) → POST /api/registration/pay `id` (MP JSAPI, no jsCode). `payParams` are decoded but only counted under `#if DEBUG`. They never reach `WeChatSDKPaymentAdapter` | Yes (:183, JSAPI unless jsCode/app) | Broken | App/RegistrationSheetView.swift:140-149; App/RegistrationPaySection.swift:170-188,269-284; Core/RegistrationPayFlow.swift:8,69,116-133 | mp-activity |
| RegistrationSheetView (result order section) | 立即支付 | Same as above, `channel: .standard` | Yes | Broken | App/RegistrationSheetView.swift:1284-1294 | mp-activity |
| OrderLifecycleView detail (我的-订单) | 立即支付 (pending order) | RegistrationPaySection(channel: .standard) → /api/registration/pay. Same dead end: JSAPI params, no SDK handoff | Yes | Broken | App/OrderLifecycleView.swift:165-175 | mp-mine |
| OrderLifecycleView detail | Pinned primary CTA "审核支付" (OrderLifecycleAction.payment → /api/registration/pay/app + adapter) | canDispatch is false: the production config has `externalCheckoutApproved:false, devicePaymentApproved:false, approvals:[]`. Confirm ends in `.dispatchDisabled` | Yes (:253) | Release-off | App/OrderLifecycleView.swift:145-160; App/ReviewedPlayerWriteLeases.swift:1433-1438; Core/OrderLifecycleProduction.swift:217-221; Core/OrderLifecycleCoordinator.swift:8,264,320 | mp-mine |
| (all CN pay) | WeChat app SDK handoff | `WeChatSDKPaymentAdapter.pay` is only wired to topic self-play and order-lifecycle (both Release-off). `runtimeDependencies.weChatPaymentConfiguration` is never supplied in production, so `isConfigured` is false. `QF_HAS_WECHAT_PAYMENT` needs `QUESTIFY_WECHAT_PAYMENT_SDK_APPROVED=1` and `<WechatOpenSDK/WXApi.h>`. Neither is defined or vendored (Vendor/ has only GLTFKit2; no pbxproj or xcconfig hit) | n/a (BE /pay/app returns matching keys appId/partnerId/prepayId/packageValue/nonceStr/timeStamp/sign) | Broken | App/AppSession.swift:4367-4378,4404-4406,5398-5404; App/ReviewedPlayerWriteLeases.swift:1460-1475; App/QFWeChatPaymentBridge.m:4-13,28; Core/WeChatSDKPaymentAdapter.swift:22-27,61-65; chengyinhub-system/.../WechatPaymentSdkGateway.java:734-741 | backend |
| (all CN pay) | Alipay app pay | No app caller for /api/pay/alipay/order or /query. Alipay code exists only for login (AlipayAppAuth). The quote/order `APP_ALIPAY` channel is ignored | Yes: /api/pay/alipay/order, /query, /notify | Broken | Core/AlipayAppAuth.swift:150-151 (only alipay use); chengyinhub-admin/.../api/ApiAlipayPayController.java:48,54,60; RegistrationCheckoutServiceImpl.java:96-98,149 | mp-activity |
| RegistrationStripePayRows (US) | Apple Pay button: create intent | POST /api/pay/stripe/intent, JSON body `{registrationId, orderNo, bizType}`, Content-Type application/json (the lease requires JSON) | Endpoint exists, but `intent(String id)` binds the **form/query param `id`**, not JSON. id=null gives "Invalid order" | Broken | Core/StripePayContracts.swift:87-93,208-224; App/StripePayBridge.swift:69-77; chengyinhub-admin/.../api/ApiStripePayController.java:48-50,103-106 | backend |
| RegistrationStripePayRows (US) | Apple Pay confirm (PassKit token) | POST /api/pay/stripe/applepay JSON `{registrationId, paymentIntentId, pkToken, pkTokenBase64, pkTokenInstrumentName, pkTokenPaymentNetwork, pkTokenTransactionId}` | BE expects form params `id, tokenId, paymentData, transactionIdentifier, paymentNetwork, paymentMethodDisplayName`. No name or encoding matches | Broken | Core/StripePayContracts.swift:100-133; App/RegistrationStripePaySection.swift:136-143; ApiStripePayController.java:54-62 | backend |
| RegistrationStripePayRows (US) | 使用银行卡支付 (Stripe Checkout in SFSafari) | createIntent then POST /api/pay/stripe/checkout JSON | BE `checkout(String id)` is form-param, so the call fails. The intent response also has no checkoutUrl | Broken | App/RegistrationStripePaySection.swift:159-174; ApiStripePayController.java:65-67; chengyinhub-system/.../stripe/StripePaymentService.java:379-387 | backend |
| RegistrationStripePayRows (US) | Apple Pay sheet amount | StripeIntent.decode reads `amount` as **major** units unless amountMinor/amountCents is present | BE sends `amount = frozen.amountMinor` (cents). The sheet would show 100x the price | Broken | Core/StripePayContracts.swift:166-175; ApplePayStripeAuthorizer.swift:41-51; StripePaymentService.java:141,384 | backend |
| PaymentProviderReturnSheet (US) | Result poll after Apple Pay / Checkout | makeReturnFlow → OrderPaymentVerifier → POST /api/registration/info | Yes | Works | App/StripePayBridge.swift:38-43; App/RegistrationStripePaySection.swift:65-81,176-179 | mp-activity |
| RegistrationPaySection (CN) | Pay result state | After /pay, an empty payParams shows "支付成功，票已放入票夹" without reading /api/registration/info. With payParams it shows "订单已创建，请完成支付" and offers no action. No status poll. MP uses utils/checkout/registration-payment-verifier.js (polls /api/registration/info) | n/a | Broken | App/RegistrationPaySection.swift:269-285; chengyinhub-xcx/utils/checkout/registration-payment-verifier.js:17; chengyinhub-xcx/pages/activity/baoming/baoming.js:1569-1590 | mp-states |
| RegistrationPaySection | Region selection CN vs US | The Stripe branch needs `storefrontMarket == .unitedStates` (user's remembered market). BE decides USD per **topic** (isUsd ownerType/ownerId). A CN-market user on a USD topic falls into China "立即支付" → /pay, which BE rejects with 409 "USD orders are paid with Apple Pay or card". A US-market user on a CNY topic gets the dead WeChat path | Yes | Broken | App/StripePayBridge.swift:18-20; App/RegionalLaunchConfiguration.swift:235-240; App/RegistrationPaySection.swift:166,210-213; RegistrationCheckoutServiceImpl.java:161-168,237-238 | backend |
| RegistrationStripePayRows (US) | Readiness preflight | Stripe preflight requires payment-readiness.ready | BE readiness = `wechatPayService.isReady()` only. A US order is blocked whenever WeChat JSAPI is not ready, and passes even when Stripe is down | Broken | App/RegistrationStripePaySection.swift:118-122; RegistrationCheckoutServiceImpl.java:171-174 | backend |
| (backend) | Stripe webhook | provider → POST /api/pay/stripe/webhook (Stripe-Signature) | Yes, @Anonymous | Works | ApiStripePayController.java:71-84 | backend |
| (backend) | WeChat pay / refund notify | provider → POST /api/registration/callback, /refund-callback (+ecommerce-*) | Yes. `wx.pay.notify-url` defaults empty (must be env-injected or prepay is refused) | Works | ApiRegistrationController.java:620,643,655,664,673; chengyinhub-admin/src/main/resources/application.yml:240,244 | backend |
| (backend) | WeChat APP trade_type readiness | /api/registration/pay/app needs `wx.pay.app-appid`. Not set in application.yml (only the MP appid wxdf8f…). Without it `isAppReady()` is false and APP is never listed | Config only | Unverified | chengyinhub-common/.../config/WxPayConfig.java:59-60; WechatPaymentSdkGateway.java:174-176; application.yml:228-240 | backend |
| (backend) | Alipay notify | provider → POST /api/pay/alipay/notify (RSA2) | Yes, @Anonymous | Works | ApiAlipayPayController.java:60-72 | backend |
| (config) | Apple Pay merchant id | `merchant.com.chengyinhub.chengyinApp` in StripePayWire and the entitlement | n/a | Works | Core/StripePayContracts.swift:33-34; Config/Questify.entitlements (com.apple.developer.in-app-payments) | backend |
| OrderLifecycleView / ProfileSelfOrdersSection | Order list | POST /api/registration/list form owner_type/status/pageNum/pageSize | Yes | Works | Core/ProfileService.swift:48-60; Core/OwnedOrderRead.swift:49-65; ApiRegistrationController.java:476-482 | mp-mine |
| OrderLifecycleView detail | Order detail read (+currency/paymentChannels) | POST /api/registration/info `id` | Yes (attachPaymentFacts) | Works | Core/OrderLifecycleService.swift:22; Core/OrderLifecycleContracts.swift:38-46; chengyinhub-admin/.../registration/RegistrationQueryApplication.java:218,240 | mp-mine |
| OrderLifecycleView detail | 取消订单 (unpaid) | review → dispatcher → POST /api/registration/cancel multipart `id` (allowsReviewedCancellationAndRefund:true) | Yes | Works | Core/OrderLifecycleCoordinator.swift:9; Core/OrderLifecycleDormantAdapter.swift:9-13; App/ReviewedPlayerWriteLeases.swift:1438; ApiRegistrationController.java:310 | mp-mine |
| OrderLifecycleView detail | 取消并退款 (paid) | POST /api/registration/cancel-refund `id`, refund switch on | Yes | Works | Core/OrderLifecycleCoordinator.swift:10; Core/OrderLifecycleProduction.swift:222; ApiRegistrationController.java:345 | mp-mine |
| TicketWalletView (票夹) | Wallet list / focus / pending-order route | POST /api/registration/list | Yes | Works | App/SessionTicketWalletHost.swift:27-35; Core/TicketWalletService.swift:17 | mp-mine |
| TicketPassSheet / OrderPassPreviewView | 入场码 QR | POST /api/verify/dyncode/issue form `registrationId` (MP sends the same, no seatNo) | Yes | Works | App/ReviewedPlayerWriteLeases.swift:91-95,1276-1287; Core/OrderLifecycleDormantAdapter.swift:37-40; chengyinhub-admin/.../api/ApiVerifyController.java:44-46; chengyinhub-xcx/subpackageMember/signup/index.js:381 | mp-mine |
| SessionRoamCouponWalletView | Coupon list / QR / status poll | /api/coupon/myrecvlist, /qr-token `couponHistoryId`, /status `couponHistoryId` | Yes | Works | Core/OrderLifecycleDormantAdapter.swift:41-43; chengyinhub-admin/.../api/ApiCouponController.java:418,517,565 | mp-mine |
| RegistrationSheetView | Promotion / coupon at checkout | G6PromotionCatalogSection is read-only. The quote applies discounts. MP baoming has no coupon block either | Yes | Works | App/RegistrationSheetView.swift:157-166 | mp-activity |
| FreeExploreBundleLaunchView | Reserve merchant slot (bundle) | POST /api/free-explore/bundle/reservation JSON | Yes | Works | App/FreeExploreBundleLaunchModel.swift:133; chengyinhub-admin/.../api/ApiFreeExploreBundleController.java:65 | mp-activity |
| BundleCancelView | Cancel reservation (quote → confirm) | GET reservation/{id}/cancel-quote → POST reservation/{id}/cancel | Yes | Works | App/BundleCancelCanceler.swift:20-40; ApiFreeExploreBundleController.java:86,97 | mp-activity |
| Bundle refund screen | 申请退款 | POST /api/free-explore/bundle/order/refund JSON | Mapped, but always throws `moneyWriteDisabled` | Missing backend | App/BundleRefundTransport.swift:62-86; chengyinhub-admin/.../api/ApiFreeExploreBundleExtrasController.java:77-78 | backend |
| Bundle transfer screen | 转赠 / claim / revoke | POST /api/free-explore/bundle/transfer[...] | Mapped, but always refuses | Missing backend | App/BundleTransferTransport.swift:18; ApiFreeExploreBundleExtrasController.java:92-93 | backend |
| PassDetailView (通行证) | 购买 pass / product | `.buyable` shows price facts plus "mp.gate.purchase". `payPassOrder` / `payProductOrder` have no app caller | Yes (/platform-pass/orders/{no}/pay, /marketing/product/orders/{no}/pay) | Release-off | App/PassMarketViews.swift:814-832; Core/PlatformPass.swift:263-282,367-371 | mp-mine |
| PassGiftClaimView | 领取 gift | POST /api/marketing/product/gifts/claim {token, requestId} | Yes | Works | Core/PlatformPass.swift:253-260; chengyinhub-admin/.../api/ApiMarketingProductController.java:110 | mp-mine |
| Workshop commerce | Buy mod (StoreKit) | `workshopCommerceApproval` is never set and `enableApprovedStoreKit = virtualGoodsEnabled` (false) | Yes (/workshop/v2/purchase/*, apple-iap/*) | Release-off | App/AppSession.swift:1742,1751-1753; App/WorkshopCommerceComposition.swift:13-14 | mp-publish |
| WorkshopPurchasedLibraryView | Paid install targets / submit / status / history | POST /api/workshop/v2/purchased/install/{targets,submit(JSON),status,history} | Yes | Works | Core/WorkshopPaidInstallService.swift:128-133; chengyinhub-admin/.../api/ApiWorkshopController.java:80-93 | mp-publish |
| HostTipPlayerScreen | 打赏主持 (prepare) | POST /api/host-tip/prepare JSON. A `payable` result always shows `.paymentClosed` (both branches of the ternary), and there is no pay step | prepare exists. No pay route (BE returns 501 when the channel is off) | Stub | App/HostTipViews.swift:283-300; Core/HostTipSource.swift:107-117,139-149; chengyinhub-admin/.../api/ApiHostTipController.java:57 | mp-club |
| Topic self-play checkout | Pay self-play ticket (/pay/app + WeChat SDK) | Gated by `selfPlayExternalCheckoutApproved && selfPlayPayment` (both default false, never set in prod) | Yes | Release-off | App/AppSession.swift:4381-4407; Core/BusinessRuntimeConfiguration.swift:73; App/ReviewedPlayerWriteLeases.swift:1453-1456 | mp-activity |
| RewardPledgeViews | Fulfilment redeem / preview / resolve | /api/reward-pledge/fulfilment/* | Yes (awards/ and review/ children are POLICY_CLOSED) | Unverified | Core/ChinaReviewedRouteCapability.swift:1665-1681; chengyinhub-admin/.../api/ApiRewardPledgeController.java:132-154 | mp-club |
| PlayStoreDay (in-play) | 扫码签到 (check-in at node) | POST /api/play/checkin form nodeId, code (+scope) | Yes | Works | Core/PlayStoreDayService.swift:56,142; chengyinhub-admin/.../api/ApiPlayController checkin(activityId, code, …, nodeId …) | mp-journey |
| Roam stamp capture | 盖章 | POST /api/roam/stamp/create | Yes | Unverified | be_endpoints.tsv (/api/roam/stamp/create); body owned by the roam lane | mp-roam |


## Ranked fix list

### P0: money, identity, or a core action dead in Release

| # | Defect | Evidence | Lane |
|---|---|---|---|
| P0-1 | **A paid registration cannot be created.** `confirm` blocks any non-zero quote with `.paymentRequired`, and the create is hard-coded to `usesAppPaymentChannel:false`. The production lease also rejects `payChannel` and any positive amount. Every paid ticket shows "当前只开放免费报名". | Core/RegistrationCoordinator.swift:256,263; App/ReviewedPlayerWriteLeases.swift:70-72,432-440; App/RegistrationSheetView.swift:601 | mp-activity |
| P0-2 | **WeChat Pay (CN) is a dead end.** This is the known defect, at 3 call sites. Pay uses `channel: .standard`, which is MP JSAPI `POST /api/registration/pay` with no jsCode, instead of `/pay/app`. `payParams` are only counted under `#if DEBUG` and never reach `WeChatSDKPaymentAdapter`. Switching the channel alone is not enough: the WechatOpenSDK is not linked (`QUESTIFY_WECHAT_PAYMENT_SDK_APPROVED` is undefined), `weChatPaymentConfiguration` is never injected, and the order flow has `devicePaymentApproved:false`. | App/RegistrationSheetView.swift:147,1292; App/OrderLifecycleView.swift:172; App/RegistrationPaySection.swift:269-285; App/QFWeChatPaymentBridge.m:4-13; App/ReviewedPlayerWriteLeases.swift:1437,1460 | mp-activity |
| P0-3 | **Stripe cards and Apple Pay (US) don't match the backend's wire format.** The app POSTs a JSON body `{registrationId,orderNo,bizType}`, but `ApiStripePayController.intent/applepay/checkout(String id, …)` binds form/query params with no `@RequestBody`. So `id` is null and every call returns "Invalid order". The Apple Pay token fields (`pkToken*`) also differ from `tokenId/paymentData/transactionIdentifier/paymentNetwork/paymentMethodDisplayName`. The backend `amount` is in cents but the app treats it as dollars, so the sheet would show 100× the price. | Core/StripePayContracts.swift:87-93,174,208-224; chengyinhub-admin/…/ApiStripePayController.java:48-67; StripePaymentService.java:141,384 | mp-activity + backend |
| P0-4 | **Alipay app pay (CN) is not implemented.** The backend serves `/api/pay/alipay/order|query|notify` and the `APP_ALIPAY` channel. The app has no caller; Alipay code exists only for login, and that login has no backend either (P1-16). | ApiAlipayPayController.java:48-60; RegistrationCheckoutServiceImpl.java:96-98; Core/AlipayAppAuth.swift:150 | mp-activity |
| P0-5 | **WeChat login is absent in Release.** `WeChatAppAuthGate()` has every flag false, `weChatSDKConfiguration = nil` and no exchange service, so the row never renders. Info.plist has no `CFBundleURLTypes` or `LSApplicationQueriesSchemes`, and the entitlements have no associated-domains, so the callback could never return either. The backend route `/api/login/wechat/app` exists. MP users with no bound phone get a new empty account when they sign in by phone. | App/AppSession.swift:3412-3428; Core/WeChatAppAuth.swift:13-22,114; Config/Info.plist; Config/Questify.entitlements; ApiLoginController.java:589-620 | mp-mine |
| P0-6 | **Accounts created with Sign in with Apple cannot be deleted** (App Store guideline 5.1.1(v)). The backend creates them with `phone=""` and `wxOpenId=""`. Deregister then needs an SMS code or a `wxcode`. The app always demands an SMS code, never sends `wxcode`, and its phone-binding screen is a stub that is never shown. | ApiLoginController.java:868-871; ApiAccountDeregistrationController.java:78-83; Core/AccountComplianceService.swift:456; Core/AccountComplianceCoordinator.swift:484-491; Core/MPGap/AccountPublish/AccountPublishGapRemaining.swift:53-59 | mp-mine + backend |
| P0-7 | **发布 → 互动 (template authoring) cannot publish.** `templateAuthoringOriginalRead/SubmitApproval` keep their default `{ _ in nil }`, so there is no request service and `canSubmit` is false. `api/template/draft` and `api/template/publish` are never sent, and the user sees 暂时无法发布. The same dead path sits behind 使用此玩法模板. | App/AppCompositionRoot.swift:317; App/AppSession.swift:4723-4731,4780; Core/TemplateAuthoringService.swift:15-26 | mp-publish |
| P0-8 | **Team writes are dead.** This covers join by invite code, leave, disband, kick and join-mode. `makeTeamCoordinator()` always wraps `TeamReadOnlyService`, whose submit returns `.notSent`. The `/api/team/*` backend routes exist and their fields match. | App/AppSession.swift:5330-5363; Core/TeamService.swift:47,86; Core/TeamCoordinator.swift:118,296; App/TeamHomeView.swift:410-414 | mp-roam |

### P1: a visible feature is broken or doesn't match the backend

| # | Defect | Evidence | Lane |
|---|---|---|---|
| P1-1 | **No share link or deep link can reach the app.** Shares point to `https://www.chengyinhub.com/pages/...`. There is no associated-domains entitlement, `verifiedHTTPSOrigins: []`, no `CFBundleURLTypes` (so `chein://` is dead), and no AASA or `/pages/*` on the backend. `replayDeepLink` and `HomeLanding` are reachable only from local notifications. Needs owner values (FP-B3/FP-O3). | Core/PublicContentShareLink.swift:20-27; App/AppSession.swift:7092 | mp-nav + backend |
| P1-2 | **The CN pay result is not confirmed by the server.** With no payParams the app shows "支付成功，票已放入票夹" without reading `/api/registration/info`, and it never polls. The MP polls (registration-payment-verifier.js). | App/RegistrationPaySection.swift:269-285 | mp-activity |
| P1-3 | **Pay region routing is wrong.** The Stripe-or-WeChat choice keys off the remembered storefront market, but the backend decides USD per topic. A CN user on a USD topic gets 409. | App/StripePayBridge.swift:18-20; RegistrationCheckoutServiceImpl.java:161-168,237 | mp-activity |
| P1-4 | **The order detail's pinned primary button is a dead "审核支付".** It always ends in `.dispatchDisabled` and pushes the working cancel button out of the pinned slot. | Core/OrderLifecycleProduction.swift:220; Core/OrderLifecycleCoordinator.swift:320; App/OrderLifecycleView.swift:145-160 | mp-activity |
| P1-5 | **The backend APP trade type is likely unconfigured.** `wx.pay.app-appid` is missing from application.yml; needs a deploy check. | WxPayConfig.java:59; WechatPaymentSdkGateway.java:175 | backend |
| P1-6 | **Bundle refund and transfer screens ship, but the backend refuses every write.** | ApiFreeExploreBundleExtrasController.java:77-78,92-93; App/BundleRefundTransport.swift:62 | backend |
| P1-7 | **Reporting an activity or a user always fails.** `targetType` ACTIVITY/MEMBER falls through to a post lookup and returns 404 (App Store guideline 1.2). | Core/UGCContentSafetyService.swift:220-239; CommunityPostServiceImpl.java:962-979 | backend |
| P1-8 | **写评价 on topic and activity detail is a stub.** `contextualReviewApproval` is never set, so the composer says "评价提交暂不可用". The backend `POST /api/comment/add` is live and the MP submits reviews. | App/ReviewedPlayerWriteLeases.swift:1460-1475; Core/ContextualOperationProduction.swift:174-179 | mp-activity |
| P1-9 | **There is no remote push at all.** The app never calls `registerForRemoteNotifications`, the backend has no device-token route and no APNs sender, and `aps-environment=development`. | Core/DevicePushRegistrationLifecycle.swift:3-5; ApiChannelNotifyController.java:99-105; Config/Questify.entitlements | backend + mp-states |
| P1-10 | **Club 置顶/取消置顶 fails, then locks the post.** `api/club/post/pin` is not in `clubCommunityPaths`, so the outcome is recorded as unknown and the dormant reconcile can never clear it. | App/ReviewedPlayerWriteLeases.swift:623-627; Core/ClubCommunityService.swift:470-480; App/ClubCommunityViews.swift:807 | mp-club |
| P1-11 | **Club 移除成员 is never sent.** `api/club/remove-member` is in no App allow-list. | Core/ClubManagementContracts.swift:34; App/MPFirstClubApprovals.swift:90-117 | mp-club |
| P1-12 | **Club owner reads are refused by the composition firewall.** Affected: 统计概览 `api/stats/club`; 结算 `settlement/summary` (any path containing "settlement" is rejected); CRM `customers/list`; `event-ops/series/list`; `event-notification/audience-counts`. | App/ClubStatsOverviewView.swift:71; App/ClubDetailView.swift:203-208; App/MPFirstClubApprovals.swift:146 | mp-club |
| P1-13 | **Club posts can't carry images.** `clubPostImageUploadApproval` is never built, so the picker is hidden; the MP uploads via uploadOSS. | App/AppCompositionRoot.swift:383; App/ClubPostImagePicker.swift:113-116 | mp-club |
| P1-14 | **A merchant page leaks in Release.** In Settings, the account card for a merchant-role account opens `MerchantOperationsDocumentView(.decor)` without checking `merchantCenterEnabled`. | App/ProfileSettingsProfileRoute.swift:30-45,149-153 | mp-mine |
| P1-15 | **"填写邀请人" is a dead control.** The sheet has `enabled:false` and the service `bindingEnabled:false`, so `/api/user/setInviter` is never sent. | App/NativeEntryLandingView.swift:15; App/AppSessionDoorEntry.swift:27 | mp-mine |
| P1-16 | **Every SMS and login error collapses to one generic message.** The backend sends `errorCode` SMS_RATE_LIMITED, SMS_DAILY_LIMIT or SMS_INTL_NOT_CONFIGURED, but the app maps only 429. Alipay login (`api/login/alipay*`) also has no backend; that row is hidden. | Core/AuthChannelService.swift:64-84; Core/AuthChannelCoordinator.swift:172,180; Core/AlipayAppAuth.swift:150-151 | mp-mine (+ backend for Alipay) |
| P1-17 | **The 漫游 home never uses the device location.** The area comes only from the picker or typed coordinates, so a first run shows "area required". The MP calls `wx.getLocation`. | App/QuestifyApp.swift:858; App/RoamAreaPicker.swift:3-13 | mp-roam |
| P1-18 | **Nearby presence is off.** `presence:false` means the `/api/roam/presence` heartbeat is never sent, the toggle is hidden, the nearby list is empty, and iOS players are invisible to MP players. | App/ReviewedPlayerWriteLeases.swift:1172; App/RoamLiveSessionView.swift:238,339 | mp-roam |
| P1-19 | **扫海报码 is a stub behind a button shown on every place detail.** | App/SessionRoamMediaViews.swift:36; App/AppSession.swift:4523-4527; App/RoamItemDetailView.swift:283 | mp-roam |
| P1-20 | **The coupon wallet opened from roam can't show a coupon code** (`couponCodeFactory` is nil). | App/SessionRoamCouponWalletView.swift:35 | mp-roam |
| P1-21 | **External-map 导航 is absent.** No production maps factory exists. | App/AppSession.swift:657; App/PlatformConsumerSessionOwner.swift:3-4 | mp-roam |
| P1-22 | **City board and 领地 entries are visible but open "not open in this build".** `QUESTIFY_CITY_GAME_REGION` is empty in Release. The `api/city-game/*` routes do exist on the backend. | Config/Base.xcconfig:35-37; App/ReviewedCityGameLease.swift:128-142 | mp-roam |
| P1-23 | **Several roam readers are never configured:** the roam browser 活动 layer, received stamps, album metadata, tile memory and session facts. | App/AppCompositionRoot.swift:472-476,537-551 | mp-roam |
| P1-24 | **Personal location share is off, but its entries show in Settings and on public profiles.** | App/AppSession.swift:1033; App/SettingsView.swift:234 | mp-roam |
| P1-25 | **The US market has no live roam, roam writes or nearby teams.** 走起 still shows and opens "not available for this account". | Core/RoamLiveContracts.swift:13; App/ReviewedPlayerWriteLeases.swift:1159-1168 | mp-roam |
| P1-26 | **发布-tab 用这个模板 copies the template on the server, then opens a blank page.** `topicEditorDestination` is not injected under `PublishTabRootView`. | App/DiscoveryTemplateDetailView.swift:931-937; App/PlatformConsumerSessionOwner.swift:100 | mp-publish |
| P1-27 | **Topic-editor media is dead:** story image, story audio, node photo and the owned-cover author sheet. Their approvals are nil outside fixtures. Cover and gallery do work. | App/AppCompositionRoot.swift:455-463; App/AppSession.swift:3877-3960 | mp-publish |
| P1-28 | **IM image send is off** (no `.imUpload` route, `imImageSelection` false), but the row still shows. The MP supports it. | App/ReviewedPlayerWriteLeases.swift:1439-1457; App/AppSession.swift:6458-6463 | mp-publish |
| P1-29 | **The 我的项目 → 模板 tab has no reader** (`templateShelfReadApproval` is nil). | App/AppCompositionRoot.swift:532; App/AppSession.swift:4681-4691 | mp-publish |

### P2: parity, state and copy gaps

- **P2-1 (mp-activity):** payment readiness checks only WeChat, even for US orders. Host tip is a stub: a payable prepare always shows "payment closed". Pass purchase, Workshop StoreKit and topic self-play pay are gated off, but their price UI still shows (App/PassMarketViews.swift:814-832).
- **P2-2 (mp-home):** the topic-template share sends a bare path string (Core/PublicContentShareLink.swift:31-33). Activity share is an image with no link back. Topic 屏蔽作者 blocks locally only, with no memberID (App/TopicDetailView.swift:101-110).
- **P2-3 (mp-home):** the city consent card records consent but never locates the city. The city rail asks for location on 首页 load with no tap. Map search opens without the known area. 关联玩法模板 rows can't be tapped.
- **P2-4 (mp-club):** the create-club name check is never admitted, so it always returns `.unchecked`. Like is a bare toggle and is not idempotent. `post/operation/comment/*` has no backend mapping (dormant). Club-lead start/settle/edit-ops are not allow-listed; mp-journey should verify.
- **P2-5 (mp-mine):** the 私人主页 row always shows "disabled". The Apple full name is dropped, so every new Apple user is "城瘾用户". Participants reject +1 numbers (backend regex `^1[3-9]\d{9}$`). Legal text is zh-only for the US. There is no bind-phone counterpart to MP `getwxbindphone`.
- **P2-6 (mp-publish):** `api/topic/publish-status` and `edit-requests/*` are still filtered as "not served", but r3 serves them (Core/TestHostOnlyRouteAdmission.swift:11-24). Signed-out "+" is a dead end with no login prompt. The content-draft browser always shows "not configured". 互动 skips MP template-intro. IM 发起会话 asks for a raw member ID.
- **P2-7 (mp-roam):** POI 点亮 never posts `/api/roam/checkin`. A guest who taps 走起 gets no sign-in CTA. The location authorization status is not re-read after the user returns from Settings. The city NavigationLink titles are hard-coded zh. The coupon-wallet guard can show the raw key `roamEvent.unavailable`.

### What works end to end (method and fields match us/r3-functional)

- **首页:** home rails, stream, refresh and paging; search and map search; banners; topic favorite, report, transfer and graduate; follow; block by member ID; template detail read, report and use.
- **Money:** registration cancel and cancel-refund; order list and detail; ticket wallet and entry QR (`dyncode/issue`, same as the MP); coupon wallet; check-in; paid workshop installs; the Apple Pay merchant ID matches the entitlement.
- **Payment callbacks:** WeChat (`/api/registration/callback`, `/refund-callback`), Alipay (`/api/pay/alipay/notify`) and Stripe (`/api/pay/stripe/webhook`) all exist on the backend.
- **俱乐部:** join, apply, leave; the clubJoin deep link (once links can arrive); share; feed, like, repost and comments; post create, edit, delete and report (text only); join-request approve and reject; role assign and revoke; topics; club chat.
- **Sign-in:** phone SMS sign-in for +86 and +1, Sign in with Apple, logout, and account deletion for phone-bound accounts.
- **我的:** profile edit and avatar upload; nickname check; favorites and likes; invite list; player code; growth; medals; stamp album; support tickets and complaints.
- **发布 + IM:** topic v2 create, update and draft submit; cover and gallery upload. IM text send, report, block, mute and read; friends; the notification list and mark-read.
- **Token refresh:** neither side has one; a 401 signs the user out, which is consistent on both sides.


## Appendix: MP request sites with no Swift contract (check_mp_contract_coverage, 52)

Most are merchant pages, which are out of scope. The ones in scope are: publish server-draft (5), roam session records and reveal, team invite QR, wx-phone-bind, orient-score (6), club-post-repost, community-post-api (2), roam-passport-read, roam-share-snapshot, play/theme/state, member market membership and pass-order, and the app.js bootstrap (4).

```
app.js:374
app.js:395
app.js:421
app.js:447
pages/club/components/cy/fe-reference-range/index.js:34
pages/gerenziliao/gerenziliao.js:837
pages/merchant/aftercare/detail/index.js:105
pages/merchant/aftercare/detail/index.js:285
pages/merchant/aftercare/index.js:112
pages/merchant/components/cy/fe-reference-range/index.js:34
pages/merchant/index/index.js:1337
pages/merchant/ledger/index.js:348
pages/merchant/reviews/index.js:314
pages/merchant/reviews/index.js:323
pages/merchant/reviews/reply-recovery.js:67
pages/merchant/reviews/reply-recovery.js:76
pages/merchant/utils/voice-enrollment-journal.js:18
pages/merchant/utils/voice-enrollment-journal.js:20
pages/merchant/utils/voice-enrollment-journal.js:76
pages/merchant/utils/voice-enrollment-journal.js:100
pages/publish/utils/publish/publish-workflow.js:44
pages/publish/utils/publish/server-draft.js:477
pages/publish/utils/publish/server-draft.js:491
pages/publish/utils/publish/server-draft.js:535
pages/publish/utils/publish/server-draft.js:559
pages/publish/utils/publish/server-draft.js:574
pages/publishkit/components/topic-state-keys/index.js:307
pages/roam/index.js:1801
pages/roam/index.js:1830
pages/team/utils/team-invite-qr.js:26
pages/topic/utils/voice-enrollment-journal.js:18
pages/topic/utils/voice-enrollment-journal.js:20
pages/topic/utils/voice-enrollment-journal.js:76
pages/topic/utils/voice-enrollment-journal.js:100
pages/topic/utils/wx-phone-bind.js:27
subpackageA/components/scene-member-invite-history/index.js:61
subpackageMember/components/cy/profile/index.js:734
subpackageMember/components/scene-member-participation-detail/index.js:149
subpackageMember/market/membership/index.js:17
subpackageMember/market/pass-order/index.js:13
subpackageMember/orient-score/index.js:91
subpackageMember/orient-score/index.js:117
subpackageMember/orient-score/index.js:155
subpackageMember/orient-score/index.js:205
subpackageMember/orient-score/index.js:240
subpackageMember/orient-score/index.js:313
utils/club-post-repost.js:92
utils/community-post-api.js:84
utils/community-post-api.js:297
utils/roam-passport-read.js:55
utils/roam-share-snapshot.js:22
utils/theme-records.js:132
```
