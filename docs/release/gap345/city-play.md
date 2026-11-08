# Gap 4 — city-game / play / city-value / city / progress / npc / onboarding / official / team

READ-ONLY classification (docs only). Branch `cloud/gap-4` (from `wip/wave4-loc`); source rows from `docs/release/backend-contract-for-ios.md` Appendix A (`cloud/doc-5`), rows marked MISSING under the nine prefixes.

- Backend baseline: `hengyin@4ac8c249fcad69e4f9c423702711d46deca2755a` (owner-confirmed, read-only checkout; nothing pushed to hengyin).
- **Production version is UNVERIFIED** (receipt 19408d49 deployed 2026-10-21). Every row below is flagged `deployment-pending-verification`; nothing here states production behaviour.
- Appendix A's method column is a heuristic; the methods below were read from the Swift call sites.
- Backend has **no** `/api/city-game/*` and no `/api/city-value/*` route (grep of non-test Java: NOT FOUND). `/api/game/session/*` (`ApiGameSessionController.java:41`, view :53, command :91, receipt :128) is **activity-scoped** with server-derived actor perspective and `GameSessionCommand{activityId,nodeId,requestId,expectedRevision,action,authorityEpoch,payload}`; the iOS city-game clients are **region/board/season-scoped** with their own envelope (`code`, `errorCode`, HTTP status mirroring). It therefore cannot be assumed to replace them.

## Summary counts (48 paths)

| Category | Count |
|---|---|
| ADAPTABLE | 4 |
| PARTIAL | 22 |
| MISSING | 22 |

Caveats: (1) the 4 ADAPTABLE rows are **already wired to the right backend route** — Appendix A listed them MISSING only because the iOS string is an approval-key / audit label or a prefix of a real call with an `{id}`; they need label/test hygiene, not new call logic. (2) Several rows are prefix strings, not calls (`/api/city-game/`, `…/acquisition/`, `/api/play/city-orientation/`, `/api/progress/requests[/]`); each is noted in its detail block. (3) Counts from the three analysis passes: group A 0/8/9, group B 3/8/6, group C 1/6/7 (ADAPTABLE/PARTIAL/MISSING).

## Table (one row per path)

| iOS path | Category | iOS call site | Nearest backend | Flag |
|---|---|---|---|---|
| `/api/city-game/` | PARTIAL | Core/CityValueBoundedMapScopedTransport.swift:33 builds GET `api/city-game/{current\|points}` (route enum :19-34, send :56-69; also … | No board/season/points route. Nearest: GET /api/city/nodes … | deployment-pending-verification |
| `/api/city-game/acquisition` | MISSING | Core/CityAcquisitionService.swift:79 is the route allowlist (CityAcquisitionRoute, prefix `api/city-game/acquisition`); real calls via … | NOT FOUND. Greps: `city-game`, `quoteHash\|self.?pay\|acquir\|titleRetained\|ownTitles`, `quote` in game session/play/team/merchant controllers. … | deployment-pending-verification |
| `/api/city-game/acquisition/` | MISSING | Core/CityAcquisitionService.swift:79 is the route allowlist (CityAcquisitionRoute, prefix `api/city-game/acquisition`); real calls via … | NOT FOUND. Greps: `city-game`, `quoteHash\|self.?pay\|acquir\|titleRetained\|ownTitles`, `quote` in game session/play/team/merchant controllers. … | deployment-pending-verification |
| `/api/city-game/action-budget` | MISSING | Reader/transport allowlist: Core/CityActionBudgetScopedTransport.swift:50 (prefix `api/city-game/action-budget`, routes /state, /request/{id}, … | NOT FOUND. Greps: `action.?budget\|actionPoint\|rollNumber\|dice` -> only advanced-play dice mini-game (AdvancedGameRuntimeServiceImpl.java:462-565; … | deployment-pending-verification |
| `/api/city-game/action-budget/command` | MISSING | Core/CityActionBudgetRecovery.swift:131 POST, JSON body CityActionBudgetCommand (Core/CityActionBudgetContract.swift:82-84: … | NOT FOUND (see action-budget greps). Nearest generic: POST /api/game/session/command … | deployment-pending-verification |
| `/api/city-game/action-budget/request/{}` | MISSING | Core/CityActionBudgetReader.swift:45 GET `api/city-game/action-budget/request/<lowercase requestId>` (receipt(), :41-49), no query, Accept json, … | NOT FOUND for budget receipts. Nearest generic: GET /api/game/session/receipt?activityId&requestId&perspective … | deployment-pending-verification |
| `/api/city-game/action-budget/state` | MISSING | Core/CityActionBudgetReader.swift:27 GET `api/city-game/action-budget/state?regionId=`; StateEnvelope{code,errorCode,data:CityActionBudgetState} … | NOT FOUND. Nearest: GET /api/game/session/view?activityId&perspective … | deployment-pending-verification |
| `/api/city-game/arrival-evidence` | PARTIAL | Core/CityArrivalEvidenceService.swift:101 route allowlist CityArrivalEvidenceRoute (prefix `api/city-game/arrival-evidence`); real calls via … | No /api/city-game route. Nearest: POST /api/game/session/command … | deployment-pending-verification |
| `/api/city-game/arrival-evidence/` | PARTIAL | Core/CityArrivalEvidenceService.swift:233 (`arrival-evidence/` + path inside execute()); sub-routes enumerated in the prefix row (state, merchant, … | No /api/city-game route. Nearest: POST /api/game/session/command … | deployment-pending-verification |
| `/api/city-game/merchant/operations` | PARTIAL | Core/CityMerchantOperationsService.swift:80 route allowlist CityMerchantRoute (prefix `api/city-game/merchant/operations`, exactly three routes … | Nearest: station-level pause/resume in POST /api/game/session/command … | deployment-pending-verification |
| `/api/city-game/merchant/operations/availability` | MISSING | Core/CityMerchantOperationsService.swift:140 GET `.../availability?regionId=` (availability() :139-143, query exactly regionId). Response … | NOT FOUND for availability/approvalHash/relation. Nearest: GET /api/game/session/merchant/entries … | deployment-pending-verification |
| `/api/city-game/merchant/operations/intent` | PARTIAL | Core/CityMerchantOperationsService.swift:146 POST JSON (submit() :144-147) via JSONSerialization sorted keys: … | Nearest: POST /api/game/session/command (chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api/ApiGameSessionController.java:91-92) … | deployment-pending-verification |
| `/api/city-game/merchant/operations/request/` | PARTIAL | Core/CityMerchantOperationsService.swift:149 GET `.../request/<UUID>` (receipt(id:) :148-153), no query; requires value.requestId==id, … | Nearest: GET /api/game/session/receipt?activityId&requestId[&perspective] … | deployment-pending-verification |
| `/api/city-game/neutral-tasks` | MISSING | Core/CityNeutralTaskService.swift:88 route allowlist CityNeutralTaskRoute (prefix `api/city-game/neutral-tasks`, :73-97). Real calls execute() … | NOT FOUND. Greps: `NEUTRAL\|REMOTE_NEUTRAL\|onsite.?task`, `city-game`, task controllers ApiPlay*/ApiOrient*. Closest: PLAYER_CHOICE/PLAYER_SUBMIT in … | deployment-pending-verification |
| `/api/city-game/neutral-tasks/` | MISSING | Core/CityNeutralTaskService.swift:199 (`neutral-tasks/` + path inside execute()); sub-routes enumerated in prefix row (state, command, request/{id}). | NOT FOUND. Greps: `NEUTRAL\|REMOTE_NEUTRAL\|onsite.?task`, `city-game`, task controllers ApiPlay*/ApiOrient*. Closest: PLAYER_CHOICE/PLAYER_SUBMIT in … | deployment-pending-verification |
| `/api/city-game/onsite-tasks` | PARTIAL | Core/CityOnsiteTaskService.swift:94 route allowlist CityOnsiteTaskRoute (prefix `api/city-game/onsite-tasks`, :78-106). Real calls execute() :250-251 … | Nearest: POST /api/game/session/command (chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api/ApiGameSessionController.java:91-92) … | deployment-pending-verification |
| `/api/city-game/onsite-tasks/` | PARTIAL | Core/CityOnsiteTaskService.swift:251 (`onsite-tasks/` + path inside execute()); sub-routes enumerated in prefix row (state, command, request/{id}, … | Nearest: POST /api/game/session/command (chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api/ApiGameSessionController.java:91-92) … | deployment-pending-verification |
| `/api/city-game/player-rules` | MISSING | `Core/CityPlayerRulesClient.swift:43` builds URL (`CityPlayerRulesRoute.request`, :41-49). GET, query-only, no body, `Authorization: <token>` header, … | NOT FOUND (greps above; no controller exposes board/season/rulesRelease/rulesHash). Closest unrelated: topic-level `journeyRules` embedded in topic … | deployment-pending-verification |
| `/api/city-game/state/snapshot  (and /api/city-game/state/deltas, next …` | PARTIAL | `Core/CityOrderedMapScopedTransport.swift:49` (validate) and request build `CityOrderedMapRequest.make` at … | Nearest: `CTRL/ApiCityNodeController.java:70-83` GET `/api/city/nodes` (params `lat,lng,radius,keyword,categoryId,tag,cityRole`; bbox coarse filter; … | deployment-pending-verification |
| `/api/city-game/state/deltas` | MISSING | Same file/line as snapshot: `Core/CityOrderedMapScopedTransport.swift:49`; used when `cursor != nil` (`CityOrderedMapReader.swift:59`). GET; same … | NOT FOUND (greps above; `cursor` grep over controllers finds no state-delta stream; no `/api/city/**` or `/api/roam/**` mapping lists event deltas - … | deployment-pending-verification |
| `/api/city-game/task-history` | PARTIAL | `Core/CityTaskHistoryService.swift:68` is the route-prefix check in `CityTaskHistoryRoute`; the real request is built in `execute` at … | Nearest: `CTRL/ApiPlayProgressController.java:274` POST `/api/play/my-completed` (`@RequestParam for_public_reference=false`; returns list of … | deployment-pending-verification |
| `/api/city-game/team-participation   (prefix row)` | PARTIAL | Prefix check `Core/CityParticipationScopedTransport.swift:50` (`authorize`, :44-104). Sub-routes reported individually (each has its own block … | NOT FOUND for the `/api/city-game/team-participation` prefix (greps above). Nearest family: `CTRL/ApiPlayTeamController.java:28` … | deployment-pending-verification |
| `/api/city-game/team-participation/command` | PARTIAL | `Core/CityParticipationCommandRecovery.swift:126`. POST, JSON body (`Content-Type: application/json`, `Accept: application/json`, `Authorization: … | Nearest: `CTRL/ApiPlayTeamController.java:34-38` POST `/api/team/command` `@RequestBody TeamEventCommand` … | deployment-pending-verification |
| `/api/city-game/team-participation/invite` | PARTIAL | `Core/CityParticipationInvitationReading.swift:55`. GET, query `regionId`, `code` (lowercase UUID), header `Authorization`, `Accept: … | Nearest: `CTRL/ApiPlayTeamController.java:96-107` POST `/api/team/info` (`@Anonymous` at :95; JSON body map `{teamId?, inviteCode?}`; returns `{team, … | deployment-pending-verification |
| `/api/city-game/team-participation/state` | PARTIAL | `Core/CityParticipationStateReading.swift:133`. GET, query `regionId`, `Authorization` header, `Accept: application/json`, timeout 20. Response … | Nearest: `CTRL/ApiPlayTeamController.java:235-241` POST `/api/team/my` (no params; returns `List<PlayTeam>` via `PlayTeamServiceImpl.java:321-324`); … | deployment-pending-verification |
| `/api/city-game/{}/request/{}` | PARTIAL | `Core/CityOriginalReceiptReading.swift:94`: path `api/city-game/\(domain)/request/\(requestID)` with `domain` in {`team-participation`, … | team-participation domain only, nearest: `CTRL/ApiPlayTeamController.java:41-44` POST `/api/team/command/query` (JSON `TeamEventCommand{requestId}`; … | deployment-pending-verification |
| `/api/city-value/visits   (prefix row, POST begin)` | MISSING | Route builder `Core/CityPlayerValueService.swift:64` (`case .begin`) inside `CityPlayerValueRoute.request` (:55-80), sent by … | NOT FOUND (greps above; `city_value\|CityValue\|visitId\|SERVICE_RATING` 0 hits). Unrelated nearest: `CTRL/ApiRoamController.java:267-268` POST … | deployment-pending-verification |
| `/api/city-value/visits/` | MISSING | `Core/CityPlayerValueService.swift:61` (`case .visit(let id)`: `path = "api/city-value/visits/" + id`). GET, no query, no body, `Authorization`, … | NOT FOUND (same greps). No GET by visit id exists in `ApiRoamController` or merchant controllers. | deployment-pending-verification |
| `/api/city-value/visits/feedback` | MISSING | `Core/CityPlayerValueService.swift:67`. POST, JSON (`Content-Type: application/json`, sorted keys), body keys: `visitId` plus either … | NOT FOUND (greps above). `feedback\|rating` appears only in unrelated controllers (ApiActivityController, ApiClubController, ApiCommentController, … | deployment-pending-verification |
| `/api/city-value/visits/services` | MISSING | `Core/CityPlayerValueService.swift:59`. GET, query-only: `regionId, boardId, seasonId, rulesReleaseId` (`CityPlayerValueScope.fields`) merged with … | NOT FOUND (greps above). Nearest unrelated listing: `CTRL/ApiCityNodeController.java:70-83` GET `/api/city/nodes` (no board binding) and `:99-107` … | deployment-pending-verification |
| `/api/city/nodes/complete` | ADAPTABLE | The listed path is the normalized approval key, not a literal URL: approval check `App/AppSession.swift:6346` (`path: "api/city/nodes/complete"`), … | `CTRL/ApiCityNodeController.java:167-170` POST `/api/city/nodes/{id}/complete` (`@PathVariable id`, unannotated params `Double lat, Double lng, … | deployment-pending-verification |
| `/api/city/nodes/favorite` | ADAPTABLE | Listed path is the normalized approval key (`App/AppSession.swift:6344`; normalization `App/AppCompositionRoot.swift:3720,3745-3754`). Real call: … | `CTRL/ApiCityNodeController.java:119-142` POST `/api/city/nodes/{id}/favorite` (`@PathVariable id`, no body); toggles … | deployment-pending-verification |
| `/api/city/walking/target` | PARTIAL | `Core/CityWalkingAuthorityReader.swift:36`. GET, query `poi_id=<positive int>` only (accepted by `CityWalkingReadRoute.accepts` :73-87), … | NOT FOUND for `/api/city/walking/target` (greps above; `ApiCityNodeController` mappings: `/nodes`, `/nodes/{id}`, `/nodes/merchant/{merchantId}`, … | deployment-pending-verification |
| `/api/npc/chat/delete` | ADAPTABLE | The literal `/api/npc/chat/delete` is NOT an HTTP call: it is only a label constant `Core/NPCChatAndSceneAISafetyAudit.swift:317` … | `CTRL/ApiAiNpcController.java:473-481` POST `/api/ai/npc/chat/data/delete` (class mapping `/api/ai/npc`, `:50`; `@RequestBody(required=false) … | deployment-pending-verification |
| `/api/official/v2/events  (prefix; real call = GET …` | ADAPTABLE | Core/OfficialOrganizer.swift:197 `request("api/official/v2/events/\(eventID)/publish-check", method:"GET")`, no query/body, headers Authorization + … | BE/ApiOfficialEventController.java:356-361 `@GetMapping("/v2/events/{id}/publish-check")` (class @RequestMapping("/api/official") :56), no … | deployment-pending-verification |
| `/api/onboarding/get` | MISSING | Core/NativeChannelOnboarding.swift:147-149 readSnapshot -> exchange() :156 (declared at :14 as `read`); POST JSON body {guild_kind:1\|3, … | NOT FOUND. Greps run on base checkout: `grep -rni onboarding --include=*.java` (only ApiComplianceController.java:42 scene "merchant_onboarding" and … | deployment-pending-verification |
| `/api/onboarding/submit` | MISSING | Core/NativeChannelOnboarding.swift:132 `exchange(submit, body:)` (path const :14); POST JSON … | NOT FOUND (same greps as onboarding/get; additionally `grep -rn "channel-platform" --include=*.java` empty). csv:613 NO-BACKEND. | deployment-pending-verification |
| `/api/play/advanced/time-window` | PARTIAL | Core/NativePlatformService.swift:31 (windowPath), call :64-75 `timeWindow(activityID:topicID:nodeID:)`: GET query activityId,nodeId,topicId, … | No such route: BE/ApiAdvancedPlayController.java mappings only :36 POST /start, :49 POST /action, :86 GET /receipt, :92 GET /state, :102 GET … | deployment-pending-verification |
| `/api/play/city-orientation/  (prefix only: request(path:) base for …` | PARTIAL | Core/CityOrientationTaskOriginalSource.swift:169 `baseURL.appendingPathComponent("api/play/city-orientation/" + path)`; not an endpoint itself. See … | NOT FOUND: `grep -rniE "city-orientation\|CITY_ORIENTATION" --include=*.java` hits only tests (TopicCreateOpenClubPoolTest.java:159,224,254). No … | deployment-pending-verification |
| `/api/play/city-orientation/answer` | PARTIAL | Core/CityOrientationTaskOriginalSource.swift:146-153 (submit): POST, Content-Type application/json, body CityOrientationTaskCommand (:10-15) … | BE/ApiPlayProgressController.java:118-126 `@PostMapping("/answer")` (class /api/play :18), params NOT @RequestBody (query/form): … | deployment-pending-verification |
| `/api/play/city-orientation/receipt` | PARTIAL | Core/CityOrientationTaskOriginalSource.swift:156-166 `original()`: GET query sessionId,nodeId,requestId(UUID) (exactly 3, route guard … | BE/ApiPlayProgressController.java:78-81 `@GetMapping("/action-receipt")` params activityId,topicId,nodeId,routeActionId -> … | deployment-pending-verification |
| `/api/play/egg/collect` | MISSING | Core/JourneyContentService.swift:46-52 `collect(topicID:egg:token:)`: POST multipart/form (AuthRequestBuilder.makeFormRequest via … | NOT FOUND for write: `grep -rniE "egg" --include=*.java` -> only reads: PlayPlayerQueryApplication.java:266-276 (achievements lists MemberCollectible … | deployment-pending-verification |
| `/api/play/route-action` | PARTIAL | App/PlayRouteMapView.swift:157 (approval path), call :164-239; URL built :271-286: GET query sessionId,memberId,actionId; Authorization+Accept; … | NOT FOUND by those keys. Nearest: BE/ApiPlayProgressController.java:78-81 GET /api/play/action-receipt (activityId,topicId,nodeId,routeActionId; … | deployment-pending-verification |
| `/api/progress/meter` | MISSING | Core/NativeChannelProgressService.swift:48-57 `meter()`: GET query channel_id,topic_id,activity_id,subject_type=MEMBER,subject_id (exact set enforced … | NOT FOUND: `grep -rn --include=*Controller.java -E "Mapping\(.*(api/progress\|/meter\|privacy\|/api/channel)"` empty; `grep -rn … | deployment-pending-verification |
| `/api/progress/requests  (prefix string only)` | MISSING | Core/NativeChannelProgressFinalForward.swift:108 builds `baseURL.appendingPathComponent("api/progress/requests") + "/"` as receipt-prefix matcher in … | NOT FOUND (greps as in /api/progress/meter). | deployment-pending-verification |
| `/api/progress/requests/  (prefix string only)` | MISSING | Core/NativeChannelProgressFinalForward.swift:100 `lease.paths.contains("api/progress/requests/" + command.requestId)` approval check; not a call by … | NOT FOUND. | deployment-pending-verification |
| `/api/progress/requests/{}` | MISSING | Core/NativeChannelProgressService.swift:68 `get("api/progress/requests/\(command.requestId)")`: GET, no query/body, receipt of privacy save (POST … | NOT FOUND (no /api/progress, /api/privacy routes: greps above). Closest idempotent-receipt pattern: TeamEventCommandService.query … | deployment-pending-verification |
| `/api/team/original-request` | PARTIAL | Core/NativeFriendTeamInviteService.swift:8 (const `receipt`); write :63-66 POST JSON raw envelope {requestId(lowercase UUID), action … | No such route (`grep -rn "original-request\|ORIGINAL_TEAM_REQUEST\|FRIEND_OFFER\|friend/team-invite\|friend-offer" --include=*.java` -> none … | deployment-pending-verification |

## Adaptation plan (ADAPTABLE rows)

Rules: never loosen existing tests; extend them. One worker per group.

### /api/city/nodes/complete
- Changes: None to path/method/encoding for the live `RoamService.completeNode` path. Only confirm: (a) keep multipart/form (do NOT switch to JSON; backend has no `@RequestBody`), (b) `poiId`/`id` decoding is already optional, (c) `needRedeem` is present on every success (backend sets it at :237 and :241); (d) the unused `ChallengePOIRequestBuilder` JSON body (`ChallengePOISubmission.swift:51-59`) must not be wired without switching to form encoding; (e) rename the approval-key label only if the audit wants a literal path.
- Swift files: `Core/RoamService.swift`, `Core/RoamExperienceMutationContracts.swift`, `Core/AuthRequestBuilder.swift`, `App/AppSession.swift`, `App/AppCompositionRoot.swift`, `Core/ChallengePOISubmission.swift`.
- Tests to extend: `Tests/AppUnitTests/RoamPOIActionTests.swift`, `Tests/CoreTests/RoamExperienceMutationTests.swift`, `Tests/CoreTests/ChallengePOISubmissionTests.swift`, `Tests/CoreTests/ChallengePOICoordinatorSubmitTests.swift`, `Tests/AppUnitTests/AssetPointsAndOrderCancellationSectionViewTests.swift`, `Tests/ContractChecks/test_business_runtime_wiring.py`.

### /api/city/nodes/favorite
- Changes: None for the live call (POST `/api/city/nodes/{id}/favorite`, empty body, read `data.favorited`). Optional: nothing else; do not add a body.
- Swift files: `Core/RoamService.swift`, `Core/RoamExperienceMutationContracts.swift`, `Core/AuthRequestBuilder.swift`, `App/AppSession.swift`, `App/AppCompositionRoot.swift`.
- Tests to extend: `Tests/AppUnitTests/RoamPOIActionTests.swift`, `Tests/CoreTests/RoamExperienceMutationTests.swift`, `Tests/AppUnitTests/AssetPointsAndOrderCancellationSectionViewTests.swift`, `Tests/ContractChecks/test_business_runtime_wiring.py`.

### /api/npc/chat/delete
- Changes: No change to the HTTP call (already POST JSON `{}` to `api/ai/npc/chat/data/delete`, reads `data.deleted`). Only rename the label/allowlist key `/api/npc/chat/delete` -> `/api/ai/npc/chat/data/delete` in the audit constant, `RegionalEndpointAllowlistAudit.Case.npcChatDelete` and the section-view rows, and update the matching test expectations. Backend accepts the empty `{}` body; adding `requestId` would only opt into receipt idempotency and is not required.
- Swift files: `Core/NPCChatAndSceneAISafetyAudit.swift` (:317), `Core/RegionalEndpointAllowlistAudit.swift` (:10), `App/RegionalEndpointAllowlistSectionView.swift` (:74,:144); live caller `Core/NPCChatLogDeletion.swift` (unchanged).
- Tests to extend: `Tests/CoreTests/NPCChatAndSceneAISafetyAuditTests.swift` (:20), `Tests/CoreTests/RegionalEndpointAllowlistAuditTests.swift` (:12,:162), `Tests/AppUnitTests/RegionalEndpointAllowlistSectionViewTests.swift` (:30), `Tests/CoreTests/NPCChatDataTests.swift`, `Tests/CoreTests/NPCChatDataLaunchRecoveryTests.swift`, `Tests/AppUnitTests/NPCChatDataViewTests.swift`, `Tests/CoreTests/Wave3HandoffVerificationRegistryTests.swift`.

### /api/official/v2/events  (prefix; real call = GET /api/official/v2/events/{id}/publish-check)
- Changes: 
- Swift files: Core/OfficialOrganizer.swift, App/AppCompositionRoot.swift (acceptsRead gate :3922)
- Tests to extend: Tests/CoreTests/OfficialOrganizerTests.swift, Tests/AppUnitTests/ReviewedOrientOfficialRouteTests.swift (Tests/ContractChecks/fixtures/backend_route_status.csv:607-608)

Worker groups:
1. **Roam POI actions** (`/api/city/nodes/complete`, `/api/city/nodes/favorite`): no call change; only assert (extend, don't weaken) that the multipart/form encoding and `{favorited}` / `needRedeem` shapes stay pinned in `RoamExperienceMutationTests`/`RoamPOIActionTests`.
2. **Audit labels** (`/api/npc/chat/delete` → `/api/ai/npc/chat/data/delete`): rename constant/case/rows, update the matching test expectations in the same commit.
3. **Official organizer** (`/api/official/v2/events`): none needed; real call already matches `ApiOfficialEventController.java:356`. Add a contract test pinning that path if absent.

## Backend tasks (MISSING / PARTIAL)

- `/api/city-game/` (PARTIAL): Add region-board `current` and bbox+cursor `points` read endpoints (board/season/rulesRelease/revision, participationStatus) or confirm iOS drops this feature.
- `/api/city-game/acquisition` (MISSING): Design+implement title acquisition (state, titles, quote/{id}, command QUOTE/CONFIRM, request/{id}) with quote hash, points and action-budget debit.
- `/api/city-game/acquisition/` (MISSING): Same task as `/api/city-game/acquisition`.
- `/api/city-game/action-budget` (MISSING): Implement team action-budget state/roll command/receipt (region+team+release scoped).
- `/api/city-game/action-budget/command` (MISSING): Add action-budget ROLL command with 200/202/400/409 receipt semantics.
- `/api/city-game/action-budget/request/{}` (MISSING): Add action-budget original-request receipt lookup (GET request/{id}) with COMPLETE/UNKNOWN states.
- `/api/city-game/action-budget/state` (MISSING): Add action-budget state read (regionId) with budgetVersion, units, roll history.
- `/api/city-game/arrival-evidence` (PARTIAL): Add region-scoped arrival-evidence state/merchant list/evidence/{id} reads, REJECT and displayCode-challenge command, or define a mapping from regionId/pointId to activityId/nodeId.
- `/api/city-game/arrival-evidence/` (PARTIAL): Same task as prefix row.
- `/api/city-game/merchant/operations` (PARTIAL): Add region-level merchant operations availability/intent/receipt (approvalHash, version, PAUSE_MERCHANT|RESTORE) or map to STATION_PAUSE/RESUME per active station.
- `/api/city-game/merchant/operations/availability` (MISSING): Add merchant operations availability read (regionId) returning version, approvalHash, relation.
- `/api/city-game/merchant/operations/intent` (PARTIAL): Add merchant-wide region intent endpoint or adapter that fans out to station pause/resume; add approvalHash/expectedVersion.
- `/api/city-game/merchant/operations/request/` (PARTIAL): Add GET merchant operations request/{id} receipt (no activityId needed) or have iOS persist activityId and map snapshot fields.
- `/api/city-game/neutral-tasks` (MISSING): Implement remote neutral task state/ACCEPT/SUBMIT/request-receipt (region+team+release scoped).
- `/api/city-game/neutral-tasks/` (MISSING): Same task as prefix row.
- `/api/city-game/onsite-tasks` (PARTIAL): Add region-scoped onsite task state/ACCEPT/SUBMIT/request/result endpoints bound to arrival evidenceId, or define mapping onto PLAYER_SUBMIT.
- `/api/city-game/onsite-tasks/` (PARTIAL): Same task as prefix row.
- `/api/city-game/player-rules` (MISSING): Add GET `/api/city-game/player-rules` returning `CITY_PLAYER_RULES_V1` bound to board/season/rulesRelease/hash (409 on drift, 404 unpublished, 403 on withdrawn), or drop the feature.
- `/api/city-game/state/snapshot  (and /api/city-game/state/deltas, next block)` (PARTIAL): Add region/board-scoped GET `/api/city-game/state/snapshot` with `scopeHash`, `sequence`, `cursor`, and 409/422 error codes (or accept a degraded non-ordered node read on iOS).
- `/api/city-game/state/deltas` (MISSING): Add GET `/api/city-game/state/deltas?cursor=` backed by a transactional event log, returning `CITY_ORDERED_RESET_REQUIRED` when the cursor is stale.
- `/api/city-game/task-history` (PARTIAL): Add region-scoped GET `/api/city-game/task-history[/instance/{id}[/request/{rid}]]` returning task instances, attempts and per-request receipts.
- `/api/city-game/team-participation   (prefix row)` (PARTIAL): Add `/api/city-game/team-participation/{state,invite,command,request/{id}}` implementing the frozen-binding lifecycle (CREATE/JOIN/LOCK/CONFIRM/EXIT/RESUME), or define an explicit mapping onto `/api/team/*`.
- `/api/city-game/team-participation/command` (PARTIAL): Add `/api/city-game/team-participation/command` accepting the frozen-binding command (kind/regionId/releaseId/contentHash/expectedVersion) with 200/400/409 receipt semantics.
- `/api/city-game/team-participation/invite` (PARTIAL): Add GET `/api/city-game/team-participation/invite?regionId&code` returning binding + teamId + version + memberCount only.
- `/api/city-game/team-participation/state` (PARTIAL): Add GET `/api/city-game/team-participation/state?regionId` returning `CityParticipationState` (binding, status, team, session).
- `/api/city-game/{}/request/{}` (PARTIAL): Add GET `/api/city-game/{domain}/request/{id}` returning `{requestId, requestStatus: COMPLETE|UNKNOWN}` with 200/400/409 vs 202 `OUTCOME_UNKNOWN` for the three domains.
- `/api/city-value/visits   (prefix row, POST begin)` (MISSING): Add `/api/city-value/visits` (begin), `/visits/{id}`, `/visits/services`, `/visits/feedback` with board-page binding, or retire the iOS value-visit flow.
- `/api/city-value/visits/` (MISSING): Add GET `/api/city-value/visits/{visitId}` returning the visit binding/state for the owning actor.
- `/api/city-value/visits/feedback` (MISSING): Add POST `/api/city-value/visits/feedback` (idempotent per visit; SERVICE_RATING/SKIP/EXIT).
- `/api/city-value/visits/services` (MISSING): Add GET `/api/city-value/visits/services` keyed by board/season/rules release and map page.
- `/api/city/walking/target` (PARTIAL): Add GET `/api/city/walking/target?poi_id` returning `{schemaVersion:1, kind:"cityNode", id, title, longitude, latitude, datum:"wgs84", region, authorityRevision:"city:<id>:<rev>", issuedAtMs, expiresAtMs}` (<=300s TTL), unwrapped.
- `/api/onboarding/get` (MISSING): Design and build guild/channel onboarding config + read endpoint (POST /api/onboarding/get returning the prompt snapshot) or drop the feature from iOS.
- `/api/onboarding/submit` (MISSING): Build onboarding answer submit with request_id idempotency plus admission-request receipt GET, or remove from iOS.
- `/api/play/advanced/time-window` (PARTIAL): Add GET /api/play/advanced/time-window deriving serverNow, nextOpenAt/nextCloseAt, windowVersion, timeZone, notificationProvider from node timeWindow config, with 409 TIME_WINDOW_OPENING_REQUIRED. (Alternative client-only: derive from /state playKit.timeWindow, but serverNow/windowVersion would be missing.)
- `/api/play/city-orientation/  (prefix only: request(path:) base for "answer" and "receipt")` (PARTIAL): See child rows.
- `/api/play/city-orientation/answer` (PARTIAL): Either add a /api/play/city-orientation/answer facade returning the V1 receipt (contract, payloadHash, revision, outcome, response) over executeBasicIntent, or re-map iOS to /api/play/answer and relax receipt validation.
- `/api/play/city-orientation/receipt` (PARTIAL): Add a receipt facade (sessionId,nodeId,requestId) returning the V1 receipt with outcome PENDING/APPLIED/FAILED, or adapt iOS to action-receipt (520 = pending).
- `/api/play/egg/collect` (MISSING): Add POST /api/play/egg/collect (eggId, content, topicId) inserting MemberCollectible TYPE_EGG idempotently, or remove egg collection from iOS.
- `/api/play/route-action` (PARTIAL): Add GET /api/play/route-action returning TopicRouteAction {sessionId,memberId,actionId,responseJson} for the caller's own session, or adapt iOS to action-receipt plus activity/topic/node scope.
- `/api/progress/meter` (MISSING): Build channel progress meter (+ privacy settings) service, or remove channel progress from iOS.
- `/api/progress/requests  (prefix string only)` (MISSING): See /api/progress/requests/{}.
- `/api/progress/requests/  (prefix string only)` (MISSING): See /api/progress/requests/{}.
- `/api/progress/requests/{}` (MISSING): Build /api/privacy/progress (GET/POST) with request_id receipts at /api/progress/requests/{id}, or remove from iOS.
- `/api/team/original-request` (PARTIAL): Extend TeamEventCommandService with FRIEND_OFFER/CONFIRM/DECLINE/REVOKE (and offer store + picker/landing/mine reads), or retire the friend team-invite feature in iOS.

## Detail blocks (evidence, file:line both sides)

Paths: `B` = hengyin baseline checkout root; `CTRL` = `chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api`; `SYS` = `chengyinhub-system/src/main/java/com/chengyinhub/business`. iOS paths are relative to the chengyin-app repo root.

### /api/city-game/
- iOS: Core/CityValueBoundedMapScopedTransport.swift:33 builds GET `api/city-game/{current|points}` (route enum :19-34, send :56-69; also Core/CityValueBoundedMapReading.swift:21,28,39). Query-string only (no body), keys sorted: current -> `regionId`; points -> regionId,boardId,seasonId,rulesReleaseId,revision + CityValueBoundedQuery.fields (south,west,north,east,datum WGS84|GCJ02,zoom 0-22,layers sorted subset MERCHANT/PLATFORM_VIRTUAL/POI, cursor) (Core/CityValueBoundedMapContracts.swift:18-37). Response CityValueBoundedEnvelope{code,data:CityValueBoundedPayload?,errorCode} (Contracts:109-115: contract,scope,status,regionId,board,participationStatus,pointsStatus,points[],complete,mapRead,watermark,nextCursor,page,pageLimitReached). Pagination: opaque `cursor`/`nextCursor`. Errors: HTTP 401 or envelope.code 401 -> unauthorized (Transport:65-66); 200-only decode elsewhere. Sub-routes: `current` (:25) and `points` (:28).
- Backend: No board/season/points route. Nearest: GET /api/city/nodes (chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api/ApiCityNodeController.java:70-71) params lat,lng,radius(default 3000,max 20000),keyword,categoryId,tag,cityRole; returns List<CityNodeVO> (:73-84), no pagination, no cursor, authenticated by anyRequest (SecurityConfig:166); POST /api/map/nearby (ApiMapController.java:52) lat/lng POI search. Region/board/season/rulesRelease/revision: NOT FOUND (grep `rulesReleaseId|boardId.*seasonId` ).
- Category: PARTIAL
- Equivalence note: Only the merchant-POI layer (circle around lat/lng) exists; iOS needs region-scoped, frozen-board, bbox, cursor-paged value points with participation status, which the backend (activity-scoped, no region/board/season concept) does not model.
- Backend task: Add region-board `current` and bbox+cursor `points` read endpoints (board/season/rulesRelease/revision, participationStatus) or confirm iOS drops this feature.
- Flag: deployment-pending-verification (production version UNVERIFIED)

### /api/city-game/acquisition
- iOS: Core/CityAcquisitionService.swift:79 is the route allowlist (CityAcquisitionRoute, prefix `api/city-game/acquisition`); real calls via `execute(path,query,body)` at :200-201 (method = body==nil ? GET : POST, JSON body, Authorization raw token). Sub-routes: GET `state?regionId=` (:131), GET `titles?regionId=` (:137), GET `quote/{serverUUID}` (:144, Envelope<QuoteData{contract,quote}>), POST `command` (:148, body CityAcquisitionCommand :61-67: QUOTE {requestId,kind,regionId,instanceId} or CONFIRM {requestId,kind,regionId,quoteId,quoteHash,confirmed:true}, <=2048 bytes, exact key sets :89), GET `request/{UUID}` (:150, Envelope<ReceiptData{requestId,requestStatus,contract,effectsStatus,quote,title}>). Errors: 401 -> APIError.unauthorized, 403 -> CityAcquisitionError.server(403,FORBIDDEN) (:205-209), body cap 524288. No pagination.
- Backend: NOT FOUND. Greps: `city-game`, `quoteHash|self.?pay|acquir|titleRetained|ownTitles`, `quote` in game session/play/team/merchant controllers. Closest generic piece: POST /api/game/session/command {G}:91 and GET /receipt :128 (no QUOTE/CONFIRM/title action in switch {S}:2311-2343).
- Category: MISSING
- Equivalence note: Self-funded point/action-cost title acquisition with quote hash and term policy has no backend counterpart; game sessions have no title ownership or quote concept.
- Backend task: Design+implement title acquisition (state, titles, quote/{id}, command QUOTE/CONFIRM, request/{id}) with quote hash, points and action-budget debit.
- Flag: deployment-pending-verification (production version UNVERIFIED)

### /api/city-game/acquisition/
- iOS: Core/CityAcquisitionService.swift:79 is the route allowlist (CityAcquisitionRoute, prefix `api/city-game/acquisition`); real calls via `execute(path,query,body)` at :200-201 (method = body==nil ? GET : POST, JSON body, Authorization raw token). Trailing-slash row is the sub-route concatenation in execute(): Core/CityAcquisitionService.swift:201 (`acquisition/` + path); sub-routes enumerated in the `/api/city-game/acquisition` row.
- Backend: NOT FOUND. Greps: `city-game`, `quoteHash|self.?pay|acquir|titleRetained|ownTitles`, `quote` in game session/play/team/merchant controllers. Closest generic piece: POST /api/game/session/command {G}:91 and GET /receipt :128 (no QUOTE/CONFIRM/title action in switch {S}:2311-2343).
- Category: MISSING
- Equivalence note: Same domain as the prefix row; no title/quote semantics in backend.
- Backend task: Same task as `/api/city-game/acquisition`.
- Flag: deployment-pending-verification (production version UNVERIFIED)

### /api/city-game/action-budget
- iOS: Reader/transport allowlist: Core/CityActionBudgetScopedTransport.swift:50 (prefix `api/city-game/action-budget`, routes /state, /request/{id}, /command, :52-84; command limited to <=4096 bytes, exact JSON, region must equal grant). Sub-routes reported in their own rows below (state, request/{id}, command).
- Backend: NOT FOUND. Greps: `action.?budget|actionPoint|rollNumber|dice` -> only advanced-play dice mini-game (AdvancedGameRuntimeServiceImpl.java:462-565; ApiAdvancedPlayController.java:28 `/api/play/advanced`, POST /action :49, GET /receipt :86, GET /state :92), which is per-play config, not a team action budget.
- Category: MISSING
- Equivalence note: Team action-budget ROLL with expectedVersion/budgetVersion has no backend equivalent; /api/play/advanced dice is a different per-play challenge.
- Backend task: Implement team action-budget state/roll command/receipt (region+team+release scoped).
- Flag: deployment-pending-verification (production version UNVERIFIED)

### /api/city-game/action-budget/command
- iOS: Core/CityActionBudgetRecovery.swift:131 POST, JSON body CityActionBudgetCommand (Core/CityActionBudgetContract.swift:82-84: kind="ROLL",requestId,regionId,teamId,contentHash,expectedTeamVersion,releaseId,expectedVersion; bytes() sorted keys <=4096 :85-91), headers Authorization, Content-Type, Accept; timeout 20s. Response decoded by CityActionBudgetReader.decodeReceipt (Core/CityActionBudgetReader.swift:60-78): envelope{code,errorCode,data{requestId,requestStatus COMPLETE|UNKNOWN,contract,scope="CITY",teamId,sessionId,binding,result}}; 202+OUTCOME_UNKNOWN -> pending; 200/400/409 complete; 401/403/404 -> unknown. Journaled for recovery (journal.begin/complete :140-146).
- Backend: NOT FOUND (see action-budget greps). Nearest generic: POST /api/game/session/command (chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api/ApiGameSessionController.java:91-92, expectedRevision+requestId idempotency, errors reasonCode GAME_*), no ROLL action (chengyinhub-system/src/main/java/com/chengyinhub/business/service/impl/GameSessionRuntimeServiceImpl.java:2311-2343).
- Category: MISSING
- Equivalence note: Idempotent command envelope pattern exists but no ROLL/budget action, and revision is activity-session scoped rather than team budgetVersion.
- Backend task: Add action-budget ROLL command with 200/202/400/409 receipt semantics.
- Flag: deployment-pending-verification (production version UNVERIFIED)

### /api/city-game/action-budget/request/{}
- iOS: Core/CityActionBudgetReader.swift:45 GET `api/city-game/action-budget/request/<lowercase requestId>` (receipt(), :41-49), no query, Accept json, timeout 20s; decodeReceipt :60-78 (see command row). Needs CityOriginalReceiptReadGrant.
- Backend: NOT FOUND for budget receipts. Nearest generic: GET /api/game/session/receipt?activityId&requestId&perspective (chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api/ApiGameSessionController.java:128-129) returning GameCommandReceiptView (GameCommandReceiptView.java:7-15).
- Category: MISSING
- Equivalence note: Receipt-by-requestId mechanism exists but is activity-scoped and holds game-command results; no action-budget receipt payload (budget version, roll, binding) exists.
- Backend task: Add action-budget original-request receipt lookup (GET request/{id}) with COMPLETE/UNKNOWN states.
- Flag: deployment-pending-verification (production version UNVERIFIED)

### /api/city-game/action-budget/state
- iOS: Core/CityActionBudgetReader.swift:27 GET `api/city-game/action-budget/state?regionId=`; StateEnvelope{code,errorCode,data:CityActionBudgetState} (:69-ish, validate(region:)), requires envelope.code==200 and empty errorCode, status==200, body<=1,048,576. No pagination.
- Backend: NOT FOUND. Nearest: GET /api/game/session/view?activityId&perspective (chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api/ApiGameSessionController.java:53-54) returns runtimeService.view safe projection, activity-scoped, no budget.
- Category: MISSING
- Equivalence note: View projection is per activity session with no region team action-budget fields.
- Backend task: Add action-budget state read (regionId) with budgetVersion, units, roll history.
- Flag: deployment-pending-verification (production version UNVERIFIED)

### /api/city-game/arrival-evidence
- iOS: Core/CityArrivalEvidenceService.swift:101 route allowlist CityArrivalEvidenceRoute (prefix `api/city-game/arrival-evidence`); real calls via execute(path,query,body) :232-233 (GET if no body else POST JSON, Authorization raw token, 401/403 -> unauthorized/forbidden, body<=524288). Sub-routes: GET `state?regionId=` (:158, player snapshot CityArrivalPlayerSnapshot), GET `merchant` (:176, CityArrivalMerchantSnapshot), POST `command` (:181, CityArrivalCommand :74-79 requestId,kind ISSUE|SUBMIT|CONFIRM|REJECT,expectedVersion,regionId,teamId,pointId,contentHash,challengeId,displayCode,reason,releaseId,expectedTeamVersion; <=4096 bytes, exact key sets by kind), GET `request/{id}` (:184, ReceiptData), GET `evidence/{serverUUID}` (:202, EvidenceData validated :222-228). Challenge+displayCode flow, merchant-attested evidence (assurance MERCHANT_ATTESTED, reviewer role MERCHANT_OWNER|MANAGER|CHECKIN).
- Backend: No /api/city-game route. Nearest: POST /api/game/session/command (chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api/ApiGameSessionController.java:91-92) actions ARRIVAL_ISSUE (chengyinhub-system/src/main/java/com/chengyinhub/business/service/impl/GameSessionRuntimeServiceImpl.java:293, issueArrival :331-348, player issues nonce {nonce,expiresAt,teamId,locationKey}) and ARRIVAL_CONFIRM (:294, confirmArrival :350-366, nonce verification, replay GAME_ARRIVAL_REPLAY, invalid GAME_ARRIVAL_INVALID), ARRIVAL_ATTEST/MANUAL_SIGN (:295,:299) ; perspective mapping ARRIVAL_ISSUE->PLAYER (chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api/ApiGameSessionController.java:210); read via GET /view. Errors AjaxResult.error + reasonCode (chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api/ApiGameSessionController.java:216-220). Auth: authenticated (SecurityConfig:166).
- Category: PARTIAL
- Equivalence note: Backend has issue-nonce/confirm arrival evidence but scoped to an activity session and HOST_NODE station (nodeId), not region/team/point/release with expectedVersion, displayCode challenge, reject path, evidence record fetch or merchant review list.
- Backend task: Add region-scoped arrival-evidence state/merchant list/evidence/{id} reads, REJECT and displayCode-challenge command, or define a mapping from regionId/pointId to activityId/nodeId.
- Flag: deployment-pending-verification (production version UNVERIFIED)

### /api/city-game/arrival-evidence/
- iOS: Core/CityArrivalEvidenceService.swift:233 (`arrival-evidence/` + path inside execute()); sub-routes enumerated in the prefix row (state, merchant, command, request/{id}, evidence/{id}).
- Backend: No /api/city-game route. Nearest: POST /api/game/session/command (chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api/ApiGameSessionController.java:91-92) actions ARRIVAL_ISSUE (chengyinhub-system/src/main/java/com/chengyinhub/business/service/impl/GameSessionRuntimeServiceImpl.java:293, issueArrival :331-348, player issues nonce {nonce,expiresAt,teamId,locationKey}) and ARRIVAL_CONFIRM (:294, confirmArrival :350-366, nonce verification, replay GAME_ARRIVAL_REPLAY, invalid GAME_ARRIVAL_INVALID), ARRIVAL_ATTEST/MANUAL_SIGN (:295,:299) ; perspective mapping ARRIVAL_ISSUE->PLAYER (chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api/ApiGameSessionController.java:210); read via GET /view. Errors AjaxResult.error + reasonCode (chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api/ApiGameSessionController.java:216-220). Auth: authenticated (SecurityConfig:166).
- Category: PARTIAL
- Equivalence note: Same domain as prefix row; command ISSUE/CONFIRM approximately map to ARRIVAL_ISSUE/ARRIVAL_CONFIRM, but SUBMIT/REJECT, evidence record and per-region state do not.
- Backend task: Same task as prefix row.
- Flag: deployment-pending-verification (production version UNVERIFIED)

### /api/city-game/merchant/operations
- iOS: Core/CityMerchantOperationsService.swift:80 route allowlist CityMerchantRoute (prefix `api/city-game/merchant/operations`, exactly three routes :74-102). Sub-routes reported individually: availability, intent, request/{id} (rows below).
- Backend: Nearest: station-level pause/resume in POST /api/game/session/command (chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api/ApiGameSessionController.java:91) actions STATION_PAUSE (chengyinhub-system/src/main/java/com/chengyinhub/business/service/impl/GameSessionRuntimeServiceImpl.java:2330, stationPause :2631-2648, payload reasonCode,reason,resumeEta,fallbackPlanCode,fallbackPlanVersion; errors GAME_STATE_CONFLICT/GAME_BAD_REQUEST) and STATION_RESUME (:2334, stationResume :2773+), CLUB_STATION_PAUSE/RESUME (:2331-2332); merchant perspective + VERIFY/PROJECT_MANAGE permission check (chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api/ApiGameSessionController.java:183-202); GET /api/game/session/merchant/entries (chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api/ApiGameSessionController.java:65-66) lists authorized stations.
- Category: PARTIAL
- Equivalence note: Backend pause/restore is per activity station run (nodeId) driven by an activity session; iOS pauses/restores the merchant within a region board with approvalHash and expectedVersion.
- Backend task: Add region-level merchant operations availability/intent/receipt (approvalHash, version, PAUSE_MERCHANT|RESTORE) or map to STATION_PAUSE/RESUME per active station.
- Flag: deployment-pending-verification (production version UNVERIFIED)

### /api/city-game/merchant/operations/availability
- iOS: Core/CityMerchantOperationsService.swift:140 GET `.../availability?regionId=` (availability() :139-143, query exactly regionId). Response Envelope{code,errorCode}+Success{data:CityMerchantSnapshot} (:48-62: merchantId,version,status,effectiveState,kind,requestId,originalRequestId,approvalHash(64 hex),availability AVAILABLE,runtimeApplied,relation{regionId,boardId,seasonId,rulesReleaseId,pointIds[]}).
- Backend: NOT FOUND for availability/approvalHash/relation. Nearest: GET /api/game/session/merchant/entries (chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api/ApiGameSessionController.java:65-66; runtimeService.merchantEntries chengyinhub-system/src/main/java/com/chengyinhub/business/service/impl/GameSessionRuntimeServiceImpl.java:2129-2145) returns activity/topic/station-count entries for the signed-in merchant; no params, no pagination (list).
- Category: MISSING
- Equivalence note: merchant/entries lists activity stations the merchant hosts; it carries no regional availability, version or approvalHash.
- Backend task: Add merchant operations availability read (regionId) returning version, approvalHash, relation.
- Flag: deployment-pending-verification (production version UNVERIFIED)

### /api/city-game/merchant/operations/intent
- iOS: Core/CityMerchantOperationsService.swift:146 POST JSON (submit() :144-147) via JSONSerialization sorted keys: requestId,expectedVersion(Int64),regionId,kind PAUSE_MERCHANT|RESTORE,reason(<=500),approvalHash; Content-Type application/json. Response CityMerchantSnapshot via execute (:152+); 401/403 mapped.
- Backend: Nearest: POST /api/game/session/command (chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api/ApiGameSessionController.java:91-92) action STATION_PAUSE/STATION_RESUME (chengyinhub-system/src/main/java/com/chengyinhub/business/service/impl/GameSessionRuntimeServiceImpl.java:2330,2334): body {activityId,nodeId,requestId,expectedRevision,action,payload{reasonCode,reason,resumeEta,...}}; errors reasonCode GAME_* (e.g. GAME_STATE_CONFLICT, GAME_FORBIDDEN_SCOPE chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api/ApiGameSessionController.java:197-199).
- Category: PARTIAL
- Equivalence note: Same business meaning (merchant pauses/resumes service with reason, idempotent requestId, optimistic version) but station/activity-scoped with required resumeEta and fallback plan, not region+approvalHash merchant-wide.
- Backend task: Add merchant-wide region intent endpoint or adapter that fans out to station pause/resume; add approvalHash/expectedVersion.
- Flag: deployment-pending-verification (production version UNVERIFIED)

### /api/city-game/merchant/operations/request/
- iOS: Core/CityMerchantOperationsService.swift:149 GET `.../request/<UUID>` (receipt(id:) :148-153), no query; requires value.requestId==id, originalRequestId==id, status != NONE else malformed. Returns CityMerchantSnapshot.
- Backend: Nearest: GET /api/game/session/receipt?activityId&requestId[&perspective] (chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api/ApiGameSessionController.java:128-129) -> GameCommandReceiptView (outcome,reasonCode,revision,replayed,result), activity-scoped, perspective derived/optional.
- Category: PARTIAL
- Equivalence note: Idempotent original-receipt lookup exists but is keyed by activityId+requestId and returns game-command receipt, not CityMerchantSnapshot; merchant has no activityId in this iOS call.
- Backend task: Add GET merchant operations request/{id} receipt (no activityId needed) or have iOS persist activityId and map snapshot fields.
- Flag: deployment-pending-verification (production version UNVERIFIED)

### /api/city-game/neutral-tasks
- iOS: Core/CityNeutralTaskService.swift:88 route allowlist CityNeutralTaskRoute (prefix `api/city-game/neutral-tasks`, :73-97). Real calls execute() :198-199 (GET/POST, JSON, Authorization raw). Sub-routes: GET `state?regionId=` (:145), POST `command` (:154, CityNeutralTaskCommand :63; keys requestId,regionId,kind ACCEPT|SUBMIT,releaseId,contentHash,teamId,expectedTeamVersion,taskId,expectedVersion (+instanceId,optionId on SUBMIT); <=4096 bytes), GET `request/{UUID}` (:159). Receipt CityNeutralTaskReceipt{requestId,succeeded,errorCode,task}; verifier NATIVE_OBJECTIVE_QA_PICK_V1. Errors 401->unauthorized, 403->CityNeutralTaskError.server(403,FORBIDDEN), body<=262144.
- Backend: NOT FOUND. Greps: `NEUTRAL|REMOTE_NEUTRAL|onsite.?task`, `city-game`, task controllers ApiPlay*/ApiOrient*. Closest: PLAYER_CHOICE/PLAYER_SUBMIT in game session command (chengyinhub-system/src/main/java/com/chengyinhub/business/service/impl/GameSessionRuntimeServiceImpl.java:2335-2336; playerSubmit :2921+ requires requireArrived station, taskCode payload).
- Category: MISSING
- Equivalence note: Remote neutral (no on-site) team tasks with ACCEPT/SUBMIT optionId QA pick have no backend equivalent; game-session PLAYER_SUBMIT requires station arrival and is activity scoped.
- Backend task: Implement remote neutral task state/ACCEPT/SUBMIT/request-receipt (region+team+release scoped).
- Flag: deployment-pending-verification (production version UNVERIFIED)

### /api/city-game/neutral-tasks/
- iOS: Core/CityNeutralTaskService.swift:199 (`neutral-tasks/` + path inside execute()); sub-routes enumerated in prefix row (state, command, request/{id}).
- Backend: NOT FOUND. Greps: `NEUTRAL|REMOTE_NEUTRAL|onsite.?task`, `city-game`, task controllers ApiPlay*/ApiOrient*. Closest: PLAYER_CHOICE/PLAYER_SUBMIT in game session command (chengyinhub-system/src/main/java/com/chengyinhub/business/service/impl/GameSessionRuntimeServiceImpl.java:2335-2336; playerSubmit :2921+ requires requireArrived station, taskCode payload).
- Category: MISSING
- Equivalence note: Same domain as prefix row.
- Backend task: Same task as prefix row.
- Flag: deployment-pending-verification (production version UNVERIFIED)

### /api/city-game/onsite-tasks
- iOS: Core/CityOnsiteTaskService.swift:94 route allowlist CityOnsiteTaskRoute (prefix `api/city-game/onsite-tasks`, :78-106). Real calls execute() :250-251 (GET/POST, JSON, Authorization raw; permitsStoredRejection for command/request). Sub-routes: GET `state?regionId=` (:150), POST `command` (:158, CityOnsiteTaskCommand :75; keys requestId,regionId,kind ACCEPT|SUBMIT,releaseId,contentHash,teamId,expectedTeamVersion,taskId,evidenceId,expectedVersion (+instanceId,optionId on SUBMIT); <=4096 bytes), GET `request/{UUID}` (:167), GET `result/{serverUUID}` (:187). Receipt CityOnsiteTaskReceipt{requestId,succeeded,errorCode,result}. Errors: 401->APIError.unauthorized, 403->CityOnsiteTaskError.server(403,errorCode) (:241-247); body<=1,048,576.
- Backend: Nearest: POST /api/game/session/command (chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api/ApiGameSessionController.java:91-92) PLAYER_SUBMIT (chengyinhub-system/src/main/java/com/chengyinhub/business/service/impl/GameSessionRuntimeServiceImpl.java:2336, playerSubmit :2921-2935: requirePlayer, requirePlayableStation, requireArrived, payload taskCode), PLAYER_CHOICE (:2335), VERIFY_SUBMISSION (:2339, merchant); state via GET /view (chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api/ApiGameSessionController.java:53-54); receipt GET /receipt (:128). Errors reasonCode GAME_*.
- Category: PARTIAL
- Equivalence note: Backend supports on-site station task submission after arrival with team, idempotent requestId and merchant verification, but within an activity session/nodeId; iOS expects region/team/release/evidence-bound ACCEPT/SUBMIT with optionId, task result record and per-version state.
- Backend task: Add region-scoped onsite task state/ACCEPT/SUBMIT/request/result endpoints bound to arrival evidenceId, or define mapping onto PLAYER_SUBMIT.
- Flag: deployment-pending-verification (production version UNVERIFIED)

### /api/city-game/onsite-tasks/
- iOS: Core/CityOnsiteTaskService.swift:251 (`onsite-tasks/` + path inside execute()); sub-routes enumerated in prefix row (state, command, request/{id}, result/{id}).
- Backend: Nearest: POST /api/game/session/command (chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api/ApiGameSessionController.java:91-92) PLAYER_SUBMIT (chengyinhub-system/src/main/java/com/chengyinhub/business/service/impl/GameSessionRuntimeServiceImpl.java:2336, playerSubmit :2921-2935: requirePlayer, requirePlayableStation, requireArrived, payload taskCode), PLAYER_CHOICE (:2335), VERIFY_SUBMISSION (:2339, merchant); state via GET /view (chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api/ApiGameSessionController.java:53-54); receipt GET /receipt (:128). Errors reasonCode GAME_*.
- Category: PARTIAL
- Equivalence note: Same domain as prefix row.
- Backend task: Same task as prefix row.
- Flag: deployment-pending-verification (production version UNVERIFIED)

### /api/city-game/player-rules
- iOS | `Core/CityPlayerRulesClient.swift:43` builds URL (`CityPlayerRulesRoute.request`, :41-49). GET, query-only, no body, `Authorization: <token>` header, `Accept: application/json`. Query keys (all required, sorted): `gameId, regionId, boardId, seasonId, rulesReleaseId, rulesHash, revision, membership` (+ `participationId, membershipVersion` if membership==JOINED), taken from `CityReadSnapshot.board` (:30-37). Response: `Envelope{code:Int, errorCode:String?, data:CityPlayerRulesSnapshot?}` (:97); `CityPlayerRulesSnapshot{contract="CITY_PLAYER_RULES_V1", scope, status, board, releaseId, sections[], eligibility, grantsParticipation, grantsAction}` (`Core/CityPlayerRulesContracts.swift:127-133`). Errors: HTTP/envelope 401 -> unauthorized, 403 -> accessWithdrawn, 409 -> changed, 404 -> notPublished, else `.server(status, errorCode)` (:104-114). No pagination; 65_536 byte cap.
- Backend | NOT FOUND (greps above; no controller exposes board/season/rulesRelease/rulesHash). Closest unrelated: topic-level `journeyRules` embedded in topic info (`ApiTopicController.java:1948`, `JourneyInitialState.publicRules`) - activity/topic content, not a region-board frozen rules release.
- Category | MISSING
- Equivalence note | iOS reads a region/board/season-frozen, hash-bound player rules snapshot with membership eligibility; backend has no region/board/season model at all (`/api/game/session/*` is activity-scoped, `ApiGameSessionController.java:53-62`).
- Flag | deployment-pending-verification
- Backend task | Add GET `/api/city-game/player-rules` returning `CITY_PLAYER_RULES_V1` bound to board/season/rulesRelease/hash (409 on drift, 404 unpublished, 403 on withdrawn), or drop the feature.

### /api/city-game/state/snapshot  (and /api/city-game/state/deltas, next block)
- iOS | `Core/CityOrderedMapScopedTransport.swift:49` (validate) and request build `CityOrderedMapRequest.make` at `Core/CityOrderedMapScopedTransport.swift:69-81` (URL at :77) (path chosen `cursor == nil ? "api/city-game/state/snapshot" : "api/city-game/state/deltas"`); caller `Core/CityOrderedMapReader.swift:59`. GET, query-only, no body. Snapshot query keys (exact set enforced, :53-58): `regionId, boardId, seasonId, rulesReleaseId, revision, south, west, north, east, datum, zoom, layers (comma list), limit, sync=TRANSACTIONAL_EVENTS_V1`. Response `Envelope{code, errorCode, data: CityOrderedMapReply}` (`Core/CityOrderedMapReader.swift:18`); `CityOrderedMapReply{contract, scope, mode, kind, streamId, scopeHash, cursor, sequence, boardVersion, capturedAtMillis, validUntilMillis, grantsAction, grantsNavigation, snapshot: CityCurrentSnapshot?, versions?, afterSequence?}` (`Core/CityOrderedMapContract.swift:4-10`). Errors (`CityOrderedMapReader.swift:63-70`): 401; 409+`CITY_SNAPSHOT_CHANGED`; 409+`CITY_ORDERED_RESET_REQUIRED`; 422+`CITY_QUERY_TOO_BROAD`; else unavailable. 256 KiB cap. Pagination: cursor format `<uuid>.<seq>` (`CityOrderedMapScopedTransport.swift:63-68`).
- Backend | Nearest: `CTRL/ApiCityNodeController.java:70-83` GET `/api/city/nodes` (params `lat,lng,radius,keyword,categoryId,tag,cityRole`; bbox coarse filter; returns `AjaxResult.success(List<CityNodeVO>)`; no pagination, no version/cursor/board). Also `CTRL/ApiRoamController.java:122` GET `/api/roam/pois`, `:491` GET `/tiles`, `:500` GET `/tiles/page` (roam-session tiles). Auth: authenticated (`SecurityConfig.java:166`).
- Category | PARTIAL
- Equivalence note | Backend can return nearby merchant POIs by bbox/radius, but has no board/season/rulesRelease scope, no revision/stream/sequence, no layers, no `sync` mode and no snapshot-changed/reset errors, so ordered-map semantics are absent.
- Flag | deployment-pending-verification
- Backend task | Add region/board-scoped GET `/api/city-game/state/snapshot` with `scopeHash`, `sequence`, `cursor`, and 409/422 error codes (or accept a degraded non-ordered node read on iOS).

### /api/city-game/state/deltas
- iOS | Same file/line as snapshot: `Core/CityOrderedMapScopedTransport.swift:49`; used when `cursor != nil` (`CityOrderedMapReader.swift:59`). GET; same query keys as snapshot plus required `cursor` (`<lowercase-uuid>.<int64>`). Response/error handling identical to snapshot; `afterSequence`, `versions` fields used for delta application.
- Backend | NOT FOUND (greps above; `cursor` grep over controllers finds no state-delta stream; no `/api/city/**` or `/api/roam/**` mapping lists event deltas - checked mapping lists of ApiCityNodeController, ApiRoamController).
- Category | MISSING
- Equivalence note | No server-side ordered event stream/sequence exists to produce deltas after a cursor.
- Flag | deployment-pending-verification
- Backend task | Add GET `/api/city-game/state/deltas?cursor=` backed by a transactional event log, returning `CITY_ORDERED_RESET_REQUIRED` when the cursor is stale.

### /api/city-game/task-history
- iOS | `Core/CityTaskHistoryService.swift:68` is the route-prefix check in `CityTaskHistoryRoute`; the real request is built in `execute` at `CityTaskHistoryService.swift:172-182` (URL at :173). GET only, query `regionId` always, plus `beforeInstanceId` (UUID) for paging. Sub-routes (all GET, `Authorization` header): `/api/city-game/task-history?regionId&beforeInstanceId?` -> `CityTaskHistoryPage{contract, scope, regionId, readAt, currentQualification, memberId, readOnly, pageSize==20, items:[CityTaskHistoryItem], nextBeforeInstanceId?}` (`CityTaskHistoryService.swift:44-50`); `/api/city-game/task-history/instance/{uuid}?regionId` -> `CityTaskHistoryDetail{instance, attempts[], result: CityOnsiteTaskResult?}` (:51-58); `/api/city-game/task-history/instance/{uuid}/request/{requestId}?regionId` -> `{requestId, requestStatus: COMPLETE|UNKNOWN, result?}` with code==HTTP status, 202 for UNKNOWN (:~127-134). Envelope `{code, errorCode, data}`; 401 -> unauthorized, 403 -> `.server(403,"FORBIDDEN")`; 262144 byte cap. Pagination: keyset cursor `beforeInstanceId`, fixed page 20.
- Backend | Nearest: `CTRL/ApiPlayProgressController.java:274` POST `/api/play/my-completed` (`@RequestParam for_public_reference=false`; returns list of completed activities via `playHistoryQueryApplication.myCompleted`, no paging); `CTRL/ApiRoamPassportController.java:19` GET `/api/roam/passport/history?before&limit` (roam sessions keyset page via `before`/`limit`; `:23` GET `/record?sessionId`); `CTRL/ApiOrientSessionController.java:77` GET `/api/play/orient/session/receipt`. Auth: authenticated.
- Category | PARTIAL
- Equivalence note | Backend has member-scoped completed-activity and roam-session history with keyset paging, but no per-task-instance history with attempts, accept/attempt request receipts, or region scoping.
- Flag | deployment-pending-verification
- Backend task | Add region-scoped GET `/api/city-game/task-history[/instance/{id}[/request/{rid}]]` returning task instances, attempts and per-request receipts.

### /api/city-game/team-participation   (prefix row)
- iOS | Prefix check `Core/CityParticipationScopedTransport.swift:50` (`authorize`, :44-104). Sub-routes reported individually (each has its own block below): GET `/state?regionId`, GET `/invite?regionId&code`, GET `/request/{id}` (no query; goes through `/api/city-game/team-participation/request/<id>`, same reader as the `{}/request/{}` row), POST `/command` (JSON, <=4096 bytes, `Content-Type: application/json`, no query). Anything else -> `APIError.notConfigured`.
- Backend | NOT FOUND for the `/api/city-game/team-participation` prefix (greps above). Nearest family: `CTRL/ApiPlayTeamController.java:28` `@RequestMapping("/api/team")` (POST `/command` :34, POST `/command/query` :41, POST `/command/cancel` :46, POST `/create` :62, POST `/info` :96 (`@Anonymous` :95), POST `/join` :109, POST `/my` :235) and game-session action `TEAM_EXIT` (`SYS/service/impl/GameSessionRuntimeServiceImpl.java:289`).
- Category | PARTIAL
- Equivalence note | Backend teams are invite-code teams owned by an owner (`ownerType/ownerId`, activity-paid-registration gated, `SYS/service/impl/PlayTeamServiceImpl.java:190-192`), not region/board/release-frozen city teams with CREATE/JOIN/LOCK/CONFIRM/EXIT/RESUME lifecycle and per-member confirmation.
- Flag | deployment-pending-verification
- Backend task | Add `/api/city-game/team-participation/{state,invite,command,request/{id}}` implementing the frozen-binding lifecycle (CREATE/JOIN/LOCK/CONFIRM/EXIT/RESUME), or define an explicit mapping onto `/api/team/*`.

### /api/city-game/team-participation/command
- iOS | `Core/CityParticipationCommandRecovery.swift:126`. POST, JSON body (`Content-Type: application/json`, `Accept: application/json`, `Authorization: <token>`, timeout 20, no retry, durable journal). Body = `CityParticipationCommand` (`Core/CityParticipationCommandContract.swift:7-16`, sorted keys, <=4096 B): `kind (CREATE|JOIN|LOCK|CONFIRM|EXIT|RESUME), requestId, regionId, releaseId:Int64, contentHash(64 hex), expectedVersion:Int64, teamId?(uuid), inviteCode?(uuid, JOIN only)`. Response `Response{code, errorCode?, data:Receipt{requestId, requestStatus, kind?}}` (`CityParticipationCommandRecovery.swift:168-171`); accepted only if `code==HTTP status`, status in {200,400,409}, `requestStatus=="COMPLETE"`, requestId echo. Unknown outcomes are never retried; recheck via the receipt route.
- Backend | Nearest: `CTRL/ApiPlayTeamController.java:34-38` POST `/api/team/command` `@RequestBody TeamEventCommand` (`SYS/domain/dto/TeamEventCommand.java:5-29`: `requestId, action, targetId, memberId, joinMode, approved, inviteCode, message, reason...`); service `SYS/service/impl/TeamEventCommandService.java:55` `execute`, action switch `:181-196` supports only `join|apply|quit|kick|disband|join-mode|withdraw|handle` (no create/lock/confirm/resume); requestId must match `[a-f0-9]{32}` (`TeamEventCommandService.java:146`); returns raw map via `AjaxResult.success` (stored `result_json` or `{requestId,state:"UNKNOWN"}`, :131-142). Game-session alternative: POST `/api/game/session/command` (`ApiGameSessionController.java:91-92`, JSON `GameSessionCommand{activityId,nodeId,requestId,expectedRevision,action,authorityEpoch,payload}`) with action `TEAM_EXIT` (`GameSessionRuntimeServiceImpl.java:289`); errors `AjaxResult.error(msg,{reasonCode:GAME_*})`. Auth: authenticated; rate-limit 120/10s per member (`ApiGameSessionController.java:90`).
- Category | PARTIAL
- Equivalence note | Idempotent team command with a requestId receipt exists (join/quit), but lacks region/release/contentHash/expectedVersion binding, CREATE/LOCK/CONFIRM/RESUME actions and the 200/400/409 `COMPLETE` receipt contract; game-session `TEAM_EXIT` is activity-scoped.
- Flag | deployment-pending-verification
- Backend task | Add `/api/city-game/team-participation/command` accepting the frozen-binding command (kind/regionId/releaseId/contentHash/expectedVersion) with 200/400/409 receipt semantics.

### /api/city-game/team-participation/invite
- iOS | `Core/CityParticipationInvitationReading.swift:55`. GET, query `regionId`, `code` (lowercase UUID), header `Authorization`, `Accept: application/json`, timeout 20. Response `Envelope{code, errorCode?, data:CityParticipationInvitation{binding: CityParticipationState.Binding, teamId, version:Int64, memberCount:Int}}` (:6-11, :88); requires HTTP 200 and `code==200`; validates rules (`mode=="CITY_TEAM"`, `joinPolicy=="INVITE_CODE"`, etc.). Anything else -> `.unverified`. 1 MiB cap.
- Backend | Nearest: `CTRL/ApiPlayTeamController.java:96-107` POST `/api/team/info` (`@Anonymous` at :95; JSON body map `{teamId?, inviteCode?}`; returns `{team, members:[{memberId,role,memberName,memberAvatar}], joined, leader}` from `SYS/service/impl/PlayTeamServiceImpl.java:142-173`; invalid code -> `AjaxResult.error("邀请已失效")` with `errorCode` from `TeamRejection` via `fail()` :`ApiPlayTeamController.java:244-250`).
- Category | PARTIAL
- Equivalence note | Backend can resolve an invite code to a team preview, but via POST/JSON, without region/release/revision/contentHash binding, team version, or frozen rules, and it exposes member names rather than only a count.
- Flag | deployment-pending-verification
- Backend task | Add GET `/api/city-game/team-participation/invite?regionId&code` returning binding + teamId + version + memberCount only.

### /api/city-game/team-participation/state
- iOS | `Core/CityParticipationStateReading.swift:133`. GET, query `regionId`, `Authorization` header, `Accept: application/json`, timeout 20. Response `Envelope{data: CityParticipationState}` after `Header{code, errorCode?}` check (:170-171); `CityParticipationState{contract, scope, binding, status, writeApproved, pointsStatus, taskExecutionStatus, actionBudgetStatus, team: Team?}` (`:38-47`); needs HTTP 200 + code 200; non-200 -> `.unavailable(status:)`. 1 MiB cap.
- Backend | Nearest: `CTRL/ApiPlayTeamController.java:235-241` POST `/api/team/my` (no params; returns `List<PlayTeam>` via `PlayTeamServiceImpl.java:321-324`); `CTRL/ApiGameSessionController.java:53-62` GET `/api/game/session/view?activityId&perspective` (activity-scoped safe projection, perspective PLAYER/MERCHANT/CLUB).
- Category | PARTIAL
- Equivalence note | Backend returns the caller's teams / an activity session view, but not a region-scoped participation state with frozen binding and `status/writeApproved/pointsStatus/...` fields.
- Flag | deployment-pending-verification
- Backend task | Add GET `/api/city-game/team-participation/state?regionId` returning `CityParticipationState` (binding, status, team, session).

### /api/city-game/{}/request/{}
- iOS | `Core/CityOriginalReceiptReading.swift:94`: path `api/city-game/\(domain)/request/\(requestID)` with `domain` in {`team-participation`, `action-budget`, `acquisition`} (:7-11). GET, no query/body, `Authorization`, `Accept: application/json`, timeout 20. Response `Envelope{code, errorCode?, data:Receipt{requestId, requestStatus}}` (:123-129). Mapping (:115-120): HTTP 202 + code 202 + `errorCode=="OUTCOME_UNKNOWN"` + `requestStatus=="UNKNOWN"` -> unknown; `requestStatus=="COMPLETE"` with (200/200) or (400|409 with code==status) -> complete; 401/403/404 -> `.unavailable(status)`. requestID regex `[A-Za-z0-9][A-Za-z0-9_-]{0,95}`.
- Backend | team-participation domain only, nearest: `CTRL/ApiPlayTeamController.java:41-44` POST `/api/team/command/query` (JSON `TeamEventCommand{requestId}`; `TeamEventCommandService.java:46-53` returns stored `result_json` or `{requestId, state:"UNKNOWN"}` - key is `state`, not `requestStatus`; requestId must be `[a-f0-9]{32}` :146). Game-session: `CTRL/ApiGameSessionController.java:128-134` GET `/api/game/session/receipt?activityId&requestId&perspective?` (`GameCommandReceiptView`, `outcome`, `reasonCode`). `/api/play/check/receipt` (`ApiPlayCheckController.java:145`), `/api/play/orient/session/receipt` (`ApiOrientSessionController.java:77`). action-budget / acquisition domains: NOT FOUND (`action-budget|acquisition` greps over controllers return no mapping).
- Category | PARTIAL
- Equivalence note | Request-id receipt lookup exists for team commands and game-session commands, but via POST/JSON or activity-scoped GET with different status vocabulary and id format; no action-budget/acquisition receipts and no 202 OUTCOME_UNKNOWN contract.
- Flag | deployment-pending-verification
- Backend task | Add GET `/api/city-game/{domain}/request/{id}` returning `{requestId, requestStatus: COMPLETE|UNKNOWN}` with 200/400/409 vs 202 `OUTCOME_UNKNOWN` for the three domains.

### /api/city-value/visits   (prefix row, POST begin)
- iOS | Route builder `Core/CityPlayerValueService.swift:64` (`case .begin`) inside `CityPlayerValueRoute.request` (:55-80), sent by `CityPlayerValueService.send` (:148-175) from `Core/CityPlayerValueController.swift:59`. Sub-routes: POST `/api/city-value/visits` (begin; JSON via `JSONSerialization` sorted keys, `Content-Type: application/json`, <=4096 B, body keys `requestId, page{scope+map-page fields}, pointId, poiId:Int64`; decoded as `CityPlayerValueBinding`), GET `/api/city-value/visits/{visitId}` (:61; no query), GET `/api/city-value/visits/services` (:59; query = scope fields `regionId, boardId, seasonId, rulesReleaseId` + map-page fields; decoded `CityPlayerValueServices`), POST `/api/city-value/visits/feedback` (:67; body `visitId, kind(SERVICE_RATING|SKIP|EXIT), rating | reasonCode`; decoded `CityPlayerValueBinding`). Envelope header `{code, errorCode?}` (:176): 401 -> unauthorized, 403 -> noPermission, else non-200 -> `.rejected(errorCode ?? "UNAVAILABLE")`; 2 MiB cap.
- Backend | NOT FOUND (greps above; `city_value|CityValue|visitId|SERVICE_RATING` 0 hits). Unrelated nearest: `CTRL/ApiRoamController.java:267-268` POST `/api/roam/shop/visit` (form params `sessionId, sourceType, sourceId, lat, lng`; credits a shop visit into an open roam session, GPS-validated, `locationConsent.requireCurrentAgreement`).
- Category | MISSING
- Equivalence note | `shop/visit` is roam-session XP crediting by coordinates, not a board-bound, requestId-idempotent value-visit binding with services list and SKIP/EXIT/rating feedback.
- Flag | deployment-pending-verification
- Backend task | Add `/api/city-value/visits` (begin), `/visits/{id}`, `/visits/services`, `/visits/feedback` with board-page binding, or retire the iOS value-visit flow.

### /api/city-value/visits/
- iOS | `Core/CityPlayerValueService.swift:61` (`case .visit(let id)`: `path = "api/city-value/visits/" + id`). GET, no query, no body, `Authorization`, `Accept`; id passes `CityReadRoute.validID` and must not be `services`/`feedback`. Response decoded by the shared envelope path as `CityPlayerValueBinding` (`Core/CityPlayerValueController.swift:94` shows the type used for feedback; the visit read uses the same `send` at `CityPlayerValueService.swift:148`). Errors as in the prefix row.
- Backend | NOT FOUND (same greps). No GET by visit id exists in `ApiRoamController` or merchant controllers.
- Category | MISSING
- Equivalence note | No persisted "value visit" entity is exposed by the backend.
- Flag | deployment-pending-verification
- Backend task | Add GET `/api/city-value/visits/{visitId}` returning the visit binding/state for the owning actor.

### /api/city-value/visits/feedback
- iOS | `Core/CityPlayerValueService.swift:67`. POST, JSON (`Content-Type: application/json`, sorted keys), body keys: `visitId` plus either `kind=SERVICE_RATING, rating:Int` or `kind=SKIP|EXIT, reasonCode:String` (parser `:97-105`); response `CityPlayerValueBinding` (`CityPlayerValueController.swift:94`). Errors as prefix row.
- Backend | NOT FOUND (greps above). `feedback|rating` appears only in unrelated controllers (ApiActivityController, ApiClubController, ApiCommentController, ApiCoopController, ApiRegistrationController, ApiTemplateController, ...); `CityNodeVO` has `averageRating/ratingCount` read-only (`SYS/domain/vo/CityNodeVO.java:10-11`), no feedback write route.
- Category | MISSING
- Equivalence note | No visit-bound service rating/skip/exit feedback write exists.
- Flag | deployment-pending-verification
- Backend task | Add POST `/api/city-value/visits/feedback` (idempotent per visit; SERVICE_RATING/SKIP/EXIT).

### /api/city-value/visits/services
- iOS | `Core/CityPlayerValueService.swift:59`. GET, query-only: `regionId, boardId, seasonId, rulesReleaseId` (`CityPlayerValueScope.fields`) merged with map-page fields (`CityPlayerValueMapPage.fields`, exact-match enforced :95-98); response `CityPlayerValueServices` (`Core/CityPlayerValueController.swift:35, :66`). Errors as prefix row.
- Backend | NOT FOUND (greps above). Nearest unrelated listing: `CTRL/ApiCityNodeController.java:70-83` GET `/api/city/nodes` (no board binding) and `:99-107` GET `/api/city/nodes/merchant/{merchantId}`.
- Category | MISSING
- Equivalence note | Backend lists nearby merchant nodes, not the services available for a board-bound map page.
- Flag | deployment-pending-verification
- Backend task | Add GET `/api/city-value/visits/services` keyed by board/season/rules release and map page.

### /api/city/nodes/complete
- iOS | The listed path is the normalized approval key, not a literal URL: approval check `App/AppSession.swift:6346` (`path: "api/city/nodes/complete"`), key normalization `App/AppCompositionRoot.swift:3720-3721,3745-3754` (maps `api/city/nodes/{digits}/complete` -> `api/city/nodes/complete`). Real call: `App/AppSession.swift:6359` `service.completeNode(poiID:fix:token:)` -> `Core/RoamService.swift:65-70` -> `writeMutation` (:79-96) -> `RoamExperienceMutation.completeNode` (`Core/RoamExperienceMutationContracts.swift:15,29,72-74,85-91`): POST `api/city/nodes/{poiID}/complete`, multipart/form-data built by `AuthRequestBuilder.makeFormRequest` (`Core/AuthRequestBuilder.swift:22-44`, `Authorization: <token>`), fields `lat, lng` (GCJ-02 only, else invalidRequest), `answer, photoUrl, code`. Response: envelope `RoamStatusEnvelope{code, msg?}` (`RoamService.swift:151`); 401 -> unauthorized, non-200 code -> `RoamActionFailure.rejected(msg)` or `APIError.businessCode`; success data `RoamNodeCompletion{needRedeem (required Bool), alreadyClaimed, poiId?, id?}` (`RoamService.swift:188-198`). No pagination. A second gated, unused stub `Core/ChallengePOISubmission.swift:59` builds JSON-style body for the same path but its default writer returns `.unavailable` (:36).
- Backend | `CTRL/ApiCityNodeController.java:167-170` POST `/api/city/nodes/{id}/complete` (`@PathVariable id`, unannotated params `Double lat, Double lng, String answer, String photoUrl, String code` -> bound from query/form/multipart, NOT JSON body). Auth: authenticated (`SecurityConfig.java:166`; `uid()` returns 0 -> `error("请先登录")` :66-68,173). Response `AjaxResult.success(data)` with `couponId, needRedeem, alreadyClaimed (on repeat; msg "你已完成过该据点"), poiId, completed, badgeCode, badgeName` (`:233-244, :248-262`). Errors: `AjaxResult.error(msg)` code 500 e.g. "缺少定位", "离据点太远,请到店后再完成" (:182-185), "答案不正确" (:193), "请扫描本店的到店打卡码" (:213). Idempotent per member+node (`insertRewardLogIgnore`, :233). No pagination, no `reasonCode`.
- Category | ADAPTABLE
- Equivalence note | Same business meaning (complete a merchant POI node with a GPS fix, answer/photo/code, once per member per node); the iOS call already targets the backend path/method/encoding (the row is only an approval-key label, not a missing route).
- Flag | deployment-pending-verification
- Per-call changes needed | None to path/method/encoding for the live `RoamService.completeNode` path. Only confirm: (a) keep multipart/form (do NOT switch to JSON; backend has no `@RequestBody`), (b) `poiId`/`id` decoding is already optional, (c) `needRedeem` is present on every success (backend sets it at :237 and :241); (d) the unused `ChallengePOIRequestBuilder` JSON body (`ChallengePOISubmission.swift:51-59`) must not be wired without switching to form encoding; (e) rename the approval-key label only if the audit wants a literal path.
- Swift files | `Core/RoamService.swift`, `Core/RoamExperienceMutationContracts.swift`, `Core/AuthRequestBuilder.swift`, `App/AppSession.swift`, `App/AppCompositionRoot.swift`, `Core/ChallengePOISubmission.swift`.
- Existing tests | `Tests/AppUnitTests/RoamPOIActionTests.swift`, `Tests/CoreTests/RoamExperienceMutationTests.swift`, `Tests/CoreTests/ChallengePOISubmissionTests.swift`, `Tests/CoreTests/ChallengePOICoordinatorSubmitTests.swift`, `Tests/AppUnitTests/AssetPointsAndOrderCancellationSectionViewTests.swift`, `Tests/ContractChecks/test_business_runtime_wiring.py`.

### /api/city/nodes/favorite
- iOS | Listed path is the normalized approval key (`App/AppSession.swift:6344`; normalization `App/AppCompositionRoot.swift:3720,3745-3754`). Real call: `App/AppSession.swift:6352` `service.toggleFavorite(poiID:token:)` -> `Core/RoamService.swift:58-62` -> `writeMutation` (:79-96) -> `RoamExperienceMutation.toggleFavorite` (`Core/RoamExperienceMutationContracts.swift:16,30,75,85-91`): POST `api/city/nodes/{poiID}/favorite`, no body (`includesBody:false` -> `AuthRequestBuilder.makeFormRequest`, `Core/AuthRequestBuilder.swift:22-44`, `Authorization` header, `Accept: application/json`). Response `RoamActionEnvelope<RoamFavoriteReceipt{favorited:Bool?}>` (`RoamService.swift:179-180`); `favorited` must be a Bool else `APIError.malformedResponse`. Errors as complete (envelope code != 200 -> `rejected(msg)`). No pagination.
- Backend | `CTRL/ApiCityNodeController.java:119-142` POST `/api/city/nodes/{id}/favorite` (`@PathVariable id`, no body); toggles `MemberCollectible.TYPE_NODE_FAV`, returns `AjaxResult.success({favorited: bool})` (:139-141). Errors `AjaxResult.error("请先登录" | "参数不合规" | "据点未开放或已下线")` code 500. Auth: authenticated (`SecurityConfig.java:166`). Related reads: GET `/api/city/nodes/favorites` (:109-117), GET `/api/city/nodes/{id}` (:85-97, sets `favorited/completed` via `markUserState` :145-165).
- Category | ADAPTABLE
- Equivalence note | Identical business meaning (toggle favorite of a merchant POI node, returns resulting state); iOS already calls the backend path/method with matching `{favorited}` shape, the row is only an approval-key label.
- Flag | deployment-pending-verification
- Per-call changes needed | None for the live call (POST `/api/city/nodes/{id}/favorite`, empty body, read `data.favorited`). Optional: nothing else; do not add a body.
- Swift files | `Core/RoamService.swift`, `Core/RoamExperienceMutationContracts.swift`, `Core/AuthRequestBuilder.swift`, `App/AppSession.swift`, `App/AppCompositionRoot.swift`.
- Existing tests | `Tests/AppUnitTests/RoamPOIActionTests.swift`, `Tests/CoreTests/RoamExperienceMutationTests.swift`, `Tests/AppUnitTests/AssetPointsAndOrderCancellationSectionViewTests.swift`, `Tests/ContractChecks/test_business_runtime_wiring.py`.

### /api/city/walking/target
- iOS | `Core/CityWalkingAuthorityReader.swift:36`. GET, query `poi_id=<positive int>` only (accepted by `CityWalkingReadRoute.accepts` :73-87), `Authorization` header, `Accept: application/json`, https required (:38). Response decoded DIRECTLY (no `{code,data}` envelope) as `Wire{schemaVersion==1, kind, id, title, longitude, latitude, datum=="wgs84", region, authorityRevision (prefix "city:<id>:"), issuedAtMs, expiresAtMs}` (:16-28); requires `status==200`, <=16 KiB, `|now-issued|<=30s`, `expires-issued<=300s`. Non-200 -> `APIError.httpStatus`. No pagination.
- Backend | NOT FOUND for `/api/city/walking/target` (greps above; `ApiCityNodeController` mappings: `/nodes`, `/nodes/{id}`, `/nodes/merchant/{merchantId}`, `/nodes/favorites`, `/nodes/{id}/favorite`, `/nodes/{id}/complete`, lines 71/86/100/110/120/168). Nearest data source: `ApiCityNodeController.java:85-97` GET `/api/city/nodes/{id}` returning `AjaxResult{data: CityNodeVO}` with `poiId, name, lat, lng, status` (`CityNodeVO.java:39-49`); `lat/lng` datum is not stated (grep `gcj|wgs` in CityNodeVO: 0 hits), and 410 via `AjaxResult.error(410,"据点未开放或已下线")` when offline (:91).
- Category | PARTIAL
- Equivalence note | Backend exposes a node's title/lat/lng, but not a time-bound, datum-tagged (wgs84), revision-stamped navigation authority in a bare (non-AjaxResult) JSON shape.
- Flag | deployment-pending-verification
- Backend task | Add GET `/api/city/walking/target?poi_id` returning `{schemaVersion:1, kind:"cityNode", id, title, longitude, latitude, datum:"wgs84", region, authorityRevision:"city:<id>:<rev>", issuedAtMs, expiresAtMs}` (<=300s TTL), unwrapped.

### /api/npc/chat/delete
- iOS | The literal `/api/npc/chat/delete` is NOT an HTTP call: it is only a label constant `Core/NPCChatAndSceneAISafetyAudit.swift:317` (`remoteChatDeleteRoute`), the `RegionalEndpointAllowlistAudit` case `Core/RegionalEndpointAllowlistAudit.swift:10`, and gate rows `App/RegionalEndpointAllowlistSectionView.swift:74,144` (grep for URL use: none). The real call is `Core/NPCChatLogDeletion.swift:20` (`path = "api/ai/npc/chat/data/delete"`), request built at :62-68: POST, `Content-Type: application/json`, `Accept: application/json`, `Cache-Control: no-store`, `Authorization: <token>`, body `{}` (:68), timeout 20, never retried. Response: only `code` and `data.deleted:Int` are read (`NPCChatLogDeletion.swift:23-35`): `code != 200` -> `NPCChatDataFailure.rejected`; unreadable/negative -> `.unknown`; else `.deleted(count:)`. Gated OFF (needs `OperationEndpointApproval`, :46-52).
- Backend | `CTRL/ApiAiNpcController.java:473-481` POST `/api/ai/npc/chat/data/delete` (class mapping `/api/ai/npc`, `:50`; `@RequestBody(required=false) Map<String,String> body`; optional `requestId` -> idempotent receipt via `authorWriteReceipts.execute(actor,"NPC_CHAT_DELETE",requestId,...)`, else direct delete :483-486; returns `AjaxResult.success({deleted:n})`). Not `@Anonymous` (only `/info` in ApiPlayTeamController is); auth: authenticated; deliberately not behind `chatOn()` flag (comment at ~:468-471). Sibling export: GET `/api/ai/npc/chat/data/export` (:462-466).
- Category | ADAPTABLE
- Equivalence note | Same business meaning (hard-delete the caller's own NPC chat log, returns deleted count); the live iOS call already hits the real backend route, so only the audit/allowlist label differs from the backend path.
- Flag | deployment-pending-verification
- Per-call changes needed | No change to the HTTP call (already POST JSON `{}` to `api/ai/npc/chat/data/delete`, reads `data.deleted`). Only rename the label/allowlist key `/api/npc/chat/delete` -> `/api/ai/npc/chat/data/delete` in the audit constant, `RegionalEndpointAllowlistAudit.Case.npcChatDelete` and the section-view rows, and update the matching test expectations. Backend accepts the empty `{}` body; adding `requestId` would only opt into receipt idempotency and is not required.
- Swift files | `Core/NPCChatAndSceneAISafetyAudit.swift` (:317), `Core/RegionalEndpointAllowlistAudit.swift` (:10), `App/RegionalEndpointAllowlistSectionView.swift` (:74,:144); live caller `Core/NPCChatLogDeletion.swift` (unchanged).
- Existing tests | `Tests/CoreTests/NPCChatAndSceneAISafetyAuditTests.swift` (:20), `Tests/CoreTests/RegionalEndpointAllowlistAuditTests.swift` (:12,:162), `Tests/AppUnitTests/RegionalEndpointAllowlistSectionViewTests.swift` (:30), `Tests/CoreTests/NPCChatDataTests.swift`, `Tests/CoreTests/NPCChatDataLaunchRecoveryTests.swift`, `Tests/AppUnitTests/NPCChatDataViewTests.swift`, `Tests/CoreTests/Wave3HandoffVerificationRegistryTests.swift`.

### /api/official/v2/events  (prefix; real call = GET /api/official/v2/events/{id}/publish-check)
- iOS | Core/OfficialOrganizer.swift:197 `request("api/official/v2/events/\(eventID)/publish-check", method:"GET")`, no query/body, headers Authorization + Accept. Envelope {code,msg,data}; reads data.blockers[String], data.risks[String] (:204-206); code!=200 -> .denied(msg) (:203); HTTP 401->unauthorized, >=500/408->network (:199-200). Prefix string at App/AppCompositionRoot.swift:3922-3924 is only the read-allowlist gate (GET, no query, id positive int). No pagination.
- Backend | BE/ApiOfficialEventController.java:356-361 `@GetMapping("/v2/events/{id}/publish-check")` (class @RequestMapping("/api/official") :56), no body/consumes; auth: authenticated (not in permitAll; plus canPublish(memberId)&&canReadControlledEvent else `error("无权查看该活动发布检查")`); returns success(OfficialEventV2PublishCheck) (SYS/domain/dto/OfficialEventV2PublishCheck.java:14-31: blockers[], risks[], warnings[] (null unless tiered), results[{level,message}], pass). No pagination.
- Category | ADAPTABLE
- Equivalence note | Same path, method, id-in-path and blockers/risks lists; iOS ignores extra warnings/results fields, so no semantic gap.
- Per-call changes | None to path/method/encoding/field mapping (already exact; csv row 608 says MATCH). Optional: surface `warnings`/`results`. Only verification against deployment needed.
- Swift files | Core/OfficialOrganizer.swift, App/AppCompositionRoot.swift (acceptsRead gate :3922)
- Existing tests | Tests/CoreTests/OfficialOrganizerTests.swift, Tests/AppUnitTests/ReviewedOrientOfficialRouteTests.swift (Tests/ContractChecks/fixtures/backend_route_status.csv:607-608)
- Flag | deployment-pending-verification

### /api/onboarding/get
- iOS | Core/NativeChannelOnboarding.swift:147-149 readSnapshot -> exchange() :156 (declared at :14 as `read`); POST JSON body {guild_kind:1|3, guild_id:String} sorted keys; Authorization+Accept headers; response NativeOnboardingSnapshot (viewer_id,guild_id,configuration_hash,completion_policy,answer_state,guild_kind,submitted,can_skip,next,prompts[prompt_id,title,single_select,required,enabled,options[option_id,label,description,emoji,channel_ids,role_ids],selected_option_ids,...]); envelope code 200; error via envelope.errorCode ONBOARDING_NOT_CONFIGURED / SCREENING_PENDING (:163-164); 401 handling :160-162. No pagination.
- Backend | NOT FOUND. Greps run on base checkout: `grep -rni onboarding --include=*.java` (only ApiComplianceController.java:42 scene "merchant_onboarding" and ApiClubController.java:354 local var, unrelated); `grep -rn "Mapping(\"/api/\(privacy|channel|progress\)" --include=*.java`; `grep -rniE "guild|channel-platform" --include=*Controller.java` -> no controller. Test fixture also says NO-BACKEND: Tests/ContractChecks/fixtures/backend_route_status.csv:612.
- Category | MISSING
- Equivalence note | Backend has no guild/channel-space or onboarding-prompt concept at all.
- Backend task | Design and build guild/channel onboarding config + read endpoint (POST /api/onboarding/get returning the prompt snapshot) or drop the feature from iOS.
- Flag | deployment-pending-verification

### /api/onboarding/submit
- iOS | Core/NativeChannelOnboarding.swift:132 `exchange(submit, body:)` (path const :14); POST JSON {guild_kind,guild_id,request_id(UUID),configuration_hash(64hex),answers:[{prompt_id,option_ids[]}]} (built :119-120); follow-up receipt read GET `api/channel-platform/admission/requests/{uuid}` (:137, :14) expecting operation ONBOARDING_SUBMIT, state APPLIED, result{...granted_role_ids,joined_channel_ids,answers}. Envelope code 200; 401 handled.
- Backend | NOT FOUND (same greps as onboarding/get; additionally `grep -rn "channel-platform" --include=*.java` empty). csv:613 NO-BACKEND.
- Category | MISSING
- Equivalence note | No onboarding submit nor admission-request receipt store exists.
- Backend task | Build onboarding answer submit with request_id idempotency plus admission-request receipt GET, or remove from iOS.
- Flag | deployment-pending-verification

### /api/play/advanced/time-window
- iOS | Core/NativePlatformService.swift:31 (windowPath), call :64-75 `timeWindow(activityID:topicID:nodeID:)`: GET query activityId,nodeId,topicId, Authorization+Accept. Response data decoded as NativeTimeWindow (Core/NativeTimeWindowContract.swift:6-26): enabled, notificationProvider=="LOCAL_ONLY", timeZone, serverNow(ms), nextOpenAt, nextCloseAt, openNow, windowVersion, plus echo activityId/topicId/nodeId (NativePlatformService.swift:~85). Errors: HTTP 401 / code 401 -> unauthorized; code 409 + data.reasonCode "TIME_WINDOW_OPENING_REQUIRED" -> openingRequired; other non-200 -> network.
- Backend | No such route: BE/ApiAdvancedPlayController.java mappings only :36 POST /start, :49 POST /action, :86 GET /receipt, :92 GET /state, :102 GET /leaderboard (class :28 /api/play/advanced). Partial semantics in SYS/service/impl/AdvancedGameRuntimeServiceImpl.java: per-node config `timeWindow{openFrom,openTo "HH:mm"}` enforced by requireWithinTimeWindow :1742-1760 (rejects with IllegalStateException text when closed; no reasonCode); action SUBSCRIBE_TIME_WINDOW :542-543 / subscribeTimeWindow :1790-1800 (stores subscribed, tmplId = WeChat subscribe template, not LOCAL_ONLY); GET /state projects playKit.timeWindow {openFrom,openTo,eyebrow,title,subscribeTmplId,subscribed} (:2356-2365). grep `TIME_WINDOW_OPENING_REQUIRED|time-window` in BE controllers/services: NOT FOUND (only RegistrationRedemptionApplication.java:581 comment).
- Category | PARTIAL
- Equivalence note | The open/close window rule exists server-side but no read endpoint computes serverNow/nextOpenAt/nextCloseAt/windowVersion/timeZone, and the 409 reasonCode contract is absent.
- Backend task | Add GET /api/play/advanced/time-window deriving serverNow, nextOpenAt/nextCloseAt, windowVersion, timeZone, notificationProvider from node timeWindow config, with 409 TIME_WINDOW_OPENING_REQUIRED. (Alternative client-only: derive from /state playKit.timeWindow, but serverNow/windowVersion would be missing.)
- Flag | deployment-pending-verification

### /api/play/city-orientation/  (prefix only: request(path:) base for "answer" and "receipt")
- iOS | Core/CityOrientationTaskOriginalSource.swift:169 `baseURL.appendingPathComponent("api/play/city-orientation/" + path)`; not an endpoint itself. See the two rows below.
- Backend | NOT FOUND: `grep -rniE "city-orientation|CITY_ORIENTATION" --include=*.java` hits only tests (TopicCreateOpenClubPoolTest.java:159,224,254). No /api/play/city-orientation controller.
- Category | PARTIAL (aggregate of the two children)
- Equivalence note | Children map to /api/play/answer + /api/play/action-receipt semantics but with a different contract (see below).
- Backend task | See child rows.
- Flag | deployment-pending-verification

### /api/play/city-orientation/answer
- iOS | Core/CityOrientationTaskOriginalSource.swift:146-153 (submit): POST, Content-Type application/json, body CityOrientationTaskCommand (:10-15) {sessionId,nodeId,requestId(UUID string),expectedVersion,answer(<=300 utf16)}, sorted keys; route guard Core/CityOrientationTaskOriginalTransport.swift:52. Response data decoded as CityOrientationTaskReceipt (:35-58): contract=="CITY_ORIENTATION_ANSWER_V1", sessionId,nodeId,requestId,payloadHash(SHA256 of "sessionId:nodeId:expectedVersion:len:answer"),configVersion,revision,outcome APPLIED|FAILED, response{code,msg,data{puzzleScore,xp,answerWrong,nodeId}}. Envelope code 200 required else .rejected(code,msg) (:193); 401/403 handled.
- Backend | BE/ApiPlayProgressController.java:118-126 `@PostMapping("/answer")` (class /api/play :18), params NOT @RequestBody (query/form): activityId,nodeId,answer,topicId,routeActionId,expectedRouteVersion,routeSessionId,runtimeInstance,authorityEpoch,longitude,latitude,accuracy; @RateLimiter(10s,120/member); authenticated. Idempotency in web/service/play/PlayBasicIntentApplication.java:133-198 executeBasicIntent: actionId regex [A-Za-z0-9:_-]{1,80} (:138), receipt keyed by "play:"+sha256(actionId) (:214), hash conflict -> 409 "动作标识已用于其他输入" (:194), original-session mismatch 409 intentNotExecuted (:157); replay returns stored AjaxResult (basicReplay :198-202). No pagination.
- Category | PARTIAL
- Equivalence note | Same business action (answer a node with idempotent replay, version and run identity) but different keys (activityId/topicId/routeActionId/expectedRouteVersion/routeSessionId vs sessionId/requestId/expectedVersion), form-not-JSON, and no CITY_ORIENTATION_ANSWER_V1 receipt wrapper with payloadHash/revision/outcome that iOS validates.
- Backend task | Either add a /api/play/city-orientation/answer facade returning the V1 receipt (contract, payloadHash, revision, outcome, response) over executeBasicIntent, or re-map iOS to /api/play/answer and relax receipt validation.
- Flag | deployment-pending-verification

### /api/play/city-orientation/receipt
- iOS | Core/CityOrientationTaskOriginalSource.swift:156-166 `original()`: GET query sessionId,nodeId,requestId(UUID) (exactly 3, route guard Core/CityOrientationTaskOriginalTransport.swift:43); response data: if outcome=="PENDING" with matching ids -> nil (unknown), else decoded as CityOrientationTaskReceipt (same as answer). Envelope code 200 else rejected; 401/403 handled.
- Backend | BE/ApiPlayProgressController.java:78-81 `@GetMapping("/action-receipt")` params activityId,topicId,nodeId,routeActionId -> PlayBasicIntentApplication.java:121-131: invalid id -> error("动作标识无效"); no receipt -> AjaxResult(520,"原命令结果待确认，请稍后查询"); wrong node/actor -> error("无权读取该命令"); else replays stored AjaxResult. Authenticated. No pagination.
- Category | PARTIAL
- Equivalence note | A receipt lookup by action id exists, but it is keyed by activity/topic/node/routeActionId, returns the original command response (not the V1 receipt) and signals pending with code 520 rather than outcome "PENDING".
- Backend task | Add a receipt facade (sessionId,nodeId,requestId) returning the V1 receipt with outcome PENDING/APPLIED/FAILED, or adapt iOS to action-receipt (520 = pending).
- Flag | deployment-pending-verification

### /api/play/egg/collect
- iOS | Core/JourneyContentService.swift:46-52 `collect(topicID:egg:token:)`: POST multipart/form (AuthRequestBuilder.makeFormRequest via PlayExperienceService.request(form:) Core/PlayExperienceService.swift:210-228) fields eggId, content(egg.text), topicId?; route bound to capability journeyEggCollection (PlayExperienceService.swift:247). Only envelope success checked; no response fields used. Egg model JourneyEgg (Core/JourneyCheckContracts.swift:58: id,lat,lng,radius,text).
- Backend | NOT FOUND for write: `grep -rniE "egg" --include=*.java` -> only reads: PlayPlayerQueryApplication.java:266-276 (achievements lists MemberCollectible TYPE_EGG, reached via ApiPlayProgressController POST /api/play/achievements :300), MemberCollectible.java:18,23, ApiConfigController.java:48 (comment: eggs config removed). No @Mapping containing egg; TYPE_EGG only ever read (`grep TYPE_EGG`). csv:647 NO-BACKEND.
- Category | MISSING
- Equivalence note | Backend can display collected eggs but has no endpoint that records a collection.
- Backend task | Add POST /api/play/egg/collect (eggId, content, topicId) inserting MemberCollectible TYPE_EGG idempotently, or remove egg collection from iOS.
- Flag | deployment-pending-verification

### /api/play/route-action
- iOS | App/PlayRouteMapView.swift:157 (approval path), call :164-239; URL built :271-286: GET query sessionId,memberId,actionId; Authorization+Accept; decode :289-299: code==200, data.sessionId/memberId/actionId must echo request, data.responseJson (String). Non-2xx or mismatch -> row hidden.
- Backend | NOT FOUND by those keys. Nearest: BE/ApiPlayProgressController.java:78-81 GET /api/play/action-receipt (activityId,topicId,nodeId,routeActionId; replays stored response, 520 if pending) and ApiPlayCheckController.java:145-147 GET /api/play/check/receipt (sessionId,nodeId,checkId,action; check-only, errorCode CHECK_*). Persistent store topic_route_action.response_json exists (SYS/domain/TopicRouteAction.java:14,31) but no GET exposes it by (sessionId, actionId). grep `route-action` in BE: NOT FOUND.
- Category | PARTIAL
- Equivalence note | Replaying a stored action response by action id exists, but not keyed by sessionId/memberId nor returned as {sessionId,memberId,actionId,responseJson}.
- Backend task | Add GET /api/play/route-action returning TopicRouteAction {sessionId,memberId,actionId,responseJson} for the caller's own session, or adapt iOS to action-receipt plus activity/topic/node scope.
- Flag | deployment-pending-verification

### /api/progress/meter
- iOS | Core/NativeChannelProgressService.swift:48-57 `meter()`: GET query channel_id,topic_id,activity_id,subject_type=MEMBER,subject_id (exact set enforced Core/NativeChannelProgressFinalForward.swift:163-169); response NativeChannelProgressMeter (Core/NativeChannelProgressContracts.swift:117-125: visible,subjectId,topicId,activityId,required,done,percent,revision,visibility); snake_case decoder (:98); errors via envelope errorCode / OUTCOME_UNKNOWN (:100-101). No pagination.
- Backend | NOT FOUND: `grep -rn --include=*Controller.java -E "Mapping\(.*(api/progress|/meter|privacy|/api/channel)"` empty; `grep -rn "Mapping(\"/api/(privacy|channel|progress)"` empty. Only loosely related: ApiOfficialEventController.java:194 GET /events/{id}/progress (single official event progress, not channel/subject). csv: backend_route_status lists channel progress as NO-BACKEND.
- Category | MISSING
- Equivalence note | No channel concept or per-subject required/done/percent meter with privacy-gated visibility exists; event progress is a different scope.
- Backend task | Build channel progress meter (+ privacy settings) service, or remove channel progress from iOS.
- Flag | deployment-pending-verification

### /api/progress/requests  (prefix string only)
- iOS | Core/NativeChannelProgressFinalForward.swift:108 builds `baseURL.appendingPathComponent("api/progress/requests") + "/"` as receipt-prefix matcher in receiptCommand(for:); not a call by itself (no request is sent to the bare path).
- Backend | NOT FOUND (greps as in /api/progress/meter).
- Category | MISSING
- Equivalence note | Prefix of the privacy-save receipt route; nothing equivalent on backend.
- Backend task | See /api/progress/requests/{}.
- Flag | deployment-pending-verification

### /api/progress/requests/  (prefix string only)
- iOS | Core/NativeChannelProgressFinalForward.swift:100 `lease.paths.contains("api/progress/requests/" + command.requestId)` approval check; not a call by itself.
- Backend | NOT FOUND.
- Category | MISSING
- Equivalence note | Same as above.
- Backend task | See /api/progress/requests/{}.
- Flag | deployment-pending-verification

### /api/progress/requests/{}
- iOS | Core/NativeChannelProgressService.swift:68 `get("api/progress/requests/\(command.requestId)")`: GET, no query/body, receipt of privacy save (POST api/privacy/progress body: aggregate_scope, detail_scope, photo_scope, leaderboard_scope, expected_revision, expected_updated_at, request_id; Core/NativeChannelProgressContracts.swift:168-190). Response NativeChannelProgressPrivacy (:148-160: scopes, revision, updatedAt, effective, appliesTo "CHANNEL_PROGRESS", requestId, status "APPLIED"...). Error 404 + errorCode PROGRESS_REQUEST_NOT_FOUND -> nil (:70); OUTCOME_UNKNOWN handled.
- Backend | NOT FOUND (no /api/progress, /api/privacy routes: greps above). Closest idempotent-receipt pattern: TeamEventCommandService.query (SYS/service/impl/TeamEventCommandService.java:46-52) but for team/event commands only.
- Category | MISSING
- Equivalence note | Progress-privacy settings and their request receipts do not exist on the backend.
- Backend task | Build /api/privacy/progress (GET/POST) with request_id receipts at /api/progress/requests/{id}, or remove from iOS.
- Flag | deployment-pending-verification

### /api/team/original-request
- iOS | Core/NativeFriendTeamInviteService.swift:8 (const `receipt`); write :63-66 POST JSON raw envelope {requestId(lowercase UUID), action FRIEND_OFFER|FRIEND_CONFIRM|FRIEND_DECLINE|FRIEND_REVOKE, expectedTeamId, body{teamId, peers[{id,version}] (offer, 1-10), offerId (UUID), joinMode 1|2 (confirm)}} (Core/NativeFriendTeamInviteContracts.swift:15-45); recover :67-70 GET query requestId. Response NativeFriendTeamInviteReceipt: contract "ORIGINAL_TEAM_REQUEST_V1", requestId, action, teamId, targetKey "friend-offer:{teamId}", requestFingerprint (SHA256 of raw), outcome UNKNOWN|APPLIED|REJECTED, errorCode, friendOffer{offerId|offers[{peerID,offerId}]} (validated :80-100). Envelope code 200 else .unknown (:110); 401 -> unauthorized().
- Backend | No such route (`grep -rn "original-request|ORIGINAL_TEAM_REQUEST|FRIEND_OFFER|friend/team-invite|friend-offer" --include=*.java` -> none relevant; no /api/friend controller). Nearest: BE/ApiPlayTeamController.java:34-39 POST /api/team/command (@RequestBody TeamEventCommand: requestId,action,targetId,memberId,joinMode,approved,reason,inviteCode,message...), :41-44 POST /command/query (receipt by requestId; absent -> state UNKNOWN, TeamEventCommandService.java:46-52), :46-49 POST /command/cancel. Allowed TEAM actions only quit|kick|disband|join-mode|withdraw|handle|join|apply (TeamEventCommandService.java:152-153, invoke :182-196); fingerprint SHA-256 :160-171. Authenticated; result Map via view()/state(). Related: friend directory/picker/landing/mine (api/friend/team-invite/*) also NOT FOUND.
- Category | PARTIAL
- Equivalence note | Idempotent requestId/fingerprint command-plus-query receipt infrastructure for team commands exists, but no friend-offer actions (offer/confirm/decline/revoke), no V1 receipt shape and the receipt query is POST not GET.
- Backend task | Extend TeamEventCommandService with FRIEND_OFFER/CONFIRM/DECLINE/REVOKE (and offer store + picker/landing/mine reads), or retire the friend team-invite feature in iOS.
- Flag | deployment-pending-verification
