# polish-search r3 — receipt (`design/r3-search`, base `origin/ui/combined-r7`)

Brief: `docs/briefs/round3-1127.md` row `polish-search` (P18 empty search, result rows name · distance · area, P10 loading words, both languages).
MP source read: `pages/search2/index.wxml|js`, `pages/search2/utils/search-history.js`, `utils/hot-words.js`, `pages/search2/result/index.wxml`, `utils/discover-search.js`, `utils/category-icon.js`.

## Principles each screen failed before (one line each)

| Screen | Failing before | Now |
|---|---|---|
| Search empty page (`App/GlobalSearchView.swift`, also hosted by 首页) | P18: map/nearby entry at the very bottom; history had only Clear (no per-row delete); categories a large-button grid; recommended words as list rows | Nearby section first; recent searches with ✕ + swipe remove and **Clear all**; recommended + categories as wrapping capsules |
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
- MP places 在地图上找 at the bottom of search2; moved to the top per P18 "Nearby first" (brief explicit).
- No Swift compiler in the cloud: not built or run on simulator; edits mirror existing patterns (`AnyLayout`, `TemplateChipFlow`, `.swipeActions`, `ProgressView(LocalizedStringKey)`). A fixture screenshot of `--design-fixture` search with seeded history is still to take.
- Merchant features and the story-flow theme untouched. Nothing deployed.
