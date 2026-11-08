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

## Batch 2 (`cl-w5a`, `cl-w5b`, `cl-w6c`, `cl-w7a`)

### Bugs & Stale Tests Resolved by Lanes in Batch 2
1. **`MerchantCoopPlazaDenialTests`** (`cl-w6c`):
   - Fixture granted only `merchant:marketing:read`, whereas `MerchantContentService.access` also requires `merchant:project:manage` for `.recruiting` queries. Fixed in `Tests/AppUnitTests/MerchantCoopPlazaDenialTests.swift` and verified with `MerchantCoopCenterAccessGateTests` (5/5 pass).
2. **`ParticipantCoordinatorTests` / `ParticipantCoordinatorSnapshotLifetimeTests` / `ProfileParticipantValidationAppTests`** (`cl-w7a`):
   - Test fakes only implemented `perform` (returning `nil` row) for creates, which `ParticipantCoordinator.confirm()` rightly treats as outcome-unknown. Updated fakes to implement `performReturningParticipant` and inverted the stale nil-ack assertion (`testNilCreateAcknowledgmentIsOutcomeUnknownWithoutInventingReturnedRow`).

### Open Contract Mismatch Noted by Lanes
- `pages/club/topic-detail/index` (`cl-w6c`): mini-program `confirmEndTopic` sends `cancellationEpoch` with `clubId`/`topicId` and expects `cancellationState`/`sessionTotal`/`cancelledSessions`/`closedPendingOrders`, whereas `Core/ClubGovernanceCommands.swift` (`.endTopic`) and `ClubGovernanceService.swift:161` currently validate only `refundedOrders`/`manualOrders`/`failedSessions`. (`ClubTopicEndSummary` added and tested 6/6; command shape left unchanged to preserve `ClubGovernanceContractTests` while the write is gated.)
