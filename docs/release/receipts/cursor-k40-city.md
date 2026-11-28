# K40 · City Monopoly points (`cursor/1128-k40-city`)

Scope: City Monopoly, points (积分) only. No cash, no payment-switch edits, no merchant entry. Base `origin/ui/combined-r7` @ `a7c956335`. Audits read: `docs/briefs/round3-1127.md`, `docs/audits/1128-plan.md`, `docs/audits/1128-functions.md`, `docs/audits/1128-ada.md` (those files live on the audit branches, not on this base).

Backend `GET /api/city-game/territory/points` is already on hengyin `us/r3-functional` (`ApiCityMonopolyController.points` → `CityTerritoryService.points`). Claim, upgrade, challenge, scout and shield already return `balance`. No backend branch. A git clone of hengyin returned 404; the controller was read through the GitHub API.

`n/m/k` = 6 re-checked / 5 already settled / 1 closed here.

| # | Row | Verdict |
|---|---|---|
| 1 | Function audit: 首页 city rail asks for location on load (P2-3c) | Already fixed @ `8f7460a2d`. `CitySessionHomeRail` takes a device fix only when location is already authorized; otherwise it uses the chosen area. |
| 2 | Plan H-01c+: 我的地盘 sits between 编辑精选 and 附近活动 | Owner keep, recorded @ `f4ea0e987` (round-1 Q1). The rail stays. |
| 3 | P1-22 / plan R-16d: 城市大富翁 and 领地 open "not open in this build" | Owner-only. `QUESTIFY_CITY_GAME_REGION` is still empty in Release (`Config/Base.xcconfig`). The region id is an owner value. Not invented. |
| 4 | ADA `d2-city` / `e2-city` | Not a points loop. Design of the city-player fixture stays with mp-journey. Unchanged. |
| 5 | Function audit: `SessionCityPlayerView` hard-coded Chinese titles | Not points. en-layout. Unchanged. |
| 6 | Points HUD after claim, upgrade, challenge, scout or shield | Closed. A 404 on `GET /api/city-game/territory/points` used to leave the pre-charge balance (scout never applied `balance` at all). The command's `balance` is now kept, and the rest of the HUD (pending, holdings, limit, season earned/spent) stays. A later 200 replaces the whole summary. The wallet source cannot paint the pre-charge number back over a command balance. |

Cash: no city-points cash row in the three audits. Money switches, `PlayerLaunch.merchantCenterEnabled`, and merchant entry were not touched. `AppSession.swift` stays 7977 lines. No `String(localized:)`. Play init order (`devices`, `sensors`, `artworkHosts`) unchanged.

Tests (no Swift toolchain in this environment, so they were not executed here):

- `CityBoardStoreTests.testPointsChargeSurvivesPointsRead404` — claim 500 → 440 on a points 404, holdings/pending/season kept; a later 200 replaces the summary; scout → 430 and shield → 370 on another 404.
- `CityMonopolyTests.testTerritoryModelReloadQuoteConfirmAndHaptics` — command balance 440 stands while the wallet source is still 500; scout 430 and shield 370 stand on a points 404.
- `CityMonopolyTests.testTerritoryModelChallengeLossPropertyLossDistrictAndRevenue` — a scout reply with no `balance` does not invent one.
