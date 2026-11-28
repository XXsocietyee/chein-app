# 1128 weather inventory (worker `ai-weather`, branch `fix/1128c-ai-weather`)

Owner (11-28 ~12:25 UTC): "We have AI NPCs, AI guides, and various weather systems... this needs to be included."
Sources read: `docs/planning/ai-requirements-1128.md` + `requirements-1128.md` (handoff-r2; neither has a weather
requirement line beyond the 迷雾 fog-of-war roam mode and 雨备 for meet-up points), brief `round3-1127.md`
(OWNER RULE 3 level A, planning-audit Release-composition rule), MP `chengyinhub-xcx/` and backend
`us/r3-functional` (hengyin), app `ui/combined-r7` at 70917c058.

Status legend: **ON** = wired and switched on in Release before this branch · **NEW** = added on this branch ·
**FIXED** = existed but incomplete, completed here · **N/A** = not a weather system (name collision) · **OWNER** =
needs an owner value (see `docs/release/owner-values.md`).

## A. Real-world weather sources

| # | System | MP / backend evidence | App before | Status after this branch |
|---|---|---|---|---|
| A1 | Map weather ambience `GET /api/map/weather {lat,lng}` → `{kind: rain/snow/fog/clear, intensity 0..1}`; anonymous, IP rate-limited, Tencent provider, per 20-cells/degree cell, failure = clear | MP `subpackageRoam/components/map-weather/{index,weather-core}.js`, `pages/roam/index.wxml:251`; backend `ApiMapController.java:148`, `MapWeatherServiceImpl`, `MapWeatherVO` (no temperature, no place names) | `MapSearchPlayerService.weather` + `MapWeatherModel` (`App/MapSearchPlayerViews.swift`) mounted on roam home (`RoamBrowserView.swift:540`) and live roam (`RoamLiveSessionView.swift:133`); admitted (`socialRoamOwnerGrant`, `capabilityReadPaths`). Drawn as a flat 8–18 % tint only | **FIXED**: drawn as real rain / snow / fog particles (`CYWeatherScene`), feeds `WeatherContext`, shows the condition chip |
| A2 | Topic environment snapshot `GET /api/play/environment?topicId=` → `{enabled, keys, environment{weather, daypart, weekpart, season}, sourceStatus AVAILABLE/FALLBACK_UNKNOWN/DISABLED, fallbackReason, events[]}`; weather values `clear cloudy rain snow fog wind storm` (`TopicEnvironmentService.WEATHER_VALUES`), daypart `dawn morning afternoon evening night` (Asia/Shanghai server clock), 30 min city cache, 800 ms timeout, fail-open to `unknown` | backend `ApiPlayEnvironmentController.java`, `TopicWeatherEventService.playerEnvironmentView`, `TopicEnvironmentService`, `TencentTopicWeatherProvider`; MP does not call it (backend-only) | Not read anywhere; route not admitted in Release | **NEW**: `PlayEnvironmentService` (Core) reads it on the play session; route admitted in `socialRoamOwnerGrant` + `capabilityReadPaths`; feeds `WeatherContext` (server weather wins over the device for game rules) |
| A3 | Temperature + condition for any coordinate (US market, places outside the Tencent provider, temperature chip) | none in MP/backend (`MapWeatherVO` deliberately carries no temperature) | none | **NEW / OWNER**: Apple WeatherKit behind build setting `CY_WEATHERKIT_ENABLED` (Info.plist `CYWeatherKitEnabled`), capability + entitlement `com.apple.developer.weatherkit` are owner values; Apple Weather mark + legal link shown whenever a WeatherKit value is on screen; off / no entitlement / any error → falls back to A1/A2 silently |
| A4 | Day / night light | backend daypart (A2); MP roam has none | `CYNight` palette only (not time-driven) | **NEW**: `WeatherContext.isDaylight` from a solar-elevation calculation at the cell centre (or WeatherKit `isDaylight`); the scene adds a dusk / night light layer on maps and game scenes |

## B. Game rules that depend on weather

| # | Rule | Evidence | App before | Status |
|---|---|---|---|---|
| B1 | Weather-gated nodes: `weather_event_rule` locks a node until its weather/daypart/weekpart/season condition holds; node list carries `weatherLocked`, `locked`, `lockReason` | `PlayNodeQueryApplication.java:707-720`, `TopicWeatherEventService.weatherLockedNodes` | Decoded (`Core/PlayContracts.swift:72,164`), shown with `cloud.rain` icon + reason in `PlaySessionView.swift:117-133` and `PlayNodeDetailView.swift:113-122`; node read is a Release play read | **ON** (verified, unchanged) |
| B2 | Weather event list for the topic (rule name, `taskLabel` easter-egg hint, `active`, `reason` / `lockReason`, window) | `TopicWeatherEventService.evaluateRuleView` via `/api/play/environment` | none | **NEW**: `PlayWeatherEventsSection` on the play session (active events first, inactive with their lock reason); refreshes with the session |
| B3 | Orienteering safety blocker `WEATHER_BLOCKED` (publisher sets 天气停玩 with reason/until via `POST /api/orient/safety/rule`; player precheck `POST /api/orient/safety/check` returns blockers) | `OrientSafetyPolicy.java:77-81`, `ApiOrientController.java:155-178`, MP `pages/topic/index/index.js:826` | `PlayerContentGapService` (`Core/MPGap/PlayerContent/PlayerContentGapService.swift:163-197`) and `OrientSessionService.swift:61` read the precheck and block Start with the server reason; admitted `liveInProduction` | **ON** (verified; publisher-side rule write is a club/host tool, not in this lane) |
| B4 | Host cancels a session/topic for weather (C8-05: stop sales + full refund) | MP `subpackageA/pages/myproject/index.js:613`, backend `HostWeatherCancelTest` | `Adapt6PublisherCancelTests` / publisher cancel flow; organiser reasons list `OfficialOrganizerConsoleView.swift:518` | **ON** (publisher lane; not a weather feed) |
| B5 | Author-side environment rules (RPG environment keys, weather values in the template editor) | `TopicWeatherEventService.adminGetConfig/adminSaveConfig`, MP publish | `Core/NativeRpgEnvironmentTemplateDraft.swift:9`, `NativeRpgEnvironmentAuthorPresentation.swift`, `EnvironmentBranchSelection.swift` | **ON** (authoring lane; level C) |
| B6 | City monopoly "WEATHERED" territory | `MonopolyRules.java:184-220` (`decay` OK/WEATHERED/DECAYING from days since the holder's last visit; −2 DC, rent ×0.5) | `CityMonopolyContracts.swift:174-231`, `CityKit/*` banners | **N/A**: absence decay, not weather. Copy kept; no weather effect is drawn on it |
| B7 | Square safety tag `WEATHER_RISK`, offline safety disclosure `WEATHER` | `SquareComponents.swift:199`, `Core/SafetyDisclosure.swift:93-105` | static labels | **ON** (labels; level C/B, no effect) |
| B8 | 掷骰子 / 抽卡 content "跟店员说一句今天的天气" | MP `node-game-catalog.js:243,267` | content strings | **N/A** (content) |

## C. Story / game-scene weather

| # | System | Evidence | App before | Status |
|---|---|---|---|---|
| C1 | Theme look SURVIVAL (末世) `params.climate` CLEAR / RAIN / STORM / SAND + `volatility` CALM / SHIFTING / VIOLENT: weather that changes by phase on the story canvas, lightning on STORM | MP `pages/play/utils/look-fx.js:33-60`, `theme-look.js:26`, `pages/play/index.js:2043` | Publisher writes the params (`AccountPublishR8Mounts.swift:431`), but `PlayThemeLookTokens` / `CYThemeLook` dropped them, so players never saw the story weather | **FIXED**: tokens and `CYThemeLook` carry climate + volatility; `StoryClimateScene` ports the phase table (wind/rain/dust/bolt) onto `CYWeatherScene` behind the play / story scenes |
| C2 | Live weather in game scenes (NativeR2 games, play HUD) | brief OWNER RULE 3 #1 | none | **NEW**: `PlaySessionView` scene draws the session's `WeatherContext` (A1/A2/A3) when the topic has no SURVIVAL look |

## D. Effects (OWNER RULE 3, level A)

| Item | Status |
|---|---|
| `App/DesignSystem/CYWeatherScene.swift`: `Canvas` + `TimelineView(.animation)` rain streaks, snow flakes, drifting fog bands, wind streaks, storm (rain + lightning flash), sand haze, dusk / night light | **NEW** |
| Reduce Motion → no particles (static tint and light only); Low Power / serious thermal (`CYLightBudget.particlesAllowed`) → static tint; never hit-testable; `accessibilityHidden` | **NEW** |
| Only level-A callers: `check_design_consistency` "effect on clean page" now also matches `CYWeatherScene(` / `.cyWeatherScene(`; callers live in `App/NativeR2/MapHome/`, `Play*` and `RoamLive*` files | **NEW** |
| Restored 89e71d61d bodies: `CYRoamKit` / `CYBurst` / `CYStarBloom` already restored by ds-consistency on combined-r7; the weather layer needs none of the emptied components, so none were re-touched | checked |

## E. AI guide / NPC hand-off

`Core/WeatherContext.swift`: `WeatherContext` (condition, intensity, temperature °C, daylight, daypart, source, observedAt),
`WeatherContextBoard.shared.current` (main-actor, last value published by any map or play scene) and
`WeatherContext.guideFacts` (`["weather": "rain", "temperatureC": "12", "daypart": "night", "source": "server"]`): the
neutral, verifiable facts the `fix/1128c-ai-npc-guide` worker may put into a RoamContext. Per the AI base doc §6, the
guide states only these facts (no invented forecast), and silence when the board is empty.

## Not found anywhere (no work)

No weather requirement in the AI requirements doc; no weather-based scoring, rewards or prices in MP or backend; no
forecast UI in the MP.
