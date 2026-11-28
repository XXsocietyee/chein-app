# K40 weather (`cursor/1128-k40-weather`)

Base: `origin/ui/combined-r7` @ `a7c956335`. Scope: weather and effects rows from `docs/briefs/round3-1127.md` (OWNER RULE 3, AI weather worker) and the weather / effects rows of `audit/1128-plan`, `audit/1128-functions`, `audit/1128-ada`.

Backend cache work is already on hengyin `cursor/1128-be-weather` @ `cf5b5d0f6` (one commit ahead of `us/r3-functional` @ `482f7cdb`). It sets map-weather TTL to 10 minutes, keeps the 20-cells-per-degree cell (~5.5 km), and pins play-environment daypart to Asia/Shanghai. Not redone. No `cursor/1128-be-k40-weather` branch. No secrets, deploys, or SQL. Money switches unchanged. `AppSession.swift` stays 7977 lines. Init order untouched. Merchant center stays gated.

Counts: **n=8** rows checked, **m=5** already fixed, **k=3** closed here.

## Rows

| # | Source | Finding | Result |
|---|---|---|---|
| 1 | plan #24 / R-02d | Live roam never draws fog (`liveRevealEnabled` false, `withFogMap` unused) | Already fixed @ `3a60af988`. `PersonalFogFeature.liveRevealEnabled` is true; `RoamLiveSessionView` mounts the fog map. `Fix1128bMapsCompositionTests` |
| 2 | plan J-03 | Story flow had no particles | Superseded (story-flow theme paused). SURVIVAL climate particles already drawn @ `0d558b75d` / `4e60eb7fc` (`StoryClimate` on `CYWeatherScene`). Not reopened |
| 3 | functions, roam tools 迷雾 | 迷雾 / 地图样式 / 减少动态 | Audit said Works. Re-checked: the sheet still binds the live fog flag, which is on @ `3a60af988` |
| 4 | ada d2-roam, Innovation, ranked item 2 | Roam tab was a drawn grid with no fog | Already fixed. Shipping root `RoamMapHomeView` draws the map plus `CYWeatherScene` @ `4e60eb7fc`. Live-walk fog is row 1 |
| 5 | ada onboarding-1, inclusivity item 14 | Fog disc needs a named "Clear fog" action and a Reduce Motion fallback | Reduce Motion crossfade already @ `123c93dc7` (`FogWindow` uses `CYMotion.reduced`). The control that clears the disc (hold GO) had an unnamed action only. Closed: `.accessibilityAction(named: Text("onboarding.fog.clear"))` (en "Clear fog", zh-Hans "拨开迷雾") |
| 6 | ada / OWNER RULE 3 | Weather particles must honour Reduce Motion and Low Power, and stay off clean pages | Already fixed @ `4e60eb7fc`. `CYWeatherScene` skips particles and lightning when Reduce Motion or `CYLightBudget.particlesAllowed` is false; not hit-testable; hidden from VoiceOver. Gate "effect on clean page" 0 |
| 7 | be-weather contract | Map weather is kind + intensity only, 10-minute cache, ~5.5 km cell, Asia/Shanghai daypart | Closed. The app already sent the cell centre and ignored extra fields for drawing. The guide board kept map weather for 30 minutes, and a missing daypart used the device zone. Map and WeatherKit facts now expire at 10 minutes; environment facts stay 30 minutes (`WEATHER_TTL_MILLIS`, unchanged on the backend). Fallback daypart is `Asia/Shanghai`. `WeatherContextTests.testMapWeatherIsKindAndIntensityOnTheShanghaiCell` / `testMapWeatherExpiresInTenMinutesAndEnvironmentInThirty` |
| 8 | inventory follow-up | Play session pull-to-refresh did not re-read weather inside the 10-minute cache | Closed. Toolbar, error retry, and the overview `.refreshable` call `SceneWeatherModel.reload`, which drops both caches and reads again. `Fix1128cWeatherReleaseCompositionTests.testReloadRereadsMapWeatherInsideTheTenMinuteWindow` |

Clear map weather still draws nothing (MP `weather-core` normalize). A `temperature` or `city` field on the payload is not shown and is not sent. WeatherKit stays off unless `CY_WEATHERKIT_ENABLED` is set.

## Gates

Swift compiler is not in this environment; the new tests are written, not executed here.

- `python3 tools/contract_ratchet.py --check`: 46 failing, baseline 46, **new 0**
- `python3 tools/check_design_consistency.py`: PASS, effect on clean page 0
- `python3 tools/check_a11y_lint.py`: PASS, 0 new
- `python3 tools/check_scaffold.py`: PASS (appsession ratchet, 21684 bilingual keys)
- `App/AppSession.swift`: 7977 lines, untouched
