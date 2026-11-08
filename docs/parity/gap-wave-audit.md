# gap-wave audit (GM-AUD, branch gm-aud from wip/gm-gap b6ac705d)

63 rows flipped partial -> exists by the gap wave were checked against the cited tests. `exists` 128 -> **112**, `partial` 20 -> **36** (16 rows reverted). CSV validated: 163 data rows + header, 6 columns each.

## Runs
- Core: `swift test --disable-sandbox --filter` for every cited Core class (72 classes, 616 tests) -> `/private/tmp/gm-aud-core.log`: **1 failure**, `InvoiceLaunchCoordinatorTests.testUnknownApplyRecoversOriginalRequestAfterRestartWithoutWrite` (caught `outcomeUnknown`, Core/InvoiceLaunchCoordinator.swift:183). Extra classes cited as better proof (PlayStoreDayServiceTests, ProfileEditServiceTests, ParticipantServiceTests, ProfileFavoriteRemovalTests, TopicUnlikeTests, WithdrawalHistoryTests, NearbyMerchantCoordinatorTests, NearbyMerchantSearchHTTPProofTests, BankWithdrawalTests): 109 tests, 0 failures (`gm-aud-core2.log`).
- AppUnit (Orca terminal, Questify-iPhone17, `rc1-ptest.sh`): all 13 cited AppUnit classes, 88 tests -> `/private/tmp/gm-aud-app.log`: **1 failure**, `ProfileGuideReadTests.testOrdinaryConfiguredGuideLoadsOriginalListAndRefreshesWithoutWrites` (hosted view: second `infomation_list` refresh never observed). Second pass over previously failing hosted classes (`gm-aud-app2.log`): still fail on iOS 27 sim (OfficialPublicEventCompositionTests, OfficialEventComponentsClosureTests, ProfileFavoriteTopicReadTests, ProfileParticipantHostRecoveryTests, ProfileWeeklyPointsSectionTests, ProjectEditCompositionTests). None of those is the cited proof of a kept row, but they are caveats on official-detail, mylike, points-history, addressinfo and fabu.
- Cited but nonexistent: `PlayStoreDayCoordinatorTests` (play/merchant) - real proof is `PlayStoreDayServiceTests`.
- The 14 earlier-audit failures: the cited classes for the rows now pass except the two above.

## Verdict legend
KEEP = main action (or honest gated state) driven through service/fake transport, passes. REVERT = row goes back to partial.

| row | cited test | ran? result | assertion reviewed? | verdict | action |
|---|---|---|---|---|---|
| pages/deregister/index | AccountComplianceTests 13, AccountDeregistrationParityTests 5, RebaseSafetyTests 18, G1 gate1 | all pass | yes: testFullOriginalJourney drives status->precheck->consents->result->apply->result->status on a fake wire, SMS=1, logout=1, apply carries original header + requestId, repeat apply sends nothing; lost apply response recovers only by GET after fresh login, cancel never sent; WeChat/unavailable stops before consent/SMS | KEEP (server-confirmed end to end) | none |
| pages/play/index | StoryParticipationActionsTests 4 | pass | only the story join/answer sub-feature; note itself said row stays partial | REVERT | partial |
| pages/play/merchant/index | PlayStoreDayPresentationTests 6 (+ nonexistent PlayStoreDayCoordinatorTests) | pass | PlayStoreDayServiceTests: nodes GET, checkin multipart body, consent JSON, unknown checkin resolved by readback, production default sends no writes | KEEP (citation corrected) | note |
| pages/play/poi-challenge/index | ChallengePOISubmissionTests 5 | pass | gated writer never reports done, invalid sends nothing, success uses mini request shape and shows done only after server answer, ambiguous locks | KEEP (note text still says "stays partial"; flagged) | none |
| pages/activity/official-detail/index | OfficialEventDetailPresentationTests 10, OfficialEventTests 38, TimeSafety 12 | pass | OfficialEventTests drive the read with wire assertions; hosted composition tests fail (env) | KEEP (hosted caveat) | none |
| subpackageA/pages/infomation/infomation | ProfileGuideReadTests 17, ProfileGuideAbsentDetailProducerTests 3 | 1 AppUnit FAIL | refresh request not observed | REVERT | partial |
| subpackageP3/pages/badge-wall/index/index | ObjectBadgeWallOrderingTests, GrowthBadgeParityTests, ProfileServiceTests | pass | ordering + service reads | KEEP | none |
| subpackageP3/pages/badge-3d/index | ObjectBadgeTurntableTests 4 | pass | page is a static native preview; gesture/route behavior is the feature | KEEP | none |
| subpackageB/pages/im/chat/index | OrdinaryIMSendReceiptTests 5 | pass | only receipt lookup; send/read dormant | REVERT | partial |
| pages/publish/fabu/index | ProjectCloudDraftIntentTests 12, ProjectEditAuthorSaveContractTests 7 | pass | fake wire: create body, lost response stays unknown and is never resent, rejected publish keeps draft | KEEP (ProjectEditCompositionTests hosted fails, uncited) | none |
| pages/publish/simple/index | QuickPublishValidationTests 4 | pass | validation strings only | REVERT | partial |
| pages/publish/temp/index | TemplateAuthoringHTTPTests 19 | pass | draft->/api/template/draft, publish->/api/template/publish, review/write/readback, unknown, session fence | KEEP | none |
| pages/club/apply/index | ClubHostApplyDraftTests 3 | pass | body builder only, no send | REVERT | partial |
| pages/club/badges/index | ClubBadgeScreenStateTests 6 | pass | list/picker reads only | REVERT | partial |
| pages/club/create/index | ClubCreateQuotaTests 2 | pass | quota precheck only | REVERT | partial |
| pages/club/customers/index | ClubCustomerSearchFilterTests 6 | pass | filter+keyword sent exactly once, failure not empty | KEEP | none |
| pages/club/edit/index | ClubEditDissolveTests 2 | pass | access + command body only | REVERT | partial |
| pages/club/checkin-detail/index | ClubOwnerRefundPanelModelTests 5 | pass | owner flow via fake transport; production grant absent shows not-available, confirm never enabled | KEEP | none |
| pages/club/event-ops/index | ClubOpsEventWriteGateTests 3 | pass | read-only service gives notAvailableYet, nothing sent | KEEP (honest gate) | none |
| pages/club/group-code/index | ClubGroupCodeSessionIssueTests 2 | pass | body builder only | REVERT | partial |
| pages/club/notify/index | ClubNotifyDeliveryStatusTests 4 | pass | send once, status read, malformed never delivered | KEEP | none |
| pages/topic/merchantinfo/merchantinfo | MerchantChapterApplyApprovalTests 3 | pass | tests chapter-apply write, not the content read | REVERT | partial |
| pages/topic/merchantapply/index | MerchantApplyXcxTests 5 (+WriteGate) | pass | body/date rules; disabled service permits no create/update | KEEP (honest gate) | none |
| pages/topic/pricing/index | PublisherLifecycleTests 29 | pass | exact preview/confirm bodies, dormant sends nothing, unknown locks | KEEP | none |
| pages/merchant/aftercare/index | MerchantAftercareParityTests 7, MerchantWorkspaceReadProofTests 8 | pass | ReadProof: bucket+paging query | KEEP | none |
| pages/merchant/predict/index | MerchantPredictionReadTests 7 (core), MerchantPredictionReadCompositionTests 19 (app) | pass | exact read request, permission denial never reads | KEEP | none |
| pages/merchant/aftercare/detail/index | MerchantAftercareResponseGuideTests 5 | pass | JSON body via fake transport, malformed receipt not success | KEEP | none |
| pages/merchant/marketing/index | MerchantMarketingGatedDashboardTests 2 | pass | gated reads unavailable with no request | KEEP | none |
| pages/merchant/reviews/index | CloseW5dMerchantReviewsStateTests 2 | pass | state helper only | REVERT | partial |
| pages/merchant/marketing/ai-insight/index | MerchantMarketingTests 49 | pass | wire assertions | KEEP | none |
| pages/merchant/citynode/create/index | MerchantCityNodeHubTests 11 | pass | placement/save receipt (bare int / object), unknown stays locked | KEEP | none |
| pages/merchant/decor/index | CloseW5dMerchantOperationsHomeStateTests 3 | pass | state helper only | REVERT | partial |
| pages/merchant/decor/ai-npc/index | StoreCharacterGatedStateTests 3 | pass | gated save/photo honest notice, never confirms; SaveProof NPC save OK only after server OK | KEEP | none |
| pages/merchant/decor/coop-setting/index | MerchantOperationsReaderShippedGateTests, MerchantDecorCoopGallerySaveProofTests 4 | pass | exact route, saved only after server OK, rejection not saved | KEEP | none |
| pages/merchant/decor/gallery/index | MerchantGalleryOversizeBlocksWriteTests 1 | pass | cited test thin; SaveProof gallery save patches only gallery after server OK, no approval sends nothing | KEEP (re-cited) | note |
| pages/merchant/coop-center/index | MerchantCoopCenterAccessGateTests 5, MerchantCoopPlazaDenialTests 2 | pass | grant/deny/403/401/malformed home | KEEP | none |
| pages/merchant/customer/index | MerchantCustomerBatchTagTests 3 | pass | batch tag POST through fake transport | KEEP | none |
| pages/merchant/crm-campaigns/index | CloseW5dPageStateTests 3 | pass | state only; MerchantEngagementServiceTests (campaign preview POST, gate sends nothing) | KEEP (re-cited) | note |
| pages/merchant/team/index | MerchantBusinessProductionTests 25, MerchantEngagementServiceTests 11 | pass | wire assertions | KEEP | none |
| pages/coop/invite-detail/index | CooperationInvitePresentationTests 6, DirectionDispatchTests 8 | pass | cancel/accept/reject via fresh prepare+confirm, production default disabled | KEEP | none |
| pages/coop/invite/index | CoopBatchInviteTests 4 | pass | each draft sends exactly one request only after own confirm | KEEP | none |
| pages/coop/nearby/index | NearbyMerchantPermissionStateTests 3 | pass | coordinator permission states; NearbyMerchantCoordinatorTests/SearchHTTPProof also pass | KEEP (re-cited) | note |
| pages/square/detail/index | SquareDetailInteractionTests 6 | pass | comment sends only after confirm, rejection not acked, disabled never sends | KEEP | none |
| pages/addressinfo/addressinfo | ParticipantCoordinatorTests 17, ProfileParticipantValidationAppTests 13 | pass | see section "Changed tests"; ParticipantServiceTests asserts /api/user/address/action multipart | KEEP (ProfileParticipantHostRecoveryTests hosted fails, uncited) | note |
| pages/gerenziliao/gerenziliao | ProfileEditAvatarGateTests 1 | pass | synthetic service only; ProfileEditServiceTests passes | KEEP (re-cited) | note |
| pages/mylike/mylike | AccountCollectionTests 30, AccountCollectionPostTests 13 | pass | reads; removal/unlike proven by ProfileFavoriteRemovalTests, TopicUnlikeTests (confirm required, one request, readback) | KEEP (hosted ProfileFavoriteTopicReadTests fails, uncited) | note |
| pages/crop/index | MiniCropSessionTests 5 | pass | local crop math | KEEP | none |
| subpackageMember/character/index | CharacterCardReadbackTests 15 | pass | read only; Save/attribute labels not wired | REVERT | partial |
| subpackageMember/invoice/index | InvoiceLaunchHistoryRulesTests 6 (app), InvoiceLaunchStatusTests 2 | pass | withdraw needs confirm, success notice only after service success | KEEP | none |
| subpackageMember/invoice-detail/index | InvoiceLaunchCoordinatorTests::testUnknownCancelRecoversOnlyCancelledOriginalDetail | cited test passes (class has 1 unrelated apply failure) | yes | KEEP | none |
| subpackageMember/invoice-apply/index | InvoiceLaunchPresentationActionTests 6 | pass, but coordinator apply-recovery test FAILS | apply send+readback test passes; unknown-apply restart recovery fails | REVERT | partial |
| subpackageMember/invoice-titles/index | InvoiceLaunchPresentationActionTests 6 | pass | save/delete title send + readback | KEEP | none |
| subpackageMember/invoice-title-edit/index | InvoiceLaunchTitleRulesTests 5 + 1 coordinator test | pass | form draft is exact save body, invalid never reaches transport | KEEP | none |
| subpackageMember/complaint/index | ProfileComplaintSubmitTests 6 | pass | success only after writer returns, failure not success, no writer = unavailable | KEEP | none |
| subpackageMember/mytemplate/mytemplate | TemplateAuthoringHTTPTests 19 | pass | shelf multipart, delete review+readback | KEEP | none |
| subpackageMember/points-history/index | WalletPointsLedgerEmptyStateTests 2, AssetPointsLedgerReadbackTests 9 (+G1 gate4) | pass | one ledger read, null balance unknown, conservation; ProfileWeeklyPointsSectionTests hosted fails (uncited) | KEEP | none |
| subpackageMember/tixian/tixian | WithdrawalHistoryGroupingTests 3 | pass | grouping alone is presentation; proof is WithdrawalHistoryTests (bodyless read, states) + G1 gate4 (stages/withdrawals read, `makeBankWithdrawalContext()` nil). Screen has only a contact button; no `/api/withdrawal/apply` caller in App/Core | KEEP (payout stays off) | note |
| subpackageRoam/citynode-code/index | VerificationCodePresentationTests 15, VerificationPresentationAppTests 5 | pass | default service cannot reach transport, exact issue forms | KEEP | none |
| subpackageRoam/history/index | CloseW5dRoamHistoryErrorTests 1 | pass | error mapping helper only | REVERT | partial |
| subpackageRoam/session/index | RoamShareSnapshotHTTPReaderTests 4 | pass | unapproved sends nothing, approved anonymous GET | KEEP | none |
| subpackageRoam/nearby/index | NearbyTeamHTTPReadTests 4 | pass | exact GET query, wrong account sends nothing | KEEP | none |
| subpackageRoam/my-teams/index | NearbyTeamPresentationTests 8, NearbyLoadIssueUnavailableTests 2 | pass | presentation + shared scoped read | KEEP (marginal) | none |
| subpackageTools/capsule/index | RoamCapsuleWriteGateTests 2 | pass | no create/delete dispatch driven | REVERT | partial |

## Changed tests (item 4)
1. **ProfileParticipantValidationAppTests `participant.form.purpose` count 3 -> 0: legitimate.** Mini-program `pages/addressinfo/addressinfo.wxml` now has `<cy-page-title title="参与人信息" subtitle="" />` (comment: the explanation under a duplicate title was removed per design system); the native source on this tree contains no `participant.form.purpose` usage (`grep` over App/*.swift), so the old count of 3 was a stale expectation (it was in the round-4 failure list). Same commit also added `performReturningParticipant` to the test fake, mirroring the backend create reply.
2. **ParticipantCoordinatorSnapshotLifetimeTests nil create ACK `.succeeded` -> `.outcomeUnknown(.malformedResponse)`: correct and safe, and not a Core change in this wave.** `git diff wip/gm-int wip/gm-gap` shows no change to Core/ParticipantCoordinator.swift; the behavior (`ParticipantOriginalCreateRetry.accepts(row)` else `outcomeUnknown(.malformedResponse)`, Core/ParticipantCoordinator.swift:245-248) was already in gm-int and the test was the stale party. Backend `ApiUmsMemberController.userAddressActoin` (`/api/user/address/action`): create -> `insertOwnedAddressIdempotent(...)` returns `success(saved)` (the row) or `error("请求标识无效，请重新提交")`; edit -> `success()` with no row. A create 200 without a row therefore cannot prove a write; staying `outcomeUnknown` keeps the lock and recovers by read-only readback, never resubmits, never claims success. Edit/delete are unaffected (row required only for create). Also `changes` counter 1 -> 0 (no shared-rows invalidation on unknown) is consistent. ParticipantServiceTests (pass) still allow an absent `data` at the service layer, the coordinator enforces the row.

## Notes
- poi-challenge note text says "row stays partial" while the status is exists; behavior is proven (gated honest state + success-only-after-server) so status kept, note text should be cleaned up.
- Hosted-SwiftUI AppUnit failures on the iOS 27 simulator are environmental per the round-4 audit; they were not re-diagnosed.
