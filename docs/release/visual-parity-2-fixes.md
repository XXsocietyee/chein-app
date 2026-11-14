# Visual Parity Check 2: Mini-Program vs Native iOS App

**Branch**: `docs/visual-parity-2` (from `origin/ui/main`)  
**Mini-Program Baseline**: `hengyin` `master` (`chengyinhub-xcx`), captured via `wxa-runner` + Playwright on VPS against TEST `8120`  
**Native App Reference**: `docs/release/screens/` (from the `DES-ui` worktree; live TEST `8120` captures under `live-*` plus parity/feature captures under `main-tabs/`, `d4/`, `d6/`, `e2/`, `e5b/`, `account-settings/`, `core-pages/`, `coupons/`, `orders/`, `roam/`, `ticket/`, `wallet/`, `merchant/`, `play-parity/`, `im/`, `consent/`)  
**Privacy Note**: Mini-program screenshots remain strictly outside git (stored on the VPS and locally under `/private/tmp/claude-501/mp-shots`). This report is text-only and contains no mini-program images or links to them.

---

## Scope & Methodology

- Captured 40 mini-program pages (plus clean/scrolled companion shots `01b`, `03b`, `06b`, `09b`) covering the top 30+ player routes plus key entry/merchant/settings parity screens.
- Checked `chengyinhub-xcx/app.json` for player City routes: the mini-program only defines `citynode/index`, `citynode/create/index`, `citynode-code/index`, and `citystamp/index` (merchant/citystamp), confirming the player `CITY` tab (`d2-city.png`) has no mini-program player counterpart.
- Audited every page side-by-side for missing sections/fields, ordering differences, copy/localization mismatches, missing CTAs, theme/contrast defects, broken loading/error states, and tab-bar overlap.
- Note on DB seed data: UTF-8 mojibake on one seeded `cy_e2e_r2` free-explore topic title appears in both the app (`live-home/discover-feed.png`, `live-clubs/club-activity-list.png`) and the mini-program (`07-roam`), indicating a shared seed/database encoding defect rather than an app-only UI regression.

---

## Summary Count Table (40 Pages, 213 Differences)

| # | Page | MP Route & Shot ID | App Reference Screenshot(s) | Diffs |
|---:|---|---|---|---:|
| 1 | Home | `pages/index/index` (`01-home`, `01b-home-clean`) | `live-home/home.png`, `live-home/home-located.png`, `live-home/more-menu.png`, `live-home/discover-feed.png`, `main-tabs/d2-home.png` | 6 |
| 2 | Discover / Community Feed | `pages/talent/list/index?tab=feed` (`02-discover`) | `live-home/discover-feed.png`, `main-tabs/d2-square.png` | 5 |
| 3 | Topic Detail | `pages/topic/index/index?id=992001` (`03-topic-detail`, `03b-topic-detail-body`) | `live-discover/topic-detail.png`, `live-discover/route-stations.png` | 6 |
| 4 | Activity Detail | `pages/activity/detail/index?id=992031` (`04-activity-detail`) | `live-discover/activity-session-detail.png`, `live-discover/activity-detail.png` | 6 |
| 5 | Activity Sign-up / Checkout | `pages/activity/baoming/baoming` (`05-activity-signup`) | `live-discover/registration-sheet.png`, `live-discover/signup-sheet.png` | 6 |
| 6 | Play Runtime | `pages/play/index` (`06-play-runtime`, `06b-play-clean`) | `d6/d6-play.png`, `main-tabs/d2-play.png`, `play-parity/g-play-prep.png`, `play-parity/g-play-gameplay.png` | 5 |
| 7 | Roam Home | `pages/roam/index` (`07-roam`) | `live-roam/roam-home.png`, `roam/roam-go.png`, `main-tabs/d2-roam.png` | 6 |
| 8 | City | No MP player route (`citynode/*`, `citystamp/index` only) | `main-tabs/d2-city.png` | 3 |
| 9 | Club Home | `pages/talent/list/index` (`08-club-home`) | `live-clubs/clubs-home.png`, `d4/d4-directory.png` | 6 |
| 10 | Club Detail | `pages/club/detail/index?id=7001` (`09-club-detail`, `09b-club-detail-clean`) | `live-clubs/club-home.png`, `live-clubs/club-welcome.png`, `live-clubs/club-activities.png`, `d4/d4-detail.png` | 6 |
| 11 | Club Chat / Channel | `subpackageB/pages/im/chat/index?conversationId=1&type=4` (`10-club-chat`) | `d4/d4-channel-chat.png` | 5 |
| 12 | IM Messages List | `subpackageB/pages/im/list/index` (`11-im-list`) | `live-im/messages.png`, `live-im/channels-tab.png`, `main-tabs/d2-inbox.png` | 6 |
| 13 | IM Chat / DM Conversation | `subpackageB/pages/im/chat/index?conversationId=2&type=1` (`12-im-chat`) | `live-im/dm-system.png`, `im/im-preview.png` | 5 |
| 14 | Passport / Me | `pages/member/index/index` (`13-passport-me`) | `live-passport/passport-me.png`, `live-passport/passport-scrolled.png`, `main-tabs/ia-passport.png` | 7 |
| 15 | Wallet / Account Earnings | `subpackageA/pages/assetcenter/earnings/index` (`14-wallet-earnings`) | `live-wallet/account-income.png`, `account-settings/e4-wallet-assets.png`, `account-settings/e4-wallet-balance.png` | 6 |
| 16 | Wallet / Asset Analysis | `subpackageA/pages/assetcenter/analysis/index` (`15-wallet-analysis`) | `account-settings/e4-wallet-analysis.png` | 4 |
| 17 | Search Home | `pages/search2/index` (`16-search`) | `live-discover/search.png` | 6 |
| 18 | Search Results | `pages/search2/result/index?keyword=老城` (`17-search-results`) | `main-tabs/d2-search-results.png` | 5 |
| 19 | Search Map | `pages/searchmap/index` (`18-search-map`) | `d6/d6-search.png` | 5 |
| 20 | Community Post Detail | `pages/square/detail/index?id=992571` (`19-community-post`) | `main-tabs/d2-square.png` | 5 |
| 21 | Rewards Store / Passes | `subpackageMember/market/passes/index` (`20-rewards-store`) | `account-settings/e4-purchase.png`, `account-settings/e4-wallet-points.png`, `wallet/wallet.png` | 6 |
| 22 | Merchant Public Homepage | `pages/merchant/profile/index?id=8001` (`21-merchant-public`) | `live-merchant/merchant-entry.png`, `play-parity/g-merchant-node.png`, `core-pages/core-nearby-merchant.png` | 6 |
| 23 | Merchant Workbench / Home | `pages/merchant/index/index` (`22-merchant-home`) | `merchant/merchant-home.png`, `live-merchant/merchant-passport.png` | 6 |
| 24 | Settings | `pages/shezhi/shezhi` (`23-settings`) | `live-settings/settings.png`, `live-settings/settings-bottom.png` | 6 |
| 25 | Publish / Templates | `pages/template/index` (`24-publish-templates`) | `account-settings/e4-template-mine.png`, `main-tabs/ia-explore-create.png` | 6 |
| 26 | Official Events List | `pages/activity/list/index` (`25-official-events`) | `live-discover/activity-list.png`, `live-clubs/club-activity-list.png` | 5 |
| 27 | Ticket Wallet | `subpackageMember/signup/index` (`26-ticket-wallet`) | `account-settings/e4-tickets.png`, `live-wallet/tickets.png`, `ticket/ticket-list.png` | 6 |
| 28 | Orders List | `subpackageMember/order/order` (`27-orders-list`) | `orders/orders-list.png` | 5 |
| 29 | Growth Center | `subpackageP3/pages/growthcenter/index/index` (`28-growth-center`) | `d4/d4-growth.png` | 5 |
| 30 | Leaderboard | `subpackageP3/pages/growthcenter/leaderboard/index` (`29-leaderboard`) | `d4/d4-leaderboard.png` | 5 |
| 31 | Badge Wall | `subpackageP3/pages/badge-wall/index/index` (`30-badge-wall`) | `d4/d4-badges.png`, `e5b/e5b-badge-wall.png` | 6 |
| 32 | Stamp Album | `subpackageP3/pages/stamp-album/index/index` (`31-stamp-album`) | `d4/d4-stamps.png` | 5 |
| 33 | Roam POI Detail | `subpackageRoam/poi-detail/index?poiId=992522` (`32-roam-poi-detail`) | `roam/roam-sheet-half.png`, `e5b/e5b-checkin.png` | 5 |
| 34 | Team Detail | `pages/team/detail/index?teamId=1` (`34-team-detail`) | `play-parity/g-team-trail.png` | 5 |
| 35 | Coupon Wallet | `subpackageMember/coupon-wallet/index` (`35-coupon-wallet`) | `coupons/coupons.png` | 4 |
| 36 | Favorites | `pages/mylike/mylike` (`36-favorites`) | `account-settings/e4-favorites.png` | 5 |
| 37 | User Profile | `pages/userinfo/userinfo?id=9004` (`37-user-profile`) | `account-settings/e4-self-growth.png`, `account-settings/e4-self-medals.png` | 5 |
| 38 | Privacy & Location | `pages/privacy/index` (`38-privacy`) | `live-settings/privacy-location.png`, `account-settings/e4-privacy.png` | 5 |
| 39 | Roam History | `subpackageRoam/history/index` (`33-roam-history`) | `live-roam/walk-finished.png` | 4 |
| 40 | Stamp Camera | `subpackageRoam/citystamp/index` (`39-city-stamp`) | `e5b/e5b-stamp.png` | 4 |
| **Total** | **40 pages** | | | **213** |


## Fix Pass Summary (`ui/h-visual-bugs`)

- **Total audited items**: 213 across 40 pages
- **Fixed defects (`fixed -> file:line`)**: 33
- **Deferred to design-system restyle (`DESIGN-SYSTEM`)**: 180
- **Supporting safeguards included in this branch**: `.cyHideTabBar()` also added to `App/GlobalSearchView.swift:140`, `App/ProfileOrdersView.swift:74`, `App/SquareDetailView.swift:96`, `App/RoamItemDetailView.swift:97`, `App/RoamHistoryViews.swift:101`, `App/SocialPublicProfileView.swift:230`, `App/TicketWalletDetailView.swift:112`, `App/ClubDirectoryView.swift:56`, `App/ClubPublicRosterView.swift:65`, `App/WalletIncomeAnalysisView.swift:46`; `Core/RoamEntryNearby.swift:313` wraps `RoamEntryNearbyFixtureReader` in `#if DEBUG`; `App/QuestifyApp.swift:171` applies `.cyScreenStyle()` in `FixtureThemeDomainModifier`.
---

## Cross-Cutting High-Priority Issues

1. **Critical dark-mode contrast failures (black text on black background)** in `d4/d4-growth.png`, `d4/d4-leaderboard.png`, `d4/d4-badges.png`, `d4/d4-stamps.png`, and `d4/d4-channel-chat.png` (plus light-mode white cards injected inside dark shells on `d4-badges.png`, `d4-stamps.png`, and `d4-channel-chat.png`).
2. **Persistent floating 4-tab bar on pushed/detail/utility screens**: Appears overlapping content or sticky CTAs in `topic-detail.png`, `clubs-home.png`, `club-home.png`, `club-activities.png`, `messages.png`, `channels-tab.png`, `dm-system.png`, `account-income.png`, `activity-list.png`, and `club-activity-list.png`, whereas the mini-program hides the tab bar off-tab.
3. **Merchant role / entry failures**: Switching to merchant role (`live-merchant/merchant-entry.png`, `live-merchant/merchant-passport.png`) keeps the app in dark Player chrome (`玩家` badge), `g-merchant-node.png` is an empty `DEBUG fixture`, and `merchant/merchant-home.png` renders the `扫码` circle button with a white-on-white invisible icon.
4. **Unresolved live data / synthetic debug placeholders**: `e4-wallet-analysis.png`, `account-income.png`, `wallet/wallet.png`, `coupons/coupons.png`, `ticket/ticket-list.png`, `live-clubs/club-activities.png`, `live-home/discover-feed.png`, `live-roam/roam-home.png`, and `orders/orders-list.png` show load failures, infinite spinners, or English `DEBUG ART` / `Synthetic fixture` placeholders in current captures.
5. **Raw API path leakage & stray English labels**: `live-im/dm-system.png` and `im/im-preview.png` leak `api/im/file/message/300/authorization`; `e5b/e5b-stamp.png` and `e5b/e5b-checkin.png` show `"Done"` instead of `"完成"`.

---

## Per-Page Differences

### 1. Home (`pages/index/index`, `01-home` / `01b-home-clean` — 6 diffs)
- **Top bar**: MP displays a `CG` logo badge on the left with no search bar; App (`live-home/home.png`, `home-located.png`) adds a top search pill (`搜索路线、活动和俱乐部` + map icon), `更多玩法 v` dropdown, and a generic grey silhouette avatar instead of the player's avatar. — `DESIGN-SYSTEM`
- **Hero / onboarding banners**: MP shows the 3-card onboarding banner carousel (`成为俱乐部` / `成为商家` / `和朋友报名活动`, with `home-banner-*.gif` 404ing on local `8120`); App replaces it with a static `今天 开始一次漫游` card and `开始漫游` CTA. — `DESIGN-SYSTEM`
- **Location prompt placement & icon**: App places `首页城市定位` above the Roam card with a paperplane icon (`home.png`); MP places the location prompt below the banner row without the icon (`01b-home-clean`). — `DESIGN-SYSTEM`
- **Bottom navigation**: App uses a floating 4-tab pill bar (`探索 / 漫游 / 俱乐部 / 护照`, folding Publish into `更多玩法 v` per `more-menu.png`); MP uses a docked 5-tab bar. — `DESIGN-SYSTEM`
- **Continuation & error state**: `live-home/discover-feed.png` renders an extra `继续游戏 / 继续探索` header with a `"最近的玩法加载失败，请下拉刷新。"` error banner + `重试` button above `主题 | 活动`. — `fixed -> App/HomeFeedView.swift:101`
- **Shared seed mojibake**: UTF-8 mojibake on the seeded `E2E` free-explore title appears in both App `discover-feed.png` and DB data (`07-roam`). — `DESIGN-SYSTEM`

### 2. Discover / Community Feed (`pages/talent/list/index?tab=feed`, `02-discover` — 5 diffs)
- **Information architecture**: MP groups `帖文 | 俱乐部` under `发现` (`talent/list/index`) with a top-left `99+` bell; App separates `动态` (`main-tabs/d2-square.png`) from the Home scroll feed (`live-home/discover-feed.png`) without the `帖文 | 俱乐部` tab header. — `DESIGN-SYSTEM`
- **Card action bar**: MP shows 4 engagement actions (`like`, `comment`, `repost`, `share`); App `d2-square.png` shows only heart (`12`), comment (`3`), and a trailing chevron `>`, missing repost and share. — `fixed -> App/SquareXcxPostCard.swift:91`
- **Follow `+` affordance**: MP places a `+` follow badge on post author avatars; App `d2-square.png` omits it. — `DESIGN-SYSTEM`
- **Synthetic fixture chrome**: App `d2-square.png` shows `示例内容`, `动态来源 / 最新 v`, `Synthetic notice`, `Example walker`, and `加载更多动态`, whereas `discover-feed.png` shows a load-failed error banner. — `DESIGN-SYSTEM`
- **Tab-bar overlap**: App's floating 4-tab bar overlaps the bottom post card in `d2-square.png`, vs MP's docked 5-tab bar. — `fixed -> App/DesignSystem/CYNightTabBar.swift:166`

### 3. Topic Detail (`pages/topic/index/index?id=992001`, `03-topic-detail` / `03b-topic-detail-body` — 6 diffs)
- **First fold presentation**: MP opens on a full-viewport hero poster (`城市定向`, title, `钟楼 · 骑楼 · 码头`, `查看详情与报名` CTA); App (`live-discover/topic-detail.png`) opens directly onto the scrolled `路线详情` card view. — `DESIGN-SYSTEM`
- **Bottom bar & sticky CTA**: App `topic-detail.png` leaves the floating 4-tab bar visible directly below the white `立即报名` sticky CTA; MP hides the main tab bar and places `[去票夹] [bookmark] [share]` inline (`03b-topic-detail-body`). — `fixed -> App/TopicDetailView.swift:40`
- **Missing secondary actions**: Bookmark and share icon buttons next to the sticky CTA in MP (`03b-topic-detail-body`) are missing in App `topic-detail.png`. — `fixed -> App/TopicXcxSections.swift:145`
- **Attribution & stats bar**: MP displays `城 城瘾跑团 发布` and a 3-column stat bar (`开放时间 11.12-1.12`, `参与商家 1 家`, `已参加 2 人`); App renders a `城瘾跑团 | 承接俱乐部` card and omits `已参加 2 人`. — `DESIGN-SYSTEM`
- **Segment tab labels**: MP uses `详情 | 故事 | 路线`; App uses `详情 | 路线节点 | 路线` (accompanied by `路线总站点 6`, `未解锁章节 2`, `参与剧情` in `route-stations.png`). — `DESIGN-SYSTEM`
- **Header bar style**: MP uses a floating `<` chevron with no centered title; App adds a centered `路线详情` navigation title. — `DESIGN-SYSTEM`

### 4. Activity Detail (`pages/activity/detail/index?id=992031`, `04-activity-detail` — 6 diffs)
- **Screen capture mismatch**: `live-discover/activity-detail.png` shows `路线详情` with the floating tab bar, whereas `live-discover/activity-session-detail.png` shows `活动详情` without the tab bar. — `fixed -> App/ActivityDetailView.swift:76`
- **Missing metadata rows**: App `activity-session-detail.png` shows only 3 rows (`时间`, `集合点`, `已报名`), missing MP's `分类 —` and `主题路线 查看路线 >` rows. — `fixed -> App/E1ActivityDetailParts.swift:78`
- **Hero card composition**: MP uses a compact header card (`进行中` green pill + title + `活动时间 · ...`); App allocates a tall map-artwork box at top with `即将开始` pill and omits the timestamp line inside the hero. — `DESIGN-SYSTEM`
- **Missing body sections & ticket tier**: App `activity-session-detail.png` omits `关于这场活动`, participant avatar initials (`玩`, `玩`), and the `票种` card (`免费体验票 ¥0`, `剩余 198 张`) above its sticky `0 人已报名` + `立即报名` bar. — `DESIGN-SYSTEM`
- **Header share action**: App `activity-session-detail.png` places a Share icon button in the top-right nav bar; MP has no top-right Share icon. — `DESIGN-SYSTEM`
- **Navigation chrome**: MP puts a large `活动详情` heading below the `<` button; App centers a compact `活动详情` title in the top navigation bar. — `DESIGN-SYSTEM`

### 5. Activity Sign-up / Checkout (`pages/activity/baoming/baoming`, `05-activity-signup` — 6 diffs)
- **Presentation & title**: MP opens a pushed `结算` page with `<` back; App (`live-discover/registration-sheet.png`, `signup-sheet.png`) presents an `活动报名` sheet with a `关闭` pill after `选择场次`. — `DESIGN-SYSTEM`
- **Already-registered banner & disabled state**: MP shows the green `你已报名这场活动` + `查看我的报名` banner and disabled `你已有该票种报名` state; App shows an empty `新增参与人信息` form (`姓名`, `手机号` blank) and footer warning `请先补全参与人信息`. — `DESIGN-SYSTEM`
- **Missing ticket price resolution**: MP renders `免费体验票 ¥0 ->`, `总计 ¥0`, and `包含内容 / 票种类型 场次票`; App renders `票种 —`, `未提供独立票种，将按此活动获取报价。`, and `合计 —`. — `DESIGN-SYSTEM`
- **Missing privacy consent checkbox**: App `registration-sheet.png` omits the required MP consent checkbox (`同意将姓名、手机号提供给主办方，用于报名核验`). — `DESIGN-SYSTEM`
- **Date, address & thumbnail format**: MP formats full date/weekday (`2026年11月12日 周四 22:37`) and street address beside a dashed-route thumb; App shows `12月20日 19:00` + district beside a ticket-stub thumb. — `DESIGN-SYSTEM`
- **Bottom CTA layout**: MP renders a full-width dark pill button; App splits the footer into left `合计 —` and wide white `立即报名` pill. — `DESIGN-SYSTEM`

### 6. Play Runtime (`pages/play/index`, `06-play-runtime` / `06b-play-clean` — 5 diffs)
- **Placeholder English prep screen**: `play-parity/g-play-prep.png` still renders English `Pre-game prep` / `DEBUG fixture · synthetic transport · no player grant` placeholder text instead of MP's Chinese prep/story intro (`城瘾 · 城市定向 / E2E 城市定向·老城三章`, `开始游戏`). — `DESIGN-SYSTEM`
- **Missing location consent dialog**: App captures omit MP's `开启定位` foreground-only prompt with `先用扫码` / `开启定位` buttons before gameplay begins. — `DESIGN-SYSTEM`
- **Runtime map & task drawer layout**: App `d6/d6-play.png` renders a custom dark grid map + station callouts (`茶馆`, `灯笼门`) + bottom task drawer (`任务 2 / 5`, `120 米`, `找到灯笼门`, `我到了` CTA), while `main-tabs/d2-play.png` shows timer pill `00:12`, `继续`, and a `Synthetic journey` card. — `DESIGN-SYSTEM`
- **Visible debug controls**: `d2-play.png` and `g-play-prep.png` expose debug UI (`切换模拟账号`, refresh button, English synthetic copy). — `DESIGN-SYSTEM`
- **Local runner note**: MP runner logged `longcang-v21.ttf` CORS failure and single `<page-container>` warning (`session/view` returned `601` without an active player session). — `DESIGN-SYSTEM`

### 7. Roam Home (`pages/roam/index`, `07-roam` — 6 diffs)
- **Top header & search bar**: MP places the user avatar top-left with no search bar; App `live-roam/roam-home.png` omits the avatar, centers `漫游` + `...`, and adds a `搜索当前结果` input. — `DESIGN-SYSTEM`
- **Mode switcher style & copy**: MP uses plain text tabs `开始漫游 | 漫游护照`; App uses a dark capsule pill `走起 | 漫游护照`. — `DESIGN-SYSTEM`
- **Card copy**: MP carousel has `NO.01 开始漫游`, `NO.02 打开地图`, `NO.03 我的队伍`; App renames `NO.01` to `走起` (`走到哪，雾散到哪`). — `DESIGN-SYSTEM`
- **Error / empty state vs live list**: App `roam-home.png` shows `暂时无法显示附近活动。` + `重试` + oversized `请先选择搜索区域` empty graphic, whereas MP `07-roam` renders live `附近活动` cards + `开启定位` link. — `DESIGN-SYSTEM`
- **Initial view hierarchy**: Map-first App variants (`roam/roam-go.png`, `main-tabs/d2-roam.png`) land straight on the fog/radar map (`走起 / 按住开始`, `附近 · 5` bottom sheet), whereas MP defaults to the numbered card stack (`NO.02` opens the map). — `DESIGN-SYSTEM`
- **Bottom tab bar**: Floating 4-tab pill in App vs docked 5-tab bar in MP. — `DESIGN-SYSTEM`

### 8. City (No MP player page vs `main-tabs/d2-city.png` — 3 diffs)
- **MP gap / app-only feature**: App `d2-city.png` presents a player `CITY 经营权与原回执` city-management screen (`城市经营`, `3/3 本轮剩余行动`, `0/2 持有点位`, `5 我的积分`, `开始本轮`, `Synthetic cafe` actions); MP has no player City tab or route. — `DESIGN-SYSTEM`
- **Synthetic placeholders in App**: `d2-city.png` displays a `DEBUG ART` stamp and synthetic English labels (`Synthetic official city`, `Synthetic cafe`). — `DESIGN-SYSTEM`
- **Route ownership split**: MP limits `city*` routes (`citynode/*`, `citystamp/index`) to merchant management and stamp camera. — `DESIGN-SYSTEM`

### 9. Club Home (`pages/talent/list/index`, `08-club-home` — 6 diffs)
- **Stretched `+` CTA proportion bug**: In `live-clubs/clubs-home.png`, the white `+` pill beside `创建你自己的俱乐部` is stretched vertically to excessive height; MP renders a compact dark `创建俱乐部` pill. — `fixed -> App/ClubHomeView.swift:100`
- **Top bar controls**: MP renders a bell icon with `99+` badge, centered `发现`, and underline tabs `帖文 | 俱乐部`; App shows a bell without badge, an extra refresh icon, large left `发现`, and a pill capsule `帖文 | 俱乐部`. — `DESIGN-SYSTEM`
- **Inconsistent quota banner**: App `clubs-home.png` prints `你的俱乐部：0 / 2` despite `城瘾跑团` showing `✓ 已加入` directly underneath; MP has no quota banner. — `DESIGN-SYSTEM`
- **Mixed card styles**: App mixes a compact dark row (`城瘾跑团`, `✓ 已加入`, `主题 4`) with a tall `DEBUG ART` gradient card (`执行俱乐部`); MP uses uniform `一起玩` illustrated cards. — `DESIGN-SYSTEM`
- **Search entry placement**: App separates `查找俱乐部` (`按俱乐部名称搜索`) into `d4/d4-directory.png`, whereas neither `clubs-home.png` nor MP `08-club-home` includes an inline search box. — `DESIGN-SYSTEM`
- **Tab-bar overlap**: Floating 4-tab bar overlaps the `执行俱乐部` card text in `clubs-home.png`. — `fixed -> App/DesignSystem/CYNightTabBar.swift:166`

### 10. Club Detail (`pages/club/detail/index?id=7001`, `09-club-detail` / `09b-club-detail-clean` — 6 diffs)
- **Persistent tab-bar overlap**: App `live-clubs/club-home.png` and `club-activities.png` keep the floating 4-tab bar over scrolled content; MP hides the tab bar. — `fixed -> App/ClubDetailView.swift:337`
- **Identity & membership controls**: MP overlaps a square club avatar beside `城瘾跑团` + Share button under the cover art, with `公开加入` and subtle `退出`; App places `公开加入` + `城瘾跑团` inside the purple hero, adds a separate `✓ 已加入` card, and renders a wide bordered `退出俱乐部` button under `成员身份`. — `DESIGN-SYSTEM`
- **Navigation header**: MP uses a transparent `<` chevron over `一起玩` cover art; App uses a solid `< 俱乐部详情 [refresh]` top bar (`d4/d4-detail.png` also adds a large `俱乐部详情` heading). — `DESIGN-SYSTEM`
- **Join welcome modal (`欢迎加入「城瘾跑团」`)**: MP renders a draggable half-sheet with side-by-side `[知道了] [去看活动]` over the detail screen; App (`live-clubs/club-welcome.png`) opens a full-screen modal with `关闭` and vertically stacked `[去看活动]` above `知道了`. — `DESIGN-SYSTEM`
- **Activities tab spinner & missing overview cards**: App `club-activities.png` stalls on a spinner above `俱乐部活动 >`, while MP renders `俱乐部介绍`, `俱乐部主理人`, `俱乐部类型`, `所在城市`, `俱乐部勋章`, `成员 · 4`, and `本团贡献榜 · 本周`. — `fixed -> App/ClubDetailEventsSection.swift:59`
- **Cover visual**: MP shows branded `一起玩` cover artwork vs App's purple 3-person placeholder card. — `DESIGN-SYSTEM`

### 11. Club Chat / Channel (`subpackageB/pages/im/chat/index?conversationId=1&type=4`, `10-club-chat` — 5 diffs)
- **Critical dark-mode contrast / mixed-theme bug**: App `d4/d4-channel-chat.png` renders a bright white header and covenant banner (`查看公约`) above a black body where timestamps (`11-07 09:00`) and footer text (`请先在上方阅读并同意《俱乐部频道公约》后再发言。`) appear near-black on black and barely legible; MP maintains a consistent dark theme. — `fixed -> App/ClubChannelMessagingView.swift:35`
- **Header `更多` pill**: MP shows a `[更多]` pill button; App uses only a `...` icon. — `DESIGN-SYSTEM`
- **Stub vs active composer**: App `d4-channel-chat.png` shows a single read-only `F` stub bubble and locked composer; MP shows live club bubbles (`城瘾跑团 · 昨天 22:38`) and an active `+ | 发消息... | ↑` composer. — `DESIGN-SYSTEM`
- **History banner**: App displays `↑ 加载更早的频道消息` at top; omitted in MP when transcript fits cleanly. — `DESIGN-SYSTEM`
- **Header alignment**: Centered club name in MP vs left-aligned icon + `#club-news / 公告 · 只读` in App. — `DESIGN-SYSTEM`

### 12. IM Messages List (`subpackageB/pages/im/list/index`, `11-im-list` — 6 diffs)
- **Top collaboration invite block**: App `live-im/messages.png` devotes the top half to a `合作邀请` card, `搜索` bar, `邀约提醒` switch, `收到 | 发出` toggle, and empty artwork; completely absent in MP `11-im-list`. — `DESIGN-SYSTEM`
- **Filter tabs & counts**: MP uses `收件箱 99+ | 发件箱`; App uses 3 capsule pills `全部 2 | 频道 | 私信 2`. — `DESIGN-SYSTEM`
- **Missing DM thread & generic preview copy**: App `messages.png` misses the active player DM thread (`玩家小城 r2 smoke ping 99+`) visible in MP `11-im-list`, and replaces `系统通知` real preview copy with generic `打开会话查看消息`. — `DESIGN-SYSTEM`
- **Tab-bar overlap**: App `messages.png` and `live-im/channels-tab.png` keep the floating 4-tab bar visible over list/empty state (`channels-tab.png` graphics/text collide with the tab bar); MP hides the tab bar. — `fixed -> App/MessagingHomeView.swift:23`
- **Row actions**: MP displays inline/swipe action labels (`标已读`, `免打扰`, `删除`); missing in App list rows. — `DESIGN-SYSTEM`
- **Header chrome**: MP uses compact `< 消息`; App puts `< [envelope] ... [compose]` above a large `消息` heading. — `DESIGN-SYSTEM`

### 13. IM Chat / DM Conversation (`subpackageB/pages/im/chat/index?conversationId=2&type=1`, `12-im-chat` — 5 diffs)
- **Raw API path leak**: App `live-im/dm-system.png` and `im/im-preview.png` render internal API paths inside system message cards (`文件授权 可预览 api/im/file/message/300/authorization`, `视频授权`, `语音消息`). — `fixed -> App/IMRecipientPreviewRow.swift:219`
- **Missing active 2-way player DM**: App `live-im/` only captures read-only `系统通知 不支持回复` and lacks an active `+ | 发消息... | ↑` DM thread like MP `12-im-chat`. — `DESIGN-SYSTEM`
- **Bottom tab-bar persistence**: App `dm-system.png` keeps the floating 4-tab bar visible; MP `12-im-chat` is full-screen. — `fixed -> App/MessagingHistoryView.swift:194`
- **Header metadata**: MP shows centered `玩家小城` + `[更多]` pill; App shows avatar + `系统通知` + `(i)` + `...`. — `DESIGN-SYSTEM`
- **Bubble layout**: App groups messages inside a wide `城瘾小助手` card instead of individual chat bubbles. — `DESIGN-SYSTEM`

### 14. Passport / Me (`pages/member/index/index`, `13-passport-me` — 7 diffs)
- **Header & backdrop layout**: MP uses a blurred full-bleed photo header, centered `主页` title, avatar with edit pencil, `玩家二号`, `连续探索：0天`, inline 3 counters, and full-width white `票夹` CTA; App (`live-passport/passport-me.png`) uses a dark `护照` card container, boxed counters, dark `票夹`, and inset `账户余额 0.00` card. — `DESIGN-SYSTEM`
- **Missing 4 sub-tabs**: App Passport omits MP's `我的 | 帖文 | 成就 | 关于` tab strip. — `DESIGN-SYSTEM`
- **Fold-1 section order**: MP puts `我的订单` (with live `待核销` order card), `我的项目`, `视频悬赏`, and `我的资产` on fold 1; App (`passport-me.png`, `passport-scrolled.png`) puts 3 circular shortcuts (`票夹`, `账户收益`, `消息`), `印章 0/12`, `漫游记录 >`, `徽章 / 成长中心 >`, and list rows (`我的计分申诉`, `我的订单`, `参与人信息`). — `DESIGN-SYSTEM`
- **Account/order mismatch**: App capture uses `平台运营` (`0.00`) with no active orders shown, vs MP `玩家二号` with an active `待核销` order. — `DESIGN-SYSTEM`
- **Missing streak & avatar edit affordance**: App omits `连续探索：0天` and the avatar edit pencil, displaying a pin icon `—`. — `DESIGN-SYSTEM`
- **Missing `消息` circular shortcut on MP fold 1**: App surfaces a `消息` button in Passport; MP places notification entry on Discover (`99+` bell). — `DESIGN-SYSTEM`
- **Settings gear placement**: Top-left in MP vs top-right in App. — `DESIGN-SYSTEM`

### 15. Wallet / Account Earnings (`subpackageA/pages/assetcenter/earnings/index`, `14-wallet-earnings` — 6 diffs)
- **Error banner & broken balance**: App `live-wallet/account-income.png` displays a top error banner (`创作者应计 / 收益暂不可用 / 原因 — / 稍后重试`) and `— 0` instead of MP's `账户收益（元） ¥0.00`. — `fixed -> App/WalletCommerceViews.swift:185`
- **Missing `提现` primary button**: App renders 3 circles (`收益明细`, `分析`, `更多`) vs MP's 4 (`[提现, 明细, 分析, 更多]`). — `DESIGN-SYSTEM`
- **Missing empty illustration & CTA**: MP renders an empty artwork + white `去发布路线` pill CTA; App places text above the action circles and shows `本月收入明细 / 这个月还没有收入` below. — `DESIGN-SYSTEM`
- **Tab-bar overlap**: Floating 4-tab bar sits over the bottom of `account-income.png`; hidden in MP. — `fixed -> App/WalletCommerceViews.swift:136`
- **Fragmented wallet cards**: `account-settings/e4-wallet-assets.png` splits `结算进度` warnings, `余额流水`, and `积分明细` across separate blocks. — `DESIGN-SYSTEM`
- **Back icon styling**: Circular back `<` styling in App vs MP chevron. — `DESIGN-SYSTEM`

### 16. Wallet / Asset Analysis (`subpackageA/pages/assetcenter/analysis/index`, `15-wallet-analysis` — 4 diffs)
- **Load failure screen**: App `account-settings/e4-wallet-analysis.png` fails to load (`! 分析数据加载失败` + `重试`) instead of rendering charts. — `fixed -> App/WalletCommerceFixtureHost.swift:32`
- **Missing segmented toggle**: `收入 | 提现` pills present in MP are absent in App. — `DESIGN-SYSTEM`
- **Missing 6-month chart card**: MP's `11月收入 ¥0.00` bar chart (`6月..11月`) is missing in App. — `DESIGN-SYSTEM`
- **Missing `收入来源` & `<` back**: MP's `收入来源` card and `<` back button are absent in `e4-wallet-analysis.png`. — `DESIGN-SYSTEM`

### 17. Search Home (`pages/search2/index`, `16-search` — 6 diffs)
- **Modal vs pushed presentation**: App `live-discover/search.png` presents as a modal sheet with a `关闭` pill; MP pushes a page with a `<` back arrow. — `DESIGN-SYSTEM`
- **Filter icon label**: App displays only `[⊞]` icon next to search; MP renders `[⊞ 筛选]`. — `DESIGN-SYSTEM`
- **Placeholder copy**: MP reads `搜索主题、活动、俱乐部、商家`; App reads `搜索路线、活动和俱乐部`. — `DESIGN-SYSTEM`
- **Category grid cards & icons**: MP uses compact dark pills with line icons; App uses tall gradient cards with mismatched translucent background icons (`夜游` shows music note, `咖啡` shows moon, `解谜冒险` shows camera). — `DESIGN-SYSTEM`
- **Missing bottom map-search CTA**: MP renders `在地图上找活动与主题节点` at the bottom of the initial viewport; missing on `search.png`. — `DESIGN-SYSTEM`
- **`推荐搜索` chip grid density**: MP packs chips tightly across ~2 rows (`5+3`); App lays them out in fixed 3-column wide pills. — `DESIGN-SYSTEM`

### 18. Search Results (`pages/search2/result/index?keyword=老城`, `17-search-results` — 5 diffs)
- **Offline synthetic fallback**: App `main-tabs/d2-search-results.png` falls back to an `示例内容` offline screen showing only 1 `Synthetic culture` category tile. — `DESIGN-SYSTEM`
- **Missing 8 result tabs**: MP displays `全部 | 主题 0 | 活动 0 | 帖文 0 | 俱乐部 0 | 商家 0 | 主题模板 1 | 玩法模板 1`; missing in App. — `DESIGN-SYSTEM`
- **Missing live template result cards**: MP displays `主题模板 E2E 主题模板·黄浦老城慢游三站` and `玩法模板 E2E 模板库·老城钟楼暗号` with `查看` buttons; missing in App. — `DESIGN-SYSTEM`
- **Missing footer & refresh control**: MP shows `内容已加载完` + `刷新搜索结果` outline button; omitted in App. — `DESIGN-SYSTEM`
- **Extra bottom control in App**: `d2-search-results.png` includes an extra `更多查找方式 v` button. — `DESIGN-SYSTEM`

### 19. Search Map (`pages/searchmap/index`, `18-search-map` — 5 diffs)
- **State divergence (live empty vs synthetic pins)**: MP `18-search-map` displays the live empty overlay (`这一带还没有活动` + `定位` pill); App `d6/d6-search.png` shows synthetic map pins (`苏州河`, `夜色外滩`, `老城厢`) and a `查看全部 8 个结果` sheet CTA. — `DESIGN-SYSTEM`
- **Missing top-bar filter funnel**: MP includes a `[Y]` filter button beside search; App puts a `定位` arrow in the top-right header instead. — `DESIGN-SYSTEM`
- **Top-bar layout**: Element sequence `<`, search input, filter in MP vs `<`, search input, locate in App. — `DESIGN-SYSTEM`
- **Missing empty-area prompt**: App `d6-search.png` lacks the `这一带还没有活动` empty prompt state. — `DESIGN-SYSTEM`
- **Map canvas**: MP uses map tile rendering vs App's custom dark grid + river line vector layer. — `DESIGN-SYSTEM`

### 20. Community Post Detail (`pages/square/detail/index?id=992571`, `19-community-post` — 5 diffs)
- **Missing Post Detail screen**: No dedicated `square/detail` screenshot exists in App `docs/release/screens/` (only the feed in `main-tabs/d2-square.png`). — `DESIGN-SYSTEM`
- **Missing author `关注` & `...` header controls**: Visible in MP post header, absent on `d2-square.png`. — `DESIGN-SYSTEM`
- **Action row disparity**: MP shows 4 controls (`like`, `comment`, `star`, `share`); `d2-square.png` shows only 2 (`heart 12`, `comment 3`). — `DESIGN-SYSTEM`
- **Missing comments section & composer**: MP shows `还没有评论` illustration and sticky `留下你的评论` input bar; unverified/absent in App captures. — `DESIGN-SYSTEM`
- **Copy cleanliness**: MP shows full author post copy vs `Synthetic notice` tags on `d2-square.png`. — `DESIGN-SYSTEM`

### 21. Rewards Store / Passes (`subpackageMember/market/passes/index`, `20-rewards-store` — 6 diffs)
- **Missing `通行证` Passes hub**: App `wallet/wallet.png` hangs on a spinner, `account-settings/e4-purchase.png` is a single bundle sheet (`Old Town Night Walk bundle ¥199.00`), and `e4-wallet-points.png` is a points ledger (`340 积分`), with no unified Passes hub. — `DESIGN-SYSTEM`
- **Missing `礼品` tab**: MP provides `可购买 | 我的订单 | 礼品`; missing in App. — `DESIGN-SYSTEM`
- **Missing `游戏主题库 >` card**: Present at top of MP `20-rewards-store`, absent in App. — `DESIGN-SYSTEM`
- **Embedded vs split points summary**: MP embeds `积分 500` + `积分记录 >` in the hub; App splits points into `e4-wallet-points.png` with English fixture items. — `DESIGN-SYSTEM`
- **Pass card vs fixture list**: MP displays a warm bronze `通行证 1 个主题全部可玩 >` card; `e4-purchase.png` shows a `DEBUG ART` box and English bullet items. — `DESIGN-SYSTEM`
- **Spinner hang**: `wallet/wallet.png` shows an unresolved loading indicator. — `fixed -> App/WalletCommerceFixtureHost.swift:68`

### 22. Merchant Public Homepage (`pages/merchant/profile/index?id=8001`, `21-merchant-public` — 6 diffs)
- **Missing populated Merchant Public Profile**: `play-parity/g-merchant-node.png` is an empty `DEBUG fixture · synthetic transport` view, and `live-merchant/merchant-entry.png` remains on dark player Home. — `DESIGN-SYSTEM`
- **Missing `NPC 角色` card**: MP displays `NPC 角色` (`阿猫 欢迎光临 [聊聊]`); absent in App. — `DESIGN-SYSTEM`
- **Missing social & save action row**: MP provides `关注`, `☆ 收藏节点`, Share, and `...`; absent in App. — `DESIGN-SYSTEM`
- **Missing merchant detail sections**: MP renders `品牌故事`, `品类` chip, `营业信息` (`营业状态 营业中`, `门店地址`), and `真实评价`; missing in App. — `DESIGN-SYSTEM`
- **Role badge stuck on `玩家`**: Even when signed in as `商家老板`, `live-merchant/merchant-entry.png` displays the `玩家` badge. — `fixed -> App/HomeSearchTabParityViews.swift:83`
- **Theme polarity mismatch**: MP renders a clean light theme for Merchant Public Profile; `g-merchant-node.png` is a dark empty shell. — `DESIGN-SYSTEM`

### 23. Merchant Workbench / Home (`pages/merchant/index/index`, `22-merchant-home` — 6 diffs)
- **Broken white-on-white `扫码` icon**: In `merchant/merchant-home.png`, the circular `扫码` quick-action icon renders white on a white button (invisible), whereas `客户`, `财务`, and `更多` render black icons. — `fixed -> App/MerchantHomeView.swift:581`
- **Header greeting & status pill**: MP shows `Hi，探店日样板咖啡`, green `● 营业中` pill, and top-right avatar; App shows `商家工作台` + large `Synthetic City Gear Hall`. — `DESIGN-SYSTEM`
- **Synthetic vs live TEST 8120 revenue**: `merchant/merchant-home.png` hardcodes `¥12860.50` while live TEST `8120` shows `¥1280.00` (even `live-merchant/merchant-passport.png` knows balance `1280.00`). — `DESIGN-SYSTEM`
- **Top module differences**: App leads with `有 1 笔售后待回应` + `待办事项` (`待核销 2`, etc.); MP leads with `项目 (全部 1 ->)` (`承接中 自由探索 E2E 城市定向·老城三章`) + `我的消息`. — `DESIGN-SYSTEM`
- **Missing 5-tab light Merchant bottom bar**: Present in MP `22-merchant-home`, absent in `merchant/merchant-home.png`. — `DESIGN-SYSTEM`
- **Role switch does not open Workbench**: Switching role in `live-merchant/merchant-passport.png` leaves the user in dark Player Passport instead of light Merchant Workbench. — `DESIGN-SYSTEM`

### 24. Settings (`pages/shezhi/shezhi`, `23-settings` — 6 diffs)
- **Added search, profile banner & nav change**: App `live-settings/settings.png` adds a `搜索设置` search bar, a `平台运营` profile card, and a top-right `完成` pill while dropping the `<` back arrow; MP opens directly to the `设置` list. — `DESIGN-SYSTEM`
- **Section & row differences**: MP lists `个人资料`, `城瘾玩法`, `AI 对话记录`, `营销消息与优惠券`, `帖文处置与申诉`, `投诉建议`, `我的申诉`, `发票`, `账号注销`, `退出账号`; App inserts `我的项目` (`工坊领取记录`, `已购玩法包`, `模组购买与授权`, `我的持久许可证`, `已保存的草稿`), `通知`, and `我的同意记录`. — `DESIGN-SYSTEM`
- **List visual style**: MP uses a flat dark list with hairline dividers and outline icons; App uses grouped rounded cards with colored square icons. — `DESIGN-SYSTEM`
- **Row ordering**: `我的收藏` and `隐私与定位` are pushed near the bottom in `settings-bottom.png`. — `DESIGN-SYSTEM`
- **App-only region/language rows**: `运营地区 CN` and `语言 跟随系统` appear in `settings-bottom.png` only. — `DESIGN-SYSTEM`
- **Duplicate chevron bug**: In `live-settings/settings.png`, the `平台运营` profile card renders a second faint `>` chevron outside its right border. — `fixed -> App/SettingsView.swift:29`

### 25. Publish / Templates (`pages/template/index`, `24-publish-templates` — 6 diffs)
- **No dedicated Publish/Template tab in App**: `main-tabs/ia-explore-create.png` is an empty `"Synthetic fixture: Explore root"` stub, while MP gives Templates a dedicated 5th center tab. — `DESIGN-SYSTEM`
- **Missing top icon tabs, search & bell**: `account-settings/e4-template-mine.png` lacks MP's `主题 | 玩法` top tabs, `搜索主题与玩法模板` search bar, and notification bell (showing only a single `创作玩法模板` card). — `DESIGN-SYSTEM`
- **Missing featured template carousel**: MP's `E2E 主题模板·黄浦老城慢游三站` hero card is absent in App. — `DESIGN-SYSTEM`
- **Missing filters & curated shelves**: MP's `全部 / 全部分类` chips, `全部主题 >` list, and `两小时内玩完 >` horizontal shelf are missing in App. — `DESIGN-SYSTEM`
- **Missing floating `+` FAB**: MP places a white `+` creation button at bottom-right; missing in `e4-template-mine.png`. — `DESIGN-SYSTEM`
- **Debug pills & English text**: `e4-template-mine.png` displays `示例：退出登录`, `测试：切换账号`, `测试：重新打开`, and mixed English `"Notice the city"`. — `DESIGN-SYSTEM`

### 26. Official Events List (`pages/activity/list/index`, `25-official-events` — 5 diffs)
- **Blank fixture vs full filter header**: App `live-discover/activity-list.png` shows only a `DEBUG ART` banner + `公开活动` disclaimer + blank area, missing MP's `搜索活动名称或城市` input, status pills (`进行中 | 即将 | 已结束 | 我的`), and `邀约 ->` link. — `DESIGN-SYSTEM`
- **Tab-bar persistence & collision**: App keeps the floating 4-tab bar visible in both `activity-list.png` and `live-clubs/club-activity-list.png` (colliding with the 3rd card in `club-activity-list.png`), whereas MP hides the tab bar. — `fixed -> App/OfficialEventsBrowserView.swift:56`
- **Missing count & empty state**: App `activity-list.png` lacks MP's `进行中 · 共 0 个活动` count and `(i) 暂无进行中的活动` card. — `DESIGN-SYSTEM`
- **Mojibake & repetitive actions**: `club-activity-list.png` displays UTF-8 mojibake in an event title and repetitive `举报活动` buttons on cards. — `DESIGN-SYSTEM`
- **View toggle vs status chips**: `club-activity-list.png` shows `列表 | 日历` instead of MP's status pills. — `DESIGN-SYSTEM`

### 27. Ticket Wallet (`subpackageMember/signup/index`, `26-ticket-wallet` — 6 diffs)
- **Empty / spinner states vs live ticket**: App `live-wallet/tickets.png` shows `还没有票`, and `ticket/ticket-list.png` spins forever below `App 内暂不支持支付、退款和完赛奖励。`, whereas MP `26-ticket-wallet` renders the live TEST `8120` ticket. — `fixed -> App/TicketWalletView.swift:142`
- **Header controls**: MP shows `票夹 v` dropdown and a circular `+` button top-right; `e4-tickets.png` shows a refresh icon and `live-wallet/tickets.png` shows `关闭`. — `DESIGN-SYSTEM`
- **Missing active team banner**: MP displays `我的队伍 E2E 钟楼探索小队 2/4 ->` above the ticket pass; missing in App. — `DESIGN-SYSTEM`
- **Card structure**: MP displays one large swipeable pass with `↗` corner icon and centered white `▶ 开始游戏` pill; `e4-tickets.png` uses a gradient card + slider + stacked purple stubs with `[QR]` buttons. — `DESIGN-SYSTEM`
- **Missing `▶ 开始游戏` launch CTA**: Absent across App Ticket Wallet views. — `DESIGN-SYSTEM`
- **Synthetic English copy**: `e4-tickets.png` renders `"Sample exploration ticket"`. — `DESIGN-SYSTEM`

### 28. Orders List (`subpackageMember/order/order`, `27-orders-list` — 5 diffs)
- **Synthetic orders vs TEST 8120 data**: App `orders/orders-list.png` shows `Synthetic fixture · debug only` and fake English orders (`Synthetic pending ¥1.5`, `upcoming ¥2.5`, `completed ¥3.5`), vs MP live `E2E 免费体验场·老城三章` (`实付款：¥0`). — `DESIGN-SYSTEM`
- **Missing `<` back button**: `orders/orders-list.png` provides only a refresh icon with no back button. — `DESIGN-SYSTEM`
- **Card internal layout**: MP places top category badge `城市定向` + `进行中`, large title, icon-less dark square, and bottom `实付款：¥0` + dark `查看详情` pill; App places a left gradient map thumb, status pill inside the right column, icons beside metadata, and a bright white `查看详情` pill. — `DESIGN-SYSTEM`
- **Currency formatting**: `¥0` integer vs `¥1.5`/`¥2.5` decimal format. — `DESIGN-SYSTEM`
- **Cover fallback art**: Plain dark square in MP vs gradient + map icon in App. — `DESIGN-SYSTEM`

### 29. Growth Center (`subpackageP3/pages/growthcenter/index/index`, `28-growth-center` — 5 diffs)
- **Critical dark-mode contrast bug**: In `d4/d4-growth.png`, player name, `640`, `总积分榜·第12名`, `我的足迹` labels, `探索值/徽章/完成主题/累计距离`, and `我的徽章` render in near-black text on a near-black background; MP renders crisp white text. — `fixed -> App/GrowthCenterView.swift:15`
- **Missing `<` back & title**: App replaces `<` + `成长中心` with a bright white `示例内容` pill and refresh icon. — `DESIGN-SYSTEM`
- **Rank card copy**: App adds `TOP20%` next to rank; MP shows clean `总积分榜 · 第 2 名 | 查看榜单 >`. — `DESIGN-SYSTEM`
- **Metric units**: MP appends units inline (`0 EXP`, `0 枚`, `1 个`, `0 km`); App moves `(km)` into the label and leaves `2,450` unitless. — `DESIGN-SYSTEM`
- **Badges footer**: MP shows empty `还没有点亮任何徽章` + white `去探索` CTA; App shows `Sample explorer badge` + `查看获得时刻`. — `DESIGN-SYSTEM`

### 30. Leaderboard (`subpackageP3/pages/growthcenter/leaderboard/index`, `29-leaderboard` — 5 diffs)
- **Critical dark-mode contrast bug**: In `d4/d4-leaderboard.png`, the `完整排行榜` header, podium names (`Sample South/North/East`), and `#2`/`#3` scores (`850`, `800`) render black-on-black and are nearly unreadable; MP uses white names and gold/amber scores. — `fixed -> App/GrowthLeaderboardView.swift:185`
- **Missing `<` back & readable header**: `d4-leaderboard.png` shows a bright white `示例内容` pill and refresh icon instead of `<` + visible title. — `DESIGN-SYSTEM`
- **Default active tabs**: App highlights `周榜` + `成长榜`; MP defaults to `总榜` + `积分榜`. — `DESIGN-SYSTEM`
- **Podium avatars & `[我]` tag**: MP uses illustrative portraits and a yellow `[我]` badge; App uses single-letter `S` circles and a dark grey `[我]` pill. — `DESIGN-SYSTEM`
- **Score layout**: MP displays `500 积分` on one line; App stacks `750` above `积分`. — `DESIGN-SYSTEM`

### 31. Badge Wall (`subpackageP3/pages/badge-wall/index/index`, `30-badge-wall` — 6 diffs)
- **Critical mixed-theme & contrast bug**: In `d4/d4-badges.png`, the ring count `2` and section headings (`城市身份卡`, `城市纪念章`, `成长成就`) are black-on-black, while `列表 | 静态墙`, summary chips (`2 已收集`, `1 未解锁`), and badge rows render as blinding white light-mode cards on a dark screen. — `fixed -> App/ObjectBadgeViews.swift:54`
- **Text truncation**: `d4/d4-badges.png` clips titles (`Fixture city meda`, `Fixture achievemen`). — `DESIGN-SYSTEM`
- **Three-way layout split**: `d4/d4-badges.png` (light rows) diverges from `e5b/e5b-badge-wall.png` (2-column dark grid) and MP `30-badge-wall` (dark empty state + `去探索` CTA). — `DESIGN-SYSTEM`
- **Missing `<` back & title**: Absent in `d4/d4-badges.png` (`e5b/e5b-badge-wall.png` shows `徽章`). — `DESIGN-SYSTEM`
- **Empty-state CTA**: MP provides `还没有点亮勋章` + `去探索`; App displays synthetic fixture items. — `DESIGN-SYSTEM`
- **English badge copy**: `Fixture ...`, `Night Owl`, `Market Regular` appear in App captures. — `DESIGN-SYSTEM`

### 32. Stamp Album (`subpackageP3/pages/stamp-album/index/index`, `31-stamp-album` — 5 diffs)
- **Critical dark-mode contrast bug**: In `d4/d4-stamps.png`, progress `3`, title `集邮册`, subtitle `已集齐 3 枚城市印章`, `最近集到`, `3 枚`, and `示例内容` pill text render in black on dark background. — `fixed -> App/RoamStampViews.swift:137`
- **Missing 3-tab switcher & `<` back**: MP's `勋章 | 邮票 | 藏品` tabs and `<` back arrow are missing in `d4/d4-stamps.png`. — `DESIGN-SYSTEM`
- **Bright white frames & debug stamps**: `d4/d4-stamps.png` injects white cards tagged `DEBUG ART` (`Synthetic city stamp NO. 0901`). — `fixed -> App/RoamStampViews.swift:286`
- **Empty-state camera CTA**: MP renders `0 枚`, `还没有邮票`, and a white `打开集邮相机` pill; App relies solely on the top-right camera icon. — `DESIGN-SYSTEM`
- **Card hierarchy**: `d4/d4-stamps.png` inserts a swipeable `最近集到` hero card above a 2-column grid. — `DESIGN-SYSTEM`

### 33. Roam POI Detail (`subpackageRoam/poi-detail/index?poiId=992522`, `32-roam-poi-detail` — 5 diffs)
- **Missing dedicated POI Detail sheet**: App `roam/roam-sheet-half.png` shows the nearby POI list and `e5b/e5b-checkin.png` shows post-checkin (`签到成功`), with no pre-challenge `节点详情` screen. — `DESIGN-SYSTEM`
- **Missing challenge block**: MP shows `漫游 · 到店互动 / 钟楼刻年·暗号问答 / 文字作答`; absent in App captures. — `DESIGN-SYSTEM`
- **Missing action bar & sticky footer**: MP provides 3 mini buttons (`收藏`, `导航`, `投一张`) and a sticky dual footer (`导航` + `开始挑战`); missing in App. — `DESIGN-SYSTEM`
- **Missing `品牌故事` & `基本信息`**: MP displays merchant details (`商家名称`, `品类 咖啡`, `收费方式 免费承接`); missing in App. — `DESIGN-SYSTEM`
- **Fixture POI names**: `roam-sheet-half.png` displays synthetic English names (`Dongmen Night Market`, `Laojie Teahouse`) instead of live TEST `8120` POIs. — `DESIGN-SYSTEM`

### 34. Team Detail (`pages/team/detail/index?teamId=1`, `34-team-detail` — 5 diffs)
- **Empty placeholder screen**: App `play-parity/g-team-trail.png` shows only `Team trail · consent` (`DEBUG fixture · synthetic transport`). — `DESIGN-SYSTEM`
- **Missing status & schedule metadata**: MP renders `队伍详情`, `已结束`, `r2 smoke team`, `公开招募`, `1 / 4 当前成员`, and `11月12日 14:37 场次开始`. — `DESIGN-SYSTEM`
- **Missing visual slot roster**: MP renders 4 circular member slots (captain + 3 dashed `+` slots), `持有效票 1`, and `邀请已失效`. — `DESIGN-SYSTEM`
- **Missing `队伍成员` card**: MP lists `玩家二号 / 队长`; absent in App. — `DESIGN-SYSTEM`
- **Missing `队伍进度` matrix**: MP tracks `全队已完成 0 / 6 个节点` across all 6 route nodes; absent in App. — `DESIGN-SYSTEM`

### 35. Coupon Wallet (`subpackageMember/coupon-wallet/index`, `35-coupon-wallet` — 4 diffs)
- **Skeleton/spinner hang**: App `coupons/coupons.png` is stuck on skeleton bars + spinner dot, whereas MP renders live TEST `8120` coupons (`RW TEST pledge coupon / 已使用 / 上海市黄浦区咖啡 / 有效期至 2026.12.31`). — `fixed -> App/AccountCollectionCouponsView.swift:14`
- **Extra search bar**: App renders a `搜索优惠券` input above tabs; MP has no search bar. — `DESIGN-SYSTEM`
- **Header layout & title**: MP shows `<` back + left large `优惠券`; App centers `我的优惠券` with a top-right refresh button and no `<`. — `DESIGN-SYSTEM`
- **Filter pill treatment**: App outlines all filter pills with a divider line beneath; MP highlights only the active white pill alongside plain text tabs. — `DESIGN-SYSTEM`

### 36. Favorites (`pages/mylike/mylike`, `36-favorites` — 5 diffs)
- **Load failure + synthetic fallback**: App `account-settings/e4-favorites.png` shows `"我的广场 / 列表没有读出来，请重试"` + `重试` and injects `示例内容` English synthetic post cards, whereas MP shows a clean empty state (`暂无收藏的帖文` + illustration). — `DESIGN-SYSTEM`
- **Missing `据点` tab**: MP offers 3 tabs (`帖文 | 主题 | 据点`); App offers 2 (`帖文 | 主题`). — `fixed -> App/AccountCollectionFavoritesView.swift:30`
- **Missing `<` back button**: `e4-favorites.png` has a top-right refresh button and no back arrow. — `DESIGN-SYSTEM`
- **Tab visual style**: Underline tabs in MP vs grey capsule segmented bar in App. — `DESIGN-SYSTEM`
- **Empty vs injected fallback cards**: MP keeps empty tabs clear with artwork instead of falling back to English placeholder posts. — `DESIGN-SYSTEM`

### 37. User Profile (`pages/userinfo/userinfo?id=9004`, `37-user-profile` — 5 diffs)
- **Header & layout style**: MP renders a blurred full-bleed backdrop, centered `主页`, inline `0 好友 0 关注 0 粉丝`, and action bar; App (`account-settings/e4-self-growth.png`) uses stacked dark Form/List cards (`分享身份卡`, `关系 ? —`, boxed counters). — `DESIGN-SYSTEM`
- **Missing primary social CTAs**: MP's white `关注` pill and `发消息` button are absent in `e4-self-growth.png`. — `DESIGN-SYSTEM`
- **Missing horizontal sub-tabs**: MP has `帖文 | 成就 | 关于` tabs; App uses a dropdown row `主页内容 帖文 v`. — `DESIGN-SYSTEM`
- **Synthetic debug copy**: `e4-self-growth.png` shows `"示例内容、人物、记录和结果均非真实。"` and `"Synthetic growth owner / Growth reads: 0 / Retire synthetic account"`. — `DESIGN-SYSTEM`
- **Bio vs feed-empty block**: MP displays `个人介绍 / 还没有个人介绍`; App displays `暂无动态。` + `刷新动态`. — `DESIGN-SYSTEM`

### 38. Privacy & Location (`pages/privacy/index`, `38-privacy` — 5 diffs)
- **Presentation**: MP opens a bottom sheet `隐私保护` with `×`; App (`live-settings/privacy-location.png`) pushes a full page `隐私与定位` with `<`. — `DESIGN-SYSTEM`
- **Policy link format**: MP renders underlined `查看《隐私保护指引》`; App uses a full card row `隐私政策 >`. — `DESIGN-SYSTEM`
- **Missing `首页城市自动定位` switch**: MP provides `[开启 | 关闭]` for home auto-location; absent in `privacy-location.png`. — `fixed -> App/SettingsPrivacyLocationView.swift:44`
- **Standalone location status card**: App adds a separate `正在使用定位` status card (`本机未在为漫游或游玩采集位置` + explanation); MP nests that note inside the `漫游定位` row. — `DESIGN-SYSTEM`
- **Control layout**: MP groups compact right-side pills (`[开启] [关闭]`, `[关闭]`, `[撤回]`, `查看`) in one card; App separates wide bordered buttons (`撤回漫游定位同意`) and disabled labels (`关闭附近的人位置分享`). — `DESIGN-SYSTEM`

### 39. Roam History (`subpackageRoam/history/index`, `33-roam-history` — 4 diffs)
- **Missing archive list page**: App `live-roam/walk-finished.png` captures only the post-walk finish summary, with no dedicated `漫游记录` history screen captured. — `DESIGN-SYSTEM`
- **Missing top filter pills**: MP provides `那年今日`, `月度回顾`, and `导出`. — `DESIGN-SYSTEM`
- **Missing empty state & CTA**: MP renders an empty illustration + `还没有漫游记录` + white `出发第一次漫游` pill. — `DESIGN-SYSTEM`
- **Missing header chrome**: MP `<` back + `漫游记录` title. — `DESIGN-SYSTEM`

### 40. Stamp Camera (`subpackageRoam/citystamp/index`, `39-city-stamp` — 4 diffs)
- **Missing camera viewfinder screen**: App `e5b/e5b-stamp.png` shows only the post-stamp confirmation (`盖章成功`). — `DESIGN-SYSTEM`
- **English CTA leak (`"Done"`)**: Both `e5b/e5b-stamp.png` and `e5b/e5b-checkin.png` render an English `"Done"` button instead of `"完成"`. — `fixed -> App/DesignFixtures/E5bFixtures.swift:20`
- **Missing camera controls & permission fallback**: MP renders inline `相机无法打开，去设置里检查权限`, shutter circle, zoom `↙↗`, and camera-flip button. — `DESIGN-SYSTEM`
- **Card container**: Rounded viewfinder card with top-left `×` in MP vs full-screen celebration gradient in `e5b-stamp.png`. — `DESIGN-SYSTEM`
