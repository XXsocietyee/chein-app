# fix/1128c-ai-weather — AI worker `ai-weather` (2026-11-28)

Base: `origin/ui/combined-r7` @70917c058. Owner (11-28 ~12:25 UTC): "We have AI NPCs, AI guides, and various weather
systems... this needs to be included." Brief: `round3-1127.md` OWNER RULE 3 (maps, games, story are level A) and the
planning-audit Release-composition rule. Behaviour reference: MP `chengyinhub-xcx` and backend `us/r3-functional`
(hengyin). Inventory with a status per weather system: `docs/audits/1128-weather-inventory.md`.

No Swift compiler in this environment: the Swift tests are written, not run. The Swift-free gates are green (below).

## What changed

| Item | Level | What | Files | Proof |
|---|---|---|---|---|
| A1 map weather (FIXED) | A | `GET api/map/weather` was drawn as a flat 8–18 % tint. Now real rain / snow / fog particles plus the day / night light, and the condition chip, on the roam map home (`RoamMapHomeView`, the Release 漫游 root, had no weather at all), live roam and the roam browser map (no chip there: its control row owns that corner). | App/NativeR2/MapHome/MapWeatherLayer.swift (new), App/NativeR2/MapHome/RoamMapHomeView.swift, App/SocialRoamMounts.swift, App/MapSearchPlayerViews.swift (old tint removed) | `Fix1128cWeatherReleaseCompositionTests.testReleaseAdmitsBothWeatherReads` (live send through the shipped transport) |
| A2 topic environment (NEW) | A / B | `PlayEnvironmentService`: `GET api/play/environment?topicId=` (`ApiPlayEnvironmentController`), Authorization, parses `environment`, `sourceStatus`, `fallbackReason`, `events[]`. Its weather wins in `WeatherContext.compose`, so the scene never contradicts the server's `weather_event_rule` gates. Admitted in Release: `socialRoamOwnerGrant` + `capabilityReadPaths`. | Core/PlayEnvironmentService.swift (new), Core/ChinaReviewedRouteCapability.swift, App/ReviewedPlayerWriteLeases.swift | `WeatherContextTests.testEnvironmentReadSendsTopicIdAndParsesEvents` / `…FailuresReadAsNoSnapshot`; composition test |
| A3 WeatherKit (NEW, OWNER) | A | `WeatherKitReader`: WeatherKit `.current` at the ~5.5 km cell centre, ten-minute cache, failure back-off; off unless Info.plist `CYWeatherKitEnabled` (= `CY_WEATHERKIT_ENABLED`, default `NO`). Temperature, condition outside the Tencent provider (US) and `isDaylight`. Apple Weather mark + legal link (`WeatherService.attribution`) under the chip whenever an Apple value shows. | App/WeatherKitReader.swift (new), Config/Info.plist, Config/OwnerValues.xcconfig, docs/release/owner-values.md | `testWeatherKitIsAnOwnerSwitchThatDefaultsOff` |
| A4 day / night (NEW) | A | `SolarLight` (NOAA low-precision sun elevation): day / civil twilight / night light layer; WeatherKit `isDaylight` wins when on. | Core/WeatherContext.swift | `WeatherContextTests.testSolarPhaseInShanghai` |
| B1 weather-locked nodes | — | Already ON (`weatherLocked` / `lockReason` in `PlaySessionView` / `PlayNodeDetailView`); unchanged. | — | existing `PlayerCapabilityRoutesTests.testWeatherLockedNodeAndClearWeatherFallback` |
| B2 weather events (NEW) | A | `PlayWeatherEventsSection`: active events first with the author's `taskLabel`, waiting ones with the server `lockReason`; `FALLBACK_UNKNOWN` note. In the play session list and in a sheet from the chip on the play scene. | App/PlaySceneWeather.swift (new), App/PlaySessionView.swift | parse test above |
| B3 orient `WEATHER_BLOCKED` | — | Already ON (`/api/orient/safety/check` precheck blocks Start with the server reason). | — | existing |
| C1 story climate (FIXED) | A | SURVIVAL look `params.climate` / `volatility` were dropped by `PlayThemeLookTokens` and `CYThemeLook`. Now carried, and `StoryClimate` ports MP `look-fx.js` `CLIMATE` / `VOL` (phases, amplitude, lightning) onto the scene over the play experience. | Core/CloudB3Readers.swift, Core/WeatherContext.swift, App/DesignSystem/CYThemeLook.swift, App/CloudB3Production.swift, App/PlaySceneWeather.swift, App/PlayExperienceView.swift | `testStoryClimateFollowsThePhaseTable`, `testLookTokensKeepSurvivalClimateOnly`, composition test (`storyClimate`) |
| C2 live weather in play scenes (NEW) | A | `PlaySceneWeather` on `PlayExperienceView` (strength 0.7 so text stays readable) and the play map in `PlaySessionView` (chip in the scaffold's control row). Place = first node with a coordinate. | App/PlaySceneWeather.swift, App/PlayExperienceView.swift, App/PlaySessionView.swift | static (view) |
| D effects kit (NEW) | A | `CYWeatherScene`: `TimelineView(.animation, ≤30 fps)` + `Canvas`, stateless seeded particles (rain streaks, snow, drifting fog bands, wind streaks, sand / debris, soft lightning ≤ once per 8 s), static tint layer. Reduce Motion → no particles / no flash (tint + light stay); Low Power / thermal (`CYLightBudget.particlesAllowed`) → tint only; not hit-testable; hidden from VoiceOver (the chip says it in text). The 89e71d61d components were already restored by ds-consistency; none needed. | App/DesignSystem/CYWeatherScene.swift (new) | `testSceneLayerAndStoryClimateAreBuiltFromReleaseReadings` |
| D clean-page guard | — | `check_design_consistency` "effect on clean page" now matches `CYWeatherScene(`; the kit file is in `EFFECT_KIT_FILES`. Its only callers are `App/NativeR2/MapHome/MapWeatherLayer.swift` and `App/PlaySceneWeather.swift` (level-A surfaces). | tools/check_design_consistency.py | gate |
| E AI guide hand-off (NEW) | — | `WeatherContext` + `WeatherContextBoard.shared.current` (fresh ≤ 30 min, the backend cache window) + `guideFacts` (`weather`, `intensity`, `temperatureC`, `daylight`, `daypart`, `source`; unknown keys omitted). For `fix/1128c-ai-npc-guide`: read `WeatherContextBoard.shared.current?.guideFacts`; nil → say nothing about weather. | Core/WeatherContext.swift | `testEnvironmentWinsOverMapAndDevice`, `testBoardKeepsTheLastValue` |

Chip: SF Symbol (multicolour, night variants) + condition (`weather.kind.*`) + rounded temperature (°C, °F for the US
measurement system) in a `.regularMaterial` capsule; `cyText` styles (Dynamic Type, capped at accessibility3 so it never
covers the map); one combined VoiceOver element. Strings: 18 keys in `Resources/Localizable.xcstrings`, en + zh-Hans.

## Release composition proof (planning-audit rule)

`Tests/AppUnitTests/Fix1128cWeatherReleaseCompositionTests.swift` builds `RegionalLaunchConfiguration.reviewedDeployment`
/ `shippedComposition` (CN, production base URL) and asserts: production gates and player writes on; both
`api/map/weather` and `api/play/environment` admitted by `ChinaReviewedRouteCapability.admitsChinaProductionCall`, in
`ReviewedProductionGateLeases.capabilityReadPaths`, not money routes; a player-grant transport built exactly like
`AppSession.playerCapabilityClient()` sends both GETs (with `topicId=4`); the scene and story climate are built from
those readings; WeatherKit stays off without the owner switch.

## Owner values

`CY_WEATHERKIT_ENABLED` (default `NO`), the WeatherKit capability + App Service on the App ID, and the
`com.apple.developer.weatherkit` entitlement: `docs/release/owner-values.md` § fix/1128c-ai-weather. No secret, no
backend change, no SQL, no deploy.

## Not done / follow-ups

- `PlaySessionView` pull-to-refresh does not force a new environment read (10-minute cache, same as the map).
- The chip on the full play scene sits at the top-leading corner; a screenshot sweep should confirm it does not cover a
  kit's own HUD (move it with `chipAlignment` if it does).
- US market: `ChinaReviewedRouteCapability` is China-only; the US composition reads weather through its own gate (not
  changed here). WeatherKit is the US source once the owner switches it on.

## Gates (final tree)

- `python3 tools/generate_project.py`: 4156 native sources, 844 app-unit sources, 4 shards (916 classes)
- `python3 tools/check_scaffold.py`: PASS (appsession ratchet, 266 pages, 5357 Swift files, 21383 bilingual keys)
- `python3 tools/contract_ratchet.py --check`: 52 failing, baseline 52, **new 0**
- `python3 tools/check_design_consistency.py`: PASS, effect on clean page 0
- `python3 tools/check_a11y_lint.py`: PASS, 0 new
- `App/AppSession.swift`: untouched.
