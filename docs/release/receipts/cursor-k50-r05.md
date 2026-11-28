# K50-R5 cold start

Branch `cursor/1128-k50-r05` from `origin/ui/combined-r7` at `b954de71c`. Tip merged again before push. No rebase, no force-push. `main` was not pushed. No deploy, no secrets, no SQL, no `xcodebuild`.

No `String(localized:)`. `App/AppSession.swift` was not edited (7976 lines, ceiling 7977). Play init order stays `devices`, `sensors`, `artworkHosts`. `PlayerLaunch.merchantCenterEnabled` stays `false` in Release. `ReleaseMoneyWriteSwitch` was not edited.

The first screen's required reads are unchanged: `HomeFeedView` still resumes on `.task(id: binding)`, the home city consent and today-ticket tasks still start with `homeFeedReader` / `ticketWalletReader` / `sessionRevision`, and `session.bootstrap()` still starts from the root `.task`. `homeFeedService` is still built in `AppSession.init`.

## What left the critical path

These used to run in `QuestifyApp.init` or in the first `SessionRootView` body. They now run on the next main turn after the root appears (`ColdStartDeferredLaunch` → `ColdStartAfterFirstFrame.open`), or when the home tab has appeared.

| Work | Before | After |
|---|---|---|
| Orphan Live Activities | `QuestLiveActivityCenter.endOrphanedActivities()` in `QuestifyApp.init` | `ColdStartAfterFirstFrame.open` |
| Plan-activity tokens | `QuestPlanActivityCenter.start()` in `QuestifyApp.init` | `ColdStartAfterFirstFrame.open` |
| External-game catalog | `ExternalGameCatalogLaunch` `.task` called `ExternalGameStore()` (registry and per-game progress on disk) on appear | same refresh, after `waitUntilOpen()`; a later token change still refreshes |
| Personal location monitor | first body read `session.personalLocationShareHost` (`NWPathMonitor`) and applied the scene phase | host is created only once `pastFirstFrame` is set; the current scene phase is applied then, and a parked control route still opens if the scene is active |
| Roam, publish, club, mine | built in the first `TabView` body (roam includes the map home) | `deferredTab` keeps them as an empty placeholder until the home tab's next main turn, or until that tab is selected |

Still on the critical path: the notification delegate (`MPNotificationTapRouter.attach`, required before launch finishes) and the Control Center handler (`QuestWidgetBoardPublisher.installControlRoute`). A nil handler would park a control route, and the scene-phase open can already have run.

## Device-free split

`Core/ColdStartFirstFrameSplit.swift` `measure` walks a virtual clock. Critical lanes finish, that clock is the first frame, then deferred lanes start. Weights are iPhone 12-class (A14) main-thread milliseconds, not an Instruments trace. Budget is 1500.

Measured on that clock: critical **840** (notification 15, control route 5, home session graph 640, home required reads 180), deferred **1610** (orphan activities 280, plan activity 240, game catalog 300, location monitor 90, other tabs 700). 840 ≤ 1500. 840 + 1610 = 2450 > 1500. Counting the other tabs as critical is 1540 and fails the budget.

Tests: `Tests/CoreTests/ColdStartFirstFrameSplitTests.swift` (the clock) and `Tests/ContractChecks/test_k50_r05_cold_start.py` (the same clock from the Swift table, plus the call sites). The contract test passed here. Core tests were not compiled (`xcodebuild` was not run).

## Gates

- `tools/generate_project.py` — regenerated; the two new Swift files are in the project
- `tools/check_scaffold.py` — PASS
- `tools/check_a11y_lint.py` — 0 new
- `tools/check_design_consistency.py` — PASS
- `tools/check_appsession_ratchet.py` — PASS (`AppSession.swift` 7976, ceiling 7977)
- `tools/contract_ratchet.py --check` — new 0 (46 failing, baseline 46)
