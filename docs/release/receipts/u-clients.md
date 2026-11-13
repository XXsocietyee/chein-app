# u-clients: app clients for U06 / U08-03 / U08-04 (2026-11-13)

Branch `ui/u-clients` from `origin/ui/main` `34f866715`. Backend: hengyin `integration/backend-app-r2` `2e6f6651c`
(U06 `758bcf9d1`, U08-03 `a1974a9a2`, U08-04 `955175611`). Code only: no xcodebuild, swift build or swift test was run
here. The integrator compiles and runs the tests.

## What ships

| Item | Core | App (entry) |
|---|---|---|
| U06 turn block | `Core/PlayAdvancedTurnProjection.swift`: decodes `multiplayer.turn` (index, position, size, round, completed/required, finished, myTurn, turnsUntilMine). `currentRoleId` and `turnOrder` are kept **only when the caller is the leader**, and a non-leader projection drops them even if a response carries them. Inconsistent blocks (position ≠ index % size, myTurn ≠ (wait == 0)) decode to nil. `PlayAdvancedTeamProjection.turn` | `App/PlayAdvancedTurnBlock.swift` in `PlayAdvancedTeamControls` (session runtime team view, U06-02 "当前等谁"). Every member sees the current turn, the next turn, "your turn" or "your turn in N", and the round. The leader also sees the role holding the current and next turn and the full order. With no `turn` block, the old turn-index row stays. |
| U08-03 creator maintenance | `Core/CreatorStudioContracts.swift` `CreatorStudioService`: `GET api/creator/feedback`, `GET …/maintenance/tickets[/{id}]`, `POST …/maintenance/tickets`, `GET …/maintenance/requests/{requestId}`, `POST …/tickets/{id}/close` | Creator centre (`CreatorContentCenterView`, Account → 创作者中心) → **维护工作台**. Feedback (per topic, reporter never shown) → select → open ticket. Ticket list → detail with the server-derived stage (problem / original content / fix draft / new version / retest / close, with versions) → close FIXED (enabled only on `canCloseFixed`) or NO_CHANGE (reason required). |
| U08-04 post-game outcome | `CreatorStudioService.postGameOutcome(cohortDate:windowDays:topicID:)`, `CreatorOutcomePresentation` | Creator centre → **复报 · 分析适配入口**. Cohort day (Shanghai), 7/14/30/60/90-day window, all topics or one. |

U08-04 owner hard rules (UI优化施工清单 §U08-04) as implemented:

* `mature=false` shows "未成熟" for the rate and the retained count, never 0%.
* A null count shows `—`.
* `basisVersion`, `computedAt` and every `sourceWatermarks` entry are always shown, and a null watermark shows `—`.
* `historicalReplayable=false` adds "即时计算，不可回放".
* `testExclusionBasis=NO_SERVER_MARKER` adds "未排除测试数据", and the report never claims that test data is excluded.
* `scope.omittedMetrics` (REWARD_ISSUANCE, PRIVATE_PHOTO, PUBLIC_SHARE, RECOMMENDATION_CLICK, CLIENT_OBSERVED_EVENT) plus ROAM_REVISIT (the scoped report sends `roamRevisit: null` without listing it) are listed under "本报表不提供" as **不可用**, never as 0. CLIENT_OBSERVED_EVENT is labelled "客户端观测，非最终结果".
* `unavailableSources` is listed there too.
* A 5xx or `REPORT_SOURCE_UNAVAILABLE` shows "数据来源暂不可用，这不是 0". A failed reload clears the old report.

## Grants (non-money, owner approval)

* `ChinaReviewedRouteCapability.creatorStudioOwnerGrant` covers the six route keys. `admitsChinaProductionCall` admits them, and `marks`/`wiredPatterns` are unchanged, so the counts 996 and 677 are untouched.
* `ReviewedPlayerWriteLeases`: `creatorStudioPaths` sits inside the `player-write-paths` block and is carried on the **play** grant (`playPaths ∪ creatorStudioPaths`). `playConfiguration` keeps `playPaths` alone. The brief's "capabilityReadPaths" does not exist on this tree. `acceptsPlayerWrite` has a creator branch:
  * reads must be body-less GETs;
  * the two writes must be JSON POSTs with a `requestId` and no money key.
  * The money switch and forced-off checks run first, as for every player write.
* `AppCompositionRoot.admitsPlayerWriteQuery`: the three query-carrying GETs were added **on the existing line** (line count still 4184). `AppSession.swift` is unchanged (8171). The service comes from `AppSession.creatorStudioService` in `App/CreatorStudioMount.swift`. It exists only for the reviewed China deployment with player writes.
* Composition test `testShippedChinaAdmitsCreatorStudioAndKeepsMoneyClosed` (ReviewedChinaLaunchCompositionTests) checks four things:
  * the real service reaches all 7 calls through the shipped transport;
  * the grant and capability contain the paths;
  * a ticket POST with `amount` is refused;
  * `pay/create` and `wallet/withdraw` stay closed.

## Hidden when the backend lacks the capability

Production does not serve these routes yet. The creator-centre rows probe their own route first: tickets `limit=1`, and the report for today's cohort.

* A route-level 404 hides the row. On TEST an unknown route answers `{"code":404,"msg":"请求路径不存在"}` with no `errorCode`.
* So do a refused composition (`APIError.notConfigured`), a signed-out viewer and a transport error.
* A business 404 such as `CREATOR_TOPICS_NOT_FOUND`, a 4xx or a 5xx proves that the route exists. The row stays and shows that state.
* U06: no `turn` block means no turn block, and the old row stays.

## Gates (this tree)

* `python3 tools/generate_project.py`: 3522 native sources, 206 catalogs.
* `python3 tools/check_scaffold.py`: PASS (structural checks, 16089 bilingual keys, appsession ratchet).
* `python3 tools/check_design_lint.py`: PASS.
* `xcrun swiftc -parse` on all 15 new or changed Swift files: clean.
* `Tests/ContractChecks/test_player_write_grant.py` and `test_allowlist_routes_have_backend.py`: OK.
* Core stub-transport tests `Tests/CoreTests/CreatorStudioTransportTests.swift`: 15 cases, one or more per route. They use the **real TEST JSON** captured on 2026-11-13 from https://8120-agqyfqxs5vwolymtoibzq3fhde.instabox.tech as 9003 (author) and 9009 (no topics): feedback, ticket list and detail, open, open recovery (APPLIED and NOT_FOUND), close (409 FIX_NOT_PUBLISHED, then NO_CHANGE), post-game outcome (`mature=false`), `CREATOR_TOPICS_NOT_FOUND`, the route-absent 404 and the 500 body. The open/APPLIED payloads reuse the ticket shape with the OPEN/REPORTED values the backend smoke recorded. The U06 cases are built from the backend's `publicTurn` code, because TEST has no seeded multiplayer session. **Not run here** (integrator).

Strings: 138 new keys in `Resources/Localizable.xcstrings` (en + zh-Hans). UI uses CYListRow, CYRowIcon, CYStatusChip, CYPillButton, CYEmptyState and CYLoadingStateView. The layout follows the Mobbin reference (Reddit Insights / Brainly stats): a window picker on top, metric rows with the value on the right, and the basis in footnotes.

## Findings for the backend

1. **`GET /api/creator/feedback` without `topicId` returns 500 on TEST.** The Druid WallFilter rejects the `… WHERE 1 = 1 ORDER BY …` query ("select alway true condition not allow"; app.log 23:12:39). With `topicId` it works. The app always sends `topicId`: it takes the topics from the creator content list (`api/project/my`, type topic) plus the topics on its tickets. The client still supports the unscoped call once that is fixed.
2. The owner flow reads 问题→原内容→修复草稿→**复测→新版本**→关闭. The backend derives RETESTED only from the author's completed run on a **published** newer version. The detail shows the backend order (new version, then retest), so no step reads as done before its fact exists.

## Not done

No simulator or UI run. Mac load is high (the coordinator asked for throttling), and the integrator compiles. The U06 block is not checked against a live multiplayer session, because TEST has none.
