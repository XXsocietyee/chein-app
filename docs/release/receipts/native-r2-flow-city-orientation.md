# Receipt: native-r2 / flow-city-orientation (同城定向)

Branch `native-r2/flow-city-orientation`, from `origin/ui/combined-r7`. Brief: `docs/briefs/native-r2.md` (design/handoff-r2).
Spec: `docs/design/native-r2/city-orientation.md` (design/native-r2-city-orientation, re-fetched, unchanged).
Gate: `python3 tools/check_scaffold.py` → `PASS structural checks`. No compiler in the cloud: every type, func and modifier
below was grepped in the repo or is standard iOS 17 SwiftUI/MapKit (deployment target 17.0). **A simulator build by the
coordinator is still required.** Status: held until owner approval (step 3).

## Switch
- `App/NativeR2/NativeR2Flags.swift`: empty `enum NativeR2Flags {}`. Each lane adds its flag in its own folder, so lanes never
  edit the same line. If another lane also adds this file, keep one copy (same content).
- `App/NativeR2/CityOrientation/CityOrientationFlags.swift`: `NativeR2Flags.cityOrientation`, default **true**; QA can turn it
  off with the `nativeR2.cityOrientation` user default. Off = every old screen exactly as before.
- `tools/generate_project.py`: sources now include `App/NativeR2/**/*.swift` (one glob added beside `App/NativeGallery`).

## Screens (new files `App/NativeR2/CityOrientation/*.swift`) and where they are routed

| Screen | File | Entry point (unchanged caller) |
|---|---|---|
| S2 event detail | `CityOrientationEventDetailList.swift` | `ActivityDetailContentView`, `.allowed` detail with a linked topic |
| S6/S7 team lobby | `CityOrientationTeamLobbyView.swift` | `OrientLobbyTeamsView.body` (both existing routes: `PlatformConsumerSessionOwner`, `MPReviewedPageScreen`) |
| S8/S9 live run | `CityOrientationRunView.swift`, `CityOrientationLocationObserver.swift` | `PlayExperienceView.body`, `gameplayMode == .cityOrientation` |
| S11 punch sheet | `CityOrientationPunchSheet.swift` | run sheet (next stop, leg rows), map banner inside 50 m |
| S12/S14 finish + ranking | `CityOrientationFinishSummaryView.swift` | `PlayExperienceView` `.fullScreenCover(isPresented: $finishScreen)` |

### Event detail (S2)
- Inset grouped `List`: name `.title2.bold()` + category; cancelled section (`activity.detail.cancelled`); `Section("信息")` of
  `LabeledContent` 时间 / 集合点 (`activity.detail.meetingPoint`) / 已报名 (`activity.detail.registeredCount`) / 价格
  (`activity.pinned.summary`); static `Map` + 路线 button; 主题路线 `NavigationLink` (`activity.openTopic`); 活动介绍; 票种 rows;
  channel row; 写评价 (`activity.openReview`) + points note (`activity.detail.readOnly`); then the existing people, reviews,
  "more info" sections (play links, 本局计分 entry, character card) and host-cancel section.
- CTA = one `ToolbarItem(placement: .bottomBar)` `.borderedProminent` `.controlSize(.large)` button. `cityEventCTA` repeats
  `registrationAction`'s branches in the same order: host 取消活动并退款 (`activity.hostCancel.footer`, opens the same
  `ActivityHostCancelSheet`), blocked sign-up (`activity.openRegistration.blocked`, disabled), sign-up
  (`activity.openRegistration`: guest sign-in first, else the same `SessionRegistrationSheet`), unavailable, then wallet /
  继续探索 (`activity.primaryAction`). **Money: paid registration still goes only through `SessionRegistrationSheet`** and its
  own gates; nothing here touches price, quote or pay. Shown only when `registrationEnabled`, as before.
- Scope note: `ActivityDetail` has no gameplay-mode field, so the native layout is used for every activity with
  `linkedTopicID` (playable activities). Activities without a topic keep `detailContent`.

### Team lobby (S6/S7)
- Toolbar `.principal` `Picker(.segmented)` 加入队伍 / 我的队伍 (the "role" picker: joiner vs. member view; the MP has no
  player-chosen team role, `TeamPlayRoleFacts` is server-assigned).
- 加入队伍: same `OrientSessionService.lobby(ownerType:ownerID:)` read and error mapping as before; full teams hidden (MP B3);
  `.searchable`, `.refreshable`, redacted loading, `ContentUnavailableView` empty/failed/signed-out. Rows `LabeledContent`
  (name, 队长 · x/y, trailing 申请加入) → the same `SessionRoamNearbyTeamsView(focusTeamID:)`. Ids kept: `orientLobby.screen`,
  `.scope`, `.signIn`, `.failed`, `.empty`, `.team.<id>`.
- 我的队伍: `TeamScreenModel(session.makeTeamCoordinator())`, `loadTeams()` then `loadDetail(.id, requireMembership: true)` for
  this owner's team. Status / members `Gauge(.accessoryLinearCapacity)` / 加入码; `Section("成员")` rows with 队长/队员 in
  secondary, captain swipe 移出 (`TeamAction.remove` → `model.prepare` → the existing `TeamReviewSheet`); captain
  `Toggle("公开招募")` (`TeamAction.changeJoinMode` through the same review, never a direct write); `ShareLink` 邀请队友 in the
  bottom bar while recruiting with a valid code.

### Live run (S8/S9)
- `CityOrientationRunView`: full-bleed `Map` with `UserAnnotation`, `MapPolyline` legs (done `.secondary`, current solid accent,
  later dashed), numbered `Annotation` control points (`CityOrientationStopBadge`: checkmark green / accent / lock gray), the
  current point's `MapCircle` (300 m start lock before the run starts, 50 m highlight during it), teammates as `Annotation`
  initials. `.mapControls { MapUserLocationButton(); MapCompass(); MapPitchToggle() }`,
  `.mapStyle(.standard(pointsOfInterest: .excludingAll))`. Data: `PlayRouteMapPresentation` only.
- Top `.safeAreaInset`: the Maps maneuver banner on `.regularMaterial` (distance, "前往 N · 名称"); inside 50 m it reads
  "已到达 · 轻点打卡" with `.sensoryFeedback(.success)` and opens the punch sheet; it **never punches by itself**. Under it,
  `.bordered` `.circle` buttons: 队伍频道 (`ingame.channel.play.entry`, only when the nav bar does not already carry it),
  路线地图 (`playRoute.open`), 结束 (`playx.run.end`).
- Bottom sheet `.presentationDetents([.height(120), .medium, .large])`, `.presentationBackgroundInteraction(.enabled(upThrough:
  .medium))`, `.interactiveDismissDisabled()`:
  - peek: `CityOrientationRunMetricsRow` — clock via `TimelineView(.periodic(by: 1))` over `PlayRunClock.elapsed(monotonicNow:)`
    (`playx.run.clock`), walked distance, points done/total, and pause (`playx.run.pause`, `.bordered`) or start/resume
    (`playx.run.resume`, `.borderedProminent`) with the same `pauseRun`/`startRun` calls and `canManageRun` gate;
  - `NavigationStack` `List`: 下一站 (`referenceTask.open`, `playHUD.hint`), 路段 (`playx.node.<id>` rows), 队友, then every other
    existing run section (`orientationSections(native: true)`: progress, issue, resync, compatibility, team pool, opening,
    entry code, city game, unresolved/reconcile (`playx.reconcile`), offline pack, records, results, contact, reward,
    ending, leaderboard, club lead + team trail). Same refresh and tools toolbar (`playx.refresh`, chapters, emergency).
  - 结束 is a `.confirmationDialog` with the existing copy and `endRun` call.
- The sheet hides itself while any other presentation of the run screen is up (finish, chapter settlement, emergency,
  chapter picker, route map, backpack, a pushed stop, title card, cast) and comes back after.
- `PlayExperienceView`: `orientationList`'s `List` body moved verbatim into `orientationSections(native:)` and its toolbar into
  `orientationToolbar`; `native: true` only skips the current-goal card and `CYRouteNodeRow` stations, which the native
  sections replace. Flag off = `orientationContent` exactly as before.
- Position: `CityOrientationLocationObserver` is foreground-only and **never requests permission** (same rule as
  `TeamTrailForegroundRecorder`), projects WGS-84 → GCJ-02 with `RuntimeLocationProjection.gcj02MapCenter`, and only feeds
  the banner, the lock row and the distance metric.
- Teammates: no second poller. `TeamTrailSection` (`App/PlayerGapViews.swift`, +3 lines) publishes its last `teams` read through
  the new `cityOrientationTeamsSink` environment value while sharing; the map mirrors it.

### Punch sheet (S11)
- `.sheet` `.presentationDetents([.medium, .large])`, `NavigationStack`, inline title, 关闭. Locked → `ContentUnavailableView`
  with the lock reason. `Section("到达")`: 距离, 精度, 到达核验 (display only: `PlayArrivalPolicy.start` verdict for the start,
  "无需定位" for later points), the `PlayArrivalService` phase rows (same copy as `PlayArrivalControl`). Arrival refusals reuse
  `PlayArrivalFailureSection`.
- Bottom: 我已到达 (`playArrival.action`, `.borderedProminent`) = `PlayArrivalService.arrive(nodeID:context:)`, same disable
  rules; 扫码到达 (`.bordered`, always). 拍照上传 / 去完成任务 / 扫码 open **the existing stop page**
  (`PlayExperienceNodeView` via `selectedNode`), which owns the camera (`PlayDeviceTaskSection`, `PlayKitCameraPresentation`)
  and scanner capture, so capture, upload and review are unchanged. After a punch: 已打卡 inline + 下一站.
- GPS arrival lock is unchanged: the start fix is still taken and checked by `PlayArrivalService` + server; the local verdict
  never enables or blocks the button.

### Finish summary + ranking (S12/S14)
- `.fullScreenCover` `NavigationStack` `List`, large title = the same server result word (`finishResultKey`, U08-01).
  Toolbar: `ShareLink` (`medalScreen.share`, same share text) and 完成 (`medalScreen.back`). Root id `medalScreen`.
- Metric grid (用时, 节点, 距离, 名次, 得分 — a missing value drops its cell), non-interactive route `Map` thumbnail, read-only
  legs, medals (MP default art via `MPAsset` when no sprite), ranking: my row pinned + `playx.leaderboard` rows from
  `model.leaderboard`. The leaderboard is still only read when the player taps 结局与同行者榜 (`playx.results.load`).
  本局战报 link (`medalScreen.secondary`) uses the same `MPParityDestination(.journeyReport)`.

## Strings
- 66 keys `nativeR2.city.*` in `docs/port/strings/native-r2-city-orientation.json`, merged into `Resources/Localizable.xcstrings`
  with `tools/merge_localization_fragments.py` (added only, no overrides). All other copy reuses existing keys.

## No Apple equivalent / deviations (noted per brief)
- Maneuver banner uses `.regularMaterial` in a `RoundedRectangle` because the spec names it (Maps' own banner); no custom blur.
- Per-leg split times ("08:12 · 640 m") are not in any existing read, so leg rows show the state only.
- S10 directions inside the run, S3 registration form, S4/S5 create/join sheets, S13 score and S15 lead menu were not rebuilt in
  this pass; their existing screens stay reachable (route map, registration sheet, team pages, 本局计分 entry, lead section).
- The "确认本局规则并开始" dialog (spec S8, owner open question 2) is not added: 开始 still starts directly, as today.
- `moreInfoSections`, `ActivityPeopleSection`, `ActivityReviewsSection`, `TeamReviewSheet` and `PlayArrivalFailureSection` are
  reused as they are (owned by other lanes); they still contain some `CY*` row chrome.

## Risks for the simulator pass
- The run sheet is a modal over a pushed screen. Presentations of the run screen are gated so only one is up at a time, but the
  dismiss-then-present hand-off (e.g. emergency help from the tools menu) needs a device check.
- `List` rows inside the run sheet load lazily, so `TeamTrailSection` (and the teammate map pins) start only once that section
  has been shown, exactly as in the old panel.
