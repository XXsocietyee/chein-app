# Gap-wave regression triage (pre-wave `origin/wip/gm-int` 29956c06 vs `gm-aud` edcfc68a)

## Core (`swift test --disable-sandbox --filter InvoiceLaunch`, both trees)

| Class / test | Pre-wave | Now (before fix) | Verdict | Fix |
|---|---|---|---|---|
| InvoiceLaunchServiceTests.testMismatchedIDsAndFutureStatusFailClosed | pass | FAIL ("Future contract must not be silently enabled") | **Wave change, test stale; fail-closed intact in code.** W7b (ecd5895e) added CLAIMED/PROCESSING/ISSUE_UNKNOWN/PAUSED to `InvoiceLaunchStatus` because the backend really emits them (`UserInvoiceProcessingService.java` transitions SUBMITTED→CLAIMED→PROCESSING→ISSUE_UNKNOWN, refund→PAUSED) and the mini-program maps them (`subpackageMember/invoice/base.js` PLAYER_STATUS). The test used `PROCESSING` as its "unknown future" example. | Test now uses `SYNTHETIC_FUTURE_STATUS` (genuinely unknown) – same assertion, decode still throws. Unknown statuses still fail decoding (also asserted in `InvoiceLaunchStatusTests`). No code loosened. |
| InvoiceLaunchCoordinatorTests.testUnknownApplyRecoversOriginalRequestAfterRestartWithoutWrite | FAIL (outcomeUnknown) | FAIL (identical) | **PRE-EXISTING**, not wave. `recover()` (`Core/InvoiceLaunchCoordinator.swift`) deliberately requires `result.titleId == command.titleId` (title binding, pinned by `InvoiceLaunchApplyTitleBindingTests`); the test's original-receipt fixture omitted `titleId`, so recovery correctly stays unresolved. | Fixture now echoes `titleId: "11"` (`Tests/CoreTests/InvoiceLaunchCoordinatorTests.swift`); code unchanged. Restart still recovers via the original-receipt read with exactly one request and no write. |

After fix: pre-wave 84 tests/1 failure; now 91 tests/0 failures (`/private/tmp/gm-reg-core-pre.log`, `gm-reg-core-now.log`, re-run green).

## AppUnit (37 candidate tests) – NOT RUN, environment blocker

Both trees built for testing (pre-wave worktree `/private/tmp/gm-reg-prewave`, build OK with `OTHER_SWIFT_FLAGS=-Xfrontend -disable-sandbox` because the macro plugin server cannot nest a sandbox), but `test-without-building` cannot start in this worker's sandbox:
`Failed to connect to unix domain socket .../com.apple.testmanagerd.unix-domain.socket: 1 Operation not permitted` (identical on both trees, `/private/tmp/gm-reg-app-pre.log`, `gm-reg-app-now.log`). No pre-wave/now result exists for these classes, so **no verdict is claimed**: CouponRuntimeCompositionTests, MerchantReviewOriginalRecoveryEntryTests, ClubCommunityLifecycleTests, ClubCommunityReadCompositionTests, ApprovedReleaseOriginalRecoveryTests, ApprovedTopicReviewCompositionTests, ClubOrdinaryAdmissionCompositionTests, ProfileGuideReadTests, RoamPassportServerHistoryHostTests, RoamPrivatePageHostRecoveryTests, StoryWalkingFogAndWorkshopUpgradeViewTests (RuntimeSessionRoleConsistencyTests: owner decision, ignored). No page-map.csv row was changed on the basis of these classes.

Re-run from an unsandboxed shell (build is already stamped; ~minutes): `/private/tmp/rc1-ptest.sh /private/tmp/gm-reg-prewave /private/tmp/gm-reg-app-pre.log Questify-iPhone17-W2 -only-testing:QuestifyAppUnitTests/<Class> ...` and the same on this worktree with `Questify-iPhone17`.
