# CB22 — Core crash, hang, and test-quality notes

Base: `origin/rc/20261108` `67053ccb33c0e1ad35a7508f8546ae9076fd82e5`.
Package: `QuestifyCore` (`Package.swift`, tools version 5.9, target path `Core/`, tests `Tests/CoreTests`).

No test was deleted or weakened. `tools/current_ci_manifest.json` was not refreshed. Nothing was deployed.

## Sanitizer

A sanitizer did not run.

`swift`, `swiftc`, `xcodebuild`, and `xcrun` are not on this machine. `clang` is Ubuntu clang 18.1.3 at `/usr/bin/clang`. Core is Swift and imports Foundation, Observation, CryptoKit, and StoreKit, so clang cannot compile it and an ASan/TSan/UBSan build of Core was not started. A stand-in C program was not compiled.

Quoted probe:

```text
$ command -v swift; command -v swiftc; command -v xcodebuild; command -v xcrun; command -v clang
/usr/bin/clang
$ type swift
--: line 1: type: swift: not found
$ type swiftc
--: line 1: type: swiftc: not found
```

`swift test` was not executed. No new test count is claimed. The last recorded Core line remains the one in `docs/release/cb2-core-unexpected.md` (15473 tests, 78 failures, 15 unexpected). That number was not reproduced here.

## Swift 6 warnings

No Swift 6 diagnostic was emitted, because `swiftc` is absent. None are invented here.

`Package.swift` is `// swift-tools-version: 5.9` and does not enable Swift 6 language mode. The isolation suppressions already in Core were left in place. Changing them would change when those values are read:

- `Core/W8Text.swift`: `languageOverride` is `nonisolated(unsafe)`. It stays a plain static. It was not wrapped in an actor or a lock.
- `Core/AppPreferences.swift`: `AppLanguageRuntime.active` is `nonisolated(unsafe)`. Same decision.
- `Core/RoamExportDeliveryLease.swift` `publish()` and `snapshot()` call `MainActor.assumeIsolated` only after `Thread.isMainThread` is true. The thread check and the isolated read both stay.

`@unchecked Sendable` types that already guard their mutable state with a lock were not restructured.

## Crash and hang fixes

Valid JSON that `ContentDraftJSON.parse` already accepts (depth at most 128, `Core/VersionedContentDraftJSON.swift`) still walks the same bytes. A container or escape that ends at EOF now throws the error that walker already used, instead of reading `bytes[index]` past the end.

| Site | Failure mode that was reachable | Change |
|---|---|---|
| `Core/ProjectNodeRouteMapping.swift` `TokenScanner` | After `ContentDraftJSON.parse`, `applying` still walks `original`. `{` or `[` then EOF read the next byte with no count check. A trailing `\` stepped `cursor` past the buffer. | Bounds check before each of those reads. Depth above 128 throws `Reason.unsupported`. |
| `Core/ProjectInitialAttributes.swift` `IntegerTokens` | `validateIntegerTokens` runs after `ApprovedTopicReleaseWire.envelope`. The same unguarded `bytes[index]` followed `{`, `[`, `:`, `,`, and `}`. | Throws `ProjectEditError.invalidDraft`. |
| `Core/NativeAttributeAuthorModel.swift` `IntegerTokens` | Callers parse with `ContentDraftJSON` first, then this walker. Same unguarded index. | Throws `NativeAttributeAuthorError.invalid("JSON token")` (depth: `"JSON depth"`). |
| `Core/NativeConditionAuthorVersion.swift` `hasExplicitV2` | `index += 2` on a final `\`. The following `guard index < count` already returned false, so this was not a live trap. The skip now returns false when the escaped byte is missing. An escaped quote that has a following byte still skips two bytes. | Same `false` for a truncated string. |
| `Core/CollectSetAuthoring.swift` `FieldScanner.stringEnd` | `index += 2` on a final `\`, then the loop ended and threw `ProjectEditError.invalidDraft`. | Throws that same error before the step. |
| `Core/MessagingHistory.swift` `readExistingMessage` | `while true` until `hasMore` is false or a cursor repeats. A server that returns `hasMore` with a new positive cursor on every page never returns and keeps the cursor set. | Stops after 1024 pages and throws `APIError.malformedResponse`, the same error as a repeated cursor. `prepend` is unchanged. A history of more than 1024 distinct pages now fails closed; the Core tests that call this helper use one page with `hasMore == false`. |
| `Core/ParticipantFileJournal.swift` and `Core/ClubOrdinaryAdmissionFileJournal.swift` `ensureDirectory` | `mkdir` `EEXIST` called `ensureDirectory` on the same URL. If `lstat` kept returning `ENOENT`, that recursion did not terminate. | Same-URL retries stop at 8 and throw `APIError.notConfigured`. Parent walks still use a fresh retry count. A directory that exists, or a `mkdir` that succeeds, still syncs the parent once. |
| `Core/MerchantOfferWithdrawalUnifiedStore.swift` `ensureDirectory` | After `mkdir` returned 0 or `EEXIST`, it called itself on the same URL. A parent whose `deletingLastPathComponent()` did not change (and was not `/`) recursed without a stop. The root-owned symlink return (`st_uid == 0`) is unchanged. | Same-URL retries stop at 8 with `CoopFlowFailure.storage`. A parent path that does not change throws the same error. A created directory is still re-stated and the parent is still synced. |

## Inspected and not changed

These were read and left because a trap or hang was not shown on a path a caller can reach, or because a guard would reject input the current code accepts.

- `ContentDraftJSON`, `QmodJSONInspection`, and `TemplatePreferenceRemoval` already check `take()` / depth before indexing.
- `WorkshopCreatorPendingContracts.instantMicros`, `MerchantNPCKnowledgeValidation`, `ClubCalendarSessions.localTimestamp`, `AccountCollectionContracts.futureStartDay`, `ProjectNodeBusinessHours`, and `RoamPassportTools.wallTime` check length or a digit regex before `Int` / `number()`.
- `RoamHistoryPoint.coordinate`, `ProjectNodeRouteMapping` after `validate()`, `TemplateD20Rehearsal.values.min()`, `TemplateChoiceMemory` `randomElement()`, `ObjectCard.frame` (modulo only when `frames.count > 1`), and `DiceRulesEngine.rollDie` (`precondition(sides >= 2)`, callers pass 20) force-unwrap only after that check.
- `QmodLocalReadBudget.probeRoom` returns at least one byte when `collected <= cap`, so the read loop does not spin at `take == 0`. `QmodRawDeflate.inflate` stays inside `withUnsafeBytes`.
- `ResponseLimitedHTTPTransport` uses 30s timeouts and a single resume under its lock. `BundleOrderReadModel` polling is bounded by `delaysNanoseconds`. `OrderPaymentReadRace.finish` is idempotent.
- `ContentDraftSystemStorage` uses `baseAddress!` only inside `while offset < count`. `ClubProfileLocalDraftStore` hashes `Data(count: 32)`.
- `MerchantOfferWithdrawalOriginalJournal` `String(cString:)` on `d_name` relies on `readdir` NUL-termination. Not sanitized here, so it was not rewritten.
- `NativeProgressPrivacyFlow` and `NativeFriendDirectoryFlow` authority tasks sleep 250ms until cancel. That is not a busy loop.
- `CityOrientationTaskApprovalRegistry` `precondition(revision < UInt64.max)` is the intentional overflow stop.

## Flaky tests

Listed only where the source shows a pass/fail that depends on a clock or on scheduling against a deadline. None of these were executed on this machine, and none were edited.

Time-dependent:

| Test | Why it is time-dependent |
|---|---|
| `VersionedContentDraftTests.testStaleCompletionAndLate401CannotInvalidateNewSession` | Calls `ContentDraftRecordingTransport.waitUntilSuspended` (`Tests/CoreTests/VersionedContentDraftTests.swift`). |
| `VersionedContentDraftTests.testExplicitRevokeFencesABAEvenWhenContextReturnsEqual` | Same helper. |
| `VersionedContentDraftTests.testLateSaveCannotPoisonNewDraftAndDurableUnknownSurvives` | Same helper. |
| `VersionedContentDraftTests.testNonASCIIAuthorityAliasesAreDifferentLifetimes` | Same helper. |
| `ContentDraftPreparedDispatchTests.testRealServiceSeesExactDurableGenerationBeforeEveryHTTP` | Same helper, via `f.transport.recorder`. |
| `ContentDraftPreparedDispatchTests.testLate401AfterActualWriteKeepsPendingAndDoesNotInvokeNewSessionCallback` | Same helper. |
| `ShopNPCInterruptionTests.testStopWaitingPreservesOriginalIDAndLateReplyCannotReplaceRetry` | `HTTP.waitFor` (`Tests/CoreTests/ShopNPCInterruptionTests.swift`). |
| `ShopNPCInterruptionTests.testBackgroundInFlightKeepsUnknownIDAndDiscardsLateResponse` | Same helper. |
| `ShopNPCInterruptionTests.testAudioLifecycleSignalsSuspendButNeverResumeOrDispatch` | Same helper. |
| `ShopNPCInterruptionTests.testBusyReviewCannotBeDiscardedAndExplicitDiscardAfterStopIsAllowed` | Same helper. |
| `ShopNPCInterruptionTests.testCallerCancellationCannotPublishLateAcceptedResponse` | Same helper. |
| `ShopNPCInterruptionTests.testInterruptedRegenerationPreservesOriginalAnswerAndReplacesItOnlyOnce` | Same helper. |
| `ShopNPCInterruptionTests.testCapturedIntentIsConsumedOnceAndCannotDispatchDuplicateTask` | Same helper. |
| `WeChatAppAuthTests.testTimeoutCancelsAndLateCallbackCannotExchange` | `timeoutNanoseconds: 1`, then `Task.sleep` of 10ms, then `XCTAssertEqual(coordinator.issue, .timedOut)`. `WeChatAppAuthCoordinator.start` sets `.timedOut` from a separate `Task` that sleeps `timeoutNanoseconds`. The assertion does not await that task. |
| `TemplateAuthoringTests.testSignoutDuringSubmitCannotDisplayStaleSuccess` | Transport `delayNanoseconds` is 40ms (`TemplateAuthoringSyntheticTransport.send` sleeps that long before the reply). The test sleeps 10ms, then nils the session, then asserts `state != .simulated`. If the 10ms sleep is not scheduled until the 40ms delay has finished, the state is already `.simulated`. |
| `ProfileSavedMediaReadTests.testExpiredLiveLeaseCannotStartARead` | `expiresAt` is `Date() + 0.5s`. The test sleeps 600ms on the task sleeper, then `key()` calls `isConfigured`, which calls `ProfileSavedMediaReadApproval.matches`, which uses `Date() < expiresAt`. A wall-clock step backward during the sleep leaves the lease valid and `key()` non-nil. |
| `ProfileParticipantMultipartCRLFBoundaryTests.testWithdrawnAndExpiredAccessRejectPreviouslyCanonicalBodyRequests` | `expiresAt` is `Date() + 0.05s`, then a 100ms sleep, then `send` must throw `.notConfigured`. `ProfileParticipantTransport.valid` calls `ProfileParticipantAccess.matches`, whose default `now` is `Date()`. Same two-clock race. The explicit `matches(owner, now: expiresAt)` check earlier in the test is not this race. |
| `NativeFriendDirectoryFlowTests.testReadyLeaseExpiryPurgesDirectoryAndDetailWithoutPollingServer` | `service.expiresAt` is `Date() + 0.03s`, then a 60ms sleep, then `live.items` must be empty. `items` returns `[]` when `service.isCurrent` is false, and that getter is `authorized && Date() < expiresAt`. The 250ms authority poll is not what this assertion waits for. A wall clock that advances less than 30ms during the sleep leaves the items in place. |

`waitUntilSuspended` is:

```swift
let deadline = Date().addingTimeInterval(2)
while !isAwaitingResponse && Date() < deadline { await Task.yield() }
XCTAssertTrue(isAwaitingResponse, ...)
```

The assertion fails when the flag is still false after two seconds of wall clock, including when the suspension task has not been scheduled yet.

`HTTP.waitFor` stores `ContinuousClock().now.advanced(by: .seconds(2))` and throws `WaitFailure.requestNotDispatched` if `waiting[index]` is still nil. The continuation is stored only once the held `send` task runs.

Not listed, after reading them:

- `W8LocalizationTests`, `QuickPublishValidationTests.testMessagesAreBilingual`, `PlayRPGPresentationTests.testUnavailableCopyIsBilingual` and `testRollerAnnouncementAndClear`, `OrientScorePresentationTests` (English strings under `languageOverride = "en"`), and `CoreUserFacingCopyLocalizationTests`. They write `W8Text.languageOverride` and read it in the same method. `swift test` in the repo docs is not passed `--parallel`, and this inspection did not show another test running between the write and the assert. The static is still an unsynchronized process global; that is noted above and is not by itself a demonstrated order failure.
- `BNDAppealModelTests.testApprovedAppealDoesNotShowUnitAsRedeemedUntilServerSaysSo` sets `languageOverride = "en"`, then asserts an enum headline and that the copy does not contain `refunded` / `consumed` / `redeemed`. Chinese copy still passes those checks.
- `OwnMediaReadExpiryTests` waits on an `XCTestExpectation` with a 2s timeout for a 50ms lease. The pass condition is the observation callback, not a short sleep compared with `Date()`.
- Test helpers that `while`-yield until a counter moves (`PlayRewardBadgeTests.waitFor` and the similar reward/coupon helpers) hang if the signal never arrives. They do not fail because of a deadline or because of another test's order. They were not changed.
