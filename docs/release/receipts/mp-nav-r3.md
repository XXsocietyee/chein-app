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
| pages/topic/index/index → subpackageMember/signup/index (票, navigateTo) | topic bottom bar 我的票 | `.cySheet` half/full with bar hero zoom (TopicDetailView.swift:128) | open — MP page shown as a half sheet; left because the bar's matched hero transitions are built on sheets |
| pages/topic/index/index → pages/topic/pricing/index (navigateTo) | topic bar 定价 (owner) | sheet half/full (TopicDetailView.swift:626) | open — same reason |
| pages/topic/index/index → pages/play/index (navigateTo) | topic bar 开始 | `navigationDestination(isPresented: $showingPlay)` push | OK |
| pages/topic/index/index → session picker / self-play form (MP popups) | topic bar 选择场次 / 自己玩 | sheets with `[.half, .full]` detents | OK |
| pages/club/detail/index → member list (MP `expandMembers`, in-page) | 查看成员 | sheet `[.medium, .large]` | OK |
| pages/club/detail/index → settings panel (MP cset popup, wxml:663-797) | toolbar gear | sheet `[.medium, .large]`; rows push the MP pages (customers / enroll / event-ops / roles / settlement) | OK |

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

Known gap: `pages/talent/list/index?tab=feed` switches to 俱乐部 but does not preselect the 帖文 sub-tab (the tab root has no external sub-tab input yet).

## Route coverage

All 136 non-merchant MP pages in `app.json` resolve natively (MPReviewedPageScreen cases or `MPParityDestination`), except four pages that are parsed (`Core/MiniProgramPageLink.swift`) but have no native screen case: `pages/playkit/index/index`, `pages/publishkit/index/index` (MP kit galleries), `pages/crop/index` (MP image-crop utility) and `subpackageP3/pages/badge-3d/index` (MP 3D badge viewer). No native player control links to them; left for the coordinator to confirm they stay unrouted.

## Pins updated

- Tests/ContractChecks/test_ticket_wallet_play_entry.py:19 — looks for the wallet `navigationDestination` line instead of the old `.cySheet` (wallet is now a push).
