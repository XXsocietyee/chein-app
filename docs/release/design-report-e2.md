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
