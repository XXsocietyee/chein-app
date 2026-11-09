# Design report E2: PLAY and CITY family (branch `ui/e2`)

**Status: NOT BUILT, NOT SCREENSHOTTED.** The base `rc/20261108` did not compile when I started (three errors listed below). The owner then ordered a stop to all builds (machine overload, load average 62), so every change on this branch was written without a compiler or simulator. No contact sheet exists. The first batch after the coordinator's GO must be treated as the compile check.

## Base fixes (not part of my family, needed to compile)
- `Core/UGGameplay.swift`: missing `return` (already fixed upstream in `cfbc9aa75`, merged).
- `App/ObjectBadgeViews.swift:247`: `CYListRow(verbatim:…)` needs a `leading` closure.
- `App/GrowthLeaderboardView.swift`: duplicated `score(alignment:)`.
- `App/DesignSystem/CYCachedAsyncImage.swift`: `$0 != 0x7F` on `Unicode.Scalar` (now `$0.value`).

## Already designed by earlier workers (left alone)
Roam browser, live roam, play orientation, play session and map chrome (d6); roam passport tabs (d2); badge wall and stamp album (d4); orient score (kit already used); timed-challenge view (kit already used). An earlier mechanical `cyGroupedSurface` pass over these files was reverted.

## Restyled on this branch (real views, kit components, presentation only)
| Page | File | Change |
|---|---|---|
| City player | `CityPlayerView.swift` | hero title, status chips (season state, membership), one `CityEntryRow` card per entry, kit empty/skeleton, point rows as cards |
| City game panel | `CityGamePanel.swift` | stat tiles (actions, holdings, points; unknown = em dash), property cards with chips, roll/confirm = primary pill, cancel/refresh = tertiary |
| City value | `CityPlayerValuePanel.swift` | card surface, primary bind, skeleton |
| City task history | `CityTaskHistoryView.swift` | hero, item cards with status chip, secondary refresh |
| City rules, arrival, participation, onsite/neutral task, ordered map, acquisition, action budget, snapshot, redeem, merchant ops/value, recovery | `City*View.swift` | `cyGroupedSurface` page ground (Form/List stay native) |
| NPC chat | `ShopNPCView.swift`, `NPCQuickQuestionBar.swift` | avatar identity row, secondary quick questions, page ground |
| NPC chat data, character cards | `NPCChatDataView.swift` | `cyGroupedSurface` only |
| Chapter story reader | `ChapterStoryView.swift` | hero title, voice/thought cards, primary return pill, kit empty |
| Journey / journal | `JourneyNarrativeView.swift`, `PlayerJourneyViews.swift` | big tabular discovery counter, hero ending title, secondary ask button, surface |
| Free exploration | `FreeExplorationViews.swift` | hero, kit cards, status chips, primary ending button, skeleton/empty |
| Explore completion | `ExploreCompletionView.swift` | status chip + big collected counter, kit empty/skeleton |
| Play node detail | `PlayNodeDetailView.swift` | heavy title, status chip, primary review pill, kit states |
| Object card reveal | `PlayObjectCardRevealView.swift` | hero, card surface, secondary frame buttons |
| Stamp result | `RoamCreatedStampView.swift` | hero, primary browse pill, skeleton, kit empty |
| Medal share | `RoamMedalShareView.swift` | hero name, primary prepare, secondary share |
| Roam history + shared roam cards | `RoamHistoryViews.swift`, `RoamExperienceComponents.swift` | `RoamExperienceCard` is now a kit card (affects every roam experience page), kit notice/issue, big km figure |
| Other Form/List pages | ~45 `Play*`, `Roam*`, `Object*`, `Free*` files | `cyGroupedSurface` page ground |

## Fixtures (`App/DesignFixtures/E2Fixtures.swift`, DEBUG only, "DEBUG fixture" strip)
`--design-fixture` names: `e2-timed-stopwatch`, `e2-timed-reaction` (poi-challenge view), `e2-dice`, `e2-journey`, `e2-chapters`, `e2-chapters-empty`, `e2-stamp-camera`, `e2-badge-detail` (badge-3d), plus aliases `e2-city`, `e2-npc`, `e2-stamp-album`, `e2-badges` onto the D2/D4 hosts.

## Pages left (no synthetic host or no restyle yet)
City rules / arrival evidence / participation / orientation / ordered map / onsite tasks (need runtime owners and Core fixtures, so only the page ground changed), free-exploration bundle launch, explore completion (no fixture: needs `ProfileReading` origin), chapter story reader (needs a `PlayExperienceCoordinator`), game journal sections, play kit forms, roam history share, passport tools. None has a screenshot.

## Not verified
Checklist items 7 to 10 (states, XL, EN/zh, builds) are all open. Possible compile risks to look at first: the Python-inserted `.cyGroupedSurface()` after `Form {}`/`List {}` in ~45 files, `CYPillButton(...)` argument order in `CityTaskHistoryView`/`CityGamePanel`, and `E2Fixtures.swift` initializers.

## New strings
None added (all changes reuse existing keys). Unknown city stats now show an em dash instead of the old "unavailable" key.

## Update (after GO attempt)
The one batch was attempted and every build failed on base errors (not on my pages). Eight base fixes are on this branch (duplicates of the integrator's `ui/main` fixes; drop them when merging `ui/main`). Since then, blind and unbuilt: compare-question page, city value panel, object card reveal, and 30 plain `ContentUnavailableView` uses in the family became `CYEmptyState`. Waiting for a compiling `ui/main` SHA (currently `85ab77ac3`), then merge, run ONE batch with `docs`-listed fixtures (`e2-*`), fix, and push.

## Benchmarks (Mobbin, ADA bar)
- Badges / collection (stamp album, badge detail): Reddit achievements sheet https://mobbin.com/screens/74ea7ef7-6fc8-4ca8-af3d-2ad3e160a256 (round medal grid, caption under each, one pinned black CTA); WHOOP levels https://mobbin.com/screens/6fe807ad-d87b-44ee-a924-3414682bd15a (locked tiers dimmed with a ring, dark layered surface); Apple Games achievements https://mobbin.com/screens/43c701fa-a4b4-4191-bdc2-ba5bd7a84a5b (progress ring and percentage per tile).
- NPC chat (`ShopNPCView`, `NPCQuickQuestionBar`): Venmo assistant https://mobbin.com/screens/fca8654a-58d4-4e59-8f79-efdf307b47f2 and Expedia virtual agent https://mobbin.com/screens/6369c0d4-8839-4a45-a2b0-78c5d322f9d8 (outlined quick-reply pills above the composer, AI disclosure under the greeting); WHOOP coach https://mobbin.com/screens/ec1b77cc-630e-479d-be4f-1f97d7f19052 (suggestion chips docked above the input).
- Applied so far: quick questions are outlined secondary pills; NPC identity is an avatar row; generated cover art (`CYCoverArt`, decoration only) behind the city title and the free-exploration card pack; `.sensoryFeedback` selection on city point select and success on an applied city action.
- Not applied yet (needs a compile and screenshots first): progress rings on stamp/badge tiles, matchedGeometry on badge unlock.

## Verified batch (merged `ui/main` 357154584, BUILD_EXIT=0, 31 shots)
Contact sheet: `docs/release/design-report-e2-shots/contact-e2.png` (full set `/Users/fanning/chengyin-refs/design-reports/e2/batch-*.png`: EN, zh-Hans, and accessibility-XL for city, NPC, stopwatch, chapters). The shots were taken from the build before the `CYCoverArt` commit, so the cover art and haptics are not yet seen.

What the sheet shows: city page (hero title, status chips, entry row, stat tiles 3/3, 0/2, 5, primary "Start this round"), NPC chat (avatar row, outlined quick-question pills), timed stopwatch/reaction, dice, journey check, stamp camera, badge detail, stamp album, badge list, roam history (big 1.4 km, tool pills, route cards), POI, sticker, play records, backpack, finish sheet, object cards. zh-Hans is fine on all.

Defects found and fixed after the sheet: the city panel title showed the raw key `cityGame.title` (the section header does not read the `CityGame` table; now a table-aware `Text`).
Defects still open:
- `e2-chapters` and `e2-chapters-empty` stay on "Loading..." (the enrolled-chapters view model never becomes visible inside my fixture host, cause not found), so that page has no valid shot.
- Accessibility-XL city: the "CITY ownership and original receipts" line and the title take over the first fold (no clipping, but weak hierarchy).
- No page reached photo/cover imagery in the shots.

## Self-score (1 to 10, six ADA lenses averaged; honest)
| Page | Score | Why under 8 |
|---|---|---|
| City player + game panel | 7 | no imagery in the shot (cover art added after), property cards still dense |
| NPC chat | 7 | composer area plain; no avatar art |
| Timed challenges (e2-timed-*) | 5 | large empty black area, no progress ring or motion |
| Dice | 5 | bare die on black, no roll moment |
| Journey check, play records, backpack, finish sheet | 5 | grouped lists with grey rows, not restyled beyond the page ground |
| Stamp camera, stamp album, badge list/detail (D4/earlier) | 6 | grey placeholder tiles, no collectible feel |
| Roam history | 7 | route sketch is a grey box |
| Object cards, POI, sticker | 5 | grey boxes, small type |
Pages under 8 need rework: all of the above. This is not ADA quality yet; it is "clean".

## Final batch (BUILD_EXIT=0, 16 shots, `docs/release/design-report-e2-shots/contact-e2-final.png`)
Seen and working: city page hero on generated cover art (`CYCoverArt`) with status chips, stat tiles, primary pill; stamp album banner "Stamps: 3" on cover art, stamp cards on cover art, single title; stopwatch is now a large ring timer with a primary Start; zh-Hans fine on all; XL city: no clipping.
Rescored after the batch: city player/game panel 8, stamp album 8, timed challenges 7 (ring and type are strong, rest of screen still empty), NPC chat 6.5 (bubbles and composer unchanged), badge detail 6 (medal image unavailable placeholder), journey check 5 (grouped list), roam history 7 (grey route box).
Unverified: after the last batch I changed only the city header chips (they now stack vertically when `ViewThatFits` fails at XL, previously "You have…" truncated). Unfixed: `e2-chapters`/`e2-chapters-empty` still stay on "Loading…" even with readers in `@State`, so the enrolled-chapters page has no valid shot; XL city still shows a very large "CITY ownership and original receipts" line above the hero.
Not done: pages left in "Pages left" above (city rules/arrival/participation/onsite/neutral, bundle launch, game journal sections, play-kit forms, roam share/passport tools) are restyled only with the page ground; no collection grid with progress ring (the album has no denominator, so a ring would be fake), no NPC bubble rework, no roam-route rework.
