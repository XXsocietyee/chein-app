# RM-01 receipt (`ui/cur-rm-01`)

Task 75. Branch `ui/cur-rm-01` from `origin/ui/main` `3ac970ec20191014b4b9a8779a3a94b961e99c9c`. The RM-01 section was read from `e4df7bd51` (`docs/completeness-4`, `docs/release/completeness-remaining.md`). That commit is not the base.

`App/AppSession.swift`, `App/AppCompositionRoot.swift`, and `App/RegionalLaunchConfiguration.swift` were not edited. `ReviewedAreaSwitch` was not redeclared. `docs/release/contract-failing-baseline.txt` was not edited. No new grant was added. The production host `www.chengyinhub.com` stays closed. Unknown stays an em dash. A decoded 0 stays 0.

`swiftc` is not on this machine. The XCTest process did not run. Nothing below is a Swift typecheck.

`python3 tools/check_page_map_gated.py` passed. `python3 tools/check_merchant_business.py` still fails three checks that read `Core/Merchant*.swift` and the merchant-business catalog (`merchant.business.reviews.listEnd`, `/api/registration/scan_qr_code`, and `.reduce(`). Those files were not edited on this branch.

## Rows

| row | status | evidence |
|---|---|---|
| `PAGE-pages/merchant/decor/index` | DONE | Page-map `exists`. `testDecorHomeSessionReaderSendsAccessRead` drives `MerchantOperationsSessionReader.access()`, the read `MerchantOperationsHomeView.load` sends. `MerchantOpsWp03Panel(page: .decor)` stays on the screen. Save stays hidden while `canSave` is false. |
| `PAGE-pages/merchant/decor/ai-npc/index` | DONE | Page-map `exists`. `choosePhoto` applies a supplied https reference only when `storeCharacterSaves` is on. Otherwise the notice is `photoUnavailable` and nothing is sent. Voice enroll stays `writesDisabled` until `storeVoiceEnrollment` is on. `StoreCharacterGatedStateTests` covers both. `MerchantOpsWp03Panel(page: .npc)` stays on the screen. |
| `PAGE-pages/merchant/relation/index` | DONE | Page-map `exists`. `SessionCoopRelationDiscoveryView` calls `CoopRelationPostFeedFactory.make` with `session.clubCommunityContext`. A nil community still returns nil. `testSessionHostCallsPostFeedFactory` reads that call site. |
| `PAGE-pages/topic/merchantinfo/merchantinfo` | DONE | Page-map `exists`. `testProjectListReadSendsMerchantScope` loads `.projects` and checks the `api/project/my` body contains `scope` `MERCHANT`. Chapter reads stay in the same suite. |
| `OWN-OPT-014` | DONE | `testCouponStockCitesOWNOPT014`. A sold-out definition shows remaining `0`. `perLimit` `0` stays `0`. A missing count is `—`. Coupon summary path is `api/merchant/coupon-summary`. |
| `OWN-OPT-022` | DONE | `testAuditAppealCitesOWNOPT022`. `CreatorAuditAppealFlow`, `api/audit/appeal`, and `api/audit/guard/appeal` are in the WP-02 tail routes. |
| `OWN-OPT-032` | DONE | `testGameplayPresetCitesOWNOPT032`. `GameplayPresetPath` list, info, and draft. An empty source revision shows `—` in English and 历史来源待核对 in Chinese. |
| `OWN-OPT-043` | DONE | `testStampPagesCitesOWNOPT043`. `RoamStampCameraView`, `RoamStampAlbumView`, and `RoamCityStampFlowView` (`subpackageRoam/citystamp`). |
| `OWN-OPT-060` | DONE | `testMerchantClaimsCitesOWNOPT060`. `api/merchant/claims/status` is a read. `api/merchant/commerce/order` is a money write and is not admitted on the China production host. |
| `OWN-OPT-062` | DONE | `testChapterInviteRevokeCitesOWNOPT062`. `api/merchant/chapter-application/invite/revoke` is a merchant write and is not admitted on the China production host. The chapter panel is on `MerchantContentViews`. |
| `OWN-OPT-082` | DONE | `testSimplePublishAIDraftCitesOWNOPT082`. `QuickPublishSimpleCount` of `0` stays `0`. Unknown stays `—`. `QuickPublishSimpleJourneyService.confirmAndSeed` and `aiTraceId` are in the tree. |

Rows still open: none.
