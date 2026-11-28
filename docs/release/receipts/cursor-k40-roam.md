# cursor/1128-k40-roam — roam tab, official roam tasks, roam history

Base: `origin/ui/combined-r7` @ `a7c956335`. Audits read from `origin/audit/1128-plan`, `origin/audit/1128-functions`, and `origin/audit/1128-ada`. Map search and nearby search stay with the map agent. Team writes, stamps, poster scan, coupons, external maps, and ADA layout were not edited.

Backend: `gh repo view XXsocietyee/hengyin` could not resolve the repository. No server change. No backend SHA.

## Fixed

| Row | What closed |
|---|---|
| Official roam task list and the first-discovery tasks card | Detail now uses `RoamOfficialTaskDetail.make` and receives `session.officialActionCoordinator`, so signup, complete, and arrival use the existing coordinator. This view does not build a second writer. |
| Finished-session tile archive | A same-process finish keeps first-seen tile times in memory and `RoamLiveSessionView` posts `api/roam/session/records` through `RoamSessionArchive.flush`. The journal still stores `"track": []` and no `collectedAt`. A restored walk does not invent times. |
| Legacy official-route empty list | `OfficialRouteListView` empty state offers the existing `roamSub.w208.poi.backToMap` action (`officialRoute.list.empty.backToMap`). |

Proof: `Tests/AppUnitTests/K40RoamOfficialTasksCompositionTests.swift` builds `RegionalLaunchConfiguration.reviewedDeployment` and checks the player approval admits `api/official/events/{}/signup`, `.../complete`, and `.../arrivals`, the player grant admits `api/roam/session/records`, a merchant context gets neither, and the detail factory keeps the same coordinator instance. `Tests/CoreTests/RoamLiveSessionTests.swift` checks the in-memory archive and that storage has no `collectedAt`.

## Already fixed @ a7c956335

| Row | Evidence |
|---|---|
| R-01a roam tab reaches 组局 and the live walk | `RoamMapHomeSheet` roam section, nearby teams, 走起 |
| P1-17 / R-16b device location on the roam home | `AppSessionRoamLocate.locateRoamArea` and `QuestifyApp` `locateArea` |
| P2-7 location status re-read after Settings | `RoamMapHomeSheet` re-reads on scene phase `.active` |
| P2-7 guest 走起 sign-in | `signInToStart` when `session.account == nil` |
| P1-25 / R-16c US live roam | `shippedComposition` pins a US build to the China deployment, so `roamLiveApproval` is issued. The composition test asserts that pin. |
| P1-18 presence heartbeat | `RoamLiveApproval` is built with `presence: true` |
| Official routes list and detail | `officialRouteReader` GET `api/preset/route/list` and `api/preset/route/info` |
| Map-home official-routes empty next step | `RoamMapHomeRoutes` `officialRoute.list.empty.backToMap` |
| G-10b official participation lease | `sessionDependencies.officialActionApproval` for player and club; merchant stays nil |
| One-event official shortcut | `RoamActiveOfficialEventDestination` already passes `session.officialActionCoordinator` |
| R-02d live fog | `PersonalFogFeature.liveRevealEnabled = true` |
| R-02f+ finish track upload | `RoamExperienceMutation.finish` sends `track`. Local history still stores an empty track. |
| R-15 / P1-23 roam history readers | Release catalog: passport history, session fact, and tiles are on |

## Owner-only

| Row | Value |
|---|---|
| P1-22 / R-16d city board and 领地 | city-game region list (`QUESTIFY_CITY_GAME_REGION`, empty in Release `Config/Base.xcconfig`) |

## Deferred-merchant

None. `PlayerLaunch.merchantCenterEnabled` stays false outside DEBUG/TEST. Merchant official-action and player-write grants stay nil.
