# K18 Core swift test burn-down

Branch `cursor/1128-core-tests` was cut from `origin/ui/combined-r7` `97b4ef2c28f44594743425a4c0ff272314e1900c`. The suite ran on top of `c4e43841afaddd576a72104f8bf8641af2060732` (that commit is the next tip of combined-r7 and is already on `origin/ui/combined-r7`). A later fetch moved combined-r7 to `a7c956335e765f618f7bc86480aa523015bc6e30`; this burn-down was not rebased onto that tip.
Command: `swift test --disable-sandbox` from the repo root. No `xcodebuild`, no simulator, no DerivedData.

## Counts

| run | executed | unique failing tests | assertion records |
|---|---:|---:|---:|
| start, compile | 0 | — | 1 compile error |
| start, after the compile helper | 9805, then the runner aborted | 9 observed | 25 |
| end | 18411 (2 skipped) | **25** | **47** (10 unexpected) |

The first invocation did not run tests. `Tests/CoreTests/AccountDeregistrationAppleReauthTests.swift:38` called a `@MainActor` initializer from a default argument. The helper now builds that fake inside the MainActor method. Deletion assertions were not edited. The class then passed 7/7.

The next run died with `Index out of range` once `MerchantStaffApproval` dropped a pending row. JSON `0` matched `is Bool` on Darwin, so status 0 never became a row and the test subscripted an empty list. `Core/MerchantStaffApproval.swift` now accepts a number only when it is not a CFBoolean, the same rule as the rest of Core. The test was not edited. The suite completes.

The 9 failures seen before that abort were `ClubCommunityReadRuntimeTests`, `HomeSearchTabParityTests`, `IMExpandedTests`, `LocaleDisplayR2Tests`, `MemberBenefitsLifetimeTests`, `MerchantOfferWithdrawalUnifiedStoreTests`, `OPTTriageClosureTests`, `OfflineRetryPackage63Tests`, and `OwnerDecisionGuardTests`. The four stale ones in that set now pass. The other five are in the ending 25. Everything after `OwnerDecisions1124Tests` had not run yet.

`WorkshopLibraryReadRejectionRecoveryTests.testLate401CannotRetireNewOwnedPresentation` is one of the 25. It passed the two earlier full runs and passed again alone. The ending miss is the helper at `Tests/CoreTests/WorkshopLibraryReadRejectionRecoveryTests.swift:21` (`Expected synthetic suspended read`) after 1000 yields, before the product assertions. It is not in the owner table. With the two store-character fixtures corrected after this run, the remaining set from these 25 is 23, and 22 of those are listed below.

## Stale tests updated (product left as shipped)

- `ClubCommunityReadRuntimeTests`: the feed body now includes `hasMore: false`. The runtime refuses a feed that omits it, then the club cursor kept paging. Request count stays 9.
- `HomeSearchTabParityTests`: English banner titles follow the shipped order (activity, club, merchant). Route paths already did.
- `IMExpandedTests`: the read cursor is multipart (`name="conversation_id"` / `name="read_to"`), which the sibling start/mute/read test already locks. `last_message_id` stays absent.
- `OPTTriageClosureTests`: cart citations moved to `ChinaReviewedRouteCapability.swift:938` and `:2769`. The same strings are still required. Wallet lines did not move.
- `PlayFullStoryH3Tests`: a named `who` is a margin `.line`, not a `Ada：` prefix. A branch with no cast is omitted. `testDeclarationIsServerFormatAndOmitsUnrenderedBranch` already requires that omission.
- `SearchMapTests`: activity list `pageSize` is 10 (`Core/SearchMapPagination.swift:6`, the mini-program page size). The pin of 50 was stale.
- `RoamOfficialTasksTests`: joined rows are kept only when their id is also in the roam list (`Core/RoamOfficialTasks.swift:81`). The fixture id is 71, which is in that list. 81 was dropped on purpose.
- `ProjectEditRichStoryFixtures`: gallery, branch, line, and divider are part of `richKinds`. The line carries a speaker, which `Core/ProjectEditRichStoryContract.swift:154` requires. Both rich-story serialization tests pass.
- `StoreCharacterTests`: `run` and `runWrite` compare the scope captured before the call with the scope after it (`Core/StoreCharacterService.swift:200` and `:208`). The fixtures passed `{ UUID() }`, so each read was a new scope and the product correctly threw `staleScope` / `outcomeUnknown`. Both tests now keep one scope. They passed when filtered after that change. The full-run count below still includes them.

## Left for the owner

Money, payout, privacy, or permission. Not edited.

| test | line | what the run showed |
|---|---|---|
| `LocaleDisplayR2Tests.testYuanAmountsRelabelsOnlyOutsideChineseAndNeverTwice` | `Tests/CoreTests/LocaleDisplayR2Tests.swift:58` | English text stays `¥30.00`, not `CN¥30.00`. `Core/LocaleDisplay.swift:31` uses the narrow symbol in every locale. |
| `MemberBenefitsLifetimeTests.testOriginalPermissionMappingDoesNotInferEarningsFromRoleOrMissingFlags` | `Tests/CoreTests/MemberBenefitsLifetimeTests.swift:114` | 8 benefit rows, test still wants 9. Earnings stay closed. `Core/MemberHome.swift:223`. |
| `MerchantOfferWithdrawalUnifiedStoreTests.testKnownHistoricalRootReadsExactScopeAndNeverAcknowledgesOrRewrites` | `Tests/CoreTests/MerchantOfferWithdrawalUnifiedStoreTests.swift:98` | `persistence` before any row. `Core/MerchantOfferWithdrawalOriginalJournal.swift:25` opens the historical root with `O_NOFOLLOW`. |
| `OfflineRetryPackage63Tests.testMoneyAndPayoutWritesAreNotQueuedAndProductionHostIsRefused` | `Tests/CoreTests/OfflineRetryPackage63Tests.swift:623` | `/prod-api/api/pay/create` is `routeNotIdempotent`, not `moneyWriteNeverAutoReplayed`. `Core/OfflineIdempotentWriteQueue.swift:316`. `normalized` keeps the `/prod-api` prefix, so the `/api/pay/` marker misses it. |
| `OwnerDecisionGuardTests.testOWND05cPayoutWritesSendNothingWhileClosedAndProductionRefusesThem` | `Tests/CoreTests/OwnerDecisionGuardTests.swift:185` | The recorder is not empty after the unbind this test requires to be sent. |
| `PayoutReceiverClientTests.testChinaProductionRefusesEveryPayoutRouteUntilTheSwitchOpens` | `Tests/CoreTests/PayoutReceiverClientTests.swift:132` | `api/club/settlement/mine` is admitted while the switch is closed. |
| `PrivacyProtectionPageModelTests` (3) | `Tests/CoreTests/PrivacyProtectionPageModelTests.swift:106`, `:148`, `:214` | Usage-record history is shown (`:106`). The usage-record route is `liveInProduction` (`:214`). Unknown renders `—` and literal zero renders `0` (`:148`). |
| `ProfileContractTests.testOrderDetailFactsFollowTheMiniProgramCard` | `Tests/CoreTests/ProfileContractTests.swift:132` | Two `金额待确认` rows. `Core/ProfileContracts.swift:635` also emits the omitted processing amount. |
| `ReleaseMoneyWriteSwitchDerivationTests.testReleaseBuildKeepsCompileTimeConstants` | `Tests/CoreTests/ReleaseMoneyWriteSwitchDerivationTests.swift:27` | Compile-time constants failed: `payment`, `payout`, `withdrawal`, `virtualGoods`, `refund`, `hostCancelRefund`. |
| `StripePayContractsTests.testUSDQuoteChannelsCountAsAppChannels` | `Tests/CoreTests/StripePayContractsTests.swift:119` | `malformedResponse`. |
| `WP08HostTipSurfaceTests.testGrantCoversTheNamedRoutesAndLeavesMoneyClosed` | `Tests/CoreTests/WP08HostTipSurfaceTests.swift:41` | `/api/coupon/usability` is live. Money paths were not opened. |
| `ZzZzCov4AccountPublishPinTests.testQuoteCreatePayRefundPayoutWithdrawalAndPricingConfirmSendNothing` | `Tests/CoreTests/ZzZzCov4AccountPublishPinTests.swift:191` | A pay/refund/payout pin sent, and a later call did not throw. |
| `ZzZzZzCov4ClubContractPinTests.testPayRefundPayoutWithdrawalPaidOrdersQuoteCreateAndPricingConfirmSendNothing` | `Tests/CoreTests/ZzZzZzCov4ClubContractPinTests.swift:272` | Same shape on the club pin. |

Product still disagrees with the test. Tests were not rewritten to match.

| test | test line | product line |
|---|---|---|
| `PlayModeLifecycleTests.testFreeEvidenceRejectsOrientationAnswerGPSAndSensorCommands` | `Tests/CoreTests/PlayModeLifecycleTests.swift:90` | `Core/PlayExperienceCoordinator.swift:478` throws `invalidAction`; one evidence did not throw. |
| `PlayReadCapabilityTests.testServerSpectatorMarkerDoesNotGrantRegistrationOrCompletion` | `Tests/CoreTests/PlayReadCapabilityTests.swift:72` | `Core/PlayProgression.swift:37` treats `leadSpectator == true` as past `registrationRequired` (`active`). |
| `RoamOfficialTasksTests.testUnavailableOrUnsignedSceneNeverReads` | `Tests/CoreTests/RoamOfficialTasksTests.swift:63` | An unconfigured or unsigned scene still reads. Failed again alone. |
| `SignedInContentDetailTests.testActivityMalformedAndUnauthorizedEnvelopeStayErrors` | `Tests/CoreTests/SignedInContentDetailTests.swift:82` | A string `"code":"200"` envelope was not kept as an error. |
| `SignedInContentDetailTests.testGuestTopicDetailDoesNotDispatchAndRoleABADropsLate401` | `Tests/CoreTests/SignedInContentDetailTests.swift:114` | Late 401 arrived as `malformedResponse`, not `unauthorized`. |
| `TemplateShelfReadTests.testCanonicalActualBuildersAndBoundedPages` | (caught error) | `Core/TemplateAuthoringWireRequestBuilder.swift:29` `invalidRequest`. |
| `TopicTests.testTopicDisplayDoesNotPromoteCollaboratorsOrPublisherToInitiator` | `Tests/CoreTests/TopicTests.swift:58` | Decoded `TopicDetail` is not equal to the no-collaborator value. |

`RoamOfficialTasksTests.testCompleteSceneReadsOnlyTwoExistingListContracts`, `testFourBucketsReuseExistingOfficialStatusContract`, and `SearchMapTests.testCityNodesUseGETCamelCaseAndActivitySourceUsesFormSnakeCase` were red on the run before the fixture updates above. They pass with those fixtures and are not in the ending 25.

## Gates

- `python3 tools/check_scaffold.py` PASS (appsession ratchet included)
- `python3 tools/check_a11y_lint.py` PASS, 0 new
- `python3 tools/contract_ratchet.py --check` 46 failing, baseline 46, new 0
- `App/AppSession.swift` is 7977 lines
- No `String(localized:)` literals added
