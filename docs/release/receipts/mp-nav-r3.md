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
| profile → pages/shezhi/shezhi (navigateTo) | 我的 top-right 设置 | sheet kept: SettingsView's profile/favorites route owners retire on `onDisappear`, so hosting it as a push would retire them on every sub-push. Needs an owner-lifetime change first (coordinator) | open |
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
| pages/topic/index/index → pages/publish/fabu (owner 编辑, navigateTo) | topic bar 编辑 (owner, productType 2) | full-detent sheet with its own stack: an editor with discard state, kept modal like every native editor (OWNER RULE 2 popups vs pages); flagged, not changed | open |
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
| review result 查看原单 (`onCurrentCard` → `originalUrl`) | review sheet only | MP binds `onCurrentCard` in no `.wxml` (the 生成时记录 cy-sheet, chat/index.wxml:210-224, has no button), so it is dead in the MP; sheet unchanged | n/a |
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
| pages/shezhi/shezhi (plain) → SettingsView | own `NavigationStack` + 完成 on the landed push | not changed: SettingsView's route owners retire on disappear and its profile routes use `navigationDestination(for:)` on the inner stack (see Open) | open |
| `login-player`, `d2-inbox` tiles | still show 微信登录 / "Fixture conversation N": sweep build a250afd77 predates 81a815048 / 9723767a1 (not yet in `ui/combined-r7`) | — | OK (pending merge) |

## Re-scan 11-27 21:0x (20:55 sweep row, mp-nav en)

| MP page / edge → native | finding | change | status |
|---|---|---|---|
| pages/login → App/LoginView.swift (`login-player` en, sweep bb76e327c) | dead row "This isn't switched on yet." (`auth.notConfigured`, shown when no API base URL) under the sign-in buttons | row removed (P27: a gated channel renders nothing); the phone page itself still reports the unconfigured error when tapped. `region.usLoginPending` kept: it is the US regional notice, not a dead channel (RegionalEntryFlowTests) | fixed |
| same screen, channel order | Sign in with Apple sat above phone sign-in and demoted the phone button to `.bordered` | phone sign-in first and always the one `.borderedProminent` action (no password form); Apple's `SignInWithAppleButton` under it only when `appleConfigurationVerified` (gated → nothing); WeChat row after, only when offered | fixed |
| backend contract 20:40 `/api/compliance/usage-records` (Core/UsageConsentRead.swift:38) → App/SettingsView.swift 设置 list | the only caller is the app-only 同意记录 / usage-evidence row (`UsageConsentReadSettingsEntry`); MP pages/shezhi/shezhi.wxml:14-35 has no such row and the backend does not serve the path, so the page could only show its error | row removed from 设置 (MP list order unchanged); no screen reaches the path any more. Agreement state stays on `/api/compliance/consents/latest` (registration, deregistration, checkout). Core reader + its unit tests left in place (unreachable) so no pin moves; route-capability entry left for debt-r3/coordinator to retire | fixed |

## Route coverage

All 136 non-merchant MP pages in `app.json` resolve natively (MPReviewedPageScreen cases or `MPParityDestination`), except four pages that are parsed (`Core/MiniProgramPageLink.swift`) but have no native screen case: `pages/playkit/index/index`, `pages/publishkit/index/index` (MP kit galleries), `pages/crop/index` (MP image-crop utility) and `subpackageP3/pages/badge-3d/index` (MP 3D badge viewer). No native player control links to them; left for the coordinator to confirm they stay unrouted.

## Pins updated

- Tests/ContractChecks/test_ticket_wallet_play_entry.py:19 — looks for the wallet `navigationDestination` line instead of the old `.cySheet` (wallet is now a push).

## Coordinator sweep rows (16:37 / 16:53)

| row | finding | status |
|---|---|---|
| `d2-city` "City tab root has no large top-left title, only a refresh button" | CityPlayerView is not a tab root: it is pushed from 漫游 ⋯ 更多 → 城市 (RoamBrowserView.swift:282 with `.cyPushedChrome()`) and from the 城市大富翁 ⋯ menu (RoamTerritoryView.swift:39). Per OWNER RULE 2 a pushed page keeps its inline title (`city.read.title`, CityPlayerView.swift:177-178); the d2-city fixture hosts it in a bare NavigationStack, so the screenshot shows no back button. The five tab roots all carry the large title (P1, P2, P7 above). Hero text on the gradient is ds-consistency's half | n/a (verified, no change) |

## Open (carried)

- 我的 → 设置 stays a `.large` sheet (AccountView.swift:146, WelcomeView.swift:66): MP navigateTo = push, but SettingsView owns its own NavigationStack, a 完成 dismiss, the guide hand-off and `profileOwner.retire()` on disappear; converting needs those lifetimes moved first. Needs the coordinator / a compiled run.
- 漫游护照与工具 hub sheet (owner Q9) and topic 编辑 editor sheet — kept, see the edge table.

## For other lanes

- mp-states / coordinator: the 消息 inbox preview is always "打开会话查看消息" (`MessagingPreview`, App/MessagingComponents.swift:300; `MessagingConversation` drops `lastMsgText` because recalled text may survive in it). MP `fmtPreview` shows the last message text / [图片] / [系统卡片]. Showing it needs a recall-safe server field first; left as is (privacy decision).

- en-layout: `onboarding-1` (en) header and centre disc show 城瘾; LoginView `brandMark` and SettingsAboutView `appName` use `Text(verbatim: "城瘾")` (en should read Chein).
