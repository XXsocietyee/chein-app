# Acceptance A5: native scan check-in drops `nodeId` (acceptance-r3 wave 6, F06)

Branch `ui/h-acceptance-a5` from `origin/ui/main` @ 5a93b447.

## Root cause

`PlayExperienceService.completionRequest(scope:nodeID:evidence:advance:token:boundary:)` (Core/PlayExperienceService.swift),
`.scan` case: the builder first sets `nodeId`, and then the scan branch removed it again ("source checkin resolves node
from code"). Wave 6 tested a build from before e83c99ca. In that build the branch always removed `nodeId` but still
merged the action-context fields, so the native door check-in sent
`activityId, topicId, code, routeActionId, expectedRouteVersion, routeSessionId` with no `nodeId`.
e83c99ca (A1) narrowed the removal to intents without a `routeSessionId`. The removal itself was still there.

Backend contract (hengyin `ApiPlayProgressController.checkin` → `PlayBasicCommandApplication.checkin` →
`PlayBasicIntentApplication.executeBasicIntent`):
- `routeActionId`, `expectedRouteVersion` and `routeSessionId` are required. Without them the reply is
  `INTENT_INPUT_INVALID` "必须提供动作标识、期望版本和原运行时身份".
- `basicIntentScope` then runs `Long.valueOf(nodeId)` before it reads the code. A missing `nodeId` gives
  `INTENT_INPUT_INVALID` "参数有误". This is the F06 failure.
- `runtimeInstance` and `authorityEpoch` are sent as a pair, only on a shared runtime.

## Fix

- `completionRequest(.scan)` no longer removes `nodeId`. Every checkin now sends the scope field, `nodeId`, `code`
  and the run identity merged from the action-context-bound `PlayRouteAdvance`: `routeActionId`,
  `expectedRouteVersion`, `routeSessionId`, plus `runtimeInstance`/`authorityEpoch` when the runtime is shared.
  This is the same identity that `play/answer` (PlayService) and the store-day checkin (PlayStoreDayService) send.
- Replay safety: a journal written without `nodeId` was always refused before any receipt was written, so no
  server receipt has that request shape. Adding `nodeId` cannot break an exact replay.
- In production `.actionContextBinding` is enabled (App/ReviewedPlayerWriteLeases.swift), so
  `PlayExperienceCoordinator.submit` reads `GET api/play/action-context` before it writes the journal and sends
  the bound identity.

## Tests

| test | asserts |
|---|---|
| `PlayExperienceTests.testDoorCheckinBodyMatchesBackendContract` (new) | Parses the exact multipart body of a door scan: `{activityId, nodeId, code, routeActionId, expectedRouteVersion, routeSessionId, runtimeInstance, authorityEpoch}`, with nothing missing and nothing extra. Also checks POST to `api/play/checkin` and the multipart content type. |
| `PlayExperienceTests.testQRCarriesReviewedNodeID` (was `testQRDoesNotManufactureNodeIDField`) | A scan sends `nodeId=701` alongside `code`. |
| `PlayExperienceTests.testScanRouteAndDormantCapabilitiesAreUnchanged` | Now expects `nodeId`. Still no location fields. |
| `PlayExperienceTests.testContextBoundScanCarriesNodeAndRunIdentity` (e83c99ca) | Unchanged; still valid. |
| `test_play_experience_contracts.test_qr_checkin_names_reviewed_node`, `test_w2_19_playMerchant.test_endpoints_are_exactly_the_mini_program_routes` | Source guards updated: `fields.removeValue(forKey: "nodeId")` is now forbidden. Before, it was required. |

Results (Swift is not installed in this environment, so the XCTest cases were written but not compiled or run):
- `python3 -B -m unittest test_w2_19_playMerchant test_play_experience_contracts`: 28 run, OK (5 skipped).
- `python3 -B tools/check_scaffold.py`: PASS, exit 0. Same result as the base.
- `python3 -B tools/contract_ratchet.py --check`: 185 failing, baseline 184, new 1. The base `ui/main` without
  this change gives the same 185, and the same single "new" failure
  (`test_play_task_outcome_journey…test_normal_result_host_survives_missing_node_during_readback`), which
  predates this change. **No new failures.**

## Not covered here

- `PlayPrefabRuntime.arriveAndCaptureHallPhoto` sends `arrive` (location, not scan) through
  `completePreparingJournal` with no action context, so it would be refused the same way (A1 residual, prefab
  path only).
- Not re-run against TEST. To confirm, re-run F06 with the harness switched back to the native request shape.
