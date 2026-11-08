# Gap-Closing Wave — Open Bugs & Test Findings

Recorded by GM-INT-G during gap-wave integration.

## Batch 1 (`cl-w5c`, `cl-w5d`, `cl-w6a`, `cl-w6b`)

### Bugs Exposed by New Tests and Fixed Small in Code
1. **`MerchantGalleryOversizeBlocksWriteTests.testTenImagesCannotBeReviewedOrSaved`** (`cl-w5c`):
   - **Exposed**: `MerchantOperationsCoordinator.prepare()` (`Core/MerchantOperationsReading.swift:240`) checked `guard canReview` before validating the draft, and `canReview` already requires `draft?.blocker == nil`, so calling `prepare()` on an oversize gallery (>9 images) silently returned with `issue == nil` instead of surfacing `.key("merchant.operations.invalidDraft")`.
   - **Fix**: In `MerchantOperationsCoordinator.prepare()`, set `issue = .key("merchant.operations.invalidDraft")` and return when `isCurrent && !isBusy && !isLocked && isDirty && draft?.blocker != nil`.
2. **`RoamStampExchangeServiceTests.testExchangePostsGivenStampIdAndShowsOnlyServerResult`** (`cl-w5c`):
   - **Exposed**: `RoamStampExchangeReceipt.init(from:)` (`Core/RoamExperienceMutationContracts.swift:168`) threw `APIError.malformedResponse` whenever `exchanged == true` and `stamp == nil`, even though `RoamStampSlip` (`Core/RoamSubpagePresentation.swift:296`) already handles `stamp == nil` safely (`got = stamp != nil`).
   - **Fix**: Relaxed `RoamStampExchangeReceipt.init(from:)` to `if exchanged, let stamp, !stamp.isVisible { throw APIError.malformedResponse }` so a present `stamp` is still validated for visibility while a bare `{"exchanged":true}` ack decodes cleanly.

### Open / Stale Pre-existing Bugs Noted by Lanes
- `pages/merchant/citynode/index` (`cl-w5c`): 5 assertions in `CityNodeRedemptionTests` are stale against the hardened exact-message contract (`CityNodeRedemptionExactContractTests` 4/4 pass on the current contract).
- `subpackageTools/monthly-recap/index` (`cl-w5c`): `RoamPassportToolsTests.testRecapRequestFieldsWeeksAndDuplicateCollapse` fixture has `routes.total = 4` with only 3 distinct items (`RoamMonthlyRecapContractTests` 3/3 pass with consistent fixtures).
