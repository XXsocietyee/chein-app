# Receipt: fix/backlog-p0 (P-034, P-040, P-050)

Branch `fix/backlog-p0`, from `origin/ui/combined-r7` @ `169f2904e`. Apple components only, MP-first,
no new requests. No compiler in the cloud: every API was grepped or is iOS 17 SDK. Gates:
`python3 tools/check_scaffold.py` → `PASS structural checks`; `python3 -B tools/check_a11y_lint.py` → `PASS (0 new)`.
Touched contract checks (`test_roam_live_contracts`, `test_roam_paused_accessibility_ids`,
`test_roam_history_live_entry`, `test_app_store_privacy_launch_contracts`, `test_wp11_session_location`,
`test_privacy_manifest_contract`, `test_runtime_dependency_wiring`) pass. `test_accessibility_hardening_wave`
(4 failures) and `tools/check_personal_location_share.py` (1 error) fail the same way on the base commit; not touched.

## P-034 Map home covers the tab bar
- `RoamMapHomeView`: the persistent `.sheet` is gone. The panel is drawn inside the 漫游 tab
  (`RoamMapHomePanel`, new file), as in Find My, so the system `TabView` tab bar stays visible.
- Detents emulated: peek 120 pt / medium (half) / large, from `RoamMapHomeModel.detents`; every existing
  `model.detent = …` call still drives it. Drag indicator (system capsule, `.tertiary`), `.snappy` spring,
  VoiceOver adjustable action (`roam.mapHome.panel.handle`). The map gets `.safeAreaPadding(.bottom)` up to
  medium so the user-location button and compass stay above the panel.
- `RoamMapHomeSheet`: the 'Tabs' menu (`roam.mapHome.tabs`) and `onSwitchTab` removed.
- iOS 26 `tabViewBottomAccessory` is not used: deployment target is iOS 17, and an accessory is a mini bar,
  not a detented sheet.
- Corner radius 10 on the panel's top edge is the only drawn shape (no system control exists for an in-tab sheet).
- New strings: `nativeR2.mapHome.panel.{handle,peek,medium,large}` (`docs/port/strings/native-r2-backlog-p0.json`).

## P-040 Live roam chrome (`App/RoamLiveSessionView.swift`)
- Map: `RoamFogMapView` when the live reveal is on (game behaviour, unchanged); otherwise a MapKit `Map`
  with `UserAnnotation`, `MapUserLocationButton`, `MapCompass`, `MapScaleView` (id `roam.live.map`).
  `CYMapScaffold`, `CYMapPlaceholder` and the decorative `CYFogLayer` edge removed.
- One persistent system `.sheet`: `.fraction(0.3)` / `.medium` / `.large`, background interaction up to
  medium, drag indicator, not dismissable. It is shown while the session content is on screen and drops
  when the finish report replaces it.
- HUD glass card → first list `Section` with `LabeledContent` rows (用时 / 地盘 / 距离);
  `RoamLiveStatTile` is now a `LabeledContent` with `.contentTransition(.numericText())`.
  Status chip → `Label(phase, systemImage: RoamPhase.statusSymbol)`.
- Hold-to-start pill, GO puck and wave → `.borderedProminent` 开始 button, same id `roam.live.start`,
  same start path (location priming first, offline-write opt-in, re-enabled when the start is refused).
  Pause/Resume `.borderedProminent`, 结束 `.bordered` destructive, all ids kept.
- Consent card pill → `.borderedProminent` button (id `roam.live.consent`).
- `PlayAreaRoamFinishModal` overlay → `.confirmationDialog` with the same copy; confirm id
  `roam.live.finish.confirm` kept.
- `cyCelebrations` particles removed. New ground → `.symbolEffect(.bounce)` on the status symbol;
  settled walk → `.sensoryFeedback(.success)`. The settle analytics event is unchanged.
- Tools, rules, check-in, location priming and the paused-browse sheets now hang off the persistent sheet
  (a presenter that already shows a sheet cannot present another). `RoamPausedBrowseLifetimeAnchor`
  stays on the screen itself, so the pause/leave lifetime logic is unchanged.
- Kept: every controller call, analytics, `onDisappear … owner.pause()`, scene handling, reveal toast,
  identifiers. UI tests that `press(forDuration:)` on `roam.live.start` still work (a long press taps a Button).

## P-050 City orientation distance stops on background / push
- `CityOrientationLocationObserver` is now run-scoped: owned by `PlayExperienceView` (`@StateObject`,
  above the run view). `CityOrientationRunView` no longer stops it on `onDisappear` or scene change, so a
  pushed page keeps the distance running.
- `PlayExperienceView.syncCityRunTracking` (from `model.clock.phase`): run started and not ended
  (`.running` or `.paused`) → `setRunActive(true)`; `.ended` → stop. Paused is included because the
  existing code auto-pauses the run when the app leaves the foreground; without it background reading
  would never happen.
- During an active run only: `allowsBackgroundLocationUpdates = true`, `showsBackgroundLocationIndicator = true`
  (gated on the declared `location` background mode, same check as `SessionBackgroundLocationTracker`).
  Always `pausesLocationUpdatesAutomatically = false`. No active run → reading stops on entering background
  (as before). `deinit` stops the manager when the play screen leaves.
- `Config/Info.plist` already declares `UIBackgroundModes = location`. The When-In-Use purpose string now
  discloses the run's background distance (en in `Config/Base.xcconfig` + `Resources/InfoPlist.xcstrings`,
  zh-Hans in the latter). No Always key, no new permission request.

## For the owner / coordinator
- The run still auto-pauses its clock when the app leaves the foreground (existing behaviour, not changed).
  The distance now keeps counting during that pause. If the run clock should also keep running while the
  phone is locked, that is a separate change to `PlayExperienceView`'s scene handler.
- Needs a simulator build (XcodeBuildMCP) before merge: no compiler here.
