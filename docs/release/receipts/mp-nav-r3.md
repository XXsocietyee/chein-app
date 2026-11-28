# mp-nav r3 — navigation, app-style (receipt)

Brief: `origin/design/handoff-r2:docs/briefs/round3-1127.md` (OWNER RULE + OWNER RULE 2). MP source: `origin/mp-source:chengyinhub-xcx`.
Branch `mp/r3-nav` from `origin/ui/combined-r7`. Not compiled (no Swift toolchain here); every member used already exists in the repo.

One native pattern: tab roots = `NavigationStack` + large top-left title (`cyRootHeader` / `.large`); pushed pages = inline title;
MP popups / half-screens = `.sheet` with detents; full-screen only for camera, game and map play (and photo/pass viewers).

## Pattern fixes

| # | where | before | after |
|---|---|---|---|
| P1 | App/HomeFeedView.swift (首页 root) | inline transparent bar over the banner, logo leading, list bled under the status bar (mp-home r3) | large top-left 首页 (`appNavigationTitle("homeFeed.title")` + `.large`); banner → greeting → … stay in MP order under it (OWNER RULE 2 correction of the 13:34 note) |
| P2 | App/NativeR2/MapHome/RoamMapHomeSheet.swift (漫游 root panel) | inline 漫游 | `cyRootHeader(.roam)` large title like the other four roots; peek height 120 → 172 pt (RoamMapHomeModel.swift) so title + search fit |
| P3 | App/PublishingManagementViews.swift:107 (我的项目, pushed) | `.large` on a pushed page | `.inline` |
| P5 | App/SessionMessagingEntry.swift:73 (消息 bell on every tab root) | push kept the tab bar, while 我的 → 消息 hid it | `.cyPushedChrome()` like every other L2 push |
| P6 | App/DiscoveryTemplateBrowserView.swift:112/137/145 (发布 root: 搜索, 发布 +, inbox) | pushes without the shared pushed chrome | `.cyPushedChrome()` |
| P7 | App/WelcomeView.swift (我的 root, signed out) | inline bar, no title | `cyRootHeader(.mine)` large 我的 (launch welcome keeps its untitled inline bar) |
| P8 | App/SquareBrowserView.swift:118 (动态, sheet/pushed page) | `.large` | `.inline` |
| P4 | 48 pushed / sheet titles in 37 files (IM location/route/map/voice, channel views, friend home/directory, blacklist, webhook logs, template authoring/sample/config, play task/tools/advanced, journey questions, city finish summary, discovery topic preview, enrollment …) | no display mode → inherited the large title when pushed from a tab root | explicit `.navigationBarTitleDisplayMode(.inline)` |

Audited, unchanged (allowed by the rule): hidden nav bar only in live roam / free-explore map / finish report (game & map play) and the story walking author (story-flow, out of scope); full-screen covers only for cameras/scanners, live roam, city board, game finish/cast, ticket pass presentation and photo viewers.

## MP edge → native control

| MP edge (from → to) | MP control | native control | status |
|---|---|---|---|
| pages/index/index → pages/activity/list/index (banner 和朋友报名活动, `openHomeActionBanner` navigateTo) | 首页 hero banner `activity_list` (+ ⋯ menu 官方活动) | was `.cySheet` + 关闭 → now `navigationDestination(isPresented:)` push, inline 官方活动 (App/SessionHomeFeedView.swift) | fixed |
| pages/index/index → pages/club/apply/index (banner 成为俱乐部, navigateTo) | 首页 hero banner `club_apply` | was sheet + 关闭 → push of `MPReviewedPageScreen("pages/club/apply/index")` | fixed |
| pages/index/index → pages/merchant/apply/index (banner 成为商家) | banner `merchant_apply` | merchant, out of scope (hidden in Release) | n/a |
| pages/roam/index → pages/searchmap/index (navigateTo) | 首页 toolbar map button / hero map (same search page) | was sheet + 关闭 → push of `SessionLinkedSearchView(startsOnMap:)` | fixed |
| pages/index/index → pages/topic/index/index (goTopic / goRecoHero, navigateTo) | feed / 编辑精选 cards → `router.pushHome(.topic)` | push, inline | OK |
| pages/index/index → play-activity-detail (goActivity → openScene) | 附近活动 / 即将上线 / 活动 cards → `router.pushHome(.activity)` | push | OK |
| pages/index/index → pages/member/index/index (goUser, switchTab) | hero avatar | switches to the 我的 tab | OK |
| pages/roam/index → subpackageRoam/nearby/index (navigateTo) | 漫游 panel 组队地图 | was a sheet stacked over the map panel → `model.push(.nearbyTeams)` inside the panel stack (RoamMapHomeSheet.swift) | fixed |
| pages/roam/index → subpackageRoam/my-teams/index (navigateTo) | 漫游 panel 我的队伍 | was a sheet → `model.push(.myTeams)` | fixed |
| pages/roam/index → nearby team page | place card 查看队伍 / card team rows | was a sheet → `model.push(.team(id))` (RoamMapHomePlaceCard.swift); matches MP roam entry-sheet `entrySheetView=='team'` with 返回 (wxml:19) | fixed |
| pages/roam/index → pages/activity/official-detail, pages/topic/index/index | 漫游 panel event / place cards | `model.push(.event)` in panel | OK |
| pages/roam/index → subpackageRoam/official-routes/index | 官方路线 | `model.push(.officialRoutes)` | OK |
| pages/roam/index → subpackageRoam/history, citystamp, badge-wall, stamp-camera, tools/* | 漫游护照与工具 | MP has no hub: each is its own navigateTo page. Native groups them in one 漫游护照与工具 sheet (presentedAsSheet, pushes inside); stamp camera full-screen. Kept (owner Q9 map home); flagged for the coordinator | open |
| pages/talent/list/index → pages/club/detail/index (navigateTo) | 俱乐部 row → `navigationDestination(item:)` + hero | push | OK |
| pages/talent/list/index → subpackageB/pages/im/list/index | toolbar 消息 bell | push (now with pushed chrome, P5) | fixed |
| pages/talent/list/index → subpackageMember/market/passes/index | 帖文 tab 通行证 card → `NavigationLink` | push | OK |
| pages/template/index → pages/search2/index (goSearch, navigateTo) | 发布 root 搜索全部 | push (pushed chrome added, P6) | fixed |
| pages/template/index → subpackageB/pages/im/list/index (tpl-bell) | 发布 root bell | push | OK |
| profile (pages/member/index) → subpackageMember/market/passes/index (票夹, navigateTo) | 我的 票夹 → pass sheet → 打开票夹 | wallet was a second sheet → `navigationDestination` push, `isPushed: true`, no close (AccountView.swift) | fixed |
| profile → pages/shezhi/shezhi (navigateTo) | 我的 top-right 设置 | push since 23:xx (`SettingsView(isPushed: true)`, guide hand-off on pop) | fixed |
| profile → subpackageMember/points-history, assetcenter/earnings (钱包), stamp-album, badge-wall, im/list | 我的 rows | `navigationDestination(isPresented:)` pushes with pushed chrome | OK |
| profile → points help (MP popup) | 积分 ⓘ | `.cySheet` with `[.medium, .large]` detents | OK |
| pages/topic/index/index → subpackageMember/signup/index (票, navigateTo) | topic bottom bar 我的票 | was `.cySheet` half/full → `navigationDestination(isPresented: $showingTickets)` push, wallet host `isPushed: true` (no close), pushed chrome; the bar hero modifier is a pass-through since native r2, so nothing depended on the sheet | fixed |
| pages/topic/index/index → pages/topic/pricing/index (navigateTo) | topic bar 定价 (owner) | was a sheet with its own NavigationStack → push of `PublisherPricingView` with pushed chrome; its post-confirm `dismiss()` now pops back like MP index.js:451 `navigateBack` | fixed |
| pages/topic/index/index → pages/play/index (navigateTo) | topic bar 开始 | `navigationDestination(isPresented: $showingPlay)` push | OK |
| pages/topic/index/index → session picker / self-play form (MP popups) | topic bar 选择场次 / 自己玩 | sheets with `[.half, .full]` detents | OK |
| pages/club/detail/index → member list (MP `expandMembers`, in-page) | 查看成员 | sheet `[.medium, .large]` | OK |
| pages/club/detail/index → settings panel (MP cset popup, wxml:663-797) | toolbar gear | sheet `[.medium, .large]`; rows push the MP pages (customers / enroll / event-ops / roles / settlement) | OK |
| pages/roam/index → pages/userinfo/userinfo, subpackageB/pages/im/chat (runnerOpenProfile / runnerSayHi, navigateTo) | 漫游工具 runner row → RoamRunnerDetailView 看 TA 的漫游 / 打个招呼 | `NavigationLink` + `navigationDestination(item:)` pushes (RoamRunnerDetailView.swift) | OK (re-scan 11-27 pm) |
| pages/topic/index/index → subpackageRoam/my-teams (openTeamLobby), pages/club/detail + pages/userinfo (onLineupTap), subpackageMember/market/pass (onCheckoutPass) | 组队 card, lineup rows, self-play checkout pass rows | `NavigationLink` pushes (TopicTeamsCard.swift:37, TopicXcxSections.swift:584, MPPassEntries.swift:111 inside the checkout sheet stack) | OK |
| pages/topic/index/index → pages/publish/fabu (owner 编辑, navigateTo) | topic bar 编辑 (owner, productType 2) | full-detent sheet with its own stack: an editor with discard state, kept modal like every native editor (OWNER RULE 2 popups vs pages); flagged, not changed | done (B lane: push + system back, test_mp_nav_topic_editor_push.py) |
| pages/activity/official-detail → pages/roam/index (goRoam, switchTab + globalData eventId) | 去漫游完成 / 去点亮 | `RoamOfficialEventHandoff.hand(eventID:missionCode:)` then `rootTabSwitch(.roam)` (OfficialOrganizerConsoleView.swift:589/629) | OK |
| pages/activity/list → official-mine / official-inbox (goMine / goInbox, navigateTo) | 我发布的 / 邀约 (top-right, no WeChat capsule) | `NavigationLink` pushes (OfficialEventsBrowserView.swift:82/86) | OK |
| pages/club/detail → badges / notify / governance / coop list / customer-detail / club topic-detail / userinfo (navigateTo) | club page rows and settings rows | `NavigationLink` / `navigationDestination` pushes (ClubDetailView.swift:197-474); 成员 stays a sheet (MP in-page expand) | OK |
| pages/play/index → subpackageP3/pages/badge-3d (openBadge3d) | — | MP `openBadge3d` is bound in no `.wxml` (dead in MP), so the unrouted badge-3d page below is correct | n/a |

## External entries → MP page (deep links, universal links, notifications, widgets, Siri)

MP: a page opened from outside (share card, subscribe message, scan) launches as the first page with a home button back to
`pages/index/index`; a tabBar page opens with `switchTab`. Native intake: `onOpenURL` / `onContinueUserActivity` /
`UNUserNotificationCenterDelegate` tap / island tap / App Intents → `AppSession.receiveNativeIntent` → `NativeEntryPresentation`.

| entry | before | after (mp-nav r3) | status |
|---|---|---|---|
| `chein://mp/<page>`, verified universal link, notification `page` payload, foreground island tap, widget / Live Activity `chein://mp/…` URLs, Siri 继续故事 / 打开城市护照 — any page with a native player screen (`MPParityRoute`) | root `.sheet` over the tabs with a 关闭 button | `HomeLanding.page`: entry dismissed, 首页 selected, page pushed as the only page above the 首页 root with pushed chrome; system back returns to 首页 = MP home button (App/QuestifyApp.swift `landNativeEntryOnHome`, App/SessionHomeFeedView.swift `openHomeLanding`) | fixed |
| public topic universal link (`.content(.topic)`, MP `pages/topic/index/index`) | sheet + 关闭 | pushed `.topic(id)` on 首页 (same detail + hero fallback as a feed tap) | fixed |
| tabBar pages `pages/index/index`, `pages/roam/index`, `pages/template/index`, `pages/talent/list/index`, `pages/member/index/index` (Siri 开始漫游, widget 俱乐部 link) | a second copy of the tab root inside the sheet (own NavigationStack; 首页 only had a hand-off) | `HomeLanding.tab`: selects the tab, pushes nothing (MP `switchTab`, app.json tabBar list) | fixed |
| `chein://ticket/<id>`, `chein://club/<id>`, `chein://roam/go`, referral / gift / seat | already resolved on the owning tab (`replayDeepLink`) | unchanged | OK |
| merchant pages, team / merchant invitations, door, badge showroom, unsupported route error | entry sheet | unchanged: invitation / door are MP landing flows with their own sign-in step; merchant out of scope (keeps its discard confirmation); errors keep 返回首页 | OK |
| link arrives while consent gate or a tab-level sheet (设置, 合作, 票夹) is open | sheet stacked on top | waits, like chein:// links, until the gate / sheet closes, then lands (`onChange` of `hasBlockingSheet` / `consentActive`) | fixed |
| signed-out launch from a link | sheet over Welcome | `browsingAsGuest = true` (same as the error view's 返回首页), page keeps its own sign-in gate | fixed |
| local play-window reminder (PlayAdvancedView 提醒我, `AppleLocalReminderProvider`) | userInfo had no `page` key, so a tap only opened the app where it was | adds `page = pages/topic/index/index?id=<topicID>` (topic id from the reminder identifier `activityID.topicID.nodeID`); the tap routes through `MPNotificationTapRouter` and lands as the topic pushed on 首页 like a subscribe-message page | fixed |
| `pages/talent/list/index?tab=feed` (帖文 share card, MP index.js:289-290 onLoad) | switched to 俱乐部 but stayed on the 俱乐部 top tab | switches to 俱乐部 and selects the 帖文 top tab via `ClubHomeView.requestedTopTab` (applied once, cleared; QuestifyApp `deepLinkClubTopTab`); `?tab=club` selects 俱乐部 | fixed |
| City local notifications (保护结束提醒 / 保护还剩 1 小时 with 开护盾 action / 今天收租 20:00 / 被拿走; App/CityKit/CityNotifications.swift) | no `page` in userInfo: a tap only opened the app where it was | `page = pages/roam/index` on all four: the tap routes through `MPNotificationTapRouter` → `HomeLanding.tab(.roam)` (MP `switchTab`; the City board is a 漫游 map mode, no MP page of its own) | fixed |

## Exits from landed pages (re-scan 11-27 18:10)

Since links / notifications land as a push on 首页 (`HomeLanding`), a page's "leave" action can no longer rely on `session.dismissNativeEntry()` alone: the entry is already cleared, so those buttons did nothing.

| MP page → exit | MP | before | after (App/MPReviewedPageScreen.swift) | status |
|---|---|---|---|---|
| subpackageRoam/session/index?shareToken → 去漫游 (shared footprint) | session/index.js:593 `goRoam` = `switchTab /pages/roam/index` | only `dismissNativeEntry()`: dead button on the landed push | `leaveForTab(.roam)`: clear entry, pop the page (`dismiss`), select 漫游; button hidden where no tab switch exists | fixed |
| pages/play/circle/index (missing topicId) → 返回首页 | circle/index.js:84 `reLaunch /pages/index/index` | only `dismissNativeEntry()`: dead | `leaveForTab(.home)`: pops back to the 首页 root | fixed |
| pages/square/list/index → toolbar 关闭 | navigateTo page, system back | a 关闭 in `.cancellationAction` that only cleared the (already cleared) entry sheet | no 关闭 (`onClose: nil`, `SessionSquareBrowserView.onClose` is optional now); pushed page keeps system back like every L2 page | fixed |
| pages/square/list/index → 登录 | goes to sign-in | `onSignIn: {}` (dead) | `signIn()` = clear entry + 我的 tab, same as the other landed pages | fixed |
| pages/coop/list/index → 关闭 (link, and the coop subscribe-message tap `.coopList`) | navigateTo page, system back | same dead 关闭 (MPReviewedPageScreen + SubscribeMessageTapScreens.swift:21) | `onClose: nil`: system back on the push; list content unchanged (mp-activity owns it) | fixed |

## IM chat cards → MP pages (re-scan 11-27 hourly)

MP `subpackageB/pages/im/chat/system-card-target.js` + `index.js` `onCardTap` / `_openGenericCard`: a system (senderId 0) generic card or button whose action is `/pages/activity/detail/index?id=`, `/pages/topic/index/index?id=` or `/pages/square/detail/index?id=` navigateTo's that page; a system text notice (`CLUB_CAMPAIGN` / `ACTIVITY_CANCELLED` extraJson) opens `pages/activity/detail/index?id=<activityId>`.

| MP edge | before | after | status |
|---|---|---|---|
| chat system card / button → `pages/activity/detail/index?id=` | `IMCardAction` only read the legacy `/topic/<id>` form, so the MP path was `.unsupported`: the answer was hidden (or a dead 查看详情 with a bcId) | `IMCardDestination.activity` (Core/IMExpandedContracts.swift via `IMSystemCardTarget.openURL`) → `MessagingCardRoute.activity` push of `MPReviewedPageScreen` above the chat (MessagingHistoryView.swift, message detail too) | fixed |
| chat system card → `pages/square/detail/index?id=` | same, hidden | `.squarePost` → pushed square detail | fixed |
| chat system card → `pages/topic/index/index?id=` | same, hidden | `.topic(id)` → pushed topic detail (existing route) | fixed |
| chat activity notice (msgType 1, `activityNoticeUrl`) | plain notice, no way to the activity | one answer 查看活动 / View event (`im.full.viewActivity`) under the notice → pushed activity detail | fixed |
| non-system sender with an MP path | — | stays `.unsupported` (MP opens page paths only for senderId 0) | OK |
| `/subpackageMember/coupon-wallet/index` | recognized, refused (L5 money surface) | unchanged | n/a |
| review result 查看原单 (`onCurrentCard` → `originalUrl`) | review sheet only | was recorded as dead; the MP now binds it (chat index.wxml:133 查看当前原单 → `onCardBtn` mode original). Fixed in the 11-28 04:xx re-scan below | fixed (04:xx) |
| pages/userinfo/userinfo share link `?userId=&tab=about` (onShareTimeline / merchant home) | — | `tab` honoured (`SocialPublicProfileView(initialTab:)`, MPReviewedPageScreen.swift:831); missing id → MPUserInfoMissingView with 返回 | OK |
| system chat 举报进度 entry (`openReportMine` → subpackageMember/report-mine, wxml:25) | — | pushed from the chat (IMDriftEntries.swift:49) | OK |

Test: Tests/CoreTests/IMExpandedTests.swift `testSystemCardMiniProgramPagesOpen`. Page host: `IMExpandedNavigationContext.pageDestination` (SessionIMExpandedContext.swift; channel host passes it through, AppSession.swift).

## Sweep rows (18:06 sweep, mp-nav sheets)

| screenshot | finding | change | status |
|---|---|---|---|
| `login-player` (zh-Hans + en) | the 欢迎回来 card drew the logo twice: `images/d_logo.png` is the same mark at a smaller size, not a wordmark | LoginView.swift `brandMark` shows `cy_logo_mark` once | fixed |
| `onboarding-1` en | header and disc read 城瘾 in the English UI | brand copy belongs to en-layout, see For other lanes | n/a here |
| `d2-inbox`, `ia-tabs`, `welcome` | inline 消息 title on the pushed inbox, tab roots with large titles, welcome inline | — | OK |

## Re-scan 11-27 19:xx (sweep build 1300a48db)

| MP page / edge → native | finding | change | status |
|---|---|---|---|
| subpackageB/pages/im/list/index → App/IMInboxViews.swift (`d2-inbox`, sheet-en / sheet-zh-Hans) | names ("Fixture conversation 3" next to 官方) and the preview line wrapped onto two lines; MP wxss:62-73 keeps both on one line with an ellipsis | `.lineLimit(1)` on the name in the standard row; preview `.lineLimit(1)` (3 at AX sizes, where the row already stacks). Sections / order / swipe actions unchanged | fixed |
| City local notification 稍后 / Later action (App/CityKit/CityNotifications.swift) → `MPNotificationTapRouter` | the background 稍后 action (and a custom dismiss) still routed the `page`, so the next foreground jumped to 漫游 although the player chose "later" | `MPNotificationTapRouter.nonOpeningActions` (laterAction + `UNNotificationDismissActionIdentifier`) skip routing; default tap and 开护盾 still land on 漫游 | fixed |
| `login-player` sweep still shows the logo twice | the fix (b9a93003c) is on `mp/r3-nav` but not yet in `ui/combined-r7` (sweep build 1300a48db) | — waits for the integration merge | OK (pending merge) |

## Re-scan 11-27 20:xx (19:15 sweep row, mp-nav zh)

| MP page / edge → native | finding | change | status |
|---|---|---|---|
| pages/login (MP 微信一键登录 is the WeChat runtime's own; app login) → App/LoginView.swift + App/WeChatAppAuthSection.swift (`login-player` zh-Hans) | a disabled 微信登录 row plus 微信登录暂不可用 / 这项功能还没开通 shown to every CN player while the SDK is not wired (dead control, OWNER RULE 2) | `WeChatAppAuthCoordinator.isOffered` (gate open + SDK adapter + exchange service, Core/WeChatAppAuth.swift); the section renders only when offered (or mid-authorization). Apple / 手机号 entries unchanged. UI test `WeChatAppAuthFlowTests` now asserts the row is absent offline | fixed |
| same screen, `这项功能还没开通` / "This isn't switched on yet." row (LoginView.swift:146) | shown only when `session.isConfigured` is false (no API base URL: design fixtures / unconfigured dev builds); a Release build always has a backend, so players never see it | kept as the dev/fixture notice | OK (verified) |
| subpackageB/pages/im/list/index → `d2-inbox` fixture (App/MessagingFixtureSupport.swift, sheet-zh-Hans) | conversation names read "Fixture conversation N" in the Chinese UI (19:50: fixture data follows the UI language) | names are 示例会话 N / Sample conversation N by UI language | fixed |

## Re-scan 11-27 20:3x (sweep build a250afd77, mp-nav sheets)

| MP page / edge → native | finding | change | status |
|---|---|---|---|
| app.json tabBar roots → `ia-tabs` fixture (App/DesignFixtures/IAFixtures.swift, sheet-zh-Hans / sheet-en tile 2) | tab roots showed a centred 首页 / Home plus the debug line "Synthetic fixture" and no large title, so the sweep did not show the real root chrome | each fixture root uses `cyRootHeader(tab)` (large top-left title, OWNER RULE 2) over an empty scroll view with a tertiary tab symbol; debug copy removed | fixed |
| pages/square/list/index landed from a link / notification (`HomeLanding.page` push on 首页) → App/SquareBrowserView.swift | the page owned `NavigationStack(path: [Int])`: pushed onto 首页's `[AppRoute]` stack it nested a second stack (double bar) and `NavigationLink(value: Int)` post rows had no matching destination in the outer path (dead taps) | `embedsNavigationStack` (default true for the 首页 ⋯ 动态 and 消息 sheets); MPReviewedPageScreen passes false. Post rows are view-destination `NavigationLink`s and governance `openPost` sets `navigationDestination(item:)`, so both work in either host. Sections / order unchanged | fixed |
| pages/coop/list/index (link, `.coopList` subscribe tap, club director 联系商家) → CooperationBrowserView | pushed everywhere but `embedsNavigationStack` defaulted to true: nested stack / double bar | both MPReviewedPageScreen and SubscribeMessageTapScreens pass `embedsNavigationStack: false` | fixed |
| pages/addressinfo/addressinfo → ParticipantFormView | the screen wrapped the pushed form in its own `NavigationStack` | `Group` instead; the form's 取消 / 保存 stay | fixed |
| pages/deregister/index and pages/shezhi/shezhi?scene=settings-deregister → AccountComplianceSheet | pushed page showed a `compliance.close` cancellation button next to system back | `showsCloseButton: false` (like pages/shezhi/marketing) | fixed |
| pages/member/index/index, pages/roam/index reaching MPReviewedPageScreen (tab roots) | rendered a second AccountView / RoamBrowserView with its own stack | `MPTabHandoff` → `rootTabSwitch(.mine / .roam)` like pages/index/index (MP switchTab); hosts without the tab switch keep the old screen | fixed |
| subpackageRoam/poi-detail/index → RoamPOIDetailHost → RoamItemDetailView | own `NavigationStack` + 关闭 on the landed push | `embedsNavigationStack` (default true: the map place sheet keeps its stack and 关闭); RoamPOIDetailHost passes false, so the push has system back only | fixed |
| pages/shezhi/shezhi (plain) → SettingsView | own `NavigationStack` + 完成 on the landed push | done in the 22:xx re-scan below | fixed (22:xx) |
| `login-player`, `d2-inbox` tiles | still show 微信登录 / "Fixture conversation N": sweep build a250afd77 predates 81a815048 / 9723767a1 (not yet in `ui/combined-r7`) | — | OK (pending merge) |

## Re-scan 11-27 21:0x (20:55 sweep row, mp-nav en)

| MP page / edge → native | finding | change | status |
|---|---|---|---|
| pages/login → App/LoginView.swift (`login-player` en, sweep bb76e327c) | dead row "This isn't switched on yet." (`auth.notConfigured`, shown when no API base URL) under the sign-in buttons | row removed (P27: a gated channel renders nothing); the phone page itself still reports the unconfigured error when tapped. `region.usLoginPending` kept: it is the US regional notice, not a dead channel (RegionalEntryFlowTests) | fixed |
| same screen, channel order | Sign in with Apple sat above phone sign-in and demoted the phone button to `.bordered` | phone sign-in first and always the one `.borderedProminent` action (no password form); Apple's `SignInWithAppleButton` under it only when `appleConfigurationVerified` (gated → nothing); WeChat row after, only when offered | fixed |
| backend contract 20:40 `/api/compliance/usage-records` (Core/UsageConsentRead.swift:38) → App/SettingsView.swift 设置 list | the only caller is the app-only 同意记录 / usage-evidence row (`UsageConsentReadSettingsEntry`); MP pages/shezhi/shezhi.wxml:14-35 has no such row and the backend does not serve the path, so the page could only show its error | row removed from 设置 (MP list order unchanged); no screen reaches the path any more. Agreement state stays on `/api/compliance/consents/latest` (registration, deregistration, checkout). Core reader + its unit tests left in place (unreachable) so no pin moves; route-capability entry left for debt-r3/coordinator to retire | fixed |
| subpackageA/pages/infomation/infomation (城瘾玩法, landed from a link) → App/MPReviewedPageScreen.swift → SocialPlayGuideView | mode cards 去看看 (MP switchTab 首页 / 漫游) and 去发布广场 / 更多玩法 (switchTab 发布) only cleared the entry and selected the tab: on the 首页 push the page stayed on the stack, and 去看看 → 首页 did nothing visible | both use `leaveForTab` (clear entry, pop the page, select the tab), like the session-share 去漫游 exit; content unchanged | fixed |

## Re-scan 11-27 21:3x (sweep build 405948d58, mp-nav sheets; 首页 menu edges)

Sweep sheets (en / zh-Hans): inbox inline title, ia-tabs large titles, onboarding and welcome OK; `login-player` still shows "This isn't switched on yet." because 405948d58 predates 062af9e5f/b68bb8279 (pending integration merge). Landed-page audit: every MPReviewedPageScreen view with a `NavigationStack` uses it only inside its own sheets, except SettingsView (Open).

| MP page / edge → native | finding | change | status |
|---|---|---|---|
| 首页 更多玩法 → 动态 = MP pages/square/list/index (navigateTo) → App/SessionHomeFeedView.swift | a `.cySheet` with its own stack and 关闭 | `navigationDestination(isPresented: $showsSquare)` push, `embedsNavigationStack: false`, `onClose: nil` (system back), pushed chrome; 登录 still closes it and opens sign-in | fixed |
| 首页 更多玩法 → 浏览模板 = MP pages/template/index (tabBar page, switchTab) | a second copy of the 发布 tab root inside a sheet | selects the 发布 tab (`rootTabSwitch(.publish)`); the sheet stays only as the fallback for hosts without a tab switch (pin test_home_composition unchanged) | fixed |
| 首页 今日票 → MP subpackageMember/signup/index (票夹, navigateTo) | sheet + 关闭 | push of `SessionTicketWalletHost(isPushed: true)` like 我的 → 票夹 | fixed |
| 首页 小游戏 banner (app-only page, `native/mini-games`) → App/SessionHomeFeedView.swift | the only 首页 banner still opening a sheet + 关闭 (activity list / club apply banners push) | `navigationDestination(isPresented: $showsMiniGames)` push, inline title, system back | fixed |
| 我的 合作 row → CooperationBrowserView sheet (App/AccountView.swift:163) | sheet + 关闭 although MP pages/coop/list is a navigateTo page | merchant-gated (`PlayerLaunch.merchantCenterEnabled`, hidden in Release): merchant out of scope | n/a |
| pages/activity/detail → 票夹 (MP navigateTo subpackageMember/signup) → App/ActivityDetailView.swift:312 | `.cySheet` + 关闭 instead of a push | not changed: the footer pill is the zoom source of this sheet (continuity r1, `tileOpenedSheet`) and test_activity_design_structure pins the trigger; see For other lanes | done (B lane: push of SessionTicketWalletHost, test_mp_nav_activity_wallet_push.py) |
| club detail 成员 / 贡献榜 → ClubPublicRosterView member profile sheet (App/ClubPublicRosterView.swift:76) | MP pages/userinfo is a navigateTo page | both hosts pass `profile: nil` (ClubDetailView.swift:291/334), so the sheet is unreachable; no change | n/a |
| 票夹 empty state + 去探索主题 (MP signup/index.js:701 switchTab 首页) in a pushed wallet → App/SessionTicketWalletHost.swift | on 首页 the tab was already selected, so the pushed wallet stayed open (dead tap) | a pushed host pops (`dismiss`) before selecting 首页, like MP switchTab closing the page | fixed |

## Re-scan 11-27 22:xx (sweep build 405948d58 unchanged; Open rows)

| MP page / edge → native | finding | change | status |
|---|---|---|---|
| pages/shezhi/shezhi (plain link, landed as a push on 首页) → App/SettingsView.swift via App/MPReviewedPageScreen.swift | nested `NavigationStack` (double bar) + 完成 next to system back; the 个人资料 card pushed `ProfileSettingsProfileRoute` by value, which the host's typed `[AppRoute]` path cannot push (dead tap) | `SettingsView(isPushed: true)`: no own stack, no 完成, the 个人资料 card is a view-destination link to the new shared `ProfileSettingsProfileSessionDestination` (App/ProfileSettingsProfileRoute.swift); `profileOwner.retire()` only in the sheet form (pushed, onDisappear also fires when a row pushes on top, and the owner leaves with the page). 我的 → 设置 sheet unchanged. MP shezhi list order unchanged | fixed |

## Re-scan 11-27 22:3x (sweep build 8fa84e4d3; mp-nav sheets clean)

Sweep sheets (en / zh-Hans): `login-player` now one mark, phone sign-in only, no gated row ✓; `onboarding-1` reads Chein in en ✓; `d2-inbox` inline 消息 (pushed) ✓; `ia-tabs` large 首页 ✓; `welcome` ✓. No new coordinator row for mp-nav after 20:55. Siri / Shortcuts (`QuestAppIntents.swift`), Control Center (`QuestControlRouteIntent` handler + parked `takePendingRoute`) all route through `MPNotificationTapRouter` → home landing: OK.

| MP page / edge → native | finding | change | status |
|---|---|---|---|
| subpackageB/pages/im/list `onEmptyCta` (收件箱 empty → feed, `wx.switchTab` talent/list + markDiscoverFeed) → App/MessagingHomeView.swift `messaging.list.emptySquare` | opened 动态 as a `.cySheet` with its own stack and 关闭 (popup for a page edge) | `navigationDestination(isPresented: $showsSquare)` push; session host passes `SessionSquareBrowserView(onClose: nil, embedsNavigationStack: false)` + pushed chrome (App/SessionMessagingEntry.swift:33), like 首页 ⋯ 动态. The native 俱乐部 tab has no 全站帖文 feed segment (ClubHomeView A8-03), so 动态 stays the destination. UI test fixture close still pops | fixed |
| pages/square/detail feed-play-card 试玩 (`goPlay` → navigateTo pages/play/index?activityId= / topicId= by `dataType`) → App/SquareDetailView.swift `SquareDetailPlayCard` | native 试玩 opens the related topic detail (play starts from there), one step more than MP; `SquareRelatedTopicDestination` deliberately injects no play/purchase provider | not changed: going straight to `SessionPlayRuntimeView` needs the session play gating in the square host (needs a compiled run); flagged for mp-activity (square owner) / coordinator | done (B lane: 试玩 pushes play, test_mp_nav_square_try_play.py) |

## Re-scan 11-27 23:xx (sweep build 8fa84e4d3 unchanged; carried Open rows)

Merged `origin/ui/combined-r7` (a2baf94fa). Sweep unchanged since 22:3x, so this run takes the carried Open row.

| MP page / edge → native | finding | change | status |
|---|---|---|---|
| pages/member/index → 设置 (MP profile index.wxml:17 icon_set, navigateTo pages/shezhi/shezhi) → App/AccountView.swift | `.large` sheet with its own stack + 完成 (popup for a page edge, OWNER RULE 2) | `navigationDestination(isPresented: $showsSettings)` push of `SettingsView(…, isPushed: true)` + `.cyPushedChrome()`: no own stack, no 完成, system back; the 城瘾玩法 guide hand-off (`SettingsGuideHandoff`) now finishes on the pop (`onChange(of: showsSettings)` false) instead of the sheet's onDismiss, same begin/request/finish order; Settings no longer marks the 我的 root "sheet open" for replayed links (a push does not cover the tabs). MP shezhi list order unchanged | fixed |
| signed-out 我的 root ⋯ → 设置 (App/WelcomeView.swift:66) | still a sheet (shared `cySheet(item:)` with 登录 / legal) | not changed this run: the welcome page is also the launch screen without a host stack; flagged | done (B lane verified: already a push, WelcomeView.swift:67-68) |

## Re-scan 11-27 23:3x (sweep build b3b03703a; mp-nav sheets clean)

Sweep sheets (en / zh-Hans): `d2-inbox` inline 消息 ✓, `ia-tabs` large 首页 ✓, `login-player` one mark + phone sign-in only ✓, `onboarding-1` reads Chein in en ✓, `welcome` ✓. No coordinator row for mp-nav after 20:55; this run takes the carried Open row.

| MP edge → native view | before | after | status |
|---|---|---|---|
| signed-out 我的 root / launch welcome ⋯ → 设置 (MP navigateTo pages/shezhi/shezhi) → App/WelcomeView.swift | `.cySheet(item:)` case `.settings` with its own stack + 完成 | both welcome modes already own a `NavigationStack` (the 23:xx note was wrong): `navigationDestination(isPresented: $showsSettings)` push of `SettingsView(isPushed: true)` + `.cyPushedChrome()`, system back, like 我的 → 设置; consent re-read on the pop. 登录 / legal stay sheets (MP popups). UI tests EntryFlowTests / NativeSettingsReuseFlowTests leave Settings with the nav-bar back button instead of 完成/Done | fixed |

## Re-scan 11-28 00:xx (sweep build 793c3190b; mp-nav sheets clean)

Merged `origin/ui/combined-r7` (793c3190b). Sweep sheets (en / zh-Hans): `d2-inbox` inline 消息 ✓, `ia-tabs` large 首页 / Home ✓, `login-player` one mark + phone sign-in only ✓, `onboarding-1` Chein in en ✓, `welcome` ✓. No new coordinator row for mp-nav. Next pages without a row: 发布 shelf (pages/templatedetail/shelf openTopic / openGame → topic-preview / templatedetail: `navigationDestination` / `NavigationLink` pushes, OK) and 俱乐部 帖文 feed edges (MP talent/list index.js:229-281).

| MP edge → native view | before | after | status |
|---|---|---|---|
| pages/talent/list 帖文 (and club detail 帖子) 引用卡 → pages/topic/index/index (`onPostReference`, index.js:241-246 navigateTo) → App/ClubPostReferenceView.swift | `.cySheet(item:)` `.large` with its own `NavigationStack` + 关闭 (popup for a page edge, OWNER RULE 2) | `NavigationLink` push of `ClubPostReferenceDestination` (no own stack, no 关闭, `.cyPushedChrome()`, system back); the destination still re-checks the route and pops when the post / identity / scope changed. Row content and MP order unchanged | fixed |
| pages/talent/list 帖文 引用卡 现在去玩 → pages/play/index?topicId= (`onPostReferencePlay`, index.js:248-252 navigateTo) → App/ClubPostPlayPreview.swift | `.cySheet(item:)` `.large` with its own `NavigationStack` + 关闭 around `SessionPlayRuntimeView` | `NavigationLink` push of `ClubPostPlayDestination` (no own stack, no 关闭, `.cyPushedChrome()`), same as topic 开始 (`showingPlay` push); route / identity / revision re-checks still pop it; signed-out 登录 stays a sheet (MP popup) | fixed |
| pages/club/detail 成员 / 贡献榜 row → pages/userinfo/userinfo (`goMemberProfile`, detail index.js:2506 navigateTo) → App/ClubPublicRosterView.swift | `.cySheet(item:)` `.large` with its own `NavigationStack` | `navigationDestination(item:)` push of `SocialPublicProfileView` + `.cyPushedChrome()`; the roster's onDisappear reset is skipped while the profile is pushed (as with the sheet), scene-phase / identity checks still close it | fixed |
| talent/list 帖文 post tap / author / club chip → square detail, club detail (postId), pages/userinfo (onPostTap / onPostUser / onPostClub) | — | `navigationDestination(item:)` pushes in ClubCommunityFeedView (ClubCommunityViews.swift:471-493) | OK |

## Re-scan 11-28 00:4x (sweep build 283dd3b52; mp-nav sheets clean)

Merged `origin/ui/combined-r7` (283dd3b52). Sweep sheets (en / zh-Hans) `d2-inbox`, `ia-tabs`, `login-player`, `onboarding-1`, `welcome`: clean, no new coordinator row for mp-nav. Contract-cleanup row `/api/compliance/usage-records` already fixed (21:0x). Next edge without a row: club detail 帖子 post-card author.

| MP edge → native view | before | after | status |
|---|---|---|---|
| pages/club/detail 帖子 post-card author → pages/userinfo/userinfo (`onPostUser`, detail index.js:2895-2897 navigateTo) → App/ClubPostAuthorProfile.swift | `.cySheet(item:)` `.large` with its own `NavigationStack` + 关闭 around `SocialPublicProfileView` | `NavigationLink` push of `ClubPostAuthorDestination` (no own stack, no 关闭, `.cyPushedChrome()`, system back); destination still re-checks post / identity / profile reader and pops when stale. Author label (avatar + name) unchanged; `club.postAuthor.close` retired | fixed |

## Re-scan 11-28 hourly (merged combined-r7 f8574edab; backend field audit row 00:30)

Merged `origin/ui/combined-r7` (f8574edab), clean. Took the brief's app-side row **[mp-nav] chat-info "mark read"**.

| MP edge → native view | before | after | status |
|---|---|---|---|
| subpackageB/pages/im/chat markRead (index.js:862-866: `POST /api/im/read` `{conversation_id, read_to}`) → chat info 标为已读 (App/IMExpandedViews.swift:370-374) → `IMExpandedService.perform(.readCursor)` (Core/IMExpandedService.swift) | sent `last_message_id` + `ack-<uuid>` request id; server reads only `read_to`, marked the whole chat read, and the app then failed decoding the reply as a channel ACK (`malformedResponse`) | sends `read_to` + a lowercase UUID `request_id` (validated through `OrdinaryIMReadRequest`); decodes `OrdinaryIMReadReceiptWire` (source / conversation / request id / requested_read_to must match; `APPLIED` → read, `PENDING`/`NOT_FOUND` → unknown outcome, retry keeps the same request). Unit test `IMExpandedTests.testChannelReadSendsCursorAndKeepsTheSameRequest` rewritten for the MP wire shape (read_to present, no last_message_id, mismatched cursor rejected, `ack-` / uppercase ids rejected before any request). Not compiled here | fixed |
| pages/square/detail 作者头像 → 查看主页 (`goUserInfo`, index.js:160-165 navigateTo pages/userinfo) and comment author → App/SquareDetailView.swift:215-219, :474 | pushed `SocialPublicProfileView` without the shared pushed chrome, so the tab bar came back on the profile and the page ground/tint were the pushing stack's (the `cloudProfile` push at :199-203 already had it) | `.cyPushedChrome(domain: .player)` on both pushes, same as every other L2 profile push. MP order / content unchanged | fixed |

## Re-scan 11-28 01:xx (merged combined-r7 907570051; sweep 01:20 has no mp-nav row)

Merged `origin/ui/combined-r7` (907570051). No coordinator row for mp-nav after 00:20. Next edges without a row: in-page profile / page pushes that skipped the shared pushed chrome (same defect as the square-detail author fix: a push without `.cyPushedChrome()` above a pushed page brings the tab bar back and uses the pushing stack's ground/tint).

| MP edge → native view | before | after | status |
|---|---|---|---|
| pages/activity/detail 报名的人 → pages/userinfo/userinfo (navigateTo) → App/ActivityDetailView.swift `profileSelection` | pushed `SocialPublicProfileView` without pushed chrome | `.cyPushedChrome(domain: .player)` | fixed |
| pages/activity/detail 我的订单 → subpackageMember order list (navigateTo) → `showsOwnOrders` push | no pushed chrome | `.cyPushedChrome(domain: .player)` (play runtime push unchanged: it owns its own chrome) | fixed |
| pages/club/detail 成员 / 贡献榜 / leaderboard member → pages/userinfo or CRM customer (`goMemberProfile`, navigateTo) → ClubMembersView.swift, ClubDetailR8Mounts.swift (×2), ClubGovernanceViews.swift leaderboard | no pushed chrome on the destination | `.cyPushedChrome()` (domain inherited from the club page) | fixed |
| club enrollment registrant → pages/userinfo / check-in (navigateTo) → ClubEnrollmentView.swift destination owner | no pushed chrome | `.cyPushedChrome()` on the destination | fixed |
| pages/square/list author → pages/userinfo (navigateTo) → SquareBrowserView.swift `profileMember` | no pushed chrome | `.cyPushedChrome(domain: .player)` | fixed |
| 我的 关注 / 粉丝 list row → pages/userinfo (navigateTo) → ProfileFollowListView.swift | no pushed chrome | `.cyPushedChrome()` | fixed |
| 邀请记录 member → pages/userinfo → SocialInviteHistoryView.swift | no pushed chrome | `.cyPushedChrome(domain: .player)` | fixed |
| 好友 directory → profile / 备注 / 删除 / chat child pushes → NativeFriendDirectoryView.swift | no pushed chrome on any child | one `.cyPushedChrome()` around the child switch | fixed |

Sections / order / content unchanged on every page; navigation only. Not compiled here.

## Re-scan 11-28 02:xx (merged combined-r7 a32387e9b; sweep 01:50 has no mp-nav row → "Next round" list)

Sweep sheets (en / zh-Hans) `d2-inbox`, `ia-tabs`, `login-player`, `onboarding-1`, `welcome`: clean. No open coordinator row for mp-nav, so this run takes "Next round" item 1/2 on the sign-in page (P27). The MP has no login page (WeChat popup), so the native first screen keeps its current sections in order: mark + title → consent (when declined) → phone sign-in → Apple (when approved) → WeChat (when offered) → legal footer.

| page → native view | principle | change | fixture (before → after) | status |
|---|---|---|---|---|
| sign-in sheet → App/LoginView.swift | P27 left-aligned title, one brand mark | header was a centred 88 pt mark + centred title/subtitle; now one 56 pt mark and title/subtitle leading-aligned (`VStack(alignment: .leading)`), Dynamic Type `.title` / `.subheadline` unchanged | `login-player` centred card → leading header | fixed (not compiled here) |
| same | motion / feedback | `.sensoryFeedback(.success)` when `session.account?.id` goes nil → non-nil (sign-in completes, just before the sheet dismisses); no animation added, so nothing for Reduce Motion | — | fixed |

## Re-scan 11-28 03:xx (merged combined-r7 41374363f; sweep 02:20 "mp-nav clean" → Next round item 2, motion/feedback)

| page → native view | principle | change | fixture | status |
|---|---|---|---|---|
| 消息 收件箱 / 发件箱 tab row (MP subpackageB/pages/im/list index.wxml:11) → App/MessagingHomeView.swift scope Picker | feedback | `.sensoryFeedback(.selection, trigger: box)` on the segmented control; sections/order unchanged; states already covered by `MessagingReadScreen` (ProgressView loading, MessagingIssueView error / signed-out / unconfigured + retry, `.refreshable`, ContentUnavailableView empty with MP copy) | `d2-inbox`, `d2-inbox-empty` | fixed (not compiled here) |
| launch welcome consent checkbox (MP pages/privacy/index.wxml:10) → App/WelcomeView.swift `consentRow` | feedback | `.sensoryFeedback(.selection)` on a tap counter (`consentTaps`), so only the player's own check / uncheck ticks, not the stored agreement syncing in on appear / scene change | `welcome` | fixed (not compiled here) |
| sign-in sheet → App/LoginView.swift | feedback | `.sensoryFeedback(.warning)` when `session.errorKey` becomes non-nil (failed code / sign-in), next to the existing success tick | `login-player` | fixed (not compiled here) |

## Re-scan 11-28 03:xx (b) (merged combined-r7 ad55acd94; Next round item 3, all states)

Backend audit row **[mp-nav] chat-info mark read** (round 4, 00:30): already in the branch — `IMMutation.readCursor` posts `conversation_id` + `read_to` + a lowercase UUID `request_id` and decodes `OrdinaryIMReadReceiptWire` (Core/IMExpandedService.swift:60-64, 91-95; App/IMExpandedViews.swift:370-374). Verified, no change.

| page → native view | state | change | fixture | status |
|---|---|---|---|---|
| 消息 inbox (MP subpackageB/pages/im/list cy-error) → App/MessagingHomeView.swift via `MessagingReadScreen` | error: 加载失败 + server line + 重试 | new design fixture; the fixture server line follows the UI language (was English "Synthetic service failure" in zh) | `d2-inbox-error` (new) | fixed (not compiled here) |
| same (MP cy-empty no-permission 登录后查看消息) | signed out | new design fixture (lock icon, sign-in hint; 登录 button when the root sign-in is available) | `d2-inbox-signed-out` (new) | fixed (not compiled here) |
| same (MP first load) | loading | new design fixture (`ProgressView` 正在加载…, 15 s fixture delay) | `d2-inbox-loading` (new) | fixed (not compiled here) |
| same | empty | already `d2-inbox-empty` (ContentUnavailableView, MP copy, one action) | — | OK |

Coordinator: please add `d2-inbox-error`, `d2-inbox-signed-out`, `d2-inbox-loading` to the mp-nav sweep list.

## Re-scan 11-28 04:xx (combined-r7 ad55acd94 already merged; sweep 03:04 mp-nav sheets clean)

No open coordinator row for mp-nav. Notification / subscribe-message landings re-checked (City + play reminder carry `page`; subscribe pages land through `MPParityDestination` with pushed chrome): OK. Next edge without a correct row: IM review-result card.

| MP edge → native view | before | after | status |
|---|---|---|---|
| subpackageB/pages/im/chat review-result card 查看当前原单 (index.wxml:133 → `onCardBtn` mode original → `_openCardOriginal` → `originalUrl`, system-card-target.js:15-25: `result.bizType` COMMUNITY_POST → pages/square/detail, TOPIC → pages/topic/index/index, `?id=<bizId>`, card `action` must match) → App chat bubble + message detail via `IMCardAction` | only 查看处理结果 (the generation-time record sheet); no way to the reviewed post / topic | `IMSystemCardTarget.reviewOriginal` (Core/IMChatCardReport.swift) + a second action `im.full.currentOriginal` 查看当前原单 / "View the current original" (Core/IMExpandedContracts.swift) → existing `.squarePost` / `.topic` pushes in MessagingHistoryView `answerCard` and MessagingMessageDetailView. System sender only; other bizTypes and a mismatched `action` add nothing. Unit test `IMExpandedTests.testReviewResultCardOpensCurrentOriginal`. Not compiled here | fixed |

## Route coverage

All 136 non-merchant MP pages in `app.json` resolve natively (MPReviewedPageScreen cases or `MPParityDestination`), except four pages that are parsed (`Core/MiniProgramPageLink.swift`) but have no native screen case: `pages/playkit/index/index`, `pages/publishkit/index/index` (MP kit galleries), `pages/crop/index` (MP image-crop utility) and `subpackageP3/pages/badge-3d/index` (MP 3D badge viewer). No native player control links to them; left for the coordinator to confirm they stay unrouted.

## Pins updated

- Tests/ContractChecks/test_account_collection_structure.py:113 — splits AccountView at `.navigationDestination(isPresented:$showsSettings)` (设置 is a push, not `.cySheet`).

- Tests/ContractChecks/test_i03_notification_blacklist_closeout.py:53 — expects the guarded `if !isPushed { profileOwner.retire() }` (sheet still retires; a pushed Settings leaves the owner with the popped page).
- Tests/ContractChecks/test_ticket_wallet_play_entry.py:19 — looks for the wallet `navigationDestination` line instead of the old `.cySheet` (wallet is now a push).

## Coordinator sweep rows (16:37 / 16:53)

| row | finding | status |
|---|---|---|
| `d2-city` "City tab root has no large top-left title, only a refresh button" | CityPlayerView is not a tab root: it is pushed from 漫游 ⋯ 更多 → 城市 (RoamBrowserView.swift:282 with `.cyPushedChrome()`) and from the 城市大富翁 ⋯ menu (RoamTerritoryView.swift:39). Per OWNER RULE 2 a pushed page keeps its inline title (`city.read.title`, CityPlayerView.swift:177-178); the d2-city fixture hosts it in a bare NavigationStack, so the screenshot shows no back button. The five tab roots all carry the large title (P1, P2, P7 above). Hero text on the gradient is ds-consistency's half | n/a (verified, no change) |

## Open (carried)

- 我的 → 设置 and signed-out Welcome ⋯ 设置 are both pushes now (23:xx / 23:3x).
- 漫游护照与工具 hub sheet (owner Q9) and topic 编辑 editor sheet — kept, see the edge table.

## For other lanes

- mp-home / motion: activity detail → 票夹 (ActivityDetailView.swift:312) is still a sheet with 关闭; MP navigateTo = push (OWNER RULE 2). The footer-pill zoom can stay on a push (`navigationTransition(.zoom)`), so the owner of continuity r1 should convert it.

- mp-states / coordinator: the 消息 inbox preview is always "打开会话查看消息" (`MessagingPreview`, App/MessagingComponents.swift:300; `MessagingConversation` drops `lastMsgText` because recalled text may survive in it). MP `fmtPreview` shows the last message text / [图片] / [系统卡片]. Showing it needs a recall-safe server field first; left as is (privacy decision).

- en-layout: `onboarding-1` (en) header and centre disc show 城瘾; LoginView `brandMark` and SettingsAboutView `appName` use `Text(verbatim: "城瘾")` (en should read Chein).

## Re-scan 11-28 05:xx (merged combined-r7 733bfb368; sweep 03:49 mp-nav sheets clean, no coordinator row)

Next edge without a row: sign-in from club pages landed by a share card / link (MP `pages/club/detail/index?id=&postId=` share path, club/detail index.js:3502; talent/list index.js:590).

| MP edge → native view | before | after | status |
|---|---|---|---|
| landed `pages/club/detail/index` (share card, link, notification) → 申请加入 / members / activity sign-in prompts → App/MPReviewedPageScreen.swift:891 `ClubDetailView` | `onSignIn: {}`: the signed-out 登录 action did nothing (same dead-button defect fixed for Square at 18:10) | `onSignIn: { signIn() }` = clear entry + 我的 tab sign-in, like every other landed page | fixed (not compiled here) |
| landed `pages/talent/list/index` → App/MPReviewedPageScreen.swift:87 `ClubHomeView`; owned-club fallback (`ownedClubs`, :909 `ClubOwnedView`) | same `onSignIn: {}` | same `{ signIn() }` | fixed (not compiled here) |

Sections / order unchanged; navigation only.

## OWNER REQUIREMENT 11-28 04:30 — sign-in methods (merged combined-r7 at 06:xx)

| item | native file | before | after | status |
|---|---|---|---|---|
| 1. P27 order + US market | App/LoginView.swift `loginForm`, App/AuthChannelView.swift `PhoneSignInForm` | first screen: 手机号登录 (US: "More ways to sign in"), then Apple, then WeChat; US showed `region.usLoginPending` on both the first screen and the phone page (no phone field) | phone first in both markets (`auth.channels.phoneTitle`), then WeChat (CN, SDK-gated), then Sign in with Apple (both markets, gated by `appleConfigurationVerified`). `region.usLoginPending` removed from both views; the phone page is shown for any configured market (`AppSession.supportsPhoneSignInInput`, in LoginView.swift so AppSession does not grow). Country menu already defaults from the market (`PhoneCountryCode.launchDefault`) | fixed (not compiled here) |
| 4. +1 formatting | App/AuthChannelView.swift `onChange(of: phone)` → `PhoneCountryCode.fieldText` | already groups `(555) 123-4567`; E.164 wire via `AuthChannelInput.phone` | verified, no change | n/a |
| 2. Alipay adapter | Core/AlipayAppAuth.swift (`AlipayAppAuthGate`, `AlipaySDKConfiguration`, `AlipaySDKAuthDriving`, `AlipayAuthAdapter`, `AlipayAppAuthService`, `AlipayAppAuthCoordinator`); App/AlipayAppAuthSection.swift; LoginView third-party row after WeChat | not present | backend-signed `authInfo` (`GET api/login/alipay/auth-info`) → SDK driver behind a protocol (`<scheme>://safepay` URL callback, `resultStatus` 9000 + `result_code=200` → `auth_code`, 6001 = cancelled) → `POST api/login/alipay` `auth_code` → `/api/userInfo` id check → shared `commitChannelLogin`. Gate defaults off and no driver/service is wired (no SDK binary), so the row renders nothing (P27). zh/en `auth.alipay.*` strings. Unit test Tests/CoreTests/AlipayAppAuthTests.swift (stub driver + stub transport: gated default, result parsing, callback scheme, full sign-in, cancel). Not compiled here. Remaining wiring (owner Alipay app + SDK): driver, `AlipaySDKConfiguration(appScheme:)`, gate, and `onOpenURL` → `adapter.acceptsURL` | fixed (gated) |
| 2b. Alipay wiring | App/AppSession.swift | — | dropped: owner correction 11-28 04:45 (no Alipay login) | dropped (11-28 07:xx) |
| 3. MP-account sync note | WeChat login result | not present | needs the backend to say the account came from the mini-program (no such field in `api/login/wechat/app` today); next run checks the backend receipt for the field name | Not done (blocked on backend field) |

Pins: Tests/ContractChecks/test_pkg19_login_deletion_chain.py:58-59 (phone page follows any configured market, owner 04:30); Tests/AppUITests/RegionalEntryFlowTests.swift US cases now expect the +1 phone field instead of the pending row. Note: a US *build* still has no approved host (`ReviewedMarketLaunch.approvedBaseURLs`), so there the phone page shows the existing `auth.notConfigured` line until a host is approved (coordinator/backend).

Pins (Alipay commit): Tests/ContractChecks/test_remaining_native_clients.py:46 splits at `func commitChannelLogin(` (now internal so the Alipay channel shares the WeChat commit; `weChatContext` also internal).
Pins (07:xx): Tests/ContractChecks/test_wechat_app_auth.py:38 — LoginView host now reads `channelCoordinator` (returns `session.authChannels`; DEBUG fixture may inject an Apple-approved coordinator).

## Re-scan 11-28 06:xx — US phone gating (after the parallel 04:30 commits above)

A parallel run of this lane showed the US phone page for any configured market (`supportsPhoneSignInInput`), but the US had no `AuthChannelService` (built for the CN capability only), so the page ended on the dead `auth.notConfigured` row (20:55 sweep finding, P27). Order phone → WeChat → Alipay → Apple kept; Alipay adapter = the one above (my duplicate dropped).

| item | before | after | status |
|---|---|---|---|
| 1b. US +1 phone, gated | US phone page always shown, no service behind it | `RegionalConfiguration.implementedCapabilities` US = `[.internationalPhone]` + `canUseInternationalPhone` / `canUsePhoneSignIn`; `authChannelService` built for `canUsePhoneSignIn` (App/AppSession.swift); `AppSession.supportsPhoneSignIn` (App/AppSession+PhoneSignIn.swift) = CN, or US once the deployment verifies `.internationalPhone`; LoginView `phoneEntrySection` renders the phone row only then; AuthChannelView keeps only a status footer when phone is hidden. Unit test `RegionalConfigurationTests.testUSPhoneNeedsVerificationAndBackend` | fixed (not compiled here) |

Pins: test_pkg19_login_deletion_chain (`canUsePhoneSignIn` / `supportsPhoneSignIn`), test_regional_storage_boundaries, test_cn_native_login_contract (US implements `.internationalPhone`), RegionalConfigurationTests + USAppleServiceTests (US all-verified set = `[.internationalPhone]`), RegionalEntryFlowTests (UI-test deployment verifies nothing → US sheet shows no pending notice and no phone row).

## Re-scan 11-28 07:xx — OWNER CORRECTION 04:45 + sweep 04:50 (merged combined-r7 at ab0e4727d)

| item | native file | before | after | status |
|---|---|---|---|---|
| Drop Alipay login (owner 04:45: Alipay is payment only) | Core/AlipayAppAuth.swift, App/AlipayAppAuthSection.swift, Tests/CoreTests/AlipayAppAuthTests.swift, App/LoginView.swift; `auth.alipay.*` strings | gated Alipay row after WeChat | files and strings removed; Alipay *payment* belongs to mp-activity | fixed |
| `login-player` (EN, sweep 13a6690eb) shows only "Phone sign-in" | App/LoginView.swift `loginForm` | order phone → WeChat → Apple; fixture used a bare `AppSession()` with no reviewed composition, so `appleSignInApproved` was false and Apple's button never rendered | order Sign in with Apple → WeChat (CN) → phone (+86 / +1 picker on the phone page). Release CN with production gates already approves Apple (`AppCompositionRoot.appleSignInApproved`); the `login-player` fixture now passes an Apple-approved `AuthChannelCoordinator` through `LoginView.DesignOverride.authChannels` (App/DesignFixtures/OnboardingFixtures.swift) so the sweep shows the shipped channel set | fixed (not compiled here) |
| WeChat "shown only when WeChat is installed" | Core/WeChatAppAuth.swift (`WeChatAppAuthorizing.isAppAvailable`, default true), Core/WeChatSDKAuthAdapter.swift (`driver.isInstalledAndSupported`) | `isOffered` = gate + adapter + service: a CN phone without WeChat saw a button that ended in `.unavailable` | `isOffered` also needs `adapter.isAppAvailable`. Unit test `WeChatSDKAuthAdapterTests.testWeChatOfferedOnlyWhenInstalled` | fixed |
| Equal-width 50 pt buttons | App/WeChatAppAuthSection.swift | WeChat was a plain inset list row with the status rows inside the same card | full-width `.bordered` `.controlSize(.large)` button on a clear row (same width/height as Apple's 50 pt `SignInWithAppleButton` and the `.borderedProminent` phone button); working / cancel / error moved to the section footer; the static "not configured" row is gone (button disabled instead, P27) | fixed (not compiled here) |

Still open: 3. MP-account sync note (backend field) — blocked. US Apple sign-in waits for a reviewed US host (`appleSignInApproved` is CN-only while the US build has no approved base URL).

## Re-scan 11-28 08:xx — universal-link paths for MP share cards (merged combined-r7 7a7d2708a)

Merged `origin/ui/combined-r7` (xcstrings: theirs, no mp-nav-only keys). Sweep a4142df0d mp-nav sheets (en / zh-Hans): inbox, ia-tabs, login-player, onboarding-1, welcome read correctly; login-player still shows phone only because that build predates the 07:xx Apple-fixture fix. No new coordinator row for mp-nav; item 3 (MP-account sync note) still blocked on the backend field.

Next edge without a row: MP share paths (`onShareAppMessage` / `onShareTimeline` `path:`) vs `docs/release/aasa.json`. Every MP page already parses (`NativeNavigationContract.parse` → `MiniProgramPageLink`), but the AASA only claimed some of them, so a web link to the others would open Safari instead of the app once the domain is approved.

| MP share path (source) → native | before | after | status |
|---|---|---|---|
| `/pages/activity/list/index` (activity/list index.js:365) | not in AASA | added | fixed |
| `/pages/userinfo/userinfo?userId=&tab=` (cy/profile index.js:2429) | not in AASA | added | fixed |
| `/pages/templatedetail/topic-detail/index?id=` (topic-detail index.js:317) | not in AASA | added | fixed |
| `/subpackageRoam/official-route/index?id=` (official-route index.js:9 SHARE_PATH) | not in AASA | added | fixed |
| `/subpackageA/pages/infomationdetail/infomationdetail?id=` (infomationdetail.js:161) | not in AASA | added | fixed |
| `/pages/index/index`, `/pages/roam/index`, `/pages/talent/list/index` (tab roots as default share) | not in AASA | left out: a web link to a tab root is the site home, not an app page | n/a |

For coordinator/owner: universal links route nothing yet — `AppSession.nativeEntryLinkPolicy` is built with `verifiedHTTPSOrigins: []` (App/AppSession.swift:7092) until the associated domain is approved and the AASA is hosted. No code change here.

## Re-scan 11-28 09:xx — MP invite card links (merged combined-r7 at 94bd848c4)

Merged `origin/ui/combined-r7` (xcstrings: theirs + our extra keys). Sweep still build 7a7d2708a (already checked at 08:xx; mp-nav sheets read correctly). No new coordinator row for mp-nav; item 3 (MP-account sync note) still blocked on the backend field. Next edge without a row: the MP invite share card.

| MP edge → native | before | after | status |
|---|---|---|---|
| MP invite card `/pages/index/index?inviter=<uid>` (cy/profile index.js:2413, myinvite.js:25; older cards `?id=`; home QR `?scene=`) → MP home onLoad keeps the inviter, binds `POST /api/user/setInviter` after sign-in (index.js:37, 318, retryPendingInviter) | `pages/index/index` takes no query, so the link / notification `page` / `chein://mp/pages/index/index?inviter=` became a route error sheet and the inviter was lost | `NativeNavigationContract.homeReferral` (Core/NativeNavigationCompletion.swift): same keys as `/door` (`scene`, `inviter`, `id`, numeric inviter) → `.door(DoorIntent)`; `chein://mp` uses the same reader (App/MPParityDeepLinkEntry.swift). `receiveNativeIntent(.door)` queues the inviter (existing `DoorReferralQueue`, binding stays behind its own switch); an inviter-only link lands on the 首页 tab (`HomeLanding` `.door` without scene → `.tab(.home)`) instead of an extra sheet, like MP; a door scene keeps the door sheet (scan → topic / play / home). Unit test `DoorReferralTests.testMiniProgramHomeInviteCardIsDoorIntent`. Not compiled here | fixed |

## Re-scan 11-28 10:xx — function-audit share rows (merged combined-r7 at d2ddb1a9b)

Merged `origin/ui/combined-r7` (xcstrings: theirs; our 14 orphan `auth.alipay.*` keys dropped, no code reads them since 07:xx). Sweep still build 7a7d2708a (checked 08:xx). No new coordinator row for mp-nav; P1-1 (URL types / associated domains / verified origins) belongs to the `fix/1128-wechat-login` worker, not this lane; item 3 (MP-account sync note) still blocked on the backend field. Next row in my area: function audit `1128-functions.md:129` "Topic-template deck 分享主题模板 → Broken".

| MP edge → native | before | after | status |
|---|---|---|---|
| pages/templatedetail/topic-detail/index `onShareAppMessage` (index.js:317 `path: /pages/templatedetail/topic-detail/index?id=`) → App/DiscoveryTemplateDetailView.swift `topicShareOffer` → `PublicContentShareLink.topicTemplate` | `topicTemplate(id:)` accepted only `.content` intents, but the parser types this MP page as `.miniProgramPage` (PC-A-8-1), so it was always nil and the ShareLink shared the bare text `/pages/templatedetail/topic-detail/index?id=N` | uses the shared `reviewedPage` check (same as club / club-ticket shares): the https link that parses back to the same MP page; the path text stays only as the fallback for a non-canonical id. Same link shape as the topic and template shares; it opens the app once the P1-1 domain lands (AASA already claims the path, 08:xx) | fixed (not compiled here) |
| subpackageA/pages/infomationdetail share (infomationdetail.js:161) → App/SocialGuideViews.swift `informationShare` → `PublicContentShareLink.information` | same defect: always nil, shared the path text | same `reviewedPage` fix | fixed (not compiled here) |

Tests: Tests/CoreTests/PublicContentShareLinkTests.swift `testTopicTemplateSharesTheParsedUniversalLink` (replaces the old "not parsed, copy only" pin) and `testInformationSharesTheParsedUniversalLink`. Level C/B unchanged (navigation only; no section/order change).

## Re-scan 11-28 10:3x — remaining mp-nav audit rows (twin run took the share rows above)

| audit row | MP → native | finding | status |
|---|---|---|---|
| 1128-functions row 288 (IM inbox → 举报结果, "Not traced") | MP has no inbox-level report row: report progress lives only in the 城瘾小助手 system chat ("系统消息只放在城瘾小助手 … 不再在消息列表单列", im/chat index.js:192) → 我的举报 (`/subpackageMember/report-mine/index`) | MP entry is present: `MessagingHistoryView.swift:188` renders `IMReportProgressEntry` for the system notice with the unread count (`CloudB3Production.swift:230`, `GET api/v1/community/notifications`) → `SquareReportProgressView` (`SessionMessagingEntry.swift:40`). The inbox ⋯ 举报结果 row (`SessionMessagingEntry.swift:50`) is a different, app-only screen: the local journal of channel reports whose outcome was unknown, read back with `GET api/channel-platform/governance/reports/requests/{uuid}` (`Core/NativeChannelReportFlow.swift:166`), granted `.liveInProduction` (`Core/ChinaReviewedRouteCapability.swift:932`); unavailable / read-failed / empty states present. Closed loop; kept because removing it would strand pending reports | verified, no change |
| row 293 (IM 发送图片 Release-off) | — | audit P1-28, owned by `fix/1128-publish` / mp-publish | n/a (other lane) |
| rows 130, 131, 397 (chein:// URL types, universal links, WeChat SDK callback) | — | P1-1 / P0-5, owned by `fix/1128-wechat-login` | n/a (fix worker) |

| MP edge → native | before | after | status |
|---|---|---|---|
| `subpackageB/pages/im/list` empty state CTA 去发现找人 (index.wxml:103-108; index.js:345-349 `onEmptyCta` → `switchTab('/pages/talent/list/index')` with `markDiscoverFeed`, 2026-10-29 "去发现页的全站帖文找人") → App/SessionMessagingEntry.swift `SessionMessagingHome.openDiscoverFeed`, App/MessagingHomeView.swift `emptyFeedAction` | copy already MP (`im.inbox.emptySquare` = 去发现找人 / Find people in Discover), but the button pushed the Square browser on top of the inbox — a different page, and a second feed stack | pops the inbox (`dismiss`) and hands `pages/talent/list/index?tab=feed` to `receiveNativeIntent`, the same path as the 帖文 share card: 俱乐部 tab, 帖文 top tab. Same visibility guards (loaded, genuinely empty direct list, no search). Design/UI-test fixtures still pass `squareDestination` and keep the push. Contract test `Tests/ContractChecks/test_mp_nav_inbox_empty_feed.py`. Level B (inbox), navigation only. Not compiled here | fixed |

## Re-scan 11-28 11:xx — sweep ffeef67c7 login-player (merged combined-r7 at ffeef67c7)

Merged `origin/ui/combined-r7` (xcstrings: both sides' keys). Sweep ffeef67c7 mp-nav sheets (en / zh-Hans): inbox, ia-tabs, onboarding-1, welcome read correctly. No coordinator row for mp-nav. Item 3 (MP-account sync note) still blocked: `api/login/wechat/app` has no mini-program-origin field in the app models yet.

| MP edge → native | screenshot | before | after | status |
|---|---|---|---|---|
| MP login (`pages/login`, P27/P33 sign-in) → App/LoginView.swift `appleSignInSection` | `login-player` en + zh-Hans: 通过 Apple 登录 / Sign in with Apple drawn at 50 % alpha above the bright phone button | the section rendered whenever Apple was approved, but `AuthChannelAppleButton` disables itself (alpha 0.5) when no `AuthChannelServing` is behind the coordinator (`canStart` needs `isConfigured`), so a build with Apple approved and no service showed a dead, washed-out button | Apple renders only when approved **and** a sign-in service exists (P27: gated channel renders nothing). `LoginFixture` (App/DesignFixtures/OnboardingFixtures.swift) now passes an offline stub service (every call throws `notConfigured`, no network) so the sweep shows the shipped enabled black/white Apple button. Pin: Tests/ContractChecks/test_auth_entry_parity.py:59. Level A (sign-in), no section/order change. Not compiled here | fixed |

## Re-scan 11-28 12:xx — P1-1 follow-ups after the `fix/1128-wechat-login` merge (merged combined-r7 at 3348aa51f)

Merged `origin/ui/combined-r7` (xcstrings: theirs block; `test_auth_entry_parity` keeps both pins — Apple needs a service, P33 China order). No coordinator row for mp-nav; item 3 (MP-account sync note) still blocked: `api/login/wechat/app` (`WeChatAppAuthService.Envelope`, Core/WeChatAppAuth.swift:83) has only `code` / `token` / `data`, no mini-program-origin field. Contract-cleanup row `/api/compliance/usage-records` was closed at 21:0x (Settings row removed). The fix worker's P1-1 (`AppUniversalLinkRouter`, `AppSession+AppLinks.swift`, `QUESTIFY_APP_LINK_DOMAIN`) is the lane's follow-up now.

| MP edge → native | before | after | status |
|---|---|---|---|
| MP share cards / WeChat SDK Universal Link (`/app/*`) → `docs/release/aasa.json` | two AASA files had drifted: `aasa-template.json` (the one owner-values.md:100 deploys) claims `/app/*` first, but the team-ID-filled `aasa.json` did not, so a copy taken from it would not open `/app/activity/<id>` links nor return the WeChat SDK to `/app/<AppID>/oauth` | `aasa.json` regenerated from the template with `TEAMID` → `9VHY8N755R`; same component list and order | fixed |
| US sign-in (P33: Apple → phone +1) → App/LoginView.swift `signInChannelSections` | phone was drawn non-prominent whenever Apple was approved, but since 11:xx Apple renders only with a sign-in service behind it, so a US build with Apple approved and no service showed only a secondary phone button (no primary action) | `appleShown(_:)` = the same test as `appleSignInSection`; phone is prominent when Apple is not on screen. Level A (sign-in), no section/order change. Not compiled here | fixed |

## Re-scan 11-28 13:xx — coordinator sweep 07:45 (build 3348aa51f) `login-player` (merged combined-r7 at 8952067e9)

Merged `origin/ui/combined-r7`. Sweep 3348aa51f predates 8b1016b7b (Apple only with a service behind it, offline stub in the fixture), so its grey pill is the old build; this run closes the rest of the row. Item 3 (MP-account sync note) still blocked on the backend field.

| MP edge → native | screenshot | before | after | status |
|---|---|---|---|---|
| MP login (P33 sign-in) → App/AuthChannelAppleButton.swift, App/LoginView.swift | `login-player` en + zh-Hans (sweep 07:45): Sign in with Apple is a grey, disabled-looking pill; "keep it enabled and ask for consent on tap" | the system button got `isEnabled = canStart && verified` + alpha 0.5, so any busy moment (or a missing agreement, which hid Apple and disabled phone) left a dimmed or absent control | the Apple button is always the enabled black / white system button while offered (`isEnabled` = configuration verified; busy taps are ignored in `signIn(_:)` and the progress row shows). Without the agreement on record, Apple and phone both stay on screen and enabled; a tap opens the same agreement sheet as the inline row (`LoginConsentPrompt`, `UsageConsentGateView`), agreeing records it and the player taps again. US order Apple → phone +1, CN WeChat → phone → Apple unchanged. Pin: Tests/ContractChecks/test_auth_entry_parity.py (consent asked on tap, Apple checks consent before `canStart`). Level A. Not compiled here | fixed |

## Re-scan 11-28 14:xx — MP home QR scenes (merged combined-r7 at 70917c058)

Merged `origin/ui/combined-r7`. Sweep still build 3348aa51f (mp-nav sheets checked at 13:xx); no new coordinator row for mp-nav after 07:45. Item 3 (MP-account sync note) still blocked: `api/login/wechat/app` (`WeChatAppAuthService.Envelope`) has no mini-program-origin field. Next edge without a row: the scene codes MP home consumes before anything else.

| MP edge → native | before | after | status |
|---|---|---|---|
| `pages/index/index?scene=` QR scenes (index.js:298 `consumeDoorScene` before the inviter read; :353-375; utils/game-door-entry.js `tp.` / `ac.` / `sh.` / `tm.` / `th.`) → Core/NativeNavigationCompletion.swift `homeScene` / `homeScenePath`, App/MPParityDeepLinkEntry.swift `homeScene(_:)` | every non-hex scene became a door intent; `DoorParsing.scene` rejects it, so a 本主题二维码 / 活动码 / 店铺码 / 队伍码 link (`chein://mp/…`, universal link, notification `page`) opened 首页 and lost the target | `tp.<id>` → topic detail (`/pages/topic/index/index?id=`), `ac.<id>` → official activity detail, `sh.<id>` → `pages/userinfo/userinfo?userId=&tab=about`, `tm.<6-char / 22-char>` → team join, `th.<22 b64url>` → team join with the restored 32-hex code; each re-parsed through the normal page parser so it lands like a direct link. MP drops the inviter on these (redirect before read), native does the same. `rc.` (merchant 招商位置, out of scope) and the 32-hex door code keep the door path. Unit test `DoorReferralTests.testMiniProgramHomeQRScenesOpenTheirPage`. Level: navigation only, no section/order change. Not compiled here | fixed |

## Re-scan 11-28 14:3x — planning-audit mp-nav rows (merged combined-r7 at 70917c058)

Merged `origin/ui/combined-r7` (clean). Sweep still build 3348aa51f (its `login-player` row closed at 13:xx). No new coordinator row for mp-nav; item 3 (MP-account sync note) still blocked: `WeChatAppAuthService.Envelope` has no mini-program-origin field. Worked the planning audit (`audit/1128-plan`) rows tagged mp-nav.

| audit row | MP → native | finding | status |
|---|---|---|---|
| H-16 `/api/compliance/usage-records` (contract cleanup, mine) | no MP caller → `Core/UsageConsentRead.swift:38`, `App/UsageConsentReadView.swift` | Release never sends it: `UsageConsentReadSettingsEntry` has no caller since the Settings row went (21:0x), and `makeUsageConsentReadCoordinator` is only reached from that view. Deleting the reader retires ~30 CI-required methods (`tools/current_ci_manifest.json` `required_current_methods`: UsageConsentHistoryHostTests / UsageConsentHistoryJourneyTests), which needs a coordinator retirement entry | verified unreachable; deletion → coordinator |
| M-08a IM tabs | `subpackageB/pages/im/list` 收件箱 / 发件箱 (index.js:263-291) → App/MessagingHomeView.swift:23-53 | already 收件箱 (received invites + every conversation) / 发件箱 (sent invites only), in MP order; the audit row read an older file | verified, no change |
| M-17d public profile 私信 | — | owned by `fix/1128b-club-mine` #10 (merged) | n/a (fix worker) |
| M-08c rich cards (location / route / signup) | `subpackageB/pages/im/chat` index.wxml:64-91, index.js:1077-1094: tapping a route / signup card opens `/pages/topic/index/index?id=`; a location card opens navigation (`openAddress`, foot 导航过去) → App/MessagingHistoryView.swift `messageRowLink`, App/NativeR2/Social/MessagingCardAnswers.swift `MessagingCardTap` | every card bubble pushed the message detail page first; the route preview there is not tappable, so the topic was never reachable from the card, and the location needed two taps to reach a map that cannot navigate | route / signup card → `cardRoute = .topic(id)` (the same `TopicDetailView` push the card answers use); location card with valid coordinates → Apple Maps (`MKMapItem.openInMaps`). Cards with inline answers, polls, media and text keep the detail push. Not done: MP sends a signup card whose topic is gone to 票夹 (index.js:1087); native shows the topic page's own unavailable state. Level B (inbox/chat), navigation only. Not compiled here | fixed (partial) |

## Re-scan 11-28 15:xx — M-08c signup card whose topic is gone (merged combined-r7 at 3dcab5af8)

Merged `origin/ui/combined-r7` (clean). No new coordinator row for mp-nav; IM read cursor (backend audit row) already fixed (row above). Item 3 (MP-account sync note) still blocked: `WeChatAppAuthService.Envelope` has no mini-program-origin field. This run takes the carried partial of M-08c.

| MP edge → native | before | after | status |
|---|---|---|---|
| `subpackageB/pages/im/chat` signup card tap with an unreadable topic (index.js:1084-1088, P-36: "票本身仍有效 —— 带去票夹") → App/MessagingHistoryView.swift `openCardTopic`, App/NativeR2/Social/MessagingCardAnswers.swift `MessagingCardRoute.signupTopic`, App/TopicDetailView.swift `TopicDetailIssueState` | the signup card pushed the topic; when the topic was 下架 / refused the page showed only 返回, so the still-valid ticket was not reachable from the card | a signup card pushes `.signupTopic(id)`; the topic page gets `unavailableWallet` (`pageDestination("subpackageMember/signup/index")` = the shared `SessionTicketWalletHost`). If the topic read is refused, the `ContentUnavailableView` says 你的票仍然有效，可以在票夹里查看 / "Your ticket is still valid…" and offers 去票夹 (`.borderedProminent`, pushed) above 返回. Route cards and every other topic entry are unchanged (no wallet action). Native cannot know the topic is gone before the push (MP preloads `topicCache`), so the wallet is one tap from the topic's unavailable state instead of a direct redirect. New key `mpfresh.topic.refused.ticketValid` (en + zh-Hans). Level B, navigation only. Not compiled here | fixed |

## Re-scan 11-28 16:xx — MP place links `poi-detail?poiId=` (merged combined-r7 at 882fca768)

Merged `origin/ui/combined-r7` (clean). Sweep build 0446d1c4f mp-nav sheets (en / zh-Hans: `d2-inbox`, `ia-tabs`, `login-player`, `onboarding-1`, `welcome`) read correctly; no coordinator row for mp-nav. Item 3 (MP-account sync note) still blocked: `WeChatAppAuthService.Envelope` has no mini-program-origin field. Next edge without a row: MP share paths (`onShareAppMessage` `path:`) checked key by key against `MiniProgramPageLink` / `NativeNavigationContract`; every path parses except the place card.

| MP edge → native | before | after | status |
|---|---|---|---|
| MP place link `/subpackageRoam/poi-detail/index?poiId=<cityNodeId>` (poi-detail/index.js:4 "一旦上线即长期契约", :27 onLoad; share `utils/place-share.js`, mylike.js:435 / :680) → Core/NativeNavigationCompletion.swift (`.content(.poi)`), Core/MiniProgramPageLink.swift (rule), Core/PublicContentShareLink.swift `poi(id:)` / `poiCopyText` | inbound: only `?id=` was accepted (`identifiedPages`), so an MP place share card, universal link, `chein://mp/…` or notification `page` with `poiId` was rejected → route error. Outbound: the app's place share sent `?id=`, which the MP page reads as no poiId → 找不到这个节点 | inbound: a lone canonical `poiId` is the same `.content(.poi)` as `?id=`; the `chein://mp` / notification rule accepts exactly one of `id` / `poiId` (screen already reads `poiId ?? id`, MPReviewedPageScreen.swift:257). Outbound share + copy text use `?poiId=` (parsed back before it is offered). AASA comment updated (path unchanged). MP `?merchantId=` fallback (legacy merchant profile link) stays unrouted: merchant out of scope. Test `PublicContentShareLinkTests.testPlaceShareUsesTheMiniProgramPoiIdAndBothSpellingsParse`. Level B, navigation only, no section/order change. Not compiled here | fixed |

## Re-scan 11-28 16:xx — team invite share link (merged combined-r7)

Merged `origin/ui/combined-r7`. Sweep build 0446d1c4f mp-nav sheets (welcome, login-player, onboarding-1, ia-tabs, d2-inbox; en + zh-Hans) clean, no coordinator row for mp-nav after 07:45. Item 3 (MP-account sync note) still blocked on the backend field. Next P1-1 share edge without a row: planning audit T-02.

| MP edge → native | before | after | status |
|---|---|---|---|
| `pages/team/detail` 分享 (index.js:539-548 `onShareAppMessage` path `/pages/team/join/index?code=`, link carries only the code) → Core/PublicContentShareLink.swift `teamInvite(code:)`, App/TeamComponents.swift `TeamInvitePreview` 分享邀请码 | the share sent the bare code text; the receiver had to find the code entry and type it | shares `https://www.chengyinhub.com/pages/team/join/index?code=<code>` as text with the team title as preview (one `ShareLink`, pin in test_team_contracts.py updated), kept only when `UniversalLinkParser` reads it back as the same `.teamInvitation` (no team id, no member data, as the MP). Opening it lands on the read-only invitation preview (`NativeNavigationContract` `/pages/team/join/index`). Falls back to the code text when the origin is not the reviewed host. Unit test `PublicContentShareLinkTests.testTeamInviteShareIsTheMiniProgramJoinLinkThatParsesBack`. Level: navigation only, no section/order change. Not compiled here | fixed |

## Re-scan 11-28 17:xx — city orienteering share edges (merged combined-r7)

Merged `origin/ui/combined-r7` (clean). Sweep index still build 0446d1c4f (mp-nav sheets clean, no coordinator row for mp-nav after 07:45). Item 3 (MP-account sync note) still blocked: `WeChatAppAuthService.Envelope` (Core/WeChatAppAuth.swift:83) has no mini-program-origin field. Next P1-1 share edges without a row: the app's outbound `ShareLink`s checked against every MP `onShareAppMessage` path; two still shared text without the MP link.

| MP edge → native | before | after | status |
|---|---|---|---|
| `pages/activity/detail` 分享 (MP `onShareAppMessage` → `buildActivityShare`, path `?id=`) → App/NativeR2/CityOrientation/CityOrientationEventDetailList.swift action pill 分享 (city-orienteering event detail) | shared only "name · time" text: the receiver could not open the event | shares "name · time" + the `PublicContentShareLink.activity(id:)` universal link (same link as the toolbar share card); text only when the link would not parse back | fixed |
| `pages/team/detail` 分享 (index.js:540-548 path `/pages/team/join/index?code=`) → App/NativeR2/CityOrientation/CityOrientationTeamLobbyView.swift bottom-bar 邀请队友 | shared the bare 6-char code | `PublicContentShareLink.teamInvite(code:)` link with the team title as preview, falling back to the code — the same item as `TeamInvitePreview` (T-02 row above) | fixed |

Tests: existing `PublicContentShareLinkTests.testActivityShareCarriesTheParsedActivityLink` / `testTeamInviteShareIsTheMiniProgramJoinLinkThatParsesBack` cover both builders. Level B, navigation only, no section/order change. Not compiled here.

## Re-scan 11-28 18:xx — play finish share link (merged combined-r7 89a55cd24)

Merged `origin/ui/combined-r7` (clean). Sweep index still build 0446d1c4f (mp-nav sheets clean); no coordinator row for mp-nav after 07:45; Contract-cleanup `/api/compliance/usage-records` closed (21:0x / H-16). Item 3 (MP-account sync note) still blocked on the backend field. B receipt read: no overlap. Next outbound share edge without a row: the play finish screens.

| MP edge → native | before | after | status |
|---|---|---|---|
| `subpackageJourney/pages/settle` 分享 (index.js:264-271 `onShareAppMessage`: referral landing when a token is issued, else `/pages/topic/index/index?id=<topicId>`) → App/PlayExperienceView.swift `cityFinishSummary` / medal screen, App/NativeR2/CityOrientation/CityOrientationFinishSummaryView.swift (toolbar 分享 + per-medal share), App/DesignSystem/CYMedalStack.swift `CYMedalScreen` share pill | shared only "我在…通关" text: the receiver could not open the topic | `PlayExperienceView.finishShareURL` = `PublicContentShareLink.topic(id:)` from the run's `result.topicID` (the MP fallback path; the app issues no referral here), shared with the same text as the message; text alone when there is no topic id / reviewed origin. Identifiers and layout unchanged. Level B, navigation only, no section/order change. Not compiled here | fixed |

## Re-scan 11-28 19:xx — official event / route share links (merged combined-r7)

Merged `origin/ui/combined-r7` (clean). Sweep index still build 0446d1c4f (mp-nav sheets clean); no coordinator row for mp-nav after 07:45. B receipt read: its four rows (topic 编辑 push, activity → 票夹 push, square 试玩, Welcome ⋯ 设置) are marked done above "(B lane)". Item 3 (MP-account sync note) still blocked on the backend field. K30 (Cursor deep links) has no branch yet; this row only touches outbound share builders. Next outbound share edges without a row: the two `CatalogShareCardView` callers that passed no `link`.

| MP edge → native | before | after | status |
|---|---|---|---|
| `pages/activity/official-detail` 分享 (index.js:651-658 `onShareAppMessage` path `/pages/activity/official-detail/index?id=`) → App/OfficialEventDetailView.swift share card, Core/PublicContentShareLink.swift `officialEvent(id:)`, docs/release/aasa.json + aasa-template.json | the share card sent only the rendered image (no way back to the event); the AASA did not claim `/pages/activity/official-detail/index`, so a web link would open Safari | card gets `link:` = the https MP path (kept only when it parses back, `reviewedPage`), shown as the card's 分享链接 action like activity detail; AASA claims the path in both files (same position in each) | fixed (not compiled here) |
| `subpackageRoam/official-route` 分享 (index.js:9 `SHARE_PATH`, :57-60) → App/OfficialRouteViews.swift share card, `PublicContentShareLink.officialRoute(id:)` | image only | same `link:` with `?id=<routeID>` (canonical digits only, as MP onLoad `/^\d{1,18}$/`); AASA already claimed the path | fixed (not compiled here) |

Test: `PublicContentShareLinkTests.testOfficialEventAndRouteSharesCarryTheMiniProgramLinkThatParsesBack`. Level B (detail pages), navigation only, no section/order change.

## Re-scan 11-28 20:xx — widget / Control Center check-in target (merged combined-r7)

Merged `origin/ui/combined-r7` (clean). Sweep index still build 0446d1c4f (mp-nav sheets clean); no coordinator row for mp-nav after 07:45. B receipt read: no new rows. Item 3 (MP-account sync note) still blocked on the backend field. Every MP `onShareAppMessage` page now has a row (journey report/settle carry the referral + topic fallback; growthcenter and the order list share nothing in the MP). Next external entries without a row: widget, Live Activity and Control Center targets, checked one by one against `MiniProgramPageLink` and the MP page each lands on.

| entry → MP page | before | after | status |
|---|---|---|---|
| Control Center 签到 / "Check in" (`QuestControlRoute.checkIn`, Core/QuestWidgetControlIntent.swift; description "Open the activities you joined to check in") → MP 入场码 = `subpackageMember/signup/index` (票夹, signup/index.json uses `cy-dot-qr`) | opened `pages/activity/list/index` = 官方活动 (MP nav title 官方活动, a browse list with no ticket or entry code) | `subpackageMember/signup/index`: lands on 票夹 pushed on 首页 through `MPNotificationTapRouter` (same host as the landed wallet link) | fixed |
| event-countdown widget without a ticket id (`QuestWidgetBoard.ticket(nil)` → `myActivities`, Core/QuestWidgetBoard.swift) | `chein://mp/pages/activity/list/index` (官方活动) | `chein://mp/subpackageMember/signup/index` (= `QuestWidgetLinks.wallet`), where the joined event's pass is | fixed |
| passport / stories / wallet widget links, Live Activity roam / event, team-invite plan link `pages/team/detail/index?teamId=` (MP onLoad `options.teamId`), club / messages / roam-history board links | all parse (`MiniProgramPageLink` rules :37, :129, :158, :204) | unchanged; parse now pinned for every `QuestWidgetLinks` / `QuestPlanLinks.team` URL | verified |

Test: Tests/CoreTests/QuestWidgetBoardTests.swift (`myActivities == QuestWidgetLinks.wallet`; every widget link parses). Navigation only, no section/order change. Not compiled here.
