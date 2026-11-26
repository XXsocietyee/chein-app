# Receipt: design/p1-map-explore (backlog P1, lane L3: Map, search-map, roam, free explore)

Branch `design/p1-map-explore` from `origin/ui/combined-r7`, with `origin/fix/backlog-p0` merged first so L3 builds on
its map-home panel (P-034) and live-roam chrome (P-040) tip instead of around it. Apple components only, MP-first,
no new endpoints. No compiler in the cloud: every API was grepped in the repo or is iOS 17 SDK. Strings:
`docs/port/strings/native-r2-p1-map-explore.json` merged into `Resources/Localizable.xcstrings` (zh-Hans + en).

- P-035 done: map-home peek is `@ScaledMetric(relativeTo: .body)` from 120 pt (`RoamMapHomeView`), passed to `RoamMapHomePanel` / `RoamMapHomePanelMetrics` (`peek:`), capped at 40% of the tab so the map stays visible at AX5; `RoamMapHomeModel.peek` is only the detent identity.
- P-037 done: submitting the map-home search (or the `roam.search` row, now a button) runs `SearchMapReading.citySearch` for the map's area — the same read the pushed explorer made for that keyword — and its places/activities become `Marker` pins on the home map, rows in the sheet and Maps place cards (`.searchNode` / `.searchActivity` payloads; activity → existing event destination). The map frames the results; VoiceOver announces the count or failure; clearing the field clears them. The explorer is no longer pushed as a second map (`RoamMapHomeRoute.search` removed; `RoamMapHomeDependencies.searchDestination` → `searchReader`, one line in `QuestifyApp.roamMapHomeDependencies`).
- P-038 done (live map): `QuestifyDensityMap` draws MapKit `Marker`s with `Map(selection:)`; the density groups stay (SwiftUI MapKit has no clustering API on iOS 17) and render as one monogram `Marker` with the member count that expands the group as before; selection still goes through `MapMarkerDensity.SelectionGate`. Forced light map and the placeholder ground removed (system appearance). Partial for the offline canvas and the alternative list: they keep `QuestifyMapPinSymbol` (MP marker art via `MPAsset`) because they are buttons, not map content, and the UI tests (`searchMap.pin.*`, `mapList.pin.*`) drive them.
- P-041 done (by fix/backlog-p0 P-040, merged here): live roam 开始 is a `.borderedProminent` button (id `roam.live.start`), no hold-to-start.
- P-042 done (by fix/backlog-p0 P-040, merged here): `cyCelebrations` particles removed from live roam; `.symbolEffect(.bounce)` + `.sensoryFeedback(.success)` instead. `RoamLiveSessionView` is combined-r7's own resolution of that merge (unchanged here).
- P-066 done: free-explore pins use the store name (untitled fallback `playFree.store.untitled`) for the `Annotation` title and the VoiceOver label "name, state".
- P-070 done: next-stop card shows the distance (`.numericText` roll, Reduce Motion: no animation, `.monospacedDigit`, id `nativeR2.freeExplore.next.distance`); each store row shows its distance and a visible 我已到达 button when the store offers it (id `playArrival.action.<id>`, swipe kept); within 50 m of the next store an IslandCenter `.arrival` pops with 我已到达 (or 打开) up front (VoiceOver announcement when the island flag is off); the Dynamic Island gets the same distance. Position comes from `CityOrientationLocationObserver` in foreground-only mode (no permission request, no background reading, no network). Persistent map sheet marked `.cySheetBackdropExempt()`.
- P-072 done: stamp creation no longer enqueues the 48-particle `cyCelebrations` burst; the seal bounces (`nativeR2BounceOnAppear`, Reduce Motion aware), `.sensoryFeedback(.success)` stays, and an IslandCenter `.arrival` (“集章成功”, action 查看集邮 when the album can open it) appears once per stamp (VoiceOver announcement when the island flag is off).

## Gates
- `python3 tools/check_scaffold.py` → PASS structural checks; `python3 -B tools/check_a11y_lint.py` → PASS (0 new).
- Contract checks that grep changed files and were updated to the new behaviour: `test_map_visual_foundation`, `test_roam_map_density`, `test_map_marker_density`, `tools/check_map_alternative_list.py` (via `test_map_alternative_list`). Full `Tests/ContractChecks` run compared with `origin/ui/combined-r7`: no new failures (pre-existing ones unchanged).
- Needs a simulator build before merge (no compiler here).

## Outside the lane (noted)
- `App/QuestifyApp.swift`: one argument in `roamMapHomeDependencies` (search reader instead of the explorer push).
- `RoamLiveSessionView.swift` / `CityOrientationRunView.swift`: identical to `origin/ui/combined-r7` (its fix/backlog-p0 merge).
