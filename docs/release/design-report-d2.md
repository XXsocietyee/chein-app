# Design report D2: player home + discovery (dark)

Branch `ui/d2`, rebased on `ui/kit`. Fixtures (DEBUG, synthetic, labelled): `--design-fixture d2-home | d2-search | d2-square | d2-roam`
(`App/DesignFixtures/D2Fixtures.swift`, hosting the real views and applying `.themeDomain(.player)` + `cyDomainPageBackground()`).
Shots and compares: `docs/release/design-report-d2-shots/` (also `/Users/fanning/chengyin-refs/design-reports/d2/`).
Strings: `docs/release/ui-strings-d2.json` (2 new keys, EN + zh-Hans; NOT yet in the xcstrings, so zh shows English for them until the integrator merges).

## Screens
| Screen | Reference | Compare | Status |
|---|---|---|---|
| Home (HomeFeedView + hero header) | player-e2e 022 / 001 | compare-home.png | done; Chinese, dark, XL checked |
| Search (GlobalSearchView) | 014 | compare-search.png | done; dark, Chinese |
| Square feed (SquareBrowserView + post card) | 017 | compare-square.png | done; dark, Chinese |
| Roam intro (ticket cards) | roam-intro-nrc | compare-roam.png | done; dark, Chinese |

Changes: home greeting `display` type, one search pill with map as trailing icon, rails use kit `CYImageCard` (`.shelf` rail, `.hero` at accessibility sizes) via new `HomeFeedShelfCard`, plain large section headers, chip row stacks at XL (fixed clipping "玩/家", "Shan/ghai"); search = pill field, outlined recommended chips, dark category tiles, one map pill; square post header is one line (avatar, name, time) with at most ONE chip (notice > author badge > level), equal-spaced tabular counts; roam intro = ticket cards with coloured spine and NO.0n.

## Demoted controls (all still reachable)
- Home: 3 action banners (成为俱乐部 / 成为商家 / 和朋友报名) -> "More ways to play" menu; map search chip -> trailing icon in the search pill; feed `.searchable` -> pull-down drawer when the hero search exists.
- Search: separate 搜索 button shows only once a keyword exists (keyboard Search key always submits); nearby / public layers / shops -> "More ways to find" menu.
- Square: 我的草稿 and 举报进度 -> toolbar "..." menu. Post header: level, author badge and extra notice badge dropped from the card list row (the detail view still shows all via SquarePostContent).

## Checklist (home / search / square / roam)
1 order same as reference: yes (home: reference starts with hero banner pager; fixture has no banners, see open). 2 one primary: yes (search pill / search field / compose / start-roam card). 3 <=3 other controls: yes. 4 dark player theme: yes (verified through the fixture applying the same role theme as the tabs). 5 no violet: yes. 6 kit-consistent: home rails use kit; others use CY tokens (no kit equivalent for the search tiles / ticket cards). 7 states: kit skeleton/empty/retry kept. 8 XL no clipping: home verified; search/square/roam NOT re-shot at XL (time). 9 EN and zh: zh shot for all; EN not shot. 10 builds, 0 errors, no logic changes: yes.

## Round 2 (coordinator review)
1. One title: the greeting is the title block; the nav bar is hidden while the hero header exists (`HomeFeedView.hasHeroHeader`), the "首页" large title is gone.
2. `homeFeed.moreWaysToPlay` already exists in `ui-strings-d2.json` with EN + zh-Hans ("更多玩法"); no new key. It still renders English in shots because Resources/*.xcstrings is off-limits for D2: the integrator must merge the json (an unrelated existing key `social.guideTemplates.browse` also has 更多玩法, not reused).
3. New kit component `App/DesignSystem/CYHeroBanner.swift` (`CYHeroBanner` + `CYHeroBannerItem`): full-width 16:9 rounded pager with capsule page dots, brand gradient when a slide has no HTTPS cover, renders nothing when there are no items (no empty frame). `HomeFeedView.bannerSection` now uses it (taps keep the same destinations). The d2-home fixture returns 3 synthetic cover-less banners (other fixtures/tests still get none).
4. Price regression fixed: rail meta is `date · place · ¥12.5 起` (EN "From ¥12.5"), tabular digits, em dash when the amount is unknown; meta wraps to 2 lines so 起 is never truncated (`CYImageCard(metaText:)` takes a pre-formatted string).
5. Leftovers: XL, EN and zh shots for home, search, square and roam; fresh compare images for all four. "See all" stays hidden (no destination exists).

Shots: `design-report-d2-shots/{home,search,square,roam}-{zh-dark,en-dark,zh-dark-XL}.png`, `compare-*.png` (reference left, ours right).

## Open issues
- "More ways to play" / "More ways to find" show English until the integrator merges `ui-strings-d2.json` into the xcstrings.
- Home XL: search placeholder truncates to "…" in the hero pill (pre-existing placeholder length, two lines max).
- Gap between the "More ways" row and the banner is generous; the mini-program has the banner as a full-bleed backdrop behind the greeting (not replicated).
- Roam intro cards are white ticket cards on dark by reference; square/roam fixtures show unrelated sections below the fold unchanged.

## Round 3: player-first sweep (EN shots, real views)
Base: `ui/d2` merged with `ui/d1`, `ui/d3`, `ui/d4`, `ui/d6` (all built clean on the kit). **`rc/20261108` does not build** (see Blockers), so shots come from this merged tree; the same views live on rc. One build, one batch: `design-batch.sh d2` (contact sheet in `/Users/fanning/chengyin-refs/design-reports/d2/contact-*.png`, single shots `batch-*.png`).
New DEBUG fixtures (`D2Fixture`, registered): `d2-search-results` (+ `--design-search-keyword <text>` DEBUG hook in `GlobalSearchView`), `d2-play`, `d2-city`, `d2-npc`, `d2-inbox`, `d2-me`; shots use `--uitesting-reset-language` so EN really is EN.
| Page | Fixture / real view | Reference | Result |
|---|---|---|---|
| Home EN + XL | `d2-home` (HomeFeedView) | player-e2e 022 | one title, banner, price "From ¥12.5"; XL stacks chips, search hint wraps to 2 lines |
| Search results | `d2-search-results` (GlobalSearchView) | 014/082 | pill field, kind tabs, shelf cards; offline label shows (fixture) |
| Play (started) | `d2-play` (PlayExperienceView, D6 skin) | none (derived from roam chrome) | map ground, clock + 2 glass buttons, one Continue pill, task panel |
| Roam | `d2-roam`, `d6-real-live` | roam-intro-nrc | D6 map + GO + peek sheet |
| City / NPC | `d2-city` (CityPlayerView), `d2-npc` (ShopNPCView) | none | city nav title made inline so the city name is the only title; NPC is unchanged |
| Notices | `d2-inbox` (MessagingHomeView) | 021/062 | segmented All/Channels/Direct, avatar rows, unread badge |
| Me / profile | `d2-me` (AccountView) | 059 | grouped dark sections; identity card; wallet/orders entries |
| Wallet, orders EN | `wallet`, `orders-list` (D3) | D3 compares | EN reviewed |
| Onboarding | `welcome` (WelcomeView) | none | merchant role button hidden (`WelcomeView.showsMerchantChoice = false`); only "Register as a player" + browse |

## Round 3 blockers and notes
- `rc/20261108` fails to compile with this toolchain: `Core/UGGameplay.swift:368,544`, `Core/ContentContractV1.swift:520` (optional chaining on non-optional `PlayWireValue`, missing `return`), `Resources/BackendErrorCatalog.xcstrings` (no `version` key), kit files (`CYCachedAsyncImage:101`, `CYHeroHeader:48`, `CYScreenStyle:28,150`, `CYListRow` verbatim init used by `MerchantMarketingView:159`) and `QuestifyApp.swift` `SessionRootView.body` ("failed to produce diagnostic"). Not fixed here (Core / Resources / QuestifyApp are off-limits); the integrator must fix before the RC builds. rc also lost the d1/d2 fixture registry cases (restored here).
- `WelcomeView.showsMerchantChoice = false` removes `welcome.merchant`; `Tests/AppUITests/EntryFlowTests.swift` lines 14 and 42 still expect it (tests not edited).
- Me tab still lists the merchant section (merchant overview/projects/application) for players; not hidden (routing/gating decision).
- Play fixture shows its own "Switch synthetic account" host button; the city/NPC/me shots are unconfigured-session states (balance and profile show em dash).
- Order cards: order number can truncate next to a wide status chip ("A2026092701F…"); not fixed.
- zh shots taken for home, search results, me, inbox, city; zh strings for new keys still wait on the integrator's xcstrings merge.
