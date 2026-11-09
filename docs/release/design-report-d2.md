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
