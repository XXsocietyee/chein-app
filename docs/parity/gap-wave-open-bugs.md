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

## Batch 3 (`cl-w7b`, `cl-w7c`, `cl-w8a`, `cl-w8b`)

### Bugs & Stale Tests Resolved by Lanes in Batch 3
1. **`subpackageMember/invoice-detail/index` & `subpackageMember/invoice/index` (`Core/InvoiceLaunchContracts.swift`, `cl-w7b`)**:
   - **Bug**: `InvoiceLaunchStatus` only knew 4 statuses (`SUBMITTED`, `ISSUED`, `REJECTED`, `CANCELLED`), so any row in back-office states (`CLAIMED`, `PROCESSING`, `ISSUE_UNKNOWN`, `PAUSED` from `UserInvoiceProcessingService`) caused the entire invoice list/detail JSON decode to fail.
   - **Fix**: Added the 4 back-office cases, `playerState`, `filterKey` (grouping `PAUSED` under the processing filter like mini `IN_TAB`), `labelKey`, and `noticeKey`. Verified by `InvoiceLaunchStatusTests` (2/2 pass) and `InvoiceLaunchHistoryRulesTests` (6/6 pass).
2. **`pages/addressinfo/addressinfo` (`ProfileParticipantValidationAppTests` & `ParticipantCoordinatorTests`, `cl-w7b`)**:
   - **Fix**: Updated `ParticipantFakeWriter.performReturningParticipant` and `ValidationStore.performReturningParticipant` to return a decoded `ProfileParticipant` on create, and updated stale `testParticipantsViewsConstructWithPurposeSubtitleKey` to assert 0 occurrences of the removed subtitle (matching mini commit `8173a5c66`). Verified by `ParticipantCoordinatorTests` (17/17 pass) and `ProfileParticipantValidationAppTests` (13/13 pass).
3. **`pages/deregister/index` (`AccountComplianceTests`, `AccountDeregistrationParityTests`, `AccountDeregistrationRebaseSafetyTests`, `cl-w7c`)**:
   - **Verified**: All 36 tests across `AccountComplianceTests` (13), `AccountDeregistrationParityTests` (5), and `AccountDeregistrationRebaseSafetyTests` (18) pass (0 failures) in `/private/tmp/gm-gap-batch3-core.log`.

### Open / Pre-existing Issues Noted in Batch 3
- `InvoiceLaunchCoordinatorTests.testUnknownApplyRecoversOriginalRequestAfterRestartWithoutWrite` (pre-existing, noted in `close-w7b.md`): throws `outcomeUnknown` at `Core/InvoiceLaunchCoordinator.swift:183` when recovering an unknown apply across restart.
- `ProfileGuideReadRouteTests` (pre-existing): 2 assertions on explicit null/empty object removal in `Tests/CoreTests/ProfileGuideReadRouteTests.swift` fail, while `ProfileGuideReadTests` (17/17 in AppUnit) and `ProfileGuideAbsentDetailProducerTests` (3/3 in Core) pass.
- `pages/play/index` (`cl-w8b`): mini `/api/club/topic-node-answer` and `/api/topic/host-node-answer` are governance answer reveal reads rather than player answer submissions; `StoryParticipationActionModel` keeps the writer gated until a reviewed player route is specified.
