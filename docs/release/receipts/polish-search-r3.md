# polish-search r3 — receipt (`design/r3-search`, base `origin/ui/combined-r7`)

Brief: `docs/briefs/round3-1127.md` row `polish-search` (P18 empty search, result rows name · distance · area, P10 loading words, both languages).
MP source read: `pages/search2/index.wxml|js`, `pages/search2/utils/search-history.js`, `utils/hot-words.js`, `pages/search2/result/index.wxml`, `utils/discover-search.js`, `utils/category-icon.js`.

## Principles each screen failed before (one line each)

| Screen | Failing before | Now |
|---|---|---|
| Search empty page (`App/GlobalSearchView.swift`, also hosted by 首页) | history had only Clear (no per-row delete); categories a large-button grid; recommended words as list rows | MP order kept (field + 筛选 → 搜索历史 → 推荐搜索 → 类别 → 在地图上找); recent searches with swipe remove (additive) and **Clear all**; recommended + categories as wrapping capsules |
| Search results loading | P10: bare spinner | "Searching… / 正在搜索…" |
| Category loading | P10: bare spinner | "Loading categories… / 正在加载类别…" |
| Map explorer (`SearchMapExplorerView`) | P10: bare spinner (load, refresh, pagination); P18: nearby rows name + address only, city place cards no distance | mode-specific words; nearby rows `name` then `distance · address`; city place cards add a distance line |
| Place detail (`SearchMapDetailViews`) / results sheet (`SearchMapResultsCapsule`) | P10: bare spinner | spinner with words |

## Done

- `App/GlobalSearchView.swift`
  - `nearbySection` (new, top of the empty page): **Explore nearby** with the reason line ("Choose a spot on the map to see places and events around it." — the nearby map uses a chosen search center, not GPS, so the copy says exactly that), **Find on the map** (MP `search-actions__map` 在地图上找), and the remaining finders menu (public layers, shops). Under results the old `mapSection` stays last; on the empty page it is not drawn twice (`showsSuggestions`).
  - Recent searches (MP 搜索历史, local, 10 max): each row has a trailing ✕ (44 pt, VoiceOver label "Remove “x” from search history") and a trailing swipe **Remove**; header button **Clear all / 清空** (MP 清空). Header en "Recent searches" / zh 搜索历史.
  - 推荐搜索 and 类别 as `.bordered` + `.buttonBorderShape(.capsule)` in a wrapping row (`TemplateChipFlow`), falling back to a column at accessibility sizes (P12). Selected category carries `.isSelected`.
  - Category capsules show the MP category icon (`SearchCategorySymbol`, same keyword rules/order as `utils/category-icon.js`, fallback storefront).
  - Loading `ProgressView("search.r3.loading.results")`, category `ProgressView("search.r3.loading.categories")`.
- `App/SearchMapComponents.swift`: `SearchMapLocalHistory.remove(_:namespace:current:)` (Keychain write shared with `add` via `write`; an emptied list deletes the item); `SearchCategorySymbol`; activity result rows show the area line with a map pin.
- `App/SearchMapExplorerView.swift`: loading words per mode (`search.r3.loading.nearby` / `.map`), refresh and pagination spinners show their existing words; nearby rows `name` / `distance · address` (straight-line from the search center via `SearchRoutePreview.distance`, formatted by `LocaleDisplay.distance` → `350 m` / `0.2 mi`); city place cards add a distance line.
- `App/SearchMapDetailViews.swift` (×2), `App/SearchMapResultsCapsule.swift`: spinners with words.
- Strings: `docs/port/strings/polish-search-r3.json` + `Resources/Localizable.xcstrings`, 11 keys, en + zh-Hans.
- Contract pins updated with one-line reasons in `Tests/ContractChecks/test_global_search_category_recovery.py` (GlobalSearchView + SearchMapExplorerView sha re-pin; retry-section end marker `LazyVGrid` → `capsuleLayout {`). Forward `contract()` still returns `[]`.

## Gates (last run)

- `python3 tools/generate_project.py` — OK
- `python3 tools/check_scaffold.py` — PASS (0 FAIL lines)
- `python3 -B tools/check_a11y_lint.py` — PASS, 0 new
- `python3 -B tools/contract_ratchet.py --check` — 104 failing, baseline 104, **new 0**, fixed 0

## Not done / notes

- **Distance on global search result rows**: the global search reads (`/api/topic/list`, `/api/activity/list`, club, merchant) send no location and return no distance; MP search2/result shows no distance either (MP-first). Rows show name → area (activity address); distance appears where the data has a position (nearby + city map explorer).
- MP has no per-row history delete; added per P18 as an additive control (Clear all keeps MP 清空 behaviour).
- ~~MP places 在地图上找 at the bottom of search2; moved to the top per P18~~ — reverted in round 3 (continue), see below: the OWNER RULE says principles never override MP order.
- No Swift compiler in the cloud: not built or run on simulator; edits mirror existing patterns (`AnyLayout`, `TemplateChipFlow`, `.swipeActions`, `ProgressView(LocalizedStringKey)`). A fixture screenshot of `--design-fixture` search with seeded history is still to take.
- Merchant features and the story-flow theme untouched. Nothing deployed.

## Round 3 (continue) — OWNER RULE pass (MP order first)

Merged `origin/ui/combined-r7` into `design/r3-search` (no conflicts). Read the OWNER RULE in `docs/briefs/round3-1127.md`.

| MP page | Native file | MP sections present (order) | Fix this pass / optimizations kept |
|---|---|---|---|
| `pages/search2/index` | `App/GlobalSearchView.swift` | search field + 筛选 ✓ · 搜索历史 + 清空 ✓ · 推荐搜索 ✓ · 类别 (loading / error + retry / list, hidden when empty) ✓ · 在地图上找 ✓ **last** | **在地图上找 back at the MP position** (bottom); the "Explore nearby" header section and its reason line removed (not an MP section) — the nearby/public layers/shops finders stay in the existing "More ways to find" menu inside the same map block. Per-row history delete is **swipe only** (trailing ✕ button removed; VoiceOver gets the same action as a named accessibility action). System `.searchable`, capsule chips, P10 loading words kept. |
| `pages/search2/result` | `App/GlobalSearchView.swift` `results(…)` + `UnifiedSearchEntry` | field ✓ · tabs (system scope bar) ✓ · club denied / partial failure inline ✓ · loading / 没能完成搜索 / 没有找到 ✓ · result list ✓ · 没有更多了 + 重新搜索 ✓ | **在地图上找 no longer drawn under results** — MP result page has no map entry (it is a search2-only block). |
| `pages/searchmap/index` | `App/SearchMapExplorerView.swift`, `App/SearchMapResultsCapsule.swift` | search + 筛选 row ✓ · offline bar ✓ · map + 定位 (choose area) ✓ · result capsule ✓ · 全部 N 个结果 sheet ✓ · selected-marker card + 查看活动详情 / 查看关联主题 ✓ · 筛选 sheet ✓ | **筛选 row now before the offline bar** (MP `smapso_bar` sits above `smap-offline`). **Sheet order to MP**: 正在更新商家节点… first, then error / empty / loading, then 正在更新地图结果…, refresh or page inline error (更多活动加载失败 · 重试这一页 — **added**), list, **加载更多 — added** (was only on the page, MP has it in the sheet; shown when more pages exist and no page error, or the error is a refresh one, as MP A-RPT-7). |

### Task 2
- `pages/mylike` and `pages/crop`: done by `origin/mp/r3-settings` (its receipt rows for `pages/mylike/mylike` and `pages/crop/index`), so not taken here.
- **Result navigation targets vs MP `utils/discover-search.js` TYPE_META** (audit, no change needed except as noted):
  - topic → `/pages/topic/index/index` → `SessionTopicDetailView` ✓
  - activity → scene `play-activity-detail` → `ActivityDetailView` ✓
  - club → `/pages/club/detail/index` → `ClubDetailView` ✓
  - post (unified rows) → `/pages/square/detail/index` → square detail in `UnifiedSearchEntry` ✓
  - gameTemplate → `/pages/templatedetail/templatedetail` → `DiscoveryTemplateDetailView` ✓
  - topicTemplate → MP public topic page; native opens the topic-preview deck with 查看详情 (prior decision R7-PC-A7-1) — flagged for owner, not changed.
  - merchant → MP `merchantHomeUrl(memberId)` (+ toast 这条结果暂不可打开 when no memberId); native `SearchMapMerchantDetailView(id: row id)` — merchant is out of scope, flagged only.
  - searchmap selected card → 查看活动详情 → activity, 查看关联主题 → topic ✓

### Tests edited (MP-driven)
- `Tests/ContractChecks/test_global_search_category_recovery.py`: re-pinned `CURRENT_VIEW_SHA256` (GlobalSearchView) and the `SearchMapExplorerView` sha, each with a one-line reason. No Swift unit/UI test referenced the removed ✕ button or nearby section.

### Strings
- `search.r3.nearby.header|row|reason` are now unused (left in the catalog so parallel lanes merge cleanly; safe to prune later). No new keys: the sheet reuses `mapPagination.*`.

### Gates (this pass)
- `python3 tools/generate_project.py` — OK
- `python3 tools/check_scaffold.py` — 0 FAIL
- `python3 -B tools/check_a11y_lint.py` — PASS, 0 new
- `python3 -B tools/contract_ratchet.py --check` — 52 failing, baseline 52, **new 0**, fixed 0

No Swift compiler here: not built; edits mirror existing patterns (memberwise defaults on the sheet, `.accessibilityAction(named:)`, `ProgressView(LocalizedStringKey)`). Merchant and story-flow theme untouched. Nothing deployed.
