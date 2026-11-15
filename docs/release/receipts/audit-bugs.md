# Audit Bugs Receipt (Gemini Hydrogen — `ui/h-audit-bugs`)

Scope: engineering diagnosis and backend fix note for `/api/play/nodes` returning `500` (Bug 5), verified against `DES-ag1` and `chengyinhub` (`integration/backend-app-r2` / `release/rehearsal-2`).

## Bug 5 — Play screen fails because `/api/play/nodes` returns 500

### Finding: Backend cause (client request conforms to contract)

- **Endpoint**: `GET /api/play/nodes`
  - Backend controller: `chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api/ApiPlayProgressController.java` (`@RequestMapping("/api/play")`, `@GetMapping("/nodes")`, lines 47–55) -> `playEntryApplication.nodes(currentMemberId(), activityId, topicId, clientPlatform, clientVersion, capabilities)`.
  - App caller & validator: `Core/PlayExperienceService.swift` (`nodes(scope:token:)`, lines 57–65) and `Core/PlayReadRoute.swift` (lines 8–43).
- **App Request & Query Payload**:
  - Method: `GET` (`httpBody == nil`, `httpBodyStream == nil`).
  - Query parameters: either `?activityId=<positive_int>` or `?topicId=<positive_int>` (from `scopeFields(_:)` in `Core/PlayExperienceService.swift:231-232`). Optional capability parameters (`clientPlatform`, `clientVersion`, `capabilities`) stay omitted unless dormant capability `.capabilityDeclaration` is enabled (`Core/PlayExperienceService.swift:7`).
  - Headers: `Authorization: <token>`, `Accept: application/json`.
  - No malformed path, extra query field, or unexpected body is sent by the iOS app; the request passes `PlayReadRoute` and matches `ApiPlayProgressController.nodes`.

### Backend Failure Paths Producing `code: 500`

1. **`TopicRouteSession.state_json` deserialization failure caught as `AjaxResult.error(...)` (`code: 500`)**:
   - `PlayEntryApplication.java:206-215` calls `topicRouteRuntimeService.state(memberId, tId, progActId)` (or `.state(..., Declaration.parse(...))`) when `registered && topicRouteRuntimeService != null && (playMode == PlayMode.LINEAR_ORIENTEERING || hasJourneyState)`.
   - Downstream `TopicRouteNarrativeProgress.readEngineState(String json)` (`chengyinhub-system/src/main/java/com/chengyinhub/business/service/impl/TopicRouteNarrativeProgress.java:269-272`) deserializes `session.getStateJson()` via Jackson into `TopicRouteEngine.State.class` and throws `IllegalStateException("路线局状态不可用", e)` on any exception.
   - `PlayEntryApplication.java:213-215` catches `IllegalArgumentException | IllegalStateException | ServiceException` and returns `error(e.getMessage())`, which produces `AjaxResult` `{"code": 500, "msg": "路线局状态不可用"}`.

2. **Uncaught `IllegalStateException` throws in `PlayEntryApplication.nodes` hitting `GlobalExceptionHandler` (`code: 500`)**:
   - `PlayEntryApplication.java:188-189`: throws uncaught `IllegalStateException("本局数值规则快照不可用")` when `NodeJourneySnapshot.hasContentSnapshots(contentSnapshot)` is true but `contentRules == null`.
   - `PlayEntryApplication.java:242-243`: throws uncaught `IllegalStateException("本局内容快照不可用")` when `nodeVersioned && !NodeJourneySnapshot.hasContent(content)`.
   - `PlayEntryApplication.java:244-245`: throws uncaught `IllegalStateException("本局内容归属不可用")` when `nodeVersioned && !sharedContent && content.path("nodePresentation").path("id").asLong() != n.getId()`.
   - `PlayEntryApplication.java:308` (`contentSnapshotForRead`) invokes `NodeJourneySnapshot.requireContentSnapshot(snapshot)` (`chengyinhub-system/src/main/java/com/chengyinhub/business/service/support/NodeJourneySnapshot.java:73-85`), which throws uncaught `IllegalStateException("本局内容快照不完整")` if `journeyRules`, `journeyStory`, `nodeConfigs`, or per-node `nodeAnswers` entries fail validation.
   - All uncaught `IllegalStateException` throws hit `GlobalExceptionHandler.handleRuntimeException` (`GlobalExceptionHandler.java:165-171`), returning `AjaxResult.error(userSafeMessage(e.getMessage()))` (`code: 500`).

### Proposed Backend Fix

1. **Tolerant `readEngineState` deserialization & non-500 recovery**:
   - In `TopicRouteNarrativeProgress.readEngineState(String json)`, guard null/blank `json` cleanly and configure Jackson tolerantly (`FAIL_ON_UNKNOWN_PROPERTIES = false`, default non-null collections on `TopicRouteEngine.State`) so legacy or partial `state_json` rows in `topic_route_session` do not fail deserialization.
   - If `state_json` is genuinely corrupted and cannot be parsed, log the session ID + exception details on the server and either reinitialize safely for unstarted runs or return an explicit `4xx` domain status (e.g. `409` with a dedicated `errorCode`) instead of generic `500`.
2. **Graceful snapshot validation fallback in `PlayEntryApplication.nodes`**:
   - Avoid letting `NodeJourneySnapshot.requireContentSnapshot` or the snapshot guards (`lines 188-189, 242-245, 308`) throw uncaught `IllegalStateException` during read-only `GET /api/play/nodes`.
   - When `contentSnapshot` is incomplete or `contentRules` is absent on a published topic/session, fall back to topic-level `routeTopic.getJourneyRulesJson()` and live node fields (or skip broken snapshot entries with a warning log) unless strict snapshot integrity is required, and map unrecoverable data issues to a structured `ServiceException` with a `4xx` code rather than `500`.
3. **Regression coverage**:
   - Add backend tests on `GET /api/play/nodes` (`PlayEntryApplication` / `ApiPlayProgressController`) with null/legacy `state_json` and partial `published_route_graph_json` confirming HTTP `200` and non-`500` payload.
