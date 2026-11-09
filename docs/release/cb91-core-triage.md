# CB91 — Core failure triage

Base: `origin/rc/20261108` `2f6d5041a57d876d3b0a953f56ecf5208089622f`.
Package: `QuestifyCore` (`Core/`, tests in `Tests/CoreTests`).

This VM has no `swift`, `swiftc`, `xcodebuild`, or `xcrun`. `swift test` was not executed. No new test count is claimed. No test was deleted, weakened, or renamed. `tools/current_ci_manifest.json` was not refreshed. `.github/workflows/ios-ci.yml` was not edited. No product source was changed.

## Recorded result

The last Core line is the Mac L1 run (`swift test --disable-sandbox` in `/private/tmp/rc-final`, log `/private/tmp/rcfinal-core.log`), copied from `docs/release/cb2-core-unexpected.md` and `origin/cursor/L1` `docs/release/cursor-L1-report.md`:

```text
Executed 15473 tests, with 78 failures (15 unexpected) in 53.331 (54.147) seconds
```

`SWIFT_TEST_EXIT=1`. That run changed no product source. The same 78 / 15 were already the Core line at 15238 tests (`docs/parity/final-integration-regression.md`). The earlier gm-test4 line was 15004 tests, 82 failures, 16 unexpected (`docs/parity/full-suite-triage.md`). L1: 36 unique failing tests, 21 classes, every class already in `docs/parity/full-suite-triage.md`. Three classes that failed on gm-test4 now pass (`InvoiceLaunchCoordinatorTests`, `ParticipantCoordinatorTests`, `ParticipantCoordinatorSnapshotLifetimeTests`). That is the drop from 39 tests / 16 unexpected to 36 / 15. `docs/release/cb40-test-speed.md` quotes the same 15473 / 78 / 15 line and does not add a newer Core run.

On this runner an unexpected failure is an error that leaves the test method (`caught error`). An `XCTAssert` / `XCTUnwrap` miss is a failure and is not unexpected. `continueAfterFailure` stays on, so one test can record several assertion failures. The 78 figure is that record count. It is not 78 unique tests. 15 unexpected means 15 tests threw out of the method. The other 63 records are assertions. The log that would assign those 63 records to individual lines is not in this repo. This note does not invent per-assertion totals.

`origin/cursor/cb22` (`docs/release/cb22-quality.md` at `6776cffb9`) is not contained in this base. Its note says a sanitizer did not run and that the last recorded Core line is still 15473 / 78 / 15. The crash and hang edits on that branch (truncated JSON index, history page cap, `ensureDirectory` retry cap) are not the causes named for these 78 records. They were not ported.

## Host accessibility

None of the 78 records are an iOS 27 host accessibility failure. `swift test` for `QuestifyCore` does not host SwiftUI, and it does not build a `UIWindow`.

These are a different suite. They are not product bugs, and they are not part of the 78.

| Where recorded | What failed | Why it is the host |
|---|---|---|
| `docs/release/cb3-appunit-groups.md` group 1, repeated by `docs/release/cb40-test-speed.md` | AppUnit baseline: 39 classes, 142 failing methods | The test needs `XCUIApplication`, `UIWindow`, `UIHostingController`, `HostedNavigationSceneWindow`, or a hosted Settings view. `docs/parity/full-suite-triage.md` describes the same host failure: an iOS 27 `AccessibilityNode` answers `accessibilityIdentifier` but is not `UIAccessibilityIdentification`, so `as? UIAccessibilityIdentification` is nil. Includes `InvalidTransition` and `cnt=0`. |
| `origin/cursor/L1` `docs/release/cursor-L1-report.md` | `WalletEarningsSegmentHitAreaTests`, both methods, `XCTUnwrap` of `Array<UIAccessibilityElement>` at `Tests/AppUnitTests/WalletEarningsSegmentHitAreaTests.swift:12` and `:25` | Same host accessibility tree. The class is not in the cb3 222-method list. |

`MerchantReviewOriginalRecoveryEntryTests` is also AppUnit, not Core. `docs/parity/gap-wave-compare.md` records 11 failures and 11 unexpected, `caught error: invalidConfiguration`. `docs/release/cb3-appunit-groups.md` says `APIConfiguration` rejects a host ending in `.invalid`, which is the harness host. That rule is what other tests require. It is not one of the 78, and it is not an accessibility failure.

## Inside the 78

### One host filesystem failure

`MerchantOfferWithdrawalUnifiedStoreTests.testKnownHistoricalRootReadsExactScopeAndNeverAcknowledgesOrRewrites` (`Tests/CoreTests/MerchantOfferWithdrawalUnifiedStoreTests.swift:98`).

`journal.entries` calls `openHistoricalDirectory` (`Core/MerchantOfferWithdrawalOriginalJournal.swift:22`). That walk `openat`s every path component with `O_NOFOLLOW` and throws `MerchantOfferWithdrawalOriginalFailure.persistence` when a component is a symlink. The Mac temp directory used by the fixture sits under a symlink. The sibling `testHistoricalSymlinkRootAncestorAndRecordAreRejected` (`:114`) requires that same refusal. The unified store's root-owned symlink exception is not on this walk (`docs/release/cb22-quality.md` records that exception and does not copy it here). Loosening `O_NOFOLLOW` would accept a swapped historical path. This is one of the 15 unexpected records. It is not a product bug. The throw happens on the first `entries` call, so this test adds no earlier assertion record.

### Eight unexpected records that are fail-closed rules

Each row is a test whose first uncaught product error leaves the method. A newer test locks the rule. Changing production to satisfy the older fixture would fail that newer test. No product edit.

| Test | Cause proved from source | Rule that stays |
|---|---|---|
| `ClubActionServiceTests.testJoinApplyAndLeaveUseCurrentJSONContract` (`Tests/CoreTests/ClubActionServiceTests.swift:15`) | The loop calls `perform` for join, then apply, with the default `joinMessage` `""`. `ClubApplicationMessage.isValid` (`Core/ClubActionContracts.swift:14`) is false for an empty apply, so `perform` throws before the request. Join would have passed. | `ClubApplicationRequiredMessageTests.testOnlyApprovalApplicationRequiresNonblankMessage` requires a non-empty apply message and an empty join or leave message. |
| `ClubActionServiceTests.testApplicationMessagePreservesReviewedUnicodeAndJSONEscaping` (`Tests/CoreTests/ClubActionServiceTests.swift:113`) | The message loop starts with `""` and `"   "`. Both fail `isValid` for `.apply`. | Same rule. Whitespace-only is not a reviewed application message. `testExistingUTF16BoundIsUnchangedAndTextNotTruncated` still accepts a trimmed non-empty message. |
| `ClubActionSessionTests.testFreshDetailPrecedesEveryMembershipWrite` (`Tests/CoreTests/ClubActionSessionTests.swift:55`) | `ClubActionSessionWriter.perform(.apply)` revalidates the message and throws `ClubActionWriteError.notSent(.invalidRequest)` before the detail read. | The session writer is the public dispatch boundary. |
| `ClubActionCoordinatorTests.testApplicationRemainsPendingAndDoesNotGrantMembers` (`Tests/CoreTests/ClubActionCoordinatorTests.swift:104`) | `prepare(..., action: .apply)` uses the default empty message and throws `ClubActionBlock.invalidMessage` before confirm. | Same `isValid` check, before the confirmation is stored. |
| `NativeFriendTransportTests.testActualServiceDecodesPendingAndEveryTerminalOriginalReceipt` (`Tests/CoreTests/NativeFriendTransportTests.swift:172`) | `reviewPayload` omits `payload_hash`. `NativeFriendService.validate` (`Core/NativeFriendService.swift:113`) throws `NativeFriendFailure.invalid` unless a non-`UNKNOWN` receipt hash matches `^[0-9a-f]{64}$`. The `try await service.receipt` is not caught. | `payload_hash` is the receipt coding key. Dropping the check would accept a terminal receipt that does not match the original intent. |
| `NativeFriendTransportTests.testActualReviewCancelSendsExactProposalAndRejectsDifferentReceipt` (`Tests/CoreTests/NativeFriendTransportTests.swift:197`) | The first `write` throws `NativeFriendFailure.invalid` from the same hash check. The `catch` expects `.unknown`, which is an assertion and is not this unexpected record. Execution continues and the second bare `try await service.write` throws `.invalid` again. | Same hash check. |
| `MerchantPersonalIncomeEligibilityTests.testOtherRouteDenied` (`Tests/CoreTests/MerchantPersonalIncomeEligibilityTests.swift:14`) | `snapshot(route: "")` fills the other finance fields and leaves `settlementRoute` empty. `MerchantBusinessSnapshot` init throws `MerchantBusinessFailure.malformed` (`Core/MerchantBusinessDocuments.swift:303`). A redemption detail must be complete finance or wholly redacted. | `PUBLIC_TRANSFER` is a complete route and is denied by the matcher. The empty route never becomes a document the matcher can read. |
| `ClubCommunityPendingJournalTests.testAuthoritativeHTTPPendingOutcomeQueryReconcilesRestartedPendingRecordWithoutUnlockingOnStillPendingOrMismatch` (`Tests/CoreTests/ClubCommunityPendingJournalTests.swift:339`) | Prepare stores `requestID` `req-cl3`. The pending receipt sends `requestId` equal to the operation UUID. `queryOutcome` throws `ClubCommunityFailure.stale` when those differ (`Core/ClubCommunityPendingJournal.swift:437`). `reconcilePendingOperation` does not catch that error. The test's `try await` is bare. | The outcome query must match the recorded `requestId`. |

### Assertion records

These are the other 27 methods inside the 36. CB2 read them as assertion failures (`XCTAssertEqual`, `XCTFail`, or `XCTAssertThrowsError` when the call does not throw). This reading agrees: the failing line does not leave the method as an uncaught product error. They were not given a product change. The gm-test4 table calls the same classes stale against the reviewed contract, or still open there; the source check below is the current file, not a new run.

Six of the 15 unexpected names are not among the eight rules or the one host walk. They are not named in the L1 report, `docs/parity/`, `docs/release/cb2-core-unexpected.md`, `docs/release/cb22-quality.md`, or `docs/release/cb40-test-speed.md`. Static reading did not show six further bare throws in this list. Those six names stay in the unknown section. They are not reassigned onto a class below.

| Tests | Records this note will claim | Why the assertion misses, and why production stays |
|---|---|---|
| `CityNodeRedemptionTests` (5): `testSuccessAndRejectionMessagesRemainByteExact`, `testReviewCancellationHasNoMutationAndConfirmationRechecksAccess`, `testKnownBusinessRejectionShowsExactMessageAndNextCanStartFresh`, `testTimeoutLeavesDurableCoarseLockAcrossNextAndNewEpoch`, `testMalformedMutationResponseRetainsUnknownLock` | Class count from `docs/parity/full-suite-triage.md` and the method names from `docs/parity/close-w5c.md`. Not a split of the 63. | `CityNodeRedemptionResult.init` returns `.unknown` for an inexact 200/400/403/500 body. It does not throw. The tests expect the old byte-exact message and `redeemed`. `CityNodeRedemptionExactContractTests` locks the exact original body. |
| `MerchantStoreIndustrySelectionTests` (3), `MerchantStoreIndustryServiceTests` (2), `MerchantStoreIndustryContractTests` (1), `MerchantOperationsServiceTests` (1), `MerchantOperationsContractTests` (1) | Same. The five class counts are the gm-test4 remainder. | Assertions on a single `categoryId` and the older `/api/merchant/coop-profile` read. `MerchantStoreIndustryTests` still requires `categoryId` on the save body and `categoryIds == nil`. `MerchantStoreDecor.fields()` writes `categoryIds` only for an explicit replacement and does not throw for the fixture. |
| `MerchantNPCTests` (1) | Same. | The `catch` expects `.rejected(403)`. Merchant-chat 403 is `MerchantNPCGameDispatchDenial`. The error is caught. |
| `ProfileGuideReadRouteTests` (2) | Same. | `ProfileGuideReadRoute.detail` accepts a detail reply with `data` omitted (`c6` AjaxResult `success(null)`). `XCTAssertThrowsError` fails because that call does not throw. `docs/release/cb70-gap-register.md` records the same split: `ProfileGuideAbsentDetailProducerTests` requires the accept, and the route tests still expect a throw. |
| `RoamPassportToolsTests` (1), method `testRecapRequestFieldsWeeksAndDuplicateCollapse` | Named by `docs/parity/close-w5c.md` and `docs/parity/exists-audit.md`. | `monthlyRecap` returns. `weeks` is empty because the collapsed item count is not the server total (`Core/RoamPassportTools.swift`, `items.count == total`). The fixture says `routes` total 4 and has 3 distinct items. `RoamMonthlyRecapContractTests` passes with a consistent total. |
| `ClubCommunityReadRuntimeTests` (2) | Same. | `load` catches and returns nil. Page-count assertions fail against the full-list contract written in `f9ca1f42` (`docs/parity/contract-triage-gm-test.md`). |
| `ClubCommunityPendingJournalTests.testPersistBeforeSendExcludesTokenBodyAndImagesAndRecoversUnknownAcrossRestart` | The other method in this class is the unexpected row above. | Assertion that the persisted JSON does not contain `req-1`. The journal stores that request id. Later `try` calls in that method do not throw. |
| `NativeFriendTransportTests.testExactHTTP401AuthenticationRefusalClearsFlowJournalAndNotifiesCurrentSession` | The other two methods in this class are the unexpected rows above. | `flow.perform` does not throw. The journal-clear check is an assertion. |
| `PrivateHomeRecoveryFenceTests` (2) | Same. `load` is not `throws`. | The fresh-journal test expects `.ready` (`Tests/CoreTests/PrivateHomeRecoveryFenceTests.swift:191`). A failed `PrivateHomeSnapshot.validate` takes the `load` catch and sets `.blocked` (`Core/PrivateHomeCoordinator.swift:73`). The same snapshot JSON is used by `PrivateHomeCurrentReadbackFenceTests`, which is not in the 36. This note does not pick a second method, and it does not treat the phase mismatch as a defect to patch: the validate gate is what the current-read tests require. |
| `NativeChannelMessageOriginalWriterJournalTests` (2) | Same. | Quoted-send and plain-receipt failures are inside `do/catch` (`XCTFail` or the wrong `APIError`). `testUnknownPublicReferenceWireCannotSilentlySendOnlyText` and `testPlainReceiptCannotSettleReferenceButOriginalLookupKeyRemainsExact` catch `.notConfigured`. A different caught error is an assertion. |
| `SquareReportTests` (1), `MessagingVisibilityTests` (1) | Same. The visibility method is named here from the assertion site. The SquareReport method is not named in the log. | `Tests/CoreTests/MessagingVisibilityTests.swift:80` expects `IMCardAction.actions(...).first?.destination == .topic(42)`. The fixture is `cardType` `route` with content that does not have the `[路线]` prefix. `IMRouteCardProjection.read` (`Core/IMExpandedContracts.swift:83`) returns nil, and `actions` returns `[]` (`:164`). `IMRouteProjectionLifecycleTests` locks that prefix. The SquareReport failure is one assertion in that class. No bare `try` on the failing path was shown to be the error that escapes. |

## Unknown

Six unexpected names. The Mac summary is 15 unexpected. Nine are the eight fail-closed rows plus the one host filesystem walk. The other six are not named in the L1 report, the parity docs, cb2, cb22, or cb40. This machine cannot run the suite. Those six names are not invented here, and they are not labeled host accessibility.

Each of those six is one unexpected record. If one of them also failed an assertion before the throw, that extra record is inside the 63 and is not separately named. This note does not move any of the 63 into the unknown count.

## What was left

| Bucket | Failure records from the 78 | Product edit |
|---|---:|---|
| Host accessibility | 0 | None. The AppUnit host rows above stay outside this total. |
| Host filesystem | 1 (`persistence` on the historical-root walk) | None. The sibling symlink test requires `O_NOFOLLOW`. |
| Unknown unexpected | 6 | None. Names are not in the recorded docs. |
| Fail-closed unexpected, proved | 8 | None. A newer test locks each rule. |
| Assertion records | 63 | None. Stale fixture or caught mismatch. Per-line assignment is not in the repo. |

Code fixes: 0.

## Not run

- `swift test`, `swift build`, `xcodebuild`, `xcrun`
- The 36 methods, including the eight fail-closed tests and `MerchantOfferWithdrawalUnifiedStoreTests.testKnownHistoricalRootReadsExactScopeAndNeverAcknowledgesOrRewrites`
- `tools/current_ci.py refresh` and any write to `tools/current_ci_manifest.json`
