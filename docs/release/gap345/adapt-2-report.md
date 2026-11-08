# ADAPT-2 report (merchant / topic ADAPTABLE rows)

Branch `cloud/adapt-2` from `wip/wave4-final`. Not compiled (no Swift toolchain); every symbol was grepped.
**Backend baseline caveat:** the doc names `hengyin@4ac8c249`, but that object does not exist in the provided hengyin checkout (detached at `147754ba`, master). Routes below were re-verified against that checkout instead. All rows stay deployment-pending-verification.

## Re-verified routes (`chengyinhub-admin/.../controller/api/`)
| Route | Source | Result |
|---|---|---|
| `POST /api/ai/merchant/insight` | ApiAiController:47,404 | confirmed, no params |
| `POST /api/merchant/public-detail` | ApiMerchantController:93,444 | confirmed, JSON `MmsMerchant`, only `id` read. **Doc correction:** the anonymous GET variant is `/api/merchant/ops/public-detail` (ApiMerchantOpsController:15,36), not `/api/merchant/public-detail` |
| `POST /api/merchant/merchant_registration` | ApiMerchantController:2009 | confirmed, JSON `@Validated MerchantRegistrationDTO`, token |
| `POST /api/topic/info-to-user` | ApiTopicController:83,1919 | confirmed, form `id`; guest-readable |
| `POST /api/merchant/npc/voice/reset` | ApiMerchantController:1027 | confirmed, **no body/params**, PROFILE_WRITE; idempotent when no NPC (`"已清除"`), else single conditional update, failure `error("声音未清除，请重试")` |

## Per group
- **Group 1 (audit constants, 4 rows): PARTIAL - mapping delivered as a new adapter, existing constants NOT re-pointed.** The doc undercounts the surface: the legacy strings live in three duplicate constant sets (`Core/MerchantAndPublishAuthoringAudit.swift`, `Core/MerchantDecorAndShopApplyWizardAudit.swift`, `App/MerchantDecorAndShopApplyWizardSectionView.swift` canonical*), plus `App/PublishTopicAndCommentModerationSectionView.swift:78/97`, pinned by `Tests/CoreTests/MerchantDecorAndShopApplyWizardAuditTests.swift` and the route ledger CSV. Editing them without a compiler risks breaking pinned tests; `poi/detail` semantics also still need product confirmation. New: `Adapt2MerchantTopicRoute.legacyReplacements` + request builders (`Core/Adapt2MerchantTopicRoutes.swift`). Live code already calls `api/ai/merchant/insight` and `api/topic/info-to-user`.
- **Group 2 (voice revoke -> reset): DONE as new dormant client** `Adapt2MerchantNPCVoiceResetClient` (gate defaults OFF; sends bodyless POST with raw token; `requestID` not sent because the controller reads none). Existing `MerchantNPCHTTP`/`MerchantNPCAuthenticatedTransport`/`MerchantBusinessMutation` allow-lists unchanged, because `Tests/ContractChecks/check_merchant_npc.py` and `test_merchant_public_production.py` pin the revoke path / its absence. Switching callers over is not done.
- **Group 3 (CRM fixture rows): no runtime change, as planned.** Docs-only matcher fix is not in this repo; not done.
- All MISSING/PARTIAL rows: not done.

## Tests
`Tests/AppUnitTests/Adapt2MerchantTopicRoutesTests.swift` (9 tests; fixtures are the controllers' `AjaxResult` shapes). No existing test touched.

## Unverified / follow-ups
- Nothing compiled or run. The new App test file and `Core/Adapt2MerchantTopicRoutes.swift` are **not registered in `Questify.xcodeproj/project.pbxproj`** (hand-editing avoided); add them in Xcode. The Core file is picked up by the SwiftPM `Core` target automatically.
- `MerchantRegistrationDTO` field names not mapped; the builder takes caller-supplied JSON.
- AjaxResult error `code` of 500 in test fixtures is the usual convention, not read from `AjaxResult`.
- Production deployment of these routes unverified.
