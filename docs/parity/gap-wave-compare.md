# Gap-Wave vs Pre-Wave AppUnit Comparison (11 Candidate Classes)

## Trees & Run Metadata

- **PRE-WAVE tree**: `/private/tmp/gm-reg-prewave`
  - Commit: `29956c06e8143b6d558f396f820dc8dbba3c3032` (`origin/wip/gm-int`, `Merge remote-tracking branch 'origin/wip/gm-test4' into gm-int`, clean working tree)
  - Simulator: `Questify-iPhone17-Lane2` (`AppleLocale = zh-Hans_US`)
  - Log: `/private/tmp/gm-cmp-pre.log` (`TEST_EXIT=65`)
- **GAP-WAVE (NOW) tree**: `/Users/fanning/orca/workspaces/native-ios/GM-INT-rc2`
  - Branch / Commit: `gm-aud` (`origin/wip/gm-reg` tip) `70e7e58a72cf4a14dfa29f0d9d2eb704c341ef9f` (`fix(invoice-tests): stale fail-closed example and recovery fixture; add gap-wave-regressions.md`, clean working tree)
  - Simulator: `Questify-iPhone17-W2` (`AppleLocale = en_US`)
  - Log: `/private/tmp/gm-cmp-now.log` (`TEST_EXIT=65`, rebuilt under global lock in `/private/tmp/gm-cmp-now.log.build.log` with `BUILD_EXIT=0`)

## Exact Overall Summary Lines

### PRE-WAVE (`/private/tmp/gm-cmp-pre.log`)
```text
Test Suite 'QuestifyAppUnitTests.xctest' failed at 2026-11-07 20:14:24.150.
	 Executed 115 tests, with 46 failures (14 unexpected) in 13.527 (13.566) seconds
Test Suite 'Selected tests' failed at 2026-11-07 20:14:24.150.
	 Executed 115 tests, with 46 failures (14 unexpected) in 13.527 (13.569) seconds
```

### GAP-WAVE / NOW (`/private/tmp/gm-cmp-now.log`)
```text
Test Suite 'QuestifyAppUnitTests.xctest' failed at 2026-11-07 20:14:17.731.
	 Executed 115 tests, with 43 failures (13 unexpected) in 4.738 (4.771) seconds
Test Suite 'Selected tests' failed at 2026-11-07 20:14:17.731.
	 Executed 115 tests, with 43 failures (13 unexpected) in 4.738 (4.772) seconds
```

## Verdict Summary Across All 115 Tests (11 Classes)

- **Total test methods executed**: 115
- **PASS** (pass on PRE, pass on NOW): **78 tests**
- **PRE-EXISTING** (fail on PRE, fail on NOW): **34 tests** (42 XCTest assertion/error failures on both runs)
- **FIXED** (fail on PRE, pass on NOW): **2 tests** (4 XCTest failures on PRE -> 0 on NOW)
  1. `RoamPassportServerHistoryHostTests.testBackgroundDiscardsPresentationAndForegroundRequiresExplicitFreshRead`
  2. `RoamPrivatePageHostRecoveryTests.testActualGrantWithdrawalHidesDetailThenRestorationReadsOnlyOriginalList`
- **REGRESSION** (pass on PRE, fail on NOW): **1 test** (0 XCTest failures on PRE -> 1 on NOW)
  1. `StoryWalkingFogAndWorkshopUpgradeViewTests.testWorkshopModUpgradeSheetViewInstantiatesBreakingAndCompatibleDiffWithConfirmationGate`
     - **Root-cause note**: `git diff 29956c06..70e7e58a` is empty for `Tests/AppUnitTests/StoryWalkingFogAndWorkshopUpgradeViewTests.swift`, `App/WorkshopModUpgradeSheetView.swift`, and `Core/WorkshopModUpgradePresentation.swift`. The test calls `WorkshopModUpgradePresentation(term: term, preview: breakingPreview)` with default `locale: Locale = .current` and asserts `breakingPresentation.pinnedExistingRunsNotice.contains("固定保持原版本")` at line 158. `Questify-iPhone17-Lane2` (PRE) has `AppleLocale = zh-Hans_US` (producing Chinese copy), whereas `Questify-iPhone17-W2` (NOW) has `AppleLocale = en_US` (producing English copy `"Published versions and active runs stay on their original version (1.0.0)..."`).

## Per-Class Summary

| Class | Tests | PRE Result (failing methods / XCTest failures) | NOW Result (failing methods / XCTest failures) | PRE Exact `Executed` Line | NOW Exact `Executed` Line | Class Verdict |
|---|---:|---|---|---|---|---|
| `CouponRuntimeCompositionTests` | 20 | FAIL (15/20 methods) | FAIL (15/20 methods) | `Executed 20 tests, with 22 failures (0 unexpected) in 0.316 (0.321) seconds` | `Executed 20 tests, with 22 failures (0 unexpected) in 0.235 (0.239) seconds` | **PRE-EXISTING** |
| `MerchantReviewOriginalRecoveryEntryTests` | 11 | FAIL (11/11 methods) | FAIL (11/11 methods) | `Executed 11 tests, with 11 failures (11 unexpected) in 0.022 (0.025) seconds` | `Executed 11 tests, with 11 failures (11 unexpected) in 0.012 (0.014) seconds` | **PRE-EXISTING** |
| `ClubCommunityLifecycleTests` | 3 | FAIL (2/3 methods) | FAIL (2/3 methods) | `Executed 3 tests, with 3 failures (0 unexpected) in 0.013 (0.014) seconds` | `Executed 3 tests, with 3 failures (0 unexpected) in 0.011 (0.012) seconds` | **PRE-EXISTING** |
| `ClubCommunityReadCompositionTests` | 3 | FAIL (2/3 methods) | FAIL (2/3 methods) | `Executed 3 tests, with 2 failures (0 unexpected) in 0.014 (0.015) seconds` | `Executed 3 tests, with 2 failures (0 unexpected) in 0.008 (0.009) seconds` | **PRE-EXISTING** |
| `ApprovedReleaseOriginalRecoveryTests` | 22 | FAIL (2/22 methods) | FAIL (2/22 methods) | `Executed 22 tests, with 2 failures (0 unexpected) in 1.590 (1.601) seconds` | `Executed 22 tests, with 2 failures (0 unexpected) in 1.356 (1.364) seconds` | **PRE-EXISTING** |
| `ApprovedTopicReviewCompositionTests` | 16 | FAIL (1/16 methods) | FAIL (1/16 methods) | `Executed 16 tests, with 1 failure (1 unexpected) in 0.345 (0.349) seconds` | `Executed 16 tests, with 1 failure (1 unexpected) in 0.282 (0.286) seconds` | **PRE-EXISTING** |
| `ClubOrdinaryAdmissionCompositionTests` | 2 | FAIL (1/2 methods) | FAIL (1/2 methods) | `Executed 2 tests, with 1 failure (1 unexpected) in 0.003 (0.004) seconds` | `Executed 2 tests, with 1 failure (1 unexpected) in 0.003 (0.004) seconds` | **PRE-EXISTING** |
| `ProfileGuideReadTests` | 17 | PASS | PASS | `Executed 17 tests, with 0 failures (0 unexpected) in 0.952 (0.958) seconds` | `Executed 17 tests, with 0 failures (0 unexpected) in 0.406 (0.410) seconds` | **PASS** |
| `RoamPassportServerHistoryHostTests` | 8 | FAIL (1/8 methods) | PASS | `Executed 8 tests, with 2 failures (0 unexpected) in 5.394 (5.397) seconds` | `Executed 8 tests, with 0 failures (0 unexpected) in 1.099 (1.102) seconds` | **FIXED** |
| `RoamPrivatePageHostRecoveryTests` | 10 | FAIL (1/10 methods) | PASS | `Executed 10 tests, with 2 failures (1 unexpected) in 4.838 (4.840) seconds` | `Executed 10 tests, with 0 failures (0 unexpected) in 1.290 (1.293) seconds` | **FIXED** |
| `StoryWalkingFogAndWorkshopUpgradeViewTests` | 3 | PASS | FAIL (1/3 methods) | `Executed 3 tests, with 0 failures (0 unexpected) in 0.040 (0.041) seconds` | `Executed 3 tests, with 1 failure (0 unexpected) in 0.037 (0.037) seconds` | **REGRESSION (simulator locale `en_US` vs `zh-Hans_US`)** |

## Per-Test Results (All 115 Tests)

| Class | Test | PRE Result | NOW Result | Verdict | Failure Details |
|---|---|---|---|---|---|
| `CouponRuntimeCompositionTests` | `testActualCouponFixtureNormalSessionReachesMarketingHomeInEveryMode` | FAIL (0.073s) | FAIL (0.056s) | **PRE-EXISTING** | (7x) L326: XCTAssertEqual failed: ("nil") is not equal to ("Optional(710)") - ready; L326: XCTAssertEqual failed: ("nil") is not equal to ("Optional(710)") - readOnly; L326: XCTAssertEqual failed: ("nil") is not equal to ("Optional(710)") - unknown; L326: XCTAssertEqual failed: ("nil") is not equal to ("Optional(710)") - revokeOnConfirm; L326: XCTAssertEqual failed: ("nil") is not equal to ("Optional(710)") - commandUnknown; L326: XCTAssertEqual failed: ("nil") is not equal to ("Optional(710)") - commandReadOnly; L326: XCTAssertEqual failed: ("nil") is not equal to ("Optional(710)") - commandNotFound |
| `CouponRuntimeCompositionTests` | `testActualFixtureCouponRevocationPreservesRecruitingButStillDeniesCouponWrite` | FAIL (0.012s) | FAIL (0.009s) | **PRE-EXISTING** | L336: XCTUnwrap failed: expected non-nil value of type "CouponManagementReview" |
| `CouponRuntimeCompositionTests` | `testCanonicalReadClonesAndAdjacentRoutesStayClosed` | PASS (0.013s) | PASS (0.008s) | PASS | — |
| `CouponRuntimeCompositionTests` | `testFinalPreNetworkBarrierRechecksExpiredWriteLease` | PASS (0.052s) | PASS (0.021s) | PASS | — |
| `CouponRuntimeCompositionTests` | `testFreshExplicitPermissionAndMerchantScopeAtReviewAndConfirm` | FAIL (0.009s) | FAIL (0.009s) | **PRE-EXISTING** | L72: XCTUnwrap failed: expected non-nil value of type "CouponManagementReview" |
| `CouponRuntimeCompositionTests` | `testLateReadSuccessAndErrorSuppressedAcrossIdentityAndLeaseChanges` | PASS (0.015s) | PASS (0.013s) | PASS | — |
| `CouponRuntimeCompositionTests` | `testLateWriteSuccessAndFailureRemainUnknownAfterRoleABAOrLeaseRevocation` | FAIL (0.008s) | FAIL (0.007s) | **PRE-EXISTING** | L30: XCTUnwrap failed: expected non-nil value of type "CouponManagementReview" |
| `CouponRuntimeCompositionTests` | `testMalformedSuccessUnknownAndAcknowledgedReadbackFailureNeverRetry` | FAIL (0.007s) | FAIL (0.007s) | **PRE-EXISTING** | L30: XCTUnwrap failed: expected non-nil value of type "CouponManagementReview" |
| `CouponRuntimeCompositionTests` | `testMissingReadOrWriteLeaseAndArbitraryDormantTransportCannotWrite` | FAIL (0.019s) | FAIL (0.017s) | **PRE-EXISTING** | L52: XCTAssertEqual failed: ("0") is not equal to ("1") |
| `CouponRuntimeCompositionTests` | `testNormalSessionCreateAndStopReadbackWithoutAISubscription` | FAIL (0.008s) | FAIL (0.008s) | **PRE-EXISTING** | L30: XCTUnwrap failed: expected non-nil value of type "CouponManagementReview" |
| `CouponRuntimeCompositionTests` | `testPerActionLeasesDenyOtherActionWithoutCreatingPendingRecord` | FAIL (0.007s) | FAIL (0.007s) | **PRE-EXISTING** | L237: XCTUnwrap failed: expected non-nil value of type "CouponManagementReview" |
| `CouponRuntimeCompositionTests` | `testPostcommitCode500RetainsOriginalPublicationLockAcrossRestart` | FAIL (0.007s) | FAIL (0.007s) | **PRE-EXISTING** | L30: XCTUnwrap failed: expected non-nil value of type "CouponManagementReview" |
| `CouponRuntimeCompositionTests` | `testRevocationAfterJournalAcquirePreventsDispatchAndRetainsRecord` | FAIL (0.007s) | FAIL (0.007s) | **PRE-EXISTING** | L30: XCTUnwrap failed: expected non-nil value of type "CouponManagementReview" |
| `CouponRuntimeCompositionTests` | `testRevokedWriteLeaseLeavesIndependentReadCapabilityUsable` | FAIL (0.013s) | FAIL (0.007s) | **PRE-EXISTING** | L30: XCTUnwrap failed: expected non-nil value of type "CouponManagementReview" |
| `CouponRuntimeCompositionTests` | `testStopRequiresFreshPermissionAndUnchangedOwnedStatus` | FAIL (0.007s) | FAIL (0.005s) | **PRE-EXISTING** | L85: XCTUnwrap failed: expected non-nil value of type "CouponManagementReview" |
| `CouponRuntimeCompositionTests` | `testUnknownPersistsAcrossDiskReopenLogoutAndDuplicateCoordinators` | FAIL (0.008s) | FAIL (0.007s) | **PRE-EXISTING** | L30: XCTUnwrap failed: expected non-nil value of type "CouponManagementReview" |
| `CouponRuntimeCompositionTests` | `testV1FinalBoundaryRevocationRetainsJournalWithoutDispatch` | PASS (0.019s) | PASS (0.015s) | PASS | — |
| `CouponRuntimeCompositionTests` | `testV1NormalCompositionPersistsThenReadOnlyRecoveryAfterRestart` | FAIL (0.009s) | FAIL (0.007s) | **PRE-EXISTING** | L30: XCTUnwrap failed: expected non-nil value of type "CouponManagementReview" |
| `CouponRuntimeCompositionTests` | `testV1OwnerReadIsNotGrantedByLegacyLeaseOrCouponPermissionAlone` | FAIL (0.020s) | FAIL (0.015s) | **PRE-EXISTING** | (2x) L277: XCTAssertNotNil failed; L276: XCTAssertEqual failed: ("nil") is not equal to ("Optional(Questify.CouponManagementError.forbidden)") |
| `CouponRuntimeCompositionTests` | `testV1ReceiptCloneDiscardsLateResponseWhenCapabilityRevoked` | PASS (0.002s) | PASS (0.002s) | PASS | — |
| `MerchantReviewOriginalRecoveryEntryTests` | `testAllThreeOriginalActionsReadExactReceiptWithoutCompleting` | FAIL (0.005s) | FAIL (0.003s) | **PRE-EXISTING** | L96: failed: caught error: "invalidConfiguration" |
| `MerchantReviewOriginalRecoveryEntryTests` | `testChangedAccountAuthorizationOrJournalCannotBorrowOriginalView` | FAIL (0.002s) | FAIL (0.001s) | **PRE-EXISTING** | L96: failed: caught error: "invalidConfiguration" |
| `MerchantReviewOriginalRecoveryEntryTests` | `testDepartureDuringAccessPreventsReceiptDispatchAndLatePublication` | FAIL (0.002s) | FAIL (0.001s) | **PRE-EXISTING** | L96: failed: caught error: "invalidConfiguration" |
| `MerchantReviewOriginalRecoveryEntryTests` | `testDepartureDuringReceiptCannotAffectReopenedVisit` | FAIL (0.002s) | FAIL (0.001s) | **PRE-EXISTING** | L96: failed: caught error: "invalidConfiguration" |
| `MerchantReviewOriginalRecoveryEntryTests` | `testGrantRevocationHidesExistingResultAndNewVisitRequiresFreshRead` | FAIL (0.003s) | FAIL (0.001s) | **PRE-EXISTING** | L96: failed: caught error: "invalidConfiguration" |
| `MerchantReviewOriginalRecoveryEntryTests` | `testHistoricalOrDuplicateIntentNeverConstructsReadCapability` | FAIL (0.001s) | FAIL (0.001s) | **PRE-EXISTING** | L96: failed: caught error: "invalidConfiguration" |
| `MerchantReviewOriginalRecoveryEntryTests` | `testMissingHostGrantIssuesNoHTTPAndKeepsIntent` | FAIL (0.001s) | FAIL (0.001s) | **PRE-EXISTING** | L96: failed: caught error: "invalidConfiguration" |
| `MerchantReviewOriginalRecoveryEntryTests` | `testReadFailureRetryDoesNotWriteOrReuseOldAppliedResult` | FAIL (0.001s) | FAIL (0.001s) | **PRE-EXISTING** | L96: failed: caught error: "invalidConfiguration" |
| `MerchantReviewOriginalRecoveryEntryTests` | `testServerPermissionDenialCannotShowAppliedAndRetainsIntent` | FAIL (0.001s) | FAIL (0.001s) | **PRE-EXISTING** | L96: failed: caught error: "invalidConfiguration" |
| `MerchantReviewOriginalRecoveryEntryTests` | `testSourceOwnerIdentityAndRetiredQueuedReadAreFenced` | FAIL (0.002s) | FAIL (0.001s) | **PRE-EXISTING** | L96: failed: caught error: "invalidConfiguration" |
| `MerchantReviewOriginalRecoveryEntryTests` | `testUnknownDoesNotBecomeCurrentStateOrReleaseLock` | FAIL (0.002s) | FAIL (0.001s) | **PRE-EXISTING** | L96: failed: caught error: "invalidConfiguration" |
| `ClubCommunityLifecycleTests` | `testIdentityInvalidationStillRemovesPrivatePosts` | PASS (0.006s) | PASS (0.005s) | PASS | — |
| `ClubCommunityLifecycleTests` | `testSuspendingDiscardsUnreviewedDraftAndAllowsFreshRead` | FAIL (0.005s) | FAIL (0.005s) | **PRE-EXISTING** | L33: XCTAssertEqual failed: ("nil") is not equal to ("Optional([20, 21])") |
| `ClubCommunityLifecycleTests` | `testSuspendingNavigationKeepsThePostThatOwnsTheDestination` | FAIL (0.002s) | FAIL (0.002s) | **PRE-EXISTING** | (2x) L9: XCTAssertEqual failed: ("nil") is not equal to ("Optional([20, 21])"); L11: XCTAssertEqual failed: ("nil") is not equal to ("Optional([20, 21])") |
| `ClubCommunityReadCompositionTests` | `testApprovedReadCompositionReadsWithoutEnablingWritesAndRevokesImmediately` | FAIL (0.003s) | FAIL (0.003s) | **PRE-EXISTING** | L95: XCTAssertEqual failed: ("nil") is not equal to ("Optional(12)") |
| `ClubCommunityReadCompositionTests` | `testDefaultCompositionFallsBackToDormantAndNeverEnablesWrites` | PASS (0.001s) | PASS (0.001s) | PASS | — |
| `ClubCommunityReadCompositionTests` | `testHostAppCompositionRootAndRuntimeDetailToListReturnFlow` | FAIL (0.011s) | FAIL (0.005s) | **PRE-EXISTING** | L173: XCTUnwrap failed: expected non-nil value of type "ClubCommunityPost" |
| `ApprovedReleaseOriginalRecoveryTests` | `testBackgroundAndLeavePreserveJournalAndInvalidateOldReader` | FAIL (1.204s) | FAIL (1.217s) | **PRE-EXISTING** | L268: XCTAssertEqual failed: ("["project-editor.v1.MTc6b3JpZ2luYWwtcmVjb3Zlcnk6Nzp0b3BpYzo3OTAx": 1507 bytes, "approved-topic-release.v1.MTc6b3JpZ2luYWwtcmVjb3Zlcnk6Nzo3OTAx": 1592 bytes]") is not equal to ("["approved-topic-release.v1.MTc6b3JpZ2luYWwtcmVjb3Zlcnk6Nzo3OTAx": 1592 bytes]") |
| `ApprovedReleaseOriginalRecoveryTests` | `testCloseReopenOldBindingsAndResultCoverCannotDestroySuccessor` | PASS (0.202s) | PASS (0.009s) | PASS | — |
| `ApprovedReleaseOriginalRecoveryTests` | `testFrozenEditorCanReadOriginalStatusWithoutEditingOrPrepareAuthority` | PASS (0.036s) | PASS (0.009s) | PASS | — |
| `ApprovedReleaseOriginalRecoveryTests` | `testHistoryInspectsCapturedRecordsButStatusUsesOnlyLatestOriginalSnapshot` | PASS (0.011s) | PASS (0.012s) | PASS | — |
| `ApprovedReleaseOriginalRecoveryTests` | `testKnownReceiptAndCapturedSummarySurviveFailedLatestRead` | PASS (0.006s) | PASS (0.007s) | PASS | — |
| `ApprovedReleaseOriginalRecoveryTests` | `testLateOldCallbackCannotPersistOrCloseNewPresentation` | PASS (0.005s) | PASS (0.006s) | PASS | — |
| `ApprovedReleaseOriginalRecoveryTests` | `testLocalDraftIDWithoutAcceptedSnapshotOrStrictAckCannotChooseTopic` | PASS (0.003s) | PASS (0.001s) | PASS | — |
| `ApprovedReleaseOriginalRecoveryTests` | `testMerchantOwnerIsRejected` | PASS (0.001s) | PASS (0.001s) | PASS | — |
| `ApprovedReleaseOriginalRecoveryTests` | `testMissingSourceOrJournalCannotOfferRecovery` | PASS (0.001s) | PASS (0.001s) | PASS | — |
| `ApprovedReleaseOriginalRecoveryTests` | `testRecoveryCatalogUsesAppEnglishAndSimplifiedChineseLocales` | PASS (0.004s) | PASS (0.005s) | PASS | — |
| `ApprovedReleaseOriginalRecoveryTests` | `testRestartReopensOriginalDurableIntentWithoutReplayOrMigration` | FAIL (0.018s) | FAIL (0.011s) | **PRE-EXISTING** | L275: XCTAssertEqual failed: ("["project-editor.v1.MTc6b3JpZ2luYWwtcmVjb3Zlcnk6Nzp0b3BpYzo3OTAx": 1507 bytes, "approved-topic-release.v1.MTc6b3JpZ2luYWwtcmVjb3Zlcnk6Nzo3OTAx": 1592 bytes]") is not equal to ("["approved-topic-release.v1.MTc6b3JpZ2luYWwtcmVjb3Zlcnk6Nzo3OTAx": 1592 bytes]") |
| `ApprovedReleaseOriginalRecoveryTests` | `testRevocationWhileStatusIsSuspendedCannotSaveLateReceipt` | PASS (0.012s) | PASS (0.004s) | PASS | — |
| `ApprovedReleaseOriginalRecoveryTests` | `testSessionOwnerEpochRealmViewerAndConfigurationChangesRejectCapturedOpening` | PASS (0.001s) | PASS (0.001s) | PASS | — |
| `ApprovedReleaseOriginalRecoveryTests` | `testStatusOnlyWithoutPrepareOrAcknowledgmentUsesAcceptedServerTopic` | PASS (0.004s) | PASS (0.004s) | PASS | — |
| `ApprovedReleaseOriginalRecoveryTests` | `testStrictNewTopicAcknowledgmentSelectsCompletedTopicNotMutableDraft` | PASS (0.036s) | PASS (0.027s) | PASS | — |
| `ApprovedReleaseOriginalRecoveryTests` | `testStrictOriginalAcknowledgmentNeedsNoNewBundleOrPrepareEvidence` | PASS (0.023s) | PASS (0.019s) | PASS | — |
| `ApprovedReleaseOriginalRecoveryTests` | `testSuccessfulReadPersistsMatchingReceiptWithoutNewRequest` | PASS (0.006s) | PASS (0.006s) | PASS | — |
| `ApprovedReleaseOriginalRecoveryTests` | `testUnconfiguredAndRevokedAreNeverEmptyJournal` | PASS (0.001s) | PASS (0.001s) | PASS | — |
| `ApprovedReleaseOriginalRecoveryTests` | `testUnknownNotFoundAndOrdinaryFailurePreserveExactRecordWithoutReplay` | PASS (0.005s) | PASS (0.005s) | PASS | — |
| `ApprovedReleaseOriginalRecoveryTests` | `testUnreadableAndDamagedStorageNeverAppearEmptyOrEraseBytes` | PASS (0.005s) | PASS (0.004s) | PASS | — |
| `ApprovedReleaseOriginalRecoveryTests` | `testWrongOwnerOrTopicEnvelopeIsDamagedStorageWithoutClearingOriginal` | PASS (0.007s) | PASS (0.007s) | PASS | — |
| `ApprovedReleaseOriginalRecoveryTests` | `testWrongTopicSourceJournalAndEditorVisitRejectOpening` | PASS (0.001s) | PASS (0.001s) | PASS | — |
| `ApprovedTopicReviewCompositionTests` | `testDefaultOffNormalFactoryNeverCreatesInnerReleaseAuthority` | PASS (0.074s) | PASS (0.039s) | PASS | — |
| `ApprovedTopicReviewCompositionTests` | `testNormalAppSessionFactoryReachesOnlyExactPrepareThroughOuterFence` | PASS (0.029s) | PASS (0.023s) | PASS | — |
| `ApprovedTopicReviewCompositionTests` | `testNormalCurrentObservationLate401AfterGrantABACannotExpireSession` | PASS (0.025s) | PASS (0.026s) | PASS | — |
| `ApprovedTopicReviewCompositionTests` | `testNormalFactorySubmitAndStatusUseOnlyTheirOwnFreshCapabilities` | PASS (0.013s) | PASS (0.014s) | PASS | — |
| `ApprovedTopicReviewCompositionTests` | `testNormalObservationFactoryUsesOnlyOriginalSixFieldsAndIndependentCurrentGrant` | PASS (0.017s) | PASS (0.016s) | PASS | — |
| `ApprovedTopicReviewCompositionTests` | `testNormalSourceChoiceFactoryCarriesExactRefsThenReadsOnlySixFields` | FAIL (0.020s) | FAIL (0.020s) | **PRE-EXISTING** | L201: failed: caught error: "notConfigured" |
| `ApprovedTopicReviewCompositionTests` | `testNormalSourcePickerDefaultOffCannotBorrowExistingPrepareGrant` | PASS (0.009s) | PASS (0.008s) | PASS | — |
| `ApprovedTopicReviewCompositionTests` | `testOldNormalFactoryCannotBecomeCurrentAgainAfterRoleABAAndFreshFactoryWorks` | PASS (0.016s) | PASS (0.015s) | PASS | — |
| `ApprovedTopicReviewCompositionTests` | `testOuterCloneKeepsExactSelectorAndRejectsAdjacentRoutesUnknownFieldsAndRevocation` | PASS (0.009s) | PASS (0.010s) | PASS | — |
| `ApprovedTopicReviewCompositionTests` | `testOuterSourcesRouteRejectsExtraReferencesQueriesAndBorrowedCapabilities` | PASS (0.006s) | PASS (0.007s) | PASS | — |
| `ApprovedTopicReviewCompositionTests` | `testQueuedReviewClaimAfterSubmitGrantABAKeepsExactJournalAndSendsNothing` | PASS (0.041s) | PASS (0.033s) | PASS | — |
| `ApprovedTopicReviewCompositionTests` | `testRealOuterHeldReadRejectsRoleABA401WithoutLoggingOutReturnedAccount` | PASS (0.012s) | PASS (0.012s) | PASS | — |
| `ApprovedTopicReviewCompositionTests` | `testRealSourceSelectionModelClaimsSynchronouslyAndOldControlsCannotQueueAfterBack` | PASS (0.016s) | PASS (0.015s) | PASS | — |
| `ApprovedTopicReviewCompositionTests` | `testRetiredReviewFactoryCannotBorrowNewSessionWhenSameCapabilitiesReturn` | PASS (0.016s) | PASS (0.015s) | PASS | — |
| `ApprovedTopicReviewCompositionTests` | `testSourceConfigurationABARejectsQueuedCaptureAndFreshPickerRemainsAvailable` | PASS (0.018s) | PASS (0.015s) | PASS | — |
| `ApprovedTopicReviewCompositionTests` | `testSourceFactoryLate401AfterRoleABACannotExpireCurrentAccount` | PASS (0.022s) | PASS (0.014s) | PASS | — |
| `ClubOrdinaryAdmissionCompositionTests` | `testApprovalCannotFollowReplacementAccountEpochOrToken` | FAIL (0.003s) | FAIL (0.003s) | **PRE-EXISTING** | L15: failed: caught error: "invalidConfiguration" |
| `ClubOrdinaryAdmissionCompositionTests` | `testNoIssuerDefaultsClosed` | PASS (0.000s) | PASS (0.000s) | PASS | — |
| `ProfileGuideReadTests` | `testActualArticleDestinationReadsOriginalViewAndRetiresOnRealRemoval` | PASS (0.351s) | PASS (0.144s) | PASS | — |
| `ProfileGuideReadTests` | `testApprovalReplacementRevocationAndAccountChangeRejectLateArticleResponses` | PASS (0.057s) | PASS (0.026s) | PASS | — |
| `ProfileGuideReadTests` | `testCurrent401ExpiresAndTaskCancellationDoesNot` | PASS (0.006s) | PASS (0.004s) | PASS | — |
| `ProfileGuideReadTests` | `testEmptyErrorRemovedAndExplicitRetryAreDistinct` | PASS (0.007s) | PASS (0.005s) | PASS | — |
| `ProfileGuideReadTests` | `testHiddenListAndBackgroundArticleRetireHeldResultsWithoutExpiringCurrentOwner` | PASS (0.010s) | PASS (0.006s) | PASS | — |
| `ProfileGuideReadTests` | `testListCoverKeepsArticleReceiptAndHiddenForegroundCannotRead` | PASS (0.009s) | PASS (0.006s) | PASS | — |
| `ProfileGuideReadTests` | `testNormalOriginalListToExplicitArticleOnlyUsesTwoOriginalRequests` | PASS (0.006s) | PASS (0.004s) | PASS | — |
| `ProfileGuideReadTests` | `testOldArticleCloseCannotRetireNewSelection` | PASS (0.005s) | PASS (0.003s) | PASS | — |
| `ProfileGuideReadTests` | `testOldSettingsCallbacksCannotRouteOrConsumeNewPresentation` | PASS (0.000s) | PASS (0.000s) | PASS | — |
| `ProfileGuideReadTests` | `testOnlyExactAcceptedRowCanCreateArticleAndRefreshRetiresOldSourceEvenSameID` | PASS (0.005s) | PASS (0.003s) | PASS | — |
| `ProfileGuideReadTests` | `testOrdinaryConfiguredGuideLoadsOriginalListAndRefreshesWithoutWrites` | PASS (0.363s) | PASS (0.142s) | PASS | — |
| `ProfileGuideReadTests` | `testOrdinaryGuideHostKeepsStaticModesAndDefaultNilDoesNoRead` | PASS (0.071s) | PASS (0.035s) | PASS | — |
| `ProfileGuideReadTests` | `testSettingsGuideConstructionKeepsExistingIndependentGrantClosed` | PASS (0.016s) | PASS (0.007s) | PASS | — |
| `ProfileGuideReadTests` | `testSettingsGuideModeRunsOnlyAfterDismissAndOnlyOnce` | PASS (0.000s) | PASS (0.000s) | PASS | — |
| `ProfileGuideReadTests` | `testSignedOutAndDefaultNilNeverDispatchGuideRequests` | PASS (0.019s) | PASS (0.007s) | PASS | — |
| `ProfileGuideReadTests` | `testTransportEpochViewerTokenAndRoleChangesRejectLateResponses` | PASS (0.020s) | PASS (0.010s) | PASS | — |
| `ProfileGuideReadTests` | `testTransportSelectedIDAndPurposeCannotFallbackOrBorrowOtherRoutes` | PASS (0.005s) | PASS (0.003s) | PASS | — |
| `RoamPassportServerHistoryHostTests` | `testBackgroundDiscardsPresentationAndForegroundRequiresExplicitFreshRead` | FAIL (4.833s) | PASS (0.194s) | **FIXED** | (2x) L115: XCTAssertTrue failed |
| `RoamPassportServerHistoryHostTests` | `testDefaultNilCannotBorrowManualMapOrPassportToolsGrant` | PASS (0.011s) | PASS (0.006s) | PASS | — |
| `RoamPassportServerHistoryHostTests` | `testHostedDefaultNilShowsDisabledRemoteEntryWithoutNetwork` | PASS (0.116s) | PASS (0.148s) | PASS | — |
| `RoamPassportServerHistoryHostTests` | `testLateOldOwner401CannotExpireSuccessorWhileCurrent401Does` | PASS (0.017s) | PASS (0.019s) | PASS | — |
| `RoamPassportServerHistoryHostTests` | `testOriginalCompositionRoutesAllThreeReadsOnlyWithIndependentGrant` | PASS (0.007s) | PASS (0.007s) | PASS | — |
| `RoamPassportServerHistoryHostTests` | `testOriginalLocalHistoryEntryOpensServerListSummaryAndExactRecordWithoutWrites` | PASS (0.344s) | PASS (0.668s) | PASS | — |
| `RoamPassportServerHistoryHostTests` | `testRealSessionDefaultNilDeniesAllThreeReadsAndKeepsLocalHistoryAvailable` | PASS (0.058s) | PASS (0.050s) | PASS | — |
| `RoamPassportServerHistoryHostTests` | `testTransportCloneRetainsOnlyExactPassportGrantAndRejectsOtherRoutes` | PASS (0.008s) | PASS (0.008s) | PASS | — |
| `RoamPrivatePageHostRecoveryTests` | `testActualCapsuleUnsubmittedFormClearsOnBackgroundWithoutTouchingPending` | PASS (0.371s) | PASS (0.305s) | PASS | — |
| `RoamPrivatePageHostRecoveryTests` | `testActualGoalFormSurvivesSameOwnerBackgroundButNoCreateIsSent` | PASS (0.325s) | PASS (0.276s) | PASS | — |
| `RoamPrivatePageHostRecoveryTests` | `testActualGrantWithdrawalHidesDetailThenRestorationReadsOnlyOriginalList` | FAIL (3.527s) | PASS (0.157s) | **FIXED** | (2x) L148: failed - Original private page control/read state did not settle; L0: failed: caught error: "InvalidTransition { |
| `RoamPrivatePageHostRecoveryTests` | `testActualPassportCapsuleEntryHidesBodyOnBackgroundThenReadsMetadataOnly` | PASS (0.307s) | PASS (0.275s) | PASS | — |
| `RoamPrivatePageHostRecoveryTests` | `testActualSameIdentityReaderReplacementCannotKeepOldCapsuleDetail` | PASS (0.118s) | PASS (0.094s) | PASS | — |
| `RoamPrivatePageHostRecoveryTests` | `testInactiveSystemInterruptionPreservesIssuedCompletionAndOrdinaryReadReleasesBusy` | PASS (0.121s) | PASS (0.115s) | PASS | — |
| `RoamPrivatePageHostRecoveryTests` | `testIssuedOperationIsNotCancelledAndReturnWaitsThenOnlyRefreshesMetadata` | PASS (0.044s) | PASS (0.044s) | PASS | — |
| `RoamPrivatePageHostRecoveryTests` | `testPageScopeIncludesActualReaderExactScopeAndEpoch` | PASS (0.000s) | PASS (0.001s) | PASS | — |
| `RoamPrivatePageHostRecoveryTests` | `testQueuedOriginalActionCannotBeginAfterInactiveBackgroundDepartureOrRevocation` | PASS (0.002s) | PASS (0.002s) | PASS | — |
| `RoamPrivatePageHostRecoveryTests` | `testReadOnlyGrantPermitsOriginalReceiptButNeverWriter` | PASS (0.021s) | PASS (0.022s) | PASS | — |
| `StoryWalkingFogAndWorkshopUpgradeViewTests` | `testPurchasedUpgradeEntryHostsInjectedCompareAndStaysClosedByDefault` | PASS (0.023s) | PASS (0.023s) | PASS | — |
| `StoryWalkingFogAndWorkshopUpgradeViewTests` | `testStoryWalkingAndFogSectionViewRendersStopNavigationArrivalVerificationAndFogProjection` | PASS (0.009s) | PASS (0.007s) | PASS | — |
| `StoryWalkingFogAndWorkshopUpgradeViewTests` | `testWorkshopModUpgradeSheetViewInstantiatesBreakingAndCompatibleDiffWithConfirmationGate` | PASS (0.008s) | FAIL (0.006s) | **REGRESSION** | L158: XCTAssertTrue failed |
