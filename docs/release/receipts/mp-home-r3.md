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
| MP shows 邀约 only when not loading/failed; native always shows it. | Not changed (low impact). |

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

Files: new `App/ActiveSessionMiniBar.swift`; `App/QuestLiveActivityCenter.swift` (feeds the store from `show` / `redecoratePlay` / `end`, `toggleRun(kind:pause:)` = the Live Activity button path, `setPlayContext` / `clearPlayContext` mark the play screen on/off screen); `App/RoamLiveSessionView.swift` (extra `.onAppear` / `.onDisappear` lines mark the roam screen visible; pinned lines untouched); `App/QuestifyApp.swift` (`.modifier(activeSessionBar)` on each of the five tab roots, both iOS 18 `Tab` and iOS 17 `tabItem` paths).

- **State:** `ActiveSessionStore` (`@Observable`, MainActor) holds the roam / play entries exactly as last published to the Live Activity (P5: bar, HUD, island and Lock Screen are one object). Recorded before the ActivityKit authorization check, so the bar works with Live Activities off. Story audio and event countdowns are not runs and stay out.
- **Bar** (`safeAreaInset(.bottom)` above the system tab bar, material card, `CYRadius.card`): tinted icon tile (walk / flag), title (session title, else 漫游中 / 游戏进行中), one live value — `Text(timerInterval:)` while running (ticks by itself, P2), `已暂停 · mm:ss` when paused, else next-stop distance — and one control: pause / resume (`playx.run.pause` / `.resume`, 44 pt). Hidden when the tab bar is hidden or the run's own screen is up.
- **Expanded HUD** (`fullScreenCover`): roam → its own `RoamLiveSessionView` with the shared `makeRoamLiveSessionController()` (`roamLiveDestination`), games / city run → `ActiveSessionPlayHUD`: title, clock as hero (P1), the existing `PlayHUDNextStopCard` (下一站 · distance · 线索), one `.borderedProminent` pause/resume (P3). 收起 (chevron.down) top-leading.
- **Motion spec:** tap on the bar → the bar zooms into the full-screen HUD (`matchedTransitionSource(id: "activeSession.miniBar")` on the bar + `.navigationTransition(.zoom(sourceID:in:))` on the cover; the bar keeps identity as the zoom source) → tab bar, tab content and its large title stay fixed underneath → system zoom timing; bar in/out `.smooth` opacity, no custom curves → swipe down (system interactive zoom dismiss; plus a downward drag on the play HUD for iOS 17) or 收起 zooms back into the bar → **Reduce Motion:** no zoom, the cover is presented without animation and its content crossfades in (0.2 s opacity); bar appears without animation.
- Strings (en + zh-Hans, `docs/port/strings/mp-home-r3.json` + catalog): `activeSession.roam.title` 漫游中 / Roaming, `activeSession.play.title` 游戏进行中 / Game in progress, `activeSession.expand.hint` 展开实时面板 / Opens the live view, `activeSession.collapse` 收起 / Collapse.
- Known limit: leaving `RoamLiveSessionView` pauses the walk (`owner.pause()` in its pinned `onDisappear`, roam lane's behaviour), so a roam usually shows in the bar as 已暂停 with 继续; collapsing the roam HUD pauses it the same way. Game screens that never call `setPlayContext` and keep the tab bar visible would show the bar under them — none found in the scan (`PlayExperienceView` hides the tab bar).

### Re-scan of 首页-reachable pages (continue 2)
- `HomeFeedView`, `HomeSearchTabParityViews`, `SessionHomeFeedView`, `OfficialEvents*`, `ActivityDetailView`, `E1ActivityDetailParts`, `TopicDetailView`: no `.font(.system(size:))`, `.tracking`/`.kerning`, `Color(red:)` or transparent-bar chrome; the only `LinearGradient` is the activity hero's legibility scrim over the cover photo (functional, kept). `.cyText` uses are the shared CY wrapper.
- MP 首页 order under the large title re-checked: banner → greeting / 玩家 · city → location card → 编辑精选 → (我的地盘 owner rail) → 附近活动 → 即将上线 → feed — unchanged.

## Not done / follow-ups
- ~~成为俱乐部 opens as a sheet~~ — closed: mp-nav r3 pushes it.
- 活动列表 邀约 link: MP hides it while loading / failed; native always shows it (the load state lives inside `OfficialReadScreen`; low impact, not changed).
- Needs a simulator pass: P21 bar height over each tab's last row, zoom source/destination match on iOS 18 and 26, Reduce Motion crossfade, the roam HUD's persistent sheet inside the cover.
- Re-scan after the queue (r3 continue): home hero / rails / stream / consent card / activity list / activity detail / topic detail have no `.font(.system(size:))`, `.tracking`/`.kerning`, custom fonts or transparent-bar chrome; 编辑精选 footnote, per-rail 正在更新…, stream failed/empty/loading-more/no-more and 长期开放 all present.
- Needs a simulator pass: 4:3 banner card height under the large title on small phones (first rails should stay near the fold).
