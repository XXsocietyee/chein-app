# Design spec D2: player home + discovery (dark theme, #000 page, #1C1C1E cards)

Kit note: `ui/kit` / `CYImageCard` are not published yet. D2 uses the existing `QuestifyImageEntityCard`
(+ `CYColor`/`CYRadius`/`CYSpacing`) and will swap to `CYImageCard` once the kit lands. No look-alike component is added.
Fixtures: existing `--uitesting-module home-feed|discovery|search-map|square|roam` (DEBUG), extended with hero data.

## 1. Home (HomeFeedView + HomeHeroHeaderSectionView)
Reference: `player-e2e-20260927/022-pure-player-home.png` (hero greet row, then 推荐主题 rail of tall image cards), `page-polish-20261102/shots/p05-home.png`.
```
Hi, <nickname>!              (avatar)     <- large heavy headline
✓ 玩家 · 📍 City
[ 🔍 search topics, activities…      ]  (map ▸ moves into search field trailing icon)
[ hero banner pager  16:9, r=24, dots ]
推荐主题                       <- section header, bold 22, large
[ img card ][ img card ][ img…  <- horizontal rail, 280pt cards
活动精选 / 即将上线             same pattern
继续游戏 banner (only when data)
探索  [segment] [category]   list of cards
```
- Stays: greeting, role/city chip, search entry, map-search entry, 3 action banners, hero banners, 3 rails, explore stream.
- Demoted: 3 action banners (成为俱乐部 / 成为商家 / 和朋友报名活动) move from a bordered chip row to one quiet text row
  "More ways to play" (menu); map-search entry becomes the trailing icon inside the search pill; segmented picker + category
  Picker stay in the Explore section header (2 controls).
- Primary action: the search pill (one). Visible controls besides: city menu, avatar, map icon (3).
- States: loading = CYSkeleton rail; empty rail = single secondary line; error = retry row; unknown price/date = em dash.
- Type: headline `largeTitle.heavy` equivalent (CYTypography), section header 22 bold; radii CYRadius.lg; Dynamic Type XL: rails become vertical stacks.

## 2. Search (GlobalSearchView)
Reference: `014-search.png`, `015-searchmap.png`, `page-polish/shots/p01-search.png` (results tabs).
```
搜索                      <- large heavy title
[ 🔍 搜索主题、活动…      ] (filter)
推荐搜索  rounded outlined chips (wrap)
类别      2-column tiles (#1C1C1E, icon + name)
[ ◁ 在地图上找活动与主题点位 ]  full-width pill secondary
```
- Stays: keyword, filters, history, recommended, categories, map/nearby/layers/shop entries, results with kind picker.
- Demoted: the extra "搜索" primary button is removed from the idle state: keyboard Search key submits (control kept via `.onSubmit`, id `searchMap.submit` kept on a button only shown once a keyword exists).
  Nearby / public layers / shop entries move into a single "More ways to find" menu row beneath the map pill.
- Primary: map pill (outlined, reference) is secondary; search field is the primary. States: skeleton categories, empty `ContentUnavailableView`, error issue card.

## 3. Square (SquareBrowserView)
Reference: `017-square.png` (posts with author row, text, rounded image card). Information order kept: composer/workspace entry, feed mode picker, upcoming strip, posts.
- Demoted: workspace/governance/report-progress entries into one toolbar "…" menu (all stay reachable); filter text fields stay inside the mode section.
- Cards: author row + body + rounded r=24 media, dark #1C1C1E, no list separators.

## 4. Roam intro (RoamBrowserView start header + RoamHomeIntroCards)
Reference: `chengyinhub-xcx/docs/screenshots/roam-intro-nrc.png`, `page-polish/shots/p06-roam-settled.png`.
```
漫游                        <- large heavy title
[开始漫游] [漫游护照]        <- segmented tabs
[ ▍START  NO.01 | 开始漫游  ][ NO.02 ... ]  <- ticket-style cards, coloured spine, white body
附近活动  [ map-style card with route ]
```
- Stays: tabs, 4 intro cards, recovery banner, nearby peek, browser list. Toolbar already one trailing menu + display toggle.
- Intro cards: white ticket cards with a coloured spine (SF Symbol + NO.0n), subtitle mono caption, r=20.
- States: not configured / unauthorized / area required use `RoamStatusView` (kept).
