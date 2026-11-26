# Receipt: native-r2 flow — map home (漫游 tab)

Branch `native-r2/flow-map-home` (from `origin/ui/combined-r7`). Spec: `docs/design/native-r2/map-home.md` on
`design/native-r2-map-home` (b87d675b4). Brief: `docs/briefs/native-r2.md` on `design/handoff-r2`.
**Held: waits for the owner to approve the map-home design before it merges.**

## What changed
- New `App/NativeR2/MapHome/`:
  - `RoamMapHomeView.swift`: full-screen MapKit `Map(position:selection:)`, `UserAnnotation`, one `Marker` per pin
    (system image + tint by kind, monogram for numbered official-route stops), `MapPolyline` for an open official route,
    `.mapControls { MapUserLocationButton(); MapCompass(); MapPitchToggle(); MapScaleView() }`, standard / hybrid `mapStyle`.
    Persistent `.sheet` with `.presentationDetents([.height(120), .medium, .large], selection:)`,
    `.presentationBackgroundInteraction(.enabled(upThrough: .medium))`, `.presentationContentInteraction(.scrolls)`,
    `.interactiveDismissDisabled()`.
  - `RoamMapHomeSheet.swift`: the sheet's `NavigationStack`; `.searchable(placement: .navigationBarDrawer(.always))`
    (focus → `.large`, submit → `.medium`); sections 漫游 (开始漫游 = the one `.borderedProminent`, 寻找组队, 打开地图·寻找组队,
    我的队伍), 附近 (segmented `Picker` 全部/活动/地点/路线/队伍 in the header + `List` rows), 漫游护照 / 官方路线 / 城市大富翁.
    States: redacted rows, `ContentUnavailableView` for area required, location denied (去设置), signed out, 403, failed (重试),
    empty, `ContentUnavailableView.search`; offline / partial-failure footers; `.refreshable`. Toolbar menus: map modes
    (探索/卫星, 范围 1–20 km, 城市大富翁, 选择搜索区域) and tab switch.
  - `RoamMapHomePlaceCard.swift`: Maps place card pushed in the sheet at `.medium`: title + kind · distance, action row
    (state-driven prominent button, 导航, 查看详情), 16:9 photo, kind sections, `LabeledContent` details, ✕ close.
  - `RoamMapHomeRoutes.swift`: 官方路线 list and route card (polyline + numbered stops on the map, stop rows push the card).
  - `RoamMapHomeModel.swift`: pins, categories, routes, load phases; `RoamMapHomeFlag.swift`.
- New `App/NativeR2/NativeR2Flags.swift` (`enum NativeR2Flags` + `isEnabled(_:)`). Flows add flags in extensions.
- `App/QuestifyApp.swift`: `roamTab` mounts `RoamMapHomeView` when `NativeR2Flags.mapHome` (default true); otherwise the
  old `SessionCityRoamRoot`, unchanged. Restore the old screen with launch argument `-nativeR2.mapHome NO` or a
  `UserDefaults` `false`.
- `tools/generate_project.py`: also globs `App/NativeR2/**/*.swift` (other native-r2 lanes need the same line).
- Strings: 74 keys `nativeR2.mapHome.*` in `docs/port/strings/native-r2-map-home.json`, merged into
  `Resources/Localizable.xcstrings` (append only).

## Same requests, same behaviour
- Pins come from reads the old roots already made: `RoamReading.roamPlaces` (default layer, on open),
  `RoamReading.roamRouteNodes` (only when 路线 is picked, as the old 路线 layer), `RoamEntryNearbyReading.entryNearby` via
  `RoamNearbyEventsEntryState` plus its team read `AppSession.roamEntryTeams` (the team result is captured for coordinates;
  no second call), `OfficialRouteReader.list/detail`. No new endpoint.
- The place card reads nothing. Its state button (开始挑战 / 出示核销码 / 已完成 from `RoamPlace.readStatus`) opens the same
  `RoamItemDetailView` the roam browser opened, so `RoamPOIActionModel` and all POI rules stay in one place.
- Activities and topics open the same `ActivityDetailView` / `SessionTopicDetailView`; teams open
  `SessionRoamNearbyTeamsView(focusTeamID:)`; 我的队伍 `initialTab: 1`; 漫游护照 is the shipped `RoamBrowserView`
  (`presentedAsSheet`); 开始漫游 opens `RoamLiveSessionView` in a full-screen cover; search hands the keyword to
  `SessionLinkedSearchView(startsOnMap: true)` (the search map explorer).
- 导航 uses `PlatformExternalMaps` behind a `confirmationDialog` (open only after confirmation; copy address separately).
- City board (decision 1, pending owner): kept intact as a map mode in a full-screen cover; a pending
  `CityDeepLinks.pendingProperty` opens it automatically.

## Accessibility identifiers kept
`city.roam.map` (Map), `city.roam.nearby` (category picker), `city.nearby.<pin id>` (rows), `city.roam.passport`,
`city.roam.board`, `roam.go` (开始), `roam.search`, `roam.layer`, `roam.radius`, `roam.detail` (place card),
`roam.home.intro.teams`, `roam.home.intro.map`, `roam.home.peek.refresh`, `officialRoute.list`, `officialRoute.detail`.
New: `roam.mapHome.*`. Identifiers inside the passport browser are untouched (it is reused as is).

## Deviations and open points (for the owner / coordinator)
- **Tab bar:** a real `.sheet` covers the system tab bar (as specified). The sheet's leading toolbar `Menu` offers the
  other tabs (it dismisses the sheet first). If the owner prefers the tab bar visible, the sheet would need to become a
  `safeAreaInset` panel, which is not the Apple Maps pattern.
- Map-modes control sits in the sheet toolbar (a system `Menu`) instead of a custom material stack on the map, so no
  custom chrome is drawn; spec §2.1 asked for a material stack.
- Not built in this pass (spec S3 filter form, S5b leader view, S7/S8 native rewrites, comments, Look Around): those
  screens are reached through the existing pages listed above. Search filters locally over loaded pins (as the old roam
  browser did) and hands off to the search map explorer for server search.
- Place card has no `ShareLink` (no public place URL in the read); 收藏 / 投一张 stay on the full place page.

## Gates
- `python3 tools/generate_project.py` then `python3 tools/check_scaffold.py` → `PASS structural checks`.
- No compiler in the cloud: every MapKit / SwiftUI API used was checked against existing repo use or the iOS 17 SDK
  surface (`Map(position:selection:)`, `Marker(_:systemImage:coordinate:)`, `Marker(_:monogram:coordinate:)`,
  `MapPolyline(coordinates:).stroke`, `MapUserLocationButton`, `MapPitchToggle`, `MapScaleView`,
  `presentationDetents(_:selection:)`, `presentationBackgroundInteraction(.enabled(upThrough:))`,
  `searchable(text:isPresented:placement:prompt:)`, `ContentUnavailableView.search(text:)`). Needs a simulator build.
- The Tree-sitter syntax preflight could not run here (pinned wheels unavailable in this container).
