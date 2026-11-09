# CB2 — Core unexpected failures

Base: `origin/rc/20261108` `a6871477c497c6440ce06417035572d7278ea830`.
Package: `QuestifyCore` (`Core/`, tests in `Tests/CoreTests`).

## What was run

`swift`, `swiftc`, `xcodebuild`, and `xcrun` are not on `PATH` in this environment. `swift test --disable-sandbox` was not executed. No new test count is claimed.

The baseline line, from the Mac L1 run (`swift test --disable-sandbox` in `/private/tmp/rc-final`, log `/private/tmp/rcfinal-core.log`, reported in `#chengyin-rc` and `docs/release/cursor-L1-report.md` on `origin/cursor/L1`), is:

```text
Executed 15473 tests, with 78 failures (15 unexpected) in 53.331 (54.147) seconds
```

`SWIFT_TEST_EXIT=1`. That run changed no product source. The same 15 unexpected were already the Core baseline at 15238 and 15004 tests (`docs/parity/final-integration-regression.md`, `docs/parity/full-suite-triage.md`). L1: 36 unique failing tests, 21 classes, every class already in `docs/parity/full-suite-triage.md`. Three classes that failed on gm-test4 now pass (`InvoiceLaunchCoordinatorTests`, `ParticipantCoordinatorTests`, `ParticipantCoordinatorSnapshotLifetimeTests`), which is the drop from 39 tests / 16 unexpected to 36 / 15.

On this runner an unexpected failure is an error that leaves the test method (`caught error`), not an `XCTAssert` / `XCTUnwrap` issue. `CouponRuntimeCompositionTests` records 22 assertion failures and 0 unexpected; `MerchantReviewOriginalRecoveryEntryTests` records 11 `caught error: invalidConfiguration` and 11 unexpected (`docs/parity/gap-wave-compare.md`). The 78 failure records are multiple assertions per test (`continueAfterFailure` stays on), so 15 unexpected means 15 tests that throw out, and the other failure records are assertions.

`makeComposition(reviewed: nil)` was not changed. `tools/current_ci_manifest.json` was not refreshed.

## iOS 27 host accessibility tree

Not part of this Core list. `WalletEarningsSegmentHitAreaTests` fails in AppUnit because an iOS 27 `AccessibilityNode` answers `accessibilityIdentifier` but is not `UIAccessibilityIdentification`, so `as? UIAccessibilityIdentification` is nil. That is a host baseline, not a QuestifyCore product bug. Core `swift test` does not run the iOS 27 host.

## Unexpected failures proved from the test and the callee

Each row is a test whose first uncaught product error leaves the method. None of these is a product defect to “fix” by accepting the stale fixture: a newer test locks the fail-closed rule, and loosening production would fail that test. Fix SHA is `baseline`.

| Test | File:line | Cause | Fix |
|---|---|---|---|
| `ClubActionServiceTests.testJoinApplyAndLeaveUseCurrentJSONContract` | `Tests/CoreTests/ClubActionServiceTests.swift:15` | The loop calls `perform` for join, then apply, with the default `joinMessage` `""`. `ClubActionService.perform` throws `APIError.invalidRequest` because `ClubApplicationMessage.isValid` is false for an empty apply. Join would have passed. | baseline. `ClubApplicationRequiredMessageTests.testOnlyApprovalApplicationRequiresNonblankMessage` requires a non-empty apply message and an empty join/leave message. The two generations disagree; production keeps the non-empty rule. |
| `ClubActionServiceTests.testApplicationMessagePreservesReviewedUnicodeAndJSONEscaping` | `Tests/CoreTests/ClubActionServiceTests.swift:113` | The message loop starts with `""` and `"   "`. Both fail `isValid` for `.apply` before any request is built, so `perform` throws `APIError.invalidRequest`. | baseline. Same rule. Whitespace-only is not a reviewed application message. |
| `ClubActionSessionTests.testFreshDetailPrecedesEveryMembershipWrite` | `Tests/CoreTests/ClubActionSessionTests.swift:55` | `ClubActionSessionWriter.perform(.apply)` checks `ClubApplicationMessage.isValid` and throws `ClubActionWriteError.notSent(.invalidRequest)` before the detail read. The test expects detail then join. | baseline. The session writer is the public dispatch boundary and revalidates the message before it reads. |
| `ClubActionCoordinatorTests.testApplicationRemainsPendingAndDoesNotGrantMembers` | `Tests/CoreTests/ClubActionCoordinatorTests.swift:104` | `prepare(..., action: .apply)` uses the default empty message and throws `ClubActionBlock.invalidMessage` (`ClubActionCoordinator.swift`) before confirm. | baseline. Same `isValid` rule, checked before the confirmation is stored. |
| `NativeFriendTransportTests.testActualServiceDecodesPendingAndEveryTerminalOriginalReceipt` | `Tests/CoreTests/NativeFriendTransportTests.swift:172` | `reviewPayload` omits `payload_hash`. `NativeFriendService.validate` throws `NativeFriendFailure.invalid` for every non-`UNKNOWN` receipt whose hash is not `^[0-9a-f]{64}$`. The `try await service.receipt` is not caught. | baseline. `payload_hash` is the receipt coding key. Dropping the check would accept a terminal receipt that does not match the original intent. |
| `NativeFriendTransportTests.testActualReviewCancelSendsExactProposalAndRejectsDifferentReceipt` | `Tests/CoreTests/NativeFriendTransportTests.swift:197` | The first `write` throws `NativeFriendFailure.invalid` from the same hash check (the catch expects `.unknown`, which is an assertion). Execution continues and the second bare `try await service.write` throws `.invalid` again. | baseline. Same hash check. The assertion mismatch (`.invalid` vs `.unknown`) is a separate expected failure inside the `catch`. |
| `MerchantPersonalIncomeEligibilityTests.testOtherRouteDenied` | `Tests/CoreTests/MerchantPersonalIncomeEligibilityTests.swift:14` | `snapshot(route: "")` builds a redemption whose `settlementRoute` is empty while the other finance fields stay filled. `MerchantBusinessSnapshot` init throws `MerchantBusinessFailure.malformed`: a redemption detail must be complete finance or wholly redacted (`MerchantBusinessDocuments.swift`). | baseline. A half-filled finance block must not become a document that eligibility can read. `PUBLIC_TRANSFER` is a complete route and is denied by the matcher; the empty route never reaches the matcher. |
| `ClubCommunityPendingJournalTests.testAuthoritativeHTTPPendingOutcomeQueryReconcilesRestartedPendingRecordWithoutUnlockingOnStillPendingOrMismatch` | `Tests/CoreTests/ClubCommunityPendingJournalTests.swift:339` | Prepare stores `requestID` `req-cl3`. The pending receipt sends `requestId` equal to the operation UUID. `ClubCommunityHTTPPendingOutcomeQuery.queryOutcome` throws `ClubCommunityFailure.stale` when those differ. `reconcilePendingOperation` does not catch that error, and the test’s `try await` is bare. | baseline. The outcome query must match the recorded `requestId`. The sibling test that asserts `req-1` is absent from the journal is an assertion failure, not this throw. |
| `MerchantOfferWithdrawalUnifiedStoreTests.testKnownHistoricalRootReadsExactScopeAndNeverAcknowledgesOrRewrites` | `Tests/CoreTests/MerchantOfferWithdrawalUnifiedStoreTests.swift:98` | `journal.entries` calls `openHistoricalDirectory`, which `openat`s every path component with `O_NOFOLLOW` and throws `MerchantOfferWithdrawalOriginalFailure.persistence` on any symlink component, and `historicalBytes` throws the same error unless the file is a single-link regular file within the size pin. The Mac triage records this one test as the class’s remaining `persistence` throw (the other tests in the class expect throws or do not walk a historical root). Not re-executed here. | baseline. Historical roots are read-only and must not follow a swapped path. The unified store’s root-owned symlink exception is intentionally not copied onto this walk. Loosening `O_NOFOLLOW` to satisfy the temp-directory fixture would accept a symlink the sibling test rejects. |

## Inspected and not unexpected

These are in the 36 failing tests. Their failing line is an assertion (`XCTAssertEqual`, `XCTFail`, or `XCTAssertThrowsError` when the call does not throw). They are not in the unexpected count. Production was not changed to satisfy them.

- `CityNodeRedemptionTests` (5). `CityNodeRedemptionResult.init` returns `.unknown` for an inexact 200/400/403/500 body. It does not throw. The tests assert the old byte-exact message and `redeemed`.
- `MerchantStoreIndustrySelectionTests` (3), `MerchantStoreIndustryServiceTests` (2), `MerchantStoreIndustryContractTests` (1), `MerchantOperationsServiceTests` (1), `MerchantOperationsContractTests` (1). Assertions on a single `categoryId` and the old `/api/merchant/coop-profile` read. `MerchantStoreDecor.fields()` writes `categoryIds` only for an explicit replacement and does not throw for the fixture.
- `MerchantNPCTests` (1). The `catch` expects `.rejected(403)`; merchant-chat 403 is `MerchantNPCGameDispatchDenial`.
- `ProfileGuideReadRouteTests` (2). `XCTAssertThrowsError` / `XCTFail` because a detail reply with `data` omitted is accepted.
- `RoamPassportToolsTests` (1). `monthlyRecap` returns. `weeks` is empty because the collapsed item count is not the server total.
- `ClubCommunityReadRuntimeTests` (2). `load` catches and returns nil. Page-count assertions fail against the full-list contract.
- `ClubCommunityPendingJournalTests.testPersistBeforeSendExcludesTokenBodyAndImagesAndRecoversUnknownAcrossRestart`. Assertion that the persisted JSON does not contain `req-1`. The journal now stores that request id. Later `try` calls in that method do not throw.
- `NativeFriendTransportTests.testExactHTTP401AuthenticationRefusalClearsFlowJournalAndNotifiesCurrentSession`. `flow.perform` does not throw. The journal-clear check is an assertion.
- `PrivateHomeRecoveryFenceTests` (2). `load` does not throw. The fresh journal ends `.blocked` where the test expects `.ready`.
- `NativeChannelMessageOriginalWriterJournalTests` (2). Quoted-send and plain-receipt failures are inside `do/catch` (`XCTFail` or the wrong `APIError`).
- `SquareReportTests` (1), `MessagingVisibilityTests` (1). The visibility failure is `IMCardAction.actions(...).first?.destination` nil against `.topic(42)`, an assertion. The SquareReport failure is one assertion in that class; no bare `try` in the failing path was shown to be the product error that escapes.

The Mac summary still says 15 unexpected. The nine rows above are every escaping product error this inspection could prove. The other six unexpected names are not in the L1 report, the parity docs, or Slack, and this machine cannot run the suite (no Swift toolchain, and `Core/` imports CryptoKit, Observation, and StoreKit). Those six names are not invented here.
