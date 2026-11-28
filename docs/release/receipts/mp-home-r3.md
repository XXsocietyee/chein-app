# mp-home r3 — Tab 首页 against the mini-program

Branch `mp/r3-home` from `origin/ui/combined-r7`. Brief: `design/handoff-r2:docs/briefs/round3-1127.md` (row `mp-home`), rules from `round2-1127.md`, principles `design-principles.md`.
MP source: `origin/mp-source:chengyinhub-xcx` (snapshot of hengyin master 2026-11-24). Pages read: `pages/index/index.{wxml,js}`, `utils/index/{home-action-banner,feed-card}.js`, `pages/activity/list/index.wxml`, `subpackageMember/components/cy/scene-play-activity-detail/index.wxml` (what `pages/activity/detail` hosts), `pages/topic/index/index.wxml`.

Gates (last run on the tip, r3 continue): `tools/generate_project.py` OK · `tools/check_scaffold.py` PASS · `tools/check_a11y_lint.py` PASS (0 new) · `tools/check_typography_lint.py` PASS · `tools/contract_ratchet.py --check` new 0 (re-arm run: the one new raw-colour hit, the avatar ring `Color(.systemBackground)`, fixed to `.background`). No Swift compiler here: edits mirror existing patterns; nothing deployed. Merchant features and the story-flow theme untouched.

Strings: `docs/port/strings/mp-home-r3.json` (6 keys; r3 continue added `activity.meetingPoint.openMaps`, `activity.hero.when %@`, en + zh-Hans) merged into `Resources/Localizable.xcstrings`: `homeFeed.type.orienteering` 城市定向 / City orienteering, `homeFeed.type.freeExplore` 自由探索 / Free exploration, `homeFeed.startingSoon` 即将开始 / Starting soon, `homeFeed.loadingMore` 正在加载更多 / Loading more…. (`homeIndex.logo` from the re-arm was removed again in round 3 continue — the logo bar item is gone.)

## MP sections top-to-bottom vs native

### `pages/index/index` → `App/HomeFeedView.swift` (+ `HomeHeroHeaderSectionView` in `App/HomeSearchTabParityViews.swift`)

MP order: `sec-hero` (action-banner swiper, logo, greeting, 玩家 · 城市, avatar) → `v3-locprompt` → `sec-reco` 编辑精选 → `sec-nearby` 附近活动 → `sec-upcoming` 即将上线 → `sec-feed` 主题 / 活动.

| # | Difference | Status |
|---|---|---|
| 1 | Action banners were folded into a "More ways to play" menu; MP shows them as the hero swiper. | **Fixed** — paging poster shelf (`ScrollView` + `.scrollTargetBehavior(.paging)`, poster + `.headline` title, one tap opens the route), `homeIndex.actionBanner.<id>` ids kept. Owner-Q9 extra items (templates, project editor) stay in the menu, shown only when present. |
| 2 | Banner order was 成为俱乐部 → 成为商家 → 和朋友报名活动; MP 1121 N1 is 和朋友报名活动 → 成为俱乐部 → 成为商家. | **Fixed** in `Core/HomeSearchTabParity.swift` `fixedActionBanners`; 3 Swift tests updated to the MP order (`HomeSearchTabParityTests`, `PlayerReleaseGateTests`, `ProfileParticipantValidationAppTests`). Release still hides 成为商家 (`playerActionBanners`). |
| 3 | 继续游戏 / 继续探索 continuation section sat between the hero and the location card; not on the MP home. | **Fixed** — not rendered on 首页 (host still loads it; `PlayContinuationBannerView` kept for other callers/tests). |
| 4 | Discovery banner shelf (`/banner` read) between 附近活动 and 即将上线; MP: "固定行动 Banner 不再请求后台随机图". | **Fixed** (section removed). **Re-arm:** `HomeFeedModel.loadMissing` no longer reads `/banner` or the category list on resume/refresh (MP `index.js` reads neither); `schedule(.banners/.categories)` / `loadBanners` / `loadCategories` stay for explicit callers. Unit tests edited to match (see re-arm section). |
| 5 | Today card + pass-store card after the infinite stream; neither is on the MP home. | **Fixed** — removed from 首页. `MotionTourTests.testTour1…` starts at the rails now (Today step removed). Widget publishing of the next ticket in the host is unchanged. |
| 6 | Location consent card came after continuation; MP puts it right under the hero. | **Fixed** (follows from 3). |
| 7 | 我的地盘 city rail under 编辑精选 — not in MP. | **Kept** — explicit owner request (round-1 Q1, City Monopoly). |
| 8 | 编辑精选 capped at 12; MP `_buildRecoHero` shows 5. | **Fixed** (`prefix(5)`; the read already asks for 5). |
| 9 | 编辑精选 meta was date · place · price; MP `metaLine` = 「N 人已报名」 · time, else the place; no price. | **Fixed** — `railMeta`; `TopicSummary.signupCount` decoded (`signupCount‖enrollCount‖joinCount‖signUpCount`), shown with the existing `activity.pinned.going %lld` (zh 「%lld 人已报名」). MP's 🔥 emoji dropped (calm surface, P7). |
| 10 | 编辑精选 facts drawn twice (featured-facts block + a caption line), up to 4 lines, two categories. | **Fixed** — one club line + one tag row (Beta 试玩 · first category · status, MP `v3-reco-tags`); caption line removed; `featuredCategoryTags` = first category only. |
| 11 | 附近活动 meta was date · place · price; MP = time (or 进行中) · distance. | **Fixed** — `ActivitySummary.distanceMeters` decoded from `distance` (m), formatted with `Measurement…formatted(.measurement(width: .abbreviated, usage: .road))` (km in zh-Hans, miles in en-US); live rows show the 进行中 chip instead of the time. |
| 12 | 即将上线 meta was date · place · price; MP = `addressName ‖ formattedDateTime`, then countdown, fallback 即将开始. | **Fixed** — place else time; `homeFeed.startingSoon` when no start date. |
| 13 | Rail VoiceOver labels spoke the price the rails no longer show. | **Fixed** — rails speak name + their meta line (+ featured facts on 编辑精选); stream cards keep price/time/place. |
| 14 | Stream eyebrow said 主题 / 活动 (repeats the segmented picker); MP `feedTypeLabel` = 城市定向 (productType 1) / 自由探索 (2) / none. | **Fixed**. |
| 15 | Load-more sentinel was a bare spinner; MP `loading-more` 正在加载更多 (P10). | **Fixed** — `ProgressView("homeFeed.loadingMore")`; first-page load keeps 正在加载…. |
| 16 | 首页 search field + map button in the bar; MP home has no search. | **Not changed** — owner Q9 / P18 search lane (`design/r3-search`) owns it. |
| 17 | Empty / error / no-more states (暂时没有主题/活动, per-rail 加载失败 + 重试, · 没有更多了 ·, 正在更新…). | Already matched; no change. |

### `pages/activity/list/index` (banner 和朋友报名活动) → `App/OfficialEventsBrowserView.swift` / `OfficialEventCard`

| Difference | Status |
|---|---|
| Card meta order was city → countdown → participants; MP `oe-meta` = time · city · N 人参与. | **Fixed** (`App/OfficialEventComponents.swift`). |
| Search → chip tabs → summary row → list; 我发布的 / 邀约 links in the toolbar (no WeChat capsule). | Matches (toolbar placement is the prior documented native choice). |
| 首页 opened the list as a sheet (with 关闭); MP `navigateTo('/pages/activity/list/index')` is a page. | **Fixed (r3 continue, OWNER RULE 2)** — `App/SessionHomeFeedView.swift`: `.navigationDestination(isPresented: $showsOfficialEvents)` pushes it onto the 首页 stack (inline title, system back, no 关闭), same as the reviewed-page route; banner and 更多玩法 entry both push. `.id(officialEventReader.scope)` and the scope reset kept. |
| MP shows 邀约 only when not loading/failed; native always shows it. | **Fixed (continue 3)** — `App/OfficialEventsBrowserView.swift`: `listLoaded` set by the loaded list's `onAppear` / cleared on `onDisappear` (MP list/index.wxml:27 `!loading && !curError`); the toolbar 邀约 link shows only then. UI test `testGuestCanBrowseButPrivateInboxRequiresLogin` waits for the list first, unchanged. |

### `pages/activity/detail` → `scene-play-activity-detail` → `App/ActivityDetailView.swift`

MP order: hero (status, title, date) → cancelled notice → facts (分类 / 集合点 / 已报名 / 主题路线) → 关于这场活动 → 主理人 → N 人已报名 → 关联玩法模板 → 票种 → 评价 → bar.

| Difference | Status |
|---|---|
| Cancelled notice came after the info card and action rows. | **Fixed** — right under the hero; contract pin in `test_activity_registration_parity_w2_06.py` updated with a one-line reason. |
| 主题路线 was a separate section after the map. | **Fixed** — directly after the facts. |
| 关联玩法模板 hidden behind "More info". | **Fixed** — between people and 票种 (also on the city-event variant). |
| Static map section (not in MP; MP 集合点 row opens the map). | **Fixed (r3 continue)** — removed from both variants; the 集合点 fact row is a `Button` that opens Maps when coordinates exist (MP `openLocation`, hint `activity.meetingPoint.openMaps` 导航到集合点 / Opens directions to the meeting point in Maps). |
| Native info card + action rows (directions / review / channel) above the facts. | **Fixed (r3 continue)** — `E1ActivityInfoCard` and `ActivityActionRows` removed from the page (the card repeated 分类 / 集合点 / 已报名 with duplicate ids; date lives in the hero, price in 票种); 写评价 stays with the reviews; the in-game channel row (native extra, joined players only) moved after the MP sections. |
| City-event variant (`App/NativeR2/CityOrientation/CityOrientationEventDetailList.swift`, behind `NativeR2Flags.cityOrientation`): map section; people / plays / reviews mounted after 票种 via `more()`. | **Fixed (r3 continue)** — map removed, 集合点 row opens Maps; new `people` / `reviews` slots put 主理人 · N 人已报名 · 关联玩法模板 between 关于 and 票种 and 评价 right after 票种; channel after the MP sections. |

| Hero (`E1ActivityHero`, `App/E1ActivityDetailParts.swift`): status + price chips, title, starts-in, place; MP `activity-hero` = status badge, title, 「活动时间 · start - end」. | **Fixed (r3 continue)** — price chip removed (price is in 票种 / the footer), place line replaced by the MP date line (`activity.hero.when %@` 活动时间 · %@ / %@, id `activity.detail.when`); the place is the 集合点 fact right under the hero. Live starts-in line kept (optimization). Date helper extracted to `E1ActivityWhen`. |

Contract pins updated with one-line reasons (r3 continue): `test_activity_registration_parity_w2_06.py` (fold order without the info card/map; meta has exactly one Button = MP `openLocation`), `test_activity_design_structure.py` (facts instead of the map in the order; no map / info card in the fold), `test_accessibility_hardening_wave.py` (no embedded map; meeting-point hint), `test_activity_reviews.py` (city list: people < 票种 < reviews < more, no map).

### `pages/topic/index/index` (编辑精选 / 主题 target) → `App/TopicDetailView.swift`

MP 详情: name + subtitle → 参与商家 → 开局前准备 (joined) → 节点介绍 → 活动内容 → 出发前 → 场次 (explore) → 参与品牌 → 组队 → 评价. MP 故事: 人物 → 章节/护照 → 主要角色.

| Difference | Status |
|---|---|
| 开局前准备 sat after 组队. | **Fixed** — after 参与商家, before 节点介绍. |
| Venue/address card in 详情; MP owner V-22b removed it. | **Fixed** (removed). |
| 人物 cast row was in 详情. | **Fixed** — leads 故事 (above 章节). The 故事 tab anchor stays on 章节 (`.id(TopicXcxTab.nodes.anchor)` is pinned). |
| 主要角色 (G6 characters) was mid-详情. | **Fixed** — closes 故事, before 路线. |
| Owner rows (转为正式主题 / 移交给俱乐部承接) mid-page; MP has them under the hero / in the Beta block. | **Fixed (re-arm, exact MP placement)** — inside the hero section above the stat bar and tabs: 移交给俱乐部承接 right after the hero (MP `topic-transfer-entry`, index.wxml:126), 转为正式主题 inside the Beta block under the badge (index.wxml:138); both `.bordered` `.small`. The separate 主题运维与快捷资料 section is gone; ids `topic.transferClub.open` / `topic.graduateBeta.open` kept. |
| 我的游玩记录 row, topic.availability section, audio guide. | **Kept** — MP has these as popups/hero CTA; no order conflict worth the risk. |

## Re-arm (coordinator visual check 13:34 UTC, build 86d15ee7b, `d2-home`, zh-Hans)

Merged `origin/ui/combined-r7` (clean). MP `pages/index/index.wxml` `sec-hero`: "Banner 顶到页面顶部，头像浮层，白点在图最底部".

| Coordinator finding | MP | Native now (`App/HomeSearchTabParityViews.swift` `HomeHeroHeaderSectionView`, `App/HomeFeedView.swift`) |
|---|---|---|
| Large title 首页 + greeting row above the banner | banner first; no title row; logo top-leading (`v3-home-logo`) | **Fixed** — with the hero, the bar is inline + transparent (`toolbarBackground(.hidden)`, `.toolbarColorScheme(.dark)`), title hidden (principal placeholder; `appNavigationTitle("homeFeed.title")` kept for back labels), MP logo mark top-leading (`homeIndex.hero.logo`, new key `homeIndex.logo` 城瘾 / Chein). Without the hero (guest fixtures, offline) the tab keeps `.large`. |
| Banner inset, rounded, no dots | full-width swiper from the top edge, `heroBannerH` 480 → 60% viewport, black stage, poster aspectFit 68% wide from 23%, title centred above the dots, top/bottom scrim, `autoplay` 5.5 s unless reduced motion | **Fixed** — List runs under the bar (`ignoresSafeArea(.container, edges: .top)` + `contentMargins(.top, 0)`, hero only); edge-to-edge 480 pt paging `ScrollView` (`scrollPosition(id:)`), black stage, poster `scaledToFit` 68% wide, MP `v3-hero-fade--action` gradient stops, white title, page dots (current = 16 pt bar) 32 pt from the bottom; autoplay every 5.5 s, off with Reduce Motion or VoiceOver. `homeIndex.actionBanner.<id>` / `.carousel` ids kept. |
| Avatar not over the banner | `v3-avatar` floats over the image, opens 我的 (`goUser`) | **Fixed** — 56 pt avatar with a background-colour ring floats on the banner's bottom-trailing edge (half over the image), same `homeIndex.hero.avatar` button → 我的. |
| Greeting row placement | `v3-hero-greet-row`: name line (display, bold), then `✓ 玩家 · 城市`; guests still get the city row | **Fixed** — directly under the banner (coordinator: "greeting row under it"); name `.title2.bold` header, then 玩家 · city menu; guests keep the city row; trailing room reserved for the floating avatar (MP `heroActionsReserve`). Native note: the MP overlays this row on the image top; under-the-banner keeps it legible on any poster. |
| City reads "Shanghai" in zh-Hans | `· {{city}}` (Chinese) | **Fixed** — `cityText` maps English names back to 上海/北京/杭州/深圳/广州/成都/全国/选择城市 in zh, and `CoreLoopCopy.tr` keeps 上海 → Shanghai in en (host may pass a roam-area label in either spelling). Fixture `d2-home` now passes 上海 like the API. |
| 即将上线 and feed tabs present in MP order | reco → nearby → upcoming → feed | Checked: `feedSection(.recommended)`, (我的地盘 owner rail), `.nearby`, `.upcoming`, `streamSection` — unchanged order. |

Test files edited for MP-driven changes (no compiler here): `Tests/AppUnitTests/HomeFeedReturnModelTests.swift` (resume/refresh read `/banner` 0 times; readiness stays `.loading` until an explicit `loadBanners`/`loadCategories`), `Tests/AppUnitTests/NormalHomeRuntimeRecoveryTests.swift` (offline home records only the page failure). `ProfileParticipantValidationAppTests` hero init unchanged (same parameters).

Gates on the tip: see the line at the top.

## Round 3 continue — OWNER RULE 2 (11-27 ~14:25): native navigation, one design system

Merged `origin/ui/combined-r7` (fast-forward). The re-arm's transparent-bar treatment is MP nav chrome, which OWNER RULE 2 forbids ("Lanes that moved a banner under a transparent nav bar must restore the standard large title").

| Re-arm change | Now |
|---|---|
| Inline transparent bar over the banner (`HomeFeedHeroChrome`: `.inline`, `toolbarBackground(.hidden)`, `.toolbarColorScheme(.dark)`, hidden principal title, MP logo item) | **Reverted** — `App/HomeFeedView.swift`: `.appNavigationTitle("homeFeed.title")` + `.navigationBarTitleDisplayMode(.large)` on every state; large top-left 首页. Logo toolbar item and `homeIndex.logo` key removed. |
| List under the status bar (`HomeFeedHeroEdge`: `ignoresSafeArea(.top)`, `contentMargins(.top, 0)`) | **Reverted** — the List keeps the system safe area under the large title. |
| 480 pt black edge-to-edge stage, top/bottom `LinearGradient` scrim, white title over the art, white dots | **Replaced** — `HomeActionBannerSlide`: 4:3 rounded card (`CYRadius.card`, continuous) inset by `CYSpacing.pageHorizontal`, poster `scaledToFit` on the dark stage, title under it in `.headline`; no gradient. Dots under the shelf in hierarchical styles (`.primary` / `.quaternary`). Paging, `scrollPosition(id:)`, 5.5 s autoplay (off with Reduce Motion / VoiceOver) and ids `homeIndex.actionBanner.<id>` / `.carousel` kept. |
| 56 pt avatar with a ring floating half over the banner (`offset`) | **Replaced** — 48 pt avatar trailing the greeting row (same `homeIndex.hero.avatar` button → 我的). |
| Greeting `.title2.bold` | `.title3.bold` — one step under the large title. |

MP content order under the title is unchanged: banner → greeting / 玩家 · city → location card → 编辑精选 → (我的地盘 owner rail) → 附近活动 → 即将上线 → 主题 / 活动 feed.

### `d2-home` fixture = exactly the MP 首页 content (r3 continue)

`App/HomeFeedFixtureSupport.swift` `HomeFeedFixtureHostView`: no continuation card (`fx-continue` removed), no Today seeding (`--design-today` plumbing and `HomeTodayFixtures.activityEvent` removed; `ticket` / `clubEvent` stay for the Today-card previews and wave fixtures), and the reader no longer serves synthetic `/banner` items to the hero fixture. `Tests/AppUITests/MotionTourTests.swift` tour 1 launches `d2-home` without `--design-today`.

## Round 3 continue (2) — 15:09 coordinator note, P21 mini bar, re-scan

Merged `origin/ui/combined-r7` (clean). Gates on `7946bc762`+: `generate_project.py` OK · `check_scaffold.py` PASS · `check_a11y_lint.py` PASS (0 new) · `check_design_consistency.py` PASS · `contract_ratchet.py --check` 52 failing / baseline 52 / **new 0**. No compiler: Swift mirrors existing patterns (`if #available(iOS 18, *), flag` as in `MotionR2Rewards`).

| MP page → native | Difference | Status |
|---|---|---|
| `pages/index/index.wxml:44` `v3-hero-mem` → `App/HomeSearchTabParityViews.swift` greeting row | Coordinator 15:09: a checkbox glyph next to 玩家. MP = a filled `--cy-color-rare` member badge + 玩家 (secondary text); role badges elsewhere are `subpackageMember/components/roleBadge` (玩家 / CLUB / 商家 / 官方 word chips). | **Fixed** — the design-system role/status label `CYStatusChip("homeFeed.player", tone: .rare, systemImage: "person.fill")` (indigo = rare; merchant viewer: `account.role.merchant`, `.info`, `storefront.fill`), id `homeIndex.hero.role`. The 16 pt MP bitmap and the en-only `person.crop.circle.badge.checkmark` are gone; the row (role + city) is one `.footnote` size. |
| `pages/activity/list/index` push (`App/SessionHomeFeedView.swift`) | The merge left two `navigationDestination(isPresented: $showsOfficialEvents)` (mine + mp-nav's). | **Fixed** — kept mp-nav's (with `.cyPushedChrome()`); one destination per binding. |
| 成为俱乐部 (`/pages/club/apply/index`) | Previous Not-done row (sheet). | **Done by mp-nav r3** — now `navigationDestination(isPresented: $showsClubApplication)` push. Row closed. |

### P21 — running activity mini bar (all tabs)

Files: new `App/ActiveSessionMiniBar.swift`; `App/QuestLiveActivityCenter.swift` (feeds the store from `show` / `redecoratePlay` / `end`, `toggleRun(kind:pause:)` = the Live Activity button path, `setPlayContext` / `clearPlayContext` mark the play screen on/off screen); `App/RoamLiveSessionView.swift` (extra `.onAppear` / `.onDisappear` lines mark the roam screen visible; pinned lines untouched); `App/PlayExperienceView.swift` (`.modifier(ActiveSessionPlayHostMarker())`); `App/QuestifyApp.swift` (`.modifier(activeSessionBar)` on each of the five tab roots, both iOS 18 `Tab` and iOS 17 `tabItem` paths).

- **State:** `ActiveSessionStore` (`@Observable`, MainActor) holds the roam / play entries exactly as last published to the Live Activity (P5: bar, HUD, island and Lock Screen are one object). Recorded before the ActivityKit authorization check, so the bar works with Live Activities off. Story audio and event countdowns are not runs and stay out.
- **Bar** (`safeAreaInset(.bottom)` above the system tab bar, material card, `CYRadius.card`): tinted icon tile (walk / flag), title (session title, else 漫游中 / 游戏进行中), one live value — `Text(timerInterval:)` while running (ticks by itself, P2), `已暂停 · mm:ss` when paused, else next-stop distance — and one control: pause / resume (`playx.run.pause` / `.resume`, 44 pt). Hidden when the tab bar is hidden or the run's own screen is up.
- **Expanded HUD** (`fullScreenCover`): roam → its own `RoamLiveSessionView` with the shared `makeRoamLiveSessionController()` (`roamLiveDestination`), games / city run → `ActiveSessionPlayHUD`: title, clock as hero (P1), the existing `PlayHUDNextStopCard` (下一站 · distance · 线索), one `.borderedProminent` pause/resume (P3). 收起 (chevron.down) top-leading.
- **Motion spec:** tap on the bar → the bar zooms into the full-screen HUD (`matchedTransitionSource(id: "activeSession.miniBar")` on the bar + `.navigationTransition(.zoom(sourceID:in:))` on the cover; the bar keeps identity as the zoom source) → tab bar, tab content and its large title stay fixed underneath → system zoom timing; bar in/out `.smooth` opacity, no custom curves → swipe down (system interactive zoom dismiss; plus a downward drag on the play HUD for iOS 17) or 收起 zooms back into the bar → **Reduce Motion:** no zoom, the cover is presented without animation and its content crossfades in (0.2 s opacity); bar appears without animation.
- Strings (en + zh-Hans, `docs/port/strings/mp-home-r3.json` + catalog): `activeSession.roam.title` 漫游中 / Roaming, `activeSession.play.title` 游戏进行中 / Game in progress, `activeSession.expand.hint` 展开实时面板 / Opens the live view, `activeSession.collapse` 收起 / Collapse.
- Known limit: leaving `RoamLiveSessionView` pauses the walk (`owner.pause()` in its pinned `onDisappear`, roam lane's behaviour), so a roam usually shows in the bar as 已暂停 with 继续; collapsing the roam HUD pauses it the same way. `PlayExperienceView` keeps the tab bar, so it carries `ActiveSessionPlayHostMarker` (own flag, separate from the map views' `setPlayContext` flag) and the bar hides while the game host is up.

### Re-scan of 首页-reachable pages (continue 2)
- `HomeFeedView`, `HomeSearchTabParityViews`, `SessionHomeFeedView`, `OfficialEvents*`, `ActivityDetailView`, `E1ActivityDetailParts`, `TopicDetailView`: no `.font(.system(size:))`, `.tracking`/`.kerning`, `Color(red:)` or transparent-bar chrome; the only `LinearGradient` is the activity hero's legibility scrim over the cover photo (functional, kept). `.cyText` uses are the shared CY wrapper.
- MP 首页 order under the large title re-checked: banner → greeting / 玩家 · city → location card → 编辑精选 → (我的地盘 owner rail) → 附近活动 → 即将上线 → feed — unchanged.

## Round 3 continue (3) — 16:37 / 16:53 coordinator sweeps

Merged `origin/ui/combined-r7` (fast-forward). No compiler/simulator here: edits mirror existing patterns. Gates: generate_project OK · check_scaffold PASS · a11y lint 0 new · design consistency PASS · contract ratchet 52 / baseline 52, new 0 (`test_global_search_category_recovery` file pin re-pinned with a one-line reason).

| Finding | Cause | Status |
|---|---|---|
| 16:53 `d2-home`: 4 s after launch the page is still dimmed under a grey overlay with a logo watermark; 编辑精选 / 附近活动 show 正在加载… | The grey + logo is the system launch screen (`Config/Info.plist` `UILaunchScreen` = `LaunchBackground` + `LaunchMark`). `AppSessionContainer` skipped the production session only for the App Store screenshot flag and a list of older fixture flags — **`--design-fixture` was not on it**, so every design-fixture launch first built the full `AppSession` (account restore, network clients) although the fixture root never shows it; the first frame came late and the screenshot caught the launch-screen fade over the first (loading) frame. The P21 mini bar is not mounted on fixture roots (only on the five session tab roots) and the sheet backdrop (`NativeR2SheetBackdrop`) is only on while a `cySheet` is presented — neither can dim a tab root. | **Fixed** — `App/QuestifyApp.swift`: `--design-fixture <id>` (same value rule as `fixtureArgument`) returns `session = nil` before any composition is built (not when a composition is injected, so unit tests are unchanged); `FixtureThemeDomainModifier` keeps its old input (`!isDesignFixture`), so fixture theming is unchanged. The fixture reader answers synchronously, so the rails replace 正在加载… on the first pass. Needs a simulator pass to confirm the first frame time. |
| 16:37 / 16:53 `d2-search`: 类别 card renders as one tall narrow pill with an icon | Category capsule = `Label` in a `.bordered` capsule inside `TemplateChipFlow`; nothing pinned the label style or its width, so the row could collapse to the icon / a wrapped name. | **Fixed** — `App/GlobalSearchView.swift`: the capsule label is `.labelStyle(.titleAndIcon)`, `.lineLimit(1)`, `.fixedSize()` (icon + name on one line at natural width; the flow wraps whole capsules). Simulator check still needed. |
| 16:37 `d2-search`: 推荐搜索 chips are Chinese in the English UI | `GlobalSearchRecommendedKeywords.china` are China-market search terms (they query Chinese content; the US market gets none via `keywords(for:)`). | **Not changed** — market data, not app copy (brief: "if they are server data, fine"). |

## Round 3 continue (4) — hourly re-scan

Merged `origin/ui/combined-r7` (fast-forward). Sweep `docs/sweeps/latest/mp-home/sheet-zh-Hans.jpg` (build 070117595) shows only the launch logo — coordinator 17:40 note: taken under archive load, not a regression; no launch-code change made from it. Gates on `3c349eef2`: generate_project OK · check_scaffold PASS · a11y lint 0 new · design consistency PASS · contract ratchet 52 / baseline 52, new 0 (the new `@AppStorage` key is catalogued in `docs/ops-safety/client-data-catalog.json`).

| MP page → native | MP sections | Difference | Status |
|---|---|---|---|
| `pages/index/index.wxml:44-63` city `cy-dropdown range="{{manualCityOptions}}"` → `App/HomeSearchTabParityViews.swift` `cityControl` | 20 cities `utils/index/home-city-location.js` CITY_OPTIONS (北京 … 合肥), no 全国 | Native menu = 全国 + 6 cities; its 全国 item was a dead tap (`selectHomeCity` returns on nationwide). | **Fixed** — menu lists the 20 MP cities in MP order (`HomeHeroCityNames.manualOptions`, 市 suffix dropped like the located label); 全国 item removed; English names for all 20 (`HomeHeroCityNames.english`, also accepts 北京市 spelling). Core `defaultSupportedCities` untouched. |
| `onManualCityChange` → `homeCity.saveLastCity` → `App/SessionHomeFeedView.swift` | city survives relaunch | Native kept the pick in `@State` only. | **Fixed** — `@AppStorage("homeIndex.manualCity")`; still a local label, never `session.roamArea`. Pin in `test_fix_r8_mp_first_pc.py` updated with a one-line reason. |
| `onTapHomeCity` (re-locate when the city came from location) | tap → `getHomeCityLocation({userInitiated})` | Native has no foreground city reverse-geocode path on 首页. | ~~Not done~~ **Fixed in continue 32** (city menu 使用当前位置, located on the device). |
| `v3-locprompt` → `App/HomeCityLocationConsentCard.swift` | title 首页城市定位 · body · 暂不定位 / 同意定位 | — | ✓ matches (GroupBox, `.bordered` / `.borderedProminent`, `ViewThatFits`). |
| `pages/search2/index` → `App/GlobalSearchView.swift` | field + 筛选 → 搜索历史 (清空) → 推荐搜索 → 类别 (loading / failed / hidden when none) → 在地图上找; 筛选 sheet 日期 / 价格 / 排序 / 重置 · 搜索 | — (submit button shown only with a keyword is the documented d2 choice) | ✓ order, copy (搜索历史 / 清空 / 推荐搜索 / 类别 / 在地图上找) and states match; swipe-to-delete a history row is the P18 addition. |
| `pages/search2/result` → same view, results branch | scope tabs → skeleton / 没能完成搜索 + 重试 / 没有找到 / 重试本页 → list → 没有更多了 · 重新搜索 | — | ✓ (`globalSearch.failed`, `globalSearch.empty`, `searchMap.retryPage`, `searchMap.endOfResults`, `searchMap.refreshResults`). |
| `pages/activity/official-*` | — | Owned and done by mp-activity (`mp-activity-r3.md` rows 13–16). | Skipped (other lane). |

## Round 3 continue (5) — 18:06 sweep (build 070117595), `rep3-activity-detail` zh-Hans + en

Screenshot: `docs/sweeps/latest/mp-home/zh-Hans-rep3-activity-detail.jpg`, `en-rep3-activity-detail.jpg`. MP: `subpackageMember/components/cy/scene-play-activity-detail/index.{wxml,js}` (hero, footer `activity-action` wxml:144-150).

| MP page → native | Difference seen | Status |
|---|---|---|
| hero `activity-hero` → `App/E1ActivityDetailParts.swift` `E1ActivityHero` + `App/NativeR2/Explore/ExploreDesignPass.swift` `ExploreStartsInLine` | An ended activity (11月21日) read 「进行中 · 还剩 已结束」 / "In progress · Ends in Ended": `TimelineView(.explicit)` with only past dates hands back a past `context.date`, so the line took the start as now. | **Fixed** — the line uses `max(context.date, Date())`; an ended activity shows no live line (status 已结束 + 活动时间 only, as MP). Also fixes the same stale line on 首页 rails. |
| hero status badge | 已结束 (neutral = `.secondary`) rendered dark grey on the black scrim — unreadable. | **Fixed** — the hero text stack resolves in `.colorScheme(.dark)` (scrim is always black), so neutral reads light grey; tones unchanged. |
| footer `activity-action` → `App/ActivityDetailView.swift` `registrationAction` | 「¥58.00 起 · 24 人已报名」 and the going stack 「24 人已报名」 said the count twice. MP footer = share + one main button. | **Fixed** — the summary line drops the count when the going stack (P6) shows it; price stays. |
| `pages/index/index` offline (per-rail `cy-error` 加载失败 + 重试, feed error) → `d2-home-offline` (`App/DesignFixtures/D2Fixtures.swift`, `App/HomeFeedFixtureSupport.swift`) | Sweep `zh-Hans-d2-home-offline.jpg`: whole page 「首页暂不可用 · 这项功能还没开通」 — the fixture passed `auth.notConfigured` (feature-off), not an offline state. | **Fixed** — new fixture scenario `offline` throws `URLError(.notConnectedToInternet)` from every rail and the feed page, so the shot shows the real MP failure states (per-rail 加载失败 + 重试, feed error). App code unchanged. |
| `pages/search2/result` → `d2-search-results` (`App/DesignFixtures/D2Fixtures.swift`) | Sweep `zh-Hans-d2-search-results.jpg` is identical to the empty search page — the fixture never ran a search, so the result list (scope tabs → rows → 没有更多了) was never shot. | **Fixed** — fixture passes `initialQuery: GlobalSearchQuery(keyword: "Lantern")` (the MP link-keyword path), so the page searches once on appear. App code unchanged. |
| footer main button 「—」 | MP `actionFor`: `isSignUp` not 0/1 → `{state:'unavailable', text:'—'}` disabled. | ✓ matches MP (fixture has no `isSignUp`). |

## Round 3 continue (6) — 18:54 sweep (build 1300a48db), mp-home sheets zh-Hans + en

Build 1300a48db predates `56f6f8aaf` (d2-home-offline) and `67f829a46` (d2-search-results), so those two tiles still show the old feature-off / empty-search shots; recheck next sweep. Merged `origin/ui/combined-r7` into `mp/r3-home` first (clean).

| MP page → native | Difference seen (screenshot) | Status |
|---|---|---|
| `scene-play-activity-detail/index.wxml:147-153` footer → `App/ActivityDetailView.swift` `registrationAction` | `zh-Hans-rep3-activity-detail.jpg` / `en-…`: footer still stacked 「¥58.00 起」 + avatar 「24 人已报名」 above the button; the count is already in the 已报名 fact row and the 「N 人已报名」 people section (3×). MP footer = share + one main button. | **Fixed** — footer is the one main button only (share stays in the toolbar). `pinnedSummary` kept for the city-event variant's 价格 fact row. |
| `index.wxml:41-43` section title 关于这场活动 → `Section("activity.about")` | zh read 活动介绍. | **Fixed** — zh-Hans `关于这场活动` (en stays "About this activity"). |
| `wave-today-club` (`App/DesignFixtures/WaveFixtures.swift`) | Bare `HomeTodayCard` + "Synthetic tap × 2" debug line. | **Not changed** — motion-only fixture; the Today card is not on the MP home and is not rendered on 首页 (row 5). |
| `d2-home` | 首页 large title, banner + dots, greeting 玩家 · 上海, 编辑精选 footnote and first card. | ✓ matches the 15:09 check. |

## Round 3 continue (7) — 19:50 coordinator sweep (build 3568fe51b), mp-home sheets zh-Hans + en

Screenshots: `docs/sweeps/latest/mp-home/sheet-en.jpg`, `sheet-zh-Hans.jpg`, `en-rep3-activity-detail.jpg`. Build 3568fe51b predates `bf305d1ba` (footer summary line removed), so the price/going line above the button is already gone on this branch. Merged `origin/ui/combined-r7` first (clean).

| MP page → native | Difference seen (screenshot) | Status |
|---|---|---|
| `scene-play-activity-detail/index.js:78-79` `actionFor` 「—」 → `App/ActivityDetailView.swift` footer | `en-rep3-activity-detail.jpg`: empty grey capsule with "—" (fixture has no `isSignUp`). The MP 「—」 is not an action (`ActivityPrimaryAction.isPlaceholder`). | **Fixed** — `showsFooter(detail)`: keeps the `registrationEnabled` gate, hides the bar for `.unavailable` unless the host footer (取消活动并退款) applies; content margin follows. Pin in `test_activity_design_structure.py` updated with a one-line reason. |
| `index.wxml:13-14` `activity-hero__fallback` → `App/E1ActivityDetailParts.swift` `E1ActivityHero` | Hero = generated "DEBUG ART" gradient + leaf glyph. MP: no image → plain subtle surface under the scrim. | **Fixed** — no safe URL → `palette.bgSurfaceSubtle`; a real cover uses `E1CoverArt` without the debug label/glyph. |
| `rep3-activity-detail` fixture (`App/ActivityFixtureSupport.swift` reviews scenario) | zh UI showed Lantern Market Quest (fixture) / Lantern Square / Walk · Food. | **Fixed** — title, place, description, categories and ticket names follow the UI language. |
| `pages/search2/result/index.wxml:31-32, 67-69` cover fallback → `App/SearchMapComponents.swift` `SearchMapCard` | `d2-search-results`: grey block with a generic stack glyph. MP fallback = the result kind icon on the subtle surface. | **Fixed** — `coverImage`: `AsyncImage` of the safe URL, else `bgSurfaceSubtle` + the kind symbol in `.secondary`, `CYRadius.md` corners. |
| `d2-search` 推荐搜索 (`App/SearchMapFixtureSupport.swift`, `App/DesignFixtures/D2Fixtures.swift`) | 骑行 / 城市 / 外滩 … in the English UI. | **Fixed** — fixtures use `GlobalSearchRecommendedKeywords.fixtureKeywords` (zh = MP China list, en = the same eight terms in English). Production market logic unchanged. |
| `d2-home` fixture (`App/HomeFeedFixtureSupport.swift`) | zh: 编辑精选 card "Sample neighborhood route", banners/category English. | **Fixed** — `HomeFixtureLanguage`: topic, activity, banner titles, category and Today candidates follow the UI language. |
| `wave-today-club` (`App/DesignFixtures/WaveFixtures.swift`) | Debug line "Synthetic tap × N". | **Fixed** — line and counter removed; the synthetic tap loop stays. |

## Round 3 continue (8) — 20:11 sweep (build a250afd77), mp-home sheets zh-Hans + en

Merged `origin/ui/combined-r7` first (clean). Build a250afd77 predates `66c41fe9e` (continue 7: dead 「—」 footer hidden, plain hero, kind-icon covers, zh fixtures, no "Synthetic tap"), so those tiles still show the old state; recheck next sweep.

| MP page → native | Difference seen (screenshot) | Status |
|---|---|---|
| `pages/index/index.wxml` `sec-hero` → `d2-home-offline` (`App/DesignFixtures/D2Fixtures.swift`) | `zh-Hans-d2-home-offline.jpg`: only 首页 + 「网络好像断开了」 + a bottom search field; banner, greeting and city are gone. MP hero is local content (fixed action banners, member info) and stays above the failed rails offline; the session host always passes it. | **Fixed** — fixture uses `HomeFeedFixtureHostView(forceHero: true, scenario: "offline")`, so the shot is what a signed-in player sees offline: banner → greeting / 玩家 · 上海 → the one offline state. App code unchanged. |
| `pages/search2/result` → `d2-search-results` (`App/SearchMapFixtureSupport.swift`) | `zh-Hans-d2-search-results.jpg`: rows "Synthetic topic / Offline Lantern", category "Synthetic culture" and keyword "Lantern" in the Chinese UI. | **Fixed** — `SearchMapFixtureLanguage`: zh rows 示例主题 / 示例活动 / 示例俱乐部 / 示例商家 with 「离线示例 · 关键词」, categories 人文 / 户外, keyword 灯笼; en keeps the pinned English values the UI tests read. |
| `pages/search2/index` → `d2-search` (`SearchMapFixtureHostView`) | `zh-Hans-d2-search.jpg` / `en-d2-search.jpg`: two UI-test capsules 「示例：游客」「示例：切换账号」 above the search title — not on the MP page. | **Fixed** — `SearchMapFixtureHostView(showsTestControls: false)` for the design fixture; the module fixture (UI tests) keeps them. |
| `onTapHomeCity` → city relocate | Still open. Native `HomeCityLocationConsentModel.agree` records consent but never locates; `api/map/reverse-geocode` is sent today only inside `SearchMapService.nearby`, and `CompositionHTTPTransport` admits map reads through `ManualMapReadRoute`, which has no reverse-geocode case. | ~~Not done~~ **Fixed in continue 32** — no reverse-geocode needed: the fix is matched on the device (`HomeCityCentre.nearest`, continue 31). |

## Round 3 continue (9) — 20:45 sweep (build bb76e327c), mp-home sheets zh-Hans + en
| MP page → native view | Difference (screenshot) | Fixed / not |
|---|---|---|
| `pages/activity/detail` → `rep3-activity-detail` (`App/ActivityFixtureSupport.swift`) | `en-rep3-activity-detail.jpg` / `zh-Hans-…`: title "Lantern Market Quest (fixture)" / 灯笼集市探索（示例）, meeting point "(fixture)", about text ends "Offline fixture copy." — debug text on screen. | **Fixed** — plain names 灯笼集市探索 / Lantern Market Quest, 灯笼广场 / Lantern Square, no fixture sentence. No test pins these. |
| `pages/search` → `d2-search` / `d2-search-results` (`App/SearchMapFixtureSupport.swift`) | `en-d2-search.jpg`: category capsule "Synthetic culture"; `en-d2-search-results.jpg`: rows "Synthetic topic" / "Offline Lantern". | **Fixed** — under `--design-fixture` only: categories Culture / Outdoors, rows Lantern Night Walk / Lantern Market Tour / Old Town Walkers, detail "Old Town · Lantern" (zh 老城 · 灯笼). UI-test runs keep the pinned "Synthetic …" values. |
| `pages/index/index` `onAddressTap`, `onHeroBannerTap` | Re-checked: feed 地点 opens Maps (`HomeFeedView.swift:939-987`); banners → 活动列表 / 成为俱乐部 / (成为商家 merchant, gated). | No change needed. |
| `d2-search` 示例内容 / Example content line under 筛选 | Honest offline-example marker (`reader.isOfflineExample`), false for the live reader. | Kept (not shown in production). |

## Round 3 continue (10) — 21:20 coordinator sweep (build 405948d58), home zh-Hans

| MP page → native view | Difference (screenshot) | Fixed / not |
|---|---|---|
| `pages/search2/result/index.wxml:31-32, 67-69` → `App/SearchMapComponents.swift` `SearchMapCard`, `GlobalTemplateResultRow` | `d2-search-results`: large grey boxes with a small kind glyph (fixture runs offline, so no cover URL ever loads). | **Fixed (P18)** — a topic / activity result is a cover card only when a safe cover URL exists (and not offline); otherwise it is a text row (kind label · title · area), no image frame. Club / merchant rows and template results drop the thumbnail the same way (templates keep the MP interaction art when `TemplateShelfArt` has one). |
| `scene-play-activity-detail/index.wxml:13-14` hero → `App/E1ActivityDetailParts.swift` `E1ActivityHero`; fixture `App/DesignFixtures/E1Fixtures.swift` | `rep3-activity-detail`: hero is an empty grey surface. | **Fixed (fixture only)** — new environment value `e1ActivityHeroFixtureCover`; `rep3-activity-detail` / `e1-activity-detail` pass the bundled MP cover `MPAsset.BannerCover.feNight` (`pages/templatedetail/art/covers/topic/fe-night.jpg`, fits Lantern Market). Production: URL cover, else the MP plain surface (unchanged). |

## Round 3 continue (11) — hourly re-scan (sweep still build 405948d58, already covered in continue 10)

Merged `origin/ui/combined-r7` first (clean). All MP pages reachable from `pages/index/index` (activity list, activity detail, topic detail, search2 index/result, club apply via mp-nav) already have rows; scan-entry targets (`pages/team/join`, `pages/userinfo/userinfo`, `pages/activity/official-detail`) are deep links → mp-nav / mp-activity.

| MP page → native view | Difference | Fixed / not |
|---|---|---|
| `pages/index/index.wxml:103-121` `v3-reco-card` → `App/HomeFeedView.swift` `HomeFeedShelfCard` / `HomeFeedShelfLockup` (`zh-Hans-d2-home.jpg`: 「Beta 试玩」 under the date) | MP card order is club (`v3-reco-club`) → tag row (Beta 试玩 · first category · status) → title → `metaLine`. Native drew cover → title → meta → club → tags. | **Fixed** — `HomeFeedShelfLockup(facts:)` draws `HomeFeedFeaturedFacts` between the cover and the title (编辑精选 only; other rails pass nil). Same footnote style, no new strings. |
| `v3-reco-meta` 「编辑精选 · 参加条件以详情为准」 per card | Native shows it once as the rail subtitle (polish-d-r1, so it never sits under the tab bar). | Kept — same copy, once per rail instead of on every card. |
| `pages/search2/index` `search-actions` → `GlobalSearchView.mapSection` | MP has only 在地图上找; native adds a 「更多查找方式」 menu (nearby / public layers / shops when not gated). | Kept — one menu row keeps native-only map entries reachable; noted for the coordinator. |

## Round 3 continue (12) — 22:11 sweep (build 8fa84e4d3), mp-home sheets zh-Hans + en

Sweep build predates continue 11 (编辑精选 card order); home / offline / activity detail / wave-today-club read clean in both languages.

| MP page → native view | Difference (screenshot) | Fixed / not |
|---|---|---|
| `pages/search2/result/index` → `d2-search-results` (`App/SearchMapFixtureSupport.swift`) | `zh-Hans-d2-search-results.jpg`: rows 示例主题 / 示例活动 / 示例俱乐部 / 示例商家 read as placeholders while en shows real names. | **Fixed** — zh design fixture: 灯笼夜行 / 灯笼集市探索 / 老城漫步者 / 灯笼茶馆; UI-test runs (no `--design-fixture`) keep 示例… |
| same, activity row second line | Pin glyph before 老城 · 灯笼 on activity rows only (P18 area line, polish-search). | Kept — P18 marks an activity's area; noted for the coordinator. |

## Round 3 continue (13) — hourly re-scan (sweep still build 8fa84e4d3, covered in continue 12)

Merged `origin/ui/combined-r7` (already up to date). No new coordinator note for mp-home since 22:20. `pages/index/index.js` navigation targets re-listed (`goUser` → 我的 tab, `goRecoHero`/`goTopic` → `pages/topic/index`, `goActivity` → activity detail, banners → `pages/activity/list`, `pages/club/apply`, `pages/merchant/apply` (gated)); every one already has a row. Design-system grep on the 首页 files (`HomeFeedView`, `HomeSearchTabParityViews`, `OfficialEventsBrowserView`, `ActivityDetailView`, `E1ActivityDetailParts`, `TopicDetailView`, `SearchMapComponents`, `GlobalSearchView`): no `.font(.system(size:))`, `.tracking`/`.kerning`, `Color(red:)`, custom fonts or untranslated `Text("…")` literals.

Re-scan of `pages/topic/index/index.wxml` 详情 / 故事 / 路线 against `App/TopicDetailView.swift` + `App/TopicXcxSections.swift`:

| MP page → native view | Difference | Fixed / not |
|---|---|---|
| `topic/index.wxml:292-296` story paywall 解锁完整体验 · price · 立即解锁 · 已购？去票夹 | Present (`TopicDetailView.swift:556-576`). | No change. |
| `topic/index.wxml:357-358` 路线配置中 + 浏览其他主题 | Present (`TopicXcxSections.swift:615-624`). | No change. |
| `topic/index.wxml:437` station card 到店礼 · gift | Present (`shopGift`, `TopicXcxSections.swift:640-644`). | No change. |
| `topic/index.wxml:302-316` 评价: when there are no reviews the 还没有评价 card **is** the only write entry; with reviews 写评价 sits trailing in the rating row, above the list. Native always draws a separate bordered 写评价 button above the section content, so the empty state has two write entries. | **Not done** — `TopicFlowTests.testKnownEmptyTopicReviewsUseChineseEmptyStateWithoutZeroStars` pins both `topic.reviews.empty` and the `topic.openReview` button in the empty state, and `tools/check_contextual_flows.py` pins the identifier; changing the accessibility tree of the empty card blind (no simulator) could break that UI test. Next run with a simulator: hide the bordered button when `hasConfirmedNoReviews && preview.isEmpty`, move `topic.openReview` onto the empty card, update the UI test. |

## Round 3 continue (14) — 23:07 sweep (build b3b03703a), mp-home sheets zh-Hans + en

Rebased on `origin/mp/r3-home`. No coordinator item for mp-home at 23:20. Sweep build includes continue 11/12: 编辑精选 card shows Beta 试玩 above the title ✓, zh search rows 灯笼夜行 / 灯笼集市探索 / 老城漫步者 / 灯笼茶馆 ✓, home / offline / activity detail / wave-today-club read clean in both languages.

| MP page → native view | Difference (screenshot) | Fixed / not |
|---|---|---|
| `pages/index/index.wxml:103-121` 编辑精选 card → `d2-home` (`App/HomeFeedFixtureSupport.swift` `HomeFixtureLanguage`) | `zh-Hans-d2-home.jpg` / `en-d2-home.jpg`: card title 「示例街区路线」 / "Sample neighborhood route" reads as a placeholder. | **Fixed** — under `--design-fixture` only: topic 老城灯笼夜行 / Old Town Lantern Walk (area 老城 / Old Town), activity 滨江灯笼漫步 / Riverside Lantern Walk (西岸码头 / West Bund Pier). UI-test runs keep the synthetic names. |

## Round 3 continue (15) — 23:37 sweep (build 793c3190b), mp-home sheets zh-Hans + en

Merged `origin/ui/combined-r7` (clean). Coordinator 23:50: the mp-home 19:15 / 19:50 / 21:20 findings are fixed. Build 793c3190b predates `933ae767e` (continue 14 编辑精选 names), so the card still reads 示例街区路线 there; recheck next sweep.

| MP page → native view | Difference (screenshot) | Fixed / not |
|---|---|---|
| `scene-play-activity-detail/index.wxml:55-62` `{{registrationCountText}} 人已报名` + avatars → `App/ActivityPeopleSection.swift` | `zh-Hans-rep3-activity-detail.jpg` / `en-…`: section 报名玩家预览 / "Participant preview" with a 报名总人数 24 row — the count repeats the 已报名 fact row right above, and the MP title is the count itself. MP also hides the section when there are no registrants. | **Fixed** — section only when `participants` is non-empty, header 「N 人已报名」 / "N going" (`activity.pinned.going %lld`; unknown count → 报名玩家预览), no total row; header keeps id `activity.people.total`. UI test `ActivityFlowTests` label → "12 going"; pin in `test_activity_topic_accessible_summaries.py` updated with a one-line reason. |
| `pages/topic/index/index.wxml:302-316` 评价 empty → `App/TopicDetailView.swift` `Section("topic.comments")` | Continue-13 Not-done row: with no reviews the bordered 写评价 button sat above the 还没有评价 card, which is itself the write entry (two entries). | **Fixed** — the bordered button (`topic.openReview`) shows only when the empty card does not; the empty card button is unchanged (keeps `topic.reviews.empty`). `TopicFlowTests.testKnownEmptyTopicReviewsUseChineseEmptyStateWithoutZeroStars` now asserts no `topic.openReview` in the empty state; `check_contextual_flows.py` still finds the id (its pre-existing failure at line 21, `ContextualTopicPicker`, is unrelated and fails on the base too). With reviews, 写评价 stays above the list (MP: trailing in the rating row) — kept. |
| `scene-play-activity-detail/index.wxml:47-53` `activity-host` (avatar · name · 「发起人 · 主理人」) → `App/ActivityPeopleSection.swift` host row | Native showed avatar + name only. | **Fixed** — `.footnote` `.secondary` role line under the name, new key `activity.people.hostRole` 发起人 · 主理人 / Creator · Host (en + zh-Hans, `docs/port/strings/mp-home-r3.json` + catalog). Shop-hosted activities keep the 主办方 section (MP 商家 role) unchanged. |

## Round 3 continue (16) — 00:10 sweep (build 283dd3b52), mp-home sheets zh-Hans + en

Rebased on `origin/mp/r3-home`, merged `origin/ui/combined-r7` (clean). No new coordinator item for mp-home after 23:50. Sweep shows continue 14 (编辑精选 老城灯笼夜行 / Old Town Lantern Walk ✓); continue 15 is not in this build.

| MP page → native view | Difference (screenshot) | Fixed / not |
|---|---|---|
| `pages/search2/index` → `App/GlobalSearchView.swift` | `zh-Hans-d2-search.jpg` / `en-d2-search.jpg` / `*-d2-search-results.jpg`: a `wifi.slash` 「示例内容」 / "Example content" row under 筛选 — demo wording in the rendered fixture (same class as the 00:20 registration-sheet finding); the MP has no such row. | **Fixed** — hidden under `--design-fixture` via `SearchMapOfflineNoteHiding` (Square's rule); UI tests and offline examples keep it, `isOfflineExample` still keeps writes offline. |

## Round 3 continue (17) — 00:37 sweep (build f8574edab), mp-home sheets zh-Hans + en

Merged `origin/ui/combined-r7` into `mp/r3-home`. No new coordinator item for mp-home after 00:20. Build f8574edab predates continue 16 (`adacc174d`, 示例内容 row), so that row still shows; recheck next sweep.

| MP page → native view | Difference (screenshot) | Fixed / not |
|---|---|---|
| `pages/search2/result/index.wxml:15-16` `cy-tabs variant="chip"` (全部 / 主题 / 活动 / 俱乐部 / 商家, always on the page) → `App/GlobalSearchView.swift` results branch | `zh-Hans-d2-search-results.jpg` / `en-…`: no result tabs. Native puts them in the system scope bar (`.searchScopes(activation: .onSearchPresentation)`), which iOS only draws while the field is focused, so after a search the type filter was invisible. | **Fixed** — when the field is not presented, the same scopes sit above the results as `CYFilterChip` capsules (全部 + each kind with its settled count), bound to the one `searchModel.scope`; the scope bar stays while typing. Id `searchMap.resultScopes`. |

## Round 3 continue (18) — 01:10 sweep (build 907570051), mp-home sheets zh-Hans + en

Merged `origin/ui/combined-r7` into `mp/r3-home`. No new coordinator item for mp-home after 00:20. Build includes continue 16 (no 示例内容 row ✓); continue 17 (result-scope chips) is not in it yet.

| MP page → native view | Difference (screenshot) | Fixed / not |
|---|---|---|
| `pages/search2/result/index.wxml` (no search button; the keyword is confirmed from the field) → `App/GlobalSearchView.swift` `searchMap.submit` | `zh-Hans-d2-search-results.jpg` / `en-…`: a full-width prominent 搜索 / "Search" button sits between 筛选 and the results after the search already ran — a second, dead-looking primary action. | **Fixed** — the button shows only while the current keyword/category has no results on screen and no request running (the suggestions page and an edited query keep it; Maestro flows tap it before results, unchanged). |

## Round 3 continue (19) — 01:40 sweep (build a32387e9b), mp-home sheets zh-Hans + en

Merged `origin/ui/combined-r7` into `mp/r3-home`. No new coordinator item for mp-home after 23:50. Build includes continue 17 (result-scope chips ✓ in both languages); continue 18 (no 搜索 button above results) is not in it yet.

| MP page → native view | Difference (screenshot) | Fixed / not |
|---|---|---|
| `pages/activity/detail` `activity-hero` status tag (light text on the cover) → `App/E1ActivityDetailParts.swift` `E1ActivityHero` | `zh-Hans-rep3-activity-detail.jpg` / `en-…`: the 已结束 / "Ended" word and its checkmark render in `.secondary` grey over the bright part of the photo — barely readable (fails 4.5:1). | **Fixed** — the ended state reads in `palette.onCoverFg` (footnote semibold, id `activity.detail.state`), and the hero scrim darkens earlier (0.5 at 25 %, 0.75 at 50 %) so the status line sits on shade. Upcoming / live keep the tinted `CYStatusChip`. |

## Round 3 continue (20) — 02:10 sweep (build 41374363f), "Next round" list (P23–P31)

Merged `origin/ui/combined-r7` (clean). No open coordinator item for mp-home; every 首页-reachable MP page already has a row. Sweep build includes continue 18 (no 搜索 button above results ✓); continue 19 (已结束 on the hero) is not in it yet.

| MP page → native view | Principle → change | Fixed / not |
|---|---|---|
| `subpackageMember/components/cy/scene-play-activity-detail/index.wxml:29-38` activity-meta (分类 / 集合点 / 已报名, MP order kept) → `App/ActivityDetailView.swift` `ActivityDetailMetaSection` | P28 facts as icon rows: `zh-Hans-rep3-activity-detail.jpg` showed plain label/value rows. Each `LabeledContent` label is now a system `Label` with a leading SF Symbol (`tag` / `mappin.and.ellipse` / `person.2`, `.secondary`, hidden from VoiceOver); values, ids, the Maps button and "—" for unknown unchanged. | **Fixed** (`rep3-activity-detail`). P28's date row + Add to Calendar is **not done**: the MP shows the time in the hero, not in activity-meta, and EventKit UI needs a usage string + device check. |

## Round 3 continue (21) — 02:10 sweep (build 41374363f), mp-home sheets zh-Hans + en

Merged `origin/ui/combined-r7` (clean). No open coordinator item for mp-home; sweep build unchanged since continue 20.

| MP page → native view | Difference (screenshot) | Fixed / not |
|---|---|---|
| `pages/search2/result/index.wxml:67-76` `result-card` (`__type` text → `__title` → `__detail` text) → `App/SearchMapComponents.swift` `SearchMapCard.textColumn` | `zh-Hans-d2-search-results.jpg`: the activity row alone draws a `mappin.and.ellipse` glyph before its area line, and every kind line is a `Label` whose icon pushes 主题 / 活动 … right of the title's edge — four rows, two leading edges. MP has plain type and detail text. | **Fixed** — kind and detail are plain `Text` lines (caption / subheadline, `.secondary`) for every kind, so title, kind and area share one leading edge; cover cards and the no-cover kind icon in `coverImage` unchanged. |
| 首页 Today card (native `HomeTodayCard`, eyebrow 今天 · 俱乐部活动) → `App/HomeFeedView.swift` `HomeTodayCard.meta` | `zh-Hans-wave-today-club.jpg`: eyebrow says 今天, then the meta line repeats the full date 「2026年11月27日 18:14 · 老城」. | **Fixed** — a start on the same day (card time zone) shows the time only (「18:14 · 老城」 / "6:14 PM · Old Town"); a ticket starting tomorrow (the ±24 h window) keeps the abbreviated date; unknown time stays "—". |

## Round 3 continue (22) — 03:15 sweep (build ad55acd94), "Next round" item 2 (motion and feedback)

No open coordinator item for mp-home (03:15: "no new findings"); the sweep build predates continue 21. Re-checked `search2/result` pagination (没有更多了 + 重新搜索 ghost button, MP `index.wxml:82-86`) and result-card tags — native matches.

| MP page → native view | Principle → change | Fixed / not |
|---|---|---|
| `pages/search2/result/index.wxml:15-16` `cy-tabs variant="chip"` → `App/GlobalSearchView.swift` `resultScopeChips` | Motion/feedback: switching 全部 / 主题 / 活动 … gave no feedback. `.sensoryFeedback(.selection, trigger: searchModel.scope)` on the chip row, as a segmented control ticks. | **Fixed** (`d2-search-results`; haptics need a device). |
| `pages/index/index` greeting row city picker (`onTapHomeCity` menu) → `App/HomeFeedView.swift` | Motion/feedback: choosing a city gives no haptic. | **Not done, by contract** — `test_native_design_motion.test_content_animation_is_local_and_not_a_refresh_success` forbids `sensoryFeedback` in `HomeFeedView.swift`; left as is. |

## Round 3 continue (23) — 04:00 sweep (build 733bfb368), "Next round" item 3 (all states)

Merged `origin/ui/combined-r7` (clean). Sweep `mp-home/sheet-zh-Hans.jpg` / `sheet-en.jpg` (build 733bfb368): no new coordinator finding for mp-home; d2-home / d2-home-offline / d2-search / d2-search-results / wave-today-club / rep3-activity-detail read correctly in both languages (search field is the system `.searchable`, 类别 capsules one line, result rows text-only, activity hero with cover).

| MP page → native view | MP state | Difference | Fixed / not |
|---|---|---|---|
| `pages/search2/result/index.wxml:23` `cy-empty` 没有找到 → `App/GlobalSearchView.swift` results branch (`globalSearch.empty`) | empty result list | State existed but no design fixture showed it, so the sweep never checked it. | **Added** fixture `d2-search-empty` (`SearchMapFixtureReader(.empty)` + the localized keyword) in `App/DesignFixtures/D2Fixtures.swift` / `DesignFixtureRegistry.swift`; UI test `Tests/AppUITests/Fixture_d2_search_emptyTests.swift` (en + zh-Hans screenshot, no raw keys). |
| `pages/search2/result/index.wxml:23` `cy-error` 没能完成搜索 + 重试 → `GlobalSearchView` `SearchMapIssue("globalSearch.failed")` | request failed | Same: no fixture. | **Added** fixture `d2-search-failed` (`SearchMapFixtureReader(.failure)`) + `Fixture_d2_search_failedTests.swift`. Coordinator: please add both ids to the mp-home sweep row. |

## Round 3 continue (24) — sweep still build 733bfb368, "Next round" item 3 (all states, 首页)

Merged `origin/ui/combined-r7` (clean). No open coordinator item for mp-home (04:00: "no new findings").

| MP page → native view | MP state | Difference | Fixed / not |
|---|---|---|---|
| `pages/index/index.wxml:246` `cy-empty` 暂时没有主题 (rails hidden when empty, `:84/:133/:170` `wx:if`) → `App/HomeFeedView.swift` | empty 首页 | Native already hides empty rails and shows `homeFeed.topicsEmpty` under the feed tabs, but no fixture showed it. | **Added** fixture `d2-home-empty` (`HomeFeedFixtureReader` scenario `empty`) + `Tests/AppUITests/Fixture_d2_home_emptyTests.swift`. |
| `pages/index/index.wxml:92` `cy-error` 编辑精选加载失败 + 重试 (other rails load) → `HomeFeedView.section` (`mpfresh.home.sectionFailed.recommended`) | one rail failed | Only the all-down offline state had a fixture. | **Added** scenario `sectionFailed` (编辑精选 throws 503, 附近活动 / feed load) and fixture `d2-home-failed` + `Fixture_d2_home_failedTests.swift`. Coordinator: please add `d2-home-empty`, `d2-home-failed` (and `d2-search-empty`, `d2-search-failed`) to the mp-home sweep row. |

## Round 3 continue (25) — sweep 11-28 ~04:50 (build 13a6690eb), mp-home (P2) wave-today-club

Merged `origin/ui/combined-r7` (receipts of other lanes / design-consistency tool taken from combined; fixture registry kept both sides). Screenshot `en-wave-today-club.jpg` / `zh-Hans-wave-today-club.jpg`: one small text card at the top of an empty screen.

| MP page → native view | Difference | Fixed / not |
|---|---|---|
| 首页 Today card (native-only `HomeTodayCard`; the MP `pages/index/index.wxml` has no Today card, so no MP section is added or reordered) → `App/HomeFeedView.swift` `HomeTodayCard`, new `App/HomeTodayMeetingPointMap.swift` | Card was eyebrow + title + one meta line + button: no image, no place, nothing below. | **Fixed** — full card: 16:9 cover (fixture: bundled MP `clubCityCamera` via `homeTodayFixtureCover`, production: safe https cover, else text-only), P28 fact icon rows (`clock` time, `mappin.and.ellipse` place) instead of the `·` meta line, and a fixed meeting-point map snippet (system `Map`, one `Marker`, no gestures, tap opens Apple Maps) when the candidate has a `meetingPoint`; `@ScaledMetric` height capped at 220 pt. VoiceOver keeps the one combined card label (time · place). Fixture `wave-today-club` gets the Old Town meeting point. |

## Round 3 continue (26) — next page without a row: `pages/searchmap` (Search → 在地图上找)

No open coordinator item for mp-home: sweep 05:15 (build a4142df0d) predates continue 25; the other mp-home tiles read correctly in en + zh-Hans. Gates: generate_project OK · scaffold PASS · a11y lint 0 new · contract ratchet new 0 (52/52) · design consistency PASS.

| MP page → native view | MP sections present | Difference | Fixed / not |
|---|---|---|---|
| `pages/searchmap/index.wxml` → `App/SearchMapExplorerView.swift`, `App/SearchMapResultsCapsule.swift`, `App/SearchMapActivityCard.swift`, `App/SearchMapFilterSheet.swift` | search + 筛选 row ✓ (`.searchable` + 筛选 button), offline bar ✓, map ✓, result capsule (loading / empty / error / N 个结果 · N 个只在列表显示) ✓, 全部结果 sheet (正在更新商家节点… → error / empty / loading → refresh/page inline error → list → 加载更多) ✓, actItem (point label, categories, 关联主题路线, address, time) ✓, filter sheet (商家发现 / 日期 / 价格 / 排序 最近) ✓ | Selected-marker sheet `smap-sel-cta`: MP = 查看活动详情 (primary) + 查看关联主题 (ghost, when linked). Native had no details button (only the tappable card) and 查看关联主题 as an unstyled text button. | **Fixed** — `.borderedProminent` 查看活动详情 / View activity details (`searchMap.w208.viewActivity`, id `searchMap.selected.viewActivity.<id>`) then `.bordered` 查看关联主题 / View related topic, both full width, `.large`. Contract pin re-pinned with a one-line reason (`test_global_search_category_recovery.py`). |
| same → `App/SearchMapFilterSheet.swift` (explorer mode) | 筛选 sheet: 商家发现 / 日期 / 价格 / 排序 + 重置 / 搜索 | Native order was 城市搜索选项 (标签, 城市角色, 排序) → 类别 → 日期 → 价格: sort sat first and category was split from tag / city role. | **Fixed** — one 商家发现 / Find shops section (category picker + its loading/failed/empty rows, then 商家标签, 城市角色), then 日期, 价格, and 排序 (最近) last, as the MP. Global-search mode (no city options) unchanged. New key `searchMap.merchantDiscovery` (en + zh-Hans, also in `docs/search-map-localizations.json`); hash pin re-pinned with a reason. |
| same | — | MP is map-first (full-screen map, 定位 button, location-error bar over the map); native is a scrolling column (filters → layers → 搜索此区域 → map → capsule → rows). | **Not done** — a full-screen map restructure of a 714-line view with read-ownership/pagination guards is not safe blind (no compiler/simulator); needs a simulator run. Section order inside the column follows the MP. |
| same | — | 全部结果 sheet draws a separate 在地图中打开 row under each card; MP makes the card's address row the tap target. | **Kept** — SwiftUI cannot nest the address button inside the card button; the visible row is the 44 pt target (R7-PC-A5-5). |

## Round 3 continue (27) — sweep 05:38 (build 7a7d2708a), mp-home sheets zh-Hans + en; "Next round" item 3

Merged `origin/ui/combined-r7` (clean). Gates: generate_project OK · scaffold PASS · a11y lint 0 new · contract ratchet new 0 (52/52) · design consistency PASS. No open coordinator item for mp-home; d2-home / d2-home-offline / d2-search / d2-search-results / rep3-activity-detail read correctly in both languages.

| MP page → native view | Difference | Fixed / not |
|---|---|---|
| 首页 Today card (native-only) → `App/DesignFixtures/WaveFixtures.swift` | `zh-Hans-wave-today-club.jpg` / `en-wave-today-club.jpg`: the 16:9 cover is a huge black camera glyph — `clubCityCamera` is the MP template **icon** (`images/interaction-templates/club-city-camera.svg`), not a photo. | **Fixed** — fixture cover is the MP photo `pages/templatedetail/art/covers/game/city-camera.jpg` (`MPAsset.BannerCover.cityCamera`, a street-market photo matching 老城摄影漫步). Production unchanged. |
| `pages/activity/list/index` (banner 和朋友报名活动 target) → `App/OfficialEventsBrowserView.swift` | Page never appeared in the sweep: only `e1-official-empty` existed, and the shared `OfficialEventSyntheticFixtures` rows are English "Synthetic …" names (pinned by contract tests, so not edited). MP states: content list, cy-error 活动列表没能打开 + 重试, cy-empty. | **Added** `HomeActivityListFixtureReader` (`App/DesignFixtures/HomeActivityListFixtures.swift`, offline, `tt(en, zh)` names/cities/subtitles, live / upcoming / ended statuses, real participant counts and start times) and fixtures `rep3-activity-list` (content, pushed in a stack like the banner) + `rep3-activity-list-failed` (503 → the MP error state with retry), UI tests `Fixture_rep3_activity_list{,_failed}Tests.swift` (en + zh-Hans, no raw keys). Coordinator: please add both ids to the mp-home sweep row. |

## Round 3 continue (28) — function audit 11-28 P2-2 (mp-home)

Merged `origin/ui/combined-r7` (pbxproj regenerated). Gates: generate_project OK · scaffold PASS · a11y lint 0 new · contract ratchet new 0 (52/52) · design consistency PASS. Level B (Crafted) pages; no visual change except one secondary button.

| Audit item → MP → native | Difference | Fixed / not |
|---|---|---|
| **P2-2a** topic-template share → MP `pages/templatedetail/topic-detail/index` `onShareAppMessage` path → `Core/PublicContentShareLink.swift` `topicTemplate(id:)` (caller `App/DiscoveryTemplateDetailView.swift:368`) | Share sent the bare path text `/pages/templatedetail/topic-detail/index?id=` because the helper only accepted `.content` parses, although `UniversalLinkParser` already types this page as `.miniProgramPage` and `MPReviewedPageScreen` opens it (PC-A-8-1). | **Fixed** — built through `reviewedPage` (parse-back check kept), so the share is `https://www.chengyinhub.com/pages/templatedetail/topic-detail/index?id=N`; copy-text fallback now nil. Test `PublicContentShareLinkTests.testTopicTemplatePathIsNotParsedSoOnlyTheMiniProgramPathIsCopied` (name kept for the CI manifest) asserts the URL. |
| **P2-2b** activity share → MP `pages/activity/detail/index.js:47` `onShareAppMessage` (`buildActivityShare` path `?id=`) → `App/ActivityDetailView.swift` share sheet → `App/CatalogShareCardView.swift` | Share was an image only, with no way back to the activity. | **Fixed** — new `PublicContentShareLink.activity(id:)` (parsed `.content(.activity)` only); `CatalogShareCardView(link:)` shows a `.bordered` 分享链接 / Share link `ShareLink` under 分享图片 once the image is ready (`share.card.shareLink`, en + zh-Hans). Referral `ref` not added (MP gets it from the server; no app route). Test `testActivityShareCarriesTheParsedActivityLink`. |
| **P2-2c** topic 举报 / 屏蔽作者 → MP topic owner `memberId` → `App/TopicDetailView.swift` `UGCSafetyMenuButton` | Presentation had only `authorName: clubName`, so 屏蔽 blocked locally by name with no memberID. | **Fixed** — passes `authorMemberID: value.ownerMemberID` (already decoded from `memberId`, R7-PC-B1-12); `canActOnAuthor` still hides it on the viewer's own topic. |
| **P2-3a** map search without the known area → MP `pages/searchmap/index.js:1047-1072` (`onLoad` → `getList()` at once around the known position / default centre) → `App/SessionHomeFeedView.swift` map button → `App/GlobalSearchLinksAndTemplates.swift` `SessionLinkedSearchView` → `SearchMapExplorerView` | The 首页 map opened with `area == nil`: disabled 搜索此区域 and the 请选择区域 prompt, although the app already knows the area. | **Fixed** — `SessionLinkedSearchView(initialArea:)`; 首页 passes `homeMapArea` = `session.roamArea`, else the centre of the 首页 city label via the existing (previously unused) `HomeCityCentre` table. Reads no device location. Unknown city keeps the prompt. The explorer then shows the area title and an enabled 搜索此区域 (reads stay user-started, manual read ownership unchanged). |
| **P2-3b** city consent card 同意 never locates | — | **Not done** (same as the `onTapHomeCity` row above): needs a foreground fix → reverse-geocode with a transport admission rule; device check required. |
| **P2-3c** city rail asks for location on 首页 load | `App/CityKit/CityHomeRail.swift` task → `cityCaptureFix()` | **Fixed** (continue 29) — the ranked list gives P2-3 to mp-home and the rail renders on 首页: the task now takes a device fix only when location is already `authorizedWhenInUse/Always`, else the chosen `roamArea`; no primer or system prompt without a tap (MP `index.js` locates only after consent / city tap). Store, reads and the roam surfaces untouched (mp-roam). |
| **P2-3d** 关联玩法模板 rows not tappable → MP `scene-play-activity-detail/index.wxml:69` `goTemplateDetail` → `templatedetail?id=&scope=my` → `App/ActivityAssociatedPlaysSection.swift` | Rows are read-only by an earlier privacy decision ("the myinfo grant is not inherited"; `ActivityAssociatedPlaysTests.testAllowedResponseReadsOnlyThreeDisplayFieldsAndKeepsReturnedOrder` pins that no `id`/`imgUrl` is decoded). | **Not done — needs coordinator decision**: MP opens `scope=my` (the organizer's own-template read), which a viewer cannot use; the safe native target would be the public `templatedetail?id=` read, which changes a pinned privacy contract. |


## Round 3 continue (30) — sweep 11-28 ~06:48 (build ffeef67c7), mp-home sheets zh-Hans + en; 07:05 states note

Merged `origin/ui/combined-r7` (clean). `sheet-zh-Hans.jpg` / `sheet-en.jpg`: d2-home-offline, d2-home, d2-search-results, d2-search, rep3-activity-detail, wave-today-club read correctly in both languages; no open coordinator item for mp-home. Every `pages/index/index.js` target already has a row. Level B (Crafted).

| MP page → native view | Difference | Fixed / not |
|---|---|---|
| `pages/index/index.wxml:246,283` `cy-empty` 暂时没有主题 / 暂时没有活动 → `App/HomeFeedView.swift` `streamSection` (coordinator 07:05, `d2-home-empty`, listed under mp-states; the file is mp-home's) | The empty `ContentUnavailableView` offered no next step. The MP empty has a title only; its next step on this page is the other feed tab. | **Fixed** — one `.bordered` action in the `ContentUnavailableView` `actions:` switches the system picker: 看看活动 / See activities on 主题, 看看主题 / See themes on 活动 (`homeFeed.empty.seeActivities` / `.seeTopics`, en + zh-Hans, id `homeFeed.empty.switchKind`); the query change reloads through the existing `.onChange(of: query)`. Title, icon, keyword hint and `homeFeed.empty` id unchanged (`HomeFeedFlowTests.testEmptyStateIsNotAnError` still holds). |

## Round 3 continue (31) — function audit P2-3b (mp-home)

Merged `origin/ui/combined-r7` (clean; fix/1128-* receipts arrived). No new coordinator item for mp-home since 07:05. Level B (Crafted).

| MP page → native view | Difference | Fixed / not |
|---|---|---|
| **P2-3b** `pages/index/index` city consent 同意 → MP `getHomeCityLocation` → `App/SessionHomeFeedView.swift` `agreeAndLocateHomeCity()` + `HomeCityCentre.nearest(to:)` | 同意 recorded consent but never located the city. | **Fixed** — after `cityConsent.agree` (consent write unchanged), one foreground fix through the existing `session.cityCaptureFix()` (the tap is the permission ask; `RuntimeNativeLocationProvider` asks only when not determined), matched **on the device** to the nearest supported 首页 city within 100 km (great-circle); the coordinate is never sent, so no reverse-geocode route or transport admission is needed. No fix / out of range keeps the label. Test `HomeCityCentreNearestTests` (Shanghai, Hangzhou vs Shanghai, New York → nil). Tap-to-relocate on the city label (`onTapHomeCity`) stays the MP menu pick. |

## Round 3 continue (32) — sweep 07:26 UTC (build 3348aa51f), `d2-search` 类别

Merged `origin/ui/combined-r7` (clean, 124 commits incl. fix/1128b-*). Gates: generate_project OK · scaffold PASS · a11y lint 0 new · contract ratchet new 0 (52/52) · design consistency PASS. `sheet-zh-Hans.jpg` / `sheet-en.jpg`: d2-home, d2-home-offline, d2-search-results, wave-today-club, rep3-activity-detail read correctly; no open coordinator item for mp-home. Level B (Crafted).

| MP page → native view | Difference | Fixed / not |
|---|---|---|
| `pages/search2/index` 类别 (`categoryList`, icon per `utils/category-icon.js`) → `App/SearchMapComponents.swift` `SearchCategorySymbol` | `en-d2-search.jpg`: English category names have no icon rule (MP rules are Chinese only), so every US-market category gets the neutral `storefront` glyph. | **Fixed** — each MP rule also matches English word starts, case-insensitive with `\b` (Food → fork.knife, Photography → camera, Culture → book, Night walks → star, Family → person.2; "Party"/"Brunch" stay neutral). Chinese rules and order unchanged. Test `SearchCategorySymbolTests`. |
| same → `App/SearchMapFixtureSupport.swift` (`d2-search` design fixture) | `zh-Hans-d2-search.jpg` / `en-d2-search.jpg`: the 类别 card held one capsule (人文 / Culture with the shop glyph), reading as a stray chip rather than the MP category grid. | **Fixed** — under `--design-fixture` only: 文化 / 户外 / 美食 / 摄影 / 夜游 / 亲子 (en Culture / Outdoors / Food / Photography / Night walks / Family), each with its MP icon; UI-test runs keep the pinned synthetic list. |
| `pages/index/index` `onTapHomeCity` → `getHomeCityLocation({ userInitiated: true })` (index.js:1294-1330, 1438) → `App/HomeSearchTabParityViews.swift` city `Menu`, `App/SessionHomeFeedView.swift` `relocateHomeCity()`, `App/HomeCityLocationConsentHost.swift` `userAsksToLocate` | Tapping the city only offered the manual list; the MP tap re-locates from the device (consent read first; REVOKE stops; no agreement shows the consent prompt; the manual `cy-dropdown` is the fallback). | **Fixed** — signed-in only, the menu's first item is 使用当前位置 / Use current location (`location` symbol, divider, then the 20 MP cities; id `homeIndex.hero.city.locate`, key `homeIndex.hero.useCurrentLocation` en + zh-Hans). It reads the consent baseline: REVOKE → nothing (MP), no agreement → the consent card comes back (a local 暂不 is cleared, the user asked), agreement → one foreground fix matched on the device to the nearest 首页 city (coordinate never sent). Guests keep the menu only (MP guest path). New `HomeCityLocationConsentRecord.isRevoked`, test `HomeCityLocationConsentRevokeTests`. |


## Not done / follow-ups
- ~~主题详情 评价: double write entry in the empty state~~ — closed in continue 15 (UI test assertion flipped; needs a simulator run).
- ~~成为俱乐部 opens as a sheet~~ — closed: mp-nav r3 pushes it.
- ~~活动列表 邀约 link hidden while loading / failed~~ — closed in continue 3.
- Needs a simulator pass: P21 bar height over each tab's last row, zoom source/destination match on iOS 18 and 26, Reduce Motion crossfade, the roam HUD's persistent sheet inside the cover.
- Re-scan after the queue (r3 continue): home hero / rails / stream / consent card / activity list / activity detail / topic detail have no `.font(.system(size:))`, `.tracking`/`.kerning`, custom fonts or transparent-bar chrome; 编辑精选 footnote, per-rail 正在更新…, stream failed/empty/loading-more/no-more and 长期开放 all present.
- Needs a simulator pass: `d2-home` first frame without the launch-screen fade (continue 3) and the 类别 capsules in en + zh-Hans.
- Needs a simulator pass: 4:3 banner card height under the large title on small phones (first rails should stay near the fold).
- ~~首页 city tap-to-relocate (MP `onTapHomeCity`)~~ — closed in continue 32 (menu 使用当前位置, on-device match).
- Needs a device pass (continue 32): city menu 使用当前位置 with consent agreed / not agreed / revoked, en + zh-Hans.
- Needs a simulator pass: 20-item city menu in en + zh-Hans.
- Needs a simulator pass: `rep3-activity-detail` hero (no live line when ended, light 已结束) and the footer as the one main button (continue 6).
- Needs a simulator pass: `d2-home-offline` now renders the per-rail failure + feed error states; `d2-search-results` now shows the result list.
- Needs a simulator pass (continue 7): `rep3-activity-detail` with no footer bar and the plain hero; `d2-search-results` kind-icon covers; zh fixtures on `d2-home` / `wave-today-club`.
- Needs a simulator pass (continue 8): `d2-home-offline` with the hero above the offline state; `d2-search-results` zh rows; `d2-search` without the test capsules.
- Needs a simulator pass (continue 9): `rep3-activity-detail` and `d2-search(-results)` without fixture/synthetic names.
- Needs a simulator pass (continue 10): `d2-search-results` text rows without image frames; `rep3-activity-detail` hero with the fe-night cover.
- Needs a simulator pass (continue 11): 编辑精选 card with club / Beta 试玩 row above the title.
- Needs a simulator pass (continue 12): zh `d2-search-results` row names.
- Needs a simulator pass (continue 14): `d2-home` 编辑精选 card name.
- Needs a simulator pass (continue 15): activity detail 「N 人已报名」 section header (and the `ActivityFlowTests` label "12 going").
- Needs a simulator pass (continue 15): `TopicFlowTests.testKnownEmptyTopicReviewsUseChineseEmptyStateWithoutZeroStars` with one write entry.
- Needs a simulator pass (continue 16): `d2-search` / `d2-search-results` without the 示例内容 row.
- Needs a simulator pass (continue 17): `d2-search-results` result-scope chips row (全部 / 主题 n / 活动 n …) in en + zh-Hans, and that it hides while the field is active.
- Needs a simulator pass (continue 18): `d2-search-results` without the 搜索 button above the results.
- Needs a simulator pass (continue 19): `rep3-activity-detail` 已结束 / Ended readable on the hero in en + zh-Hans, light and dark.
- Needs a simulator pass (continue 20): `rep3-activity-detail` fact rows with leading icons in en + zh-Hans, AX5 (LabeledContent stacks).
- Needs a simulator pass (continue 21): `d2-search-results` rows with plain kind / area lines (one leading edge) in en + zh-Hans, AX5.
- Needs a simulator pass (continue 21): `wave-today-club` meta line time-only in en + zh-Hans.
- Needs a device pass (continue 22): selection haptics on the search result-scope chips.
- Needs a simulator pass (continue 23): `d2-search-empty` (没有找到 / no results) and `d2-search-failed` (没能完成搜索 + 重试) in en + zh-Hans.
- Needs a simulator pass (continue 24): `d2-home-empty` (暂时没有主题 / No themes right now) and `d2-home-failed` (编辑精选加载失败 + 重试 above 附近活动) in en + zh-Hans.
- Needs a simulator pass (continue 25): `wave-today-club` full card (cover, time/place icon rows, meeting-point map) in en + zh-Hans, light/dark, AX5.
- Needs a simulator pass (continue 26): searchmap selected-marker sheet with 查看活动详情 + 查看关联主题 in en + zh-Hans, AX5.
- searchmap full-screen map-first layout (MP `pages/searchmap`): needs a simulator run before restructuring `SearchMapExplorerView`.
- Needs a simulator pass (continue 26): searchmap 筛选 sheet order (Find shops → Date → Price → Sort) in en + zh-Hans.
- Needs a simulator pass (continue 27): `wave-today-club` with the city-camera photo cover; `rep3-activity-list` / `rep3-activity-list-failed` in en + zh-Hans (cards with the cover fallback, status badges, 邀约 link; error + 重试).
- Needs a simulator pass (continue 28): activity share sheet Share link button under Share image in en + zh-Hans, AX5.
- Function audit P2-3d (关联玩法模板 tap, needs a decision). P2-3b fixed in continue 31.
- Needs a device pass (continue 31): city consent 同意 asks for location once and sets the 首页 city label (Shanghai / Hangzhou).
- Needs a simulator pass (continue 28): 首页 map button opens the explorer titled with the 首页 city and 搜索此区域 enabled.
- Needs a device pass (continue 29): 首页 city rail with location not determined shows no prompt and loads around the chosen area.
- Needs a simulator pass (continue 30): `d2-home-empty` with the 看看活动 / See activities button in en + zh-Hans, AX5.
- Needs a simulator pass (continue 32): `d2-search` 类别 card with six capsules wrapping in en + zh-Hans, AX5.

## For other lanes
- mp-states: the 07:05 `d2-home-empty` next-step item is done on `mp/r3-home` (continue 30); `r3-roam-routes-empty` stays yours / mp-roam.
