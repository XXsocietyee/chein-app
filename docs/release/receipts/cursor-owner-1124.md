# Owner decisions 1124

Base `82388e4a5e7391e0c5a286735d6b30613a860ae8`. Branch `cursor/owner-1124`. Money writes stay TEST-only. "Money on" is not yet.

This VM has no `swiftc`. No parse is claimed. No screenshots were taken. `project.pbxproj` and `tools/current_ci_manifest.json` were not edited. `RuntimeLocationProjection` was not edited.

## D1 Platform-pass order reads

Players may GET `/api/platform-pass/orders` and `/api/platform-pass/orders/{orderNo}`. Merchants return before the request. Purchase still throws `PlatformPassWriteRefusal.unreachable`. A POST on the order path is refused on the China host. The path is not a `ReleaseMoneyWriteKind`.

Gate default: **ON** for players (`PlatformPass.orderReadsEnabled = true`). Off for merchants. Not a money write.

Pin: `OwnerDecisions1124Tests.testPlatformPassOrderReadIsOnForPlayersAndIsNotAMoneyWrite`.

## D2 Refunds and host-cancel refunds

`ReleaseMoneyWriteKind.refund` covers `/api/registration/cancel-refund`, `/api/registration/cancel-by-owner`, and `/api/free-explore/bundle/order/refund`. `hostCancelRefund` covers `/api/activity/cancel` only. Preview (`cancel_preview`) and plain `/api/registration/cancel` stay reads or non-refund cancels. Send sites check the switch before a request leaves.

Gate default: **OFF**. Release compiles `refundEnabled = false` and `hostCancelRefundEnabled = false`. A DEBUG/TEST build stays off until `testDerivation` opens that kind.

Pin: `OwnerDecisions1124Tests.testRefundAndHostCancelStayOffUntilATestDerivationOpensThem` and `ReleaseMoneyWriteSwitchDerivationTests.testReleaseBuildKeepsCompileTimeConstants`.

## D3 Media upload retry

`MediaUploadRetry` retries an idempotent upload on a transport failure, with backoff 0.2s then 0.4s, and stops at 3 attempts. A rejection is not retried. A non-idempotent write is one attempt and does not sleep. Existing uploaders that are not idempotent were not wrapped.

Gate default: retry **ON** only when the caller marks the upload idempotent. Non-idempotent retry is **OFF** (one attempt).

Pin: `OwnerDecisions1124Tests.testMediaUploadRetriesOnlyAnIdempotentTransportFailureUpToThreeTimes`.

## D4 Merchant staff approve and reject

`MerchantStaffApproval` lists `POST api/merchant/chapter-application/owner-list` `{topicId}` and audits `POST api/merchant/chapter-application/audit` `{applicationId, approved, auditRemark}`. Pending rows are status 0. A reject with an empty remark does not send. The caller must be the owner or an active operator with `merchant:project:manage`. The screen is `App/MerchantApprovals/MerchantStaffApprovalView.swift` (system `List`, semantic text styles from `.largeTitle` through `.caption`). Its glob is in `tools/generate_project.py`. Copy is `Resources/MerchantApprovals.xcstrings` (`en` and `zh-Hans`).

Gate default: the screen and contract are present. A caller without the permission sends nothing.

Pin: `OwnerDecisions1124Tests.testMerchantStaffApprovalMatchesTheAuditContractAndChecksPermission`.

## D5 Money display

`MoneyDisplay.current` stays `.twoDecimals`. `MoneyDisplay.yuan(fen:)` is the shared formatter (`¥12.50`). Club welcome member price, enrollment session fen, and both platform-pass yuan formatters call it. Distances, ratings, percents, and hours were left alone.

Gate default: **two decimals**.

Pin: `OwnerDecisions1124Tests.testSharedMoneyFormatterUsesTwoDecimals`, `ClubEnrollmentTests.testSessionMoneyFormatsServerFenOnly`, `ClubCoreClubContractTests` member price, `MPParityPassBindingTests`.

## D6 GPS arrival lock

`ChapterArrivalLock.opens` is true only after arrival at a stop in the chapter, and only when the server has not locked the chapter. `PlayLeadProgress` will not unlock the next chapter until `meArrived` and `allArrived`. The free-exploration archive uses the same lock. A WGS-84 fix between 100 m and 200 m stays `PlayArrivalProjection.isUnprojectableAccuracy` (a local accuracy failure). `RuntimeLocationProjection` was not edited.

Gate default: next chapter **locked until arrival**.

Pin: `OwnerDecisions1124Tests.testNextChapterOpensOnlyOnArrivalAndWGS84BandStaysALocalAccuracyFailure`.

## D7 P4 game kits

`PlayKitPilotGate` allows a kit only when the event id is in `pilotEventIDs`. The set starts empty. `PlayExperienceView` does not publish `playGameStage` unless the gate allows `result.topicID`. Release compiles `allows` as a constant false. `PlayStageAnalyticsGate` stays off.

Gate default: **OFF**.

Pin: `OwnerDecisions1124Tests.testPlayKitPilotGateIsOffUntilAnEventIsAdded`.

## D8 Story cast

`CastCapability.productionEnabled` is `[]`. `PlayExperienceCoordinator.makeCastCoordinator` uses that set. Enabling the three capabilities against the China production host still sends nothing for `/api/topic/cast/voice`, `/api/play/run/profile`, and `/api/play/run/branch`. No cast capability was added. Fixture hosts are unchanged.

Gate default: production cast **OFF** (empty set). Fixtures only.

Pin: `OwnerDecisions1124Tests.testProductionCastStaysOnFixturesAndSendsNoneOfTheThreeRoutes`.
