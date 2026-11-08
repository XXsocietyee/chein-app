# Gap classification — /api/merchant, /api/topic, /api/template, /api/project, /api/activity (MISSING rows)

Status: DRAFT, docs only, read-only analysis. Branch `cloud/gap-2` (from `wip/wave4-loc`), input `docs/release/backend-contract-for-ios.md` (from `cloud/doc-5`), Appendix A.

**Backend baseline:** `hengyin@4ac8c249fcad69e4f9c423702711d46deca2755a` (owner-confirmed source baseline, checked out detached, read-only).
**Deployment flag:** every row below is **deployment-pending-verification**. Whether production runs this commit is UNVERIFIED (only historical receipt: `19408d49` deployed 2026-10-21). Nothing here claims production state.

Path shorthand: `api/X.java` = `hengyin/chengyinhub-admin/src/main/java/com/chengyinhub/web/controller/api/X.java`.
Common backend facts (all controllers above): responses are `AjaxResult {code,msg,data}`; business errors come back as `code != 200` with `msg` (HTTP is mostly 200) — per-row error codes are only listed where the controller defines distinct ones; otherwise "NOT FOUND: no per-route code table". Pagination, where present, is `pageNum`/`pageSize` form fields (e.g. `ApiActivityController.activityList` api/ApiActivityController.java:176-185). Evidence rule: `file:line` on both sides or NOT FOUND.

## Summary

| Category | Count |
|---|---|
| ADAPTABLE | 9 |
| PARTIAL | 19 |
| MISSING | 31 |
| **Total (rows taken from Appendix A)** | **59** |

Every row: deployment-pending-verification.

Important reading note on why PARTIAL, not ADAPTABLE, for the `*-requests/*` families: the iOS contracts (`ProjectEditRequestContract`, `ProjectStateRequestContract`, `ActivityCreateRequestContract`, `TemplateAuthoringRequestReceipt`) wrap the *original* write endpoints in a request-id + payload-hash + read-back receipt protocol. The original endpoints exist, but the idempotency/receipt/read-back layer does not. Pointing the App directly at the originals would drop the exactly-once and "did my write commit?" guarantees the App relies on, so it is a **semantic downgrade, not an equivalent**. The App code is already approval-gated per path (e.g. `Core/ProjectEditHTTPService.swift:36-40,145`, `Core/TemplateAuthoringRequestHTTPService.swift:33-37`): without approval of those paths it degrades to read-only / `.notSent`.

## Row table

Columns: iOS site · Swift types · method/encoding (iOS) · nearest backend · category · note. All rows flagged **deployment-pending-verification**.

### A. /api/merchant/authoring/* (17 rows) — all MISSING

Backend: NOT FOUND. Grep of non-test Java for `authoring`, `draft-selection` finds no `@RequestMapping`/`@*Mapping` (only `TopicRoutePublicationCompiler`, `TopicRouteOutcomeReader`, `BaseController` mention the word). The iOS comment names `ApiMerchantAuthoringController` on branch `cursor/w05-j-merchant-authoring` (Core/MerchantAuthoringService.swift:7-8): that controller is NOT in the baseline. Nearest *unrelated-semantics* capability: AI endpoints under `/api/ai/*` (api/ApiAiController.java:47 class mapping, e.g. `/merchant/insight` :404) — not equivalent to draft/release/job authoring.

| iOS path | iOS call site / types | method + body | Category |
|---|---|---|---|
| `/api/merchant/authoring/jobs` | Core/MerchantAuthoringService.swift:10,335,363 | POST JSON (create, :335) and GET `?requestId=` (:363); body via JSONSerialization (:131-132) | MISSING |
| `/api/merchant/authoring/jobs/cancel` | Core/MerchantAuthoringService.swift:11,226 | POST JSON `{requestId}` | MISSING |
| `/api/merchant/authoring/drafts` | Core/MerchantAuthoringService.swift:12,192 | GET (list), POST via :335 | MISSING |
| `/api/merchant/authoring/drafts/{}` | Core/MerchantAuthoringService.swift:21,249,272 | GET | MISSING |
| `/api/merchant/authoring/releases` | Core/MerchantAuthoringService.swift:13,378 | GET `?requestId=`, POST via :335 | MISSING |
| `/api/merchant/authoring/releases/{}/withdraw` | Core/MerchantAuthoringService.swift:25,335 | POST JSON | MISSING |
| `/api/merchant/authoring/public` | Core/MerchantAuthoringService.swift:14,286 | GET + query | MISSING |
| `/api/merchant/authoring/environment` | Core/MerchantAuthoringService.swift:15,310 | GET `?releaseId=` | MISSING |
| `/api/merchant/authoring/main-line` | Core/MerchantAuthoringService.swift:16,298 | GET + query | MISSING |
| `/api/merchant/authoring/draft-selection/list` | Core/ProjectMerchantDraftSelection.swift:7; client Core/ProjectMerchantDraftClient.swift:44,57 | JSON body via `OperationAdapterHTTP.json` (Core/OperationAdapterSafety.swift:115-117) | MISSING |
| `/api/merchant/authoring/draft-selection/resolve` | Core/ProjectMerchantDraftSelection.swift:8; Core/ProjectMerchantDraftClient.swift:49 | same JSON POST | MISSING |
| `/api/merchant/authoring/player` | Core/MerchantGamePlayerReadGrant.swift:46 | GET prefix check (:42-48) | MISSING |
| `/api/merchant/authoring/player/` | Core/MerchantGamePlayerReadGrant.swift:48 | GET prefix | MISSING |
| `/api/merchant/authoring/player/{merchantId}/game` | Core/MerchantGamePlayerReadGrant.swift:19,28 | GET, no body (:42) | MISSING |
| `/api/merchant/authoring/player/{merchantId}/requests/{requestId}` | Core/MerchantGamePlayerReadGrant.swift:20,29 | GET, requestId UUID | MISSING |
| `/api/merchant/authoring/player/{}/game` | Core/MerchantGamePlayer.swift:79,118 | GET | MISSING |
| `/api/merchant/authoring/player/{}/requests/{}` | Core/MerchantGamePlayer.swift:99,118 | GET | MISSING |

Backend task: B-1 (below).

### B. /api/merchant/city-value/* (4 rows) — MISSING

iOS: Core/CityMerchantValueService.swift:51 (report), :53 (result/{id}), :57 (event/{}/benefit), :61 (events). GET with query items (`from`,`to`,`cursor`, scope fields), `Accept: application/json`; POST only for `merchantAccess` (:66,83). Envelope `{code,data,errorCode}` (:168-169); failures `rejected/stale/noPermission` (:170).
Backend: NOT FOUND (`city-value` grep empty). Nearest unrelated: `ApiMerchantController.dashboard` api/ApiMerchantController.java:1298 (`POST /dashboard`, no window/scope/cursor) and `events` :1639 (`POST /events`, no params) — different semantics (own-store operational stats vs. city-level value report with snapshot/benefit).
Category: MISSING for all 4. Backend task: B-2.

### C. /api/merchant/crm/* fixture rows (4) — ADAPTABLE (no runtime change)

The four literal-id paths (`customers/61001/detail`, `customers/61001/contact`, `exports/74001/status`, `exports/74001/download`) come from the fixture shim `App/MerchantEngagementFixtureSupport.swift:34-42`, not from real calls. Real call sites build templated paths: Core/MerchantEngagementContracts.swift:137 (`exports/\(id)/status`, POST `{}`), :138 (`customers/\(id)/detail`, POST nil body), :194 (`customers/\(id)/contact`, POST JSON `{purpose}`), :195 + Core/MerchantEngagementService.swift:109-112 (`exports/\(id)/download`, GET with header `X-CRM-Export-Token`).
Backend, all present with the same verb/shape: api/ApiMerchantCrmController.java:279 `POST /exports/{taskId}/status`, :173 `POST /customers/{customerMemberId}/detail`, :182 `POST /customers/{customerMemberId}/contact` body `MerchantCrmContactRequest.purpose`, :288 `GET /exports/{taskId}/download` header `X-CRM-Export-Token` (token required; 401/403 via `writeDownloadError`). Auth: token login (`principal()`), merchant CRM permission.
Semantic equivalence: exact. Category: ADAPTABLE — adaptation = none in runtime code; fix the Appendix-A matcher to normalise `\d+` ids (docs only). Flag deployment-pending-verification.

### D. Merchant store / NPC (13 rows)

| iOS path | iOS site / types / method | nearest backend | Category + note |
|---|---|---|---|
| `/api/merchant/insight` | Core/MerchantAndPublishAuthoringAudit.swift:119 (constant for audit only, no call). Real call: Core/MerchantMarketingService.swift:140 `api/ai/merchant/insight` | api/ApiAiController.java:404 `POST /api/ai/merchant/insight`, no params, token, MARKETING_READ; failures `error(MERCHANT_ONLY_BLOCKED)` :418/ROLE_RESOLVE_FAILED :424 | **ADAPTABLE** — change constant at MerchantAndPublishAuthoringAudit.swift:119 to `api/ai/merchant/insight`; the live call already uses it |
| `/api/merchant/poi/detail` | MerchantAndPublishAuthoringAudit.swift:115 (audit constant; no live call found) | api/ApiMerchantController.java:444 `POST /public-detail` body `MmsMerchant`; also api/ApiMerchantOpsController.java:36 `GET /public-detail?merchantId=` (anonymous) | **ADAPTABLE** — change constant (:115) to `api/merchant/public-detail`; semantic caveat: "POI detail" vs merchant public detail not confirmed identical (product to confirm) |
| `/api/merchant/shop/apply` | MerchantAndPublishAuthoringAudit.swift:117 (audit constant; "4-step wizard" per file header :5) | api/ApiMerchantController.java:2009 `POST /merchant_registration`, JSON `MerchantRegistrationDTO` (@Validated), token, `@Transactional` | **ADAPTABLE** — change constant (:117); caveat: wizard steps map to one DTO, wizard-level draft/resume not on backend (NOT FOUND) |
| `/api/merchant/npc/voice/revoke` | Core/MerchantNPCHTTP.swift:28,85 POST JSON `{requestId}`, envelope `{code,msg,data}` (:44) | api/ApiMerchantController.java:1027 `POST /npc/voice/reset`, no body, merchant PROFILE_WRITE | **ADAPTABLE** — change path at MerchantNPCHTTP.swift:28,85 to `/api/merchant/npc/voice/reset`; requestId is ignored by backend (lose client-side dedup, acceptable: reset is idempotent — NOT verified, no code read of reset internals beyond signature) |
| `/api/merchant/npc/voice/script` | MerchantNPCHTTP.swift:26,75 POST JSON `{}`, response `MerchantNPCVoiceScript` | NOT FOUND (`voice/script` grep empty); api/ApiMerchantController.java:952 `voice/enroll`, :998 `voice/status` exist but return no script | **MISSING** — B-3 |
| `/api/merchant/npc/avatar/generate` | MerchantNPCHTTP.swift:29,89 POST JSON `{imageUrl,style}` → `MerchantAvatarResource.Job` | NOT FOUND (no avatar route in api/ApiMerchantController.java; `npc/save` :820 stores an avatar string only) | **MISSING** — B-3 |
| `/api/merchant/npc/avatar/status` | Core/MerchantOperationsService.swift:122 JSON `{}` (Body.json :48) → `MerchantAvatarResource` | NOT FOUND | **MISSING** — B-3 |
| `/api/merchant/npc/knowledge-review` | Core/MerchantNPCKnowledgeReviewWriter.swift:52,228-234 POST JSON | NOT FOUND for submit | **MISSING** — B-3 |
| `/api/merchant/npc/knowledge-review/request` | Writer:54,249-258 GET `?requestId=` | api/ApiMerchantController.java:922 `GET /npc/review` — no requestId, returns current profile review receipt `profileReviewService.merchantNpcReceipt` | **PARTIAL** — read of current review exists; per-request lookup missing |
| `/api/merchant/offer-withdrawal/request/` | Core/MerchantOfferWithdrawalOriginalFlow.swift:24,38-47,91-92: GET `current?merchantId&offerId`, GET `result?...&requestId`, POST JSON `withdraw` with 7 keys (merchantId, offerId, requestId, intentSHA256, expectedSHA256, reasonSHA256, reason) | api/ApiCoopController.java:858 `POST /api/coop/offer/withdraw` JSON `Map`, uses `offerId` only; merchant COOP_MANAGE | **PARTIAL** — withdraw action exists; `current`/`result` read-back and hash/requestId CAS missing |

### E. /api/project, /api/topic, /api/template, /api/activity receipt families (23 rows) — PARTIAL

| iOS path | iOS site / types / method | nearest backend (file:line) | Missing part |
|---|---|---|---|
| `/api/project/state-requests/context` | Core/ProjectStateRequestContract.swift:5; Core/PublishModesService.swift:97-98; `Context`; POST JSON | none (NOT FOUND); baseline-hash source absent | baselineHash/context read |
| `/api/project/state-requests/submit` | Contract:6; PublishModesService.swift:158-166; `Submit/Command`; POST JSON, payload chunks | originals: api/ApiTopicController.java:1308 `update_user_status` (form, `expectedUserStatus` CAS), :1172 `delete`; api/ApiTemplateController.java:345 `updateLibraryStatus`, :311 `delete`; api/ApiActivityController.java:674 `update_publish_status`, :493 `delete` — all form params, `scope` | requestId idempotency, payload-hash binding, receipt; originals CAS only for topic status (:1308) |
| `/api/project/state-requests/read` | Contract:7; PublishModesService.swift:252-260; POST JSON | none | request read-back |
| `/api/topic/edit-requests/submit` | Core/ProjectEditRequestContract.swift:8; Core/ProjectEditHTTPService.swift:145-148; POST JSON `Submit` | api/ApiTopicController.java:370 `create`, :377 `v2/create`, :707 `update`, :714 `v2/update` (JSON `TopicCreateDTO`/`TopicUpdateDTO`, @Validated); draft requestKey helper :640 only | request-id idempotency, payload hash, receipt |
| `/api/topic/edit-requests/read` | Contract:9; ProjectEditHTTPService.swift:198-202 | none | read-back |
| `/api/topic/edit-requests/resume-post-processing` | Contract:10; ProjectEditHTTPService.swift:224 | none | post-processing resume |
| `/api/activity/create-requests/submit` | Core/ActivityCreateRequestContract.swift:5; PublishModesService.swift:142; POST JSON | api/ApiActivityController.java:779 `publish` JSON `CmsActivityPublishRequest`; :879 `update` | idempotency/receipt |
| `/api/activity/create-requests/read` | Contract:6; PublishModesService.swift:232 | none | read-back (`NOT_FOUND/RUNNING/COMMITTED/REJECTED` states, Contract:74) |
| `/api/activity/create-requests/resume-post-processing` | Contract:7 | none | resume |
| `/api/template/author-requests/submit` | Core/TemplateAuthoringRequestReceipt.swift:8; Core/TemplateAuthoringRequestHTTPService.swift:54 | api/ApiTemplateController.java:98 `publish`, :166 `draft` (JSON `CmsTemplatePublishRequest`) | idempotency/receipt |
| `/api/template/author-requests/read` | Receipt:9; HTTPService.swift:60 | none | read-back |
| `/api/template/report-receipt` | Core/TemplateContentReportContracts.swift:11,13 (read path) | api/ApiTemplateController.java:733 `report`, :753 `personal-report` (form `id`,`reason`; dedupe per reporter "同一人同一轮只记一次") | receipt read |
| `/api/topic/attribute-author` | Core/NativeAttributeAuthorRuntimeConfiguration.swift:20; Core/NativeAttributeAuthorService.swift:53-70 versioned GET/POST JSON with configVersion | api/ApiTopicAttributeController.java:53 `GET /attributes`, :59 POST, :66 PUT, :79 DELETE; api/ApiTopicAttributeBindingController.java:22 `GET /attribute-binding` | versioned envelope + expectedConfigVersion CAS; App already has legacy `state-keys` fallback (Service.swift:19,327) |
| `/api/topic/attribute-author/request` | Configuration.swift:21; Service.swift:291-312 | none | request receipt |
| `/api/topic/attribute-author/references` | Configuration.swift:22; Service.swift:56,373 GET `?key` | api/ApiTopicAttributeController.java:111 `GET /state-keys/usage` (topicId, scope) | key-scoped lookup/shape differs |
| `/api/topic/attribute-author/validate` | Configuration.swift:23; Service.swift:243-246 (local check only) | api/ApiTopicStateKeyController.java:153 `POST /state-keys/validate` (`TopicStateKeyRegisterDTO`), returns `{valid:true}` or code 400 + errorCode + problems | request shape for versioned definitions |
| `/api/topic/module-preflight` | Configuration.swift:26; Service.swift:26-29 GET topicId, scope, expectedConfigVersion | api/ApiTopicStateKeyController.java:243 `GET /publish-check` (topicId, scope); api/ApiTopicController.java:1512 `publish-draft` takes configVersion/registryVersion | module-level preflight with expectedConfigVersion |

(That is 3+3+3+2+1+4+1 = 17 rows; with D's 2 PARTIAL rows + `offer-withdrawal` the PARTIAL total is 19: 3 state + 3 edit + 3 activity + 2 author + 1 report-receipt + 4 attribute-author + 1 preflight = 17, plus knowledge-review/request and offer-withdrawal = 19.)

### F. /api/topic/cover* (6 rows) and /api/topic/detail (1) 

| iOS path | iOS site / types / method | nearest backend | Category |
|---|---|---|---|
| `/api/topic/cover` | App/OwnedTopicCoverCompositionRoute.swift:16 (GET prefix match :11-16) | NOT FOUND | MISSING |
| `/api/topic/cover/selection/current` | Core/OwnedTopicCoverClient.swift:44,77-81 GET + query | NOT FOUND | MISSING |
| `/api/topic/cover/upload` | Client:45,106-111 POST multipart/form-data, part `file` (`cover.jpg` JPEG) | NOT FOUND; generic upload `api/common/uploadOSS` is referenced by iOS fixtures (App/MerchantEngagementFixtureSupport.swift) but its controller not examined here → NOT FOUND in this pass | MISSING |
| `/api/topic/cover/selection` | Client:46,119 POST JSON (JSONEncoder sortedKeys) → `OwnedTopicCoverSelectionReceipt` (Contracts:90) | NOT FOUND | MISSING |
| `/api/topic/cover/selection/status` | Client:47 | NOT FOUND | MISSING |
| `/api/topic/cover/{}/content` | Core/OwnedTopicCoverContracts.swift:22 (`contentPath`), GET | NOT FOUND | MISSING |
| `/api/topic/detail` | App/PublishTopicAndCommentModerationSectionView.swift:78 — default string for a display/audit view model; only grep hit outside the file: none (`topicDetailEndpoint` unused elsewhere) | api/ApiTopicController.java:1919 `POST /info-to-user` (form `id`) and :2808 `info-to-merchant` | **ADAPTABLE** — change default at :78 to `api/topic/info-to-user`; no live call |

Backend task: B-4 for cover.

## Adaptation plan (ADAPTABLE rows)

Never loosen existing tests; extend them with the new path expectations.

**Group 1 — audit-constant re-pointing (one worker, 4 rows):** `Core/MerchantAndPublishAuthoringAudit.swift:115,117,119` (`poiDetailEndpoint`→`api/merchant/public-detail`, `shopApplyEndpoint`→`api/merchant/merchant_registration`, `merchantInsightEndpoint`→`api/ai/merchant/insight`), and `App/PublishTopicAndCommentModerationSectionView.swift:78` (`topicDetailEndpoint` default →`api/topic/info-to-user`). Check the Swift readers of those constants (`MerchantStoreParitySnapshot` :138-187, `MerchantDecorAndShopApplyWizardAudit.swift:10`) and update their assertions. Tests to extend: locate with `grep -rn "poiDetailEndpoint\|shopApplyEndpoint\|merchantInsightEndpoint\|topicDetailEndpoint" Tests`; add cases asserting the new strings, keep all old negative cases. Caveat: poi/detail and shop/apply need a product confirmation of semantics before merge.

**Group 2 — NPC voice revoke (1 row):** `Core/MerchantNPCHTTP.swift:28` (allowed-path list), `:85` (post path), and `Core/MerchantNPCAuthenticatedTransport.swift` path switch (`case "/api/merchant/npc/avatar/generate"` at :38 shows the switch to extend), `Core/MerchantBusinessMutation.swift:251` allow-list. Path `/api/merchant/npc/voice/revoke`→`/api/merchant/npc/voice/reset`; keep sending requestId (server ignores). Extend `Tests/*/MerchantNPCVoiceDeviceTests.swift` and `MerchantNPCFieldFlowTests.swift`.

**Group 3 — CRM fixture matcher (4 rows):** no Swift runtime change. Optionally normalise numeric ids in `App/MerchantEngagementFixtureSupport.swift` fixture keys; extend `MerchantEngagementFlowTests.swift`/`MerchantEngagementDetailOwnerTests.swift` only if the fixture is changed. Docs: teach the Appendix-A generator to treat `\d+` as `{}`.

## Backend tasks (MISSING / the missing half of PARTIAL)

- **B-1** Merchant authoring service: `ApiMerchantAuthoringController` (jobs create/get/cancel, drafts list/get, releases get/withdraw, public/environment/main-line read, draft-selection list/resolve, game-player read endpoints). Branch `cursor/w05-j-merchant-authoring` is referenced by iOS but absent from baseline. (17 rows)
- **B-2** City merchant value: report/result/events/benefit read APIs with scope+window+cursor and `errorCode` (rejected/stale/noPermission). (4 rows)
- **B-3** Merchant NPC: voice script, avatar generate/status, knowledge-review submit + request lookup by requestId. (5 rows, +1 PARTIAL)
- **B-4** Topic cover: upload (multipart), selection current/status/commit with receipt, content read. (6 rows)
- **B-5** Request/receipt layer (idempotent requestId + payload hash + read-back + post-processing resume) over topic create/update, project state change, activity create, template author, template report, attribute-author, offer-withdrawal, plus module-preflight with expectedConfigVersion. (19 PARTIAL rows)

## Not verified / limits

- No production verification; all rows deployment-pending-verification.
- HTTP verbs on iOS side verified from Swift code at the cited lines; Appendix-A verbs were not used.
- Per-route error-code tables were not found in these controllers beyond what is cited.
- `api/common/uploadOSS` backend location was not searched in this pass.
