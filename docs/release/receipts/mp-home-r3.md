# mp-home r3 — Tab 首页 against the mini-program

Branch `mp/r3-home` from `origin/ui/combined-r7`. Brief: `design/handoff-r2:docs/briefs/round3-1127.md` (row `mp-home`), rules from `round2-1127.md`, principles `design-principles.md`.
MP source: `origin/mp-source:chengyinhub-xcx` (snapshot of hengyin master 2026-11-24). Pages read: `pages/index/index.{wxml,js}`, `utils/index/{home-action-banner,feed-card}.js`, `pages/activity/list/index.wxml`, `subpackageMember/components/cy/scene-play-activity-detail/index.wxml` (what `pages/activity/detail` hosts), `pages/topic/index/index.wxml`.

Gates (last run on the tip): `tools/generate_project.py` OK · `tools/check_scaffold.py` PASS · `tools/check_a11y_lint.py` PASS (0 new) · `tools/check_typography_lint.py` PASS · `tools/contract_ratchet.py --check` new 0 (re-arm run: the one new raw-colour hit, the avatar ring `Color(.systemBackground)`, fixed to `.background`). No Swift compiler here: edits mirror existing patterns; nothing deployed. Merchant features and the story-flow theme untouched.

Strings: `docs/port/strings/mp-home-r3.json` (4 keys, en + zh-Hans) merged into `Resources/Localizable.xcstrings`: `homeFeed.type.orienteering` 城市定向 / City orienteering, `homeFeed.type.freeExplore` 自由探索 / Free exploration, `homeFeed.startingSoon` 即将开始 / Starting soon, `homeFeed.loadingMore` 正在加载更多 / Loading more…. (`homeIndex.logo` from the re-arm was removed again in round 3 continue — the logo bar item is gone.)

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
| MP shows 邀约 only when not loading/failed; native always shows it. | Not changed (low impact). |

### `pages/activity/detail` → `scene-play-activity-detail` → `App/ActivityDetailView.swift`

MP order: hero (status, title, date) → cancelled notice → facts (分类 / 集合点 / 已报名 / 主题路线) → 关于这场活动 → 主理人 → N 人已报名 → 关联玩法模板 → 票种 → 评价 → bar.

| Difference | Status |
|---|---|
| Cancelled notice came after the info card and action rows. | **Fixed** — right under the hero; contract pin in `test_activity_registration_parity_w2_06.py` updated with a one-line reason. |
| 主题路线 was a separate section after the map. | **Fixed** — directly after the facts. |
| 关联玩法模板 hidden behind "More info". | **Fixed** — between people and 票种 (also on the city-event variant). |
| Static map section (not in MP; MP 集合点 row opens the map). | **Kept** — pinned by `test_activity_design_structure` / parity order; directions remain the action row. |
| Native info card + action rows (directions / review / channel) above the facts. | **Kept** — pinned E1 parts (`E1ActivityInfoCard`); no MP counterpart, noted. |

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

## Not done / follow-ups
- Needs a simulator pass: 4:3 banner card height under the large title on small phones (first rails should stay near the fold).
- Activity detail map / info card are native extras kept because contracts pin them.
- Fixtures that seed continuation/Today on `d2-home` still pass the inputs; they simply no longer render on 首页.
