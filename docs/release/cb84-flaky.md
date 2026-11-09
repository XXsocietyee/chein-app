# CB84 — Flaky tests already named

Base: `origin/rc/20261108` `89dcba807e7e5439182ff8852d6600d1fa9fdd49`.
Branch: `cursor/cb84`.

Version stays 0.1.0 (1). `Config/Base.xcconfig` is unchanged (`MARKETING_VERSION = 0.1.0`, `CURRENT_PROJECT_VERSION = 1`).

The names below are copied from two existing notes. They were not rerun. CI has not produced a flake result yet. No flake rate and no new failure count are claimed. No test was edited, deleted, or renamed.

Sources, read only:

- `origin/cursor/cb22` `6776cffb9d3813d6080f400c38eaea65f97a9b0e`, `docs/release/cb22-quality.md`, section `Flaky tests`
- `origin/cursor/cb40` `09adeff5f396f04de223616079a76c8e10a61104`, `docs/release/cb40-test-speed.md`, section `Stability list`

`swift test`, `swift build`, `xcodebuild`, `xcrun`, and `simctl` were not run.

## From CB22

`docs/release/cb22-quality.md` lists these under `Flaky tests`, and only where the source shows a pass or fail that depends on a clock or on scheduling against a deadline. That note says none of them were executed on that machine and none were edited. They were not rerun for this note.

| Test | Why that note lists it |
|---|---|
| `VersionedContentDraftTests.testStaleCompletionAndLate401CannotInvalidateNewSession` | `ContentDraftRecordingTransport.waitUntilSuspended` |
| `VersionedContentDraftTests.testExplicitRevokeFencesABAEvenWhenContextReturnsEqual` | Same helper |
| `VersionedContentDraftTests.testLateSaveCannotPoisonNewDraftAndDurableUnknownSurvives` | Same helper |
| `VersionedContentDraftTests.testNonASCIIAuthorityAliasesAreDifferentLifetimes` | Same helper |
| `ContentDraftPreparedDispatchTests.testRealServiceSeesExactDurableGenerationBeforeEveryHTTP` | Same helper, via `f.transport.recorder` |
| `ContentDraftPreparedDispatchTests.testLate401AfterActualWriteKeepsPendingAndDoesNotInvokeNewSessionCallback` | Same helper |
| `ShopNPCInterruptionTests.testStopWaitingPreservesOriginalIDAndLateReplyCannotReplaceRetry` | `HTTP.waitFor` |
| `ShopNPCInterruptionTests.testBackgroundInFlightKeepsUnknownIDAndDiscardsLateResponse` | Same helper |
| `ShopNPCInterruptionTests.testAudioLifecycleSignalsSuspendButNeverResumeOrDispatch` | Same helper |
| `ShopNPCInterruptionTests.testBusyReviewCannotBeDiscardedAndExplicitDiscardAfterStopIsAllowed` | Same helper |
| `ShopNPCInterruptionTests.testCallerCancellationCannotPublishLateAcceptedResponse` | Same helper |
| `ShopNPCInterruptionTests.testInterruptedRegenerationPreservesOriginalAnswerAndReplacesItOnlyOnce` | Same helper |
| `ShopNPCInterruptionTests.testCapturedIntentIsConsumedOnceAndCannotDispatchDuplicateTask` | Same helper |
| `WeChatAppAuthTests.testTimeoutCancelsAndLateCallbackCannotExchange` | `timeoutNanoseconds: 1`, then a 10ms sleep, then an assert that does not await the timeout task |
| `TemplateAuthoringTests.testSignoutDuringSubmitCannotDisplayStaleSuccess` | 10ms sleep against a 40ms transport delay |
| `ProfileSavedMediaReadTests.testExpiredLiveLeaseCannotStartARead` | Sleeps 600ms, then `Date()` against `expiresAt` of `Date() + 0.5s` |
| `ProfileParticipantMultipartCRLFBoundaryTests.testWithdrawnAndExpiredAccessRejectPreviouslyCanonicalBodyRequests` | Sleeps 100ms, then `Date()` against `expiresAt` of `Date() + 0.05s` |
| `NativeFriendDirectoryFlowTests.testReadyLeaseExpiryPurgesDirectoryAndDetailWithoutPollingServer` | Sleeps 60ms, then `Date()` against `expiresAt` of `Date() + 0.03s` |

## From CB40

`docs/release/cb40-test-speed.md` says the tree does not record a flake rate, and that no failure count in that section was produced there. The names it does give are copied here. They were not rerun.

### Result changed with the simulator locale

`StoryWalkingFogAndWorkshopUpgradeViewTests.testWorkshopModUpgradeSheetViewInstantiatesBreakingAndCompatibleDiffWithConfirmationGate`

That note records one published pass and one published failure of this method (`AppleLocale = zh-Hans_US`, then `en_US`). It says that pair is not a rate.

### Waits that can fail when a request never arrives

That note says no flake count is attached to these. The names it lists:

- `ClubPostDiscussionReadTests` (`waitForRequests`, 3 seconds)
- `ProfileServiceTests` (`waitForRequests`, 5 seconds)
- `CooperationTests` (`waitForRequests`, 5 seconds)
- `AccountCollectionTests` (`waitForRequests`, 5 seconds)
- `TicketWalletTests` (`waitForRequests`, 5 seconds)
- `WalkingNavigationAppTests` (`Task.sleep` polls)
- `WorkshopCreatorConsentNormalFlowTests` (`Date()` and `Task.sleep`)
- `WorkshopCreatorPendingNormalFlowTests` (`Date()` and `Task.sleep`)

The same note says 82 test classes contain `Task.sleep` and that this is a source pattern, not 82 flakes. Those 82 classes are not listed by name there, so they are not listed here.

### Not carried in as a flake name

The PlayKit retry case in that note is historical nondeterminism whose method is not named. `PlayKitGLBPolicyTests` and `PlayKitGLBDecoderTests` appear only as files that contain `JSONSerialization.WritingOptions.sortedKeys`. The note says those two mentions do not identify the unnamed retry test.

The rows under `Stable on the recorded baseline` are names that note says fail the same way in the published triage. It says treating them as flakes and retrying them would hide a real result. They are not copied into the lists above.

## Not run

- Any rerun of the names above
- A CI flake result (none has been produced yet)
- `tools/current_ci.py refresh` and any write to `tools/current_ci_manifest.json`
