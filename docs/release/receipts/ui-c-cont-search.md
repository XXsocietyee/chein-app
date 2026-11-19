# Receipt: ui/c-cont-search (continuity r1, item 1: 首页 search field → global search)

Brief: `origin/design/continuity-brief:docs/briefs/continuity-r1.md`. Branched from `origin/ui/main`.
Swift is not installed here: nothing on this branch has been compiled, run or screenshotted. Every API was
checked against existing uses in the repo and against the iOS 17 deployment target, and the one API with no
precedent in the repo is listed under "Compile risks".

Skills: all three repos cloned (`apple-design-skills`, `emilkowalski/skills`, `make-interfaces-feel-better`) and read.

## ⚠️ Needs owner approval: presentation structure change

Global search on 首页 was a `.sheet` holding its own `NavigationStack`. It is now an **in-page state**: an
`.overlay` on the 首页 `NavigationStack` in `SessionHomeFeedView` (`searchLayer`). The overlay keeps its own
`NavigationStack`, so results, 在地图上找 and the 筛选 sheet push and present exactly as they did inside the sheet,
and the home router (`router.homePath`) is untouched. What changes for users:
- swipe-down-to-dismiss is gone; **取消** (top row, same `globalSearch.close` identifier as the old 关闭) and the
  VoiceOver escape gesture close search.
- the old sheet's glass (`cyPlayerSheetGlass`) is gone; the search ground is `CYColor.bgPage`, the same colour the
  search list already painted.
- the search screen's field moved from the first list row into a top row: field, 筛选, 取消. The list content
  below it (history, 推荐搜索, 类别, results, map entry) is unchanged.

## Item 1: search becomes a state of 首页

### Files touched
- `App/SessionHomeFeedView.swift`: removed the `showsGlobalSearch` sheet; added `HomeInPageSearch` state,
  `searchLayer`, `openSearch` / `searchFieldPlaced` / `closeSearch`, and publishes `homeSearchSource` to the feed.
- `App/HomeSearchTabParityViews.swift` (hero header only): `HomeSearchSourceBox`, `HomeSearchSourceContext`,
  the `homeSearchSource` environment value and `HomeSearchSourceField` (records the field's window frame, hides it
  with no fade while search stands in for it, returns VoiceOver focus on close).
- `App/GlobalSearchView.swift`: `GlobalSearchInPageHost` environment value; when it is set, the inline field row
  is dropped and `hostedFieldRow` draws the same field (same `searchMap.keyword` id, spinner, clear, submit) in a
  top `safeAreaInset`; the morph modifiers; list motion key; contextual icon transition.
- `App/HomeFeedView.swift`: **not touched.** The feed's `.searchable` modifier is disabled whenever the hero header
  is shown (always true on 首页), so the source field is the hero's, and the host passes the source context through
  the environment instead.
- `App/SessionGlobalSearchView.swift`: not touched (reused unchanged).

### Approach
One animated value, `search.progress` (0 = the field sits on the 首页 field, 1 = search at rest), driven by
`CYMotion.standard` (0.3 / 0.85). Every piece derives from it inside `Animatable` modifiers that are evaluated per
frame, so the windows below are exact and 取消 or a second tap reverses or retargets from wherever it is.

| Element | Role | Progress window | Motion |
| --- | --- | --- | --- |
| Search field capsule | Lead | 0 → 1 | top-leading corner and size interpolate from the 首页 capsule box to the top-row box (a background layer, so nothing reflows); icon + text ride along with `offset` |
| Placeholder text | Lead (part) | 0 → 1 | scales 14 pt (`--cy-type-body`, the 首页 size) → the field's `@ScaledMetric` body size, anchored leading; never cross-fades |
| Map glyph (only the 首页 field has it) | Decoration | 0 → 0.3 | fades out |
| Ground (`bgPage`) over feed, bar and large title | Support | 0 → 0.3 | fades in; this is the large title fading out (the overlay covers the bar) |
| 取消 | Support | 0 → 1 | slides in from the trailing edge by its own width + page margin (`visualEffect`) |
| 筛选 tile | End-only | 0.5 → 1 | fades in |
| History / 推荐搜索 / 类别 / map entry (the list) | End-only | 0.5 → 1 | fades in |
| Results while typing | — | after the move | list swaps and row inserts/removes run on `CYMotion.standard` via `.cyAnimation(value: listMotionKey)` |

Sequence of an open: tap → overlay mounts with progress 0 and the field invisible → the field measures its resting
window frame (`onFieldPlaced`) → in that same update the 首页 field hides (opacity 0, no animation) and the
progress animates to 1. So the 首页 copy and the search copy are never both visible. Keyboard focus is set as the
move starts, so the keyboard rises with it (iOS search behaviour). 取消 drops focus first, then animates progress
back to 0; on completion (`.logicallyComplete`, generation-guarded) the overlay unmounts, the 首页 field reappears
in the same frame, and VoiceOver focus returns to it.

No-travel cases cross-fade the whole layer on the same progress with no movement or scaling: Reduce Motion
(`CYMotion.reduced`, 0.2 s), iOS 17 (the overlay's `NavigationStack` ground cannot be cleared before iOS 18), the
toolbar 🔍 when the hero field has been scrolled above the top row, and fixtures with no hero.

The 🔍 toolbar button and the map button in the 首页 field still open the same search, as before.

### Skill rules applied
- apple-design-motion: "Springs over fixed easing" and "Interruptible + velocity handoff": one spring-driven value,
  retargeted mid-flight; "Animate transform/opacity only": content moves by `offset`/`scaleEffect`; only the capsule
  background layer's frame is interpolated, and it sits in `.background` so nothing reflows.
- apple-design-interaction: "Never block input behind a spinner": the layer stops hit-testing the moment 取消 is
  pressed, so the feed (and the toolbar 🔍, which re-opens mid-close) take touches during the reverse.
- apple-design-os / perceived-performance-and-input "Focus is navigation": `@FocusState` on the field when open,
  `@AccessibilityFocusState` back on the 首页 field when closed; `.isModal` on the layer.
- emil/choreograph: Step 1 cast (Lead = field, Support = ground + 取消, Decoration = map glyph, End-only = list,
  筛选); "Exits ... match its entry": 取消 runs the same progress backwards; Hard rule 2 "Never stagger on
  keyboard-triggered UI": typing animates list inserts/removes together, no new stagger added; "one entrance per
  container": the list fades as one block, not row by row.
- emil/gestures and animation-vocabulary: "interrupt, don't queue" (generation token; re-open retargets).
- emil/break-ui: checklist below covers long text, empty, rapid taps and interruption.
- make-interfaces-feel-better §7 Contextual Icon Animations: spinner and clear (x) in the hosted field trade
  places with scale 0.25 → 1, opacity 0 → 1, blur 4 → 0 on the product spring. §19 Motion restraint: no new motion
  on the per-keystroke path besides the list swap.
- Brief: content only at the start fades out in the first 30 %; content only at the end fades in after 50 %; text
  that changes size scales; the moving panel is opaque; 0.3 / 0.85 product spring (~450 ms settle); Reduce Motion
  0.2 s cross-fade.

### First and last frames
- **First frame (progress 0):** the search field's capsule exactly covers the 首页 capsule (same window rect,
  same `bgElevated` fill), with the magnifier and placeholder at the 首页 positions and size, and the map glyph at
  its 首页 trailing spot. The ground and the list are at opacity 0 and 取消 is off the trailing edge, so the screen
  is pixel-identical to 首页 at rest except two sub-pixel details listed under "Known differences".
- **Last frame (progress 1):** the field is the search screen's own field in the top row: the same capsule
  (`searchNightPill`), 筛选 tile and the list exactly as `GlobalSearchView` draws them, over `bgPage`.
- **After 取消:** progress 0 frame again, then the overlay unmounts and the 首页 field is visible in the same frame.

### Known differences at progress 0 (for the integrator to judge on device)
- the 首页 capsule uses `Capsule()` (circular) and the search field `Capsule(style: .continuous)`: corner shape
  differs very slightly.
- the 首页 magnifier and placeholder are `textSecondary`; the field's magnifier is `textTertiary` and its
  placeholder uses the system placeholder colour.

### Search screen states polish (content unchanged)
- spinner ↔ clear button: contextual icon transition (above), hosted field only. The inline field (used by other
  hosts and fixtures) is left byte-for-byte, because contract checks match its source text.
- suggestions ↔ loading ↔ failure ↔ results ↔ empty ("没有结果") swaps now animate on `CYMotion.standard` instead
  of snapping (`listMotionKey`); the skeleton's existing timed cross-fade is unchanged.

### Compile risks (no Swift toolchain here)
- `containerBackground(.clear, for: .navigation)` (iOS 18, inside `#available`) has no precedent in this repo. If
  the SDK rejects the `.navigation` placement, drop `HomeSearchClearStackBackground` and set `travels = false`
  (cross-fade everywhere) in `openSearch`.
- `Animatable` `ViewModifier`s holding `@State` (`GlobalSearchFieldMorph`) follow `CYFlipFace` in `CYAlbum.swift`.

## Checks
- `python3 -B tools/check_scaffold.py`: PASS.
- `python3 -B tools/check_design_lint.py`: PASS.
- `python3 -B tools/contract_ratchet.py --check`: 185 failing, baseline 184, **no new failure from this branch**.
  The one non-baseline failure, `test_workshop_paid_professional ... test_current_generic_draft_cas_reuses_real_reader_with_bounded_paging`,
  reads only `Core/WorkshopPaidProfessionalPreparation.swift` (untouched here) and already fails on `origin/ui/main`.
- `Tests/ContractChecks/test_global_search_category_recovery.py`: `CURRENT_VIEW_SHA256` (a byte pin of the shipping
  `GlobalSearchView.swift`) bumped to the new file hash, as earlier branches that edited this view did. All other
  failures in that module are already in the baseline. The inline field row is byte-identical, so the
  source-text contracts on `searchMap.keyword` still pass.

## LOCAL VERIFICATION CHECKLIST (integrator)
Record at 10 % speed (Simulator ▸ Debug ▸ Slow Animations) and step frame by frame.
1. 首页 at rest: identical to `ui/main` (field, map button, greeting). Search at rest: field, 筛选, 取消 top row;
   list identical to the old sheet's list.
2. Tap the 首页 field: frame 0 shows ONE field exactly over the 首页 one (no double, no flash); the large title, 消息
   and 🔍 fade under the ground by ~30 %; 取消 slides in from the right; history/推荐/类别 and 筛选 appear only
   after the field is about half way; the keyboard rises with the move and the caret is in the field.
3. Tap 取消: everything reverses; the field lands exactly on the 首页 field and the swap is invisible; keyboard drops.
4. Tap 取消 mid-open, and tap 🔍 (toolbar) mid-close: both retarget smoothly, never a jump or a stuck overlay.
5. Fast repeated taps on the 首页 field / 取消: no second overlay, no stuck hidden 首页 field.
6. Scroll the feed so the 首页 field is above the bar, then tap toolbar 🔍: cross-fade, no flight from off-screen.
   Partly scrolled (field under the bar): the field rises from there.
7. Type: suggestions → results animate; clear (x) and spinner trade places with scale/blur; submit, no results,
   failure + 重试, guest gate. Long keyword (40+ CJK chars) and long placeholder in English at the largest
   Dynamic Type size: the field truncates, 筛选 and 取消 stay fully visible (check iPhone SE width).
8. Open a result, go back: search state, keyword and results are preserved. Swipe back half way and cancel the
   gesture: search remains. Open 在地图上找, back. Open 筛选 sheet, apply.
9. Empty history / empty recommended / category failed / no network.
10. Light and dark (player is always dark; check any light host if one exists).
11. Reduce Motion (system and in-app setting, or `--uitesting-reduce-motion`): 0.2 s cross-fade, no move, no slide, no scale.
12. iOS 17 simulator: cross-fade path; no system-coloured flash under the feed.
13. VoiceOver: on open, focus lands in the search field; two-finger scrub (escape) closes; on close focus is back on
    the 首页 search field; the feed is not reachable while search is open.
14. Tab bar: confirm whether `GlobalSearchView`'s `cyHideTabBar()` now hides the tab bar from inside the overlay
    (the sheet used to cover it); either is acceptable but note which.
15. Sign-in from the search guest gate: search closes instantly and sign-in shows.
16. Switch account / market (home scope change) with search open: search closes, no stuck hidden field.
17. UITests: `SearchMapFlowTests` etc. still find `searchMap.keyword` and `globalSearch.close`.
