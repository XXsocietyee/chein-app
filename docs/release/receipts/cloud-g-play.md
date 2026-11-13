# Cloud G1 — play runtime (player)

Parent: `origin/ui/main` `ec2e42ba8`. Source list: `origin/ui/capgraph` `c2202dbe3`, `docs/release/capability-graph.md` §(1) MP-ONLY “play runtime (player) — 25”.
Mini-program source read: `chengyinhub-xcx` at `/private/tmp/claude-501/hg/chengyinhub-xcx` (PR #812, 2026-11-12). The path named in the brief does not exist on this machine. `pages/topic` and `pages/topic/merchantinfo` are not in that checkout, so those two pages were read from `/Users/fanning/hengyin-pr730/chengyinhub-xcx` (2026-11-06).
Code only. No `xcodebuild` was run. The integrator compiles.

## What changed

- `Core/PlayRuntimeGap.swift` (new). `PlayRuntimeClient` sends one request per call: a form POST (the mini-program default header), a JSON POST, or a GET. The calls are typed and ported from the mini-program:
  - `PlayCheckRuntime` is `journey-check-recovery.js` `_legacyCheckAction`. Roll, reroll and settle are form POSTs `{topicId, activityId, sessionId, nodeId, checkId}`. The server rolls. Before sending, the client stores the pending write on the device: `{scope, action, actionId = check:<node>:<check>:<action>}`. A receipt is accepted only when the session, node, check and `actionId` all match. Only `CHECK_REJECTED` or `CHECK_BAD_REQUEST` clears the pending write. Anything else is unknown, and the only way out of unknown is `recover`, which is `GET api/play/check/receipt {sessionId,nodeId,checkId,action}`. A relaunch restores the unknown state. `marginText` and `natTag` are ported. A receipt marked `detailsHidden` never shows dice or totals.
  - `PlayAdvancedReceipt.read` is `GET api/play/advanced/receipt {sessionId, idempotencyKey}`. It accepts only the same session and key, and returns the `view` to hydrate.
  - `PlayCoopHelp` is `coop-help.js`: the body, level rows (free, points cost, unlocked, off, SKIP), and the outcome as OK, rejected or unknown. A lost response may only be retried with the same request id.
  - `PlayHistoryProjection` is `play-history.js` `project()`. Every field is checked. If any check fails, nothing is shown.
  - `PlayTopicSetup` is `_loadPrep` and `_buildPrep`. It shows up to 6 prep items. It shows the play window only when the mode is not `any`. It reads `openNow` and builds the row text. A failed read shows the retry row.
  - `PlayContact` is `contact()` plus the `loadPlayContact` params. The phone must match `^[0-9+\-\s()]{3,32}$`.
  - `PlayThemeGameplayExchange` covers the SOLO command shape, `gameplay-action` (applied only with the same session and an integer version), `gameplay-preview` (through the existing `PlayThemeRewardsRules.preview`), and the player-side `game/session/shared/preview`.
  - `PlayRunSessionClear` is `clearServerRunSession`.
- `App/PlayRuntimeGapProduction.swift` (new). This is the production binding, the same shape as `PlayThemeReplayProduction`. It uses the session's regional API and `runtimeHTTPTransport`. It has a per-scope bridge, a device store for pending check writes (`UserDefaults`, catalogued in `docs/ops-safety/client-data-catalog.json`), and the environment keys `\.playRuntimeGap` and `\.playRuntimeTopicClient`.
- `App/PlayRuntimeGapViews.swift` (new):
  - `PlayCheckRuntimeSection` is the D20 card. Hold to roll, then the server's dice and verdict, then reroll or settle. It shows 「再次查询」 when the result is unknown.
  - `PlayContactSection`: 联系主办 / 联系商家. The number shows as text, with a `tel:` link beside it. On a finished run it also sends the `run-session/clear` end tombstone once.
  - `PlayTopicPrepSection`: 开局前准备 row and checklist sheet.
  - `PlayThemeGameplayFlow` and `PlayThemeGameplayFlowSection`: personal theme actions. The preview is read first for QUEST_RESOLVE and FACILITY_USE. An unconfirmed command can only be resent as the same command.
- Wiring:
  - `SessionPlayRuntimeView` installs `\.playRuntimeGap`.
  - `PlayExperienceView` shows the check card when the dormant journey coordinator is absent, and shows the contact section.
  - `PlayThemeBackpackView` builds gameplay rows from `GET api/play/theme/state` and dispatches personal actions.
  - `SessionTopicBrowserView` and `TopicDetailView` show the prep row.

## Grants (both places)

- `App/ReviewedPlayerWriteLeases.swift` `playPaths` gained these POSTs: `check/roll|reroll|settle`, `help/shared`, `run-session/clear`, `theme/gameplay-action|gameplay-preview`, `game/session/shared/preview`, `circle-theme/session/answer|record`. It also gained the reads in `playRuntimeReadPaths`: `encounter`, `check/receipt`, `advanced/receipt`, `history`, `setup`, `contact`.
- A read path is admitted only as a GET with an empty body. A POST to a read path is refused.
- `AppCompositionRoot.admitsPlayerWriteQuery` lets those GETs through the early query gate. The line count stays at the 4307 ratchet.
- `Core/ChinaReviewedRouteCapability.swift` has a new owner set, `playRuntimeOwnerGrant`: `/api/play/help/shared`, `/api/play/history`, `/api/circle-theme/session/answer`, `/api/circle-theme/session/record`. Every other route in this gap was already in `wiredPatterns`. `wiredPatternCount` (672) is unchanged.
- The following are not granted to players: `game/session/shared/control`, `shared/export`, `shared/export/anchor` (host only), and `circle-theme/instance/configure`, which is a host write on `merchantinfo`. Every money path stays closed.

## Path → native file → status

| Path | Native | Status |
|---|---|---|
| `POST /api/play/check/roll` | `Core/PlayRuntimeGap.swift` `PlayCheckRuntime` · `App/PlayRuntimeGapViews.swift` `PlayCheckRuntimeSection` | DONE |
| `POST /api/play/check/reroll` | same | DONE |
| `POST /api/play/check/settle` | same | DONE |
| `GET /api/play/check/receipt` | same (`recover`) | DONE |
| `GET /api/play/advanced/receipt` | `PlayAdvancedReceipt.read` | PARTIAL: the Core read, grant and test are in. The native advanced game (`PlayAdvancedCoordinator`) still reconciles unknowns its own way and does not call this read yet. |
| `POST /api/play/help/use` | H8 `App/PlayHelpLadderPanel.swift` (reused) | DONE (H8) |
| `POST /api/play/help/skip` | H8 (reused) | DONE (H8) |
| `POST /api/play/help/shared` | `PlayCoopHelp` | PARTIAL: Core, grant and test only. The shared help sheet belongs to the TEAM backpack, and the native backpack does not present TEAM views. |
| `GET /api/play/history` | `PlayHistoryProjection` | PARTIAL: Core read, projection, grant and test only. The mini-program only prepares this read for a later continuous-history renderer (`_precedingHistoryParas`), and there is no native chapter journal for it to feed yet. |
| `POST /api/play/run-session/clear` | `PlayRunSessionClear` · `PlayContactSection(finished:)` | DONE when a run completes. The pause/exit paths are not ported, because the app has no paused-run timer. |
| `GET /api/play/setup` | `PlayTopicSetup` · `PlayTopicPrepSection` on topic detail | DONE. The `orient/safety/check` precheck before start is not part of this gap. |
| `POST /api/play/theme/gameplay-action` | `PlayThemeGameplayExchange.action` · `PlayThemeGameplayFlow` in the backpack 玩法 tab | DONE (SOLO). TEAM goes through `game/session/command`, which is not here. |
| `POST /api/play/theme/gameplay-preview` | `PlayThemeGameplayExchange.preview` · flow | PARTIAL: the preview is read and confirmed. When the backpack would overflow, the discard picker is not offered and confirm stays disabled. |
| `POST /api/play/theme/replay` | cloud-stubs-replay `App/PlayThemeReplayProduction.swift` (reused) | DONE (replay) |
| `POST /api/circle-theme/instance/configure` | none | NOT GRANTED: host write on `merchantinfo` (merchant side). The new mini-program circle page does not call it. |
| `POST /api/circle-theme/instance/{}` | `PlayCircleRuntime.circleOffers` (`GET instance/{id}/offers`, already wired) | DONE. This is a capgraph artifact of the offers read. |
| `POST /api/circle-theme/session/answer` | `PlayCircleRuntime.circleWrite(.answer)` (existing) | PARTIAL: the China and composition grants were added here. The circle screen is still built from the dormant play runtime service (`AppSession.playCircle`), so it does not reach production yet. |
| `POST /api/circle-theme/session/record` | `PlayCircleRuntime.circleWrite(.record)` (existing) | PARTIAL: same as answer. |
| `POST /api/circle-theme/session/{}` | `PlayCircleRuntime.circleCard` (`GET session/{id}/card`, already wired) | DONE. This is a capgraph artifact of the card read. |
| `GET /api/game/session/shared/control` | none | HIDDEN for players (host control) |
| `GET /api/game/session/shared/export` | none | HIDDEN for players (host export) |
| `POST /api/game/session/shared/export/anchor` | none | HIDDEN for players (host export) |
| `POST /api/game/session/shared/preview` | `PlayThemeGameplayExchange.sharedPreview` | PARTIAL: Core, grant and test only. The trade and reward preview UI is part of the TEAM backpack, which is not presented natively. |
| `POST /api/orient/task/alternative` | none | OUT OF SCOPE: `pages/publish/fabu` author page, not the play runtime. |
| `GET /api/play/contact` | `PlayContact` · `PlayContactSection` on the run screen | DONE |

## Tests and gates

- `Tests/CoreTests/PlayRuntimeGapTests.swift` (new) uses one stub transport per route. It covers:
  - check roll, reroll and settle: form body, receipt match, and recovery after a relaunch through `GET check/receipt`
  - a mismatched receipt stays unknown; `CHECK_REJECTED` clears the pending write; a broken store never sends
  - advanced receipt, shared help, history, setup, contact, gameplay action, gameplay preview, shared preview, and run-session clear
  - 401 is reported as unauthorized, not unknown
  - the China gate admits all of these routes and refuses money routes
- `Tests/AppUnitTests/ReviewedChinaLaunchCompositionTests.swift` `testShippedChinaAdmitsPlayRuntimeAndKeepsMoneyClosed` sends every route through the shipped China composition with the app's own `PlayRuntimeClient`. It also checks that:
  - a POST to a read path is closed
  - host control and export and circle configure are not in the grant
  - `pay/create` and `wallet/withdraw` stay closed
- `python3 tools/generate_project.py` ran. `python3 tools/check_scaffold.py` PASS. `python3 tools/check_design_lint.py` PASS. `swiftc -parse` passes on every changed Swift file.
- Contract checks (`unittest discover`): no new failures that this branch caused. The remaining failures that are not in `contract-failing-baseline.txt` also fail on the parent tree. Examples: `ChapterReadingPosition` is an uncatalogued store, and the playkit hangman and creator-root text checks fail.
- `swiftc -typecheck` of the whole `Core/` module (macOS 14 target): 0 errors. It caught and this branch fixed one `self.activityID` assignment.
- Core and App unit tests were not run here. That is the integrator's compile and test lane.
