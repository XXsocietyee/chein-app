# ADAPT-4 report — city-play ADAPTABLE rows

Branch `cloud/adapt-4` (from `wip/wave4-final`). Backend source re-read at `hengyin@4ac8c249fcad69e4f9c423702711d46deca2755a` (detached, read-only; the local checkout initially sat at 147754ba and the pinned commit was fetched before use). Nothing pushed to hengyin. Production version UNVERIFIED (`deployment-pending-verification`). I cannot compile Swift here: **none of the new tests have been run**.

Result: all 4 ADAPTABLE rows are already wired to the correct backend route. No production code changed. Work = re-verification + new deterministic tests + this documentation.

## Per row

| Row | Re-verified against | Status |
|---|---|---|
| `/api/city/nodes/complete` | `ApiCityNodeController.complete` — `POST /api/city/nodes/{id}/complete`, params `Double lat, Double lng, String answer, photoUrl, code` unannotated (no `@RequestBody`, so form/multipart or query binding). Success `AjaxResult.success("完成"/"你已完成过该据点", {couponId, needRedeem, alreadyClaimed?, poiId?, completed?, badgeCode?, badgeName?, hint?})`; errors are `error(msg)` = code 500 inside HTTP 200. Auth: `uid()`, "请先登录" if absent. | Already wired (`RoamService.completeNode` → `RoamExperienceMutation.completeNode`, multipart via `AuthRequestBuilder.makeFormRequest`). Row exists only because AppSession/AppCompositionRoot use the normalized approval key `api/city/nodes/complete`. **Not changed.** Note: the already-claimed branch omits `poiId`; `RoamNodeCompletion` treats it as optional — pinned by a new test. |
| `/api/city/nodes/favorite` | `ApiCityNodeController.favorite` — `POST /api/city/nodes/{id}/favorite`, no body, success `{favorited: Bool}`, errors code 500 ("请先登录", "参数不合规", "据点未开放或已下线"). | Already wired (`RoamService.toggleFavorite`, `includesBody:false`). Approval-key label only. **Not changed.** |
| `/api/npc/chat/delete` | `ApiAiNpcController` (`/api/ai/npc`) `POST /chat/data/delete`, `@RequestBody(required=false) Map<String,String>`; absent/blank `requestId` → plain delete `{deleted:n}`; with `requestId` → receipt-idempotent path. | Live call `NPCChatLogDeletion.path = api/ai/npc/chat/data/delete` already correct (POST JSON `{}`). **Label rename NOT done**: the plan asks to rename `/api/npc/chat/delete` in `NPCChatAndSceneAISafetyAudit`, `RegionalHighRiskWriteRoute.npcChatDelete` and the section view, but existing tests pin that exact string (`NPCChatAndSceneAISafetyAuditTests:20`, `RegionalEndpointAllowlistAuditTests:12,:162`, `RegionalEndpointAllowlistSectionViewTests:30`) and the rules forbid altering existing tests; the string is also a regional fail-closed denylist key. Documented only; a future owner-approved change would need to update those tests in one commit. |
| `/api/official/v2/events` | `ApiOfficialEventController.v2PublishCheck` — `GET /api/official/v2/events/{id}/publish-check`; data = `OfficialEventV2PublishCheck` `{blockers, risks, pass}` plus `warnings`/`results` only when tiering enabled; no-permission = code 500 "无权查看该活动发布检查". | Already exact (`OfficialOrganizer.swift:197`). Extra tier fields ignored by iOS. **Not changed.** |

## Tests added (Tests/AppUnitTests, `@testable import Questify`, no QuestifyCore import, fixtures copied from controller/DTO shapes)
- `Adapt4RoamPOIBackendShapeTests` — complete: coupon / badge+null coupon / already-claimed (no poiId) / code-500 rejection; multipart field names `lat,lng,answer,photoUrl,code`, not JSON, id only in path; favorite on/off, no body/no Content-Type, offline-node rejection; non-positive id never sent.
- `Adapt4NPCChatDeleteShapeTests` — live path constant vs. audit label (documents the intentional difference); `{deleted:n}` incl. confirmed zero; code-500 → `.rejected`; missing/negative count → `.unknown`.
- `Adapt4OfficialPublishCheckShapeTests` — GET path/no query/no body/Authorization; legacy and tiered DTO shapes; clean pass; code-500 denial message; id ≤ 0 not sent.

## Rule compliance
Safety gates OFF and `reviewed:nil` untouched; no approvals/leases; nothing wired into AppSession/AppCompositionRoot/QuestifyApp; no allowlist changes; no mock data in production paths; no secrets; no Resources/xcstrings edits (see `adapt-4-new-strings.md`: none); no existing test modified.

## Not done / unverified
- Label rename for `/api/npc/chat/delete` (see above) — deliberately skipped.
- Not run: no Swift toolchain in this environment. Symbols were grepped (`RoamService`, `RoamDeviceFix`, `RoamCoordinate`, `RoamActionFailure`, `NPCChatLogDeletion.decode`, `NPCChatDataFailure`, `OfficialOrganizerHTTPAccess`, `OfficialOrganizerFailure`) but compile/run status is unconfirmed.
- Backend multipart binding for unannotated params is inferred from Spring conventions, not from a backend test; production behaviour UNVERIFIED.
- Only the 4 ADAPTABLE rows were in scope; the 22 PARTIAL / 22 MISSING rows were not touched — the source proves no equivalent for them (no `/api/city-game/*`, `/api/city-value/*`; `/api/game/session/*` is activity-scoped).
