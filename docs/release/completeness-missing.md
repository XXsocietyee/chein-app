# Completeness: open work packages

Source: `completeness-matrix.md` refresh 2 (app `e3264af9f`, backend hengyin `067da9748`). 169 rows are open: 135 MISSING and 34 IN-PROGRESS. Each open row is in exactly one package below. WP packages are sized for one native worker; NX packages need an owner or hengyin decision before any native work.

| package | rows | MISSING | IN-PROGRESS | native worker |
|---|---|---|---|---|
| [WP-01](#wp-01) Payout receivers and club settlement (money, gated) | 10 | 9 | 1 | yes |
| [WP-02](#wp-02) Play and creator tail: guard appeals, lead station, compensation reason | 12 | 12 | 0 | yes |
| [WP-03](#wp-03) Merchant operations gaps | 14 | 12 | 2 | yes |
| [WP-04](#wp-04) Coop invites and creative-square delete | 11 | 6 | 5 | yes |
| [WP-05](#wp-05) Money writes and payment readiness (owner gate first) | 10 | 2 | 8 | no |
| [WP-06](#wp-06) Partial pages close-out (roam tools, profile, invoices, coupons) | 12 | 0 | 12 | yes |
| [WP-07](#wp-07) Commerce §16–§17: product activate, group/school checkout, coupon usability | 10 | 7 | 3 | yes |
| [WP-08](#wp-08) Host tip, video attribution, OTA channel code, landing SEO (§18–§20) | 11 | 10 | 1 | yes |
| [WP-09](#wp-09) Template presets, team roles and after-sale (§21, U02-04, U06, U07) | 12 | 10 | 2 | yes |
| [WP-R](#wp-r) Roll-up rows (no worker: they close when their children close) | 5 | 5 | 0 | no |
| [NX-01](#nx-01) Owner decisions and product confirmation (not native work) | 21 | 21 | 0 | no |
| [NX-02](#nx-02) Back-office and backend-only gaps (not native work) | 5 | 5 | 0 | no |
| [NX-03](#nx-03) 落地清单 OPT program packages: triage for a native slice | 17 | 17 | 0 | no |
| [NX-04](#nx-04) 落地清单 OPT program packages: content, play, club, AI | 19 | 19 | 0 | no |
| total | 169 | 135 | 34 | |

How to close a row: land the change, then re-run the evaluator described under "Status rules" in `completeness-matrix.md` (capgraph for the app tree, the hengyin route list, and a test that cites the id). A row is not closed by a report alone.

## WP-01

**Payout receivers and club settlement (money, gated)** — 10 rows.

- Native files to touch: new App/ClubPayoutReceiverView.swift + App/MerchantPayoutAccountView.swift; App/ClubOpsSettlementViews.swift; Core client next to Core/ClubSettlement*.swift; route admission in App/ReviewedPlayerWriteLeases.swift; MPParityRoute cases in App/MPParityKit.swift
- Backend route: ApiClubController (personal-receiver/*), ApiClubSettlementController (settlement/mine), ApiMerchantPayoutAccountController, ApiClubDirectMerchantReceivableController
- Mini-program page: pages/club/payout-receiver/index, pages/merchant/payout-account/index, pages/club/settlement/index, components/cy/club-direct-merchant
- Acceptance test: On TEST 8120 the status and settlement reads render for club 9003 and merchant 9002; a unit test proves bind/unbind/payout-account writes send nothing while ReleaseMoneyWriteSwitch.payoutEnabled is false.

| row | status | what is open |
|---|---|---|
| `PAGE-pages/club/payout-receiver/index` | MISSING | page-map status=missing; not wired: /api/club/settlement/mine, /api/club/personal-receiver/status, /api/club/personal-receiver/bind, /api/club/personal-receiver/unbind |
| `PAGE-pages/merchant/payout-account/index` | MISSING | page-map status=missing; not wired: /api/merchant/payout-account |
| `PAGE-pages/club/settlement/index` | IN-PROGRESS (screen on e3264af9f, not finished) | page-map status=exists; not wired: /api/club/settlement/mine |
| `API-/api/club/personal-receiver/bind` | MISSING | no App/ or Core/ call site on e3264af9f; backend ApiClubController POST (ApiClubController.java) |
| `API-/api/club/personal-receiver/status` | MISSING | no App/ or Core/ call site on e3264af9f; backend ApiClubController GET (ApiClubController.java) |
| `API-/api/club/personal-receiver/unbind` | MISSING | no App/ or Core/ call site on e3264af9f; backend ApiClubController POST (ApiClubController.java) |
| `API-/api/club/settlement/mine` | MISSING | no App/ or Core/ call site on e3264af9f; backend ApiClubSettlementController POST (ApiClubSettlementController.java) |
| `API-/api/merchant/payout-account` | MISSING | no App/ or Core/ call site on e3264af9f; backend ApiMerchantPayoutAccountController POST (ApiMerchantPayoutAccountController.java) |
| `API-/api/club-direct-merchant/club` | MISSING | no App/ or Core/ call site on e3264af9f; backend ApiClubDirectMerchantReceivableController GET (ApiClubDirectMerchantReceivableController.java) |
| `API-/api/club-direct-merchant/merchant` | MISSING | no App/ or Core/ call site on e3264af9f; backend ApiClubDirectMerchantReceivableController GET (ApiClubDirectMerchantReceivableController.java) |

## WP-02

**Play and creator tail: guard appeals, lead station, compensation reason** — 12 rows.

- Native files to touch: App/PlayExperienceView.swift, Core/PlayExperienceContracts.swift (PlayLeadAction), App/CreatorContentViews.swift, App/ClubDetailView.swift, Core/TemplateContentReportContracts.swift
- Backend route: ApiAuditController, ApiClubLeadController, ApiClubCompensationController; /api/template/report-receipt has no route in 067da9748 (ask hengyin or drop the client path)
- Mini-program page: pages/play/index, subpackageA/pages/myproject/index, pages/club/detail/index
- Acceptance test: XCTest per path asserts the request shape against the hengyin controller signature, and an E2E rerun on TEST shows a guard appeal round-trip (submit then receipt) from My projects. Also covers E2E-20261113b N5 if the same worker takes the advanced-prerequisite session flow.

| row | status | what is open |
|---|---|---|
| `PAGE-pages/play/index` | MISSING | page-map status=partial; not wired: /api/club/lead/release-station, /api/club/lead/unlock-chapter-receipt, /api/audit/guard/reference, /api/audit/guard/appeal/receipt, /api/audit/guard/appeal |
| `PAGE-subpackageA/pages/myproject/index` | MISSING | page-map status=partial; not wired: /api/audit/appeal/receipt, /api/audit/appeal |
| `PAGE-pages/club/detail/index` | MISSING | page-map status=partial; not wired: /api/club-compensation/editions/empty-reason |
| `API-/api/audit/appeal` | MISSING | no App/ or Core/ call site on e3264af9f; backend ApiAuditController POST (ApiAuditController.java) |
| `API-/api/audit/appeal/receipt` | MISSING | no App/ or Core/ call site on e3264af9f; backend ApiAuditController GET (ApiAuditController.java) |
| `API-/api/audit/guard/appeal` | MISSING | no App/ or Core/ call site on e3264af9f; backend ApiAuditController POST (ApiAuditController.java) |
| `API-/api/audit/guard/appeal/receipt` | MISSING | no App/ or Core/ call site on e3264af9f; backend ApiAuditController GET (ApiAuditController.java) |
| `API-/api/audit/guard/reference` | MISSING | no App/ or Core/ call site on e3264af9f; backend ApiAuditController GET (ApiAuditController.java) |
| `API-/api/club/lead/release-station` | MISSING | no App/ or Core/ call site on e3264af9f; backend ApiClubLeadController POST (ApiClubLeadController.java) |
| `API-/api/club/lead/unlock-chapter-receipt` | MISSING | path only in a registry/capability table, no client call site; Core/ChinaReviewedRouteCapability.swift:1696; backend ApiClubLeadController GET (ApiClubLeadController.java) |
| `API-/api/club-compensation/editions/empty-reason` | MISSING | no App/ or Core/ call site on e3264af9f; backend ApiClubCompensationController POST (ApiClubCompensationController.java) |
| `API-/api/template/report-receipt` | MISSING | app call site present; no route in hengyin 067da9748 (capgraph backend-r6); Core/TemplateContentReportContracts.swift:11 |

## WP-03

**Merchant operations gaps** — 14 rows.

- Native files to touch: App/MerchantOperationsViews.swift, App/MerchantStoreCharacterView.swift, App/MerchantBusinessViews.swift, App/CouponManagementView.swift, App/MerchantContentViews.swift, Core/MerchantBusinessMutation.swift
- Backend route: ApiMerchantClaimController, ApiMerchantCommerceController, ApiMerchantController (coupon-summary, npc/review, share-code), ApiMerchantOperatorController, ApiMerchantChapterApplicationController
- Mini-program page: pages/merchant/decor/*, pages/merchant/team/index, subpackageMember/coupon/coupon, pages/topic/merchantinfo/merchantinfo, pages/merchant/components/claim*
- Acceptance test: Signed in as merchant 9002 on TEST 8120, each of the nine routes returns 200 from its screen (request log), and commerce/order stays refused in production by the merchant money gate (unit test).

| row | status | what is open |
|---|---|---|
| `PAGE-pages/merchant/decor/index` | MISSING | page-map status=partial; not wired: /api/merchant/commerce/order/status, /api/merchant/commerce/order |
| `PAGE-pages/merchant/decor/ai-npc/index` | MISSING | page-map status=gated; not wired: /api/merchant/npc/review |
| `PAGE-pages/merchant/team/index` | IN-PROGRESS (screen on e3264af9f, not finished) | page-map status=exists; not wired: /api/merchant/operators/invite/preview |
| `PAGE-subpackageMember/coupon/coupon` | IN-PROGRESS (screen on e3264af9f, not finished) | page-map status=exists; not wired: /api/merchant/coupon-summary |
| `PAGE-pages/topic/merchantinfo/merchantinfo` | MISSING | page-map status=partial; not wired: /api/merchant/chapter-application/invite/revoke |
| `API-/api/merchant/claims/status` | MISSING | no App/ or Core/ call site on e3264af9f; backend ApiMerchantClaimController GET (ApiMerchantClaimController.java) |
| `API-/api/merchant/claims/submit` | MISSING | no App/ or Core/ call site on e3264af9f; backend ApiMerchantClaimController POST (ApiMerchantClaimController.java) |
| `API-/api/merchant/commerce/order` | MISSING | no App/ or Core/ call site on e3264af9f; backend ApiMerchantCommerceController POST (ApiMerchantCommerceController.java) |
| `API-/api/merchant/commerce/order/status` | MISSING | no App/ or Core/ call site on e3264af9f; backend ApiMerchantCommerceController POST (ApiMerchantCommerceController.java) |
| `API-/api/merchant/coupon-summary` | MISSING | no App/ or Core/ call site on e3264af9f; backend ApiMerchantController POST (ApiMerchantController.java) |
| `API-/api/merchant/npc/review` | MISSING | no App/ or Core/ call site on e3264af9f; backend ApiMerchantController GET (ApiMerchantController.java) |
| `API-/api/merchant/operators/invite/preview` | MISSING | no App/ or Core/ call site on e3264af9f; backend ApiMerchantOperatorController POST (ApiMerchantOperatorController.java) |
| `API-/api/merchant/share-code` | MISSING | no App/ or Core/ call site on e3264af9f; backend ApiMerchantController POST (ApiMerchantController.java) |
| `API-/api/merchant/chapter-application/invite/revoke` | MISSING | no App/ or Core/ call site on e3264af9f; backend ApiMerchantChapterApplicationController POST (ApiMerchantChapterApplicationController.java) |

## WP-04

**Coop invites and creative-square delete** — 11 rows.

- Native files to touch: Core/CooperationFlowContracts.swift (CoopFlowMutation.path), App/CooperationContextualViews.swift, App/CooperationInviteDetailView.swift, Core/SocialActionContracts.swift, App/SquareDetailView.swift
- Backend route: ApiCoopController (invite/read, invite/request(s), supply-stations), ApiCreativeSquareController (delete)
- Mini-program page: pages/coop/invite/index, pages/coop/invite-detail/index, pages/square/detail/index, pages/mylike/mylike
- Acceptance test: Unit tests build each path from the client type (not only the capability table), and on TEST an author deletes their own square post and the list re-reads without it.

| row | status | what is open |
|---|---|---|
| `PAGE-pages/coop/invite/index` | IN-PROGRESS (screen on e3264af9f, not finished) | page-map status=exists; not wired: /api/coop/invite/request, /api/coop/invite/requests, /api/coop/supply-stations |
| `PAGE-pages/coop/invite-detail/index` | IN-PROGRESS (screen on e3264af9f, not finished) | page-map status=exists; not wired: /api/coop/invite/read |
| `PAGE-pages/merchant/relation/index` | MISSING | page-map status=partial; not wired: /api/creativesquare/delete |
| `PAGE-pages/mylike/mylike` | IN-PROGRESS (screen on e3264af9f, not finished) | page-map status=exists; not wired: /api/creativesquare/delete |
| `PAGE-pages/square/detail/index` | IN-PROGRESS (screen on e3264af9f, not finished) | page-map status=exists; not wired: /api/creativesquare/delete |
| `PAGE-pages/talent/list/index` | IN-PROGRESS (screen on e3264af9f, not finished) | page-map status=exists; not wired: /api/creativesquare/delete |
| `API-/api/coop/invite/read` | MISSING | path only in a registry/capability table, no client call site; Core/ChinaReviewedRouteCapability.swift:1774; backend ApiCoopController POST (ApiCoopController.java) |
| `API-/api/coop/invite/request` | MISSING | path only in a registry/capability table, no client call site; Core/ChinaReviewedRouteCapability.swift:1775; backend ApiCoopController GET (ApiCoopController.java) |
| `API-/api/coop/invite/requests` | MISSING | path only in a registry/capability table, no client call site; Core/ChinaReviewedRouteCapability.swift:1776; backend ApiCoopController GET (ApiCoopController.java) |
| `API-/api/coop/supply-stations` | MISSING | path only in a registry/capability table, no client call site; Core/ChinaReviewedRouteCapability.swift:1797; backend ApiCoopController GET (ApiCoopController.java) |
| `API-/api/creativesquare/delete` | MISSING | no App/ or Core/ call site on e3264af9f; backend ApiCreativeSquareController POST (ApiCreativeSquareController.java) |

## WP-05

**Money writes and payment readiness (owner gate first)** — 10 rows.

- Native files to touch: App/RegistrationSheetView.swift, Core/RegistrationCheckoutPresentation.swift, Core/ChinaReviewedRouteCapability.swift (ReleaseMoneyWriteSwitch, forcedOff), Core/BankWithdrawalAdapter.swift, App/ProfileEditView.swift
- Backend route: ApiRegistrationController, ApiMiscGapController, ApiFundActionPreflightController, ApiWithdrawalController; /api/getwxbindphone is WeChat-only (ApiLoginController)
- Mini-program page: pages/activity/baoming/baoming, subpackageA/pages/assetcenter/earnings/index, pages/gerenziliao/gerenziliao
- Acceptance test: Owner decides whether TEST/DEBUG may send money writes (E2E-20261113b "Money writes"). Then: payment-readiness renders on the sign-up sheet, and a unit test keeps every money write refused on the China production host. getwxbindphone is marked dropped in page-map (WeChat-only).

| row | status | what is open |
|---|---|---|
| `PAGE-pages/activity/baoming/baoming` | IN-PROGRESS (screen on e3264af9f, not finished) | page-map status=exists; not wired: /api/registration/payment-readiness; production off: /api/registration/pay |
| `PAGE-pages/gerenziliao/gerenziliao` | IN-PROGRESS (screen on e3264af9f, not finished) | page-map status=gated |
| `API-/api/registration/payment-readiness` | MISSING | no App/ or Core/ call site on e3264af9f; backend ApiRegistrationController POST (ApiRegistrationController.java) |
| `API-/api/registration/pay` | IN-PROGRESS (call site on e3264af9f, production off) | forcedOff(virtual-goods) keeps this write off in China production; Core/OrderLifecycleDormantAdapter.swift:16; backend ApiRegistrationController POST (ApiRegistrationController.java) |
| `API-/api/pay/create` | IN-PROGRESS (call site on e3264af9f, production off) | forcedOff(virtual-goods) keeps this write off in China production; App/RegionalEndpointAllowlistSectionView.swift:73; backend ApiMiscGapController POST (ApiMiscGapController.java) |
| `API-/api/asset/withdraw` | IN-PROGRESS (call site on e3264af9f, production off) | forcedOff(bank-withdrawal) keeps this write off in China production; App/RegionalEndpointAllowlistSectionView.swift:72; backend ApiMiscGapController POST (ApiMiscGapController.java) |
| `API-/api/fund/preflight/bank-withdrawal` | IN-PROGRESS (call site on e3264af9f, production off) | forcedOff(bank-withdrawal) keeps this write off in China production; Core/BankWithdrawalAdapter.swift:106; backend ApiFundActionPreflightController POST (ApiFundActionPreflightController.java) |
| `API-/api/withdrawal/create` | IN-PROGRESS (call site on e3264af9f, production off) | forcedOff(bank-withdrawal) keeps this write off in China production; App/QuestifyApp.swift:438; backend ApiWithdrawalController POST (ApiWithdrawalController.java) |
| `API-/api/getwxbindphone` | MISSING | no App/ or Core/ call site on e3264af9f; backend ApiLoginController POST (ApiLoginController.java) |
| `OWN-READ-工坊付费安装-渠道支付-视频现金兑付` | IN-PROGRESS (production off) | App/AccountView.swift:300; test Tests/AppUnitTests/StoryWalkingFogAndWorkshopUpgradeViewTests.swift:23; workshop purchase/install/income and video cash payout requested only under the non-production test switch (merge 213f1fae2) |

## WP-06

**Partial pages close-out (roam tools, profile, invoices, coupons)** — 12 rows.

- Native files to touch: the screen named in each row (App/ProfileParticipantsView.swift, App/PublishingModesViews.swift, App/ProfileComplaintPreparationView.swift, App/CouponManagementView.swift, App/InvoiceLaunchApplyView.swift, App/RoamStampViews.swift, App/RoamStampCameraView.swift, App/RoamSubpageParityViews.swift, App/RoamHistoryViews.swift, App/RoamPassportToolsViews.swift, App/RoamExplorationExportView.swift); docs/parity/page-map.csv
- Backend route: all page routes already served and wired (page APIs n/n DONE in the evidence column)
- Mini-program page: the page in each row
- Acceptance test: For each page, the gap named in its page-map note is closed or recorded as a decision, page-map status moves from partial/gated to exists with a hosted XCTest that opens the screen, and the matrix row re-evaluates DONE.

| row | status | what is open |
|---|---|---|
| `PAGE-pages/address/address` | IN-PROGRESS (screen on e3264af9f, not finished) | page-map status=partial |
| `PAGE-pages/publish/simple/index` | IN-PROGRESS (screen on e3264af9f, not finished) | page-map status=partial |
| `PAGE-subpackageMember/complaint/index` | IN-PROGRESS (screen on e3264af9f, not finished) | page-map status=gated |
| `PAGE-subpackageMember/couponInfo/couponInfo` | IN-PROGRESS (screen on e3264af9f, not finished) | page-map status=partial |
| `PAGE-subpackageMember/invoice-apply/index` | IN-PROGRESS (screen on e3264af9f, not finished) | page-map status=partial |
| `PAGE-subpackageP3/pages/stamp-album/index/index` | IN-PROGRESS (screen on e3264af9f, not finished) | page-map status=partial |
| `PAGE-subpackageP3/pages/stamp-camera/index/index` | IN-PROGRESS (screen on e3264af9f, not finished) | page-map status=partial |
| `PAGE-subpackageRoam/citystamp/index` | IN-PROGRESS (screen on e3264af9f, not finished) | page-map status=partial |
| `PAGE-subpackageRoam/history/index` | IN-PROGRESS (screen on e3264af9f, not finished) | page-map status=partial |
| `PAGE-subpackageTools/anniversary/index` | IN-PROGRESS (screen on e3264af9f, not finished) | page-map status=partial |
| `PAGE-subpackageTools/exploration-export/index` | IN-PROGRESS (screen on e3264af9f, not finished) | page-map status=partial |
| `PAGE-subpackageTools/monthly-recap/index` | IN-PROGRESS (screen on e3264af9f, not finished) | page-map status=partial |

## WP-07

**Commerce §16–§17: product activate, group/school checkout, coupon usability** — 10 rows.

- Native files to touch: App/PassMarketViews.swift (PassProductKind.group/.schoolGroup), App/MPParityPassSession.swift, App/RegistrationSheetView.swift, new Core client for group-checkout
- Backend route: /api/marketing/product/activate, /api/marketing/group-checkout/quote, /api/marketing/group-checkout/create, /api/coupon/usability (all served on 067da9748; TEST 8120 answers 401 without a token)
- Mini-program page: subpackageMember/market/pass/index, subpackageMember/market/passes/index, pages/activity/baoming/baoming
- Acceptance test: Group/school quote shows the server tier and total from group-checkout/quote (never a local price), coupon usability renders read-only with couponDeductYuan staying 0, and create/activate stay behind MPCommerceGate (unit tests).

| row | status | what is open |
|---|---|---|
| `OWN-17.1` | MISSING | App/MPParityPassSession.swift:134; test Tests/AppUnitTests/MPParityPassBindingTests.swift:8; routes /api/marketing/product/list=DONE, /api/marketing/product/quote=DONE, /api/marketing/product/activate=MISSING; open: /api/marketing/product/activate |
| `OWN-17.4` | IN-PROGRESS (code on e3264af9f, not finished) | App/PassMarketViews.swift:21; routes /api/marketing/group-checkout/quote=MISSING, /api/marketing/group-checkout/create=MISSING; no test cites it; open: /api/marketing/group-checkout/quote, /api/marketing/group-checkout/create |
| `OWN-17.6` | MISSING | App/RegistrationSheetView.swift:551; test Tests/CoreTests/ActivityRegistrationParityW206Tests.swift:400; routes /api/registration/quote=DONE, /api/coupon/usability=MISSING; open: /api/coupon/usability |
| `OWN-十六-04` | IN-PROGRESS (code on e3264af9f, not finished) | App/PassMarketViews.swift:21; routes /api/marketing/group-checkout/quote=MISSING; no test cites it; open: /api/marketing/group-checkout/quote |
| `OWN-十六-07` | IN-PROGRESS (code on e3264af9f, not finished) | App/PassMarketViews.swift:21; routes /api/marketing/group-checkout/quote=MISSING, /api/marketing/group-checkout/create=MISSING; no test cites it; open: /api/marketing/group-checkout/quote, /api/marketing/group-checkout/create |
| `OWN-十七` | MISSING | rollup: 3/6 child rows not DONE: 17.1, 17.4, 17.6 |
| `OWN-十三-08` | MISSING | rollup: 2/4 child rows not DONE: 17.1, 17.4 |
| `OWN-十三-09` | MISSING | rollup: 1/2 child rows not DONE: 17.6 |
| `OWN-十六` | MISSING | rollup: 5/14 child rows not DONE: 十六-04, 十六-07, 十六-12, 十六-13, 十六-14 |
| `OWN-十一-16` | MISSING | rollup: 1/1 child rows not DONE: 十六 |

## WP-08

**Host tip, video attribution, OTA channel code, landing SEO (§18–§20)** — 11 rows.

- Native files to touch: new App/HostTipViews.swift + Core client; Core/VideoBountySource.swift (attribution is blocked on purpose at :88); App/PublicCatalogViews.swift; new channel-redeem sheet
- Backend route: /api/host-tip/{config,config/mine,prepare,intent/mine,intent/{id}/cancel}, /api/video-bounty/{submission,campaign}/{id}/attribution, /api/channel/redeem, /api/content-landing/{info,save,translation/save}
- Mini-program page: (owner doc §18–§20; no mini-program page beyond subpackageA/pages/video-bounty/index and pages/topic/catalog/*)
- Acceptance test: Host tip shows config and intent states with no payment success (501 CHANNEL_NOT_ENABLED renders as unavailable), attribution reads show UNKNOWN rather than 0, channel redeem shows unavailable when the provider is off, and §12-15/16/17 absence checks still hold.

| row | status | what is open |
|---|---|---|
| `OWN-C` | MISSING | routes /api/host-tip/config=MISSING, /api/host-tip/config/mine=MISSING; no native code traces this requirement |
| `OWN-D` | MISSING | routes /api/host-tip/prepare=MISSING, /api/host-tip/intent/{}/cancel=MISSING, /api/host-tip/intent/mine=MISSING; no native code traces this requirement |
| `OWN-G` | MISSING | test Tests/AppUITests/SettingsNativeFlowTests.swift:171; routes /api/video-bounty/submission/{}/attribution=MISSING, /api/video-bounty/campaign/{}/attribution=MISSING; Core/VideoBountySource.swift:88 deliberately blocks attribution methods; no native code traces this requirement |
| `OWN-十六-12` | MISSING | routes /api/host-tip/config=MISSING, /api/host-tip/prepare=MISSING, /api/host-tip/intent/mine=MISSING; no native code traces this requirement |
| `OWN-十六-13` | MISSING | routes /api/channel/redeem=MISSING; no native code traces this requirement |
| `OWN-十六-14` | IN-PROGRESS (code on e3264af9f, not finished) | App/PublicCatalogViews.swift:13; test Tests/AppUnitTests/PlayerJourneyProductionTests.swift:9; routes /api/public-catalog/list=DONE, /api/content-landing/info=MISSING; open: /api/content-landing/info |
| `OWN-20.1` | MISSING | App/PublicCatalogViews.swift:13; test Tests/AppUnitTests/PlayerJourneyProductionTests.swift:9; routes /api/public-catalog/city/list=DONE, /api/content-landing/info=MISSING, /api/content-landing/save=MISSING, /api/content-landing/translation/save=MISSING; open: /api/content-landing/info, /api/content-landing/save, /api/content-landing/translation/save |
| `OWN-20.2` | MISSING | routes /api/channel/redeem=MISSING; no native code traces this requirement |
| `OWN-十八` | MISSING | rollup: 3/8 child rows not DONE: C, D, G |
| `OWN-十三-10` | MISSING | rollup: 3/7 child rows not DONE: C, D, G |
| `OWN-十三-11` | MISSING | rollup: 2/2 child rows not DONE: 20.1, 20.2 |

## WP-09

**Template presets, team roles and after-sale (§21, U02-04, U06, U07)** — 12 rows.

- Native files to touch: App/DiscoveryTemplateBrowserView.swift, App/TopicTemplateUseSection.swift, App/SocialRoamMounts.swift, Core/PlayAdvancedTeamProjection.swift, App/TeamHomeView.swift, App/OrderLifecycleView.swift, App/WalletCommerceViews.swift
- Backend route: /api/preset/gameplay/{list,info,draft}; team and order reads already served (see U06/U07 sections of the owner doc)
- Mini-program page: pages/template/index, pages/team/detail/index, subpackageMember/orderinfo/orderinfo
- Acceptance test: Each U-id gets a code citation plus an XCTest named after it (the matrix rule), preset list → draft opens an editable draft on TEST, and partial refunds show the server amounts only.

| row | status | what is open |
|---|---|---|
| `OWN-21.1` | IN-PROGRESS (code on e3264af9f, not finished) | routes /api/preset/gameplay/draft=MISSING, /api/topic/v2/create=DONE, /api/template/adopt-draft=DONE; no test cites it; open: /api/preset/gameplay/draft |
| `OWN-21.2` | MISSING | routes /api/preset/gameplay/list=MISSING, /api/preset/gameplay/info=MISSING; no native code traces this requirement |
| `OWN-U02-04` | IN-PROGRESS (code on e3264af9f, not finished) | App/SocialRoamMounts.swift:192; no test cites it |
| `OWN-十三-02` | MISSING | rollup: 3/8 child rows not DONE: U02-04, 21.1, 21.2 |
| `OWN-U06-02` | MISSING | Core/PlayAdvancedTeamProjection.swift:10; no test cites it |
| `OWN-U06-04` | MISSING | no native code traces this requirement |
| `OWN-U07-01` | MISSING | no native code traces this requirement |
| `OWN-U07-02` | MISSING | no native code traces this requirement |
| `OWN-U07-03` | MISSING | no native code traces this requirement |
| `OWN-U07-04` | MISSING | no native code traces this requirement |
| `OWN-U07-05` | MISSING | no native code traces this requirement |
| `OWN-十三-03` | MISSING | rollup: 7/9 child rows not DONE: U06-02, U06-04, U07-01, U07-02, U07-03, U07-04, U07-05 |

## WP-R

**Roll-up rows (no worker: they close when their children close)** — 5 rows.

- Native files to touch: —
- Backend route: —
- Mini-program page: —
- Acceptance test: Re-run the evaluator after WP-07/08/09; each roll-up turns DONE when every native child row is DONE.

| row | status | what is open |
|---|---|---|
| `OWN-22.1` | MISSING | rollup: 7/9 child rows not DONE: 十六, 十七, 十八, 20.1, 20.2, 21.1, 21.2 |
| `OWN-22.2` | MISSING | rollup: 1/1 child rows not DONE: 22.1 |
| `OWN-十三` | MISSING | rollup: 6/11 child rows not DONE: 十三-02, 十三-03, 十三-08, 十三-09, 十三-10, 十三-11 |
| `OWN-十一` | MISSING | rollup: 1/3 child rows not DONE: 十三 |
| `OWN-十四` | MISSING | rollup: 1/1 child rows not DONE: 十三 |

## NX-01

**Owner decisions and product confirmation (not native work)** — 21 rows.

- Native files to touch: —
- Backend route: —
- Mini-program page: —
- Acceptance test: Owner records a decision per row in docs/owner-handover/SUPPLEMENT.md; rows that become build work move into a WP package.

| row | status | what is open |
|---|---|---|
| `OWN-D-01` | MISSING | owner decision still open (落地清单 §决策依赖); not native work |
| `OWN-D-02` | MISSING | owner decision still open (落地清单 §决策依赖); not native work |
| `OWN-D-03` | MISSING | owner decision still open (落地清单 §决策依赖); not native work |
| `OWN-D-04` | MISSING | owner decision still open (落地清单 §决策依赖); not native work |
| `OWN-D-05` | MISSING | owner decision still open (落地清单 §决策依赖); not native work |
| `OWN-D-06` | MISSING | owner decision still open (落地清单 §决策依赖); not native work |
| `OWN-D-07` | MISSING | owner decision still open (落地清单 §决策依赖); not native work |
| `OWN-D-08` | MISSING | owner decision still open (落地清单 §决策依赖); not native work |
| `OWN-D-09` | MISSING | owner decision still open (落地清单 §决策依赖); not native work |
| `OWN-D-10` | MISSING | owner decision still open (落地清单 §决策依赖); not native work |
| `OWN-10.3` | MISSING | owner doc §10.3: content contract v1 not finalised (未定稿，不作已实现) |
| `OWN-EXT-01` | MISSING | 落地清单 condition package 待产品确认 (needs product confirmation, D-09); not started |
| `OWN-EXT-02` | MISSING | 落地清单 condition package 待产品确认 (needs product confirmation, D-09); not started |
| `OWN-EXT-03` | MISSING | 落地清单 condition package 待产品确认 (needs product confirmation, D-09); not started |
| `OWN-EXT-04` | MISSING | 落地清单 condition package 待产品确认 (needs product confirmation, D-09); not started |
| `OWN-EXT-05` | MISSING | 落地清单 condition package 待产品确认 (needs product confirmation, D-09); not started |
| `OWN-EXT-06` | MISSING | 落地清单 condition package 待产品确认 (needs product confirmation, D-09); not started |
| `OWN-EXT-07` | MISSING | 落地清单 condition package 待产品确认 (needs product confirmation, D-09); not started |
| `OWN-EXT-08` | MISSING | 落地清单 condition package 待产品确认 (needs product confirmation, D-09); not started |
| `OWN-EXT-09` | MISSING | 落地清单 condition package 待产品确认 (needs product confirmation, D-09); not started |
| `OWN-EXT-11` | MISSING | 落地清单 condition package 待产品确认 (needs product confirmation, D-09); not started |

## NX-02

**Back-office and backend-only gaps (not native work)** — 5 rows.

- Native files to touch: — (hengyin admin console / backend)
- Backend route: hengyin admin (Vue) and a new team help-pool service (owner §25.1)
- Mini-program page: —
- Acceptance test: hengyin ships the admin pages and the team pool API; the native side then adds rows for the client half.

| row | status | what is open |
|---|---|---|
| `OWN-U03-04` | MISSING | out-of-native-scope (hengyin admin console / backoffice) |
| `OWN-UG-12` | MISSING | out-of-native-scope (hengyin admin console / backoffice) |
| `OWN-E` | MISSING | out-of-native-scope (hengyin admin console / backoffice) |
| `OWN-25.1` | MISSING | shared team help pool is a separate backend gap (owner §25.1); no native code traces this requirement |
| `OWN-READ-全队共享提示-跳过-计时-团队总分` | MISSING | shared team help pool is a separate backend gap (owner §25.1); no native code traces this requirement |

## NX-03

**落地清单 OPT program packages: triage for a native slice** — 17 rows.

- Native files to touch: Core/UnifiedOPT*Contract.swift and App/UnifiedOPT*SectionView.swift are records only
- Backend route: per OPT ticket
- Mini-program page: per OPT ticket
- Acceptance test: For each OPT id the owner says whether native has a slice; the slice becomes a WP row with a test, otherwise the row is closed as not-native in SUPPLEMENT.md.

| row | status | what is open |
|---|---|---|
| `OWN-OPT-001` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-002` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-003` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-070` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-071` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-072` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-090` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-091` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-092` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-010` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-011` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-012` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-013` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-014` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-060` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-061` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-062` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |

## NX-04

**落地清单 OPT program packages: content, play, club, AI** — 19 rows.

- Native files to touch: Core/UnifiedOPT*Contract.swift and App/UnifiedOPT*SectionView.swift are records only
- Backend route: per OPT ticket
- Mini-program page: per OPT ticket
- Acceptance test: Same triage as NX-03.

| row | status | what is open |
|---|---|---|
| `OWN-OPT-020` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-021` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-022` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-023` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-030` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-031` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-032` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-033` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-040` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-041` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-042` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-043` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-050` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-051` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-052` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-053` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-080` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-081` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |
| `OWN-OPT-082` | MISSING | 落地清单 program package (mini-program/backend owners); Core/UnifiedOPT*/EXT* files are contract records, not behaviour; no native acceptance test |

