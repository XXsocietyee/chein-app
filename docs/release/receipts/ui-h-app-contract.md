# ui/h-app-contract Receipt

## Base and Branch
- Branch: `ui/h-app-contract`
- Base: `origin/ui/h-r5-build` (`52d2e8f10`, since `origin/ui/h-integ-r6` is not pushed on origin)
- Source contract spec: `docs/delivery/backend-app-r2/APP-CONTRACT-FIXES.md` (`hengyin` branch `fix/api-smoke-4xx` @ `a67acd4c2`)

## Contract Fixes & Request-Shape Unit Tests
- Items 1–4 and prompt item 5 (`chapter-application/audit` keys `applicationId`, `approved`, `auditRemark`) from `52d2e8f10` were retained and their unit tests were strengthened to explicitly assert HTTP method, path, `Content-Type`/`Accept` headers, and body/query keys across:
  - `Tests/CoreTests/MerchantContentContractTests.swift` (5 NPC calls + `chapter-application/audit`)
  - `Tests/CoreTests/OwnerDecisionGuardTests.swift` (`saveAccount()` `.notSent` + `account()` request shape)
  - `Tests/CoreTests/WorkshopPurchasedV2PathTests.swift` (`api/workshop/v2/purchased/{list,detail}` form content type & payload)
  - `Tests/CoreTests/RewardPledgeTests.swift`, `Tests/CoreTests/NativeChannelManagementRuntimeGateTests.swift`, `Tests/CoreTests/NativeFriendChannelInviteRecoveryTests.swift`, `Tests/CoreTests/NativeFriendTeamInviteRecoveryTests.swift` (templated/concrete route constants and request shapes)
- Section 5 (`POST /api/ai/theme/draft` -> `400 AI_DRAFT_PREPARE_REQUIRED`) migrated to V2 prepare-then-execute flow (`POST api/ai/theme/draft/prepare` -> `POST api/ai/theme/draft/execute` -> `GET api/ai/theme/draft/request`):
  - `Core/PublishModesContracts.swift`: `PublishingContracts.aiThemeDraft` targets `api/ai/theme/draft/prepare` (`prepareKey`, `idea`, optional `productType`) and adds `aiThemeDraftExecute(requestID:)` targeting `api/ai/theme/draft/execute`.
  - `Core/BusinessRuntimeConfiguration.swift`: `.publishingAITheme` allowlists `["api/ai/theme/draft/prepare", "api/ai/theme/draft/execute"]`.
  - `Core/PublishingAIRuntimeFactory.swift`: `PublishingAIRuntimeTransport.validates` enforces V2 prepare and execute request shapes for `.publishingAITheme`.
  - `Core/PublishingAuxiliaryService.swift`: `.theme` and `.themeForProduct` require prepare+execute approval grants and execute the 2-phase prepare -> execute flow.
  - `Core/MerchantNPCKnowledgeAuthorFlow.swift` & `Core/MerchantNPCOriginalDraftWriter.swift`: `isThemeDraftRequestID` accepts UUID or `td2_<32hex>`, and `MerchantNPCOriginalDraftWriter` executes V2 `prepare` -> `execute` before calling `MerchantNPCThemeDraftRequestRead`.
  - Unit tests updated in `Tests/CoreTests/PublishingAuxiliaryTests.swift`, `Tests/CoreTests/PublishingAIDraftFlowTests.swift`, `Tests/CoreTests/PublishingAIRuntimeTests.swift`, and `Tests/CoreTests/MerchantNPCOriginalDraftWriterTests.swift`.

## Pin & Fixture Updates
- `Tests/ContractChecks/test_merchant_station_submission_import.py`: updated `PROTECTED['Core/BusinessRuntimeConfiguration.swift']` SHA-256 to `7be293486c3f9f1d1dec23f9d9c7684829e00486003c4f1615e82e139d35f8d8` after updating `.publishingAITheme` allowlist routes.
- `Tests/ContractChecks/test_merchant_npc_knowledge_author_flow.py`: updated `test_original_draft_writer_submits_then_reads_returned_id_and_does_not_publish` assertions to verify the V2 prepare + execute + request contract (no assertions deleted).
- `Tests/ContractChecks/fixtures/backend_route_status.csv`: replaced `POST,api/ai/theme/draft` with `POST,api/ai/theme/draft/prepare,MATCH` and `POST,api/ai/theme/draft/execute,MATCH`.
