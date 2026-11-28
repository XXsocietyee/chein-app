# K18 Core swift test burn-down

Branch `cursor/1128-core-tests`. It contains `origin/ui/combined-r7` at `c4e43841afaddd576a72104f8bf8641af2060732` (merged, not rebased). A later fetch moved `origin/ui/combined-r7` to `a7c956335e765f618f7bc86480aa523015bc6e30`. This burn-down was not rebased onto that tip.
Command: `swift test --disable-sandbox` from the repo root. No `xcodebuild`, no simulator, no DerivedData.

## Counts

| run | executed | unique failing tests | assertion records |
|---|---:|---:|---:|
| first invocation | 0 | — | 1 compile error |
| `/tmp/cursor-1128-core-tests-2.log` (the named start) | aborted after the runner had summed about 9805 | 9 | 25, then signal 5 |
| first complete run, after the crash fix | 18411 (2 skipped) | 29 | 54 (10 unexpected) |
| ending run, `/tmp/cursor-1128-core-tests-10.log` | 18411 (2 skipped) | **22** | 44 (8 unexpected) |

The first invocation did not run tests. `Tests/CoreTests/AccountDeregistrationAppleReauthTests.swift` called a `@MainActor` initializer from a default argument. The helper now builds that fake inside the MainActor method. Deletion assertions were not edited. That class then passed.

The named run then died with `Index out of range` as `OwnerDecisions1124Tests` started. `MerchantStaffApproval` dropped a pending row because JSON `0` matched `is Bool` on Darwin, so status 0 never became a row. `Core/MerchantStaffApproval.swift` now accepts a number only when it is not a CFBoolean. The test was not edited. The suite completes.

The 9 failures seen before that abort were `ClubCommunityReadRuntimeTests`, `HomeSearchTabParityTests`, `IMExpandedTests`, `LocaleDisplayR2Tests`, `MemberBenefitsLifetimeTests`, `MerchantOfferWithdrawalUnifiedStoreTests`, `OPTTriageClosureTests`, `OfflineRetryPackage63Tests`, and `OwnerDecisionGuardTests`. Four of those were stale and now pass. The other five are in the ending 22.

One later full run, under a loaded machine, also failed `WorkshopLibraryReadRejectionRecoveryTests.testLate401CannotRetireNewOwnedPresentation` because its 1000-yield wait returned before the paused read suspended. That test passed on the runs before and on the ending run. It was not edited.

## Stale tests updated (product left as shipped)

- `ClubCommunityReadRuntimeTests`: the feed body now includes `hasMore: false`. The runtime refuses a feed that omits it, then the club cursor kept paging.
- `HomeSearchTabParityTests`: English banner titles follow the shipped order (activity, club, merchant). Route paths already did.
- `IMExpandedTests`: the read cursor is multipart (`name="conversation_id"` / `name="read_to"`). `last_message_id` stays absent.
- `OPTTriageClosureTests`: cart citations moved to `ChinaReviewedRouteCapability.swift:938` and `:2769`. The same strings are still required.
- `PlayFullStoryH3Tests`: a named `who` is a margin `.line`, not an `Ada：` prefix. A branch with no cast is omitted.
- `SearchMapTests`: activity list `pageSize` is 10 (`Core/SearchMapPagination.swift:6`). The pin of 50 was stale.
- `RoamOfficialTasksTests` mine rows: a joined id is kept only when it is also in the roam list (`Core/RoamOfficialTasks.swift:81`). The fixture id is 71, which is in that list. The unsigned-read test was not changed.
- `ProjectEditRichStoryFixtures`: gallery, branch, line, and divider are part of `richKinds`. The line carries a speaker, which `Core/ProjectEditRichStoryContract.swift:154` requires.
- `StoreCharacterTests`: the voice reset and voice-status fixtures now hold one scope id for the call. `scope: { UUID() }` minted a new id on every read, so the shipped stale-scope check (`Core/StoreCharacterService.swift:200` and `:208`) fired before the body and review assertions. Those assertions are unchanged. The rotating-scope test in the same file was not changed.

## Left for the owner

Money, payout, privacy, permission, or deletion. Not edited, except the deletion compile helper above (assertions unchanged).

| test | line | what the ending run showed |
|---|---|---|
| `LocaleDisplayR2Tests.testYuanAmountsRelabelsOnlyOutsideChineseAndNeverTwice` | `Tests/CoreTests/LocaleDisplayR2Tests.swift:58` | English text stays `¥30.00`, not `CN¥30.00`. `Core/LocaleDisplay.swift:31` uses the narrow symbol in every locale. |
| `MemberBenefitsLifetimeTests.testOriginalPermissionMappingDoesNotInferEarningsFromRoleOrMissingFlags` | `Tests/CoreTests/MemberBenefitsLifetimeTests.swift:114` | 8 benefit rows, test still wants 9. `Core/MemberHome.swift:223`. |
| `MerchantOfferWithdrawalUnifiedStoreTests.testKnownHistoricalRootReadsExactScopeAndNeverAcknowledgesOrRewrites` | `Tests/CoreTests/MerchantOfferWithdrawalUnifiedStoreTests.swift:98` | `persistence` before any row. `Core/MerchantOfferWithdrawalOriginalJournal.swift` opens the historical root with `O_NOFOLLOW`. |
| `OfflineRetryPackage63Tests.testMoneyAndPayoutWritesAreNotQueuedAndProductionHostIsRefused` | `Tests/CoreTests/OfflineRetryPackage63Tests.swift:623` | `/prod-api/api/pay/create` is `routeNotIdempotent`, not `moneyWriteNeverAutoReplayed`. `Core/OfflineIdempotentWriteQueue.swift:316`. `normalized` keeps the `/prod-api` prefix, so the `/api/pay/` marker misses it. |
| `OwnerDecisionGuardTests.testOWND05cPayoutWritesSendNothingWhileClosedAndProductionRefusesThem` | `Tests/CoreTests/OwnerDecisionGuardTests.swift:185` | The recorder is not empty after the unbind this test requires to be sent. |
| `PayoutReceiverClientTests.testChinaProductionRefusesEveryPayoutRouteUntilTheSwitchOpens` | `Tests/CoreTests/PayoutReceiverClientTests.swift:132` | `api/club/settlement/mine` is admitted while the switch is closed. |
| `PrivacyProtectionPageModelTests` (3) | `Tests/CoreTests/PrivacyProtectionPageModelTests.swift:106`, `:148`, `:214` | Usage-record route is `liveInProduction`. Unknown and literal zero render text. Money switches stay off. |
| `ProfileContractTests.testOrderDetailFactsFollowTheMiniProgramCard` | `Tests/CoreTests/ProfileContractTests.swift:132` | Two `金额待确认` rows. The product also emits the omitted processing amount. |
| `ReleaseMoneyWriteSwitchDerivationTests.testReleaseBuildKeepsCompileTimeConstants` | `Tests/CoreTests/ReleaseMoneyWriteSwitchDerivationTests.swift:27` | `payment`, `payout`, `withdrawal`, `virtualGoods`, `refund`, and `hostCancelRefund` constants failed. |
| `StripePayContractsTests.testUSDQuoteChannelsCountAsAppChannels` | `Tests/CoreTests/StripePayContractsTests.swift:119` | `malformedResponse`. |
| `WP08HostTipSurfaceTests.testGrantCoversTheNamedRoutesAndLeavesMoneyClosed` | `Tests/CoreTests/WP08HostTipSurfaceTests.swift:41` | `/api/coupon/usability` is live. |
| `ZzZzCov4AccountPublishPinTests.testQuoteCreatePayRefundPayoutWithdrawalAndPricingConfirmSendNothing` | `Tests/CoreTests/ZzZzCov4AccountPublishPinTests.swift:191` | A pay/refund/payout pin sent, and a later call did not throw (`:203`). |
| `ZzZzZzCov4ClubContractPinTests.testPayRefundPayoutWithdrawalPaidOrdersQuoteCreateAndPricingConfirmSendNothing` | `Tests/CoreTests/ZzZzZzCov4ClubContractPinTests.swift:272` | Same shape on the club pin (`:286`). |

Product still disagrees with the test. Tests were not rewritten to match.

| test | test line | product line |
|---|---|---|
| `PlayModeLifecycleTests.testFreeEvidenceRejectsOrientationAnswerGPSAndSensorCommands` | `Tests/CoreTests/PlayModeLifecycleTests.swift:90` | One free-mode evidence did not throw. A later one threw `invalidAction` at `Core/PlayExperienceCoordinator.swift:478`. |
| `PlayReadCapabilityTests.testServerSpectatorMarkerDoesNotGrantRegistrationOrCompletion` | `Tests/CoreTests/PlayReadCapabilityTests.swift:72` | `Core/PlayProgression.swift:37` treats `leadSpectator == true` as past `registrationRequired` (`active`). |
| `RoamOfficialTasksTests.testUnavailableOrUnsignedSceneNeverReads` | `Tests/CoreTests/RoamOfficialTasksTests.swift:63` | `Core/RoamOfficialTasks.swift:77` still reads `activeForRoam()` when the scene is configured, including a guest. |
| `SignedInContentDetailTests.testActivityMalformedAndUnauthorizedEnvelopeStayErrors` | `Tests/CoreTests/SignedInContentDetailTests.swift:82` | `Core/ActivityService.swift:69` turns a string `"code":"200"` into 200, so that envelope is not an error. |
| `SignedInContentDetailTests.testGuestTopicDetailDoesNotDispatchAndRoleABADropsLate401` | `Tests/CoreTests/SignedInContentDetailTests.swift:114` | `Core/TopicReading.swift:55` sends a guest topic detail. The call returned `malformedResponse`, and the request list was not empty. |
| `TemplateShelfReadTests.testCanonicalActualBuildersAndBoundedPages` | `Tests/CoreTests/TemplateShelfReadTests.swift:40` | `Core/TemplateAuthoringWireRequestBuilder.swift:29` rebuilds the shelf request without `scope`, so `scope: "MERCHANT"` throws `invalidRequest`. |
| `TopicTests.testTopicDisplayDoesNotPromoteCollaboratorsOrPublisherToInitiator` | `Tests/CoreTests/TopicTests.swift:58` | `Core/TopicContracts.swift:369` keeps `memberId` as `ownerMemberID`, and `:402` uses `contentPublisherName` as the publisher. |

## Gates

- `python3 tools/check_scaffold.py` PASS, exit 0 (appsession ratchet included)
- `python3 tools/check_a11y_lint.py` PASS, 0 new, exit 0
- `python3 tools/contract_ratchet.py --check` 46 failing, baseline 46, new 0, fixed 0, exit 0
- `App/AppSession.swift` is 7977 lines
- No `String(localized:)` literals added
