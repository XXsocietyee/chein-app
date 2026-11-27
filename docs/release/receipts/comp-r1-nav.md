# Components r1 · lane C6 nav — receipt

Brief: `origin/design/handoff-r2:docs/briefs/components-r1.md` (lane C6: navigation / city orientation run). Also followed `COORDINATOR-HANDOVER.md` §4 and the fix-r11 decisions (`docs/briefs/fix-r11.md`, N-r11-2: no locate-me button).
Branch `comp/r1-nav` from `origin/ui/combined-r7` (`64a344358`). Not compiled (no Swift toolchain in the cloud). Every type and member was grepped before use.

## Added

| item | file:line | MP reference |
|---|---|---|
| `CityOrientationETA`: walking minutes at 5 km/h (min 1), `N分钟` / `H小时M分`, arrival clock `HH:mm` in Asia/Shanghai | App/NativeR2/CityOrientation/CityOrientationNavComponents.swift:10 | pages/play/index.js:4510-4527 `_syncNavMeta` (L01-098 Beijing time) |
| `CityOrientationETAText`: 预计 12分钟 · 14:32 到达, `TimelineView(.everyMinute)`, `.numericText()` | CityOrientationNavComponents.swift:42 | pages/play/index.wxml:600-604 |
| `CityOrientationPausedTag`: 已暂停 · 计时已停, orange `pause.circle.fill` | CityOrientationNavComponents.swift:62 | index.wxml:557-561 (paused run stack; pause is orange) |
| `CityOrientationTeamProgressRow`: team name in its trail colour, `done/total` (`numericText`), `ProgressView` bar; one VoiceOver element with value 已完成 N / M 站 | CityOrientationNavComponents.swift:73 | team-trail.js `done` (existing `TeamTrailTeam.done`) |
| `CityOrientationArrivalCard`: 这一关你已通关, route progress bar, 下一站 · name with distance + ETA | CityOrientationNavComponents.swift:110 | index.wxml:1104-1110 (`sheet.node.done` block, `continueText` 前往下一站) |

## Adopted

| where | file:line | change |
|---|---|---|
| Run map controls | App/NativeR2/CityOrientation/CityOrientationRunView.swift:188-192 | `MapUserLocationButton` removed (fix-r11 N-r11-2: MP maps set `show-location="{{false}}"`, subpackageRoam/session/index.wxml:27, components/cy/route-thumb/index.wxml:6). Compass + pitch stay. |
| Run controls row | CityOrientationRunView.swift:296-303 | 开启定位 (opens Settings) only while location is off — the one MP location control (pages/roam/index.wxml:150). |
| Next-stop banner (run HUD) | CityOrientationRunView.swift:253, :268-273, :288 | Paused tag + pause symbol while the clock is paused; ETA line under 前往 N · name (hidden in the 50 m highlight and when location is off). |
| Next-stop section (medium detent) | CityOrientationRunView.swift:418-427 | Distance rolls with `numericText`; ETA under it. |
| Teams section (large detent) | CityOrientationRunView.swift:486-496; App/PlayExperienceView.swift:792 | Rows → `CityOrientationTeamProgressRow` with the route total (`visibleNodes.count`). |
| Punch sheet arrival confirmation | App/NativeR2/CityOrientation/CityOrientationPunchSheet.swift:163-168, :299 | Done state → `CityOrientationArrivalCard` (identifier `nativeR2.city.punch.done` kept); the next button reads 前往下一站 (new key `nativeR2.city.punch.goNext`; identifier kept). |

Behaviour is unchanged: nothing new is sent; arrival is still `PlayArrivalService` + server; the 50 m highlight still never punches.

## C3 kit

`origin/comp/r1-kit` was not pushed when this lane ran, so the lane uses its own small views (`CityOrientationNavComponents.swift`), all plain Apple components. Swap-in points once C3 lands: `CityOrientationTeamProgressRow` bar → `CYRing`/`CYStatPill`; ETA/distance text → `CYLiveCounter`.

## Strings

Fragment `docs/port/strings/comp-r1-nav.json` (10 keys, en + zh-Hans), merged into `Resources/Localizable.xcstrings`.

## Gates (last push)

`check_scaffold.py` PASS structural checks · `check_a11y_lint.py` PASS (0 new) · `contract_ratchet.py --check` 104 failing, baseline 105, new 0 (1 unrelated now-passing: test_profile_read_failure_remote_admission, left for the coordinator's `--update`).

## For the coordinator

- No capabilities or profiles needed by this lane.
- Other maps still carry `MapUserLocationButton` (outside this lane): App/NativeR2/MapHome/RoamMapHomeView.swift:119, App/NativeR2/FreeExplore/NativeFreeExploreMapView.swift:50, App/RoamLiveSessionView.swift:279. Per the N-r11-2 decision these should drop it too; left for their owners.
- Dynamic Island paused/ETA is lane C1 (`comp/r1-live`).

## Compile risks to check first

- `appLocalized("nativeR2.city.eta.hoursMinutes \(Int) \(Int)", locale:)` interpolation into `String.LocalizationValue`.
- `ProgressView(value:total:label:)` with `Double` in `CityOrientationArrivalCard`.
- `.accessibilityValue(total > 0 ? Text(...) : Text(verbatim: ""))` ternary of `Text`.
- `CityOrientationTeammatesSection(teams:total:)` memberwise init with the defaulted `total`.
