# Design report D6: player play / roam / map (branch `ui/d6`)

Build: `design-run.sh d6 … --design-fixture d6-{play,play-loading,roam,search,live}`, BUILD_EXIT=0, no logic changes.
New: `App/DesignSystem/CYMapChrome.swift` (CYGlassButton, CYGlassCapsule, CYGoButton white circle, CYMapPlaceholder, CYMapCallout, `cyMapSheet` persistent detent sheet, opens at .medium at accessibility text sizes). Fixtures: `App/DesignFixtures/D6Fixtures.swift` (DEBUG, synthetic, map is a static placeholder).
Shots in `design-report-d6-shots/`: `en-*.png` (EN default), `zh-play/zh-roam.png` (zh default), `zh-play-XL/zh-search-XL.png` (zh, accessibility XL), `compare-roam.png` (ref roam-intro-nrc), `compare-search.png` (ref 015-searchmap), `compare-live.png`. Play has no mini-program screenshot: closest ref is the roam map chrome; stated honestly.

## Checklist (design fixtures)
1 info order matches refs (roam: title, passport/menu, info·GO·map; search: back·search·locate, callouts, results pill) yes. 2 one primary per screen (sheet pill / GO / results pill / Pause) yes. 3 <=3 other controls yes. 4 dark yes. 5 no violet yes. 6 kit radii/pill/chip/list rows yes. 7 loading = skeleton in sheet (`d6-play-loading`, not screenshotted); empty/error use kit states (not shown). 8 XL: play and search checked, no clipping of controls (placeholder callouts clip, fixture only). 9 EN + zh checked. 10 builds, no logic changes.

## Demoted controls
Search map: filter moved from the top bar into the results sheet. Play: refresh/route map/end run/hints stay in More or the large detent. Live roam: finish is a glass circle (keeps confirmation dialog).

## Round 2: REAL views re-skinned (branch `ui/d6`)
Builds: `design-run.sh d6 …`, BUILD_EXIT=0, presentation only (no logic, hints, skip, scoring, location or session code touched).
Shared chrome added to `CYMapChrome.swift`: `CYMapScaffold` (full-bleed map + glass controls + `floating` primary + three-detent bottom panel, grabber drags / VoiceOver adjustable; in-view so the existing detail/entry sheets keep working), `CYGoLabel`. `QuestifyDensityMap` gained `fillsHeight` (default false, other callers unchanged).
- **RoamBrowserView** (`pages/roam/index`): map fills the screen, glass area pill, white GO circle (`roam.go`, opens the same start destination), existing list (intro cards, 附近活动, filters, rows, retained read) in the detent panel; inline title; list-only mode unchanged. Empty = `CYEmptyState` (`roam.empty`), issues = `RoamStatusView` now kit state (`roam.error`), loading = `CYSkeleton` (`roam.loading`).
- **RoamLiveSessionView**: fog map ground behind the HUD; primary pill (start/pause/resume) kept; finish demoted from destructive pill to glass circle (same `roam.live.finish`, same confirmation dialog).
- **PlayExperienceView** (orientation): map ground, glass clock capsule + route-map + end-run glass buttons (`playx.run.clock/playRoute.open/playx.run.end`), the one primary pause/resume pill floating above the panel, task list in the panel; save-failed notice moved into the list. Loading/error/disabled use kit skeleton / `CYEmptyState`.
- **PlaySessionView**: overview, loading, issues in the same map + panel (`PlayIssueView` is now a kit state; `play.retry` kept).
- **SearchMapCanvas**: offline canvas is the dark kit map with glass pin capsules (ids, labels, selected trait kept). Live MapKit path unchanged.
- **SessionPlayRuntimeView**: only hosts PlayExperienceView, so its visible chrome is the above; no edits.
Fixtures used (all existing DEBUG hosts): `--uitesting-roam-home [--uitesting-roam-home-scenario empty]`, `--uitesting-module play --uitesting-play-scenario success|loading|error|empty`, `--uitesting-module playExperience --uitesting-play-experience-scenario classic`, `--uitesting-module searchMap --uitesting-search-map-entry markerStyle`. One new DEBUG host: `--design-fixture d6-real-live` (real `RoamLiveSessionView` on the existing `RoamLiveFixture`).
Shots `design-report-d6-shots/real-*.png` (EN, zh, XL = accessibility-extra-large: roam zh, play EN); compares `compare-real-roam/search/live/play.png`. Refs: roam `roam-intro-nrc.png`, search `015-searchmap.png`; **play has no mini-program screenshot**, compared against the roam map chrome (closest layout).
Demoted: live finish (pill to glass circle); play route map / end run (card buttons to glass circles); search map pins (text rows to glass capsules). Nothing removed; all identifiers kept.
New string key `map.panel.size` (grabber VoiceOver label) is in `docs/release/ui-strings-d6.json`, to be merged into the catalog by the owner of Resources.

## Checklist (real views)
1 order matches ref (map, GO, info) yes. 2 one primary (GO / run pill / start pill) yes. 3 <=3 other controls: roam toolbar 2 + area pill; play 2 glass + refresh yes. 4 dark yes. 5 no violet yes. 6 kit radii/pill yes. 7 loading/empty/error shown (`real-play-loading/error/empty`, `real-roam-empty`) yes. 8 XL: roam + play checked; play clock scales down, no clipping of controls; roam intro cards still crop horizontally (scrolling row, as before). 9 EN + zh yes. 10 builds, no logic changes yes.

## Open issues (honest)
- Simulator MapKit shows blue without tiles (no network), so real-map shots have no streets; pins and fog not visible there. `QuestifyDensityMap`'s accessibility "Show places as a list" row still sits above the map (kept for VoiceOver, offset under the area pill).
- System `.searchable` pill floats over the panel bottom (list gets bottom inset). Live roam has no real map (static fog ground); finish glass circle only appears once a roam is started (not captured: fixture is in the ready state).
- `searchMap` shot is the offline marker fixture; the full SearchMapExplorerView screen (list with filters) was not re-skinned beyond its canvas. Roam passport tab (D2) untouched. XL/zh not shot for every state.
