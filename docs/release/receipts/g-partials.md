# g-partials — closing the PARTIAL rows of G1 (play runtime) and G7/G8 (club / team / misc)

Branch `ui/g-partials` = `origin/ui/cloud-g-club-misc` (`b883292dd`) + `--no-ff` merge of `origin/ui/cloud-g-play` (`bea7690f5`).
Merge conflicts in `App/ReviewedPlayerWriteLeases.swift`, `Core/ChinaReviewedRouteCapability.swift` and
`Tests/AppUnitTests/ReviewedChinaLaunchCompositionTests.swift` were resolved as the union: both path sets (no duplicate entries),
both owner grants (`playerGapOwnerGrant` + `playRuntimeOwnerGrant`), the G1 GET-only read rule ahead of the G7/G8 bodyless-GET rule,
and both composition tests.

Mini-program source: `/private/tmp/claude-501/hg/chengyinhub-xcx` (`92eda912`). `pages/roam` (the BL-41 card consumer) is not in that
checkout and was read from `/Users/fanning/hengyin-pr730/chengyinhub-xcx` (`4ac8c249f`); `/private/tmp/claude-501/hengyin-pr730` does not exist.
Backend existence for circle answer/record: `origin/ui/capgraph` `docs/release/capability-graph.csv` (`ApiCircleThemeController.answer` / `.record`).
Code only; no `xcodebuild` was run. `App/AppSession.swift` and `App/AppCompositionRoot.swift` are unchanged.

## Rows

| Row (receipt) | Was | Now | Native |
|---|---|---|---|
| `GET /api/official/active-for-roam` (club-misc) | PARTIAL: card did not navigate | DONE | `OfficialRoamActiveCardView(destination:)` → `RoamActiveOfficialEventDestination`: one open event opens `OfficialEventDetailView` (mini-program `official-detail?id=`), several open the roam official-task list (`openRoamTasks`). Same session-reader guard as `RoamOfficialTasksDestination`. |
| `POST /api/team/trail/sync` (club-misc) | PARTIAL: no walked points | DONE | `Core/TeamWalkedTrail.swift` ports `play-trail.js` (accuracy ≤ 60 m, step ≥ 8 m, simplify to 1000 past 4000 with `roam-track-simplify.js`). `App/TeamTrailForegroundRecorder.swift` feeds it GCJ-02 fixes only while the team model is sharing (`canRun`), the scene is active and When-In-Use/Always is already granted; it never requests permission and never enables background updates. `TeamTrailSection` syncs every 12 s (back-off to 60 s), ≤ 40 new points per body `{activityId, pts, done}`, `done` = done visible nodes. The team rail is still a list, not map polylines. |
| `POST /api/play/help/shared` (g-play) | PARTIAL: no TEAM view | DONE | `Core/PlayTeamBackpack.swift` `PlayCoopHelpFlow` ports `coop-help-methods.js` (VIEW / USE / SKIP, same request id after an unknown, SKIP closes and re-reads). `App/PlayTeamBackpackView.swift` `PlayCoopHelpSheet` behind 「提示」 on TEAM QUEST rows. |
| `POST /api/game/session/shared/preview` (g-play) | PARTIAL: no TEAM view | DONE (preview) / HIDDEN (commands) | `PlayTeamTradePreview` ports `previewThemeTrade` (preview-only, payload/teams/revision/epoch matched; a newer revision re-reads the backpack once). 发起交换, trade confirm/cancel, TEAM item use/discard/receive and the TEAM reward preview before QUEST_RESOLVE / FACILITY_USE are HIDDEN: each leads to `api/game/session/command`, which the player grant does not carry. |
| TEAM backpack itself | — | DONE (read) | `PlayTeamBackpackRead` = `_loadPlayerGameModule` + `_applyThemeTeamView`: `GET api/game/session/view {activityId, perspective: PLAYER}`, ROUTE + TEAM only; absent-session codes hide it. `PlayThemeBackpackView` shows `PlayTeamBackpackSections` and hides its personal projection while a TEAM snapshot is loaded. |
| `GET /api/play/history` (g-play) | PARTIAL: no renderer | DONE | `App/PlayCompletedHistorySection.swift`: like `_loadCompletedHistory`, earned chapters the live route does not list appear as read-only 「已完成章节」 cards on the run screen. Failed/mismatched reads show nothing. |
| `GET /api/play/advanced/receipt` (g-play) | PARTIAL: coordinator did not call it | DONE | `PlayExperienceService.advancedReceipt` (`resolveUnknown`): same session + idempotency key and a view past the sent version. `PlayAdvancedCoordinator.recover` and `recoverDurably` ask it first; a match settles the original without replay (durable: dispatching → acknowledged → cleared; a failed step returns the record to unknown). Anything else falls back to the state read and the exact replay. Mod-installation flows keep their own readback. |
| `POST /api/play/theme/gameplay-preview` overflow (g-play) | PARTIAL: no discard picker | DONE | `PlayThemeGameplayFlow.setDiscard / rereadPreview` port `changeThemeRewardDiscard` / `rereadThemeRewardPreview`: per own reward a stepper 0…quantity, the preview is re-read with `discardRewards`; until that read succeeds confirm stays off; 重新读取 clears the discard choice. |
| `POST /api/circle-theme/session/answer`, `/record` (g-play) | PARTIAL: dormant service only | DONE | Backend path exists (capability-graph). `App/PlayCircleProduction.swift` builds a `PlayCircleCoordinator` on the session transport (`[.reads, .circle]`) only when the shipped China composition built the player grant; `SessionPlayRuntimeView` uses it when the dormant one is nil. |

## Grants (both places)

- `ReviewedProductionGateLeases.playPaths` gained the circle page's own player routes: `api/circle-theme/instance/{}/offers`,
  `api/circle-theme/session`, `api/circle-theme/session/join`, `api/circle-theme/session/{}/card` (all already `liveInProduction` in
  `ChinaReviewedRouteCapability`). `circle-theme/instance/configure` (merchant host write) stays out.
- `playRuntimeReadPaths` gained `api/game/session/view`; `acceptsPlayerWrite` admits it only as a bodyless GET with exactly one
  `perspective=PLAYER` (`playerPerspective`). CLUB / MERCHANT perspectives are not this grant. `/api/game/session/view` was already
  `liveInProduction` in the China table, so `wiredPatternCount` is unchanged.
- No money, payout, host-only or merchant route was added. `api/game/session/command` is not granted.

## Rules kept

- Money, host-only and merchant entries stay hidden. Unknown values are never shown as 0 (team trail `done` comes from the snapshot,
  backpack values print the server text, trade loads require integers). A nil service / binding / grant hides every new entry.
- New strings in `Resources/Localizable.xcstrings` (38 keys, en + zh-Hans); Core copy uses `W8Text.t(zh, en)`; `PlayCoopHelp` row/reason text is now bilingual.

## Gates

- `python3 tools/generate_project.py` (4 App + 2 Core sources + 1 Core test), `python3 tools/check_scaffold.py` PASS,
  `python3 tools/check_design_lint.py` PASS, `xcrun swiftc -parse` clean on every changed Swift file.
- `swift build --build-tests` built the whole `QuestifyCore` module (new Core files included). The full Core test target does not compile on
  the base tree (pre-existing: `UGGameplayTests.swift:421` implicit self, `ObjectCardTests.swift:185/262` await in autoclosure,
  `PlayThemeReplayTests.swift:106` type mismatch), so the run used a temporary `sources:` filter (reverted, not committed):
  `PlayGapPartialsTests`, `PlayRuntimeGapTests`, `PlayerGapRoutesTests`, `PlayAdvancedDurableRecoveryTests`,
  `PlayAdvancedOriginalRecoveryTests`, `ModInstallationNativeRuntimeTests` (+ `ContentDraftDurableJournalTests` for shared fixtures):
  **119 tests, 0 failures**.
- New stub-transport tests (`Tests/CoreTests/PlayGapPartialsTests.swift`): walked trail filters/simplify, trail sync uploads each walked
  point once, TEAM backpack read (path, PLAYER query, merge, personal/absent/foreign/lost), shared help VIEW/USE/retry-same-id/SKIP and
  rejection/stale, trade preview body + ready/stale/unconfirmed, advanced receipt settles / does not settle. `PlayAdvancedDurableRecoveryTests`
  gained a durable receipt-settle test, and its path expectation now includes the receipt read before the state read.
- `ReviewedChinaLaunchCompositionTests.testShippedChinaAdmitsPlayRuntimeAndKeepsMoneyClosed` now also checks: PLAYER game-session view
  admitted, CLUB/MERCHANT closed, circle routes in the grant, circle card GET and session open POST reach the network. Not run here
  (integrator's App build/test lane).
- Contract checks (`python3 -m unittest discover` in `Tests/ContractChecks`): 21 failures outside `contract-failing-baseline.txt`; the 20
  runnable ones fail identically on the parent merge commit `1b8359eaf` (e.g. uncatalogued `ChapterReadingPosition`, playkit hangman
  strings, module import errors). None is caused by this branch; no new device store was added.
