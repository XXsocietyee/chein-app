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

## Open issues
- Hero banner pager not visible in the fixture (synthetic banner reader returns none), so the top of the home differs from the reference.
- "See all" on section headers not added: no destination exists in the real feed.
- Rail price line shows "12.5" without currency/起 in the kit card meta (localized key lookup falls back); needs a small follow-up.
- Search / square / roam XL and English shots outstanding.
- Roam intro cards are white ticket cards on dark by reference; square/roam fixtures show unrelated sections below the fold unchanged.
